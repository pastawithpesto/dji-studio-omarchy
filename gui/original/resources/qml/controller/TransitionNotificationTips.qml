import QtQuick 2.15
import QtQuick.Controls
import Controls 1.0
import Config 1.0
import TrackingManager 1.0
import Qt5Compat.GraphicalEffects

/**
 * @author robert.guo
 * @desc 过渡效果说明tips
 * @create_date 2024-08-08
 */
Item {
    id: root
    width: parent.width

    property int arrowLeftMargin: 90
    // 文本是否右对齐
    property bool alignRight: false
    // 箭头资源
    property string arrowSource: "qrc:/icons/panorama/transition_effect_arrow.svg"
    // 箭头是否朝上
    property bool arrowUpward: false

    function updateDesc(desc) {
        dynamicText.text = desc
    }

    function hideArrow() {
        arrow.visible = false
    }

    Rectangle {
        id: parentRectangle
        width: parent.width
        color: Colors.color_141414_85
        border.width: 0.5
        border.color: Colors.color_444444
        radius: 4
        LightClipRectangle {
            anchors.fill: parent
            clip: true
            radius: [4,4,4,4]

            ShaderEffectSource {
                id: shaderSource
                sourceItem: mainPanel
                sourceRect: Qt.rect(root.x, root.y, root.width, root.height)
                width: parent.width
                height: parent.height
                live: true
                smooth: true
            }

            // 高斯调节
            FastBlur {
                anchors.fill: parent
                source: shaderSource
                radius: 48
            }

            Rectangle {
                anchors.fill: parent
                border.color: Colors.color_444444
                border.width: 0.5
                color: Colors.color_141414_85
                radius: 4
            }
        }
        Text {
            id: dynamicText
            text: qsTr("pccut_panel_video_transition_tips")
            color: Colors.color_EEEEEE
            font.pixelSize: 11
            wrapMode: Text.WordWrap
            lineHeight: 15
            font.letterSpacing: 1
            lineHeightMode: Text.FixedHeight
            horizontalAlignment: alignRight? Text.AlignRight : Text.AlignLeft
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                leftMargin: 8
                rightMargin: 8
                topMargin: 7
            }

            // 绑定父控件的高度到子控件的高度
            Component.onCompleted: {
                parentRectangle.height = dynamicText.height + 14;
                root.height = parentRectangle.height + 8;
            }

            onHeightChanged: {
                parentRectangle.height = dynamicText.height + 14;
                root.height = parentRectangle.height + 8;
            }
        }
    }

    Image {
        id: arrow
        source: arrowSource
        width: 8
        height: 8
        sourceSize: Qt.size(8, 8)
        visible: !arrowUpward
        anchors {
            bottom: parent.bottom
            leftMargin: root.arrowLeftMargin - dynamicText.anchors.leftMargin
            left: parent.left
            bottomMargin: 4
        }
    }

    Image {
        id: arrowUp
        source: arrowSource
        width: 8
        height: 8
        sourceSize: Qt.size(8, 8)
        visible: arrowUpward
        anchors {
            top: parent.top
            leftMargin: root.arrowLeftMargin - dynamicText.anchors.leftMargin
            left: parent.left
            topMargin: -4
        }
    }
}
