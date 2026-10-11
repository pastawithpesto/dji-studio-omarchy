import QtQuick 2.15
import QtQuick.Controls
import Controls 1.0
import Config 1.0
import TrackingManager 1.0

/**
 * @author robert.guo
 * @desc 过渡效果说明tips
 * @create_date 2024-08-08
 */
Item {
    id: root

    default property alias content: parentRectangle.data

    property real borderWidth: 0.5
    property color borderColor: Colors.color_666666
    property alias bgColor: parentRectangle.color
    property alias radius: parentRectangle.radius
    property real bubbleTailPos: 10

    width: parentRectangle.width
    // 4是下面的那个三角的Image的高度(8)加上margin(-4)
    height: parentRectangle.height + 4

    Rectangle {
        id: parentRectangle
        width: childrenRect.width
        height: childrenRect.height
        color: Colors.color_444444
        border.width: borderWidth
        border.color: borderColor
        radius: 4
    }

    Image {
        source: "qrc:/icons/bubble_tail.svg"
        width: 8
        height: 8
        sourceSize: Qt.size(8, 8)
        anchors {
            top: parentRectangle.bottom
            leftMargin: bubbleTailPos - 4
            left: parent.left
            topMargin: -4
        }
    }
}
