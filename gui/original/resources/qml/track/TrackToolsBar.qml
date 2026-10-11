import Config 1.0
import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.3
import QtQuick.Window 2.15
import Controls 1.0
import TrackDockViewModel 1.0
import ShortcutAction 1.0
import TrackingManager 1.0
import "../tracking"
import KeyframeBtnViewModel 1.0
import VideoFragmentViewModel 1.0
import MarkPointToolbarViewModel 1.0
import MultiTrackView 1.0
import QmlConstants 1.0
import Qt5Compat.GraphicalEffects
import MediaTypeModel 1.0
import app_qrc 1.0
import PanoramaConfig 1.0
import UserGuideTypeModel 1.0
import UsedFunctionManager 1.0
import ProjectSettingsInfo 1.0
import Nova 1.0
import "../user_guide"

/**
* Created by whiskey.cao on 2024-02-06 .
* ClassName : TrackToolsBar
* Description :自定义Track bar 工具条
* Copyright : ©2024 Light All Rights Reserved.
*/
Rectangle {
    id: root
    objectName:actionableItemName.trackToolsBar
    width: parent.width
    height: parent.height
    color: Colors.color_title_area_background

    required property TrackDockViewModel trackInfo
    property bool isInTrackingFragment: false

    // 点击tracking入口发送这个信号
    signal clickTrackingEntance()
    required property KeyframeBtnViewModel keyFrameViewModel
    property real indicatorFrame
    property VideoFragmentViewModel viewModel: VideoFragmentViewModel {}
    property bool isInEditeState
    property string firstAddKf: "first_add_kf"
    property bool trackingInited: false
    property bool trackingNonHeldInited: false
    property bool deviceIsAmd: false
    // 超级慢动作由 Nova SpeedViewModel 的“曲线变速 + VFI”组合态驱动。
    // 不在工具栏维护独立的旧 hasSuperSlow 状态。
    property var superSlowViewModel: (typeof settingPanel !== "undefined" && settingPanel)
                                      ? settingPanel.speedViewModel : null

    property int tkInitDuration: -1


    Connections {
        target: trackInfo
        function onIndicatorFrameChanged() {
            editorManager.setIndicatorFrame(trackInfo.indicatorFrame);
        }
    }

    signal splitClicked(int operationType)
    // 轨道缩放
    signal trackScale(real scale)
    // 片段裁切信号
    signal cutBtnClickedSignal(bool isLeftCut, int operationType)
    // 素材裁切
    signal videoClipClickedSignal()


    MouseArea {
        anchors.fill: parent
        onPressed: (mouse) => {
            globalSignal.cleanSelectMediaPath();
            mouse.accepted = false;
        }
    }

    TrackToolsButton {
        id: undoButton
        opacity: UndoController.canUndo ? 1 : 0.2
        layer.enabled: true
        anchors.left: parent.left
        anchors.leftMargin: 12
        pressedColor: UndoController.canUndo ? Colors.color_19191A : Colors.color_transparent
        hoverColor: UndoController.canUndo ? Colors.color_track_tool_button_background_hovered : Colors.color_transparent
        hoverTextFunc: function() {
            return qsTr("pccut_menu_undo") + ShortcutConfig.actionTips(ShortcutAction.UN_DO);
        }
        iconSource: "qrc:/app_qrc/icons/icon_undo.svg"
        Accessible.role: Accessible.Button
        externalOpacity: true
        onClicked: {
            if (UndoController.canUndo) {
                UndoController.undo();
                eventTracker.trackEvent("pccut_undo_click", {"use_method": "navigation_bar"})
                var projectId = draftManager.activeProjectEnvId();
                UsedFunctionManager.undo(projectId);
            }
        }
    }

    TrackToolsButton {
        id: redoButton
        opacity: UndoController.canRedo ? 1 : 0.2
        layer.enabled: true
        anchors.left: undoButton.right
        anchors.leftMargin: 24
        pressedColor: UndoController.canRedo ? Colors.color_19191A : Colors.color_transparent
        hoverColor: UndoController.canRedo ? Colors.color_track_tool_button_background_hovered : Colors.color_transparent
        hoverTextFunc: function() {
            return qsTr("pccut_menu_redo") + ShortcutConfig.actionTips(ShortcutAction.RE_DO);
        }
        iconSource: "qrc:/app_qrc/icons/icon_redo.svg"
        Accessible.role: Accessible.Button
        externalOpacity: true
        onClicked: {
            if (UndoController.canRedo) {
                UndoController.redo();
                eventTracker.trackEvent("pccut_redo_click", {"use_method": "navigation_bar"})
                var projectId = draftManager.activeProjectEnvId();
                UsedFunctionManager.redo(projectId);
            }
        }
    }

    TrackToolsButton {
        id: splitButton
        opacity: isInEditeState && trackInfo.hasIntentFragment ? 1 : 0.2
        layer.enabled: true
        anchors.left: redoButton.right
        anchors.leftMargin: 24
        pressedColor: isInEditeState && trackInfo.hasIntentFragment ? Colors.color_19191A : Colors.color_transparent
        hoverColor: isInEditeState && trackInfo.hasIntentFragment ? Colors.color_track_tool_button_background_hovered : Colors.color_transparent
        hoverTextFunc: function() {
            return qsTr("pccut_shortcut_b") + ShortcutConfig.actionTips(ShortcutAction.SPLIT);
        }
        iconSource: "qrc:/app_qrc/icons/ic_split.svg"
        Accessible.role: Accessible.Button
        Accessible.description: "videoedit_split"
        externalOpacity: true
        onClicked: {
            if(trackInfo.hasIntentFragment) {
                splitClicked(MultiTrackView.NavigationBar);
            }
        }
    }

    TrackToolsButton {
        id: cutStartButton
        visible: true
        opacity: isInEditeState && trackInfo.hasIntentFragment ? 1 : 0.2
        layer.enabled: true
        anchors.left: splitButton.right
        anchors.leftMargin: 24
        pressedColor: isInEditeState && trackInfo.hasIntentFragment ? Colors.color_19191A : Colors.color_transparent
        hoverColor: isInEditeState && trackInfo.hasIntentFragment ? Colors.color_track_tool_button_background_hovered : Colors.color_transparent
        hoverTextFunc: function() {
            return qsTr("pccut_navigation_trim_beginning");
        }
        iconSource: "qrc:/app_qrc/icons/ic_cutstart.svg"
        Accessible.role: Accessible.Button
        Accessible.description: "videoedit_lefttrim"
        externalOpacity: true
        onClicked: {
            if(isInEditeState && trackInfo.hasIntentFragment) {
                cutBtnClickedSignal(true, MultiTrackView.NavigationBar);
            }
        }
    }

    TrackToolsButton {
        id: cutEndButton
        objectName: actionableItemName.trackDockCutToRight
        visible: true
        opacity: isInEditeState && trackInfo.hasIntentFragment ? 1 : 0.2
        layer.enabled: true
        anchors.left: cutStartButton.right
        anchors.leftMargin: 24
        pressedColor: isInEditeState && trackInfo.hasIntentFragment ? Colors.color_19191A : Colors.color_transparent
        hoverColor: isInEditeState && trackInfo.hasIntentFragment ? Colors.color_track_tool_button_background_hovered : Colors.color_transparent
        hoverTextFunc: function() {
            return qsTr("pccut_navigation_trim_end");
        }
        iconSource: "qrc:/app_qrc/icons/ic_cutend.svg"
        Accessible.role: Accessible.Button
        Accessible.description: "videoedit_righttrim"
        externalOpacity: true
        onClicked: {
            if(isInEditeState && trackInfo.hasIntentFragment) {
                cutBtnClickedSignal(false, MultiTrackView.NavigationBar);
            }
        }
    }

    // 变速按钮
    TrackToolsButton {
        id: routineSpeedButton
        enabled: isInEditeState
        opacity: isInEditeState ? 1 : 0.2
        layer.enabled: true
        visible: false
        property bool isHighLight: false
        anchors.right: selfieSticker.left
        anchors.rightMargin: 24
        iconSource: isHighLight ? "qrc:/icons/trackToolBar/toolbar_speed_high.svg" : "qrc:/icons/trackToolBar/toolbar_speed.svg"
        onClicked: {
            playerPanel.controller.pause();
        }
    }

    TrackToolsButton {
        id: selfieSticker
        enabled: isInEditeState
        opacity: isInEditeState ? 1 : 0.2
        layer.enabled: true
        visible: false
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: keyframeButton.left
        anchors.rightMargin: 24

        iconSource: "qrc:/icons/trackToolBar/toolbar_selfie_stick.svg"
    }

    // 标记点按钮
    TrackToolsButton {
        id: markPointButton
        objectName: "markPointButton"
        layer.enabled: true
        visible: true
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: cutEndButton.right
        anchors.leftMargin: 24
        readonly property bool markEnabled: MarkPointToolbarViewModel.iconState !== MarkPointToolbarViewModel.Disabled
        opacity: markPointButton.markEnabled ? 1 : 0.2
        externalOpacity: true
        pressedColor: markPointButton.markEnabled ? Colors.color_19191A : Colors.color_transparent
        hoverColor: markPointButton.markEnabled ? Colors.color_track_tool_button_background_hovered : Colors.color_transparent
        iconSource: MarkPointToolbarViewModel.iconState === MarkPointToolbarViewModel.DeleteAvailable
                    ? "qrc:/icons/markPoint/ic_mark_delete.svg"
                    : "qrc:/icons/markPoint/ic_mark_add.svg"
        Accessible.role: Accessible.Button
        Accessible.description: "videoedit_mark_point"
        hoverTextFunc: function() {
            var tip = MarkPointToolbarViewModel.tooltipText;
            // 删除标记无快捷键，仅添加态拼接 M 键提示
            if (MarkPointToolbarViewModel.iconState === MarkPointToolbarViewModel.AddAvailable) {
                tip += ShortcutConfig.actionTips(ShortcutAction.ADD_MARK_POINT);
            }
            return tip;
        }
        onClicked: {
            if (markPointButton.markEnabled) {
                MarkPointToolbarViewModel.toggleMarkAtBase();
            }
        }
        // iconState 变(add<->delete)时 tooltip 仍 hover 显示中不会重取文本，主动刷新(仿 keyframeButton)
        property int iconState: MarkPointToolbarViewModel.iconState
        onIconStateChanged: refreshTips()
    }

    //控件UI View
    TrackToolsButton {
        id: keyframeButton
        objectName: actionableItemName.keyframeButton
        layer.enabled: true
        visible: true
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: markPointButton.right
        anchors.leftMargin: 24
        pressedColor: isInEditeState && keyFrameViewModel.keyframeEnable ? Colors.color_19191A : Colors.color_transparent
        hoverColor: isInEditeState && keyFrameViewModel.keyframeEnable ? Colors.color_track_tool_button_background_hovered : Colors.color_transparent
        iconSource: keyFrameViewModel.icon
        hoverIconSource: keyFrameViewModel.hoverIcon
        pressedIconSource: keyFrameViewModel.pressIcon
        iconAsynchronous: false
        externalOpacity: true
        iconMargins: 0
        property bool isKeyframe: keyFrameViewModel.isKeyframe
        onIsKeyframeChanged: {
            refreshTips();
        }
        tipLinesFunc: function() {
        return  [
                    {
                        text: keyFrameViewModel.tipTitle,
                        color: Colors.color_EEEEEE,
                        size: 11
                    },
                    {
                        text: keyFrameViewModel.tipDesc,
                        color: Colors.color_999999,
                        size: 11
                    },
                ];
        }

        onClicked: {
            keyFrameViewModel.onClick(KeyframeBtnViewModel.NavigationBar);
            if(!editorManager.isInUserGuideStatus){
                if(!lightSetting.getBool(firstAddKf) && !lightSetting.getBool("first_enter_tk")){
                    if(editorManager.isPanoramaVideoOrImageInIndicator() &&
                        editorManager.getCurVideoType() !== MediaType.DUSS_REMUX_RECORD_PANO_VIDEO_BULLET_TIME &&
                        editorManager.getCurVideoType() !== MediaType.DUSS_REMUX_RECORD_PANO_VIDEO_SEMI){
                       lightSetting.save(firstAddKf, true);
                        globalSignal.enterKfGuideModelStep3();
                        editorManager.isInUserGuideStatus = true;
                    }
                }
            }else {
                globalSignal.nextStepInKfGuide();
            }
        }

        Connections {
            target: globalSignal

            function onKeyFrameValueChanged(hasKeyFrame, hasNextKeyFrame, hasPreviousKeyFrame) {
                keyFrameViewModel.isKeyframe = hasKeyFrame;
            }

            function onKeyframePositionRefreshed() {
                keyFrameViewModel.refreshKeyFramePosition();
            }

            function onVideoSelected(fragment) {
                if(!viewModel) {
                    return;
                }
                viewModel.videoFragment = fragment;
            }

            function onAddKfActionInGuide() {
                if(mask.userGuideType === UserGuideType.REGIONKEYFRAME){
                    keyFrameViewModel.onClick(KeyframeBtnViewModel.NavigationBar, KeyframeBtnViewModel.AddRegionKeyframe);
                }else{
                    keyFrameViewModel.onClick(KeyframeBtnViewModel.NavigationBar);
                }
            }
        }
    }

    // tracking Ui
    TrackToolsButton {
        id: trackButton
        visible: Tools.isAppleChip() || (Tools.isWindowsSys() && !deviceIsAmd)
        opacity: isInEditeState && trackButton.canStartTk ? 1 : 0.2
        layer.enabled: true
        property bool isEnterTk: false
        property int clipIndex: 0
        property int position: 0
        // 智能追踪按钮可用态由 KeyframeBtnViewModel 计算
        property bool canStartTk: keyFrameViewModel.canStartTk

        anchors.verticalCenter: parent.verticalCenter
        anchors.left: keyframeButton.right
        anchors.leftMargin: 24
        pressedColor: isInEditeState && trackButton.canStartTk ? Colors.color_19191A : Colors.color_transparent
        hoverColor: isInEditeState && trackButton.canStartTk ? Colors.color_track_tool_button_background_hovered : Colors.color_transparent
        iconSource: isInEditeState && hovered && trackButton.canStartTk ? "qrc:/app_qrc/icons/ic_track_hover.svg" : "qrc:/app_qrc/icons/ic_track.svg"
        externalOpacity: true
        objectName: actionableItemName.trackingBtnForTrackToolsBar

        tipLinesFunc: function() {
            return [
            {
                text: qsTr("pccut_navigation_track_button")+ ShortcutConfig.actionTips(ShortcutAction.OPEN_TRACKING_POPUP),
                color: Colors.color_EEEEEE,
                size: 11
            },
            {
                text: qsTr("pccut_navigation_track_description"),
                color: Colors.color_999999,
                size: 11
            },
        ]
        }

        onClicked: {
            if (deviceIsAmd) {
                return;
            }

            if (!trackingInited || (!Tools.isWindowsSys() && !trackingNonHeldInited)) {
                toast.showToast(qsTr("pccut_shortcut_tk_loading_tip"))
                return
            }

            if (isInEditeState && canStartTk && !isEnterTk) {
                globalSignal.trackingSwitchSpeed(1)
                eventTracker.trackEvent("pccut_tk_enter", {"use_method": "navigation_bar", "tk_sdk": QmlConstants.trackingSDKVersion,
                                        "tk_init_time": tkInitDuration.toString()})

                if(!lightSetting.getBool("first_enter_tk")){
                    lightSetting.save("first_enter_tk", true);
                    editorManager.isInUserGuideStatus = true;
                    globalSignal.enterTkGuideModel();
                }
            }
        }

        Connections {
            target: globalSignal

            function onUpdateTrackingInitDuration(duration) {
                tkInitDuration = duration
            }

            function onGpuInfoStateChanged(isAmd) {
                deviceIsAmd = isAmd
            }

            function onTrackingInitFinish(handler, isHeld) {
                if (isHeld) {
                    trackingInited = true
                } else {
                    trackingNonHeldInited = true
                }
            }

            function onTrackingStateChanged(status) {
                if (status === TrackingManager.TK_ENTER) {
                    trackButton.isEnterTk = true
                    trackMaskPopup.dealWindowSizeChanged()
                } else if (status === TrackingManager.TK_EXIT) {
                    trackButton.isEnterTk = false;
                }
            }

            function onOpenTrackMaskPopup() {
                openPopup()
            }

            function onTrackingSwitchSpeedFinish() {
                if (deviceIsAmd) {
                    return;
                }

                if (!trackingInited || (!Tools.isWindowsSys() && !trackingNonHeldInited)) {
                    toast.showToast(qsTr("pccut_shortcut_tk_loading_tip"))
                    return
                }

                openPopup()
            }

        }

        CShortcut {
            action: ShortcutAction.OPEN_TRACKING_POPUP
            onActivated: {
                if(Tools.isAppleChip() || (Tools.isWindowsSys() && !deviceIsAmd)) {
                    globalSignal.cleanSelectMediaPath()
                    if (trackButton.canStartTk && !trackButton.isEnterTk) {
                        globalSignal.trackingSwitchSpeed(1)
                        eventTracker.trackEvent("pccut_tk_enter", {"use_method": "shortcut", "tk_sdk": QmlConstants.trackingSDKVersion,
                                                "tk_init_time": tkInitDuration.toString()})
                    }
                }
            }
        }
    }

    // 超级慢动作
    TrackToolsButton {
        id: superSlowButton
        property bool superSlowActive: root.superSlowViewModel
                                       ? root.superSlowViewModel.superSlowEnable : false
        property bool canEnableSuperSlow: root.superSlowViewModel
                                         && root.superSlowViewModel.superSlowCanUse === 0
                                         && root.superSlowViewModel.isIndicatorInClip

        visible: root.superSlowViewModel !== null && root.superSlowViewModel.supportsSuperSlow
        enabled: canEnableSuperSlow || superSlowActive
        opacity: enabled ? 1 : 0.2
        layer.enabled: true
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: trackButton.visible ? trackButton.right : keyframeButton.right
        anchors.leftMargin: 24
        pressedColor: enabled ? Colors.color_19191A : Colors.color_transparent
        hoverColor: enabled ? Colors.color_track_tool_button_background_hovered : Colors.color_transparent
        iconSource: superSlowActive
                     ? "qrc:/icons/icon_super_slow_remove.svg"
                     : "qrc:/icons/icon_super_slow_add.svg"
        externalOpacity: true

        onSuperSlowActiveChanged: refreshTips()
        tipLinesFunc: function() {
            if (superSlowActive) {
                return [
                    {
                        text: qsTr("pccut_superslow_btn_close") + ShortcutConfig.actionTips(ShortcutAction.REMOVE_SUPER_SLOW),
                        color: Colors.color_EEEEEE,
                        size: 11
                    },
                    {
                        text: qsTr("pccut_superslow_btn_close_tip"),
                        color: Colors.color_999999,
                        size: 11
                    }
                ];
            }
            return [
                {
                    text: qsTr("pccut_superslow_btn_open") + ShortcutConfig.actionTips(ShortcutAction.ADD_SUPER_SLOW),
                    color: Colors.color_EEEEEE,
                    size: 11
                },
                {
                    text: qsTr("pccut_superslow_btn_tip"),
                    color: Colors.color_999999,
                    size: 11
                }
            ];
        }

        onClicked: root.setSuperSlowEnabled(!superSlowActive)
    }

    // 画面裁切 暂时屏蔽开关
    // TrackToolsButton {
    //     id: videoCliBtn
    //     opacity: trackInfo.isShowFrameCrop ? 1 : 0.2
    //     disabled: !trackInfo.isShowFrameCrop
    //     layer.enabled: true
    //     anchors.left: trackButton.visible ? trackButton.right : keyframeButton.right
    //     anchors.leftMargin: 24
    //     pressedColor: Colors.color_19191A
    //     hoverColor: Colors.color_track_tool_button_background_hovered
    //     hoverTextFunc: function() {
    //         return qsTr("pccut_frame_cropping_title") + ShortcutConfig.actionTips(ShortcutAction.FRAME_CROP);
    //     }
    //     iconSource: "qrc:/icons/trackToolBar/ic_frame_crop.svg"
    //     Accessible.role: Accessible.Button
    //     // Accessible.description: "videoedit_righttrim"
    //     externalOpacity: true
    //     onClicked: {
    //         videoClipClickedSignal();
    //     }

    //     CShortcut {
    //         action: ShortcutAction.FRAME_CROP
    //         onActivated: {
    //             if(!videoCliBtn.disabled){
    //                 videoClipClickedSignal();
    //             }
    //         }
    //     }
    // }


    // 语音高光新手卡片
    Item {

        parent: audioHighlightBtn

        x : (parent.width - width - 1) / 2
        y : - audioHighlightGuidePopup.height / 2 - 14

        AdaptablePopupforUserGuide {
            id : audioHighlightGuidePopup
            titleText: qsTr("pccut_voice_tag_title")
            descriptionText: qsTr("pccut_voice_tag_tip")
            radius: 12
        }

        Connections  {
            target : globalSignal
            function onAudioHighlightPromptRequired() {
                trackInfo.audioHighlightPrompt = true
                audioHighlightGuidePopup.open() // 新手气泡
            }
        }
    }

    // 语音高光开关
    TrackToolsButton {
        id: audioHighlightBtn
        property bool isOpen: trackInfo.audioHighlight

        anchors.verticalCenter: parent.verticalCenter
        anchors.right: snappingButton.left
        anchors.rightMargin: 24

        hoverColor: Colors.color_track_tool_button_background_hovered
        iconSource:
            isOpen ? "qrc:/app_qrc/icons/audio_highlight_btn_red.svg"
                   : "qrc:/app_qrc/icons/audio_highlight_btn_white.svg"

        onIsOpenChanged: {
            refreshTips();
        }
        // 鼠标滑过事件
        hoverTextFunc: function() {
            return (isOpen ? qsTr("pccut_voice_tag_title_close")
                           : qsTr("pccut_voice_tag_title_open"))
                    + ShortcutConfig.actionTips(ShortcutAction.AUDIO_HIGHLIGHT);
        }

        onClicked: {
            trackInfo.audioHighlight = !trackInfo.audioHighlight;
            AudioHighlightTaskManager.highlightBtnClicked(trackInfo.audioHighlight)
        }

        CShortcut {
            action: ShortcutAction.AUDIO_HIGHLIGHT
            onActivated: {
                trackInfo.audioHighlight = !trackInfo.audioHighlight;
                AudioHighlightTaskManager.highlightBtnClicked(trackInfo.audioHighlight)
            }
        }
    }

    // 自动吸附开关
    TrackToolsButton {
        id: snappingButton
        property bool isOpen: trackInfo.autoSnapping
        onIsOpenChanged: {
            refreshTips();
        }
        hoverTextFunc: function() {
            return (isOpen ? qsTr("pccut_autoadhesion_turn_off_button") : qsTr("pccut_autoadhesion_turn_on_button")) + ShortcutConfig.actionTips(ShortcutAction.ADSORPTION);
        }
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: preViewAxisButton.left
        anchors.rightMargin: 24
        hoverColor: Colors.color_track_tool_button_background_hovered
        iconSource: isOpen ? "qrc:/app_qrc/icons/snapping_red.svg" : "qrc:/app_qrc/icons/snapping_white.svg"
        onClicked: {
            trackInfo.autoSnapping = !trackInfo.autoSnapping;
            var projectId = draftManager.activeProjectEnvId();
            if(trackInfo.autoSnapping)
            {
                UsedFunctionManager.addFunction(projectId,UsedFunctionManager.EditorFunctionType.AUTO_SNAP);
            }
            else
            {
                UsedFunctionManager.removeFunction(projectId,UsedFunctionManager.EditorFunctionType.AUTO_SNAP);
            }

            eventTracker.trackEvent("pccut_auto_snap_click", {"is_turnon": trackInfo.autoSnapping})
        }
    }

    // 预览轴开关
    TrackToolsButton {
        id: preViewAxisButton
        objectName: actionableItemName.trackToolsBarPreviewAxis
        property bool isOpen: trackInfo.showHoverPreview
        onIsOpenChanged: {
            refreshTips();
        }
        hoverTextFunc: function() {
            return (isOpen ? qsTr("pccut_navigation_previewaxis_close_button") : qsTr("pccut_navigation_previewaxis_open_button")) + ShortcutConfig.actionTips(ShortcutAction.PREVIEW_AXIS);
        }
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: slider.left
        anchors.rightMargin: 31
        iconSource: isOpen ? "qrc:/app_qrc/icons/toolbar_preview_open.svg" : "qrc:/app_qrc/icons/toolbar_preview.svg"
        hoverColor: Colors.color_track_tool_button_background_hovered
        onClicked: {
            trackInfo.showHoverPreview = !trackInfo.showHoverPreview;
            eventTracker.trackEvent("pccut_preview_axis_click", {"is_turnon": trackInfo.showHoverPreview})
            globalSignal.hoverPreview(trackInfo.showHoverPreview);
        }

        Component.onCompleted: {
            globalSignal.hoverPreview(trackInfo.showHoverPreview);
        }

        CShortcut {
            action: ShortcutAction.PREVIEW_AXIS
            onActivated: {
                trackInfo.showHoverPreview = !trackInfo.showHoverPreview;
                eventTracker.trackEvent("pccut_preview_axis_click", {"is_turnon": trackInfo.showHoverPreview})
                if (!trackInfo.showHoverPreview) {
                    editorManager.seek(trackDockViewModel.indicatorFrame);
                }else{
                    flickable.mouseXChanged();//为了让鼠标在轨道时，按预览轴快捷键能够正常展示预览轴
                }
                globalSignal.hoverPreview(trackInfo.showHoverPreview);
            }
        }
    }

    Timer {
        id: sliderTimer

        property real draggingScale: 0
        
        interval: 100
        repeat: true
        onTriggered: {
            trackScale(draggingScale);
        }

    }

    ZoomSliderBar {
        id: slider
        width: 130
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: 12
        sliderSelectedColor: Colors.color_EEEEEE
        sliderUnSelectedColor: Colors.color_444444
        sliderHandleBorderColor: Colors.color_title_area_background
        value: getPercentageByScale()
        enabled: isInEditeState ? isRangeValid() : false
        opacity: isInEditeState ? 1 : 0.2
        layer.enabled: true

        property int invokeCount: 0


        onDragging: (value) => {
            const scale = updateScaleByPercentage(value);
            sliderTimer.draggingScale = scale;
            if (invokeCount <= 0) {
                sliderTimer.start();
            }
            invokeCount++;
        }

        onBtnClickZoom: (value) => {
            const scale = updateScaleByPercentage(value);
            trackScale(scale);
        }

        onReleased: {
            sliderTimer.stop();
            trackScale(sliderTimer.draggingScale);
            invokeCount = 0;
            eventTracker.trackEvent("pccut_scroll_bar_click", {"use_method": "navigation_bar"})
        }

        function isRangeValid() {
            const range = trackInfo.scaleRange;
            return range[0] > 0 && range[1] > 0 && range[1] >= range[0];
        }

        function getPercentageByScale() {
            const range = trackInfo.scaleRange;
            if (!isRangeValid()) {
                return 0;
            }
            const value = Math.log(trackInfo.scaleBase / range[0]) / Math.log(range[1] / range[0]);
            return value * 100.0;
        }

        function updateScaleByPercentage(targetValue) {
            const range = trackInfo.scaleRange;
            if (range[0] <= 0 || range[1] <= 0) {
                return 0;
            }
            const factor = Math.pow(range[1] / range[0], targetValue / 100.0);
            return range[0] * factor;
        }
    }

    TrackMaskPopup {
        id: trackMaskPopup
        objectName: actionableItemName.trackMaskPopupForTrackToolsBar
        closePolicy: Popup.CloseOnPressOutside

        Component.onCompleted: {
            trackMaskPopup.init()
        }
    }

    function openPopup() {
        if (trackMaskPopup.visible) {
            return
        }
        clickTrackingEntance()
        globalSignal.trackingEnterAction()
        updateTrackMaskRects()
        trackMaskPopup.open()
    }

    function updateTrackMaskRects() {
        trackMaskPopup.playerRect = playerPanel.getPlayerPosition()
        trackMaskPopup.playerControllerRect = playerPanel.getPlayerControllerPosition()
        trackMaskPopup.playerPanelRect = Qt.rect(UiUtils.getGlobalPosition(playerPanel).x,
                                         UiUtils.getGlobalPosition(playerPanel).y,
                                         playerPanel.width,
                                         playerPanel.height)
        trackMaskPopup.selectItemRect = tracks.getSelectItemRect()
    }

    Connections {
        target: lightWindow
        function onWidthChanged() {
            if (trackMaskPopup.visible) {
                windowSizeChangeTimer.restart()
            }
        }
        function onHeightChanged() {
            if (trackMaskPopup.visible) {
                windowSizeChangeTimer.restart()
            }
        }
    }

    Timer {
        id: windowSizeChangeTimer
        interval: 0
        repeat: false
        onTriggered: {
            trackMaskPopup.dealWindowSizeChanged()
            updateTrackMaskRects()
        }
    }

    // 监听轨道缩小和放大
    CShortcut {
        action: ShortcutAction.TRACK_ENLARGE
        onActivated: {
            slider.zoomIn();
            eventTracker.trackEvent("pccut_scroll_bar_click", {"use_method": "shortcut"})
        }
    }

    CShortcut {
        action: ShortcutAction.TRACK_SHRINK
        onActivated: {
            slider.zoomOut();
            eventTracker.trackEvent("pccut_scroll_bar_click", {"use_method": "shortcut"})
        }
    }

    CShortcut {
        action: ShortcutAction.SPLIT
        onActivated: {
            splitClicked(MultiTrackView.ShortCut);
        }
    }

    CShortcut {
        action: ShortcutAction.CUT_LEFT
        onActivated: {
            cutBtnClickedSignal(true, MultiTrackView.ShortCut)
        }
    }

    CShortcut {
        action: ShortcutAction.CUT_RIGHT
        onActivated: {
            cutBtnClickedSignal(false, MultiTrackView.ShortCut)
        }
    }

    CShortcut {
        action: ShortcutAction.ADD_SUPER_SLOW
        onActivated: root.setSuperSlowEnabled(true)
    }

    CShortcut {
        action: ShortcutAction.REMOVE_SUPER_SLOW
        onActivated: root.setSuperSlowEnabled(false)
    }

    CShortcut {
        action: ShortcutAction.ADSORPTION
        onActivated: {
            trackInfo.autoSnapping = !trackInfo.autoSnapping;
            eventTracker.trackEvent("pccut_auto_snap_click", {"is_turnon": trackInfo.autoSnapping})
        }
    }

    // 加/删标记点
    CShortcut {
        action: ShortcutAction.ADD_MARK_POINT
        enabled: markPointButton.markEnabled
        onActivated: {
            // M 快捷键：无标记则加；有标记暂不处理
            MarkPointToolbarViewModel.addMarkAtBase();
        }
    }

    function setSuperSlowEnabled(enabled) {
        if (!root.superSlowViewModel) {
            return;
        }
        if (enabled && (!superSlowButton.canEnableSuperSlow || root.superSlowViewModel.superSlowEnable)) {
            return;
        }
        if (!enabled && !root.superSlowViewModel.superSlowEnable) {
            return;
        }
        root.superSlowViewModel.superSlowEnable = enabled;
        if (enabled && editorManager.isInUserGuideStatus) {
            globalSignal.enterNextStepSuperSlowGuide();
        }
    }
}
