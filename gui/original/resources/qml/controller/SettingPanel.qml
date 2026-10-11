import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.3
import LightRectangle 1.0
import Config 1.0
import Controls 1.0
import VideoFragmentViewModel 1.0
import SettingPanelViewModel 1.0
import Qt5Compat.GraphicalEffects
import TransitionSettingViewModel 1.0
import Nova 1.0
import "../transition"
import UsedFunctionManager 1.0
import ProjectSettingsInfo 1.0


import "../effect"


Rectangle {
    id: root
    anchors.fill: parent
    color: Colors.color_141414
    property VideoFragmentViewModel viewModel: VideoFragmentViewModel {}
    property string mediaPath: ""
    property bool mediaExist: true
    SpeedViewModel {
        id: sharedSpeedVm
    }
    property SpeedViewModel speedViewModel: sharedSpeedVm
    property int selectIndex: 0
    // 点击了关键帧
    property bool isKeyframeClicked: false
    // 用户主动触发的操作
    property bool isUserTrigger: true
    // 【调节】tab 中的选中index
    property int adjustSettingPanelIndex: 0
    // 【新变速设置】内部子Tab：0=常规变速，1=曲线变速
    property int speedSubTabIndex: 0
    // 标记是否正在程序内部设置tab（区别于用户手动点击）
    property bool isRestoringTab: false
    // 记住最后一次选中片段时的tab索引（用于取消选中后再选其他片段时继承）
    property int lastActiveTabIndex: 0
    property int lastActiveSubTabIndex: -1
    // 记住最后一次选中的片段引用（用于类型比较）
    property QtObject lastActiveFragment: null
    // 标记本次selectIndex是否来自继承（用于refreshUI中判断子tab是否也需继承）
    property bool isInheritingTab: false
    // 只展示工程tab
    property bool isOnlyShowProjectTab: true
    // 切到另一 clip 时要保持的右侧 tab 组件（refreshUI 内按组件定位新索引后清空）
    property var preferredTabComponent: null
    // 上次 nova 面板归类（PropertyPanelViewModel.PanelKind），用于判断是否同类型 clip 间切换
    property int prevPanelKind: PropertyPanelViewModel.None

    property bool deviceIsAmd: false

    // 右侧当前 tab 类型（SettingPanelViewModel.SETTINGPANELTABTYPE_*）
    property int currentTabType: getSettingPanelTabType()

    SettingPanelViewModel {
        id: settingPanelviewModel
    }

    // 持久保存 trackingEditAction 的 tk 状态，供 PanoramaTrackingLayer 读取
    property bool isInTrackingFragment: false
    property bool isTkSupported: false
    Connections {
        target: globalSignal
        function onTrackingEditAction(inTrackingFragment, isEnd, isSupportTk) {
            console.log("onTrackingEditAction", inTrackingFragment, isEnd, isSupportTk);
            root.isInTrackingFragment = inTrackingFragment
            root.isTkSupported = isSupportTk
        }
    }

    onAdjustSettingPanelIndexChanged: currentTabType = getSettingPanelTabType()
    onSpeedSubTabIndexChanged: currentTabType = getSettingPanelTabType()

    // nova 选中决策：读 nle 选中，派生 panelKind，驱动右侧面板可见性（替代老选中计数）。
    PropertyPanelViewModel {
        id: propertyPanelViewModel
    }

    TransitionSettingViewModel{
        id: transitionViewModel

        // 转场选中 更新数据
        function showTransition() {
            //return
            logger.d("[Setting] showTransition ");

            isOnlyShowProjectTab = false;
            selectIndex = 0;
            var currentTab = tableView.getTab(tableView.currentIndex);
            if (!CommonUtils.isNull(currentTab) && currentTab === transitionTab) {
                return;
            }
            refreshUI();
            for (var i = 0; i < tableView.count; i++) {
                var tab = tableView.getTab(i);
                if (tab && tab === transitionTab) {
                    tableView.currentIndex = i;
                    break;
                }
            }
        }

        function hideTransition() {
            logger.d("[Setting] hideTransition ");
            var currentTab = tableView.getTab(tableView.currentIndex);
            if (!CommonUtils.isNull(currentTab) && currentTab === transitionTab) {
                selectIndex = 0;
                refreshUI();
            }
        }


        onIsShowChanged:{
            if(transitionViewModel.isShow){
                showTransition()
            }else{
                hideTransition()
            }

        }

    }


    NdFilterViewModel{
        id: videoMotionBlurController
    }
    //去频闪模型(nova：自动跟随选中片段)
    DeflickerFilterViewModel{
        id: deflickerSettingViewModel
    }

    Rectangle {
        anchors.fill: parent
        color: Colors.color_title_area_background
        visible: true
        Item {
            id: hoverContainer
            x: 12
            y: 0
            width: parent.width - 12
            height: 45

            property bool isHovered: false

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                propagateComposedEvents: true
                onEntered: hoverContainer.isHovered = true
                onExited: hoverContainer.isHovered = false
                onPressed: function(mouse) { mouse.accepted = false }
            }
        }

        ListView {
            id: hederList
            objectName: actionableItemName.settingHeadListView
            x: 12
            y: 0
            // 左右各留12px
            width: parent.width - 24
            height: 45
            spacing: 20 // 按钮之间的间距
            orientation: ListView.Horizontal
            clip: true
            model: tableView.dataList
            boundsBehavior: Flickable.StopAtBounds

            property bool needScroll: contentWidth > parent.width - 24

            // 让选中的tab居中显示的函数
            function centerSelectedTab(index) {
                if (!needScroll) {
                    return;
                }

                // 计算选中item的位置
                var itemX = 0;
                for (var i = 0; i < index; i++) {
                    var item = itemAtIndex(i);
                    if (item) {
                        itemX += item.width + spacing;
                    }
                }

                var currentItem = itemAtIndex(index);
                if (!currentItem) {
                    return;
                }

                var itemCenter = itemX + currentItem.width / 2;
                var listCenter = width / 2;
                var targetX = itemCenter - listCenter;

                var maxContentX = contentWidth - width;
                targetX = Math.max(0, Math.min(targetX, maxContentX));

                scrollAnimation.to = targetX;
                scrollAnimation.start();
            }

            delegate: MouseArea {
                objectName: actionableItemName.delegateItemForSettingHeadListView + index
                width: label.width
                onClicked: {
                    tableView.currentIndex = index;
                    // 让选中的tab居中显示
                    hederList.centerSelectedTab(index);
                    if (model.trackEventName.length > 0) {
                        eventTracker.trackEvent(model.trackEventName)
                    }
                    var tab = tableView.getTab(tableView.currentIndex);
                    if (!CommonUtils.isNull(tab) && tab === panoramaTab) {
                        return;
                    }
                    // tk 片段选中的时候切换到非tk的tab取消tk片段的选中状态
                    globalSignal.removeTrackingSelect();
                }
                height: hederList.height
                Text {
                    id: label
                    anchors.centerIn: parent
                    text: model.text
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    color: tableView.currentIndex === index ? Theme.settingTabSelectedTitleColor : Theme.settingTabNormalTitleColor
                }
            }
        }

        // 左侧滚动指示器
        Rectangle {
            id: leftScrollIndicator
            x: 4
            y: hederList.y
            width: 16
            height: hederList.height
            color: Colors.transparent
            visible: hederList.needScroll && hoverContainer.isHovered && !hederList.atXBeginning
            z: 2

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    scrollAnimation.to = 0;
                    scrollAnimation.start();
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: 16
                    height: 16
                    color: Colors.transparent

                    Image {
                        anchors.centerIn: parent
                        width: 16
                        height: 16
                        source: "qrc:/icons/icon_slider_left.svg"
                        sourceSize: Qt.size(16, 16)
                    }
                }
            }
        }

        // 左侧渐变阴影
        Rectangle {
            id: leftGradientShadow
            x: leftScrollIndicator.x + 4
            y: hederList.y
            width: 32
            height: hederList.height
            visible: hederList.needScroll && !hederList.atXBeginning
            z: 1

            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Colors.color_title_area_background }
                GradientStop { position: 0.5; color: Colors.color_title_area_background }
                GradientStop { position: 1.0; color: Colors.transparent}
            }
        }

        // 右侧渐变阴影
        Rectangle {
            id: rightGradientShadow
            x: scrollIndicator.x - 16
            y: hederList.y
            width: 32
            height: hederList.height
            visible: hederList.needScroll && !hederList.atXEnd
            z: 1

            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Colors.transparent }
                GradientStop { position: 0.4; color: Colors.color_title_area_background }
                GradientStop { position: 1.0; color: Colors.color_title_area_background }
            }
        }

        // 右侧滚动指示器
        Rectangle {
            id: scrollIndicator
            x: parent.width - 20
            y: hederList.y
            width: 16
            height: hederList.height
            color: Colors.transparent
            visible: hederList.needScroll && hoverContainer.isHovered && !hederList.atXEnd
            z: 2

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    var targetX = hederList.contentWidth - hederList.width;
                    scrollAnimation.to = targetX;
                    scrollAnimation.start();
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: 16
                    height: 16
                    color: Colors.transparent

                    Image {
                        anchors.centerIn: parent
                        width: 16
                        height: 16
                        source: "qrc:/icons/icon_slider_right.svg"
                        sourceSize: Qt.size(16, 16)
                    }
                }
            }
        }

        NumberAnimation {
            id: scrollAnimation
            target: hederList
            property: "contentX"
            duration: 200
            easing.type: Easing.OutCubic
        }



        LightTabView {
            id: tableView
            objectName: actionableItemName.settingPanelTabView
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                top: hederList.bottom
            }
            onCurrentIndexChanged: {
                // 用户手动切换tab时，子tab重置为第一个；程序恢复tab时不重置
                if (!isRestoringTab) {
                    adjustSettingPanelIndex = 0;
                    speedSubTabIndex = 0;
                    // 用户主动点击tab时，实时保存到当前片段（videoFragment 为 legacy 草稿加载路径，
                    // nova 记忆双写：取消选中后再选中走 onStateChanged 恢复）
                    propertyPanelViewModel.saveLastTabIndex(tableView.currentIndex, -1);
                    if (!CommonUtils.isNull(viewModel) && viewModel.hasFragment) {
                        viewModel.videoFragment.lastSettingTabIndex = tableView.currentIndex;
                        viewModel.videoFragment.lastSubTabIndex = -1;
                    }
                }
                currentTabType = getSettingPanelTabType();
            }

            // 初始化，当第一个为变速时，片段上的变速标签，需focus
            onCountChanged: {
                currentTabType = getSettingPanelTabType();
            }
        }

        Item {
            id: tableViewbgView
            parent: tableView
            anchors.fill: parent
            PointHandler {
               onGrabChanged: (transition, eventPointValue) => {
                    eventPointValue.accepted = false;
                    if (eventPointValue.pressPosition !== eventPointValue.position) {
                        return;
                    }
                    var tab = tableView.getTab(tableView.currentIndex);
                    if (!CommonUtils.isNull(tab) && tab === panoramaTab) {
                        return;
                    }
                    // tk 片段选中的时候切换到非tk的tab取消tk片段的选中状态
                    globalSignal.removeTrackingSelect();
               }
            }
        }
    }


    TextSettingPanel {
        id: textSettingPanel
        anchors.fill: parent
        color: Colors.color_title_area_background
        // 显隐由 propertyPanelViewModel.onStateChanged 统一控制（唯一入口）；初值隐藏。
        visible: false
    }

    Component {
        id: projectTab
        ProjectSettingsTabPanel {
              id: projectSettingsTabPanel
        }
    }

    // 「项目设置」编辑弹窗的宿主：弹窗本身挂在 Overlay 上，这里只需要一个不占位的承载体。
    // 必须 clip：宿主宽高为 0，面板内以 right/bottom 锚定的「修改」按钮会落到负坐标，
    // 而编辑器根节点用的是 layer+OpacityMask（只遮渲染、不裁事件），
    // 不 clip 的话这个看不见的按钮会飘到顶部 AppBar 上，抢走右上角图标的 hover 与点击。
    Loader {
        id: projectSettingsPopupHost
        width: 0
        height: 0
        clip: true
    }

    Connections {
        target: globalSignal
        function onClickProxySuggestPopup() {
            // 复用同一个实例，避免每次进入都泄漏一个 ProjectSettingsTabPanel
            if (!projectSettingsPopupHost.item) {
                projectSettingsPopupHost.sourceComponent = projectTab;
            }
            if (projectSettingsPopupHost.item) {
                projectSettingsPopupHost.item.showEditorPop();
            }
        }
    }

    Component {
        id: panoramaTab
        PanoramaPanel {
            viewModel: root.viewModel
            devIsAmd: deviceIsAmd
        }
    }

    Component {
        id: qualitySettingsTab
        QualitySettingsPanel {
            viewModel: root.viewModel
        }
    }

    // 普通（非全景）视频的【画面】tab，目前仅承载 ND 滤镜入口
    Component {
        id: regularImageTab
        RegularImagePanel {
        }
    }

    // 【新变速设置】
    Component {
        id: speedSettingTab
        SpeedSettingPanel {
            id: speedSettingPanel
            viewModel: sharedSpeedVm
            subTabIndex: root.speedSubTabIndex
            onCurrentIndexChanged: {
                root.speedSubTabIndex = currentIndex;
                if (!isRestoringTab) {
                    sharedSpeedVm.saveSubTabIndex(currentIndex);
                }
                currentTabType = getSettingPanelTabType();
            }
            // 普通变速抬手：统计/埋点（内核写入已在 SpeedSlider 内完成）
            onRegSpeedSliderSignal: (newRegSpeed) => {
                UsedFunctionManager.addFunction(draftManager.activeProjectEnvId(),UsedFunctionManager.EditorFunctionType.SPEED_ADJUST);
                eventTracker.trackEvent("pccut_speed_adjust", {"speed_value": newRegSpeed})
            }

            onCurveSpeedSignal: {
                UsedFunctionManager.addFunction(draftManager.activeProjectEnvId(),UsedFunctionManager.EditorFunctionType.SPEED_ADJUST);
            }
        }
    }

    Component {
        id: adjustSettingTab
        AdjustSettingPanel {
            id: adjustSettingPanel
            viewModel: root.viewModel
            hasDLog2Metadata: propertyPanelViewModel.hasDLog2Metadata
            initSubTabIndex: adjustSettingPanelIndex

            Accessible.role: Accessible.Button
            Accessible.description: "videoedit_image"
            onCurrentIndexChanged: {
                adjustSettingPanelIndex = adjustSettingPanel.currentIndex;
                if (!isRestoringTab) {
                    // nova 双写：调节子 tab 也按 clip 记忆（legacy fm 路径保留）
                    propertyPanelViewModel.saveLastTabIndex(tableView.currentIndex, adjustSettingPanelIndex);
                    if (!CommonUtils.isNull(viewModel) && viewModel.hasFragment) {
                        viewModel.videoFragment.lastSubTabIndex = adjustSettingPanelIndex;
                    }
                }
                currentTabType = getSettingPanelTabType();
            }
        }
    }

    Component {
        id: beautySettingTab
        ImageBeautyPanel {
            Accessible.role: Accessible.Button
            Accessible.description: "videoedit_image"
        }
    }

    Component {
        id: audioSettingTab
        VolumePanel {
            Accessible.role: Accessible.Button
            Accessible.description: "audioedit_audio"
        }
    }

    Component {
        id: fileInfoTab
        FileInfoPanel {
            filePath: mediaPath
        }
    }

    Component {
        id: mediaLostTab
        MediaLostPanel {
        }
    }

    Component {
        id: specialEffectTab
        SpecialEffectPanel {
            viewModel: root.viewModel
            Accessible.role: Accessible.Button
            Accessible.description: "videoedit_special_effect"
        }
    }

    Component {
        id: dashboardTab

        DashboardSettingPanel {
            objectName: actionableItemName.dashboardSettingPanel
            viewModel: root.viewModel
        }
    }

    // 转场编辑面板
    Component{
        id: transitionTab
        TransitionSettingPanel {
            id:transitionSettingPanel
            model:transitionViewModel
        }
    }

    //【快捷变速】Alert
    RegSpeedAlert {
        id: regSpeedAlert
        viewModel: null
        property bool mediaLost: CommonUtils.isNull(viewModel) || !viewModel.hasClip || !viewModel.mediaExists
        onMediaLostChanged: {
            if (mediaLost && !CommonUtils.isNull(viewModel) && viewModel.hasClip) {
                regSpeedAlert.close();
            }
        }
        onQuickRegSpeedItemClicked: (newRegSpeed) => {
            if (viewModel && viewModel.hasClip) {
                viewModel.updateRegSpeed(newRegSpeed);
            }
        }
    }

    function clearTableView() {
        tableView.clearTableView();
    }

    function getSettingPanelTabType() {
        var tab = tableView.getTab(tableView.currentIndex);
        if (CommonUtils.isNull(tab)) {
            return SettingPanelViewModel.SETTINGPANELTABTYPE_REGSPEED;
        }
        if (tab === panoramaTab) {
            return SettingPanelViewModel.SETTINGPANELTABTYPE_PANORAMA;
        }
        if (tab === qualitySettingsTab) {
            return SettingPanelViewModel.SETTINGPANELTABTYPE_QUALITY;
        }
        if (tab === regularImageTab) {
            return SettingPanelViewModel.SETTINGPANELTABTYPE_QUALITY;
        }
        if (tab === audioSettingTab) {
            return SettingPanelViewModel.SETTINGPANELTABTYPE_AUDIO;
        }
        if (tab === adjustSettingTab) {
            if (adjustSettingPanelIndex === 0) {
                return SettingPanelViewModel.SETTINGPANELTABTYPE_ADJUST_LUT;
            } else if (adjustSettingPanelIndex === 1) {
                return SettingPanelViewModel.SETTINGPANELTABTYPE_ADJUST_STYLEFILTER;
            }
        }
        if (tab === speedSettingTab) {
            if (root.speedSubTabIndex === 1) {
                return SettingPanelViewModel.SETTINGPANELTABTYPE_SPEED;
            }
            // 超级慢动作与常规变速共用 speedSettingTab 的常规子面板。
            return SettingPanelViewModel.SETTINGPANELTABTYPE_REGSPEED;
        }
        if (tab === specialEffectTab) {
            return SettingPanelViewModel.SETTINGPANELTABTYPE_EFFECT;
        }

        if (tab === dashboardTab) {
            return SettingPanelViewModel.SETTINGPANELTABTYPE_DASHBOARD;
        }
        if (tab === transitionTab) {
            return SettingPanelViewModel.SETTINGPANELTABTYPE_TRANSITION;
        }
        if(tab === beautySettingTab) {
            return SettingPanelViewModel.SETTINGPANELTABTYPE_BEAUTY;
        }
        return -1;
    }

    // 获取当前tab的子tab索引
    function getCurrentSubTabIndex() {
        var tab = tableView.getTab(tableView.currentIndex);
        if (tab === adjustSettingTab) return adjustSettingPanelIndex;
        if (tab === speedSettingTab) return speedSubTabIndex;
        return -1;
    }

    // 刷新Tab
    function refreshUI() {
        // 整个refreshUI过程中阻止onCurrentIndexChanged保存tab状态
        isRestoringTab = true;
        clearTableView();
        if (transitionViewModel.isShow) {
            // 转场选中优先级最高：即使 PropertyPanelViewModel 因转场非普通 clip 判为 None(isOnlyShowProjectTab)，也要显示转场面板
            tableView.addTab(qsTr("pccut_resource_transition_title"), transitionTab, "");
        } else if (isOnlyShowProjectTab) {
            tableView.addTab(qsTr("pccut_project_info"), projectTab, "");
        } else {
            if (!CommonUtils.isEmptyStr(mediaPath) && mediaExist) {
                tableView.addTab(qsTr("pccut_media_info"), fileInfoTab, "");
            }else if ((!CommonUtils.isNull(root.viewModel) && root.viewModel.hasFragment)
                      || propertyPanelViewModel.panelKind === PropertyPanelViewModel.Video) {
                if (!CommonUtils.isNull(root.viewModel) && root.viewModel.hasFragment) {
                if (root.viewModel.videoFragment.mediaSourceExists) {
                    if (root.viewModel.videoFragment.isPanoramaSource) {
                        tableView.addTab(qsTr("pccut_panel_video"), panoramaTab, "");
                        if (!root.viewModel.videoFragment.isPanoramaImage()) {
                            tableView.addTab(qsTr("pccut_panel_image"), qualitySettingsTab, "pccut_image_tab");
                        }
                    } else if (videoMotionBlurController.canUseNdFilterInCurClipForRegularVideo()) {
                        // 非全景普通视频：当前设备/片段支持 ND 滤镜时，提供【画面】tab
                        tableView.addTab(qsTr("pccut_panel_image"), regularImageTab, "pccut_image_tab");
                    }
                    // 当视频片段有音频时，再添加【音频】tab
                    if (root.viewModel.videoFragment.isHasAudioPresent) {
                        tableView.addTab(qsTr("pccut_panel_audio"), audioSettingTab, "pccut_audio_tab");
                    }
                    tableView.addTab(qsTr("pccut_adjust"), adjustSettingTab, "pccut_panel_tab");
                    tableView.addTab(qsTr("pccut_panel_beauty_tab_title"), beautySettingTab, "pccut_panel_beauty_tab");
                    if (root.viewModel.videoFragment.isVideo()) {
                        tableView.addTab(qsTr("pccut_panel_speed"), speedSettingTab, "pccut_speed_tab");
                    }

                    // 添加特效tab：门控改读 nova 草稿（active 项目唯一选中 clip 是否存在且启用特效）
                    var effectGate = editorManager.isActiveSelectedClipEffectEnabled();
                    if (effectGate) {
                        tableView.addTab(qsTr("pccut_tab_effects"), specialEffectTab, "");
                    }

                    //当视频片段有仪表盘时，添加tab
                    if (dashboardManager.hasDashboardForSelectedClip()) {
                        tableView.addTab(qsTr("pccut_dashboard"), dashboardTab, "");
                    }

                } else {
                    tableView.addTab("", mediaLostTab, "");
                }
                } else {
                    // nova 第1步：选中视频片段但无 fragment 数据，先加基础视频 tab（子面板数据第2步补）。
                    // 全景判定改读 PropertyPanelViewModel 探测结果（基于 nle path，对齐老 isPanoramaSource）。
                    // 顺序对齐原始：取景(全景) → 画质(全景非图片) → 音频(视频带音轨时) → 调节 → 变速
                    if (propertyPanelViewModel.videoIsPanorama) {
                        tableView.addTab(qsTr("pccut_panel_video"), panoramaTab, "");
                        if (!propertyPanelViewModel.videoIsPanoramaImage) {
                            tableView.addTab(qsTr("pccut_panel_image"), qualitySettingsTab, "pccut_image_tab");
                        }
                    } else if (videoMotionBlurController.canUseNdFilterInCurClipForRegularVideo()) {
                        // 非全景普通视频：当前设备/片段支持 ND 滤镜时，提供【画面】tab
                        tableView.addTab(qsTr("pccut_panel_image"), regularImageTab, "pccut_image_tab");
                    }
                    if (propertyPanelViewModel.videoHasAudio) {
                        tableView.addTab(qsTr("pccut_panel_audio"), audioSettingTab, "pccut_audio_tab");
                    }
                    tableView.addTab(qsTr("pccut_adjust"), adjustSettingTab, "pccut_panel_tab");
                    tableView.addTab(qsTr("pccut_panel_beauty_tab_title"), beautySettingTab, "pccut_panel_beauty_tab");
                    // 变速 tab：图片(含全景图片)不加
                    if (!propertyPanelViewModel.videoIsImage) {
                        tableView.addTab(qsTr("pccut_panel_speed"), speedSettingTab, "pccut_speed_tab");
                    }

                    // 特效 tab（nova 选中路径，门控读 nle 草稿）
                    if (editorManager.isActiveSelectedClipEffectEnabled()) {
                        tableView.addTab(qsTr("pccut_tab_effects"), specialEffectTab, "");
                    }
                    // 仪表盘 tab（nova 选中路径，门控读 nle 草稿，不依赖 legacy fragment）
                    if (dashboardManager.hasDashboardForSelectedClip()) {
                        tableView.addTab(qsTr("pccut_dashboard"), dashboardTab, "");
                    }
                }
            } else if (propertyPanelViewModel.panelKind === PropertyPanelViewModel.Audio) {
                tableView.addTab(qsTr("pccut_panel_audio"), audioSettingTab, "pccut_audio_tab");
            }else {
                tableView.addTab(qsTr("pccut_project_info"), projectTab, "");
            }
        }
        tableView.syncTab();
        // 恢复子tab：必须在设置tableView.currentIndex之前，因为tab组件创建时会读取这些值
        var restoreIndex = Math.min(Math.max(0, selectIndex), tableView.count - 1);
        // 保持当前 tab：新列表中若存在要保留的 tab 组件，则定位到它（子 tab 经 isInheritingTab 继承），否则回退 selectIndex
        if (!CommonUtils.isNull(preferredTabComponent)) {
            for (var pi = 0; pi < tableView.count; pi++) {
                if (tableView.getTab(pi) === preferredTabComponent) {
                    restoreIndex = pi;
                    break;
                }
            }
            preferredTabComponent = null;
        }
        var inheritedSubTabIndex = -1;
        var restoreTab = tableView.getTab(restoreIndex);
        if (!CommonUtils.isNull(viewModel) && viewModel.hasFragment && viewModel.videoFragment.lastSubTabIndex >= 0) {
            if (restoreTab === adjustSettingTab) adjustSettingPanelIndex = viewModel.videoFragment.lastSubTabIndex;
        } else if (restoreTab === speedSettingTab && sharedSpeedVm.lastSubTabIndex >= 0) {
            speedSubTabIndex = sharedSpeedVm.lastSubTabIndex;
        } else if (isInheritingTab && lastActiveSubTabIndex >= 0) {
            // 一级tab继承成功时，同步继承子tab
            inheritedSubTabIndex = lastActiveSubTabIndex;
            if (restoreTab === adjustSettingTab) adjustSettingPanelIndex = lastActiveSubTabIndex;
            else if (restoreTab === speedSettingTab) speedSubTabIndex = lastActiveSubTabIndex;
        } else if (restoreTab === adjustSettingTab && propertyPanelViewModel.lastSubTabIndex >= 0) {
            // nova 路径：恢复该 clip 记住的调节子 tab
            adjustSettingPanelIndex = propertyPanelViewModel.lastSubTabIndex;
        } else {
            adjustSettingPanelIndex = 0;
            speedSubTabIndex = 0;
        }
        isInheritingTab = false;
        tableView.currentIndex = restoreIndex;
        // 首次通过继承确定的tab，保存记账：legacy 写片段；nova 写 PropertyPanelViewModel（取消选中后再选中可恢复）
        if (!CommonUtils.isNull(viewModel) && viewModel.hasFragment && viewModel.videoFragment.lastSettingTabIndex < 0) {
            viewModel.videoFragment.lastSettingTabIndex = restoreIndex;
            viewModel.videoFragment.lastSubTabIndex = inheritedSubTabIndex >= 0 ? inheritedSubTabIndex : getCurrentSubTabIndex();
        }
        if (propertyPanelViewModel.panelKind === PropertyPanelViewModel.Video
                && propertyPanelViewModel.lastTabIndex < 0) {
            propertyPanelViewModel.saveLastTabIndex(restoreIndex, getCurrentSubTabIndex());
        }
        isRestoringTab = false;
        currentTabType = getSettingPanelTabType();
    }

    Component.onCompleted: {
        Qt.callLater(function(){
            refreshUI();
        })
    }

    Connections {
        target: root.viewModel

        function onSourceDataUpdated() {
            selectIndex = tableView.currentIndex;
            refreshUI();
            if (selectIndex >= tableView.count) {
                selectIndex = 0;
            }
        }
    }

    // nova 选中决策：唯一驱动右侧面板可见性的入口（读 nle 选中，替代老 multiSelectStateChanged 计数）。
    Connections {
        target: propertyPanelViewModel
        function onStateChanged() {
            var kind = propertyPanelViewModel.panelKind;
            var wasVideo = (prevPanelKind === PropertyPanelViewModel.Video);
            prevPanelKind = kind;
            preferredTabComponent = null;
            if (kind === PropertyPanelViewModel.None || kind === PropertyPanelViewModel.Multi) {
                // 取消/多选 → 项目信息。复刻老 none/multi 分支的 tab 继承记账
                lastActiveTabIndex = tableView.currentIndex;
                lastActiveSubTabIndex = getCurrentSubTabIndex();
                if (!CommonUtils.isNull(root.viewModel)) {
                    lastActiveFragment = root.viewModel.videoFragment;
                    root.viewModel.videoFragment = null;
                }
                textSettingPanel.visible = false;  // 取消/多选：隐藏文字面板
                isOnlyShowProjectTab = true;
                dashboardManager.selectClip("");  // nova 选中清空：同步仪表盘目标 + 刷新左侧已添加态
                refreshUI();
                return;
            }
            isOnlyShowProjectTab = false;
            selectIndex = 0;
            if (propertyPanelViewModel.lastTabIndex >= 0) {
                // 恢复该 clip 上次选中的 tab（子 tab 在 refreshUI 内按面板类型恢复）
                selectIndex = propertyPanelViewModel.lastTabIndex;
            } else if (kind === PropertyPanelViewModel.Video && wasVideo) {
                // 切到另一视频 clip 时保持当前右侧 tab：记住当前 tab 组件与子 tab，refreshUI 内按组件定位
                preferredTabComponent = tableView.getTab(tableView.currentIndex);
                lastActiveSubTabIndex = getCurrentSubTabIndex();
                isInheritingTab = true;
            }
            if (kind === PropertyPanelViewModel.Audio) {
                // 音频面板=VolumePanel 自追踪 nle。复刻老 onAudioSelected 的 tab 记账重置
                lastActiveFragment = null;
                lastActiveTabIndex = 0;
                lastActiveSubTabIndex = -1;
                if (!CommonUtils.isNull(root.viewModel)) root.viewModel.videoFragment = null;
                textSettingPanel.visible = false;  // 音频：隐藏文字面板
                dashboardManager.selectClip("");
            } else if (kind === PropertyPanelViewModel.Text) {
                // 文字面板：显示浮层 TextSettingPanel（其内部 TextViewModel 自追踪 nle 选中）。
                // 浮层 anchors.fill 盖住 tableView，仅需置可见；底层 tab 仍刷新保持状态一致。
                textSettingPanel.visible = true;
                dashboardManager.selectClip("");
                refreshUI();
                return;
            } else {
                // Video：走 refreshUI 的视频分支（基础 tab）
                textSettingPanel.visible = false;  // 视频：隐藏文字面板
                dashboardManager.selectClipFromSelection();  // 同步仪表盘目标到 nova 当前选中 clip
            }
            refreshUI();
        }
    }

    Connections {
        target: globalSignal
        function onGpuInfoStateChanged(isAmd) {
            deviceIsAmd = isAmd
        }

        // 仪表盘增/删/参数撤销重做后，选中片段未变不会触发 onStateChanged；
        // 借 refreshDashboardName（对账变更后发出）重建 tab，门控 hasDashboardForSelectedClip 直接读草稿。
        function onRefreshDashboardName() {
            refreshUI();
        }

        function onActivedProjectChanged(id) {
            logger.d("[Setting] onActivedProjectChanged " + id);
            refreshUI();
        }

        // 目前逻辑：hover素材，不会影响到右侧操作面板
        // 素材列表，选中素材，右侧展示【文件详情】
        // 选中轨道上的片段，右侧展示 具体的操作项
        // 未有选中态时，显示 项目信息
        // 素材列表选中素材
        function onMediaSelected(selectedPaths, exists) {
            if (selectedPaths.length === 1 && exists.length === 1) {
                isOnlyShowProjectTab = false;
                mediaPath = selectedPaths[0];
                mediaExist = exists[0];
            } else {
                // 素材区取消选中：面板回退到 nle 选中态（单选片段→片段属性，无选中/多选→项目信息）
                var kind = propertyPanelViewModel.panelKind;
                isOnlyShowProjectTab = (kind === PropertyPanelViewModel.None
                                        || kind === PropertyPanelViewModel.Multi);
                mediaPath = "";
                mediaExist = false;
            }
            logger.d("[Setting] onMediaSelected " + mediaPath);
            refreshUI();
        }

        // 视频片段，选中
        function onVideoSelected(fragment) {
            logger.d("[Setting] onVideoSelected " + fragment);
            if (CommonUtils.isNull(root.viewModel) || !root.viewModel.hasFragment) {
                isOnlyShowProjectTab = false;
                isInheritingTab = false;
                // 从片段恢复上次选中的tab索引
                if (!CommonUtils.isNull(fragment) && fragment.lastSettingTabIndex >= 0) {
                    selectIndex = fragment.lastSettingTabIndex;
                } else if (!CommonUtils.isNull(fragment) && !CommonUtils.isNull(lastActiveFragment)
                           && fragment.mediaType === lastActiveFragment.mediaType) {
                    // 无记录且类型相同时，继承取消选中前的tab
                    selectIndex = lastActiveTabIndex;
                    isInheritingTab = true;
                } else {
                    selectIndex = 0;
                }
            } else {
                isInheritingTab = false;
                if (!CommonUtils.isNull(fragment)) {
                    // 优先恢复片段自己记录的tab索引；首次选中时仅同类型片段继承tab
                    if (fragment.lastSettingTabIndex >= 0) {
                        selectIndex = fragment.lastSettingTabIndex;
                    } else if (viewModel.videoFragment.mediaType === fragment.mediaType) {
                        // 类型完全相同，继承当前tab索引
                        selectIndex = tableView.currentIndex;
                        isInheritingTab = true;
                    } else {
                        // 类型不同，显示第一个tab
                        selectIndex = 0;
                    }
                }
            }
            // 切换片段前，记住当前tab索引并保存子tab到旧片段
            if (!CommonUtils.isNull(viewModel) && viewModel.hasFragment && viewModel.videoFragment !== fragment) {
                lastActiveTabIndex = tableView.currentIndex;
                lastActiveSubTabIndex = getCurrentSubTabIndex();
                lastActiveFragment = viewModel.videoFragment;
            }
            var isSame = !CommonUtils.isNull(root.viewModel) && root.viewModel.hasFragment && root.viewModel.videoFragment === fragment;
            if (!CommonUtils.isNull(root.viewModel)) {
                root.viewModel.videoFragment = fragment;
                dashboardManager.selectClipFromSelection();
            }
            if (CommonUtils.isNull(root.viewModel) || !root.viewModel.hasFragment) {
                selectIndex = 0;
            }
            // 先选中普通素材，再点击全景素材上的关键帧，会触发该情况
            if (!CommonUtils.isNull(root.viewModel) && root.viewModel.hasFragment && root.viewModel.videoFragment.isPanoramaSource && isKeyframeClicked) {
                selectIndex = 0;
                isKeyframeClicked = false;
            }
            if(!isSame) {
                refreshUI();
            }
        }
        // 关键帧选中
        function onKeyframeClicked(track, clip, position) {
            logger.d("[Setting] onKeyframeClicked " + clip);
            // tableView中有【取景】tab，会直接切换到【取景】tab
            for (var i = 0; i < tableView.count; i++) {
                var tab = tableView.getTab(i);
                if (tab && tab === panoramaTab) {
                    tableView.currentIndex = i;
                    return;
                }
            }
            // 若没有【取景】tab，说明还tableView没有将tab 添加上
            isKeyframeClicked = true;
        }

        // 片段上【快捷变速】按钮被点击
        function onQuickRegSpeedBtnClicked(target) {
            var speedVm = sharedSpeedVm;
            if (!speedVm || !speedVm.hasClip) {
                return;
            }
            regSpeedAlert.viewModel = speedVm;
            logger.d("[Setting] onQuickRegSpeedBtnClicked " + target);
            var rect = UiUtils.getGlobalPosition(target);
            regSpeedAlert.refreshMaxHeight();
            var contentRectangleY = rect.y + target.height / 2;
            if (windowSizeManager.getCurrentGeometry().height < regSpeedAlert.maxHeight / 2 + 12 + contentRectangleY) {
                contentRectangleY -= 10 + stackLayout.anchors.bottomMargin;
            }
            regSpeedAlert.contentRectangleX = rect.x + target.width;
            regSpeedAlert.contentRectangleY = contentRectangleY;
            regSpeedAlert.open();
        }

        // 片段上的标签tag被点击，需切换到对应的tab
        function onVideoItemViewClickTabType(tabType) {
            logger.d("[Setting] onVideoItemViewClickTabType " + tabType);
            // 在切换外部 Tab 前设置目标子 Tab，确保 SpeedSettingPanel 实例化时能读到正确值
            if (tabType === SettingPanelViewModel.SETTINGPANELTABTYPE_SPEED) {
                root.speedSubTabIndex = 1;  // 曲线变速
            } else if (tabType === SettingPanelViewModel.SETTINGPANELTABTYPE_REGSPEED
                       || tabType === SettingPanelViewModel.SETTINGPANELTABTYPE_SUPER_SLOW) {
                root.speedSubTabIndex = 0;  // 常规变速（含超级慢动作）
            }
            var tabComponentMap = {
                [SettingPanelViewModel.SETTINGPANELTABTYPE_PANORAMA]: panoramaTab,
                [SettingPanelViewModel.SETTINGPANELTABTYPE_ADJUST_LUT]: adjustSettingTab,
                [SettingPanelViewModel.SETTINGPANELTABTYPE_ADJUST_STYLEFILTER]: adjustSettingTab,
                [SettingPanelViewModel.SETTINGPANELTABTYPE_REGSPEED]: speedSettingTab,
                [SettingPanelViewModel.SETTINGPANELTABTYPE_SPEED]: speedSettingTab,
                [SettingPanelViewModel.SETTINGPANELTABTYPE_SUPER_SLOW]: speedSettingTab,
                [SettingPanelViewModel.SETTINGPANELTABTYPE_DASHBOARD]: dashboardTab,
                [SettingPanelViewModel.SETTINGPANELTABTYPE_EFFECT]: specialEffectTab
            };
            var expectedComponent = tabComponentMap[tabType];
            for (var i = 0; i < tableView.count; i++) {
                var tab = tableView.getTab(i);
                if (!CommonUtils.isNull(tab) && tab === expectedComponent) {
                    // isRestoringTab 仅阻止 onCurrentIndexChanged 中的 adjustSettingPanelIndex=0 和 speedSubTabIndex=0 重置
                    isRestoringTab = true;
                    tableView.currentIndex = i;
                    isRestoringTab = false;
                    // 片段标签点击是用户主动操作，保存tab状态（nova 双写）
                    propertyPanelViewModel.saveLastTabIndex(i, getCurrentSubTabIndex());
                    if (!CommonUtils.isNull(viewModel) && viewModel.hasFragment) {
                        viewModel.videoFragment.lastSettingTabIndex = i;
                        viewModel.videoFragment.lastSubTabIndex = getCurrentSubTabIndex();
                    }
                    if (tabType === SettingPanelViewModel.SETTINGPANELTABTYPE_ADJUST_LUT) {
                        globalSignal.switchToAdjustTab();
                    } else if (tabType === SettingPanelViewModel.SETTINGPANELTABTYPE_ADJUST_STYLEFILTER) {
                        globalSignal.switchToFilterTab();
                    } else if (tabType === SettingPanelViewModel.SETTINGPANELTABTYPE_DASHBOARD) {
                        globalSignal.switchToDashboardTab();
                    }
                    return;
                }
            }
        }

        function onSwitchPanoromaPanel() {
            logger.d("[Setting] onSwitchPanoromaPanel ");
            var tab = tableView.getTab(tableView.currentIndex);
            if (!CommonUtils.isNull(tab) && tab === panoramaTab) {
                return;
            }
            selectIndex = 0;
            refreshUI();
        }
        // 添加仪表盘时通知设置面板tab刷新并切换
        function onSwitchToDashboardTab() {
            var currentTab = tableView.getTab(tableView.currentIndex);
            if (!CommonUtils.isNull(currentTab) && currentTab === dashboardTab) {
                return;
            }
            refreshUI();
            for (var i = 0; i < tableView.count; i++) {
                var tab = tableView.getTab(i);
                if (tab && tab === dashboardTab) {
                    tableView.currentIndex = i;
                    // 跳到 dashboard tab 后同步 selectIndex：添加后会接连触发 refreshDashboardName/onDraftChanged
                    // 等多次 refreshUI，其末尾按 selectIndex 重置 currentIndex。不同步则被刷回 Video 分支的 0。
                    selectIndex = i;
                    break;
                }
            }
        }
    }

    Connections{
        target: globalSignal
        function onEnterKfGuideModel(){
            for (var i = 0; i < tableView.count; i++) {
                var tab = tableView.getTab(i);
                if (tab && tab === panoramaTab) {
                    tableView.currentIndex = i;
                    return;
                }
            }
        }
    }
}
