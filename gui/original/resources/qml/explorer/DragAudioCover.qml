/**
 * @author: fread.zhang
 * @details: 音频拖拽添加 在非轨道上的样式
 * @date: 2024-11-06 12:21:35
 */

import QtQuick 2.15
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Config 1.0
import AudioListModel 1.0
import app_qrc 1.0

Rectangle {
    id: draggableRect
    property AudioListModel audioListModel
    parent: mainPanel
    width: 72
    height: 72
    visible: false
    radius: 6
    layer.enabled: true
    border.color: ColorsConfig.color_brand
    border.width: 1.5
    clip: true
    color: Colors.color_000000
    Image {
        clip: true
        anchors.margins: 1.5
        anchors.fill: parent
        source: parent.mediaPath
        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: draggableRect.width
                height: draggableRect.height
                radius: draggableRect.radius // 设置圆角的大小
            }
        }
    }
    // 素材的路径
    property string mediaPath: ""
    // 素材的index
    property int index: 0
    function setDragPointMove(mousePoint, isFirst) {
        let windowPoint = draggableRect.parent.mapToItem(null, mousePoint);
        // 从这里直接访问 tracks.flickable 感觉不太好, 但这样很直接方便
        let flickablePoint = tracks.flickable.mapFromItem(draggableRect.parent, mousePoint);
        tracks.flickable.dragMousePoint = flickablePoint;
        console.log("lcm value:"+isFirst);
        if (isFirst) {
            // 开始拖拽
            editorManager.pause();
            audioListModel.dragAddBegin(index, windowPoint);
        }
        globalSignal.audioDragMove(windowPoint);
        draggableRect.x = mousePoint.x - 20;
        draggableRect.y = mousePoint.y - 20;
        draggableRect.visible = flickablePoint.y < 0;
    }
    function setDragPointRelease(mousePoint, isCancel) {
        let windowPoint = draggableRect.parent.mapToItem(null, mousePoint);
        globalSignal.audioDragRelease(windowPoint, isCancel);
        draggableRect.visible = false;
    }
}
