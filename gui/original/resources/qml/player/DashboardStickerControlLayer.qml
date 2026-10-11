import QtQuick 2.15
import QtQuick.Controls

import Config 1.0
import Controls 1.0
import MarkPointToolbarViewModel 1.0

Item {
    id: controlRoot

    property var trackStickersList: []
    property real resizeAreaSize: 5
    property bool isPanorama: false
    property bool isItemSelected: false
    // Qt6 中有奇怪的bug 点击切换按钮后, 会直接响应 PointHandler 的点击方法导致选中效果取消掉
    // 没有发现更好的处理方法
    property real lastTime: 0.0
    Timer {
            id: resetTimer
            interval: 50
            repeat: false
            onTriggered: {
                globalSignal.resetDashboardSticker();
            }
        }

    Connections {
        target: globalSignal

        function onMultiTrackStickersLoaded(list) {
            controlRoot.trackStickersList = list;
            var isSelected = false;
            for (var t = 0; t < list.length; t++) {
                var stickers = list[t].stickers;
                if (stickers) {
                    for (var i = 0; i < stickers.length; i++) {
                        if (stickers[i] !== null && stickers[i].isSelected) {
                            isSelected = true;
                            break;
                        }
                    }
                }
                if (isSelected) break;
            }
            controlRoot.isItemSelected = isSelected;
        }

        function onPlayerProfileSizeChanged() {
            resetTimer.start()
        }

        function onVideoSelected(fragment){
            if (CommonUtils.isNull(fragment)) {
                dashboardManager.refreshStickerControlLayer();
            }
        }

        function onResetStickerControlLayerState() {
            controlRoot.isItemSelected = false
        }

        function onRemoveSticker(stickerType) {
            globalSignal.updateStickerState(stickerType)
            globalSignal.removeDashboardSticker(stickerType)
        }
    }

    // 点击背景做取消选中
    function clickBgView(point) {
        var isInCover = false;
        for (var t = 0; t < trackLayerRepeater.count; t++) {
            var trackLayer = trackLayerRepeater.itemAt(t);
            if (trackLayer === null) continue;
            var innerRepeater = trackLayer.stickerRepeater;
            if (innerRepeater === null) continue;
            var rp = mapToItem(innerRepeater, point.x, point.y);
            for (var j = 0; j < innerRepeater.count; j++) {
                var sItem = innerRepeater.itemAt(j);
                if (sItem === null) continue;
                var sp = innerRepeater.mapToItem(sItem, rp.x, rp.y);
                if (sItem.contains(sp) || sItem.clickOnBtn(sp)) {
                    isInCover = true;
                    break;
                }
            }
            if (isInCover) break;
        }

        if (!isInCover) {
            dashboardManager.refreshStickerControlLayer();
        }
    }

    // 监听点击背景 (为了做取消选中)
    Item {
        id: bgView
        visible: controlRoot.isItemSelected
        parent: UiUtils.getTopParent(controlRoot)
        anchors.fill: parent
        PointHandler {
            onGrabChanged: (transition, point) => {
                point.accepted = false;
                if (Date.now() - lastTime < 200) {
                    return;
                }
                // 主要是为了适配Qt6
                if (point.pressPosition !== point.position) {
                    return
                }
                var mousePoint = point.position;
                var clickPoint = bgView.mapToItem(controlRoot, mousePoint);
                if (controlRoot.contains(clickPoint)) {
                    controlRoot.clickBgView(clickPoint);
                } else {
                    dashboardManager.refreshStickerControlLayer();
                }
            }
        }
    }

    // 判断点击位置是否被更高层的视频区域遮挡
    function isOccludedByUpperLayer(currentLayerIndex, px, py) {
        for (var i = 0; i < currentLayerIndex; i++) {
            var upperLayer = trackLayerRepeater.itemAt(i);
            if (upperLayer !== null && upperLayer.containsPoint(px, py)) {
                return true;
            }
        }
        return false;
    }

    // 多轨道多层 Repeater（统一处理全景和非全景）
    Repeater {
        id: trackLayerRepeater
        model: controlRoot.trackStickersList

        delegate: Item {
            id: trackLayer
            anchors.fill: parent
            z: controlRoot.trackStickersList.length - index

            property int layerIndex: index
            property var trackData: modelData
            property alias stickerRepeater: innerRepeater
            property bool layerIsPanorama: trackData.isPanorama === true

            property size originSize: {
                if (layerIsPanorama) {
                    return Qt.size(editorManager.profileWidth(), editorManager.profileHeight());
                }
                var w = trackData.videoWidth;
                var h = trackData.videoHeight;
                var aspectRatio = w / h;

                if (Math.abs(aspectRatio - 16 / 9) < 0.01) {
                    return Qt.size(1920, 1080);
                } else if (Math.abs(aspectRatio - 9 / 16) < 0.01) {
                    return Qt.size(1080, 1920);
                } else if (Math.abs(aspectRatio - 4 / 3) < 0.01) {
                    return Qt.size(1440, 1080);
                } else if (Math.abs(aspectRatio - 3 / 4) < 0.01) {
                    return Qt.size(1080, 1440);
                } else if (Math.abs(aspectRatio - 1) < 0.01) {
                    return Qt.size(1080, 1080);
                } else {
                    return Qt.size(w, h);
                }
            }

            property size realSize: {
                if (layerIsPanorama) {
                    return Qt.size(controlRoot.width, controlRoot.height);
                }
                var originAspectRatio = originSize.width / originSize.height;
                var profileAspectRatio = editorManager.profileWidth() / editorManager.profileHeight();

                var newWidth, newHeight;
                if (profileAspectRatio > originAspectRatio) {
                    newHeight = controlRoot.height;
                    newWidth = newHeight * originAspectRatio;
                } else {
                    newWidth = controlRoot.width;
                    newHeight = newWidth / originAspectRatio;
                }
                return Qt.size(newWidth, newHeight);
            }

            property real offsetX: (controlRoot.width - realSize.width) / 2
            property real offsetY: (controlRoot.height - realSize.height) / 2

            function containsPoint(px, py) {
                return px >= offsetX && px < offsetX + realSize.width
                    && py >= offsetY && py < offsetY + realSize.height;
            }

            Repeater {
                id: innerRepeater
                model: trackData.stickers
                delegate: Item {
                    id: item

                    width: modelData.width / trackLayer.originSize.width * trackLayer.realSize.width
                    height: modelData.height / trackLayer.originSize.height * trackLayer.realSize.height
                    anchors.left: parent.left
                    anchors.leftMargin: trackLayer.offsetX + modelData.x / trackLayer.originSize.width * trackLayer.realSize.width
                    anchors.top: parent.top
                    anchors.topMargin: trackLayer.offsetY + modelData.y / trackLayer.originSize.height * trackLayer.realSize.height

                    function clickOnBtn(point) {
                        var itemPoint = item.mapToItem(unitChangeArea, point.x, point.y);
                        if(unitChangeArea.contains(itemPoint)) {
                            return true;
                        }
                        itemPoint = item.mapToItem(cancelArea, point.x, point.y);
                        if(cancelArea.contains(itemPoint)) {
                            return true;
                        }
                        return false;
                    }

                    Image {
                        id: tmpImage
                        source: ""
                        anchors.fill: parent
                        cache: false
                    }

                    Rectangle {
                        id: border
                        visible: false
                        color: Colors.color_transparent
                        border.color: Colors.color_FFFFFF
                        border.width: 1
                        radius: 4
                        anchors.fill: parent
                        Timer {
                            id: borderTimer
                            interval: 100
                            repeat: false
                            onTriggered: {
                                border.visible = modelData.isSelected
                            }
                        }

                        Connections {
                            target: modelData
                            function onIsSelectedChanged() {
                                if (modelData.isSelected) {
                                    borderTimer.start();
                                } else {
                                    border.visible = false;
                                }
                            }
                        }
                        Component.onCompleted: {
                            if (modelData.isSelected) {
                                borderTimer.start();
                            }
                        }
                    }

                    property real btnMargin: Math.min(trackLayer.realSize.width * 30 / 1080, trackLayer.realSize.height * 30 / 1080)
                    property real pixelRatio: trackLayer.originSize.width / controlRoot.width

                    MouseArea {
                        id: dragArea
                        anchors.fill: parent
                        property var isDragging
                        property var startX
                        property var startY
                        preventStealing: modelData.isSelected
                        hoverEnabled: true

                        onPressed: (mouse) => {
                            // 检查点击是否在本层视频区域内，不在则穿透到下层
                            var globalPt = item.mapToItem(controlRoot, mouse.x, mouse.y);
                            if (!trackLayer.containsPoint(globalPt.x, globalPt.y)) {
                                mouse.accepted = false;
                                return;
                            }

                            // 检查是否被更高层视频区域遮挡
                            if (controlRoot.isOccludedByUpperLayer(trackLayer.layerIndex, globalPt.x, globalPt.y)) {
                                mouse.accepted = false;
                                return;
                            }

                            lastTime = Date.now();
                            isDragging = false;
                            preventStealing = true;
                            if (!modelData.isSelected) {
                                var repeaterPoint = item.mapToItem(innerRepeater, mouse.x, mouse.y);
                                for (var i = 0; i < innerRepeater.count; i++) {
                                    var tempItem = innerRepeater.itemAt(i);
                                    if (tempItem === null) continue;
                                    var itemPoint = innerRepeater.mapToItem(tempItem, repeaterPoint.x, repeaterPoint.y);
                                    if (item !== tempItem && trackLayer.trackData.stickers[i] !== null
                                            && trackLayer.trackData.stickers[i].isSelected
                                            && (tempItem.contains(itemPoint) || tempItem.clickOnBtn(itemPoint))) {
                                        mouse.accepted = false;
                                        break;
                                    }
                                }
                                return;
                            }

                            startX = mouse.x
                            startY = mouse.y
                            logger.d("Sticker onPressed " + startX + ", " + startY)
                        }

                        onPositionChanged: (mouse) => {
                            if (!(pressedButtons & Qt.LeftButton)) {
                                return
                            }
                            if (!modelData.isSelected) {
                                preventStealing = true;
                                return
                            }

                            if (!isDragging) {
                                isDragging = true;
                                globalSignal.stickerDragStarted()
                            }

                            var leftMargin = item.anchors.leftMargin + (mouse.x - startX)
                            var topMargin = item.anchors.topMargin + (mouse.y - startY)

                            if (leftMargin <= trackLayer.offsetX) {
                                leftMargin = trackLayer.offsetX
                            }

                            if (leftMargin > trackLayer.offsetX + trackLayer.realSize.width - item.width) {
                                leftMargin = trackLayer.offsetX + trackLayer.realSize.width - item.width
                            }

                            if (topMargin <= trackLayer.offsetY) {
                                topMargin = trackLayer.offsetY
                            }

                            if (topMargin > trackLayer.offsetY + trackLayer.realSize.height - item.height) {
                                topMargin = trackLayer.offsetY + trackLayer.realSize.height - item.height
                            }

                            modelData.x = (leftMargin - trackLayer.offsetX) / trackLayer.realSize.width * trackLayer.originSize.width
                            modelData.y = (topMargin - trackLayer.offsetY) / trackLayer.realSize.height * trackLayer.originSize.height
                            Qt.callLater(function() { editorManager.refreshPlayer() })
                        }

                        onReleased: {
                            if (!isDragging) {
                                dashboardManager.selectFragmentByClipId(trackLayer.trackData.clipId)
                                globalSignal.switchToDashboardTab()
                                globalSignal.removeKeyFrameSelect()
                                globalSignal.removeTrackingSelect()
                                MarkPointToolbarViewModel.clearSelectedMark();

                                dashboardManager.refreshStickerControlLayer(false, modelData.type, trackLayer.trackData.clipId);
                                controlRoot.isItemSelected = true

                                editorManager.refreshPlayer()
                            }
                            else {
                                isDragging = false
                                globalSignal.stickerDragEnded()
                            }
                        }
                    }

                    Connections {
                        target: globalSignal

                        function onStickerImageLoaded(target) {
                            if (target !== modelData.type) {
                                return
                            }

                            tmpImage.source = ""
                            tmpImage.source = "image://tempImage/" + modelData.type
                        }
                    }

                    Image {
                        id: unitChangeBtn
                        source: "qrc:/icons/dashboard_unit_change.svg"
                        width: 2 * btnMargin
                        height: 2 * btnMargin
                        sourceSize: Qt.size(2 * btnMargin, 2 * btnMargin)
                        anchors.left: parent.left
                        anchors.leftMargin: -btnMargin
                        anchors.top: parent.top
                        anchors.topMargin: -btnMargin
                        visible: false

                        MouseArea {
                            id: unitChangeArea
                            anchors.fill: parent
                            preventStealing: modelData.isSelected
                            onPressed: (mouse) => {
                                dragArea.startX = mouse.x
                                dragArea.startY = mouse.y
                                dragArea.isDragging = false
                            }
                            onPositionChanged: (mouse) =>{
                                dragArea.isDragging = true
                                dragArea.onPositionChanged(mouse)
                            }
                            onReleased: {
                                lastTime = Date.now();
                                if (!dragArea.isDragging) {
                                    modelData.toggleUnit()
                                    dashboardManager.pushActiveStickerCustomData()
                                }
                                else {
                                    dragArea.isDragging = false
                                    globalSignal.stickerDragEnded()
                                }
                            }
                        }

                        Timer {
                            id: unitChangeTimer
                            interval: 100
                            repeat: false
                            onTriggered: {
                                unitChangeBtn.visible = modelData !== null && modelData.isSelected && modelData.units.length > 1
                            }
                        }

                        Connections {
                            target: modelData
                            function onIsSelectedChanged() {
                                if (modelData.isSelected) {
                                    unitChangeTimer.start();
                                } else {
                                    unitChangeBtn.visible = false;
                                }
                            }
                        }

                        Component.onCompleted: {
                            unitChangeTimer.start();
                        }
                    }

                    Image {
                        id: cancelBtn
                        source: "qrc:/icons/dasnhboard_close.svg"
                        width: 2 * btnMargin
                        height: 2 * btnMargin
                        sourceSize: Qt.size(2 * btnMargin, 2 * btnMargin)
                        anchors.right: parent.right
                        anchors.rightMargin: -btnMargin
                        anchors.top: parent.top
                        anchors.topMargin: -btnMargin
                        visible: false

                        MouseArea {
                            id: cancelArea
                            anchors.fill: parent
                            preventStealing: modelData.isSelected
                            onPressed: (mouse) =>{
                                dragArea.startX = mouse.x
                                dragArea.startY = mouse.y
                                dragArea.isDragging = false
                            }
                            onPositionChanged: (mouse) =>{
                                dragArea.isDragging = true
                                dragArea.onPositionChanged(mouse)
                            }
                            onReleased: {
                                if (!dragArea.isDragging) {
                                    globalSignal.updateStickerState(modelData.type)
                                    globalSignal.removeDashboardSticker(modelData.type)
                                }
                                else {
                                    dragArea.isDragging = false
                                    globalSignal.stickerDragEnded()
                                }
                            }
                        }
                        Timer {
                            id: cancelTimer
                            interval: 100
                            repeat: false
                            onTriggered: {
                                cancelBtn.visible = modelData.isSelected
                            }
                        }

                        Connections {
                            target: modelData
                            function onIsSelectedChanged() {
                                if (modelData.isSelected) {
                                    cancelTimer.start();
                                } else {
                                    cancelBtn.visible = false;
                                }
                            }
                        }

                        Component.onCompleted: {
                            if (modelData.isSelected) {
                                cancelTimer.start();
                            }
                        }
                    }
                }
            }
        }
    }

}
