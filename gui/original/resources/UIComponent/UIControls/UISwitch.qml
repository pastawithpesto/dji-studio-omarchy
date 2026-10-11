import QtQuick
import QtQuick.Templates as T
import UIComponent

// UISwitch
//   开关。Templates 基类 Switch + ComponentToken (UITheme.lightSwitch.of(size))。
//   track 颜色走 9 态 resolvedTrackColor，thumb 用 200ms 动画位移。
//   toggleDuration  切换动画时长，默认 200ms
T.Switch {
    id: root

    property int size: UIControlSize.M

    readonly property var _style: UITheme.lightSwitch.of(size)

    property color trackColor:             _style.track.base
    property color trackColorHovered:      _style.track.base
    property color trackColorDisabled:     _style.track.disabled
    property color trackColorChecked:      _style.track.checked
    property color trackColorCheckedHovered: _style.track.checked

    property color textColor:              _style.text.base
    property color textColorDisabled:      _style.text.disabled

    property color thumbColor:             _style.thumbColor

    property int   trackWidth:       _style.trackWidth
    property int   trackHeight:      _style.trackHeight
    property real  trackBorderWidth: 0.5
    property color trackBorderColor: Qt.rgba(1, 1, 1, 0.1)
    property real  disabledOpacity: _style.opacity.disable

    hoverEnabled: true

    spacing: _style.spacing
    leftPadding:   text.length > 0 ? trackWidth + spacing : trackWidth
    rightPadding:  0
    topPadding:    0
    bottomPadding: 0

    implicitWidth:  leftPadding + (contentItem ? contentItem.implicitWidth : 0) + rightPadding
    implicitHeight: Math.max(trackHeight, contentItem ? contentItem.implicitHeight : 0)

    font.pixelSize: _style.fontSize

    // ===== resolvedXxx 状态机 =====
    readonly property color resolvedTrackColor: {
        if (!enabled && checked)  return trackColorChecked
        if (!enabled)            return trackColorDisabled
        if (hovered && checked)  return trackColorCheckedHovered
        if (checked)             return trackColorChecked
        if (hovered)             return trackColorHovered
        return trackColor
    }
    readonly property color resolvedTextColor:
        enabled ? textColor : textColorDisabled

    readonly property int toggleDuration: 200

    indicator: Rectangle {
        id: track
        x: 0
        y: (root.height - height) / 2
        implicitWidth:  root.trackWidth
        implicitHeight: root.trackHeight
        radius: height / 2
        antialiasing: true
        color: root.resolvedTrackColor
        border.width: root.trackBorderWidth
        border.color: root.trackBorderColor
        opacity: root.enabled ? 1.0 : root.disabledOpacity

        Behavior on color {
            ColorAnimation { duration: root.toggleDuration }
        }

        Rectangle {
            id: thumb
            width:  track.height - 2
            height: width
            radius: width / 2
            antialiasing: true
            y: 1
            x: root.checked ? track.width - width - 1 : 1
            color: root.thumbColor

            Behavior on x {
                NumberAnimation { duration: root.toggleDuration; easing.type: Easing.InOutQuad }
            }
        }
    }

    contentItem: Text {
        text: root.text
        font: root.font
        verticalAlignment: Text.AlignVCenter
        color: root.resolvedTextColor
    }
}
