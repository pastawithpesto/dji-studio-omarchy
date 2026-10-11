import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts

import UIComponent

Item {
    id: root
    anchors.fill: parent

    property Component background: null
    property ContainerComponentViewModel viewModel: null

    Loader {
        anchors.fill: parent
        sourceComponent: root.background
        active: root.background !== null
    }

    UIContainer {
        id: container
        viewModel: root.viewModel
    }
}
