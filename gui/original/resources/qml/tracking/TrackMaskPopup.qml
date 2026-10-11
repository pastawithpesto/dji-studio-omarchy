import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls
//import QtQuick.Controls.Styles 1.4
import QtQuick.Dialogs
import Controls 1.0
import Config 1.0
import TrackingManager 1.0
import LightRectangle 1.0
import ShortcutAction 1.0
import UserGuideMaskManager 1.0
import "../user_guide"

/**
 * @author robert.guo
 * @desc 进入tk模式时的蒙层弹框
 * @create_date 2024-07-23
 */
Popup {
    id: maskPopupRoot
    width: parent.width
    height: parent.height

    // 通过添加下面的属性，屏蔽所有快捷键
    modal:false
    dim: false
    property UserGuideMaskManager userGuideMaskManager: UserGuideMaskManager{}
    // 播放器位置信息
    property rect playerRect: Qt.rect(0, 0, 0 ,0)
    // 播放器控制栏位置信息
    property rect playerControllerRect: Qt.rect(0, 0, 0 ,0)
    // 播放器整个面板位置信息
    property rect playerPanelRect: Qt.rect(0, 0, 0, 0)
    // 轨道选中的视频片段的位置信息
    property rect selectItemRect: Qt.rect(0, 0, 0, 0)

    property var currentStatus
    property bool isTracking:false
    property int prioritySetting: 4

    background: LightRectangle{
        color: Colors.color_transparent
    }
    parent: Overlay.overlay
    padding: 0

    CShortcut {
        action: ShortcutAction.ESCAPE_FULL_SCREEN
        priority:prioritySetting
        enabled:(currentStatus == TrackingManager.TK_ENTER || currentStatus == TrackingManager.TK_READY || currentStatus == TrackingManager.TK_START || isTracking)
        onActivated: {
            if(isTracking){
                editorManager.pause()
                globalSignal.trackingStopAction(true)
                globalSignal.trackingExitAction()
                // 取消追踪时，也需要删除对应的tk片段
                globalSignal.trackingSegmentRemoveAction(true)
                return
            }
            switch(currentStatus){
                case TrackingManager.TK_ENTER:
                case TrackingManager.TK_READY:
                case TrackingManager.TK_START:
                    globalSignal.trackingExitAction()
            }
        }
    }
    Item {
        anchors.fill: parent

        LightOverlayMask {
            id: lightOverlayMask
            anchors.fill: parent
        }

        Rectangle {
            id: trackRectLayerRoot
            color: Colors.transparent
            anchors.fill: parent
            TrackRectLayer {
                id: trackRectLayer
                objectName: actionableItemName.trackRectLayer

                onVisibleChanged: {
                    if(trackRectLayer.visible){
                        trackRectLayer.enabled = true;
                    }
                }
            }
            visible: true
        }

        Rectangle {
            id: trackControllerRoot
            anchors.fill: parent
            color: Colors.transparent
            visible: true

            TrackController {
                id: trackController
                objectName: actionableItemName.trackController

                trackingInited: trackingManager.isInited
            }
        }

		Rectangle {
            id: selectedTarget
            color: Colors.color_2E276D
            visible: true
            anchors.left: parent.left
            anchors.top: parent.top
            width: 0
            height: 0
		}

        KeyFrameGuide{
            id: trackingGuide
            objectName: actionableItemName.trackingGuide
            property bool isPracticalOperation: false // 是否是用户的实际操作触发进入下一步
            property bool isFinishTracking: false
            visible: false
            curStep: 0
            x: trackController.x + trackController.width / 2 - trackingGuide.width / 2
            y: trackController.y + trackController.height
            z:10

            onCurStepChanged: {
                updateGuide(); // 修改指引UI
                onNextStep();
            }

            onVisibleChanged:{
                if(visible){
                    updateGuide();
                }
                globalSignal.enablePlayerViewGesture(!trackingGuide.visible);
            }

            onExitGuide: {
                editorManager.isInUserGuideStatus = false;
                editorManager.pause()
                globalSignal.trackingStopAction(true)
                globalSignal.trackingExitAction()
                // 取消追踪时，也需要删除对应的tk片段
                globalSignal.trackingSegmentRemoveAction(true)
                globalSignal.exitTkGuideModel(false);
                maskPopupRoot.close()
            }

            function updateGuide(){
                if(trackingGuide.curStep === 0){
                    trackingGuide.titleText = qsTr("pccut_guide_TK_1");
                    trackingGuide.stepText = qsTr("1/4");
                    trackingGuide.descriptionText = qsTr("pccut_guide_TK_2");
                }else if(trackingGuide.curStep === 1){
                    trackingGuide.titleText = qsTr("pccut_guide_TK_3");
                    trackingGuide.stepText = qsTr("2/4");
                    trackingGuide.descriptionText = qsTr("pccut_guide_TK_4");
                    trackRectLayer.enabled = false;
                }else if(trackingGuide.curStep === 2){
                    trackingGuide.titleText = qsTr("pccut_guide_TK_5");
                    trackingGuide.stepText = qsTr("3/4");
                    trackingGuide.descriptionText = qsTr("pccut_guide_TK_6");
                }else if(trackingGuide.curStep === 3){
                    trackingGuide.titleText = qsTr("pccut_guide_TK_7");
                    trackingGuide.stepText = qsTr("4/4");
                    trackingGuide.descriptionText = qsTr("pccut_guide_TK_8");
                }
            }

            function onNextStep(){
                if(trackingGuide.guideStep === 3){
                    trackingGuide.curStep = 0;
                    globalSignal.enableMenuBar(true);
                }
                if(trackingGuide.curStep === 1){
                    if(trackingGuide.isPracticalOperation){
                        trackRectLayer.isUseDefalutRect = false;
                    }else{
                        trackRectLayer.isUseDefalutRect = true;
                    }
                    globalSignal.trackingReadyAction();
                    globalSignal.closeAnimationInTkGuide();

                }else if(trackingGuide.curStep === 2){
                    if(!trackingGuide.isFinishTracking && !isTracking){
                        globalSignal.readyTrackingEvent();
                        globalSignal.trackingStartAction();
                        trackingGuide.isFinishTracking = true;
                    }
                }else if(trackingGuide.curStep === 3){
                    globalSignal.trackingStopAction(false)
                    globalSignal.trackingExitAction()
                    trackRectLayer.isUseDefalutRect = false;
                    globalSignal.exitTkGuideModel(true);
                    trackingGuide.curStep = 0;
                    globalSignal.enableMenuBar(true);
                }
            }

            Connections {
                    target: trackingGuide
                    function onExitGuide(){
                        trackingGuide.curStep = 0;
                        mask.visible = false;
                        editorManager.isInUserGuideStatus = false;
                        globalSignal.enableMenuBar(true);
                    }
                }

            Connections{
                target: globalSignal
                function onNextStepInTkGuide(){
                    trackingGuide.isPracticalOperation = true;
                    trackingGuide.curStep += 1;
                }

                function onEnterTkGuideModel(){
                    editorManager.isInUserGuideStatus = true;
                    trackingGuide.visible = true;
                }
            }
        }
    }

    /**
     * @desc tracking初始化，初始化配置文件，模型文件，log路径和三方库路径
     */
    function init() {
        trackingManager.init()
    }

    /**
     * @desc 重新绘制蒙层
     */
    function refreshMask() {
        if (lightOverlayMask === undefined || lightOverlayMask === null) {
            return
        }

        lightOverlayMask.clearData(false)
        lightOverlayMask.addData(playerPanelRect)
        lightOverlayMask.addData(selectItemRect)
        if(editorManager.isInUserGuideStatus){
            shaderEffect.requestPaint();
        }
    }

    Canvas {
        id: shaderEffect
        anchors.fill: parent
        visible: editorManager.isInUserGuideStatus;
        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

                // 绘制外层描边
                ctx.strokeStyle = "rgba(255, 255, 255, 0.1)";
                ctx.lineWidth = 8; // 设置外层描边宽度
            var x = playerPanelRect.x;
            var y = playerPanelRect.y;
            var rectWidth = playerPanelRect.width;
            var rectHeight = playerPanelRect.height;
            var radius = 6; // 圆角半径

                let deltaBoard = 0;
                let radius1 = radius;

                ctx.beginPath();
                let delX = 2 + deltaBoard;
                ctx.moveTo(x + radius1 + delX, y - delX);
                ctx.lineTo(x + rectWidth - radius1 - delX, y - delX);
                ctx.quadraticCurveTo(x + rectWidth + delX, y - delX, x + rectWidth + delX, y + radius1 + delX);
                ctx.lineTo(x + rectWidth + delX, y + rectHeight - radius1 - delX);
                ctx.quadraticCurveTo(x + rectWidth + delX, y + rectHeight + delX, x + rectWidth - radius1 - delX, y + rectHeight + delX);
                ctx.lineTo(x + radius1 + delX, y + rectHeight + delX);
                ctx.quadraticCurveTo(x - delX, y + rectHeight + delX, x - delX, y + rectHeight - radius1 - delX);
                ctx.lineTo(x - delX, y + radius1 + delX);
                ctx.quadraticCurveTo(x - delX, y - delX, x + radius1 + delX, y - delX);
                ctx.closePath();
                ctx.stroke();

                // 绘制内层白色框
                ctx.strokeStyle = "white";
                ctx.lineWidth = 2; // 设置内层边缘宽度

                // 绘制圆角矩形路径
                delX = deltaBoard;
                ctx.beginPath();
                ctx.moveTo(x + radius - delX, y - delX); // 内层路径向外偏移 delX 像素
                ctx.lineTo(x + rectWidth - radius + delX, y - delX);
                ctx.quadraticCurveTo(x + rectWidth + delX, y - delX, x + rectWidth + delX, y + radius - delX);
                ctx.lineTo(x + rectWidth + delX, y + rectHeight - radius + delX);
                ctx.quadraticCurveTo(x + rectWidth + delX, y + rectHeight + delX, x + rectWidth - radius + delX, y + rectHeight + delX);
                ctx.lineTo(x + radius - delX, y + rectHeight + delX);
                ctx.quadraticCurveTo(x - delX, y + rectHeight + delX, x - delX, y + rectHeight - radius + delX);
                ctx.lineTo(x - delX, y + radius - delX);
                ctx.quadraticCurveTo(x - delX, y - delX, x + radius - delX, y - delX);
                ctx.closePath();

                // 绘制路径
                ctx.stroke();
            }
        }


    /**
     * @desc 重新绘制tk相关蒙层控件
     */
    function refreshTkControl() {
        if (lightOverlayMask === undefined || lightOverlayMask === null) {
            return
        }
        // 画框控件
        trackRectLayer.x = playerRect.x
        trackRectLayer.y = playerRect.y
        trackRectLayer.width = playerRect.width
        trackRectLayer.height = playerRect.height

        // tk控制栏
        trackController.x = playerControllerRect.x
        trackController.y = playerControllerRect.y
        trackController.width = playerControllerRect.width
        trackController.height = playerControllerRect.height
    }

    TrackingManager {
        id: trackingManager
    }

    Connections {
        target: globalSignal

        function onTrackingEnterAction() {
            ShortcutObserver.switchTKAction();
            globalSignal.readyTrackingEvent();
            trackingManager.trackingEnter();
        }

        function onTrackingExitAction() {
            ShortcutObserver.switchDefaultAction();
            trackingManager.trackingExit();
        }
        function onTrackingReadyAction() {
            trackingManager.trackingReady();
        }

        function onTrackingStartAction() {
            isTracking = true
            trackRectLayer.clearCanvasOnly()
            trackingManager.trackingStart();
        }
        function onTrackingStopAction(cancel) {
            isTracking = false
            trackRectLayer.hasMoved = false
            trackingManager.trackingStop(cancel);
        }
        function onTrackingEditAction(enter, isEnd, isSupportTk) {
            trackingManager.trackingEdit(enter,isEnd)
        }

        function onPushImage(buffer, width, height, timeStamp) {
            trackingManager.pushImage(buffer, width, height, timeStamp)
        }

        function onTrackingRecommandListChanged(rectList) {
            trackRectLayer.trackingRecommandListChanged(rectList)
        }

        function onTrackingRectListChanged(rectList, mainRectIndex, trackingIsLoss, bodyRectIndex, sampleFramePtsUs) {
            if (mainRectIndex >= rectList.length) {
                return
            }

            var rect = rectList[mainRectIndex]
            if (rect === null || rect === undefined) {
                return
            }

            trackRectLayer.trackingRectListChanged(rectList, mainRectIndex, trackingIsLoss, bodyRectIndex)

            // 发送信号，处理目标居中逻辑
            globalSignal.trackingRectCenter(Qt.rect(rect.x, rect.y, rect.width, rect.height), trackRectLayer.getVideoSize(), false, trackingIsLoss, false, sampleFramePtsUs)
        }

        function onTrackingRectChanged(centerX, centerY, widthRatio, heightRatio, trackingIsLoss) {
            // 刷新tracking 框ui
            trackRectLayer.trackingRectChanged(centerX, centerY, widthRatio, heightRatio, trackingIsLoss);
            // 发送信号，处理目标居中逻辑
            globalSignal.trackingRectCenter(Qt.rect(centerX, centerY, widthRatio, heightRatio), trackRectLayer.getVideoSize(), false, trackingIsLoss, false, -1)
        }

        function onTrackingStateChanged(status) {
            currentStatus = status
            if (status === TrackingManager.TK_ENTER) {
                content.enabled = false
                lightOverlayMask.visible = true
                lightOverlayMask.addData(playerRect)

                // 框父布局
                trackRectLayerRoot.visible = true
                trackRectLayerRoot.enabled = true
                trackControllerRoot.visible = true
                trackControllerRoot.enabled = true
                trackController.tkReady = false

                refreshTkControl()

            } else if (status === TrackingManager.TK_EXIT) {
                content.enabled = true
                // 蒙层
                lightOverlayMask.visible = false
                lightOverlayMask.clearData(true)

                // 框父布局
                trackController.tkReady = false
                trackController.startTk = false
                trackRectLayer.startTk = false
                trackRectLayer.clearData()

                // 画框控件
                trackRectLayerRoot.visible = false
                trackRectLayerRoot.enabled = false
                trackControllerRoot.visible = false
                trackControllerRoot.enabled = false
                close()

            } else if (status === TrackingManager.TK_READY) {
                trackController.tkReady = true
            } else if (status === TrackingManager.TK_START) {
                trackController.startTk = true
                trackRectLayer.startTk = true
                // 根据用户拖拽框信息，先走居中逻辑
                globalSignal.trackingRectCenter(trackRectLayer.getRectPositionInfo(), trackRectLayer.getVideoSize(), true, false, true, -1)
                // 下面的play之所以要放在这儿，主要是为了保证时序，先把当前框信息给到机器学习，然后再开始播放
                // trackingManager.votPrototal(trackRectLayer.getRectPositionInfo())
                // trackingManager.votPrototal(trackRectLayer.getRectCenterPositionInfo())
                // editorManager.play()
            } else if (status === TrackingManager.TK_STOP) {
                trackController.tkReady = false
                trackController.startTk = false
                trackRectLayer.startTk = false
                trackRectLayer.clearData()

                if(editorManager.isInUserGuideStatus){
                    globalSignal.exitTkGuideModel(true);
                }
            } else if (status === TrackingManager.TK_EDIT) {
            }
        }

        function onTrackingRectCenterGen(centerX, centerY, widthRatio, heightRatio) {
            logger.d("Tracking triggered! target is [" + centerX + ", " + centerY + "," + widthRatio + ", " + heightRatio + "]")
            editorManager.refreshPlayer()
            trackingManager.setRect( Qt.rect(centerX, centerY, widthRatio, heightRatio))

            // 把方框居中优先画面居中执行的逻辑注释掉
            // globalSignal.trackingRectChanged(centerX, centerY, widthRatio, heightRatio, false)

            trackRectLayer.updateSelectedTarget(Qt.rect(centerX, centerY, widthRatio, heightRatio))
        }

        function onDeathZoneFactorChanged(factor, vOffset) {
            trackRectLayer.updateDeathZoneFactor(factor, vOffset)
        }

        function onPlayerProfileSizeChanged() {
            delayTimer.start()
        }

        // 高倍速片段启动 tk 会被恢复为 1 倍速，片段在轨道上重排变宽；selectItemRect 抠图矩形须按
        // 新宽度重取，否则常亮抠图仍停留在旧的高倍速宽度。片段 ItemView 宽度经草稿→VM→绑定异步更新，
        // 未必同步 settled，复用 delayTimer 延后重取（同 onPlayerProfileSizeChanged 时序保护）。
        function onRefreshPanoramaKeyframeUi(track, clip) {
            delayTimer.restart()
        }
    }

    Timer {
        // MKDisplayView在Line:99的地方有一个35ms的delay，用来避免画面拉伸。导致去数据的时候是错的
        id: delayTimer
        interval: 50 // 毫秒
        repeat: false  // 是否重复（默认单次）
        onTriggered: {
            dealWindowSizeChanged()
        }
    }

    Connections {
        target: trackingManager
        function onTrackingStateChanged(status) {
            globalSignal.trackingStateChanged(status)
        }
    }

    function dealWindowSizeChanged() {
        playerRect = playerPanel.getPlayerPosition()
        playerControllerRect = playerPanel.getPlayerControllerPosition()
        playerPanelRect = Qt.rect(UiUtils.getGlobalPosition(playerPanel).x,
                                 UiUtils.getGlobalPosition(playerPanel).y,
                                 playerPanel.width,
                                 playerPanel.height)
        selectItemRect = tracks.getSelectItemRect()
        refreshMask()
        refreshTkControl()
    }

    onWidthChanged: {
        dealWindowSizeChanged()
    }

    onHeightChanged: {
        dealWindowSizeChanged()
    }

    onOpened: {
        dealWindowSizeChanged()
    }

    onClosed: {
        globalSignal.trackingStateChanged(TrackingManager.TK_EXIT)
        trackingGuide.visible = false;
    }
}
