/**
 * @author: fread.zhang
 * @details: 素材拖拽添加 在非轨道上的样式
 * @date: 2024-09-18 12:21:35
 */

import QtQuick 2.15
import QtQuick.Controls

import Qt5Compat.GraphicalEffects
import Config 1.0
import Controls 1.0
import MediaListViewModel 1.0
import app_qrc 1.0

Item {
    id: draggableRect
    property MediaListViewModel mediaListViewModel
    property int itemCount: 0
    property bool isDragging: false
    property bool isEnterReplaceArea: false
    parent: editorManager.isInUserGuideStatus ? userGuideMask : mainPanel
    z:10
    width: 82
    height: 82
    visible: false

    Rectangle {
        id: roundedRectangle
        visible: itemCount > 1
        property real borderWidth: 1.5
        width: coverBorder.width
        height: coverBorder.height
        color: Colors.color_000000
        radius: 6
        opacity: 0.5
        anchors.centerIn: parent
        border.color: ColorsConfig.color_brand
        border.width: roundedRectangle.borderWidth
        transform: Rotation {
            id: rotation
            origin.x: roundedRectangle.width / 2
            origin.y: roundedRectangle.height / 2
            angle: 8
        }
    }

    Rectangle {
        id: coverBorder
        property real borderWidth: 1.5
        anchors.centerIn: parent
        width: 72
        height: 72
        radius: 6
        clip: true
        color: Colors.color_000000
        layer.enabled: true
        //用遮罩来设置阴影圆角
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: coverBorder.width
                height: coverBorder.height
                radius: coverBorder.radius
                color: Colors.color_000000
            }
        }
        DropShadow {
            horizontalOffset: 0
            verticalOffset: 0
            radius: 10
            color: Colors.color_000000_40
        }

        MediaCover {
            anchors.fill: parent
            mediaPath: draggableRect.mediaPath
            mediaMd5: draggableRect.mediaMd5
            layer.enabled: true
            needScale: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: coverBorder.width
                    height: coverBorder.height
                    radius: 30 // 设置圆角的大小
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            width: parent.width
            height: parent.height
            radius: parent.radius
            border.color: ColorsConfig.color_brand
            border.width: coverBorder.borderWidth
            color: Colors.color_transparent
        }

        Image {
            id: replaceIcon
            visible: true
            anchors{
                bottom: parent.bottom
                bottomMargin: 4
                right: parent.right
                rightMargin: 4
            }

            source: "qrc:/icons/icon_repalce_media.svg"
            sourceSize: Qt.size(20, 20)

            layer.enabled: true
            layer.effect: Glow {
                color: Colors.color_000000_15
                spread: 0.6
                radius: 4
            }

        }
    }

    Rectangle {
        visible: itemCount > 1
        color: ColorsConfig.color_brand
        height: 18
        width: Math.max(18, countText.width + 11)
        anchors.right: coverBorder.right
        anchors.rightMargin: 4
        radius: height / 2
        anchors.verticalCenter: coverBorder.top
        anchors.verticalCenterOffset: 2
        Text {
            id: countText
            anchors.centerIn: parent
            text: itemCount
            color: ColorsConfig.color_FFFFFF_000000
            wrapMode: Text.NoWrap
            font.pixelSize: 11
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }
    // 素材的id
    property string mediaAssetId: ""
    // 素材的路径
    property string mediaPath: ""
    // 素材分段MD5(上游预算)，透传给内部 MediaCover 拼入缩略图 URL
    property string mediaMd5: ""
    // 素材的index
    property int index: 0
    property var fileList: []
    // 云相册等外部素材源可注入开始/结束拖拽逻辑；为空时保持本地素材行为
    property var dragBeginCallback: null
    property var dragReleaseCallback: null

    function setDragPointMove(mousePoint, isFirst) {
        // 从这里直接访问 tracks.flickable 感觉不太好, 但这样很直接方便
        let flickablePoint = tracks.flickable.mapFromItem(draggableRect.parent, mousePoint);
        let windowPoint = draggableRect.parent.mapToItem(null, mousePoint);
        tracks.flickable.dragMousePoint = flickablePoint;
        if (isFirst) {
            // 开始拖拽
            editorManager.pause();
            if (dragBeginCallback !== null) {
                fileList = dragBeginCallback(index, windowPoint);
            } else {
                fileList = draggableRect.mediaListViewModel.mediaDragAddBegin(index, windowPoint);
            }
            if (!fileList || fileList.length === 0) {
                isDragging = false;
                return false;
            }
            itemCount = fileList.length;
        }
        isDragging = true;
        globalSignal.mediaDragAddMove(windowPoint);
        draggableRect.x = mousePoint.x - 20;
        draggableRect.y = mousePoint.y - 20;
        draggableRect.visible = flickablePoint.y < 0 || isEnterReplaceArea

        if (tracks.checkIsInVideoTrack(flickablePoint)) {
            draggableRect.width = 56;
            draggableRect.height = 56;
            coverBorder.width = 56;
            coverBorder.height = 56;
            coverBorder.borderWidth = 0;
            roundedRectangle.borderWidth = 0;
            replaceIcon.visible = true;
        } else {
            draggableRect.width = 82;
            draggableRect.height = 82;
            coverBorder.width = 72;
            coverBorder.height = 72;
            coverBorder.borderWidth = 1.5;
            roundedRectangle.borderWidth = 1.5;
            replaceIcon.visible = false;
        }
        return true;
    }
    function setDragPointRelease(mousePoint, isCancel) {
        isDragging = false;
        let windowPoint = draggableRect.parent.mapToItem(null, mousePoint);
        if (dragReleaseCallback !== null) {
            dragReleaseCallback(fileList, isCancel);
        } else if (!isCancel) {
            root.clikAddMedia(fileList);
        }
        // nova: 落点插入改由 mediaDragAddRelease 经 nle 处理(按落点插入主视频轨)；不再走 clikAddMedia 追加末尾。
        globalSignal.mediaDragAddRelease(windowPoint, isCancel);
        draggableRect.mediaListViewModel.stopPreviewPlay();
        draggableRect.visible = false;
    }

    Connections {
        target: globalSignal
        function onMediaDragEnterReplaceArea(isEnterReplaceArea){
            if(draggableRect.isDragging){
                draggableRect.isEnterReplaceArea = isEnterReplaceArea;
                draggableRect.visible = isEnterReplaceArea;
            }
        }
    }
}
