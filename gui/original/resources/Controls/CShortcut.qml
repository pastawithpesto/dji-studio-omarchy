import QtQuick 2.15
import QtQuick.Window 2.15
import ShortcutHandler 1.0

Item {
    id: root

    // 只能初始化的时候设置，之后再修改就不会生效了，这里其实对应的是C++的ShortcutAction::Action
    property string action

    // 调用方可通过 enabled 表达式加自己的门控（如 enabled: someCondition）。
    // 窗口级隔离由 C++ 侧完成：CShortcut 把所在 Window 传给 ShortcutHandler.ownerWindow，
    // ShortcutObserver 分发时用 QGuiApplication::focusWindow() 比对。
    // 适用范围：仅对独立 QQuickWindow 弹窗（如 MaterialReplaceWindow、CustomWindow 派生
    // 的偏好设置/关于/快捷键设置窗）生效——弹窗打开时 focusWindow 切到弹窗、主窗口
    // handler 的 ownerWindow ≠ focusWindow 而被跳过。
    // 不覆盖：基于 QtQuick.Controls Popup（含 LightPopup）的 Overlay 弹窗与主窗口同属
    // 一个 QQuickWindow，弹窗内 Item 的 Window.window 仍指向主窗口，focusWindow 也不变，
    // 因此 ownerWindow 完全一致、不做隔离。若 Overlay 弹窗与主窗口注册了同一 action 的
    // CShortcut，会同时触发（双执行）。当前工程内 ESCAPE_FULL_SCREEN 有多处 Overlay 弹窗
    // 与主窗口重复注册（TrackMaskPopup / VideoStitcherCorrectionLoadingMask / PlayerPanel /
    // AppBar / DevicePanel），依赖各处 enabled 门控（visible / 全屏状态 / 追踪状态）互斥来
    // 避免冲突——新增 Overlay 场景的同 action CShortcut 时须自行确保 enabled 表达式与其他
    // 注册者互斥，或另寻隔离机制。
    property alias enabled: handler.enabled
    property alias priority: handler.priority
    property alias isDefault: handler.isDefault

    signal activated(string sequence)

    ShortcutHandler {
        id: handler
        // Window.window 是 attached property，会随 root 移入/移出 window 自动更新。
        ownerWindow: root.Window.window

        onShortcutActivated: (sequence) => {
            activated(sequence);
        }
    }

    Component.onCompleted: {
        ShortcutObserver.registerHandler(action, handler)
    }
}
