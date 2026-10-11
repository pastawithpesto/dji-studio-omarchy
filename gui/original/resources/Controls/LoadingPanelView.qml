import QtQuick
import QtQuick.Controls
import Config 1.0

Item {
    id: root

    property alias loadingTextTip: loadingText.text
    property alias loadingTextFont: loadingText.font
    property alias loadingTextColor: loadingText.color
    property alias backgroudColor: backgroundRect.color

    // 半透明遮罩背景
    Rectangle {
        id: backgroundRect
        anchors.fill: parent
        color: Colors.color_141414
    }

    // 内容容器
    Item {
        id: contentRect
        anchors.centerIn: parent
        width: 200
        height: 120

        // Loading 状态
        Column {
            anchors.centerIn: parent
            spacing: 16

            // 自定义loading指示器 - 还原设计稿样式
            Item {
                id: busyIndicator
                anchors.horizontalCenter: parent.horizontalCenter
                width: 38  // 37.33
                height: 38

                Canvas {
                    id: loadingCanvas
                    anchors.fill: parent

                    property real rotation: 0

                    onPaint: {
                        var ctx = getContext("2d");
                        var centerX = width / 2;
                        var centerY = height / 2;
                        var radius = Math.min(width, height) / 2 - 2;

                        ctx.clearRect(0, 0, width, height);
                        ctx.lineCap = "round";
                        ctx.lineWidth = 4;

                        // 绘制从透明到白色的渐变弧（模拟conic-gradient）
                        for (var i = 0; i < 360; i += 2) {
                            var opacity = (i % 360) / 360;
                            ctx.strokeStyle = "rgba(238, 238, 238, " + opacity + ")";

                            var angle = (loadingCanvas.rotation + 90 + i) * Math.PI / 180;
                            var nextAngle = (loadingCanvas.rotation + 90 + i + 2) * Math.PI / 180;

                            ctx.beginPath();
                            ctx.arc(centerX, centerY, radius, angle, nextAngle);
                            ctx.stroke();
                        }
                    }

                    RotationAnimator on rotation {
                        from: 0
                        to: 360
                        duration: 1000
                        running: root.visible
                        loops: Animation.Infinite
                    }

                    onRotationChanged: requestPaint()
                }
            }

            Text {
                id: loadingText
                anchors.horizontalCenter: parent.horizontalCenter
                text: loadingTextTip
                font.pixelSize: 14
                color: Colors.color_666666
            }
        }
    }
}
