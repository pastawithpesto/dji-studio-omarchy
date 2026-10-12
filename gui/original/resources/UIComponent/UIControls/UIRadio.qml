import QtQuick
import QtQuick.Templates as T
import UIComponent

// UIRadio
//   单选按钮。Templates 基类 RadioButton + ComponentToken (UITheme.radio.of(size))。
//   iconSource         未选中态图标
//   iconSourceChecked  选中态图标
T.RadioButton {
    id: root

    property int size: UIControlSize.M

    readonly property var _style: UITheme.radio.of(size)

    property string iconSource:        UITheme.isolationIcon(_style.icon.base)
    property string iconSourceChecked: UITheme.isolationIcon(_style.icon.checked)

    property color textColor:         _style.text.base
    property color textColorDisabled: _style.text.disabled

    property int indicatorSize: _style.indicatorSize
    property real disabledOpacity: _style.opacity.disable

    hoverEnabled: true

    spacing: _style.spacing
    leftPadding:   indicatorSize + spacing
    rightPadding:  0
    topPadding:    0
    bottomPadding: 0

    implicitWidth:  leftPadding + (contentItem ? contentItem.implicitWidth : 0) + rightPadding
    implicitHeight: Math.max(indicatorSize, contentItem ? contentItem.implicitHeight : 0)

    font.pixelSize: _style.fontSize

    readonly property color resolvedTextColor:
        enabled ? textColor : textColorDisabled

    indicator: Image {
        x: 0
        y: (root.height - height) / 2
        width:  root.indicatorSize
        height: root.indicatorSize
        sourceSize: Qt.size(width, height)
        smooth: true
        opacity: root.enabled ? 1.0 : root.disabledOpacity
        source: root.checked ? root.iconSourceChecked : root.iconSource
    }

    contentItem: Text {
        text: root.text
        font: root.font
        verticalAlignment: Text.AlignVCenter
        color: root.resolvedTextColor
    }
}
