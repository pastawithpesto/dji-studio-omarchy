import QtQuick 2.15
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Config 1.0
import Controls 1.0

MouseArea {
    id: tipMouseArea
    anchors.fill: parent
    hoverEnabled: true
    property alias text: toolTip.text
    property alias delay: toolTip.delay
    property alias contentItemY: toolTip.y

    ToolTip {
        id: toolTip
        visible: tipMouseArea.containsMouse
        opacity: 0
        // 背景
        background: LightClipRectangle {
            anchors.fill: parent
            clip: true
            radius: [4,4,4,4]

            ShaderEffectSource {
                id: shaderSource
                sourceItem: mainPanel
                sourceRect: Qt.rect(toolTip.x, toolTip.y, toolTip.width, toolTip.height)
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
        leftPadding: 8
        rightPadding: 8
        topPadding: 6
        bottomPadding: 6
        contentItem: Text {
            font.pixelSize: 11
            text: toolTip.text
            color: Colors.color_EEEEEE
        }
        // 渐隐渐现的动画
        Behavior on opacity {
            NumberAnimation {
                duration: 300
            }
        }
        // 监听 visible 属性的变化，控制 opacity
        onVisibleChanged: {
            if (visible) {
                opacity = 1.0
            } else {
                opacity = 0.0
            }
        }
    }
}
