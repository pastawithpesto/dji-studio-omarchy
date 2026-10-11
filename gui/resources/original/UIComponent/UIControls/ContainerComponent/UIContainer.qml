import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts

import UIComponent

Item {
    id: root
    anchors.fill: parent
    property UIContainerViewModel viewModel: null

    property var preViewModel: null
    property bool finishInit: false

    onViewModelChanged: {
        if(!root.finishInit) {
            return
        }

        if (root.preViewModel) {
            root.preViewModel.containerItem = null
        }
        
        root.preViewModel = root.viewModel
        if (root.viewModel) {
            root.viewModel.containerItem = root
        }
    }

    Component.onCompleted: {
        root.finishInit = true
        if (root.viewModel) {
            root.viewModel.containerItem = root
        }
    }
}
