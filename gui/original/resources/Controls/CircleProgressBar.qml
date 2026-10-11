import QtQuick 2.15
import Qt5Compat.GraphicalEffects

/**
 * @author robert.guo
 * @desc 圆形进度条
 * @create_date 2024-04-23
 */
Rectangle {
    id: img
    property url cuted_background
    property int background_width
    property int background_height
    property int arcWidth
    property color arcColor
    property color arcBackgroundColor
    // 进度，范围0-360
    property real progress: 0
    width: background_width
    height: background_width
    radius: width / 2
    color: "transparent"

    onProgressChanged: {
        canvas.requestPaint();
    }

    Image {
        id: _image
        smooth: true
        visible: false
        anchors.fill: parent
        source: cuted_background
        sourceSize: Qt.size(parent.size, parent.size)
        antialiasing: true
    }
    Rectangle {
        id: _mask
        color: "black"
        anchors.fill: parent
        radius: width / 2
        visible: false
        antialiasing: true
        smooth: true
    }
    OpacityMask {
        id: mask_image
        anchors.fill: _image
        source: _image
        maskSource: _mask
        visible: true
        antialiasing: true
    }

    Canvas {
        id: canvas
        anchors.centerIn: mask_image
        width: 2 * background_width + arcWidth
        height: 2 * background_height + arcWidth
        onPaint: {
            if (progress <= 0) {
                return;
            }
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, canvas.width, canvas.height);
            ctx.beginPath();

            // 自定义画笔笔头， 设置成圆形笔头
            var pen = {
                style: Qt.DotLine,
                capStyle: Qt.RoundCap,
                joinStyle: Qt.RoundJoin
            };
            ctx.strokeStyle = arcBackgroundColor;
            ctx.lineCap = pen.capStyle === Qt.RoundCap ? "round" : "butt";
            ctx.lineJoin = pen.joinStyle === Qt.RoundJoin ? "round" : "bevel";
            ctx.lineWidth = arcWidth;
            ctx.arc(canvas.width / 2, canvas.height / 2, background_width / 2, 0, Math.PI * 2, false);
            ctx.stroke();
            var r = progress * Math.PI / 180;
            ctx.beginPath();
            ctx.strokeStyle = arcColor;
            ctx.lineWidth = arcWidth;
            ctx.arc(canvas.width / 2, canvas.height / 2, background_width / 2, 0 - 90 * Math.PI / 180, r - 90 * Math.PI / 180, false);
            ctx.stroke();
        }
    }
}
