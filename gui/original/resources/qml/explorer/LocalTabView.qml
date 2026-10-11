import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.3
import Qt.labs.platform 1.1
import Config 1.0
import MediaListViewModel 1.0
import DeviceMediaListModel 1.0
import Controls 1.0
import UIComponent
import ProjectGenerator 1.0
import QtQuick.Dialogs
import Qt5Compat.GraphicalEffects

import DeviceMediaCategory 1.0
import AlgBizHighLightModel 1.0
import HighLightThemeTabViewModel 1.0

import "../controller"
import "../AiRoughCut"
import app_qrc 1.0

/**
 * @author robert.guo
 * @desc 本地文件面板
 * @create_date 2024-04-11
 */
Item {
    id: tabRoot


    // 根据不同的页面使用 isLocal 来区分是本地素材还是
    property var dataModel
    property MediaListViewModel localMediaViewModel
    property bool isLocal: tabRoot.dataModel.isLocalPage
    property bool isSelectHighlightTab: tabRoot.dataModel.mediaCategoryType == DeviceMediaCategory.Highlight

    property var sourceArray: null
    property var highlightIds: null
    property bool createImport:false

    // 灵感粗剪 Loading 弹窗状态
    property alias draftPopup: draftPopup
    property var source: null
    property bool isFavorate: false

    onVisibleChanged: {
        if (visible) {
            // 因为这个该项目的三个tab共享的, 所以在切换tab的时候刷新一下
            tabRoot.dataModel.isGridModeChanged();
        }
    }

    ProjectGenerator {
        id: projectGenerator
    }

    function scrollToFirstSelected() {
        contentId.scrollToTarget();
    }

    function selectMaterial(id, autoPlay, playedPercentage) {
        contentId.selectMaterial(id, autoPlay, playedPercentage);
        contentId.scrollToTarget();
    }

    function importToLocal(sourceList, highlightIds) { // Finder打开播放器导入素材调此接口
        // 素材先加入到本地素材内
        tabRoot.dataModel.importMedia(sourceList, MediaListViewModel.Finder, highlightIds);
        contentId.scrollToTarget();
    }

    function importToLocalWithFav(source, isFavorite) {
        tabRoot.dataModel.importOneMedia(source, MediaListViewModel.Finder, isFavorite)
        contentId.scrollToTarget()
    }

    function importMedia(files, operationType){
        tabRoot.dataModel.importMedia(files, operationType);
    }

    function realImportMedia(currentFiles) {
        tabRoot.dataModel.importMedia(currentFiles, MediaListViewModel.Importing);
        if(editorManager.isInUserGuideStatus){
            globalSignal.nextStepInAllGuide();
        }
        if (currentFiles.length > 0) {
            var file = currentFiles[0]
            logger.d("FileOperator " + " filePath = " + file)
            fileOperator.checkPermission(file)
        }

    }

    ConfirmPopup {
        id: draftPopup
        title: qsTr("pccut_add_open_project_description")
        leftButtonText: qsTr("pccut_import_current_project")
        rightButtonText: qsTr("pccut_project_label")
        onLeftButtonClicked: {
            if (sourceArray != null) {
                importToLocal(sourceArray, highlightIds ? highlightIds : [])
                sourceArray = null
                highlightIds = null
            }

            if (source != null) {
                importToLocalWithFav(source, isFavorate)
                source = null
                isFavorate = false
            }
        }
        onRightButtonClicked: {
            draftManager.addNewDraft()
            tabRoot.createImport = true;
        }
    }

    Connections {
        target: globalSignal
        function onActivedProjectChanged(draftId){
            if(tabRoot.createImport){
                tabRoot.createImport = false;
                if (sourceArray != null) {
                    importToLocal(sourceArray, highlightIds ? highlightIds : [])
                    sourceArray = null
                    highlightIds = null
                }

                if (source != null) {
                    importToLocalWithFav(source, isFavorate)
                    source = null
                    isFavorate = false
                }
            }
        }

        function onDeviceItemImported(deviceName, target) {
            // 当前页面是设备素材页才响应此信号
            if (isLocal) return
            globalSignal.deviceSelected(deviceName)
            if (draftManager.isInWelcomePage()) {
                draftManager.addNewDraft()
            }

            // 暂时取消播放逻辑，等待产品优化
            // // 等待草稿完全创建后再播放，不然播放器无数据源
            // Qt.callLater(function () {
            //     // 不知道id是哪个，就找第一个id
            //     const ids = tabRoot.dataModel.idForPath(target);
            //     const selectAssetId = ids.length <= 0 ? "" : ids[0];
            //     // 将播放器的播放源切换到目标素材
            //     tabRoot.dataModel.coverEnter(selectAssetId)
            //     tabRoot.dataModel.playedPercentage = 0
            //     tabRoot.dataModel.coverSeek(0)
            //     tabRoot.dataModel.isPlayingChanged()
            //     // 开始播放
            //     tabRoot.dataModel.resume()

            //     contentId.scrollToTarget()
            // })
        }
    }

    Item {
        anchors.fill: parent

        //添加按钮
        // 页面为空的添加按钮
        EmptyPanel {
            objectName: actionableItemName.addMediaPanel
            visible: tabRoot.dataModel.count < 1 && tabRoot.isLocal && !tabRoot.isSelectHighlightTab
            width: 180
            height: 180
            anchors.centerIn: parent
            desc_tip1: qsTr("pccut_shortcut_l")
            desc_tip2: qsTr("pccut_media_empty")
            desc_tip3: qsTr("pccut_media_empty_description")
            color_tip1: Colors.color_EEEEEE
            color_tip2: Colors.color_999999
            color_tip3: Colors.color_999999
            source: "qrc:/icons/media_import.svg"
            sourceSize: Qt.size(44, 44)
            onClick: {
                eventTracker.trackEvent("pccut_local_file_click")
                importFileDialogLoader.openFileDialog();
            }
        }

        // 新的导入按钮
        Rectangle {
            id: addBtn
            height: 28

            // 高光功能开启时显示
            visible: tabRoot.dataModel.isTabsViewVisible && tabRoot.isLocal

            // 高光功能开启时作为新手引导目标
            objectName: tabRoot.dataModel.isTabsViewVisible ? actionableItemName.addMediaButton : ""

            anchors {
                top: parent.top
                topMargin: 16
                left: parent.left
                leftMargin: 12
                right: parent.right
                rightMargin: 12
            }

            radius: 4
            color: addBtnContent.hovered ? ColorsConfig.color_brand_20 : ColorsConfig.color_brand_10

            IconTextButton {
                id: addBtnContent
                anchors.centerIn: parent
                height: 28
                
                title: qsTr("pccut_media_import_add")
                titleFontSize: 12
                titleColorNormal: "#FFF22443"
                titleColorHover: "#FFF22443"

                iconPathNormal: "qrc:/app_qrc/icons/editor_material_add.svg"
                imageRectWidth: 16
                imageRectHeight: 16
                internalSpacing: 3
                leftPadding: (addBtn.width - buttonContentImplicitWidth) / 2
                rightPadding: (addBtn.width - buttonContentImplicitWidth) / 2

                isTextOnly: false
                alignment: Qt.AlignHCenter

                backgroundColorNormal: Colors.transparent
                backgroundColorHover: Colors.transparent
                backgroundColorPressed: Colors.transparent

                onCustomClicked: {
                    tabRoot.dataModel.setIsCancelImport(false)
                    eventTracker.trackEvent("pccut_local_file_click")
                    importFileDialogLoader.openFileDialog()
                }
            }
        }

        //原片/高光Tab
        MediaImportTitleBar {
            id: mediaImportTitleBar
            height: 24
            //anchors.top: parent.top

            anchors {
                top: addBtn.visible ? addBtn.bottom : parent.top
                topMargin: 16
                left: parent.left
                leftMargin: 12
                right: parent.right
                //verticalCenter: parent.verticalCenter
            }
            mediaListViewModel: tabRoot.dataModel
            isLocal: tabRoot.isLocal
            onClickAddFile: {
                tabRoot.dataModel.setIsCancelImport(false)
                eventTracker.trackEvent("pccut_local_file_click")
                importFileDialogLoader.openFileDialog();
            }
        }

        //高光主题Tab
        EnumTabsView {
            id: highLightThemeTab
            anchors {
                top: mediaImportTitleBar.bottom
                topMargin: 12
                left: parent.left
                leftMargin: 12
            }
            spacing: 8
            tabHorizontalPadding: 6
            tabVerticalPadding: 2.5
            visible: tabRoot.isSelectHighlightTab && !tabRoot.dataModel.isHighlightMediaListEmpty
            viewModel: tabRoot.dataModel ? tabRoot.dataModel.highLightThemeTabViewModel : null
        }

        // 新增控件显示高光任务状态，
        // 对MediaImportTitlebar而言topMargin是12，对 MediaSelectedPage anchors 也是 12.

        Item {
            id: highlightStatusTip
            height: 16

            anchors {
                top: mediaImportTitleBar.bottom
                topMargin: 16
                left: parent.left
                leftMargin: 12
                right: parent.right
                rightMargin: 12
            }

            visible: !tabRoot.isSelectHighlightTab && highlightManager.taskCount > 0

            RowLayout {
                anchors.fill: parent
                spacing: 0

                Text {
                    text: highlightManager.taskRunningTips
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    lineHeight: 15
                    lineHeightMode: Text.FixedHeight
                    font.letterSpacing: 0
                    color: "#999999"
                    Layout.alignment: Qt.AlignVCenter
                }

                Item {
                    Layout.fillWidth: true
                }

                IconTextButton {
                    id: cancelAllBtn
                    Layout.alignment: Qt.AlignVCenter
                    height: 16
                    title: qsTr("pccut_highlight_cancel_all")
                    imageRectWidth: 16
                    imageRectHeight: 16
                    titleFontSize: 11
                    titleFontWeight: Font.Medium
                    titleColorNormal: "#EEEEEE"
                    titleColorHover: "#FFFFFF"
                    iconPathNormal: "qrc:/icons/highlight/all_cancel.svg"
                    iconPathHover: "qrc:/icons/highlight/all_cancel_highlight.svg"
                    internalSpacing: 2
                    leftPadding: 0
                    rightPadding: 0
                    backgroundColorNormal: Colors.transparent
                    backgroundColorHover: Colors.transparent
                    isTextOnly: false
                    onCustomClicked: {
                        // 取消所有高光任务
                        highlightManager.cancelAllTasks()
                        highlightManager.eventTrackingCancel("edit");  // 高光分析埋点
                    }
                }
            }
        }

        //导入之后
        MediaSelectedPage {
            id: contentId
            anchors {
                top: !tabRoot.isSelectHighlightTab ?
                    (highlightStatusTip.visible ? highlightStatusTip.bottom : mediaImportTitleBar.bottom) :
                    (highLightThemeTab.visible ? highLightThemeTab.bottom : mediaImportTitleBar.bottom)
                topMargin: 16
                left: parent.left
                right: parent.right
                rightMargin: 6
                bottom: parent.bottom
                bottomMargin: (roughCutToolbar.visible || batchHighlightToolbar.visible) ? 32 : 0
                leftMargin: 6
            }
            mediaListViewModel: tabRoot.dataModel
            isLocal: tabRoot.isLocal
            visible: !isLocal || tabRoot.dataModel.count > 0
            clip: true
            // 硬件素材当点击添加的时候导入到本地素材列表
            onClikAddMedia: (fileList) => {
                if (isLocal) {
                    return;
                }
                tabRoot.localMediaViewModel.importDeviceMedia(fileList);
            }
        }

        // 设备素材加载提示
        Rectangle {
            id: deviceLoadingMask
            anchors.fill: contentId
            color: Colors.color_content_area_background
            visible: !isLocal && tabRoot.dataModel.isLoading !== undefined && tabRoot.dataModel.isLoading
            z: 10
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 12
                Image {
                    width: 48
                    height: 48
                    source: "qrc:/icons/icon_loading.png"
                    sourceSize: Qt.size(48, 48)
                    Layout.alignment: Qt.AlignHCenter
                    RotationAnimation on rotation {
                        from: 0
                        to: 360
                        running: deviceLoadingMask.visible
                        duration: 2000
                        loops: Animation.Infinite
                    }
                }
                Text {
                    text: qsTr("pccut_material_loading")
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    color: Colors.color_EEEEEE
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }

        Rectangle {
            anchors {
                top: mediaImportTitleBar.bottom
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                topMargin: 1
                bottomMargin: 1
                leftMargin: 1
                rightMargin: 1
            }
            color: Colors.color_content_area_background
            visible: tabRoot.isSelectHighlightTab && tabRoot.dataModel.isHighlightMediaListEmpty
        }

        HighlightEmptyPanel {
            id: highlightEmptyPanel
            anchors.centerIn: parent
            visible: tabRoot.isSelectHighlightTab && tabRoot.dataModel.highlightLoadFinish && tabRoot.dataModel.isHighlightMediaListEmpty
        }

        DropArea {
            enabled: isLocal && topPopupCount <= 0
            anchors.fill: parent
            // 拖入时实时过滤
            onEntered: (drag) => {
                const allInvalid = fileOperator.isAllFilesInvalid(drag.urls)
                const hasFolder = fileOperator.hasAnyFolder(drag.urls)
                // 如果所有文件都不支持，则拒绝拖入
                if (allInvalid && !hasFolder) {
                    drag.accepted = false
                }
            }
            onDropped: (drop) => {
                drop.accept();
                if (drop.hasUrls) {
                    const hasFolder = fileOperator.hasAnyFolder(drop.urls)
                    if (hasFolder) {
                        // 走文件夹展开导入流程
                        //只要拖拽的内容中包含文件夹,就按照DragFolder上报埋点
                        dataModel.importMedia(drop.urls, MediaListViewModel.DragFolder)
                    } else {
                        // 原流程不变
                        dataModel.importMedia(drop.urls, MediaListViewModel.Drag)
                    }
                    if (editorManager.isInUserGuideStatus) {
                        globalSignal.nextStepInAllGuide();
                    }
                }
            }
        }

        Loader {
            id: importFileDialogLoader
            active: false
            anchors.fill:parent
            sourceComponent: FileDialog {
                fileMode: FileDialog.OpenFiles
                objectName: actionableItemName.fileDialogForMediaImport
                // 支持的格式
                nameFilters: [ fileOperator.fileSuffixes() ]
                onAccepted: {
                    realImportMedia(currentFiles)
                    importFileDialogLoader.active = false;
                }
            }

            function openFileDialog(){
                importFileDialogLoader.active = true;
                if (importFileDialogLoader.item) {
                    importFileDialogLoader.item.open();
                }
            }
        }

        Connections {
            target: globalSignal
            function onImportMediaFile(currentFiles) {
                realImportMedia(currentFiles)
            }
        }

        // 监听点击背景 (为了做取消选中)
        Item {
            id: bgView
            visible: contentId.visible && tabRoot.dataModel.selectPathSize > 0
            parent: UiUtils.getTopParent(contentId)
            anchors {
                fill: parent
                leftMargin: 5
                rightMargin: 5
                topMargin: 34
                bottomMargin: 5
            }
            PointHandler {
               onGrabChanged: (transition, eventPointValue) => {
                    eventPointValue.accepted = false;
                    if (eventPointValue.timeHeld !== 0) {
                        return;
                    }
                    // mac 触控板设置 轻点来点按, 会有一些魔法数据的回调
                    if (transition === 2 && eventPointValue.timestamp === eventPointValue.pressTimestamp) {
                        return;
                    }
                    if (eventPointValue.pressPosition !== eventPointValue.position) {
                        return
                    }
                    var mousePoint = eventPointValue.position;
                    var point = bgView.mapToItem(mediaImportTitleBar.sortBtn, mousePoint);
                    // 点击了排序按钮
                    var needContinue = true;
                    if (mediaImportTitleBar.sortBtn.contains(point)) {
                        needContinue = false;
                    }
                    // 点击了切换模式
                    point = bgView.mapToItem(mediaImportTitleBar.gridBtn, mousePoint);
                    if (mediaImportTitleBar.gridBtn.contains(point)) {
                        needContinue = false;
                    }
                    // 点击了筛选按钮
                    point = bgView.mapToItem(mediaImportTitleBar.filterBtn, mousePoint);
                    if (mediaImportTitleBar.filterBtn.contains(point)) {
                        needContinue = false;
                    }
                    point = bgView.mapToItem(playerPanel, mousePoint);
                    // 点击了播放器区域
                    if (playerPanel.contains(point)) {
                        needContinue = false;
                    }
                    point = bgView.mapToItem(settingPanel, mousePoint);
                    //点击了设置区域
                    if(settingPanel.contains(point)){
                        needContinue = false;
                    }
                    // 点击了灵感粗剪工具栏
                    if (roughCutToolbar.visible) {
                        point = bgView.mapToItem(roughCutToolbar, mousePoint);
                        if (roughCutToolbar.contains(point)) {
                            needContinue = false;
                        }
                    }
                    if (needContinue) {
                        point = bgView.mapToItem(contentId, mousePoint);
                        var batchBarPoint = bgView.mapToItem(batchHighlightToolbar, mousePoint);
                        if(!batchHighlightToolbar.contains(batchBarPoint) || !batchHighlightToolbar.visible) {
                            if (contentId.contains(point)) {
                                contentId.clickBgView(point);
                            } else {
                                tabRoot.dataModel.resetSelectedAssets();
                            }
                        }
                    }
                }
            }
        }

        // ==================== 批量高光分析工具栏 ====================
        Rectangle {
            id: batchHighlightToolbar
            visible: !tabRoot.isSelectHighlightTab
                     && !tabRoot.dataModel.aiRoughCutSupport
                     && (tabRoot.dataModel.selectedCanHighlightPathAndMd5.length > 1 ||
                         (tabRoot.dataModel.selectedCanHighlightPathAndMd5.length > 0 && tabRoot.dataModel.getSelectedPathList().length > 1))
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }
            height: 32
            z: 100
            color: "#252627"

            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: 12
                    rightMargin: 12
                }
                spacing: 8
                z: 100

                TooltipText {
                    id: batchPromptText
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    text: qsTr("pccut_home_highlight_edit_switch")
                    color: Colors.color_999999
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }

                IconTextButton {
                    id: batchAnalysisButton
                    Layout.alignment: Qt.AlignVCenter
                    height: 20
                    z: 100

                    // 文字配置（按照设计稿）
                    title: qsTr("pccut_panel_adjust_highlights")  // 高光
                    titleFontSize: 11
                    titleFontWeight: Font.Medium
                    titleColorNormal: Colors.color_EEEEEE

                    // 图标配置
                    iconPathNormal: "qrc:/icons/highlight/ic_highlight.svg"
                    imageRectWidth: 16   // 图标容器宽度
                    imageRectHeight: 16  // 图标容器高度
                    iconSize: Qt.size(16, 16)  // 图标实际尺寸
                    isTextOnly: false

                    // 背景配置
                    backgroundColorNormal: "transparent"
                    backgroundColorHover: "transparent"
                    radius: 4  // 圆角 4px

                    // 布局配置（关键 - 居中）
                    alignment: Qt.AlignHCenter  // 图标+文字整体在按钮内居中
                    internalSpacing: 4  // 图标与文字间距 4px
                    topPadding: 2.5
                    bottomPadding: 2.5
                    leftPadding: 7.5
                    rightPadding: 7.5

                    // 自定义 SVG 背景
                    background: RoundedSvgBackground {
                        radius: 4
                        //color: "transparent"
                        //antialiasing: true
                        //clip: true
                        anchors.fill: parent
                        source: batchAnalysisButton.hovered ? "qrc:/icons/highlight/ic_hl_bg_highlight.svg" : "qrc:/icons/highlight/ic_hl_bg.svg"
                    }

                    // 使用 MouseArea 覆盖按钮，捕获 onPressed 事件
                    // 因为按钮在 pressed 时就会消失，所以 onClicked 永远不会触发
                    onCustomClicked: {
                        tabRoot.dataModel.batchStartHighlight();
                    }
                }
            }
        }

        // ==================== 灵感粗剪工具栏 ====================
        RoughCutToolbar {
            id: roughCutToolbar
            isDisabled: !tabRoot.dataModel.canAiRoughCut
            disableReason: tabRoot.dataModel.aiRoughCutDisableReason
            visible: tabRoot.dataModel.aiRoughCutSupport
                     && tabRoot.dataModel.selectPathSize >= 1
                     && !batchHighlightToolbar.visible
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }

            property var cachedAssetIds: []
            onVisibleChanged: {
                if (visible) {
                    cachedAssetIds = tabRoot.dataModel.getSelectedIdList();
                }
            }
            Connections {
                target: tabRoot.dataModel
                function onSelectPathSizeChanged() {
                    if (tabRoot.dataModel.selectPathSize >= 1) {
                        roughCutToolbar.cachedAssetIds = tabRoot.dataModel.getSelectedIdList();
                    }
                }
            }

            onButtonClicked: {
                tabRoot.dataModel.openRoughCutLoadingPanel()
                tabRoot.dataModel.checkLoginBeforeRoughCut(roughCutToolbar.cachedAssetIds);
            }
        }



        LoadingPanelView {
            anchors {
                top: mediaImportTitleBar.bottom
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                topMargin: 1
                bottomMargin: 1
                leftMargin: 1
                rightMargin: 1
            }

            visible: tabRoot.isSelectHighlightTab && !tabRoot.dataModel.highlightLoadFinish
            loadingTextTip: qsTr("pccut_media_loading")
            loadingTextColor: Colors.color_666666
            loadingTextFont.pixelSize: 14
            backgroudColor: Colors.color_content_area_background
        }
    }
}
