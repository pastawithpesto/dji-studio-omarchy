import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Shapes 1.15
import Controls 1.0
import Config 1.0
import Qt5Compat.GraphicalEffects

Item {
    id: root
    objectName: "cloudAlbumGuideStepsView"

    property var benefitViewModel: null   // 由 CloudAlbumGuideView 注入

    // ========== 权益校验失败时弹 Toast ==========
    Connections {
        target: root.benefitViewModel
        function onClaimFailed(errorCode, message) {
            if (!root.visible) return
            if (errorCode === 0) {
                globalSignal.toast(qsTr("pccut_cloud_album_guide_benefit_pending"), "cloudAlbum")
            } else {
                globalSignal.toast(qsTr("pccut_cloud_album_beta_check_failed"), "cloudAlbum")
            }
        }
    }

    // 居中内容容器
    ColumnLayout {
        anchors.centerIn: parent
        spacing: 0

        // ========== Logo ==========
        Image {
            Layout.alignment: Qt.AlignHCenter
            source: "qrc:/app_qrc/icons/cloud_album_guide_logo.svg"
            sourceSize: Qt.size(51, 51)
        }

        // ========== 标题 ==========
        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 16
            text: qsTr("pccut_cloud_album_guide_title")
            font.pixelSize: 20
            font.weight: Font.Medium
            color: Colors.color_FFFFFF
        }

        // ========== 副标题 ==========
        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 8
            text: qsTr("pccut_cloud_album_guide_subtitle")
            font.pixelSize: 11
            font.weight: Font.Medium
            lineHeight: 15
            lineHeightMode: Text.FixedHeight
            color: Colors.color_999999
        }

        // ========== 支持机型 ==========
        Text {
            objectName: "cloudAlbumGuideSupportedModels"
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 4
            visible: root.benefitViewModel
                     && root.benefitViewModel.supportedDeviceTypes.length > 0
            text: visible
                  ? qsTr("pccut_cloud_album_guide_supported_models")
                    + root.benefitViewModel.supportedDeviceTypes
                  : ""
            font.pixelSize: 11
            font.weight: Font.Medium
            lineHeight: 15
            lineHeightMode: Text.FixedHeight
            color: Colors.color_999999
        }

        // ========== 步骤卡片区域（带背景） ==========
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 32
            // 宽度 = 左padding(80) + 3列(112) + 2箭头区域(112) + 右padding(80)
            Layout.preferredWidth: 720
            Layout.preferredHeight: 434
            radius: 8
            color: Colors.color_1F2021

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 76
                anchors.rightMargin: 80
                anchors.topMargin: 24
                anchors.bottomMargin: 40
                spacing: 37

                // --- 步骤 01 ---
                ColumnLayout {
                    Layout.preferredWidth: 124
                    Layout.alignment: Qt.AlignTop
                    spacing: 0

                    Image {
                        width: 17
                        height: 16
                        Layout.preferredWidth: 17
                        Layout.preferredHeight: 16
                        Layout.topMargin: 14
                        source: "qrc:/app_qrc/icons/cloud_album_guide_number_1.svg"
                        sourceSize: Qt.size(17, 16)
                        fillMode: Image.Stretch
                    }

                    // 描述文字（固定高度保证三列等高）
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        Layout.topMargin: 12

                        Text {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            text: qsTr("pccut_cloud_album_guide_step1_desc")
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            lineHeight: 15
                            lineHeightMode: Text.FixedHeight
                            color: Colors.color_999999
                            wrapMode: Text.WordWrap
                        }
                    }

                    // 手机截图（圆角遮罩）
                    Item {
                        Layout.topMargin: 12
                        Layout.preferredWidth: 112
                        Layout.preferredHeight: 240

                        Rectangle {
                            id: mask1
                            anchors.fill: parent
                            radius: 12
                            visible: false
                        }

                        Image {
                            id: img1
                            anchors.fill: parent
                            source: "qrc:/app_qrc/icons/cloud_album_guide_step1.png"
                            fillMode: Image.PreserveAspectCrop
                            visible: false
                        }

                        OpacityMask {
                            anchors.fill: img1
                            source: img1
                            maskSource: mask1
                        }

                        // 图片未就绪时的占位背景
                        Rectangle {
                            anchors.fill: parent
                            radius: 12
                            color: Colors.color_2F3032
                            visible: img1.status !== Image.Ready
                        }
                    }
                }

                // --- 箭头 01 → 02 ---
                Image {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.topMargin: 40
                    source: "qrc:/app_qrc/icons/cloud_album_guide_arrow.svg"
                    sourceSize: Qt.size(32, 32)

                    // 箭头未就绪时用文字代替
                    Text {
                        anchors.centerIn: parent
                        text: ">>"
                        font.pixelSize: 16
                        color: Colors.color_666666
                        visible: parent.status !== Image.Ready
                    }
                }

                // --- 步骤 02 ---
                ColumnLayout {
                    Layout.preferredWidth: 124
                    Layout.alignment: Qt.AlignTop
                    spacing: 0

                    Image {
                        width: 20
                        height: 16
                        Layout.preferredWidth: 20
                        Layout.preferredHeight: 16
                        Layout.topMargin: 14
                        source: "qrc:/app_qrc/icons/cloud_album_guide_number_2.svg"
                        sourceSize: Qt.size(20, 16)
                        fillMode: Image.Stretch
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        Layout.topMargin: 12

                        Text {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            text: qsTr("pccut_cloud_album_guide_step2_desc")
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            lineHeight: 15
                            lineHeightMode: Text.FixedHeight
                            color: Colors.color_999999
                            wrapMode: Text.WordWrap
                        }
                    }

                    Item {
                        Layout.topMargin: 12
                        Layout.preferredWidth: 112
                        Layout.preferredHeight: 240

                        Rectangle {
                            id: mask2
                            anchors.fill: parent
                            radius: 12
                            visible: false
                        }

                        Image {
                            id: img2
                            anchors.fill: parent
                            source: "qrc:/app_qrc/icons/cloud_album_guide_step2.png"
                            fillMode: Image.PreserveAspectCrop
                            visible: false
                        }

                        OpacityMask {
                            anchors.fill: img2
                            source: img2
                            maskSource: mask2
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: 12
                            color: Colors.color_2F3032
                            visible: img2.status !== Image.Ready
                        }
                    }
                }

                // --- 箭头 02 → 03 ---
                Image {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.topMargin: 40
                    source: "qrc:/app_qrc/icons/cloud_album_guide_arrow.svg"
                    sourceSize: Qt.size(32, 32)

                    Text {
                        anchors.centerIn: parent
                        text: ">>"
                        font.pixelSize: 16
                        color: Colors.color_666666
                        visible: parent.status !== Image.Ready
                    }
                }

                // --- 步骤 03 ---
                ColumnLayout {
                    Layout.preferredWidth: 124
                    Layout.alignment: Qt.AlignTop
                    spacing: 0

                    Image {
                        width: 19
                        height: 16
                        Layout.preferredWidth: 19
                        Layout.preferredHeight: 16
                        Layout.topMargin: 14
                        source: "qrc:/app_qrc/icons/cloud_album_guide_number_3.svg"
                        sourceSize: Qt.size(19, 16)
                        fillMode: Image.Stretch
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        Layout.topMargin: 12

                        Text {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            text: qsTr("pccut_cloud_album_guide_step3_desc")
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            lineHeight: 15
                            lineHeightMode: Text.FixedHeight
                            color: Colors.color_999999
                            wrapMode: Text.WordWrap
                        }
                    }

                    Item {
                        Layout.topMargin: 12
                        Layout.preferredWidth: 112
                        Layout.preferredHeight: 240

                        Rectangle {
                            id: mask3
                            anchors.fill: parent
                            radius: 12
                            visible: false
                        }

                        Image {
                            id: img3
                            anchors.fill: parent
                            source: "qrc:/app_qrc/icons/cloud_album_guide_step3.png"
                            fillMode: Image.PreserveAspectCrop
                            visible: false
                        }

                        OpacityMask {
                            anchors.fill: img3
                            source: img3
                            maskSource: mask3
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: 12
                            color: Colors.color_2F3032
                            visible: img3.status !== Image.Ready
                        }
                    }
                }
            }

            // ========== 底部按钮：我已领取（文字 + 右箭头，橙色，无背景）==========
            CloudAlbumCheckingButton {
                objectName: "cloudAlbumGuideCheckBtn"
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.horizontalCenterOffset: -4
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 32
                buttonText: qsTr("pccut_cloud_album_guide_qualified_btn")
                loadingText: qsTr("pccut_cloud_album_beta_checking")
                isLoading: root.benefitViewModel && root.benefitViewModel.isBenefitChecking
                onClicked: {
                    if (root.benefitViewModel) {
                        root.benefitViewModel.onGuideButtonClicked()
                    }
                }
            }
        }
    }
}
