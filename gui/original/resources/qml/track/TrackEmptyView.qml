/**
 * @author: fread.zhang
 * @details: 轨道空状态的样式
 * @date: 2024-09-18 12:21:35
 */

import QtQuick 2.15
import Config 1.0
import Qt5Compat.GraphicalEffects
import QmlConstants 1.0
import app_qrc 1.0

Item {
    id: emptyContent
    anchors.fill: parent

    Rectangle {
        objectName: actionableItemName.emptyTrack
        width: parent.width - x
        height: 80
        anchors.verticalCenter: parent.verticalCenter
        color: ColorsConfig.color_track_dock_line_background_normal

        Image {
            id: img
            anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
                leftMargin: 36
            }
            width: 20
            height: 20
            sourceSize: Qt.size(24, 24)
            fillMode: Image.PreserveAspectFit
            source: "qrc:/icons/track/empty_track_hint.svg"
        }

        Text {
            anchors {
                left: img.right
                verticalCenter: parent.verticalCenter
                leftMargin: 8
            }
            font.pixelSize: 12
            color: Colors.color_EEEEEE
            text: qsTr("pccut_track_empty_tips")
        }

        // 用ShapePath和用Canvas的效果差不多，都不怎么样
        Canvas {
            width: parent.width - 8
            height: parent.height - 8
            anchors.verticalCenter: parent.verticalCenter
            anchors.horizontalCenter: parent.horizontalCenter

            property real radius: 4
            property real strokeWidth: 2.0
            property real offset: strokeWidth / 2.0

            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);

                // 设置虚线样式
                ctx.setLineDash([2, 1.5]);

                // 设置描边颜色和宽度
                ctx.strokeStyle = ColorsConfig.color_454649_transparent;
                ctx.lineWidth = strokeWidth;

                // 绘制矩形
                drawRoundedRect(ctx, offset, offset, width - offset * 2, height - offset * 2, radius);
            }

            function drawRoundedRect(ctx, x, y, w, h, r) {
                ctx.beginPath();
                ctx.moveTo(x + r, y);
                ctx.lineTo(x + w - r, y);
                ctx.quadraticCurveTo(x + w, y, x + w, y + r);
                ctx.lineTo(x + w, y + h - r);
                ctx.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
                ctx.lineTo(x + r, y + h);
                ctx.quadraticCurveTo(x, y + h, x, y + h - r);
                ctx.lineTo(x, y + r);
                ctx.quadraticCurveTo(x, y, x + r, y);
                ctx.closePath();
                ctx.stroke();
            }
        }
    }

    // 只是放个置灰的UI在这里，不是真正的起指示器的作用
    FrameIndicator {
        height: parent.height
        x: -width / 2
    }
}
