import QtQuick
import UIComponent

Item {
    id: root
    property var viewModel: null

    Rectangle {
        anchors.fill: parent
        color: "transparent"

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: UIColors.colorFillDark5
        }

        UIText {
            anchors.centerIn: parent
            text: root.viewModel ? ("Section " + root.viewModel.sectionIndex + " End") : ""
            color: UIColors.colorTextTertiary
            size: UIControlSize.M
        }
    }
}
