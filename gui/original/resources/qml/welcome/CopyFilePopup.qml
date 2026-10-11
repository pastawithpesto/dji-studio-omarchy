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
            exitDuration = 100
        }
    }
    onOpened: {
        globalSignal.enablePlayerViewGesture(false)  // 禁用全景手势
    }
    onClosed: {
        globalSignal.enablePlayerViewGesture(true)   // 启用全景手势
        // 关闭后再切换样式
        isFinshed = false
    }
    Connections {  
        target: copyFileManager
        function onNoAvailableSpace(count) {
            console.log("noAvailableSpace", popup.visible);
            if (!popup.visible) {
                return;
            }
            // 动画最小写的数是 1
            exitDuration = 1;
            popup.close();
            toast.showToast(qsTr("pccut_device_batch_download_fail").arg(count));
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
                text: qsTr("pccut_device_batch_downloading") + "(" + copyFileManager.countTxt + ")"
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
                    width: parent.width * copyFileManager.progress
                    color: ColorsConfig.color_brand
                }
            }
            IconTextButton {
                id: downloadBtn
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
                    copyFileManager.cancel();
                    cancelClick();
                }
            }
        }

        Column {
            id: contentLayout
            visible: isFinshed
            x: 28
            y: 24
            width: parent.width - 28 * 2

            ColumnLayout {
                width: parent.width //- 56  // 左右各减去 28
                spacing: 12
                Text {
                    id: titleLabel
                    text: qsTr("pccut_connected_download_done")
                    visible: isFinshed
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    color: Colors.color_EEEEEE
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                Text {
                    id: textLabel
                    text: qsTr("pccut_connected_download_toast")
                    visible: isFinshed
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    wrapMode: Text.Wrap
                    lineHeight: 1 // 行高设为1.5倍
                    lineHeightMode: Text.ProportionalHeight // 使用比例模式
                    color: Colors.color_999999
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                Rectangle{
                    width:parent.width
                    height:11
                    color:Colors.color_transparent
                }
            }

            RowLayout {
                spacing: 12
                width: parent.width - 56 - 60
                anchors.horizontalCenter: parent.horizontalCenter

                IconTextButton {
                    id: leftButton
                    visible: isFinshed
                    Layout.preferredHeight: 28
                    Layout.preferredWidth: 88
                    isTextOnly: true
                    title: qsTr("pccut_connected_download_btn_confirm")
                    titleColorNormal: Colors.color_FFFFFF
                    backgroundColorNormal: Colors.color_68696D
                    backgroundColorHover: Colors.color_7A7B80
                    onCustomClicked: {
                        close()
                        leftButtonClicked()
                    }
                }
                IconTextButton {
                    id: rightButton
                    visible: isFinshed
                    objectName: actionableItemName.cancelBtnForHomeViewConfirm
                    Layout.preferredHeight: 28
                    Layout.preferredWidth: 88
                    isTextOnly: true
                    title: qsTr("pccut_connected_download_btn_list")
                    titleColorNormal: ColorsConfig.color_FFFFFF_000000
                    backgroundColorNormal: ColorsConfig.color_brand
                    backgroundColorPressed: ColorsConfig.color_F44C65_6DFFD3

                    onCustomClicked: {
                        close()
                        rightButtonClicked()
                    }
                }
            }
        }   
    }
}
