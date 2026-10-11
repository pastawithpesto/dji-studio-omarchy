import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.15

import Controls 1.0
import Config 1.0

Item { // 自定义的标题栏
    id: titleBar
    height: 40
    width: parent.width
    property alias title: titleTxt.text
    signal closeClick
    Item {
        anchors.top: parent.top
        height: 39.5
        width: parent.width
        RowLayout {
            visible: !CommonUtils.isWindows()
            anchors {
                verticalCenter: parent.verticalCenter
                left: parent.left
                leftMargin: 18
            }

            ImageButton {
                Layout.preferredHeight: 12
                Layout.preferredWidth: 12
                normalImage: "qrc:/icons/appbar/btn_close_normal.svg"
                hoveredImage: "qrc:/icons/appbar/btn_close_hovered.svg"
                pushedImage: "qrc:/icons/appbar/btn_close_pushed.svg"
                onClicked: closeClick()
            }
        }
        RowLayout {
            visible: CommonUtils.isWindows()
            anchors {
                verticalCenter: parent.verticalCenter
                right:parent.right
                rightMargin:12
            }
            IconButton {
                id: btn_close
                width: 20
                height: 20
                iconMargins:0
                normalColor: Colors.transparent
                hoverColor: Colors.transparent
                pressedColor: Colors.transparent
                disableColor: Colors.transparent
                iconSource: "qrc:/icons/WindowsIcon/icon_close_modal.svg"
                hoverIconSource: "qrc:/icons/WindowsIcon/icon_close_modal_hover.svg"

                onClicked: closeClick()
            }
        }
    }

    Text {
        id: titleTxt
        text: qsTr("pccut_menu_about")
        color: Colors.color_FFFFFF
        font.pixelSize: 12
        anchors.centerIn: parent
    }

    BaseSpliter { // 标题栏分隔线
        id: bottomLine
        anchors.bottom: parent.bottom
        width: parent.width
    }
}
