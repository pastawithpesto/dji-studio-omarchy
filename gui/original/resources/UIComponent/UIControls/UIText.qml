import QtQuick
import UIComponent

// UIText
//   文本展示。Text 基类 + ComponentToken (UITheme.text.of(size, type))。
//   truncated hover 自动弹 UITooltip；copyable=true 切到 TextEdit 可选可复制。
//   type      UITextType.Primary / Secondary / Emphasize / ...
//   copyable  true 时文本可选可复制
Text {
    id: root

    property int type: UITextType.Primary
    property int size: UIControlSize.M
    property bool copyable: false

    readonly property var _style: UITheme.text.of(size, type)
    readonly property color resolvedColor: enabled ? _style.color : UIColors.colorTextDisabled

    color: copyable ? "transparent" : resolvedColor
    font.pixelSize: _style.fontSize
    //lineHeight: _style.lineHeight
    //lineHeightMode: Text.FixedHeight
    verticalAlignment: Text.AlignVCenter

    HoverHandler { id: _hover }

    UITooltip {
        visible: root.truncated && _hover.hovered
        text: root.text
    }

    Loader {
        active: root.copyable
        anchors.fill: parent
        clip: true
        sourceComponent: TextEdit {
            text: root.text
            color: root.resolvedColor
            font: root.font
            readOnly: true
            selectByMouse: true
            selectionColor: UITheme.brand
            wrapMode: root.wrapMode
            verticalAlignment: TextEdit.AlignVCenter
        }
    }
}
