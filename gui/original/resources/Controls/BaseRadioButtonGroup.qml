import QtQuick 2.15
import QtQuick.Controls
import Config 1.0
import app_qrc 1.0


Item{

    property var options
    property int indicatorRadius: 8
    property int itemHeight: 20
    property int itemSpacing: 8
    signal itemSelect(int index)
    height: column.height
    ButtonGroup {
        id: group
        onCheckedButtonChanged: {
            if (group.checkedButton) {
                itemSelect(group.checkedButton.index)
            } else {
                itemSelect(0)
            }
        }
        Component.onCompleted: {
            // 默认选中第一个按钮
            if (buttons.length > 0) {
                checkedButton = buttons[0]
            }
        }
    }
    Column {
        id: column
        width: parent.width
        spacing:itemSpacing
        Repeater {
            id: repeater
            model: options
            RadioButton {
                required property string modelData
                required property int index
                width: column.width
                height: textLabel.lineCount * 20
                ButtonGroup.group: group
                indicator: Rectangle {
                    width: indicatorRadius*2
                    height: indicatorRadius*2
                    radius: indicatorRadius
                    anchors.verticalCenter: parent.verticalCenter
                    color: Colors.color_444444
                    border.color: Colors.color_666666
                    Image {
                        anchors.fill: parent
                        source: "qrc:/app_qrc/icons/select.svg"
                        sourceSize: Qt.size(parent.width, parent.height)
                        visible: parent.parent.checked
                    }

                }
                contentItem: Text {
                    id: textLabel
                    text: modelData
                    verticalAlignment: Text.AlignVCenter
                    leftPadding: parent.indicator.width
                    maximumLineCount: 2
                    wrapMode: Text.WordWrap
                    color: Colors.color_CCCCCC
                }
            }
        }
    }
}
