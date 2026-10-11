import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Controls 1.0
import Config 1.0
import app_qrc 1.0
import CloudAlbumRecycleBinModel 1.0

/**
 * 云相册回收站网格视图
 * 基于 CloudAlbumGridView.qml，右键菜单改为"恢复"和"彻底删除"，
 * 缩略图下方显示红色"剩余X天"文字
 */
Item {
    id: root

    // ===== 网格配置 =====
    property int itemWidth: 177
    property int itemHeight: 100
    property int itemSpacing: 24
    property int columns: Math.max(1, Math.floor((width - leftPadding - rightPadding + itemSpacing) / (itemWidth + itemSpacing)))
    property int leftPadding: 0
    property int rightPadding: 0
    property int gridRightPadding: rightPadding

    // 外部数据模型
    property var model: null
    property var sourceModel: null
    property bool showSelectState: false

    signal menuActionClicked(int actionType, string fileId, int fileIndex)
    signal selectionChanged()
    signal requestShowSelectState()

    // 画框多选
    property alias isDragSelecting: dragSelectMouseArea.isShowRect

    // 右键菜单操作类型
    enum MenuAction {
        Restore,
        PermanentDelete
    }

    clip: true

    // 点击空白区域取消选择
    MouseArea {
        id: emptyAreaMouseArea
        anchors.fill: parent
        onClicked: {
            if (root.model) {
                // TODO: 取消全部选中
            }
        }
    }

    // ========== 网格模式 ==========
    GridView {
        id: gridListView
        anchors.fill: parent
        leftMargin: root.leftPadding
        rightMargin: root.gridRightPadding
        boundsBehavior: Flickable.StopAtBounds
        interactive: !bgSelectionRect.visible

        cellWidth: root.itemWidth + root.itemSpacing
        cellHeight: root.itemHeight + root.itemSpacing + 20  // 额外 20px 给底部"剩余天数"文字

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
            if (atYEnd && root.sourceModel && !root.sourceModel.isLoading && !root.sourceModel.isEnd) {
                root.sourceModel.fetchNextPage();
            }
        }

        delegate: Item {
            id: delegateRoot
            objectName: "cloudAlbumRecycleAssetDelegate_" + index
            width: root.itemWidth
            height: root.itemHeight + 20

            // 缩略图容器（圆角裁剪）
            LightClipRectangle {
                id: thumbnailClip
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: root.itemHeight
                radius: [6, 6, 6, 6]
                color: Colors.color_444444
                clip: true

                // 缩略图
                Image {
                    anchors.fill: parent
                    source: model.thumbnailUrl || ""
                    sourceSize: Qt.size(root.itemWidth, root.itemHeight)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: status === Image.Ready
                }

                // hover 边框
                Rectangle {
                    anchors.fill: parent
                    radius: 6
                    color: Colors.transparent
                    border.color: Colors.color_FFFFFF_30
                    border.width: 2
                    visible: itemMouseArea.containsMouse
                }
            }

            // 选择图标（右上角）
            Image {
                id: selectIcon
                anchors.top: thumbnailClip.top
                anchors.right: thumbnailClip.right
                anchors.topMargin: 8
                anchors.rightMargin: 8
                width: 20
                height: 20
                source: (model.isSelected || false)
                        ? "qrc:/app_qrc/icons/media_selected.svg"
                        : "qrc:/icons/media_normal.svg"
                visible: root.showSelectState
            }

            // 类型图标（左下角）
            Image {
                id: typeIcon
                source: getTypeIconSource(model.fileType)
                visible: source.toString().length > 0
                width: 16
                height: 16
                anchors.left: thumbnailClip.left
                anchors.leftMargin: 8
                anchors.bottom: thumbnailClip.bottom
                anchors.bottomMargin: 6
                sourceSize: Qt.size(32, 32)
                fillMode: Image.PreserveAspectFit
            }

            // 时长标签（左下角，紧跟类型图标）
            Text {
                id: durationText
                anchors.left: typeIcon.visible ? typeIcon.right : thumbnailClip.left
                anchors.leftMargin: typeIcon.visible ? 4 : 8
                anchors.verticalCenter: typeIcon.verticalCenter
                visible: (model.duration || 0) > 0
                text: formatDuration(model.duration || 0)
                font.pixelSize: 10
                color: Colors.color_FFFFFF
            }

            // 剩余天数文字（红色，缩略图下方）
            Text {
                anchors.top: thumbnailClip.bottom
                anchors.left: parent.left
                anchors.topMargin: 12
                text: qsTr("pccut_cloud_album_recycle_remain_days").arg(model.remainDays || 0)
                font.pixelSize: 11
                color: Colors.color_F22443
            }

            // 文件名 tooltip
            LightToolTip {
                visible: itemMouseArea.containsMouse
                tip: model.fileName || ""
                y: parent.height - 12
                z: 200
            }

            // 交互区域
            MouseArea {
                id: itemMouseArea
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: (mouse) => {
                    if (mouse.button === Qt.RightButton) {
                        if (root.showSelectState) {
                            return;
                        }
                        var newPoint = itemMouseArea.mapToItem(root, mouse.x, mouse.y);
                        if (root.height - newPoint.y < 120) {
                            newPoint.y = root.height - 120;
                        }
                        recyclePopupLoader.openPop(newPoint, model.assetId, index);
                        return;
                    }
                    if (root.showSelectState) {
                        if (root.isDragSelecting) {
                            return;
                        }
                        root.sourceModel.selectAsset(model.assetId, !(model.isSelected || false));
                        root.selectionChanged();
                    }
                }
            }
        }
    }

    // ========== 画框多选 ==========
    MouseArea {
        id: dragSelectMouseArea
        anchors.fill: parent
        parent: gridListView
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
                gridListView.forceLayout();
                dragSelectMouseArea.isShowRect = false;
            } else {
                dragScrollTimer.stop();
            }
        }

        onPressed: (mouse) => {
            if (pressed) {
                let point = mapToItem(gridListView, Qt.point(mouse.x, mouse.y));
                startX = point.x - gridListView.leftMargin;
                startY = point.y;
                currentX = startX;
                currentY = startY;
                startContentY = gridListView.contentY;
                dragScrollTimer.scrollDirectionY = 0;
                dragScrollTimer.maxContentY = 0;
                dragScrollTimer.start();
            }
        }

        onPositionChanged: (mouse) => {
            if (mouse.buttons === Qt.LeftButton) {
                let point = mapToItem(root, Qt.point(mouse.x, mouse.y));
                currentX = point.x - gridListView.leftMargin;
                currentY = point.y;
                let edge = 30;
                let distance = 5;
                var speed = 0;
                if (point.y < edge) {
                    speed = (point.y - edge) / (edge * 2);
                } else if (root.height - edge < point.y) {
                    speed = (point.y + edge - root.height) / (edge * 2);
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
            parent: gridListView.contentItem
            color: Colors.color_FFFFFF_10
            radius: 2
            border.width: 1
            border.color: Colors.color_FFFFFF_20
            z: Number.MAX_SAFE_INTEGER
            visible: dragSelectMouseArea.pressed
            x: Math.min(dragSelectMouseArea.startX, dragSelectMouseArea.currentX)
            width: Math.abs(dragSelectMouseArea.startX - dragSelectMouseArea.currentX)
            y: Math.min(dragSelectMouseArea.startY + dragSelectMouseArea.startContentY,
                        dragSelectMouseArea.currentY + gridListView.contentY)
            height: Math.abs(dragSelectMouseArea.startY + dragSelectMouseArea.startContentY
                             - dragSelectMouseArea.currentY - gridListView.contentY)

            onWidthChanged: refreshDragSelect()
            onHeightChanged: refreshDragSelect()

            function refreshDragSelect() {
                if (!bgSelectionRect.visible || !dragSelectMouseArea.pressed) {
                    return;
                }
                if (bgSelectionRect.width < 2 || bgSelectionRect.height < 2) {
                    return;
                }
                if (!root.showSelectState) {
                    root.requestShowSelectState();
                }
                dragSelectMouseArea.isShowRect = true;

                var selLeft = bgSelectionRect.x;
                var selTop = bgSelectionRect.y;
                var selRight = selLeft + bgSelectionRect.width;
                var selBottom = selTop + bgSelectionRect.height;

                // GridView：用 indexAt 直接查询
                var cw = gridListView.cellWidth;
                var ch = gridListView.cellHeight;
                var selectedSet = {};

                for (var sy = selTop; sy <= selBottom; sy += ch / 2) {
                    for (var sx = selLeft; sx <= selRight; sx += cw / 2) {
                        var hitIdx = gridListView.indexAt(sx, sy);
                        if (hitIdx >= 0 && !selectedSet[hitIdx]) {
                            selectedSet[hitIdx] = true;
                            var aid = root.model.data(root.model.index(hitIdx, 0), CloudAlbumRecycleBinModel.AssetId);
                            if (aid) {
                                root.sourceModel.selectAsset(aid, true);
                            }
                        }
                    }
                }
                var edgePoints = [
                    Qt.point(selLeft, selTop), Qt.point(selRight, selTop),
                    Qt.point(selLeft, selBottom), Qt.point(selRight, selBottom)
                ];
                for (var ep = 0; ep < edgePoints.length; ep++) {
                    var eidx = gridListView.indexAt(edgePoints[ep].x, edgePoints[ep].y);
                    if (eidx >= 0 && !selectedSet[eidx]) {
                        selectedSet[eidx] = true;
                        var eaid = root.model.data(root.model.index(eidx, 0), CloudAlbumRecycleBinModel.AssetId);
                        if (eaid) {
                            root.sourceModel.selectAsset(eaid, true);
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
                if (scrollDirectionY !== 0 && gridListView.visible) {
                    var contentY = gridListView.contentY + scrollDirectionY * 10;
                    var currentMaxY = gridListView.contentHeight * 1000;
                    if (dragScrollTimer.maxContentY !== 0) {
                        currentMaxY = dragScrollTimer.maxContentY;
                    }
                    if (contentY < gridListView.originY) {
                        contentY = gridListView.originY;
                    }
                    contentY = Math.min(contentY, currentMaxY);
                    gridListView.contentY = contentY;
                    if (contentY !== gridListView.contentY) {
                        if (scrollDirectionY > 0) {
                            dragScrollTimer.maxContentY = gridListView.contentY;
                        }
                    }
                }
            }
        }
    }

    // 工具函数：根据文件类型获取图标资源
    function getTypeIconSource(fileType) {
        var type = parseInt(fileType || "0");
        switch (type) {
            case 2: return "qrc:/app_qrc/metaType/welcome_device_item_video.svg";
            case 5: return "qrc:/app_qrc/metaType/welcome_device_item_pano_video.svg";
            case 6: return "qrc:/app_qrc/metaType/welcome_device_item_video.svg";
            case 4: return "qrc:/app_qrc/metaType/welcome_device_item_pano_photo.svg";
            case 1: return "qrc:/app_qrc/metaType/welcome_device_item_photo.svg";
            case 3: return "qrc:/app_qrc/metaType/welcome_device_item_video.svg";  // 动图本体为 MP4，用视频图标
            default: return "";
        }
    }

    // 工具函数：格式化时长
    function formatDuration(seconds) {
        if (seconds <= 0) return ""
        var m = Math.floor(seconds / 60)
        var s = Math.floor(seconds % 60)
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
    }

    // 右键菜单: 恢复 / 彻底删除
    Loader {
        id: recyclePopupLoader
        active: false

        function openPop(showPoint, fileId, fileIndex) {
            active = true;
            var popup = recyclePopupLoader.item;
            popup.x = showPoint.x;
            popup.y = showPoint.y;
            popup.fileId = fileId;
            popup.index = fileIndex;

            var operateModels = popup.listModel;
            operateModels.clear();
            operateModels.append({"title": qsTr("pccut_cloud_album_recycle_restore"),          "type": CloudAlbumRecycleBinGridView.MenuAction.Restore, "objectName": "cloudAlbumRecycleRestoreMenuItem"});
            operateModels.append({"title": qsTr("pccut_cloud_album_recycle_permanent_delete"), "type": CloudAlbumRecycleBinGridView.MenuAction.PermanentDelete, "objectName": "cloudAlbumRecyclePermanentDeleteMenuItem"});

            popup.open();
        }

        sourceComponent: Component {
            OperatePopup {
                objectName: "cloudAlbumRecycleOperatePopup"
                property string fileId: ""
                property int index: 0
                shaderSourceItem: root

                onClosed: {
                    recyclePopupLoader.active = false;
                }
                onClickType: (actionType) => {
                    background.visible = false;
                    contentItem.visible = false;
                    root.menuActionClicked(actionType, fileId, index);
                }
            }
        }
    }
}
