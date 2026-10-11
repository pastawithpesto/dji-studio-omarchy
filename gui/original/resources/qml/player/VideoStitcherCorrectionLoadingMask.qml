import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls
import QtQuick.Dialogs
import Controls 1.0
import Config 1.0
import TrackingManager 1.0
import LightRectangle 1.0
import ShortcutAction 1.0


/**
 * @author hugo.li
 * @desc 进入拼接校正的时候，展示的加载界面,界面效果就是镂空播放器部分，显示转圈
 * @create_date 2025-01-04
 */
Popup {
    id: maskPopupRoot
    width: parent.width
    height: parent.height
    // 通过添加下面的属性，屏蔽所有快捷键
    modal:false
    dim: false
    // 为了单独做取消功能 所以要区分关闭
    closePolicy: Popup.NoAutoClose
    focus: true
    // 播放器位置信息
    property rect playerRect: Qt.rect(0, 0, 0 ,0)
    // 播放器控制栏位置信息
    property rect playerControllerRect: Qt.rect(0, 0, 0 ,0)
    // 播放器整个面板位置信息
    property rect playerPanelRect: Qt.rect(0, 0, 0, 0)
    // 轨道选中的视频片段的位置信息
    property rect selectItemRect: Qt.rect(0, 0, 0, 0)

    background: LightRectangle{
        color: Colors.color_transparent
    }
    parent: Overlay.overlay
    padding: 0

    CShortcut {
        action: ShortcutAction.ESCAPE_FULL_SCREEN
        enabled:maskPopupRoot.visible
        onActivated: {
            if(!maskPopupRoot.visible){
                return
            }
            stitcherCorrectionSwitch.switchManual(false,false)
            panoramaVM.cancelStitcher()
        }
    }

    Item {
        anchors.fill: parent

        LightOverlayMask {
            id: lightOverlayMask
            anchors.fill: parent
        }
    }

    // 旋转图
    Image {
        id: loading
        x:playerRect.x + (playerRect.width - width)/2
        y:playerRect.y + (playerRect.height - height)/2
        width: 48
        height: 48
        source: "qrc:/icons/icon_loading.png"
        sourceSize: Qt.size(200, 200)

        RotationAnimation on rotation {
            id:loadingRotation
            running: false
            from: 0
            to: 360
            duration: 2000 // Duration of one full rotation in milliseconds
            loops: Animation.Infinite // Loop indefinitely
        }
    }


    /**
     * @desc 重新绘制蒙层
     */
    function refreshMask() {
        if (lightOverlayMask === undefined || lightOverlayMask === null) {
            return
        }

        lightOverlayMask.clearData(false)
        lightOverlayMask.addData(playerRect)
    }

    function dealWindowSizeChanged() {
        playerRect = playerPanel.getPlayerPosition()
        selectItemRect = tracks.getSelectItemRect()
        refreshMask()
    }

    onWidthChanged: {
        dealWindowSizeChanged()
    }

    onHeightChanged: {
        dealWindowSizeChanged()
    }

    onOpened: {
        forceActiveFocus()
        loadingRotation.running = true
        dealWindowSizeChanged()
        globalSignal.enablePlayerViewGesture(false)
        logger.d("logger :open videoStitcherCorrectionLoading!!!!!")
    }

    onClosed: {
        loadingRotation.running = false
        globalSignal.enablePlayerViewGesture(true)
        logger.d("logger :close  videoStitcherCorrectionLoading!!!!!")
    }
}
