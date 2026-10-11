import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window 2.15
import Qt5Compat.GraphicalEffects
import Config 1.0
import Controls 1.0

Popup {
    id: userInfoPopup

    // 设计稿布局: width:180, height:112, padding:12px 0px, justify-content:center, align-content:flex-start
    width: 180
    height: 112
    modal: false
    // 仅保留 Esc 关闭。刻意不要 CloseOnPressOutside:触发器(头像按钮)在弹窗外,
    // 点头像会被判定为"点击外部"而与按钮的显示逻辑赛跑导致一点就消失。
    // 关闭统一由"hover 离开 → hideTimer"负责(见 keepAlive/requestHide)。
    closePolicy: Popup.CloseOnEscape
    parent: Overlay.overlay
    padding: 0
    topPadding: 12
    bottomPadding: 12
    leftPadding: 0
    rightPadding: 0

    // 锚点元素：用于计算弹窗相对于触发按钮的位置
    property Item anchorItem: null

    // 悬停保活：当鼠标仍在 popup 或触发区域内时，阻止自动关闭
    function keepAlive() {
        hideTimer.stop()
    }

    // 请求延迟关闭：鼠标离开后延迟关闭，给用户移动鼠标到 popup 的缓冲时间
    function requestHide() {
        hideTimer.restart()
    }

    function showAt() {
        if (!anchorItem) return
        var anchorPos = anchorItem.mapToItem(Overlay.overlay, 0, 0)
        x = anchorPos.x + (anchorItem.width - width) / 2
        y = anchorPos.y + anchorItem.height + 8
        open()
    }

    Timer {
        id: hideTimer
        interval: 300
        onTriggered: {
            userInfoPopup.close()
        }
    }

    // 样式: border-radius:8px, background:#2F3032, border:1px solid #454649, box-shadow:0 0 50px rgba(0,0,0,0.5)
    background: Rectangle {
        color: Colors.color_2F3032          // 背景色/BG_Bar
        border.color: Colors.color_454649   // 描边色/Line_Popover
        border.width: 1
        radius: 8
        layer.enabled: true
        layer.effect: DropShadow {
            horizontalOffset: 0
            verticalOffset: 0
            radius: 50
            samples: 101
            color: Qt.rgba(0, 0, 0, 0.5)   // Shadow_Large
        }
    }

    // 头像 URL：绑定 ViewModel 的 avatarPath(file:// 本地缓存),空则回退默认头像
    property string avatarSource: userLoginViewModel.avatarPath !== ""
        ? userLoginViewModel.avatarPath
        : "qrc:/app_qrc/icons/icon_default_avatar.svg"

    contentItem: Item {
        anchors.fill: parent

        HoverHandler {
            onHoveredChanged: {
                if (hovered) {
                    userInfoPopup.keepAlive()
                } else {
                    userInfoPopup.requestHide()
                }
            }
        }

        // 圆形头像：32x32，距左12，距顶16（相对 contentItem）
        Rectangle {
            id: avatarContainer
            x: 12
            y: 16
            width: 32
            height: 32
            radius: 16
            //color: avatarHoverArea.containsMouse ? "#1aFFFFFF" : "transparent"
            color: "transparent"

            Image {
                id: avatarImage
                anchors.fill: parent
                source: userInfoPopup.avatarSource
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                // Retina/高 DPI:按物理像素解码,否则被放大发虚(devicePixelRatio 跨 mac/Win 通用)
                sourceSize: Qt.size(32 * Screen.devicePixelRatio, 32 * Screen.devicePixelRatio)
                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: 32
                        height: 32
                        radius: 16
                    }
                }
            }

            //todo:  no jump with avatar for user center now
            //MouseArea {
            //    id: avatarHoverArea
            //    anchors.fill: parent
            //    hoverEnabled: true
            //    cursorShape: Qt.PointingHandCursor
            //    onClicked: {
            //        // jump to login user center or mimo user center?
            //    }
            //}
        }

        // 用户昵称：头像右侧，间距24/2=12，距顶24
        Item {
            x: 56
            y: 24
            width: 112
            height: 16

            Text {
                id: nicknameText
                anchors.fill: parent
                text: userLoginViewModel.nickname
                font.pixelSize: 12
                font.weight: Font.Medium
                lineHeight: 16
                lineHeightMode: Text.FixedHeight
                color: Colors.color_EEEEEE
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }

            MouseArea {
                id: nicknameHoverArea
                anchors.fill: parent
                hoverEnabled: true
            }

            LightToolTip {
                visible: nicknameHoverArea.containsMouse && nicknameText.truncated
                tip: nicknameText.text
            }
        }

        // 分割线: width:156px, border-top:1px solid #454649
        // 距Top 128物理像素(64逻辑点) / 距Bottom 96物理像素(48逻辑点)
        Rectangle {
            width: 156
            height: 1
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 64  // 从contentItem顶部(已去除topPadding)算起64逻辑点
            color: Colors.color_454649   // 背景色/BG_Box
        }

        // 退出当前账号按钮
        // 位置: 距顶部80, 距左侧12。宽度不写死——由文案内容(implicitWidth)决定,
        // 使点击区(MouseArea anchors.fill)与可见文字等长。写死 72px 是按中文
        // "退出当前账号"的设计稿宽度,英文等更长文案会溢出 72px 却只有前半段可点。
        Text {
            id: logoutButton
            text: qsTr("pccut_user_info_logout")
            x: 12
            y: 80
            height: 16
            font.pixelSize: 12
            font.weight: Font.Medium
            lineHeight: 16
            lineHeightMode: Text.FixedHeight
            color: logoutButtonArea.containsMouse ? Colors.color_EEEEEE : Colors.color_999999
            verticalAlignment: Text.AlignVCenter

            MouseArea {
                id: logoutButtonArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    userInfoPopup.close()
                    userLoginViewModel.logout()
                    userLoginViewModel.reportLogout("manual")
                }
            }
        }

        // TODO: 子元素待从设计稿逐个搬运后在此添加
    }
}
