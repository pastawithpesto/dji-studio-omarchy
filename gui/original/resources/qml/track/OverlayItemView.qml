import QtQuick 2.15
import QtQuick.Controls
import Config 1.0
import CursorHelper 1.0
import QTractorType 1.0
import Controls 1.0
import app_qrc 1.0
import Nova 1.0

Item {
    id: root
    // nova: fragmentInfo 现为 TimelineTextClipViewModel（modelData），仅投影布局子集 + textTitle。
    required property var fragmentInfo

    // 选中框左右耳朵宽度
    property int selectedGripWidth: 2
    // 选中框上下线宽度
    property int selectedLineWidth: 1
    // 是否处于选中状态
    property bool selected: CommonUtils.isNull(fragmentInfo) ? false : fragmentInfo.selected
    // 是否正在拖拽
    property bool isDragging: false

    // 片段的可视区域长度，单位px
    property real trackLength: 1000
    // 轨道可见的最左边x坐标， 单位px，其实就是滚动的x轴距离
    property real visibleLeft: 0

    property real visibleRight: 0
    // 每个片段对应的时长，单位ms
    property real msPerFragment: 1

    // 每个片段对应的px长度， 给了个默认值16
    property double pxPerFragment: Instance.audio_wave_track_length
    // 每个片段对应的最小刻度的数量，比如最小刻度是100ms， 片段间隔是1s， 那这个数量就是10
    property int countForFragment: 0
    // 是否需要刷新
    property bool needRefresh: false
    // 请求数据的最小粒度，单位ms
    property int requestDataMiniScale: 1
    // 轨道缩放 px per frame
    property double pxPerFrame: 0
    // 帧率
    property int outputFps: 0
    //相邻两个片段中间的间隙， 片段整体宽度不变，填充内容时，左边留1像素，右边留1像素
    property real itemGap: 1

    property int trackIndex: -1
    property int clipIndex: -1

    property int  oneFrameToTimes : 1000
    property real trackVisibleLeft: 0
    property real trackVisibleRight: 0
    property int scrollClipArea : 30
    // 左右裁切控件默认触发区域宽度
    property int clipAreaWidth : 5

    // 保存上一步裁切的结果, 用于执行撤销，恢复操作
    property int lastTrackFreamIn: 0
    property int lastFreamIn: 0
    property int lastLength: 0

    // 原始的片段长度
    property int originFragmentLength : 0

    //property real isClipping: leftClipDragArea.isStartclip || rightClipDragArea.isStartclip

    property bool isMouseMoved: false // 鼠标位置是否发生移动
    property bool isSnapped: false // 是否吸附成功
    property real snappingPos: -1 // 吸附位置

    property bool mediaLost: CommonUtils.isNull(fragmentInfo) || !fragmentInfo.mediaSourceExists;

    // 信号: 开始裁切
    signal startClip()
    // 信号:剪切结束
    signal fragmentChange(bool isLeftClip, bool isScroll, bool isClipping)
    // 信号： 是否开启滚动裁切
    signal scrollClip(bool isScroll, bool isLeftClip, bool isScrollToLeft)
    // 信号: 查看当前位置是否可以吸附
    signal getSnappingPosSig(real pos)
    // 点击
    signal itemClicked(bool isRightButton)
    // 片段拖拽 移动
    signal itemDragMove(point point, bool isFirst)
    // 片段拖拽 结束
    signal itemDragRelease(point point, bool isCancel)
    // 信号： 右键打开片段操作弹窗
    signal openOperatorPop(real windowPointX, real windowPointY, bool isMediaLost, bool isSelectFile);

    width: fragment.displayLength
    z: isDragging ? 100 : 0

    CursorHelper {
        id: cursorhelper
    }

    Item {
        id: fragment

        // 文本无源范围，视觉长度取时间线区间(trackFrameOut-trackFrameIn)；裁切改 trackFrame* 即时反馈。
        property real totalTimebase: CommonUtils.isNull(fragmentInfo) ? 0 : (fragmentInfo.trackFrameOut - fragmentInfo.trackFrameIn)
        property real displayFrames: totalTimebase / 30000.0 * outputFps
        property real displayLength: displayFrames * pxPerFrame
        property color borderColor: Colors.color_EEEEEE
        property int rectRadius: RadiusConfig.radius_4_8
    }
    // 点击片段选中
    MouseArea {
        anchors.fill: parent
        // 是否是拖拽中
        property bool isSortDragging: false
        property bool isRightButton: false
        // 拖拽阈值相关
        property real dragThreshold: 3           // 拖拽像素阈值
        property real dragTimeSlop: 150          // 拖拽时间阈值（毫秒）
        property real dragStartX: 0              // 拖拽开始的X坐标
        property real dragStartY: 0              // 拖拽开始的Y坐标
        property double dragStartTime: 0         // 拖拽开始时间
        property bool hasDragExceededThreshold: false  // 是否超出阈值
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: (mouse) => {
            // 先不认为是拖拽, 如果位置变化就是拖拽
            if (mouse.button === Qt.LeftButton){
                isSortDragging = false;
                isRightButton = false;
                // 初始化拖拽阈值检查
                dragStartX = mouse.x
                dragStartY = mouse.y
                dragStartTime = new Date().getTime()
                hasDragExceededThreshold = false
            } else if (mouse.button === Qt.RightButton){
                isSortDragging = false;
                isRightButton = true;
            }
        }
        onReleased: (mouse) => {
            if (mouse.button === Qt.RightButton && !isSortDragging) {
                // 先选中
                itemClicked(true);
                let windowPoint = mapToItem(lightWindow.contentItem, mouse.x, mouse.y);
                let isMediaLost = root.mediaLost;
                let isSelectFile = (multiTrackDataProvider.getSelectedCount() > 0);
                root.openOperatorPop(windowPoint.x, windowPoint.y, isMediaLost, isSelectFile);
            } else {
                isRightButton = false;
                root.isDragging = false;
                itemDragRelease(Qt.point(mouseX, mouseY), false);
            }
        }
        onCanceled: {
            root.isDragging = false;
            itemDragRelease(Qt.point(mouseX, mouseY), true);
        }
        onPositionChanged: {
            if(isRightButton){
                isSortDragging = true;
                return;
            }

            // 检查是否超出拖拽像素阈值
            if (!hasDragExceededThreshold) {
                var pixelXMoved = Math.abs(mouseX - dragStartX)
                var pixelYMoved = Math.abs(mouseY - dragStartY)

                if (pixelXMoved > dragThreshold || pixelYMoved > dragThreshold) {
                    hasDragExceededThreshold = true
                } else {
                    return  // 未超出阈值，不响应拖拽
                }
            }

            // 鼠标按下并改变了位置就响应为拖拽（参照 AudioItemView）：首帧选中 + 发拖拽起手，后续发移动。
            if (!isSortDragging) {
                isSortDragging = true;
                root.isDragging = true;
                // 先选中
                itemClicked(false);
                itemDragMove(Qt.point(dragStartX, dragStartY), true);
            } else {
                itemDragMove(Qt.point(mouseX, mouseY), false);
            }
        }

        onClicked: (mouse) => {
            // 如果已经响应了拖拽就不再响应点击
            if (isSortDragging) {
                return;
            }
            itemClicked(mouse.button === Qt.RightButton);
        }
    }

    Rectangle {
        id: itemRectangle
        anchors {
            left: parent.left
            top: parent.top
            bottom: parent.bottom
        }
        width: parent.width - itemGap
        color: mediaLost ? ColorsConfig.color_brand : ColorsConfig.color_0A9B83_transparent
        radius: fragment.rectRadius
        clip: true
        z: 1
        // 文本名称
        Rectangle {
            id: textNameRect
            anchors {
                left: parent.left
                leftMargin: 4
                top: parent.top
                topMargin: 3
            }
            color: Colors.color_transparent
            height: 14
            width: Math.max(Math.min(parent.width - 8, 40), fontMetrics.advanceWidth(textNameRectText.text) + 8)
            Text {
                id: textNameRectText
                anchors.fill: parent
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignLeft
                font.pixelSize: 10
                color: mediaLost ? ColorsConfig.color_EEEEEE_000000 :ColorsConfig.color_95FCEB_95FCEB
                // nova: 文本名取 VM textTitle（NOTIFY clipChanged 自动刷新），替换换行/回车为空格
                text: CommonUtils.isNull(fragmentInfo) ? "" : (fragmentInfo.textTitle || "").replace(/[\n\r]+/g, ' ')
            }
            // 用于获取文本名称的宽度
            FontMetrics {
                id: fontMetrics
                font: textNameRectText.font
            }
        }

        Rectangle {
            id: lostUI
            anchors {
                top: textNameRect.bottom
                bottom: parent.bottom
                left: parent.left
                right: parent.right
                topMargin: 4
            }
            color: ColorsConfig.color_492C2D_15473C
            visible: mediaLost
            radius: fragment.rectRadius

            // 补个两个角的缺，如果将lostUI改成LightRectangle，当尺寸过长的时候，会出现绘制问题
            Rectangle {
                anchors {
                    top: lostUI.top
                    left: lostUI.left
                }
                width: fragment.rectRadius
                height: fragment.rectRadius
                color: ColorsConfig.color_492C2D_15473C
            }

            Rectangle {
                anchors {
                    top: lostUI.top
                    right: lostUI.right
                }
                width: fragment.rectRadius
                height: fragment.rectRadius
                color: ColorsConfig.color_492C2D_15473C
            }

            Column {
                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }

                Text {
                    anchors {
                        left: parent.left
                        right: parent.right
                    }
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: 10
                    color: ColorsConfig.color_brand
                    // 这里不要翻译
                    text: "文本丢失"
                }

                Text {
                    anchors {
                        left: parent.left
                        right: parent.right
                    }
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: 10
                    color: ColorsConfig.color_brand
                    // 这里不要翻译
                    text: "Text Not Found"
                }
            }
        }

        // 选中框
        Rectangle {
            visible: selected
            width: itemRectangle.width
            height: itemRectangle.height
            color: Colors.transparent
            radius: fragment.rectRadius
            border.width: selectedGripWidth
            border.color: fragment.borderColor
        }

        MouseArea{
            id:leftClipDragArea
            // nova: 文本裁切落 nle(仅改时间线 time_range，无源范围)。
            property real lastMousePosX: 0
            property real delPosX: 0
            property bool isStartclip: false
            property bool isScrollClipping: false
            property bool isGroupClip: false  // 本次拖拽是否为多选整组裁切

            hoverEnabled:true
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            height: parent.height
            width: clipAreaWidth
            onReleased: {
                finishDrag();
            }

            onCanceled: {
                finishDrag();
            }

            function finishDrag() {
                if (!isStartclip) return;
                isStartclip = false;
                if(isScrollClipping){
                    isScrollClipping = false;
                    scrollClip(false, true, false);
                }
                delPosX = 0;
                lastMousePosX = 0;
                if(!leftClipDragArea.containsMouse){
                    cursorhelper.restoreOverrideCursor();
                }
                var clipPosition = fragmentInfo.trackFrameIn
                fragmentChange(true, false, false)
                root.addClipAction()
                root.updateLastResult()
                ShortcutObserver.disableAllShortcut(false);
                root.isSnapped = false;
                root.snappingPos = -1;
                // nova: 文本裁切松手把时间线 time_range 提交到 nle，并刷新预览。
                if(leftClipDragArea.isGroupClip){
                    // nova: 多选整组裁切一次事务提交(单步 undo,含 base)，内部按涉及类型回读并请重排。
                    TimelineEditController.commitGroupTrim();
                    leftClipDragArea.isGroupClip = false;
                } else {
                    fragmentInfo.commitTrim();
                }
                fragmentChange(true, false, false);  // isClipping=false：收尾重排+复位裁切态
                editorManager.refreshPlayer();
                delPosX = 0
                editorManager.sendTrackEventForDragCLip(root.trackIndex, root.clipIndex, clipPosition, true, "overlay", 3)
            }
            onEntered: {
                if(!isStartclip){
                    if(rightClipDragArea.containsMouse){
                        cursorhelper.restoreOverrideCursor()
                    }
                    cursorhelper.setCustomCursor(":/icons/ic_cutleft.svg", 24, 24)
                }
            }
            onExited: {
                if(!isStartclip){
                    cursorhelper.restoreOverrideCursor()
                }
                ShortcutObserver.disableAllShortcut(false);
            }

            onPressed: {
                // 未选中片段边缘按下：先独占选中再进入裁切，selectedClipCount 随之归 1，不会误开整组裁切
                if (!root.selected) {
                    root.itemClicked(false);
                }
                lastMousePosX = mouseX;
                delPosX = 0;
                isStartclip = true;
                leftClipDragArea.isGroupClip = TimelineEditController.selectedClipCount() > 1;  // 多选则整组裁切
                if(leftClipDragArea.isGroupClip){
                    TimelineEditController.beginGroupTrim(fragmentInfo.clipNodeId, true);
                }
                startClip();
                ShortcutObserver.disableAllShortcut(true);
            }
            onPositionChanged: {
                if(!isStartclip)
                    return;
                root.isMouseMoved = true;
                // nova: 文本裁头——按像素 delta 取整帧，只改时间线起点 trackFrameIn(最短 1 帧)，不碰源范围。
                // delPosX 累加补偿:item 随裁切移动后左缘(本 MouseArea 锚 parent.left)也偏移，需带入上次余量。
                // 注意：不要再 delPosX -= deltaFullFrame*pxPerFrame——边缘移动已使下次 mouseX 自动回落消费掉该量，
                // 再减一次会双重消费导致正负来回震荡(不跟手)。与 AudioItemView 同口径。
                delPosX = mouseX - lastMousePosX + delPosX;
                lastMousePosX = mouseX;
                var deltaFullFrame = Math.round(delPosX / pxPerFrame);
                // 吸附: 命中则用"贴到吸附点"所需的帧位移替换原始位移；须在整组钳制之前
                // 滚动裁切期间不吸附，否则吸附线会跟着自动滚动乱跳
                if(!isScrollClipping){
                    var adjustDeltaFullFrame = root.adjustClipPosBySnapping(leftClipDragArea.delPosX, fragmentInfo.trackFrameIn);
                    if(root.isSnapped){
                        deltaFullFrame = adjustDeltaFullFrame;
                    }
                }
                // 滚动裁切: 片段头被拖到轨道右边缘(裁短)或左边缘(拉长)时，交由 overlayScrollClipTimer 边滚边裁。
                // 探针取"当前左缘 + 未消费像素位移"，即鼠标所在的时间线位置。
                var probeLeftPx = fragmentInfo.trackFrameIn / oneFrameToTimes * pxPerFrame + delPosX;
                if(trackVisibleRight - probeLeftPx <= scrollClipArea){  // 鼠标进入轨道右侧滚动裁切触发区域
                    if(fragmentInfo.trackFrameOut / oneFrameToTimes * pxPerFrame > trackVisibleRight){  // 片段尾部在可视区域外才需要滚动
                        if(!isScrollClipping){
                            isScrollClipping = true;
                            scrollClip(true, true, true);
                        }
                    }
                    return;
                }else if(probeLeftPx < trackVisibleLeft){  // 鼠标进入轨道左侧滚动恢复触发区域
                    if(trackVisibleLeft > 0 && fragmentInfo.trackFrameIn > 0){  // 轨道头未到原点且片段还能向左拉长
                        if(!isScrollClipping){
                            isScrollClipping = true;
                            scrollClip(true, true, false);
                        }
                        return;
                    }
                }
                if(isScrollClipping){  // 回到非触发区域，停止滚动裁切
                    isScrollClipping = false;
                    scrollClip(false, true, false);
                }
                if (deltaFullFrame === 0)
                    return;
                // 多选整组裁切: 钳制到所有选中片段都可行的帧数(锁步, 以最受限为准)
                if(leftClipDragArea.isGroupClip){
                    deltaFullFrame = TimelineEditController.clampGroupTrimDelta(deltaFullFrame);
                    if (deltaFullFrame === 0)
                        return;
                }
                var oldTrackIn = fragmentInfo.trackFrameIn;
                var newTrackIn = oldTrackIn + deltaFullFrame * oneFrameToTimes;
                if (newTrackIn < 0)
                    newTrackIn = 0;
                if (fragmentInfo.trackFrameOut - newTrackIn < oneFrameToTimes)
                    newTrackIn = fragmentInfo.trackFrameOut - oneFrameToTimes;  // 最短 1 帧
                fragmentInfo.trackFrameIn = newTrackIn;  // setTrackFrameIn→clipChanged 本地预览
                // nova: 几何与邻居钳制交由 C++ relayoutTrimPreview(单一数据源)——按 VM 预览值重排 item，
                // 并钳制左缘不越过相邻文字片段；不再在 QML 命令式 setX/setWidth(那样不跟手且不防重叠)。
                fragmentChange(true, false, true);  // 同步触发 relayoutTrimPreview，可能再钳制 VM
                // 多选整组裁切: 将相同帧位移施加到其余选中片段
                if(leftClipDragArea.isGroupClip && deltaFullFrame !== 0){
                    TimelineEditController.applyGroupTrimToOthers(deltaFullFrame);
                }
                // 不在此扣减 delPosX：生效部分由左缘(锚 parent.left)移动后下次 mouseX 自动回落消费；
                // 未生效部分(顶到左邻被钳，边缘没动)保留为"越界余量"，反向回拽时需先抵消它、光标走回真实
                // 边缘后边缘才回退(死区)，避免顶到邻片后一往右立刻回缩并带动邻片。
            }
        }

        MouseArea{
            id:rightClipDragArea
            // nova: 文本裁切落 nle(仅改时间线 time_range，无源范围)。
            property real lastMousePosX: 0
            property real delPosX: 0
            property bool isStartclip: false
            property bool isScrollClipping: false
            property bool isGroupClip: false  // 本次拖拽是否为多选整组裁切
            hoverEnabled:true
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            height: parent.height
            width: clipAreaWidth

            onEntered: {
                if(!isStartclip){
                    if(leftClipDragArea.containsMouse){
                        cursorhelper.restoreOverrideCursor()
                    }
                    cursorhelper.setCustomCursor(":/icons/ic_cutright.svg", 24, 24)
                }
            }

            onExited: {
                if(!isStartclip){
                    cursorhelper.restoreOverrideCursor()
                }
                ShortcutObserver.disableAllShortcut(false);
            }

            onPressed: {
                // 未选中片段边缘按下：先独占选中再进入裁切，selectedClipCount 随之归 1，不会误开整组裁切
                if (!root.selected) {
                    root.itemClicked(false);
                }
                lastMousePosX = mouseX; // 初始化位置
                isStartclip = true;
                delPosX = 0;
                rightClipDragArea.isGroupClip = TimelineEditController.selectedClipCount() > 1;  // 多选则整组裁切
                if(rightClipDragArea.isGroupClip){
                    TimelineEditController.beginGroupTrim(fragmentInfo.clipNodeId, false);
                }
                startClip();
                root.updateLastResult()
                ShortcutObserver.disableAllShortcut(true)
            }
            onReleased: {
                finishDrag();
            }

            onCanceled: {
                finishDrag();
            }

            function finishDrag() {
                delPosX = 0;
                lastMousePosX = 0
                if(isScrollClipping){
                    isScrollClipping = false
                    scrollClip(false, false, false)
                }
                isStartclip = false
                if(!rightClipDragArea.containsMouse){
                    cursorhelper.restoreOverrideCursor()
                }

                ShortcutObserver.disableAllShortcut(false)
                fragmentChange(false, false, false);
                root.isSnapped = false;
                root.snappingPos = -1;
                // nova: 文本裁切松手把时间线 time_range 提交到 nle，并刷新预览。
                if(rightClipDragArea.isGroupClip){
                    // nova: 多选整组裁切一次事务提交(单步 undo,含 base)，内部按涉及类型回读并请重排。
                    TimelineEditController.commitGroupTrim();
                    rightClipDragArea.isGroupClip = false;
                } else {
                    fragmentInfo.commitTrim();
                }
                editorManager.refreshPlayer();
                editorManager.sendTrackEventForDragCLip(root.trackIndex, root.clipIndex, fragmentInfo.trackFrameOut, false, "overlay", 3)
            }

            onPositionChanged: {
                if(!isStartclip)
                    return;
                root.isMouseMoved = true;
                // nova: 文本裁尾——按像素 delta 取整帧，只改时间线终点 trackFrameOut(最短 1 帧)，不碰源范围。
                // 不要 delPosX -= deltaFullFrame*pxPerFrame：右缘(本 MouseArea 锚 parent.right)随裁切移动后，
                // 下次 mouseX 会自动回落消费该量，再减一次会双重消费导致来回震荡(不跟手)。与 AudioItemView 同口径。
                delPosX = mouseX - lastMousePosX + delPosX;
                lastMousePosX = mouseX;
                var deltaFullFrame = Math.round(delPosX / pxPerFrame);
                // 吸附: 命中则用"贴到吸附点"所需的帧位移替换原始位移；须在整组钳制之前
                // 滚动裁切期间不吸附，否则吸附线会跟着自动滚动乱跳
                if(!isScrollClipping){
                    var adjustDeltaFullFrame = root.adjustClipPosBySnapping(rightClipDragArea.delPosX, fragmentInfo.trackFrameOut);
                    if(root.isSnapped){
                        deltaFullFrame = adjustDeltaFullFrame;
                    }
                }
                // 滚动裁切: 片段尾被拖到轨道左边缘(裁短)或右边缘(拉长)时，交由 overlayScrollClipTimer 边滚边裁。
                // 探针取"当前右缘 + 未消费像素位移"，即鼠标所在的时间线位置。
                var probeRightPx = fragmentInfo.trackFrameOut / oneFrameToTimes * pxPerFrame + delPosX;
                if(probeRightPx - trackVisibleLeft <= scrollClipArea){  // 鼠标进入轨道左侧滚动裁切触发区域
                    if(fragmentInfo.trackFrameIn / oneFrameToTimes * pxPerFrame < trackVisibleLeft){  // 片段头部在可视区域外才需要滚动
                        if(!isScrollClipping){
                            isScrollClipping = true;
                            scrollClip(true, false, false);
                        }
                        return;
                    }
                }else if(probeRightPx >= trackVisibleRight){  // 鼠标进入轨道右侧滚动恢复触发区域
                    if(!isScrollClipping){
                        isScrollClipping = true;
                        scrollClip(true, false, true);
                    }
                    return;
                }
                if(isScrollClipping){  // 回到非触发区域，停止滚动裁切
                    isScrollClipping = false;
                    scrollClip(false, false, false);
                }
                if (deltaFullFrame === 0)
                    return;
                // 多选整组裁切: 钳制到所有选中片段都可行的帧数(锁步, 以最受限为准)
                if(rightClipDragArea.isGroupClip){
                    deltaFullFrame = TimelineEditController.clampGroupTrimDelta(deltaFullFrame);
                    if (deltaFullFrame === 0)
                        return;
                }
                var oldTrackOut = fragmentInfo.trackFrameOut;
                var newTrackOut = oldTrackOut + deltaFullFrame * oneFrameToTimes;
                if (newTrackOut - fragmentInfo.trackFrameIn < oneFrameToTimes - 1)
                    newTrackOut = fragmentInfo.trackFrameIn + oneFrameToTimes - 1;  // 最短 1 帧
                fragmentInfo.trackFrameOut = newTrackOut;  // setTrackFrameOut→clipChanged 本地预览
                // nova: 几何与邻居钳制交由 C++ relayoutTrimPreview(单一数据源)——按 VM 预览值重排 item，
                // 并钳制右缘不越过相邻文字片段；不再在 QML 命令式 setWidth(那样不跟手且不防重叠)。
                fragmentChange(false, false, true);  // 同步触发 relayoutTrimPreview，可能再钳制 VM
                // 多选整组裁切: 将相同帧位移施加到其余选中片段
                if(rightClipDragArea.isGroupClip && deltaFullFrame !== 0){
                    TimelineEditController.applyGroupTrimToOthers(deltaFullFrame);
                }
            }
        }
    }

    // 特效、滤镜等向轨道拖拽时的蒙层样
    TrackItemCover {
        anchors.fill: itemRectangle
        fragmentInfo: root.fragmentInfo
        rectRadius: fragment.rectRadius
    }

    Component.onCompleted: {
        if (CommonUtils.isNull(fragmentInfo)) {
            return;
        }
        // nova: 文本名走声明式绑定（见 textNameRectText.text），此处不再命令式赋值以免破坏绑定。
        originFragmentLength = fragmentInfo.length;
    }

    Component.onDestruction: {
        cursorhelper.restoreOverrideCursor();
    }

    onVisibleLeftChanged: {
        setTrackLength(visibleRight - visibleLeft);
    }

    onVisibleRightChanged: {
        setTrackLength(visibleRight - visibleLeft);
    }

    // 滚动裁切每 tick 回调: 面板已滚动，把片段头贴到 fixPos(轨道内容坐标 px)。
    // 文本无源范围，只改时间线起点 trackFrameIn；到达最短 1 帧/轨道头/相邻片段边界即停滚。
    function leftScrollClipUpdate(fixPos, isScrollToLeft){
        var newTrackFrameIn = Math.round(fixPos / pxPerFrame) * oneFrameToTimes;
        var isStopScroll = false;
        // fixPos 取自 visibleRect.x(恒 >=0)，滚到轨道原点后本值会稳在 0 而不再变化，
        // 只靠"被钳回"判不出到底，必须在此显式停滚，否则会继续向左滚出轨道原点。
        if(newTrackFrameIn <= 0){
            newTrackFrameIn = 0;
            isStopScroll = true;
        }
        if(fragmentInfo.trackFrameOut - newTrackFrameIn < oneFrameToTimes){
            newTrackFrameIn = fragmentInfo.trackFrameOut - oneFrameToTimes;  // 最短 1 帧
            isStopScroll = true;
        }
        fragmentInfo.trackFrameIn = newTrackFrameIn;
        fragmentChange(true, true, true);  // 同步触发 relayoutPreview: 重排 + 相邻文字片段钳制
        if(fragmentInfo.trackFrameIn !== newTrackFrameIn){  // 被 C++ 钳回 => 已顶到相邻片段
            isStopScroll = true;
        }
        if(isStopScroll){
            leftClipDragArea.isScrollClipping = false;
            scrollClip(false, true, isScrollToLeft);
        }
    }

    // 滚动裁切每 tick 回调: 面板已滚动，把片段尾贴到 fixPos(轨道内容坐标 px)。
    // 文本无源范围，只改时间线终点 trackFrameOut；到达最短 1 帧/相邻片段/时间线上限即停滚。
    function rightScrollClipUpdate(fixPos, isScrollToLeft){
        var newTrackFrameOut = Math.round(fixPos / pxPerFrame) * oneFrameToTimes;
        var isStopScroll = false;
        if(newTrackFrameOut - fragmentInfo.trackFrameIn < oneFrameToTimes){
            newTrackFrameOut = fragmentInfo.trackFrameIn + oneFrameToTimes;  // 最短 1 帧
            isStopScroll = true;
        }
        fragmentInfo.trackFrameOut = newTrackFrameOut;
        fragmentChange(false, true, true);  // 同步触发 relayoutPreview: 重排 + 相邻片段/时间线上限钳制
        if(fragmentInfo.trackFrameOut !== newTrackFrameOut){  // 被 C++ 钳回 => 已顶到相邻片段或时间线上限
            isStopScroll = true;
        }
        if(isStopScroll){
            rightClipDragArea.isScrollClipping = false;
            scrollClip(false, false, isScrollToLeft);
        }
    }

    // 裁切吸附: 用"当前边缘 + 未消费像素位移"作为探针查吸附点，命中则返回贴到吸附点所需的整帧位移
    // deltaX: 本次未消费的像素位移; targetPos: 被裁边缘当前时间线位置(mk)
    function adjustClipPosBySnapping(deltaX, targetPos){
        var deltaFullFrame = 0;
        let isSnappedSuc = false;
        let tempPos = targetPos + deltaX / pxPerFrame * oneFrameToTimes;
        getSnappingPosSig(tempPos);

        if(root.snappingPos !== -1){
            deltaFullFrame = Math.floor((root.snappingPos - targetPos) / oneFrameToTimes);
            isSnappedSuc = true;
        }
        root.isSnapped = isSnappedSuc;
        return deltaFullFrame;
    }

    // 保存最近一次裁切之后的结果
    function updateLastResult(){
        var delta = fragmentInfo.length - Math.floor(fragmentInfo.length / oneFrameToTimes) * oneFrameToTimes; // 尾部不足一帧的长度，主要是滚动裁切时尾部生成的, 解决滚动裁切后片段尾部可能出现半帧的问题
        fragmentInfo.frameOut -= delta;

        root.lastTrackFreamIn = fragmentInfo.trackFrameIn;
        root.lastFreamIn = fragmentInfo.frameIn;
        root.lastLength = fragmentInfo.length;
    }

    // 将此次裁切操作添加进撤销堆栈中
    function addClipAction(){
    }
}
