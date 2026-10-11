import QtQuick 2.15
import Config 1.0


// 这个是一个有拖尾效果的转圈动画，一般用于表示运行中或等待状态
Rectangle {
    id: animationRect
    width: 14
    height: 14
    color: Colors.transparent
    Canvas {
        id: canvas
        anchors.fill: parent
        property int begineAngle: 0
        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            ctx.lineWidth = 2;
            ctx.lineCap = "butt";

            // 使用这种方式主要是因为不支持createConicGradient()
            for (var i = 0; i < 360; i++) {
                var startAngle = (i + begineAngle) * Math.PI / 180
                var endAngle = startAngle + Math.PI / 180;
                ctx.beginPath();
                ctx.arc(parent.width / 2, parent.height / 2, parent.width / 2 - ctx.lineWidth / 2, startAngle, endAngle);
                var alpha = i / 360;
                ctx.strokeStyle = "rgba(255, 255, 255, %1)".arg(alpha);
                ctx.stroke();
            }
        }

        Timer {
            interval: 20
            running: animationRect.visible
            repeat: true
            onTriggered: {
                canvas.requestPaint()
            }
        }

        NumberAnimation on begineAngle {
            running: animationRect.visible
            from: 0
            to: 360
            duration: 3000
            onFinished: {
                restart()
            }
        }
    }
}
