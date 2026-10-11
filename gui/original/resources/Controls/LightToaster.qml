import QtQuick 2.15
import QtQuick.Controls
import Qt3D.Render 2.15
import QtQuick.Layouts 1.15
import Config 1.0

/**
 *  @File        : LightToaster.qml copy from LightToastManager.qml
 *  @Brief       : ToastManager
 *  @Details     : 详细说明
 *  @Author      : pansy.guo
 *  @Date        : 2024-03-11 20:59:05
 */
Popup {
    id: toastPopup
    width: toast.width
    height: toast.height
    parent: Overlay.overlay
    anchors.centerIn: parent
    dim: false

    z: Infinity
    
    background: Rectangle {
        color: Colors.color_transparent
    }

    contentItem: Item {
        width: parent.width
        height: parent.height

        LightToast {
            id: toast
            anchors.centerIn: parent
            onHiding: {
                toastPopup.close();
            }
        }
    }

    function showToast(text, panelName, needBlock = false) {
        if (needBlock) {
            toastPopup.modal = true;
            toastPopup.closePolicy = Popup.NoAutoClose;
        }
        else if (panelName === "playerPanel") {
            // 播放面板居中
            toastPopup.parent = playerPanel;
        } else if(panelName === "tracks") {
            // 轨道面板水平居中，置顶显示
            toastPopup.parent = tracks.trackToastArea;
        } else if (panelName === "editPanel") {
            // 编辑面板显示
            toastPopup.parent = rightPanelItem;
        }
        else {
            // 默认显示在全局居中
            toastPopup.parent = Overlay.overlay;
        }
        toast.show(text);
        toastPopup.open();
    }

    function showToastText(text) {
       toast.show(text);
       toastPopup.open();
   }
}
