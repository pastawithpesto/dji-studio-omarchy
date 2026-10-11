import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.3
import Controls 1.0
import Config 1.0
import Qt5Compat.GraphicalEffects
import app_qrc 1.0

/*
  需要用户点确认的通知弹窗。可以优化UI，但最好不要往里面添加功能
*/

LightPopup {
    id: noticePopup

    property string text: qsTr("pccut_feedback_exit_yes")

    signal buttonClicked
    
    property bool isClosedOrDestruction: false
    
    parent: Overlay.overlay
    anchors.centerIn: parent

    background: Rectangle {
        color: Colors.color_2F3032
        border.color: Colors.color_454649
        border.width: 1
        radius: 8
        layer.enabled: true
        layer.effect: DropShadow {
            horizontalOffset: 0
            verticalOffset: 0
            radius: 50
            transparentBorder: true
            color: Colors.color_000000_40
        }
    }

    contentItem: Item{
        MouseArea {
            anchors.fill: parent
            preventStealing: true
        }
        Item {
            id: content
            anchors {
                fill: parent
                margins: 20
                topMargin: 0
            }
            ColumnLayout {
                anchors.fill: parent
                spacing: 0
                Item {
                    Layout.fillHeight: true
                    Layout.fillWidth: true
                    Text {
                        anchors.centerIn: parent
                        font.pixelSize: 14
                        color: Colors.color_EEEEEE
                        text: noticePopup.text
                    }
                }
    
                IconTextButton {
                    id: rightButton
                    Layout.preferredHeight: 28
                    Layout.preferredWidth: 88
                    Layout.alignment: Qt.AlignHCenter
                    alignment: Qt.AlignHCenter
                    isTextOnly: true
                    titleColorNormal: ColorsConfig.color_FFFFFF_000000
                    backgroundColorNormal: ColorsConfig.color_brand
                    backgroundColorPressed: ColorsConfig.color_F44C65_6DFFD3
                    title: qsTr("pccut_export_still_export_exists_yes")
                    onCustomClicked: {
                        buttonClicked()
                        close()
                    }
                }            
            }
        }
    }
    

    onOpened: {
        isClosedOrDestruction = true
        ShortcutObserver.disableAllShortcut(true)
        globalSignal.addPopupQuantity()
    }
    onClosed: {
        if (isClosedOrDestruction) {
            ShortcutObserver.disableAllShortcut(false)
            globalSignal.reducePopupQuantity()
            isClosedOrDestruction = false
        }
    }

    Component.onDestruction: {
        if (isClosedOrDestruction) {
            ShortcutObserver.disableAllShortcut(false)
            globalSignal.reducePopupQuantity()
            isClosedOrDestruction = false
        }
    }

    function closePopup() {
        destroy()
    }
}
