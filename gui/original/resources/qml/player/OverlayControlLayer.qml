import QtQuick 2.15
import QtQuick.Controls

import Config 1.0
import Controls 1.0
import Nova 1.0

/**
 * @brief 文字片段控制器
 * @details 负责文字片段的控制，包括文字的位置、缩放、选中和旋转等
 * @author zhongshan.wang
 * @date 2025-12-2
 */

Item {
    id: controlRoot
    clip: true

    property int baseHeight: 720
    property int textMargin: 20
    // 字号缩放比，基于view高度与底层标准值
    property real viewScale: height / baseHeight
    // 边框缩放比，基于view高度和分辨率高度
    property real profileScale: height / originSize.height

    readonly property real minScale: 0.01
    readonly property real maxScale: 10
    // 鼠标是否悬停在文字item上
    property bool mouseOnItem: false
    //右键穿透了，只记录左键
    property bool overlayPressed: false
    // 全屏闸门：全屏时隐藏文字选中框，但不破坏 visible 与 hasSelected 的绑定
    property bool overlaySelectionVisible: true

    onEnabledChanged: {
        if (!enabled) {
            mouseOnItem = false
        }
    }
    readonly property int baseMaxLength: 4320
    property int baseMaxWidth: {
        if(originSize.width >= originSize.height){
            return baseMaxLength*originSize.width/originSize.height
        }else{
            return baseMaxLength
        }
    }
    property int baseMaxHeight: {
        if(originSize.width >= originSize.height){
            return baseMaxLength
        }else{
            return baseMaxLength*originSize.height/originSize.width
        }
    }

    onWidthChanged: {
        updateOverlayContainerRect()
    }
    onHeightChanged: {
        updateOverlayContainerRect()
    }

    function updateOverlayContainerRect(){
        overlayContainerRect.x = overlayTextLayerViewModel.textRect.x*controlRoot.profileScale -10
        overlayContainerRect.y = overlayTextLayerViewModel.textRect.y*controlRoot.profileScale -10
        overlayContainerRect.width = overlayTextLayerViewModel.textRect.width*controlRoot.profileScale + 20
        overlayContainerRect.height = overlayTextLayerViewModel.textRect.height*controlRoot.profileScale + 20
    }

    TextDragController{
        id: overlayTextLayerViewModel
        originSize: controlRoot.originSize

        onTextRectChanged: {
            controlRoot.updateOverlayContainerRect()
        }
    }
    function transformAlignFromModel(align){
        switch (align) {
        case 0:
            return Text.AlignLeft
        case 1:
            return Text.AlignHCenter
        case 2:
            return Text.AlignRight
        default:
            return Text.AlignHCenter
        }
    }

    function transformAlignToModel(align){
        switch (align) {
        case Text.AlignLeft:
            return 0
        case Text.AlignHCenter:
            return 1
        case Text.AlignRight:
            return 2
        default:
            return 1
        }
    }

    function currentTextEditor(){
        if (overlayLoader.item) {
            // 遍历子元素查找textEditor
            for (var i = 0; i < overlayLoader.item.children.length; i++) {
                var child = overlayLoader.item.children[i];
                if (child.objectName === "textEditor") {
                    return child;
                }
            }
        }
        return null;
    }

    function toggleOverlaySelection(visible){
        overlaySelectionVisible = visible
    }

    // 汇总边框、旋转按钮、四个角锚点的悬停状态
    function updateMouseOnItem(){
        mouseOnItem = containerHover.hovered
                || rotateHover.hovered
                || topLeftAnchor.hovered
                || topRightAnchor.hovered
                || bottomLeftAnchor.hovered
                || bottomRightAnchor.hovered
    }

    property size originSize: {
        // 没有任何片段时，宽高可能为空，默认1920*1080
        if(width == 0 || height == 0){
            return Qt.size(1920, 1080)
        }
        // 定义标准宽高比和对应的尺寸
        const standardFormats = [
            { ratio: 16/9, size: Qt.size(1920, 1080) },  // 16:9
            { ratio: 9/16, size: Qt.size(1080, 1920) },  // 9:16
            { ratio: 4/3, size: Qt.size(1440, 1080) },   // 4:3
            { ratio: 3/4, size: Qt.size(1080, 1440) },   // 3:4
            { ratio: 1/1, size: Qt.size(1080, 1080) }     // 1:1
        ];

        const currentRatio = width / height;
        const tolerance = 0.01; // 宽高比容差

        // 查找匹配的标准格式
        for (let format of standardFormats) {
            if (Math.abs(currentRatio - format.ratio) < tolerance) {
                return format.size;
            }
        }

        // 没有匹配的标准格式，返回当前尺寸
        return Qt.size(width, height);
    }

    onOriginSizeChanged: {
        overlayTextLayerViewModel.originSize = originSize;
    }

    // 主点击区域
    MouseArea {
        id: mainClickArea
        anchors.fill: parent
        propagateComposedEvents: true
        property bool isClickedText: false
        property bool isMoved: false

        onPressed: function(mouseEvent) {
            let p = Qt.point(mouseX / controlRoot.profileScale , mouseY / controlRoot.profileScale)
            isClickedText = overlayTextLayerViewModel.pressOverlay(p)
            // 按到文字时 accept 事件以抓取 grab：原地点击(不移动)将在 release 中提交选中。
            // 但本 MouseArea 不设置 preventStealing，一旦发生拖动，下层全景 DragHandler 会夺取 grab；
            // 这里同步点亮 overlayPressed，使 DragHandler 的守卫放行(见 PlayerViewGesture)，从而调整视角。
            mouseEvent.accepted = isClickedText
            controlRoot.overlayPressed = isClickedText
        }
        onPositionChanged: function(mouseEvent){
            if(!isMoved){
                isMoved = true
            }
        }
        onReleased: function(mouseEvent){
            mouseEvent.accepted = false
            if(isClickedText && !isMoved){
                overlayTextLayerViewModel.releaseOverlay()
            }
            // 原地点击(未被夺取 grab)：在此清掉按下标记；
            // 若发生拖动，grab 会被 DragHandler 夺走并触发 onCanceled，overlayPressed 由全景拖拽结束时复位。
            controlRoot.overlayPressed = false
            isClickedText = false
            isMoved = false
        }
        onCanceled: function(){
            // grab 被全景 DragHandler 夺取，转为视角拖拽，不提交选中。
            // overlayPressed 保持 true，待全景拖拽结束(PanoramaPlayerView.onDraggingChanged)复位。
            isClickedText = false
            isMoved = false
        }
    }


    Rectangle{
        id: overlayContainerRect
        color: "transparent"
        rotation: overlayTextLayerViewModel.rotate
        border.color: Colors.color_EEEEEE
        border.width: 1.5
        antialiasing: true
        visible: overlayTextLayerViewModel.hasSelected && controlRoot.overlaySelectionVisible

        HoverHandler {
            id: containerHover
            onHoveredChanged: controlRoot.updateMouseOnItem()
        }
        MouseArea {
            id: textClickArea
            anchors.fill: parent

            property point lastDragtPos
            property bool isDragging: false
            property bool moved: false      // 需要判断是否有位移
            property point lastGlobalCenter: Qt.point(0,0)
            property point pendingPos: Qt.point(0, 0)
            property bool hasPendingUpdate: false
            preventStealing: true

            Timer {
                id: dragThrottleTimer
                interval: 33  // ~30 FPS (1000/30 ≈ 33ms)
                repeat: false
                onTriggered: {
                    if (textClickArea.hasPendingUpdate && textClickArea.isDragging) {
                        textClickArea._processDragUpdate(textClickArea.pendingPos)
                        textClickArea.hasPendingUpdate = false
                    }
                }
            }

            function _processDragUpdate(currentPos) {
                var deltaX = currentPos.x - lastDragtPos.x
                var deltaY = currentPos.y - lastDragtPos.y
                moved = true
                var newGlobalCenter = Qt.point(lastGlobalCenter.x + deltaX,
                                        lastGlobalCenter.y + deltaY)
                var p = Qt.point(newGlobalCenter.x / controlRoot.width - 0.5, 0.5 - newGlobalCenter.y / controlRoot.height)
                if(Math.abs(p.x*originSize.width) > baseMaxWidth ){
                    p.x = baseMaxWidth*1.0/originSize.width * Math.sign(p.x)
                }
                if( Math.abs(p.y*originSize.height) > baseMaxHeight){
                    p.y = baseMaxHeight*1.0/originSize.height * Math.sign(p.y)
                }
                newGlobalCenter = Qt.point((p.x + 0.5) * controlRoot.width, (0.5 - p.y) * controlRoot.height)
                let moveOffset = Qt.point(newGlobalCenter.x - lastGlobalCenter.x, newGlobalCenter.y - lastGlobalCenter.y)
                p.x = moveOffset.x/controlRoot.width
                p.y = -moveOffset.y/controlRoot.height
                overlayTextLayerViewModel.setTranslate(p)
            }

            onPressed: (mouseEvent) =>{
                lastDragtPos = mapToItem(controlRoot, mouseX, mouseY)
                isDragging = true
                mouseEvent.accepted = true
                overlayPressed = true
                lastGlobalCenter = Qt.point(overlayContainerRect.x + overlayContainerRect.width/2.0, 
                                            overlayContainerRect.y + overlayContainerRect.height/2.0)
                overlayTextLayerViewModel.setStartOperate()
                console.log("press text editor ", lastDragtPos, lastGlobalCenter)
            }

            onPositionChanged: {
                if (isDragging) {
                    var currentPos = mapToItem(controlRoot, mouseX, mouseY)
                    pendingPos = currentPos
                    hasPendingUpdate = true
                    if (!dragThrottleTimer.running) {
                        dragThrottleTimer.start()
                    }
                }
            }

            onReleased: (mouseEvent) =>{
                isDragging = false
                overlayPressed = false
                if(moved){
                    overlayTextLayerViewModel.addUndoAction()
                    //overlayTextLayerViewModel.addUndoAction("translate", startPoint, overlayTextLayerViewModel.translate)
                }
                moved = false;
                mouseEvent.accepted = true
                overlayTextLayerViewModel.setEndOperate()
            }
            onCanceled: {
                overlayTextLayerViewModel.setEndOperate()
            }
        }

        property bool isRotating: false
        property real startRotation

        // 旋转按钮（放在textEditor内部，跟随旋转）
        Rectangle {
            id: rotateButton
            width: 20
            height: 20
            x: overlayContainerRect.width / 2 - width / 2
            y: overlayContainerRect.height + 10
            radius: 10
            color: Colors.color_EEEEEE

            Image {
                id: rotate_icon
                anchors.fill: parent
                source: "qrc:/icons/player/ic_text_rotate.svg"
                sourceSize: Qt.size(20, 20)
            }

            HoverHandler {
                id: rotateHover
                onHoveredChanged: controlRoot.updateMouseOnItem()
            }

            MouseArea {
                anchors.fill: parent
                preventStealing: true

                property bool moved: false
                property point centerPos: Qt.point(overlayContainerRect.x + overlayContainerRect.width / 2, overlayContainerRect.y + overlayContainerRect.height / 2)
                property point startVector
                property point previousVector
                property real accumulatedAngleDiff: 0
                property point pendingPos: Qt.point(0, 0)
                property bool hasPendingRotationUpdate: false

                Timer {
                    id: rotateThrottleTimer
                    interval: 33  // ~30 FPS
                    repeat: false
                    onTriggered: {
                        if (parent.hasPendingRotationUpdate && overlayContainerRect.isRotating) {
                            parent._processRotationUpdate(parent.pendingPos)
                            parent.hasPendingRotationUpdate = false
                        }
                    }
                }

                function _processRotationUpdate(currentPos) {
                    // currentPos 与 centerPos 同为 controlRoot 坐标系。
                    var currentVector = Qt.point(
                        currentPos.x - centerPos.x,
                        currentPos.y - centerPos.y
                    )

                    var dotProduct = previousVector.x * currentVector.x + previousVector.y * currentVector.y
                    var crossProduct = previousVector.x * currentVector.y - previousVector.y * currentVector.x

                    var previousLength = Math.sqrt(previousVector.x * previousVector.x + previousVector.y * previousVector.y)
                    var currentLength = Math.sqrt(currentVector.x * currentVector.x + currentVector.y * currentVector.y)

                    if (previousLength === 0 || currentLength === 0) {
                        return
                    }

                    var angle = Math.acos(Math.max(-1, Math.min(1, dotProduct / (previousLength * currentLength))))
                    var rotationDirection = crossProduct < 0 ? -1 : 1
                    var angleDiff = angle * rotationDirection * 180 / Math.PI

                    accumulatedAngleDiff += angleDiff
                    previousVector = Qt.point(currentVector.x, currentVector.y)

                    overlayTextLayerViewModel.setRotate(accumulatedAngleDiff)
                }

                onPressed: (event) => {
                    overlayContainerRect.isRotating = true
                    // 锚定按下瞬间的边框中心作旋转基准（controlRoot 坐标系）。
                    centerPos = Qt.point(overlayContainerRect.x + overlayContainerRect.width / 2,
                                         overlayContainerRect.y + overlayContainerRect.height / 2)
                    overlayContainerRect.startRotation = overlayContainerRect.rotation

                    var startGlobal = mapToItem(controlRoot, event.x, event.y)
                    startVector = Qt.point(startGlobal.x - centerPos.x, startGlobal.y - centerPos.y)
                    previousVector = Qt.point(startVector.x, startVector.y)
                    accumulatedAngleDiff = 0
                    moved = false
                    overlayTextLayerViewModel.setStartOperate()
                }

                onPositionChanged: (event) => {
                    if (overlayContainerRect.isRotating) {
                        moved = true
                        // 转控制层坐标系，与按下锚定的 centerPos 同空间。
                        pendingPos = mapToItem(controlRoot, event.x, event.y)
                        hasPendingRotationUpdate = true
                        if (!rotateThrottleTimer.running) {
                            rotateThrottleTimer.start()
                        }
                    }
                }

                onReleased: {
                    overlayContainerRect.isRotating = false
                    rotateThrottleTimer.stop()
                    if (hasPendingRotationUpdate) {
                        _processRotationUpdate(pendingPos)
                        hasPendingRotationUpdate = false
                    }
                    if(moved) {
                        console.log("rotate", overlayContainerRect.startRotation, overlayTextLayerViewModel.rotate)
                        overlayTextLayerViewModel.addUndoAction()
                    }
                    moved = false
                    overlayTextLayerViewModel.setEndOperate()
                }
                onCanceled: {
                    overlayTextLayerViewModel.setEndOperate()
                }
            }
        }

        // 四个角的锚点（使用通用组件，放在textEditor内部，跟随旋转）
        // 左上角
        AnchorHandle {
            id: topLeftAnchor
            x: -6
            y: -6
            anchorType: "topLeft"
        }

        // 右上角
        AnchorHandle {
            id: topRightAnchor
            x: overlayContainerRect.width - 6
            y: -6
            anchorType: "topRight"
        }

        // 左下角
        AnchorHandle {
            id: bottomLeftAnchor
            x: -6
            y: overlayContainerRect.height - 6
            anchorType: "bottomLeft"
        }

        // 右下角
        AnchorHandle {
            id: bottomRightAnchor
            x: overlayContainerRect.width - 6
            y: overlayContainerRect.height - 6
            anchorType: "bottomRight"
        }
    }

    // 通用锚点组件
    component AnchorHandle : Rectangle {
        property string anchorType: "topLeft" // "topLeft", "topRight", "bottomLeft", "bottomRight"
        property alias hovered: anchorHover.hovered

        width: 12
        height: 12
        color: Colors.color_EEEEEE
        radius: 6

        HoverHandler {
            id: anchorHover
            onHoveredChanged: controlRoot.updateMouseOnItem()
        }

        MouseArea {
            anchors.fill: parent
            preventStealing: true

            property point startPos
            property real startWidth
            property real startHeight
            property real startX
            property real startY
            property real startScale
            property real stopScale
            property bool isScaling: false
            property bool moved: false
            property point pendingPos: Qt.point(0, 0)
            property bool hasPendingScaleUpdate: false

            Timer {
                id: scaleThrottleTimer
                interval: 33  // ~30 FPS
                repeat: false
                onTriggered: {
                    if (parent.hasPendingScaleUpdate && parent.isScaling) {
                        parent._processScaleUpdate(parent.pendingPos)
                        parent.hasPendingScaleUpdate = false
                    }
                }
            }

            function _processScaleUpdate(currentPos) {
                // 计算文本中心点位置
                var centerX = startX + startWidth / 2
                var centerY = startY + startHeight / 2

                // 计算起始和当前鼠标位置相对于中心点的向量
                var startVectorX = startPos.x - centerX
                var startVectorY = startPos.y - centerY
                var currentVectorX = currentPos.x - centerX
                var currentVectorY = currentPos.y - centerY

                // 计算起始和当前向量的长度
                var startLength = Math.sqrt(startVectorX * startVectorX + startVectorY * startVectorY)
                var currentLength = Math.sqrt(currentVectorX * currentVectorX + currentVectorY * currentVectorY)

                // 计算缩放比例
                var scaleRatio = currentLength / startLength

                stopScale = startScale * scaleRatio
                if(stopScale < controlRoot.minScale){
                    stopScale = controlRoot.minScale
                }
                else if(stopScale > controlRoot.maxScale){
                    stopScale = controlRoot.maxScale
                }
                overlayTextLayerViewModel.setScale(stopScale)
            }

            onPressed: {
                startPos = mapToItem(controlRoot, mouseX, mouseY)
                startWidth = overlayContainerRect.width
                startHeight = overlayContainerRect.height
                startX = overlayContainerRect.x
                startY = overlayContainerRect.y
                startScale = 1
                overlayTextLayerViewModel.setStartOperate()

                isScaling = true
                moved = false
            }

            onPositionChanged: {
                if (!isScaling) return
                moved = true
                pendingPos = mapToItem(controlRoot, mouseX, mouseY)
                hasPendingScaleUpdate = true
                if (!scaleThrottleTimer.running) {
                    scaleThrottleTimer.start()
                }
            }

            onReleased: (event) => {
                console.log("scale onReleased")
                isScaling = false
                scaleThrottleTimer.stop()
                if (hasPendingScaleUpdate) {
                    _processScaleUpdate(pendingPos)
                    hasPendingScaleUpdate = false
                }
                if(moved){
                    overlayTextLayerViewModel.addUndoAction()
                }
                moved = false
                overlayTextLayerViewModel.setEndOperate()
            }
            onCanceled: {
                console.log("scale onCanceled")
                overlayTextLayerViewModel.setEndOperate()
            }
        }
    }

}
