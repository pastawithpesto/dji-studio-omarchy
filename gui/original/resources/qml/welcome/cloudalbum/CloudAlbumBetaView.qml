import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Shapes 1.15
import Controls 1.0
import Config 1.0

Item {
    id: root
    objectName: "cloudAlbumBetaView"

    property var benefitViewModel: null   // 由 CloudAlbumGuideView 注入

    // ========== 权益校验失败时弹 Toast ==========
    Connections {
        target: root.benefitViewModel
        function onClaimFailed(errorCode, message) {
            if (!root.visible) return
            globalSignal.toast(qsTr("pccut_cloud_album_beta_check_failed"), "cloudAlbum")
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 0

        // ========== 品牌图标（51×51）==========
        Image {
            Layout.alignment: Qt.AlignHCenter
            source: "qrc:/app_qrc/icons/cloud_album_guide_logo.svg"
            sourceSize: Qt.size(51, 51)
        }

        // ========== 标题（20px, #EEEEEE, lineHeight=24）==========
        Text {
            Layout.topMargin: 13
            Layout.alignment: Qt.AlignHCenter
            text: qsTr("pccut_cloud_album_beta_title")
            font.pixelSize: 20
            font.weight: Font.Medium
            lineHeight: 24
            lineHeightMode: Text.FixedHeight
            color: Colors.color_EEEEEE
        }

        // ========== 副标题（11px, #999999, lineHeight=15）==========
        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 8
            text: qsTr("pccut_cloud_album_beta_subtitle")
            font.pixelSize: 11
            font.weight: Font.Medium
            lineHeight: 15
            lineHeightMode: Text.FixedHeight
            color: Colors.color_999999
        }

        // ========== 联系方式列表（3项，间距 48px）==========
        Column {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 64
            spacing: 16

            Repeater {
                model: [
                    {
                        "icon":  "qrc:/app_qrc/icons/cloud_album_beta_phone.svg",
                        "title": qsTr("pccut_cloud_album_beta_phone_title"),
                        "desc":  qsTr("pccut_cloud_album_beta_phone_desc")
                    },
                    {
                        "icon":  "qrc:/app_qrc/icons/cloud_album_beta_wechat.svg",
                        "title": qsTr("pccut_cloud_album_beta_wechat_title"),
                        "desc":  qsTr("pccut_cloud_album_beta_wechat_desc")
                    },
                    {
                        "icon":  "qrc:/app_qrc/icons/cloud_album_beta_email.svg",
                        "title": qsTr("pccut_cloud_album_beta_email_title"),
                        "desc":  qsTr("pccut_cloud_album_beta_email_desc")
                    }
                ]

                delegate: Rectangle {
                    width: 420
                    height: 71
                    radius: 8
                    color: Colors.color_1F2021

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 23
                        spacing: 16

                        // 图标容器 32×32（无独立背景，卡片即背景）
                        Item {
                            width: 32
                            height: 32
                            anchors.verticalCenter: parent.verticalCenter

                            Image {
                                anchors.centerIn: parent
                                source: modelData.icon
                                sourceSize: Qt.size(32, 32)
                            }
                        }

                        // 标题 + 描述（间距 6px）
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6

                            Text {
                                text: modelData.title
                                font.pixelSize: 14
                                font.weight: Font.Medium
                                lineHeight: 18
                                lineHeightMode: Text.FixedHeight
                                color: Colors.color_EEEEEE
                            }

                            Text {
                                text: modelData.desc
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                lineHeight: 15
                                lineHeightMode: Text.FixedHeight
                                color: Colors.color_999999
                            }
                        }
                    }
                }
            }
        }

        // ========== 联系列表与按钮间距 ==========
        Item { Layout.preferredHeight: 64 }

        // ========== 按钮 / 加载状态 ==========
        CloudAlbumCheckingButton {
            objectName: "cloudAlbumBetaCheckBtn"
            Layout.alignment: Qt.AlignHCenter
            buttonText: qsTr("pccut_cloud_album_beta_qualified_btn")
            loadingText: qsTr("pccut_cloud_album_beta_checking")
            isLoading: root.benefitViewModel && root.benefitViewModel.isBenefitChecking
            onClicked: {
                if (root.benefitViewModel) {
                    root.benefitViewModel.onBetaButtonClicked()
                }
            }
        }

        // 补齐到 CloudAlbumGuideStepsView 的内容高度，保证两个页面居中后 logo 顶部一致。
        Item { Layout.preferredHeight: 80 }
    }
}
