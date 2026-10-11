import QtQuick 2.15
import Config 1.0
import Controls 1.0
import app_qrc 1.0

// 首次进入云相册前展示的协议确认弹窗。
ConfirmPopup {
    id: root

    signal agreementAccepted()

    title: qsTr("pccut_lingcloud_service_agreement_dialog_title")
    leftButtonText: qsTr("pccut_cloud_service_agreement_dialog_btn_decline")
    rightButtonText: qsTr("pccut_cloud_service_agreement_dialog_btn_agree")
    leftButtonObjectName: "cloudAlbumAgreementDeclineBtn"
    rightButtonObjectName: "cloudAlbumAgreementAcceptBtn"

    // 设计稿 248x194：内边距 24/28/20，标题-正文-链接三段间距均为 12，
    // 链接与按钮区之间的 20px 由 ConfirmPopup 自带的占位块提供。
    loader.sourceComponent: Column {
        width: parent.width
        // ConfirmPopup 的 contentLayout spacing 为 0，标题与正文之间的 12px 只能在这里补。
        topPadding: 12
        spacing: 12

        Text {
            width: parent.width
            text: qsTr("pccut_lingcloud_service_agreement_dialog_desc")
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
            color: Colors.color_999999
            font.pixelSize: 11
            font.weight: Font.Medium
            // 设计稿行高 15px；用固定行高而非比例行高，保证三行正文正好 45px。
            lineHeight: 15
            lineHeightMode: Text.FixedHeight
        }

        // 链接按文本实际宽度居中，点击热区不铺满整行。
        Item {
            width: parent.width
            height: agreementLink.height

            Text {
                id: agreementLink
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(implicitWidth, parent.width)
                // 不用 StyledText 的 <a>：它会强制加下划线，而设计稿是无下划线的纯色文本。
                text: qsTr("pccut_cloud_service_agreement_link")
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
                color: ColorsConfig.color_3392FF_4DFFC9
                font.pixelSize: 11
                font.weight: Font.Medium
                lineHeight: 15
                lineHeightMode: Text.FixedHeight

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: agreementViewLoader.active = true
                }
            }
        }
    }

    // 「暂不使用」不需要额外处理：ConfirmPopup 的按钮本身已经 close() 了弹窗。
    onRightButtonClicked: {
        agreementAccepted()
    }

    Loader {
        id: agreementViewLoader
        active: false
        sourceComponent: CloudAlbumAgreementView {
            onDestorySource: agreementViewLoader.active = false
        }
    }
}
