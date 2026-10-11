import QtQuick
import QtQuick.Controls
import QtQuick.Window
import UIComponent

// 用法：作为触发元素的子 Item，通过 visible 绑定 hover 状态。
//
//   UITooltip { visible: hover.hovered; text: "提示文字" }
//
// 多行模式：
//   UITooltip {
//       visible: hover.hovered
//       lines: [
//           { text: "第一行", color: UIColors.colorTextPrimary, size: 12 },
//           { text: "第二行", color: UIColors.colorTextSecondary, size: 11 }
//       ]
//   }
ToolTip {
    id: root

    property var lines: []   // 多行模式：[{ text, color?, size? }]
    property int animDuration: 300

    readonly property bool _multiline: Array.isArray(lines) && lines.length > 0

    x: parent ? (parent.width - width) / 2 : 0
    y: parent ? parent.height + UISize.sizeXS : 0

    padding: 0
    leftPadding:   UISize.sizeSM
    rightPadding:  UISize.sizeSM
    topPadding:    UISize.size6
    bottomPadding: UISize.size6

    // 取自 qml/controls/LightToolTip.qml：500ms 延迟 + 300ms 渐入渐出
    delay: 500
    timeout: -1
    closePolicy: Popup.NoAutoClose

    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: root.animDuration }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; from: 1; to: 0; duration: root.animDuration }
    }

    onAboutToShow: _adjustPosition()

    function _adjustPosition() {
        if (!parent) return
        var gp = parent.mapToGlobal(x, y)
        var sw = Screen.width
        var sh = Screen.height
        if (gp.x + width > sw)
            x = x - (gp.x + width - sw) - UISize.sizeXS
        if (gp.y + height > sh)
            y = -(height + UISize.sizeXS)
    }

    background: Rectangle {
        color:        UIColors.colorBgTooltip
        border.color: UIColors.colorBorderTooltip
        border.width: 0.5
        radius:       UISize.borderRadiusSM
    }

    contentItem: Column {
        spacing: UISize.sizeXS

        // 单行模式
        Text {
            visible:        !root._multiline
            text:           root.text
            color:          UIColors.colorTextLightSolid
            font.pixelSize: UIFonts.fontSizeS
            wrapMode:       Text.WrapAnywhere
        }

        // 多行模式
        Repeater {
            model: root._multiline ? root.lines : null
            Text {
                text:           modelData.text  || ""
                color:          modelData.color || UIColors.colorTextLightSolid
                font.pixelSize: modelData.size  || UIFonts.fontSizeS
            }
        }
    }
}
