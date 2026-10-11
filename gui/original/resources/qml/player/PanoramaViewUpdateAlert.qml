import QtQuick 2.15
import QtQuick.Controls
import VideoFragmentViewModel 1.0
import Config 1.0
import Controls 1.0
import Qt5Compat.GraphicalEffects
import app_qrc 1.0

Rectangle {
    id: root
    width: rowLayout.implicitWidth
    height: 24
    color: Colors.color_000000_20
    radius: 4
    clip: true

    signal cancelSignal
    signal confirmSignal

    Row {
        id: rowLayout
        anchors.centerIn: parent

        Text {
            id: text
            text: qsTr("pccut_editing_perspective_effect")
            leftPadding: 6
            rightPadding: 2
            font.pixelSize: 12
            color: Colors.color_FFFFFF
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
        }

        IconButton {
            id: closeBtn
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            height: 16
            iconMargins:0
            normalColor: Colors.transparent
            hoverColor: Colors.transparent
            pressedColor: Colors.transparent
            disableColor: Colors.transparent
            iconSource: "qrc:/icons/panorama/panorama_update_close_normal.svg"
            hoverIconSource: "qrc:/icons/panorama/panorama_update_close_hover.svg"

            onClicked: {
                cancelSignal()
            }
        }

        Item {
            width: 4
            height: parent.height
        }

        IconButton {
            id: updateBtn
            width: updateText.implicitWidth + 8
            height: 16
            normalColor: Colors.color_FFFFFF_20
            hoverColor: Colors.color_FFFFFF_30
            pressedColor: Colors.color_FFFFFF_30
            radius: 3
            anchors.verticalCenter: parent.verticalCenter

            Text {
                id: updateText
                anchors.centerIn: parent
                text: qsTr("pccut_editing_perspective_update_button")
                color: Colors.color_FFFFFF
                font.pixelSize: 10
            }
            onClicked: {
                confirmSignal()
            }
        }
        Item {
            width: 4
            height: parent.height
        }
    }
}
