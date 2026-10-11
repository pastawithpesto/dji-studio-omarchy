import QtQuick 2.15
import QtQuick.Controls
import Qt3D.Render 2.15
import QtQuick.Layouts 1.15
import Config 1.0

/**
 *  @File        : LightToastManager.qml
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
    closePolicy: Popup.NoAutoClose // 不自动关闭

    // Toast显示时长枚举值 (外部调用方只能使用这些常量)
    readonly property int durationShort: 0       // 1000ms
    readonly property int durationMedium: 1      // 2000ms
    readonly property int durationMediumLong: 2  // 3000ms
    readonly property int durationLong: 3        // 4000ms
    readonly property int durationExtraLong: 4   // 8000ms

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

    // 根据枚举值转换为毫秒
    function durationToMilliseconds(durationLevel) {
        switch(durationLevel) {
            case 0:  // durationShort
                return 1000;
            case 1:  // durationMedium
                return 2000;
            case 2:  // durationMediumLong
                return 3000;
            case 3:  // durationLong
                return 4000;
            case 4:  // durationExtraLong
                return 8000;
            default:
                logger.w("Invalid toast duration: " + durationLevel + ", using SHORT instead");
                return 1000;
        }
    }

    /**
     * 显示Toast提示
     * @param text 提示文本
     * @param panelName 显示位置 ("materialTabView" | "playerPanel" | "playerMainView" | "tracks")
     * @param needBlock 是否阻止交互，默认false
     * @param durationLevel Toast显示时长，必须使用以下枚举值之一：
     *        - durationShort (0) -> 显示1秒
     *        - durationMedium (1) -> 显示2秒
     *        - durationLong (2) -> 显示4秒
     *        - durationExtraLong (3) -> 显示8秒
     *        传入其他值将被转换为durationShort
     */
    function showToast(text, panelName, needBlock = false, durationLevel = durationMediumLong) {
        if (needBlock) {
            toastPopup.modal = true;
            toastPopup.closePolicy = Popup.NoAutoClose;
        }
        if (panelName === "materialTabView") {
            // 素材面板居中
            toastPopup.parent = materialTabView;
        }
        // else if (panelName === "playerPanel") {
        //     // 播放面板居中
        //     toastPopup.parent = playerPanel;
        // }
        else if (panelName === "playerPanel" || panelName === "playerMainView") {
            // 增加多视角功能后，播放面板居中会有些奇怪，统一为播放器主窗口居中（不含多视角小窗）
            toastPopup.parent = playerPanel.playerMainView;
        }
        else if(panelName === "tracks") {
            // 轨道面板水平居中，置顶显示
            toastPopup.parent = tracks.trackToastArea;
        }
        else {
            // 默认显示在全局居中
            toastPopup.parent = Overlay.overlay;
        }
        // 这个只有Debug 环境才会有,显示Debug环境的qml报错, 红色是为了更醒目
        if (panelName === "debugError") {
            toast.color = "red";
            toast.time = 5000
        } else {
            toast.color = Colors.color_FFFFFF;
            toast.time = durationToMilliseconds(durationLevel);
        }
        toast.show(text);
        toastPopup.open();
    }

    /**
     * 在指定 Item 内居中显示 Toast
     * @param text 提示文本
     * @param item 目标 Item（Toast 将在其内部居中显示）
     * @param needBlock 是否阻止交互，默认 false
     * @param durationLevel Toast 显示时长，默认 durationMediumLong
     */
    function showToastAtItem(text, item, needBlock = false, durationLevel = durationMediumLong) {
        if (needBlock) {
            toastPopup.modal = true;
            toastPopup.closePolicy = Popup.NoAutoClose;
        }
        else {
            toastPopup.modal = false;
            toastPopup.closePolicy = Popup.CloseOnEscape | Popup.CloseOnPressOutside;
        }

        toastPopup.parent = item;
        toast.color = Colors.color_FFFFFF;
        toast.time = durationToMilliseconds(durationLevel);
        toast.show(text);
        toastPopup.open();
        
    }
}

