import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.3
import Controls 1.0
import Config 1.0
import LightRectangle 1.0

/**
 * @author robert.guo
 * @desc 视角参数可编辑弹框
 * @create_date 2024-06-17
 */
Popup {
    property alias text: valueTextInput.text
    property bool showDegreeLabel: false
    property var inputValidator: DoubleValidator { }
    property var maxCharsNum: Number.MAX_SAFE_INTEGER

    background: Rectangle{
        radius: 4
        color: Colors.color_19191A
    }

    function autoFocus() {
        valueTextInput.forceActiveFocus()
        valueTextInput.cursorPosition = text.length
    }


    contentItem: Item {
        anchors.fill: parent
        focus: true

        Text {
            id: degreeLabel
            font.pixelSize: 12
            color: Colors.color_999999
            text: "°"
            visible: showDegreeLabel
            anchors {
                right: parent.right
                rightMargin: 4
                verticalCenter: parent.verticalCenter  // 垂直居中展示
            }
        }

        TextInput {
            id: valueTextInput
            anchors {
                right: degreeLabel.right
                left: parent.left
                leftMargin: 4
                verticalCenter: parent.verticalCenter  // 垂直居中展示
            }
            font.pixelSize: 12
            color: Colors.color_EEEEEE
            maximumLength: 6
            // 支持控件点击和拖拽框选
            selectByMouse: true
            // 设置框选背景色
            selectionColor: Colors.color_EEEEEE
            // 设置框选后文本颜色
            selectedTextColor: Colors.color_000000_70
            // 下面的正则表达式，限定了只能输入浮点型数据
            validator: inputValidator
            horizontalAlignment: TextInput.AlignRight
            rightPadding: degreeLabel.width

            onTextChanged: {
                if (valueTextInput.text.length > Math.max(maxCharsNum)) {
                    valueTextInput.text = valueTextInput.text.slice(0, maxCharsNum)
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

            onActiveFocusChanged: {
                if (!activeFocus) {
                    autoFocus()
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
