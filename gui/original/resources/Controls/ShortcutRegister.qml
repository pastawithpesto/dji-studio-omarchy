import QtQuick 2.15
import QtQuick.Controls
import Config 1.0

Item {
    id: root
    // 全局快捷键统一由 C++ 侧 ShortcutKeyFilter 拦截 QEvent::ShortcutOverride（在 KeyPress 之前派发）反查并分发，
    // 紧跟的 KeyPress 仅用于消费已分发的按键、防止焦点控件二次触发（见 ShortcutKeyFilter.cpp）。
    // 这样天然覆盖所有焦点场景，且能识别 IME 编辑态。
    // 本文件只保留少量走 Qt Shortcut 系统的兜底绑定（Delete → Backspace、Enter）。

    property var shortcuts: ShortcutConfig.shortcuts
    property int backspaceAction: getAction(shortcuts, "Backspace");

    Shortcut {
        sequences: [StandardKey.Delete]
        context: Qt.WindowShortcut
        enabled: backspaceAction >= 0
        onActivated: {
            ShortcutObserver.shortcutActivated(backspaceAction, "Backspace");
        }
    }

    Shortcut {
        sequences: [Qt.Key_Return, Qt.Key_Enter, "Return", "Enter"]
        context: Qt.WindowShortcut
        enabled: true
        onActivated: {
            var action = getAction(shortcuts, "Enter")
            if(action >= 0){
                ShortcutObserver.shortcutActivated(action, "Enter");
            }
        }
    }

    function getAction(shortcuts, sequence) {
        let action = -1;
        for (var i = 0; i < shortcuts.length; i++) {
            if (shortcuts[i].sequence === sequence) {
                action = shortcuts[i].action
                break;
            }
        }
        return action
    }
}
