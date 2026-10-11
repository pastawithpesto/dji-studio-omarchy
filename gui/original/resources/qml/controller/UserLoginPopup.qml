import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.15
import Qt5Compat.GraphicalEffects
import Controls 1.0
import Config 1.0
import app_qrc 1.0
import QmlConstants 1.0

LightPopup {
    id: loginPopup
    width: 760
    height: 438
    anchors.centerIn: Overlay.overlay
    needTransparent: true
    needNoBorder: true

    Connections {
        target: userLoginViewModel
        function onLoginSuccess() {
            loginPopup.close()
        }
        function onLoginFailure() {
            loginPopup.close()
        }
    }

    contentItem: Item {
        anchors.fill: parent

        // 弹窗主体（带圆角裁剪）
        Item {
            id: popupBody
            anchors.fill: parent

            Rectangle {
                anchors.fill: parent
                color: "#FFFFFF"

                Row {
                    anchors.fill: parent

                    // 左侧背景图面板
                    Item {
                        width: 320
                        height: parent.height
                        clip: true  // 背景图宽 380/x:-30 会溢出 30px 到右侧白色面板,导致右侧登录按钮视觉偏左,裁剪到面板内

                        Image {
                            width: 380
                            height: parent.height
                            x: -30
                            source: "qrc:/app_qrc/icons/login_bg.png"
                            fillMode: Image.PreserveAspectCrop
                        }
                    }

                    // 右侧内容面板
                    Item {
                        width: 440
                        height: parent.height

                        // 垂直居中内容列：Logo 组 + 40px 间隔 + 登录按钮
                        Column {
                            anchors.centerIn: parent
                            spacing: 40

                            // Logo 区域
                            Column {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 8

                                // Logo 图标 80x80
                                Image {
                                    width: 80
                                    height: 80
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    source: "qrc:/app_qrc/icons/login_logo@2x.png"
                                    sourceSize: Qt.size(80, 80)
                                }

                                Text {
                                    text: QmlConstants.appShowName()
                                    font.pixelSize: 16
                                    font.weight: Font.DemiBold
                                    color: "#141414"
                                    horizontalAlignment: Text.AlignHCenter
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                            }

                            // 登录按钮
                            Rectangle {
                                id: loginButton
                                width: 320
                                height: 40
                                anchors.horizontalCenter: parent.horizontalCenter
                                color: loginButtonArea.containsMouse ? "#2F3032" : "#141414"
                                radius: 6

                                Text {
                                    anchors.centerIn: parent
                                    text: qsTr("pccut_login_account_btn")
                                    font.pixelSize: 12
                                    font.weight: Font.Medium
                                    color: "#EEEEEE"
                                }

                                MouseArea {
                                    id: loginButtonArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        userLoginViewModel.login()
                                        userLoginViewModel.reportLogin("top_bar");
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // 外层圆角遮罩
            Rectangle {
                id: outerMask
                anchors.fill: parent
                radius: 8
                visible: false
            }

            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: outerMask
            }
        }

        // macOS 关闭按钮（左上角）
        IconButton {
            anchors {
                top: parent.top
                left: parent.left
                topMargin: 14
                leftMargin: 16
            }
            width: 12
            height: 12
            iconMargins: 0
            visible: !CommonUtils.isWindows()
            iconSource: "qrc:/icons/appbar/btn_close_normal.svg"
            hoverIconSource: "qrc:/icons/appbar/btn_close_hovered.svg"
            pressedIconSource: "qrc:/icons/appbar/btn_close_pushed.svg"
            onClicked: {
                loginPopup.close()
                userLoginViewModel.loginCancel()
            }
        }

        // Windows 关闭按钮（右上角）
        // 本弹窗是白底,IconButton 默认 hover 行为(深底 + 亮图标)与白底场景不搭。
        // 暂时关闭 hover 响应:背景透明 + 图标不变,点击仍正常工作。
        IconButton {
            anchors {
                top: parent.top
                right: parent.right
                topMargin: 14
                rightMargin: 16
            }
            width: 20
            height: 20
            iconMargins: 0
            visible: CommonUtils.isWindows()
            hoverColor: "transparent"
            pressedColor: "transparent"
            iconSource: "qrc:/icons/WindowsIcon/icon_close_modal.svg"
            hoverIconSource: "qrc:/icons/WindowsIcon/icon_close_modal.svg"
            pressedIconSource: "qrc:/icons/WindowsIcon/icon_close_modal.svg"
            onClicked: {
                loginPopup.close()
                userLoginViewModel.loginCancel()
            }
        }
    }
}
