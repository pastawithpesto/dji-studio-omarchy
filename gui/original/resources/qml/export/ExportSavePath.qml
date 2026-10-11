import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Dialogs
import Controls 1.0
import Config 1.0
import app_qrc 1.0

/**
 * @author: mark.zhu
 * @details 导出保存路径选择（包含文件夹对话框）
 *          传入 viewModel（MediaExportSettingsProtocol 实例或兼容的 QtObject）驱动
 * @date: 2026-03-02
 */
BaseSelectionWithButton {
    id: root

    // 外部传入 viewModel（需具备 savePath / estimatedFileSizeMB / enableEventTracking 等属性）
    required property var viewModel

    // 权限检查策略：外部可传入自定义函数
    property var accessCheckFunc: function(path) { return fileOperator.hasFileCreateAccess(path); }

    // 磁盘空间状态（readonly，供父级弹窗在导出时判断）
    // 对齐 checkStorageWarn 逻辑：预留 1.5 倍文件大小 + 正在导出的文件大小
    readonly property bool spaceInsufficient: availableSpaceMB >= 0
        && availableSpaceMB < warnFileSizeMB
    // 平台换算风险：mac - 1000
    readonly property bool spaceLow: availableSpaceMB >= 0 && availableSpaceMB < 5120 && !spaceInsufficient

    // 内部状态
    property real availableSpaceMB: -1
    property real warnFileSizeMB: 0
    property bool pathAccessible: true
    // 外接移动磁盘标志（readonly，供父级弹窗在导出时判断）
    property bool isExternalDrive: false

    // 文件夹选择结果信号（供外部监听，做埋点或定制逻辑）
    signal dialogAccepted(string newPath, bool isChanged)
    signal dialogRejected()

    // 绑定到 viewModel 数据源
    titleText: qsTr("pccut_player_screenshot_path")
    btnText: qsTr("pccut_player_screenshot_modify")
    contentText: root.viewModel.savePath
    height: 28
    width: parent.width
    showWarning: !pathAccessible || spaceInsufficient || spaceLow
    warningColor: Colors.color_3392FF

    // 路径权限 + 外接磁盘同步检查
    function checkPathAccess() {
        const path = root.viewModel.savePath
        if (path.length === 0) {
            root.pathAccessible = true
            root.isExternalDrive = false
            return
        }
        const accessible = root.accessCheckFunc(path)
        root.pathAccessible = accessible
        root.isExternalDrive = fileOperator.isExternalDrive(path)
        if (!accessible) {
            toast.showToast(qsTr("pccut_editor_fail_warn_5"))
        } else if (root.isExternalDrive) {
            toast.showToast(qsTr("pccut_export_still_export_low_tip3"))
        }
    }

    // 磁盘空间检查
    function checkDiskSpace() {
        const path = root.viewModel.savePath
        if (path.length === 0) {
            root.availableSpaceMB = -1
            root.warnFileSizeMB = 0
            return
        }
        root.availableSpaceMB = fileOperator.tempBytesAvailableWithTimeout(path, 100, 1 /* MB */)
        root.warnFileSizeMB = fileOperator.getStorageWarnSize(path, root.viewModel.estimatedFileSizeMB)
    }

    Component.onCompleted: {
        checkDiskSpace()
        checkPathAccess()
    }

    Connections {
        target: root.viewModel
        function onSavePathChanged() {
            diskSpaceCheckTimer.restart()
            checkPathAccess()
        }
        function onEstimatedFileSizeMBChanged() {
            diskSpaceCheckTimer.restart()
        }
    }

    // 磁盘空间防抖（路径/文件大小变化时使用）
    Timer {
        id: diskSpaceCheckTimer
        interval: 300
        repeat: false
        onTriggered: checkDiskSpace()
    }

    // 文件夹选择对话框（使用 Loader 避免冲突）
    Loader {
        id: folderDialogLoader
        active: false
        sourceComponent: FolderDialog {
            id: folderDialog
            title: qsTr("pccut_export_folder")

            onAccepted: {
                // 优先使用 selectedFolder（用户确认选中的目录），currentFolder 仅作防御性兜底
                var selectedUrl = folderDialog.selectedFolder.toString();
                var rawPath = selectedUrl.length > 0 ? selectedUrl : folderDialog.currentFolder.toString();
                var os = Qt.platform.os;
                var cleanedPath;

                // 根据平台移除 file:// 前缀
                // Windows: file:/// → path
                // macOS/Linux: file:// → path
                if (CommonUtils.isWindows()) {
                    cleanedPath = rawPath.replace(/^file:\/\/\//, "");
                } else {
                    cleanedPath = rawPath.replace(/^file:\/\//, "");
                }

                // Windows 特殊处理
                if (CommonUtils.isWindows()) {
                    // 移除开头的斜杠（C:/ 形式）
                    cleanedPath = cleanedPath.replace(/^\//, "");
                }

                // Windows 额外处理：移除尾部的斜杠（盘符根目录）
                if (os === "windows" && cleanedPath.endsWith("/")) {
                    cleanedPath = cleanedPath.slice(0, -1);
                }

                var isChanged = root.viewModel.savePath !== cleanedPath;
                root.viewModel.savePath = cleanedPath;
                root.dialogAccepted(cleanedPath, isChanged);
                fileOperator.setExportFolder(cleanedPath);
                folderDialogLoader.active = false;
            }
            onRejected: {
                root.dialogRejected();
                folderDialogLoader.active = false;
            }
        }

        onLoaded: {
            item.currentFolder = fileOperator.FileUrlWithPreFix(root.viewModel.savePath);
            item.open();
        }
    }

    // 用户点击"修改"按钮时，激活文件夹选择对话框
    onCustomClick: {
        folderDialogLoader.active = true;
    }
}
