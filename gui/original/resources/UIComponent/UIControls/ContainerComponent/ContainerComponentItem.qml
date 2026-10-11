import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts

import UIComponent

Item {
    id: root
    anchors.fill: parent

    property var viewModel: null

    Text {
        anchors.centerIn: parent
        text: "hello world"
    }
}
