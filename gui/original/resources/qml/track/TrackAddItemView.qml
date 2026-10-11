/**
 * @author: fread.zhang
 * @details: 素材拖拽添加 在轨道上拖拽的样式
 * @date: 2024-09-18 12:21:35
 */

import QtQuick 2.15
import QtQuick.Controls
import Config 1.0

Item {
    id: root
    property string showName: ""
    property real frameLength: 0
    // 每帧的宽度 == scaleBase
    property real pxPerFrame: 0
    width: frameLength * pxPerFrame
    clip: true
    property real itemGap: 1
    property var color
    property var textColor

    Rectangle {
        x: itemGap / 2
        y: 0
        width: parent.width - itemGap
        height: parent.height
        color: parent.color
        radius: 4
    }
    Item {
        x: 4
        y: 4
        height: 14
        width: textLabel.width + 8
        Text {
            id: textLabel
            text: showName
            x: 4
            horizontalAlignment: Text.AlignHCenter
            color: textColor
            font.pixelSize: 10
        }
    }
}
