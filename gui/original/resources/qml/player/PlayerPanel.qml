import Config 1.0
import Controls 1.0
import MKDisplayView 1.0
import QtMultimedia 5.15
import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.15
import QtQuick.Window 2.15
import Qt5Compat.GraphicalEffects
import ShortcutAction 1.0
import PanoramaController 1.0
import MKPlayerController 1.0

import TrackingManager 1.0
import QPlayType 1.0
import QPanoramaLimit 1.0
import HdrController 1.0
import VideoConfig 1.0
import Nova 1.0

import "./screen_shot"


Item {
    id: playerPanel

    //默认点击打开
    property string refUseMethod:     "guides"
    property bool refShowLine:        false
    property bool refShowGrid:        false
    property bool refShowCenterPoint: false
    property bool refShowCrossLine:   false
    property bool refShowDiagonal:    false
    property bool refShowGoldenRatio: false
    readonly property var refLineConfig: ({
        refLine:     { key: "referenceLine/refLine",     prop: "refShowLine"            },
        grid:        { key: "referenceLine/grid",        prop: "refShowGrid"        },
        centerPoint: { key: "referenceLine/centerPoint", prop: "refShowCenterPoint" },
        crossLine:   { key: "referenceLine/crossLine",   prop: "refShowCrossLine"   },
        diagonal:    { key: "referenceLine/diagonal",    prop: "refShowDiagonal"    },
        goldenRatio: { key: "referenceLine/goldenRatio", prop: "refShowGoldenRatio" },
    })
    //参考线参数初始化状态,防止读取持久化的数据时误报埋点
    property bool initRefArg: false

    readonly property alias controller: player.controller
    readonly property alias displayView: player.displayView
    readonly property alias playerMainView: player
    property int prioritySetting: 3
    anchors.fill: parent

    property bool isMultiPreviewMode: false
    property real multiViewMaxWidth: 569
    readonly property int multiViewMinWidth: 92
    readonly property int multiViewFullscreenWidth: 201
    readonly property int splitviewMinWidth: 569

    function setColorSpace(colorSpace) {
        hdrController.setColorSpace(colorSpace)
    }

    function setColorDepth(colorDepth) {
        hdrController.setColorDepth(colorDepth)
    }

    function getColorSpaceStr(colorSpace) {
        return hdrController.getColorSpaceStr(colorSpace)
    }

    // ==================================================
    //判断是否正在导出
    property bool isExporting: false
    //标记下是否弹过窗
    property bool stutterPopupShown: false

    Connections {
        target: projectExportEnvManager
        function onExportStarted(draftPath, envId, outPath, context) {
            playerPanel.isExporting = true
        }
        function onExportFinished(draftPath, envId, outPath, success, context) {
            playerPanel.isExporting = false
        }
        function onExportError(draftPath, envId, outPath, errorCode, errorStr, context) {
            playerPanel.isExporting = false
        }
        function onExportCancelled() {
            playerPanel.isExporting = false
        }
    }

    // =========  判断是否有弹窗改变播放器的enabled =========
    property int topPopupCount: 0

    // 弹窗数量变化信号
    Connections {
        target: globalSignal
        function onAddPopupQuantity() {
            topPopupCount++
        }
        function onReducePopupQuantity() {
            topPopupCount--
        }
    }
    Connections {
        target: lightWindow
        onScreenChanged: {
            projectStateController.checkScreenSupportHdr(lightWindow);
            hdrController.checkScreenIsApple()
        }
    }
    // ==================================================

    property var win: Window.window
    property int windowVisibility: win.visibility
    Timer {
        id: raiseTimer
        interval: 400
        running: true
        repeat: false
        
        onTriggered: {
            if (!CommonUtils.isNull(win)) {
                win.raise()
                win.requestActivate()
            }
        }
    }
    
    function getPlayerPosition() {
        var position = UiUtils.getGlobalPosition(displayView)
        return Qt.rect(position.x, position.y, displayView.width, displayView.height)
    }

    function getPlayerControllerPosition() {
        var position = UiUtils.getGlobalPosition(playerController)
        return Qt.rect(position.x, position.y, playerController.width, playerController.height)
    }

    function capture() {
        controller.pause()
        eventTracker.trackEvent("pccut_player_screenshot_click") // 不区分入口
        let jpgName = screenShot.updateDramaSource(player.controller.playedPosition())
        if(jpgName === "-1"){
            //为-1说明当前时间指示器位置无素材
            toast.showToast(qsTr("pccut_player_screenshot_no_fail"), "playerPanel")
            return
        }
        if (jpgName === "") {
            // 之前截图实现不支持多个, 防止手速过快产生异常,在这里加个toast
            toast.showToast(qsTr("pccut_player_screenshot_save"), "playerPanel")
            return
        }
        screenShotPopupLoader.active = true;
        var screenShotPopup = screenShotPopupLoader.item;
        screenShotPopup.exportSuperPath = screenShot.getAvailablePath(lightSetting.get(Instance.key_screen_shot_save_path))
        let isPreView = editorManager.playType !== QPlayType.editor;
        screenShotPopup.isPreViewScreenShot = isPreView;
        screenShotPopup.jpgFileName = jpgName
        screenShotPopup.show()
    }

    //开启参考线勾选状态发生变化时
    onRefShowLineChanged: {

        if (!initRefArg) {
            return
        }

        var functionUsedList = []

        if (playerPanel.refShowGrid)
            functionUsedList.push("Grid Lines")

        if (playerPanel.refShowCenterPoint)
            functionUsedList.push("Center Point")

        if (playerPanel.refShowCrossLine)
            functionUsedList.push("Cross Lines")

        if (playerPanel.refShowDiagonal)
            functionUsedList.push("Diagonal Lines")

        if (playerPanel.refShowGoldenRatio)
            functionUsedList.push("Golden Ratio")

        eventTracker.trackEvent("pccut_player_more_click_grid", {
            "user_method": playerPanel.refUseMethod,
            "is_turnon": playerPanel.refShowLine,
            "function_used": functionUsedList
        })
    }

    //根据参考线的勾选状态，来设置对应的参考线的的可见状态，并保存
    function toggleRef(item) {
        if (!(item.prop in playerPanel)) {
            console.warn("toggleRef: unknown property", item.prop)
            return
        }

        var newVal = !playerPanel[item.prop]
        playerPanel[item.prop] = newVal
        lightSetting.save(item.key, newVal)
    }

    Rectangle {
        id: player_container_root
        objectName:actionableItemName.playerContainerRoot
        anchors.fill: parent
        color: CommonUtils.isWindows() ? Colors.color_content_area_background : Colors.transparent

        Rectangle {
            id: header
            objectName: actionableItemName.mainPlayerHeader
            width: parent.width
            height: 45
            color: Colors.color_title_area_background

            Text {
                id: title

                text: AudioHighlightTaskManager.showProgress ? AudioHighlightTaskManager.processingProgress : qsTr("pccut_player")
                color: Colors.color_EEEEEE
                font.pixelSize: 12

                visible: !stutterTips.visible

                anchors {
                    verticalCenter: parent.verticalCenter
                    left: parent.left
                    leftMargin: 12
                }
            }

            Rectangle{
                id: stutterTips

                property int  draftOpenedCount: draftManager.openedCount
                property string tipsText: "";

                onDraftOpenedCountChanged: {  // 草稿变化后隐藏当前草稿的卡顿提示
                    stutterTips.visible = false;
                    hideTipsPopup();
                }

                width: 180
                height: 16
                anchors {
                    verticalCenter: parent.verticalCenter
                    left: parent.left
                    leftMargin: 12
                }
                color: Colors.transparent
                visible: false

                Text {
                    id: tips
                    width: parent.width
                    elide: Text.ElideRight
                    text: stutterTips.tipsText
                    color: Colors.color_EEEEEE
                    font.pixelSize: 12

                    anchors {
                        verticalCenter: parent.verticalCenter
                        left: parent.left
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.ArrowCursor
                        LightToolTip {
                            visible: parent.containsMouse && tips.implicitWidth > tips.width
                            tip: tips.text
                            z: 200
                        }
                    }
                }

                //暂时注释掉
                // MouseArea {
                //     anchors.fill: tips
                //     onClicked: {
                //         if(btn.popupShow){
                //             stutterTips.hideTipsPopup();
                //         }else{
                //             stutterTips.showTipsPopup()
                //         }
                //     }
                //     cursorShape: Qt.PointingHandCursor
                // }

                Image{
                    id: btn
                    visible: false
                    property bool popupShow: false
                    width: 16
                    height: 16
                    anchors{
                        verticalCenter: parent.verticalCenter
                        left: tips.right
                        leftMargin: 2
                    }
                    source: btn.popupShow ? "qrc:/icons/ic_triangle_up.svg" : "qrc:/icons/ic_triangle_down.svg"
                    sourceSize: Qt.size(width, height)

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if(btn.popupShow){
                                stutterTips.hideTipsPopup();
                            }else{
                                stutterTips.showTipsPopup()
                            }
                        }
                        cursorShape: Qt.PointingHandCursor
                    }
                }

                function showTipsPopup(){
                    tipPopup.y = btn.y + btn.height + 4
                    tipPopup.open()
                    btn.popupShow = true;
                }

                function hideTipsPopup(){
                    tipPopup.close();
                    btn.popupShow = false;
                }

                Popup {
                    id:tipPopup
                    width: 236
                    height: tipText.height + 24
                    modal: false
                    focus: true
                    closePolicy: Popup.CloseOnPressOutsideParent

                    onClosed: {
                        btn.popupShow = false;

                        }

                    Text {
                        id: tipText
                        text: stutterTips.tipsText
                        font.pixelSize: 11
                        color: Colors.color_EEEEEE
                        wrapMode: Text.WordWrap
                        anchors{
                            top: parent.top
                            topMargin: 12
                            left: parent.left
                            leftMargin: 13
                            right: parent.right
                            rightMargin: 6
                        }
                        horizontalAlignment: Text.AlignLeft
                        verticalAlignment: Text.AlignVCenter
                    }

                    background: Rectangle{
                        radius: 4
                        border.width: 1
                        border.color: "#454649"
                        color: "#2F3032"
                    }
                    leftPadding: 0
                    topPadding: 0
                }
            }

            PlayerPreviewMode {
                id: previewMode
                visible: (controller.totalFrames > 0
                         && editorManager.playType === QPlayType.editor) || editorManager.playType === QPlayType.preview
                anchors.centerIn: parent

                onTypeChanged: {
                    logger.d("[PlayerPanel] previewType: " + type)

                    controller.pause()

                    isMultiPreviewMode = (type === PlayerPreviewMode.Type.Multi)

                    playerMultiView.setPreviewMode(type)

                    if (type === PlayerPreviewMode.Type.Multi) {
                        // 计算最大宽度和初始宽度
                        multiViewMaxWidth = (splitView.height - (playerMultiView.itemSpace * 3)) / 4 / 9 * 16
                        // 单视角→多视角：启用滑入动画
                        splitViewRightContainer.animatingModeSwitch = true
                        splitViewRightContainer.splitViewWidth = (multiViewMaxWidth + multiViewMinWidth) * 0.618
                    } else {
                        // 多视角→单视角：直接收缩，无动画
                        splitViewRightContainer.splitViewWidth = 0
                    }
                }
            }

            Connections {
                target: playerMultiView
                // 草稿切换/加载完成后回灌持久化的预览模式（复用 onTypeChanged 全套接线）
                function onPreviewModeChanged() {
                    previewMode.type = playerMultiView.previewMode
                }
            }

            Connections {
                target: previewMode
                // 可见性翻转（转场/素材预览返回编辑态）时重读草稿值；此路径无内核消息
                function onVisibleChanged() {
                    if (previewMode.visible) playerMultiView.restorePreviewMode()
                }
            }

            Connections {
                target: editorManager
                function onPlayTypeChanged() {
                    // 非编辑/素材预览模式时，切换到单视角（不持久化，退出后自动恢复）
                    if (editorManager.playType !== QPlayType.editor && editorManager.playType !== QPlayType.preview) {
                        if (previewMode.type !== PlayerPreviewMode.Type.Single) {
                            previewMode.type = PlayerPreviewMode.Type.Single
                        }
                    }
                }
            }

            // 调试用, 显示当前画面的debug 信息
            Text {
                text: controller.debugText
                visible: editorManager.debugStatus
                color: "#C7C7C7"
                font.pixelSize: 12
                anchors {
                    verticalCenter: parent.verticalCenter
                    left: title.right
                    leftMargin: 25
                }
            }

            IconButton {
                id: refLineBtn
                width: 20
                height: 20
                externalOpacity: true
                anchors {
                    right: parent.right
                    rightMargin: 12
                    topMargin: 13
                    bottomMargin: 12
                    verticalCenter: parent.verticalCenter
                }

                iconSource: (refLineMenuLoader.active && refLineMenuLoader.item && refLineMenuLoader.item.visible)
                        ? "qrc:/icons/player/ic_referenceline_menu_pressed.svg"
                        : "qrc:/icons/player/ic_referenceline_menu.svg"
                hoverIconSource: "qrc:/icons/player/ic_referenceline_menu_pressed.svg"
                pressedIconSource: "qrc:/icons/player/ic_referenceline_menu_pressed.svg"

                normalColor: Colors.transparent
                hoverColor: Colors.transparent
                pressedColor: Colors.transparent
                onClicked: {
                    eventTracker.trackEvent("pccut_player_more_click")
                    refLineMenuLoader.active = true
                    refLineMenuLoader.item.popup(refLineBtn.x + refLineBtn.width - refLineMenuLoader.item.implicitWidth,
                                    refLineBtn.y + refLineBtn.height + 8)
                }
            }

            Loader {
                id: refLineMenuLoader
                active: false
                sourceComponent: LightMenu {
                    showCheckable: true
                    menuWidth: 155
                    menuRadius: 8
                    itemRadius: 4
                    itemHighlighted: Colors.color_2F3032
                    itemFontSize: 11
                    disabledCheckIconSource:"qrc:/icons/WindowsIcon/icon_select_disable.svg"
                    disableEnableTextColor: Colors.color_666666
                    subItemsEnabled: playerPanel.refShowLine
                    iconBtnMargins: 0

                    //IconButton 距离菜单左侧边距
                    checkBtnLeftMargin: 12
                    //菜单文本 距离菜单栏左侧边距
                    contentTextLeftMargin: 36
                    //content距离菜单栏右侧边距
                    contentRightMargin: 12

                    //启用参考线
                    Action {
                        text: qsTr("pccut_reference_line")
                        checkable: true
                        checked:  playerPanel.refShowLine
                        shortcut: ShortcutConfig.actionTips(ShortcutAction.REFERENCE_LINE)
                        onTriggered: {
                            playerPanel.refUseMethod = "guides"
                            toggleRef(refLineConfig.refLine)
                        }
                    }

                    MenuSeparator {
                        leftPadding: 4
                        rightPadding: 4
                        contentItem: Rectangle {
                            implicitHeight: 1
                            color: Colors.color_2F3032
                        }
                    }

                    //网格线
                    Action {
                        text: qsTr("pccut_grid_line")
                        checkable: true
                        checked: playerPanel.refShowGrid
                        onTriggered: toggleRef(refLineConfig.grid)
                    }
                    //中心点
                    Action {
                        text: qsTr("pccut_center_point")
                        checkable: true
                        checked: playerPanel.refShowCenterPoint
                        onTriggered: toggleRef(refLineConfig.centerPoint)
                    }
                    //十字线
                    Action {
                        text: qsTr("pccut_cross_line")
                        checkable: true
                        checked: playerPanel.refShowCrossLine
                        onTriggered: toggleRef(refLineConfig.crossLine)
                    }
                    //对角线
                    Action {
                        text: qsTr("pccut_diagonal_line")
                        checkable: true
                        checked: playerPanel.refShowDiagonal
                        onTriggered: toggleRef(refLineConfig.diagonal)
                    }
                    // //黄金分割线,暂时注释掉,后续可能会打开
                    // Action {
                    //     text: qsTr("pccut_grid_golden")
                    //     checkable: true
                    //     checked:  playerPanel.refShowGoldenRatio
                    //     onTriggered: toggleRef(refLineConfig.goldenRatio)
                    // }
                }
            }
        }

        Rectangle {
            id: header_divider
            width: parent.width
            height: 1
            color: Colors.color_141414
            anchors {
                top: header.bottom
                left: parent.left
            }
        }

        HdrController {
            id: hdrController
        }

        PanoramaController {
            id: panoramaController
        }

        PanoramaKeyframeOperationViewModel {
            id: panoKfOpVm
        }

        PlayerController {
            id: playerController
            enabled: controller.totalFrames > 0
            player: controller
            onFullscreenClicked: {
                // 点击播放器下面的全屏按钮
                if(enabled){
                    player_container_root.callFullScreen(true)
                    eventTracker.trackEvent("pccut_player_fullscreen_click", {"use_method": "edit_page"})
                }
            }
            onCaptureClicked: {
                capture()
            }

            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }

            CShortcut {
                action: ShortcutAction.SCREEN_SHOT
                onActivated: {
                    // 首页点击快捷键 不要响应
                    if (!playerPanel.visible) {
                        return;
                    }
                    capture()
                }
            }
        }

        Rectangle {
            id: player_container
            objectName: actionableItemName.playerContainer
            anchors {
                left: parent.left
                top: header_divider.bottom
                right: parent.right
                bottom: playerController.top
            }
            color: CommonUtils.isWindows() ? Colors.color_content_area_background : Colors.transparent

            state: "normal"
            onStateChanged: {
                lightWindow.isPlayerFullScreen = "fullScreen" === state;
            }

            states: [
                State {
                    name: "fullScreen"

                    PropertyChanges {
                        target: splitViewRightContainer
                        splitViewWidth: isMultiPreviewMode ? multiViewFullscreenWidth : 0
                        z: player.z + 1
                    }
                    ParentChange {
                        target: splitViewRightContainer
                        parent: player_container
                    }

                    PropertyChanges {
                        target: playerMultiView
                        width: isMultiPreviewMode ? multiViewFullscreenWidth : 0
                        itemSpace: 8
                    }

                    PropertyChanges {
                        target: player_container
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 0
                    }
                    
                    ParentChange {
                        target: player_container
                        parent: UiUtils.getTopParent(player_container)
                    }

                    PropertyChanges {
                        target: player
                        anchors.fill: parent
                    }
                },
                State {
                    name: "normal"
                    ParentChange {
                        target: player_container
                        parent: player_container_root
                    }
                    PropertyChanges {
                        target: player_container
                        anchors.left: parent.left
                        anchors.top: header_divider.bottom
                        anchors.right: parent.right
                        anchors.bottom: playerController.top
                    }
                    ParentChange {
                        target: splitViewRightContainer
                        parent: splitView
                    }
                    PropertyChanges {
                        target: splitViewRightContainer
                        anchors.right: undefined
                        anchors.verticalCenter: undefined
                    }
                    PropertyChanges {
                        target: playerMultiView
                        itemSpace: 4
                    }
                }
            ]

            Connections{
                target: videoStutterDetector
                function onShowStutterTips(isOpenAgency, isLocalMedia, isShowPopup){                    
                    //正在TK时不弹窗,如果isShowPopup为true时先记录下来,等到TK结束再重新弹
                    if (playerController.isTracking) {
                        if (isShowPopup)
                            playerPanel.stutterPopupShown = false;
                        return
                    }
                    
                    //只要检测到卡顿，没有开启流畅模式，就在清晰度处提示切换清晰度
                    if (!editorManager.useMaterialProxy && isShowPopup) {
                        //建议开启流畅模式
                        playerController.showStutterBubble(qsTr("pccut_player_lag_tip_1"));
                        stutterTips.visible = false;
                        playerPanel.stutterPopupShown = true;
                    }else if (editorManager.useMaterialProxy && playerPanel.isExporting) {
                        //如果是正在导出
                        stutterTips.tipsText = qsTr("pccut_player_lag_tip_4");
                        stutterTips.visible = true;
                    }else if (editorManager.useMaterialProxy && isLocalMedia === 0) {
                        //如果开启了流畅模式，并且不是本地文件，提示将文件拷贝到本地
                        stutterTips.tipsText = qsTr("pccut_player_lag_tip_2");
                        stutterTips.visible = true;
                    }else if (editorManager.useMaterialProxy && isLocalMedia === 1) {
                        //如果开启了流畅模式，并且是本地文件，提示性能不足
                        stutterTips.tipsText = qsTr("pccut_player_lag_tip_3");
                        stutterTips.visible = true;
                    }else {
                        stutterTips.visible = false;
                    }
                }

                function onHideStutterTips() {
                    stutterTips.visible = false;
                    stutterTips.hideTipsPopup();
                    playerController.hideStutterBubble();
                }
            }

            Connections{
                target: playerController
                function onTogglePlayState(start){
                    if(start){
                        videoStutterDetector.startDetect();
                    }else{
                        videoStutterDetector.stopDetect();
                    }
                    if (!start) {
                        editorManager.trackPauseClickEventAsync("edit_page")
                    } else {
                        var clarity = PreviewQualityViewModel.useSuperHD ? "UHD" : (editorManager.useMaterialProxy ? "SD" : "HD");
                        var viewType = isMultiPreviewMode ? "preview_multiple" : "preview_single";
                        editorManager.trackPlayClickEventAsync(clarity, viewType);
                    }
                }
            }



            // 播放区域，播放器主屏+多视角小窗口
            SplitView {
                id: splitView
                visible: controller.totalFrames > 0
                Layout.fillWidth: true
                Layout.fillHeight: true
                orientation: Qt.Horizontal
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                }

                onHeightChanged: {
                    if (!isMultiPreviewMode || height <= 0) {
                        return
                    }
                    // 全屏时 splitViewRightContainer 已脱离 SplitView，跳过整个计算，避免 multiViewMaxWidth 被全屏尺寸污染
                    if (player_container.state === "fullScreen") {
                        return
                    }
                    var oldMaxWidth = multiViewMaxWidth
                    multiViewMaxWidth = (height - (playerMultiView.itemSpace * 3)) / 4 / 9 * 16
                    // 之前的 maxWidth 无效（height 为负数导致），用标准公式重新初始化
                    if (oldMaxWidth <= 0) {
                        splitViewRightContainer.splitViewWidth = (multiViewMaxWidth + multiViewMinWidth) * 0.618
                    } else if (!animation.running && splitViewRightContainer.splitViewWidth > 0) {
                        // 正常按比例缩放，保持用户手动拖拽的比例
                        var ratio = splitViewRightContainer.splitViewWidth / oldMaxWidth
                        splitViewRightContainer.splitViewWidth = Math.max(multiViewMinWidth, Math.min(multiViewMaxWidth, multiViewMaxWidth * ratio))
                    }
                }

                // SplitView分隔条
                handle: Component {
                    Rectangle {
                        implicitWidth: 8
                        visible: isMultiPreviewMode
                        color: Colors.color_transparent

                        Row {
                            anchors.centerIn: parent
                            width: 3
                            height: 12
                            spacing: 1

                            Repeater {
                                model: 2
                                Rectangle {
                                    width: 1
                                    height: 12
                                    radius: 0.5
                                    color: Colors.color_37383A
                                }
                            }
                        }
                    }
                }

                // 全景播放器
                PanoramaPlayerView {
                    id: player
                    SplitView.fillWidth: true
                    height: parent.height
                    // 在快速拖拽窗口的情况下, 会响应到全景手势, 进而一些其他的UI不会响应鼠标的操作, 很奇怪
                    enabled: lightWindow.topPopupCount <= 0 && controller.totalFrames > 0
                    playerHandleGesture: editorManager.playType !== QPlayType.editor
                    // 云相册边下边播临时预览时显示缓冲转圈（非 streaming 恒 false，无副作用）
                    bufferingActive: editorManager.bufferingActive
                    highlightViewUpdateAlertVisible: player.controller.highlightViewUpdateAlertVisible
                    referenceLineLayer.showRef: playerPanel.refShowLine
                    referenceLineLayer.showGrid: playerPanel.refShowGrid
                    referenceLineLayer.showCenterPoint: playerPanel.refShowCenterPoint
                    referenceLineLayer.showCrossLine: playerPanel.refShowCrossLine
                    referenceLineLayer.showDiagonal: playerPanel.refShowDiagonal
                    referenceLineLayer.showGoldenRatio: playerPanel.refShowGoldenRatio
                    isFullScreen: player_container.state === "fullScreen"

                    onWidthChanged: {
                        if (width > 0 && height > 0) {
                            canvasDataSaver.updateWindowSize(width, height)
                        }
                        logger.d("[multiview] splitView.player onWidthChanged: height=" + height + ", width=" + width)
                    }

                    onHeightChanged: {
                        if (width > 0 && height > 0) {
                            canvasDataSaver.updateWindowSize(width, height)
                        }
                        logger.d("[multiview] splitView.player onHeightChanged: height=" + height + ", width=" + width)
                    }

                    property bool isPlaying: player.controller.playing

                    onHighlightViewUpdateAlertCancel: {
                        player.controller.restoreGestureStartView()
                    }

                    onHighlightViewUpdateAlertConfirm: {
                        player.controller.confirmGestureOffset()
                    }

                    onIsPlayingChanged: {
                        if(!isPlaying){  // 主要为了补充播放到片尾之后自动暂停的case
                            videoStutterDetector.stopDetect();
                        }else{
                            videoStutterDetector.startDetect();
                        }
                    }

                    Connections {
                        target: editorManager
                        // 刷新时长
                        function onTotalTimebaseChanged() {
                            player.controller.updateTotalFrames();
                        }
                        // 刷新播放源
                        function onPlaySourceChanged(dramaSource, seekPosition) {
                            player.controller.updateDramaSource(dramaSource, seekPosition, true);
                            // 这里只是销毁 QVariant<MKDramaSourcePtr> 不会对 dramaSource产生影响, 如果不destroy会产生内存泄漏
                            // 按照目前的理解这里先调用 destroy 等以后有好的方式再修改 TODO: Fread
                            dramaSource.destroy();
                        }
                    }
                    Connections {
                        target: globalSignal
                        // 刷新画幅
                        function onPlayerProfileSizeChanged(isTracking) {
                            player.displayView.updateSize();
                            if (!isTracking && canvasDataSaver.getModeIndex() !== -1) {
                                globalSignal.updateFov(canvasDataSaver.getCanvasFov(canvasDataSaver.getModeIndex()))
                            }
                        }

                        function onSwitchToHome() {
                            if (player.controller.isPlaying()) {
                                player.controller.pause()
                            }
                        }

                        // 设备预览窗关闭后，把主编辑器的 view 重新注册回内核，
                        // 恢复被设备预览窗 registerPlayerView 抢走的出帧目标
                        function onCloseWindow() {
                            NovaBridge.registerPlayerView(player.displayView);
                        }
                    }
                    Connections {
                        target: player.controller
                        // 给素材快速预览的时候记录视场角
                        function onPanoramaVideoAdjusted(jsonValue) {
                            globalSignal.panoramaPreviewAdjusted(jsonValue);
                        }
                    }
                    Component.onCompleted: {
                        editorManager.attachConsumer(this.displayView);
                        videoStutterDetector.target = this.displayView;
                        NovaBridge.registerPlayerView(this.displayView);
                    }
                    PanoramaViewUpdateAlert {
                        id: viewUpdateAlert
                        anchors.horizontalCenter: parent.displayView.horizontalCenter
                        anchors.top: parent.displayView.top
                        anchors.topMargin: 12
                        visible: panoramaController.viewUpdateAlertVisible
                        onConfirmSignal: {
                            panoramaController.updateOffsetAngel()
                        }
                        onCancelSignal: {
                            panoramaController.cancelUpdateOffsetData()
                        }
                    }
                }

                Item {
                    id: splitViewRightContainer
                    height: parent.height
                    clip: true  // 裁剪超出部分，实现滑入效果

                    // 全屏时的定位：右侧居中
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter

                    property real splitViewWidth: 0
                    property real finalWidth: (multiViewMaxWidth + multiViewMinWidth) * 0.618
                    property bool animatingModeSwitch: false

                    SplitView.preferredWidth: splitViewWidth
                    // 动画运行时 minimumWidth 为 0，允许从 0 开始；动画结束后设为 multiViewMinWidth 防止拖得太小
                    SplitView.minimumWidth: (isMultiPreviewMode && !animation.running) ? multiViewMinWidth : 0
                    SplitView.maximumWidth: isMultiPreviewMode ? multiViewMaxWidth : 0

                    Behavior on SplitView.preferredWidth {
                        enabled: splitViewRightContainer.animatingModeSwitch
                        NumberAnimation {
                            id: animation
                            duration: 300
                            easing.type: Easing.OutCubic
                            onRunningChanged: {
                                if (!running) {
                                    splitViewRightContainer.animatingModeSwitch = false
                                }
                            }
                        }
                    }

                    PlayerMultiView {
                        id: playerMultiView
                        anchors {
                            top: parent.top
                            bottom: parent.bottom
                            left: parent.left  // 固定在左侧，配合 clip 实现滑入
                        }
                        // 动画时固定宽度，动画结束后跟随容器宽度
                        width: animation.running ? splitViewRightContainer.finalWidth : splitViewRightContainer.width
                    }

                    onWidthChanged: {
                        // 只在非动画、非全屏、非太小时同步宽度
                        if (player_container.state === "fullScreen" || width < multiViewMinWidth || animation.running) {
                            return
                        }
                        // 动画结束后，手动拖拽时更新宽度
                        playerMultiView.width = width
                    }
                }

            }

            // 高斯模糊，控件按x、y、width、height和播放控件对齐， 因为在全屏过程中发生了位移，不能用相对布局
            // 默认非全屏， 隐藏
            LightClipRectangle {
                visible: false
                id: blur_player_controller_fullscreen
                x: player_controller_full_screen.x
                y: player_controller_full_screen.y
                width: player_controller_full_screen.width
                height: player_controller_full_screen.height
                radius: [player_controller_full_screen.radius, player_controller_full_screen.radius, player_controller_full_screen.radius, player_controller_full_screen.radius]
                // 高斯模糊的画面数据源设置
                ShaderEffectSource {
                    id: effectsource
                    // 模糊的画面数据来自player
                    sourceItem: player
                    // 画面区域坐标系是player的坐标系，这里要注意，x、y都做了差值计算，是因为player_controller_full_screen.x和player.x 相对于父布局的坐标系
                    sourceRect: Qt.rect(player_controller_full_screen.x - player.x,
                                        player_controller_full_screen.y - player.y,
                                        player_controller_full_screen.width,
                                        player_controller_full_screen.height)
                    live: true
                    smooth: true
                }

                //高斯模糊配置入口
                FastBlur {
                    anchors.fill: parent
                    source: effectsource
                    // 模糊采样半径，越高越模糊
                    radius: 64
                }
            }
            
            MouseArea {
                id: mouseLayer
                anchors.fill: parent
                enabled: player_container.state === "fullScreen"
                visible: enabled // visible是true时会影响上层的光标样式
                z:0
                onPressed: (mouse) => {
                    mouse.accepted = false // 传递按下事件给下层
                }

                onReleased: (mouse) => {
                    mouse.accepted = false // 传递释放事件给下层
                }

            }

            HoverHandler {
                id: fullScreenHoverHandler
                enabled: player_container.state === "fullScreen"
                property point lastPosition: Qt.point(-1, -1)
                property bool updatingController: false

                onEnabledChanged: {
                    lastPosition = Qt.point(-1, -1)
                }

                onHoveredChanged: {
                    if (updatingController) return
                    updatingController = true
                    if (hovered) {
                        fullScreenHoverTimer.start()
                        if (!player_controller_full_screen.hovered) {
                            player_container.showController()
                        }
                    } else {
                        fullScreenHoverTimer.stop()
                        if (!player_controller_full_screen.hovered) {
                            player_container.dismissController()
                        }
                    }
                    updatingController = false
                }

                onPointChanged: {
                    if (updatingController) return
                    if (hovered && (point.position.x !== lastPosition.x || point.position.y !== lastPosition.y)) {
                        lastPosition = point.position
                        updatingController = true
                        if (!fullScreenHoverTimer.running) {
                            fullScreenHoverTimer.start()
                        }
                        player_container.showController()
                        updatingController = false
                    }
                }
            }

            Timer {
                id: fullScreenHoverTimer
                interval: 3000
                repeat: false
                onTriggered: {
                    player_container.dismissController()
                }
            }

            //全屏时的播放控件
            PlayerControllerFullScreen {
                visible: false
                id: player_controller_full_screen

                width: 600
                height: 60
                // x、y绝对值配置， 用player的左上角坐标，加上半个player宽高可以得到player中心坐标，再减去播放控件的半个宽高的到控件左上角坐标
                x: player.x + player.width / 2 - width / 2
                y: player.y + player.height - height - 80
                color: Colors.color_1F2021
                radius: 8
                player: controller

                onVisibleChanged: {
                    logger.d("PlayerControllerFullScreen " + visible);
                    globalSignal.updatePlayerUiState(visible)
                }

                onEscapeFullscreenClicked: {
                    player_container_root.callFullScreen(false);
                }
            }

            // 全屏快捷键节流：首次立即响应，200ms 内的重复按键忽略，防止快速连按导致多视角小窗尺寸异常
            Timer {
                id: fullscreenThrottleTimer
                interval: 200
                repeat: false
            }

            function toggleFullscreen() {
                if (fullscreenThrottleTimer.running) {
                    return
                }
                fullscreenThrottleTimer.restart()
                if (player_container.state !== "fullScreen") {
                    playerController.fullscreenClicked()
                } else {
                    player_controller_full_screen.escapeFullscreenClicked()
                }
            }

            // 监听播放器全屏和退出全屏快捷键
            CShortcut {
                action: ShortcutAction.FULL_SCREEN
                onActivated: {
                    if(draftManager.currentDraft === -1){
                        return
                    }
                    player_container.toggleFullscreen()
                }
            }
            // ~ 键，同上
            CShortcut {
                action: ShortcutAction.SECOND_FULL_SCREEN
                onActivated: {
                    if(draftManager.currentDraft === -1){
                        return
                    }
                    player_container.toggleFullscreen()
                }
            }
            // 监听esc 按键， 全屏下退出全屏
            CShortcut {
                action: ShortcutAction.ESCAPE_FULL_SCREEN
                priority:prioritySetting
                enabled:player_controller_full_screen.visible
                onActivated: {
                    if (player_container.state === "fullScreen") {
                        player_container.toggleFullscreen()
                    }
                }
            }
       
            function dismissController() {
                blur_player_controller_fullscreen.visible = false
                player_controller_full_screen.visible = false
            }
    
            function showController() {
                blur_player_controller_fullscreen.visible = true
                player_controller_full_screen.visible = true
            }
        }

        property var prePlayerState
        property int preAppState: Window.Windowed

        Connections {
            target: lightWindow
            // 监听主窗口的尺寸变化而不监听playerPanel的尺寸是因为
            // 监听playerPanel的话，在全屏/退出全屏时，尺寸会变化两次
            // 一次是主窗口全屏时，playerPanel尺寸变化，一次是playerPanel的state切换到全屏时，尺寸变化
            function onWidthChanged() {
                if (player_container_root.prePlayerState === Window.FullScreen) {
                    player_container_root.prePlayerState = Window.Windowed
                    globalSignal.enableMenuBar(true);
                    ShortcutObserver.switchDefaultAction();
                    player_container.state = "normal";
                    blur_player_controller_fullscreen.visible = false;
                    player_controller_full_screen.visible = false;
                    if (!raiseTimer.running) {
                        raiseTimer.start()
                    }
                }
            }

            function onHeightChanged() {
                if (player_container_root.prePlayerState === Window.FullScreen) {
                    player_container_root.prePlayerState = Window.Windowed
                    globalSignal.enableMenuBar(true);
                    ShortcutObserver.switchDefaultAction();
                    player_container.state = "normal";
                    blur_player_controller_fullscreen.visible = false;
                    player_controller_full_screen.visible = false;
                    if (!raiseTimer.running) {
                        raiseTimer.start()
                    }
                }
            }
        }

        // 全屏后延迟调整多视角小窗布局（等待窗口全屏动画完成后再定位）
        Timer {
            id: fullscreenMultiViewTimer
            interval: 100
            repeat: false
            onTriggered: {
                if (player_container.state === "fullScreen" && isMultiPreviewMode) {
                    logger.d("[multiview] fullscreenTimer: before width set, containerWidth=" + splitViewRightContainer.width
                             + ", splitViewWidth=" + splitViewRightContainer.splitViewWidth)
                    splitViewRightContainer.width = multiViewFullscreenWidth
                    splitViewRightContainer.anchors.rightMargin = 12
                }
                splitViewRightContainer.opacity = 1
                playerMultiView.showExtraViews()
            }
        }

        // 退出全屏后延迟恢复多视角小窗（等待窗口恢复动画完成后再定位，避免尺寸不正确）
        Timer {
            id: exitFullscreenMultiViewTimer
            interval: 100
            repeat: false
            onTriggered: {
                logger.d("[multiview] exitFullscreenTimer: splitViewWidth=" + splitViewRightContainer.splitViewWidth
                         + ", containerWidth=" + splitViewRightContainer.width
                         + ", multiViewMaxWidth=" + multiViewMaxWidth
                         + ", playerMultiView.width=" + playerMultiView.width
                         + ", splitView.height=" + splitView.height
                         + ", player.width=" + player.width)
                splitViewRightContainer.opacity = 1
                if (isMultiPreviewMode && splitView.height > 0) {
                    multiViewMaxWidth = (splitView.height - (playerMultiView.itemSpace * 3)) / 4 / 9 * 16
                    // clamp 到合法范围，保持 state revert 恢复的用户自定义宽度
                    var w = splitViewRightContainer.splitViewWidth
                    if (w < multiViewMinWidth || w > multiViewMaxWidth) {
                        splitViewRightContainer.splitViewWidth = (multiViewMaxWidth + multiViewMinWidth) * 0.618
                    }
                    player.SplitView.fillWidth = false
                    player.SplitView.fillWidth = true
                }
                playerMultiView.showExtraViews()
            }
        }

        // 清理全屏多视角的命令式属性（Timer 设的 rightMargin）
        function cleanupFullscreenMultiView() {
            fullscreenMultiViewTimer.stop()
            exitFullscreenMultiViewTimer.stop()
            splitViewRightContainer.anchors.rightMargin = 0
        }

        function callFullScreen(isShow) {
            logger.d("callFullScreen " + isShow);
            // 全屏切换开始前隐藏多视角小窗，避免过渡期间看到中间态
            if (isMultiPreviewMode) {
                splitViewRightContainer.opacity = 0
                playerMultiView.hideExtraViews()
            }
            player.toggleOverlaySelection(!isShow)
            if (isShow) { // 进入全屏
                player_container.state = "fullScreen"
                globalSignal.enableMenuBar(false);
                ShortcutObserver.switchPreviewPlayerAction();
                player_container.showController()
                // 取消文字选中状态
                // 这三行顺序绝对不能改
                preAppState = Window.window.visibility
                Window.window.showFullScreen()
                prePlayerState = Window.FullScreen
                // --------------------------------
            } else { // 退出全屏
                globalSignal.enableMenuBar(true);
                ShortcutObserver.switchDefaultAction();
                player_container.state = "normal";
                player_container_root.cleanupFullscreenMultiView()
                player_container.dismissController()
                if (preAppState === Window.Maximized) {
                    Window.window.showMaximized()
                    preAppState = Window.Maximized
                } else if (preAppState !== Window.FullScreen) {
                    Window.window.showNormal()
                    preAppState = Window.Windowed // 这里不能用 preAppState = Window.window.visibility 因为visibility存在滞后性，此时还未更新
                }
                prePlayerState = Window.Windowed
                // windows 在全屏状态下, 创建底层的 drama 会有屏幕闪烁, 这里暂时规避一下, 退出全屏保存草稿
                 if (CommonUtils.isWindows()) {
                    editorDraftManager.saveDraft();
                }
            }
            // 全屏切换完成后恢复多视角小窗显示
            if (isMultiPreviewMode) {
                if (isShow) {
                    // 进入全屏：用定时器等待窗口全屏动画完成后再定位
                    fullscreenMultiViewTimer.start()
                } else {
                    // 退出全屏：用定时器等待窗口恢复动画完成后再定位
                    exitFullscreenMultiViewTimer.start()
                }
            }
        }
    }

    Connections {
        target: globalSignal

        // 关键帧激活状态变更
        function onPanoramaKeyframeActiveChanged(trackIndex, clipIndex, position, active) {
            player.flingStop();
        }

        function onKeyframePositionRefreshed() {
        }

        function onTrackingRectCenter(rect, videoSize, needStartTracking, trackingLose, firstResult, sampleFramePtsUs) {
            // TODO 这块需要处理的逻辑是：
            // 1、 根据入参，调用底层接口生成居中参数
            // 2、 然后调用关键帧接口，设置居中参数，让居中
            // 3、 并把生成的居中参数保存下来，这个是头部数据
            if (needStartTracking) {
                panoramaController.startTracking();
            }
            panoramaController.trackingRectCenter(rect, videoSize, trackingLose, firstResult, sampleFramePtsUs)
        }

        function onTrackingEnterAction() {
            panoramaController.enterTrackingMode(true)
        }

        function onTrackingStateChanged(status) {
            if (status === TrackingManager.TK_EXIT) {
                panoramaController.enterTrackingMode(false)
            }
        }

        function onTrackingExitAction() {
            //如果没有出现过弹窗,就先把卡顿检测弹窗标识置为未弹窗
            if (!playerPanel.stutterPopupShown) {
                videoStutterDetector.resetStutterPopup()
            }
        }

        function onPlayerZoom(deltaPercentage, isStart, isEnd) {
            if (isStart) {
                panoramaController.previewGestureStart();
                return;
            } else if (isEnd) {
                panoramaController.previewGestureEnd();
                // 参考手势调节结束的存稿逻辑
                editorDraftManager.saveDraft(false);
                return;
            }
            console.log("onZoom", deltaPercentage, isEnd);
            const fovRange = QPanoramaLimit.FOV_MAX - QPanoramaLimit.FOV_MIN;
            const distortionRange = QPanoramaLimit.DISTORTION_MAX - QPanoramaLimit.DISTORTION_MIN;
            if (fovRange <= 0 || distortionRange <= 0) {
                return;
            }
            const deltaFov = fovRange * deltaPercentage;
            const params = panoramaController.params;
            const fov = params.fov + deltaFov;
            const deltaDistortion = distortionRange * deltaPercentage;
            const distortion = params.distortion + deltaDistortion;
            panoramaController.updatePreviewFov(fov, distortion);
        }
    }

    Connections {
        target: player

        function onGesturingChanged() {
            if (player.playerHandleGesture) {
                return;
            }
            if (player.gesturing) {
                // 传入按下点的画布归一化坐标，让选片按 Z 序命中透出的全景片段
                panoramaController.previewGestureStart(player.playerViewGesture.gestureStartPoint.x,
                                                       player.playerViewGesture.gestureStartPoint.y);
            } else {
                panoramaController.previewGestureEnd();
                // windows 在全屏状态下, 创建底层的 drama 会有屏幕闪烁, 这里暂时规避一下
                if (!(CommonUtils.isWindows() && player_container_root.prePlayerState === Window.FullScreen)) {
                    editorDraftManager.saveDraft(false);
                }
            }
        }

        // 移动/拖拽/调节水平和垂直视角
        function onMove(deltaX, deltaY, fling) {
            // TODO: 目前没考虑profile的尺寸和画幅的选，先以完美填充来调试
            const normalizedDX = deltaX / player.width / 2;
            const normalizedDY = deltaY / player.height / 2;
            const params = panoramaController.params;
            const profileWidth = editorManager.profileWidth();
            const profileHeight = editorManager.profileHeight();
            // TODO: 这里的转换规则是临时写的，具体规则需要后续底层升级后再调整
            const hDegree = params.hDegree + (profileWidth * 2 * normalizedDX / 5);
            const vDegree = params.vDegree + (profileHeight * 2 * normalizedDY / 5);
            panoramaController.updatePreviewViewDegree(hDegree, vDegree);
        }

        // 缩放/调节视场角
        function onZoom(deltaPercentage) {
            const fovRange = QPanoramaLimit.FOV_MAX - QPanoramaLimit.FOV_MIN;
            const distortionRange = QPanoramaLimit.DISTORTION_MAX - QPanoramaLimit.DISTORTION_MIN;
            if (fovRange <= 0 || distortionRange <= 0) {
                return;
            }
            const deltaFov = fovRange * deltaPercentage;
            const params = panoramaController.params;
            const fov = params.fov + deltaFov;
            const deltaDistortion = distortionRange * deltaPercentage;
            const distortion = params.distortion + deltaDistortion;
            panoramaController.updatePreviewFov(fov, distortion);
        }

        // 旋转/调节z轴
        function onRotate(rotation) {
            const params = panoramaController.params;
            const rotationZ = params.rotationZ + rotation;
            panoramaController.updatePreviewRotationZ(rotationZ);
        }
    }
    // 截图的 popup
    Loader {
        id: screenShotPopupLoader
        // 默认不加载
        active: false
        anchors.fill:parent
        sourceComponent: ScreenShotPopup {
            id: screenShotPopup
            property bool isPreViewScreenShot: false
            anchors.centerIn: Overlay.overlay
            onStartShot: (fileSuperPath, fileName, resolution, useCylinder, imageLoadSuccess, isFileNameChange, exportAsDng) => {
                screenShot.screenShot(fileSuperPath, fileName, screenShotPopup.isPreViewScreenShot, resolution, useCylinder,
                                      imageLoadSuccess, isFileNameChange, exportAsDng);
            }
            onClosed: {
                screenShotPopupLoader.active = false;
            }

            onGetCurDispalyFrameSig:{
                var path = player.saveCurDispalyFrame();
                if(path !== ""){
                    onImageSaved(path);
                }else{
                    // 调用截帧保存
                    generatePic();
                }
            }
        }
    }
    Connections {
        target: projectStateController
        function onOpenHdrpopup(paths) {
            hdrMismatchLoader.active = true;
            projectStateController.updatePaths(paths)
        }
    }
    Loader {
        id: hdrMismatchLoader
        active: false
        sourceComponent: ConfirmPopup {
            id: hdrMismatchDialog
            title: qsTr("pccut_hdr_import_hdr_to_sdr_dialog_title")
            text: qsTr("pccut_hdr_import_hdr_to_sdr_dialog_content")
            leftButtonText: qsTr("pccut_hdr_import_hdr_to_sdr_dialog_keep_button")
            rightButtonText: qsTr("pccut_hdr_import_hdr_to_sdr_dialog_switch_button")
            checkBox.text: qsTr("pccut_hdr_import_hdr_to_sdr_dialog_no_reminder_checkbox")
            isCheckBoxVisible: true
            popWidth: 313
            onLeftButtonClicked: {
                projectStateController.isCloseHdrTips = checkBox.checked;
                hdrController.setColorDepth(8)
                hdrController.setColorSpace(VideoConfig.SDR_Rec709)
                projectStateController.reportHdrSwitchEvent(qsTr("pccut_hdr_import_hdr_to_sdr_dialog_keep_button"))
            }
            onRightButtonClicked: {
                projectStateController.isCloseHdrTips = checkBox.checked;
                hdrController.setColorDepth(10)
                hdrController.setColorSpace(VideoConfig.HDR_BT2020_HLG)
                projectStateController.reportHdrSwitchEvent(qsTr("pccut_hdr_import_hdr_to_sdr_dialog_switch_button"))
            }
            onClosed: {
                hdrMismatchLoader.active = false;
            }
        }
        onLoaded: item.open()
    }
    Connections {
        target: screenShot
        // 导出图片结束后 隐藏蒙层弹出弹框提示截图成功
        function onExportImageComplete() {
            toast.showToast(qsTr("pccut_player_screenshot_success"), "playerPanel")
        }
    }

    CShortcut {
        action: ShortcutAction.REFERENCE_LINE
        onActivated: {
            playerPanel.refUseMethod = "shortcut"
            toggleRef(refLineConfig.refLine)
        }
    }

    CShortcut {
        action: ShortcutAction.START_FRAME
        onActivated: {
            controller.seekStart();
        }
    }

    CShortcut {
        action: ShortcutAction.END_FRAME
        onActivated: {
            controller.seekEnd();
        }
    }

    CShortcut {
        action: ShortcutAction.PAUSE
        onActivated: {
            if(draftManager.currentDraft !== -1){
                controller.togglePlayState();
                playerController.togglePlayState(controller.playing)
            }
        }
    }

    Component.onCompleted: {
        var items = [refLineConfig.refLine, refLineConfig.grid, refLineConfig.centerPoint, refLineConfig.crossLine,
                    refLineConfig.diagonal, refLineConfig.goldenRatio]
        items.forEach(function(item) {
            playerPanel[item.prop] = lightSetting.getBool(item.key, false)
        })
        initRefArg = true
    }
}
