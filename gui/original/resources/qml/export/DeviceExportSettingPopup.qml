import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts 1.15
import Qt.labs.platform
import Config 1.0
import Controls 1.0
import VideoConfig 1.0
import DeviceExportSettingViewModel 1.0
import app_qrc 1.0

import "../controller"
import "../menubar"
import "../export"

/**
 * @brief 设备素材导出设置弹窗
 * @details 支持2种导出模式：
 *          1. 单个文件导出（原片或高光）
 *          2. 批量文件导出（多个原片或多个高光）
 * @author your-name
 * @date 2026-02-25
 */
LightPopup {
    id: exportPopup

    // ==================== 入口1：设备页 ====================

    /**
     * @brief 文件列表 Model 引用
     * @details DeviceFileInfoModel 实例，用于访问文件信息
     */
    property var deviceFileInfoModel: null
    
    /**
     * @brief 待导出文件id列表
     * @details 每个元素为文件在 deviceFileInfoModel 中的id（_selectedIdList）
     */
    property var selectedIdList: []
    
    // ==================== 入口2：预览页 ====================

    /**
     * @brief PreviewSourceHandler 引用
     * @details 从 PreviewSourceHandler 获取当前播放状态和高光列表
     */
    property var sourceHandler: null

    // ==================== UI 控制 ====================

    // 自定义项展开状态
    property bool customSettingsExpanded: false

    // ==================== ViewModel ====================

    // 设备导出 ViewModel（继承 MediaExportSettingsProtocol，同时提供设备导出业务逻辑）
    DeviceExportSettingViewModel {
        id: deviceExportViewModel

        // 监听批量导出文件类型不一致警告
        onExportTypeInconsistent: {
            // TODO 产品需求仅支持全景视频，后续再支持其他类型
        }
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
        // 初始化 ViewModel（C++ 会自动处理所有参数初始化，包括文件名列表生成）
        if (deviceFileInfoModel != null) {
            deviceExportViewModel.init(deviceFileInfoModel, selectedIdList);
        } else if (sourceHandler != null) {
            deviceExportViewModel.init(sourceHandler);
        }
        // 文件名去重（避免与导出队列或本地已有文件冲突）
        deviceExportViewModel.deduplicateFileNames();
    }

    onOpened: {
        // 获得焦点以接收快捷键事件
        exportPopup.forceActiveFocus();

        // 对齐 MacComposePanel：进入导出页，保存路径同盘且预测剩余不足 → 应急清理；否则 → 常规清理
        if (!tryEmergencyCleanForExport(deviceExportViewModel.savePath, "onOpened")) {
            autoCacheCleaner();
        }
    }

    // ==================== 快捷键处理 ====================

    Keys.onEscapePressed: {
        exportPopup.close();
    }

    // ==================== 核心逻辑函数 ====================

    // 常规清理（统一逻辑见 Config/ExportCacheHelper）
    function autoCacheCleaner() {
        ExportCacheHelper.autoCacheCleaner("[DeviceExport][CacheCleaner]")
    }

    // 按保存路径判断是否需要应急清理（统一逻辑见 ExportCacheHelper）。返回是否触发了应急。
    function tryEmergencyCleanForExport(savePath, scene) {
        return ExportCacheHelper.tryEmergencyCleanForExport(
            [{ path: savePath, estimatedMB: Math.max(0, deviceExportViewModel.estimatedFileSizeMB) }],
            "[DeviceExport][CacheCleaner]", scene)
    }

    /**
     * @brief 开始导出
     * @note 检查顺序：文件覆盖 → 磁盘空间 → 导出
     *       收集所有需要确认的条件，逐个弹窗，全部通过后导出
     */
    function startExport() {
        // 清除输入框焦点，并显式提交文件名编辑（确保空名恢复）
        contentRect.forceActiveFocus()
        fileNameControl.commitEdit()

        // 收集需要用户确认的条件
        let confirmations = [];

        // 1. 文件覆盖
        const outputPaths = deviceExportViewModel.getFullOutputPaths();
        for (let i = 0; i < outputPaths.length; i++) {
            if (fileOperator.isExists(outputPaths[i])) {
                confirmations.push({
                    "title": qsTr("pccut_export_still_export_exists"),
                    "text": qsTr("pccut_export_still_export_exists_description"),
                    "leftButtonText": qsTr("pccut_export_still_export_exists_cancel"),
                    "rightButtonText": qsTr("pccut_shortcut_space_customize_warn_cover")
                });
                break;
            }
        }

        // 2. 磁盘空间不足
        if (savePathControl.spaceInsufficient) {
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
        deviceExportViewModel.exportAllFiles();
        close();
    }

    // ==================== UI 主体 ====================

    contentItem: Item {
        // 遮罩层
        MouseArea {
            anchors.fill: parent
            onClicked: {
                // 点击遮罩层关闭弹窗
                // exportPopup.close();
            }
        }

        // 主容器（动态高度）
        Rectangle {
            id: contentRect
            anchors.centerIn: parent
            width: 360
            height: (customSettingsExpanded ? 444 : 312) + (spaceWarning.visible ? 39 : 0)
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
                    spacing: 16

                    // ==================== 文件导出 ====================

                    // 文件名（统一组件，自动适配单个/批量模式）
                    ExportFileNameUnified {
                        id: fileNameControl
                        width: parent.width
                        height: 28
                        viewModel: deviceExportViewModel
                        titleText: qsTr("pccut_export_name")
                    }

                    // 保存路径选择
                    ExportSavePath {
                        id: savePathControl
                        visible: true
                        width: parent.width
                        height: visible ? 28 : 0
                        viewModel: deviceExportViewModel
                        titleText: qsTr("pccut_player_screenshot_path")
                        btnText: qsTr("pccut_player_screenshot_modify")
                        onDialogAccepted: function(newPath, isChanged) {
                            if (deviceExportViewModel.enableEventTracking) {
                                eventTracker.trackEvent("pccut_home_export_change_location", {"is_change": isChanged})
                            }
                            // 对齐 MacComposePanel：用户改保存路径，同盘且预测剩余不足才应急清理，否则什么都不做
                            if (isChanged) {
                                tryEmergencyCleanForExport(newPath, "dialogAccepted")
                            }
                        }
                        onDialogRejected: {
                            if (deviceExportViewModel.enableEventTracking) {
                                eventTracker.trackEvent("pccut_home_export_change_location", {"is_change": false})
                            }
                        }
                    }

                    // 导出类型（视频/全景视频）
                    ExportTypeSelector {
                        width: parent.width
                        viewModel: deviceExportViewModel
                    }

                    // 自定义设置展开按钮
                    Rectangle {
                        visible: true
                        width: parent.width
                        height: visible ? 28 : 0
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
                                source: customSettingsExpanded ? "qrc:/icons/ic_triangle_up.svg" : "qrc:/icons/ic_triangle_down.svg"
                                sourceSize: Qt.size(16, 16)
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                customSettingsExpanded = !customSettingsExpanded;
                            }
                        }
                    }

                    // ==================== 自定义参数选择区域 ====================

                    Column {
                        visible: customSettingsExpanded
                        width: parent.width
                        height: visible ? implicitHeight : 0
                        spacing: 16

                        // 分辨率选择
                        ExportResolution {
                            id: resolutionControl
                            width: parent.width
                            viewModel: deviceExportViewModel
                            titleLeftMargin: 63
                        }

                        // 帧率选择
                        ExportFrameRate {
                            id: frameRateControl
                            width: parent.width
                            viewModel: deviceExportViewModel
                            titleLeftMargin: 63
                        }

                        // 码率选择
                        ExportBitrate {
                            id: bitrateControl
                            width: parent.width
                            viewModel: deviceExportViewModel
                            titleLeftMargin: 63
                            scrollContainer: scrollView.contentItem
                        }
                    }
                }
            }

            // 底部按钮栏（高度自适应）
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
                    spaceInsufficient: savePathControl.spaceInsufficient
                    spaceLow: savePathControl.spaceLow
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
                    estimatedFileSize: deviceExportViewModel.estimatedFileSize
                }

                // 导出按钮
                BaseConfirmBtn {
                    id: exportButton
                    btnText: qsTr("pccut_menu_export")
                    width: 88
                    height: 28
                    type: 0
                    clickEnabled: savePathControl.pathAccessible
                    canUse: clickEnabled
                    anchors {
                        right: parent.right
                        bottom: parent.bottom
                        bottomMargin: 24
                    }
                    onCustomClick: () => {
                        eventTracker.trackEvent("pccut_home_export_click",
                            {"use_method": "list"});
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
