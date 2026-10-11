import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.3
import Controls 1.0
import Config 1.0
import LightRectangle 1.0

/**
 * @author jack.ni
 * @desc 重命名编辑输入框
 * @create_date 2025-10-29
 */
Popup {
    id: popup
    property int popTopPadding: 0
    property int maximumLength: Number.MAX_SAFE_INTEGER
    property alias textInput: valueTextInput
    property alias text: valueTextInput.text

    background: Rectangle{
        color: Colors.color_transparent
    }

    function autoFocus() {
        valueTextInput.forceActiveFocus()
        valueTextInput.cursorPosition = text.length
    }

    clip: true

    contentItem: Item {
        anchors.fill: parent
        focus: true

        TextInput {
            id: valueTextInput
            topPadding: popTopPadding
            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: parent.verticalCenter  // 垂直居中展示
            }
            font.pixelSize: 12
            color: Colors.color_EEEEEE
            // 支持控件点击和拖拽框选
            selectByMouse: true
            maximumLength: popup.maximumLength
            // 设置框选背景色
            selectionColor: Colors.color_EEEEEE
            // 设置框选后文本颜色
            selectedTextColor: Colors.color_000000_70
            horizontalAlignment: TextInput.AlignLeft
            rightPadding: 0

            onTextChanged: {
                var filteredText = CommonUtils.sanitizeString(valueTextInput.text);
                if (valueTextInput.text !== filteredText) {
                    var cursorPos = valueTextInput.cursorPosition;
                    valueTextInput.text = filteredText;
                    valueTextInput.cursorPosition = Math.max(0, cursorPos - 1);
                }
            }

            cursorDelegate: Rectangle {
                id: cursor
                width: 1
                height: 14
                color: Colors.color_EEEEEE // 设置光标颜色为白色

                // 搞个定时器实现光标闪烁
                Timer {
                    id: cursorTimer
                    interval: 500 // 闪烁间隔，500 毫秒
                    running: valueTextInput.activeFocus // 当 TextInput 获得焦点时运行
                    repeat: true
                    onTriggered: cursor.visible = !cursor.visible // 切换光标的可见性
                }
            }

        }

        Keys.onPressed: (event)=> {
            // 监听两个回车键， Qt.Key_Return 是Enter键， Qt.Key_Enter是数字键旁边的回车键
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                // 输入框内容为空时，点击回撤键无效
                if (valueTextInput.text !== "") {
                    close()
                }
            }
        }
    }
}
