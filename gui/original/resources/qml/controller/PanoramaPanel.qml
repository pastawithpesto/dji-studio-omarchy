import QtQuick 2.15
import QtQuick.Controls
import Controls 1.0
import Config 1.0
import VideoFragmentViewModel 1.0
import Nova 1.0
import MediaTypeModel 1.0
import QmlConstants 1.0
import PanoramaController 1.0
import PanoramaConfig 1.0
import UserGuideTypeModel 1.0
import UsedFunctionManager 1.0
import app_qrc 1.0
import Nova 1.0

/**
 * @author robert.guo
 * @desc 取景右侧面板
 * @create_date 2024-06-12
 */
Rectangle {
    id: root
    color: Colors.color_content_area_background
    clip: true

    property int currentPresetType: selectPerspective.currentPreset

    PanoramaPanelViewModel {
        id: panoramaPanelViewModel
    }
    // 过渡「应用到全部」已接入 nova。
    PanoramaKeyframeViewModel {
        id: panoKfVm
    }
    property bool devIsAmd: false
    property VideoFragmentViewModel viewModel
    property var currentMediaType: CommonUtils.isNull(viewModel) || !viewModel.hasFragment? MediaType.DUSS_REMUX_RECORD_UNKNOWN : viewModel.videoFragment.mediaType
    // nova 选中片段不回灌老 videoFragment(常为 null)，全景图片门控改读全景 VM(与 QualitySettingsPanel 同口径)
    property bool isPanoramaImage: panoStabilizeAdjust.isPanoramaImage
    property bool isDrone: CommonUtils.isNull(viewModel) || !viewModel.hasFragment ? false : viewModel.videoFragment.isDrone()
    property var  projectId: draftManager.activeProjectEnvId()
    property bool isStabilizeVisible: !isPanoramaImage && !panoKfVm.isSemiOrBullet
    // 顶部分割线
    Rectangle {
        color: Colors.color_141414
        width: parent.width
        height: 1
        z: 1
    }

    function isSyncOpenHorizonCorrectWhenOpenStable() {
        // return isDrone || currentMediaType === MediaType.DUSS_REMUX_RECORD_PANO_TIMELAPSE
        return true
    }

    function getDiffDistance() {
        if (CommonUtils.isWindows()) {
            return 5
        } else {
            return 0
        }
    }

    ScrollView {
        id: scrollView
        anchors.fill: parent
        contentHeight: contentRoot.height
        bottomPadding: 20
        clip: true
        ScrollBar.vertical.policy: ScrollBar.AlwaysOff
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        Component.onCompleted: {
            contentItem.boundsBehavior = Flickable.StopAtBounds
        }

        contentItem: Flickable {

            Item {
                id: contentRoot
                width: parent.width
                height: childrenRect.height

            Connections{
                target: globalSignal
                function onKfEffectAdjustView(offset){
                    scrollView.anchors.topMargin = offset;
                }

                function onKfEffectFinish(){
                    scrollView.anchors.topMargin = 16;
                }
            }
            Component.onCompleted: {
                if(panoKfVm.isSemiOrBullet){
                    selectPerspectiveSetArgumentRoot.anchors.top = panoramaTool.bottom
                    selectPerspectiveSetArgumentRoot.anchors.topMargin = 12;
                    transitionEffectTitle.anchors.top = selectPerspectiveSetArgumentRoot.bottom;
                    transitionEffectTitle.anchors.topMargin = 8
                }
            }

            Rectangle {
                id: panoramaSpace
                width: scrollView.width
                height: 16
                color: Colors.color_transparent
            }

            Connections {
                target: viewModeAnalyzeController
                function onAnalyzeProgressUpdated(progress) {
                    analyzeWaitingPopup.segmentProgress = progress
                }
                function onAnalyzeFinished(mode, success) {
                    analyzeWaitingPopup.close()
                    if (success) {
                        updateFragmentViewingMode(mode)                 // 先切(nova 内核选中片段，不依赖老 fragment)
                        viewModeAnalyzeController.applyAnalyzed(mode)    // 后灌(前进散点；自拍见 ViewModeAnalyzeController)
                    }
                }
                function onMultiAnalyzeProgressUpdated(index, progress){
                    analyzeWaitingPopup.currentIndex = index
                    analyzeWaitingPopup.segmentProgress = progress
                }
                function onMultiAnalyzeFinished(mode) {
                    analyzeWaitingPopup.close()

                    viewModeAnalyzeController.applyViewModeToAll(mode)
                }
            }

            // 增稳: 增稳的开关在 QualitySettingsPanel，但增稳会影响这里的视角模式，
            // 故这里也用全景 VM 读取增稳/地平线状态(跟随 nova 选中片段)。
            PanoramaFilterViewModel {
                id: panoStabilizeAdjust

                onIsUseStabilizeChanged: {
                    stableCheckBox.checked = panoStabilizeAdjust.isUseStabilize
                    horizonCorrectSwitch.checked = panoStabilizeAdjust.isUseHorizonCorrect
                }
                onIsUseHorizonCorrectChanged: {
                    horizonCorrectSwitch.checked = panoStabilizeAdjust.isUseHorizonCorrect
                }
            }

            Connections {
                target: globalSignal

                function onUseStabilizeChanged(trackIndex, clipIndex) {
                    // 手动触发刷新：本面板的全景 VM 仅读增稳状态，借 globalSignal 通知 UI 重读
                    if (CommonUtils.isNull(root.viewModel) || !root.viewModel.hasFragment) {
                        return;
                    }
                    const trackClipModel = editorManager.getTrackClipIndexByFragment(CommonUtils.isNull(root.viewModel) || !root.viewModel.hasFragment ? null : root.viewModel.videoFragment);
                    if (trackClipModel.track === trackIndex && trackClipModel.clip === clipIndex) {
                        panoStabilizeAdjust.isUseStabilizeChanged();
                    }
                }
            }

            Rectangle {
                id: viewingModeTitle
                width: parent.width
                height: 20
                visible: viewingModeMenu.itemCount > 1
                anchors {
                    left: parent.left
                    top: parent.top
                    leftMargin: 12
                    topMargin: 16
                    right: parent.right
                    rightMargin: 12
                }
                color: Colors.color_transparent
                clip: true
                Text {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignLeft
                    font {
                        pixelSize: 12
                    }
                    color: Colors.color_EEEEEE
                    text: qsTr("pccut_panel_video_reframe")
                }

                Rectangle{
                    id: allUseBtn
                    property bool isHovered: false
                    color: !enabled ? Colors.color_353738 : allUseBtn.isHovered ? Colors.color_414344 : Colors.color_353738
                    enabled: viewingModeSelector.enabled
                    radius: RadiusConfig.radius_4_88
                    anchors{
                        right: parent.right
                    }
                    opacity: enabled ? 1 : 0.2
                    width: allUseBtnText.width + 16
                    height: 20
                    anchors.verticalCenter: parent.verticalCenter
                    Text{
                        id: allUseBtnText
                        text: qsTr("pccut_panel_colorrecovery_applyglobally")
                        anchors.centerIn: parent
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: Colors.color_EEEEEE
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: allUseBtn.isHovered = true
                        onExited: allUseBtn.isHovered = false
                        onClicked: {
                            editorManager.pause()

                            // 应用到全部基于 nova 选中片段：mode=当前选中片段视角。
                            const mode = panoKfVm.viewingMode
                            if (mode === PanoramaConfig.UNKNOWN_VIEW) {
                                return;
                            }

                            const analyzeFragments = viewModeAnalyzeController.getNeedAnalyzeFragments(mode)
                            const analyzeCount = analyzeFragments.length
                            if(analyzeCount > 0) {
                                analyzeWaitingPopup.totalCount = analyzeCount
                                analyzeWaitingPopup.open();
                                //开始分析
                                viewModeAnalyzeController.startAnalyzeFragment(analyzeFragments, mode)
                            }
                            else {
                                viewModeAnalyzeController.applyViewModeToAll(mode)
                            }
                        }
                    }
                }
            }
            
            SelectableText {
                id: viewingModeSelector

                // 无选中/未知视角 → 回退 FREEDOM_VIEW 显示，对齐老逻辑(取代老 panoramaViewingMode)
                property int viewingMode: panoKfVm.viewingMode === PanoramaConfig.UNKNOWN_VIEW
                                          ? PanoramaConfig.FREEDOM_VIEW
                                          : panoKfVm.viewingMode
                property bool viewingModeSwitchEnable: panoKfVm.playheadOnSelectedClip
                property bool stabilization: panoStabilizeAdjust.isUseStabilize
                visible: viewingModeMenu.itemCount > 1

                height: 28
                text: viewingModeMenu.modeNames[viewingMode]
                enabled: viewingModeSwitchEnable /*&& stabilization*/
                color: enabled ? (isHovered ? Colors.color_button_background_hovered : Colors.color_button_background_normal) : Colors.color_2F3032_40
                textColor: enabled ? Colors.color_EEEEEE : Colors.color_444444

                anchors {
                    top: viewingModeTitle.bottom
                    topMargin: 12
                    left: parent.left
                    leftMargin: 12
                    right: parent.right
                    rightMargin: 12
                }

                ViewingModeMenu {
                    id: viewingModeMenu

                    supportModes: ({
                        [PanoramaConfig.SHOT_VIEW]: panoKfVm.shotViewSupport,
                        [PanoramaConfig.FREEDOM_VIEW]: panoKfVm.freeViewSupport,
                        [PanoramaConfig.DIRECTION_LOCK]: panoKfVm.fixViewSupport,
                        [PanoramaConfig.SELFIE_VIEW]: panoKfVm.selfieViewSupport,
                        [PanoramaConfig.FORWARD_VIEW]: panoKfVm.forwardViewSupport,
                        [PanoramaConfig.FRONTSHOT_VIEW]: panoKfVm.frontShotViewSupport
                    });

                    modeDescs: ({
                        [PanoramaConfig.SHOT_VIEW]: panoKfVm.shotViewDescription !== "" ? panoKfVm.shotViewDescription : qsTr("pccut_image_preview_desc"),
                        [PanoramaConfig.FREEDOM_VIEW]: qsTr("pccut_image_liberty_desc"),
                        [PanoramaConfig.DIRECTION_LOCK]: qsTr("pccut_image_directionlock_desc"),
                        [PanoramaConfig.SELFIE_VIEW]: qsTr("pccut_image_backward_desc"),
                        [PanoramaConfig.FORWARD_VIEW]: qsTr("pccut_editing_perspective_forward_explain"),
                        [PanoramaConfig.FRONTSHOT_VIEW]: qsTr("pccut_editing_perspective_towards_explain")
                    });
                    // 无选中/未知视角 → -1(谁都不打勾)，对齐老逻辑(取代老 panoramaViewingMode)
                    selectedMode: panoKfVm.viewingMode === PanoramaConfig.UNKNOWN_VIEW
                                  ? -1
                                  : panoKfVm.viewingMode
                }

                Connections {
                    target: viewingModeMenu

                    function onSelect(mode, name) {
                        if (panoKfVm.viewingMode !== mode) {
                            onViewingModeSelected(mode);
                        }
                        viewingModeSelector.hide();
                    }
                }
            }

            Rectangle {
                id: stableLine
                color: Colors.color_2F3032
                height: 1
                anchors {
                    top: viewingModeSelector.visible ? viewingModeSelector.bottom : parent.top
                    topMargin: viewingModeSelector.visible ? 16 : 0
                    left: parent.left
                    leftMargin: 12
                    right: parent.right
                    rightMargin: 12
                }
                visible: viewingModeSelector.visible && isStabilizeVisible
            }

            Rectangle{
                id: stableRect
                property bool isDisable: !stableCheckBox.checked
                width: parent.width
                height: 16
                color: Colors.color_transparent
                visible: isStabilizeVisible

                opacity: (!viewingModeSelector.viewingModeSwitchEnable || (viewingModeMenu.selectedMode !== PanoramaConfig.FREEDOM_VIEW)) ? 0.2 : 1

                anchors {
                    top: stableLine.bottom
                    topMargin: 16
                    left: parent.left
                    leftMargin: 12
                    right: parent.right
                    rightMargin: 12
                }

                LightCheckBox {
                    id:stableCheckBox
                    maxTextWidth: parent.width - 180
                    text: qsTr("pccut_panel_image_flowstate")
                    anchors.verticalCenter: parent.verticalCenter
                    checked: panoStabilizeAdjust.isUseStabilize
                    verticalPadding: 1.5
                    enabled: ((viewingModeMenu.selectedMode !== PanoramaConfig.FREEDOM_VIEW)) ? false : true
                    Component.onCompleted:
                    {
                        var isFuncExist = UsedFunctionManager.hasFunction(projectId,UsedFunctionManager.EditorFunctionType.PANO_EIS);
                        if(!isFuncExist && checked)
                        {
                            UsedFunctionManager.addFunction(projectId,UsedFunctionManager.EditorFunctionType.PANO_EIS);
                        }
                    }

                    onClicked:{
                        var projectId = draftManager.activeProjectEnvId();
                        if(!stableCheckBox.checked) {
                            UsedFunctionManager.removeFunction(projectId,UsedFunctionManager.EditorFunctionType.PANO_EIS);
                            // toast.showToast(qsTr("pccut_image_stabilization_toast"), "playerPanel");
                            panoStabilizeAdjust.isUseStabilize = false
                            panoStabilizeAdjust.updateUseStabilizeAndHorizonCorrect(false, true, isSyncOpenHorizonCorrectWhenOpenStable(), viewingModeMenu.selectedMode === PanoramaConfig.FREEDOM_VIEW)
                        }else{
                            UsedFunctionManager.removeFunction(projectId,UsedFunctionManager.EditorFunctionType.PANO_EIS);
                            UsedFunctionManager.addFunction(projectId,UsedFunctionManager.EditorFunctionType.PANO_EIS);
                            panoStabilizeAdjust.isUseStabilize = true
                            panoStabilizeAdjust.updateUseStabilizeAndHorizonCorrect(true, true, isSyncOpenHorizonCorrectWhenOpenStable(), viewingModeMenu.selectedMode === PanoramaConfig.FREEDOM_VIEW)
                        }
                    }
                }

                Rectangle {
                    id: stableCheckBoxRect
                    anchors {
                        top:stableCheckBox.top
                        bottom: stableCheckBox.bottom
                        left: stableCheckBox.left
                        right: stableCheckBox.right
                    }
                    visible: !stableCheckBox.enabled
                    color: Colors.color_transparent

                    MouseArea {
                        id: stableCheckBoxMouse
                        anchors.fill: parent
                        hoverEnabled: true
                    }
                }
            }

            Rectangle {
                id: horizonCorrectRectangle
                property bool isEnable
                width: scrollView.width
                height: 16
                anchors.left: parent.left
                color: Colors.color_transparent
                visible: isStabilizeVisible
                opacity: !isDrone && viewingModeSelector.viewingModeSwitchEnable && currentMediaType !== MediaType.DUSS_REMUX_RECORD_PANO_TIMELAPSE && viewingModeMenu.selectedMode === PanoramaConfig.FREEDOM_VIEW && panoStabilizeAdjust.isUseStabilize ? 1 :0.2
                anchors {
                    top: stableRect.bottom
                    topMargin: 16
                    left: parent.left
                    leftMargin: 12
                    right: parent.right
                    rightMargin: 12
                }
                clip: true

                Text {
                    id: horizonCorrectDesc
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter // 垂直居中
                    horizontalAlignment: Text.AlignLeft // 水平对齐方式为靠左
                    font {
                        pixelSize: 11
                    }
                    color: Colors.color_999999
                    text: qsTr("pccut_stabilization_horizon_leveling")
                }

                Rectangle{
                    id: descriptionBtn
                    anchors.left: horizonCorrectDesc.right
                    anchors.leftMargin:  2
                    width: 14
                    height: 14
                    anchors.verticalCenter: parent.verticalCenter
                    color: Colors.color_transparent
                    Image {
                        id:descriptIcon
                        anchors.fill: parent
                        source: horizonCorrectMouse.containsMouse ? "qrc:/icons/ic_explain.svg" : "qrc:/icons/ic_explain_hover.svg"
                        sourceSize: Qt.size(parent.width, parent.height)
                    }

                    MouseArea {
                        id: horizonCorrectMouse
                        anchors.fill: parent
                        hoverEnabled:true
                    }
                }
                LightBaseSwitch {
                    id: horizonCorrectSwitch
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    checked: panoStabilizeAdjust.isUseHorizonCorrect
                    enabled: !isDrone && currentMediaType !== MediaType.DUSS_REMUX_RECORD_PANO_TIMELAPSE && viewingModeMenu.selectedMode === PanoramaConfig.FREEDOM_VIEW && panoStabilizeAdjust.isUseStabilize

                    Component.onCompleted:
                    {
                        var isFuncExist = UsedFunctionManager.hasFunction(projectId,UsedFunctionManager.EditorFunctionType.INCLINE);
                        if(!isFuncExist && checked)
                        {
                            UsedFunctionManager.addFunction(projectId,UsedFunctionManager.EditorFunctionType.INCLINE);
                        }
                    }

                    onToggledSignal: {
                        if(checked){
                            UsedFunctionManager.removeFunction(projectId,UsedFunctionManager.EditorFunctionType.INCLINE);
                            UsedFunctionManager.addFunction(projectId,UsedFunctionManager.EditorFunctionType.INCLINE);
                            panoStabilizeAdjust.isUseHorizonCorrect = true
                            panoStabilizeAdjust.updateUseStabilizeAndHorizonCorrect(true, false, isSyncOpenHorizonCorrectWhenOpenStable(), viewingModeMenu.selectedMode === PanoramaConfig.FREEDOM_VIEW)

                        }else{
                            UsedFunctionManager.removeFunction(projectId,UsedFunctionManager.EditorFunctionType.INCLINE);
                            // toast.showToast(qsTr("pccut_image_stabilization_toast"), "playerPanel");
                            panoStabilizeAdjust.isUseHorizonCorrect = false
                            panoStabilizeAdjust.updateUseStabilizeAndHorizonCorrect(false, false, isSyncOpenHorizonCorrectWhenOpenStable(), viewingModeMenu.selectedMode === PanoramaConfig.FREEDOM_VIEW)
                        }
                        eventTracker.trackEvent("pccut_image_stabilization_switch", {"is_turnon": checked})
                    }
                }

                Rectangle {
                    id: horizonCorrectSwitchRect
                    anchors {
                        top:horizonCorrectSwitch.top
                        bottom: horizonCorrectSwitch.bottom
                        left: horizonCorrectSwitch.left
                        right: horizonCorrectSwitch.right
                    }
                    visible: !horizonCorrectSwitch.enabled
                    color: Colors.color_transparent

                    MouseArea {
                        id: horizonCorrectSwitchMouse
                        anchors.fill: parent
                        hoverEnabled: true
                    }
                }
            }

            Rectangle {
                id: bottomHorizonCorrectLine
                color: Colors.color_2F3032
                height: 1
                anchors {
                    top: horizonCorrectRectangle.bottom
                    topMargin: 16
                    left: parent.left
                    leftMargin: 12
                    right: parent.right
                    rightMargin: 12
                }
                visible: isStabilizeVisible
            }


            // 手动取景-工具栏 (记得更换下字符串)
            PanoramaTitleTool {
                id: panoramaTool
                panoKfVm: panoKfVm
                topMarginToParent: panoramaSpace.height
                anchors {
                    // top: viewingModeSelector.visible ? viewingModeSelector.bottom : parent.top
                    // topMargin: viewingModeSelector.visible ? 24 : panoramaSpace.height
                    top: bottomHorizonCorrectLine.visible ? bottomHorizonCorrectLine.bottom : parent.top
                    topMargin: bottomHorizonCorrectLine.visible ? 16 : panoramaSpace.height
                }
                width: parent.width
                height: 20
            }

            TransitionNotificationTips {
                id: stableSwitchTips
                width: 232
                height: 63
                arrowLeftMargin: descriptionBtn.x + descriptionBtn.width / 2 + 3
                anchors {
                    top: stableRect.bottom
                    topMargin: 4
                    left: parent.left
                    leftMargin: 12
                }
                visible: stableCheckBoxMouse.containsMouse

                onVisibleChanged: {
                    if (visible) {
                        if (!panoStabilizeAdjust.isUseStabilize) {
                            stableSwitchTips.updateDesc(qsTr("pccut_stabilization_off_effects"))
                            stableSwitchTips.width = 232 + getDiffDistance()
                        } else if (viewingModeMenu.selectedMode !== PanoramaConfig.FREEDOM_VIEW) {
                            stableSwitchTips.updateDesc(qsTr("pccut_stabilization_fixed_strength"))
                            stableSwitchTips.width = 232 + getDiffDistance()
                        } else if (isDrone || currentMediaType === MediaType.DUSS_REMUX_RECORD_PANO_TIMELAPSE) {
                            stableSwitchTips.updateDesc(qsTr("pccut_stabilization_disable_unsupported"))
                            stableSwitchTips.width = 185 + getDiffDistance()
                        } else {
                            stableSwitchTips.updateDesc(qsTr("pccut_stabilization_off_effects"))
                            stableSwitchTips.width = 232 + getDiffDistance()
                        }
                        stableSwitchTips.hideArrow()
                    }
                }
            }

            TransitionNotificationTips {
                id: horizonCorrectSwitchTips
                width: 232
                height: 63
                arrowLeftMargin: descriptionBtn.x + descriptionBtn.width / 2 + 3
                anchors {
                    top: horizonCorrectRectangle.bottom
                    topMargin: 4
                    right: parent.right
                    rightMargin: 12
                }
                visible: horizonCorrectSwitchMouse.containsMouse

                onVisibleChanged: {
                    if (visible) {
                        if (!panoStabilizeAdjust.isUseStabilize) {
                            horizonCorrectSwitchTips.updateDesc(qsTr("pccut_stabilization_horizon_requires_super"))
                            horizonCorrectSwitchTips.width = 245 + getDiffDistance()
                        } else if (viewingModeMenu.selectedMode !== PanoramaConfig.FREEDOM_VIEW) {
                            horizonCorrectSwitchTips.updateDesc(qsTr("pccut_stabilization_fixed_strength"))
                            horizonCorrectSwitchTips.width = 232 + getDiffDistance()
                        } else if (isDrone || currentMediaType === MediaType.DUSS_REMUX_RECORD_PANO_TIMELAPSE) {
                            horizonCorrectSwitchTips.updateDesc(qsTr("pccut_stabilization_disable_unsupported"))
                            horizonCorrectSwitchTips.width = 185 + getDiffDistance()
                        } else {
                            horizonCorrectSwitchTips.updateDesc(qsTr("pccut_stabilization_off_effects"))
                            horizonCorrectSwitchTips.width = 232 + getDiffDistance()
                        }
                        horizonCorrectSwitchTips.hideArrow()
                        horizonCorrectSwitchTips.alignRight = true
                    }
                }
            }

            TransitionNotificationTips {
                id: horizonCorrectTips
                width: 232
                height: 63
                arrowLeftMargin: descriptionBtn.x + descriptionBtn.width / 2 + 3
                arrowSource: "qrc:/icons/panorama/transition_effect_down_arrow.svg"
                anchors {
                    top: horizonCorrectRectangle.bottom
                    topMargin: 4
                    left: parent.left
                    leftMargin: 12
                }
                visible: horizonCorrectMouse.containsMouse

                onVisibleChanged: {
                    if (visible) {
                        horizonCorrectTips.updateDesc(qsTr("pccut_stabilization_off_effects"))
                        horizonCorrectTips.arrowUpward = true
                    }
                }
            }

            // 手动取景-选择模型
            SelectPerspectiveLayer {
                id: selectPerspective
                panoKfVm: panoKfVm
                width: parent.width
                visible: !panoKfVm.isSemiOrBullet

                anchors {
                    left: parent.left
                    right: parent.right
                    leftMargin: 12
                    top: panoramaTool.bottom
                    topMargin: 12
                }
                Component.onCompleted: {
                    globalSignal.keyframePositionRefreshed();
                }
            }

            // 手动取景-详细参数设置GridView区域
            SelectPerspectiveConfigureLayer {
                id: selectPerspectiveSetArgumentRoot
                panoKfVm: panoKfVm
                isSelfieMode: panoKfVm.isSemiOrBullet
                width: parent.width
                anchors {
                    left: parent.left
                    right: parent.right
                    top: selectPerspective.bottom
                    topMargin: 4
                }
            }

                PanoramaTrackingLayer {
                    id: trackingLayer
                    // 硬件门控(Apple/Windows 非 AMD 才支持) + 半球素材屏蔽，声明式随选中/硬件态实时刷新
                    visible: (Tools.isAppleChip() || (Tools.isWindowsSys() && !deviceIsAmd)) && !panoKfVm.isSemiOrBullet
                    anchors {
                        left: parent.left
                        right: parent.right
                        leftMargin: 12
                        rightMargin: 12
                        top: selectPerspectiveSetArgumentRoot.bottom
                        topMargin: 4
                    }

                    onYChanged: {
                        globalSignal.keyFrameSelectViewAreaUpadate(trackingLayer.y - selectPerspective.y, selectPerspective.y);
                    }
                }

                Text {
                    id: transitionEffectTitle
                    text: qsTr("pccut_panel_video_transition")
                    color: Colors.color_EEEEEE
                    font.pixelSize: 12
                    anchors {
                        top: ((!Tools.isAppleChip() && !Tools.isWindowsSys()) || (Tools.isWindowsSys() && deviceIsAmd)) ? selectPerspectiveSetArgumentRoot.bottom : trackingLayer.bottom
                        topMargin: 28
                        left: parent.left
                        leftMargin: 12
                    }
                }

                Image {
                    id: transitionNotificationButton
                    anchors {
                        left: transitionEffectTitle.right
                        leftMargin: 4
                    }
                    y: transitionEffectTitle.y + 1.0 * (transitionEffectTitle.height - height) / 2 // 为了避免0.5px的偏差
                    source: transitionNotificationButtonMouseArea.containsMouse ? "qrc:/icons/ic_explain.svg" : "qrc:/icons/ic_explain_hover.svg"
                    sourceSize: Qt.size(14, 14)
                    MouseArea {
                        id: transitionNotificationButtonMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                    }
                }

                Rectangle{
                    id: rectangle_applyToAll
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: transitionEffectTitle.verticalCenter
                    width: 73
                    height: 20
                    radius: 4
                    enabled: {
                        let transitionEffectEnable = transitionEffect.maskVisible === false && transitionEffect.transitionEditEnable === true && transitionEffect.transitionEffectEnable === true;
                        // 自拍视角PanoramaConfig::SELFIE_VIEW禁止操作关键帧
                        // 拍摄视角PanoramaConfig::SHOT_VIEW可操作区域关键帧，但目前不考虑区域关键帧
                        let normalKeyframeMode = (panoKfVm.viewingMode === PanoramaConfig.FREEDOM_VIEW || panoKfVm.viewingMode === PanoramaConfig.DIRECTION_LOCK);
                        return (transitionEffectEnable === true && normalKeyframeMode === true);
                    }
                    color: (rectangle_applyToAll.enabled === false) ? Colors.color_353738 : mousearea_applyToAll.containsMouse ? Colors.color_414344 : Colors.color_353738
                    opacity: (rectangle_applyToAll.enabled === true) ? 1 : 0.2

                    Text {
                        id: text_applyToAll
                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        wrapMode: Text.WordWrap
                        text: qsTr("pccut_image_nd_all")
                        font.pixelSize: 11
                        color: Colors.color_EEEEEE
                    }

                    MouseArea {
                        id: mousearea_applyToAll
                        anchors.fill: parent
                        hoverEnabled: true

                        onClicked: {
                            panoKfVm.applyTransitionToAll(transitionEffect.transitionEffectType);
                            toast.showToast(qsTr("pccut_adjust_applied_all"));
                            editorDraftManager.saveDraft();
                        }
                    }
                }

                // 关键帧过渡效果GridView区域
                TransitionEffectLayer {
                    id: transitionEffect
                    panoKfVm: panoKfVm
                    anchors {
                        left: parent.left
                        right: parent.right
                        leftMargin: 6
                        rightMargin: 6
                        top: transitionEffectTitle.bottom
                        topMargin: 12
                    }
                    onYChanged: {
                        globalSignal.transitionEffectLayerAreaUpadate(transitionEffectTitle.y, transitionEffectTitle.height + transitionEffect.height + transitionEffect.anchors.topMargin);
                    }
                }

                TransitionNotificationTips {
                    id: transitionNotificationTips
                    width: parent.width
                    height: 63
                    arrowLeftMargin: transitionNotificationButton.x
                    anchors {
                        bottom: transitionEffectTitle.top
                        bottomMargin: -2
                        left: parent.left
                        leftMargin: 12
                        right: parent.right
                        rightMargin: 12
                    }
                    visible: transitionNotificationButtonMouseArea.containsMouse
                }
            }
        }
    }

    Rectangle {
        width: parent.width
        height: 15
        anchors.bottom: parent.bottom

        // 设置从上到下的渐变色背景
        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: Colors.color_panorama_panel_gradient_start_color
            }
            GradientStop {
                position: 1.0
                color: Colors.color_panorama_panel_gradient_end_color
            }
        }
    }

    // 置灰
    Rectangle {
        id: visibleRectangle
        anchors.fill: parent
        color:  Colors.color_transparent
        visible: panoKfVm.panelOverlayVisible
        MouseArea {
            id:mouseID
            anchors.fill: parent
            hoverEnabled: true
            propagateComposedEvents: true  // 允许事件传递

            onClicked: (mouse) =>{
                mouse.accepted = !isInOverlayArea(mouse.x, mouse.y);
            }

            onPositionChanged: (mouse) =>{
                mouseID.hoverEnabled = !isInOverlayArea(mouse.x, mouse.y);
            }
        }
    }

    Component.onCompleted: {
        globalSignal.keyframePositionRefreshed();
        globalSignal.panoramaPanelTabCompleted();
    }

    Connections {
        target: globalSignal

        function onPanoramaPlayerPramaAdjust(operationType) {
            let valueList = panoramaPanelViewModel.getAllPerspectiveArgumentValue()
            if (valueList.length === 5) {
                globalSignal.panoramaControllerTrackEvent(valueList[0], valueList[1], valueList[2], valueList[3], valueList[4], operationType, root.currentPresetType)
            }
        }

        function onTrackViewingModeChanged(mode) {
            onViewingModeSelected(mode)
        }
    }

    function onViewingModeSelected(mode) {
        var isFreedomView = (mode === PanoramaConfig.FREEDOM_VIEW)
        panoStabilizeAdjust.updateUseStabilizeAndHorizonCorrectWhenSwitchView(isFreedomView, true)
        if (mode === PanoramaConfig.SELFIE_VIEW) {
            if (!viewModeAnalyzeController.needAnalyze(mode)) {
                updateFragmentViewingMode(mode);
            } else {
                // 还没数据的时候，先不着急切换，先分析一波
                if(viewModeAnalyzeController.hasUsbAgencyFile()) {
                    analyzeWaitingPopup.text = qsTr("pccut_editing_assistant_open_arithmetic");
                }
                else {
                    analyzeWaitingPopup.text = qsTr("pccut_editing_assistant_open_arithmetic_tip_1");
                }

                analyzeWaitingPopup.open();
                viewModeAnalyzeController.analyze(mode);
            }
        } else if (mode === PanoramaConfig.FORWARD_VIEW) {
            if (!viewModeAnalyzeController.needAnalyze(mode)) {
                updateFragmentViewingMode(mode);                 // 先切
                viewModeAnalyzeController.applyAnalyzed(mode);    // 缓存命中：后灌散点
            } else {
                // 还没数据的时候，先不着急切换，先分析一波
                if(viewModeAnalyzeController.forwardAnalyzeUsesProxy()) {
                    analyzeWaitingPopup.text = qsTr("pccut_editing_perspective_forward_open_tip");
                }
                else {
                    analyzeWaitingPopup.text = qsTr("pccut_editing_perspective_forward_open_tip_1");
                }

                analyzeWaitingPopup.open();
                viewModeAnalyzeController.analyze(mode);
            }
        }
        else {
            // 基础视角统一走 panoKfVm（基于内核选中片段），不再受老 root.viewModel 门控。
            updateFragmentViewingMode(mode);
        }
    }

    function updateFragmentViewingMode(mode) {
        panoKfVm.switchViewingMode(mode);  // nova: SwitchPanoramaViewCmd
    }

    function isPointInItem(point, item) {
        return point.x >= 0 && point.y >= 0 &&
                point.x <= item.width &&
                point.y <= item.height &&
                item.visible;
    }

    function isInOverlayArea(mouseX, mouseY) {
        return isPointInItem(mapToItem(viewingModeSelector, mouseX, mouseY), viewingModeSelector) ||
                isPointInItem(mapToItem(trackingLayer, mouseX, mouseY), trackingLayer) ||
                isPointInItem(mapToItem(panoramaTool, mouseX, mouseY), panoramaTool) ||
                isPointInItem(mapToItem(transitionNotificationButton, mouseX, mouseY), transitionNotificationButton) ||
                isPointInItem(mapToItem(allUseBtn, mouseX, mouseY), allUseBtn);
    }
}
