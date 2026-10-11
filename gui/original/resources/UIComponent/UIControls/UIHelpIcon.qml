import QtQuick
import UIComponent

// UIHelpIcon
//   ? 图标 + hover 触发 tooltip。设计为纯被动展示，无 disabled / pressed 态。
//   tip                纯文本 tooltip 内容
//   iconSize           图标尺寸，默认 14
//   resolvedIconSource hover 时切换到 help_hover.svg
Item {
    id: root

    property string tip: ""
    property real iconSize: 16

    readonly property url resolvedIconSource: {
        if (!enabled) return UITheme.isolationIcon("button/Button_Help_Disabled.svg")
        return hover.hovered
            ? UITheme.isolationIcon("button/Button_Help_Hover.svg")
            : UITheme.isolationIcon("button/Button_Help_Default.svg")
    }

    implicitWidth:  iconSize
    implicitHeight: iconSize

    Image {
        id: icon
        anchors.fill: parent
        sourceSize: Qt.size(width, height)
        smooth: true
        source: root.resolvedIconSource
    }

    HoverHandler { id: hover }

    UITooltip {
        visible: hover.hovered && root.tip.length > 0
        text:    root.tip
        delay:   400
    }
}
