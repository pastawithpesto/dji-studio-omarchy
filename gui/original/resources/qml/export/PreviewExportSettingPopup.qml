import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts 1.15
import Qt.labs.platform
import Config 1.0
import Controls 1.0
import VideoConfig 1.0
import PreviewExportSettingViewModel 1.0
import PreviewSourceHandler 1.0
import app_qrc 1.0

import "../controller"
import "../menubar"
import "../export"

/**
 * @brief 预览素材混合导出设置弹窗
 * @details 支持同时导出原片和高光，每种类型独立配置参数
 * @author mark.zhu
 * @date 2026-03-03
 */
LightPopup {
    id: exportPopup

    // ==================== 入口1：预览页 ====================

    /**
     * @brief PreviewSourceHandler 引用
     * @details 从 PreviewSourceHandler 获取当前播放状态和高光列表
     */
    property var sourceHandler: null

    // ==================== UI 控制 ====================

    // 自定义项展开状态（两组独立）
    property bool originalSettingsExpanded: false
    property bool highlightSettingsExpanded: false

    // 勾选的路径中是否存在空间不足 / 空间紧张 / 权限不可访问
    readonly property bool anySpaceInsufficient:
        (previewExportViewModel.exportOriginalEnabled && origSavePathControl.spaceInsufficient)
        || (previewExportViewModel.exportHighlightEnabled && hlSavePathControl.spaceInsufficient)
    readonly property bool anySpaceLow:
        (previewExportViewModel.exportOriginalEnabled && origSavePathControl.spaceLow)
        || (previewExportViewModel.exportHighlightEnabled && hlSavePathControl.spaceLow)
    readonly property bool allPathsAccessible:
        (!previewExportViewModel.exportOriginalEnabled || origSavePathControl.pathAccessible)
        && (!previewExportViewModel.exportHighlightEnabled || hlSavePathControl.pathAccessible)

    // ==================== ViewModel ====================

    // 预览导出 ViewModel（唯一，管理原片+高光两组参数）
    PreviewExportSettingViewModel {
        id: previewExportViewModel
    }

    // ==================== 预编译弹窗组件 ====================

    // 导出确认弹窗（队列式：逐个确认，全部通过后导出）
    Component {
        id: confirmDialogComponent
        ConfirmPopup {
            onClosed: destroy()
            onLeftButtonClicked: {
                _pendingConfirmations = [];
            }
            onRightButtonClicked: {
                processNextConfirmation();
            }
        }
    }

    // 待确认条件队列
    property var _pendingConfirmations: []

    // ==================== UI 配置 ====================

    modal: false
    Overlay.modal: Rectangle {
        color: Colors.transparent
    }
    parent: Overlay.overlay
    width: parent.width
    height: parent.height
    z: 100

    // ==================== 生命周期 ====================

    Component.onCompleted: {
        // 初始化 ViewModel（缓存 sourceHandler 和相关数据）
        previewExportViewModel.init(sourceHandler);
        // 文件名去重（避免与导出队列或本地已有文件冲突）
        previewExportViewModel.deduplicateFileNames();
    }

    onOpened: {
        // 屏蔽底层播放器手势响应，防止事件穿透
        player.playerViewGesture.enabled = false;
        // 获得焦点以接收快捷键事件
        exportPopup.forceActiveFocus();

        // 打印原片导出路径+文件名
        var oriSettings = previewExportViewModel.originalSettings;
        if (oriSettings.fileNameList.length > 0) {
            var oriFullPath = oriSettings.savePath + "/" + oriSettings.fileNameList[0] + oriSettings.fileNameSuffix;
        }

        // 打印高光导出路径+文件名
        var hlSettings = previewExportViewModel.highlightSettings;
        if (hlSettings.fileNameList.length > 0) {
            for (var i = 0; i < hlSettings.fileNameList.length; i++) {
                var hlFullPath = hlSettings.savePath + "/" + hlSettings.fileNameList[i] + hlSettings.fileNameSuffix;
            }
        }

        // 对齐 MacComposePanel：进入导出页，同盘且预测剩余不足 → 应急清理；否则 → 常规清理
        if (!tryEmergencyCleanForExport("onOpened")) {
            autoCacheCleaner();
        }
    }

    onClosed: {
        player.playerViewGesture.enabled = true;
    }

    // ==================== 快捷键处理 ====================

    Keys.onEscapePressed: {
        exportPopup.close();
    }

    // ==================== 核心逻辑函数 ====================

    // 常规清理（统一逻辑见 Config/ExportCacheHelper）
    function autoCacheCleaner() {
        ExportCacheHelper.autoCacheCleaner("[PreviewExport][CacheCleaner]")
    }

    // 预览导出可能同时导出原片+高光、各有保存路径：拼成 targets 交给统一逻辑（内部按同盘过滤+聚合预留）。
    // 返回是否触发了应急，供调用方决定是否走常规清理兜底。scene 仅用于日志区分调用来源。
    function tryEmergencyCleanForExport(scene) {
        var targets = [];
        if (previewExportViewModel.exportOriginalEnabled)
            targets.push({ path: previewExportViewModel.originalSettings.savePath,
                           estimatedMB: previewExportViewModel.originalSettings.estimatedFileSizeMB });
        if (previewExportViewModel.exportHighlightEnabled)
            targets.push({ path: previewExportViewModel.highlightSettings.savePath,
                           estimatedMB: previewExportViewModel.highlightSettings.estimatedFileSizeMB });
        return ExportCacheHelper.tryEmergencyCleanForExport(targets, "[PreviewExport][CacheCleaner]", scene)
    }

    /**
     * @brief 开始导出
     * @note 检查顺序：文件覆盖 → 磁盘空间 → 导出
     *       收集所有需要确认的条件，逐个弹窗，全部通过后导出
     */
    function startExport() {
        // 清除输入框焦点，并显式提交文件名编辑（确保空名恢复）
        contentRect.forceActiveFocus()
        origFileNameControl.commitEdit()
        hlFileNameControl.commitEdit()

        // 至少勾选一个
        if (!previewExportViewModel.exportOriginalEnabled && !previewExportViewModel.exportHighlightEnabled) {
            return;
        }

        // 收集需要用户确认的条件
        let confirmations = [];

        // 1. 文件覆盖
        let hasExisting = false;
        if (previewExportViewModel.exportOriginalEnabled) {
            const origPaths = previewExportViewModel.originalSettings.getFullOutputPaths();
            for (let i = 0; i < origPaths.length; i++) {
                if (fileOperator.isExists(origPaths[i])) { hasExisting = true; break; }
            }
        }
        if (!hasExisting && previewExportViewModel.exportHighlightEnabled) {
            const hlPaths = previewExportViewModel.highlightSettings.getFullOutputPaths();
            for (let i = 0; i < hlPaths.length; i++) {
                if (fileOperator.isExists(hlPaths[i])) { hasExisting = true; break; }
            }
        }
        if (hasExisting) {
            confirmations.push({
                "title": qsTr("pccut_export_still_export_exists"),
                "text": qsTr("pccut_export_still_export_exists_description"),
                "leftButtonText": qsTr("pccut_export_still_export_exists_cancel"),
                "rightButtonText": qsTr("pccut_shortcut_space_customize_warn_cover")
            });
        }

        // 2. 磁盘空间不足
        if (anySpaceInsufficient) {
            confirmations.push({
                "title": qsTr("pccut_export_still_export_low_storage"),
                "leftButtonText": qsTr("pccut_export_still_export_cancel"),
                "rightButtonText": qsTr("pccut_export_still_export")
            });
        }

        if (confirmations.length > 0) {
            _pendingConfirmations = confirmations;
            processNextConfirmation();
            return;
        }

        doExport();
    }

    /**
     * @brief 处理下一个待确认条件，队列为空时执行导出
     */
    function processNextConfirmation() {
        if (_pendingConfirmations.length === 0) {
            doExport();
            return;
        }
        const props = _pendingConfirmations.shift();
        var dialog = confirmDialogComponent.createObject(contentRect, props);
        if (dialog && dialog.hostWindow) {
            dialog.open();
        } else {
            if (dialog) dialog.destroy();
            console.error("Failed to open confirm dialog: no host window");
            doExport();
        }
    }

    /**
     * @brief 执行导出并关闭弹窗
     */
    function doExport() {
        if (previewExportViewModel.exportOriginalEnabled) {
            previewExportViewModel.exportOriginalFile();
        }
        if (previewExportViewModel.exportHighlightEnabled) {
            previewExportViewModel.exportHighlightFiles();
        }
        close();
    }

    // ==================== UI 主体 ====================

    contentItem: Item {
        id: contentItemId
        // 遮罩层
        MouseArea {
            anchors.fill: parent
            onClicked: {
                // 点击遮罩层关闭弹窗
                // exportPopup.close();
            }
        }

        readonly property int expandedHeight: 492
        readonly property int collapsedHeight: 413
        readonly property int warningExtraHeight: 39

        // 主容器
        Rectangle {
            id: contentRect
            anchors.centerIn: parent
            width: 360
            height: {
                const bothEnabled = previewExportViewModel.exportOriginalEnabled && previewExportViewModel.exportHighlightEnabled;
                const oriEnableExpanded = previewExportViewModel.exportOriginalEnabled && originalSettingsExpanded;
                const hlEnableExpanded = previewExportViewModel.exportHighlightEnabled && highlightSettingsExpanded;
                const warningExtra = spaceWarning.visible ? contentItemId.warningExtraHeight : 0;

                if (bothEnabled || oriEnableExpanded || hlEnableExpanded) {
                    return contentItemId.expandedHeight + warningExtra;
                }
                return contentItemId.collapsedHeight + warningExtra;
            }
            radius: 8
            color: Colors.color_2F3032
            border.width: 1
            border.color: Colors.color_454649
            layer.enabled: true

            // 点击内容区不关闭
            MouseArea {
                anchors.fill: parent
                onClicked: {}
            }

            FocusClearArea { }
            // 标题栏
            WindowTitleBar {
                id: titleBar
                width: parent.width
                title: qsTr("pccut_export_settings")
                onCloseClick: {
                    eventTracker.trackEvent("pccut_home_export_close_click");  // 数据埋点
                    exportPopup.close();
                }
            }

            // 滚动内容区
            ScrollView {
                id: scrollView
                anchors {
                    left: parent.left
                    leftMargin: 28
                    right: parent.right
                    rightMargin: 8 // + 滚动条 = 28
                    top: titleBar.bottom
                    topMargin: 24
                    bottom: bottomBar.top
                }

                Component.onCompleted: {
                    scrollView.contentItem.boundsBehavior = Flickable.StopAtBounds;
                }

                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                // ==================== 滚动条配置（不可修改！QTBUG-65853） ====================
                // 注意：Qt 6.5 ScrollBar 的 policy: ScrollBar.AsNeeded 存在缺陷（QTBUG-65853）
                // 当 ScrollBar 自定义了 contentItem 时，AsNeeded policy 会失效，无论如何都会显示或隐藏
                // 因此这里使用显式高度判断来控制 ScrollBar 的显示/隐藏
                ScrollBar.vertical: ScrollBar {
                    policy: scrollContent.implicitHeight > scrollView.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                    anchors {
                        right: parent.right
                        top: parent.top
                        bottom: parent.bottom
                    }

                    contentItem: Rectangle {
                        implicitWidth: 6
                        implicitHeight: 0
                        radius: 3
                        color: Colors.color_454649
                    }
                }

                clip: true
                contentHeight: scrollContent.implicitHeight

                // 滚动区域内容容器
                Column {
                    id: scrollContent
                    width: scrollView.width - 20
                    spacing: 24

                    // ==================== 原片导出区域 ====================

                    Column {
                        width: parent.width
                        spacing: 16

                        // 勾选框和标题
                        LightCheckBox {
                            id: originalCheckBox
                            width: parent.width
                            height: 14
                            anchors.bottomMargin: 4
                            checked: previewExportViewModel.exportOriginalEnabled
                            enabled: previewExportViewModel.hasOriginSelected
                            isDisabled: !previewExportViewModel.hasOriginSelected
                            text: qsTr("pccut_home_export_tab_original").arg(1)
                            onCheckedChanged: {
                                previewExportViewModel.exportOriginalEnabled = checked;
                            }
                        }

                        // 原片导出参数
                        Column {
                            visible: previewExportViewModel.exportOriginalEnabled
                            width: parent.width
                            height: visible ? implicitHeight : 0
                            spacing: 16

                            // 文件名
                            ExportFileNameUnified {
                                id: origFileNameControl
                                width: parent.width
                                height: 28
                                viewModel: previewExportViewModel.originalSettings
                                titleText: qsTr("pccut_export_name")
                            }

                            // 保存路径
                            ExportSavePath {
                                id: origSavePathControl
                                width: parent.width
                                height: 28
                                viewModel: previewExportViewModel.originalSettings
                                titleText: qsTr("pccut_player_screenshot_path")
                                btnText: qsTr("pccut_player_screenshot_modify")
                                onDialogAccepted: function(newPath, isChanged) {
                                    if (previewExportViewModel.originalSettings.enableEventTracking) {
                                        eventTracker.trackEvent("pccut_home_export_change_location", {"is_change": isChanged})
                                    }
                                    // 对齐 MacComposePanel：改保存路径，同盘且预测剩余不足才应急清理
                                    if (isChanged) {
                                        tryEmergencyCleanForExport("dialogAccepted")
                                    }
                                }
                                onDialogRejected: {
                                    if (previewExportViewModel.originalSettings.enableEventTracking) {
                                        eventTracker.trackEvent("pccut_home_export_change_location", {"is_change": false})
                                    }
                                }
                            }

                            // 导出类型（视频/全景视频）
                            ExportTypeSelector {
                                width: parent.width
                                viewModel: previewExportViewModel.originalSettings
                            }

                            // 自定义设置展开按钮
                            Rectangle {
                                width: parent.width
                                height: 28
                                color: Colors.color_transparent

                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 6

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: qsTr("pccut_home_highlight_export_customize")
                                        font.pixelSize: 12
                                        font.weight: Font.DemiBold
                                        color: Colors.color_EEEEEE
                                    }

                                    Image {
                                        width: 16
                                        height: 16
                                        anchors.verticalCenter: parent.verticalCenter
                                        source: originalSettingsExpanded ? "qrc:/icons/ic_triangle_up.svg" : "qrc:/icons/ic_triangle_down.svg"
                                        sourceSize: Qt.size(16, 16)
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        originalSettingsExpanded = !originalSettingsExpanded;
                                    }
                                }
                            }

                            // 自定义参数选择区域
                            Column {
                                visible: originalSettingsExpanded
                                width: parent.width
                                height: visible ? implicitHeight : 0
                                spacing: 16

                                ExportResolution {
                                    width: parent.width
                                    viewModel: previewExportViewModel.originalSettings
                                    titleLeftMargin: 63
                                }

                                ExportFrameRate {
                                    width: parent.width
                                    viewModel: previewExportViewModel.originalSettings
                                    titleLeftMargin: 63
                                }

                                ExportBitrate {
                                    id: originalBitrateControl
                                    width: parent.width
                                    viewModel: previewExportViewModel.originalSettings
                                    titleLeftMargin: 63
                                    scrollContainer: scrollView.contentItem
                                }
                            }
                        }
                    }

                    // ==================== 分隔线 ====================

                    Column {
                        width: parent.width
                        height: implicitHeight
                        spacing: 0

                        Item {
                            width: parent.width
                            height: 8
                        }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: Colors.color_454649
                        }
                    }

                    // ==================== 高光导出区域 ====================

                    Column {
                        width: parent.width
                        spacing: 16

                        // 勾选框和标题
                        LightCheckBox {
                            id: highlightCheckBox
                            width: parent.width
                            height: 14
                            anchors.bottomMargin: 4
                            checked: previewExportViewModel.exportHighlightEnabled
                            text: qsTr("pccut_home_export_tab_hightlight").arg(previewExportViewModel.highlightSettings.fileNameList.length)
                            onCheckedChanged: {
                                previewExportViewModel.exportHighlightEnabled = checked;
                            }
                        }

                        // 高光导出参数
                        Column {
                            visible: previewExportViewModel.exportHighlightEnabled
                            width: parent.width
                            height: visible ? implicitHeight : 0
                            spacing: 16

                            // 批量文件名列表
                            ExportFileNameUnified {
                                id: hlFileNameControl
                                width: parent.width
                                height: implicitHeight
                                viewModel: previewExportViewModel.highlightSettings
                                titleText: qsTr("pccut_export_name")
                            }

                            // 保存路径
                            ExportSavePath {
                                id: hlSavePathControl
                                width: parent.width
                                height: 28
                                viewModel: previewExportViewModel.highlightSettings
                                titleText: qsTr("pccut_player_screenshot_path")
                                btnText: qsTr("pccut_player_screenshot_modify")
                                onDialogAccepted: function(newPath, isChanged) {
                                    if (previewExportViewModel.highlightSettings.enableEventTracking) {
                                        eventTracker.trackEvent("pccut_home_export_change_location", {"is_change": isChanged})
                                    }
                                    // 对齐 MacComposePanel：改保存路径，同盘且预测剩余不足才应急清理
                                    if (isChanged) {
                                        tryEmergencyCleanForExport("dialogAccepted")
                                    }
                                }
                                onDialogRejected: {
                                    if (previewExportViewModel.highlightSettings.enableEventTracking) {
                                        eventTracker.trackEvent("pccut_home_export_change_location", {"is_change": false})
                                    }
                                }
                            }

                            // 导出类型（视频/全景视频）
                            ExportTypeSelector {
                                width: parent.width
                                viewModel: previewExportViewModel.highlightSettings
                            }

                            // 自定义设置展开按钮
                            Rectangle {
                                width: parent.width
                                height: 28
                                color: Colors.color_transparent

                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 6

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: qsTr("pccut_home_highlight_export_customize")
                                        font.pixelSize: 12
                                        font.weight: Font.DemiBold
                                        color: Colors.color_EEEEEE
                                    }

                                    Image {
                                        width: 16
                                        height: 16
                                        anchors.verticalCenter: parent.verticalCenter
                                        source: highlightSettingsExpanded ? "qrc:/icons/ic_triangle_up.svg" : "qrc:/icons/ic_triangle_down.svg"
                                        sourceSize: Qt.size(16, 16)
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        highlightSettingsExpanded = !highlightSettingsExpanded;
                                    }
                                }
                            }

                            // 自定义参数选择区域
                            Column {
                                visible: highlightSettingsExpanded
                                width: parent.width
                                height: visible ? implicitHeight : 0
                                spacing: 16

                                ExportResolution {
                                    width: parent.width
                                    viewModel: previewExportViewModel.highlightSettings
                                    titleLeftMargin: 63
                                }

                                ExportFrameRate {
                                    width: parent.width
                                    viewModel: previewExportViewModel.highlightSettings
                                    titleLeftMargin: 63
                                }

                                ExportBitrate {
                                    id: highlightBitrateControl
                                    width: parent.width
                                    viewModel: previewExportViewModel.highlightSettings
                                    titleLeftMargin: 63
                                    scrollContainer: scrollView.contentItem
                                }
                            }
                        }
                    }
                }
            }

            // 底部按钮栏
            Item {
                id: bottomBar
                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                    leftMargin: 28
                    rightMargin: 28
                }
                height: spaceWarning.visible
                    ? 36 + spaceWarning.height + 16 + Math.max(fileSizeDisplay.height, exportButton.height) + 24
                    : 88

                // 空间警告（顶部边距 36，底部边距 16）
                SpaceWarningTip {
                    id: spaceWarning
                    anchors {
                        left: parent.left
                        top: parent.top
                        topMargin: 36
                    }
                    spaceInsufficient: anySpaceInsufficient
                    spaceLow: anySpaceLow
                }

                // 文件大小显示
                ExportFileSize {
                    id: fileSizeDisplay
                    anchors {
                        left: parent.left
                        bottom: parent.bottom
                        bottomMargin: 24
                    }
                    width: 164
                    height: 33
                    estimatedFileSize: previewExportViewModel.totalEstimatedFileSize
                }

                // 导出按钮
                BaseConfirmBtn {
                    id: exportButton
                    btnText: qsTr("pccut_menu_export")
                    width: 88
                    height: 28
                    type: 0
                    clickEnabled: allPathsAccessible
                    canUse: clickEnabled
                        && (previewExportViewModel.exportOriginalEnabled || previewExportViewModel.exportHighlightEnabled)
                    anchors {
                        right: parent.right
                        bottom: parent.bottom
                        bottomMargin: 24
                    }
                    onCustomClick: () => {
                        eventTracker.trackEvent("pccut_home_export_click",
                            {"use_method": "preview"});
                        startExport();
                    }
                }

                // 取消按钮
                BaseConfirmBtn {
                    id: cancelBtn
                    btnText: qsTr("pccut_draft_delete_popup_cancel")
                    width: 88
                    height: 28
                    type: 1
                    anchors {
                        right: exportButton.left
                        bottom: parent.bottom
                        bottomMargin: 24
                        rightMargin: 8
                    }
                    onCustomClick: () => {
                        eventTracker.trackEvent("pccut_home_export_cancel_click");  // 数据埋点
                        exportPopup.close();
                    }
                }
            }
        }
    }
}
