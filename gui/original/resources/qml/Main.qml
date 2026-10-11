import QtQuick.Window 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.3
import QtQuick 2.15
import Controls 1.0
import Config 1.0
import Qt5Compat.GraphicalEffects
import FpsDetect 1.0
import CloudAlbumManager 1.0
import "./track"
import "./menubar"
import "./player"
import "./controller"
import "./explorer"
import "./welcome"
import "./welcome/cloudalbum"
import "./debug"
import UserGuideMaskManager 1.0
import UserGuideTypeModel 1.0
import BusinessLogger 1.0
import BusinessLog 1.0
import WindowPositionDetector 1.0
import ViewModeAnalyzeController 1.0
import ProjectStateController 1.0
import SettingPanelViewModel 1.0

LightWindow {
    id: lightWindow
    // 检测当前平台
    objectName: actionableItemName.mainPanel
    property bool isWindows: CommonUtils.isWindows()

    property UserGuideMask userGuideMask: mask

    property MaterialPanel materialPanel: null
    property PlayerPanel playerPanel: null
    property SettingPanel settingPanel: null
    property TrackDock tracks: null
    property SplitView content: null

    property bool editorCompleted: false

    UserGuideMask{
        id:mask
        visible: false
        anchors.top: appbar.top
        anchors.left: parent.left
        anchors.fill: parent
        z: 2
        color: Colors.transparent
        userGuideType: UserGuideType.UNKOWN

        WindowPositionDetector{
            id: windowPositionDetector
        }

        onVisibleChanged: {
            if(mask.visible){
                renderTimer.start();
            }

            if (mask.visible === false && mask.userGuideType === UserGuideType.OVERALL) {
                globalSignal.audioHighlightPromptRequired()
            }
        }

        // 通过定时器解决切换到编辑页面时，页面布局还没有完成时获取到的元素的位置错误的问题
        Timer {
            id: renderTimer
            interval: 300;
            repeat: false
            onTriggered: {
                mask.maskAreaUpdate();
            }
        }

        function adjustWindow(){
            // 参考剪映:进入新手引导时，如果主窗口有部分在屏幕外，先将主窗口移到屏幕内
            // 主要是为了防止关闭蒙层的弹窗不在屏幕内时无法关闭蒙层的问题
            let isCompleteOnScreen = windowPositionDetector.isWindowCompletelyOnScreen(lightWindow);
            if(!isCompleteOnScreen){
                windowPositionDetector.resetWindowToBestScreen(lightWindow);
            }
        }

        Connections{
            target: globalSignal
            function onOpenUserGuide(){
                mask.adjustWindow();
                mask.userGuideType = UserGuideType.OVERALL;
                mask.visible = true;
                globalSignal.enableMenuBar(false);
                editorManager.isInUserGuideStatus = true;
            }
            function onEnterSuperSlowGuide(){
                if (!Tools.isSupportSuperSlow()) return;
                globalSignal.videoItemViewClickTabType(SettingPanelViewModel.SETTINGPANELTABTYPE_SUPER_SLOW);
                mask.adjustWindow();
                mask.userGuideType = UserGuideType.SUPER_SLOW;
                mask.visible = true;
                editorManager.isInUserGuideStatus = true;
            }
            function onEnterTkGuideModel(){
                mask.adjustWindow();
                mask.visible = true;
                mask.userGuideType = UserGuideType.TRACKING;
                editorManager.isInUserGuideStatus = true;
            }

            function onEnterKfGuideModel(){
                mask.adjustWindow();
                mask.visible = true;
                mask.userGuideType = UserGuideType.KEYFRAMESTART;
                editorManager.isInUserGuideStatus = true;
            }

            function onEnterRegionKfEnable(){
                mask.adjustWindow();
                mask.visible = true;
                mask.userGuideType = UserGuideType.REGIONKEYFRAMESTART;
                editorManager.isInUserGuideStatus = true;
            }

            function onEnterKfEfModel(){
                mask.adjustWindow();
                mask.visible = true;
                mask.userGuideType = UserGuideType.TRANSITION_EFFECT;
                //kfEffectGuide.visible = true;
                editorManager.isInUserGuideStatus = true;
            }

            // AC206黑框裁切指引
            function onEnterCropFrameGuide(){
                mask.adjustWindow();
                mask.visible = true;
                mask.userGuideType = UserGuideType.FRAMECROP;
                editorManager.isInUserGuideStatus = true;
            }

            function onLocationNotify(success, location) {
                // 首次检测国内外版本，如果是国内的话，就直接触发更新上报状态
                productLoader.active = true
                if (success && location === "CN") {
                    productLoader.item.updateCbState(true)
                }
                else if(success && locationManager.isEuropeanUnion(location)){
                    productLoader.item.updateCbState(false)
                } else {
                    // 首次检测，如果是国外或无网，则触发弹框，并且弹框是一次性的
                    productLoader.item.open()
                }
            }
        }
    }

    // Loader 用于动态加载 UserGuideMask 组件
    Loader {
        id: userGuideMaskLoader
        anchors.fill: parent
    }

    Connections {
        target: appbar

        function onTabChanged(index) {
            if (index === -1) {
                stackLayout.currentIndex = 0
                globalSignal.deviceSelected(
                            deviceListViewModel.getDeviceNameByIndex(
                                deviceListViewModel.currentIndex))
            } else if (editorCompleted) {
                // 需要编辑器加载完成才可以
                stackLayout.currentIndex = 1
                if (!CommonUtils.isNull(materialPanel)) {
                    globalSignal.deviceSelected(materialPanel.getMediaTabSelectedDeviceName())
                }
            }
        }

        function onOpenTaskQueue() {
            if (!taskQueuePopupLoader.active) {
                taskQueuePopupLoader.active = true
            }
            if (taskQueuePopupLoader.item) {
                taskQueuePopupLoader.item.open()
            }
            // 打开任务队列时清除瞬态导出完成红点（用户已知悉导出任务）
            appbar.clearFinishImage()
        }
    }

    // 任务队列弹窗（由 AppBar.exportListButton 触发）
    Loader {
        id: taskQueuePopupLoader
        active: false
        sourceComponent: Component {
            TaskQueuePopup {
                vm: appbar.taskQueueViewModel
                onNavigateToCloudAlbumAsset: (fileName) => {
                    homeView.navigateToCloudAlbumAsset(fileName);
                }
            }
        }
    }

    Connections {
        target: cloudAlbumFeatureFlags

        function onEnableChanged() {
            if (!cloudAlbumFeatureFlags.enable && taskQueuePopupLoader.item) {
                taskQueuePopupLoader.item.close()
            }
        }
    }

    // 灰度不可用（如运行中紧急停用）时同样收起云相册任务队列弹窗
    Connections {
        target: CloudAlbumManager

        function onGrayCloudAlbumAvailableChanged() {
            if (!CloudAlbumManager.grayCloudAlbumAvailable && taskQueuePopupLoader.item) {
                taskQueuePopupLoader.item.close()
            }
        }

        // 协议同意态失效（登出/换号）时收起云相册任务队列弹窗
        function onCloudAlbumAgreementAcceptedChanged() {
            if (!CloudAlbumManager.cloudAlbumAgreementAccepted && taskQueuePopupLoader.item) {
                taskQueuePopupLoader.item.close()
            }
        }
    }

    Component {
        id: menuBarComponent
        AppMenuBar {
            id:macMenuBar
        }
    }
    // 使用 Loader 动态加载组件
    Loader {
        id: menuLoader
        asynchronous: editorABConfig.asyncLoadComponent
        // 不设宽高，等待 item 加载后自动撑开
        sourceComponent: CommonUtils.isWindows() ? null : menuBarComponent
    }
    MenuBarPopupLayers {
        id: macMenuBarLayers
        anchors.fill: parent
        Connections {
            target: menuLoader.item
            function onItemClicked(page, item) {
                // topbar第一个选项的第三个item，代表检测升级
                if (page === 0 && item === 2) {
                    Updater.checkUpdateAvailable(false);
                    return;
                }

                macMenuBarLayers.showPopLayer(page, item)
            }
        }
    }

    ProjectStateController {
        id: projectStateController
    }

    // Toast
    CloudAlbumToastHost {
        id: cloudAlbumToastHost
        anchors.fill: parent
        visible: !(stackLayout.currentIndex === 0 && homeView.isCloudAlbumVisible)
    }

    LightToastManager {
        id: toast
        Connections {
            target: globalSignal
            function onToast(msg, panelName) {
                console.log("[CloudAlbumToast] Main received",
                            "panel=" + panelName,
                            "stackIndex=" + stackLayout.currentIndex,
                            "isCloudAlbumVisible=" + homeView.isCloudAlbumVisible,
                            "message=" + msg)
                if (panelName === "cloudAlbum" && stackLayout.currentIndex === 0 && homeView.isCloudAlbumVisible) {
                    console.log("[CloudAlbumToast] Main skipped: CloudAlbumView handles toast")
                    return;
                }
                if (panelName === "cloudAlbum") {
                    console.log("[CloudAlbumToast] Main routed to CloudAlbumToastHost")
                    return;
                }
                console.log("[CloudAlbumToast] Main shows global toast")
                toast.showToast(msg, panelName)
            }
        }
    }

    Loader {
        id: notificationTipsLoader
        active: false
        
        // 添加卸载定时器
        property Timer unloadTimer: Timer {
            interval: 100  // 延迟100ms卸载，确保动画完成
            onTriggered: notificationTipsLoader.active = false
        }
        
        sourceComponent: Component {
            BaseNotificationTips {
                id: notificationTips
                parent: Overlay.overlay
                width: 200
                text: qsTr("pccut_editor_fail_warn_2")
                arrowLeftMargin: width / 2 + 10
                arrowPosition: 0
                visible: true
                z: 999

                property real targetX: 0
                property real targetY: 0

                x: targetX - width / 2
                y: targetY - height
                
                // 如果有淡出动画，在动画完成后触发卸载
                onVisibleChanged: {
                    if (!visible && notificationTipsLoader.active) {
                        notificationTipsLoader.unloadTimer.start();
                    }
                }
            }
        }
    }

    Connections {
        target: globalSignal

        function onShowComposeFailToast(x, y, text) {
            notificationTipsLoader.unloadTimer.stop();  // 停止可能在进行的卸载
            notificationTipsLoader.active = true;
            
            Qt.callLater(function() {
                if (notificationTipsLoader.item) {
                    var tips = notificationTipsLoader.item;
                    tips.targetX = x;
                    tips.targetY = y;
                    tips.text = text;
                }
            });
        }

        function onHideComposeFailToast() {
            if (notificationTipsLoader.item) {
                notificationTipsLoader.item.visible = false;
                // visible变化会触发onVisibleChanged，然后启动卸载定时器
            }
        }
    }
    
    // 导出
    Loader {
        id: composeLoader
        // 默认不加载
        active: false
        anchors.fill:parent
        sourceComponent: MacComposePanel {
        }
    }

    Loader {
        id: productLoader
        active: false
        anchors.fill:parent
        sourceComponent: ProductImproveScheme {
            id: productImporveScheme
        }
    }

    Loader {
        id: resolutionSettingPanel
        active: editorABConfig.asyncLoadComponent===false?true:false
        sourceComponent:
        // 分辨率选择
        ResolutionSettingPanel {

        }
    }
    Loader {
        id: frameRateSettingPanel
        active: editorABConfig.asyncLoadComponent===false?true:false
        sourceComponent:
        // 帧率选择
        FrameRateSettingPanel {

        }
    }

    Loader {
        id: bitrateSettingPanel
        active: editorABConfig.asyncLoadComponent===false?true:false
        sourceComponent:
        // 码率选择
        BitrateSettingPanel {

        }
    }

    onClosing: event => {
        event.accepted = false; // 暂时阻止窗口关闭
        appbar.beforeCloseListener();
    }

    AppBar {
        id: appbar
        objectName: "appbar"
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 34
        opacity: lightWindow.isPlayerFullScreen ? 0 : 1
        isCloudAlbumVisible: homeView.isCloudAlbumVisible
    }

    Component {
        id: editorUIComponent
        LightClipRectangle {
            anchors {
                fill: parent
                bottomMargin: 8
                leftMargin: 8
                rightMargin: 8
            }

            radius: [8, 8, 8, 8]
            color: CommonUtils.isWindows() ? Colors.color_content_area_background : Colors.transparent
            Connections {
                target: globalWidget

                function onWidgetSourceChanged(isShow) {
                    if (isShow === true) {
                        if (!CommonUtils.isNull(mainPanel)) {
                            mainPanel.enabled = false
                        }
                    } else {
                        ShortcutObserver.switchDefaultAction()
                        if (!CommonUtils.isNull(mainPanel)) {
                            mainPanel.enabled = true
                        }
                    }
                }
            }

            SplitView {
                id: content

                // 上层区域最小高度（与 topSplitView.SplitView.minimumHeight 一致）
                readonly property real topMinHeight: 427
                // 轨道区域初始和最小高度
                readonly property real tractorInitialHeight: 240
                readonly property real tractorMinHeight: 240

                Behavior on width { enabled: false }
                Behavior on height { enabled: false }
                anchors.fill: parent
                orientation: Qt.Vertical

                handle: Rectangle {
                    implicitHeight: 1
                    color: Colors.color_141414
                    containmentMask: Item {
                        y: -4
                        height: 9
                        width: content.width
                    }
                }

                SplitView {
                    id: topSplitView

                    Behavior on width { enabled: false }
                    Behavior on height { enabled: false }

                    SplitView.minimumHeight: content.topMinHeight
                    SplitView.fillHeight: true
                    orientation: Qt.Horizontal
                    // 素材面板
                    Item {
                        id : materialPanelItem
                        SplitView.preferredWidth: 428
                        SplitView.minimumWidth: 400

                        MaterialPanel {
                            id: materialPanel
                            objectName: actionableItemName.materialPanel
                            // onMediaImport: {}
                            Component.onCompleted: {
                                lightWindow.materialPanel = this
                            }
                        }
                    }

                    //播放器面板
                    Item {
                        id: playerPanelItem
                        objectName: "PlayerPanel"
                        SplitView.minimumWidth: 556
                        SplitView.fillWidth: true

                        PlayerPanel {
                            id: playerPanel
                            Component.onCompleted: {
                                lightWindow.playerPanel = this
                            }
                        }
                    }
                    //设置面板
                    Item {
                        id: rightPanelItem
                        readonly property real defaultWidth: 280
                        readonly property real minWidth: 280   // 属性面板最小宽度：满足色轮两列完整显示
                        property real prevSplitWidth: 0
                        SplitView.minimumWidth: minWidth
                        SplitView.maximumWidth: 320
                        SplitView.preferredWidth: defaultWidth
                        //界面显示的时候，再加载具体设置面板
                        SettingPanel {
                            id: settingPanel
                            objectName: actionableItemName.settingPanel
                            Component.onCompleted: {
                                lightWindow.settingPanel = this
                            }
                        }

                        Connections {
                            target: topSplitView
                            function onWidthChanged() {
                                var w = topSplitView.width
                                var delta = (rightPanelItem.prevSplitWidth > 0)
                                            ? (w - rightPanelItem.prevSplitWidth) : 0
                                rightPanelItem.prevSplitWidth = w
                                var currentPref = rightPanelItem.SplitView.preferredWidth
                                if (delta > 0 && currentPref < rightPanelItem.defaultWidth) {
                                    // 窗口变宽：优先恢复右侧面板到 280，多余空间由播放器(fillWidth)吸收
                                    rightPanelItem.SplitView.preferredWidth = Math.min(currentPref + delta, rightPanelItem.defaultWidth)
                                } else if (delta < 0) {
                                    // 窗口变窄：播放器优先压缩，到极限后再压缩右侧面板
                                    var available = w - materialPanelItem.width - playerPanelItem.SplitView.minimumWidth
                                    if (available < currentPref) {
                                        rightPanelItem.SplitView.preferredWidth = Math.max(rightPanelItem.minWidth, available)
                                    }
                                }
                            }
                        }
                    }

                    handle: Rectangle {
                        implicitWidth: 1
                        color: Colors.color_141414
                        containmentMask: Item {
                            z: 1
                            x: -4
                            width: 9
                            height: topSplitView.height
                        }
                    }
                }
                // 轨道
                Item {
                    id: tractorItem
                    objectName: "tractor"
                    SplitView.minimumHeight: content.tractorMinHeight
                    SplitView.preferredHeight: content.tractorInitialHeight

                    clip: true
                    TrackDock {
                        id: tracks
                        objectName: actionableItemName.trackDockContentForMultiTrack
                        clip: true

                        Component.onCompleted: {
                            lightWindow.tracks = this
                        }
                    }
                }

                // 在应用启动时或主组件中添加平台特定代码
                Component.onCompleted: {
                    lightWindow.content = content
                }

                // 监听 content 高度变化，按当前比例分配高度
                onHeightChanged: {
                    var totalHeight = content.height
                    var handleHeight = 1  // SplitView 分隔条高度

                    // 获取当前上层和轨道区域的实际高度
                    var currentTopHeight = topSplitView.height
                    var currentTractorHeight = tractorItem.height
                    var currentTotal = currentTopHeight + currentTractorHeight + handleHeight

                    // 如果当前总高度有效，计算当前比例
                    if (currentTotal > 0 && totalHeight > 0) {
                        var topRatio = currentTopHeight / currentTotal
                        var tractorRatio = currentTractorHeight / currentTotal

                        // 按比例分配新高度
                        var availableHeight = totalHeight - handleHeight
                        var newTopHeight = availableHeight * topRatio
                        var newTractorHeight = availableHeight * tractorRatio

                        // 确保不低于最小高度
                        if(newTopHeight < content.topMinHeight){
                            newTopHeight = content.topMinHeight
                        }
                        newTractorHeight = Math.max(content.tractorMinHeight, availableHeight - newTopHeight)

                        // 如果两者最小高度之和超过可用高度，优先保证上层区域
                        if (newTopHeight + newTractorHeight > availableHeight) {
                            newTopHeight = availableHeight - content.tractorMinHeight
                            newTractorHeight = content.tractorMinHeight
                        }

                        // 更新轨道区域高度（topSplitView 使用 fillHeight，会自动填充剩余空间）
                        tractorItem.SplitView.preferredHeight = newTractorHeight
                    }
                }
            }
        }
    }



    Timer {
        id: layoutSyncTimer
        interval: isWindows ? 200 : 0
        repeat: false
        onTriggered: syncLayoutSize()
    }

    // 布局同步函数
    function syncLayoutSize() {
        if (stackLayout) {
            stackLayout.x = 0
            stackLayout.y = 34
            stackLayout.width = lightWindow.width
            stackLayout.height = lightWindow.height - 34;
        }
    }

    // 在窗口大小变化时也同步布局
    onWidthChanged: {
        if(!dragging){
            syncLayoutSize()
        }else{
            layoutSyncTimer.start()
        }
    }
    onHeightChanged: {
        if(!dragging){
            syncLayoutSize()
        }else{
            layoutSyncTimer.start()
        }
    }

    StackLayout {
        id: stackLayout
        currentIndex: 0
        objectName: actionableItemName.mainStackLayout
        opacity: lightWindow.isPlayerFullScreen ? 0 : 1
        Item {
            HomeView {
                id: homeView
                objectName: "homeView"
                anchors {
                    fill: parent
                    leftMargin: 1
                    bottomMargin: 1
                    rightMargin: 1
                }
            }
        }


        Item {
            id: mainPanel

            onParentChanged: {
                // 没有办法监听Loader是什么时候开始load的，因为我们这里的sourceComponent是一开始就设置好的
                // 所以用mainPanel这个Item的初始化来作为editorUILoader加载的起点
                var timestamp = Date.now() - BusinessLogger.getAbandonElapsed();
                BusinessLogger.log(BusinessLog.Stream.APP_LAUNCH, BusinessLog.Events.LOAD_EDITOR_QML, "", timestamp);
            }

            Loader {
                id: editorUILoader
                sourceComponent: editorUIComponent
                // 打开之后启动速度能提升很多，但是目前很多地方的实现依赖qml加载完成
                // 所以安全起见，还是不开启了
                // asynchronous: true
                anchors.fill: parent

                onStatusChanged: {
                    const loadStatus = editorUILoader.status;
                    if (loadStatus === Loader.Ready || loadStatus === Loader.Error) {
                        editorCompleted = true;
                        globalSignal.editorQmlLoadCompleted();
                    }

                }
            }
        }

        Connections {
            target: globalSignal

            function onProjectPreparing(id) {
                console.log("onProjectPreparing, id:", id, "prepare loading open")
                projPrepareLoading.open();
            }

            function onActivedProjectChanged(id) {
                if (id < 0) {
                    return;
                }
                console.log("onActivedProjectChanged, id:", id, "prepare loading close")
                projPrepareLoading.close();
                if (draftManager.markToastUseAgency()) {
                    toast.showToast(qsTr("pccut_player_preview_mode_smooth_tip"), "playerPanel");
                }
            }

            // nova 草稿内核加载完成后色彩空间才可读，HDR 显示器检测在这里做
            function onNovaDraftLoaded(id) {
                if (id < 0) {
                    return;
                }
                projectStateController.checkScreenSupportHdr(lightWindow, false);
            }

            property GpuUpdateHintDialog dialog: null
            property GpuUpdateHintDialog confrim_dialog: null

            function onOpenGpuDriverUpdatePopup(isConfirmDialog) {
                console.log("onOpenGpuDriverUpdatePopup gpuDriverUpdate open isConfirmDialog:",isConfirmDialog)
                if(isConfirmDialog)
                {
                    if (CommonUtils.isNull(confrim_dialog)) {
                        confrim_dialog = Qt.createComponent("qrc:/qml/explorer/GpuUpdateHintDialog.qml").createObject(lightWindow, {
                            "titleText": qsTr("pccut_graphics_upgrade_tip_1"),
                            "contentText": isConfirmDialog?qsTr("pccut_graphics_upgrade_tip_5"):qsTr("pccut_graphics_upgrade_tip_2"),
                            "updatebtnText": qsTr("pccut_graphics_upgrade_tip_switch"),
                            "isConfirmDialog":true})
                    }
                    if (!CommonUtils.isNull(confrim_dialog)) {
                        confrim_dialog.open();
                    }
                }else
                {
                    if (CommonUtils.isNull(dialog)) {
                        dialog = Qt.createComponent("qrc:/qml/explorer/GpuUpdateHintDialog.qml").createObject(lightWindow, {
                            "titleText": qsTr("pccut_graphics_upgrade_tip_1"),
                            "contentText": isConfirmDialog?qsTr("pccut_graphics_upgrade_tip_5"):qsTr("pccut_graphics_upgrade_tip_2"),
                            "updatebtnText": qsTr("pccut_graphics_upgrade_tip_switch"),
                            "isConfirmDialog":isConfirmDialog})
                    }
                    if (!CommonUtils.isNull(dialog)) {
                        dialog.open();
                    }
                }
            }
        }
    }

    WaitingPopup {
        id: projPrepareLoading
        loadingText: qsTr("pccut_loading")

        onOpened: {
            ShortcutObserver.disableAllShortcut(true)
        }
        onClosed: {
            ShortcutObserver.disableAllShortcut(false)
        }
    }

    // 拍摄视角，自拍视角等meta数据
    FetchShotDataBlockLoading {
        id: fetchShotDataBlockLoading
    }

    AnalyzeWaitingPopup{
        id: analyzeWaitingPopup
        onOpened: {
            ShortcutObserver.disableAllShortcut(true)
        }
        onClosed: {
            ShortcutObserver.disableAllShortcut(false)
            analyzeWaitingPopup.segmentProgress = 0
            analyzeWaitingPopup.currentIndex = 1
            analyzeWaitingPopup.totalCount = 0
        }
        onCancelSignal: {
            viewModeAnalyzeController.cancelAnalyze()
        }
    }

    ViewModeAnalyzeController {
        id: viewModeAnalyzeController
    }

    // 替换素材带入全景视角需分析时的进度弹窗(替换可在全景面板未打开时发生，故在此全局驱动)。
    Connections {
        target: viewModeAnalyzeController
        function onReplaceAnalyzeStarted() {
            analyzeWaitingPopup.text = viewModeAnalyzeController.forwardAnalyzeUsesProxy()
                    ? qsTr("pccut_editing_perspective_forward_open_tip")
                    : qsTr("pccut_editing_perspective_forward_open_tip_1")
            analyzeWaitingPopup.open()
        }
        function onReplaceAnalyzeFinished() {
            analyzeWaitingPopup.close()
        }
        function onAnalyzeProgressUpdated(progress) {
            analyzeWaitingPopup.segmentProgress = progress
        }
    }

    GlobalWidget {
        id: globalWidget
        anchors {
            top: stackLayout.top
            bottom: parent.bottom
            left: parent.left
            right: parent.right
            bottomMargin: 8
            leftMargin: 8
            rightMargin: 8
        }
    }

    // 性能提示弹窗，不知道应该放在哪里合适，先放在这里吧
    PerformanceHint {}

    // 应急清理跑完磁盘仍 <1GB 的全局严重不足提示（单实例：已开着就不再弹）
    ConfirmPopup {
        id: diskCriticalPopup
        onlyOneBtn: true
        title: qsTr("pccut_setting_storage_disk_critical_dialog_title")
        text: qsTr("pccut_setting_storage_disk_critical_dialog_desc")
        leftButtonText: qsTr("pccut_common_text_got_it")
    }

    Connections {
        target: emergencyCacheCleaner
        // 确认磁盘 <1GB、即将开始应急清理时提示（磁盘充足则不发 started，不弹）
        function onStarted(willClean) {
            if (willClean) {
                toast.showToast(qsTr("pccut_setting_storage_disk_full_clean_toast"))
            }
        }
        function onCompleted(finalFreeBytes, reachedTarget, didExecute) {
            if (finalFreeBytes >= 0
                    && finalFreeBytes < emergencyCacheCleaner.startThresholdBytes()
                    && !diskCriticalPopup.visible) {
                diskCriticalPopup.open()
            }
        }
    }

    // 云相册灰度紧急停用/恢复提示（单实例：已开着就不再弹）。
    // 正文完全由服务端运营文案决定，没有本地标题，故整段写入 title 槽位并改成正文排版：
    // 12px 常规字重、行高 1.6、多行左对齐——原样式（14px Medium 居中）是给短标题用的，
    // 200 字用那套会变成一堵居中的墙，行首参差没法读。
    ConfirmPopup {
        id: cloudAlbumGrayNoticePopup
        objectName: 'cloudAlbumGrayNoticePopup'
        // 产品约定的文案上限，超出走截断 + hover 看全文
        readonly property int maxChars: 200
        onlyOneBtn: true
        popWidth: 440
        titleFontSize: 12
        titleFontWeight: Font.Normal
        titleLineHeight: 1.6
        // 单行时居中（左对齐会贴着左边显得空），多行才左对齐
        titleHorizontalAlignment: cloudAlbumGrayNoticePopup.titleWrapped
                                  ? Text.AlignLeft : Text.AlignHCenter
        leftButtonText: qsTr("pccut_common_text_got_it")
        leftButtonObjectName: 'cloudAlbumGrayNoticeConfirmButton'
    }

    Connections {
        target: CloudAlbumManager
        // 紧急停用与恢复共用一个弹窗，两者的差异全在服务端下发的文案里
        function onGrayEmergencyNotice(message) {
            // C++ 侧已拦掉空文案，这里再兜一道，避免任何情况下弹出空白框
            if (!message) {
                return
            }
            // 产品约定文案 ≤200 字。服务端一旦违约给了超长文案，弹窗会被撑到顶穿窗口、
            // 按钮挤出可视区，所以这里截断展示，全文挂到 hover tooltip 上不丢信息。
            var full = String(message)
            var overLimit = full.length > cloudAlbumGrayNoticePopup.maxChars
            cloudAlbumGrayNoticePopup.title =
                    overLimit ? full.substring(0, cloudAlbumGrayNoticePopup.maxChars) + "…" : full
            cloudAlbumGrayNoticePopup.titleTooltip = overLimit ? full : ""
            // 守卫用 opened 而非 visible：关闭动画期间 visible 仍为 true，
            // 用 visible 会把用户刚点完确认那一瞬间到达的新提示吞掉
            if (!cloudAlbumGrayNoticePopup.opened) {
                cloudAlbumGrayNoticePopup.open()
            }
        }
    }

    // 一个黑色的蒙层， 当播放器弹框出来的时候， 需要增加蒙层
    Rectangle {
        anchors.fill: parent
        color: Colors.color_000000_50
        radius: 10
        visible: openOperator.showPreview
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            preventStealing: true
            
            // 使用 JavaScript 函数代替信号处理器
            onClicked: function(mouse) {
                mouse.accepted = true
            }
            
            onPressed: function(mouse) {
                mouse.accepted = true
            }
            
            onReleased: function(mouse) {
                mouse.accepted = true
            }
            
            onDoubleClicked: function(mouse) {
                mouse.accepted = true
            }
            
            onWheel: function(wheel) {
                wheel.accepted = true
            }
        }
    }

    // 登录弹窗浮出时,主界面盖半透明黑蒙皮(rgba(0,0,0,0.5))。
    // 视觉/模式与上方"播放器预览蒙层"一致:蒙皮在主窗口内、贴合圆角窗(radius:10);
    // 登录弹窗为 modal,浮在 Overlay 层其上并吃掉输入,故此处纯视觉、无需 MouseArea。
    Rectangle {
        anchors.fill: parent
        color: Colors.color_000000_50
        radius: 10
        visible: appbar.loginPopupVisible
    }

    Component.onCompleted: {
        globalSignal.mainQmlOnCompleted()
        locationManager.checkLocationForProductImprove()
    }

    Component.onDestruction: {
    }

    onDraggingChanged: {
        if(dragging && isWindows && playerPanel.controller.playing){
            playerPanel.controller.pause();
        }
    }
	
	// 恢复草稿
    DraftRecoverManager {
        id: draftRecoverManager
    }

    UIComponentGalleryManager { id: galleryDebugManager }
    property alias galleryDebugManager: galleryDebugManager
}
