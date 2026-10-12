import QtQuick
import QtQuick.Controls
import QtQuick.Templates as T
import UIComponent

// UISelectPopup — 单列下拉弹窗

T.Popup {
    id: root

    property int size: UIControlSize.M
    readonly property var _style: UITheme.select.of(size)
    required property real controlHeight // ComboBox 自身高度
    required property real controlWidth  // ComboBox 宽度
    required property var delegateModel
    required property int currentIndex

    property int maxHeight: _style.popMaxH
    property int popOffsetY: _style.popOffsetY
    // ── 样式常量 ────────────────────────────
    readonly property int   _borderW:  _style.borderWidth
    readonly property color _divColor: _style.popBorder
    readonly property color _bgColor:  _style.popBg
    

    y:       controlHeight + root.popOffsetY
    width:   controlWidth
    padding: 0 // popup有默认的非零的padding，这里会影响样式
    height:  Math.min(contentItem.contentHeight, maxHeight)
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

    background: Rectangle {
        color:        root._bgColor
        radius:       UISize.borderRadius
        border.width: root._borderW
        border.color: root._divColor
    }

    contentItem: ListView {
        clip:            true
        model:           root.delegateModel
        currentIndex:    root.currentIndex
        boundsBehavior:  Flickable.StopAtBounds
        highlightMoveDuration: 0
        ScrollBar.vertical: UIScrollBar { policy: ScrollBar.AsNeeded }
    }

    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 300 }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 300 }
    }
}
