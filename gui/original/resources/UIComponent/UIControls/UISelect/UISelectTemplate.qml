import QtQuick
import QtQuick.Templates as T
import UIComponent

// UISelectTemplate — 继承于T.ComboBox 实现了除popup和delegate外的popup显示
// 单列和多列都继承该组件，如果单列和双列的Select能够满足不建议直接使用这个组件
// 如果使用该组件请设置正确的popup和delegate
T.ComboBox {
    id: root

    // ── 样式 ─────────────────────────────────────────────────────────
    property int size: UIControlSize.M
    readonly property var _style: UITheme.select.of(size)

    property color textColor:          _style.text.base
    property color textColorDisabled:  _style.text.disabled
    property color bgColor:            _style.bg.base
    property color bgColorDisabled:    _style.bg.disabled
    property color bgColorHovered:     _style.bg.hovered
    property color borderColor:        _style.border.base
    
    property color borderColorFocused: _style.border.focused
    property int   borderRadius:       _style.borderRadius
    property int   paddingH:           _style.paddingH
    property int  indicatorSize:     _style.indicatorSize   // indicator 图标尺寸

    implicitHeight: _style.height
    font.pixelSize: _style.fontSize
    hoverEnabled:   true
    opacity: root.enabled ? _indicatorOpacity : _indicatorOpacityDisabled

    
    readonly property real _indicatorOpacity:  _style.opacity.base
    readonly property real _indicatorOpacityDisabled: _style.opacity.disable

    readonly property color resolvedTextColor:
        enabled ? textColor : textColorDisabled
    readonly property color resolvedBgColor:{
        if (!enabled)            return bgColorDisabled
        if (hovered)             return bgColorHovered
        return bgColor
    }
    readonly property color resolvedBorderColor:
        activeFocus ? borderColorFocused : borderColor

    background: Rectangle {
        radius:       root.borderRadius
        color:        root.resolvedBgColor
        border.width: _style.borderWidth
        border.color: root.resolvedBorderColor
    }

    contentItem: Text {
        leftPadding:       root.paddingH
        rightPadding:      root.paddingH
        text:              root.displayText
        font:              root.font
        color:             root.resolvedTextColor
        anchors {
            left: root.left
            right: indicator.left
        }
        verticalAlignment: Text.AlignVCenter
        elide:             Text.ElideRight
        UITooltip {
            visible: parent.truncated && root.hovered
            text: parent.text
        }
    }

    indicator: Image {
            x:          root.width - width - root.paddingH
            y:          (root.height - height) / 2
            width:      root.indicatorSize
            height:     root.indicatorSize
            sourceSize: Qt.size(root.indicatorSize * 2, root.indicatorSize * 2)
            smooth:     true
            source:     (root.popup && root.popup.visible) ? UITheme.isolationIcon("menu_collapse.svg")
                                                           : UITheme.isolationIcon("menu_expand.svg") 
    }
}
