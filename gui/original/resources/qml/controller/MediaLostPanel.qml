import QtQuick 2.15
import QtQuick.Controls
import Config 1.0
import Controls 1.0

Rectangle {
    color: Colors.color_content_area_background

    Rectangle {
        id: titleDivider
        color: Colors.color_141414
        width: parent.width
        height: 1
    }
    Text {
        id: text

        anchors {
            top: titleDivider.bottom
            topMargin: parent.height * 0.3
            horizontalCenter: parent.horizontalCenter
        }

        text: qsTr("pccut_files_missing_timeline")
        font.pixelSize: 14
        color: Colors.color_999999
    }
}
