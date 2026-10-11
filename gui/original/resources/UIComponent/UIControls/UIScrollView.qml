import QtQuick
import QtQuick.Templates
import UIComponent

// Fusion 的 ScrollView.qml 在 `ScrollBar.vertical/horizontal` 内联里手写了
// parent / x / y / height / active 互锁——这是 Fusion 模板的视觉默认，**不是**
// Qt 通用机制；attached 槽位只负责 size / position 自动绑。派生 ScrollView 改
// 用自己的 ScrollBar 实例时，这套内联布局必须完整复刻，否则实例落到 window
// 根 visual parent 的 (0,0)，按 implicitWidth × implicitHeight 渲染成左上角圆点。

ScrollView {
    id: root
    clip: true

    // implicitHeight and implicitHeight copy from Quick.Controls.Fusions
    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            contentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             contentHeight + topPadding + bottomPadding)

    Component.onCompleted: root.contentItem.boundsBehavior = Flickable.StopAtBounds

    ScrollBar.vertical: UIScrollBar {
        x: root.mirrored ? 0 : root.width - width
        y: root.topPadding
        height: root.availableHeight
        active: root.ScrollBar.horizontal.active
    }

    ScrollBar.horizontal: UIScrollBar {
        x: root.leftPadding
        y: root.height - height
        width: root.availableWidth
        active: root.ScrollBar.vertical.active
    }
}
