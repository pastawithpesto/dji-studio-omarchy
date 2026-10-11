import QtMultimedia 5.15
import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.15
import QtQuick.Window 2.15
import Qt5Compat.GraphicalEffects
import QtQuick.Dialogs
import QtCore

import Controls 1.0
import Config 1.0

import MKDisplayView 1.0
import MKPlayerController 1.0
import PreviewConductor 1.0
import ShortcutAction 1.0
import PreviewSourceHandler 1.0
import ProjectGenerator 1.0
import LightRectangle 1.0
import app_qrc 1.0
import DeviceMediaCategory 1.0
import QPanoramaLimit 1.0

import "../player"
import "../controller"
import "../export"

LightClipRectangle {
    id: previewPlayerRoot
    // LightToolTip 和 MultilineToolTip 中都用的 mainPanel
    property var mainPanel: previewPlayerRoot
    property bool isFullScreen: false
    
    onIsFullScreenChanged: {
        if (CommonUtils.isWindows()) {
            if (isFullScreen) {
                playerContainer.state = "fullScreen"
            } else {
                playerContainer.state = "normal"
            }
        }
    }
    
    property int topbarHeight: CommonUtils.isWindows() ? 32 : 40
    property int resizeAreaSize: 8

    property int prioritySetting: 2
    readonly property alias controller: player.controller

    // 云相册预览时：「渲染线上图片」需隐藏底部播放控件；「边下边播视频」需保留控件（与本地一致）。
    // 故仅当云相册预览且内容为图片时才隐藏控件；视频（含边下边播）不隐藏。
    readonly property bool isCloudAlbumImagePreview: playerWindow.isCloudAlbumPreview
                                                     && (conductor.isImage || conductor.isPanoImage)

    // 图片类型在窗口标志翻转后才解析出来时，靠此属性变化兜底强制隐藏。
    onIsCloudAlbumImagePreviewChanged: {
        if (isCloudAlbumImagePreview) {
            playerContainer.dismissController()
        }
    }
    
    property int prePlayerState: Window.Windowed
    property int preAppState: Window.Windowed
    property int windowVisibility: CommonUtils.isNull(win) ? 0 : win.visibility
    property var win: Window.window

    onWindowVisibilityChanged: {
        if (windowVisibility === Window.Windowed || windowVisibility === Window.Maximized) {
            raiseTimer.start()
        }
    }

    clip: true
    radius: [10, 10, 10, 10]

    ProjectGenerator {
        id: projectGenerator
        Component.onCompleted: {
            sourceHandler.setProjectGenerator(projectGenerator)
        }
    }

    LightToastManager {
        id: toast

        Connections {
            target: conductor

            function onToastMessage(msg) {
                toast.showToast(msg);
            }
        }
        
        Connections {
            target: sourceHandler

            function onSourcePathUpdated(sourcePath) {
                var isFileValid;

                // 获取循环素材信息
                var subFiles = sourceHandler.currentSubFiles();
                var processParam = sourceHandler.getCurrentProcessParam();
                var loopGroupId = (processParam && processParam.groupId) ? processParam.groupId : "";
                var fileMd5 = (processParam && processParam.fileMd5) ? processParam.fileMd5 : "";
                var virtualPath = (processParam && processParam.filePath) ? processParam.filePath : sourcePath; // 虚拟路径
                var isLoopRecording = subFiles.length > 1 && loopGroupId !== "";

                if (isLoopRecording) {
                    // 循环素材：传递虚拟路径、子文件列表和组ID
                    isFileValid = conductor.conduct(virtualPath, subFiles, loopGroupId, fileMd5);
                } else {
                    // 普通素材
                    isFileValid = conductor.conduct(sourcePath);
                }

                var lastSlashIndex = sourcePath.lastIndexOf('/');
                var lastSlashIndexRight = sourcePath.lastIndexOf('\\');
                lastSlashIndex = Math.max(lastSlashIndex, lastSlashIndexRight)

                var extractedString = sourcePath.substring(lastSlashIndex + 1);

                if(isLoopRecording){
                    extractedString=conductor.getDirFromFilePath(subFiles[0]);
                }

                topbar.sourceFileName = extractedString
                if (!isFileValid) {
                    logger.d("fail valid")
                    toast.showToast(sourcePath + qsTr("pccut_player_anomaly"))
                }
            }

            onToastMessage: (msg) => {
                toast.showToast(msg);
            }
        }
    }

    Connections {
        target: globalSignal
        

        function onSelectedDeviceDetached() {
            controller.pause()
            topbar.closeWindow()
        }
        
        function onShowPreviewWindow() {
            if (!CommonUtils.isNull(win) && win.visibility === Window.Windowed) {
                win.raise()
                win.requestActivate()                
            }            
        }

        function onNeedPauseMediaPlayer() {
            controller.pause();
        }
    }
    
    Rectangle {
        id: playerTopBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: topbarHeight
        color: Colors.color_content_area_background
    }

    Timer {
        id: hideTimer
        interval: 3000 // 3 seconds
        repeat: false
        onTriggered: {
            // console.log("【调试预览弹窗】hideTimer.onTriggered")
            playerContainer.dismissController()
        }
    }

    Connections {
        target: playerWindow
        function onCloudAlbumPreviewChanged() {
            if (previewPlayerRoot.isCloudAlbumImagePreview) {
                playerContainer.dismissController()
            }
        }
    }

    // ✨ 统一的悬停控制器：使用 HoverHandler 仅感知鼠标事件，不抢占子控件
    HoverHandler {
        id: unifiedHoverController

        property int topbarHeight: playerTopBar.height

        property var mouseX: 0
        property var mouseY: 0

        onHoveredChanged: {
            if (hovered) {
                // console.log("【调试预览弹窗】统一控制器.onEntered")
                playerContainer.showController()
                hideTimer.stop()
            } else {
                // console.log("【调试预览弹窗】统一控制器.onExited → 立即隐藏（鼠标离开窗口）")
                hideTimer.stop()
                playerContainer.dismissController()
            }
        }

        onPointChanged: {
            if (mouseX === point.position.x && mouseY === point.position.y) {
                // 过滤重复鼠标事件
                return
            }
            mouseX = point.position.x
            mouseY = point.position.y

            // ✨ 在窗口边缘留出 resize 区域，不处理边缘事件
            if (mouseX < resizeAreaSize || mouseX > previewPlayerRoot.width - resizeAreaSize ||
                mouseY < resizeAreaSize || mouseY > previewPlayerRoot.height - resizeAreaSize) {
                return
            }

            // ✨ 统一判断：简单的 if-else-if 链条

            // 判断是否在顶栏内
            var isInTopbar = (mouseY >= 0 && mouseY < topbarHeight)

            // 判断是否在控制面板内
            var cpHeight = controlPanel.height
            var cpWidth = controlPanel.width
            var cpBottomMargin = controlPanel.anchors.bottomMargin
            var cpBottomY = previewPlayerRoot.height - cpBottomMargin
            var cpTopY = cpBottomY - cpHeight
            var cpLeftX = (previewPlayerRoot.width - cpWidth) / 2
            var cpRightX = cpLeftX + cpWidth

            var isInControlPanel = (
                cpHeight > 0 && cpWidth > 0 &&
                mouseX >= cpLeftX && mouseX <= cpRightX &&
                mouseY >= cpTopY && mouseY <= cpBottomY
            )

            // console.log("【调试预览弹窗】统一控制器.onPointChanged | y=" + mouseY + " isInTopbar=" + isInTopbar + " isInControlPanel=" + isInControlPanel)

            // 统一的条件判断
            if (isInControlPanel) {
                // console.log("【调试预览弹窗】→ 鼠标在控制面板，永不隐藏")
                hideTimer.stop()
                playerContainer.showController()
            }
            else if (isInTopbar) {
                // console.log("【调试预览弹窗】→ 鼠标在顶栏，永不隐藏")
                hideTimer.stop()
                playerContainer.showController()
            }
            else {
                // console.log("【调试预览弹窗】→ 鼠标在画面区域，启动 3 秒定时器")
                if (!hideTimer.running) {
                    hideTimer.start()
                }
                playerContainer.showController()
            }
        }
    }

    PreviewConductor {
        id: conductor

        Component.onCompleted: {
            sourceHandler.setPreviewConductor(conductor)
        }
    }

    DeviceRemovePopup {
        id: deviceRemovePopup
        isPlayerRemove: true
        anchors.centerIn: parent
        isDownloadRemove: sourceHandler.fromType === PreviewSourceHandler.PREVIEW_FROM_DOWNLOAD
        onShowToast: (toastStr) => {
            toast.showToast(toastStr);
        }
        onBeforeRemove: {
            // 如果同时勾选了高光，在删除原片的同时也删除高光
            if (sourceHandler.isSelectModel && sourceHandler.highlightSelectedList.length > 0) {
                var highlightsMap = buildHighlightsMapForRemove();
                if (highlightsMap) {
                    highlightManager.batchRemoveMediaHighlights(highlightsMap);
                }
            }
        }
    }

    Loader {
        id: highlightRemovePopupLoader
        active: false
        sourceComponent: HighlightRemovePopup {
            anchors.centerIn: parent
            onShowToast: (toastStr) => {
                toast.showToast(toastStr);
            }
        }
    }

    // 辅助函数：构建要删除的高光Map
    function buildHighlightsMapForRemove() {
        var highlightsMap = {};
        var fileMd5 = sourceHandler.currentFileMd5;

        if (!fileMd5 || fileMd5 === "") {
            logger.e("删除失败：无法获取文件MD5");
            return null;
        }

        var highlightIds = [];

        if (sourceHandler.isSelectModel) {
            // 多选模式：删除选中的高光
            highlightIds = sourceHandler.highlightSelectedList;
        } else {
            // 非多选模式：删除当前预览的高光
            var currentHighlightId = sourceHandler.currentPreviewHighlight;
            if (currentHighlightId && currentHighlightId !== "") {
                highlightIds = [currentHighlightId];
            }
        }

        if (highlightIds.length === 0) {
            return null;
        }

        highlightsMap[fileMd5] = highlightIds;
        return highlightsMap;
    }

    // 辅助函数：下载页删除原片（含循环录影）
    function deleteDownloadOriginal() {
        var removeSource = sourceHandler.currentSource;
        //*#*#*# 循环录影：currentSource 是虚拟 OSV 路径，finderPath 存子文件真实路径，直接匹配会失败。
        //        改用 currentSubFiles()[0]（首个真实子文件本地路径）查 virtualPath，再整组删除。
        var subFiles = sourceHandler.currentSubFiles();
        var lookupPath = (subFiles.length > 0) ? subFiles[0] : removeSource;
        var loopVirtualPath = copyFileManager.getVirtualPathFromCopiedPath(lookupPath);
        if (loopVirtualPath !== "") {
            deviceRemovePopup.showPop([loopVirtualPath]);
            return;
        }
        // 普通文件：通过本地路径查 uuid 删除
        removeSource = copyFileManager.getIdFromCopiedPath(lookupPath);
        if (removeSource === "") {
            toast.showToast(qsTr("pccut_device_batch_delete_fail").arg(1));
            return;
        }
        deviceRemovePopup.showPop([removeSource]);
    }

    CopyFilePopup {
        id: copyFilePopup
        isFinshed: false
        Connections {
            target: copyFileManager
            function onAllFinished(errorCount) {
                if (errorCount > 0) {
                    copyFilePopup.close();
                    toast.showToast(qsTr("pccut_device_batch_download_fail").arg(errorCount));
                } else {
                    copyFilePopup.isFinshed = true;
                }
                sourceHandler.resetIsCopied();
            }
        }

        onRightButtonClicked: {
            globalSignal.checkDownload();
            topbar.closeWindow()
        }
    }

    Loader {
        id: fileFolderLoader
        property var fileList: []
        //*#*#*# 循环录影：整组下载时携带 groupId、虚拟路径和组MD5，用于下载页合并展示并还原 _fileMd5
        property string loopVideoGroupId: ""
        property string loopVirtualPath: ""
        property string loopGroupMd5: ""
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
                //*#*#*# 循环录影：有 groupId 时调用带组信息的下载接口，下载页可合并展示
                if (fileFolderLoader.loopVideoGroupId !== "") {
                    // 先 capture 到局部变量，再立即清空 fileFolderLoader 上的字段；
                    // 否则 storageWarn dialog 的异步回调里读到的会是空串，丢失合并组信息
                    var loopGid    = fileFolderLoader.loopVideoGroupId
                    var loopVPath  = fileFolderLoader.loopVirtualPath
                    var loopGMd5   = fileFolderLoader.loopGroupMd5
                    fileFolderLoader.loopVideoGroupId = "";
                    fileFolderLoader.loopVirtualPath  = "";
                    fileFolderLoader.loopGroupMd5     = "";
                    previewPlayerRoot.startCopyWithStorageCheck(needCopyList, cleanedPath,
                        loopGid, loopVPath, loopGMd5)
                } else {
                    previewPlayerRoot.startCopyWithStorageCheck(needCopyList, cleanedPath)
                }
                
                fileFolderLoader.active = false;
            }
            onRejected: {
                fileFolderLoader.loopVideoGroupId = "";
                fileFolderLoader.loopVirtualPath  = "";
                fileFolderLoader.loopGroupMd5     = "";
                fileFolderLoader.active = false;
            }
        }
    }

    //*#*#*# loopGroupId 非空时走 copyLoopRecordingFileList（单组循环录影），否则走 copyFileList（普通文件）
    function startCopyWithStorageCheck(needCopyList, cleanedPath,
                                       loopGroupId, loopVirtualPath, loopGroupMd5) {
        var totalSizeMB = copyFileManager.calculateTotalSizeMB(needCopyList)
        var doCopy = function() {
            if (loopGroupId && loopGroupId !== "") {
                copyFileManager.copyLoopRecordingFileList(needCopyList, cleanedPath,
                    loopGroupId, loopVirtualPath, loopGroupMd5)
            } else {
                copyFileManager.copyFileList(needCopyList, cleanedPath)
            }
        }
        if (fileOperator.checkStorageWarn(cleanedPath, totalSizeMB)) {
            var storageWarnDialog = Qt.createComponent("qrc:/Controls/ConfirmPopup.qml").createObject(previewPlayerRoot, {
                "title": qsTr("pccut_device_batch_download_low_storage"),
                "leftButtonText": qsTr("pccut_quick_delete_cancel"),
                "rightButtonText": qsTr("pccut_panel_image_directionlock_continue_yes"),
                // ConfirmPopup 默认绑 lightWindow.width/height，但本文件运行在 PreviewPlayerWindow，
                // lightWindow id 不在作用域 → 默认尺寸为 undefined → 内容被居中到 0×0 = 左上角
                "width": previewPlayerRoot.width,
                "height": previewPlayerRoot.height
            })
            storageWarnDialog.onRightButtonClicked.connect(function() {
                copyFilePopup.open();
                doCopy()
            })
            storageWarnDialog.onClosed.connect(function() {
                storageWarnDialog.destroy()
                storageWarnDialog = null
            })
            storageWarnDialog.open()
        } else {
            copyFilePopup.open();
            doCopy()
        }
    }

    // 预览素材导出弹窗
    Loader {
        id: previewExportPopupLoader
        active: false
        property var pendingSourceHandler: null

        sourceComponent: PreviewExportSettingPopup {
            // 通过属性绑定直接传递数据（组件创建时即可用）
            sourceHandler: previewExportPopupLoader.pendingSourceHandler

            onClosed: {
                previewExportPopupLoader.active = false;
            }
        }
        onLoaded: {
            // 数据已在 Component.onCompleted 中初始化，此处仅打开弹窗
            item.open();
        }
    }

    // 设备素材导出弹窗
    Loader {
        id: deviceExportPopupLoader
        active: false
        property var pendingSourceHandler: null

        sourceComponent: DeviceExportSettingPopup {
            // 通过属性绑定直接传递数据（组件创建时即可用）
            sourceHandler: deviceExportPopupLoader.pendingSourceHandler

            onClosed: {
                deviceExportPopupLoader.active = false;
            }
        }
        onLoaded: {
            // 数据已在 Component.onCompleted 中初始化，此处仅打开弹窗
            item.open();
        }
    }

    function showExportDialog(sourceHandler) {
        eventTracker.trackEvent("pccut_home_preview_export_click");  // 数据埋点

        if (sourceHandler.mediaCategory == DeviceMediaCategory.Highlight) {
            // 仅导出高光
            deviceExportPopupLoader.pendingSourceHandler = sourceHandler;
            deviceExportPopupLoader.active = true;
            return;
        }

        if (sourceHandler.hlListSize > 0) {
            // 同时导出原片+高光
            previewExportPopupLoader.pendingSourceHandler = sourceHandler;
            previewExportPopupLoader.active = true;
        } else {
            // 仅导出原片
            deviceExportPopupLoader.pendingSourceHandler = sourceHandler;
            deviceExportPopupLoader.active = true;
        }
    }

    PreviewPlayerTopBar {
        id: topbar
        anchors.top: playerTopBar.top
        anchors.left: playerTopBar.left
        anchors.right: playerTopBar.right
        anchors.bottom: playerTopBar.bottom
        fromType: sourceHandler.fromType
        visible: CommonUtils.isWindows() ? !isFullScreen : true
        sourceFileName: sourceHandler.currentFileName
        isCloudAlbumImagePreview: previewPlayerRoot.isCloudAlbumImagePreview
        
        isPreviewHighlight: (sourceHandler.mediaCategory === DeviceMediaCategory.Highlight) ||
                            (sourceHandler.mediaCategory === DeviceMediaCategory.Original && sourceHandler.currentPreviewHighlight !== "")
        isPreviewOriginal: !isPreviewHighlight
    
        onFullScreenClicked: {
            if (isFullScreen) {
                previewPlayerRoot.callFullScreen(false)
            } else {
                previewPlayerRoot.callFullScreen(true)
            }
        }

        onCustomClosedClicked: {
            controller.pause()
            closeWindow()
        }

        onDraftCreationClicked: {
            controller.pause()
            sourceHandler.processGenerator()
            closeWindow()
            // globalSignal.showMainPanel() eisen
        }
        onRemoveClicked: {
            controller.pause();
            // 判断是从哪个tab进来的
            if (sourceHandler.mediaCategory === DeviceMediaCategory.Highlight) {
                // 从高光tab进来：删除当前高光片段
                var highlightId = sourceHandler.getCurrentSourceId();  // 从高光tab进入时，sourceId就是高光ID
                var fileMd5 = sourceHandler.currentFileMd5;

                if (fileMd5 && highlightId) {
                    var highlightsMap = {};
                    highlightsMap[fileMd5] = [highlightId];
                    highlightRemovePopupLoader.active = true;
                    highlightRemovePopupLoader.item.showPop(highlightsMap);
                } else {
                    logger.e("从高光tab删除失败：无法获取高光信息");
                }
            } else if (sourceHandler.mediaCategory === DeviceMediaCategory.Original) {
                // 从原片tab进来：支持多选模式和切换预览
                if (sourceHandler.isSelectModel) {
                    // 多选模式：根据勾选内容删除
                    var isOriginalSelected = sourceHandler.isOriginalSelected;
                    var selectedHighlightIds = sourceHandler.highlightSelectedList;

                    if (isOriginalSelected) {
                        // 勾选了原片：删除原片（如果同时勾选了高光，会在 deviceRemovePopup.onBeforeRemove 中一起删除）
                        if (sourceHandler.fromType === PreviewSourceHandler.PREVIEW_FROM_DOWNLOAD) {
                            deleteDownloadOriginal();
                        } else {
                            //*#*#*# 循环录影：传所有子文件路径
                            deviceRemovePopup.showPop(sourceHandler.currentSubFiles());
                        }
                    } else if (selectedHighlightIds.length > 0) {
                        // 只勾选了高光：删除高光
                        var highlightsMap = buildHighlightsMapForRemove();
                        if (highlightsMap) {
                            highlightRemovePopupLoader.active = true;
                    highlightRemovePopupLoader.item.showPop(highlightsMap);
                        }
                    } else {
                        // 什么都没勾选
                        logger.w("请先选择要删除的内容");
                        return;
                    }
                } else {
                    // 非多选模式：根据当前预览内容删除
                    if (topbar.isPreviewHighlight) {
                        // 删除当前预览的高光片段
                        var highlightsMap = buildHighlightsMapForRemove();
                        if (highlightsMap) {
                            highlightRemovePopupLoader.active = true;
                    highlightRemovePopupLoader.item.showPop(highlightsMap);
                        }
                    } else {
                        // 删除原片
                        if (sourceHandler.fromType === PreviewSourceHandler.PREVIEW_FROM_DOWNLOAD) {
                            deleteDownloadOriginal();
                        } else {
                            //*#*#*#此处只是暂时如此调用，需要适配设备端支持整组删除后传入循环录影所有子文件路径列表
                            deviceRemovePopup.showPop(sourceHandler.currentSubFiles());
                        }
                    }
                }
            }
        }
        // 点击下载
        onDownloadClicked: {
            controller.pause()
            var subFiles = sourceHandler.currentSubFiles();
            fileFolderLoader.fileList = subFiles;
            //*#*#*# 循环录影：获取 groupId 和虚拟路径，传递给 fileFolderLoader 以便合并下载
            var processParam = sourceHandler.getCurrentProcessParam();
            var loopGroupId  = (processParam && processParam.groupId) ? processParam.groupId : "";
            var loopVPath    = (processParam && processParam.filePath) ? processParam.filePath : "";
            if (loopGroupId !== "" && subFiles.length > 1) {
                fileFolderLoader.loopVideoGroupId = loopGroupId;
                fileFolderLoader.loopVirtualPath  = loopVPath;
                //*#*#*# 循环录影：MD5 从 processParam.fileMd5 透传（Q_PROPERTY 可直接访问）
                fileFolderLoader.loopGroupMd5     = (processParam && processParam.fileMd5) ? processParam.fileMd5 : "";
            }
            fileFolderLoader.showFolder(true);
        }
        // 点击导出（原片、高光）
        onExportClicked: {
            controller.pause()
            previewPlayerRoot.showExportDialog(sourceHandler);
        }
    }

    Rectangle {
        id: playerContainer
        anchors.left: parent.left
        anchors.top: playerTopBar.bottom
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        state: "normal"
        states: [
            State {
                name: "fullScreen"
                PropertyChanges {
                    target: playerContainer
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                }
            },
            State {
                name: "normal"
                PropertyChanges {
                    target: playerContainer
                    anchors.left: parent.left
                    anchors.top: playerTopBar.bottom
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                }
            }
        ]

        color: CommonUtils.isWindows() ? Colors.color_000000 : Colors.transparent

        // ✨ 新增：追踪鼠标在控制面板上的状态
        property bool mouseInControlPanel: false

        PanoramaPlayerView {
            id: player
            visible: true
            anchors.centerIn: parent
            anchors.fill: parent
            playerRole: previewPlayerName
            // 视角手势交给 conductor(nova 绝对改帧)，外抛 move/zoom/rotate 信号(对齐编辑页 PlayerPanel)。
            playerHandleGesture: false
            layer.enabled: true
            highlightViewUpdateAlertVisible: conductor.highLightViewUpdateAlertVisible
            // 边下边播首帧缓冲状态，遮罩在 PanoramaPlayerView 内部锚 displayView 显示。
            // && prepared：本窗口另有 loadingMask(visible: !conductor.prepared)，两者都是同一张
            // 48×48 icon_loading.png、都居中、都 2000ms 无限自转，起转时刻不同 → 相位错开，同时可见
            // 时视觉上是两个错位的圈重合。资源就绪前由 loadingMask("素材加载中")独占，就绪后
            // RemotePlaybackUtils open 完成后由 bufferingMask 接管，直到 PreviewSession 首帧到达。
            // 编辑器主播放器无 prepared 遮罩，仍直接绑 bufferingActive，不受影响。
            bufferingActive: conductor.bufferingActive && conductor.prepared
            onHighlightViewUpdateAlertCancel: {
                conductor.restoreGestureStartView()
            }
            onHighlightViewUpdateAlertConfirm: {
                conductor.confirmGestureOffset()
            }
            // 手势起止驱动 conductor 视角编辑。
            Connections {
                target: player
                function onGesturingChanged() {
                    if (player.playerHandleGesture) {
                        return;
                    }
                    if (player.gesturing) {
                        conductor.previewGestureStart();
                    } else {
                        conductor.previewGestureEnd();
                    }
                }
            }

            onPlayerHandleGestureChanged: {
                logger.d("PreviewPlayer PlayerHandleGesture: " + player.playerHandleGesture)
            }

            // 移动/拖拽/调节水平和垂直视角
            onMove: (deltaX, deltaY, fling) => {
                const normalizedDX = deltaX / player.width / 2;
                const normalizedDY = deltaY / player.height / 2;
                const params = conductor.params;
                const profileWidth = editorManager.profileWidth();
                const profileHeight = editorManager.profileHeight();
                const hDegree = params.hDegree + (profileWidth * 2 * normalizedDX / 5);
                const vDegree = params.vDegree + (profileHeight * 2 * normalizedDY / 5);
                conductor.updatePreviewViewDegree(hDegree, vDegree);
            }

            // 缩放/调节视场角
            onZoom: (deltaPercentage) => {
                const fovRange = QPanoramaLimit.FOV_MAX - QPanoramaLimit.FOV_MIN;
                const distortionRange = QPanoramaLimit.DISTORTION_MAX - QPanoramaLimit.DISTORTION_MIN;
                if (fovRange <= 0 || distortionRange <= 0) {
                    return;
                }
                const deltaFov = fovRange * deltaPercentage;
                const params = conductor.params;
                const fov = params.fov + deltaFov;
                const deltaDistortion = distortionRange * deltaPercentage;
                const distortion = params.distortion + deltaDistortion;
                conductor.updatePreviewFov(fov, distortion);
            }

            // 旋转/调节z轴
            onRotate: (rotation) => {
                const params = conductor.params;
                const rotationZ = params.rotationZ + rotation;
                conductor.updatePreviewRotationZ(rotationZ);
            }

            Component.onCompleted: {
                logger.d("MKDisplayView player completed")
                conductor.setupTarget(this.displayView);
            }

            // 云相册边下边播标志下传给播放控制器：仅用于放宽「播完再点播放从头播」的判据
            // （流式 profile 30fps 与云端素材 29.97fps 不匹配，帧数判据失效，详见 togglePlayState）。
            // 本地预览 isStreaming 恒为 false，播放器行为与改动前一致。
            Binding {
                target: player.controller
                property: "streamingPlayback"
                value: sourceHandler.isStreaming
                when: player.controller !== null
            }
        }

        Rectangle {
            id: loadingMask
            anchors.fill: parent
            color: Colors.color_transparent
            visible: !conductor.prepared

            ColumnLayout {
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    verticalCenter: parent.verticalCenter
                }
                spacing: 12
                Image {
                    id: loading
                    width: 48
                    height: 48
                    source: "qrc:/icons/icon_loading.png"
                    sourceSize: Qt.size(48, 48)
                    Layout.alignment: Qt.AlignHCenter
                    RotationAnimation on rotation {
                        from: 0
                        to: 360
                        running: loadingMask.visible
                        duration: 2000 // Duration of one full rotation in milliseconds
                        loops: Animation.Infinite // Loop indefinitely
                    }
                }

                Text {
                    id: loadingText
                    text: qsTr("pccut_image_preview_tip")
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    color: Colors.color_EEEEEE
                }
            }
        }

        // 高斯模糊，控件按x、y、width、height和播放控件对齐， 因为在全屏过程中发生了位移，不能用相对布局
        // 默认非全屏， 隐藏
        LightClipRectangle {
            property var target: controlPanel
            id: blur_player_controller_fullscreen
            x: target.x
            y: target.y
            width: target.width
            height: target.height
            radius: [target.radius, target.radius, target.radius, target.radius]
            // 高斯模糊的画面数据源设置
            ShaderEffectSource {
                id: effectsource
                // 模糊的画面数据来自player
                sourceItem: player
                // 逻辑是取播放器中的区域去做模糊。这个区域的位置是相对于播放器的左上角(0,0)点
                // 这里为什么要删掉 topbar 的高度。原因是根布局是Rectangle，各个UI的xy是获取
                // 相对于整个window左上角的(0,0)点，而播放器的左上角在整个布局文件中的 (0, topbar)
                // 减去topbar是为了对齐坐标
                sourceRect: Qt.rect(blur_player_controller_fullscreen.target.x - player.x,
                                    blur_player_controller_fullscreen.target.y - topbarHeight - player.y,
                                    blur_player_controller_fullscreen.target.width,
                                    blur_player_controller_fullscreen.target.height)
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

        PreviewControlPanel {
            id: controlPanel
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottomMargin: 36
            controller: player.controller
            isFullScreen: isFullScreen
            handler: sourceHandler
            z: 1
            // 【云相册边下边播·缓冲进度·正式】把 conductor 的已缓冲帧区间透到进度条灰条。
            cachedRanges: conductor.cachedRanges

            onFullScreenClicked: {
                if (isFullScreen) {
                    previewPlayerRoot.callFullScreen(false)
                } else {
                    previewPlayerRoot.callFullScreen(true)
                    eventTracker.trackEvent("pccut_player_fullscreen_click", {"use_method": "player_page"})
                }
            }
        }

        PreviewItemTypeTip {
            id: typeTip
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: 20
            anchors.topMargin: 16
            visible: conductor.isVideo || conductor.isImage || conductor.isPanoVideo ||
                     conductor.isPanoImage || conductor.isLoopVideo || conductor.isHyperlapseVideo ||
                     conductor.isTimelapseVideo || conductor.isSlowMotionVideo
            isVideo: conductor.isVideo
            isImage: conductor.isImage
            isPanoImage: conductor.isPanoImage
            isPanoVideo: conductor.isPanoVideo
            isLoopVideo: conductor.isLoopVideo
            isHyperlapseVideo: conductor.isHyperlapseVideo
            isTimelapseVideo: conductor.isTimelapseVideo
            isSelfieModeVideo: conductor.isSelfieModeVideo
            isBullefTimeVideo: conductor.isBullefTimeVideo
            isSlowMotionVideo: conductor.isSlowMotionVideo
            isPanoFlatVideo: conductor.isPanoFlatVideo
            imageSource:conductor.getIconType
            sourceView: player
            videoPath: sourceHandler.currentSource
        }

        onWidthChanged: {
            handleSizeChanged()
        }

        onHeightChanged: {
            handleSizeChanged()
        }

        // 当播放器所在区域的宽高发生变化时，调整播放器本身的大小
        function handleSizeChanged() {
            // TODO: yahui.li 拿画幅尺寸
            const frameWidth = 16;
            const frameHeight = 9;
            // TODO: END
            const frameRatio = frameWidth / frameHeight
            const containerRatio = playerContainer.width / playerContainer.height
            let playerWidth, playerHeight
            if (frameRatio > containerRatio) {
                playerWidth = playerContainer.width
                playerHeight = playerContainer.width / frameRatio
            } else {
                playerHeight = playerContainer.height
                playerWidth = playerContainer.height * frameRatio
            }
            player.width = playerWidth
            player.height = playerHeight
        }
        // 播放器的快捷键增加删除一定要改switchPlayerWindowAction名单
        // 监听播放器全屏和退出全屏快捷键
        CShortcut {
            id: fullScreen
            action: ShortcutAction.FULL_SCREEN
            priority: prioritySetting
            onActivated: {
                if (isFullScreen) {
                    previewPlayerRoot.callFullScreen(false)
                } else {
                    previewPlayerRoot.callFullScreen(true)
                    eventTracker.trackEvent("pccut_player_fullscreen_click", {"use_method": "player_page"})
                }
            }
        }
        CShortcut {
            action: ShortcutAction.SECOND_FULL_SCREEN
            priority: prioritySetting
            onActivated: {
                if (isFullScreen) {
                    previewPlayerRoot.callFullScreen(false)
                } else {
                    previewPlayerRoot.callFullScreen(true)
                    eventTracker.trackEvent("pccut_player_fullscreen_click", {"use_method": "player_page"})
                }
            }
        }


        // 监听esc 按键， 全屏下退出全屏
        CShortcut {
            action: ShortcutAction.ESCAPE_FULL_SCREEN
            priority: prioritySetting
            onActivated: {
                if (isFullScreen) {
                    // 当前全屏播放控件展示，表示全屏状态， 触发非全屏操作
                    previewPlayerRoot.callFullScreen(false)
                }
                else {
                    // 关闭预览播放器
                    controller.pause()
                    if (playerWindow.isCloudAlbumPreview) {
                        globalSignal.cloudAlbumPreviewClosing(1)
                    }
                    globalSignal.closeWindow()
                }
            }
        }

        // 支持系统退出快捷键来关闭预览播放器
        Shortcut {
            sequence: StandardKey.Quit // 自动适配平台快捷键
            onActivated: {
                controller.pause()
                globalSignal.closeWindow()
            }
        }

        function dismissController() {
            blur_player_controller_fullscreen.visible = false
            controlPanel.visible = false
        }

        function showController() {
            if (previewPlayerRoot.isCloudAlbumImagePreview) {
                return
            }
            blur_player_controller_fullscreen.visible = true
            controlPanel.visible = true
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Colors.transparent
        border.color: Colors.color_FFFFFF_10
        border.width: 1
        radius: 10
    }

    // 顶部调整大小区域
    ResizeArea {
        id: topResizeArea
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: resizeAreaSize

        mouseArea.cursorShape: !CommonUtils.isNull(Window.window) ? Window.window.visibility === Window.FullScreen ? Qt.ArrowCursor : Qt.SizeVerCursor : Qt.ArrowCursor
        mouseArea.onPositionChanged: {
            previewWindowSizeManager.resizeWindowBasedOnCursor(Qt.TopEdge);
        }
    }
    // 底部调整大小区域
    ResizeArea {
        id: bottomResizeArea
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: resizeAreaSize

        mouseArea.cursorShape: !CommonUtils.isNull(Window.window) ? Window.window.visibility === Window.FullScreen ? Qt.ArrowCursor : Qt.SizeVerCursor : Qt.ArrowCursor
        mouseArea.onPositionChanged: {
            previewWindowSizeManager.resizeWindowBasedOnCursor(Qt.BottomEdge);
        }
    }
    // 左侧调整大小区域
    ResizeArea {
        id: leftResizeArea
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: resizeAreaSize
        mouseArea.cursorShape: !CommonUtils.isNull(Window.window) ? Window.window.visibility === Window.FullScreen ? Qt.ArrowCursor : Qt.SizeHorCursor : Qt.ArrowCursor
        mouseArea.onPositionChanged: {
            previewWindowSizeManager.resizeWindowBasedOnCursor(Qt.LeftEdge);
        }
    }

    // 右侧调整大小区域
    ResizeArea {
        id: rightResizeArea
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: resizeAreaSize

        mouseArea.cursorShape: !CommonUtils.isNull(Window.window) ? Window.window.visibility === Window.FullScreen ? Qt.ArrowCursor : Qt.SizeHorCursor : Qt.ArrowCursor
        mouseArea.onPositionChanged: {
            previewWindowSizeManager.resizeWindowBasedOnCursor(Qt.RightEdge);
        }
    }

    // 左上角调整大小区域
    ResizeArea {
        id: topLeftResizeArea
        anchors.left: parent.left
        anchors.top: parent.top
        width: resizeAreaSize
        height: resizeAreaSize

        mouseArea.cursorShape: !CommonUtils.isNull(Window.window) ? Window.window.visibility === Window.FullScreen ? Qt.ArrowCursor : Qt.SizeFDiagCursor : Qt.ArrowCursor
        mouseArea.onPositionChanged: {
            previewWindowSizeManager.resizeWindowBasedOnCursor(Qt.LeftEdge | Qt.TopEdge);
        }
    }

    // 右上角调整大小区域
    ResizeArea {
        id: topRightResizeArea
        anchors.right: parent.right
        anchors.top: parent.top
        width: resizeAreaSize
        height: resizeAreaSize

        mouseArea.cursorShape: !CommonUtils.isNull(Window.window) ? Window.window.visibility === Window.FullScreen ? Qt.ArrowCursor : Qt.SizeBDiagCursor : Qt.ArrowCursor
        mouseArea.onPositionChanged: {
            previewWindowSizeManager.resizeWindowBasedOnCursor(Qt.RightEdge | Qt.TopEdge);
        }
    }

    // 左下角调整大小区域
    ResizeArea {
        id: bottomLeftResizeArea
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        width: resizeAreaSize
        height: resizeAreaSize
        mouseArea.cursorShape: !CommonUtils.isNull(Window.window) ? Window.window.visibility === Window.FullScreen ? Qt.ArrowCursor : Qt.SizeBDiagCursor : Qt.ArrowCursor
        mouseArea.onPositionChanged: {
            previewWindowSizeManager.resizeWindowBasedOnCursor(Qt.LeftEdge | Qt.BottomEdge);
        }
    }

    // 右下角调整大小区域
    ResizeArea {
        id: bottomRightResizeArea
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: resizeAreaSize
        height: resizeAreaSize
        mouseArea.cursorShape: !CommonUtils.isNull(Window.window) ? Window.window.visibility === Window.FullScreen ? Qt.ArrowCursor : Qt.SizeFDiagCursor : Qt.ArrowCursor
        mouseArea.onPositionChanged: {
            previewWindowSizeManager.resizeWindowBasedOnCursor(Qt.RightEdge | Qt.BottomEdge);
        }
    }

    function saveWindowGeometrySettings() {
        previewWindowSizeManager.saveWindowGeometrySettings();
    }

    onWidthChanged: saveWindowGeometrySettings()
    onHeightChanged: saveWindowGeometrySettings()
    onXChanged: saveWindowGeometrySettings()
    onYChanged: saveWindowGeometrySettings()
    
    // 设置该定时器的目的，是为了让播放器退出全屏时可以重新获取焦点以响应快捷键
    // 为什么设置定时器而不是在callFullScreen方法中直接调用triggered中的两个方法？
    // 如果直接调用，此时退出全屏的动画还未结束，调用下面两个方法后会出现全屏的画面正在缩小，但中心区已经显示了缩小完成的画面，整个画面呈“回”字型
    Timer {
        id: raiseTimer
        interval: 400
        repeat: false
        
        onTriggered: {
            win.raise()
            win.requestActivate()
        }
    }
    
    Connections {
        target: previewPlayerRoot
        // 监听主窗口的尺寸变化而不监听playerPanel的尺寸是因为
        // 监听playerPanel的话，在全屏/退出全屏时，尺寸会变化两次
        // 一次是主窗口全屏时，playerPanel尺寸变化，一次是playerPanel的state切换到全屏时，尺寸变化
        function onWidthChanged() {
            if (previewPlayerRoot.prePlayerState === Window.FullScreen) {
                previewPlayerRoot.prePlayerState = Window.Windowed
                blur_player_controller_fullscreen.visible = false;
                isFullScreen = false
                controlPanel.isFullScreen = false
            }
        }

        function onHeightChanged() {
            if (previewPlayerRoot.prePlayerState === Window.FullScreen) {
                previewPlayerRoot.prePlayerState = Window.Windowed
                blur_player_controller_fullscreen.visible = false;
                isFullScreen = false
                controlPanel.isFullScreen = false
            }
        }
    }

    function callFullScreen(isShow) {
        if (isShow) {
            preAppState = Window.window.visibility
            Window.window.showFullScreen()
            prePlayerState = Window.FullScreen
            isFullScreen = true
            controlPanel.isFullScreen = true
        } else {
            if (preAppState === Window.Maximized) {
                Window.window.showMaximized()
                preAppState = Window.Maximized
            } else if (preAppState !== Window.FullScreen) {
                Window.window.showNormal()
                preAppState = Window.Windowed // 这里不能用 preAppState = Window.window.visibility 因为visibility存在滞后性，此时还未更新
            }
            prePlayerState = Window.Windowed
            isFullScreen = false
            controlPanel.isFullScreen = false
        }
    }
    
    CShortcut {
        action: ShortcutAction.START_FRAME
        priority: prioritySetting
        onActivated: {
            controller.seekStart();
        }
    }

    CShortcut {
        action: ShortcutAction.END_FRAME
        priority: prioritySetting
        onActivated: {
            controller.seekEnd();
        }
    }

    CShortcut {
        action: ShortcutAction.PAUSE
        priority: prioritySetting
        onActivated: {
            controller.togglePlayState();
            if (!controller.playing) {
                editorManager.trackPauseClickEventAsync("player_page", sourceHandler.currentSource)
            } else {
                eventTracker.trackEvent("pccut_player_play_click", {"use_method": "player_page"})
            }
        }
    }

    CShortcut {
        action: ShortcutAction.PREVIOUS_FRAME
        onActivated: {
            controller.seekPreviousFrame();
        }
    }

    CShortcut {
        action: ShortcutAction.NEXT_FRAME
        onActivated: {
            controller.seekNextFrame();
        }
    }

    CShortcut {
        action: ShortcutAction.PREVIOUS_TEN_FRAME
        onActivated: {
            controller.seekPreviousNFrame(10);
        }
    }

    CShortcut {
        action: ShortcutAction.NEXT_TEN_FRAME
        onActivated: {
            controller.seekNextNFrame(10);
        }
    }
}
