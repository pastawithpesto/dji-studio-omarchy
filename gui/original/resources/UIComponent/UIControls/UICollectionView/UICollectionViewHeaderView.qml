import QtQuick
import UIComponent

Item {
    id: root
    property var viewModel: null

    Rectangle {
        anchors.fill: parent
        color: "transparent"

        UIText {
            anchors.left: parent.left
            anchors.leftMargin: UISize.sizeXS
            anchors.verticalCenter: parent.verticalCenter
            text: root.viewModel ? root.viewModel.title : ""
            color: UIColors.colorTextPrimary
            size: UIControlSize.XL
            type: UITextType.Primary
        }

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: UIColors.colorFillDark5
        }
    }
}
