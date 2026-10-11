import QtQuick 2.15
import Config 1.0

/**
 * 云相册存储空间警告气泡控件
 * 白底圆角气泡样式，右侧带小三角，可通过 warningText 设置不同提示内容
 */
Item {
    id: root

    property string warningText: ""

    implicitWidth: bubble.width + arrow.width
    implicitHeight: 28

    // 气泡主体
    Rectangle {
        id: bubble
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: bubbleText.implicitWidth + 24
        height: 28
        radius: 4
        color: "#FFFFFF"

        Text {
            id: bubbleText
            anchors.centerIn: parent
            text: root.warningText
            font.pixelSize: 12
            font.weight: Font.Normal
            color: Colors.color_333333
        }
    }

    // 右侧小三角
    Canvas {
        id: arrow
        width: 6
        height: 10
        anchors.left: bubble.right
        anchors.verticalCenter: bubble.verticalCenter

        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            ctx.beginPath();
            ctx.moveTo(0, 0);
            ctx.lineTo(width, height / 2);
            ctx.lineTo(0, height);
            ctx.closePath();
            ctx.fillStyle = "#FFFFFF";
            ctx.fill();
        }
    }
}
