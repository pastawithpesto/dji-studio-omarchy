import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.15
import Config 1.0
import Controls 1.0
import app_qrc 1.0

LightPopup {
    id: popup
    property bool isFinshed: false
    property int processCount: 0;
    property int totalCount: 0;
    property string text;
    signal leftButtonClicked
    signal rightButtonClicked
    parent: Overlay.overlay
    anchors.centerIn: parent
    closePolicy: Popup.NoAutoClose
    width: 360
    height: isFinshed?contentLayout.height + 24 * 2:column.height + 24 * 2
    Overlay.modal: Rectangle {
        color: Colors.color_000000_50
        radius: 10
    }
    signal cancelClick
    onVisibleChanged: {
        if (visible) {
            exitDuration = 0
        }
    }

    // 背景
    contentItem: Rectangle {
        width: popup.width
        height: popup.height
        color: Colors.color_2F3032
        border.color: Colors.color_454649
        border.width: 0.5
        radius: 8
        ColumnLayout {
            id: column
            x: 28
            y: 24
            width: parent.width - 28 * 2
            spacing: 22
            Text {
                visible: !isFinshed
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                text: popup.text
                font.pixelSize: 14
                wrapMode: Text.Wrap
                color: Colors.color_EEEEEE
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
            }
            Rectangle {
                Layout.fillWidth: true
                visible: !isFinshed
                radius: 2
                height: 4
                color: Colors.color_454649
                Rectangle {
                    radius: 2
                    height: 4
                    width: totalCount == 0 ? 0 : parent.width * (processCount * 1.0 / totalCount)
                    color: ColorsConfig.color_brand
                }
            }
            IconTextButton {
                id: cancelBtn
                usePreferredWidth: true
                Layout.preferredWidth: 88
                Layout.preferredHeight: 28
                Layout.alignment: Qt.AlignHCenter
                visible: !isFinshed
                title: qsTr("pccut_device_batch_downloading_cancel")
                titleColorNormal: Colors.color_FFFFFF
                backgroundColorNormal: Colors.color_68696D
                backgroundColorHover: Colors.color_7A7B80
                isTextOnly: true
                leftPadding: 6
                rightPadding: 6
                onCustomClicked: {
                    popup.close();
                    cancelClick();
                }
            }
        }
    }


    onClosed: {
        // 关闭后再切换样式
        isFinshed = false
    }
}
