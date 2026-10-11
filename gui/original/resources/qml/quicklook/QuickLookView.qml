import QtMultimedia 5.15
import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.15
import QtQuick.Window 2.15
import Qt5Compat.GraphicalEffects
import QtQuick.Dialogs
import QtCore

import Controls 1.0
import Config 1.0

import MKPlayerController 1.0
import PreviewConductor 1.0
import ShortcutAction 1.0
import LightRectangle 1.0
import QuickLookViewModel 1.0
import QPanoramaLimit 1.0

import "../welcome"
import "../player"
import "../controller"

ApplicationWindow {
    id: quicklook

    readonly property int defautWidth: 812
    readonly property int defautHeight: 642
    readonly property int resizeAreaSize: 8
    readonly property int windowBorderRadius: 10
    property alias playerPlayedFrame: player.playedFrame
    property alias isFullScreen: controlPanel.isFullScreen
    property alias conductor: vm.conductor

    // 真全屏会抢占焦点，采用伪全屏方案（大小跟屏幕大小一样）
    function callFullScreen(full) {
        isFullScreen = full
        if (full) {
            //伪全屏
            x = 0
            y = 0
            width = Screen.width
            height = Screen.height
        } else {
            //居中显示
            width = defautWidth
            height = defautHeight
            x = (Screen.width - width) / 2
            y = (Screen.height - height) / 2
        }
    }

    color: Colors.color_transparent
    visible: vm.fileSelected
    width: defautWidth
    height: defautHeight
    minimumWidth: defautWidth
    minimumHeight: defautHeight
    flags: Qt.Tool |                      // 1. 不显示在任务栏
           Qt.WindowStaysOnTopHint |      // 2. 始终置顶
           Qt.FramelessWindowHint         // 3. 无边框

    onVisibleChanged: {
        if (!visible) {
            //恢复原尺寸
            callFullScreen(false)
        }
    }

    onClosing: {
        vm.quit()
    }

    //定时器，控制进度条隐藏
    Timer {
        id: hoverTimer
        interval: 3000
        repeat: false
        onTriggered: {
            controlPanel.visible = false
        }
    }

    QuickLookViewModel {
        id: vm

        onResetVolume: {
            //与mac保持一致
            voiceSlider.volume = 100
            controlPanel.isMuted = false
        }

        onFileInvalidChanged: {
            logger.d("quicklookview fileInvalid:" + fileInvalid + ",vm.fileName:" + vm.fileName)
            if (fileInvalid) {
                controlPanel.visible = false
            }
        }

        onEscKeyDown: {
            if (isFullScreen) {
                callFullScreen(false);
            } else {
                vm.userClosePreview()
            }
        }
    }

    Component.onCompleted: {
        // Qt.WindowDoesNotAcceptFocus这个属性有问题，
        // 当鼠标点击时还是获得焦点，使用native方案
        logger.d("[quicklook] setNoActivate.")
        vm.setNoActivate(quicklook)
    }

    Connections {
        target: vm
        function onResetVolume() {
            //与mac保持一致
            voiceSlider.volume = 100
            controlPanel.isMuted = false
        }

    }

    Rectangle {
        id: windowBorder
        anchors.fill: parent
        color: Colors.color_373737
        border.color: Colors.color_000000
        border.width: 1
        radius: isFullScreen ? 0 : 10
        antialiasing: true
    }

    QuickLookTopBar {
        id: topbar
        height: 38
        window: quicklook
        visible: !isFullScreen
        favorate: vm.favorate
        sourceFileName: vm.fileName
        fileInvalid: vm.fileInvalid
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }

        onCustomClosedClicked: {
            vm.userClosePreview()
        }

        onFavorateClicked: {
            vm.favorate = !vm.favorate
        }

        onGotoEdit: {
            vm.gotoEdit()

            vm.userClosePreview()
        }
    }

    Rectangle {
        id: content
        color: Colors.color_222222
        radius: 6
        anchors {
            top: isFullScreen ? parent.top : topbar.bottom
            left: parent.left
            leftMargin: 5
            right: parent.right
            rightMargin: 5
            bottom: parent.bottom
            bottomMargin: 5
        }

        //播放器view
        PanoramaPlayerView {
            id: player
            anchors.fill: parent
            playerRole: previewPlayerName
            // 视角手势交给 conductor(nova 绝对改帧)，外抛 move/zoom/rotate 信号(对齐首页预览 PreviewPlayer)。
            playerHandleGesture: false
            layer.enabled: true

            // 手势起止驱动 conductor 视角编辑。
            Connections {
                target: player
                function onGesturingChanged() {
                    if (player.playerHandleGesture) {
                        return;
                    }
                    if (player.gesturing) {
                        conductor.previewGestureStart()
                    } else {
                        conductor.previewGestureEnd()
                    }
                }
            }

            onPlayerHandleGestureChanged: {
                logger.d("quicklook PlayerHandleGesture: " + player.playerHandleGesture)
            }

            // 移动/拖拽/调节水平和垂直视角
            onMove: (deltaX, deltaY, fling) => {
                const normalizedDX = deltaX / player.width / 2;
                const normalizedDY = deltaY / player.height / 2;
                const params = conductor.params;
                const profileWidth = editorManager.profileWidth();
                const profileHeight = editorManager.profileHeight();
                const hDegree = params.hDegree + (profileWidth * 2 * normalizedDX / 5);
                const vDegree = params.vDegree + (profileHeight * 2 * normalizedDY / 5);
                conductor.updatePreviewViewDegree(hDegree, vDegree);
            }

            // 缩放/调节视场角
            onZoom: (deltaPercentage) => {
                const fovRange = QPanoramaLimit.FOV_MAX - QPanoramaLimit.FOV_MIN;
                const distortionRange = QPanoramaLimit.DISTORTION_MAX - QPanoramaLimit.DISTORTION_MIN;
                if (fovRange <= 0 || distortionRange <= 0) {
                    return;
                }
                const deltaFov = fovRange * deltaPercentage;
                const params = conductor.params;
                const fov = params.fov + deltaFov;
                const deltaDistortion = distortionRange * deltaPercentage;
                const distortion = params.distortion + deltaDistortion;
                conductor.updatePreviewFov(fov, distortion);
            }

            // 旋转/调节z轴
            onRotate: (rotation) => {
                const params = conductor.params;
                const rotationZ = params.rotationZ + rotation;
                conductor.updatePreviewRotationZ(rotationZ);
            }

            Component.onCompleted: {
                logger.d("quicklook MKDisplayView player completed")
                conductor.setupTarget(this.displayView)
                conductor.registerNovaPreviewView(this.displayView)
            }
        }

        //进度条控制器
        QuickLookControlPanel {
            id: controlPanel
            controller: player.controller
            visible: false
            z: 1
            anchors {
                bottom: parent.bottom
                bottomMargin: 11
                left: parent.left
                leftMargin: 11
                right: parent.right
                rightMargin: 11
            }

            onFullScreenClicked: {
                quicklook.callFullScreen(isFullScreen)
            }

            onIsVoiceBtnHoverChanged: {
                if (isVoiceBtnHover) {
                    voiceSlider.visible = true
                }
            }

            onIsMutedChanged: {
                if (isMuted) {
                    conductor.setVoiceVolume(0)
                } else {
                    conductor.setVoiceVolume(voiceSlider.volume)
                }
            }

            onVisibleChanged: {
                if (!visible) {
                    voiceSlider.visible = false
                }
            }
        }

        //音量条
        QuickLookVoiceSlider {
            id: voiceSlider
            visible: false
            anchors {
                right: controlPanel.right
                rightMargin: controlPanel.voiceBtnRightMargin - width / 2 //跟voiceBtn中心对齐
                bottom: controlPanel.top
                bottomMargin: 7
            }

            onVolumeChanged: {
                conductor.setVoiceVolume(volume)
                controlPanel.isMuted = (volume === 0)
            }
        }

        //loading
        Rectangle {
            id: loading
            anchors.fill: parent
            color: parent.color
            visible: !conductor.prepared

            ColumnLayout {
                spacing: 12
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    verticalCenter: parent.verticalCenter
                }

                Image {
                    id: loadingImg
                    width: 48
                    height: 48
                    source: "qrc:/icons/icon_loading.png"
                    sourceSize: Qt.size(48, 48)
                    Layout.alignment: Qt.AlignCenter

                    RotationAnimation on rotation {
                        from: 0
                        to: 360
                        running: loading.visible
                        duration: 2000 // Duration of one full rotation in milliseconds
                        loops: Animation.Infinite // Loop indefinitely
                    }
                }

                Text {
                    id: loadingText
                    text: qsTr("pccut_image_preview_tip")
                    font.pixelSize: 14
                    font.weight: 400
                    color: Colors.color_EEEEEE
                }
            }
        }

        //全景类型icon
        PreviewItemTypeTip {
            id: typeTip
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: 20
            anchors.topMargin: 20
            visible: (conductor.isVideo || conductor.isImage || conductor.isPanoVideo ||
                      conductor.isPanoImage || conductor.isLoopVideo || conductor.isHyperlapseVideo ||
                      conductor.isTimelapseVideo || conductor.isSlowMotionVideo) && !loading.visible && !vm.fileInvalid
            isVideo: conductor.isVideo
            isImage: conductor.isImage
            isPanoImage: conductor.isPanoImage
            isPanoVideo: conductor.isPanoVideo
            isLoopVideo: conductor.isLoopVideo
            isHyperlapseVideo: conductor.isHyperlapseVideo
            isTimelapseVideo: conductor.isTimelapseVideo
            isSelfieModeVideo: conductor.isSelfieModeVideo
            isBullefTimeVideo: conductor.isBullefTimeVideo
            isSlowMotionVideo: conductor.isSlowMotionVideo
            isPanoFlatVideo: conductor.isPanoFlatVideo
            imageSource: conductor.getIconType
            sourceView: player
            fontWeight: 400
        }

        //音量条hover区域，用于控制音量条的隐藏
        Rectangle {
            id: voiceSlidehoverArea
            property bool isHovered: false
            color: Colors.transparent
            anchors {
                top: voiceSlider.top
                left: voiceSlider.left
                right: voiceSlider.right
                bottom: controlPanel.bottom
            }

            HoverHandler {
                onHoveredChanged: {
                    voiceSlidehoverArea.isHovered = hovered
                    //controlPanel中有mousearea，会触发hover变化
                    //hovered为false时，需同步判断此时鼠标是否在voicebtn上
                    if (!hovered && !controlPanel.isVoiceBtnHover) {
                        voiceSlider.visible = false
                    }
                }
            }
        }

        //控制进度条的显示/隐藏
        HoverHandler {
            id: hoverLayer

            property point lastPos: Qt.point(-1, -1)

            onHoveredChanged: {
                if (hovered) {
                    if (vm.fileInvalid) {
                        return
                    }

                    hoverTimer.restart()
                    controlPanel.visible = true
                } else {
                    hoverTimer.stop()
                    controlPanel.visible = false
                }
            }

            onPointChanged: {
                if (controlPanel.isEnter() || voiceSlidehoverArea.isHovered) {
                    //当鼠标在进度条或音量条上时，停止计时器，防止进度条隐藏
                    hoverTimer.running = false
                } else if (lastPos !== point.position) {
                    if (vm.fileInvalid) {
                        return
                    }

                    hoverTimer.restart()
                    controlPanel.visible = true
                    lastPos = point.position
                }
            }
        }
    }

    // 播放器渲染界面是个直角，UI要求圆角，所以做了个罩子盖一下
    Rectangle {
        anchors.centerIn: content
        width: content.width + border.width * 2
        height: content.height + border.width * 2
        color: Colors.transparent
        radius: content.radius + border.width //外圆角=内圆角+border.width
        border.color: Colors.color_373737
        border.width: content.radius / 2
    }

    component ResizeHandler: MouseArea {
        property int edges
        cursorShape: {
            if (edges === Qt.TopEdge || edges === Qt.BottomEdge) {
                return Qt.SizeVerCursor
            }
            if (edges === Qt.LeftEdge || edges === Qt.RightEdge) {
                return Qt.SizeHorCursor
            }
            if (edges === (Qt.TopEdge | Qt.LeftEdge) || edges === (Qt.BottomEdge | Qt.RightEdge)) {
                return Qt.SizeFDiagCursor
            }
            if (edges === (Qt.TopEdge | Qt.RightEdge) || edges === (Qt.BottomEdge | Qt.LeftEdge)) {
                return Qt.SizeBDiagCursor
            }
            return Qt.ArrowCursor
        }
        onPressed: quicklook.startSystemResize(edges)
    }
    // 左侧调整大小区域
    ResizeHandler {
        edges: Qt.LeftEdge
        width: resizeAreaSize
        anchors {
            left: parent.left
            top: parent.top
            topMargin: resizeAreaSize
            bottom: parent.bottom
            bottomMargin: resizeAreaSize
        }
    }
    // 右侧调整大小区域
    ResizeHandler {
        edges: Qt.RightEdge
        width: resizeAreaSize
        anchors {
            right: parent.right
            top: parent.top
            topMargin: resizeAreaSize
            bottom: parent.bottom
            bottomMargin: resizeAreaSize
        }
    }
    // 顶部调整大小区域
    ResizeHandler {
        edges: Qt.TopEdge
        height: resizeAreaSize
        anchors {
            top: parent.top
            left: parent.left
            leftMargin: resizeAreaSize
            right: parent.right
            rightMargin: resizeAreaSize
        }
    }
    // 底部调整大小区域
    ResizeHandler {
        edges: Qt.BottomEdge
        height: resizeAreaSize
        anchors {
            bottom: parent.bottom
            left: parent.left
            leftMargin: resizeAreaSize
            right: parent.right
            rightMargin: resizeAreaSize
        }
    }
    // 左上角调整大小区域
    ResizeHandler {
        edges: Qt.LeftEdge | Qt.TopEdge
        width: resizeAreaSize
        height: resizeAreaSize
        anchors {
            left: parent.left
            top: parent.top
        }
    }
    // 右上角调整大小区域
    ResizeHandler {
        edges: Qt.RightEdge | Qt.TopEdge
        width: resizeAreaSize
        height: resizeAreaSize
        anchors {
            right: parent.right
            top: parent.top
        }
    }
    // 左下角调整大小区域
    ResizeHandler {
        edges: Qt.LeftEdge | Qt.BottomEdge
        width: resizeAreaSize
        height: resizeAreaSize
        anchors {
            left: parent.left
            bottom: parent.bottom
        }
    }
    // 右下角调整大小区域
    ResizeHandler {
        edges: Qt.RightEdge | Qt.BottomEdge
        width: resizeAreaSize
        height: resizeAreaSize
        anchors {
            right: parent.right
            bottom: parent.bottom
        }
    }
}
