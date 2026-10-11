import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.15
import Config 1.0
import Controls 1.0
import Nova 1.0
import TrackingManager 1.0
import MKPlayerController 1.0
import QPlayType 1.0
import Qt5Compat.GraphicalEffects
import "../controller"
import "../explorer"
import AgencyFileLostViewModel 1.0
import UserGuideTypeModel 1.0
import UsedFunctionManager 1.0
import ProjectSettingsInfo 1.0
import PreviewTracker 1.0

Rectangle {
    id: root
    required property MKPlayerController player
    color: Colors.color_content_area_background

    signal fullscreenClicked
    signal captureClicked
    objectName: actionableItemName.playerController
    height: 58
    width: parent.width

    property bool isTracking: false
    property var selectedAgencyType : Instance.AGENCY_TYPE_CLOSE

    signal togglePlayState(bool start);

    property string stutterTipText: ""

    function showStutterBubble(text) {
        stutterTipText = text;
        stutterBubbleLoader.active = true

        var bubble = stutterBubbleLoader.item
        bubble.visible = true;
        //清晰度切换弹窗5s后自动消失
        stutterBubbleAutoHideTimer.restart();
    }

    function hideStutterBubble() {
        var bubble = stutterBubbleLoader.item
        if (bubble) {
            bubble.visible = false;
        }

        stutterBubbleLoader.active = false
    }

    //如果是windows intel 电脑,则弹窗提醒开启代理功能
    function showProxySuggestPopupIfNeed() {

        // 自动化测试绿灯：屏蔽该特殊UI弹窗，避免干扰模拟点击
        if (lightSetting.getBool("auto_test_greenlight", false)) {
            return;
        }

        // 是否提示过
        if (lightSetting.getBool("hasShowProxyAlert", false)) {
            return;
        }
        // 是否有素材
        if(player.totalFrames <= 0) {
            return;
        }
        // 是否显示过新手指引
        if(!lightSetting.getBool("first_add_draft", false)){
            return;
        }
        // 判断当时是否非新手指引
        if(editorManager.isInUserGuideStatus){
            return
        }
        // 是否低性能设备
        if(!Tools.isIntegratedGraphics()){
            return;
        }
        // 导出面板显示中
        if(composeLoader.item && composeLoader.item.visible) {
            return;
        }
        if (isTracking) {
            return;
        }

        lightSetting.save("hasShowProxyAlert", true);
        proxySuggestPopup.open()
    }


    Connections {
        target: globalSignal
        function onActivedProjectChanged(proId) {
            if (proId !== -1) {
                    root.selectedAgencyType = PreviewQualityViewModel.useSuperHD ? Instance.AGENCY_TYPE_SUPER_HD : (editorManager.useMaterialProxy ? Instance.AGENCY_TYPE_OPEN : Instance.AGENCY_TYPE_CLOSE)
            }
        }
    }

    ConfirmPopup {
        id: proxySuggestPopup
        objectName: actionableItemName.proxySuggestPopup
        title: qsTr("pccut_performance_save_local_tips")
        text: qsTr("pccut_proxy_note")
        leftButtonText: qsTr("pccut_proxy_note_cancel")
        rightButtonText: qsTr("pccut_proxy_note_yes")
        onRightButtonClicked: {
            proxySuggestPopup.close()
            globalSignal.clickProxySuggestPopup();
        }
     }

    // 播放器进度条
    PlayerSlider {
        enabled: player.totalFrames > 0
        y: 8
        id: playerSlider
        height: 10
        width: parent.width
        from: 0
        to: player.totalFrames
        // 边下边播临时预览时显示已缓冲灰条（非流式态 editorManager.cachedRanges 恒空，无灰条）
        cachedRanges: editorManager.cachedRanges
        onValueChanged: {
            if (pressed) {
                PreviewTracker.setUserSeek(true);
                player.seekFrame(value);
            }
        }
        Connections {
            target: player
            function onPlayedFrameChanged(role) {
                // 裁切中更新这个UI跳动很频繁看着比较乱
                // 轨道hover预览不更新
                // 拖动中不回写：连续 seek 期间引擎异步回灌陈旧位置，会把 handle 从手指下拽走(反向拖动尤其明显)
                if (playerSlider.pressed) {
                    return;
                }

                if (!tracks.flickable.isFragmentClipping && !(role == 2 && editorManager.playType === QPlayType.editor)) {
                    playerSlider.value = player.playedFrame;
                     showProxySuggestPopupIfNeed();
                }
            }
        }
        // 拖动标记预览 seek 时进度条跟随预览帧同步移动：拖动标记走 previewSeek(ROLE_PREVIEW_SEEK，role==2)，
        // 上面的 onPlayedFrameChanged 会过滤 role==2 不更新进度条，故这里在拖动期间直接用 previewFrame 驱动进度条。
        // 仅拖动(markDragging)时跟随，悬停标记不跟随(避免进度条跳动)；拖动结束后下次真实帧变更自动回同步。
        property bool markDragging: false
        Connections {
            target: globalSignal
            function onMarkPointDragging(dragging) {
                playerSlider.markDragging = dragging;
            }
            function onPreviewFrame(frame) {
                if (playerSlider.markDragging) {
                    playerSlider.value = frame;
                }
            }
        }
        Connections {
            target: editorManager
            function onIsInUserGuideStatusChanged(){
                if(editorManager.isInUserGuideStatus){
                   return
                }
                showProxySuggestPopupIfNeed()
            }
        }

        Connections {
            target: globalSignal

            function onTrackingStateChanged(status) {
                if (status === TrackingManager.TK_ENTER) {
                    isTracking = true
                } else if (status === TrackingManager.TK_EXIT) {
                    isTracking = false
                }
            }
        }
    }
    // 画幅选择
    Loader {
        id: canvasSettingPanelLoader
        active: false
        sourceComponent: CanvasSettingPanel {
            id: canvasSettingPanel
            parent: Overlay.overlay
            closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
            Overlay.modal: Rectangle {
                color: Colors.transparent
            }
            objectName: "canvasSettingPanel"
            // 接收画幅选择界面的信号
            onClickCanvasItemSignal: (new_canvas_type) => {
                editorManager.pause();
                editorManager.setCanvasManualChanged(true);
                canvasBg.canvasSelecting = false;
                CanvasController.setRatioByCanvasType(new_canvas_type);
                editorDraftManager.saveDraft()
                let item = videoConfig.getQmlItemByCanvasType(new_canvas_type);
                var projectId = draftManager.activeProjectEnvId();
                UsedFunctionManager.addFunction(projectId,UsedFunctionManager.EditorFunctionType.ASPECT_RATIO);
                eventTracker.trackEvent("pccut_player_ratio_click", {"aspect_ratio": item.name})
            }
            onCloseSignal: {
                console.log("canvasSettingPanel close");
                canvasBg.canvasSelecting = false;
            }
        }
    }

    Item {
        y: 14
        height: 44
        width: parent.width

        Text {
            id: playProgress
            property string progress: getProgress()

            text: progress
            verticalAlignment: Text.AlignVCenter
            color: root.enabled ? Colors.color_EEEEEE : Colors.color_444444
            width: 72
            anchors {
                left: parent.left
                leftMargin: 12
                top: parent.top
                bottom: parent.bottom
            }

            font {
                pixelSize: 12
                weight: Font.Medium
            }

            function getProgress() {
                const fps = player.fps();
                if (player.playedFrame < 0 || player.totalFrames <= 0 || fps <= 0) {
                    return "00:00:00:00";
                }
                const playedProgress = DurationFormatter.format(player.playedFrame, fps);
                return `${playedProgress}`;
            }
        }

        Text {
            id: splitText

            text: "/";
            verticalAlignment: Text.AlignVCenter
            color: root.enabled ? Colors.color_666666 : Colors.color_444444

            anchors {
                left: playProgress.right
                top: parent.top
                bottom: parent.bottom
            }

            font {
                pixelSize: 12
                weight: Font.Medium
            }
        }

        Text {
            id: totalProgress

            property string progress: getProgress()

            text: progress
            verticalAlignment: Text.AlignVCenter
            color: root.enabled ? Colors.color_666666 : Colors.color_444444

            anchors {
                left: splitText.right
                leftMargin: 3
                top: parent.top
                bottom: parent.bottom
            }

            font {
                pixelSize: 12
                weight: Font.Medium
            }

            function getProgress() {
                const fps = player.fps();
                if (player.playedFrame < 0 || player.totalFrames <= 0 || fps <= 0) {
                    return "00:00:00:00";
                }
                const totalProgress = DurationFormatter.format(player.totalFrames, fps);
                return `${totalProgress}`;
            }
        }

        // 画幅
        Rectangle {
            id: canvasBg
            width: 20
            height: 20
            radius: 4
            color: Colors.transparent
            opacity: editorManager.playType == QPlayType.editor && editorManager.isInEditeState ? 1 : 0.2
            property bool canvasSelecting: false

            anchors {
                verticalCenter: parent.verticalCenter
                right: agencyImgBg.left
                rightMargin: 10
            }

            function getCanvasIconSource() {
                switch(editorManager.canvasType) {
                    case 2: // CANVASRATIOTYPE_3_4
                        return "qrc:/icons/player/ic_canvas_3_4.svg";
                    case 3: // CANVASRATIOTYPE_4_3
                        return "qrc:/icons/player/ic_canvas_4_3.svg";
                    case 4: // CANVASRATIOTYPE_9_16
                        return "qrc:/icons/player/ic_canvas_9_16.svg";
                    case 5: // CANVASRATIOTYPE_16_9
                    case 8: // CANVASRATIOTYPE_16_9_SETTING（用户在项目设置中手动确认的16:9，与默认16:9同图标）
                        return "qrc:/icons/player/ic_canvas_16_9.svg";
                    case 1: // CANVASRATIOTYPE_1_1
                    default:
                        return "qrc:/icons/player/ic_canvas_1_1.svg";
                }
            }
            Rectangle {
                id: canvas
                anchors.centerIn: parent
                width: 20
                height: 20
                color: Colors.color_transparent

            Image {
                id: canvasTypeIcon
                anchors.fill: parent
                source: canvasBg.getCanvasIconSource()
                sourceSize: Qt.size(20, 20)
            }

            // 使用 ColorOverlay 改变颜色
            layer.enabled: true
            layer.effect: ColorOverlay {
                color: canvasMouseArea.containsMouse ? Colors.color_FFFFFF : Colors.color_EEEEEE
            }
            MouseArea {
                id: canvasMouseArea
                anchors.fill: parent
                hoverEnabled: true
                enabled: editorManager.playType == QPlayType.editor && editorManager.isInEditeState
                onClicked: {
                    // 展示画幅选择界面
                    canvasBg.canvasSelecting = true;
                    canvasSettingPanelLoader.active = false;
                    canvasSettingPanelLoader.active = true;
                    var canvasSettingPanel = canvasSettingPanelLoader.item;
                    canvasSettingPanel.show(canvasBg, editorManager.canvasType);
                    }
                }
            }
        }

        // 流畅度切换
        Rectangle {
            id: agencyImgBg
            width: 20
            height: 20
            radius: 4
            color: Colors.transparent
            // 边下边播（流式源）不支持切换清晰度，置灰
            opacity: root.enabled && !editorManager.isCloudStreamingPreview ? 1 : 0.2

            anchors {
                verticalCenter: parent.verticalCenter
                rightMargin: 10
                right: captureBg.left
            }

        Image {
            id: agencyImg
            width: 20
            height: 20
            anchors.centerIn: parent
            property string sdImg: translationHandler.isChineseLang() ? "qrc:/icons/preview/preview_mode_switch_sd_zh.svg" : "qrc:/icons/preview/preview_mode_switch_sd_en.svg"
            property string hdImg: translationHandler.isChineseLang() ? "qrc:/icons/preview/preview_mode_switch_hd_zh.svg" : "qrc:/icons/preview/preview_mode_switch_hd_en.svg"
            property string uhdImg: translationHandler.isChineseLang() ? "qrc:/icons/preview/preview_mode_switch_uhd_zh.svg" : "qrc:/icons/preview/preview_mode_switch_uhd_en.svg"

            source: {
                if (root.selectedAgencyType === Instance.AGENCY_TYPE_SUPER_HD) {
                    return uhdImg;
                } else if (root.selectedAgencyType === Instance.AGENCY_TYPE_CLOSE) {
                    return hdImg;
                } else {
                    return sdImg;
                }
            }
            sourceSize: Qt.size(40, 40)
            antialiasing: true

            // 使用 ColorOverlay 改变颜色
            layer.enabled: true
            layer.effect: ColorOverlay {
                color: agencyMouseArea.containsMouse ? Colors.color_FFFFFF : Colors.color_EEEEEE
            }
            MouseArea {
                id: agencyMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                // 边下边播（流式源）不支持切换清晰度，禁用点击
                enabled: !editorManager.isCloudStreamingPreview
                onClicked: {
                    agencyPopupLoader.showPopup(agencyImgBg);
                }
            }

            AgencyFileLostViewModel{
                id: agencyFileLostViewModel

                onAgencyFileLossSignal:{ //有循环录影素材丢失代理时，弹高级弹窗(缺失列表+打开目录)
                    if (agencyFileLostViewModel.hasLoopRecordingLost()) {
                        agencyTipsAdvancedLoader.active = true;
                        if (agencyTipsAdvancedLoader.item) {
                            agencyTipsAdvancedLoader.item.open();
                        }
                    } else {
                        agencyTipsLoader.active = true;
                        agencyTipsLoader.item.open();
                    }
                }

                onExtraAudioFileLossSignal : {
                    //提示额外的音频文件丢失
                    var lostCount = agencyFileLostViewModel.getTrackMediaOfLostExtraAudioFile();
                    if (lostCount > 1) {
                        toast.showToast(qsTr("pccut_panel_audio_lost_toast_2").arg(lostCount), "tracks", false, toast.durationLong);
                    } else {
                        toast.showToast(qsTr("pccut_panel_audio_lost_toast"), "tracks", false, toast.durationLong);
                    }
                }
            }
            // 流畅模式
            Loader {
                id: agencyPopupLoader
                active: false
                sourceComponent: SubTitlePopup {
                    shaderSourceItem: mainPanel
                    onClickType: (modeType) => {
                        var toastTip = qsTr("pccut_player_preview_mode_smooth_tip");
                        if (modeType === Instance.AGENCY_TYPE_OPEN) {
                            if (!editorManager.useMaterialProxy) {
                                var count = agencyFileLostViewModel.getTrackMediaOfNoAgencyFile();
                                 if (count <= 0) {
                                     editorManager.useMaterialProxy = true;
                                 } else if (agencyFileLostViewModel.hasLoopRecordingLost()) {
                                     agencyTipsAdvancedLoader.active = true;
                                     if (agencyTipsAdvancedLoader.item) {
                                         agencyTipsAdvancedLoader.item.open();
                                     }
                                     return;
                                 } else {
                                     agencyTipsLoader.active = true;
                                     agencyTipsLoader.item.open();
                                     return;
                                 }
                                 //切换成流畅模式的时候隐藏切换清晰度提示
                                 hideStutterBubble();
                            }
                        } else if (modeType === Instance.AGENCY_TYPE_CLOSE  || modeType === Instance.AGENCY_TYPE_SUPER_HD) {
                            //清晰度切换时,弹窗标识重置
                            videoStutterDetector.resetStutterPopup();
                            if (editorManager.useMaterialProxy) {
                                editorManager.useMaterialProxy = false;
                            }
                            if(modeType === Instance.AGENCY_TYPE_SUPER_HD){
                                toastTip = qsTr("pccut_player_preview_mode_UHD_tip");
                            }
                            else{
                                toastTip = qsTr("pccut_player_preview_mode_HD_tip");
                            }
                        }
                        agencyFileLostViewModel.enableOriginalPreview(modeType === Instance.AGENCY_TYPE_SUPER_HD);
                        root.selectedAgencyType = modeType;
                        toast.showToast(toastTip, "playerPanel");
                    }
                    onClosed: {
                        agencyPopupLoader.active = false;
                    }
                }

                function showPopup(widget) {
                    agencyPopupLoader.active = true;

                    // 提取枚举值为局部变量，提高可读性
                    const AGENCY_TYPE = Instance.AGENCY_TYPE;

                    // 清空现有模型
                    item.listModel.clear();

                    // 定义预览模式选项
                    const previewModes = [
                        {
                            title: qsTr("pccut_player_preview_mode_UHD_switch"),
                            subTitle: qsTr("pccut_player_preview_mode_UHD_toast"),
                            type: AGENCY_TYPE.AGENCY_TYPE_SUPER_HD
                        },
                        {
                            title: qsTr("pccut_player_preview_mode_hd_switch"),
                            subTitle: qsTr("pccut_player_preview_mode_hd_desc"),
                            type: AGENCY_TYPE.AGENCY_TYPE_CLOSE
                        },
                        {
                            title: qsTr("pccut_player_preview_mode_smooth_switch"),
                            subTitle: qsTr("pccut_player_preview_mode_smooth_desc"),
                            type: AGENCY_TYPE.AGENCY_TYPE_OPEN
                        }
                    ];

                    // 添加选项到模型
                    for (let mode of previewModes) {
                        item.listModel.append({
                            title: mode.title,
                            subTitle: mode.subTitle,
                            type: mode.type,
                            checked: mode.type === root.selectedAgencyType
                        });
                    }

                    item.open();
                    item.y = item.y - item.height - 8;
                    item.x = item.x - (202 - widget.width) / 2;
                }
            }
            // 提示弹框
            Loader {
                id: agencyTipsLoader
                active: false
                sourceComponent: AgencyFileLostPop {
                    isHideOpenAgencyBtn: agencyFileLostViewModel.isAllNoAgencyFile();
                    onLeftButtonClicked: {
                        close()
                    }

                    onRightButtonClicked: {
                        editorManager.useMaterialProxy = true;
                        toast.showToast(qsTr("pccut_player_preview_mode_smooth_tip"), "playerPanel");
                        agencyFileLostViewModel.enableOriginalPreview(false);
                        root.selectedAgencyType = Instance.AGENCY_TYPE_OPEN;
                        close()
                    }

                    onClosed: {
                        agencyTipsLoader.active = false;
                    }

                }

                onActiveChanged: {
                    globalSignal.enablePlayerViewGesture(!active)
                }
                }
            }
            // 循环录影代理文件部分缺失弹窗
            Loader {
                id: agencyTipsAdvancedLoader
                active: false
                sourceComponent: AgencyFileLostPopAdvanced {
                    //*#*#*# 循环录影：所有丢失代理的文件名列表
                    lostFileList: agencyFileLostViewModel.lostFileNames()
                    onContinueClicked: {
                        editorManager.useMaterialProxy = true;
                        agencyFileLostViewModel.enableOriginalPreview(false);
                        root.selectedAgencyType = Instance.AGENCY_TYPE_OPEN
                        close()
                    }
                    onOpenOsvDirClicked: {
                        Qt.openUrlExternally(agencyFileLostViewModel.firstLostFileDirPath())
                    }
                    onClosed: {
                        agencyTipsAdvancedLoader.active = false
                    }
                }
                onActiveChanged: {
                    globalSignal.enablePlayerViewGesture(!active)
                }
            }
        }
        // 截屏
        Rectangle {
            id: captureBg
            width: 20
            height: 20
            radius: 4
            color: Colors.transparent
            // 边下边播（流式源）不支持截图，置灰
            opacity: root.enabled && !editorManager.isCloudStreamingPreview ? 1 : 0.2

            anchors {
                verticalCenter: parent.verticalCenter
                rightMargin: 10
                right: fullscreenBg.left
            }

            Image {
                id: capture
                width: 20
                height: 20
                anchors.centerIn: parent
                source: "qrc:/icons/player/ic_screenshot.svg"
                sourceSize: Qt.size(20, 20)

                // 使用 ColorOverlay 改变颜色
                layer.enabled: true
                layer.effect: ColorOverlay {
                    color: captureMouseArea.containsMouse ? Colors.color_FFFFFF : Colors.color_EEEEEE
                }
                MouseArea {
                    id: captureMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    // 边下边播（流式源）不支持截图，禁用点击
                    enabled: !editorManager.isCloudStreamingPreview
                    onClicked: {
                        player.pause();
                        captureClicked();
                    }
                }
            }
        }

        // 全屏
        Rectangle {
            id: fullscreenBg
            width: 20
            height: 20
            radius: 4
            color: Colors.transparent
            opacity: root.enabled ? 1 : 0.2

            anchors {
                verticalCenter: parent.verticalCenter
                rightMargin: 10
                right: parent.right
            }

            Image {
                id: fullscreen
                width: 20
                height: 20
                anchors.centerIn: parent
                source: "qrc:/icons/player/ic_fullscreen.svg"
                sourceSize: Qt.size(20, 20)

                // 使用 ColorOverlay 改变颜色
                layer.enabled: true
                layer.effect: ColorOverlay {
                    color: fullscreenMouseArea.containsMouse ? Colors.color_FFFFFF : Colors.color_EEEEEE
                }
                MouseArea {
                    id: fullscreenMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    preventStealing: true
                    onClicked: {
                        fullscreenClicked();
                    }
                }
            }
        }

        RowLayout {
            height: parent.height
            anchors.centerIn: parent
            spacing: 20

            Rectangle {
                width: 28
                height: 28
                Layout.alignment: Qt.AlignVCenter
                radius: 4
                color: Colors.transparent
                Image {
                    id: start
                    width: 20
                    height: 20
                        anchors.centerIn: parent
                    source: "qrc:/icons/player/ic_start.svg"
                    sourceSize: Qt.size(20, 20)
                    opacity: root.enabled ? 1 : 0.2

                    // 使用 ColorOverlay 改变颜色
                    layer.enabled: true
                    layer.effect: ColorOverlay {
                        color: startMouseArea.containsMouse ? Colors.color_FFFFFF : Colors.color_EEEEEE
                    }

                    MouseArea {
                        id: startMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            player.seekStart();
                        }
                    }
                }
            }

            Rectangle {
                width: 28
                height: 28
                Layout.alignment: Qt.AlignVCenter
                radius: 4
                color: Colors.transparent

                Image {
                    id: play
                    objectName:actionableItemName.mainPlayerControl
                    width: 20
                    height: 20
                    anchors.centerIn: parent
                    source: player.playing ? "qrc:/icons/player/ic_pause.svg" : "qrc:/icons/player/ic_play.svg"
                    sourceSize: Qt.size(20, 20)
                    opacity: root.enabled ? 1 : 0.2

                    // 使用 ColorOverlay 改变颜色
                    layer.enabled: true
                    layer.effect: ColorOverlay {
                        color: playMouseArea.containsMouse ? Colors.color_FFFFFF : Colors.color_EEEEEE
                    }

                    MouseArea {
                        id: playMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if(editorManager.isInUserGuideStatus
                                && (UserGuideType.KEYFRAME === mask.userGuideType || UserGuideType.REGIONKEYFRAME === mask.userGuideType)
                            ){
                                globalSignal.userGuideNextStepPlay();
                                return;
                            }
                            player.togglePlayState();
                            togglePlayState(player.playing);
                        }
                    }

                    onSourceChanged: {
                        if(editorManager.isInUserGuideStatus && editorManager.playType !== QPlayType.preview){
                            // 这里的逻辑主要是处理主流程引导时第三步点击播放完之后，自动跳到下一步指引
                            if(!player.playing){
                                // globalSignal.nextStepInAllGuide();  // 暂时移除掉，修复06.13号左右代码修改导致新手引导第一步错乱的问题
                            }
                        }
                    }
                }
            }
            Rectangle {
                width: 28
                height: 28
                Layout.alignment: Qt.AlignVCenter
                radius: 4
                color: Colors.transparent

                Image {
                    id: end
                    width: 20
                    height: 20
                    anchors.centerIn: parent
                    source: "qrc:/icons/player/ic_end.svg"
                    sourceSize: Qt.size(20, 20)
                    opacity: root.enabled ? 1 : 0.2

                    // 使用 ColorOverlay 改变颜色
                    layer.enabled: true
                    layer.effect: ColorOverlay {
                        color: endMouseArea.containsMouse ? Colors.color_FFFFFF : Colors.color_EEEEEE
                    }

                    MouseArea {
                        id: endMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            player.seekEnd();
                        }
                    }
                }
            }
        }

        // Loader 同级，放在外面
        TextMetrics {
            id: bubbleTextMetrics
            font.pixelSize: 12
            font.weight: Font.Medium
            font.letterSpacing: 0
            text: root.stutterTipText
        }

        Loader {
             id: stutterBubbleLoader
             active: false

             Timer {
                 id: stutterBubbleAutoHideTimer
                 interval: 5000
                 repeat: false
                 onTriggered: hideStutterBubble()
             }
             property string tipText: ""
             property int tipsWidth:  Math.min(Math.ceil(bubbleTextMetrics.width) + 16, 300)

             sourceComponent: Component {
                 BaseNotificationTips {
                    id: stutterBubble
                    parent: mainPanel
                    x: {
                        // 直接追踪 agencyImgBg 位置，否则冒泡位置不会跟随窗口大小进行实时移动
                        agencyImgBg.x; agencyImgBg.y;
                        var pos = agencyImgBg.mapToItem(mainPanel, 0, 0);
                        return pos.x - (width - agencyImgBg.width) / 2;
                    }
                    y: {
                        // 直接追踪 agencyImgBg 位置和root.y位置，否则冒泡位置不会跟随窗口大小进行实时移动
                        agencyImgBg.x; agencyImgBg.y; root.y; 
                        var pos = agencyImgBg.mapToItem(mainPanel, 0, 0);
                        return pos.y - height;
                    }
                    width: stutterBubbleLoader.tipsWidth
                    showArrow: true
                    arrowLeftMargin: width / 2 - arrowWidth / 2 + contentLeftMargin
                    text: root.stutterTipText
                    backgroundColor: Colors.color_EEEEEE
                    arrowSource: "qrc:/icons/panorama/transition_effect_arrow_white.svg"
                    fontSize: 12
                    fontWeight: Font.Medium
                    textColor: Colors.color_141414
                    arrowWidth: 12
                    contentBottomMargin:6
                    lineHeight: 16
                    letterSpacing: 0
                    textWrapMode: bubbleTextMetrics.width + 16 > 300 ? Text.WordWrap : Text.NoWrap
                 }
             }
         }
    }
}
