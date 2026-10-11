import QtQuick
import UIComponent

// UIMultiDelegateTemplate — 多列级联弹窗专用条目 delegate
//
// 在 UIDelegateTemplate 视觉基础上，将 hover / click 以信号对外暴露，
// 供 UISelectMultiPopup 接线驱动列联动逻辑。
// 参考 DoubleListPopup 的「每个 delegate 自己管理鼠标事件」模式：
// MouseArea 放在 delegate 内部，不在 ListView 上铺覆盖层，
// 与 Flickable 滚动天然无冲突。

UIDelegateTemplate {
    id: root

    signal itemHovered(int index)
    signal itemClicked(int index)
    // 这里使用MouseArea的原因是TapHandler和Flickable（ListView）组件存在冲突
    MouseArea {
        id: _mouseArea
        anchors.fill:    parent
        hoverEnabled:    true
        preventStealing: false

        onEntered: {
            root.ListView.view.currentIndex = root.index
            root.itemHovered(root.index)
        }

        onClicked: root.itemClicked(root.index)
    }
}
