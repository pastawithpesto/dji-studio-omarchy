import QtQuick 2.15
import FlingHelper 1.0
import VelocityCalculator 1.0
import CursorHelper 1.0

Item {

    // 是否启用拖动释放后的fling，对于非全景视频，理论上应该不需要，禁用可以减少部分操作
    property alias enableDragFling: flingHandler.enable
    // 这个属性是触摸板的双指滚动手势，为true，则双指手势为滑动，为false，则双指手势为缩放
    property alias twoFingerRoll: touchPadWheelHandler.enabled
    property int activedHandlerCount: 0
    property bool gesturing: false
    //WheelHandler.active 的活跃期非常短暂，到 onActivedHandlerCountChanged 执行时可能已经变回 false 了。
    property bool wheelGesturing: false  // 新增
    // 鼠标是否悬停在覆盖层（文字等）上
    property bool mouseOnOverlay: false
    //文本区按下状态
    property bool overlayPressed: false
    property bool isPanorama:false
    // 按下时画布归一化落点[0,1]，供 gestureStart 做画布空间命中选源
    property point gestureStartPoint: Qt.point(-1, -1)
    // 落点级全景命中回调 (nx,ny)->bool：判断该落点命中的片段是否为全景
    property var hitTestPanorama: null
    //拖拽状态，鼠标按下开始拖拽，鼠标释放停止拖拽，只记录状态
    //不能用gesturing来判断拖拽状态，因为FlingHelper没结束前，
    //gesturing一直为true，导致鼠标样式延迟变化
    property bool dragging: false
    // 鼠标当前是否悬停在“可拖动的全景画面”上（落点级判断）。
    // setCustomCursor 走 Qt 覆盖光标压栈，必须仅在该状态翻转时 push/pop 一次，
    // 否则鼠标每次移动都会把光标压栈导致栈无限膨胀。
    property bool hoveringPanorama: false

    onDraggingChanged: {
        if (!isPanorama)
            return;

        if (dragging) {
            if (wheelGesturing) {
                return;
            }
            //如果发生了拖拽，就设置拖拽手,左键拖拽
            else if (overlayPressed) {
                cursorhelper.setCustomCursor(":/icons/panorama/left_click.svg", 32, 32)
            }else if (gestureMouseArea.pressedButton === Qt.RightButton) {
                cursorhelper.setCustomCursor(":/icons/panorama/right_pressed_add_key_freme.svg", 32, 32)
            }else if (!mouseOnOverlay){
                //在文本区点击左键(disable文本框了)
                cursorhelper.setCustomCursor(":/icons/panorama/left_click.svg", 32, 32)
            }
        } else {
            wheelGesturing = false;

            //先恢复系统图标
            cursorhelper.restoreAllOverrideCursors();
            hoveringPanorama = false;
            //无论是在哪个地方取消拖拽的,都设置成无按下操作
            gestureMouseArea.anyButtonPressed = false
            gestureMouseArea.pressedButton = Qt.NoButton
            //拖拽结束后按当前落点刷新光标：仍在透出的全景画面上→全景手型，普通视频/非视频区→系统光标
            if (!mouseOnOverlay && hoverHandler.hovered && width > 0 && height > 0) {
                refreshHoverCursor(hoverHandler.point.position.x / width, hoverHandler.point.position.y / height)
            }
        }

    }

    signal move(real deltaX, real deltaY, bool fling)
    // 这个参数发生了变更，不再是缩放系数，而是改成了一个比例，作用是使缩放变成线性操作
    // 比例的意思是相对于整个变化范围，本次zoom变化了多少。
    // 例如fov的范围是15-155，那么如果deltaPercentage是0.1，那么本次fov变化需要增加14
    signal zoom(real deltaPercentage, bool end)
    signal rotate(real rotation)

    onActivedHandlerCountChanged: {

        if (activedHandlerCount == 1 && !gesturing) {
            gesturing = true;
            return;
        }
        if (activedHandlerCount <= 0 && gesturing) {
            // zoom(0, true);
            gesturing = false;
        }
    }

    FlingHelper {
        id: flingHandler

        property real lastX: 0.0
        property real lastY: 0.0

        onActiveChanged: {
            lastX = 0;
            lastY = 0;
            activedHandlerCount += (active ? 1 : -1);
        }

        Component.onCompleted: {
            flingChanged.connect(function (newX, newY) {
                    const deltaX = newX - lastX;
                    const deltaY = newY - lastY;
                    lastX = newX;
                    lastY = newY;
                    move(deltaX, deltaY, true);
                });
        }
    }

    VelocityCalculator {
        id: velocityCalculator
    }

    CursorHelper {
        id: cursorhelper
    }

    //用来处理按键操作
    MouseArea {
        id: gestureMouseArea
        acceptedButtons: Qt.AllButtons
        anchors.fill: parent
        hoverEnabled: true
        //非文本/仪表盘区域是否有按钮按下
        property bool anyButtonPressed: false
        //非文本/仪表盘区域按下的键
        property int pressedButton:Qt.NoButton

        onPressed: (mouse) => {
            flingHandler.stop();

            if (!isPanorama) {
                mouse.accepted = false
                return
            }

            // 落点级精确门控：命中被遮挡的普通视频区时不起全景手势
            let nx = width > 0 ? mouse.x / width : -1.0
            let ny = height > 0 ? mouse.y / height : -1.0
            if (hitTestPanorama && !hitTestPanorama(nx, ny)) {
                mouse.accepted = false
                return
            }
            gestureStartPoint = Qt.point(nx, ny)

            anyButtonPressed = true
            if (mouse.button === Qt.RightButton) {
                cursorhelper.setCustomCursor(":/icons/panorama/right_pressed_add_key_freme.svg", 32, 32)
                globalSignal.callItemSelectedByPosition()
                globalSignal.rightPressedAddKeyFrameAction();
            }
            else if (mouse.button === Qt.LeftButton) {
                cursorhelper.setCustomCursor(":/icons/panorama/left_click.svg", 32, 32)
            }
            pressedButton = mouse.button
        }
        onReleased: (mouse) => {
            anyButtonPressed = false
            cursorhelper.restoreOverrideCursor()
            pressedButton = Qt.NoButton
        }
    }

    //防止DragHandler对MouseArea的hover事件干扰，用HoverHandler来判断进出窗口
    HoverHandler {
        id: hoverHandler
        // 悬停移动时按落点刷新光标：移到普通视频画面区→恢复系统光标，移到透出的全景区→全景手型
        onPointChanged: {
            if (hovered && !mouseOnOverlay && !gestureMouseArea.anyButtonPressed && !dragging) {
                let nx = width > 0 ? point.position.x / width : -1.0
                let ny = height > 0 ? point.position.y / height : -1.0
                refreshHoverCursor(nx, ny)
            }
        }
        onHoveredChanged: {
            //进入
            if (hovered && !mouseOnOverlay) {
                //没有任何按键按下的时候进入,才会修改，防止出现在视频区按下移出来后又进去鼠标样式异常变化的情况
                if (!gestureMouseArea.anyButtonPressed && !dragging && width > 0 && height > 0) {
                    //按进入点的落点决定光标：透出的全景区→全景手型，普通视频画面区→系统光标
                    refreshHoverCursor(point.position.x / width, point.position.y / height)
                }
            }
            //退出
            else{
                //没有任何按键的时候退出恢复系统图标
                if (!gestureMouseArea.anyButtonPressed && !dragging) {
                    hoveringPanorama = false
                    cursorhelper.restoreAllOverrideCursors()
                }
            }
        }
    }


    // 移动监听
    DragHandler {
        //鼠标左键右键同时支持拖拽
        acceptedButtons:Qt.LeftButton | Qt.RightButton
        acceptedModifiers: Qt.NoModifier
        dragThreshold: 0

        property bool cancelDrag: false
        property real lastX: 0.0
        property real lastY: 0.0
        property real lastTime: 0.0

        property real minAngle: Math.tan(5 * Math.PI / 180) // 5 degrees in radians

        onActiveChanged: {
            lastX = 0.0;
            lastY = 0.0;
            if (active) {
                // 按着右键从区域外进来时禁止拖拽
                // 注意: cancelDrag 在 dragging = true 之前 return，
                // 所以 dragging 不会被错误设置
                if (!gestureMouseArea.anyButtonPressed && !mouseOnOverlay && !overlayPressed) {
                    cancelDrag = true;
                    return;
                }
                dragging = true;

                lastTime = Date.now();
                activedHandlerCount += 1;
                flingHandler.stop();
                velocityCalculator.reset();

            } else {
                dragging = false;

                if (cancelDrag) {
                    cancelDrag = false
                    return;
                }

                const velocityX = velocityCalculator.velocityX;
                const velocityY = velocityCalculator.velocityY;
                if ((velocityX !== 0 || velocityY !== 0) && Date.now() - lastTime < 100) {
                    flingHandler.fling(velocityX, velocityY, Number.MAX_SAFE_INTEGER, Number.MAX_SAFE_INTEGER);
                }
                velocityCalculator.reset();

                lastX = 0.0;
                lastY = 0.0;

                Qt.callLater(function () { activedHandlerCount -= 1;});
            }
        }
        onTranslationChanged: {
            if (lastX == 0.0 && lastY == 0.0) {
                // DragHandler更新Translation有bug，在激活的时候拿不到正确的值，只有当translation改变的时候才能拿到正确的值
                // 所以第一次用来更新数据，不做实际移动。
                lastX = translation.x;
                lastY = translation.y;
                return;
            }

            let deltaX = translation.x - lastX;
            let deltaY = translation.y - lastY;

            if (Math.abs(deltaX) > Math.abs(deltaY)) {
                if (deltaX != 0 && Math.abs(deltaY / deltaX) < minAngle) {
                    deltaY = 0;
                }
            } else {
                if (deltaY != 0 && Math.abs(deltaX / deltaY) < minAngle) {
                    deltaX = 0;
                }
            }
            move(deltaX, deltaY, false);
            lastX = translation.x;
            lastY = translation.y;
            const now = Date.now();
            const deltaTime = now - lastTime;
            lastTime = now;
            velocityCalculator.update(deltaX, deltaY, deltaTime);
        }
    }

    // 旋转监听，在按住CMD键的时候，拖动事件转换为按照中心点旋转
    DragHandler {
        acceptedModifiers: Qt.ControlModifier
        dragThreshold: 0

        property real pivotX: 0.0
        property real pivotY: 0.0

        property real startX: 0.0
        property real startY: 0.0

        property real startAngle: 0
        property real lastAngle: 0

        // 是否取消本次旋转：起手不在透出全景区时置位，全程不触发旋转（与平移拖动的 cancelDrag 同理）
        property bool cancelRotate: false

        onGrabChanged: (transition, point) => {
            if (transition == 16) {
                pivotX = point.position.x;
                pivotY = point.position.y;

                startAngle = calculateAngle(width / 2, height / 2, pivotX, pivotY);
                lastAngle = startAngle;
            }
        }

        onActiveChanged: {
            startY = 0;
            if (active) {
                // 起手落点门控：与平移拖动一致，按下不在透出全景区（anyButtonPressed 未置位）则取消本次旋转
                if (!gestureMouseArea.anyButtonPressed && !mouseOnOverlay && !overlayPressed) {
                    cancelRotate = true;
                    return;
                }
                cancelRotate = false;
                activedHandlerCount += 1;
                flingHandler.stop();
            } else {
                if (cancelRotate) {
                    cancelRotate = false;
                    return;
                }
                activedHandlerCount -= 1;
                pivotX = 0;
                pivotY = 0;
                startAngle = 0;
                lastAngle = 0;
                // 旋转结束：pop 按下时压入的光标，重置状态后刷新为悬停光标
                cursorhelper.restoreOverrideCursor();
                gestureMouseArea.anyButtonPressed = false;
                gestureMouseArea.pressedButton = Qt.NoButton;
                hoveringPanorama = false;
                if (!mouseOnOverlay && hoverHandler.hovered && width > 0 && height > 0) {
                    refreshHoverCursor(hoverHandler.point.position.x / width, hoverHandler.point.position.y / height);
                }
            }
        }

        onTranslationChanged: {
            if (cancelRotate) {
                return;
            }
            if (startX == 0.0 && startY == 0.0) {
                // DragHandler更新Translation有bug，在激活的时候拿不到正确的值，只有当translation改变的时候才能拿到正确的值
                // 所以第一次用来更新数据，不做实际移动。
                startX = translation.x;
                startY = translation.y;
                return;
            }
            // 计算出当前鼠标位置
            const mouseX = pivotX + translation.x - startX;
            const mouseY = pivotY + translation.y - startY;
            // 计算出当前鼠标位置和中心点的连线与X轴的夹角
            const curAngle = calculateAngle(width / 2, height / 2, mouseX, mouseY);
            // 计算夹角差值
            let deltaAngle = curAngle - lastAngle;
            if (deltaAngle == 0) {
                return;
            }
            // 上一步得到的夹角差值其实并非是增量，因为参与计算的curAngle和lastAngle都是各自相对于X轴的夹角
            // 所以这里就是计算出实际的增量应该是多少，就是计算出从上次的角度到这次的角度，应该怎么样变换过去
            // 实际的交互肯定要求是以较小的角度变换过去，例如如果计算出两次的差值是顺时针350度，那其实应该是逆时针10度
            const absDeltaAngle = Math.abs(deltaAngle);
            if (absDeltaAngle > 180) {
                const symbol = deltaAngle / absDeltaAngle;
                deltaAngle = (360 - absDeltaAngle) * -symbol;
            }
            rotate(deltaAngle);
            lastAngle = curAngle;
        }

        function calculateAngle(x1, y1, x2, y2) {
            // 计算两点之间的角度（弧度）
            const angleRadians = Math.atan2(y2 - y1, x2 - x1);
            // 将弧度转换为度数
            return angleRadians * (180 / Math.PI);
        }
    }

    // 对于Qt来说，滚轮的手势对于鼠标和触摸板(在触摸板上是双指拖动)是一样的，
    // 当 acceptedDevices 为 PointerDevice.Mouse 的时候，当前Handler只对鼠标响应
    // 当 acceptedDevices 为 PointerDevice.TouchPad 的时候，当前Handler并不能对触摸板响应
    // 当 acceptedDevices 为 PointerDevice.Mouse | PointerDevice.TouchPad 的时候，当前Handler同时对鼠标和触摸板响应
    // 也就是说，想响应触摸板的滚轮操作，需要同时设置 Mouse 和 TouchPad ，但是在接收到事件中，设备的type却始终为1，1为鼠标
    // 即在响应事件的时候，不能知道当前操作到底是来自鼠标还是来自触摸板，这种情况下，为了区分两种操作，声明了两个WheelHandler
    // 一个的 acceptedDevices 为 TouchPad | Mouse 用于响应触摸板操作，id为touchPadWheelHandler
    // 一个的 acceptedDevices 为 Mouse 只响应鼠标操作，id为mouseWheelHandler
    // 但是当手势是来自于鼠标的时候，两个都会做出响应，为了避免这种情况，所以在mouseWheelHandler active的时候，touchPadWheelHandler不做处理。
    // TODO: 有一个问题目前不知道解决方案，就是两指滑动的时候，如何知道手势什么时候开始，什么时候结束呢
    WheelHandler {
        id: touchPadWheelHandler
        acceptedDevices: PointerDevice.TouchPad | PointerDevice.Mouse
        onWheel: (event) => {
            if (mouseWheelHandler.active) {
                return;
            }
            // 播放器视角调整灵敏，跳过触摸板抬指后的惯性，只响应主动滑动。
            if (typeof globalEventFilter !== 'undefined' && globalEventFilter.isWheelInMomentum()) {
                return;
            }
            const deltaX = event.pixelDelta.x;
            const deltaY = event.pixelDelta.y;
            if (deltaX != 0 || deltaY != 0) {
                move(deltaX, deltaY, false);
            }
        }
    }

    // 临时措施，延迟下再结束手势，这么做其实不太好，但是目前是为了临时优化tk数据过多造成卡顿的问题
    Timer {
        id: mouseWheelActiveTimer
        interval: 200
        repeat: false
        onTriggered: {
            activedHandlerCount -= 1;
        }
    }

    // 之所以要根据twoFlingrRoll的真假来决定acceptedDevices的原因在touchPadWheelHandler的注释中说明了原因
    WheelHandler {
        id: mouseWheelHandler
        acceptedDevices: twoFingerRoll ? PointerDevice.Mouse : PointerDevice.Mouse | PointerDevice.TouchPad
        onActiveChanged: {
            if (active) {
                wheelGesturing = true;
                if (mouseWheelActiveTimer.running) {
                    mouseWheelActiveTimer.stop();
                } else {
                    activedHandlerCount += 1;
                }
            } else {
                wheelGesturing = false;
                mouseWheelActiveTimer.restart();
            }
            // zoom(0, !gesturing);
        }
        onWheel: (event) => {
            // 播放器视角调整灵敏，跳过触摸板抬指后的惯性，只响应主动滑动/滚轮。
            if (typeof globalEventFilter !== 'undefined' && globalEventFilter.isWheelInMomentum()) {
                return;
            }
            // 落点门控：滚轮/触摸板缩放只作用于透出的全景区，普通视频画面区不缩放被遮挡的全景。
            // 用 handler 的 point.position（父项坐标，与本文件其余落点判定一致），坐标系比 event.x/y 更可靠；
            // nx/ny 兜底校验，取不到有效落点时不门控（宁可放行也不误杀缩放）。
            let nx = width > 0 ? point.position.x / width : -1.0
            let ny = height > 0 ? point.position.y / height : -1.0
            if (hitTestPanorama && nx >= 0 && ny >= 0 && !hitTestPanorama(nx, ny)) {
                return;
            }
            // 这里要反着来，放大意味着fov要变小，这里除的系数只是控制缩放的快慢
            const angleY = event.angleDelta.y;
            mouseWheelActiveTimer.stop();
            zoom(-angleY / 360 / 8, !gesturing);
        }
    }

    // scale不要使用PinchHandler，有不能理解的bug
    // PinchArea也有点问题，问题在于scale和rotation不能同时响应
    PinchArea {
        id: pinchArea
        anchors.fill: parent

        // 起手捏合中心不在透出全景区时取消本次缩放（与滚轮/拖动落点门控一致）
        property bool cancelPinch: false

        onPinchStarted: (pinch) => {
            let nx = width > 0 ? pinch.startCenter.x / width : -1.0
            let ny = height > 0 ? pinch.startCenter.y / height : -1.0
            if (hitTestPanorama && nx >= 0 && ny >= 0 && !hitTestPanorama(nx, ny)) {
                cancelPinch = true;
                return;
            }
            cancelPinch = false;
            wheelGesturing = true;
            activedHandlerCount += 1;
            zoom(0, !gesturing);
        }
        onPinchFinished: (pinch) => {
            if (cancelPinch) {
                cancelPinch = false;
                return;
            }
            wheelGesturing = false;
            activedHandlerCount -= 1;
            zoom(0, !gesturing);
        }
        onPinchUpdated: (pinch) => {
            if (cancelPinch) {
                return;
            }
            // 这里的计算公式没有实际意义，就是一种计算幅度的方式，是调出来的
            zoom((pinch.previousScale / pinch.scale - 1) / 2, !gesturing);
        }
    }

    function flingStop() {
        flingHandler.stop();
    }

    // 按落点刷新悬停光标：命中可拖动全景→全景手型；命中普通视频/无全景→恢复系统光标。
    // 仅在“是否悬停全景”状态翻转时操作光标，避免 setCustomCursor 重复压栈。
    function refreshHoverCursor(nx, ny) {
        // 覆盖层（文字/仪表盘）区域不接管光标；按下/拖拽/滚轮手势期间由各自分支管理光标
        if (mouseOnOverlay || gestureMouseArea.anyButtonPressed || dragging || wheelGesturing) {
            return;
        }
        // hitTestPanorama 为空时退回到“整片区域按 isPanorama 处理”的旧行为
        let onPanorama = isPanorama && hoverHandler.hovered
                         && (!hitTestPanorama || hitTestPanorama(nx, ny));
        if (onPanorama === hoveringPanorama) {
            return;
        }
        hoveringPanorama = onPanorama;
        if (onPanorama) {
            cursorhelper.setCustomCursor(":/icons/panorama/enter_player_area.svg", 32, 32);
        } else {
            cursorhelper.restoreAllOverrideCursors();
        }
    }

    function resetGestureState() {
        dragging = false;
        gesturing = false;
        wheelGesturing = false;
        hoveringPanorama = false;
        gestureMouseArea.anyButtonPressed = false;
        gestureMouseArea.pressedButton = Qt.NoButton;
        cursorhelper.restoreAllOverrideCursors();
    }
}
