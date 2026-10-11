import QtQuick 2.15
import MKDisplayView 1.0
import MKPlayerController 1.0
import PanoramaController 1.0

Item {
    id: root
    readonly property alias playerViewGesture: playerViewGesture
    readonly property alias displayView: displayView
    readonly property alias controller: controller
    property bool isFullScreen: false
    readonly property alias playedFrame: controller.playedFrame
    readonly property alias referenceLineLayer: referenceLineLayer

    // 手势相关
    // 是否是拖拽过程中
    readonly property alias gesturing: playerViewGesture.gesturing
    // 播放器是否自己处理全景手势(如果处理就不向外抛出手势的信号)
    // 目前视频编辑需要设置 playHandleGesture 为 false
    property bool playerHandleGesture: true

    // 设置几个只读属性，以便在构造此对象时统一使用，如有新的使用场景，再写新的，其值为埋点参数名，新增时需与产品商定具体值
    readonly property string editorPlayerName: "edit_page"
    readonly property string previewPlayerName: "player_page"
    // 表示改播放器的使用场景，如编辑器页面播放器、预览播放器等（埋点用）
    property string playerRole: editorPlayerName

    // 视角更新弹窗相关属性（由外部绑定）
    property bool viewUpdateAlertVisible: false
    property bool highlightViewUpdateAlertVisible: false

    // 【边下边播·帧超时/缓冲 buffering】由外部绑定 conductor.bufferingActive。
    //    true=帧超时开始，在视频画面正中显示转圈 loading；false=隐藏。
    //    必须锚定 displayView 且高 z：MKDisplayView 走 Qt 场景图渲染，同层高 z 的兄弟节点
    //    才能盖在视频画面之上（参照 PanoramaViewUpdateAlert 的 z:2 做法）。
    property bool bufferingActive: false

    signal highlightViewUpdateAlertCancel()
    signal highlightViewUpdateAlertConfirm()
    // 高光手势信号（PanoramaPlayerView内部触发，外部处理）
    signal highlightGestureStarted()
    signal highlightGestureEnded()

    signal move(real deltaX, real deltaY, bool fling)
    signal zoom(real deltaPercentage)
    signal rotate(real rotation)

    function flingStop() {
        playerViewGesture.flingStop();
    }
    // 全屏时，取消文字的选中状态
    function toggleOverlaySelection(visible) {
        overlayControlLayer.toggleOverlaySelection(visible);
    }
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
    }

    // 播放控制
    MKPlayerController {
        id: controller
        target: displayView
    }
    // 视频画面展示
    MKDisplayView {
        id: displayView
        anchors.centerIn: parent
    }

    // 【边下边播·帧超时/缓冲 buffering】转圈 loading 遮罩：锚定 displayView、高 z 盖在视频画面上。
    //    背景保持不动——buffering 期间 consumer 停在最后一帧，遮罩无背景色只叠图标。
    Item {
        id: bufferingMask
        anchors.fill: displayView
        z: 3
        visible: root.bufferingActive
        Image {
            width: 48
            height: 48
            anchors.centerIn: parent
            source: "qrc:/icons/icon_loading.png"
            sourceSize: Qt.size(48, 48)
            RotationAnimation on rotation {
                from: 0
                to: 360
                running: bufferingMask.visible
                duration: 2000
                loops: Animation.Infinite
            }
        }
    }

    function saveCurDispalyFrame(){
        return displayView.saveCurDispalyFrame();
    }

    // 视角更新提示
    PanoramaViewUpdateAlert {
        id: highlightViewUpdateAlert
        anchors.horizontalCenter: displayView.horizontalCenter
        anchors.top: displayView.top
        anchors.topMargin: 12
        z: 2
        visible: root.highlightViewUpdateAlertVisible
        onConfirmSignal: {
            playerViewGesture.flingStop()
            root.highlightViewUpdateAlertConfirm()
        }
        onCancelSignal: {
            playerViewGesture.flingStop()
            root.highlightViewUpdateAlertCancel()
        }
    }

    Connections {
        target: playerViewGesture
        function onDraggingChanged() {
            if (!playerViewGesture.dragging) {
                overlayControlLayer.overlayPressed = false
            }
        }
    }

    // 全景手势
    PlayerViewGesture {
        id: playerViewGesture
        anchors.fill: displayView
        enableDragFling: true
        twoFingerRoll: false
        mouseOnOverlay: overlayControlLayer.mouseOnItem
        isPanorama: controller.currentStackHasPanorama
        hitTestPanorama: (nx, ny) => controller.isPanoramaAt(nx, ny)
        overlayPressed: overlayControlLayer.overlayPressed

        onIsPanoramaChanged: {
            if (!isPanorama) {
                // 视频片段播放完成，文本轨道继续播放时，重置手势和光标状态
                playerViewGesture.resetGestureState()
            }
        }

        onGesturingChanged: {
            if(editorManager.isInUserGuideStatus){
                if(playerViewGesture.gesturing){
                    globalSignal.startAdjustView();
                }else{
                    globalSignal.nextStepInKfGuide();
                }
            }

            if (!playerHandleGesture) {
                if (playerViewGesture.gesturing) {
                    eventTracker.trackEvent("pccut_player_drop", {"use_method" : playerRole})
                } else { // 手势结束
                    globalSignal.panoramaPlayerPramaAdjust(PanoramaController.PreviewArea)
                }
                return;
            }

            if (playerViewGesture.gesturing) {
                controller.gestureStart(playerViewGesture.gestureStartPoint.x, playerViewGesture.gestureStartPoint.y);
                root.highlightGestureStarted()
                eventTracker.trackEvent("pccut_player_drop", {"use_method": playerRole})
            } else {
                controller.gestureEnd();
                root.highlightGestureEnded()
            }
        }

        // 移动/拖拽/调节水平和垂直视角
        onMove: (deltaX, deltaY, fling) => {
            if (!playerHandleGesture) {
                root.move(deltaX, deltaY, fling);
                return;
            }
            controller.gestureUpdateDelta(deltaX, deltaY);
        }

        // 缩放/调节视场角
        onZoom: (deltaPercentage) => {
            if (!playerHandleGesture) {
                root.zoom(deltaPercentage);
                return;
            }
            controller.gestureUpdateScale(deltaPercentage);
        }

        // 旋转/调节z轴
        onRotate: (rotation) => {
            if (!playerHandleGesture) {
                root.rotate(rotation);
                return;
            }
            controller.gestureUpdateRotationZ(rotation);
        }

        Connections{
            target: globalSignal
            function onEnablePlayerViewGesture(enable){
                playerViewGesture.enabled = enable;
            }

            function onMediaChangedWhenCoverClick() {
                // 感觉不需要手动重置，记录的参数不用就行了
                // controller.resetPanoramaArgument()
            }
        }
    }

    // 仅在有 dashboardManager 的引擎(主编辑器)创建：预览/QuickLook 等独立引擎未注册该单例，
    // 且不做贴纸编辑，创建会因引用该单例触发 ReferenceError。
    Loader {
        anchors.fill: displayView
        active: typeof dashboardManager !== "undefined"
        sourceComponent: DashboardStickerControlLayer {
            isPanorama: controller.currentPlayIsPanorama
            enabled: !root.isFullScreen
        }
    }

    OverlayControlLayer {
        id: overlayControlLayer
        anchors.fill: displayView
        enabled: !playerViewGesture.dragging && !root.isFullScreen
    }

    ReferenceLineLayer {
        id: referenceLineLayer
        anchors.fill: displayView
        //非空轨状态下显示参考线
        visible: controller.totalFrames > 0
    }
}
