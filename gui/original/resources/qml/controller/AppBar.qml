import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Window 2.15
import QtQuick.Layouts 1.15
import QtQuick.Templates 2.12 as T
import Qt5Compat.GraphicalEffects
import Controls 1.0
import Config 1.0
import LightTabRectangle 1.0
import ShortcutAction 1.0
import Qt.labs.platform 1.1
import QtQuick.Dialogs
import TrackingManager 1.0
import LogManager 1.0
import MediaListViewModel 1.0
import LightRectangle 1.0
import QmlConstants 1.0
import FeedBackManager 1.0
import app_qrc 1.0
import CloudAlbumTransferModel 1.0
import CloudAlbumManager 1.0
import TaskQueueViewModel 1.0
import UsedFunctionManager 1.0
import ProjectSettingsInfo 1.0
import AppBarViewModel 1.0
import Nova 1.0

import "../menubar"

Item {
    id: control

    AppBarViewModel {
        id: appBarViewModel
    }

    property bool isAvailable: true
    property bool userLoginOnboarded: lightSetting.getBool("user_login_onboarded", false)

    property string title: ""
    property bool titleVisible: true
    property bool isExporting: true
    property bool isExportListOpened: true
    // 云相册任务队列（含上传/下载）需功能开关 + 灰度可用 + 已同意协议；否则恢复旧导出队列形态
    readonly property bool cloudTaskQueueEnabled: cloudAlbumFeatureFlags.enable
                                                  && CloudAlbumManager.grayCloudAlbumAvailable
                                                  && CloudAlbumManager.cloudAlbumAgreementAccepted
    property bool playerIsFullscreen: false
    property url icon
    property int iconSize: 20
    property var maxClickListener: function () {
        if (CommonUtils.isWindows()) {
            if (d.win.visibility === Window.Maximized) {
                d.win.showNormal()
            } else {
                d.win.showMaximized()
            }
        } else {
            if (d.win.visibility === Window.FullScreen) {
                d.win.showNormal()
                d.win.requestActivate()
            } else {
                d.win.showFullScreen()
            }
        }
    }
    property var minClickListener: function () {
        globalSignal.switchToHome()
        d.win.showMinimized()
    }
    property var closeClickListener: function () {
        //d.win.close()
        if (exportListButton.itemProgress != 0) {
            removePopup.open()
        } else {
            globalSignal.quitApp();
        }       
    }
    property var systemMenuListener: function () {
        d.win.showSystemMenu()
    }

    property var beforeCloseListener: function () {
        if (exportListButton.itemProgress != 0) {
            removePopup.open()
        } else {
            globalSignal.quitApp();
        }
    }

    // ❌ 已删除：批量选择按钮已移到 DeviceView/CopiedView
    // property alias multipleSelectDeviceBtn: multipleSelectDeviceBtn

    // 首页显示/隐藏导出按钮
    property bool devicePageEnableExport: false

    // 云相册已登录视图是否正在显示（由 Main.qml 绑定 homeView.isCloudAlbumVisible）
    property bool isCloudAlbumVisible: false

    // 打开任务队列时清除导出完成的瞬态红点
    function clearFinishImage() {
        exportTabView.showFinishImage = false
    }

    signal createNewDraft
    signal tabChanged(int index)
    signal openTaskQueue

    // 暴露 ExportTabView 的 ViewModel 供 TaskQueuePopup 共享
    property var exportViewModel: exportTabView.exportVM

    TaskQueueViewModel {
        id: taskQueueBadgeVM
        exportTabViewModel: exportTabView.exportVM
    }
    readonly property var taskQueueViewModel: taskQueueBadgeVM

    function taskQueueBadgeCount(counts) {
        var total = 0
        for (var i = 0; i < counts.length; i++) {
            total += counts[i]
        }
        return total
    }

    function taskQueueHasHistoryDot(dots) {
        for (var i = 0; i < dots.length; i++) {
            if (dots[i]) return true
        }
        return false
    }

    CShortcut {
        action: ShortcutAction.NEW_PROJECT
        enabled: control.visible
        onActivated: {
            logger.d("CShortcut NEW_PROJECT");
            draftManager.addNewDraft()
        }
    }

    CShortcut {
        action: ShortcutAction.IMPORT
        enabled: control.visible
        onActivated: {
            if(draftManager.currentDraft !== -1) {
                if (importFileDialog.importOperationType === -1) {
                    globalSignal.setImportOperationType(MediaListViewModel.ShortCut)
                }
                importFileDialog.open()
            }
        }
    }

    CShortcut {
        action: ShortcutAction.EXPORT
        enabled: control.visible
        onActivated: {
            if(draftManager.currentDraft !== -1)
                globalSignal.clickExportAction()
        }
    }

    CShortcut {
        action: ShortcutAction.ESCAPE_FULL_SCREEN
        onActivated: {
            if (playerIsFullscreen) {
                return
            }
            if (d.win.visibility === Window.FullScreen) {
                maxClickListener()
            }
        }
    }

    Connections {
        target: globalSignal

        // 首页显示/隐藏导出按钮
        function onDevicePageEnableExportStateChanged(enableExport) {
            control.devicePageEnableExport = enableExport
        }

        // 点击导出
        function onClickExportAction() {
            logger.i("[Compose] onClickExportAction");
            logger.i(draftManager.currentDraft)

            if (draftManager.currentDraft === -1) {
                // 首页-导出原片和高光，在 DevicePanel 处理
            } else {
                // 导出草稿
                if (editorManager.isInEditeState) {
                    if (!composeLoader.active) {
                        composeLoader.active = true;
                    }
                    if (!composeLoader.item.visible) {
                        playerPanel.controller.pause()
                        composeLoader.item.show()
                        logger.i("[Compose] show compose panel");
                    }
                } else {
                    toast.showToast(qsTr("pccut_export_novideo"))
                }
            }
        }

        function onUpdatePlayerUiState(isFullScreen) {
            playerIsFullscreen = isFullScreen
        }
    }

    height: visible ? 30 : 0
    opacity: visible
    // z: 65535

    Connections {
        target: globalSignal

        function onEnableMenuBar(enable) {
            if(editorManager.isInUserGuideStatus && enable){ // 用户指引过程中，禁止enable
                return;
            }
            isAvailable = enable;
        }

        function onTrackingStateChanged(status){
            if (status === TrackingManager.TK_ENTER) {
                isAvailable = false
            } else if(status === TrackingManager.TK_EXIT){
                isAvailable = true
            }
        }
    }
    
    // Connections { eisen
    //     target: globalSignal
        
    //     function onShowMainPanel() {
    //         if (!CommonUtils.isNull(d.win) && d.win.visibility === Window.Minimized) {
    //             if (d.visiblityBeforeMinimized === Window.Maximized) {
    //                 d.win.showMaximized()
    //             } else {
    //                 d.win.showNormal()
    //             }
    //         }
    //     }        
    // }

    function popupAndProhibit(page,item){
        //itemClicked(page,item);
        if (page === 0 && item === 2) {
            Updater.checkUpdateAvailable(false)
            return
        }
        isAvailable = false;
        if (menuPopLoader.active && menuPopLoader.item) {
            menuPopLoader.item.close();
        }
        // topbar第一个选项的第三个item，代表检测升级
        appMenuBarLayers.showPopLayer(page, item)
    }

    Item {
        id: d

        property var win: Window.window
        property bool resizable: win && !(win.height === win.maximumHeight
                                          && win.height === win.minimumHeight
                                          && win.width === win.maximumWidth
                                          && win.width === win.minimumWidth)
        
        // property int visiblityBeforeMinimized: Window.Windowed eisen
        // Connections { eisen
        //     target: d.win
        //     function onVisibilityChanged() {
        //         if (!CommonUtils.isNull(d.win) && d.win.visibility !== Window.Minimized) {
        //             d.visiblityBeforeMinimized = d.win.visibility
        //         }
        //     }
        // }
    }

    //关闭程序时提示弹窗
    LightAlert {
        id: removePopup
        objectName: actionableItemName.runningProcessPopup
        title: qsTr("pccut_export_exit_abort")
        onCancelSignal: {
            removePopup.close()
        }
        onConfirmBtnSignal: {
            globalSignal.quitApp();
            removePopup.close()
        }
    }

    WindowMovable {
        id: mouse_app_bar

        anchors.fill: parent

        onClicked: mouse => {
                       if (mouse.button === Qt.RightButton) {
                           systemMenuListener()
                       }
                   }

        window: lightWindow
        sizeHandler: windowSizeManager
        resizableBar: d
    }

    RowLayout {
        id: windowsButtonsRow
        anchors {
            top: parent.top
            bottom: parent.bottom
            topMargin: 0.5
            right: parent.right
            rightMargin: 0.5
        }
        spacing: 0

        visible: CommonUtils.isWindows()

        IconButton {
            id: minButton
            width: 48
            height: 32
            radius: 0

            normalColor: Colors.transparent
            hoverColor: Colors.color_2F3032
            pressedColor: Colors.color_252627
            disableColor: Colors.transparent

            iconSource: "qrc:/icons/WindowsIcon/icon_minimize.svg"

            onClicked: {
                minClickListener()
            }
        }

        IconButton {
            id: maxButton
            width: 48
            height: 32
            radius: 0

            normalColor: Colors.transparent
            hoverColor: Colors.color_2F3032
            pressedColor: Colors.color_252627
            disableColor: Colors.transparent

            iconSource: lightWindow.visibility !== Window.Maximized ? "qrc:/icons/WindowsIcon/icon_maximizing.svg" : "qrc:/icons/WindowsIcon/icon_maxminimizing.svg"

            onClicked: {
                maxClickListener()
            }
        }

        LightRectangle {
            id: closeButton
            objectName: actionableItemName.closeAppWindows
            width: 48
            height: 32
            radius: [0, 9, 0, 0]
            color: {
                if (mouseArea.pressed) return Colors.color_C61E37;
                if (mouseArea.containsMouse) return Colors.color_F22443;
                return Colors.color_transparent;
            }

            Image {
                anchors.centerIn: parent
                width: parent.width
                height: parent.height
                source: "qrc:/icons/WindowsIcon/icon_close.svg"
                sourceSize: Qt.size(width, height)
            }

            MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    closeClickListener()
                }
            }
        }
    }

    RowLayout {
        id: macButtonsRow
        objectName: actionableItemName.macTitleBarRowLayout
        visible: CommonUtils.isWindows() ? false : true

        anchors {
            verticalCenter: parent.verticalCenter
            left: parent.left
            leftMargin: 10
        }

        ImageButton {
            id: btn_close
            objectName: actionableItemName.closeApp
            Layout.preferredHeight: 12
            Layout.preferredWidth: 12
            hoverEnabled: false
            enabled: lightWindow.active
            normalImage: "qrc:/icons/appbar/btn_close_normal.svg"
            hoveredImage: "qrc:/icons/appbar/btn_close_hovered.svg"
            pushedImage: "qrc:/icons/appbar/btn_close_pushed.svg"
            disabledImage: "qrc:/icons/appbar/btn_appbar_disable.svg"
            onClicked: closeClickListener()
        }

        ImageButton {
            id: btn_min

            Layout.preferredHeight: 12
            Layout.preferredWidth: 12
            hoverEnabled: false
            enabled: lightWindow.active
            normalImage: "qrc:/icons/appbar/btn_min_normal.svg"
            hoveredImage: "qrc:/icons/appbar/btn_min_hovered.svg"
            pushedImage: "qrc:/icons/appbar/btn_min_pushed.svg"
            disabledImage: "qrc:/icons/appbar/btn_appbar_disable.svg"
            onClicked: minClickListener()
        }

        ImageButton {
            id: btn_max

            Layout.preferredHeight: 12
            Layout.preferredWidth: 12
            hoverEnabled: false
            enabled: lightWindow.active
            normalImage: "qrc:/icons/appbar/btn_max_normal.svg"
            hoveredImage: lightWindow.visibility === Window.FullScreen ? "qrc:/icons/appbar/btn_normal_hovered.svg" : "qrc:/icons/appbar/btn_max_hovered.svg"
            pushedImage: lightWindow.visibility === Window.FullScreen ? "qrc:/icons/appbar/btn_normal_pushed.svg" : "qrc:/icons/appbar/btn_max_pushed.svg"
            disabledImage: "qrc:/icons/appbar/btn_appbar_disable.svg"
            onClicked: maxClickListener()
            visible: d.resizable
        }
    }

    MouseArea {
        property var buttons: [btn_close, btn_min, btn_max]

        anchors.fill: macButtonsRow
        hoverEnabled: true
        onEntered: {
            for (var i in buttons) {
                buttons[i].customHovered = true
            }
        }
        onExited: {
            for (var i in buttons) {
                buttons[i].customHovered = false
            }
        }
        acceptedButtons: Qt.NoButton
    }

    // Text {
    //     id: debugText
    //     visible: true
    //     text: "设备:" + sysInfo.machineHostName + "/" + sysInfo.prettyProductName + " BundleID:" + sysInfo.applicationVersion + "  启动时间:" + new
    //     wrapMode: Text.WordWrap
    //     font.pointSize: 8
    //     anchors.left: parent.left
    //     anchors.right: parent.right
    //     anchors.leftMargin: 100
    //     anchors.rightMargin: 200
    //     color: "#ADD8E6"
    // }
    property int tabWidth: 180
    property int homeButtonWidth: 24
    property int tabMaxWidth: control.width - 25 - 280 - macButtonsRow.width - homeButtonWidth
    property int tabMaxCount: (tabMaxWidth / tabWidth) + 1
    property int tipsDeviation: 4

    onTabMaxCountChanged: {
        if (draftManager.currentDraft < tabMaxCount) {
            listView.currentIndex = draftManager.currentDraft
        }
    }

    IconTextButton {
        id: menuButton
        anchors {
            verticalCenter: parent.verticalCenter
            left: parent.left
            leftMargin: 8
        }
        height: 26
        visible: CommonUtils.isWindows()

        title: qsTr("pccut_project_menu")
        internalSpacing: 2
        leftPadding: 5
        rightPadding: 8
        titleColorNormal: Colors.color_999999
        titleColorHover: Colors.color_FFFFFF
        titleColorChecked: Colors.color_FFFFFF
        imageRectWidth:16
        imageRectHeight:16
        backgroundColorNormal: Colors.color_262728_30
        backgroundColorPressed: Colors.color_262728
        backgroundColorChecked: Colors.color_262728
        backgroundColorHover: Colors.color_262728
        iconPathNormal: "qrc:/icons/WindowsIcon/icon_menu_normal.svg"
        iconPathHover:"qrc:/icons/WindowsIcon/icon_menu_pressed.svg"
        iconPathChecked:"qrc:/icons/WindowsIcon/icon_menu_pressed.svg"

        onCustomClicked: {
            menuPopLoader.active = true
            if (menuPopLoader.active && menuPopLoader.item) {
                var menuPopup = menuPopLoader.item
                menuPopup.x = menuButton.mapToItem(control, 0, 0).x
                menuPopup.y = menuButton.mapToItem(control, 0,
                                                menuButton.height + 4).y
                menuPopup.open()
            }
        }
    }

    // 快剪标题栏
    Item {
        id: quickCutTitleBar
        visible: false
    }

    RowLayout {
        id: tabRow
        anchors.left: CommonUtils.isWindows(
                          ) ? menuButton.right : macButtonsRow.right
        anchors.right: splitLine.left
        height: parent.height
        // width: tabMaxCount * tabWidth + homeButtonWidth + 10
        anchors.leftMargin: CommonUtils.isWindows() ? 12 : 25
        visible: true

        // 首页按钮
        Rectangle {
            id: homeButton
            width: homeButtonWidth
            height: 26
            color: Colors.transparent
            Layout.alignment: Qt.AlignVCenter
            property bool isHovered: false
            Rectangle {
                width: 26
                height: 26
                color: (draftManager.currentDraft === -1
                        || homeButton.isHovered) ? Colors.color_2F3032 : Colors.color_2F3032_20
                radius: RadiusConfig.radius_6_88
                anchors.centerIn: parent
                Image {
                    width: 24
                    height: 24
                    anchors.centerIn: parent
                    source: (draftManager.currentDraft === -1
                             || homeButton.isHovered) ? "qrc:/app_qrc/icons/icon_home_pressed_new.svg" : "qrc:/app_qrc/icons/icon_home_normal_new.svg"
                    sourceSize: Qt.size(24, 24)
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true

                    onEntered: {
                        homeToolTipLoader.active = true
                        var homeToolTip = homeToolTipLoader.item
                        homeToolTip.visible = true
                        homeButton.isHovered = true
                    }
                    onExited: {
                        var homeToolTip = homeToolTipLoader.item
                        homeToolTip.visible = false
                        homeButton.isHovered = false
                        homeToolTipLoader.active = false
                    }
                    onClicked: {
                        draftManager.saveProject()
                        listView.currentIndex = -1
                        draftManager.currentDraft = -1
                        globalSignal.switchToHome()
                    }
                }

                Loader {
                    id: homeToolTipLoader
                    // 默认不加载
                    active: false
                    // 首页ToolTip
                    sourceComponent: ToolTip {
                        id: homeToolTip
                        x: 0
                        y: homeButton.height + tipsDeviation
                        opacity: 0
                        delay: 500
                        background: LightClipRectangle {
                            anchors.fill: parent
                            clip: true
                            radius: [4, 4, 4, 4]

                            ShaderEffectSource {
                                id: shaderSource
                                sourceItem: mainPanel
                                sourceRect: Qt.rect(homeToolTip.x, homeToolTip.y,
                                                    homeToolTip.width,
                                                    homeToolTip.height)
                                width: parent.width
                                height: parent.height
                                live: true
                                smooth: true
                            }

                            // 高斯调节
                            FastBlur {
                                anchors.fill: parent
                                source: shaderSource
                                radius: 48
                            }

                            Rectangle {
                                anchors.fill: parent
                                border.color: Colors.color_444444
                                border.width: 0.5
                                color: Colors.color_141414_85
                                radius: 4
                            }
                        }
                        contentItem: Text {
                            text: qsTr("pccut_home")
                            color: Colors.color_EEEEEE
                        }
                        // 渐隐渐现的动画
                        Behavior on opacity {
                            NumberAnimation {
                                duration: 300
                            }
                        }
                        // 监听 visible 属性的变化，控制 opacity
                        onVisibleChanged: {
                            if (visible) {
                                opacity = 1.0
                            } else {
                                opacity = 0.0
                            }
                        }
                        }
                    }
                }
        }

        Rectangle {
            id: listViewContainer
            Layout.preferredWidth: (tabMaxCount < draftManager.openedCount ? tabMaxCount : draftManager.openedCount) * (tabWidth + 4) - 4
            Layout.maximumWidth: tabRow.width - homeButton.width - addPageRect.width - tabRow.spacing * 3
            height: parent.height
            Layout.alignment: Qt.AlignLeft
            clip: true
            color: Colors.transparent
            property TextInput activeInputText: null
            
            Loader {
                active: listViewContainer.activeInputText != null
                sourceComponent: TextInputOverlay {
                        activeInputContainer: listViewContainer.activeInputText
                }
            }

            ListView {
                id: listView
                objectName: actionableItemName.projectListView
                model: tabListModel
                width: listViewContainer.width
                height: listViewContainer.height
                orientation: ListView.Horizontal
                spacing: 4
                interactive: tabMaxCount < draftManager.openedCount ? true : false
                property bool isDragging: false
                ScrollBar.horizontal: ScrollBar {
                    policy: ScrollBar.AlwaysOff
                }
                onCurrentIndexChanged: {
                    tabChanged(listView.currentIndex)
                    for (var i = 0; i < listView.count; i++) {
                        var button = listView.itemAtIndex(i)
                        if (button) {
                            button.isHovered = false
                        }
                    }
                }
                onMovementStarted: {
                    isDragging = true
                }
                onMovementEnded: {
                    isDragging = false
                }
                Connections {
                    target: draftManager
                    function onSwitchTo(id) {
                        var index = draftManager.findOpenedDraftIndexById(id)
                        listView.currentIndex = index
                    }
                }

                TextMetrics {
                    id: tipTextMetrics
                    font.pixelSize: 11
                    font.letterSpacing: 1
                }

                Loader {
                    id: notificationTips
                    active: false
                    property string tipText: ""
                    property real tipX: 0
                    property real tipY: 0
                    property int tipsWidth: 200

                    Timer {
                        id: notificationAutoHideTimer
                        interval: 3000
                        repeat: false
                        onTriggered: notificationTips.active = false
                    }

                    function showTip() {
                        notificationTips.active = true
                        notificationAutoHideTimer.restart()
                    }

                    sourceComponent: Component {
                        BaseNotificationTips {
                            parent: Window.contentItem
                            x: notificationTips.tipX
                            y: notificationTips.tipY
                            width: tipsWidth
                            showArrow: true
                            arrowPosition: 1
                            arrowLeftMargin: width / 2 - arrowWidth / 2 + contentLeftMargin
                            text: notificationTips.tipText
                            contentBottomMargin: 6
                        }
                    }
                }

                delegate: TabButton {
                    id: tab
                    objectName: actionableItemName.delegateItemForProjectListView + index
                    width: tabWidth
                    height: 26
                    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

                    property bool isHovered: false
                    property bool isRenaming: false
                    property string originalName: ""
                    // 捕获 delegate 的行号与草稿 id，供嵌套 Component（tabContextMenuLoader）安全引用。
                    // 视图注入的 index/model 在嵌套 Component 里可能解析为 -1/失效，故在此固化。
                    property int tabIndex: index
                    property var tabDraftId: model.id

                    function startRename() {
                        originalName = model.name
                        tabNameInput.text = model.name
                        isRenaming = true
                        tabNameInput.forceActiveFocus()
                        tabNameInput.selectAll()
                    }

                    function commitRename() {
                        if (!isRenaming) {
                            return true
                        }

                        if (newName === originalName) {
                            return true
                        }

                        var newName = tabNameInput.text.trim()
                        if (newName.length === 0) {
                            //如果名称为空回退原名称
                            tabNameInput.text = originalName
                            showNotificationTip(qsTr("pccut_rename_empty"))
                            return false
                        }

                        if (!draftManager.renameDraftById(model.id, newName)) {
                            //如果名称已被占用回退原名称
                            tabNameInput.text = originalName
                            showNotificationTip(qsTr("pccut_files_missing_samename"))

                            return false
                        }

                        return true
                    }

                    function cancelRename() {
                        if (!isRenaming) {
                            return
                        }
                        tabNameInput.text = originalName
                    }

                    function showNotificationTip(text) {
                        tipTextMetrics.text = text
                        var contentPadding = 8 + 8  // contentLeftMargin + contentRightMargin
                        notificationTips.tipsWidth = Math.min(Math.ceil(tipTextMetrics.advanceWidth) + contentPadding, 300)
                        var pos = tab.mapToItem(null, 0, tab.height - 1)
                        notificationTips.tipText = text
                        notificationTips.tipX = pos.x + tab.width / 2 - notificationTips.tipsWidth / 2
                        notificationTips.tipY = pos.y
                        notificationTips.showTip()
                    }

                    background: Item {
                        anchors.fill: parent
                        Rectangle {
                            id: background
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            width: parent.width
                            height: parent.height
                            color: (draftManager.currentDraft === index
                                    || tab.isHovered) ? Colors.color_2F3032 : Colors.color_2F3032_20
                            radius: RadiusConfig.radius_6_88
                        }
                    }

                    MouseArea {
                        id: tabMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton

                        onEntered: {
                            toolTip.visible = true
                            tab.isHovered = true
                            for (var i = 0; i < listView.count; i++) {
                                if (i !== index) {
                                    var button = listView.itemAtIndex(i)
                                    if (button) {
                                        button.isHovered = false
                                    }
                                }
                            }
                        }
                        onExited: {
                            toolTip.visible = false
                            Qt.callLater(function () {
                                // 重命名状态下鼠标移入 TextInput 会导致 tabMouseArea 失去 hover，
                                // 此时不应重置 isHovered，避免 moreBtn 闪烁消失
                                if (!tab.isRenaming
                                        && !tabMouseArea.containsMouse
                                        && !closeMouseArea.containsMouse
                                        && !moreMouseArea.containsMouse) {
                                    tab.isHovered = false
                                }
                            })
                        }
                        onClicked: (mouse) => {

                            if (mouse.button === Qt.RightButton) {
                                tabContextMenuLoader.active = true
                                if (tabContextMenuLoader.item) {
                                    let menu = tabContextMenuLoader.item
                                    let pos = tab.mapToGlobal(mouse.x, mouse.y)
                                    let overlay = menu.parent
                                    let local = overlay.mapFromGlobal(pos.x, pos.y)
                                    // open() 不做窗口边界钳制，手动收进窗口内
                                    menu.x = Math.max(0, Math.min(local.x, overlay.width - menu.width))
                                    menu.y = Math.max(0, Math.min(local.y, overlay.height - menu.height))
                                    menu.open()
                                }
                                return
                            }

                            draftManager.saveProject()
                            var result = draftManager.switchToDraftByIndex(
                                        index)
                            if (result === false) {
                                // 切换失败了
                                draftManager.closeDraft(model.id)
                            } else {
                                // 切换成功
                                listView.currentIndex = index
                            }
                        }
                    }
                    ToolTip {
                        id: toolTip
                        x: -(toolTip.width - tab.width) / 2
                        y: tab.height + tipsDeviation
                        opacity: 0
                        delay: 500
                        background: LightClipRectangle {
                            anchors.fill: parent
                            clip: true
                            radius: [4, 4, 4, 4]

                            ShaderEffectSource {
                                id: shaderSource3
                                sourceItem: mainPanel
                                sourceRect: Qt.rect(toolTip.x, toolTip.y,
                                                    toolTip.width,
                                                    toolTip.height)
                                width: parent.width
                                height: parent.height
                                live: true
                                smooth: true
                            }

                            // 高斯调节
                            FastBlur {
                                anchors.fill: parent
                                source: shaderSource3
                                radius: 48
                            }

                            Rectangle {
                                anchors.fill: parent
                                border.color: Colors.color_444444
                                border.width: 0.5
                                color: Colors.color_141414_85
                                radius: 4
                            }
                        }
                        contentItem: Text {
                            text: qsTr(model.name)
                            color: Colors.color_EEEEEE
                        }
                        // 渐隐渐现的动画
                        Behavior on opacity {
                            NumberAnimation {
                                duration: 300
                            }
                        }
                        // 监听 visible 属性的变化，控制 opacity
                        onVisibleChanged: {
                            if (visible) {
                                opacity = 1.0
                            } else {
                                opacity = 0.0
                            }
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        Text {
                            id: draftName
                            Layout.fillWidth: true
                            height: 26
                            visible: !tab.isRenaming
                            Layout.alignment: Qt.AlignVCenter
                            Layout.leftMargin: 13
                            text: qsTr(model.name)
                            font.pixelSize: 12
                            color: (draftManager.currentDraft
                                    === index) ? Colors.color_EEEEEE : Colors.color_999999
                            elide: Text.ElideMiddle
                            horizontalAlignment: Text.AlignLeft

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton
                                propagateComposedEvents: true
                                onClicked: (mouse) => { mouse.accepted = false }
                                onDoubleClicked: {
                                    tab.startRename()
                                    listViewContainer.activeInputText = tabNameInput
                                }
                            }
                        }

                        TextInput {
                            id: tabNameInput
                            Layout.fillWidth: true
                            height: 26
                            visible: tab.isRenaming
                            Layout.alignment: Qt.AlignVCenter
                            Layout.leftMargin: 13
                            font.pixelSize: 12
                            clip: true           // 超 50 字时文字自动滚动
                            // maximumLength: 50
                            verticalAlignment: TextInput.AlignVCenter
                            color: Colors.color_EEEEEE
                            selectionColor: Colors.color_EEEEEE
                            selectedTextColor: Colors.color_1F2021
                            property bool isUpdatingText: false

                            Keys.onShortcutOverride: (event) => {
                                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    event.accepted = true
                                    //失去焦点的时候触发提交重命名
                                    focus = false
                                } else if (event.key === Qt.Key_Escape) {
                                    event.accepted = true
                                    tab.cancelRename()
                                    isRenaming = false
                                    listViewContainer.activeInputText = null
                                    focus = false
                                }
                            }

                            onTextChanged: {
                                if (isUpdatingText) return
                                isUpdatingText = true
                                //禁止输入非法字符
                                var filteredText = CommonUtils.sanitizeString(tabNameInput.text);

                                if (tabNameInput.text !== filteredText) {
                                    var cursorPos = tabNameInput.cursorPosition;
                                    tabNameInput.text = filteredText;
                                    tabNameInput.cursorPosition = Math.max(0, cursorPos - 1);
                                }

                                // 长度限制
                                var maxLen = 50;
                                if (CommonUtils.mixedTextLength(tabNameInput.text) > maxLen) {
                                    var pos = tabNameInput.cursorPosition;
                                    tabNameInput.text = CommonUtils.truncateByMixedLength(tabNameInput.text, maxLen);
                                    tabNameInput.cursorPosition = Math.min(pos, tabNameInput.text.length);
                                }
                                isUpdatingText = false
                            }

                            onActiveFocusChanged: {
                                if (!activeFocus && tab.isRenaming) {
                                    // 点击输入框外自动保存
                                    var isCommit = tab.commitRename()
                                    //提交成功
                                    if (isCommit) {
                                        isRenaming = false
                                        listViewContainer.activeInputText = null
                                        notificationTips.active = false
                                    }else {
                                        //提交失败(校验失败)，焦点还要在tabNameInput上
                                        Qt.callLater(function() {
                                            if (tab.isRenaming) {
                                                tabNameInput.forceActiveFocus()
                                            }
                                        })
                                    }
                                }
                            }
                        }

                        // 更多设置 —— hover tab 时显示；左键点击从图标下方弹出下拉菜单
                        // 复用 tabContextMenuLoader（同一份"重命名 / 项目设置"菜单，与右键 tab 一致）
                        // 外层 Item 始终占据布局空间，保证 hover 前后 draftName 可用宽度一致，截断字数不变
                        // 内层 moreBtn 用 visible 控制，visible:false 时不拦截鼠标事件
                        Item {
                            width: 16
                            height: 16
                            Layout.alignment: Qt.AlignVCenter
                            Layout.rightMargin: 2

                            Rectangle {
                                id: moreBtn
                                objectName: "moreSettingsButton"
                                anchors.fill: parent
                                // hover tab 时显示；下拉菜单展开中保持显示（激活态）
                                // 始终保持 visible:true，仅用 opacity 控制显隐，保证淡入淡出动画两个方向都能播放
                                visible: true
                                // PRD 5.3.3 ②：150ms 淡入淡出
                                opacity: (tab.isHovered
                                          || (tabContextMenuLoader.item
                                              && tabContextMenuLoader.item.visible)) ? 1 : 0
                                Behavior on opacity {
                                    NumberAnimation { duration: 150 }
                                }
                                // opacity 为 0 时禁用鼠标事件，避免透明状态拦截 tabMouseArea 的 hover
                                color: moreMouseArea.containsMouse ? Colors.color_454649 : Colors.transparent
                                radius: 4
                                Image {
                                    anchors.centerIn: parent
                                    source: moreMouseArea.pressed
                                            ? "qrc:/icons/icon_project_more_pressed.svg"
                                            : moreMouseArea.containsMouse
                                              ? "qrc:/icons/icon_project_more_hover.svg"
                                              : "qrc:/icons/icon_project_more_default.svg"
                                    sourceSize: Qt.size(20, 20)

                                    MouseArea {
                                        id: moreMouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        enabled: moreBtn.opacity > 0

                                        onEntered: {
                                            tab.isHovered = true
                                        }
                                        onExited: {
                                            if (!tabMouseArea.containsMouse
                                                    && !closeMouseArea.containsMouse
                                                    && !moreMouseArea.containsMouse) {
                                                tab.isHovered = false
                                            }
                                        }
                                        onClicked: {
                                            // PRD 5.3.3 ④：左键点击图标 → 从图标正下方弹出下拉菜单
                                            tabContextMenuLoader.active = true
                                            if (tabContextMenuLoader.item) {
                                                var menu = tabContextMenuLoader.item
                                                var pos = moreBtn.mapToGlobal((moreBtn.width - menu.width) / 2, moreBtn.height + 2)
                                                var overlay = menu.parent
                                                var local = overlay.mapFromGlobal(pos.x, pos.y)
                                                // open() 不做窗口边界钳制，手动收进窗口内
                                                menu.x = Math.max(0, Math.min(local.x, overlay.width - menu.width))
                                                menu.y = Math.max(0, Math.min(local.y, overlay.height - menu.height))
                                                menu.open()
                                            }
                                        }
                                    }
                                }
                            }
                        } // Item (moreBtn 占位容器)

                        //关闭按钮
                        Rectangle {
                            id: closeBtn
                            objectName: actionableItemName.closeProject
                            width: 16
                            height: 16
                            property bool isHovered: false
                            color: closeMouseArea.containsMouse ? Colors.color_454649 : Colors.transparent
                            radius: 13
                            Layout.alignment: Qt.AlignVCenter
                            Layout.rightMargin: 6
                            Image {
                                anchors.centerIn: parent
                                source: closeMouseArea.pressed
                                        ? "qrc:/icons/icon_project_close_pressed.svg"
                                        : closeBtn.isHovered
                                          ? "qrc:/icons/icon_project_close_hover.svg"
                                          : "qrc:/icons/icon_project_close_default.svg"
                                sourceSize: Qt.size(20, 20)

                                MouseArea {
                                    id: closeMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true

                                    onEntered: {
                                        closeBtn.isHovered = true
                                        tab.isHovered = true
                                    }
                                    onExited: {
                                        closeBtn.isHovered = false
                                        if (!tabMouseArea.containsMouse
                                                && !closeMouseArea.containsMouse
                                                && !moreMouseArea.containsMouse) {
                                            tab.isHovered = false
                                        }
                                    }
                                    onClicked: {
                                        draftManager.closeDraft(model.id)
                                    }
                                }
                            }
                        }
                    }

                    Loader {
                        id: tabContextMenuLoader
                        active: false
                        sourceComponent: Component {
                            LightPopup {
                                id: tabContextMenu
                                width: 90
                                height: 64
                                customRadius: 8
                                needTransparent: true
                                needNoBorder: false
                                closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
                                // 覆盖 modal 遮罩为透明，避免弹出时整个窗口变暗
                                T.Overlay.modal: Rectangle { color: Colors.transparent }

                                function isMenuItemEnabled(idx) {
                                    if (idx === 0) return true
                                    // 点开的必然是已打开的 tab，恒可用；与全局 currentDraft 无关
                                    return true
                                }

                                function getMenuText(idx) {
                                    if (idx === 0) return qsTr("pccut_draft_rename")
                                    return qsTr("pccut_project_modify_settings")
                                }

                                function triggerItem(index) {
                                    if (index === 0) {
                                        tab.startRename()
                                        listViewContainer.activeInputText = tabNameInput
                                    } else if (index === 1) {
                                        draftManager.saveProject()
                                        // 按草稿 id 切换，关闭左侧 tab 后行号漂移不影响定位
                                        if (draftManager.switchToDraftById(tab.tabDraftId) !== false) {
                                            let idx = draftManager.findOpenedDraftIndexById(tab.tabDraftId)
                                            if (idx >= 0) {
                                                listView.currentIndex = idx
                                            }
                                            editorManager.pause()
                                            globalSignal.clickProxySuggestPopup()
                                        }
                                    }
                                }

                                contentItem: LightClipRectangle {
                                    radius: [8, 8, 8, 8]
                                    clip: true

                                    Rectangle {
                                        anchors.fill: parent
                                        border.color: Colors.color_444444
                                        border.width: 1
                                        color: Colors.color_141414
                                        radius: 8
                                    }

                                    Column {
                                        anchors {
                                            top: parent.top
                                            topMargin: 4
                                            left: parent.left
                                            right: parent.right
                                        }

                                        Repeater {
                                            model: 2
                                            delegate: MouseArea {
                                                id: menuItemArea
                                                width: tabContextMenu.width
                                                height: 28
                                                hoverEnabled: true
                                                enabled: tabContextMenu.isMenuItemEnabled(index)

                                                onClicked: {
                                                    tabContextMenu.close()
                                                    tabContextMenu.triggerItem(index)
                                                }

                                                Rectangle {
                                                    anchors {
                                                        fill: parent
                                                        leftMargin: 4
                                                        rightMargin: 4
                                                    }
                                                    radius: 4
                                                    color: menuItemArea.containsMouse && menuItemArea.enabled
                                                           ? Colors.color_454649 : Colors.transparent
                                                }

                                                Text {
                                                    anchors.fill: parent
                                                    leftPadding: 12
                                                    verticalAlignment: Text.AlignVCenter
                                                    text: tabContextMenu.getMenuText(index)
                                                    font.pixelSize: 11
                                                    color: menuItemArea.enabled
                                                           ? Colors.color_EEEEEE : Colors.color_999999
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                property bool leftVisible: false // 用于控制左侧渐变的可见性
                property bool rightVisible: false // 用于控制右侧渐变的可见性
                function getLeftVisible() {
                    var index = Math.floor(
                                listView.contentX / (tabWidth + spacing))
                    var itemStartX = index * (tabWidth + spacing)
                    var itemEndX = itemStartX + tabWidth
                    return itemStartX !== listView.contentX
                }
                function getRightVisible() {
                    var index = Math.floor(
                                (listView.contentX + listView.width) / (tabWidth + spacing))
                    var itemStartX = index * (tabWidth + spacing)
                    var itemEndX = itemStartX + tabWidth
                    return listView.contentX + listView.width !== itemEndX
                }

                onContentXChanged: {
                    leftVisible = listView.contentX > 0 && getLeftVisible()
                    rightVisible = listView.contentX + listView.width < listView.contentWidth
                            && getRightVisible()
                }

                // 左侧渐变
                Rectangle {
                    width: 15
                    height: 26
                    visible: listView.leftVisible
                    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop {
                            position: 0.0
                            color: Colors.color_141414
                        }
                        GradientStop {
                            position: 1.0
                            color: Colors.transparent
                        }
                    }
                }

                // 右侧渐变
                Rectangle {
                    width: 15
                    height: 26
                    visible: listView.rightVisible
                    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                    anchors.right: parent.right
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop {
                            position: 0.0
                            color: Colors.transparent
                        }
                        GradientStop {
                            position: 1.0
                            color: Colors.color_141414
                        }
                    }
                }
            }
        }

        // 添加草稿按钮
        Rectangle {
            id: addPageRect
            width: 20
            height: 20
            radius: 4
            color: Colors.transparent
            visible: draftManager.openedCount > 0
            Layout.alignment: Qt.AlignLeft
            Image {
                id: addPageImage
                width: 20
                height: 20
                anchors.fill: parent

                source: "qrc:/icons/editor_draft_add.svg"
                sourceSize: Qt.size(20, 20)
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true

                onEntered: {
                    toolTipLoader.visible = true
                    addPageImage.source = "qrc:/icons/editor_draft_add_pressed.svg"
                }
                onExited: {
                    toolTipLoader.visible = false
                    addPageImage.source = "qrc:/icons/editor_draft_add.svg"
                }
                onClicked: {
                    eventTracker.trackEvent("pccut_create_project_click", {"use_method": "tabbed"});
                    draftManager.addNewDraft()
                }
            }
            Loader {
                id: toolTipLoader
                active: false
                visible: false
                anchors.fill:parent
                onVisibleChanged: {
                    if (visible) {
                        active = true;
                        item.tip = qsTr("pccut_project_label");
                        item.visible = true
                    } else {
                        active = false;
                    }
                }
                sourceComponent: LightToolTip {}
            }
        }
        Rectangle {
            id: fillRectangle
            Layout.fillHeight: true
            Layout.fillWidth: true
            color: Colors.transparent
        }
    }

    //分割线
    Rectangle {
        id: splitLine
        width: 1
        height: 12
        color: Colors.color_262728
        visible: draftManager.openedCount >= tabMaxCount
        anchors {
            verticalCenter: parent.verticalCenter
            right: draftMoreButton.left
            rightMargin: 6
        }
    }

    // 更多草稿按钮
    Rectangle {
        id: draftMoreButton
        width: 20
        height: 20
        radius: 4
        color: Colors.transparent
        visible: draftManager.openedCount >= tabMaxCount
        anchors {
            verticalCenter: parent.verticalCenter
            right: optionButtonLayout.left
            rightMargin: 24
        }

        Image {
            id: draftMoreImage
            width: 20
            height: 20
            anchors.fill: parent
            source: "qrc:/icons/icon_draftmore_normal.svg"
            sourceSize: Qt.size(20, 20)
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true

            onEntered: {
                draftMoreImage.source = "qrc:/icons/icon_draftmore_pressed.svg"
                moreToolTip.visible = true
            }
            onExited: {
                moreToolTip.visible = false
                if (!moreDraftListView.visible) {
                    draftMoreImage.source = "qrc:/icons/icon_draftmore_normal.svg"
                }
            }
            onClicked: {
                draftMoreImage.source = "qrc:/icons/icon_draftmore_pressed.svg"
                moreDraftListView.x = draftMoreButton.x
                        - moreDraftListView.width + draftMoreButton.width
                moreDraftListView.y = draftMoreButton.y + 30
                moreDraftListView.open()
            }
        }
        ToolTip {
            id: moreToolTip
            x: 0
            y: draftMoreButton.height + tipsDeviation
            opacity: 0
            delay: 500
            background: LightClipRectangle {
                anchors.fill: parent
                clip: true
                radius: [4, 4, 4, 4]

                ShaderEffectSource {
                    id: shaderSource2
                    sourceItem: mainPanel
                    sourceRect: Qt.rect(moreToolTip.x, moreToolTip.y,
                                        moreToolTip.width, moreToolTip.height)
                    width: parent.width
                    height: parent.height
                    live: true
                    smooth: true
                }

                // 高斯调节
                FastBlur {
                    anchors.fill: parent
                    source: shaderSource2
                    radius: 48
                }

                Rectangle {
                    anchors.fill: parent
                    border.color: Colors.color_444444
                    border.width: 0.5
                    color: Colors.color_141414_85
                    radius: 4
                }
            }
            contentItem: Text {
                text: qsTr("pccut_menu_more")
                color: Colors.color_EEEEEE
            }
            // 渐隐渐现的动画
            Behavior on opacity {
                NumberAnimation {
                    duration: 300
                }
            }
            // 监听 visible 属性的变化，控制 opacity
            onVisibleChanged: {
                if (visible) {
                    opacity = 1.0
                } else {
                    opacity = 0.0
                }
            }
        }
    }

    function getDraftListViewHeight() {
        if(draftManager.openedCount > 13) {
            return 406;
        }
        var count = draftManager.openedCount;
        return count * 28 + (count + 1) * 4;
    }

    LightPopup {
        id: moreDraftListView
        closePolicy: Popup.CloseOnPressOutside
        width: 165
        height: getDraftListViewHeight()
        Overlay.modal: Rectangle {
            color: Colors.transparent
        }

        Connections {
            target: draftManager
            function onCurrentDraftChanged() {
                popupListview.positionViewAtIndex(draftManager.currentDraft,
                                                  ListView.Beginning)
            }
        }
        onClosed: {
            draftMoreImage.source = "qrc:/icons/icon_draftmore_normal.svg"
        }

        contentItem: LightClipRectangle {
            anchors.fill: parent
            clip: true
            radius: [8,8,8,8]

            ShaderEffectSource {
                id: shaderSources
                sourceItem: mainPanel
                sourceRect: Qt.rect(moreDraftListView.x, moreDraftListView.y, moreDraftListView.width, moreDraftListView.height)
                width: parent.width
                height: parent.height
                live: true
                smooth: true
            }

            // 高斯调节
            FastBlur {
                anchors.fill: parent
                source: shaderSources
                radius: 48
            }

            Rectangle {
                anchors.fill: parent
                border.color: Colors.color_444444
                border.width: 0.5
                color: Colors.color_141414_85
                radius: 8
            }

            ListView {
                id: popupListview
                anchors.fill: parent
                anchors.topMargin: 4
                anchors.bottomMargin: 4
                anchors.leftMargin: 4
                anchors.rightMargin: 4
                spacing: 4
                clip: true
                model: tabListModel
                boundsBehavior: Flickable.StopAtBounds
                delegate: Item {
                    width: 155
                    height: 28
                    IconTextButton {
                        id: tabLabel
                        anchors.fill: parent
                        radius: 4
                        titleColorNormal: Colors.color_EEEEEE
                        backgroundColorNormal: Colors.color_transparent
                        backgroundColorHover: Colors.color_FFFFFF_15
                        title: model.name
                        iconPathNormal: draftManager.currentDraft
                                        === index ? "qrc:/icons/icon_selectlist.svg" : ""
                        iconSizeNormal: Qt.size(16, 16)
                        imageRectWidth: 16
                        imageRectHeight: 16
                        omitPolicy: Text.ElideMiddle
                        checkable: true
                        onCustomClicked:  {
                            moreDraftListView.close()
                            draftManager.currentDraft = index
                            draftManager.openDraft(model.id)
                            listView.positionViewAtIndex(index, ListView.Beginning)
                        }
                    }
                }

                ScrollBar.vertical: ScrollBar {
                    Component.onCompleted: {
                        contentItem.color = Colors.color_444444
                    }
                }
            }
        }
    }
    
    ExportTabView {
        id: exportTabView
        visible: false
        x: optionButtonLayout.x + exportButtonGroup.x + exportListButton.x + exportListButton.width - width + xOffset
        y: optionButtonLayout.y + exportListButton.height + 2 + yOffset

        onHasOperation: {
            Tools.timerStop("ExportTabView AutoClose")
        }

        onCustomClosed: {
            Tools.timerStop("ExportTabView AutoClose")
        }

        Connections {
            target: globalSignal

            function onClickExportButton() {
                exportTabView.exportTypeIndex = 0
                // 云相册任务队列接管时不弹旧导出浮层，判定与 cloudTaskQueueEnabled 保持同源
                if (control.cloudTaskQueueEnabled) {
                    return
                }
                exportTabView.open()
                Tools.singleShot("ExportTabView AutoClose", 3000, function () {
                    exportTabView.close()
                })
            }
        }
    }

    // 主界面蒙层显示/隐藏属性绑定:  
    property bool loginPopupVisible: userLoginPopupLoader.item ? userLoginPopupLoader.item.visible : false
    Loader {
        id: userLoginPopupLoader
        active: false
        sourceComponent: userLoginPopupComponent
    }
    Component {
        id: userLoginPopupComponent
        UserLoginPopup { }
    }

    Connections {
        target: userLoginViewModel
        function onRequestShowLoginWindow() {  
            if (!userLoginPopupLoader.active) {
                userLoginPopupLoader.active = true
            }
            if (userLoginPopupLoader.item) {
                userLoginPopupLoader.item.open()
            } 
            // 暂停播放
            editorManager.pause();
        }
        function onSessionExpired() {
            // 会话过期, 自动弹出登录窗口?
            //userLoginViewModel.showLoginWindow()
            // 暂停播放
            //editorManager.pause();
        }
    }

    // 未登录时调用 addUpload 触发登录弹窗
    Connections {
        target: CloudAlbumTransferModel
        function onLoginRequired() {
            userButton.clicked()
        }
        function onUploadsQueued(count) {
            uploadQueueBubble.showBubble(count, exportListButton)
        }
        function onDownloadsQueued(count) {
            uploadQueueBubble.showBubble(count, exportListButton)
        }
    }

    Connections {
        target: exportTabView.exportVM
        function onExportsQueued(count) {
            uploadQueueBubble.showBubble(count, exportListButton)
        }
    }

    UploadQueueBubble {
        id: uploadQueueBubble
    }

    // 用户信息弹窗：鼠标悬停在 userButton 上时显示
    UserInfoPopup {
        id: userInfoPopup
        anchorItem: userButton
    }

    FeedBackManager {
        id: idFeedBackManager
    }
    Loader{
        id: userFeedBackPanelLoader
        active: editorABConfig.asyncLoadComponent===false?true:false
        sourceComponent: userFeedBackPanelComponent
    }
    Component {
        id: userFeedBackPanelComponent
    UserFeedBackPanel {
        id: userFeedBackPanel
        feedBackManager: idFeedBackManager

        Component.onCompleted: {
            locationManager.fetchCountryCode()
        }

        Connections {
            target: idFeedBackManager
            
            function onDetectedNoNetwork() {
                toast.showToast(qsTr("pccut_feedback_no_network"))
            }
            
            function onRequestTooFrequent() {
                toast.showToast(qsTr("pccut_feedback_frequent"))
            }
                        
            function onDetectedNoNetworkSingle() {
                toast.showToast(qsTr("pccut_feedback_no_network"))
            }
            
            function onRequestTooFrequentSingle() {
                toast.showToast(qsTr("pccut_feedback_frequent"))
            }
            function onUploadFailed() {
                toast.showToast(qsTr("pccut_feedback_log_fail"))
            }
            
        }
    }
    }


    Connections {
        target: globalSignal
        function onShowUserFeedback() {
            eventTracker.trackEvent("pccut_feedback_enter")
            if(userFeedBackPanelLoader.active === false) {
                userFeedBackPanelLoader.active = true
            }
            if(userFeedBackPanelLoader.item) {
                userFeedBackPanelLoader.item.open()
            }
        }
    }

    RowLayout {
        id: optionButtonLayout
        spacing: 16
        anchors {
            verticalCenter: parent.verticalCenter
            right: CommonUtils.isWindows(
                       ) ? windowsButtonsRow.left : parent.right
            rightMargin: 8
        }
        visible: true

        // 设置
        IconButton {
            width: 20
            height: 20
            visible: false
            Layout.alignment: Qt.AlignVCenter
            hoverColor: Colors.transparent
            pressedColor: Colors.transparent
            iconSource: "qrc:/icons/icon_setting.svg"
            hoverIconSource: "qrc:/icons/icon_setting_hover.svg"
            isHoverEnabled: true
        }

        // 灵感粗剪后台任务图标（收至后台时显示）
        IconButton {
            id: roughCutBgIcon
            width: 20
            height: 20
            disabled: !appBarViewModel.roughCutInBackground
            Layout.alignment: Qt.AlignVCenter
            iconMargins: 0
            hoverColor: Colors.transparent
            pressedColor: Colors.transparent
            disabledIconSource: "qrc:/icons/roughcut/AIRoughCutDisabledIcon.svg"
            iconSource: appBarViewModel.roughCutTaskFinished ? "qrc:/icons/roughcut/AIRoughCutFinishedIcon.svg" : "qrc:/icons/roughcut/loading_base.svg"
            isHoverEnabled: true
            hoverTextFunc: function() {
                return qsTr("pccut_roughcut_title");
            }
            onClicked: {
                roughCutBgBubble.close()
                appBarViewModel.restoreRoughCutFromBackground()
            }

            // 扫光动画（任务进行中，仅在图标形状内显示）
            Item {
                id: shimmerEffect
                anchors.fill: parent
                visible: appBarViewModel.roughCutInBackground && !appBarViewModel.roughCutTaskFinished

                Image {
                    id: shimmerMaskSource
                    source: "qrc:/icons/roughcut/loading_base.svg"
                    anchors.fill: parent
                    visible: false
                }

                Item {
                    id: shimmerSource
                    anchors.fill: parent
                    visible: false

                    Rectangle {
                        id: shimmer
                        width: 16
                        height: parent.height
                        x: -width

                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: Colors.color_transparent }
                            GradientStop { position: 0.5; color: Colors.color_A24FE2 }
                            GradientStop { position: 1.0; color: Colors.color_transparent }
                        }

                        SequentialAnimation on x {
                            running: shimmerEffect.visible
                            loops: Animation.Infinite
                            NumberAnimation {
                                from: -shimmer.width
                                to: shimmerEffect.width
                                duration: 1800
                                easing.type: Easing.InOutQuad
                            }
                            PauseAnimation {
                                duration: 500
                            }
                        }
                    }
                }

                OpacityMask {
                    anchors.fill: parent
                    source: shimmerSource
                    maskSource: shimmerMaskSource
                }
            }

            // 四角星跳动旋转动画（任务进行中）
            Image {
                id: loadingStar
                source: "qrc:/icons/roughcut/loading_star.svg"
                width: 13
                height: 13
                visible: appBarViewModel.roughCutInBackground && !appBarViewModel.roughCutTaskFinished
                x: 10
                property real restY: -3
                y: restY
                scale: 1.0
                transformOrigin: Item.Center

                SequentialAnimation {
                    running: loadingStar.visible
                    loops: Animation.Infinite

                    // 上升：y上移 + 旋转到90 + 放大到1.2
                    ParallelAnimation {
                        NumberAnimation {
                            target: loadingStar
                            property: "y"
                            to: loadingStar.restY - 3
                            duration: 500
                            easing.type: Easing.OutCubic
                        }
                        NumberAnimation {
                            target: loadingStar
                            property: "rotation"
                            from: 0
                            to: 90
                            duration: 500
                            easing.type: Easing.OutCubic
                        }
                        NumberAnimation {
                            target: loadingStar
                            property: "scale"
                            from: 1.0
                            to: 1.2
                            duration: 500
                            easing.type: Easing.OutCubic
                        }
                    }

                    // 下落：y回位 + 旋转到180 + 缩回1.0
                    ParallelAnimation {
                        NumberAnimation {
                            target: loadingStar
                            property: "y"
                            to: loadingStar.restY
                            duration: 500
                            easing.type: Easing.InQuad
                        }
                        NumberAnimation {
                            target: loadingStar
                            property: "rotation"
                            from: 90
                            to: 180
                            duration: 500
                            easing.type: Easing.InQuad
                        }
                        NumberAnimation {
                            target: loadingStar
                            property: "scale"
                            from: 1.2
                            to: 1.0
                            duration: 500
                            easing.type: Easing.InQuad
                        }
                    }

                    // 底部停留1秒
                    PauseAnimation {
                        duration: 1000
                    }
                }
            }
            // 当前任务是否已展示过气泡（只在首次收起时弹）
            property bool _bubbleShownForCurrentTask: false

            Connections {
                target: appBarViewModel
                function onRoughCutInBackgroundChanged() {
                    if (appBarViewModel.roughCutInBackground && !roughCutBgIcon._bubbleShownForCurrentTask) {
                        roughCutBgIcon._bubbleShownForCurrentTask = true
                        roughCutBgBubble.show()
                    }
                }
                function onRoughCutTaskStarted() {
                    roughCutBgIcon._bubbleShownForCurrentTask = false
                }
            }

            // 收至后台提示气泡（Popup 渲染在 overlay 层，不会被其他 UI 遮挡）
            Popup {
                id: roughCutBgBubble
                width: bgBubbleText.implicitWidth + 24
                height: 32 + 6  // 气泡 + 箭头高度
                padding: 0
                closePolicy: Popup.NoAutoClose
                modal: false

                // 定位：图标正下方
                x: (parent.width - width) / 2
                y: parent.height + 4

                background: Item {}

                contentItem: Item {
                    // 顶部小三角（指向上方图标）
                    Canvas {
                        id: bubbleArrow
                        width: 10
                        height: 6
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        property color arrowColor: Colors.color_EEEEEE
                        onArrowColorChanged: requestPaint()
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            ctx.fillStyle = String(arrowColor)
                            ctx.beginPath()
                            ctx.moveTo(0, 6)
                            ctx.lineTo(5, 0)
                            ctx.lineTo(10, 6)
                            ctx.closePath()
                            ctx.fill()
                        }
                    }

                    // 气泡主体
                    Rectangle {
                        id: bubbleBody
                        anchors.top: bubbleArrow.bottom
                        anchors.topMargin: -1
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 32
                        radius: 4
                        color: Colors.color_EEEEEE

                        Text {
                            id: bgBubbleText
                            anchors.centerIn: parent
                            text: qsTr("pccut_task_minimized_tip")
                            color: Colors.color_1F2021
                            font.pixelSize: 12
                        }
                    }

                    // 用 Translate 做上下晃动
                    transform: Translate { id: bubbleShift; y: 0 }
                }

                // 晃动动画（上下摇摆3次）
                SequentialAnimation {
                    id: shakeAnim
                    loops: 3
                    NumberAnimation {
                        target: bubbleShift
                        property: "y"
                        from: 0
                        to: 4
                        duration: 300
                        easing.type: Easing.InOutQuad
                    }
                    NumberAnimation {
                        target: bubbleShift
                        property: "y"
                        from: 4
                        to: 0
                        duration: 300
                        easing.type: Easing.InOutQuad
                    }
                    onFinished: bgBubbleTimer.restart()
                }

                // 2s 后消失
                Timer {
                    id: bgBubbleTimer
                    interval: 2000
                    onTriggered: roughCutBgBubble.close()
                }

                function show() {
                    bubbleShift.y = 0
                    open()
                    shakeAnim.start()
                }
            }
        }

        // 教程入口
        IconButton {
            width: 20
            height: 20
            visible: !QmlConstants.isWhiteXtra()
            Layout.alignment: Qt.AlignVCenter
            iconMargins: 0
            hoverColor: Colors.transparent
            pressedColor: Colors.transparent
            iconSource: "qrc:/app_qrc/icons/ic_guide_tutorial.svg"
            // hoverIconSource: "qrc:/app_qrc/icons/icon_feedback_hover.svg"
            isHoverEnabled: true
            hoverTextFunc: function() {
                return qsTr("pccut_guide_tutorial");
            }
            onClicked: {
                Qt.openUrlExternally(QmlConstants.officialWebTutorial())
            }
        }

        // 意见反馈
        IconButton {
            width: 20
            height: 20
            visible: !QmlConstants.isWhiteXtra()
            Layout.alignment: Qt.AlignVCenter
            iconMargins: 0
            hoverColor: Colors.transparent
            pressedColor: Colors.transparent
            iconSource: "qrc:/app_qrc/icons/icon_feedback.svg"
            hoverIconSource: "qrc:/app_qrc/icons/icon_feedback_hover.svg"
            isHoverEnabled: true
            hoverTextFunc: function() {
                return qsTr("pccut_feedback");
            }
            onClicked: {
                eventTracker.trackEvent("pccut_feedback_enter")
                if(userFeedBackPanelLoader.active === false){
                    userFeedBackPanelLoader.active = true
                }
                if(userFeedBackPanelLoader.item) {
                    userFeedBackPanelLoader.item.open()
                }
            }
        }

        // 用户登录
        IconButton {
            id: userButton
            width: 20
            height: 20
            visible: !QmlConstants.isWhiteXtra()
            Layout.alignment: Qt.AlignVCenter
            iconMargins: 0
            hoverColor: Colors.transparent
            pressedColor: Colors.transparent
            iconSource: userLoginViewModel.isLoggedIn
                ? ""
                : (control.userLoginOnboarded ? "qrc:/app_qrc/icons/icon_user.svg" : "qrc:/app_qrc/icons/icon_user_onboarding.svg")
            hoverIconSource: userLoginViewModel.isLoggedIn
                ? ""
                : (control.userLoginOnboarded ? "qrc:/app_qrc/icons/icon_user_hover.svg" : "qrc:/app_qrc/icons/icon_user_onboarding_hover.svg")
            isHoverEnabled: true
            hoverTextFunc: function() {
                return userLoginViewModel.isLoggedIn ? "" : qsTr("pccut_login_account_tip")
            }

            onHoveredChanged: {
                if (!userLoginViewModel.isLoggedIn) {
                    return
                }
                if (hovered) {
                    userLoginViewModel.refreshUserProfile()
                    userInfoPopup.keepAlive()
                    if (!userInfoPopup.visible) {
                        userInfoPopup.showAt()
                    }
                } else {
                    // hover 离开：请求延迟关闭（给鼠标移动到面板的缓冲时间）
                    userInfoPopup.requestHide()
                }
            }

            onClicked: {
                // 首次红点显示，setting保存状态
                if (!control.userLoginOnboarded) {
                    lightSetting.save("user_login_onboarded", true)
                    control.userLoginOnboarded = true
                }

                if (userLoginViewModel.isLoggedIn) {
                    // 已登录：点击只做"保活+确保显示"，绝不关闭（避免一点就消失）
                    userInfoPopup.keepAlive()
                    if (!userInfoPopup.visible) {
                        userInfoPopup.showAt()
                    }
                } else {
                    // 未登录：弹出登录弹窗
                    if (!userLoginPopupLoader.active) {
                        userLoginPopupLoader.active = true
                    }
                    if (userLoginPopupLoader.item) {
                        userLoginPopupLoader.item.open()
                    }
                    // 暂停播放
                    logger.d("editorManager.pause()")
                    editorManager.pause();
                    // 埋点上报
                    userLoginViewModel.reportLoginPopup("top_bar")
                }
            }

            // 已登录头像 overlay：20×20 圆形，覆盖在 IconButton 之上。
            // 无 MouseArea → hover/点击事件穿透到下层 IconButton 的 MouseArea，
            // 复用既有 onHoveredChanged/onClicked 逻辑，零重复。
            Item {
                anchors.fill: parent
                visible: userLoginViewModel.isLoggedIn

                Image {
                    id: appBarAvatar
                    anchors.fill: parent
                    source: userLoginViewModel.avatarPath !== ""
                        ? userLoginViewModel.avatarPath
                        : "qrc:/app_qrc/icons/icon_default_avatar.svg"
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    // Retina/高 DPI:按物理像素解码,否则被放大发虚(devicePixelRatio 跨 mac/Win 通用)
                    sourceSize: Qt.size(20 * Screen.devicePixelRatio, 20 * Screen.devicePixelRatio)
                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: 20
                            height: 20
                            radius: 10
                        }
                    }
                }

                // 悬停态：白 10% 圆形蒙层（设计稿 layer 28051:070397）
                Rectangle {
                    anchors.fill: parent
                    radius: 10
                    color: "#1aFFFFFF"
                    visible: userButton.hovered
                }
            }
        }

        // 已删除：批量选择按钮已移到 DeviceView/CopiedView，与"原片"/"高光"按钮同行
        // // 批量选择
        // IconTextButton {
        //     id: multipleSelectDeviceBtn
        //     usePreferredWidth: true
        //     Layout.preferredWidth: 84
        //     Layout.preferredHeight: 26
        //
        //     title: qsTr("pccut_device_batch_selection")
        //     titleColorNormal: Colors.color_FFFFFF
        //     iconPathNormal: "qrc:/app_qrc/icons/multiple_select.svg"
        //     backgroundColorNormal: Colors.color_button_background_normal
        //     backgroundColorHover: Colors.color_button_background_hovered
        //     isTextOnly: false
        //     internalSpacing: 4
        //     leftPadding: 6
        //     rightPadding: 6
        //     onCustomClicked: {
        //         globalSignal.deviceClickMultipleSelectBtn()
        //     }
        // }

        // 导出按钮组（队列 + 导出）
        Row {
            id: exportButtonGroup
            spacing: 8
            Layout.alignment: Qt.AlignVCenter

            // 导出队列
            ExportListButton {
                id: exportListButton
                objectName: "exportListButton"
                anchors.verticalCenter: parent.verticalCenter
                showFinishImage: exportTabView.showFinishImage
                // 云相册任务队列（含上传/下载）需功能开关 + 灰度可用 + 已同意协议；否则恢复旧导出队列形态
                readonly property bool cloudQueueEnabled: control.cloudTaskQueueEnabled
                showHistoryDot: cloudQueueEnabled
                                && control.taskQueueHasHistoryDot(taskQueueBadgeVM.navHistoryDots)
                exportCount: cloudQueueEnabled
                             ? control.taskQueueBadgeCount(taskQueueBadgeVM.navActiveCounts)
                             : exportTabView.exportCount
                pausedFailedCount: cloudQueueEnabled
                                   ? control.taskQueueBadgeCount(taskQueueBadgeVM.navPausedFailedCounts)
                                   : 0
                onClicked: {
                    logger.d("exportListButton clicked")
                    if (cloudQueueEnabled) {
                        control.openTaskQueue()
                        eventTracker.trackEvent("pccut_task_queue_open")
                        return
                    }

                    if (exportListButton.itemProgress !== 0
                            && exportListButton.itemProgress !== 360) {
                        exportTabView.changeTabIndex()
                    }
                    exportTabView.open()
                    eventTracker.trackEvent("pccut_export_task_tab")
                }
            }

            // 导出按钮
            Rectangle {
                id: exportRectangle
                objectName:actionableItemName.appBarExportRectangle
                anchors.verticalCenter: parent.verticalCenter
                width: 16 + 8 * 2 + menuExportText.width + 4
                height: 26
                color: (exportArea.containsMouse && enabled) ? ColorsConfig.color_F44C65_6DFFD3 : ColorsConfig.color_brand
                radius: RadiusConfig.radius_6_88
                Accessible.role: Accessible.Button
                Accessible.description: "filmexport_exportentrance"
                opacity: enabled ? 1.0 : 0.2

            visible: {
                // 高光功能开关
                if (highlightManager.highlightSupport) {
                    return true;
                }
                return draftManager.currentDraft === -1 ? false : true;
            }
            enabled: {
                // 高光功能开关
                if (highlightManager.highlightSupport) {
                    return draftManager.currentDraft === -1 ? control.devicePageEnableExport : true;
                }
                return true;
            }

                Image {
                    id: exportImage
                    width: 16
                    height: 16
                    anchors {
                        left: parent.left
                        leftMargin: 8
                        verticalCenter: parent.verticalCenter
                    }
                    source: "qrc:/app_qrc/icons/btn_export.svg"
                    sourceSize: Qt.size(16, 16)
                }

                Text {
                    id: menuExportText
                    anchors {
                        left: exportImage.right
                        leftMargin: 4
                        verticalCenter: parent.verticalCenter
                    }
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                    color: ColorsConfig.color_FFFFFF_000000
                    text: qsTr("pccut_menu_export")
                }

                MouseArea {
                    id: exportArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        if (!parent.enabled) {
                            return;
                        }
                        globalSignal.clickExportAction()
                        if(editorManager.isInUserGuideStatus){
                            globalSignal.allGuideFinish();
                        }
                    }
                }
            }
        }
    }
    MenuBarPopupLayers {
        id: appMenuBarLayers
        anchors.fill: parent
    }
    FileDialog {
        id: importFileDialog
        fileMode: FileDialog.OpenFiles
        property int importOperationType
        nameFilters: [ fileOperator.fileSuffixes() ]
        onAccepted: {
            globalSignal.importMedia(currentFiles, importOperationType)
            importOperationType = -1
        }

        onRejected: {
            importOperationType = -1
        }

        Connections {
            target: globalSignal
            function onSetImportOperationType(operationType) {
                importFileDialog.importOperationType = operationType
            }
        }
    }
    Action {
        id:newProjectAction
        text: qsTr("pccut_menu_create")
        enabled: isAvailable
        shortcut:"Ctrl+N"
        onTriggered: {
            // 编程式触发（非键盘），显式跳过窗口隔离：菜单点击不受 focusWindow 影响
            ShortcutObserver.shortcutActivated(ShortcutAction.NEW_PROJECT,"newProject", false)
        }
    }
    Action {
        id:importAction
        text: qsTr("pccut_menu_import")
        enabled: isAvailable && (draftManager.currentDraft !== -1)
        shortcut:"Ctrl+I"
        onTriggered: {
            ShortcutObserver.shortcutActivated(ShortcutAction.IMPORT,"import", false)
        }
    }
    Action {
        id:exportActionMain
        text: qsTr("pccut_menu_export")
        enabled: isAvailable && (draftManager.currentDraft !== -1)
        shortcut: CommonUtils.isWindows() ? ShortcutConfig.actionString(ShortcutAction.EXPORT) : ""
        onTriggered: {
            ShortcutObserver.shortcutActivated(ShortcutAction.EXPORT,"export", false)
        }

    }
    Connections {
        target: ShortcutConfig
        function onShortcutsChanged() {
            exportActionMain.shortcut = ""
            exportActionMain.shortcut = ShortcutConfig.actionString(ShortcutAction.EXPORT)
        }
    }

    Component {
        id: menuPopupComponent
        LightMenu {
            id: menuPopup
            enabled: isAvailable
            LightMenu {
                menuWidth:180
                title: qsTr("pccut_menu_file")
                enabled: isAvailable

                Action {
                    text: qsTr("pccut_menu_create")
                    enabled: isAvailable
                    shortcut:"Ctrl+N"
                    onTriggered: {
                        ShortcutObserver.shortcutActivated(ShortcutAction.NEW_PROJECT,"newProject", false)
                    }
                }
                Action {
                    text: qsTr("pccut_menu_import")
                    enabled: isAvailable && (draftManager.currentDraft !== -1)
                    shortcut:"Ctrl+I"
                    onTriggered: {
                        globalSignal.setImportOperationType(MediaListViewModel.Menubar)
                        ShortcutObserver.shortcutActivated(ShortcutAction.IMPORT,"import", false)
                    }
                }
                Action {
                    id:exportAction
                    text: qsTr("pccut_menu_export")
                    enabled: isAvailable && (draftManager.currentDraft !== -1)
                    shortcut: CommonUtils.isWindows() ? ShortcutConfig.actionString(ShortcutAction.EXPORT) : ""
                    onTriggered: {
                        ShortcutObserver.shortcutActivated(ShortcutAction.EXPORT,"export", false)
                    }
                }
                Connections {
                    target: ShortcutConfig
                    function onShortcutsChanged() {
                        exportAction.shortcut = ""
                        exportAction.shortcut = ShortcutConfig.actionString(ShortcutAction.EXPORT)
                    }
                }
            }

            onVisibleChanged: {
                if (fileOperator.isRelease()) {
                    menuPopup.removeMenu(debugMenu);
                }

                if (!visible) {
                    // 主菜单关闭时检测关闭所有子菜单
                    for (var i = 0; i < count; i++) {
                        var item = itemAt(i);
                        if (item && item.subMenu && item.subMenu.visible) {
                            item.subMenu.close();
                        }
                    }
                }
            }
            LightMenu {
                id:test
                menuWidth:180
                title: qsTr("pccut_menu_edit")
                enabled: isAvailable
                onAboutToShow: {
                    // 在菜单即将显示时进行动态判断
                    undo.enabled = UndoController.canUndo && (draftManager.currentDraft !== -1)
                    redo.enabled = UndoController.canRedo && (draftManager.currentDraft !== -1)
                    test.y = parent.y
                }
                Action {
                    id:undo
                    text: qsTr("pccut_menu_undo")
                    shortcut:"Ctrl+Z"
                    onTriggered: {
                        ShortcutObserver.shortcutActivated(ShortcutAction.UN_DO,"Undo", false)
                        eventTracker.trackEvent("pccut_undo_click", {"use_method": "shortcut"})
                        var projectId = draftManager.activeProjectEnvId();
                        UsedFunctionManager.undo(projectId)

                    }
                }
                Action {
                    id:redo
                    text: qsTr("pccut_menu_redo")
                    shortcut:"Ctrl+Shift+Z"
                    onTriggered: {
                        ShortcutObserver.shortcutActivated(ShortcutAction.RE_DO,"Redo", false)
                        eventTracker.trackEvent("pccut_redo_click", {"use_method": "shortcut"})
                        var projectId = draftManager.activeProjectEnvId();
                        UsedFunctionManager.redo(projectId)
                    }
                }
            }
            LightMenu {
                menuWidth:180
                title: qsTr("pccut_menu_preference_settings")
                enabled: isAvailable
                Action {
                    text: qsTr("pccut_navigation_preference_global_setting_title")
                    onTriggered: {
                        popupAndProhibit(0, 1)
                    }
                }
                Action {
                    text: qsTr("pccut_project_modify_settings")
                    // 项目设置依赖 SettingPanel（仅编辑器页存在）+ 已打开草稿，
                    // 无草稿时置灰，避免首页点击静默无反应（与导入/导出一致）
                    enabled: isAvailable && (draftManager.currentDraft !== -1)
                    onTriggered: {
                        editorManager.pause()
                        globalSignal.clickProxySuggestPopup()
                    }
                }
                Action {
                    text: qsTr("pccut_shortcut")
                    onTriggered: {
                        popupAndProhibit(3, 2)
                    }
                }
                LightMenu {
                    id: preferencesLanguageSubmenu
                    menuWidth:180
                    title: qsTr("pccut_menu_language")
                    enabled: isAvailable
                    showCheckable:true
                    Action {
                        text: qsTr("pccut_menu_language_default")
                        property string code: ""
                        enabled: isAvailable
                        checked: translationHandler.currentCode === code
                        onTriggered: {
                            macMenuBarLayers.showLanguagePop(code)
                        }
                    }
                    Action {
                        text: "简体中文"
                        property string code: "zh"
                        enabled: isAvailable
                        checked: translationHandler.currentCode === code
                        onTriggered: {
                            macMenuBarLayers.showLanguagePop(code)
                        }
                    }
                    Action {
                        text: "繁體中文"
                        property string code: "zh_Hant"
                        enabled: isAvailable
                        checked: translationHandler.currentCode === code
                        onTriggered: {
                            macMenuBarLayers.showLanguagePop(code)
                        }
                    }
                    Action {
                        text: "English"
                        property string code: "en"
                        enabled: isAvailable
                        checked: translationHandler.currentCode === code
                        onTriggered: {
                            macMenuBarLayers.showLanguagePop(code)
                        }
                    }
                    Action {
                        text: "Français"
                        property string code: "fr"
                        enabled: isAvailable
                        checked: translationHandler.currentCode === code
                        onTriggered: {
                            macMenuBarLayers.showLanguagePop(code)
                        }
                    }
                    Action {
                        text: "日本語"
                        property string code: "ja"
                        enabled: isAvailable
                        checked: translationHandler.currentCode === code
                        onTriggered: {
                            macMenuBarLayers.showLanguagePop(code)
                        }
                    }
                    Action {
                        text: "Deutsch"
                        property string code: "de"
                        enabled: isAvailable
                        checked: translationHandler.currentCode === code
                        onTriggered: {
                            macMenuBarLayers.showLanguagePop(code)
                        }
                    }
                    Action {
                        text: "한국어"
                        property string code: "ko"
                        enabled: isAvailable
                        checked: translationHandler.currentCode === code
                        onTriggered: {
                            macMenuBarLayers.showLanguagePop(code)
                        }
                    }
                    Action {
                        text: "Español"
                        property string code: "es"
                        enabled: isAvailable
                        checked: translationHandler.currentCode === code
                        onTriggered: {
                            macMenuBarLayers.showLanguagePop(code)
                        }
                    }
                    Action {
                        text: "Türkçe"
                        property string code: "tr"
                        enabled: isAvailable
                        checked: translationHandler.currentCode === code
                        onTriggered: {
                            macMenuBarLayers.showLanguagePop(code)
                        }
                    }
                    Action {
                        text: "ภาษาไทย"
                        property string code: "th"
                        enabled: isAvailable
                        checked: translationHandler.currentCode === code
                        onTriggered: {
                            macMenuBarLayers.showLanguagePop(code)
                        }
                    }
                    Action {
                        text: "Русский"
                        property string code: "ru"
                        enabled: isAvailable
                        checked: translationHandler.currentCode === code
                        onTriggered: {
                            macMenuBarLayers.showLanguagePop(code)
                        }
                    }
                    Action {
                        text: "Português"
                        property string code: "pt"
                        enabled: isAvailable
                        checked: translationHandler.currentCode === code
                        onTriggered: {
                            macMenuBarLayers.showLanguagePop(code)
                        }
                    }
                    Action {
                        text: "Polski"
                        property string code: "pl"
                        enabled: isAvailable
                        checked: translationHandler.currentCode === code
                        onTriggered: {
                            macMenuBarLayers.showLanguagePop(code)
                        }
                    }
                    Action {
                        text: "Italiano"
                        property string code: "it"
                        enabled: isAvailable
                        checked: translationHandler.currentCode === code
                        onTriggered: {
                            macMenuBarLayers.showLanguagePop(code)
                        }
                    }
                    Action {
                        text: "Bahasa Indonesia"
                        property string code: "id"
                        enabled: isAvailable
                        checked: translationHandler.currentCode === code
                        onTriggered: {
                            macMenuBarLayers.showLanguagePop(code)
                        }
                    }
                }
            }


            LightMenu {
                menuWidth:180
                title: qsTr("pccut_menu_help")
                enabled: isAvailable
                Action {
                    text: qsTr("pccut_menu_help")
                    onTriggered: {
                        Qt.openUrlExternally(QmlConstants.officicalWebHelp())
                    }
                }
                Action {
                    text: qsTr("pccut_menu_feedback")
                    onTriggered: {
                        eventTracker.trackEvent("pccut_feedback_enter")
                        if(userFeedBackPanelLoader.active === false) {
                            userFeedBackPanelLoader.active = true
                        }
                        if(userFeedBackPanelLoader.item) {
                            userFeedBackPanelLoader.item.open()
                        }
                    }
                }
                Action {
                    text: qsTr("pccut_guide_quick")
                    onTriggered: {
                        draftManager.addNewDraft();
                        globalSignal.openUserGuide();
                        // globalSignal.enableMenuBar(false);
                        // editorManager.isInUserGuideStatus = true;
                        menuPopup.close();
                    }
                }
                Action {
                    text: qsTr("pccut_guide_tutorial")
                    onTriggered: {
                        Qt.openUrlExternally(QmlConstants.officialWebTutorial())
                    }
                }
                Action {
                    text: qsTr("pccut_account_delete_title")
                    // visible: userLoginViewModel.isLoggedIn
                    enabled: userLoginViewModel.isLoggedIn
                    onTriggered: {
                        userLoginViewModel.deleteAccount();
                        userLoginViewModel.reportAccountDelete("top_menu");
                    }
                }
            }

            LightMenu { // debug
                id: debugMenu
                menuWidth:180
                title: "DEBUG";

                LogManager {
                    id: logManager
                }

                Action {
                    text: "[DEBUG] 打开数据存储文件夹"
                    onTriggered: {
                        fileOperator.openAppDataFile();
                    }
                }

                Action {
                    text: "[DEBUG] 打开此次执行log"
                    onTriggered: {
                        fileOperator.openLogPath();
                    }
                }
                Action {
                    text: "[DEBUG] 打开此次底层执行log"
                    onTriggered: {
                        fileOperator.openMKLogPath();
                    }
                }

                Action {
                    text: "[DEBUG] 打开日志入口"
                    onTriggered: {
                        logManager.collect();
                        fileOperator.openExportLogPath();
                    }
                }

                LightMenu {
                    menuWidth: 220
                    title: "[DEBUG] 模拟崩溃"
                    Action {
                        text: "[Bugly] 空指针崩溃"
                        onTriggered: fileOperator.testCrashNullPointer()
                    }
                    Action {
                        text: "[Bugly] 除零崩溃"
                        onTriggered: fileOperator.testCrashDivByZero()
                    }
                    Action {
                        text: "[Bugly] 栈溢出崩溃"
                        onTriggered: fileOperator.testCrashStackOverflow()
                    }
                    Action {
                        text: "[Bugly] FastFail崩溃"
                        onTriggered: fileOperator.testCrashFastFail()
                    }
                    Action {
                        text: "[Bugly] 非法参数崩溃(strcpy_s)"
                        onTriggered: fileOperator.testCrashInvalidParam()
                    }
                    Action {
                        text: "[Bugly] Purecall崩溃"
                        onTriggered: fileOperator.testCrashPurecall()
                    }
                    Action {
                        text: "[Bugly] abort崩溃(FullDump)"
                        onTriggered: fileOperator.testCrashAbort()
                    }
                    Action {
                        text: "[Bugly] 非崩溃Dump上报"
                        onTriggered: fileOperator.testNonCrashDump()
                    }
                    Action {
                        text: "[Bugly] 触发基建SDK Monitor崩溃"
                        onTriggered: fileOperator.testMonitorCrash()
                    }
                    Action {
                        text: "[Bugly] 触发自定义错误上报"
                        onTriggered: fileOperator.testCustomErrorReport()
                    }
                    Action {
                        text: "[Bugly] 触发错误文件上报"
                        onTriggered: fileOperator.testCustomErrorFileReport()
                    }
                    Action {
                        text: "[Bugly] 主动日志上传测试"
                        onTriggered: fileOperator.testDiagnoseUploadLogs()
                    }
                }

                Action {
                    text: "[DEBUG] 恢复草稿"
                    enabled: true
                    onTriggered: {
                        globalSignal.selectDraftFile();
                    }
                }

                Action {
                    property bool discardFrame: lightSetting.getBool("debug_key_preview_discard_frame", true)
                    property bool hasTriggered: false
                    property string menuText: discardFrame ? "[DEBUG] 预览丢帧:是" : "[DEBUG] 预览丢帧:否"
                    text: hasTriggered ? menuText + "(重启生效)" : menuText;
                    onTriggered: {
                        lightSetting.save("debug_key_preview_discard_frame", !discardFrame);
                        discardFrame = !discardFrame;
                        hasTriggered = true;
                    }
                }

                Action {
                    property bool showdebuginfo: editorManager.debugStatus
                    property string menuText: editorManager.debugStatus ? "[DEBUG] 关闭调试" : "[DEBUG] 开启调试"
                    text: menuText
                    enabled: true
                    onTriggered: {
                        showdebuginfo = !showdebuginfo;
                        editorManager.setDebugStatus(showdebuginfo);
                    }
                }

                Action {
                    property bool updateTestEnv: lightSetting.getBool("updateTestEnv", false)
                    property string menuText: updateTestEnv ? "[DEBUG] 当前测试环境" : "[DEBUG] 当前正式环境"
                    text: menuText
                    enabled: true
                    onTriggered: {
                        updateTestEnv = !updateTestEnv;
                        lightSetting.save("updateTestEnv", updateTestEnv);
                        globalSignal.restart();
                    }
                }

                Action {
                    property bool isEU: locationManager.isInEURegion
                    text: isEU ? "[DEBUG] 当前 EU(切换为 CN)" : "[DEBUG] 当前非 EU(切换为 AT)"
                    enabled: true
                    onTriggered: {
                        locationManager.setCountryCodeForDebug(isEU ? "CN" : "AT");
                    }
                }

                Action {
                    id: denoiseAlgoAction
                    property bool forceTraditional: lightSetting.getBool("debug_key_denoise_force_traditional", false)
                    text: forceTraditional ? "[DEBUG] 降噪算法: 传统算法(强制)" : "[DEBUG] 降噪算法: NN算法(跟随白名单)"
                    enabled: true
                    onTriggered: {
                        forceTraditional = !forceTraditional;
                        lightSetting.save("debug_key_denoise_force_traditional", forceTraditional);
                        globalSignal.denoiseForceTraditionalChanged(forceTraditional);
                    }
                }

                Connections {
                    target: globalSignal
                    function onDenoiseForceTraditionalChanged(value) {
                        denoiseAlgoAction.forceTraditional = value;
                    }
                }

                Action {
                    property bool showdebuginfo: lightSetting.getBool("tkHeadToggle", true)
                    property string menuText: showdebuginfo ? "[DEBUG] 关闭追头" : "[DEBUG] 开启追头"
                    text: menuText
                    enabled: true
                    onTriggered: {
                        showdebuginfo = !showdebuginfo;
                        lightSetting.save("tkHeadToggle", showdebuginfo);
                    }
                }

                Action {
                    property bool useMachineSelfieMetaData: lightSetting.getBool("useMachineSelfieMetaData", true)
                    property string menuText: useMachineSelfieMetaData ? "[DEBUG] 自拍视角不用机内高光数据" : "[DEBUG] 自拍视角用机内高光数据"
                    text: menuText
                    enabled: true
                    onTriggered: {
                        useMachineSelfieMetaData = !useMachineSelfieMetaData;
                        lightSetting.save("useMachineSelfieMetaData", useMachineSelfieMetaData);
                    }
                }

                Action {
                    property bool showEventFilter: globalEventFilter.isOpen()
                    property string menuText: showEventFilter ? "[DEBUG] 关闭EventFilter" : "[DEBUG] 开启EventFilter"
                    text: menuText
                    enabled: true
                    onTriggered: {
                        showEventFilter = !showEventFilter;
                        if (showEventFilter) {
                            globalEventFilter.open();
                        } else {
                            globalEventFilter.close();
                        }
                    }
                }

                Action {
                    text: appBarViewModel.inspectorActive ? "[DEBUG] 关闭qml路径调试" : "[DEBUG] 开启qml路径调试"
                    enabled: true
                    onTriggered: {
                        appBarViewModel.toggleInspector();
                    }
                }

                Action {
                    text: "[DEBUG] 打开QML调试窗口"
                    enabled: true
                    onTriggered: {
                        appBarViewModel.openDebugWindow();
                    }
                }

                Action {
                    text: "[DEBUG] 打开 UIComponent Gallery"
                    enabled: true
                    onTriggered: lightWindow.galleryDebugManager.open()
                }
                
                Action {
                    text: "[DEBUG] 立即跑分"
                    enabled: true
                    onTriggered: {
                        machineGradingManager.debugRunBenchmark();
                    }
                }

                Action {
                    text: "[DEBUG] 灵感粗剪开关（AB测试）（当前：" + (appBarViewModel.roughCutSupport ? "开" : "关") + "）"
                    enabled: true
                    onTriggered: {
                        appBarViewModel.toggleRoughCutSupport();
                    }
                }

                Action {
                    property bool showRemaining: lightSetting.getBool("debug_ai_roughcut_show_remaining", false)
                    text: "[DEBUG] 灵感粗剪剩余次数显示（当前：" + (showRemaining ? "开" : "关") + "）"
                    enabled: true
                    onTriggered: {
                        showRemaining = !showRemaining;
                        lightSetting.save("debug_ai_roughcut_show_remaining", showRemaining);
                    }
                }

                LightMenu {
                    title: "[DEBUG] 灵感粗剪每日限制次数（当前：" + aiRoughCutManager.config.dailyLimit + "）"
                    enabled: true

                    Action {
                        text: "不限频(-1)"
                        onTriggered: aiRoughCutManager.config.setDebugDailyLimit(-1)
                    }
                    Action {
                        text: "2次"
                        onTriggered: aiRoughCutManager.config.setDebugDailyLimit(2)
                    }
                    Action {
                        text: "6次(默认)"
                        onTriggered: aiRoughCutManager.config.setDebugDailyLimit(6)
                    }
                    Action {
                        text: "10次"
                        onTriggered: aiRoughCutManager.config.setDebugDailyLimit(10)
                    }
                }

                LightMenu {
                    title: "[DEBUG] 灵感粗剪错误模拟"
                    enabled: true

                    Action {
                        text: "模拟：分析超时（可重试）"
                        onTriggered: appBarViewModel.debugSimulateRoughCutError(AppBarViewModel.SimError_JobTimeout)
                    }
                    Action {
                        text: "模拟：解析失败（可重试）"
                        onTriggered: appBarViewModel.debugSimulateRoughCutError(AppBarViewModel.SimError_Unknown)
                    }
                    Action {
                        text: "模拟：素材内容问题（退出）"
                        onTriggered: appBarViewModel.debugSimulateRoughCutError(AppBarViewModel.SimError_ParamInvalid)
                    }
                    Action {
                        text: "模拟：远端执行失败（退出）"
                        onTriggered: appBarViewModel.debugSimulateRoughCutError(AppBarViewModel.SimError_JobExecuteFailed)
                    }
                }

                LightMenu {
                    title: "[DEBUG] 高光分析调试"
                    enabled: true

                    Action {
                        text: "高光开关（AB测试 && GPU支持）（当前：" + (highlightManager.highlightSupport ? "开" : "关") + "）"
                        enabled: true
                        onTriggered: {
                            highlightManager.highlightSupport = !highlightManager.highlightSupport;
                        }
                    }

                    LightMenu {
                        title: "构图方案"
                        enabled: true

                        Action {
                            text: (highlightManager.analyzeSolution == 0 ? "[✓]" : "[ ]") + "不处理"
                            enabled: true
                            onTriggered: {
                                highlightManager.analyzeSolution = 0;
                            }
                        }
                        Action {
                            text: (highlightManager.analyzeSolution == 1 ? "[✓]" : "[ ]") + "方案1：仅16:9参数(100, 0.6) 畸变更小，横向构图更好，主体突出"
                            enabled: true
                            onTriggered: {
                                highlightManager.analyzeSolution = 1;
                            }
                        }
                        Action {
                            text: (highlightManager.analyzeSolution == 2 ? "[✓]" : "[ ]") + "方案2：根据画幅比例选择 16:9(100, 0.6)、9:16(100, 1)、1:1(110, 0.7) 三套参数"
                            enabled: true
                            onTriggered: {
                                highlightManager.analyzeSolution = 2;
                            }
                        }
                        Action {
                            text: (highlightManager.analyzeSolution == 3 ? "[✓]" : "[ ]") + "方案3：仅1:1参数(110, 0.7) 畸变更小，兼顾横竖构图，主体略小"
                            enabled: true
                            onTriggered: {
                                highlightManager.analyzeSolution = 3;
                            }
                        }
                    }

                    LightMenu {
                        title: "视角调整方案"
                        enabled: true

                        Action {
                            text: (highlightManager.offsetAngleSolution == 0 ? "[✓]" : "[ ]") + "方案A：全量平移（所有关键帧统一偏移）"
                            enabled: true
                            onTriggered: {
                                highlightManager.offsetAngleSolution = 0;
                            }
                        }
                        Action {
                            text: (highlightManager.offsetAngleSolution == 1 ? "[✓]" : "[ ]") + "方案B：局部调整（仅调整当前位置相邻关键帧）"
                            enabled: true
                            onTriggered: {
                                highlightManager.offsetAngleSolution = 1;
                            }
                        }
                        Action {
                            text: (highlightManager.offsetAngleSolution == 2 ? "[✓]" : "[ ]") + "方案C：绝对值反算（从filter读取反算offsetParams）"
                            enabled: true
                            onTriggered: {
                                highlightManager.offsetAngleSolution = 2;
                            }
                        }
                        Action {
                            text: (highlightManager.offsetAngleSolution == 3 ? "[✓]" : "[ ]") + "方案D：按帧位置精确差值（保存每帧快照）"
                            enabled: true
                            onTriggered: {
                                highlightManager.offsetAngleSolution = 3;
                            }
                        }
                    }

                    Action {
                        text: "高光任务使用前一次的缓存加速分析（当前：" + (highlightManager.enableTaskCache ? "开" : "关") + "）"
                        enabled: true
                        onTriggered: {
                            highlightManager.enableTaskCache = !highlightManager.enableTaskCache;
                        }
                    }
                    
                    Action {
                        text: "高光数量copy翻倍（测试UI布局、主题）"
                        enabled: true
                        onTriggered: {
                            highlightManager.debugDuplicateHighlight();
                        }
                    }
                    
                    Action {
                        text: "删除所有高光（包括缓存）"
                        enabled: true
                        onTriggered: {
                            highlightManager.debugDeleteAllHighlight();
                        }
                    }
                    
                    Action {
                        text: "模拟任务失败（所有任务都返回失败，持续10秒）"
                        enabled: true
                        onTriggered: {
                            highlightManager.debugMockTaskFailed();
                        }
                    }
                }

                LightMenu {
                    title: "[DEBUG] 云相册功能开关"
                    enabled: true
                    id: cloudAlbumDebugMenu

                    property string networkHost: lightSetting.getString("debug_cloud_album_network_host", QmlConstants.cloudAlbumHostUlanProd())
                    property bool forceBetaView: lightSetting.getBool("debug_force_cloud_album_beta_view", false)
                    property bool forceGuideStepsView: lightSetting.getBool("debug_force_cloud_album_guide_steps_view", false)

                    onAboutToShow: {
                        forceBetaView = lightSetting.getBool("debug_force_cloud_album_beta_view", false)
                        forceGuideStepsView = lightSetting.getBool("debug_force_cloud_album_guide_steps_view", false)
                    }

                    function currentNetworkLabel() {
                        switch (networkHost) {
                        case QmlConstants.cloudAlbumHostHangzhouDev():
                            return "杭州-开发"
                        case QmlConstants.cloudAlbumHostHangzhouTest():
                            return "杭州-测试"
                        case QmlConstants.cloudAlbumHostHangzhouPreProd():
                            return "杭州-PRE-PROD"
                        case QmlConstants.cloudAlbumHostUlanDev():
                            return "乌兰-开发"
                        case QmlConstants.cloudAlbumHostUlanTest():
                            return "乌兰-测试"
                        case QmlConstants.cloudAlbumHostUlanPreProd():
                            return "乌兰-预发"
                        case QmlConstants.cloudAlbumHostUlanPayPreProd():
                            return "乌兰支付-pre-prod"
                        case QmlConstants.cloudAlbumHostUlanProd():
                            return "乌兰-生产"
                        default:
                            return networkHost
                        }
                    }

                    function networkActionText(label, host) {
                        return (networkHost === host ? "[✓] " : "[ ] ") + label + "    " + host
                    }

                    function setNetworkHost(host) {
                        networkHost = host
                        lightSetting.save("debug_cloud_album_network_host", host)
                        globalSignal.restart()
                    }

                    function setForceBetaView(enabled) {
                        forceBetaView = enabled
                        if (enabled) {
                            forceGuideStepsView = false
                            lightSetting.save("debug_force_cloud_album_guide_steps_view", false)
                        }
                        lightSetting.save("debug_force_cloud_album_beta_view", enabled)
                        globalSignal.cloudAlbumDebugRefreshBenefit()
                    }

                    function setForceGuideStepsView(enabled) {
                        forceGuideStepsView = enabled
                        if (enabled) {
                            forceBetaView = false
                            lightSetting.save("debug_force_cloud_album_beta_view", false)
                        }
                        lightSetting.save("debug_force_cloud_album_guide_steps_view", enabled)
                        globalSignal.cloudAlbumDebugRefreshBenefit()
                    }

                    Action {
                        text: "总开关（当前：" + (cloudAlbumFeatureFlags.enable ? "开" : "关") + "）"
                        enabled: true
                        onTriggered: {
                            cloudAlbumFeatureFlags.enable = !cloudAlbumFeatureFlags.enable
                        }
                    }
                    Action {
                        text: "高光标签（当前：" + (cloudAlbumFeatureFlags.highlightEnable ? "开" : "关") + "）"
                        enabled: true
                        onTriggered: {
                            cloudAlbumFeatureFlags.highlightEnable = !cloudAlbumFeatureFlags.highlightEnable
                        }
                    }
                    Action {
                        text: "新建相册（当前：" + (cloudAlbumFeatureFlags.createAlbumEnable ? "开" : "关") + "）"
                        enabled: true
                        onTriggered: {
                            cloudAlbumFeatureFlags.createAlbumEnable = !cloudAlbumFeatureFlags.createAlbumEnable
                        }
                    }
                    Action {
                        text: "去订阅（当前：" + (cloudAlbumFeatureFlags.subscribeEnable ? "开" : "关") + "）"
                        enabled: true
                        onTriggered: {
                            cloudAlbumFeatureFlags.subscribeEnable = !cloudAlbumFeatureFlags.subscribeEnable
                        }
                    }
                    Action {
                        text: "强制显示内测资格申请页（当前：" + (cloudAlbumDebugMenu.forceBetaView ? "开" : "关") + "）"
                        enabled: true
                        onTriggered: {
                            cloudAlbumDebugMenu.setForceBetaView(!cloudAlbumDebugMenu.forceBetaView)
                        }
                    }
                    Action {
                        text: "强制显示权益领取页（当前：" + (cloudAlbumDebugMenu.forceGuideStepsView ? "开" : "关") + "）"
                        enabled: true
                        onTriggered: {
                            cloudAlbumDebugMenu.setForceGuideStepsView(!cloudAlbumDebugMenu.forceGuideStepsView)
                        }
                    }

                    LightMenu {
                        title: "切换网络环境（当前：" + cloudAlbumDebugMenu.currentNetworkLabel() + "，需重启生效）"
                        enabled: true

                        Action {
                            text: cloudAlbumDebugMenu.networkActionText("杭州-开发", QmlConstants.cloudAlbumHostHangzhouDev())
                            enabled: true
                            onTriggered: {
                                cloudAlbumDebugMenu.setNetworkHost(QmlConstants.cloudAlbumHostHangzhouDev())
                            }
                        }
                        Action {
                            text: cloudAlbumDebugMenu.networkActionText("杭州-测试", QmlConstants.cloudAlbumHostHangzhouTest())
                            enabled: true
                            onTriggered: {
                                cloudAlbumDebugMenu.setNetworkHost(QmlConstants.cloudAlbumHostHangzhouTest())
                            }
                        }
                        Action {
                            text: cloudAlbumDebugMenu.networkActionText("杭州-PRE-PROD", QmlConstants.cloudAlbumHostHangzhouPreProd())
                            enabled: true
                            onTriggered: {
                                cloudAlbumDebugMenu.setNetworkHost(QmlConstants.cloudAlbumHostHangzhouPreProd())
                            }
                        }
                        Action {
                            text: cloudAlbumDebugMenu.networkActionText("乌兰-开发", QmlConstants.cloudAlbumHostUlanDev())
                            enabled: true
                            onTriggered: {
                                cloudAlbumDebugMenu.setNetworkHost(QmlConstants.cloudAlbumHostUlanDev())
                            }
                        }
                        Action {
                            text: cloudAlbumDebugMenu.networkActionText("乌兰-测试", QmlConstants.cloudAlbumHostUlanTest())
                            enabled: true
                            onTriggered: {
                                cloudAlbumDebugMenu.setNetworkHost(QmlConstants.cloudAlbumHostUlanTest())
                            }
                        }
                        Action {
                            text: cloudAlbumDebugMenu.networkActionText("乌兰-预发", QmlConstants.cloudAlbumHostUlanPreProd())
                            enabled: true
                            onTriggered: {
                                cloudAlbumDebugMenu.setNetworkHost(QmlConstants.cloudAlbumHostUlanPreProd())
                            }
                        }
                        Action {
                            text: cloudAlbumDebugMenu.networkActionText("乌兰支付-pre-prod", QmlConstants.cloudAlbumHostUlanPayPreProd())
                            enabled: true
                            onTriggered: {
                                cloudAlbumDebugMenu.setNetworkHost(QmlConstants.cloudAlbumHostUlanPayPreProd())
                            }
                        }
                        Action {
                            text: cloudAlbumDebugMenu.networkActionText("乌兰-生产", QmlConstants.cloudAlbumHostUlanProd())
                            enabled: true
                            onTriggered: {
                                cloudAlbumDebugMenu.setNetworkHost(QmlConstants.cloudAlbumHostUlanProd())
                            }
                        }
                    }

                    Action {
                        property bool active: lightSetting.getBool("debug_mock_storage_1gb", false)
                        text: "模拟剩余空间1G（当前：" + (active ? "开" : "关") + "）"
                        enabled: true
                        onTriggered: {
                            active = !active
                            lightSetting.save("debug_mock_storage_1gb", active)
                            globalSignal.cloudAlbumDebugRefreshBenefit()
                        }
                    }
                    Action {
                        property bool active: lightSetting.getBool("debug_mock_membership_expiring_20d", false)
                        text: "模拟会员还有20天到期（当前：" + (active ? "开" : "关") + "）"
                        enabled: true
                        onTriggered: {
                            active = !active
                            lightSetting.save("debug_mock_membership_expiring_20d", active)
                            if (active) lightSetting.save("debug_mock_membership_expired_20d", false)
                            globalSignal.cloudAlbumDebugRefreshBenefit()
                        }
                    }
                    Action {
                        property bool active: lightSetting.getBool("debug_mock_membership_expired_20d", false)
                        text: "模拟会员已过期20天（当前：" + (active ? "开" : "关") + "）"
                        enabled: true
                        onTriggered: {
                            active = !active
                            lightSetting.save("debug_mock_membership_expired_20d", active)
                            if (active) lightSetting.save("debug_mock_membership_expiring_20d", false)
                            globalSignal.cloudAlbumDebugRefreshBenefit()
                        }
                    }
                }

                Action {
                    property bool isProEnv: lightSetting.getBool("useProdEventTrackHost", false)
                    text: "[DEBUG] 当前" + (isProEnv ? "正式" : "测试") + "环境埋点(需重启)"
                    enabled: true
                    onTriggered: {
                        lightSetting.save("useProdEventTrackHost", !isProEnv);
                        globalSignal.restart();
                    }
                }

                LightMenu {
                    title: "[DEBUG] 性能追踪与调试"
                    enabled: isAvailable

                    Action {
                        property bool trackingStatsEnabled: lightSetting.getBool("trackingStatsEnabled", false)
                        property string menuText: trackingStatsEnabled ? "关闭追踪统计" : "开启追踪统计"
                        text: menuText
                        enabled: true
                        onTriggered: {
                            trackingStatsEnabled = !trackingStatsEnabled;
                            lightSetting.save("trackingStatsEnabled", trackingStatsEnabled);
                        }
                    }

                    Action {
                        text: "导出追踪数据"
                        enabled: true
                        onTriggered: {
                            globalSignal.exportTrackingStats();
                        }
                    }

                    Action {
                        property bool showTkSpeedUpFeature: lightSetting.getBool("showTkSpeedUpFeature", false)
                        property string menuText: showTkSpeedUpFeature ? "隐藏倍速TK功能" : "显示倍速TK功能"
                        text: menuText
                        enabled: true
                        onTriggered: {
                            showTkSpeedUpFeature = !showTkSpeedUpFeature;
                            lightSetting.save("showTkSpeedUpFeature", showTkSpeedUpFeature);
                        }
                    }
                }

                Action {
                    property bool useTrackingPreview: editorManager.tkPreviewStatus
                    property string menuText: useTrackingPreview ? "[DEBUG] 关闭实时追踪预览" : "[DEBUG] 开启实时追踪预览"
                    text: menuText
                    enabled: true
                    onTriggered: {
                        editorManager.tkPreviewStatus = !useTrackingPreview;
                        globalSignal.switchTrackingPreview();
                    }
                }

                Action {
                    id: lagButton
                    text: "[DEBUG] 模拟卡顿(Sleep 2s)"
                    enabled: true
                    onTriggered: {
                        //globalSignal.freezeByWaitLock();
                        keepAliveEventFilter.SetSimulateLag();
                    }
                }
                
                Action {
                    text: "[DEBUG] 模拟转场替换失败"
                    onTriggered: {
                        globalSignal.toast(qsTr("pccut_resource_transition_replace_fail"), "tracks")
                    }
                }

                Action {
                    id: freezedButton
                    text: "[DEBUG] 模拟卡死(Sleep 20s)"
                    enabled: true
                    onTriggered: {
                        //globalSignal.freezeBySlowFunction();
                        keepAliveEventFilter.SetSimulateFreezed();
                    }
                }
                Action {
                    id: unresponsiveButton
                    text: "[DEBUG] 模拟窗口无响应 8s"
                    enabled: true
                    onTriggered: {
                        keepAliveEventFilter.SetSimulateUnresponsive();
                    }
                }
                Action {
                    property bool isSimulating: false
                    text: isSimulating ? "[DEBUG] 停止模拟渲染线程卡死" : "[DEBUG] 模拟渲染线程卡死"
                    enabled: true
                    onTriggered: {
                        isSimulating = !isSimulating;
                        if (isSimulating) {
                            keepAliveEventFilter.setSimulateRenderFreezed();
                        } else {
                            keepAliveEventFilter.stopSimulateRenderFreezed();
                        }
                     }
                }
                Action {
                    property bool mockExportFail: lightSetting.getBool("mockExportFail", false)
                    property string menuText: mockExportFail ? "[DEBUG] 当前开启模拟导出失败" : "[DEBUG] 当前关闭模拟导出失败"
                    text: menuText
                    enabled: true
                    onTriggered: {
                        lightSetting.save("mockExportFail", !mockExportFail);
                        globalSignal.restart();
                    }
                }

                LightMenu {
                    title: "[DEBUG] 模拟 OOM 崩溃"
                    enabled: isAvailable
                    Action {
                        text: "模拟显式 OOM 崩溃"
                        enabled: true
                        onTriggered: {
                            console.log("模拟显式 OOM 崩溃")
                            sdkTestDialog.methodIndex = 0
                            globalSignal.mockExplicitOomCrash();
                        }
                    }
                    Action {
                        text: "模拟隐式 OOM 崩溃"
                        enabled: true
                        onTriggered: {
                            console.log("模拟隐式 OOM 崩溃")
                            sdkTestDialog.methodIndex = 1
                            globalSignal.mockImplicitOomCrash();
                        }
                    }
                }

                LightMenu {
                    title: "[DEBUG] ASAN 内存错误测试"
                    enabled: isAvailable
                    Action {
                        text: "堆缓冲区溢出 (heap-buffer-overflow)"
                        enabled: true
                        onTriggered: {
                            console.log("测试: 堆缓冲区溢出")
                            globalSignal.testAsanHeapBufferOverflow();
                        }
                    }
                    Action {
                        text: "栈缓冲区溢出 (stack-buffer-overflow)"
                        enabled: true
                        onTriggered: {
                            console.log("测试: 栈缓冲区溢出")
                            globalSignal.testAsanStackBufferOverflow();
                        }
                    }
                    Action {
                        text: "释放后使用 (use-after-free)"
                        enabled: true
                        onTriggered: {
                            console.log("测试: 堆释放后使用")
                            globalSignal.testAsanUseAfterFree();
                        }
                    }
                    Action {
                        text: "重复释放 (double-free)"
                        enabled: true
                        onTriggered: {
                            console.log("测试: 重复释放")
                            globalSignal.testAsanDoubleFree();
                        }
                    }
                    Action {
                        text: "全局缓冲区溢出 (global-buffer-overflow)"
                        enabled: true
                        onTriggered: {
                            console.log("测试: 全局缓冲区溢出")
                            globalSignal.testAsanGlobalBufferOverflow();
                        }
                    }
                    Action {
                        text: "作用域后使用 (use-after-scope)"
                        enabled: true
                        onTriggered: {
                            console.log("测试: 作用域后使用")
                            globalSignal.testAsanUseAfterScope();
                        }
                    }
                }

                LightMenu {
                    id: fulldumpMenu
                    title: "[DEBUG] Fulldump 截取配置"

                    property bool fulldumpEnabled: true

                    onAboutToShow: {
                        fulldumpEnabled = lightSetting.getBool("key_fulldump_enabled", true)
                    }

                    Action {
                        text: "[DEBUG] 打开Fulldump路径"
                        onTriggered: { fileOperator.openFullDumpPath() }
                    }

                    Action {
                        text: fulldumpMenu.fulldumpEnabled ? "[DEBUG] 关闭fulldump功能" : "[DEBUG] 开启fulldump功能"
                        onTriggered: {
                            fulldumpMenu.fulldumpEnabled = !fulldumpMenu.fulldumpEnabled
                            fileOperator.setFulldumpEnabled(fulldumpMenu.fulldumpEnabled)
                        }
                    }
                }

                LightMenu {
                    id: exportDebugMenuWin
                    title: "[DEBUG] 导出"

                    property double currentMock: lightSetting.getDouble("debug_disk_mock_available_mb", -1)

                    function setMock(val) {
                        lightSetting.save("debug_disk_mock_available_mb", val);
                        currentMock = val;
                    }

                    LightMenu {
                        title: "模拟导出剩余空间 (" + (exportDebugMenuWin.currentMock < 0 ? "真实值" : exportDebugMenuWin.currentMock + " MB") + ")"

                        Action {
                            text: (exportDebugMenuWin.currentMock < 0 ? "✓ " : "   ") + "真实值"
                            onTriggered: exportDebugMenuWin.setMock(-1)
                        }
                        Action {
                            text: (exportDebugMenuWin.currentMock === 100 ? "✓ " : "   ") + "100 MB"
                            onTriggered: exportDebugMenuWin.setMock(100)
                        }
                        Action {
                            text: (exportDebugMenuWin.currentMock === 512 ? "✓ " : "   ") + "512 MB"
                            onTriggered: exportDebugMenuWin.setMock(512)
                        }
                        Action {
                            text: (exportDebugMenuWin.currentMock === 1024 ? "✓ " : "   ") + "1024 MB (1GB)"
                            onTriggered: exportDebugMenuWin.setMock(1024)
                        }
                        Action {
                            text: (exportDebugMenuWin.currentMock === 3072 ? "✓ " : "   ") + "3072 MB (3GB)"
                            onTriggered: exportDebugMenuWin.setMock(3072)
                        }
                        Action {
                            text: (exportDebugMenuWin.currentMock === 5120 ? "✓ " : "   ") + "5120 MB (5GB)"
                            onTriggered: exportDebugMenuWin.setMock(5120)
                        }
                        Action {
                            text: (exportDebugMenuWin.currentMock === 10240 ? "✓ " : "   ") + "10240 MB (10GB)"
                            onTriggered: exportDebugMenuWin.setMock(10240)
                        }
                        Action {
                            text: (exportDebugMenuWin.currentMock === 51200 ? "✓ " : "   ") + "51200 MB (50GB)"
                            onTriggered: exportDebugMenuWin.setMock(51200)
                        }
                    }
                }

                Action {
                    text: Instance.debugMarkPointUseAltIcon ? "[DEBUG] 标记标签: 调试图标" : "[DEBUG] 标记标签: 正式图标"
                    onTriggered: {
                        Instance.debugMarkPointUseAltIcon = !Instance.debugMarkPointUseAltIcon;
                    }
                }
                LightMenu {
                    title: "[DEBUG] VideoTranscodeHelper 测试"
                    enabled: true

                    FileDialog {
                        id: vthWinTestDialog
                        nameFilters: ["视频文件 (*.mp4 *.mov *.avi *.mkv *.hevc *.h264 *.m4v *.osv *.lrf *.OSV *.LRF)"]
                        property int testMode: 0   // 0=VideoExport 1=FrameExtract 2=AudioExport 3=PanoVideoExport 4=PanoFrameExtract 5=PanoAudioExport
                        onAccepted: {
                            var path = selectedFile.toString().replace("file:///", "").replace("file://", "")
                            if (testMode === 0) {
                                videoTranscodeHelperTest.testVideoExport(path)
                            } else if (testMode === 1) {
                                videoTranscodeHelperTest.testFrameExtract(path)
                            } else if (testMode === 2) {
                                videoTranscodeHelperTest.testAudioExport(path)
                            } else if (testMode === 3) {
                                videoTranscodeHelperTest.testPanoVideoExport(path)
                            } else if (testMode === 4) {
                                videoTranscodeHelperTest.testPanoFrameExtract(path)
                            } else if (testMode === 5) {
                                videoTranscodeHelperTest.testPanoAudioExport(path)
                            } else if (testMode === 6) {
                                videoTranscodeHelperTest.testCompareExport(path)
                            }
                        }
                    }

                    Action {
                        text: "[DEBUG] 测试 VideoExport（选文件→转 480P 3fps MP4）"
                        enabled: true
                        onTriggered: {
                            vthWinTestDialog.testMode = 0
                            vthWinTestDialog.open()
                        }
                    }
                    Action {
                        text: "[DEBUG] 测试 FrameExtract（选文件→抽 3fps JPEG 序列）"
                        enabled: true
                        onTriggered: {
                            vthWinTestDialog.testMode = 1
                            vthWinTestDialog.open()
                        }
                    }
                    Action {
                        text: "[DEBUG] 测试 AudioExport（选文件→提取音频）"
                        enabled: true
                        onTriggered: {
                            vthWinTestDialog.testMode = 2
                            vthWinTestDialog.open()
                        }
                    }

                    Action {
                        text: "[DEBUG] 测试 PanoVideoExport（选全景文件→转 480P 3fps MP4，fov=100 eyez=1）"
                        enabled: true
                        onTriggered: {
                            vthWinTestDialog.testMode = 3
                            vthWinTestDialog.open()
                        }
                    }
                    Action {
                        text: "[DEBUG] 测试 PanoFrameExtract（选全景文件→抽 3fps JPEG 序列，fov=100 eyez=1）"
                        enabled: true
                        onTriggered: {
                            vthWinTestDialog.testMode = 4
                            vthWinTestDialog.open()
                        }
                    }
                    Action {
                        text: "[DEBUG] 测试 PanoAudioExport（选全景文件→提取音频，fov=100 eyez=1）"
                        enabled: true
                        onTriggered: {
                            vthWinTestDialog.testMode = 5
                            vthWinTestDialog.open()
                        }
                    }

                    Action {
                        text: "[DEBUG] 对比导出清晰度（方案A:3fps 1Mbps vs 方案B:30fps 10Mbps 10x快进）"
                        enabled: true
                        onTriggered: {
                            vthWinTestDialog.testMode = 6
                            vthWinTestDialog.open()
                        }
                    }
                }
                LightMenu {
                    title: "[DEBUG] 设置底层LOGLevel"
                    enabled: true
                    Action {
                        text: "默认(error)"
                        enabled: true
                        onTriggered: {
                            crashTrackHelper.setMltLogLevel(16);
                        }
                    }
                    Action {
                        text: "warning"
                        enabled: true
                        onTriggered: {
                            crashTrackHelper.setMltLogLevel(24);
                        }
                    }
                    Action {
                        text: "info"
                        enabled: true
                        onTriggered: {
                            crashTrackHelper.setMltLogLevel(32);
                        }
                    }
                    Action {
                        text: "debug"
                        enabled: true
                        onTriggered: {
                            crashTrackHelper.setMltLogLevel(48);
                        }
                    }
                }
                LightMenu {
                    id: panoDebugOsdMenu
                    title: "[DEBUG] 开关画面OSD"
                    enabled: true
                    property bool osdEnabled: false
                    onAboutToShow: {
                        osdEnabled = lightSetting.getBool("panoDebugOsd", false)
                    }
                    Action {
                        text: panoDebugOsdMenu.osdEnabled ? "[DEBUG] 关闭画面OSD" : "[DEBUG] 开启画面OSD"
                        enabled: true
                        onTriggered: {
                            panoDebugOsdMenu.osdEnabled = !panoDebugOsdMenu.osdEnabled
                            lightSetting.save("panoDebugOsd", panoDebugOsdMenu.osdEnabled)
                        }
                    }
                }
            }

            Rectangle {
                color: Colors.color_444444  // 自定义分隔线的颜色
                height: 1      // 自定义分隔线的高度
                width: parent.width - 8  // 自定义分隔线的宽度
                anchors.horizontalCenter: parent.horizontalCenter
                opacity:0.5
                anchors.topMargin:4
                anchors.bottomMargin:4
            }
            Action {
                text: qsTr("pccut_menu_about")
                onTriggered: {
                    popupAndProhibit(0,0)
                }
            }
            Action {
                text: qsTr("pccut_menu_updates")
                onTriggered: {
                    popupAndProhibit(0, 2)
                }
            }

            Rectangle {
                color: Colors.color_444444  // 自定义分隔线的颜色
                height: 1      // 自定义分隔线的高度
                width: parent.width - 8  // 自定义分隔线的宽度
                anchors.horizontalCenter: parent.horizontalCenter
                opacity:0.5
                anchors.topMargin:4
                anchors.bottomMargin:4
            }
            Action {
                text: qsTr("pccut_shortcut_q")
                onTriggered: {
                    globalSignal.quitApp();
                }
            }

            onOpened: {
                menuButton.checked = true;
                globalSignal.windowsMenuOpen(true)
            }

            onClosed: {
                menuButton.checked = false;
                globalSignal.windowsMenuOpen(false)
            }
        }
    }

    Loader {
        id: menuPopLoader
        active: editorABConfig.asyncLoadComponent === false?true:false
        sourceComponent: CommonUtils.isWindows() ? menuPopupComponent : null
    }

    CShortcut {
        action: ShortcutAction.CLOSE_PROJECT

        onActivated: {
            if (draftManager.openedCount === 1) {
                //如果唯一一个页签被关掉了
                tabChanged(-1)
            }
            var id = draftManager.findOpenedDraftIdByIndex(
                        draftManager.currentDraft)
            if (id >= 0) {
                draftManager.closeDraft(draftManager.findOpenedDraftIdByIndex(
                                            draftManager.currentDraft))
            }
        }
    }
}
