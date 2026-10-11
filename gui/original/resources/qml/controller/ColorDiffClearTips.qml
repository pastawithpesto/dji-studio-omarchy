import QtQuick 2.15
import QtQuick.Controls
import Controls 1.0
import Config 1.0
import TrackingManager 1.0
import Qt5Compat.GraphicalEffects

/**
 * @author o-victor.di
 * @desc 色差消除说明tips
 * @create_date 2025.3.15
 */
Item {
    id: root
    width: parent.width
    property int arrowLeftMargin: 10
    property string tipText: qsTr("pccut_panel_image_color_control_describe")
    Rectangle {
        id: parentRectangle
        width: parent.width
        height: parent.height - arrow.height
        anchors{
            top: parent.top
            topMargin: 0
        }

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
                color: Colors.color_141414
                radius: 4
            }
        }
        Text {
            id: dynamicText
            text: root.tipText
            color: Colors.color_EEEEEE
            font.pixelSize: 11
            wrapMode: Text.WrapAnywhere
            lineHeight: 15
            font.letterSpacing: 1
            lineHeightMode: Text.FixedHeight
            anchors {
                left: parent.left
                right: parent.right
                leftMargin: 8
                rightMargin: 8
                verticalCenter: parent.verticalCenter
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
        id:arrow
        source: "qrc:/icons/panorama/transition_effect_arrow.svg"
        width: 8
        height: 8
        sourceSize: Qt.size(8, 8)
        anchors {
            top: parentRectangle.bottom
            left: parent.left
            leftMargin: arrowLeftMargin - arrow.width / 2
            topMargin: -4
        }
    }
}
