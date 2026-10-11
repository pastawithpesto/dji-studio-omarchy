import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts

import UIComponent

Item {
    id: root
    anchors.fill: parent
    property alias tabViewAnchors: enumTabsView.anchors
    property var tabViewItemSpacing: 8

    property MenuPageViewModelProtocol viewModel: null

    EnumTabsView {
        id: enumTabsView

        spacing: root.tabViewItemSpacing
        viewModel: root.viewModel ? root.viewModel.tabsViewModel : null
    }

    // PageView
    ContainerComponent {
        id: pageView


        viewModel: root.viewModel ? root.viewModel.currentPageViewModel : null
    }
}
