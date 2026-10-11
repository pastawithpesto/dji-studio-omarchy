import QtQuick
import QtQuick.Controls

import UIComponent


Rectangle {
    id: tabItem

    property EnumTabItemProtocol tabItemViewModel: modelData
    property var tabItemConfig: tabItemViewModel ? tabItemViewModel.config : null
    property bool isSelected: tabItem.ListView.view ? tabItem.ListView.view.selectedIndex === index : false
    property bool isHovered: false

    width: tabText.implicitWidth + root.tabHorizontalPadding * 2
    height: tabText.implicitHeight + root.tabVerticalPadding * 2

    color: {
        if (!tabItemConfig) return "transparent"
        if (isSelected) {
            return isHovered ? tabItemConfig.selectedHoveredBackgroundColor : tabItemConfig.selectedBackgroundColor
        } else {
            return isHovered ? tabItemConfig.unselectedHoveredBackgroundColor : tabItemConfig.unselectedBackgroundColor
        }
    }

    border.color: {
        if (!tabItemConfig) return "transparent"
        if (isSelected) {
            return isHovered ? tabItemConfig.selectedHoveredBorderColor : tabItemConfig.selectedBorderColor
        } else {
            return isHovered ? tabItemConfig.unselectedHoveredBorderColor : tabItemConfig.unselectedBorderColor
        }
    }

    border.width: tabItemConfig ? (isSelected ? tabItemConfig.selectedBorderWidth  : tabItemConfig.unselectedBorderWidth)  : 0
    radius:       tabItemConfig ? (isSelected ? tabItemConfig.selectedBorderRadius  : tabItemConfig.unselectedBorderRadius) : 0

    Text {
        id: tabText
        anchors.centerIn: parent

        text: tabItemConfig ? tabItemConfig.name : ""
        color: {
            if (!tabItemConfig) return "transparent"
            if (tabItem.isSelected) {
                return tabItem.isHovered ? tabItemConfig.selectedHoveredTextColor : tabItemConfig.selectedTextColor
            } else {
                return tabItem.isHovered ? tabItemConfig.unselectedHoveredTextColor : tabItemConfig.unselectedTextColor
            }
        }
        font: tabItemConfig ? tabItemConfig.font : Qt.application.font
    }

    Rectangle {
        id: redBot
        width: 5
        height: 5
        radius: 2.5
        anchors.left: tabText.right
        anchors.leftMargin: UISize.sizeXS
        anchors.top: tabText.top
        color: UIColors.colorRedDot
        visible: tabItemConfig ? tabItemConfig.redDot : false
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true

        onEntered: tabItem.isHovered = true
        onExited: tabItem.isHovered = false

        onClicked: {
            if (viewModel) {
                tabItem.ListView.view.tabViewModel.selectedIndex = index
            }
        }
    }
}
