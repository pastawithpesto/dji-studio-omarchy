import QtQuick
import QtQuick.Templates as T
import UIComponent

// UICheckBox
//   复选框。Templates 基类 CheckBox + ComponentToken (UITheme.checkBox.of(size))。
//   indicator 默认 Rectangle (resolvedBgColor 控制 9 态)；当 iconSourceChecked /
//   iconSourceUnchecked 任一非空，切到图标模式 (indicator 用 SVG)。
//   iconSourceChecked    checked 态图标，含此属性即图标模式
//   iconSourceUnchecked  unchecked 态图标，含此属性即图标模式
T.CheckBox {
    id: root

    property int size: UIControlSize.M
    property int type: UICheckBoxType.Dark

    readonly property var _style: UITheme.checkBox.of(size, type)

    // ===== 暴露的可覆盖口子 =====
    property color bgColor:            _style.bg.base
    property color bgColorHovered:     _style.bg.base
    property color bgColorDisabled:    _style.bg.disabled
    property color bgColorChecked:     _style.bg.checked
    property color bgColorCheckedHovered: _style.bg.checked

    property color textColor:          _style.text.base
    property color textColorDisabled:  _style.text.disabled

    property int   indicatorSize:      _style.indicatorSize
    property int   indicatorRadius:    _style.borderRadius
    property bool  borderVisible:      false
    property real  disabledOpacity:    _style.opacity.disable
    property real  maxTextWidth:       0  // 0 = 不限制；设置后文字超长时 ElideRight + hover tooltip

    property url   iconSourceChecked: ""
    property url   iconSourceUnchecked: ""
    readonly property bool _isIconMode: iconSourceChecked.toString().length > 0 || iconSourceUnchecked.toString().length > 0

    hoverEnabled: true

    spacing: _style.spacing
    leftPadding:   text.length > 0 ? indicatorSize + spacing : indicatorSize
    rightPadding:  0
    topPadding:    0
    bottomPadding: 0

    implicitWidth:  leftPadding + (maxTextWidth > 0 ? maxTextWidth : (contentItem ? contentItem.implicitWidth : 0)) + rightPadding
    implicitHeight: Math.max(indicatorSize, contentItem ? contentItem.implicitHeight : 0)

    font.pixelSize: _style.fontSize

    // ===== resolvedXxx 状态机 =====
    readonly property color resolvedBgColor: {
        if (!enabled)            return bgColorDisabled
        if (hovered && checked)  return bgColorCheckedHovered
        if (checked)             return bgColorChecked
        if (hovered)             return bgColorHovered
        return bgColor
    }
    readonly property color resolvedTextColor:
        enabled ? textColor : textColorDisabled

    readonly property url _resolvedIndicatorIcon: {
        if (_isIconMode) return checked ? iconSourceChecked : iconSourceUnchecked
        if (checked) return UITheme.isolationIcon(_style.icon.checked)
        return ""
    }

    indicator: Item {
        x: 0
        y: (root.height - height) / 2
        implicitWidth:  root.indicatorSize
        implicitHeight: root.indicatorSize
        opacity: !root.enabled ? root.disabledOpacity : 1.0

        Loader {
            active: !root._isIconMode
            anchors.fill: parent
            anchors.margins: root._isIconMode ? 0 : 1
            sourceComponent: Component {
                Rectangle {
                    radius: root.indicatorRadius
                    color: root.resolvedBgColor
                    border.width: root.borderVisible && !root.checked ? 1 : 0
                    border.color: UIColors.colorFillDark3
                }
            }
        }

        Loader {
            active: root._resolvedIndicatorIcon.toString().length > 0
            anchors.fill: parent
            anchors.margins: root._isIconMode ? 0 : 1
            sourceComponent: Component {
                Image {
                    source: root._resolvedIndicatorIcon
                    sourceSize: Qt.size(width, height)
                    smooth: true
                }
            }
        }
    }

    contentItem: UIText {
        text: root.text
        font: root.font
        verticalAlignment: Text.AlignVCenter
        color: root.resolvedTextColor
        elide: Text.ElideRight
        width: root.maxTextWidth > 0 ? root.maxTextWidth : implicitWidth
    }
}
