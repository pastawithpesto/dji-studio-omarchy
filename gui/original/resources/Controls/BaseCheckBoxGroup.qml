import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    property alias checkBoxes: checkBoxRepeater.model

    Repeater {
        id: checkBoxRepeater
        model: []
        
        CheckBox {
            text: modelData
            anchors {
                left: typeText.right
                leftMargin: 12
                top: parent.top
                bottom: parent.bottom
                right: parent.right
            }
            checked: true
            anchors.verticalCenter: parent.verticalCenter
            indicator: Rectangle {
                implicitWidth: 16
                implicitHeight: 16
                anchors.left: videoCheckBox.left
                anchors.verticalCenter: parent.verticalCenter
                color:Colors.color_141414
                radius: 8
                Image {
                    id: icon2
                    visible: videoCheckBox.checked
                    anchors.fill: parent
                    source: "qrc:/icons/icon_radio_button.svg"
                    sourceSize: Qt.size(parent.width, parent.height)
                }
            }
            MouseArea {
                anchors.fill: videoCheckBox
                onClicked: {
                    var newChecked = !videoCheckBox.checked;
                }
            }
            contentItem: Text {
                text: videoCheckBox.text
                font.pixelSize: 12
                color: Colors.color_EEEEEE
                verticalAlignment: Text.AlignVCenter
                leftPadding: videoCheckBox.indicator.width + 2
            }
        }
        CheckBox {
            text: modelData
            onClicked: {
                if (checked) {
                    for (let i = 0; i < checkBoxRepeater.count; i++) {
                        if (checkBoxRepeater.itemAt(i) !== this) {
                            checkBoxRepeater.itemAt(i).checked = false;
                        }
                    }
                }
            }
        }
    }
}