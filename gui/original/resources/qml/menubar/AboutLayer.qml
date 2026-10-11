import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.15
import Controls 1.0
import Config 1.0
import Qt5Compat.GraphicalEffects
import QmlConstants 1.0
import app_qrc 1.0
import CloudAlbumManager 1.0

/**
 * @author xu.lv
 * @desc 关于 页面
 * @create_date 2024-07-03
 */
Item {
    id: layer

    // 模态窗口关闭时触发的信号，用于通知上层界面卸载loader资源
    signal destorySource()
    signal clickThirdCopyright()
    // 点击「大疆灵云用户服务协议」。关于窗口是 WindowModal，且协议正文弹窗有 600px 宽，
    // 塞不进 360px 的关于窗口，因此与「第三方版权」一样先隐藏本窗口、由外层在主窗口里展示。
    signal clickCloudAlbumProtocol()
    signal clickAppIcon()

    // 模态窗口关闭
    function closeWinowd() {
        mainWindow.visible = false
        destorySource()
    }

    // 模态窗口的宽高
    // 「大疆灵云服务用户协议」入口门禁：功能开关 + 已登录 + 命中灰度。
    // 不看「是否已同意协议」——这个入口正是给用户读协议正文用的，要求已同意会自相矛盾。
    // 未通过门禁时回退到接入云相册之前的一行三项布局。
    readonly property bool showCloudAlbumProtocol: cloudAlbumFeatureFlags.enable
                                                   && CloudAlbumManager.isLoggedIn
                                                   && CloudAlbumManager.grayCloudAlbumAvailable

    property real windowWidth: 360
    // 高度 = 标题栏 40 + 上边距 40 + 设计稿内容区 + 下边距 40。
    // 协议入口两行时 385；回退为一行时还原成接入云相册前的 361，否则底部会多出空白。
    property real windowHeight: showCloudAlbumProtocol ? 385 : 361

    CustomWindow {
        id: mainWindow
        width: windowWidth
        height: windowHeight
        Shortcut {
            sequence: "Escape"
            context: Qt.WindowShortcut
            onActivated: {
                closeWinowd()
            }
        }

        WindowTitleBar { // 自定义的标题栏
            id: titleBar
            title: qsTr("pccut_menu_about")
            height: 40
            width: parent.width
            onCloseClick: {
                closeWinowd();
            }
        }
        Item{
            anchors.top: titleBar.bottom
            anchors.topMargin:40
            anchors.bottom: parent.bottom
            anchors.bottomMargin:40
            anchors.left:parent.left
            anchors.leftMargin:28
            anchors.right:parent.right
            anchors.rightMargin:28

            Image {
                id: icon
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                width: 80
                height: 80
                source: "qrc:/app_qrc/app_icon.png"
                sourceSize: Qt.size(288, 288)


                MouseArea {
                    id: iconClickArea
                    property int clickCount: 0
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        clickCount++
                        iconClickResetTimer.restart()
                        if (clickCount >= 3) {
                            clickCount = 0
                            iconClickResetTimer.stop()
                            clickAppIcon()
                        }
                    }
                    Timer {
                        id: iconClickResetTimer
                        interval: 1000
                        repeat: false
                        onTriggered: iconClickArea.clickCount = 0
                    }
                }
            }

            Item {
                id: info
                anchors.top: icon.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.topMargin: 12
                width: 79
                height: 39

                Text{
                    id: appName
                    width: parent.width
                    height: 20
                    text: QmlConstants.appShowName()
                    color: Colors.color_EEEEEE
                    wrapMode: Text.NoWrap
                    font.pixelSize: 16
                    horizontalAlignment: Text.AlignHCenter
                }

                Text{
                    id: appVersion
                    anchors.top: appName.bottom
                    anchors.topMargin: 4
                    width: parent.width
                    height: 15
                    text: qsTr(Updater.getCurrentVersionName())
                    color: Colors.color_EEEEEE
                    wrapMode: Text.NoWrap
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: 11
                }

            }

            Text{
                id: copyright
                anchors.top: info.bottom
                anchors.topMargin: 40
                anchors.left: parent.left
                anchors.leftMargin: 0
                anchors.right: parent.right
                anchors.rightMargin: 0
                height: 30
                text: qsTr("pccut_menu_about_copyright") + " " + qsTr("pccut_menu_about_coltd")
                color: Colors.color_999999
                wrapMode: Text.WrapAnywhere
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: 11
                lineHeight: 1
                lineHeightMode: Text.ProportionalHeight
            }

            // 协议入口（含云相册）：设计稿两行居中排列，行内间距 12、行间距 8。
            Column {
                id: agreements
                visible: layer.showCloudAlbumProtocol
                anchors.top: copyright.bottom
                anchors.topMargin: 24
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 12

                    HoverableText {
                        id: userProto
                        font.pixelSize: 12
                        text: qsTr("pccut_menu_terms_service")
                        color: ColorsConfig.color_3392FF_4DFFC9
                        horizontalAlignment: Text.AlignHCenter
                        maximumLineCount: 1
                        maxTextWidth: 75
                        onClicked: {
                            Qt.openUrlExternally(QmlConstants.termsWebSite())
                        }
                    }

                    HoverableText {
                        id: cloudAlbumProto
                        // 复用协议详情窗的标题文案：点这里就是打开详情窗，两处保持同名。
                        text: qsTr("pccut_cloud_service_agreement_detail_title")
                        font.pixelSize: 12
                        color: ColorsConfig.color_3392FF_4DFFC9
                        horizontalAlignment: Text.AlignHCenter
                        maximumLineCount: 1
                        // 中文 120px；留出余量避免英文等长文案被省略号截断。
                        maxTextWidth: 150
                        onClicked: {
                            mainWindow.visible = false
                            clickCloudAlbumProtocol();
                        }
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 12

                    HoverableText {
                        id: privacy
                        text: qsTr("pccut_menu_privacy_policy")
                        font.pixelSize: 12
                        color: ColorsConfig.color_3392FF_4DFFC9
                        horizontalAlignment: Text.AlignHCenter
                        maximumLineCount: 1
                        maxTextWidth: 65
                        onClicked: {
                            Qt.openUrlExternally(QmlConstants.policyWebSite())
                        }
                    }

                    HoverableText {
                        id: thirdparty
                        text: qsTr("pccut_menu_thirdparty_copyright")
                        font.pixelSize: 12
                        color: ColorsConfig.color_3392FF_4DFFC9
                        horizontalAlignment: Text.AlignHCenter
                        maximumLineCount: 1
                        maxTextWidth: 65
                        onClicked: {
                            mainWindow.visible = false
                            clickThirdCopyright();
                        }
                    }
                }
            }

            // 未通过云相册门禁时的协议入口：接入云相册之前的一行三项布局，原样保留。
            Item {
                id: legacyAgreements
                visible: !layer.showCloudAlbumProtocol
                width: 244
                anchors.top: copyright.bottom
                anchors.topMargin: 24
                anchors.left: parent.left
                anchors.leftMargin: 30
                anchors.right: parent.right
                anchors.rightMargin: 30

                HoverableText {
                    id: legacyUserProto
                    font.pixelSize: 12
                    text: qsTr("pccut_menu_terms_service")
                    color: ColorsConfig.color_3392FF_4DFFC9
                    horizontalAlignment: Text.AlignLeft
                    maximumLineCount: 1
                    anchors.right: legacyPrivacy.left
                    anchors.rightMargin: 32
                    maxTextWidth: 75
                    onClicked: {
                        Qt.openUrlExternally(QmlConstants.termsWebSite())
                    }
                }

                HoverableText {
                    id: legacyPrivacy
                    text: qsTr("pccut_menu_privacy_policy")
                    font.pixelSize: 12
                    color: ColorsConfig.color_3392FF_4DFFC9
                    anchors.horizontalCenter: parent.horizontalCenter
                    maximumLineCount: 1
                    // 旧版这里写的是 Layout.maximumWidth（非 Layout 父项下无效），实际生效的是
                    // HoverableText 默认的 maxTextWidth 51；此处不设，保持与旧版完全一致的宽度。
                    onClicked: {
                        Qt.openUrlExternally(QmlConstants.policyWebSite())
                    }
                }

                HoverableText {
                    id: legacyThirdparty
                    text: qsTr("pccut_menu_thirdparty_copyright")
                    font.pixelSize: 12
                    color: ColorsConfig.color_3392FF_4DFFC9
                    maximumLineCount: 1
                    anchors.left: legacyPrivacy.right
                    anchors.leftMargin: 32
                    maxTextWidth: 65
                    onClicked: {
                        mainWindow.visible = false
                        clickThirdCopyright();
                    }
                }
            }

        }
    }

}
