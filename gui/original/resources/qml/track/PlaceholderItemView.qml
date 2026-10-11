/**
 * @author: fread.zhang
 * @details: 多轨道view的拖拽是的投影占位
 * @date: 2024-08-27 12:21:35
 */

import QtQuick 2.15
import QtQuick.Controls
import Config 1.0
import QmlConstants 1.0
import MultiTrackView 1.0
import app_qrc 1.0

Item {
    id: root
    property real itemGap: 1
    property var shadowType

    Rectangle {
        x: itemGap / 2
        y: 0
        width: parent.width - itemGap
        height: parent.height
        color: {
            switch(shadowType) {
            case MultiTrackView.Video: {
                return ColorsConfig.color_2460B915_04585820
            }
            case MultiTrackView.Audio: {
                return ColorsConfig.color_5346C215_0F305840
            }
            case MultiTrackView.Text: {
                return ColorsConfig.color_0A9B8315_0A9B8315
            }
            default: {
                return Colors.transparent
            }
            }
        }

        radius: 4
        Canvas {
            width: parent.width
            height: parent.height
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
                switch(root.shadowType) {
                case MultiTrackView.Video: {
                    ctx.strokeStyle = ColorsConfig.color_2460B9_transparent;
                    break;
                }
                case MultiTrackView.Audio: {
                    ctx.strokeStyle = ColorsConfig.color_5346C2_transparent;
                    break;
                }
                case MultiTrackView.Text: {
                    ctx.strokeStyle = ColorsConfig.color_0A9B83_transparent;
                    break;
                }
                default: {
                    ctx.strokeStyle = Colors.transparent;
                }
                }
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
}
