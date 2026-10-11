import QtQuick 2.15
import QtQuick.Layouts 1.15
import Controls 1.0
import Config 1.0

Item {
    ColumnLayout {
        anchors.fill: parent

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "transparent"
        }
        Image {
            Layout.alignment: Qt.AlignHCenter
            source: "qrc:/icons/icon_usb.svg"
            sourceSize: Qt.size(36, 36)
        }
        Text {
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            Layout.maximumWidth: 760
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 12
            height: 28
            font.pixelSize: 20
            color: Colors.color_FFFFFF
            text: qsTr("pccut_device_description")
        }
        Image {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 24
            sourceSize: Qt.size(418, 263)
            source: "qrc:/app_qrc/deviceIntroduce.png"
        }
        Text {
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            Layout.maximumWidth: 760
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 38
            height: 25
            font.pixelSize: 18
            color: Colors.color_FFFFFF
            text: qsTr("pccut_hardware")
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 14
            height: 20
            font.pixelSize: 14
            font.underline: true
            color: Colors.color_3392FF
            text: qsTr("pccut_quick_learn_more")
            visible: false
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "transparent"
        }
    }
}
