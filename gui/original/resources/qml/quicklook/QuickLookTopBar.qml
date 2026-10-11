import QtQuick 2.15
import QtQuick.Layouts 1.15
import LightRectangle 1.0
import ShortcutAction 1.0
import Controls 1.0
import Config 1.0
import app_qrc 1.0

Item {
    id: topbar

    required property var window
    property string sourceFileName: ""
    property bool playerIsFullscreen: false
    property bool favorate: false
    property int iconSize: 20
    property bool fileInvalid: false

    signal customClosedClicked
    signal favorateClicked
    signal gotoEdit

    z: 65535

    Item {
        id: d
        property var win: Window.window
        property bool resizable: false
    }

    WindowMovable {
        id: movable
        anchors.fill: parent
        resizableBar: d
    }

    Text {
        id: sourceFileText
        horizontalAlignment: Text.AlignLeft
        verticalAlignment: Text.AlignVCenter
        color: Colors.color_EBEBEB
        text: sourceFileName
        elide: Text.ElideRight
        font {
            pixelSize: 13
            weight: 400
        }
        anchors {
            left: parent.left
            leftMargin: 13
            verticalCenter: parent.verticalCenter
            right: btnLayout.left
            rightMargin: 12
        }

        HoverHandler {
            id: hover
        }

        LightToolTip {
            visible: hover.hovered && sourceFileText.truncated
            tip: sourceFileText.text
            textWrapMode: Text.WrapAnywhere
            z: 200
        }
    }


    RowLayout {
        id: btnLayout
        spacing: 8
        anchors {
            verticalCenter: parent.verticalCenter
            right: parent.right
            rightMargin: 13
        }

        // 收藏
        IconButton {
            visible: !fileInvalid
            width: 31
            height: 22
            iconWidth: 16
            iconHeight: 16
            hoverColor: Colors.color_444444
            pressedColor: Colors.color_515151
            iconSource: favorate ? "qrc:/icons/quicklook/quicklook_favor.svg" :  "qrc:/icons/quicklook/quicklook_unfavor.svg"
            isHoverEnabled: true
            onClicked: favorateClicked()
        }

        // 去编辑
        IconTextButton {
            id: editBtn
            visible: !fileInvalid
            usePreferredWidth: false
            horPadding: 0
            leftPadding: 6
            rightPadding: 6
            topPadding: 2
            bottomPadding: 2

            title: qsTr("pccut_quicklook_edit_text")
            titleColorNormal: Colors.color_B1B1B1
            titleFontSize: 13
            titleFontWeight: 400

            backgroundColorNormal: Colors.color_transparent
            backgroundColorHover: Colors.color_444444
            backgroundColorPressed: Colors.color_515151

            borderWidth: 1
            borderColor: Colors.color_444444

            isTextOnly: true

            onCustomClicked: gotoEdit()
        }

        LightRectangle {
            id: closeButton
            width: 31
            height: 22
            radius: [6, 6, 6, 6]
            color: {
                if (mouseArea.pressed) return Colors.color_515151;
                if (mouseArea.containsMouse) return Colors.color_444444;
                return Colors.color_transparent;
            }

            Image {
                anchors.centerIn: parent
                width: 16
                height: 16
                source: "qrc:/icons/quicklook/quicklook_close.svg"
                sourceSize: Qt.size(width, height)
            }

            MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: customClosedClicked()
            }
        }
    }
}
