import QtQuick 2.15
import QtQuick.Controls
import Config 1.0
import QtQuick.Window 2.15
import QtQuick.Layouts 1.15

import "qrc:/qml/controller"
import app_qrc 1.0

Item{
    id:root
    property string titleText
    // contentText 仅作为对外只读窗口，反映当前显示的字符串。
    // 设值统一走 setText(value)，禁止外部命令式赋值或声明式绑定到 contentText，
    // 这样可以彻底避免外部绑定被组件内部写入打断的问题。
    readonly property alias contentText: valueText.text
    property int spacing: 12
    property alias valueTextCom: valueText  // 暴露整个Text组件
    //这两个是是否带有尾缀的
    property bool showSuffix:false
    property string suffixText
    property int maxLength: -1
    property string placeholderText: ""
    property bool showWarning: false
    property color warningColor: Colors.color_3392FF
    signal textValueChanged(string value)

    // 外部设值的唯一入口
    function setText(value) {
        if (valueText.text !== value) {
            valueText.text = value
        }
    }
    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: root.top
        anchors.bottom: root.bottom
        spacing: root.spacing  // 控制子项间距
        HoverableText {
            id: title
            Layout.preferredWidth: 51
            color: Colors.color_CCCCCC
            horizontalAlignment: Text.AlignLeft
            verticalAlignment: Text.AlignVCenter
            font.pixelSize: 12
            text: titleText
            maximumLineCount: 2
            cursorChanged: false
            wrapMode: Text.WrapAnywhere
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    valueText.focus = false;
                }
            }
        }

        TextField {
            id: valueText
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            //height: root.height
            Layout.fillHeight: true
            placeholderText: root.placeholderText
            placeholderTextColor: Colors.color_666666
            rightPadding: root.showSuffix?(fileNameSuffixText.contentWidth+16):8
            // 设置 TextField 的背景色
            background: Rectangle {
                radius: RadiusConfig.radius_4_8
                color: Colors.color_454649
                border.width: root.showWarning ? 1 : 0
                border.color: root.warningColor
                //尾缀
                Text {
                    id: fileNameSuffixText
                    visible: root.showSuffix
                    anchors {
                        right: parent.right
                        rightMargin:8
                        verticalCenter: parent.verticalCenter
                    }
                    horizontalAlignment: Text.AlignLeft
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: 12
                    color: Colors.color_999999
                    text: root.suffixText
                }
            }
            // 设置文本的对齐方式
            horizontalAlignment: TextInput.AlignLeft
            verticalAlignment: TextInput.AlignVCenter
            // 选择文本的字体和颜色
            font.pixelSize: 12
            // 按住鼠标左键选择文本
            selectByMouse: true
            selectionColor: Colors.color_EEEEEE // 选中文本的背景色
            selectedTextColor: Colors.color_000000_70   // 选中文本的颜色
            color: Colors.color_EEEEEE
            leftPadding: 8
            property bool isUpdatingText: false
            onTextChanged: {
                if (isUpdatingText) return
                isUpdatingText = true

                var filteredText = CommonUtils.sanitizeString(valueText.text);
                if (valueText.text !== filteredText) {
                    var cursorPos = valueText.cursorPosition;
                    valueText.text = filteredText;
                    valueText.cursorPosition = Math.max(0, cursorPos - 1);
                }

                if (root.maxLength > 0 && CommonUtils.mixedTextLength(valueText.text) > root.maxLength) {
                    var pos = valueText.cursorPosition;
                    valueText.text = CommonUtils.truncateByMixedLength(valueText.text, root.maxLength);
                    valueText.cursorPosition = Math.min(pos, valueText.text.length);
                }
                isUpdatingText = false
                textValueChanged(valueText.text)
            }

            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Delete) {
                    if (inputField.selectedText.length > 0) {
                        // 删除选中的文本
                        inputField.text = inputField.text.remove(inputField.selectionStart, inputField.selectionEnd - inputField.selectionStart);
                        inputField.deselect();
                    }
                }
            }
        }
    }

}
