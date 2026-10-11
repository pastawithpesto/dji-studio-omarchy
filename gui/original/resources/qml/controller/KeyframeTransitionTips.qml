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
Rectangle {
    id: root
    width: parent.width
    color: Colors.transparent

    property real originY: 0

    Timer {
        id: hideTimer
        interval: 2000
        repeat: false
        onTriggered: root.visible = false
    }

    // 当控件变为可见时启动计时器
    onVisibleChanged: {
        if (root.visible) {
            if (originY == 0) {
                originY = rootAnim.y
            }

            hideTimer.start()
            itemAnim.start()
        } else {
            if (itemAnim.running) {
                itemAnim.stop()
            }
            rootAnim.y = originY
        }
    }

    Rectangle {
        id: rootAnim
        width: parent.width
        color: Colors.transparent

        SequentialAnimation {
            id: itemAnim
            loops: 5

            // 向上移动一点
            NumberAnimation {
                target: rootAnim
                property: "y"
                to: rootAnim.y - 2
                duration: 150
                easing.type: Easing.InOutQuad
            }

            // 向下移动一点
            NumberAnimation {
                target: rootAnim
                property: "y"
                to: rootAnim.y + 2
                duration: 300
                easing.type: Easing.InOutQuad
            }

            // 回到初始位置
            NumberAnimation {
                target: rootAnim
                property: "y"
                to: rootAnim.y
                duration: 150
                easing.type: Easing.InOutQuad
            }
        }

        Rectangle {
            id: parentRectangle
            width: parent.width
            color: Colors.color_EEEEEE
            border.width: 0.5
            border.color: Colors.color_EEEEEE
            radius: 4
            Text {
                id: dynamicText
                text: qsTr("pccut_panel_video_transition_effect")
                color: Colors.color_141414
                font.pixelSize: 10
                wrapMode: Text.WordWrap
                lineHeight: 13
                lineHeightMode: Text.FixedHeight
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    leftMargin: 8
                    rightMargin: 8
                    topMargin: 4
                }

                // 绑定父控件的高度到子控件的高度
                Component.onCompleted: {
                    parentRectangle.height = dynamicText.height + 10;
                    root.height = parentRectangle.height + 8;
                }

                onHeightChanged: {
                    parentRectangle.height = dynamicText.height + 10;
                    root.height = parentRectangle.height + 8;
                }
            }
        }

        Image {
            source: "qrc:/icons/panorama/transition_effect_tips_arrow.svg"
            width: 8
            height: 8
            sourceSize: Qt.size(8, 8)
            anchors {
                bottom: parentRectangle.bottom
                bottomMargin: -4
                horizontalCenter: parent.horizontalCenter
            }
            asynchronous: true
        }
    }
}
