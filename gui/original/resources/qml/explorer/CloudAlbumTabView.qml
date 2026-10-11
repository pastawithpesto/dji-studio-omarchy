import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Dialogs
import Controls 1.0
import Config 1.0
import CloudAlbumManager 1.0
import CloudAlbumFilterProxyModel 1.0
import CloudAlbumTransferModel 1.0
import CloudAlbumAssetListModel 1.0
import CloudAlbumTabViewModel 1.0
import MediaListViewModel 1.0
import Qt5Compat.GraphicalEffects
import ShortcutAction 1.0
import app_qrc 1.0

import "../welcome/cloudalbum"

/**
 * @desc 编辑器素材面板 - 云相册视图
 *       与 LocalTabView + MediaSelectedPage 视觉风格完全一致
 */
Item {
    id: tabRoot

    property var cloudAlbumModel: null
    property MediaListViewModel mediaListViewModel: null
    property CloudAlbumTabViewModel tabViewModel: CloudAlbumTabViewModel {
        assetModel: tabRoot.cloudAlbumModel
        mediaListViewModel: tabRoot.mediaListViewModel
        visible: tabRoot.visible
    }
    property bool hasContent: tabViewModel.hasContent
    property bool isLoggedIn: CloudAlbumManager.isLoggedIn
    // 模式切换功能暂时隐藏，后续恢复时取消相关注释。
    // property bool isListMode: false

    // 多选：记录上次左键点击的 proxy 索引，供 shift+click 区间选择使用
    property int _lastClickedIndex: -1
    property bool _isDragSelecting: false

    function clearCloudSelection() {
        if (!tabRoot.cloudAlbumModel) {
            return;
        }
        tabRoot.cloudAlbumModel.selectAll(false);
        tabRoot._lastClickedIndex = -1;
    }

    function showDeletePopup(fileIds, method) {
        if (!fileIds || fileIds.length === 0) return
        tabRoot.tabViewModel.trackDeleteClick(fileIds, method)
        var metadata = tabRoot.tabViewModel.deleteMetadata(fileIds)
        cloudAlbumDeletePopup.showPop(fileIds.slice(), metadata)
    }

    CShortcut {
        action: ShortcutAction.DELETE
        enabled: tabRoot.visible && tabRoot.cloudAlbumModel
                 && tabRoot.cloudAlbumModel.selectedAssetIds().length > 0
        onActivated: {
            tabRoot.showDeletePopup(
                tabRoot.cloudAlbumModel.selectedAssetIds(), 2)
        }
    }

    CShortcut {
        action: ShortcutAction.ESCAPE_FULL_SCREEN
        enabled: tabRoot.visible && tabRoot.tabViewModel.hasTrackedPreview()
        onActivated: {
            tabRoot.tabViewModel.trackPreviewClose(1)
            tabRoot.tabViewModel.resetImagePreviewState(true)
            editorManager.exitCloudPreview(-1)
        }
    }

    // 与 MediaSelectedPage 对齐：点击云相册面板任意位置时通知轨道清空选中，右侧设置面板
    // 回落到"项目信息"。此顶层 MouseArea 兜底 GridView 之外的区域（未登录空态、标题栏等），
    // GridView 内的空白与 delegate 分别在 dragSelectMouseArea / delegate mouseArea 里发信号。
    MouseArea {
        anchors.fill: parent
        onPressed: (mouse) => {
            globalSignal.cleanTrackSelectState();
            mouse.accepted = false;
        }
    }

    DragMediaCover {
        id: cloudDraggableRect
        mediaListViewModel: tabRoot.mediaListViewModel
        dragBeginCallback: function(index, mousePoint) {
            var fileList = tabRoot.tabViewModel.beginCloudDrag(mousePoint);
            if (fileList.length > 0) {
                cloudDraggableRect.mediaPath = fileList[0];
                cloudDraggableRect.mediaAssetId =
                    tabRoot.tabViewModel.currentCloudDragAssetId();
            }
            return fileList;
        }
        dragReleaseCallback: function(fileList, isCancel) {
            tabRoot.tabViewModel.endCloudDrag();
            cloudDraggableRect.mediaPath = "";
            cloudDraggableRect.mediaAssetId = "";
        }
    }

    // 上传文件
    function openUploadFileDialog() {
        if (!tabRoot.isLoggedIn) {
            userLoginViewModel.showLoginPopup()
            return
        }
        var formats = tabRoot.tabViewModel.supportedUploadFormats();
        if (formats.length > 0) {
            var wildcards = formats.map(function(ext) { return "*" + ext; }).join(" ");
            uploadFileDialog.nameFilters = ["Media files (" + wildcards + ")"];
        }
        uploadFileDialog.open();
    }

    // 上传文件选择对话框
    FileDialog {
        id: uploadFileDialog
        title: qsTr("pccut_cloud_album_upload")
        nameFilters: ["Media files (*.mp4 *.mov *.jpg *.jpeg *.png *.dng)"]
        fileMode: FileDialog.OpenFiles
        onAccepted: {
            tabRoot.tabViewModel.uploadUrls(selectedFiles, 0);
        }
    }

    // 下载保存 - 单文件用 FileDialog（SaveFile），多文件用 FolderDialog
    FileDialog {
        id: downloadSaveFileDialog
        title: qsTr("pccut_device_batch_download")
        fileMode: FileDialog.SaveFile
        currentFolder: tabRoot.tabViewModel.defaultDownloadFolderUrl()
        onAccepted: {
            tabRoot.tabViewModel.acceptSingleFileDownload(selectedFile);
        }
        onRejected: {
            tabRoot.tabViewModel.cancelPendingDownload();
        }
    }

    FolderDialog {
        id: downloadFolderDialog
        title: qsTr("pccut_device_batch_download")
        currentFolder: tabRoot.tabViewModel.defaultDownloadFolderUrl()
        onAccepted: {
            tabRoot.tabViewModel.acceptFolderDownload(selectedFolder);
        }
        onRejected: {
            tabRoot.tabViewModel.cancelPendingDownload();
        }
    }

    // 筛选代理模型
    CloudAlbumFilterProxyModel {
        id: filterProxyModel
        filterType: tabRoot.currentFilterType
        hideDngPrimaryFiles: Qt.platform.os === "windows"
    }
    onCloudAlbumModelChanged: {
        if (cloudAlbumModel) {
            filterProxyModel.setSourceModelFromQml(cloudAlbumModel);
            Qt.callLater(function() {
                tabRoot.tabViewModel.preloadDownloadedCloudMedia(filterProxyModel);
            });
        }
    }

    Connections {
        target: filterProxyModel
        function onCountChanged() {
            Qt.callLater(function() {
                tabRoot.tabViewModel.preloadDownloadedCloudMedia(filterProxyModel);
            });
        }
    }

    Connections {
        target: cloudAlbumModel
        function onCountChanged() {
            Qt.callLater(function() {
                tabRoot.tabViewModel.preloadDownloadedCloudMedia(filterProxyModel);
            });
        }
    }

    Connections {
        target: tabRoot.mediaListViewModel
        function onCloudMediaPrepared(assetId, success) {
            // 预热完成后，delegate 会通过 isCloudMediaPrepared() 放开拖拽。
        }
    }

    Connections {
        target: globalSignal
        function onCleanSelectMediaPath() {
            tabRoot.clearCloudSelection();
        }
        function onAudioSelected(fragment) {
            if (!CommonUtils.isNull(fragment)) {
                tabRoot.clearCloudSelection();
            }
        }
        function onVideoSelected(fragment) {
            if (!CommonUtils.isNull(fragment)) {
                tabRoot.clearCloudSelection();
            }
        }
    }

    CloudAlbumLocalUploadBridge {
        assetModel: tabRoot.cloudAlbumModel
        active: tabRoot.visible
    }

    Connections {
        target: openOperator
        function onShowPreviewChanged() {
            if (!openOperator.showPreview) {
                tabRoot.tabViewModel.trackPreviewClose(0)
                tabRoot.tabViewModel.resetImagePreviewState(true)
            }
        }
    }

    // 筛选类型：0=全部, 1=视频, 2=图片, 3=收藏
    property int currentFilterType: 0

    onVisibleChanged: {
        // 切走云相册面板时退出主播放器临时预览，恢复时间轴
        if (!visible) {
            tabRoot.tabViewModel.trackPreviewClose(0);
            tabRoot.tabViewModel.resetImagePreviewState(true);
            editorManager.exitCloudPreview(-1);
        }
    }

    onIsLoggedInChanged: {
        tabRoot.tabViewModel.refreshIfNeeded();
    }

    // 封面尺寸（与 MediaSelectedPage 网格模式一致）
    // property real itemCoverWidth: isListMode ? (gridView.width - 18) : 128
    // property real itemCoverHeight: isListMode ? 48 : 72
    property real itemCoverWidth: 128
    property real itemCoverHeight: 72
    property real itemCoverX: 6
    property real cellRadius: 6

    Connections {
        target: tabRoot.tabViewModel
        function onLoginRequired() {
            userLoginViewModel.showLoginPopup();
        }
        function onSingleFileDownloadRequested(currentFolder, selectedFile) {
            downloadSaveFileDialog.currentFolder = currentFolder;
            downloadSaveFileDialog.selectedFile = selectedFile;
            downloadSaveFileDialog.open();
        }
        function onFolderDownloadRequested(currentFolder) {
            downloadFolderDialog.currentFolder = currentFolder;
            downloadFolderDialog.open();
        }
        function onPreviewLocalRequested(localPath, durationMs) {
            editorManager.previewCloudLocal(localPath, 0, durationMs);
        }
    }

    // 下载完成后触发已下载素材预热；状态同步由页面 ViewModel 处理。
    Connections {
        target: CloudAlbumTransferModel
        function onDownloadComplete(assetId, localPath) {
            Qt.callLater(function() {
                tabRoot.tabViewModel.preloadDownloadedCloudMedia(filterProxyModel);
            });
        }
    }

    Item {
        id: cloudAlbumContent
        anchors.fill: parent
        visible: tabRoot.isLoggedIn

        // 空状态面板（云相册专用）
        Rectangle {
            id: emptyPanel
            visible: !tabRoot.hasContent
            width: 180
            height: 180
            anchors.centerIn: parent
            layer.enabled: true
            color: emptyMouseArea.containsMouse ? Colors.color_FFFFFF_10 : Colors.color_2F3032
            border.color: Colors.color_454649
            border.width: 1
            radius: 8

            Image {
                id: emptyIcon
                width: 44
                height: 44
                anchors {
                    top: parent.top
                    horizontalCenter: parent.horizontalCenter
                    topMargin: 35
                }
                source: "qrc:/app_qrc/icons/cloud_album_upload_large.svg"
                sourceSize: Qt.size(44, 44)
            }

            Text {
                id: emptyTip1
                anchors {
                    top: emptyIcon.bottom
                    horizontalCenter: parent.horizontalCenter
                    topMargin: 12
                }
                text: qsTr("pccut_cloud_album_empty")
                color: Colors.color_D8D8D8
                font.pixelSize: 12
            }

            Text {
                id: emptyTip2
                anchors {
                    top: emptyTip1.bottom
                    horizontalCenter: parent.horizontalCenter
                    topMargin: 8
                }
                text: qsTr("pccut_cloud_album_empty_desc")
                color: Colors.color_666666
                font.pixelSize: 11
            }

            MouseArea {
                id: emptyMouseArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    tabRoot.openUploadFileDialog();
                }
            }

            HoverableText {
                id: emptyTip3
                anchors {
                    top: emptyTip2.bottom
                    left: parent.left
                    leftMargin: 12
                    right: parent.right
                    rightMargin: 12
                    topMargin: 1
                }
                text: qsTr("pccut_cloud_album_format_hint")
                color: Colors.color_666666
                font.pixelSize: 11
                maximumLineCount: 2
                wrapMode: Text.WordWrap
                cursorChanged: false
                horizontalAlignment: Text.AlignHCenter

                onClicked: {
                    tabRoot.openUploadFileDialog();
                }
            }
        }

        // 标题栏
        Item {
            id: titleBar
            height: 24
            visible: true
            anchors {
                top: parent.top
                topMargin: 16
                left: parent.left
                leftMargin: 12
                right: parent.right
            }

            // 导入按钮（左侧，与 LocalTabView addBtn 风格一致）
            Rectangle {
                id: importBtn
                height: 24
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                radius: 4
                color: importBtnArea.containsMouse ? ColorsConfig.color_brand_20 : ColorsConfig.color_brand_10
                width: uploadIcon.width + importText.implicitWidth + 18

                Image {
                    id: uploadIcon
                    width: 16
                    height: 16
                    anchors {
                        left: parent.left
                        leftMargin: 8
                        verticalCenter: parent.verticalCenter
                    }
                    source: "qrc:/app_qrc/icons/cloud_album_upload_tab.svg"
                    sourceSize: Qt.size(16, 16)
                }

                Text {
                    id: importText
                    anchors {
                        left: uploadIcon.right
                        leftMargin: 2
                        verticalCenter: parent.verticalCenter
                    }
                    font.pixelSize: 12
                    color: ColorsConfig.color_brand
                    text: qsTr("pccut_cloud_album_upload")
                }

                MouseArea {
                    id: importBtnArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: tabRoot.openUploadFileDialog()
                }
            }

            /*
            // 视图切换按钮（最右侧）
            IconButton {
                id: viewToggleBtn
                visible: tabRoot.hasContent
                radius: 4
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: 10
                width: 24
                height: 24
                iconMargins: 2
                hoverTextFunc: function() {
                    return qsTr("pccut_media_mode");
                }
                hoverColor: Colors.color_track_tool_button_background_hovered
                iconSource: tabRoot.isListMode
                    ? "qrc:/app_qrc/icons/cloud_album_grid.svg"
                    : "qrc:/app_qrc/icons/cloud_album_list.svg"
                onClicked: {
                    tabRoot.isListMode = !tabRoot.isListMode;
                }
            }
            */

            // 筛选按钮（最右侧）
            IconButton {
                id: filterBtn
                visible: tabRoot.hasContent
                radius: 4
                anchors.verticalCenter: parent.verticalCenter
                // anchors.right: viewToggleBtn.left
                anchors.right: parent.right
                anchors.rightMargin: 10
                width: 24
                height: 24
                iconMargins: 2
                hoverTextFunc: function() {
                    return qsTr("pccut_media_filter");
                }
                hoverColor: Colors.color_track_tool_button_background_hovered
                iconSource: (filterPopup.visible || tabRoot.currentFilterType !== 0)
                    ? "qrc:/app_qrc/icons/editor_material_filter_selected.svg"
                    : "qrc:/icons/editor_material_filter.svg"
                onClicked: {
                    var newPoint = filterBtn.mapToItem(null, width, height);
                    filterPopup.x = newPoint.x - filterPopup.width;
                    filterPopup.y = newPoint.y + 4;
                    var operateModels = filterPopup.filterModel;
                    operateModels.clear();
                    operateModels.append({"title": qsTr("pccut_media_filter_all"),      "filterType": CloudAlbumFilterPopup.FilterType.All});
                    operateModels.append({"title": qsTr("pccut_media_filter_video"),    "filterType": CloudAlbumFilterPopup.FilterType.Video});
                    operateModels.append({"title": qsTr("pccut_media_filter_image"),    "filterType": CloudAlbumFilterPopup.FilterType.Image});
                    operateModels.append({"title": qsTr("pccut_media_filter_favorite"), "filterType": CloudAlbumFilterPopup.FilterType.Favorite});
                    filterPopup.open();
                }
            }

            // 筛选弹框
            CloudAlbumFilterPopup {
                id: filterPopup
                x: 0
                y: 0
                parent: Overlay.overlay
                currentFilterType: tabRoot.currentFilterType
                closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
                Overlay.modal: Rectangle {
                    color: Colors.color_transparent
                }
                onClickFilterType: (filterType) => {
                    tabRoot.currentFilterType = filterType;
                }
            }
        }

        // 内容区 GridView（与 MediaSelectedPage 网格模式一致）
        GridView {
            id: gridView
            visible: tabRoot.hasContent
            anchors {
                top: titleBar.visible ? titleBar.bottom : parent.top
                topMargin: 16
                left: parent.left
                right: parent.right
                rightMargin: 6
                bottom: parent.bottom
                leftMargin: 6
            }
            clip: true

            flow: GridView.FlowLeftToRight
            // cellWidth: tabRoot.isListMode ? gridView.width : (itemCoverWidth + itemCoverX * 2)
            // cellHeight: tabRoot.isListMode ? 78 : 102
            cellWidth: itemCoverWidth + itemCoverX * 2
            cellHeight: 102
            boundsBehavior: GridView.StopAtBounds
            flickDeceleration: 7000
            model: filterProxyModel

            onContentHeightChanged: ensureContentHeight()
            onHeightChanged: ensureContentHeight()
            function ensureContentHeight() {
                // 与 MediaSelectedPage 对齐：contentHeight < height 时把 contentItem 撑满可见区。
                // 否则 items 稀少时 contentItem 只有实际内容高度，dragSelectMouseArea
                // (parent: gridView.contentItem) 覆盖不到下方空白，点空白清空选中无法触发。
                if (contentHeight < height) {
                    contentHeight = height;
                }
            }

            onAtYEndChanged: {
                if (atYEnd && tabRoot.cloudAlbumModel && !tabRoot.cloudAlbumModel.isLoading && !tabRoot.cloudAlbumModel.isEnd) {
                    tabRoot.cloudAlbumModel.fetchNextPage();
                }
            }

            ScrollBar.vertical: ScrollBar {
                Component.onCompleted: {
                    contentItem.color = Colors.color_444444;
                }
            }

            // 点击空白区域清空选中 + 鼠标拖动框选
            MouseArea {
                id: dragSelectMouseArea
                parent: gridView.contentItem
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                propagateComposedEvents: true
                preventStealing: true
                property real startX: 0
                property real startY: 0
                property real startContentY: 0
                property real currentX: 0
                property real currentY: 0
                property bool isShowRect: false

                onPressedChanged: {
                    if (pressed) {
                        gridView.forceLayout();
                        isShowRect = false;
                        tabRoot._isDragSelecting = false;
                    } else {
                        Qt.callLater(function() {
                            dragSelectMouseArea.isShowRect = false;
                            tabRoot._isDragSelecting = false;
                        });
                        dragScrollTimer.stop();
                    }
                }

                onPressed: (mouse) => {
                    // 与 MediaSelectedPage 对齐：点击 GridView 空白清空轨道选中
                    globalSignal.cleanTrackSelectState();
                    let point = mapToItem(gridView, Qt.point(mouse.x, mouse.y));
                    startX = point.x;
                    startY = point.y;
                    currentX = startX;
                    currentY = startY;
                    startContentY = gridView.contentY;
                    dragScrollTimer.scrollDirectionY = 0;
                    dragScrollTimer.maxContentY = 0;
                    dragScrollTimer.start();
                }

                onPositionChanged: (mouse) => {
                    if (mouse.buttons === Qt.LeftButton) {
                        let point = mapToItem(gridView, Qt.point(mouse.x, mouse.y));
                        currentX = point.x;
                        currentY = point.y;

                        let edge = 30;
                        let distance = 5;
                        var speed = 0;
                        if (point.y < edge) {
                            speed = (point.y - edge) / (edge * 2);
                        } else if (gridView.height - edge < point.y) {
                            speed = (point.y + edge - gridView.height) / (edge * 2);
                        }
                        dragScrollTimer.scrollDirectionY = speed * distance;
                    }
                }

                onCanceled: {
                    dragScrollTimer.stop();
                }

                onReleased: {
                    dragScrollTimer.stop();
                }

                onClicked: (mouse) => {
                    if (tabRoot._isDragSelecting) {
                        mouse.accepted = true;
                        return;
                    }

                    var point = mapToItem(gridView, Qt.point(mouse.x, mouse.y));
                    var item = gridView.itemAt(point.x, point.y + gridView.contentY);
                    if (!item && tabRoot.cloudAlbumModel) {
                        tabRoot.cloudAlbumModel.selectAll(false);
                        tabRoot._lastClickedIndex = -1;
                    }
                    mouse.accepted = false;
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
                    y: Math.min(dragSelectMouseArea.startY + dragSelectMouseArea.startContentY,
                                dragSelectMouseArea.currentY + gridView.contentY)
                    height: Math.abs(dragSelectMouseArea.startY + dragSelectMouseArea.startContentY
                                     - dragSelectMouseArea.currentY - gridView.contentY)

                    onWidthChanged: refreshDragSelect()
                    onHeightChanged: refreshDragSelect()

                    function refreshDragSelect() {
                        if (!bgSelectionRect.visible || !dragSelectMouseArea.pressed) {
                            return;
                        }
                        if (!tabRoot.cloudAlbumModel || !filterProxyModel) {
                            return;
                        }
                        if (bgSelectionRect.width < 2 || bgSelectionRect.height < 2) {
                            return;
                        }

                        dragSelectMouseArea.isShowRect = true;
                        tabRoot._isDragSelecting = true;
                        tabRoot._lastClickedIndex = -1;
                        tabRoot.cloudAlbumModel.selectAll(false);

                        var selLeft = bgSelectionRect.x;
                        var selTop = bgSelectionRect.y;
                        var selRight = selLeft + bgSelectionRect.width;
                        var selBottom = selTop + bgSelectionRect.height;
                        var totalCount = filterProxyModel.rowCount();
                        var cellWidth = gridView.cellWidth;
                        var cellHeight = gridView.cellHeight;
                        var columnCount = Math.max(1, Math.floor(gridView.width / cellWidth));

                        for (var i = 0; i < totalCount; i++) {
                            var column = i % columnCount;
                            var row = Math.floor(i / columnCount);
                            var itemLeft = column * cellWidth + tabRoot.itemCoverX;
                            var itemTop = row * cellHeight;
                            var itemRight = itemLeft + tabRoot.itemCoverWidth;
                            var itemBottom = itemTop + tabRoot.itemCoverHeight;

                            if (itemRight > selLeft && itemLeft < selRight &&
                                    itemBottom > selTop && itemTop < selBottom) {
                                var idx = filterProxyModel.index(i, 0);
                                var assetId = filterProxyModel.data(idx, CloudAlbumAssetListModel.AssetId);
                                if (assetId) {
                                    tabRoot.cloudAlbumModel.selectAsset(assetId, true);
                                }
                            }
                        }
                    }
                }

                Timer {
                    id: dragScrollTimer
                    interval: 20
                    repeat: true
                    running: false
                    property real scrollDirectionY: 0
                    property real maxContentY: 0
                    onTriggered: {
                        if (scrollDirectionY !== 0 && gridView.visible) {
                            var contentY = gridView.contentY + scrollDirectionY * 10;
                            var currentMaxY = gridView.contentHeight - gridView.height;
                            if (dragScrollTimer.maxContentY !== 0) {
                                currentMaxY = dragScrollTimer.maxContentY;
                            }
                            if (contentY < 0) {
                                contentY = 0;
                            }
                            contentY = Math.min(contentY, currentMaxY);
                            gridView.contentY = contentY;
                            if (contentY !== gridView.contentY && scrollDirectionY > 0) {
                                dragScrollTimer.maxContentY = gridView.contentY;
                            }
                        }
                    }
                }
            }

            delegate: Item {
                id: itemRoot
                width: gridView.cellWidth
                height: gridView.cellHeight

                Rectangle {
                    id: mediaCover
                    color: Colors.color_000000
                    width: itemCoverWidth
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
                                radius: cellRadius
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: Colors.color_444444

                            Image {
                                anchors.fill: parent
                                source: model.thumbnailUrl || ""
                                sourceSize: Qt.size(itemCoverWidth, itemCoverHeight)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                visible: status === Image.Ready
                            }
                        }
                    }

                    // 已下载角标（左上角，参考 CloudAlbumGridView）
                    Rectangle {
                        anchors.left: parent.left
                        anchors.leftMargin: 4
                        anchors.top: parent.top
                        anchors.topMargin: 4
                        width: 20
                        height: 20
                        color: Colors.color_000000_50
                        radius: 4
                        visible: (model.downloadState || 0) === 1

                        Image {
                            source: "qrc:/icons/media_download.svg"
                            width: 20
                            height: 20
                            anchors.centerIn: parent
                            sourceSize: Qt.size(20, 20)
                        }
                    }

                    // 素材类型图标（左下角，与 MediaSelectedPage 的 materialTypeImg 一致）
                    Image {
                        id: materialTypeImg
                        width: 16
                        height: 16
                        source: model.typeIcon || ""
                        sourceSize: Qt.size(width, height)
                        visible: source.toString().length > 0
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
                    }

                    // 时长文本（左下角，与 MediaSelectedPage 的 durationText 一致）
                    Text {
                        id: durationText
                        text: " " + formatDuration(model.duration || 0) + " "
                        color: Colors.color_EEEEEE
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        visible: (model.duration || 0) > 0
                        anchors {
                            left: materialTypeImg.visible ? materialTypeImg.right : parent.left
                            leftMargin: materialTypeImg.visible ? 2 : 4
                            verticalCenter: materialTypeImg.verticalCenter
                        }
                        renderType: CommonUtils.isWindows() ? Text.NativeRendering : Text.QtRendering
                        antialiasing: CommonUtils.isWindows() ? false : true
                        layer.enabled: true
                        layer.samples: 100
                        layer.effect: Glow {
                            color: Colors.color_000000_60
                            spread: 0.1
                            radius: 2
                        }
                        Component.onCompleted: {
                            if (CommonUtils.isWindows()) {
                                durationText.font.family = "Arial"
                            }
                        }
                    }

                    // 收藏图标（右上角，与 MediaSelectedPage 的 favoriteImg 一致）
                    // hover 时显示空心红心，已收藏时常驻显示实心红心
                    Image {
                        id: favoriteImg
                        width: 20
                        height: 20
                        source: (model.isFavorite || false)
                            ? "qrc:/app_qrc/icons/mediaimport_favorite_yes_icon.svg"
                            : "qrc:/app_qrc/icons/mediaimport_favorite_no_icon.svg"
                        sourceSize: Qt.size(width, height)
                        z: 1
                        anchors {
                            top: parent.top
                            right: parent.right
                            topMargin: 4
                            rightMargin: 4
                        }
                        visible: (model.isFavorite || false) || mouseArea.containsMouse

                        MouseArea {
                            anchors.fill: parent
                            onClicked: (mouse) => {
                                mouse.accepted = true;
                                if (tabRoot.cloudAlbumModel) {
                                    tabRoot.tabViewModel.trackCollectClick(model.assetId, 0)
                                    tabRoot.cloudAlbumModel.toggleFavorite(model.assetId);
                                }
                            }
                        }
                    }

                    // 选中边框 - 红色（云相册多选状态）
                    Rectangle {
                        anchors.fill: parent
                        radius: cellRadius
                        color: Colors.transparent
                        border.color: "#F22443"
                        border.width: 2
                        visible: model.isSelected || false
                    }

                    // 鼠标交互区域
                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        preventStealing: true
                        scrollGestureEnabled: false
                        property bool isDragAdd: false
                        property point pressedPoint: Qt.point(0, 0)
                        property bool hasLoggedMove: false
                        property bool hasShownDownloadToast: false

                        onPressedChanged: {
                            if (pressed) {
                                // 与 MediaSelectedPage 对齐：点击云相册 item 也通知轨道清空。
                                // 放 onPressedChanged 而不放 onClicked：Qt6 中定义了 onDoubleClicked
                                // 后 onClicked 会延迟且此处不稳定触发。
                                globalSignal.cleanTrackSelectState();
                            }
                            if (pressed && (mouseArea.pressedButtons & Qt.LeftButton)) {
                                pressedPoint = Qt.point(mouseX, mouseY);
                                isDragAdd = false;
                                hasLoggedMove = false;
                                hasShownDownloadToast = false;
                                logger.d("[CloudDrag] pressed, asset=" + (model.assetId || "")
                                         + " type=" + (model.fileType || "")
                                         + " downloadState=" + (model.downloadState || 0)
                                         + " selected=" + (model.isSelected || false));
                            }
                        }

                        onPositionChanged: (mouse) => {
                            if (!pressed || !(mouse.buttons & Qt.LeftButton)) {
                                return;
                            }
                            if (!hasLoggedMove) {
                                logger.d("[CloudDrag] first move, asset=" + (model.assetId || "")
                                         + " dx=" + Math.abs(pressedPoint.x - mouseX)
                                         + " dy=" + Math.abs(pressedPoint.y - mouseY)
                                         + " dragSelecting=" + tabRoot._isDragSelecting);
                                hasLoggedMove = true;
                            }
                            if (tabRoot._isDragSelecting) {
                                logger.d("[CloudDrag] blocked by drag selection, asset="
                                         + (model.assetId || ""));
                                return;
                            }

                            var dragDistance = 4;
                            if (!isDragAdd
                                    && Math.abs(pressedPoint.x - mouseX) < dragDistance
                                    && Math.abs(pressedPoint.y - mouseY) < dragDistance) {
                                return;
                            }

                            if (!isDragAdd) {
                                if ((model.downloadState || 0) !== 1) {
                                    if (!hasShownDownloadToast) {
                                        hasShownDownloadToast = true;
                                        globalSignal.toast(
                                            qsTr("pccut_cloud_album_download_before_use"),
                                            "cloudAlbum");
                                    }
                                    return;
                                }
                                if (!tabRoot.tabViewModel.canStartCloudDrag(
                                        model.assetId || "", filterProxyModel)) {
                                    return;
                                }
                            }

                            var point = mapToItem(cloudDraggableRect.parent, mouseX, mouseY);
                            var started = cloudDraggableRect.setDragPointMove(point, !isDragAdd);
                            if (started) {
                                isDragAdd = true;
                            }
                        }

                        onClicked: (mouse) => {
                            if (isDragAdd) {
                                mouse.accepted = true;
                                return;
                            }
                            if (tabRoot._isDragSelecting) {
                                return;
                            }
                            if (mouse.button === Qt.RightButton) {
                                var newPoint = mouseArea.mapToItem(tabRoot, mouse.x, mouse.y);
                                if (tabRoot.height - newPoint.y < 150) {
                                    newPoint.y = tabRoot.height - 150;
                                }
                                // 多选时右键操作所有选中项，否则只操作当前项
                                var assetIds, fileNames;
                                var isCurrentSelected = model.isSelected || false;
                                var selected = tabRoot.tabViewModel.selectedItems(filterProxyModel);
                                if (isCurrentSelected && selected.ids.length > 1) {
                                    assetIds  = selected.ids;
                                    fileNames = selected.names;
                                } else {
                                    assetIds  = [model.assetId];
                                    fileNames = [
                                        tabRoot.tabViewModel.fileNameForAssetId(model.assetId)
                                    ];
                                }
                                fileOperatePopupLoader.openPop(newPoint, assetIds, fileNames, index, model.isFavorite || false);
                                return;
                            }

                            // 左键：单选 / Ctrl切换 / Shift追加
                            if (!tabRoot.cloudAlbumModel) return;
                            var isCtrl  = mouse.modifiers & Qt.ControlModifier;
                            var isShift = mouse.modifiers & Qt.ShiftModifier;

                            if (isShift) {
                                // Shift+Click：追加选中当前 item（不清空已选）
                                tabRoot.cloudAlbumModel.selectAsset(model.assetId, true);
                                tabRoot._lastClickedIndex = index;
                            } else if (isCtrl) {
                                // Ctrl+Click：切换单项选中
                                tabRoot.cloudAlbumModel.selectAsset(model.assetId, !(model.isSelected || false));
                                tabRoot._lastClickedIndex = index;
                            } else {
                                // 普通点击：清空后仅选中当前
                                tabRoot.cloudAlbumModel.selectAll(false);
                                tabRoot.cloudAlbumModel.selectAsset(model.assetId, true);
                                tabRoot._lastClickedIndex = index;
                            }
                        }
                        onDoubleClicked: {
                            var type = parseInt(model.fileType || "0");
                            var assetId = model.assetId || "";
                            if (!assetId) return;

                            // 动图(type=3)归为图片类型，但本体是 MP4：双击走边下边播，不走图片预览。
                            if (tabRoot.tabViewModel.isImageAssetType(type) && type !== 3) {
                                tabRoot.tabViewModel.previewCloudImage(
                                    assetId, model.fileName || "", type);
                                return;
                            }
                            tabRoot.tabViewModel.previewCloudVideo(
                                assetId, type, model.downloadState || 0, model.duration || 0,
                                model.mediaType || 0);
                        }

                        onReleased: {
                            logger.d("[CloudDrag] released, asset=" + (model.assetId || "")
                                     + " isDragAdd=" + isDragAdd);
                            if (isDragAdd) {
                                var point = mapToItem(cloudDraggableRect.parent, mouseX, mouseY);
                                cloudDraggableRect.setDragPointRelease(point, false);
                                isDragAdd = false;
                            }
                        }

                        onCanceled: {
                            logger.d("[CloudDrag] canceled, asset=" + (model.assetId || "")
                                     + " isDragAdd=" + isDragAdd);
                            if (isDragAdd) {
                                var point = mapToItem(cloudDraggableRect.parent, mouseX, mouseY);
                                cloudDraggableRect.setDragPointRelease(point, true);
                                isDragAdd = false;
                            }
                        }
                    }

                    // 添加到时间轴按钮：仅在素材已下载且预热完成后显示
                    Image {
                        id: addMedia
                        width: 20
                        height: 20
                        z: 2
                        source: "qrc:/app_qrc/icons/filter_add.svg"
                        sourceSize: Qt.size(width, height)
                        visible: mouseArea.containsMouse
                                 && tabRoot.mediaListViewModel
                                 && tabRoot.tabViewModel.isCloudMediaType(model.fileType)
                                 && (model.downloadState || 0) === 1
                                 && tabRoot.mediaListViewModel.isCloudMediaPrepared(
                                     model.assetId || "")
                        anchors {
                            right: parent.right
                            bottom: parent.bottom
                            rightMargin: 4
                            bottomMargin: 4
                        }

                        MouseArea {
                            id: addMouseArea
                            anchors.fill: parent
                            onClicked: (mouse) => {
                                mouse.accepted = true;
                                tabRoot.mediaListViewModel.mediaClickAdd(model.assetId || "");
                            }

                            LightToolTip {
                                visible: addMouseArea.containsMouse
                                tip: qsTr("pccut_track_add")
                            }
                        }
                    }
                }

                // 文件名（封面下方，与 MediaSelectedPage 一致）
                Text {
                    text: model.fileName || ""
                    anchors {
                        left: mediaCover.left
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

        DropArea {
            enabled: tabRoot.isLoggedIn && lightWindow.topPopupCount <= 0
            anchors.fill: parent
            z: Number.MAX_SAFE_INTEGER

            onEntered: (drag) => {
                const allInvalid = fileOperator.isAllFilesInvalid(drag.urls)
                const hasFolder = fileOperator.hasAnyFolder(drag.urls)
                if (allInvalid && !hasFolder) {
                    drag.accepted = false
                }
            }

            onDropped: (drop) => {
                drop.accept();
                if (drop.hasUrls) {
                    tabRoot.tabViewModel.uploadUrls(drop.urls, 1);
                }
            }
        }

        // 右键菜单（与 CloudAlbumGridView 一致）
        Loader {
            id: fileOperatePopupLoader
            active: false
            function openPop(showPoint, assetIds, fileNames, fileIndex, isFavorite) {
                active = true;
                var popup = fileOperatePopupLoader.item;
                popup.x = showPoint.x;
                popup.y = showPoint.y;
                popup.fileIds   = assetIds;
                popup.fileNames = fileNames;

                var operateModels = popup.listModel;
                operateModels.clear();
                // 导出为视频文件 — 暂时屏蔽，后期可能再上
                // operateModels.append({"title": qsTr("pccut_home_highlight_export_tab"), "type": 0});
                operateModels.append({"title": qsTr("pccut_home_original_download"),    "type": 1});
                operateModels.append({"title": isFavorite ? qsTr("pccut_media_unfavorite") : qsTr("pccut_media_favorite"), "type": 2});
                operateModels.append({"title": qsTr("pccut_device_batch_delete"),        "type": 3});

                popup.open();
            }

            sourceComponent: Component {
                OperatePopup {
                    property var fileIds: []
                    property var fileNames: []
                    shaderSourceItem: tabRoot

                    onClosed: {
                        fileOperatePopupLoader.active = false;
                    }
                    onClickType: (actionType) => {
                        background.visible = false;
                        contentItem.visible = false;
                        if (actionType === 3) {
                            tabRoot.showDeletePopup(fileIds, 1)
                        } else if (actionType === 2) {
                            // 收藏/取消收藏（支持批量）
                            if (tabRoot.cloudAlbumModel) {
                                for (var i = 0; i < fileIds.length; i++) {
                                    tabRoot.tabViewModel.trackCollectClick(fileIds[i], 1)
                                    tabRoot.cloudAlbumModel.toggleFavorite(fileIds[i]);
                                }
                            }
                        } else if (actionType === 1) {
                            // 下载原片（支持批量）
                            tabRoot.tabViewModel.startDownload(fileIds, fileNames, 1);
                        }
                    }
                }
            }
        }
    }

    Connections {
        target: CloudAlbumTransferModel
        function onDownloadDiskSpaceInsufficient() {
            if (tabRoot.visible && !downloadDiskSpacePopup.opened) {
                downloadDiskSpacePopup.open()
            }
        }
    }

    ConfirmPopup {
        id: downloadDiskSpacePopup
        objectName: 'explorerCloudAlbumDownloadDiskSpacePopup'
        parent: Overlay.overlay
        onlyOneBtn: true
        title: qsTr('pccut_cloud_album_err_disk_full')
        text: qsTr('pccut_device_batch_download_low_storage')
        leftButtonText: qsTr('pccut_common_text_got_it')
    }

    ConfirmPopup {
        id: cloudAlbumDeletePopup
        objectName: "cloudAlbumDeletePopup"
        parent: Overlay.overlay

        title: qsTr("pccut_cloud_album_recycle_move_confirm_title")
        text: qsTr("pccut_cloud_album_recycle_move_confirm").arg(_deleteFileIds.length)
        leftButtonText: qsTr("pccut_device_batch_delete_all_cancel")
        rightButtonText: qsTr("pccut_device_batch_delete_all_yes")
        leftButtonObjectName: "cloudAlbumDeleteCancelBtn"
        rightButtonObjectName: "cloudAlbumDeleteConfirmBtn"

        property var _deleteFileIds: []

        function showPop(fileIds) {
            _deleteFileIds = fileIds;
            open();
        }

        onLeftButtonClicked: {
            tabRoot.tabViewModel.trackDeleteConfirm(false, _deleteFileIds)
        }

        onRightButtonClicked: {
            if (tabRoot.cloudAlbumModel) {
                tabRoot.tabViewModel.trackDeleteConfirm(true, _deleteFileIds)
                tabRoot.cloudAlbumModel.deleteAssets(_deleteFileIds);
            }
        }
    }

    CloudAlbumNotLoginView {
        anchors.fill: parent
        visible: !tabRoot.isLoggedIn
        panelWidth: 292
        panelHeight: 379
        centerPanel: true
        imageWidth: 236
        imageHeight: 132
        titleTopMargin: 14
        descTopMargin: 8
        buttonTopMargin: 12
        titleFontSize: 12
        titleLineHeight: 16
        descFontSize: 11
        descLineHeight: 15
        buttonWidth: 88
        buttonHeight: 28
        buttonFontSize: 12
        onLoginClicked: {
            userLoginViewModel.showLoginPopup()
        }
    }

    // 工具函数：格式化时长（与 MediaSelectedPage 一致，使用 MM:SS 格式）
    function formatDuration(seconds) {
        if (seconds <= 0) return ""
        var m = Math.floor(seconds / 60)
        var s = Math.floor(seconds % 60)
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
    }
}
