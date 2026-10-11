import QtQuick 2.15
import Controls 1.0
import Config 1.0
import VideoConfig 1.0
import QtQuick.Controls
import QtQuick.Window 2.15
import "../menubar"

/**
  * @author: robert.guo
  * @details 用户改进计划弹框界面
  * @date: 2024-07-05
  */
LightPopup {

    property bool joinPorductImprove: false

    modal:false
    Overlay.modal: Rectangle {
        color: Colors.transparent
    }
    parent: Overlay.overlay
    width: parent.width
    height: parent.height
    z: 100

    function updateCbState(checked) {
        lightSetting.save("needReport", checked);
        var needReport = checked
        logger.d("[ProductImproveScheme]: updateCbState() needReport = " + needReport)

        if (needReport) {
            // 打开时： 需要先打开神策数据等，然后在上报
            eventTracker.enable(true)
            eventTracker.trackEvent("pccut_first_open_app_user_agree_product_improve")
        } else {
            eventTracker.enable(false)
        }

        crashTrackHelper.enableUploadEvent(needReport);
    }

    onClosed: {
        if (!joinPorductImprove) {
            updateCbState(false)
        }
    }

    onOpened: {
        joinPorductImprove = false
    }

    contentItem: Item {

        Rectangle {
            id: rectangle
            anchors {
                centerIn: parent
            }

            width: 360
            height: titleBar.height + desc.height + details.height + cancel.height + 100
            radius: 4
            clip: true
            color: Colors.color_2F3032
            border.width:1
            border.color:Colors.color_454649

            WindowTitleBar {
                id: titleBar
                width: parent.width
                title: qsTr("pccut_permissions_product")
                onCloseClick: {
                    close();
                    eventTracker.trackEvent("pccut_export_close_click");
                }
            }

            Text {
                id: desc
                anchors {
                    left: parent.left
                    right: parent.right
                    leftMargin: 28
                    rightMargin: 28
                    top: titleBar.bottom
                    topMargin: 24
                }
                maximumLineCount: 12
                wrapMode: Text.WordWrap
                text: qsTr("pccut_permissions_product_text_1")
                font.pixelSize: 12
                color: Colors.color_EEEEEE
            }

            Rectangle {
                id: details
                anchors {
                    left: titleBar.left
                    right: titleBar.right
                    leftMargin: 28
                    rightMargin: 28
                    top: desc.bottom
                    topMargin: 16
                }

                height: detailTitle.height + detailContent.height + detail2Title.height + detail2Content.height + 70
                radius: 8
                clip: true
                color: Colors.color_1F2021

                Text {
                    id: detailTitle
                    anchors {
                        left: details.left
                        leftMargin: 16
                        top: details.top
                        topMargin: 16
                    }
                    maximumLineCount: 2
                    wrapMode: Text.WordWrap
                    text: qsTr("pccut_permissions_product_text_2")
                    font.pixelSize: 12
                    color: Colors.color_EEEEEE
                }

                Text {
                    id: detailContent
                    anchors {
                        left: details.left
                        leftMargin: 16
                        right: details.right
                        rightMargin: 16
                        top: detailTitle.bottom
                        topMargin: 8
                    }
                    maximumLineCount: 10
                    wrapMode: Text.WordWrap
                    text: qsTr("pccut_permissions_product_text_3")
                    font.pixelSize: 11
                    color: Colors.color_999999
                }

                Text {
                    id: detail2Title
                    anchors {
                        left: details.left
                        leftMargin: 16
                        top: detailContent.bottom
                        topMargin: 16
                    }
                    maximumLineCount: 2
                    wrapMode: Text.WordWrap
                    text: qsTr("pccut_permissions_product_text_4")
                    font.pixelSize: 12
                    color: Colors.color_EEEEEE
                }

                Text {
                    id: detail2Content
                    anchors {
                        left: details.left
                        leftMargin: 16
                        right: details.right
                        rightMargin: 16
                        top: detail2Title.bottom
                        topMargin: 8
                    }
                    maximumLineCount: 10
                    wrapMode: Text.WordWrap
                    text: qsTr("pccut_permissions_product_text_5")
                    font.pixelSize: 11
                    color: Colors.color_999999
                }

            }


            BaseConfirmBtn {
                id: cancel
                objectName: actionableItemName.productImproveSchemeCancel
                btnText: qsTr("pccut_permissions_product_agree")
                width: 88
                height: 28
                type: 1
                Accessible.role: Accessible.Button
                Accessible.description: "filmexport_exportconfirm"
                anchors {
                    right: confirm.left
                    top: details.bottom
                    topMargin: 36
                    rightMargin: 8
                }

                onCustomClick:() => {
                    close();
                    updateCbState(false)
                }
            }

            BaseConfirmBtn {
                id: confirm
                btnText:qsTr("pccut_permissions_product_disagree")
                width: 88
                height: 28
                type: 0
                Accessible.role: Accessible.Button
                Accessible.description: "filmexport_exportconfirm"
                anchors {
                    right: details.right
                    top: details.bottom
                    topMargin: 36
                }
                onCustomClick:() => {
                    joinPorductImprove = true;
                    close();
                    updateCbState(true)
                }
            }
        }
    }
}
