import QtQuick 2.15
import QtQuick.Controls

// 用于检测点击编辑框以外区域，使编辑框失焦
// 使用方式：通过 Loader 动态加载此组件，配合 activeInputContainer 属性指定要监听的输入框
// Popup 只覆盖编辑框区域，点击外部时自动触发 CloseOnPressOutside 失焦
Popup {
    id: overlay
    property TextInput activeInputContainer: null

    visible: false
    padding: 0
    background: null
    modal: false
    closePolicy: Popup.CloseOnPressOutside

    // 只覆盖编辑框区域
    x: activeInputContainer ? activeInputContainer.x : 0
    y: activeInputContainer ? activeInputContainer.y : 0
    width: activeInputContainer ? activeInputContainer.width : 0
    height: activeInputContainer ? activeInputContainer.height : 0

    Component.onCompleted: {
        if (activeInputContainer && activeInputContainer.parent) {
            parent = activeInputContainer.parent
            open()
        }
    }

    Component.onDestruction: {
        if (opened) {
            close()
        }
    }

    onClosed: {
        if (activeInputContainer) {
            activeInputContainer.focus = false
        }
    }

    // 提交失败后 forceActiveFocus 恢复焦点时，重新打开 Popup 以恢复拖选功能
    Connections {
        target: overlay.activeInputContainer
        function onActiveFocusChanged() {
            if (overlay.activeInputContainer && overlay.activeInputContainer.activeFocus && !overlay.opened) {
                overlay.open()
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        property int selectionStart: -1

        onPressed: (mouse) => {
            //在编辑区点击，可拖选文字内容
            var textPt = mapToItem(overlay.activeInputContainer, mouse.x, mouse.y)
            selectionStart = overlay.activeInputContainer.positionAt(textPt.x)
            overlay.activeInputContainer.cursorPosition = selectionStart
            mouse.accepted = true
        }

        //双击编辑区，全选内容
        onDoubleClicked: (mouse) => {
            if (overlay.activeInputContainer) {
                overlay.activeInputContainer.selectAll()
            }
        }

        //拖选内容
        onPositionChanged: (mouse) => {
            if (selectionStart >= 0 && overlay.activeInputContainer) {
                var textPt = mapToItem(overlay.activeInputContainer, mouse.x, mouse.y)
                overlay.activeInputContainer.select(selectionStart, overlay.activeInputContainer.positionAt(textPt.x))
            }
        }

        onReleased: {
            selectionStart = -1
        }
    }
}
