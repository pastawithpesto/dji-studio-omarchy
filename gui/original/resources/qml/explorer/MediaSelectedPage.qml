import Config 1.0
import Controls 1.0
import Qt.labs.platform 1.1
import Qt5Compat.GraphicalEffects
import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Dialogs
import QtCore
import QtQuick.Layouts 1.3
import MediaListViewModel 1.0
import ShortcutAction 1.0
import DeviceMaterialAsyncLoader 1.0
import AgencyManager 1.0
import QPlayType 1.0
import Qt5Compat.GraphicalEffects
import HighlightTaskStatus 1.0
import "../welcome"
import app_qrc 1.0

import DeviceMediaCategory 1.0
import AlgBizHighLightModel 1.0
import HighLightThemeTabViewModel 1.0
import QmlConstants 1.0
import CloudAlbumTransferModel 1.0

/**
 * @author robert.guo
 * @desc 本地素材列表详情页
 * @create_date 2024-04-11
 */
Item {
    id: root
    objectName: actionableItemName.mediaSelectedPage
    property var mediaListViewModel
    property bool isLocal
    property bool hasDiskAccessPermission: USBDeviceDetector.hasDiskAccessPermission
    
    property bool isScrolling: false
    property string pendingPreviewAssetId: ""
    property real pendingPreviewSeekPercentage: -1

    property bool isSelectHighlightTab: root.mediaListViewModel.mediaCategoryType == DeviceMediaCategory.Highlight

    property bool isMediaListFocused: false

    MouseArea {
        anchors.fill: parent
        onPressed: (mouse) => {
            root.isMediaListFocused = true;
            globalSignal.cleanTrackSelectState();
            mouse.accepted = false;
        }
    }

    // 拖拽添加时候的UI样式
    DragMediaCover {
        id: draggableRect
        mediaListViewModel: root.mediaListViewModel
    }

    onMediaListViewModelChanged: {
        root.mediaListViewModel.setGridview(gridView)
    }

    // 选择目录弹窗
    Loader {
        id: fileFolderLoader
        property var fileList: []
        //*#*#*# 循环录影：批量下载参数列表，非空时优先使用 copyBatchFiles
        property var batchParams: []
        active: false
        anchors.fill:parent
        function showFolder(isShow) {
            if (isShow) {
                active = true;
                var defaultPath = lightSetting.getString("curCopyPath", StandardPaths.writableLocation(StandardPaths.DownloadLocation));
                defaultPath = fileOperator.isDirExists(defaultPath)?defaultPath:StandardPaths.writableLocation(StandardPaths.DownloadLocation);
                item.currentFolder = fileOperator.FileUrlWithPreFix(defaultPath);
                item.open();
            } else {
                item.close();
                active = false;
            }
        }

        sourceComponent: FolderDialog {
            id: fileDialog
            onAccepted: {
                var needCopyList = fileList
                var rawPath = fileDialog.currentFolder.toString()
                // 去掉 file:///
                var cleanedPath = rawPath.replace(/^file:\/\//, "")
                // Windows 下去掉开头的斜杠
                if (Qt.platform.os === "windows") {
                    cleanedPath = cleanedPath.replace(/^\//, "")
                }

                lightSetting.save("curCopyPath",cleanedPath)
                //*#*#*# 循环录影：batchParams 非空时调用批量下载接口，支持循环录影整组下载
                if (fileFolderLoader.batchParams && fileFolderLoader.batchParams.length > 0) {
                    // capture + clear，跟 loop 同理：dialog 异步回调时 fileFolderLoader 字段可能已被清空
                    var bp = fileFolderLoader.batchParams
                    fileFolderLoader.batchParams = [];
                    root.startBatchCopyWithStorageCheck(bp, cleanedPath);
                } else {
                    root.startCopyWithStorageCheck(needCopyList, cleanedPath);
                }
                fileFolderLoader.active = false;
            }
            onRejected: {
                fileFolderLoader.batchParams = [];  //*#*#*# 循环录影
                fileFolderLoader.active = false;
            }
        }
    }

    function startCopyWithStorageCheck(needCopyList, cleanedPath) {
        var totalSizeMB = copyFileManager.calculateTotalSizeMB(needCopyList)
        if (fileOperator.checkStorageWarn(cleanedPath, totalSizeMB)) {
            var storageWarnDialog = Qt.createComponent("qrc:/Controls/ConfirmPopup.qml").createObject(root, {
                "title": qsTr("pccut_device_batch_download_low_storage"),
                "leftButtonText": qsTr("pccut_quick_delete_cancel"),
                "rightButtonText": qsTr("pccut_panel_image_directionlock_continue_yes")
            })

            if (!storageWarnDialog) {
                console.warn("Failed to create ConfirmPopup")
                copyFilePopup.open();
                copyFileManager.copyFileList(needCopyList, cleanedPath)
                return
            }

            storageWarnDialog.onRightButtonClicked.connect(function() {
                copyFilePopup.open();
                copyFileManager.copyFileList(needCopyList, cleanedPath)
            })
            storageWarnDialog.onClosed.connect(function() {
                storageWarnDialog.destroy()
                storageWarnDialog = null
            })
            storageWarnDialog.open()
        } else {
            copyFilePopup.open();
            copyFileManager.copyFileList(needCopyList, cleanedPath)
        }
    }

    //*#*#*# 多选下载（含循环录影）专用预检：copyBatchFiles 内部按 isLoopVideo 分发
    function startBatchCopyWithStorageCheck(batchParams, cleanedPath) {
        // 多选含循环录影时 needCopyList 含 .osv 虚拟路径，QFileInfo 算成 0；必须用 batch 版
        var totalSizeMB = copyFileManager.calculateBatchTotalSizeMB(batchParams)
        if (fileOperator.checkStorageWarn(cleanedPath, totalSizeMB)) {
            var storageWarnDialog = Qt.createComponent("qrc:/Controls/ConfirmPopup.qml").createObject(root, {
                "title": qsTr("pccut_device_batch_download_low_storage"),
                "leftButtonText": qsTr("pccut_quick_delete_cancel"),
                "rightButtonText": qsTr("pccut_panel_image_directionlock_continue_yes")
            })
            storageWarnDialog.onRightButtonClicked.connect(function() {
                copyFilePopup.open();
                copyFileManager.copyBatchFiles(batchParams, cleanedPath)
            })
            storageWarnDialog.onClosed.connect(function() {
                storageWarnDialog.destroy()
                storageWarnDialog = null
            })
            storageWarnDialog.open()
        } else {
            copyFilePopup.open();
            copyFileManager.copyBatchFiles(batchParams, cleanedPath)
        }
    }

    // 展示样式，列表or 网格
    property bool mGridMode: root.mediaListViewModel.isGridMode
    // 最后一个选中并且播放的文件路径
    property string lastSelectPlayAssetId: ""
    onLastSelectPlayAssetIdChanged: {
        selectMediaPlayedPercentage = -1;
        if (lastSelectPlayAssetId == null || lastSelectPlayAssetId.length < 1) {
            root.mediaListViewModel.stopPreviewPlay();
        }
    }
    // 选中的视频的播放进度
    property real selectMediaPlayedPercentage: -1

    // 鼠标悬停的的文件id
    property string mouseAssetId: ""

    // 是否起播完成
    property bool isStartPlay: false
    // 是否正在播放
    property bool isPlaying: root.mediaListViewModel.isPlaying
    // 封面的宽度
    property real itemCoverWidth: mGridMode ? 128 : gridView.width - 18
    // 封面的高度
    property real itemCoverHeight: mGridMode ? 72 : 48
    // 封面在本cell item中的x
    property real itemCoverX: 6
    // 鼠标在封面上的x的坐标
    property real mouseInItemX: 0

    onIsPlayingChanged: {
        if (isPlaying && mouseAssetId.length > 0 && !root.mediaListViewModel.isSelectedForAssetId(mouseAssetId) && mouseAssetId === root.mediaListViewModel.previewingMediaAssetId()) {
            lastSelectPlayAssetId = mouseAssetId;
            root.mediaListViewModel.resetSelectedAssets([mouseAssetId]);
        }

        //只有一个被选中的时候才会开启,点击非预览区和非播放暂停,不会触发该信号
        if (root.mediaListViewModel.selectPathSize === 1) {
            globalSignal.previewStatusChanged(isPlaying, root.mediaListViewModel.previewingMediaPath());
        }
    }

    onIsScrollingChanged: {
        if (!isScrolling && pendingPreviewAssetId !== "") {
            delayShowPreviewTimer.restart();
        }
    }
    // 悬停预览是否能用
    property bool isSeekAble: false

    // 点击添加到轨道素材路径列表
    signal clikAddMedia(var fileList)

    // 监听素材变化
    Connections {
        target: globalSignal
        // 点击导出
        function onClickExportAction() {
            root.mediaListViewModel.resetSelectedAssets();
        }
        // 轨道片段选中状态变更，重置资源列表焦点
        function onMultiSelectStateChanged() {
            root.isMediaListFocused = false;
        }
        // 清空选中状态
        function onCleanSelectMediaPath() {
            root.isMediaListFocused = false;
            cleanSelectPath();
        }

        // 轨道视频选中，这里就取消选中
        function onVideoSelected(fragment) {
            if (!CommonUtils.isNull(fragment)) {
                cleanSelectPath();
            }
        }
        // 快捷键预览轴开关变化
        function onShowHoverPreviewChanged(showHover, isInTrackMouse) {
            if (!visible) {
                return;
            }
            // 只是预览文件库
            if (editorManager.playType === QPlayType.preview && lastSelectPlayAssetId.length < 1 && !showHover) {
                isSeekAble = false;
                root.mediaListViewModel.stopPreviewPlay();
                return;
            }
            // 预览轨道但是文件库有选中 回到预览轴
            if (editorManager.playType !== QPlayType.preview && !showHover && lastSelectPlayAssetId.length > 0 && !root.mediaListViewModel.isPlaying) {
                showPreviewMedia(lastSelectPlayAssetId, false, selectMediaPlayedPercentage);
                return;
            }
            isSeekAble = showHover;
            if (showHover) {
                // 打开预览轴情况
                if (mouseAssetId === root.mediaListViewModel.previewingMediaAssetId()) {
                    root.mediaListViewModel.pause();
                    root.mediaListViewModel.coverSeek(mouseInItemX / itemCoverWidth);
                } else if (isInTrackMouse) {
                    root.mediaListViewModel.stopPreviewPlay();
                } else {
                    root.mediaListViewModel.pause();
                    isSeekAble = false;
                }
            } else {
                if (!root.mediaListViewModel.isPlaying) {
                    // 关闭预览轴
                    if (root.mediaListViewModel.isSelectedForAssetId(root.mediaListViewModel.previewingMediaAssetId())) {
                        root.mediaListViewModel.coverSeek(selectMediaPlayedPercentage);
                    } else {
                        if (lastSelectPlayAssetId.length > 0) {
                            showPreviewMedia(lastSelectPlayAssetId, false, selectMediaPlayedPercentage);
                        } else {
                            root.mediaListViewModel.stopPreviewPlay();
                        }
                    }
                }
            }
        }
        // 鼠标进入编辑器轨道
        function onTrackDockContainsMouseChanged(isContains) {
            if (!visible) {
                return;
            }
            if (lastSelectPlayAssetId == null || lastSelectPlayAssetId.length < 1) {
                // 多选的情况下
                if (isContains && editorManager.playType === QPlayType.preview && !root.mediaListViewModel.isPlaying) {
                    root.mediaListViewModel.stopPreviewPlay();
                }
                return;
            }
            // 判断分开写 为了代码易读
            if (!root.mediaListViewModel.showHoverPreview() || root.mediaListViewModel.isPlaying) {
                return;
            }
            if (isContains && editorManager.playType === QPlayType.preview) {
                root.mediaListViewModel.pause();
                root.mediaListViewModel.stopPreviewPlay();
            } else if (!isContains && editorManager.playType === QPlayType.editor && lastSelectPlayAssetId.length > 0) {
                showPreviewMedia(lastSelectPlayAssetId, false, selectMediaPlayedPercentage);
            }
        }
    }
    Connections {
        target: root.mediaListViewModel
        function onIsGridModeChanged() {
            // 由于布局发生变化,直接滚动有些问题, 所以加了延时
            delayTimer.start();
        }
        function onIsASCChanged() {
            positionToSelected();
        }
        function onOrderTypeChanged() {
            positionToSelected();
        }
        // 监听播放位置
        function onPlayedPercentageChanged() {
            if (lastSelectPlayAssetId.length > 0 && lastSelectPlayAssetId === root.mediaListViewModel.previewingMediaAssetId()) {
                selectMediaPlayedPercentage = root.mediaListViewModel.playedPercentage;
            }
        }
        // 选中的文件数量发生变化
        function onSelectPathSizeChanged() {
            if (root.mediaListViewModel.selectPathSize !== 1) {
                lastSelectPlayAssetId = "";
            }
        }
        // 点击添加时候添加的素材列表
        function onDidClickAddFilePaths(fileList) {
            clikAddMedia(fileList);
        }
    }

    Timer {
        id: delayTimer
        interval: 50
        repeat: false
        onTriggered: {
            positionToSelected();
        }
    }
    
    Timer {
        id: delayShowPreviewTimer
        interval: isLocal ? 0 : 300
        repeat: false
        onTriggered: {
            if (isScrolling) {
                return;
            }
            if (pendingPreviewAssetId !== "" && mouseAssetId === pendingPreviewAssetId) {
                showPreviewMedia(pendingPreviewAssetId, false, pendingPreviewSeekPercentage);
            }
            pendingPreviewAssetId = "";
            pendingPreviewSeekPercentage = -1;
        }
    }

    function scrollToTarget() {
        positionToSelected();
    }

    // 当片段添加到轨道上，在删除、移除时的弹框
    ConfirmPopup {
        id: fileOperateRemoveAlert
        property string deletePath:""
        title: qsTr("pccut_media_remove_title")
        text: qsTr("pccut_media_remove_add_tips")
        leftButtonText: qsTr("pccut_draft_delete_popup_cancel")

        rightButtonText: qsTr("pccut_records_confirm_delete_yes")

        onRightButtonClicked: {
            root.mediaListViewModel.removeSelectedAssets()
        }
    }
    // 硬件删除素材
    DeviceRemovePopup {
        id: deviceRemovePopup
        isDownloadRemove: root.mediaListViewModel.pageType === MediaListViewModel.PAGE_DOWNLOAD
        //*#*#*# 循环录影：供 expandToRealPaths 展开循环录影路径为真实子文件路径
        fileInfoModel: mediaListViewModel
        onShowToast: (toastStr) => {
            toast.showToast(toastStr);
        }
        onBeforeRemove: {
            isSeekAble = false;
            // 主要是windows 上播放器中如果使用的话，就肯定删除不成功，所以先停止播放器
            root.mediaListViewModel.stopPreviewPlay();
        }
        function showRemovePop() {
            if (root.mediaListViewModel.pageType === MediaListViewModel.PAGE_DOWNLOAD) {
                //*#*#*# 循环录影：循环录影传虚拟路径，普通文件传 UUID
                var idList = mediaListViewModel.getSelectedIdList();
                var deleteIds = [];
                for (var i = 0; i < idList.length; i++) {
                    var isLoop = mediaListViewModel.getVideoGroupIdForAssetId(idList[i]).length > 0;
                    deleteIds.push(isLoop ? mediaListViewModel.getPathForAssetId(idList[i]) : idList[i]);
                }
                deviceRemovePopup.showPop(deleteIds);
            } else {
                deviceRemovePopup.showPop(root.mediaListViewModel.getSelectedPathList());
            }
        }
    }

    // 高光删除
    Loader {
        id: highlightRemovePopupLoader
        active: false
        sourceComponent: HighlightRemovePopup {
            onShowToast: (toastStr) => {
                globalSignal.toast(toastStr);
            }
        }
    }

    // copy 下载
    CopyFilePopup {
        id: copyFilePopup
        isFinshed: false
        Connections {
            target: copyFileManager
            function onAllFinished(errorList) {
                if (!copyFilePopup.visible) {
                    return;
                }
                if (errorList.length > 0) {
                    copyFilePopup.close();
                    globalSignal.toast(qsTr("pccut_device_batch_download_fail").arg(errorList.length));
                } else {
                    copyFilePopup.isFinshed = true;
                }
            }
        }

        onRightButtonClicked: {
            mediaTab.checkMediaDownload();
        }

        function copyFiles() {
            //*#*#*# 循环录影：使用 getSelectedBatchDownloadParams 获取批量下载参数，支持循环录影整组下载
            var batchParams = root.mediaListViewModel.getSelectedBatchDownloadParams();
            if (batchParams.length === 0) {
                toast.showToast(qsTr("pccut_device_batch_download_save"));
                return;
            }
            fileFolderLoader.batchParams = batchParams;
            fileFolderLoader.showFolder(true);
        }
    }

    /**
     * @desc 打开文件操作弹框
     *
     * @x 弹框显示的x坐标
     * @y 弹框显示的y坐标
     * @operateFileIndex 操作文件索引
     * @return 无
     */
    function openPopup(x, y, assetId, openPath, fileMd5, isFavourite, mediaExist, agency16KTimelapseLost, isDownload, isSupportHighlight) {
        if (visible) {
            root.mediaListViewModel.pause();
            if (!root.mediaListViewModel.isSelectedForAssetId(assetId)) {
                root.mediaListViewModel.resetSelectedAssets([assetId]);
            }
            fileOperatePopup.isDownload = isDownload;
            fileOperatePopup.pageType = root.mediaListViewModel.pageType;
            fileOperatePopup.assetId = assetId;
            fileOperatePopup.openPath = openPath;
            fileOperatePopup.fileMd5 = fileMd5 || "";
            fileOperatePopup.x = x;
            fileOperatePopup.y = y;
            fileOperatePopup.isFavourite = isFavourite;
            fileOperatePopup.mediaExist = mediaExist;
            fileOperatePopup.agency16KTimelapseLost = agency16KTimelapseLost;
            fileOperatePopup.isSupportHighlight = isSupportHighlight;
            fileOperatePopup.showPop();
        }
    }

    // 时间格式化
    function timeFormat(duration) {
        var seconds = duration / 1000;
        var showSecound = Math.floor(seconds % 60);
        var showMinute = Math.floor((seconds % 3600) / 60);
        var showHour = Math.floor(seconds / 3600);
        var result = ("0" + showMinute).slice(-2) + ":" + ("0" + showSecound).slice(-2);
        if (showHour > 0) {
            return ("0" + showHour).slice(-2) + ":" + result;
        }
        return result;
    }
    // 点击背景做取消选中
    function clickBgView(point) {
        var isInCover = false;
        var gridPoint = mapToItem(gridView, point.x, point.y + gridView.contentY);
        // 点击到右侧的滚动条
        if (gridView.width - gridPoint.x < 10) {
            isInCover = true;
}
        var item = gridView.itemAt(gridPoint.x, gridPoint.y);
        if (!isInCover && item !== null) {
            var itemPoint = gridView.mapToItem(item, point);
            isInCover = item.mediaCoverContains(itemPoint);
        }
        // 如果没有点击在封面上就取消选中
        if (!isInCover) {
            root.mediaListViewModel.resetSelectedAssets();
        }
    }
    // 清空选中状态
    function cleanSelectPath() {
        isSeekAble = false;
        root.mediaListViewModel.pause();
        root.mediaListViewModel.stopPreviewPlay();
        root.mediaListViewModel.resetSelectedAssets();
    }

    // 快捷键 粗剪in
    CShortcut {
        action: ShortcutAction.ROUGH_IN
        enabled: isLocal && root.visible
        onActivated: {
            if (root.mediaListViewModel.selectPathSize !== 1) {
                return;
            }
            let index = root.mediaListViewModel.indexForId(root.mediaListViewModel.firstSelectAssetId());
            let item = gridView.itemAtIndex(index);
            if (index >= 0 && item !== null) {
                item.shortcutAction(true);
            }
            eventTracker.trackEvent("pccut_rough_cut")
        }
    }
    // 快捷键 粗剪out
    CShortcut {
        action: ShortcutAction.ROUGH_OUT
        enabled: isLocal && root.visible
        onActivated: {
            if (root.mediaListViewModel.selectPathSize !== 1) {
                return;
            }
            let index = root.mediaListViewModel.indexForId(root.mediaListViewModel.firstSelectAssetId());
            let item = gridView.itemAtIndex(index);
            if (index >= 0 && item !== null) {
                item.shortcutAction(false);
            }
            eventTracker.trackEvent("pccut_rough_cut")
        }
    }

    CShortcut {
        action: ShortcutAction.DELETE
        enabled: root.visible && root.mediaListViewModel.selectPathSize > 0
        onActivated: {
            if (root.isSelectHighlightTab) {
                // 高光tab：调用高光删除弹窗
                var highlightsMap = root.mediaListViewModel.getSelectedHighlightsMap();
                highlightRemovePopupLoader.active = true;
                highlightRemovePopupLoader.item.showPop(highlightsMap);
            } else if (isLocal) {
                tryRemoveFileFromList();
            } else {
                deviceRemovePopup.showRemovePop();
            }
        }
    }

    CShortcut {
        action: ShortcutAction.SELECT_ALL
        enabled: root.visible && root.isMediaListFocused && root.mediaListViewModel !== null
        priority: 1
        onActivated: {
            root.mediaListViewModel.selectAll();
        }
    }

    function positionToSelected() {
        var index = root.mediaListViewModel.indexForId(root.mediaListViewModel.firstSelectAssetId());
        if (index >= 0) {
            gridView.positionViewAtIndex(index, GridView.Beginning);
        }
    }

    function showPreviewMedia(assetId, autoPlay = false, seekPercentage = -1) {
        if (root.isScrolling) {
            pendingPreviewAssetId = assetId;
            pendingPreviewSeekPercentage = seekPercentage;
            return;
        }

        if (root.mediaListViewModel.selectPathSize === 1 && root.mediaListViewModel.isSelectedForAssetId(assetId)) {
            lastSelectPlayAssetId = assetId;
        }
        root.mediaListViewModel.coverEnter(assetId, autoPlay, seekPercentage);
    }


    // 选中某个导入的素材
    function selectMaterial(assetId, autoPlay, playedPercentage) {
        if (lastSelectPlayAssetId === assetId) {
            return;
        }
        root.mediaListViewModel.resetSelectedAssets([assetId]);
        root.mediaListViewModel.playedPercentage = playedPercentage;
        showPreviewMedia(assetId, true, playedPercentage);
        const showHoverLine = root.mediaListViewModel.showHoverPreview();
        isSeekAble = showHoverLine;
        selectMediaPlayedPercentage = playedPercentage;
    }

    function tryRemoveFileFromList(assetId, ) {
        // 正在使用，需要弹框提示用户
        if (root.mediaListViewModel.isUsedInTrackForSelectedPaths()) {
            fileOperateRemoveAlert.open();
        } else {
            root.mediaListViewModel.removeSelectedAssets();
        }
    }

    Item {
        anchors.fill: parent
        FileOperatePopup {
            id: fileOperatePopup
            property string assetId: ""
            property string openPath: ""
            property string fileMd5: ""
            property bool isClicked: false
            mediaListViewModel: root.mediaListViewModel  // 绑定 mediaListViewModel，用于判断当前是否在高光Tab页
            closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
            onClickType: (modeType) => {
                logger.d("onUpdateIndex modeType:" + modeType + " removeFileIndex = ");
                switch (modeType) {
                case Instance.FILE_OPERATE_TYPE.TYPE_OF_REMOVE_FILE_FROM_LIST:
                    // 从文件列表移除
                    tryRemoveFileFromList();
                    eventTracker.trackEvent("pccut_assets_rightclick", {"function": "remove"})
                    break;
                case Instance.FILE_OPERATE_TYPE.TYPE_OF_MEDIA_DEVICE_REMOVE:
                    // 硬件删除素材
                    deviceRemovePopup.showRemovePop();
                    break;
                case Instance.FILE_OPERATE_TYPE.TYPE_OF_MEDIA_DEVICE_DOWNLOAD:
                    // 硬件下载素材
                    copyFilePopup.copyFiles();
                    break;
                case Instance.FILE_OPERATE_TYPE.TYPE_OF_FAVORITE:
                    // 收藏
                    root.mediaListViewModel.setFavoriteForSelectedPaths(!isFavourite);
                    eventTracker.trackEvent("pccut_favorites", {"use_method": "rightclick"})
                    eventTracker.trackEvent("pccut_assets_rightclick", {"function": "favorites"})
                    break;
                case Instance.FILE_OPERATE_TYPE.TYPE_OF_OPEN_FILE:
                    // 循环素材：revealPaths 返回所有子文件路径；普通文件返回单路径列表
                    // Qt.callLater 推迟到信号处理器退出后执行，避免打开文件管理器时因失焦导致
                    // popup 在信号处理中被销毁引发崩溃
                    var openPaths = root.mediaListViewModel.revealPaths(assetId);
                    Qt.callLater(function() {
                        fileOperator.openExplorerAtFiles(openPaths);
                    });
                    eventTracker.trackEvent("pccut_assets_rightclick", {"function": "folder"})
                    break;
                case Instance.FILE_OPERATE_TYPE.TYPE_OF_AGENCY_OPEN:
                    // 开启代理文件
                    root.mediaListViewModel.setOpenAgencyForSelectedPaths(true);
                    eventTracker.trackEvent("pccut_assets_rightclick", {"function": "proxy_open"})
                    break;
                case Instance.FILE_OPERATE_TYPE.TYPE_OF_AGENCY_CLOSE:
                    // 关闭代理文件
                    root.mediaListViewModel.setOpenAgencyForSelectedPaths(false);
                    eventTracker.trackEvent("pccut_assets_rightclick", {"function": "proxy_cancel"})
                    break;
                case Instance.FILE_OPERATE_TYPE.TYPE_OF_MEDIA_LINK:
                    // 需要找到所有选中的媒体中丢失的部分
                    if (root.mediaListViewModel.isSelectedForAssetId(assetId)) {
                        const tfInfos = root.mediaListViewModel.getLostTrackingFiles(true);
                        if (tfInfos.length > 0) {
                            globalSignal.manualLinkMedia(tfInfos);
                        }
                    } else {
                        const tfInfo = root.mediaListViewModel.getTrackingFileInfo(assetId);
                        globalSignal.manualLinkMedia([tfInfo]);
                    }
                    eventTracker.trackEvent("pccut_assets_rightclick", {"function": "link_media"})
                    break;
                case Instance.FILE_OPERATE_TYPE.TYPE_OF_MEDIA_DEVICE_COPIED_OPEN:
                    // 循环素材：getCopiedPaths 返回所有已下载子文件本地路径；普通文件返回单路径列表
                    var copiedPaths = root.mediaListViewModel.getCopiedPaths(assetId);
                    Qt.callLater(function() {
                        if (copiedPaths.length > 0) {
                            fileOperator.openExplorerAtFiles(copiedPaths);
                        }
                    });
                    eventTracker.trackEvent("pccut_assets_rightclick", {"function": "folder"})
                    break;

                case Instance.FILE_OPERATE_TYPE.TYPE_OF_MEDIA_HIGHLIGHT:
                    root.mediaListViewModel.startHighlightAnalyzeForSelected()
                    highlightManager.eventTrackingStart("edit");  // 高光分析埋点
                    break;

                case Instance.FILE_OPERATE_TYPE.TYPE_OF_MEDIA_CANCEL_HIGHLIGHT:
                    root.mediaListViewModel.cancelHighlightAnalyzeForSelected()
                    highlightManager.eventTrackingCancel("edit");  // 高光分析埋点

                    break;
                case Instance.FILE_OPERATE_TYPE.TYPE_OF_MEDIA_DEL_HIGHLIGHT:
                    root.mediaListViewModel.removeMediaAllHighlightsForSelected()
                    highlightManager.eventTrackingCancel("edit");  // 高光分析埋点
                    break;
                case Instance.FILE_OPERATE_TYPE.TYPE_OF_DEL_HIGHLIGHT_ITEM:
                    var highlightsMap = root.mediaListViewModel.getSelectedHighlightsMap();
                    highlightRemovePopupLoader.active = true;
                    highlightRemovePopupLoader.item.showPop(highlightsMap);
                    break;
                case Instance.FILE_OPERATE_TYPE.TYPE_OF_MEDIA_ROUGH_CUT: {
                    root.mediaListViewModel.openRoughCutLoadingPanel()
                    var roughCutIds = root.mediaListViewModel.selectPathSize > 1
                        ? root.mediaListViewModel.getSelectedIdList()
                        : [fileOperatePopup.assetId];
                    root.mediaListViewModel.checkLoginBeforeRoughCut(roughCutIds);
                    break;
                }
                case Instance.FILE_OPERATE_TYPE.TYPE_OF_UPLOAD_CLOUD_ALBUM:
                    CloudAlbumTransferModel.addUpload([openPath], [fileMd5]);
                    break;
                default:
                    eventTracker.trackEvent("pccut_assets_rightclick", {"function": "no"})
                    break;
                }
                isClicked = true
            }
            onClosed: {
                if (!isClicked) {
                    eventTracker.trackEvent("pccut_assets_rightclick", {"function": "no"})
                }
                isClicked = false
            }
        }
        StackLayout {
            anchors.fill: parent
            currentIndex: (root.mediaListViewModel.pageType === MediaListViewModel.PAGE_DEVICE && !hasDiskAccessPermission) ? 0 : 1
    
            Item {
                id: permissionGuidancePage
                ColumnLayout {
                    id: contentLayout
                    spacing: 0
                    anchors.left: parent.left
                    anchors.right: parent.right
                    property double customImplicitHeight: 0.0
                    y: (parent.height - customImplicitHeight) / 2 * 0.8
                    Image {
                        Layout.preferredWidth: 40
                        Layout.preferredHeight: 47
                        Layout.alignment: Qt.AlignHCenter
                        source: "qrc:/icons/icon_lock.svg"
                    }
                    Text {
                        Layout.topMargin: 12
                        Layout.alignment: Qt.AlignHCenter
                        font {
                            pixelSize: 12
                            weight: Font.DemiBold
                        }
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                        color: Colors.color_EEEEEE
                        text: qsTr("pccut_permission_movable_access_permission")
                    }
                    Item {
                        id: tipsLineLayout
                        Layout.fillWidth: true
                        Layout.topMargin: 8
                        Layout.preferredHeight: tipsText.height
                        Text {
                            id: tipsText
                            width: implicitWidth + 2 * (tipsIcon.width + 2) > parent.width ? parent.width - 2 * (tipsIcon.width + 2) : implicitWidth
                            anchors.horizontalCenter: parent.horizontalCenter
                            font {
                                pixelSize: 11
                                weight: Font.DemiBold
                            }
                            color: Colors.color_999999
                            wrapMode: Text.Wrap
                            text: qsTr("pccut_permission_movable_insufficient_permission")
                            horizontalAlignment: Text.AlignHCenter
                            property string laseLineText: ""
                            property double laseLineWidth: 0.0
                            onWidthChanged: {
                                let lines = []
                                let currentLine = ""
                                const words = text.split(" ")
                                
                                for (let word of words) {
                                    const testLine = currentLine === "" ? word : currentLine + " " + word
                                    textMetrics.text = testLine
                                    if (textMetrics.advanceWidth <= width) {
                                        currentLine = testLine
                                    } else {
                                        lines.push(currentLine)
                                        currentLine = word
                                    }
                                }
                                lines.push(currentLine)
                                laseLineText = lines[lines.length - 1]
                                textMetrics.text = tipsText.laseLineText
                                laseLineWidth = textMetrics.advanceWidth
                                contentLayout.customImplicitHeight = contentLayout.implicitHeight
                            }
                        }
                        TextMetrics {
                            id: textMetrics
                            font: tipsText.font
                            elideWidth: parent.width - 2 * (tipsIcon.width + 2)
                            elide: Qt.ElideNone
                        }
                        Image {
                            id: tipsIcon
                            x: {
                                if (tipsText.lineCount === 1) {
                                    // 单行：直接取 paintedWidth
                                    return parent.width * 0.5 + tipsText.width * 0.5 + 2
                                } else {
                                    return parent.width * 0.5 + tipsText.laseLineWidth / 2 + 2
                                }
                            }
                            y: {
                                let textLineHeight = 1.0 * tipsText.height / Math.max(tipsText.lineCount, 1)
                                let yOffset = (1.0 * textLineHeight - tipsIcon.height) / 2
                                return tipsText.y + (tipsText.lineCount - 1) * textLineHeight + yOffset
                            }
                            width: 14
                            height: 14
                            source: tipsIconMouseArea.containsMouse ? "qrc:/icons/ic_explain.svg" : "qrc:/icons/ic_explain_hover.svg"
                            MouseArea {
                                id: tipsIconMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                            }
                        }
                    }

                    IconTextButton {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 24
                        Layout.preferredWidth: 88
                        Layout.preferredHeight: 28
                        titleFontSize: 12
                        isTextOnly: true
                        title: qsTr("pccut_quick_goto_enable")
                        alignment: Qt.AlignHCenter
                        titleColorNormal: ColorsConfig.color_FFFFFF_000000
                        backgroundColorNormal: ColorsConfig.color_F22443_4DFFC9
                        backgroundColorHover: ColorsConfig.color_F44C65_6DFFD3
                        onCustomClicked: {
                            if (!CommonUtils.isWindows()) {
                                eventTracker.trackEvent("pccut_assets_authorize_click")
                                Tools.openSystemFilesAndFoldersPanel()
                            }
                        }
                    }
                }
                LightPopup {
                    id: tipsImagePopup
                    parent: permissionGuidancePage
                    x: contentLayout.x + tipsLineLayout.x + tipsIcon.x + tipsIcon.width + 2
                    y: contentLayout.y + tipsLineLayout.y + tipsIcon.y - (implicitHeight - tipsIcon.height) / 2
                    visible: tipsIconMouseArea.containsMouse
                    modal: false
                    background: Item{}
                    RowLayout {
                        spacing: 0
                        Image {
                            source: "qrc:/icons/icon_fileandfloder_point.svg"
                        }
                        Image {
                            Layout.preferredWidth: 400
                            Layout.preferredHeight: 345
                            source: translationHandler.isChineseLang() ? "qrc:/app_qrc/FileAndFloderPage.png" : "qrc:/app_qrc/FileAndFloderPage_en.png"
                        }
                    }
                }
            }
            
            GridView {
                id: gridView
                objectName: actionableItemName.gridViewForMediaImport

                onVisibleChanged: {
                    // 当页面消失时 取消选中
                    if (!visible) {
                        root.mediaListViewModel.resetSelectedAssets();
                    }
                }
                // 因为鼠标是添加每个片段上 片段可能被销毁导致拖拽失效
                interactive: (!draggableRect.visible && !bgSelectionRect.visible)
                flow: GridView.FlowLeftToRight
                cellWidth: mGridMode ? itemCoverWidth + itemCoverX * 2 : gridView.width
                cellHeight: mGridMode ? 102 : 78
                boundsBehavior: GridView.StopAtBounds
                flickDeceleration: 7000
                model: root.mediaListViewModel
                property int column: cellWidth !== 0 ? gridView.width / cellWidth : 0
                // delegate: Loader {
                //     asynchronous: false
                //     sourceComponent: contactsGridDelegate
                // }
                delegate: contactsGridDelegate
                function ensureContentHeight() {
                    if (contentHeight < height) {
                        contentHeight = height;
                    }
                }
                onContentHeightChanged: ensureContentHeight()
                onHeightChanged: ensureContentHeight()
                onMovementStarted: {
                    root.isScrolling = true
                }
                onMovementEnded: {
                    root.isScrolling = false
                }
                onFlickingChanged: {
                    if (flicking) {
                        root.isScrolling = true
                    } else if (!moving) {
                        root.isScrolling = false
                    }
                }
                onMovingChanged: {
                    if (!moving && !flicking) {
                        root.isScrolling = false
                    }
                }
                onDragStarted: {
                    logger.d("[MediaCover] onDragStarted ");
                }
                onFlickStarted: {
                    logger.d("[MediaCover] onFlickStarted ");
                }
                ScrollBar.vertical: ScrollBar {
                    Component.onCompleted: {
                        contentItem.color = Colors.color_444444;
                    }
                }

                Component.onCompleted: {
                    root.mediaListViewModel.setGridview(gridView)
                }
            }
        }        
    }


    MouseArea {
        id: dragSelectMouseArea
        anchors.fill: parent
        parent: gridView.contentItem
        acceptedButtons: Qt.LeftButton
        property real startX: 0
        property real startY: 0
        property real startContentY: 0
        property real currentX: 0
        property real currentY: 0
        onPressedChanged: {
            logger.d("[MediaCover] dragSelectMouseArea " + pressed);
            if (pressed) {
                ShortcutObserver.disableAllShortcut(true);
            } else {
                ShortcutObserver.disableAllShortcut(false);
                scrollTimer.stop();
            }
        }
        onPressed: (mouse) => {
            root.isMediaListFocused = true;
            globalSignal.cleanTrackSelectState();
            if (pressed) {
                let point = mapToItem(gridView, Qt.point(mouse.x, mouse.y));
                startX = point.x;
                startY = point.y;
                currentX = startX;
                currentY = startY;
                startContentY = gridView.contentY;
                scrollTimer.scrollDirectionY = 0;
                scrollTimer.start();
            }
        }

        onPositionChanged: (mouse) => {
            if (mouse.buttons === Qt.LeftButton) {
                let point = mapToItem(gridView, Qt.point(mouse.x, mouse.y));
                currentX = point.x;
                currentY = point.y;
                // 检测边缘并设置滚动方向
                let edge = 30;
                // 滑动的速度
                let distance = 5;
                var speed = 0;
                if (point.y < edge) {
                    speed = (point.y - edge) / (edge * 2);
                } else if (gridView.height - edge < point.y) {
                    speed = (point.y + edge - gridView.height) / (edge * 2);
                }
                speed = speed * distance;
                scrollTimer.scrollDirectionY = speed;
            }
        }

        onCanceled: {
            scrollTimer.stop();
        }

        onReleased: {
            scrollTimer.stop();
            if (root.mediaListViewModel.selectPathSize > 0) {
                eventTracker.trackEvent("pccut_assets_batch", {"use_method": "mouse_batch"})
            }
        }

        Rectangle {
            id: bgSelectionRect
            parent: gridView.contentItem
            color: Colors.color_FFFFFF_10
            radius: 2
            border.width: 1
            border.color: Colors.color_FFFFFF_20
            z: Number.MAX_SAFE_INTEGER
            visible: dragSelectMouseArea.pressed
            x: Math.min(dragSelectMouseArea.startX, dragSelectMouseArea.currentX)
            width: Math.abs(dragSelectMouseArea.startX - dragSelectMouseArea.currentX)
            y: Math.min(dragSelectMouseArea.startY + dragSelectMouseArea.startContentY, dragSelectMouseArea.currentY + gridView.contentY)
            height: Math.abs(dragSelectMouseArea.startY + dragSelectMouseArea.startContentY - dragSelectMouseArea.currentY - gridView.contentY)
            onWidthChanged: {
                refreshDragSelect();
            }

            onHeightChanged: {
                refreshDragSelect();
            }

            function refreshDragSelect() {
                // 判定一定是鼠标拖拽画框的过程中
                if (!bgSelectionRect.visible || !dragSelectMouseArea.pressed) {
                    return;
                }
                const selectRect = Qt.rect(bgSelectionRect.x, bgSelectionRect.y, bgSelectionRect.width, bgSelectionRect.height);
                const cellSize = Qt.size(gridView.cellWidth, gridView.cellHeight);
                const itemRect = Qt.rect(itemCoverX, 0, itemCoverWidth, itemCoverHeight);
                root.mediaListViewModel.dragSelect(selectRect, gridView.column, cellSize, itemRect);
            }
        }

        Timer {
            id: scrollTimer
            interval: 20
            repeat: true
            running: false
            property int scrollDirectionY: 0
            onTriggered: {
                if (scrollDirectionY !== 0 && gridView.visible) {
                    var contentY = gridView.contentY + scrollDirectionY * 10;
                    if (contentY < 0) {
                        contentY = 0;
                    } else if (contentY > gridView.contentHeight - gridView.height) {
                        contentY = gridView.contentHeight - gridView.height;
                    }
                    gridView.contentY = contentY;
                }
            }
        }
    }

    Component {
        id: contactsGridDelegate
        Item {
            id: item_root
            objectName: actionableItemName.delegateItemForGridViewForMediaImport + index
            Accessible.role: Accessible.Button
            Accessible.description: "filemanage_videoitem"
            Accessible.name: fileOperator.fileShowNameForPath(path)
            // 左右裁切小耳朵的宽度(宽一点 鼠标容易点击)
            property real earWidth: 8
            // 裁剪的最短时长(参考剪映) 100 毫秒
            property real minDuration: Math.min(100, duration)
            // 裁切框的最小宽度
            property real minRectWidth: coverWidth / duration * minDuration
            // 是否在编辑中
            property bool containsEditor: root.mediaListViewModel.trackUsedAssets.indexOf(assetId) !== -1
            // 展示图片的数量
            property int imageCount: mGridMode ? 1 : Math.ceil(item_root.width / mediaCover.height)
            // 一个图片代表的时长
            property int imageDuration: duration / coverWidth * mediaCover.height
            // 圆角
            property real cellRadius: 6
            // 是否在拖拽(粗剪)
            property bool isDragEar: rightEarMouseArea.drag.active || leftEarMouseArea.drag.active
            // 拖拽(粗剪) 是否结束
            property bool isDragEarEnd: true
            // 图片的宽度
            property real coverWidth: itemCoverWidth
            property bool realIs16KTimelapse: mediaListViewModel.pageType === MediaListViewModel.PAGE_DEVICE ? asyncLoader.is16KTimelapse : is16KTimelapse
            // 封面是否按全景裁剪：asyncLoader 的判定要等异步 FileInfo，未就绪时按后缀同步判定
            property bool coverIsPanorama: asyncLoader.mediaPrepared ? asyncLoader.isPanoramaMedia : isPanorama
            // 素材是否有效
            property bool sourceValid: mediaExist && !mediaDamaged && !(realIs16KTimelapse && !agencyExists)
            // 选中获取预览，即为激活状态，此时就显示加号添加素材进轨道(前提是准备好的话)
            property bool itemActivated: sourceValid && (mouseArea.containsMouse || highlightIcon.selfHovered || (isSelected !== undefined && isSelected)) && !item_root.isDragEar
            // 这是一个兜底逻辑，防止一直加载个不停，导致轨道添加按钮始终无法露出
            property bool preparedTimeout: root.mediaListViewModel.mediaPreparedTimeout(assetId)

            onIsDragEarChanged: {
                if (isDragEar) {
                    root.mediaListViewModel.pause();
                }
            }
            // 是否点击在图片上
            function mediaCoverContains(point) {
                var itemPoint = mapToItem(leftEar, point);
                if (leftEar.contains(itemPoint)) {
                    return true;
                }
                itemPoint = mapToItem(rightEar, point);
                if (rightEar.contains(itemPoint)) {
                    return true;
                }
                itemPoint = mapToItem(coverImage, point);
                return coverImage.contains(itemPoint);
            }

            // 刷新裁切框的位置
            function refreshCutRange() {
                let cutBegin = root.mediaListViewModel.cutBeginForIndex(index);
                let cutLength = root.mediaListViewModel.cutLengthForIndex(index);
                let beginX = mediaCover.x - item_root.earWidth / 2;
                leftEar.x = beginX + cutBegin * mediaCover.width;
                rightEar.x = leftEar.x + cutLength * mediaCover.width;
            }
            // 快捷键 粗剪 in
            function shortcutAction(isCutIn) {
                if (isDragEar) {
                    return;
                }
                // 裁切点
                var cutPosition = playedLine.x;
                // 如果有预览轴就以预览轴黄线 为准
                if (lineProgress.visible == true) {
                    cutPosition = lineProgress.x;
                }
                root.mediaListViewModel.pause();
                // 之前的裁切点
                let oldCutBegin = root.mediaListViewModel.cutBeginForIndex(index);
                let oldCutLength = root.mediaListViewModel.cutLengthForIndex(index);
                let oldCutEnd = oldCutBegin + oldCutLength;
                let minPercentage = minDuration / duration;
                // 转换成百分比
                let cutPercentage = cutPosition / coverWidth;
                // 最终的裁切点
                var newCutBegin = oldCutBegin;
                var newCutLength = oldCutLength;
                var seekPosition = 0;
                if (isCutIn === true) {
                    newCutBegin = cutPercentage;
                    // 左裁切没有超出右边范围
                    if (newCutBegin <= oldCutEnd) {
                        newCutBegin = Math.min(newCutBegin, oldCutEnd - minPercentage);
                        newCutBegin = Math.max(newCutBegin, 0);
                        newCutLength = oldCutEnd - newCutBegin;
                    } else {
                        newCutBegin = Math.min(newCutBegin, 1 - minPercentage);
                        newCutBegin = Math.max(newCutBegin, 0);
                        newCutLength = 1 - newCutBegin;
                    }
                    seekPosition = newCutBegin;
                } else {
                    // 右裁切没有超过左边的范围
                    if (cutPercentage >= oldCutBegin) {
                        newCutBegin = oldCutBegin;
                    } else {
                        newCutBegin = 0;
                    }
                    newCutLength = cutPercentage - newCutBegin;
                    newCutLength = Math.max(newCutLength, minPercentage);
                    seekPosition = newCutLength + newCutBegin;
                }
                root.mediaListViewModel.playedPercentage = seekPosition;
                root.mediaListViewModel.coverSeek(seekPosition);
                root.mediaListViewModel.update(index, newCutBegin, newCutLength);
                refreshCutRange();
            }

            function getDurationText() {
                if (root.mediaListViewModel.pageType !== MediaListViewModel.PAGE_DEVICE) {
                    //*#*#*# 循环录影：下载到本地的循环录影使用 asyncLoader.text，通过 concat producer 累加所有子文件得到正确总时长
                    if (isLoopVideo) {
                        return asyncLoader.text !== "" ? asyncLoader.text : "";
                    }
                    var speed = asyncLoader.previewSpeed;
                    return isVideo ? UiUtils.formatSeconds(duration / speed) : ""
                } else {
                    var speed = asyncLoader.previewSpeed;
                    return isHighlightItem ? UiUtils.formatSeconds(duration / speed) : asyncLoader.text
                }
            }

            function getFavorite() {
                return favorite;
            }

            DeviceMaterialAsyncLoader {
                id: asyncLoader
                //*#*#*# 循环录影：设备页用 thumbnailPath（首个真实子文件路径），避免虚拟 OSV 路径导致 duration=0 → mediaDamaged=true → 封面隐藏
                //*#*#*# 循环录影：非设备页的已下载循环录影也需要用第一个真实子文件路径，确保 infoPtr 非 null，asyncLoader.text 能正确计算
                filePath: mediaListViewModel.pageType === MediaListViewModel.PAGE_DEVICE ? thumbnailPath
                        : (isLoopVideo && loopVideoList.length > 0 ? loopVideoList[0] : path)
                //*#*#*# 循环录影：传虚拟路径，供 onCopyFileInfoUpdated 精确匹配，避免 O(N) 广播
                loopVirtualPath: path
                //*#*#*# 循环录影：传所有子文件路径，供 DeviceMaterialAsyncLoader 累加所有子文件时长得到正确总时长
                subFilePaths: loopVideoList
                onDurationChanged: {
                    if (root.mediaListViewModel.pageType === MediaListViewModel.PAGE_DEVICE) {
                        root.mediaListViewModel.updateDuration(index, asyncLoader.duration, asyncLoader.width(), asyncLoader.height());
                    }
                }

                onMediaPreparedChanged: {
                    // 通知Model准备状态更新了
                    root.mediaListViewModel.setMediaPrepared(assetId, asyncLoader.mediaPrepared);
                }
            }

            width: gridView.cellWidth
            height: gridView.cellHeight
            Rectangle {
                id: mediaCover
                color: Colors.color_000000
                width: item_root.coverWidth
                onWidthChanged: {
                    refreshCutRange();
                }
                height: itemCoverHeight
                x: itemCoverX
                radius: cellRadius
                // 封面
                Item {
                    id: coverImage
                    clip: true
                    anchors.fill: parent
                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: mediaCover.width
                            height: mediaCover.height
                            radius: cellRadius // 设置圆角的大小
                        }
                    }
                    ListView {
                        anchors.fill: parent
                        orientation: ListView.Horizontal
                        model: imageCount
                        interactive: false
                        delegate: Rectangle {
                            id: delegateRoot
                            width: mGridMode ? mediaCover.width : mediaCover.height
                            height: mediaCover.height
                            color: {
                                if (mediaDamaged) {
                                    return Colors.color_19191A;
                                } else if(!mediaExist) {
                                    return ColorsConfig.color_492C2D_15473C;
                                } else if(realIs16KTimelapse && !agencyExists) {
                                    return Colors.color_19191A;
                                }
                                return Colors.color_000000;
                            }

                            Item {
                                width: parent.width
                                height: parent.height
                                visible: mediaExist && !mediaDamaged && !(root.mediaListViewModel.pageType !== MediaListViewModel.PAGE_DEVICE &&
                                                                          realIs16KTimelapse &&
                                                                          !agencyExists)

                                // 高光封面：使用 Image 组件加载静态 JPEG
                                Image {
                                    anchors.fill: parent
                                    fillMode: item_root.coverIsPanorama ? Image.PreserveAspectCrop : Image.PreserveAspectFit
                                    visible: isHighlightItem
                                    source: isHighlightItem && mediaExist ? "image://image_provider/" + highlightCover + ";0;0;0;1;1" : ""
                                    sourceSize: Qt.size(parent.width, parent.height)
                                }

                                // 普通视频：使用 MediaCover 组件抽取视频帧
                                MediaCover {
                                    id: mediaCoverItem
                                    width: parent.width
                                    height: parent.height
                                    visible: !isHighlightItem
                                    imageTime: index * imageDuration * 30
                                    // 使用thumbnailPath，以便给出循环录影首个子素材路径抽封面
                                    mediaPath: mediaExist ? isHighlightItem ? highlightCover : thumbnailPath : ""
                                    // 仅在使用 thumbnailPath 时下传其预算MD5(asyncLoader.fileMd5 与 thumbnailPath 同源)；
                                    // highlight 封面另有路径、无预算MD5，传空回退自算
                                    mediaMd5: (mediaExist && !isHighlightItem) ? asyncLoader.fileMd5 : ""
                                    isGridModel: mGridMode
                                    needScale: item_root.coverIsPanorama
                                }
                            }

                            Image {
                                id: agencyLostIcon
                                anchors.centerIn: parent
                                width: 96
                                height: 44
                                fillMode: Image.PreserveAspectFit
                                visible: {
                                    if(root.mediaListViewModel.pageType === MediaListViewModel.PAGE_DEVICE) {
                                        return false;
                                    }
                                    return realIs16KTimelapse && !agencyExists;
                                }
                                source: isFromRemovable ? "qrc:/app_qrc/icons/icon_device_agency_missing.svg" : "qrc:/app_qrc/icons/icon_agency_missing.svg"
                            }

                            Image {
                                id: damagedIcon
                                anchors.centerIn: parent
                                height: 24
                                width: 32
                                visible: mediaDamaged
                                sourceSize: Qt.size(32, 24)
                                source: "qrc:icons/ic_resource_damaged.png"
                            }

                            Image {
                                id: lostIcon
                                anchors.centerIn: parent
                                width: 96
                                height: 44
                                visible: !mediaExist
                                fillMode: Image.PreserveAspectFit
                                //*#*#*# 循环录影：同 toast 逻辑，本地循环录影子文件丢失应显示"媒体丢失"封面
                                source: (isFromRemovable && !isLoopVideo) ? "qrc:/app_qrc/icons/ic_device_media_lost.svg" : "qrc:/app_qrc/icons/ic_normal_media_lost.svg"
                            }
                        }
                    }

                    // 已添加标签
                    Image {
                        id: addedTag
                        visible: containsEditor
                        width: 20
                        height: 20
                        x: 4
                        y: 4
                        source: "qrc:/icons/icon_added_tag.svg"
                        sourceSize: Qt.size(width, height)
                    }

                    // 已裁切标签
                    Rectangle {
                        id: cutedTag
                        visible: borderRect.width != mediaCover.width
                        radius: 4
                        color: Colors.transparent
                        height: 20
                        width: 20
                        x: addedTag.visible ? (addedTag.x + addedTag.width + 4) : 4
                        y: 4
                        Image {
                            source: "qrc:/icons/icon_cutted.svg"
                            width: 20
                            height: 20
                            anchors.centerIn: parent
                            sourceSize: Qt.size(width, height)
                        }
                    }
                    // 预览轴的线条
                    Rectangle {
                        id: lineProgress
                        x: mouseInItemX
                        width: 1
                        height: parent.height
                        visible: sourceValid && mouseArea.containsMouse && !item_root.isDragEar && !isPlaying && isSeekAble && editorManager.playType === QPlayType.preview && !editorManager.isInUserGuideStatus
                        color: ColorsConfig.color_brand
                    }
                }
                // 右键点击, 单独拿出来防止在拖拽的过程中点击右键, 减少一些场景的if判断
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.RightButton
                    onClicked: {
                        var newPoint = mouseArea.mapToItem(fileOperatePopup.parent, mouseX, mouseY);
                        fileOperatePopup.showPoint = mouseArea.mapToItem(mainPanel, mouseX, mouseY);
                        fileOperatePopup.agencyFileState = agencyFileState;
                        openPopup(newPoint.x, newPoint.y, assetId, path, asyncLoader.fileMd5, favorite, mediaExist, (realIs16KTimelapse && !agencyExists), downloadedRect.visible, asyncLoader.isSupportHighlight);
                    }
                    onPressedChanged: {
                        logger.d("[MediaCover] right pressed " + pressed);
                    }
                }

                //鼠标掠过效果
                MouseArea {
                    id: mouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton
                    scrollGestureEnabled: false
                    // 防止鼠标被窃取, 先设置上
                    preventStealing: true
                    drag.target: draggableRect
                    // 是否是拖拽添加素材
                    property bool isDragAdd: false
                    // 用户开始点击的位置
                    property point pressedPoint: Qt.point(0, 0)
                    //用于实时在素材列表更新预览轴状态
                    onClicked: (mouse) => {
                        root.isMediaListFocused = true;
                        globalSignal.cleanTrackSelectState();
                        const multiSelectMode = (mouse.modifiers & Qt.ControlModifier) || (mouse.modifiers & Qt.ShiftModifier)
                        // 多选的时候可以点，单点不让点，别怀疑这个逻辑，目前能想到的最好的交互了
                        if (mediaDamaged) {
                            // 这里不要翻译
                            const msg = "无效文件 Invalid File";
                            mediaTabToaster.showToast(msg);
                            return;
                        }
                        if (!mediaExist && !multiSelectMode) {
                            // 这里不要翻译
                            //*#*#*# 循环录影：设备页循环录影 mediaExist 永远为 true（早返回），能走到这里的只有本地循环录影
                            //        子文件被删除属于"媒体丢失"而非"相机文件丢失"，不受 isFromRemovable 影响
                            const msg = (isFromRemovable && !isLoopVideo) ? "相机文件丢失 Camera Files Not Found" : "媒体丢失 Media Not Found"
                            mediaTabToaster.showToast(msg);
                            return;
                        }
                        if (realIs16KTimelapse && !agencyExists && !multiSelectMode) {
                            // 这里不要翻译
                            const msg = isFromRemovable ? "相机代理文件丢失 No Proxy File" : "媒体代理文件丢失 No Proxy File"
                            mediaTabToaster.showToast(msg);
                            return;
                        }

                        if (isDragAdd) {
                            return;
                        }
                        if (mouse.button === Qt.LeftButton && (mouse.modifiers & Qt.ControlModifier)) {
                            isSeekAble = false;
                            root.mediaListViewModel.stopPreviewPlay();
                            if (root.mediaListViewModel.isSelectedForAssetId(assetId)) {
                                root.mediaListViewModel.removeSelectedAsset(assetId);
                            } else {
                                root.mediaListViewModel.appendSelectedAssetId([assetId]);
                                eventTracker.trackEvent("pccut_assets_batch", {"use_method": "cmd"})
                            }
                            return;
                        }
                        if (mouse.button === Qt.LeftButton && (mouse.modifiers & Qt.ShiftModifier)) {
                            isSeekAble = false;
                            root.mediaListViewModel.stopPreviewPlay();
                            root.mediaListViewModel.continuousSelect(index);
                            eventTracker.trackEvent("pccut_assets_batch", {"use_method": "shift"})
                            return;
                        }
                        var playedPercentage = 0;
                        if (mediaCover.width > 0) {
                            // 点击坐标以事件自带的 mouse.x 为准，mouseArea.mouseX 在部分场景为 0
                            playedPercentage = mouse.x / mediaCover.width;
                        }
                        if (lastSelectPlayAssetId != assetId) {
                            const showHoverLine = root.mediaListViewModel.showHoverPreview();
                            // 首次点击切换素材：始终自动起播，且从素材首帧开始（不采用鼠标落点位置）
                            selectMaterial(assetId, true, 0, showHoverLine);
                            let previewMediaIsLocal = isLocal ? "local_file" : "connected_devices"
                            eventTracker.trackEvent("pccut_toggle_preview", {"function": previewMediaIsLocal, "use_method": "click"})
                            globalSignal.mediaChangedWhenCoverClick()
                        } else {
                            var point = borderRect.mapFromItem(mediaCover, mouseX, mouseY);
                            var inBorderRect = borderRect.contains(point);
                            // 点击空包恢复原长
                            if (!inBorderRect) {
                                root.mediaListViewModel.update(index, 0, 1);
                                refreshCutRange();
                            }
                            // 已选中素材再次点击：在暂停态恢复自动播放，在播放态仅 seek
                            root.mediaListViewModel.playedPercentage = playedPercentage;
                            if (!root.mediaListViewModel.isPlaying) {
                                // 暂停态下 coverSeek 只刷帧不起播，必须 resume 恢复播放
                                root.mediaListViewModel.coverSeek(playedPercentage);
                                root.mediaListViewModel.resume();
                            } else {
                                root.mediaListViewModel.coverSeek(playedPercentage);
                            }
                        }
                    }
                    //鼠标移动到item区域时，需要刷新一下收藏状态，因为有可能list刷新过这个状态
                    onEntered: {
                        if (!sourceValid) {
                            return;
                        }
                        mouseAssetId = assetId;
                        root.mediaListViewModel.isPlayingChanged();
                        var isPlayOther = false;
                        if (editorManager.playType !== QPlayType.preview) {
                            isPlayOther = isPlaying;
                        } else {
                            isPlayOther = isPlaying && root.mediaListViewModel.previewingMediaAssetId() !== assetId;
                        }
                        if (isPlayOther || isDragAdd) {
                            isSeekAble = false;
                        } else {
                            isSeekAble = root.mediaListViewModel.showHoverPreview();
                        }
                        // 判定开启预览轴
                        if (!isPlaying && isSeekAble) {
                            if (borderRect.visible && !playedLine.visible && root.mediaListViewModel.selectPathSize === 1) {
                                root.mediaListViewModel.playedPercentage = 0;
                            }
                            showPreviewMedia(assetId, false, width <= 0 ? 0 : lineProgress.x / width);
                            let previewMediaIsLocal = isLocal ? "local_file" : "connected_devices"
                            eventTracker.trackEvent("pccut_toggle_preview", {"function": previewMediaIsLocal, "use_method": "seek"})
                        }
                    }
                    onPressedChanged: {
                        logger.d("[MediaCover] left pressed " + pressed);
                        if (pressed) {
                            pressedPoint = Qt.point(mouseX, mouseY);
                            isDragAdd = false;
                        }
                    }
                    onPositionChanged: (mouse) => {
                        if (pressed) {
                            // 文件不存在禁止拖动
                            if (!sourceValid || (!asyncLoader.mediaPrepared && !preparedTimeout)) {
                                return;
                            }
                            // 增加容错,某些鼠标一点击就有位置移动,鼠标移动多少才认为是拖动
                            let distance = 2;
                            if (Math.abs(pressedPoint.x - mouseX) < distance && Math.abs(pressedPoint.y - mouseY) < distance && !isDragAdd) {
                                return;
                            }
                            let point = mapToItem(draggableRect.parent, mouseX, mouseY);
                            if (!isDragAdd) {
                                mouseAssetId = "";
                                isSeekAble = false;
                                root.mediaListViewModel.pause();
                                draggableRect.mediaAssetId = assetId;
                                draggableRect.mediaPath = thumbnailPath;
                                draggableRect.mediaMd5 = asyncLoader.fileMd5;
                                draggableRect.index = index;
                            }
                            draggableRect.setDragPointMove(point, !isDragAdd);
                            if (!isDragAdd) {
                                isDragAdd = true;
                            }
                        }
                    }
                    onMouseXChanged: {
                        if (!sourceValid) {
                            return;
                        }
                        if (isDragAdd) {
                            return;
                        }
                        mouseInItemX = mouseX;
                        if (!isPlaying && isSeekAble && isDragEarEnd && !editorManager.isInUserGuideStatus) {
                            root.mediaListViewModel.coverSeek(lineProgress.x / width);
                        }
                        // 粗剪结束后会调用到这里, 导致seek位置有细微变化, 所以做个标记来解决
                        isDragEarEnd = true;
                    }

                    onExited: {
                        mouseAssetId = "";
                        if (borderRect.visible) {
                            if (root.mediaListViewModel.selectPathSize > 1) {
                                if (!root.mediaListViewModel.isPlaying) {
                                    root.mediaListViewModel.stopPreviewPlay();
                                }
                            } else {
                                if (isSeekAble && !isPlaying) {
                                    root.mediaListViewModel.coverSeek(root.mediaListViewModel.playedPercentage);
                                }
                            }
                        } else if (lastSelectPlayAssetId.length > 0 && lastSelectPlayAssetId !== assetId && !isPlaying && isSeekAble) {
                            showPreviewMedia(lastSelectPlayAssetId, false, selectMediaPlayedPercentage);
                        } else if (lastSelectPlayAssetId === "" && root.mediaListViewModel.previewingMediaAssetId() === assetId && !isPlaying) {
                            root.mediaListViewModel.stopPreviewPlay();
                        } else if (lastSelectPlayAssetId === "" && assetId === undefined && root.mediaListViewModel.previewingMediaAssetId() !== "" && isSeekAble) {
                            //item被删除时assetId已经被销毁，变成了undefined
                            root.mediaListViewModel.stopPreviewPlay();
                        }
                    }
                    onReleased: {
                        if (isDragAdd) {
                            let point = mapToItem(draggableRect.parent, mouseX, mouseY);
                            draggableRect.setDragPointRelease(point, false);
                            isDragAdd = false;
                        }
                    }
                    onCanceled: {
                        if (isDragAdd) {
                            let point = mapToItem(draggableRect.parent, mouseX, mouseY);
                            draggableRect.setDragPointRelease(point, true);
                            isDragAdd = false;
                        }
                    }
                }
                // 收藏
                Image {
                    id: favoriteImg
                    width: 20
                    height: 20
                    source: getFavorite() ? "qrc:/app_qrc/icons/mediaimport_favorite_yes_icon.svg" : "qrc:/app_qrc/icons/mediaimport_favorite_no_icon.svg"
                    sourceSize: Qt.size(width, height)
                    anchors {
                        top: parent.top
                        right: parent.right
                        topMargin: 4
                        rightMargin: 4
                    }
                    // 在本地素材页面才允许操作以及默认显示，当在设备素材页面时只展示不交互。对于没有收藏设备素材，则不显示星标
                    // 如果处于收藏状态，则图标常驻
                    visible: sourceValid && (getFavorite() || mouseArea.containsMouse || highlightIcon.selfHovered) && !item_root.isDragEar && (isLocal || (!isLocal && getFavorite())) && (!editorManager.isInUserGuideStatus)

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            // 素材丢失不允许操作
                            if (!sourceValid) {
                                return;
                            }
                            if (isLocal) {
                                root.mediaListViewModel.setFavoriteForId(assetId, !favorite);
                                eventTracker.trackEvent("pccut_favorites", {"use_method": "cover_icon"})
                            }
                        }
                    }
                }

                // 高光任务按钮
                HighlightButton {
                    id: highlightIcon
                    filePath: path
                    videoId: asyncLoader.fileMd5
                    //*#*#*# 循环录影：直接传 fileMd5，避免对虚拟路径计算 MD5
                    isHovered: mouseArea.containsMouse
                    z: 10

                    eventTrackingHighlightTag: "edit"  // 高光分析埋点
                    
                    // 判断是否为 INIT 状态（需要在 visible 之前定义）
                    property bool isReadyState: currentState === HighlightTaskStatus.INIT
                    property bool noHighlight: currentState === HighlightTaskStatus.SUCCESS && !hasHighlightItem
                    
                    // 可见性控制：
                    // - INIT 状态：鼠标 hover 封面或按钮本身时显示
                    // - 非 INIT 状态：常驻显示
                    visible: !(videoId.length === 0) && !root.isSelectHighlightTab && !noHighlight &&
                             (
                                 (isReadyState && (mouseArea.containsMouse || selfHovered)) ||  // INIT: hover 封面或按钮时显示
                                 (!isReadyState)  // 非 INIT: 常驻显示
                             ) && asyncLoader.isSupportHighlight

                    x: {
                        if (isReadyState) {
                            // Ready 状态：右上角，favoriteImg 左侧
                            return favoriteImg.x - width - 4
                        } else {
                            // 非 Ready 状态：左上角最右侧图标的右边
                            if (cloudUploadedRect.visible) {
                                return cloudUploadedRect.x + cloudUploadedRect.width + 4
                            } else if (downloadedRect.visible) {
                                return downloadedRect.x + downloadedRect.width + 4
                            } else if (cutedTag.visible) {
                                return cutedTag.x + cutedTag.width + 4
                            } else if (addedTag.visible) {
                                return addedTag.x + addedTag.width + 4
                            } else {
                                return 4
                            }
                        }
                    }

                    y: 4
                }

                // loading
                Rectangle {
                    id: loading
                    property bool visibleState: itemActivated && !asyncLoader.mediaPrepared && !preparedTimeout

                    width: 20
                    height: 20
                    anchors {
                        bottom: parent.bottom
                        right: parent.right
                        bottomMargin: 4
                        rightMargin: 4
                    }
                    color: Colors.color_68696D
                    radius: width / 2
                    visible: false
                    Image {
                        anchors {
                            horizontalCenter: parent.horizontalCenter
                            verticalCenter: parent.verticalCenter
                        }
                        width: 14
                        height: 14
                        source: "qrc:/icons/icon_loading.png"

                        RotationAnimation on rotation {
                            from: 0
                            to: 360
                            running: loading.visible
                            duration: 2000 // Duration of one full rotation in milliseconds
                            loops: Animation.Infinite // Loop indefinitely
                        }
                    }

                    // 产品要求500ms之后再展示loading
                    Timer {
                        id: visibleTimer
                        repeat: false
                        interval: 500

                        onTriggered: {
                            loading.visible = true;
                        }
                    }

                    // loading展示超过5s，触发超时逻辑，避免异常情况造成用户无法使用
                    Timer {
                        id: forceFinishedTimer
                        repeat: false
                        // 产品要求由30s改为5s
                        interval: 5000

                        onTriggered: {
                            root.mediaListViewModel.setMediaPreparedTimeout(assetId);
                            preparedTimeout = true;
                        }
                    }

                    onVisibleStateChanged: {
                        if (visibleState) {
                            if (!loading.visible && !visibleTimer.running) {
                                visibleTimer.start();
                                forceFinishedTimer.start();
                            }
                        } else {
                            loading.visible = false;
                            visibleTimer.stop();
                            forceFinishedTimer.stop();
                        }
                    }
                }

                // 素材类型图标，普通视频不展示，目前类型暂时有：全景视频/全景图片/普通图片
                Image {
                    id: materialTypeImg
                    // 区分硬件和本地素材
                    property string iconName: asyncLoader.typeIconName
                    property bool trackedIcon: false  // 标记是否已上报
                    width: 16
                    height: 16
                    source: iconName
                    sourceSize: Qt.size(width, height)
                    visible: iconName.length !== 0
                    anchors {
                        bottom: parent.bottom
                        left: parent.left
                        leftMargin: 6
                        bottomMargin: 4
                    }
                    layer.enabled: true
                    layer.effect: Glow {
                        color: Colors.color_000000_15
                        spread: 0.6
                        radius: 4
                    }

                    // 当图标可见时上报埋点
                    onVisibleChanged: {
                        if (visible && !trackedIcon && iconName.length > 0) {
                            var quickshotType = getQuickshotTypeFromIcon(iconName);
                            if (quickshotType !== "none") {
                                trackedIcon = true;
                                // 根据页面类型区分展示位置
                                var showLocation = mediaListViewModel.pageType === MediaListViewModel.PAGE_DEVICE
                                                   ? "home_device" : "home_local";
                                eventTracker.trackEvent("pccut_quickshot_icon_show", {
                                    "quickshot_type": quickshotType,
                                    "show_location": showLocation
                                });
                            }
                        }
                    }

                    // 根据图标路径判断一键短片类型
                    function getQuickshotTypeFromIcon(iconPath) {
                        if (iconPath.indexOf("quick_video_rocket") !== -1) return "rocket";
                        if (iconPath.indexOf("quick_video_dronie") !== -1) return "dronie";
                        if (iconPath.indexOf("quick_video_orbit") !== -1) return "orbit";
                        if (iconPath.indexOf("quick_video_circle") !== -1) return "circle";
                        if (iconPath.indexOf("quick_video_helix") !== -1) return "helix";
                        if (iconPath.indexOf("quick_video_comet") !== -1) return "comet";
                        return "none";
                    }
                }
                // 已下载标识
                Rectangle {
                    id: downloadedRect
                    anchors {
                        top: parent.top
                        left: parent.left
                        leftMargin: cutedTag.visible ? (cutedTag.x + cutedTag.width + 4)
                                                      : (addedTag.visible ? (addedTag.x + addedTag.width + 4) : 4)
                        topMargin: 4
                    }
                    width: 20
                    height: 20
                    color: Colors.transparent
                    radius: 4
                    //*#*#*# 循环录影：循环素材用模型级 copiedState（直接查 _copiedFileList），
                    //        普通文件仍用 asyncLoader.copied（需要 MD5 查 map）
                    visible: root.mediaListViewModel.pageType === MediaListViewModel.PAGE_DEVICE &&
                             (isLoopVideo ? copiedState : asyncLoader.copied)
                    Image {
                        source: "qrc:/icons/icon_downloaded.svg"
                        width: 20
                        height: 20
                        anchors.centerIn: parent
                        sourceSize: Qt.size(20, 20)
                    }
                }
                // 已上传云相册标识
                Rectangle {
                    id: cloudUploadedRect
                    anchors {
                        top: parent.top
                        left: parent.left
                        leftMargin: downloadedRect.visible ? (downloadedRect.x + downloadedRect.width + 4)
                                                            : (cutedTag.visible ? (cutedTag.x + cutedTag.width + 4)
                                                                               : (addedTag.visible ? (addedTag.x + addedTag.width + 4) : 4))
                        topMargin: 4
                    }
                    width: 20
                    height: 20
                    color: Colors.color_000000_50
                    radius: 4
                    visible: {
                        var md5 = asyncLoader.fileMd5;
                        if (!md5 || md5.length === 0) {
                            return false;
                        }
                        var uploadedRevision = CloudAlbumTransferModel.uploadedRevision;
                        return uploadedRevision >= 0 && CloudAlbumTransferModel.isFileUploaded(md5);
                    }
                    Image {
                        source: "qrc:/icons/media_type_cloud_uploaded.svg"
                        width: 20
                        height: 20
                        anchors.centerIn: parent
                        sourceSize: Qt.size(20, 20)
                    }
                }
                // Dlog-M标志
                Rectangle {
                    id: logmRect
                    anchors {
                        left: materialTypeImg.visible ? materialTypeImg.right : parent.left
                        leftMargin: materialTypeImg.visible ? 4 : 6
                        verticalCenter: materialTypeImg.verticalCenter
                    }
                    width: 24
                    height: 16
                    color: Colors.transparent
                    // radius: 4
                    visible: asyncLoader.colorMode === QmlConstants.deviceLutLogmName
                    Image {
                        source: "qrc:/icons/material_type_logm.svg"
                        width:24
                        height:16
                        anchors.fill: parent
                        sourceSize: Qt.size(24, 16)
                    }
                }
                // 时长
                Text {
                    id: durationText
                    // 加入空格为了阴影不被裁切
                    text: " " + getDurationText() + " "
                    color: Colors.color_EEEEEE
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    anchors {
                        left: logmRect.visible ? logmRect.right : (materialTypeImg.visible ? materialTypeImg.right : parent.left)
                        leftMargin: logmRect.visible ? 2 : (materialTypeImg.visible ? 2 : 4)
                        verticalCenter: materialTypeImg.verticalCenter
                    }
                    // windows使用系统原生渲染
                    renderType: CommonUtils.isWindows() ? Text.NativeRendering : Text.QtRendering
                    antialiasing: CommonUtils.isWindows() ? false : true
                    //添加阴影效果
                    layer.enabled: true
                    layer.samples: 100
                    layer.effect: Glow {
                        color: Colors.color_000000_60
                        spread: 0.1
                        radius: 2
                    }
                    Component.onCompleted: {
                        //windows系统默认字体会导致数字展示没有对齐，所以特殊指定字体
                        //选择Arial字体是因为它是Windows操作系统的通用预装字体，且效果经过设计验收
                        if (CommonUtils.isWindows()) {
                            durationText.font.family = "Arial"
                        }
                    }
                }

            }
            // 选中的边框
            Rectangle {
                id: borderRect
                x: leftEar.middleX
                width: rightEar.middleX - leftEar.middleX
                height: mediaCover.height
                border.color: ColorsConfig.color_brand
                border.width: 2
                radius: cellRadius
                visible: isSelected && (!editorManager.isInUserGuideStatus)
                onVisibleChanged: {
                    if (mouseArea.containsMouse || highlightIcon.selfHovered) {
                        root.mediaListViewModel.playedPercentage = mouseArea.mouseX / mediaCover.width;
                    }
                    if (visible) {
                        refreshCutRange();
                    }
                }
                onWidthChanged: {
                    if (rightEarMouseArea.drag.active) {
                        let presentage = (x - mediaCover.x + borderRect.width) / mediaCover.width;
                        root.mediaListViewModel.playedPercentage = presentage;
                        root.mediaListViewModel.coverSeek(presentage);
                    }
                }
                onXChanged: {
                    if (leftEarMouseArea.drag.active) {
                        let presentage = (x - mediaCover.x) / mediaCover.width;
                        root.mediaListViewModel.playedPercentage = presentage;
                        root.mediaListViewModel.coverSeek(presentage);
                    }
                }
                color: Colors.transparent
            }

            // 左边裁切小耳朵
            Item {
                id: leftEar
                property real middleX: x + width / 2
                onMiddleXChanged: {
                    if (!leftEarMouseArea.drag.active) {
                        return;
                    }
                    let newCutBegin = (leftEar.middleX - mediaCover.x) / mediaCover.width;
                    let newCutLength = (rightEar.middleX - leftEar.middleX) / mediaCover.width;
                    root.mediaListViewModel.update(index, newCutBegin, newCutLength);
                }
                visible: borderRect.visible && isLocal
                width: item_root.earWidth
                height: borderRect.height
                anchors.verticalCenter: borderRect.verticalCenter
                x: itemCoverX - width / 2

                Rectangle {
                    x: 3
                    height: 32
                    radius: 2
                    width: 4
                    color: ColorsConfig.color_brand
                    anchors.verticalCenter: parent.verticalCenter
                }
                MouseArea {
                    id: leftEarMouseArea
                    anchors.fill: parent
                    cursorShape: Qt.SplitHCursor
                    property bool isDrag: drag.active
                    onIsDragChanged: {
                        item_root.isDragEarEnd = false;
                        if (active) {
                            showPreviewMedia(assetId);
                        }
                    }
                    drag {
                        target: leftEar
                        axis: Drag.XAxis
                        filterChildren: false
                        minimumX: itemCoverX - 8 / 2
                        maximumX: rightEar.x - item_root.minRectWidth
                        smoothed: false
                        threshold: 0
                    }
                    onReleased: {
                        if (active) {
                            eventTracker.trackEvent("pccut_rough_cut")
                        }
                    }
                }
            }
            // 右边裁切小耳朵
            Item {
                id: rightEar
                property real middleX: x + item_root.earWidth / 2
                onMiddleXChanged: {
                    if (!rightEarMouseArea.drag.active) {
                        return;
                    }
                    let newCutBegin = (leftEar.middleX - mediaCover.x) / mediaCover.width;
                    let newCutLength = (rightEar.middleX - leftEar.middleX) / mediaCover.width;
                    root.mediaListViewModel.update(index, newCutBegin, newCutLength);
                }
                visible: borderRect.visible && isLocal
                property real maxX: mediaCover.width + mediaCover.x - width / 2
                width: item_root.earWidth
                height: borderRect.height
                anchors.verticalCenter: borderRect.verticalCenter
                x: maxX
                Rectangle {
                    x: 1
                    height: 32
                    radius: 2
                    width: 4
                    color: ColorsConfig.color_brand
                    anchors.verticalCenter: parent.verticalCenter
                }
                MouseArea {
                    id: rightEarMouseArea
                    cursorShape: Qt.SplitHCursor
                    anchors.fill: parent
                    property bool isDrag: drag.active
                    onIsDragChanged: {
                        item_root.isDragEarEnd = false;
                        if (active) {
                            showPreviewMedia(assetId);
                        }
                    }
                    drag {
                        target: rightEar
                        axis: Drag.XAxis
                        minimumX: leftEar.x + item_root.minRectWidth
                        maximumX: rightEar.maxX
                        smoothed: false
                        threshold: 0
                    }
                    onReleased: {
                        if (active) {
                            eventTracker.trackEvent("pccut_rough_cut")
                        }
                    }
                }
            }
            // 添加按钮
            Image {
                id: addMedia
                source: "qrc:/app_qrc/icons/filter_add.svg"
                visible: sourceValid && (mouseArea.containsMouse || highlightIcon.selfHovered) && !item_root.isDragEar && (asyncLoader.mediaPrepared || preparedTimeout)

                // 选中时候的x
                property real selectX: {
                    let distance = rightEar.middleX - leftEar.middleX;
                    if (distance < 28) {
                        let rightSpace = mediaCover.x + mediaCover.width - rightEar.middleX - 4;
                        if (rightSpace >= 20) {
                            return rightEar.middleX + 4;
                        } else {
                            return leftEar.middleX - 4 - 20;
                        }
                    } else {
                        return Math.max(rightEar.middleX - 4 - 20, mediaCover.x + 4);
                    }
                }
                // 未选中时候的x
                property real unSelectX: mediaCover.x + item_root.coverWidth - 4 - 20
                x: borderRect.visible ? selectX : unSelectX
                anchors {
                    bottom: borderRect.bottom
                    bottomMargin: 4
                }
                width: 20
                height: 20
                sourceSize: Qt.size(width, height)
                MouseArea {
                    id: addMouseArea
                    anchors.fill: parent
                    onClicked: {
                        isSeekAble = false;
                        root.mediaListViewModel.pause();
                        //*#*#*# 循环录影：始终使用虚拟路径（path）做存在性检查，
                        //*#*#*# 避免 thumbnailPath 指向已删除的本地路径导致误判（下载后删本地再回设备页的场景）
                        //*#*#*# FileOperator::isExists 内部已处理虚拟路径 → FileInfoManager → DeviceLoopVideoCache 的完整兜底链路
                        var checkPath = model.isLoopVideo ? path : (model.thumbnailPath || path);
                        if (fileOperator.asyncIsExists(checkPath)) {
                           root.mediaListViewModel.mediaClickAdd(assetId);
                           if(editorManager.isInUserGuideStatus){
                               globalSignal.nextStepInAllGuide();
                           }
                        } else {
                            toast.showToast(qsTr("pccut_player_nonexistent"));
                        }
                        root.mediaListViewModel.stopPreviewPlay();
                    }
                    LightToolTip {
                        visible: addMouseArea.containsMouse
                        tip: qsTr("pccut_track_add")
                    }
                }
            }

            Rectangle {
                anchors.fill: mediaCover
                radius: cellRadius
                color: Colors.transparent
                clip: true
                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: mediaCover.width
                        height: mediaCover.height
                        radius: cellRadius // 设置圆角的大小
                    }
                }
                // 当前播放的时间线（预览轴期间 hovered 素材切换预览画面，选中素材的进度线停在记忆位置）
                Rectangle {
                    id: playedLine
                    property real linePercentage: root.mediaListViewModel.previewingAssetId === assetId
                                                   ? root.mediaListViewModel.playedPercentage
                                                   : selectMediaPlayedPercentage >= 0 ? selectMediaPlayedPercentage : 0
                    x: Math.min(linePercentage * coverImage.width, coverImage.width - playedLine.width)
                    width: 1
                    height: parent.height
                    // 暂停态悬停刮擦时与红色预览轴红线并存：白线标记暂停进度，红线跟随光标
                    visible: borderRect.visible && lastSelectPlayAssetId === assetId && !item_root.isDragEar && root.mediaListViewModel.selectPathSize === 1
                    color: Colors.color_FFFFFF
                }
            }
            AgencyIconView {
                id: agencyIconView
                visible: agencyFileState === AgencyManager.AGENCY_RESULT_AGENCY_WAIT || agencyFileState === AgencyManager.AGENCY_RESULT_AGENCY_PROGRESS || agencyFileState === AgencyManager.AGENCY_RESULT_AGENCY_EXISTS
                progress: root.mediaListViewModel.agencyProgress
                fileState: agencyFileState
                anchors {
                    left: mediaCover.left
                    top: mediaCover.bottom
                    topMargin: 4
                }
            }
            Text {
                text: root.isSelectHighlightTab ? highlightItemName : fileOperator.fileShowNameForPath(path)
                anchors {
                    left: agencyIconView.visible ? agencyIconView.right : mediaCover.left
                    right: mediaCover.right
                    top: mediaCover.bottom
                    topMargin: 4
                }
                color: Colors.color_999999
                elide: Text.ElideMiddle
                wrapMode: Text.NoWrap
                font.pixelSize: 10
            }
        }
    }

}
