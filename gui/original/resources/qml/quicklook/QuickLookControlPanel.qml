import QtQuick 2.15
import QtQuick.Controls
import Qt5Compat.GraphicalEffects

import Config 1.0
import MKPlayerController 1.0
import Controls 1.0
import PreviewSourceHandler 1.0
import LightRectangle 1.0

Rectangle {
    id: controlPanel

    property int iconSize: 20
    property MKPlayerController controller
    property bool isFullScreen: false
    property bool isMuted: false
    property bool isVoiceBtnHover: voice.hovered
    property real voiceBtnRightMargin: width - voice.x - voice.width/2 //voice中心点的右边距

    signal fullScreenClicked()

    function getPlayedProgress() {
        const fps = controller.fps();
        if (controller.playedFrame < 0 || controller.totalFrames <= 0 || fps <= 0) {
            return "00:00";
        }
        const playedProgress = DurationFormatter.format(controller.playedFrame, fps, false, false);
        return `${playedProgress}`;
    }

    function getTotalProgress() {
        const fps = controller.fps();
        if (controller.playedFrame < 0 || controller.totalFrames <= 0 || fps <= 0) {
            return "00:00";
        }
        const totalProgress = DurationFormatter.format(controller.totalFrames, fps, false, false);
        return `${totalProgress}`;
    }

    function isEnter() {
        return playToggle.hovered || enterFullScreen.hovered || playSlider.isHovered || voice.hovered
    }

    height: 32
    radius: 6
    border.width: 0
    border.color: Colors.transparent
    color: Colors.color_202020

    layer.enabled: true
    layer.effect: DropShadow {
        color: Colors.color_33000000  // RGBA格式阴影颜色
        horizontalOffset: 0 // 水平偏移（对应CSS的0px）
        verticalOffset: 2   // 垂直偏移（对应CSS的2px）
        radius: 20          // 模糊半径（对应CSS的20px）
        spread: 0           // 阴影扩散比例（对应CSS的0px）
        transparentBorder: true
    }

    onIsFullScreenChanged: {
        enterFullScreen.refreshTips();
    }

    IconButton {
        id: playToggle

        iconSource: controller.playing ? "qrc:/icons/quicklook/quicklook_pause_normal.svg" : "qrc:/icons/quicklook/quicklook_play_normal.svg"
        pressedIconSource: controller.playing ? "qrc:/icons/quicklook/quicklook_pause_pressed.svg" : "qrc:/icons/quicklook/quicklook_play_pressed.svg"
        width: iconSize
        height: iconSize
        iconMargins: 0
        normalColor: Colors.transparent
        hoverColor: Colors.transparent
        pressedColor: Colors.transparent
        anchors {
            left: parent.left
            leftMargin: 16
            verticalCenter: parent.verticalCenter
        }

        onClicked: {
            controller.togglePlayState()
        }
    }

    Text {
        id: progress
        text: getPlayedProgress()
        font.pixelSize: 12
        color: Colors.color_8F8F8F
        font.weight: Font.Medium
        font.letterSpacing: 0
        anchors {
            left: playToggle.right
            leftMargin: 16
            verticalCenter: parent.verticalCenter
        }
    }    

    LightBaseSlider {
        id: playSlider
        property var lastPlayingStatus

        handleWidth: 3
        handleHeight: 15
        handleRadius:2
        handleBorderWidth: 1
        visualColor: Colors.color_676767
        unVisualColor: Colors.color_414141
        handleBorderColor: Colors.color_000000

        from: 0
        to: controller.totalFrames
        stepSize: 1
        snapMode: Slider.SnapAlways
        anchors {
            left: parent.left //不能使用progress，进度变化时TEXT宽度会变，导致进度条抖动
            right: duration.left //duration不会变，可以使用
            leftMargin: 95
            rightMargin: 12
            verticalCenter: parent.verticalCenter
        }

        onValueChanged: {
            if (pressed) {
                controller.seekFrame(value)
            }
        }

        onPressedChanged: {
            if (playSlider.pressed) {
                lastPlayingStatus = controller.playing
                controller.pause();
            } else if (lastPlayingStatus) {
                // 防止进度条seek到最后再从头播放
                if (controller.playedFrame < controller.totalFrames) {
                    controller.togglePlayState();
                }
            }
        }

        Connections {
            target: controller
            function onPlayedFrameChanged(role) {
                playSlider.value = controller.playedFrame;
            }
        }
    }

    Text {
        id: duration
        text: getTotalProgress()
        font.pixelSize: 12
        color: Colors.color_8F8F8F
        font.weight: Font.Medium
        font.letterSpacing: 0
        anchors {
            right: voice.left
            rightMargin: 16
            verticalCenter: parent.verticalCenter
        }
    }

    IconButton {
        id: voice
        iconSource: isMuted ? "qrc:/icons/quicklook/quicklook_voice_muted_nomal.svg" : "qrc:/icons/quicklook/quicklook_voice_nomal.svg"
        pressedIconSource: isMuted ? "qrc:/icons/quicklook/quicklook_voice_muted_pressed.svg" : "qrc:/icons/quicklook/quicklook_voice_pressed.svg"
        width: iconSize
        height: iconSize
        iconMargins: 0
        normalColor: Colors.transparent
        hoverColor: Colors.transparent
        pressedColor: Colors.transparent
        anchors {
            right: enterFullScreen.left
            rightMargin: 12
            verticalCenter: parent.verticalCenter
        }

        onClicked: {
            isMuted = !isMuted
        }
    }

    IconButton {
        id: enterFullScreen
        iconSource: isFullScreen ? "qrc:/icons/quicklook/quicklook_fullscreen_exit_normal.svg" : "qrc:/icons/quicklook/quicklook_fullscreen_normal.svg"
        pressedIconSource: isFullScreen ? "qrc:/icons/quicklook/quicklook_fullscreen_exit_pressed.svg" :  "qrc:/icons/quicklook/quicklook_fullscreen_pressed.svg"
        width: iconSize
        height: iconSize
        iconMargins: 0
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        normalColor: Colors.transparent
        hoverColor: Colors.transparent
        pressedColor: Colors.transparent

        onClicked: {
            isFullScreen = !isFullScreen
            fullScreenClicked()
        }
    }
}
