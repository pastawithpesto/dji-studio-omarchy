import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import UIComponent

// UIMenuItem —— 由 UIMenu 的 delegate 实例化，不直接使用。
// indicator (checkmark) / arrow (subMenu) 用 Loader 按需创建；
// 文字+快捷键双栏，状态机包含 hovered / pressed / disabled / checked。
MenuItem {
    id: root

    property int size: UIControlSize.M

    readonly property var _style: UITheme.menu.of(size)

    // ===== 9 态扁平字段 =====
    property color bgColor:               _style.bg.base
    property color bgColorHovered:        _style.bg.hovered
    property color bgColorPressed:        _style.bg.pressed
    property color bgColorDisabled:       _style.bg.disabled
    property color bgColorChecked:        _style.bg.checked
    property color bgColorCheckedHovered: _style.bg.checkedHovered
    property color bgColorCheckedPressed: _style.bg.checkedPressed
    property color bgColorFocused:        _style.bg.focused
    property color bgColorLoading:        _style.bg.loading

    property color textColor:               _style.text.base
    property color textColorHovered:        _style.text.hovered
    property color textColorPressed:        _style.text.pressed
    property color textColorDisabled:       _style.text.disabled
    property color textColorChecked:        _style.text.checked
    property color textColorCheckedHovered: _style.text.checkedHovered
    property color textColorCheckedPressed: _style.text.checkedPressed
    property color textColorFocused:        _style.text.focused
    property color textColorLoading:        _style.text.loading

    property color shortcutColor:         _style.shortcutText.base
    property color shortcutColorHovered:  _style.shortcutText.hovered
    property color shortcutColorDisabled: _style.shortcutText.disabled

    readonly property color resolvedBgColor: {
        if (!enabled)             return bgColorDisabled
        if (pressed && checked)   return bgColorCheckedPressed
        if (highlighted && checked) return bgColorCheckedHovered
        if (pressed)              return bgColorPressed
        if (highlighted)          return bgColorHovered
        if (checked)              return bgColorChecked
        return bgColor
    }
    readonly property color resolvedTextColor: {
        if (!enabled)             return textColorDisabled
        if (pressed && checked)   return textColorCheckedPressed
        if (highlighted && checked) return textColorCheckedHovered
        if (pressed)              return textColorPressed
        if (highlighted)          return textColorHovered
        if (checked)              return textColorChecked
        return textColor
    }
    readonly property color resolvedShortcutColor: {
        if (!enabled)    return shortcutColorDisabled
        if (highlighted) return shortcutColorHovered
        return shortcutColor
    }

    implicitHeight: _style.itemHeight
    leftPadding:  _style.paddingH
    rightPadding: _style.paddingH
    topPadding:    _style.paddingV
    bottomPadding: _style.paddingV
    spacing: _style.spacing

    indicator: Image {
        anchors.verticalCenter: root.verticalCenter
        anchors.left:           root.left
        anchors.leftMargin:     root._style.paddingV
        visible:                root.checkable && root.checked
        source:                 UITheme.isolationIcon(root._style.iconCheck)
        width:                  root._style.indicatorSize
        height:                 root._style.indicatorSize
        sourceSize.width:       root._style.indicatorSize * 2
        sourceSize.height:      root._style.indicatorSize * 2
    }

    arrow: Image {
        anchors.verticalCenter: root.verticalCenter
        anchors.right:          root.right
        anchors.rightMargin:    root._style.paddingV
        visible:                root.subMenu !== null
        source:                 UITheme.isolationIcon(root._style.iconArrow)
        width:                  root._style.arrowSize
        height:                 root._style.arrowSize
        rotation:               -90
        sourceSize.width:       root._style.arrowSize * 2
        sourceSize.height:      root._style.arrowSize * 2
    }

    contentItem: RowLayout {
        spacing: root._style.spacing
        // 给左侧 indicator 让位
        Item {
            implicitWidth: root.checkable ? root._style.indicatorSize + root._style.spacing : 0
        }
        Text {
            text: root.text
            font.pixelSize: root._style.fontSize
            color: root.resolvedTextColor
            verticalAlignment: Text.AlignVCenter
            Layout.fillWidth: true
            elide: Text.ElideRight
        }
        Text {
            visible: root.action !== null && root.action.shortcut !== undefined
                  && String(root.action.shortcut).length > 0
            text: root.action ? String(root.action.shortcut) : ""
            font.pixelSize: root._style.fontSize
            color: root.resolvedShortcutColor
            verticalAlignment: Text.AlignVCenter
        }
        // 给右侧 arrow 让位
        Item {
            implicitWidth: root.subMenu ? root._style.arrowSize + root._style.spacing : 0
        }
    }

    background: Rectangle {
        anchors {
            fill:    parent
            margins: root._style.bgMargin
        }
        radius: root._style.borderRadius
        color:  root.resolvedBgColor
    }
}
