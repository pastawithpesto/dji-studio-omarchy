import QtQuick 2.15
import QtQuick.Controls
//import QtQuick.Controls.Styles 1.4
import Config 1.0

Rectangle {
    id: root

    property int currentIndex: 0
    color: Colors.color_333333
    radius: 6

    function switchIndex(idx) {
        currentIndex = idx;
    }

    Rectangle {
        id: rect0
        anchors.left: root.left
        anchors.leftMargin: 2
        anchors.verticalCenter: root.verticalCenter
        implicitWidth: 99
        implicitHeight: 20
        radius: 5
        color: currentIndex === 0 ? Colors.color_666666_50 : Colors.color_transparent
        Text {
            anchors.fill: parent
            font.pixelSize: 10
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            color: currentIndex === 0 ? Colors.color_EEEEEE : Colors.color_999999
            text: qsTr("pccut_panel_adjus")
        }
        MouseArea {
            anchors.fill: parent
            onClicked: {
                switchIndex(0);
            }
        }
    }

    Rectangle {
        id: rect1

        anchors.right: root.right
        anchors.rightMargin: 2
        anchors.verticalCenter: root.verticalCenter
        implicitWidth: 99
        implicitHeight: 20
        color: currentIndex === 1 ? Colors.color_666666_50 : Colors.color_transparent
        radius: 5
        Text {
            anchors.fill: parent
            font.pixelSize: 10
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            color: currentIndex === 1 ? Colors.color_EEEEEE : Colors.color_999999
            text: qsTr("pccut_panel_image_video_settings")
        }
        MouseArea {
            anchors.fill: parent
            onClicked: {
                switchIndex(1);
            }
        }
    }
}
