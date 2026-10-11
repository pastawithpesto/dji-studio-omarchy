import QtQuick 2.15
import Controls 1.0
import Config 1.0
import QtQuick.Layouts 1.3
import UIComponent
import "../controller"
import "../welcome/cloudalbum"
/**
 * @author xu.lv
 * @desc 菜单栏点击后弹出页面控制器
 * @create_date 2024-07-03
 */
Item {
    id: layer
    signal close();
    property var performanceWindow: null

    function showLanguagePop(code) {
        if (translationHandler.chekNeedRestart(code)) {
            if (!restartPopupLoader.active)
            {
                restartPopupLoader.active = true
            }

            var restartPopup = restartPopupLoader.item
            restartPopup.code = code;
            restartPopup.open();
        } else {
            translationHandler.setCurrentCode(code);
        }
    }

    // 使用布局容器居中
    ColumnLayout {
        anchors.fill: parent

        Loader {
            id: popupLoader
            Layout.alignment: Qt.AlignCenter
            onLoaded: {
                // 弹出的模态窗口关闭时触发,卸载掉loader的source
                if (popupLoader.item) {
                    popupLoader.item.destorySource.connect(function() {
                        popupLoader.sourceComponent = null
                        globalSignal.enableMenuBar(true)
                    });
                }
            }
        }
    }

    Component {
        id: aboutLayerComponent
        AboutLayer {
            id:aboutLayer
            onClickThirdCopyright: {
                popupLoader.sourceComponent = thirdCopyrightComponent
            }
            onClickAppIcon: {
                popupLoader.sourceComponent = null
                globalSignal.enableMenuBar(true)
                showDebugInfo()
            }
            // 关于窗口已自行隐藏，这里卸载它并在主窗口里展示协议正文——
            // 关于窗口是 WindowModal 且只有 360px 宽，600px 的正文弹窗放不下。
            onClickCloudAlbumProtocol: {
                popupLoader.sourceComponent = null
                globalSignal.enableMenuBar(true)
                cloudAlbumAgreementLoader.active = true
            }
        }
    }

    Loader {
        id: cloudAlbumAgreementLoader
        active: false
        // CloudAlbumAgreementView 在 Component.onCompleted 里自行 open()。
        sourceComponent: CloudAlbumAgreementView {
            onDestorySource: cloudAlbumAgreementLoader.active = false
        }
    }
    UIMessageBoxHost { id: debugMsgBoxHost }

    TextEdit {
        id: debugClipboard
        visible: false
        width: 0
        height: 0
    }

    function showDebugInfo() {
        var did = eventTracker.distinctId()
        var payload = "DID：" + did
        debugMsgBoxHost.show({
            size: UIControlSize.M,
            title: payload,
            buttons: [
                { text: qsTr("pccut_did_copy"), role: "copy",  type: UIButtonType.White}
            ],
            onClosed: function(role) {
                if (role === "copy") {
                    debugClipboard.text = payload
                    debugClipboard.selectAll()
                    debugClipboard.copy()
                }
            }
        })
    }


    Component {
        id: preferencesLayerComponent
        PreferencesLayer {
            id:preferencesLayer
        }
    }

    Component {
        id: thirdCopyrightComponent
        ThirdCopyright {
        }
    }

    Loader {
        id: restartPopupLoader
        // 默认不加载
        active: false
        // 切换语言重启弹窗
        sourceComponent: ConfirmPopup {
            id: restartPopup
            title: qsTr("pccut_menu_reboot_title")
            text: qsTr("pccut_menu_reboot")
            leftButtonText: qsTr("pccut_draft_delete_popup_cancel")
            rightButtonText: qsTr("pccut_menu_reboot_yes")
            property string code: ""

            onRightButtonClicked: {
                translationHandler.setCurrentCode(code);
                globalSignal.restart()
            }
            // 目前如果草稿损坏，无论怎么选都会阻止草稿打开，若切换到一个已打开的并且损坏的草稿，就关闭那个草稿
        }
    }

    Component {
        id: macShortcutLayerComponent
        MacShortCutLayer {
            id:shortcutLayer
        }
    }

    // 根据菜单栏的点击展示对应的页面
    function showPopLayer(page, item) {
        switch(page) { // 系统菜单页
            case 0: // 系统菜单页 
                if(item === 0){// 关于
                    popupLoader.sourceComponent = aboutLayerComponent
                    
                }
                else if(item === 1){
                    popupLoader.sourceComponent = preferencesLayerComponent
                }
                break;
            case 3:
                if(item === 0){//切换中文
                }
                else if(item === 2)
                    popupLoader.sourceComponent = macShortcutLayerComponent
                break;
            default:       
        }
    }
}
