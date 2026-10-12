import QtQuick
import QtQuick.Controls
import QtQuick.Window
import UIComponent

// UIMenu —— 上下文 / 下拉菜单容器
// 设计契约 / 设计思路：见 docs/COMPONENT_SPEC.md（命名 / 状态 / resolvedXxx / ComponentToken）。
//
// 用法:
//   UIButton {
//       text: "操作"
//       onClicked: menu.open()
//       UIMenu {
//           id: menu
//           Action { text: "新建"; shortcut: "Ctrl+N" }
//           Action { text: "保存"; shortcut: "Ctrl+S"; onTriggered: ... }
//       }
//   }
//
//   右键上下文菜单：
//   TapHandler { acceptedButtons: Qt.RightButton; onTapped: ctxMenu.popup() }
//   UIMenu { id: ctxMenu; size: UIControlSize.M; ... }
Menu {
    id: root

    // ===== 变体 =====
    property int type: UIButtonType.White
    property int size: UIControlSize.M

    readonly property var _style: UITheme.menu.of(size)

    // ===== 暴露容器壳层字段（业务可覆盖）=====
    property color bgColor:     _style.menuBg
    property color borderColor: _style.menuBorder
    property int   menuBorderWidth: _style.menuBorderWidth
    property int   menuRadius:      _style.menuRadius
    property int   fontSize:        _style.fontSize

    readonly property color resolvedBgColor:     bgColor
    readonly property color resolvedBorderColor: borderColor

    // 动态测量菜单项文字最大宽度，参考 LightMenu 的做法
    property real _maxTextWidth: 0

    TextMetrics {
        id: _tm
        font.pixelSize: root.fontSize
    }

    Component.onCompleted: {
        for (let i = 0; i < count; i++) {
            const mi = itemAt(i)
            if (!mi) continue
            _tm.text = mi.text ?? ""
            _maxTextWidth = Math.max(_maxTextWidth, _tm.width)
        }
    }

    // 动态宽度：文字宽度 + 左右 padding + indicator/arrow 预留空间
    implicitWidth: Math.max(_maxTextWidth + _style.paddingH * 2 + _style.indicatorSize + _style.arrowSize,
                            _style.minWidth)
    verticalPadding: _style.verticalPadding

    background: Rectangle {
        color:        root.resolvedBgColor
        radius:       root.menuRadius
        border.width: root.menuBorderWidth
        border.color: root.resolvedBorderColor
        implicitWidth: root.implicitWidth
    }

    // Fusion Menu.qml 的 contentItem 把溢出滚动条写成 ScrollIndicator{}（系统视觉），
    // 与库内其他容器统一走 UIScrollBar 不一致。覆写 contentItem 须按 §8.8 完整复刻
    // Fusion 的 ListView inline 默认（implicitHeight/model/interactive/clip/currentIndex），
    // 否则 Action 子项无法显示。ListView 是 Flickable，attached ScrollBar 走 C++ 自动布局，
    // 不需要再复刻 ScrollBar 的几何 inline。
    contentItem: ListView {
        implicitHeight: contentHeight
        model:          root.contentModel
        interactive:    Window.window
                            ? contentHeight + root.topPadding + root.bottomPadding > Window.window.height
                            : false
        clip:           true
        currentIndex:   root.currentIndex
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: UIScrollBar { policy: ScrollBar.AsNeeded }
    }

    delegate: UIMenuItem {
        size: root.size
    }
}
