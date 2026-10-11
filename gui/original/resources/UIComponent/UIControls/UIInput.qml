import QtQuick
import QtQuick.Templates as T
import UIComponent

// UIInput
//   单行文本输入框。Templates 基类 TextField + ComponentToken (UITheme.input.of(size))。
//   borderVisible  控制边框显隐
//   suffix         右侧 Row 槽 (子项 = suffix 元素，如清除按钮、单位文字)
T.TextField {
    id: root

    property int size: UIControlSize.M
    property alias suffix: suffixSlot.data    // 右侧 suffix 槽（如 clear 按钮、单位文字）
    property bool borderVisible: false

    hoverEnabled: true
    verticalAlignment: TextInput.AlignVCenter

    readonly property var _style: UITheme.input.of(size)

    // ===== 暴露的可覆盖口子 =====
    property color textColor:         _style.text.base
    property color textColorDisabled: _style.text.disabled

    property color bgColor:           _style.bg.base
    property color bgColorDisabled:   _style.bg.disabled

    property color borderColor:       _style.border.base
    property color borderColorFocused:_style.border.focused
    property int   borderRadius:      _style.borderRadius
    property int   paddingH:          _style.paddingH

    implicitHeight: _style.height
    //implicitWidth:  implicitContentWidth + leftPadding + rightPadding

    leftPadding:  paddingH
    rightPadding: paddingH + suffixSlot.implicitWidth
                  + (suffixSlot.implicitWidth > 0 ? UISize.size : 0)
    topPadding:    0
    bottomPadding: 0

    font.pixelSize: _style.fontSize

    // ===== resolvedXxx 状态机 =====
    readonly property color resolvedTextColor:
        enabled ? textColor : textColorDisabled

    readonly property color resolvedBgColor:
        enabled ? bgColor : bgColorDisabled

    readonly property color resolvedBorderColor:
        activeFocus ? borderColorFocused : borderColor

    color:                resolvedTextColor
    placeholderTextColor: UIColors.gray6
    selectionColor:       _style.selectionColor
    selectedTextColor:    _style.selectedTextColor

    background: Rectangle {
        radius: root.borderRadius
        color:  root.resolvedBgColor
        border.width: root.borderVisible ? 1 : 0
        border.color: root.resolvedBorderColor
    }

    UIText {
        x: root.leftPadding
        width: root.width - root.leftPadding - root.rightPadding
        height: root.height
        text: root.placeholderText
        color: root.placeholderTextColor
        font: root.font
        horizontalAlignment: root.horizontalAlignment
        verticalAlignment: Text.AlignVCenter
        visible: !root.length && !root.preeditText
        elide: Text.ElideRight
    }

    Row {
        id: suffixSlot
        anchors.right: parent.right
        anchors.rightMargin: root._style.paddingH
        anchors.verticalCenter: parent.verticalCenter
        spacing: UISize.sizeXS
    }
}
