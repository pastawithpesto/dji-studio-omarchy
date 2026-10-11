import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.15
import Config 1.0
import Controls 1.0
import QtQuick.Templates 2.12 as T

LightPopup {
    parent: Overlay.overlay
    anchors.centerIn: parent
    //modal:true
    closePolicy: Popup.NoAutoClose
    width: lightWindow.width
    height: lightWindow.height
    dim: false

    property string loadingText: ""

    // 背景
    contentItem: Item{
            Rectangle {
                width: 248
                height: 156
                anchors.verticalCenter: parent.verticalCenter
                anchors.horizontalCenter: parent.horizontalCenter
                radius: 8
                clip: true
                color: Colors.color_2F3032
                border.width:1
                border.color:Colors.color_454649

                Image {
                    id: loading
                    anchors {
                        top: parent.top
                        topMargin: 39
                        horizontalCenter: parent.horizontalCenter
                    }
                    width: 48
                    height: 48
                    source: "qrc:/icons/icon_loading.png"
                    sourceSize: Qt.size(48, 48)

                    RotationAnimation on rotation {
                        from: 0
                        to: 360
                        running: loading.visible
                        duration: 2000 // Duration of one full rotation in milliseconds
                        loops: Animation.Infinite // Loop indefinitely
                    }
                }

                Text {
                    anchors.top: loading.bottom
                    anchors.topMargin: 12
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: loadingText
                    font.pixelSize: 14
                    color: Colors.color_FFFFFF
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                }
            }
    }

}
