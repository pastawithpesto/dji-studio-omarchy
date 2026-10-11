import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Dialogs
import Controls 1.0
import Config 1.0
import UIComponent
import Qt5Compat.GraphicalEffects
import ShortcutAction 1.0
import CloudAlbumFilterProxyModel 1.0
import CloudAlbumTransferModel 1.0
import CloudAlbumAssetListModel 1.0
import CloudAlbumManager 1.0
import app_qrc 1.0

Item {
    id: root
    objectName: "cloudAlbumLoggedInView"

    // 是否显示引导页（由 ViewModel 控制）
    property bool showGuide: false
    property bool forceShowBetaView: false
    property bool forceShowGuideStepsView: false
    // 权益 ViewModel（由 CloudAlbumView 传入，转发给 CloudAlbumGuideView）
    property var benefitViewModel: null

    // 外部可绑定的属性
    property string userName: "User"
    property real usedStorage: 2.5        // GB
    property real totalStorage: 120.0     // GB
    readonly property real storageGbBytes: Math.pow(CommonUtils.base_file_number, 3)
    property bool isBenefitExpired: false
    property int expireDay: -1
    property int expireDeleteMeta: 0
    property string expireDate: ""
    property string avatarSource: ""
    property var mediaCategoryViewModel: null
    property int currentTabIndex: mediaCategoryViewModel ? mediaCategoryViewModel.selectedIndex : 0       // 0=云空间, 1=高光
    property bool isListMode: false        // false=网格模式, true=列表模式

    function directoryFromFilePath(localPath) {
        var separatorIndex = localPath.lastIndexOf("/");
        if (separatorIndex < 0) {
            return "";
        }
        if (separatorIndex === 0) {
            return "/";
        }
        if (separatorIndex === 2 && localPath.charAt(1) === ":") {
            return localPath.substring(0, 3);
        }
        return localPath.substring(0, separatorIndex);
    }

    function appendLocalPath(directory, fileName) {
        return directory.endsWith("/") ? directory + fileName : directory + "/" + fileName;
    }

    function localPathsFromUrls(urls) {
        var paths = [];
        for (var i = 0; i < urls.length; i++) {
            var localPath = CloudAlbumTransferModel.fileUrlToLocalPath(urls[i]);
            if (localPath.length > 0) {
                paths.push(localPath);
            }
        }
        return paths;
    }

    // 存储状态枚举
    enum StorageWarningType {
        None,        // 正常
        Full,        // 空间已满（≥99%）
        ExpiringSoon, // 权益已过期，但仍在服务端指定的素材保留期内
        Expired      // 权益已超过服务端指定的素材保留期
    }

    // 过期状态以服务端 last-online-benefit 的 status 为准
    readonly property bool isExpired: isBenefitExpired

    function daysUntilExpiredContentDeletion() {
        return Math.max(0, expireDeleteMeta - expireDay + 1);
    }

    // 当前警告类型
    function storageWarningType() {
        if (isExpired) {
            if (expireDay > 0 && expireDay <= expireDeleteMeta)
                return CloudAlbumLoggedInView.StorageWarningType.ExpiringSoon;
            return CloudAlbumLoggedInView.StorageWarningType.Expired;
        }
        if (totalStorage > 0 && (usedStorage / totalStorage * 100) >= 99)
            return CloudAlbumLoggedInView.StorageWarningType.Full;
        return CloudAlbumLoggedInView.StorageWarningType.None;
    }

    // 是否需要显示警告
    property bool showStorageWarning: storageWarningType() !== CloudAlbumLoggedInView.StorageWarningType.None

    // 根据警告类型返回内联警告文案
    function storageWarningText() {
        switch (storageWarningType()) {
        case CloudAlbumLoggedInView.StorageWarningType.Full:
            return qsTr("pccut_cloud_album_warn_storage_full");
        case CloudAlbumLoggedInView.StorageWarningType.ExpiringSoon:
            return qsTr("pccut_cloud_album_warn_expiring_soon")
                .arg(daysUntilExpiredContentDeletion());
        case CloudAlbumLoggedInView.StorageWarningType.Expired:
            return qsTr("pccut_cloud_album_warn_expired").arg(expireDeleteMeta);
        default:
            return "";
        }
    }

    function previewFailReasonFromMessage(message) {
        var lowerMessage = (message || "").toLowerCase()
        if (lowerMessage.indexOf("unsupported") >= 0
                || lowerMessage.indexOf("format") >= 0) return 12
        if (lowerMessage.indexOf("corrupt") >= 0
                || lowerMessage.indexOf("checksum") >= 0) return 13
        return 1
    }

    // 外部可绑定的属性 - 数据模型
    property var cloudAlbumModel: null
    property bool hasContent: cloudAlbumModel ? cloudAlbumModel.count > 0 : false

    onCurrentTabIndexChanged: {
        if (showSelectState) {
            showSelectState = false;
        }
        contentArea.isDragOver = false;
    }

    ListModel {
        id: emptyHighlightModel
    }

    QtObject {
        id: emptyHighlightSourceModel
        property bool isLoading: true
        property bool isEnd: true

        function selectAll(selected) {}
        function selectAsset(assetId, selected) {}
        function fetchNextPage() {}
    }

    // 回收站红点状态
    property bool showRecycleBinDot: false
    function refreshRecycleBinDot() {
        root.showRecycleBinDot = CloudAlbumManager.getLocalUiFlag(CloudAlbumManager.RecycleBinUnread)
    }

    // 筛选代理模型（前端过滤，不影响底层数据）
    CloudAlbumFilterProxyModel {
        id: filterProxyModel
        objectName: "cloudAlbumFilterProxyModel"
        filterType: root.currentFilterType
    }
    onCloudAlbumModelChanged: {
        if (cloudAlbumModel) {
            filterProxyModel.setSourceModelFromQml(cloudAlbumModel);
        }
    }

    // 筛选类型：0=全部, 1=视频, 2=图片, 3=收藏
    property int currentFilterType: CloudAlbumFilterPopup.FilterType.All
    signal filterTypeChanged(int filterType)

    // 批量选中模式
    property bool showSelectState: false
    onShowSelectStateChanged: {
        if (!showSelectState && cloudAlbumModel) {
            cloudAlbumModel.selectAll(false);
        }
        updateSelectCount();
    }

    // 批量选中：下载/删除按钮 enabled 绑定
    property int selectCount: 0
    function updateSelectCount() {
        selectCount = cloudAlbumModel ? cloudAlbumModel.selectedAssetIds().length : 0;
    }

    function deleteMetadataForIds(fileIds) {
        var metadata = {
            size: 0,
            materials: {photo: 0, video: 0, panoPhoto: 0, panoVideo: 0, livePhoto: 0}
        }
        if (!cloudAlbumModel) return metadata
        for (var i = 0; i < fileIds.length; ++i) {
            var info = cloudAlbumModel.assetInfo(fileIds[i])
            metadata.size += info.fileSizeMB || 0
            var type = info.assetType || 0
            if (type === 1) metadata.materials.photo++
            else if (type === 2) metadata.materials.video++
            else if (type === 3) metadata.materials.livePhoto++
            else if (type === 4) metadata.materials.panoPhoto++
            else if (type === 5) metadata.materials.panoVideo++
        }
        return metadata
    }

    function showBatchDeletePopup(method) {
        var selectedIds = root.cloudAlbumModel
                ? root.cloudAlbumModel.selectedAssetIds() : []
        if (selectedIds.length === 0) return
        var metadata = root.deleteMetadataForIds(selectedIds)
        cloudAlbumEventReport.trackDeleteClick(
            method, metadata.materials, metadata.size, selectedIds)
        cloudAlbumDeletePopup.showPop(selectedIds, metadata)
    }

    signal expandStorageClicked()

    // 预览下载中的 assetId（空字符串表示无预览下载）
    property string _previewPendingAssetId: ""
    // 预览点击时的时间戳（毫秒），用于计算加载耗时
    property real _previewStartTime: 0
    // 预览打开时的时间戳（毫秒），用于计算停留时长
    property real _previewOpenTime: 0
    // 预览中的 assetId、mediaType、fileSize（供关闭时上报）
    property string _previewingAssetId: ""
    property int _previewingMediaType: 0
    property real _previewingFileSizeMB: 0
    // 关闭方式：0=button, 1=shortcut（ESC）
    property int _previewCloseMethod: 0
    // 当前预览素材是否为 DNG；仅 Windows 使用缩略图且不下载原图
    property bool _previewingIsDng: false
    // 当前预览素材的 AssetType（1=Photo, 3=LivePhoto, 4=PanoramaPhoto）
    property int _previewingFileType: 0
    // 缩略图已打开、后台继续下载原图的 assetId（原图完成后保留在预览缓存）
    property string _backgroundDownloadAssetId: ""

    CShortcut {
        action: ShortcutAction.DELETE
        enabled: root.visible && root.showSelectState
        onActivated: {
            root.showBatchDeletePopup(2)
        }
    }

    Connections {
        target: globalSignal
        function onCloudAlbumPreviewClosing(closeMethod) {
            if (root._previewingAssetId !== "") {
                root._previewCloseMethod = closeMethod
            }
        }
    }

    onVisibleChanged: {
        if (visible && cloudAlbumModel) {
            cloudAlbumModel.refresh();
            // 显示时刷新回收站红点状态
            root.refreshRecycleBinDot()
            console.log("[CloudAlbum] onVisibleChanged showRecycleBinDot=" + root.showRecycleBinDot)
        }
    }

    Connections {
        target: CloudAlbumManager
        function onLocalUiStateChanged() {
            root.refreshRecycleBinDot()
        }
        function onStreamingReadyToPlay(primaryUrl, metaUrl, isPanorama, mediaType, durationMs, destination) {
            if (destination !== 0 || root._previewingAssetId === "") return;
            var spendMs = Date.now() - root._previewStartTime
            cloudAlbumEventReport.trackPreviewClick(
                true, 0,
                root._previewingMediaType,
                root._previewingFileSizeMB,
                root._previewingAssetId,
                spendMs)
            root._previewOpenTime = Date.now()
        }
        function onStreamingPrepareFailed(destination) {
            if (destination !== 0 || root._previewingAssetId === "") return;
            var spendMs = Date.now() - root._previewStartTime
            cloudAlbumEventReport.trackPreviewClick(
                false, 1,
                root._previewingMediaType,
                root._previewingFileSizeMB,
                root._previewingAssetId,
                spendMs)
            root._previewingAssetId = ""
            root._previewOpenTime = 0
            root._previewCloseMethod = 0
        }
    }

    // 上传完成后追加本地临时资产；主动刷新时由资产模型统一清理。
    CloudAlbumLocalUploadBridge {
        assetModel: root.cloudAlbumModel
        active: root.visible
    }

    Connections {
        target: CloudAlbumTransferModel
        function onUploadComplete(fileName) {
            console.log("[CloudAlbumUpload] onUploadComplete fileName=" + fileName
                        + " rootVisible=" + root.visible)
            if (root.benefitViewModel) {
                root.benefitViewModel.refreshQuota();
            }
        }
        function onDownloadComplete(assetId, localPath) {
            if (cloudAlbumModel) {
                cloudAlbumModel.markDownloaded(assetId, localPath);
            }
        }
        function onLocalFileDeleted(assetId, localPath) {
            if (cloudAlbumModel) {
                cloudAlbumModel.markNotDownloaded(assetId, localPath);
            }
        }
        function onSpaceFullBeforeUpload() {
            console.log("[CloudAlbumUpload] onSpaceFullBeforeUpload")
            cloudAlbumSpacePopup.showFull()
        }
        function onSpaceInsufficientAfterUpload(skippedCount) {
            console.log("[CloudAlbumUpload] onSpaceInsufficientAfterUpload skippedCount=" + skippedCount)
            cloudAlbumSpacePopup.showInsufficient(skippedCount)
        }
        function onQuotaUpdated(totalBytes, usedBytes, frozenBytes) {
            root.totalStorage = totalBytes / root.storageGbBytes
            root.usedStorage = (usedBytes + frozenBytes) / root.storageGbBytes
        }
        function onPreviewThumbnailReady(assetId, localPath) {
            if (root._previewPendingAssetId !== assetId) return;
            var elapsed = Date.now() - root._previewStartTime
            var isPano = (root._previewingFileType === 4)

            if (CommonUtils.isWindows() && root._previewingIsDng) {
                // Windows DNG：缩略图即最终质量，取消原图下载，直接打开
                root._previewPendingAssetId = "";
                CloudAlbumTransferModel.cancelPreviewDownload();
                if (isPano) {
                    openOperator.cloudAlbumOpenAsPanorama([localPath]);
                } else {
                    openOperator.cloudAlbumOpen([localPath]);
                }
                cloudAlbumEventReport.trackPreviewClick(
                    true, 0,
                    root._previewingMediaType,
                    root._previewingFileSizeMB,
                    assetId,
                    elapsed)
                root._previewOpenTime = Date.now()
            } else {
                // macOS DNG 及其他图片：缩略图立即打开，后台继续下载原图（不替换预览）
                root._previewPendingAssetId = "";
                root._backgroundDownloadAssetId = assetId;
                if (isPano) {
                    openOperator.cloudAlbumOpenAsPanorama([localPath]);
                } else {
                    openOperator.cloudAlbumOpen([localPath]);
                }
                // 缩略图打开即视为预览成功，立即上报埋点
                cloudAlbumEventReport.trackPreviewClick(
                    true, 0,
                    root._previewingMediaType,
                    root._previewingFileSizeMB,
                    assetId,
                    elapsed)
                root._previewOpenTime = Date.now()
            }
        }
        function onPreviewReady(assetId, localPath) {
            if (root._backgroundDownloadAssetId === assetId) {
                // 非 DNG 原图下载完毕，缩略图已在预览中 → 仅清状态，不替换播放源
                root._backgroundDownloadAssetId = "";
                return;
            }
            if (root._previewPendingAssetId !== assetId) return;
            var elapsed = Date.now() - root._previewStartTime
            root._previewPendingAssetId = "";
            // 全景图强制全景模式（缩略图未触发时的兜底路径）
            if (root._previewingFileType === 4) {
                openOperator.cloudAlbumOpenAsPanorama([localPath]);
            } else {
                openOperator.cloudAlbumOpen([localPath]);
            }
            // preview_click 成功埋点
            cloudAlbumEventReport.trackPreviewClick(
                true, 0,
                root._previewingMediaType,
                root._previewingFileSizeMB,
                assetId,
                elapsed)
            root._previewOpenTime = Date.now()
        }
        function onPreviewFailed(assetId, message) {
            if (root._previewPendingAssetId === assetId) {
                var spendMs = Date.now() - root._previewStartTime
                root._previewPendingAssetId = "";
                // preview_click 失败埋点
                cloudAlbumEventReport.trackPreviewClick(
                    false, root.previewFailReasonFromMessage(message),
                    root._previewingMediaType,
                    root._previewingFileSizeMB, assetId, spendMs)
            } else if (root._backgroundDownloadAssetId === assetId) {
                // 缩略图已打开，原图下载失败 → 静默忽略（缩略图已可用）
                root._backgroundDownloadAssetId = "";
            }
        }
    }

    // 监听 lightSetting 变化，更新回收站红点状态
    // 注意：lightSetting 不发出 valueChanged 信号，因此直接在 save 后赋值

    Connections {
        target: root.cloudAlbumModel
        function onDeleteSuccess(count) {
            if (root.benefitViewModel) {
                root.benefitViewModel.refreshQuota();
            }
        }
        function onRefreshRequested() {
            if (root.benefitViewModel) {
                root.benefitViewModel.refreshQuota();
            }
        }
    }

    Connections {
        target: root.benefitViewModel
        function onQuotaChanged() {
            if (root.benefitViewModel) {
                root.totalStorage = root.benefitViewModel.totalBytes / root.storageGbBytes;
                root.usedStorage = (root.benefitViewModel.usedBytes + root.benefitViewModel.frozenBytes) / root.storageGbBytes;
            }
        }
    }

    // 预览窗口关闭时，取消正在进行的预览下载，防止下载完后自动重新弹窗
    Connections {
        target: openOperator
        function onShowPreviewChanged() {
            if (!openOperator.showPreview) {
                if (root._previewPendingAssetId !== "") {
                    // 预览下载中关闭窗口，取消下载（规范不上报 preview_click for cancel）
                    root._previewPendingAssetId = "";
                    CloudAlbumTransferModel.cancelPreviewDownload();
                } else if (root._backgroundDownloadAssetId !== "") {
                    // 缩略图已打开、原图后台下载中，关闭窗口时取消后台下载
                    // 两个状态互斥，用 else if 确保 cancelPreviewDownload 只调一次
                    root._backgroundDownloadAssetId = "";
                    CloudAlbumTransferModel.cancelPreviewDownload();
                }
                // preview_close_click 埋点
                if (root._previewingAssetId !== "" && root._previewOpenTime > 0) {
                    var stayDuration = Date.now() - root._previewOpenTime
                    cloudAlbumEventReport.trackPreviewCloseClick(
                        root._previewCloseMethod,
                        root._previewingMediaType,
                        root._previewingFileSizeMB,
                        root._previewingAssetId,
                        stayDuration)
                    root._previewingAssetId = ""
                    root._previewOpenTime = 0
                    root._previewCloseMethod = 0
                }
            }
        }
    }

    signal uploadClicked()
    signal createAlbumClicked()
    signal batchSelectClicked()
    signal recycleBinClicked()

    // 待下载的 assetId、文件名和素材类型列表（FolderDialog 选择路径后使用）
    property var _pendingDownloadAssetIds: []
    property var _pendingDownloadFileNames: []
    property var _pendingDownloadAssetTypes: []
    property real _pendingDownloadExpectedBytes: 0

    // 从 model 中查找 assetId 对应的 fileName
    function getFileNameForAssetId(assetId) {
        if (!cloudAlbumModel) return assetId;
        for (var i = 0; i < cloudAlbumModel.rowCount(); i++) {
            var idx = cloudAlbumModel.index(i, 0);
            if (cloudAlbumModel.data(idx, CloudAlbumAssetListModel.AssetId) === assetId) {
                return cloudAlbumModel.data(idx, CloudAlbumAssetListModel.FileName) || assetId;
            }
        }
        return assetId;
    }

    function getFileNamesForAssetIds(assetIds) {
        var names = [];
        for (var i = 0; i < assetIds.length; i++) {
            names.push(getFileNameForAssetId(assetIds[i]));
        }
        return names;
    }

    // 滚动到指定文件名的素材
    function scrollToFileName(fileName) {
        return gridView.scrollToFileName(fileName);
    }

    // 动态刷新上传文件选择对话框的格式过滤
    function openUploadFileDialog() {
        var formats = CloudAlbumTransferModel.supportedUploadFormats();
        console.log("[CloudAlbumUpload] openUploadFileDialog supportedFormats=" + formats.join(",")
                    + " isExpired=" + root.isExpired)
        if (formats.length > 0) {
            var wildcards = formats.map(function(ext) { return "*" + ext; }).join(" ");
            uploadFileDialog.nameFilters = ["Media files (" + wildcards + ")"];
        }
        console.log("[CloudAlbumUpload] uploadFileDialog.open nameFilters=" + uploadFileDialog.nameFilters.join("|"))
        uploadFileDialog.open();
    }

    // 上传文件选择对话框
    FileDialog {
        id: uploadFileDialog
        title: qsTr("pccut_cloud_album_upload")
        nameFilters: ["Media files (*.mp4 *.mov *.jpg *.jpeg *.png *.dng)"]
        fileMode: FileDialog.OpenFiles
        onAccepted: {
            var paths = root.localPathsFromUrls(selectedFiles);
            console.log("[CloudAlbumUpload] uploadFileDialog.accepted count=" + paths.length
                        + " firstPath=" + (paths.length > 0 ? paths[0] : ""))
            if (paths.length > 0) {
                console.log("[CloudAlbumUpload] CloudAlbumTransferModel.addUpload from fileDialog count=" + paths.length)
                CloudAlbumTransferModel.addUpload(paths, [], 0)  // 0 = UploadMethod::Button
            }
        }
        onRejected: {
            console.log("[CloudAlbumUpload] uploadFileDialog.rejected")
        }
    }

    // 下载保存 - 单文件用 FileDialog（SaveFile），多文件用 FolderDialog
    FileDialog {
        id: downloadSaveFileDialog
        title: qsTr("pccut_device_batch_download")
        fileMode: FileDialog.SaveFile
        currentFolder: CloudAlbumTransferModel.pathToFileUrl(CloudAlbumTransferModel.defaultDownloadPath())
        onAccepted: {
            var rawPath = CloudAlbumTransferModel.fileUrlToLocalPath(selectedFile);
            if (root._pendingDownloadAssetIds.length > 0) {
                // 单文件：savePath 是完整文件路径，取其所在目录
                var dirPath = root.directoryFromFilePath(rawPath);
                var separatorIndex = rawPath.lastIndexOf("/");
                var fileName = separatorIndex >= 0 ? rawPath.substring(separatorIndex + 1) : rawPath;
                if (dirPath.length === 0) {
                    dirPath = CloudAlbumTransferModel.defaultDownloadPath();
                }
                if (dirPath.length === 0 || fileName.length === 0) {
                    console.warn("[CloudAlbumDownload] invalid selected file path:", rawPath);
                    root._pendingDownloadAssetIds = [];
                    root._pendingDownloadFileNames = [];
                    root._pendingDownloadAssetTypes = [];
                    return;
                }
                CloudAlbumTransferModel.saveDownloadPath(dirPath);
                CloudAlbumTransferModel.addDownload(root._pendingDownloadAssetIds, [fileName], dirPath,
                                                    root._pendingDownloadAssetTypes,
                                                    root._pendingDownloadExpectedBytes);
                root._pendingDownloadAssetIds = [];
                root._pendingDownloadFileNames = [];
                root._pendingDownloadAssetTypes = [];
            }
        }
        onRejected: {
            root._pendingDownloadAssetIds = [];
            root._pendingDownloadFileNames = [];
            root._pendingDownloadAssetTypes = [];
        }
    }

    FolderDialog {
        id: downloadFolderDialog
        title: qsTr("pccut_device_batch_download")
        currentFolder: CloudAlbumTransferModel.pathToFileUrl(CloudAlbumTransferModel.defaultDownloadPath())
        onAccepted: {
            var rawPath = CloudAlbumTransferModel.fileUrlToLocalPath(selectedFolder);
            if (root._pendingDownloadAssetIds.length > 0) {
                if (rawPath.length === 0) {
                    rawPath = CloudAlbumTransferModel.defaultDownloadPath();
                }
                if (rawPath.length === 0) {
                    console.warn("[CloudAlbumDownload] invalid selected folder path");
                    root._pendingDownloadAssetIds = [];
                    root._pendingDownloadFileNames = [];
                    root._pendingDownloadAssetTypes = [];
                    return;
                }
                CloudAlbumTransferModel.saveDownloadPath(rawPath);
                CloudAlbumTransferModel.addDownload(root._pendingDownloadAssetIds,
                                                    root._pendingDownloadFileNames, rawPath,
                                                    root._pendingDownloadAssetTypes,
                                                    root._pendingDownloadExpectedBytes);
                root._pendingDownloadAssetIds = [];
                root._pendingDownloadFileNames = [];
                root._pendingDownloadAssetTypes = [];
            }
        }
        onRejected: {
            root._pendingDownloadAssetIds = [];
            root._pendingDownloadFileNames = [];
            root._pendingDownloadAssetTypes = [];
        }
    }

    // 统一下载入口：已配置默认路径则直接下载，否则单文件弹 SaveFile，多文件弹 FolderDialog
    // method: 0=button, 1=right_click
    function startDownload(assetIds, fileNames, method) {
        // 构建下载任务参数及点击埋点所需的批量素材统计
        var mat = {photo: 0, video: 0, panoPhoto: 0, panoVideo: 0, livePhoto: 0}
        var totalSizeMB = 0
        var expectedBytes = 0
        var assetTypes = []
        if (root.cloudAlbumModel) {
            for (var i = 0; i < assetIds.length; i++) {
                var info = root.cloudAlbumModel.assetInfo(assetIds[i])
                totalSizeMB += (info.fileSizeMB || 0)
                expectedBytes += (info.fileSizeBytes || 0)
                var t = info.assetType || 0
                assetTypes.push(t)
                // album::AssetType: 1=Photo, 2=Video, 3=LivePhoto, 4=PanoramaPhoto, 5=PanoramaVideo
                if (t === 1)      mat.photo++
                else if (t === 2) mat.video++
                else if (t === 3) mat.livePhoto++
                else if (t === 4) mat.panoPhoto++
                else if (t === 5) mat.panoVideo++
            }
        }
        cloudAlbumEventReport.trackDownloadClick(method || 0, mat, totalSizeMB, assetIds)

        if (CloudAlbumTransferModel.hasCustomDownloadPath()) {
            var savePath = CloudAlbumTransferModel.defaultDownloadPath();
            CloudAlbumTransferModel.addDownload(assetIds, fileNames, savePath, assetTypes, expectedBytes);
            return;
        }
        root._pendingDownloadAssetIds = assetIds;
        root._pendingDownloadFileNames = fileNames;
        root._pendingDownloadAssetTypes = assetTypes;
        root._pendingDownloadExpectedBytes = expectedBytes;
        if (assetIds.length === 1 && fileNames.length === 1) {
            var defaultPath = CloudAlbumTransferModel.defaultDownloadPath();
            downloadSaveFileDialog.currentFolder = CloudAlbumTransferModel.pathToFileUrl(defaultPath);
            downloadSaveFileDialog.selectedFile = CloudAlbumTransferModel.pathToFileUrl(root.appendLocalPath(defaultPath, fileNames[0]));
            downloadSaveFileDialog.open();
        } else {
            downloadFolderDialog.currentFolder = CloudAlbumTransferModel.pathToFileUrl(CloudAlbumTransferModel.defaultDownloadPath());
            downloadFolderDialog.open();
        }
    }

    // ESC 退出批量选择模式
    CShortcut {
        action: ShortcutAction.ESCAPE_FULL_SCREEN
        enabled: root.visible && root.showSelectState
        onActivated: {
            root.showSelectState = false;
        }
    }

    StackLayout {
        id: mainStack
        anchors.fill: parent
        currentIndex: root.forceShowBetaView || root.forceShowGuideStepsView || root.showGuide ? 0 : 1

        // index 0: 引导页
        CloudAlbumGuideView {
            objectName: "cloudAlbumGuideView"
            forceShowBetaView: root.forceShowBetaView
            forceShowGuideStepsView: root.forceShowGuideStepsView
            benefitViewModel: root.benefitViewModel
        }

        // index 1: 主内容
        Item {
            ColumnLayout {
                anchors.fill: parent
                anchors.topMargin: 40
                anchors.bottomMargin: 40
                anchors.leftMargin: 0
                anchors.rightMargin: 0
                spacing: 0

        // ========== 1. 用户信息卡片 ==========
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: root.showStorageWarning ? 107 : 80
            Layout.leftMargin: 40
            Layout.rightMargin: 40
            radius: 8
            color: {
                var wt = root.storageWarningType();
                if (wt === CloudAlbumLoggedInView.StorageWarningType.Full ||
                        wt === CloudAlbumLoggedInView.StorageWarningType.Expired)
                    return Qt.rgba(242/255, 36/255, 67/255, 0.1);
                if (wt === CloudAlbumLoggedInView.StorageWarningType.ExpiringSoon)
                    return Qt.rgba(255/255, 129/255, 17/255, 0.1);
                return Colors.color_1F2021;
            }

            // 主卡内容区（固定 80px）
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 80
                radius: 8
                color: Colors.color_1F2021

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 20
                    anchors.rightMargin: 26
                    spacing: 16

                    // 头像（OpacityMask 实现圆角裁剪）
                    Item {
                        Layout.preferredWidth: 48
                        Layout.preferredHeight: 48
                        Layout.alignment: Qt.AlignVCenter

                        Rectangle {
                            id: avatarMask
                            anchors.fill: parent
                            radius: 24
                            visible: false
                        }

                        Rectangle {
                            id: avatarContent
                            anchors.fill: parent
                            radius: 24
                            color: Colors.color_454649
                            visible: false

                            Image {
                                anchors.fill: parent
                                source: root.avatarSource
                                fillMode: Image.PreserveAspectCrop
                            }
                        }

                        OpacityMask {
                            anchors.fill: avatarContent
                            source: avatarContent
                            maskSource: avatarMask
                        }
                    }

                    // 空间信息 + 进度条
                    ColumnLayout {
                        id: storageColumn
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 6

                        property bool isStorageFull: root.totalStorage > 0
                            && (root.usedStorage / root.totalStorage * 100) >= 99

                        // 标题行
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            // 用户名 + "的云空间" 后缀：用户名超长时中间缩略，后缀始终可见
                            RowLayout {
                                spacing: 0
                                Layout.alignment: Qt.AlignVCenter
                                Text {
                                    // 长度限制与用户信息面板一致（112px），超长中间缩略
                                    Layout.maximumWidth: 112
                                    text: root.userName
                                    elide: Text.ElideMiddle
                                    font.pixelSize: 14
                                    font.weight: Font.Medium
                                    color: Colors.color_FFFFFF
                                }
                                Text {
                                    text: qsTr("pccut_cloud_album_space_suffix")
                                    font.pixelSize: 14
                                    font.weight: Font.Medium
                                    color: Colors.color_FFFFFF
                                }
                            }
                            Rectangle {
                                width: 1
                                height: 12
                                opacity: 0.2
                                color: Colors.color_FFFFFF
                                Layout.alignment: Qt.AlignVCenter
                            }
                            Text {
                                text: qsTr("pccut_cloud_album_used")
                                font.pixelSize: 12
                                color: storageColumn.isStorageFull ? Colors.color_F22443 : Colors.color_EEEEEE
                            }
                            Text {
                                property int percent: root.totalStorage > 0
                                    ? Math.floor(root.usedStorage / root.totalStorage * 100) : 0
                                text: percent + "%" + (storageColumn.isStorageFull ? (" " + qsTr("pccut_cloud_album_storage_full")) : "")
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                color: {
                                    var wt = root.storageWarningType();
                                    if (wt === CloudAlbumLoggedInView.StorageWarningType.Full)
                                        return Colors.color_F22443;
                                    if (wt === CloudAlbumLoggedInView.StorageWarningType.Expired)
                                        return Colors.color_999999;
                                    return Qt.color("#FF8111");
                                }
                            }
                        }

                        // 进度条
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 4
                            radius: 88
                            color: Colors.color_454649

                            Rectangle {
                                width: root.totalStorage > 0
                                    ? parent.width * Math.min(root.usedStorage / root.totalStorage, 1.0)
                                    : 0
                                height: parent.height
                                radius: 88
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop {
                                        position: 0.0
                                        color: {
                                            var wt = root.storageWarningType();
                                            if (wt === CloudAlbumLoggedInView.StorageWarningType.Full)
                                                return Colors.color_FC4763;
                                            if (wt === CloudAlbumLoggedInView.StorageWarningType.Expired)
                                                return Colors.color_666666;
                                            return Colors.color_FFB26D;
                                        }
                                    }
                                    GradientStop {
                                        position: 1.0
                                        color: {
                                            var wt = root.storageWarningType();
                                            if (wt === CloudAlbumLoggedInView.StorageWarningType.Full)
                                                return Colors.color_F22443;
                                            if (wt === CloudAlbumLoggedInView.StorageWarningType.Expired)
                                                return Colors.color_666666;
                                            return Colors.color_FF8111;
                                        }
                                    }
                                }
                            }
                        }

                        // 容量标签: "118.0 GB / 120.0 GB" 左对齐, 到期日期右对齐
                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: root.usedStorage.toFixed(1) + " GB / " + root.totalStorage.toFixed(1) + " GB"
                                font.pixelSize: 10
                                color: Colors.color_666666
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: root.isExpired
                                    ? (qsTr("pccut_cloud_album_expire_prefix").arg(root.expireDate))
                                    : (root.expireDate + " " + qsTr("pccut_cloud_album_expire"))
                                font.pixelSize: 10
                                color: Colors.color_666666
                            }
                        }
                    }

                    // 间隔区域（保持进度条与原版等宽）
                    Item {
                        Layout.preferredWidth: 267.5
                        Layout.fillHeight: true
                    }

                    // 去订阅/去扩容 按钮
                    FixedWidthIconTextButton {
                        id: expandStorageBtn
                        visible: cloudAlbumFeatureFlags.subscribeEnable
                        Layout.alignment: Qt.AlignVCenter
                        fixedWidth: 88
                        fixedHeight: 28
                        hoveredCursor: Qt.PointingHandCursor
                        title: qsTr("pccut_cloud_album_expand")
                        titleFontSize: 12
                        titleColorNormal: Colors.color_141414
                        titleColorHover: Colors.color_141414
                        radius: 6

                        customBackground: Component {
                            Rectangle {
                                radius: 6

                                HoverHandler { id: hoverHandler }

                                gradient: Gradient {
                                    orientation: Gradient.Vertical
                                    GradientStop { position: 0.0; color: hoverHandler.hovered ? "#FFBC80" : "#FFB26D" }
                                    GradientStop { position: 1.0; color: hoverHandler.hovered ? "#FFA95D" : "#FFA24F" }
                                }
                            }
                        }

                        onCustomClicked: root.expandStorageClicked()
                    }
                }
            }

            // 底部警告行（仅在警告状态下可见）
            RowLayout {
                visible: root.showStorageWarning
                anchors.left: parent.left
                anchors.leftMargin: 24
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 6
                spacing: 4
                height: 15

                Image {
                    Layout.preferredWidth: 15
                    Layout.preferredHeight: 15
                    Layout.alignment: Qt.AlignVCenter
                    sourceSize: Qt.size(15, 15)
                    fillMode: Image.PreserveAspectFit
                    source: root.storageWarningType() === CloudAlbumLoggedInView.StorageWarningType.ExpiringSoon
                        ? "qrc:/app_qrc/icons/cloud_album_warning_orange.svg"
                        : "qrc:/app_qrc/icons/cloud_album_warning_red.svg"
                }

                Text {
                    text: root.storageWarningText()
                    font.pixelSize: 11
                    color: {
                        var wt = root.storageWarningType();
                        return wt === CloudAlbumLoggedInView.StorageWarningType.ExpiringSoon
                            ? Qt.color("#FF8111") : Colors.color_F22443;
                    }
                }
            }
        }

        // 保留 CloudAlbumStorageWarning 以备后用（当前不显示）
        CloudAlbumStorageWarning {
            id: storageWarning
            visible: false
            Layout.preferredHeight: 0
            warningText: root.storageWarningText()
        }

        // 卡片到标签行间距 40px
        Item { Layout.preferredHeight: 34 }

        // ========== 2. 标签行 + 操作栏 ==========
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 40
            Layout.rightMargin: 40
            spacing: 0

            // 左侧: 云空间 / 高光 标签
            EnumTabsView {
                id: cloudAlbumTabsView
                objectName: "cloudAlbumTabsView"
                spacing: 24
                clip: false
                tabHorizontalPadding: 0
                tabVerticalPadding: 0
                viewModel: root.mediaCategoryViewModel
            }

            // 弹簧
            Item { Layout.fillWidth: true }

            // 右侧: 操作图标栏
            RowLayout {
                spacing: 8

                // --- 非批量选择模式：显示网格/列表切换、筛选、勾选图标 ---
                IconButton {
                    id: refreshBtn
                    objectName: "cloudAlbumRefreshBtn"
                    width: 28; height: 28
                    radius: 6
                    iconWidth: 20; iconHeight: 20
                    visible: !root.showSelectState
                    enabled: !(root.isExpired && !root.hasContent)
                    opacity: enabled ? 1.0 : 0.2
                    iconSource: "qrc:/app_qrc/icons/cloud_album_refresh.svg"
                    normalColor: Colors.color_2F3032
                    hoverColor: Colors.color_37383A
                    pressedColor: Colors.color_2F3032
                    onClicked: {
                        if (root.cloudAlbumModel) {
                            root.cloudAlbumModel.refresh();
                        }
                    }
                }
                // 描边色/Line_Panel（#2F3032）
                Rectangle {
                    width: 1
                    height: 12
                    color: Colors.color_2F3032
                    Layout.alignment: Qt.AlignVCenter
                    visible: !root.showSelectState
                }

                IconButton {
                    id: viewModeBtn
                    objectName: "cloudAlbumViewModeBtn"
                    width: 28; height: 28
                    radius: 6
                    iconWidth: 20; iconHeight: 20
                    visible: !root.showSelectState && root.hasContent
                    enabled: !(root.isExpired && !root.hasContent)
                    opacity: enabled ? 1.0 : 0.2
                    // 当前是列表模式时显示网格图标（点击切回网格），反之显示列表图标
                    iconSource: root.isListMode
                        ? "qrc:/app_qrc/icons/cloud_album_list.svg"
                        : "qrc:/app_qrc/icons/cloud_album_grid.svg"
                    normalColor: Colors.color_2F3032
                    hoverColor: Colors.color_37383A
                    pressedColor: Colors.color_2F3032
                    hoverTextFunc: function() { return root.isListMode ? qsTr("pccut_cloud_album_thumbnail_view") : qsTr("pccut_cloud_album_list_view") }
                    onClicked: {
                        root.isListMode = !root.isListMode;
                    }
                }
                IconButton {
                    id: filterBtn
                    objectName: "cloudAlbumFilterBtn"
                    width: 28; height: 28
                    radius: 6
                    iconWidth: 20; iconHeight: 20
                    visible: !root.showSelectState && root.hasContent
                    enabled: !(root.isExpired && !root.hasContent)
                    opacity: enabled ? 1.0 : 0.2
                    iconSource: (filterPopup.visible)
                                ? "qrc:/app_qrc/icons/cloud_album_filter_checked.svg"
                                : "qrc:/app_qrc/icons/cloud_album_filter.svg"
                    normalColor: (filterPopup.visible)
                                 ? Colors.color_37383A : Colors.color_2F3032
                    hoverColor: Colors.color_37383A
                    pressedColor: Colors.color_2F3032
                    hoverTextFunc: function() { return qsTr("pccut_cloud_album_filter") }
                    onClicked: {
                        var newPoint = filterBtn.mapToItem(null, filterBtn.width, filterBtn.height);
                        filterPopup.x = newPoint.x - (filterPopup.width - filterBtn.width) / 2 - filterBtn.width;
                        filterPopup.y = newPoint.y + 4;
                        var operateModels = filterPopup.filterModel;
                        operateModels.clear();
                        operateModels.append({"title": qsTr("pccut_media_filter_all"),      "filterType": CloudAlbumFilterPopup.FilterType.All,      "objectName": "cloudAlbumFilterAllItem"});
                        operateModels.append({"title": qsTr("pccut_media_filter_video"),    "filterType": CloudAlbumFilterPopup.FilterType.Video,    "objectName": "cloudAlbumFilterVideoItem"});
                        operateModels.append({"title": qsTr("pccut_media_filter_image"),    "filterType": CloudAlbumFilterPopup.FilterType.Image,    "objectName": "cloudAlbumFilterImageItem"});
                        operateModels.append({"title": qsTr("pccut_media_filter_favorite"), "filterType": CloudAlbumFilterPopup.FilterType.Favorite, "objectName": "cloudAlbumFilterFavoriteItem"});
                        filterPopup.open();
                    }
                }
                IconButton {
                    id: recycleBinBtn
                    objectName: "cloudAlbumRecycleBinBtn"
                    width: 28; height: 28
                    radius: 6
                    iconWidth: 20; iconHeight: 20
                    visible: !root.showSelectState
                    enabled: !(root.isExpired && !root.hasContent)
                    opacity: enabled ? 1.0 : 0.2
                    iconSource: "qrc:/app_qrc/icons/cloud_album_check.svg"
                    normalColor: Colors.color_2F3032
                    hoverColor: Colors.color_37383A
                    pressedColor: Colors.color_2F3032
                    hoverTextFunc: function() { return qsTr("pccut_cloud_album_recycle_title_empty") }
                    onClicked: {
                        console.log("[CloudAlbum] recycleBinBtn clicked, 清除红点标记")
                        root.recycleBinClicked()
                        CloudAlbumManager.setLocalUiFlag(CloudAlbumManager.RecycleBinUnread, false)
                        root.showRecycleBinDot = false
                    }

                    // 红点指示器
                    Rectangle {
                        x: 17
                        y: 6
                        width: 6
                        height: 6
                        radius: 5
                        color: Colors.color_F22443
                        border.width: 1
                        border.color: recycleBinBtn.hovered ? Colors.color_37383A : Colors.color_2F3032
                        visible: root.showRecycleBinDot

                        onVisibleChanged: console.log("[CloudAlbum] 红点可见性=" + visible + " showRecycleBinDot=" + root.showRecycleBinDot)
                    }
                }

                IconTextButton {
                    id: batchSelectBtn
                    objectName: "cloudAlbumBatchSelectBtn"
                    Layout.preferredHeight: 28
                    Layout.preferredWidth: 88
                    radius: 6
                    usePreferredWidth: false
                    visible: !root.showSelectState && root.hasContent
                    alignment: Qt.AlignLeft
                    enabled: !(root.isExpired && !root.hasContent)
                    opacity: enabled ? 1.0 : 0.2

                    title: qsTr("pccut_cloud_album_batch_select")
                    titleFontSize: 12
                    titleColorNormal: Colors.color_EEEEEE
                    imageRectWidth: 16
                    imageRectHeight: 16

                    iconPathNormal: "qrc:/app_qrc/icons/cloud_album_batch.svg"
                    backgroundColorNormal: Colors.color_2F3032
                    backgroundColorHover: Colors.color_37383A
                    backgroundColorPressed: Colors.color_2F3032
                    internalSpacing: 7
                    leftPadding: 8
                    rightPadding: 8
                    topPadding: 6
                    bottomPadding: 6

                    onCustomClicked: {
                        root.showSelectState = !root.showSelectState;
                        root.batchSelectClicked();
                    }
                }

                // --- 批量选择模式：下载、删除、取消选择独立编组 ---
                RowLayout {
                    id: batchSelectActions
                    visible: root.showSelectState
                    spacing: 24

                    IconTextButton {
                        id: batchDownloadBtn
                        objectName: "cloudAlbumBatchDownloadBtn"
                        height: 28
                        radius: 6

                        enabled: root.selectCount > 0
                        title: qsTr("pccut_device_batch_download")
                        titleColorNormal: enabled ? hovered ? Colors.color_FFFFFF : Colors.color_EEEEEE : Colors.color_444444
                        iconPathNormal: "qrc:/icons/multiple_need_download.svg"
                        iconPathDisable: "qrc:/icons/multiple_need_download_disable.svg"
                        iconPathHover: "qrc:/icons/multiple_need_download_highlight.svg"
                        imageRectWidth: 16
                        imageRectHeight: 16

                        backgroundColorNormal: Colors.color_transparent
                        backgroundColorHover: Colors.color_transparent
                        internalSpacing: 4

                        onCustomClicked: {
                            if (!enabled) return;
                            var selectedIds = root.cloudAlbumModel ? root.cloudAlbumModel.selectedAssetIds() : [];
                            if (selectedIds.length > 0) {
                                root.startDownload(selectedIds, root.getFileNamesForAssetIds(selectedIds), 0);  // 0=button
                            }
                        }
                    }

                    // 删除
                    IconTextButton {
                        id: batchDeleteBtn
                        objectName: "cloudAlbumBatchDeleteBtn"
                        height: 28
                        radius: 6

                        enabled: root.selectCount > 0
                        title: qsTr("pccut_device_batch_delete")
                        titleColorNormal: enabled ? hovered ? Colors.color_FFFFFF : Colors.color_EEEEEE : Colors.color_444444
                        iconPathNormal: "qrc:/icons/multiple_delete.svg"
                        iconPathDisable: "qrc:/icons/multiple_delete_disable.svg"
                        iconPathHover: "qrc:/icons/multiple_delete_hover.svg"
                        imageRectWidth: 16
                        imageRectHeight: 16

                        backgroundColorNormal: Colors.color_transparent
                        backgroundColorHover: Colors.color_transparent
                        internalSpacing: 4

                        onCustomClicked: {
                            if (!enabled) return;
                            var selectedIds = root.cloudAlbumModel ? root.cloudAlbumModel.selectedAssetIds() : [];
                            if (selectedIds.length > 0) {
                                root.showBatchDeletePopup(0)
                            }
                        }
                    }

                    IconTextButton {
                        id: batchCancelBtn
                        objectName: "cloudAlbumBatchCancelBtn"
                        Layout.preferredHeight: 28
                        Layout.preferredWidth: 88
                        radius: 6
                        usePreferredWidth: false
                        alignment: Qt.AlignHCenter
                        enabled: !(root.isExpired && !root.hasContent)
                        opacity: enabled ? 1.0 : 0.2

                        title: qsTr("pccut_device_batch_cancel")
                        titleFontSize: 12
                        titleColorNormal: Colors.color_EEEEEE
                        imageRectWidth: 16
                        imageRectHeight: 16

                        isTextOnly: true
                        backgroundColorNormal: Colors.color_2F3032
                        backgroundColorHover: Colors.color_37383A
                        backgroundColorPressed: Colors.color_2F3032
                        internalSpacing: 7
                        leftPadding: 18
                        rightPadding: 18
                        topPadding: 6
                        bottomPadding: 6

                        onCustomClicked: {
                            root.showSelectState = !root.showSelectState;
                            root.batchSelectClicked();
                        }
                    }
                }
            }
        }

        // 标签行到按钮行间距 16px
        Item { Layout.preferredHeight: 21 }

        // ========== 3. 操作按钮行（白色背景按钮）==========
        RowLayout {
            Layout.leftMargin: 40
            Layout.rightMargin: 40
            spacing: 8

                IconTextButton {
                id: uploadBtn
                objectName: "cloudAlbumUploadBtn"
                enabled: !root.isExpired
                iconPathNormal: "qrc:/app_qrc/icons/cloud_album_upload.svg"
                iconSizeNormal: Qt.size(16, 16)
                title: qsTr("pccut_cloud_album_upload")
                titleFontSize: 12
                titleFontWeight: Font.Medium
                titleColorNormal: Colors.color_141414
                titleColorHover: Colors.color_141414
                titleColorDisable: Colors.color_141414
                backgroundColorNormal: Colors.color_EEEEEE
                backgroundColorHover: Colors.color_FFFFFF
                backgroundColorDisable: Colors.color_EEEEEE_20
                usePreferredWidth: true
                leftPadding: 8
                internalSpacing: 2
                radius: 6
                Layout.preferredHeight: 28
                Layout.preferredWidth: 88
                onCustomClicked: {
                    console.log("[CloudAlbumUpload] uploadBtn.onCustomClicked enabled=" + uploadBtn.enabled
                                + " isExpired=" + root.isExpired)
                    root.openUploadFileDialog()
                }
            }

            IconTextButton {
                id: createAlbumBtn
                objectName: "cloudAlbumCreateAlbumBtn"
                visible: cloudAlbumFeatureFlags.createAlbumEnable
                enabled: !root.isExpired
                iconPathNormal: "qrc:/app_qrc/icons/cloud_album_create.svg"
                iconSizeNormal: Qt.size(16, 16)
                title: qsTr("pccut_cloud_album_create_album")
                titleFontSize: 12
                titleFontWeight: Font.Medium
                titleColorNormal: Colors.color_141414
                titleColorHover: Colors.color_141414
                titleColorDisable: Colors.color_141414
                backgroundColorNormal: Colors.color_EEEEEE
                backgroundColorHover: Colors.color_FFFFFF
                backgroundColorDisable: Colors.color_EEEEEE_20
                usePreferredWidth: true
                leftPadding: 8
                internalSpacing: 2
                radius: 6
                Layout.preferredHeight: 28
                Layout.preferredWidth: 88
                onCustomClicked: root.createAlbumClicked()
            }
        }

        // 按钮行到内容区间距 40px
        Item { Layout.preferredHeight: 40 }

        // ========== 4. StackView 内容区 ==========
        Item {
            id: contentArea
            Layout.fillWidth: true
            Layout.fillHeight: true

            StackLayout {
                id: cloudAlbumContentStack
                objectName: "cloudAlbumContentStack"
                anchors.fill: parent

                currentIndex: root.currentTabIndex

                CloudAlbumGridView {
                    id: gridView
                    objectName: "cloudAlbumGridView"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: filterProxyModel
                    sourceModel: root.cloudAlbumModel
                    showSelectState: root.showSelectState
                    isListMode: root.isListMode
                    leftPadding: 40
                    rightPadding: 40
                    gridRightPadding: 16
                    previewingAssetId: root._previewingAssetId
                    interactionsEnabled: !contentArea.isDragOver

                    onFileDragEntered: { if (!root.isExpired) contentArea.isDragOver = true }
                    onFileDragExited: contentArea.isDragOver = false
                    onFilesDropped: function(urls) {
                        contentArea.isDragOver = false;
                        if (root.isExpired) return;
                        var paths = root.localPathsFromUrls(urls);
                        console.log("[CloudAlbumUpload] gridView.filesDropped count=" + paths.length
                                    + " firstPath=" + (paths.length > 0 ? paths[0] : ""))
                        if (paths.length > 0) {
                            console.log("[CloudAlbumUpload] CloudAlbumTransferModel.addUpload from gridDrop count=" + paths.length)
                            CloudAlbumTransferModel.addUpload(paths, [], 1)  // 1 = UploadMethod::Drag
                        }
                    }
                    onMenuActionClicked: function(actionType, fileId, fileIndex, filePath, useMethod) {
                        if (actionType === CloudAlbumGridView.MenuAction.Delete) {
                            // delete_click 埋点（右键单文件，1=RightClick，汇总一次）
                            var delInfo = root.cloudAlbumModel ? root.cloudAlbumModel.assetInfo(fileId) : {}
                            var delT = delInfo.assetType || 0
                            var delMat = {photo: 0, video: 0, panoPhoto: 0, panoVideo: 0, livePhoto: 0}
                            if (delT === 1)      delMat.photo++
                            else if (delT === 2) delMat.video++
                            else if (delT === 3) delMat.livePhoto++
                            else if (delT === 4) delMat.panoPhoto++
                            else if (delT === 5) delMat.panoVideo++
                            cloudAlbumEventReport.trackDeleteClick(useMethod, delMat, delInfo.fileSizeMB || 0, [fileId])
                            cloudAlbumDeletePopup.showPop([fileId], {
                                size: delInfo.fileSizeMB || 0,
                                materials: delMat
                            });
                        } else if (actionType === CloudAlbumGridView.MenuAction.ToggleFavorite) {
                            // collect_click 埋点（右键收藏，1=RightClick）
                            var colInfo = root.cloudAlbumModel ? root.cloudAlbumModel.assetInfo(fileId) : {}
                            cloudAlbumEventReport.trackCollectClick(!(colInfo.isFavorite || false), useMethod, cloudAlbumEventReport.mediaTypeFromAssetType(colInfo.assetType || 0), colInfo.fileSizeMB || 0, fileId)
                            root.cloudAlbumModel.toggleFavorite(fileId);
                        } else if (actionType === CloudAlbumGridView.MenuAction.DownloadOriginal) {
                            root.startDownload([fileId], [root.getFileNameForAssetId(fileId)], 1);  // 1=right_click
                        }
                    }
                    onSelectionChanged: root.updateSelectCount()
                    onRequestShowSelectState: root.showSelectState = true
                    onItemClicked: function(index, modelData) {
                        var type = parseInt(modelData.fileType || "0");
                        // 仅图片(1/4)走单击预览；动图(3)本体是 MP4，由双击走边下边播，不在此当照片打开。
                        if (type !== 1 && type !== 4) return;
                        var assetId = modelData.assetId || "";
                        var fileName = modelData.fileName || "";
                        if (!assetId || !fileName) return;

                        var isDngFile = fileName.toLowerCase().endsWith(".dng");

                        // Windows DNG preview uses the already loaded thumbnail only.
                        // Do not start a preview download for the original DNG file.
                        if (CommonUtils.isWindows() && isDngFile) {
                            var thumbnailPath = CloudAlbumTransferModel.getThumbnailCachedPath(assetId);
                            if (thumbnailPath.length === 0) return;

                            root._previewingAssetId = assetId
                            root._previewingMediaType = cloudAlbumEventReport.mediaTypeFromAssetType(type)
                            var dngPreviewInfo = root.cloudAlbumModel ? root.cloudAlbumModel.assetInfo(assetId) : {}
                            root._previewingFileSizeMB = dngPreviewInfo.fileSizeMB || 0
                            root._previewOpenTime = Date.now()
                            cloudAlbumEventReport.trackPreviewClick(
                                true, 0,
                                root._previewingMediaType,
                                root._previewingFileSizeMB,
                                assetId, 0)
                            if (type === 4) {
                                openOperator.cloudAlbumOpenAsPanorama([thumbnailPath]);
                            } else {
                                openOperator.cloudAlbumOpen([thumbnailPath]);
                            }
                            return;
                        }
                        // 已下载原图：直接打开，不触发预览下载
                        if ((modelData.downloadState || 0) === 1) {
                            var localPath = CloudAlbumTransferModel.getValidDownloadedLocalPath(assetId);
                            if (localPath.length > 0) {
                                var directPreviewInfo = root.cloudAlbumModel ? root.cloudAlbumModel.assetInfo(assetId) : {}
                                root._previewingAssetId = assetId
                                root._previewingMediaType = cloudAlbumEventReport.mediaTypeFromAssetType(type)
                                root._previewingFileSizeMB = directPreviewInfo.fileSizeMB || 0
                                root._previewOpenTime = Date.now()
                                cloudAlbumEventReport.trackPreviewClick(
                                    true, 0,
                                    root._previewingMediaType,
                                    root._previewingFileSizeMB,
                                    assetId, 0)
                                // 全景图强制全景模式（服务端元数据可信，无需依赖 EXIF）
                                if (type === 4) {
                                    openOperator.cloudAlbumOpenAsPanorama([localPath]);
                                } else {
                                    openOperator.cloudAlbumOpen([localPath]);
                                }
                                return;
                            }
                        }

                        // 未下载或本地路径获取失败：走预览下载流程
                        // 已在下载中，忽略重复点击
                        if (root._previewPendingAssetId === assetId) return;
                        // 若有正在进行的预览下载，先取消（规范不上报 preview_click for cancel）
                        if (root._previewPendingAssetId !== "") {
                            CloudAlbumTransferModel.cancelPreviewDownload();
                        }
                        // 若缩略图已打开、后台下载中，取消并重置
                        if (root._backgroundDownloadAssetId !== "") {
                            root._backgroundDownloadAssetId = "";
                            CloudAlbumTransferModel.cancelPreviewDownload();
                        }
                        root._previewPendingAssetId = assetId;
                        // 记录预览时间和素材信息（供 onPreviewReady/onPreviewFailed/onShowPreviewChanged 使用）
                        root._previewStartTime = Date.now()
                        root._previewingAssetId = assetId
                        root._previewingIsDng = fileName.toLowerCase().endsWith(".dng")
                        root._previewingFileType = type
                        // 将 album::AssetType int 转换为 CloudAlbumEventReport::MediaType int
                        root._previewingMediaType = cloudAlbumEventReport.mediaTypeFromAssetType(type)
                        var previewInfo = root.cloudAlbumModel ? root.cloudAlbumModel.assetInfo(assetId) : {}
                        root._previewingFileSizeMB = previewInfo.fileSizeMB || 0
                        CloudAlbumTransferModel.downloadForPreview(assetId, fileName);
                    }
                    onItemDoubleClicked: function(index, modelData) {
                        var type = parseInt(modelData.fileType || "0");
                        // 视频(2)/全景视频(5)/动图(3，MP4) 双击走边下边播；图片双击不处理。
                        if (type !== 2 && type !== 3 && type !== 5) return;
                        var assetId = modelData.assetId || "";
                        if (!assetId) return;
                        var videoInfo = root.cloudAlbumModel
                                ? root.cloudAlbumModel.assetInfo(assetId) : {}
                        root._previewingAssetId = assetId
                        root._previewingMediaType =
                                cloudAlbumEventReport.mediaTypeFromAssetType(type)
                        root._previewingFileSizeMB = videoInfo.fileSizeMB || 0
                        root._previewStartTime = Date.now()
                        root._previewOpenTime = 0
                        root._previewCloseMethod = 0

                        // 本地已下载 → 直接播本地文件（复用预览窗口）
                        if ((modelData.downloadState || 0) === 1) {
                            var lp = CloudAlbumTransferModel.getValidDownloadedLocalPath(assetId);
                            if (lp.length > 0) {
                                // 本地已下载文件独立于云端，删除云端不关窗：清除记录。
                                CloudAlbumManager.clearPlayingCloudVideo();
                                // 全景视频不能走 cloudAlbumOpenAsPanorama：它会把视频路径登记成
                                // 全景图片，PanoramaCompat 缓存命中后视频被当经纬图渲染。
                                // 普通打开链路自会按 MediaType 识别全景。
                                openOperator.cloudAlbumOpen([lp]);
                                cloudAlbumEventReport.trackPreviewClick(
                                    true, 0,
                                    root._previewingMediaType,
                                    root._previewingFileSizeMB,
                                    assetId, 0)
                                root._previewOpenTime = Date.now()
                                return;
                            }
                        }
                        // 未下载 / 本地路径缺失 → 边下边播（一体化：现取URL+注册+开播）
                        // duration 是秒（model 里 duration_ms/1000），×1000 转毫秒传给 C++
                        var durationMs = (modelData.duration || 0) * 1000;
                        CloudAlbumManager.playCloudVideoStreaming(
                                assetId, durationMs, modelData.mediaType || 0);
                    }
                }

                CloudAlbumGridView {
                    id: highlightGridView
                    objectName: "cloudAlbumHighlightGridView"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: emptyHighlightModel
                    sourceModel: emptyHighlightSourceModel
                    showSelectState: false
                    isListMode: root.isListMode
                    leftPadding: 40
                    rightPadding: 40
                    gridRightPadding: 16
                    previewingAssetId: ""
                }
            }

            // 无内容时显示空状态 / 有内容时拖入文件显示覆盖层
            property bool isDragOver: false

            Rectangle {
                anchors.fill: parent
                anchors.leftMargin: 40
                anchors.rightMargin: 40
                visible: root.currentTabIndex === 0 && (!root.hasContent || contentArea.isDragOver)
                z: 100
                // 有内容时作为覆盖层，不拦截事件，让拖拽事件穿透到 GridView 的 DropArea
                enabled: !root.hasContent
                color: root.hasContent ? Qt.rgba(0.122, 0.125, 0.129, 0.85) : "transparent"

                Loader {
                    anchors.fill: parent
                    active: parent.visible
                    sourceComponent: (root.isExpired && !root.hasContent)
                        ? expiredEmptyPage
                        : emptyUploadPage
                }
            }

            // 筛选后无结果的空态层（有内容但当前筛选条件下无匹配项）
            Item {
                id: filterEmptyState
                objectName: "cloudAlbumFilterEmptyState"
                anchors.fill: parent
                visible: root.currentTabIndex === 0 && root.hasContent
                         && gridView.activeListView.count === 0 && !contentArea.isDragOver

                ColumnLayout {
                    id: filterEmptyColumnLayout
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -32
                    spacing: 12

                    Image {
                        Layout.alignment: Qt.AlignHCenter
                        source: "qrc:/app_qrc/icons/cloud_album_filter_empty.svg"
                        sourceSize: Qt.size(56, 56)
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: qsTr("pccut_cloud_album_filter_no_result")
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        lineHeight: 16
                        lineHeightMode: Text.FixedHeight
                        horizontalAlignment: Text.AlignHCenter
                        color: Colors.color_666666
                    }
                }
            }
        }

        // 空状态: 拖拽上传页
        Component {
            id: emptyUploadPage

            Item {
                objectName: "cloudAlbumEmptyUploadPage"
                property bool isDragOver: false

                // 拖拽时填充背景色
                Rectangle {
                    anchors.fill: parent
                    radius: 8
                    color: parent.isDragOver ? Colors.color_1F2021 : "transparent"
                }

                // 虚线边框
                Canvas {
                    id: dashedBorder
                    anchors.fill: parent

                    property real radius: 8
                    property real strokeWidth: 1.0
                    property real offset: strokeWidth / 2.0

                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        ctx.setLineDash([4, 3]);
                        ctx.strokeStyle = Colors.color_454649;
                        ctx.lineWidth = strokeWidth;
                        drawRoundedRect(ctx, offset, offset,
                            width - offset * 2, height - offset * 2, radius);
                    }

                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()

                    function drawRoundedRect(ctx, x, y, w, h, r) {
                        ctx.beginPath();
                        ctx.moveTo(x + r, y);
                        ctx.lineTo(x + w - r, y);
                        ctx.quadraticCurveTo(x + w, y, x + w, y + r);
                        ctx.lineTo(x + w, y + h - r);
                        ctx.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
                        ctx.lineTo(x + r, y + h);
                        ctx.quadraticCurveTo(x, y + h, x, y + h - r);
                        ctx.lineTo(x, y + r);
                        ctx.quadraticCurveTo(x, y, x + r, y);
                        ctx.closePath();
                        ctx.stroke();
                    }
                }

                // 居中内容
                Item {
                    id: emptyUploadContent
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: 6
                    width: emptyUploadColumnLayout.implicitWidth
                    height: emptyUploadColumnLayout.implicitHeight

                    ColumnLayout {
                        id: emptyUploadColumnLayout
                        anchors.fill: parent
                        spacing: 12

                        Image {
                            Layout.alignment: Qt.AlignHCenter
                            source: "qrc:/app_qrc/icons/cloud_album_upload_large.svg"
                            sourceSize: Qt.size(56, 56)
                        }

                        ColumnLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 8

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: qsTr("pccut_cloud_album_drag_hint")
                                font.pixelSize: 12
                                color: Colors.color_FFFFFF
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: qsTr("pccut_cloud_album_format_hint")
                                font.pixelSize: 11
                                color: Colors.color_666666
                            }
                        }
                    }
                }

                // 拖拽区域
                DropArea {
                    id: emptyDropArea
                    objectName: "cloudAlbumEmptyUploadDropArea"
                    anchors.fill: parent
                    function handleDroppedUrls(urls) {
                        var paths = root.localPathsFromUrls(urls);
                        console.log("[CloudAlbumUpload] emptyDropArea.dropped count=" + paths.length
                                    + " firstPath=" + (paths.length > 0 ? paths[0] : ""))
                        if (paths.length > 0) {
                            console.log("[CloudAlbumUpload] CloudAlbumTransferModel.addUpload from emptyDrop count=" + paths.length)
                            CloudAlbumTransferModel.addUpload(paths, [], 1)  // 1 = UploadMethod::Drag
                        }
                    }
                    onEntered: parent.isDragOver = true
                    onExited: parent.isDragOver = false
                    onDropped: function(drop) {
                        parent.isDragOver = false;
                        if (root.isExpired) return;
                        if (drop.hasUrls) {
                            handleDroppedUrls(drop.urls)
                        }
                    }
                }

                // 点击上传
                MouseArea {
                    id: emptyUploadMouseArea
                    objectName: "cloudAlbumEmptyUploadClickArea"
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        console.log("[CloudAlbumUpload] emptyUploadMouseArea.onClicked")
                        root.openUploadFileDialog()
                    }
                }
            }
        }
    } // ColumnLayout
    } // Item (index 1)
    } // StackLayout

    // 过期空状态: 不可上传，提示续订
    Component {
        id: expiredEmptyPage

        Item {
            objectName: "cloudAlbumExpiredEmptyPage"
            // 居中提示内容
            Item {
                id: expiredEmptyContent
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -17
                width: expiredEmptyColumnLayout.implicitWidth
                height: expiredEmptyColumnLayout.implicitHeight

                ColumnLayout {
                    id: expiredEmptyColumnLayout
                    anchors.fill: parent
                    spacing: 8

                    Image {
                        Layout.alignment: Qt.AlignHCenter
                        source: "qrc:/app_qrc/icons/cloud_album_upload_expired_large.svg"
                        sourceSize: Qt.size(56, 56)
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: qsTr("pccut_cloud_album_expired_empty_desc").arg(root.expireDeleteMeta)
                        font.pixelSize: 12
                        color: Colors.color_666666
                    }
                }
            }
        }
    }

    // 筛选弹框
    CloudAlbumFilterPopup {
        id: filterPopup
        objectName: "cloudAlbumFilterPopup"
        x: 0
        y: 0
        parent: Overlay.overlay
        currentFilterType: root.currentFilterType
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        Overlay.modal: Rectangle {
            color: Colors.color_transparent
        }
        onClickFilterType: (filterType) => {
            root.currentFilterType = filterType;
            root.filterTypeChanged(filterType);
        }
    }

    // 删除确认弹框
    CloudAlbumDeletePopup {
        id: cloudAlbumDeletePopup
        objectName: "cloudAlbumDeletePopup"
        parent: Overlay.overlay

        onConfirmDelete: function(fileIds) {
            // delete_confirm 埋点（确认删除，汇总 size 和 materials）
            var confirmTotalSizeMB = 0
            var confirmMat = {photo: 0, video: 0, panoPhoto: 0, panoVideo: 0, livePhoto: 0}
            if (root.cloudAlbumModel) {
                for (var ci = 0; ci < fileIds.length; ci++) {
                    var confirmInfo = root.cloudAlbumModel.assetInfo(fileIds[ci])
                    confirmTotalSizeMB += (confirmInfo.fileSizeMB || 0)
                    var ct = confirmInfo.assetType || 0
                    if (ct === 1)      confirmMat.photo++
                    else if (ct === 2) confirmMat.video++
                    else if (ct === 3) confirmMat.livePhoto++
                    else if (ct === 4) confirmMat.panoPhoto++
                    else if (ct === 5) confirmMat.panoVideo++
                }
            }
            cloudAlbumEventReport.trackDeleteConfirm(true, fileIds, confirmTotalSizeMB, confirmMat)
            root.cloudAlbumModel.deleteAssets(fileIds);
        }
    }

    // 空间不足弹窗
    Connections {
        target: CloudAlbumTransferModel
        function onDownloadDiskSpaceInsufficient() {
            if (root.visible && !downloadDiskSpacePopup.opened) {
                downloadDiskSpacePopup.open()
            }
        }
    }

    ConfirmPopup {
        id: downloadDiskSpacePopup
        objectName: 'cloudAlbumDownloadDiskSpacePopup'
        parent: Overlay.overlay
        onlyOneBtn: true
        title: qsTr('pccut_cloud_album_err_disk_full')
        text: qsTr('pccut_device_batch_download_low_storage')
        leftButtonText: qsTr('pccut_common_text_got_it')
    }

    CloudAlbumSpacePopup {
        id: cloudAlbumSpacePopup
        objectName: "cloudAlbumSpacePopup"
        parent: Overlay.overlay

        onExpandStorageClicked: root.expandStorageClicked()
    }
}
