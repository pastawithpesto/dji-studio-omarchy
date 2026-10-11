import QtQuick.Controls
import QtQuick 2.15
import QtQuick.Layouts 1.15
import Qt5Compat.GraphicalEffects
import Config 1.0
import app_qrc 1.0

// 这个button 适用于固定宽度的 button (图片+文字)
Button {
    id: btn
    Accessible.role: Accessible.Button
    property alias textColor: textLabel.color
    property alias source: image.source
    property alias image: image
    property alias textLabel: textLabel
    property alias textLabelWidth: textLabel.implicitWidth
    property color hoverColor: Colors.color_button_background_hovered
    property color normalColor: Colors.color_button_background_normal

    property bool enableIconColor: false
    property color iconColor: ColorsConfig.color_brand

    signal clickBtn()
    height: 26
    padding: 0
    implicitWidth: width
    implicitHeight: height
    property real maxTextWidth: width - (image.visible ? image.width + rowSpace : 0) - textSpace * 2
    property real textSpace: 8
    // btn 是否是可用状态
    property bool btnEnabled: true
    property real rowSpace: 4
    property real bgRadius: RadiusConfig.radius_6_88

    onClicked: {
        clickBtn();
    }

    background: Item {
    }

    contentItem: Rectangle {
        color: hovered ? hoverColor : normalColor
        radius: bgRadius
        Row {
            id: row
            height: parent.height
            width: Math.min(textLabel.width + (image.visible ? image.width + rowSpace : 0), btn.width - textSpace * 2)
            anchors.centerIn: parent
            spacing: rowSpace
            opacity: btnEnabled ? 1 : 0.3
            Image {
                id: image
                visible: source != ""
                width: 16
                height: 16
                anchors.verticalCenter: parent.verticalCenter
                sourceSize: Qt.size(image.width, image.height)

                ColorOverlay {
                    id: colorOverlay
                    anchors.fill: parent
                    source: parent
                    visible: enableIconColor
                    color: btn.iconColor
                }
            }

            Text {
                id: textLabel
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, maxTextWidth)
                wrapMode: Text.Wrap
                elide: Text.ElideRight
                font.pixelSize: 12
                font.weight: Font.Normal
                horizontalAlignment: Text.AlignHCenter
                color: Colors.color_FFFFFF
                maximumLineCount: 1
                text: btn.text
                
            }
        }
    }

    LightToolTip {
        visible: hovered && textLabel.implicitWidth > textLabel.width
        tip: textLabel.text
        z: 200
    }
}
