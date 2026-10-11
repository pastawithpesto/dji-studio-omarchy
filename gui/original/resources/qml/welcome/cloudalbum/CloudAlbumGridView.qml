import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Controls 1.0
import Config 1.0
import app_qrc 1.0
import CloudAlbumAssetListModel 1.0

/**
 * 云相册内容视图（支持网格 / 列表两种模式）
 * 参考 DevicePanel.qml 的 listSuperView 网格布局模式
 */
Item {
    id: root

    // ===== 视图模式 =====
    property bool isListMode: false

    // ===== 网格配置 =====
    property int itemWidth: 177
    property int itemHeight: 100
    property int itemSpacing: 24
    property int columns: Math.max(1, Math.floor((width - leftPadding - rightPadding + itemSpacing) / (itemWidth + itemSpacing)))
    property int leftPadding: 0
    property int rightPadding: 0
    property int gridRightPadding: rightPadding  // 网格模式可单独设置右边距

    // ===== 列表模式配置 =====
    property int listItemHeight: 48
    property int listThumbnailWidth: 85
    property int listThumbnailHeight: 48

    // 列表模式列宽比例（名称列自动填充剩余空间）
    property int listColType: 126
    property int listColDuration: 114
    property int listColSize: 123
    property int listColDate: 104
    readonly property int listHeaderFontSize: 12
    readonly property color listHeaderTextColor: Colors.color_666666

    // 外部数据模型
    property var model: null
    property var sourceModel: null  // 原始模型（用于选中等操作）
    property bool showSelectState: false
    property string previewingAssetId: ""  // 正在预览下载的 assetId，用于在缩略图上显示 loading
    property bool interactionsEnabled: true

    signal itemClicked(int index, var modelData)
    signal itemDoubleClicked(int index, var modelData)
    signal selectionToggled(int index, var modelData, bool selected)
    signal selectionChanged()
    signal fileDragEntered()
    signal fileDragExited()
    signal filesDropped(var urls)
    signal menuActionClicked(int actionType, string fileId, int fileIndex, string filePath,
                             int useMethod)
    signal requestShowSelectState()

    // 滚动到指定文件名的素材，使其顶部对齐视图顶部
    function scrollToFileName(fileName) {
        if (!root.model) return false;
        for (var i = 0; i < root.model.rowCount(); i++) {
            var idx = root.model.index(i, 0);
            var name = root.model.data(idx, CloudAlbumAssetListModel.FileName);
            if (name === fileName) {
                if (isListMode) {
                    activeListView.positionViewAtIndex(i, ListView.Beginning);
                } else {
                    activeListView.positionViewAtIndex(i, GridView.Beginning);
                }
                return true;
            }
        }
        return false;
    }

    // 画框多选
    readonly property var activeListView: isListMode ? listView : gridListView
    property alias isDragSelecting: dragSelectMouseArea.isShowRect
    property var _refreshListView: null
    property real _refreshContentY: 0
    property bool _hasPendingRefreshContentY: false
    property bool _autoFillRequestPending: false
    property int _autoFillRequestCount: -1

    function saveRefreshContentY() {
        var listView = root.activeListView;
        if (!listView) {
            return;
        }
        root._refreshListView = listView;
        root._refreshContentY = listView.contentY;
        root._hasPendingRefreshContentY = true;
    }

    function restoreRefreshContentY() {
        if (!root._hasPendingRefreshContentY || !root._refreshListView) {
            return;
        }

        var listView = root._refreshListView;
        listView.forceLayout();
        var maxContentY = Math.max(listView.originY,
                                   listView.contentHeight - listView.height + listView.originY);
        if (root._refreshContentY > maxContentY + 0.5) {
            if (root.sourceModel
                    && !root.sourceModel.isLoading
                    && !root.sourceModel.isEnd) {
                root.sourceModel.fetchNextPage();
            } else if (root.sourceModel
                       && !root.sourceModel.isLoading
                       && root.sourceModel.isEnd) {
                root._hasPendingRefreshContentY = false;
                root._refreshListView = null;
            }
            return;
        }

        listView.contentY = Math.max(listView.originY, root._refreshContentY);
        if (Math.abs(listView.contentY - root._refreshContentY) <= 0.5) {
            root._hasPendingRefreshContentY = false;
            root._refreshListView = null;
        }
    }

    function requestNextPageForAutoFill() {
        if (!root.activeListView
                || !root.sourceModel
                || root.sourceModel.isLoading
                || root.sourceModel.isEnd
                || root._autoFillRequestPending) {
            return;
        }

        var currentCount = Number(root.sourceModel.count);
        if (!isFinite(currentCount)) {
            currentCount = root.activeListView.count;
        }
        root._autoFillRequestCount = currentCount;
        root._autoFillRequestPending = true;
        root.sourceModel.fetchNextPage();
    }

    function ensureActiveListViewScrollable() {
        var listView = root.activeListView;
        if (!listView || !root.sourceModel
                || root.sourceModel.isLoading || root.sourceModel.isEnd
                || root._autoFillRequestPending) {
            return;
        }

        listView.forceLayout();
        if (listView.contentHeight <= listView.height + 0.5) {
            root.requestNextPageForAutoFill();
        }
    }

    function onAutoFillLoadingFinished() {
        if (!root.sourceModel || root.sourceModel.isLoading) {
            return;
        }

        if (root._autoFillRequestPending) {
            var currentCount = Number(root.sourceModel.count);
            var hasProgress = root.sourceModel.isEnd
                    || (isFinite(currentCount) && currentCount > root._autoFillRequestCount);
            root._autoFillRequestPending = false;
            if (!hasProgress) {
                return;
            }
        }

        Qt.callLater(root.ensureActiveListViewScrollable);
    }

    Connections {
        target: root.sourceModel
        ignoreUnknownSignals: true

        function onRefreshRequested() {
            root._autoFillRequestPending = false;
            root.saveRefreshContentY();
        }

        function onLoadingChanged() {
            if (!root.sourceModel || !root.sourceModel.isLoading) {
                root.onAutoFillLoadingFinished();
                Qt.callLater(root.restoreRefreshContentY);
            }
        }
    }

    Connections {
        target: root.activeListView
        ignoreUnknownSignals: true

        function onContentHeightChanged() {
            Qt.callLater(root.restoreRefreshContentY);
            Qt.callLater(root.ensureActiveListViewScrollable);
        }
    }

    // 右键菜单操作类型
    enum MenuAction {
        ExportVideo,
        DownloadOriginal,
        ToggleFavorite,
        Delete
    }

    clip: true

    // 点击空白区域取消选择
    MouseArea {
        id: emptyAreaMouseArea
        anchors.fill: parent
        enabled: root.interactionsEnabled
        onClicked: {
            if (root.isDragSelecting) {
                return;
            }
            if (root.sourceModel) {
                root.sourceModel.selectAll(false);
                root.selectionChanged();
            }
        }
    }

    // ========== 网格模式 ==========
    GridView {
        id: gridListView
        objectName: "cloudAlbumGridListView"
        anchors.fill: parent
        leftMargin: root.leftPadding
        rightMargin: root.gridRightPadding
        boundsBehavior: Flickable.StopAtBounds
        interactive: root.interactionsEnabled && !bgSelectionRect.visible
        visible: !root.isListMode

        cellWidth: root.itemWidth + root.itemSpacing
        cellHeight: root.itemHeight + root.itemSpacing

        ScrollBar.vertical: ScrollBar {
            rightPadding: 6
            Component.onCompleted: {
                contentItem.color = Colors.color_444444
            }
        }

        footer: Item {
            width: 1
            height: gridListView.cellHeight
        }

        model: root.model

        onAtYEndChanged: {
            if (atYEnd) {
                root.requestNextPageForAutoFill();
            }
        }

        onWidthChanged: Qt.callLater(root.ensureActiveListViewScrollable)
        onHeightChanged: Qt.callLater(root.ensureActiveListViewScrollable)
        onVisibleChanged: {
            if (visible) {
                Qt.callLater(root.ensureActiveListViewScrollable);
            }
        }

        delegate: Item {
            id: delegateRoot
            objectName: "cloudAlbumAssetDelegate_" + index
            width: root.itemWidth
            height: root.itemHeight
            readonly property bool hasThumbnailImage:
                thumbnailImage.status === Image.Ready
                && thumbnailImage.paintedWidth > 0
                && thumbnailImage.paintedHeight > 0
            readonly property bool isThumbnailTranscoding: !hasThumbnailImage

            // 缩略图容器（圆角裁剪）
            LightClipRectangle {
                id: thumbnailClip
                objectName: "cloudAlbumAssetThumbnail_" + index
                anchors.fill: parent
                radius: [6, 6, 6, 6]
                color: Colors.color_444444
                clip: true

                // 缩略图
                Image {
                    id: thumbnailImage
                    objectName: "cloudAlbumAssetThumbnailImage_" + index
                    anchors.fill: parent
                    source: root.isListMode ? "" : (model.thumbnailUrl || "")
                    sourceSize: Qt.size(root.itemWidth, root.itemHeight)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: delegateRoot.hasThumbnailImage
                }

                // hover 边框
                Rectangle {
                    anchors.fill: parent
                    radius: 6
                    color: Colors.transparent
                    border.color: Colors.color_FFFFFF_30
                    border.width: 2
                    visible: root.interactionsEnabled && itemMouseArea.containsMouse
                }

                // 预览下载 loading
                Rectangle {
                    anchors.fill: parent
                    radius: 6
                    color: Colors.color_000000_50
                    visible: root.previewingAssetId === (model.assetId || "")
                             && root.previewingAssetId.length > 0

                    BusyIndicator {
                        anchors.centerIn: parent
                        width: 24
                        height: 24
                        running: parent.visible
                    }
                }
            }

            // 已下载角标（左上角）
            Rectangle {
                id: downloadBadge
                objectName: "cloudAlbumAssetDownloadBadge_" + index
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.top: parent.top
                anchors.topMargin: 8
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
                LightToolTip {
                    visible: root.interactionsEnabled && downloadBadgeHover.containsMouse
                    tip: qsTr("pccut_cloud_album_badge_downloaded")
                }
                MouseArea {
                    id: downloadBadgeHover
                    anchors.fill: parent
                    enabled: root.interactionsEnabled
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                }
            }

            // 右上角操作区：多选框贴右，收藏按钮在多选框出现时自动排到左侧
            Row {
                anchors.top: thumbnailClip.top
                anchors.right: thumbnailClip.right
                anchors.topMargin: 6
                anchors.rightMargin: root.showSelectState ? 8 : 6
                spacing: 4
                layoutDirection: Qt.RightToLeft
                z: 1
                height: 20

                // 选择图标（右上角）
                Image {
                    id: selectIcon
                    objectName: "cloudAlbumAssetSelectIcon_" + index
                    width: 20
                    height: 20
                    source: (model.isSelected || false)
                            ? "qrc:/app_qrc/icons/media_selected.svg"
                            : "qrc:/icons/media_normal.svg"
                    visible: root.showSelectState
                }

                // 收藏角标：已收藏时常驻显示实心星；悬停时显示空心星；点击触发收藏切换
                Image {
                    id: favoriteIcon
                    width: 20
                    height: 20
                    visible: !root.showSelectState
                             && ((model.isFavorite || false)
                                 || (root.interactionsEnabled && itemMouseArea.containsMouse))
                    source: (model.isFavorite || false)
                            ? "qrc:/app_qrc/icons/mediaimport_favorite_yes_icon.svg"
                            : "qrc:/app_qrc/icons/mediaimport_favorite_no_icon.svg"
                    sourceSize: Qt.size(20, 20)

                    MouseArea {
                        objectName: "cloudAlbumAssetFavoriteBtn_" + index
                        anchors.fill: parent
                        enabled: root.interactionsEnabled
                        onClicked: (mouse) => {
                            mouse.accepted = true
                            root.menuActionClicked(
                                CloudAlbumGridView.MenuAction.ToggleFavorite,
                                model.assetId,
                                index,
                                "",
                                0
                            )
                        }
                    }
                }
            }

            // 左下角状态：缩略图未就绪时显示转码中，否则显示类型图标和时长
            Row {
                id: transcodingStatus
                objectName: "cloudAlbumAssetTranscodingStatus_" + index
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 6
                spacing: 2
                visible: delegateRoot.isThumbnailTranscoding

                Image {
                    width: 16
                    height: 16
                    anchors.verticalCenter: parent.verticalCenter
                    source: "qrc:/icons/icon_loading.png"
                    sourceSize: Qt.size(48, 48)
                    smooth: true
                    mipmap: true

                    RotationAnimation on rotation {
                        from: 0
                        to: 360
                        running: transcodingStatus.visible
                        duration: 2000
                        loops: Animation.Infinite
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("pccut_cloud_album_thumbnail_transcoding")
                    font.pixelSize: 12
                    color: Colors.color_FFFFFF
                }
            }

            // 类型图标（左下角）
            Image {
                id: typeIcon
                objectName: "cloudAlbumAssetTypeIcon_" + index
                source: model.typeIcon || ""
                visible: !delegateRoot.isThumbnailTranscoding && source.toString().length > 0
                width: 16
                height: 16
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 6
                sourceSize: Qt.size(32, 32)
                fillMode: Image.PreserveAspectFit
            }

            // 时长标签（左下角，紧跟类型图标）
            Text {
                id: durationText
                objectName: "cloudAlbumAssetDuration_" + index
                anchors.left: typeIcon.visible ? typeIcon.right : parent.left
                anchors.leftMargin: typeIcon.visible ? 4 : 8
                anchors.verticalCenter: typeIcon.verticalCenter
                visible: !delegateRoot.isThumbnailTranscoding && (model.durationMs || model.duration || 0) > 0
                text: formatDuration(model.durationMs || ((model.duration || 0) * 1000))
                font.pixelSize: 10
                color: Colors.color_FFFFFF
            }

            // 文件名 tooltip
            LightToolTip {
                visible: root.interactionsEnabled && itemMouseArea.containsMouse
                tip: model.fileName || ""
                z: 200
            }

            // 交互区域
            MouseArea {
                id: itemMouseArea
                objectName: "cloudAlbumAssetClickArea_" + index
                anchors.fill: parent
                enabled: root.interactionsEnabled
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: (mouse) => {
                    if (mouse.button === Qt.RightButton) {
                        // 多选状态不响应右键
                        if (root.showSelectState) {
                            return;
                        }
                        var newPoint = itemMouseArea.mapToItem(root, mouse.x, mouse.y);
                        if (root.height - newPoint.y < 150) {
                            newPoint.y = root.height - 150;
                        }
                        fileOperatePopupLoader.openPop(newPoint, model.assetId, index, "", model.isFavorite || false);
                        return;
                    }
                    if (root.showSelectState) {
                        if (root.isDragSelecting) {
                            return;
                        }
                        root.sourceModel.selectAsset(model.assetId, !(model.isSelected || false));
                        root.selectionChanged();
                    } else {
                        root.itemClicked(index, model)
                    }
                }
                onDoubleClicked: {
                    root.itemDoubleClicked(index, model)
                }
            }
        }
    }

    // ========== 列表模式 ==========
    ListView {
        id: listView
        objectName: "cloudAlbumListView"
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        leftMargin: root.leftPadding
        rightMargin: root.rightPadding
        boundsBehavior: Flickable.StopAtBounds
        interactive: root.interactionsEnabled && !bgSelectionRect.visible
        visible: root.isListMode
        spacing: 24

        ScrollBar.vertical: ScrollBar {
            rightPadding: 6
            Component.onCompleted: {
                contentItem.color = Colors.color_444444
            }
        }

        header: Item {
            width: listView.width - listView.leftMargin - listView.rightMargin
            height: listView.count > 0 ? 40 : 0  // 16(标题行) + 24(与首条 delegate 的间距)

            RowLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 16
                spacing: 0
                visible: listView.count > 0

                // 名称列（缩略图+文件名）
                Text {
                    Layout.fillWidth: true
                    text: qsTr("pccut_cloud_album_col_name")
                    font.pixelSize: root.listHeaderFontSize
                    color: root.listHeaderTextColor
                }

                // 类型列
                Text {
                    Layout.preferredWidth: root.listColType
                    text: qsTr("pccut_cloud_album_col_type")
                    font.pixelSize: root.listHeaderFontSize
                    color: root.listHeaderTextColor
                    horizontalAlignment: Text.AlignLeft
                }

                // 时长列
                Text {
                    Layout.preferredWidth: root.listColDuration
                    text: qsTr("pccut_cloud_album_col_duration")
                    font.pixelSize: root.listHeaderFontSize
                    color: root.listHeaderTextColor
                    horizontalAlignment: Text.AlignLeft
                }

                // 大小列
                Text {
                    Layout.preferredWidth: root.listColSize
                    text: qsTr("pccut_cloud_album_col_size")
                    font.pixelSize: root.listHeaderFontSize
                    color: root.listHeaderTextColor
                    horizontalAlignment: Text.AlignLeft
                }

                // 最后修改时间列
                Text {
                    Layout.preferredWidth: root.listColDate
                    text: qsTr("pccut_cloud_album_col_modified")
                    font.pixelSize: root.listHeaderFontSize
                    color: root.listHeaderTextColor
                    horizontalAlignment: Text.AlignLeft
                }
            }
        }
        headerPositioning: ListView.InlineHeader

        footer: Item {
            width: 1
            height: root.listItemHeight
        }

        model: root.model

        onAtYEndChanged: {
            if (atYEnd) {
                root.requestNextPageForAutoFill();
            }
        }

        onWidthChanged: Qt.callLater(root.ensureActiveListViewScrollable)
        onHeightChanged: Qt.callLater(root.ensureActiveListViewScrollable)
        onVisibleChanged: {
            if (visible) {
                Qt.callLater(root.ensureActiveListViewScrollable);
            }
        }

        delegate: Item {
            id: listDelegateRoot
            objectName: "cloudAlbumAssetListDelegate_" + index
            width: listView.width - listView.leftMargin - listView.rightMargin
            height: root.listItemHeight
            readonly property bool hasThumbnailImage:
                listThumbnailImage.status === Image.Ready
                && listThumbnailImage.paintedWidth > 0
                && listThumbnailImage.paintedHeight > 0
            readonly property bool isThumbnailTranscoding: !hasThumbnailImage

            // 去掉整行 hover 背景

            // 交互区域（先声明使其 z 低于 RowLayout，收藏图标的 MouseArea 才能优先截获点击）
            MouseArea {
                id: listItemMouseArea
                objectName: "cloudAlbumAssetListClickArea_" + index
                anchors.fill: parent
                enabled: root.interactionsEnabled
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: (mouse) => {
                    if (mouse.button === Qt.RightButton) {
                        if (root.showSelectState) {
                            return;
                        }
                        var newPoint = listItemMouseArea.mapToItem(root, mouse.x, mouse.y);
                        if (root.height - newPoint.y < 150) {
                            newPoint.y = root.height - 150;
                        }
                        fileOperatePopupLoader.openPop(newPoint, model.assetId, index, "", model.isFavorite || false);
                        return;
                    }
                    if (root.showSelectState) {
                        if (root.isDragSelecting) {
                            return;
                        }
                        root.sourceModel.selectAsset(model.assetId, !(model.isSelected || false));
                        root.selectionChanged();
                    } else {
                        root.itemClicked(index, model)
                    }
                }
                onDoubleClicked: {
                    root.itemDoubleClicked(index, model)
                }
            }

            RowLayout {
                anchors.fill: parent
                spacing: 0

                // 名称列：缩略图 + 文件名
                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 24

                    // 选择图标（列表模式）
                    Image {
                        objectName: "cloudAlbumAssetListSelectIcon_" + index
                        Layout.preferredWidth: 16
                        Layout.preferredHeight: 16
                        Layout.alignment: Qt.AlignVCenter
                        source: (model.isSelected || false)
                                ? "qrc:/app_qrc/icons/media_selected.svg"
                                : "qrc:/icons/media_normal.svg"
                        visible: root.showSelectState
                    }

                    // 缩略图
                    LightClipRectangle {
                        objectName: "cloudAlbumAssetListThumbnail_" + index
                        Layout.preferredWidth: root.listThumbnailWidth
                        Layout.preferredHeight: root.listThumbnailHeight
                        Layout.alignment: Qt.AlignVCenter
                        radius: [4, 4, 4, 4]
                        color: Colors.color_444444
                        clip: true

                        Image {
                            id: listThumbnailImage
                            objectName: "cloudAlbumAssetListThumbnailImage_" + index
                            anchors.fill: parent
                            source: root.isListMode ? (model.thumbnailUrl || "") : ""
                            sourceSize: Qt.size(root.listThumbnailWidth, root.listThumbnailHeight)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            visible: listDelegateRoot.hasThumbnailImage
                        }

                        Row {
                            objectName: "cloudAlbumAssetListTranscodingStatus_" + index
                            anchors.centerIn: parent
                            spacing: 4
                            visible: listDelegateRoot.isThumbnailTranscoding

                            BusyIndicator {
                                width: 14
                                height: 14
                                running: parent.visible
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: root.listThumbnailWidth - 22
                                text: qsTr("pccut_cloud_album_thumbnail_transcoding")
                                font.pixelSize: 12
                                color: Colors.color_FFFFFF
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }
                        }

                        // 已下载角标（左上角）
                        Rectangle {
                            objectName: "cloudAlbumAssetListDownloadBadge_" + index
                            anchors.left: parent.left
                            anchors.leftMargin: 4
                            anchors.top: parent.top
                            anchors.topMargin: 4
                            width: 16
                            height: 16
                            color: Colors.color_000000_50
                            radius: 3
                            visible: (model.downloadState || 0) === 1
                            Image {
                                source: "qrc:/icons/media_download.svg"
                                width: 16
                                height: 16
                                anchors.centerIn: parent
                                sourceSize: Qt.size(16, 16)
                            }
                            LightToolTip {
                                visible: root.interactionsEnabled && listDownloadBadgeHover.containsMouse
                                tip: qsTr("pccut_cloud_album_badge_downloaded")
                            }
                            MouseArea {
                                id: listDownloadBadgeHover
                                anchors.fill: parent
                                enabled: root.interactionsEnabled
                                hoverEnabled: true
                                acceptedButtons: Qt.NoButton
                            }
                        }

                        // 收藏角标（右上角）
                        // 已收藏时常驻显示实心星；悬停时显示空心星；点击触发收藏切换
                        Image {
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.topMargin: 2
                            anchors.rightMargin: 2
                            width: 16
                            height: 16
                            z: 1
                            visible: (model.isFavorite || false) || (root.interactionsEnabled && listItemMouseArea.containsMouse)
                            source: (model.isFavorite || false)
                                    ? "qrc:/app_qrc/icons/mediaimport_favorite_yes_icon.svg"
                                    : "qrc:/app_qrc/icons/mediaimport_favorite_no_icon.svg"
                            sourceSize: Qt.size(16, 16)
                            MouseArea {
                                objectName: "cloudAlbumAssetListFavoriteBtn_" + index
                                anchors.fill: parent
                                enabled: root.interactionsEnabled
                                onClicked: (mouse) => {
                                    mouse.accepted = true
                                    root.menuActionClicked(
                                        CloudAlbumGridView.MenuAction.ToggleFavorite,
                                        model.assetId,
                                        index,
                                        "",
                                        0
                                    )
                                }
                            }
                        }

                        // hover 边框
                        Rectangle {
                            anchors.fill: parent
                            radius: 4
                            color: Colors.transparent
                            border.color: Colors.color_FFFFFF_30
                            border.width: 2
                            visible: root.interactionsEnabled && listItemMouseArea.containsMouse
                        }

                        // 预览下载 loading
                        Rectangle {
                            anchors.fill: parent
                            radius: 4
                            color: Colors.color_000000_50
                            visible: root.previewingAssetId === (model.assetId || "")
                                     && root.previewingAssetId.length > 0

                            BusyIndicator {
                                anchors.centerIn: parent
                                width: 20
                                height: 20
                                running: parent.visible
                            }
                        }
                    }

                    // 文件名
                    Text {
                        id: listFileNameText
                        objectName: "cloudAlbumAssetListFileName_" + index
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        text: model.fileName || ""
                        font.pixelSize: 12
                        color: Colors.color_999999
                        elide: Text.ElideMiddle
                        maximumLineCount: 1
                    }

                    // 文件名 tooltip
                    LightToolTip {
                        visible: root.interactionsEnabled
                                 && listItemMouseArea.containsMouse
                                 && listFileNameText.truncated
                        tip: model.fileName || ""
                        z: 200
                    }
                }

                // 类型列
                Text {
                    objectName: "cloudAlbumAssetListType_" + index
                    Layout.preferredWidth: root.listColType
                    Layout.alignment: Qt.AlignVCenter
                    text: getMediaTypeText(model)
                    font.pixelSize: 12
                    color: Colors.color_999999
                    horizontalAlignment: Text.AlignLeft
                }

                // 时长列
                Text {
                    objectName: "cloudAlbumAssetListDuration_" + index
                    Layout.preferredWidth: root.listColDuration
                    Layout.alignment: Qt.AlignVCenter
                    text: formatDuration(model.durationMs || ((model.duration || 0) * 1000))
                    font.pixelSize: 12
                    color: Colors.color_999999
                    horizontalAlignment: Text.AlignLeft
                }

                // 大小列
                Text {
                    objectName: "cloudAlbumAssetListSize_" + index
                    Layout.preferredWidth: root.listColSize
                    Layout.alignment: Qt.AlignVCenter
                    text: model.fileSize > 0
                        ? CommonUtils.getFileSizeInfo(model.fileSize)
                        : ""
                    font.pixelSize: 12
                    color: Colors.color_999999
                    horizontalAlignment: Text.AlignLeft
                }

                // 最后修改时间列
                Text {
                    objectName: "cloudAlbumAssetListDate_" + index
                    Layout.preferredWidth: root.listColDate
                    Layout.alignment: Qt.AlignVCenter
                    text: formatTimestamp(model.createTime || 0)
                    font.pixelSize: 12
                    color: Colors.color_999999
                    horizontalAlignment: Text.AlignLeft
                }
            }
        }
    }

    // ========== 画框多选（parent 动态绑定到 activeListView，和 DevicePanel 一致）==========
    MouseArea {
        id: dragSelectMouseArea
        anchors.fill: parent
        anchors.rightMargin: 14 // 滚动条宽度(8) + rightPadding(6)
        parent: root.activeListView
        enabled: root.interactionsEnabled
        acceptedButtons: Qt.LeftButton
        z: Number.MAX_SAFE_INTEGER
        propagateComposedEvents: true
        preventStealing: true
        property real startX: 0
        property real startY: 0
        property real startContentY: 0
        property real currentX: 0
        property real currentY: 0
        property bool isShowRect: false

        onClicked: (mouse) => {
            mouse.accepted = false;
        }

        onPressedChanged: {
            if (pressed) {
                root.activeListView.forceLayout();
                dragSelectMouseArea.isShowRect = false;
            } else {
                // 用 Qt.callLater 延迟清除 isShowRect，确保本轮事件循环中
                // onClicked 传播到 item 时仍能看到 isDragSelecting=true，
                // 避免 itemMouseArea.onClicked 反向切换刚框选好的素材
                Qt.callLater(function() { dragSelectMouseArea.isShowRect = false; });
                dragScrollTimer.stop();
            }
        }

        onPressed: (mouse) => {
            if (pressed) {
                var lv = root.activeListView;
                let point = mapToItem(lv, Qt.point(mouse.x, mouse.y));
                startX = point.x - lv.leftMargin;
                startY = point.y;
                currentX = startX;
                currentY = startY;
                startContentY = lv.contentY;
                dragScrollTimer.scrollDirectionY = 0;
                dragScrollTimer.maxContentY = 0;
                dragScrollTimer.start();
            }
        }

        onPositionChanged: (mouse) => {
            if (mouse.buttons === Qt.LeftButton) {
                var lv = root.activeListView;
                let point = mapToItem(lv, Qt.point(mouse.x, mouse.y));
                currentX = point.x - lv.leftMargin;
                currentY = point.y;
                let edge = 30;
                let distance = 5;
                var speed = 0;
                if (point.y < edge) {
                    speed = (point.y - edge) / (edge * 2);
                } else if (lv.height - edge < point.y) {
                    speed = (point.y + edge - lv.height) / (edge * 2);
                }
                speed = speed * distance;
                dragScrollTimer.scrollDirectionY = speed;
            }
        }

        onCanceled: {
            dragScrollTimer.stop();
        }

        onReleased: {
            dragScrollTimer.stop();
        }

        Rectangle {
            id: bgSelectionRect
            parent: root.activeListView.contentItem
            color: Colors.color_FFFFFF_10
            radius: 2
            border.width: 1
            border.color: Colors.color_FFFFFF_20
            z: Number.MAX_SAFE_INTEGER
            visible: dragSelectMouseArea.pressed
            x: Math.min(dragSelectMouseArea.startX, dragSelectMouseArea.currentX)
            width: Math.abs(dragSelectMouseArea.startX - dragSelectMouseArea.currentX)
            y: Math.min(dragSelectMouseArea.startY + dragSelectMouseArea.startContentY,
                        dragSelectMouseArea.currentY + root.activeListView.contentY)
            height: Math.abs(dragSelectMouseArea.startY + dragSelectMouseArea.startContentY
                             - dragSelectMouseArea.currentY - root.activeListView.contentY)

            onWidthChanged: refreshDragSelect()
            onHeightChanged: refreshDragSelect()

            function refreshDragSelect() {
                if (!bgSelectionRect.visible || !dragSelectMouseArea.pressed) {
                    return;
                }
                if (!root.model || !root.sourceModel) {
                    return;
                }
                if (bgSelectionRect.width < 2 || bgSelectionRect.height < 2) {
                    return;
                }
                if (!root.showSelectState) {
                    root.requestShowSelectState();
                }
                dragSelectMouseArea.isShowRect = true;

                // 先清空选中状态，再重新选中矩形范围内的条目
                root.sourceModel.selectAll(false);

                var lv = root.activeListView;
                var selLeft = bgSelectionRect.x;
                var selTop = bgSelectionRect.y;
                var selRight = selLeft + bgSelectionRect.width;
                var selBottom = selTop + bgSelectionRect.height;

                var totalCount = lv.count;

                if (root.isListMode) {
                    var rowH = root.listItemHeight;
                    var spacing = listView.spacing;
                    var stride = rowH + spacing;   // 每条 item 实际占用高度（含间距）
                    var headerH = listView.headerItem ? listView.headerItem.height : 0;
                    var listSelTop = selTop - listView.originY - headerH;
                    var listSelBottom = selBottom - listView.originY - headerH;
                    var idxStart = Math.max(0, Math.floor(listSelTop / stride));
                    var idxEnd = Math.min(totalCount - 1, Math.floor(listSelBottom / stride));
                    for (var i = idxStart; i <= idxEnd; i++) {
                        var itemTop = i * stride;
                        var itemBottom = itemTop + rowH;
                        if (listSelTop < itemBottom && listSelBottom > itemTop) {
                            var assetId = root.model.data(root.model.index(i, 0), CloudAlbumAssetListModel.AssetId);
                            if (assetId) {
                                root.sourceModel.selectAsset(assetId, true);
                            }
                        }
                    }
                } else {
                    // GridView：按网格坐标数学计算，遍历所有 item（含视口外），不依赖 indexAt
                    var cw = gridListView.cellWidth;
                    var ch = gridListView.cellHeight;
                    var colCount = root.columns;

                    for (var i = 0; i < totalCount; i++) {
                        var col = i % colCount;
                        var row = Math.floor(i / colCount);
                        var itemLeft = col * cw;
                        var itemTop  = row * ch;
                        var itemRight  = itemLeft + cw;
                        var itemBottom = itemTop  + ch;

                        if (itemRight > selLeft && itemLeft < selRight &&
                                itemBottom > selTop && itemTop < selBottom) {
                            var aid = root.model.data(root.model.index(i, 0), CloudAlbumAssetListModel.AssetId);
                            if (aid) {
                                root.sourceModel.selectAsset(aid, true);
                            }
                        }
                    }
                }
                root.selectionChanged();
            }
        }

        Timer {
            id: dragScrollTimer
            interval: 20
            repeat: true
            running: false
            property int scrollDirectionY: 0
            property int maxContentY: 0
            onTriggered: {
                var lv = root.activeListView;
                if (scrollDirectionY !== 0 && lv.visible) {
                    var contentY = lv.contentY + scrollDirectionY * 10;
                    var currentMaxY = lv.contentHeight - lv.height + lv.originY;
                    if (dragScrollTimer.maxContentY !== 0) {
                        currentMaxY = dragScrollTimer.maxContentY;
                    }
                    contentY = Math.min(contentY, currentMaxY);
                    if (contentY < lv.originY) {
                        contentY = lv.originY;
                    }
                    lv.contentY = contentY;
                    if (contentY !== lv.contentY) {
                        if (scrollDirectionY > 0) {
                            dragScrollTimer.maxContentY = lv.contentY;
                        }
                    }
                }
            }
        }
    }

    // 文件拖入检测区域，通知父组件显示覆盖层
    DropArea {
        id: fileDropArea
        anchors.fill: parent
        onEntered: root.fileDragEntered()
        onExited: root.fileDragExited()
        onDropped: function(drop) {
            if (drop.hasUrls) {
                root.filesDropped(drop.urls);
            }
        }
    }

    Component.onCompleted: Qt.callLater(root.ensureActiveListViewScrollable)

    // 工具函数：直接复用本地素材的毫秒时长格式
    function formatDuration(milliseconds) {
        if (milliseconds <= 0) return "";
        return UiUtils.formatSeconds(milliseconds);
    }

    // 工具函数：获取媒体类型显示文本
    function getMediaTypeText(modelItem) {
        var type = parseInt(modelItem.fileType || "0");
        // AssetType: 0=Unspecified, 1=Photo, 2=Video, 3=LivePhoto, 4=PanoramaPhoto, 5=PanoramaVideo, 6=VR180
        switch (type) {
            case 2: return qsTr("pccut_cloud_album_type_video");
            case 5: return qsTr("pccut_cloud_album_type_pano_video");
            case 6: return qsTr("pccut_cloud_album_type_video");
            case 4: return qsTr("pccut_cloud_album_type_pano_image");
            case 1: case 3: return qsTr("pccut_cloud_album_type_image");
            default: return "";
        }
    }

    // 工具函数：格式化时间戳为日期字符串
    function formatTimestamp(ms) {
        if (ms <= 0) return "";
        var d = new Date(ms);
        var today = new Date();
        if (d.getFullYear() === today.getFullYear()
                && d.getMonth() === today.getMonth()
                && d.getDate() === today.getDate()) {
            return qsTr("pccut_cloud_album_today") + " " + Qt.formatDateTime(d, "HH:mm");
        }
        return Qt.formatDateTime(d, "yyyy-MM-dd HH:mm");
    }

    // 右键菜单
    Loader {
        id: fileOperatePopupLoader
        active: false

        function openPop(showPoint, fileId, index, filePath, isFavorite) {
            active = true;
            var popup = fileOperatePopupLoader.item;
            popup.x = showPoint.x;
            popup.y = showPoint.y;
            popup.fileId = fileId;
            popup.index = index;
            popup.filePath = filePath;

            var operateModels = popup.listModel;
            operateModels.clear();
            // 导出为视频文件 — 暂时屏蔽，后期可能再上
            // operateModels.append({"title": qsTr("pccut_home_highlight_export_tab"), "type": CloudAlbumGridView.MenuAction.ExportVideo});
            operateModels.append({"title": qsTr("pccut_home_original_download"),    "type": CloudAlbumGridView.MenuAction.DownloadOriginal, "objectName": "cloudAlbumMenuDownloadOriginalItem"});
            operateModels.append({"title": isFavorite ? qsTr("pccut_media_unfavorite") : qsTr("pccut_media_favorite"), "type": CloudAlbumGridView.MenuAction.ToggleFavorite, "objectName": "cloudAlbumMenuToggleFavoriteItem"});
            operateModels.append({"title": qsTr("pccut_device_batch_delete"),        "type": CloudAlbumGridView.MenuAction.Delete, "objectName": "cloudAlbumMenuDeleteItem"});

            popup.open();
        }

        sourceComponent: Component {
            OperatePopup {
                objectName: "cloudAlbumOperatePopup"
                property string fileId: ""
                property string filePath: ""
                property int index: 0
                shaderSourceItem: root

                onClosed: {
                    fileOperatePopupLoader.active = false;
                }
                onClickType: (actionType) => {
                    background.visible = false;
                    contentItem.visible = false;
                    root.menuActionClicked(actionType, fileId, index, filePath, 1);
                }
            }
        }
    }
}
