import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.3
import Qt.labs.platform 1.1
import Config 1.0
import Controls 1.0
import CameraMoveAssertModel
import Qt5Compat.GraphicalEffects
import NetworkGifCache
import MovementItemViewModel
import MultiTrackView 1.0
import MaterialDragController 1.0
import CameraMoveDragBussiness 1.0
import PanoramaController 1.0
import MediaTypeModel 1.0

Item {
    id: root
    property CameraMoveAssertModel cameraMoveAssertModel: null
    property string categorySlug: ""
    property string resourceSlug: ""
    property string resourceName: ""
    property string imageUrl: ""
    property bool clearSelect: hasClearSelectItem
    property bool clickSelect: false  // 临时状态
    property bool isSelect: clearSelect && clickSelect // 处理选中态
    onClearSelectChanged : {
        if(hasClearSelectItem == false){
            if(isSelect){
                coverAnimated.currentFrame = 0;
                coverAnimated.playing = false;
                addBtnImage.visible = false;
            }
            clickSelect = false;
        }
    }

    onClickSelectChanged: {
        if(!movementItemViewModel.isCollect){
            collectImage.visible = clickSelect;
        }

    }
    onIsSelectChanged: {
        if(!isSelect)
        {
            movementItemViewModel.unPreviewInFragment();
        }
    }

    MovementItemViewModel{
        id: movementItemViewModel
        categorySlug: root.categorySlug
        resurceSlug: root.resourceSlug
        assertModel:root.cameraMoveAssertModel

        onIsCollectChanged: {
            collectImage.visible = isCollect;
        }

        onCanNotUseInShortSpaceSig:  (isPreview) => {
            if(isPreview)
                toast.showToast(qsTr("pccut_resource_movement_preview_tip"));
            else
                toast.showToast(qsTr("pccut_resource_movement_add_fail_3"));
        }

        onCanNotUseInLossVideoSig: {
            toast.showToast(qsTr("pccut_resource_movement_add_fail_6"));
        }

        onCanNotUseInSpecialVideoSig:{
            toast.showToast(qsTr("pccut_resource_movement_add_fail_4"));
        }

        onCanNotUseInPresetViewSig:{
            toast.showToast(qsTr("pccut_resource_movement_add_fail_5"));
        }

        onCanNotUseInKeyframeSig: (isPreview) => {
            if(isPreview)
                toast.showToast(qsTr("pccut_resource_movement_preview_tip_1"));
            else
                toast.showToast(qsTr("pccut_resource_movement_add_fail_1"));
        }
    }

    onVisibleChanged: {
        if(visible){
            movementItemViewModel.onVisibleChanged(visible);
        }
    }
    onImageUrlChanged: {
        imageCache.getCachedImage(imageUrl);
    }

    width: 80
    height: 100

    Rectangle {
        id: coverContainer
        width: 80
        height: 80
        radius: 6
        border {
            width: root.isSelect ? 2 : 0
            color: Colors.color_F22443
        }
        color: Colors.color_444444
        anchors.top: parent.top
        Rectangle {
                id: imageContainer
                anchors.fill: parent
                anchors.margins: parent.border.width
                radius: parent.radius - parent.border.width
                clip: true
                color: Colors.transparent

            AnimatedImage {
                id: coverAnimated
                visible: true
                anchors.fill: parent
                source: imageUrl
                asynchronous: true
                cache: true
                playing: false

                fillMode: Image.PreserveAspectCrop

                layer.enabled: true // 启用图片自身的裁剪层

                // 图片圆角遮罩
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: imageContainer.width
                        height: imageContainer.height
                        radius: imageContainer.radius
                    }
                }
            }
        MouseArea{
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true

            drag.target: materialDragController.dragCoverItem  // 必须设置
            onEntered: {
                coverAnimated.playing = true;
                addBtnImage.visible = true;
                collectImage.visible = true;
            }
            onExited: {
                if(!isSelect){
                coverAnimated.currentFrame = 0;
                coverAnimated.playing = false;
                addBtnImage.visible = false;
                }

                if(!movementItemViewModel.isCollect && !isSelect){
                    collectImage.visible = false;
                }
            }

            // 处理选中态
            onClicked: {
                clickSelect = true;
                hasClearSelectItem = true;
                coverAnimated.playing = true;
                addBtnImage.visible = true;
                collectImage.visible = true;
                eventTracker.trackEvent("pccut_movement_click", {"movement_slug": resourceSlug, "use_method": "click"})
                movementItemViewModel.previewInFragment();
            }

            onPositionChanged: {
                if(pressed){
                    if(!materialDragController.visible){
                        if(movementItemViewModel.isEmptyVideoTrack()){
                            toast.showToast(qsTr("pccut_resource_movement_add_fail_2"), "tracks");
                            return;
                        }
                        materialDragController.visible = true;
                        var pos = mapToItem(lightWindow.contentItem, mouseX, mouseY);
                        materialDragController.mousePoint = pos;
                    }

                    var posInWindow = mapToItem(lightWindow.contentItem, mouseX, mouseY);
                    materialDragController.mousePoint = posInWindow;
                }
            }

            onReleased: {
                if(materialDragController.visible){
                    materialDragController.visible = false;
                }
            }

            onCanceled: {
                if(materialDragController.visible){
                    materialDragController.visible = false;
                }
            }
        }
}
        Image {
            id: addBtnImage
            visible: false
            anchors{
                bottom: parent.bottom
                bottomMargin: 4
                right: parent.right
                rightMargin: 4
            }
            sourceSize: Qt.size(20, 20)
            source: "qrc:/icons/icon_add.svg"
        }

        MouseArea{
            id: addBtnArea
            anchors.fill: addBtnImage
            onClicked: {
                if(movementItemViewModel.isEmptyVideoTrack()){
                    toast.showToast(qsTr("pccut_resource_movement_add_fail_2"), "tracks");

                    return;
                }
                movementItemViewModel.addInFragment();
            }
        }

        Image {
            id: collectImage
            visible: movementItemViewModel.isCollect
            anchors{
                top: parent.top
                topMargin: 4
                right: parent.right
                rightMargin: 4
            }
            sourceSize: Qt.size(20, 20)
            source: movementItemViewModel.isCollect ?  "qrc:/icons/icon_collect_red.svg" : "qrc:/icons/icon_collect.svg"
        }

        MouseArea{
            id: collectBtnArea
            anchors.fill: collectImage
            onClicked: {
                var curIsCollected = movementItemViewModel.isCollect;
                movementItemViewModel.isCollect = !curIsCollected;
                if(movementItemViewModel.isCollect){
                    collectImage.visible = true;
                }
            }
        }
    }

    // 处理封面拖拽的组件
    MaterialDragController{
        id: materialDragController
        visible: false;
        parentItem: lightWindow.contentItem // 必须设置: 确保可以在整个窗口中进行拖拽
        dragBusinessManager: CameraMoveDragBussiness{
            id: cameraMoveDragBussiness
            view: tracks.multiTrackView
            movementTemplate: movementItemViewModel.movementTemplate

            onCanNotUseInSpecialVideoSig: {
                toast.showToast(qsTr("pccut_resource_movement_add_fail_4"));
            }

            onCanNotUseInShortSpaceSig: (isPreview) => {

                if(isPreview)
                    toast.showToast(qsTr("pccut_resource_movement_preview_tip"));
                else
                    toast.showToast(qsTr("pccut_resource_movement_add_fail_3"));
            }

            onCanNotUseInLossVideoSig: {
                toast.showToast(qsTr("pccut_resource_movement_add_fail_6"));
            }

            onCanNotUseInPresetViewSig:{
                toast.showToast(qsTr("pccut_resource_movement_add_fail_5"));
            }

            onCanNotUseInKeyframeSig: {
                toast.showToast(qsTr("pccut_resource_movement_add_fail_1"));
            }
        }

        dragCoverItem: Rectangle {
            id: dragItemDelegate
            property string imagePath: root.imageUrl
            height: 72
            width: 72
            radius: 6
            border {
                width: 2
                color: Colors.color_F22443
            }
            color: Colors.color_1E1E1E

            Rectangle {
                id: imageContainer1
                anchors.fill: parent
                anchors.margins: parent.border.width
                radius: parent.radius - parent.border.width
                clip: true // 应用圆角裁剪

                Image {
                    id: contentImage
                    anchors.fill: parent
                    anchors.margins: 0
                    source: coverAnimated.source
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    layer.enabled: true // 启用图片自身的裁剪层

                    // 图片圆角遮罩
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: imageContainer1.width
                            height: imageContainer1.height
                            radius: imageContainer1.radius
                        }
                    }
                }
            }
        }
        dragItemInTrack: Rectangle {
            id: dragItemDelegate2
            property string imagePath: root.imageUrl
            height: 56
            width: 56
            radius: 6
            color: Colors.color_1E1E1E

            Rectangle {
                id: imageRectange
                anchors.fill: parent
                radius: 6
                clip: true // 应用圆角裁剪
                color: Colors.transparent

                Image {
                    // id: contentImage2
                    anchors.fill: parent
                    anchors.margins: 0
                    source: coverAnimated.source
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    layer.enabled: true // 启用图片自身的裁剪层

                    // 图片圆角遮罩
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: imageRectange.width
                            height: imageRectange.height
                            radius: imageRectange.radius
                        }
                    }
                }
            }
        }
    }

    NetworkGifCache {
        id: imageCache

        onImageCached: function(url, localPath) {
            if (url === imageUrl) {
                coverAnimated.source = "file:///" + localPath;
            }
        }
        // onImageCached: {
        //     if (url === imageUrl) {
        //         coverAnimated.source = "file:///" + localPath;
        //     }
        // }
    }

    Item {
        id: textContainer
        anchors {
            top: coverContainer.bottom
            topMargin: 4
        }
        width: 80
        height: 16


        Text {
            id: displayText
            width: textContainer.width + 5
            text: resourceName || ""
            font.pixelSize: 12
            color: Colors.color_959595
            elide: Text.ElideMiddle
            visible: true
            verticalAlignment: Text.AlignVCenter

            // 存在添加后不能编辑的问题，暂时屏蔽
            MouseArea {
                id: textMouseArea
                anchors.fill: parent
                hoverEnabled: true
                propagateComposedEvents: true
                onEntered: {
                    if (displayText.implicitWidth > displayText.width)
                    {
                        nameToolTipLoader.active = true
                        var toolTip = nameToolTipLoader.item
                        toolTip.visible = true; // 显示ToolTip
                        var newPoint = textMouseArea.mapToItem(toolTip.parent, textMouseArea.x, textMouseArea.y)
                        // 显示在文本位置
                        toolTip.y = newPoint.y
                        toolTip.tip = displayText.text; // 鼠标进入时设置ToolTip的文本
                        toolTip.x = displayText.x - (nameToolTipLoader.item.width - textContainer.width) / 2
                    }
                }
                onExited: {
                    nameToolTipLoader.active = false
                }
            }

            Loader {
                id: nameToolTipLoader
                active: false  // 默认不加载
                sourceComponent: LightToolTip{
                }
            }
        }
    }

}
