import QtQuick 2.15
import QtQuick.Controls
import Config 1.0

Menu {
    id: baseMenu
    property int menuWidth:132
    property real maxItemTextWidth: 0
    property bool showCheckable:false
    //暴漏菜单圆角属性
    property int menuRadius: 8
    //暴露子项圆角属性
    property int itemRadius: 4
    //暴露子项高亮颜色
    property color itemHighlighted: Colors.color_303233
    //暴露文字大小
    property int itemFontSize: 12
    //IconButton 距离菜单左侧边距
    property int checkBtnLeftMargin: 7
    //菜单文本 距离菜单栏左侧边距
    property int contentTextLeftMargin: 31
    //菜单快捷键文本 距离菜单栏右侧边距
    // property int contentActionRightMargin:
    //content距离菜单栏右侧边距
    property int contentRightMargin: 16
    //暴露禁选时的文字颜色
    property color disableEnableTextColor: "transparent"

    property string disabledCheckIconSource: ""
    //暴露iconMargins
    property int iconBtnMargins: 2
    // 子项是否"可用"（仅影响外观，不禁用交互，保留hover高亮）
    property bool subItemsEnabled: true

    verticalPadding:2
    background: Rectangle {
        color: Colors.color_141414
        implicitWidth: baseMenu.implicitWidth
        border.width: 1
        border.color: Colors.color_444444
        radius:menuRadius
    }
    TextMetrics {
        id: textMetrics
        font.pixelSize: 12
    }
    implicitWidth: Math.max(maxItemTextWidth + 32, menuWidth)
    Component.onCompleted: {
        for (var i = 0; i < count; i++) {
            var item = baseMenu.itemAt(i)
            textMetrics.text = CommonUtils.isNull(item.text) ? "" : item.text
            maxItemTextWidth = Math.max(maxItemTextWidth, textMetrics.width)
        }
    }
    delegate: MenuItem {
        id: menuItem
        readonly property bool itemDisabled: {
            var itemActive = action ? action.enabled : true
            var isFirstItem = baseMenu.count > 0 && menuItem === baseMenu.itemAt(0)
            return !itemActive || (!subItemsEnabled && !isFirstItem)
        }
        readonly property real itemOpacity: itemDisabled ? (disableEnableTextColor.a === 0 ? 0.3 : 1) : 1
        readonly property color itemColor: itemDisabled ? (disableEnableTextColor.a === 0 ? Colors.color_EEEEEE : disableEnableTextColor) : Colors.color_EEEEEE

        implicitWidth: baseMenu.implicitWidth
        implicitHeight: 34
        indicator: IconButton {
            anchors.verticalCenter: menuItem.verticalCenter
            anchors.left:menuItem.left
            anchors.leftMargin: checkBtnLeftMargin
            id: minButton
            width: 16
            height: 16
            iconMargins: iconBtnMargins
            normalColor: Colors.transparent
            hoverColor: Colors.transparent
            pressedColor: Colors.transparent
            disableColor: Colors.transparent
            visible:showCheckable && menuItem.action.checked
            enabled: false
            // indicator 的 iconSource 改为
            iconSource: {
                var isFirstItem = baseMenu.count > 0 && menuItem === baseMenu.itemAt(0)
                if (action && !action.enabled && disabledCheckIconSource !== "") {
                    return disabledCheckIconSource
                } else if (!subItemsEnabled && disabledCheckIconSource !== "" && !isFirstItem) {
                    return disabledCheckIconSource
                } else {
                    return "qrc:/icons/WindowsIcon/icon_select.svg"
                }
            }
        }
        arrow: Image {
            anchors.right: menuItem.right
            anchors.verticalCenter: menuItem.verticalCenter
            anchors.rightMargin:8
            visible: menuItem.subMenu
            source: "qrc:/icons/WindowsIcon/icon_next.svg"
            sourceSize: Qt.size(20, 20)
            asynchronous: true
        }
        contentItem: Item {
            id:content
            anchors {
                left:menuItem.left
                right:menuItem.right
                verticalCenter: menuItem.verticalCenter
                rightMargin:contentRightMargin
            }
            Text{
                lineHeight:16
                anchors.left:parent.left
                anchors.leftMargin:showCheckable?contentTextLeftMargin:16
                anchors.right: shortcutText.left
                anchors.rightMargin: shortcutText.implicitWidth > 0 ? 8 : 0
                anchors.top: parent.top
                anchors.topMargin: 3
                elide: Text.ElideRight
                text: menuItem.text
                font.pixelSize: itemFontSize
                opacity: itemOpacity
                color: itemColor
            }

            Text{
                id: shortcutText
                lineHeight:16
                anchors.right:parent.right
                anchors.top: parent.top
                anchors.topMargin: 3
                text: action?(action.shortcut?action.shortcut:""):""
                font.pixelSize: itemFontSize
                opacity: itemOpacity
                color: itemColor
            }

        }
        background: Rectangle {
            anchors {
                left: parent.left
                right: parent.right
                leftMargin: 4  // 设置左边距
                rightMargin: 4  // 设置右边距
                top:parent.top
                bottom:parent.bottom
                topMargin:4
                bottomMargin:4

            }
            radius: baseMenu.itemRadius
            // color: menuItem.highlighted  ? Colors.color_303233 : Colors.transparent
            color: menuItem.highlighted  ? itemHighlighted : Colors.transparent
        }
    }
}
