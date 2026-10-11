import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.15
import Controls 1.0
import Config 1.0
import ShortcutAction 1.0

/**
 * 云相册回收站页面
 * 参照 CloudAlbumLoggedInView.qml 的布局和批量选择逻辑
 */
Item {
    id: root
    objectName: "cloudAlbumRecycleBinView"

    // 外部数据模型（回收站 C++ 模型）
    property var recycleBinModel: null
    property int totalCount: recycleBinModel ? recycleBinModel.count : 0
    property bool hasContent: totalCount > 0

    // 批量选中模式
    property bool showSelectState: false
    onShowSelectStateChanged: {
        if (!showSelectState && recycleBinModel) {
            recycleBinModel.selectAll(false);
        }
    }

    // 批量选中：恢复/删除按钮 enabled 绑定
    property int selectCount: 0
    function updateSelectCount() {
        selectCount = recycleBinModel ? recycleBinModel.selectedAssetIds().length : 0;
    }

    signal backClicked()

    // ESC 退出批量选择模式
    CShortcut {
        action: ShortcutAction.ESCAPE_FULL_SCREEN
        enabled: root.visible && root.showSelectState
        onActivated: {
            root.showSelectState = false;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: 34
        anchors.bottomMargin: 30
        anchors.leftMargin: 0
        anchors.rightMargin: 0
        spacing: 0

        // ========== 1. 顶部导航栏 ==========
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 40
            Layout.rightMargin: 40
            spacing: 0

            // 返回按钮: < 最近删除 (N) 整体可点击
            Item {
                id: backBtn
                objectName: "cloudAlbumRecycleBackBtn"
                Layout.preferredHeight: 28
                Layout.preferredWidth: backBtnRow.implicitWidth + 8

                Row {
                    id: backBtnRow
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12

                    // TODO: 替换为实际的返回箭头图标
                    Image {
                        anchors.verticalCenter: parent.verticalCenter
                        source: backBtnMouseArea.containsMouse
                            ? "qrc:/app_qrc/icons/cloud_album_back_hover.svg"
                            : "qrc:/app_qrc/icons/cloud_album_back.svg"
                        sourceSize: Qt.size(8, 20)
                        width: 8
                        height: 20
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.totalCount > 0
                            ? qsTr("pccut_cloud_album_recycle_title").arg(root.totalCount)
                            : qsTr("pccut_cloud_album_recycle_title_empty")
                        font.pixelSize: 16
                        font.weight: Font.Medium
                        color: backBtnMouseArea.containsMouse ? Colors.color_FFFFFF : Colors.color_EEEEEE
                    }
                }

                MouseArea {
                    id: backBtnMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.backClicked()
                }
            }

            Item { width: 12 }

            // 提示文字
            Text {
                text: qsTr("pccut_cloud_album_recycle_hint")
                font.pixelSize: 12
                color: Colors.color_666666
                Layout.alignment: Qt.AlignVCenter
            }

            // 弹簧
            Item { Layout.fillWidth: true }

            // 右侧: 操作图标栏
            RowLayout {
                spacing: root.showSelectState ? 24 : 8

                // --- 非批量选择模式：一键清空按钮 ---
                IconButton {
                    id: clearAllBtn
                    objectName: "cloudAlbumRecycleClearAllBtn"
                    width: 28; height: 28
                    visible: !root.showSelectState
                    disabled: !root.hasContent
                    opacity: disabled ? 0.2 : 1.0
                    // TODO: 替换为实际的一键清空图标
                    iconSource: "qrc:/app_qrc/icons/cloud_album_clear_all.svg"
                    iconWidth: 20; iconHeight: 20
                    normalColor: Colors.color_2F3032
                    hoverColor: Colors.color_454649
                    pressedColor: Colors.color_2F3032
                    disableColor: Colors.color_2F3032
                    disableOpacity: 1.0
                    onClicked: {
                        // TODO: 一键清空回收站
                        recycleBinClearAllPopup.open();
                    }
                }

                // --- 批量选择模式：恢复按钮 ---
                IconTextButton {
                    id: batchRestoreBtn
                    objectName: "cloudAlbumRecycleBatchRestoreBtn"
                    height: 28
                    visible: root.showSelectState

                    enabled: root.selectCount > 0
                    title: qsTr("pccut_cloud_album_recycle_restore")
                    titleColorNormal: enabled ? hovered ? Colors.color_FFFFFF : Colors.color_EEEEEE : Colors.color_444444
                    iconPathNormal: "qrc:/icons/multiple_need_restore.svg"
                    iconPathDisable: "qrc:/icons/multiple_need_restore_disable.svg"
                    iconPathHover: "qrc:/icons/multiple_need_restore_hover.svg"
                    imageRectWidth: 16
                    imageRectHeight: 16

                    backgroundColorNormal: Colors.color_transparent
                    backgroundColorHover: Colors.color_transparent
                    internalSpacing: 4

                    onCustomClicked: {
                        if (!enabled) return;
                        var selectedIds = root.recycleBinModel.selectedAssetIds();
                        if (selectedIds.length > 0) {
                            root.recycleBinModel.restoreAssets(selectedIds);
                            root.showSelectState = false;
                        }
                    }
                }

                // --- 批量选择模式：彻底删除按钮 ---
                IconTextButton {
                    id: batchDeleteBtn
                    objectName: "cloudAlbumRecycleBatchDeleteBtn"
                    height: 28
                    visible: root.showSelectState

                    enabled: root.selectCount > 0
                    title: qsTr("pccut_cloud_album_recycle_permanent_delete")
                    titleColorNormal: enabled ? hovered ? Colors.color_FFFFFF : Colors.color_EEEEEE : Colors.color_444444
                    iconPathNormal: "qrc:/icons/multiple_delete.svg"
                    iconPathDisable: "qrc:/icons/multiple_delete_disable.svg"
                    iconPathHover: "qrc:/icons/multiple_delete_highlight.svg"
                    imageRectWidth: 16
                    imageRectHeight: 16

                    backgroundColorNormal: Colors.color_transparent
                    backgroundColorHover: Colors.color_transparent
                    internalSpacing: 4

                    onCustomClicked: {
                        if (!enabled) return;
                        var selectedIds = root.recycleBinModel.selectedAssetIds();
                        if (selectedIds.length > 0) {
                            recycleBinDeletePopup.showPop(selectedIds);
                        }
                    }
                }

                // --- 批量选择 / 取消选择 按钮 ---
                IconTextButton {
                    id: recycleBatchSelectBtn
                    objectName: "cloudAlbumRecycleBatchSelectBtn"
                    Layout.preferredHeight: 28
                    Layout.preferredWidth: 88
                    usePreferredWidth: false
                    alignment: root.showSelectState ? Qt.AlignHCenter : Qt.AlignLeft

                    enabled: root.hasContent
                    opacity: enabled ? 1.0 : 0.2
                    title: root.showSelectState
                        ? qsTr("pccut_device_batch_cancel")
                        : qsTr("pccut_cloud_album_batch_select")
                    titleFontSize: 12
                    titleColorNormal: Colors.color_EEEEEE
                    imageRectWidth: 16
                    imageRectHeight: 16

                    iconPathNormal: root.showSelectState
                        ? ""
                        : "qrc:/app_qrc/icons/cloud_album_batch.svg"
                    isTextOnly: root.showSelectState
                    backgroundColorNormal: Colors.color_2F3032
                    backgroundColorHover: Colors.color_37383A
                    backgroundColorPressed: Colors.color_2F3032
                    internalSpacing: 6
                    leftPadding: root.showSelectState ? 18 : 8
                    rightPadding: root.showSelectState ? 18 : 8
                    topPadding: 6
                    bottomPadding: 6

                    onCustomClicked: {
                        if (!enabled) return;
                        root.showSelectState = !root.showSelectState;
                    }
                }
            }
        }

        // 导航栏到内容区间距
        Item { Layout.preferredHeight: 20 }

        // ========== 2. 内容区 ==========
        Item {
            id: contentArea
            Layout.fillWidth: true
            Layout.fillHeight: true

            // 有内容时显示网格视图
            CloudAlbumRecycleBinGridView {
                id: recycleGridView
                objectName: "cloudAlbumRecycleGridView"
                anchors.fill: parent
                visible: root.hasContent
                model: root.recycleBinModel
                sourceModel: root.recycleBinModel
                showSelectState: root.showSelectState
                leftPadding: 40
                rightPadding: 40
                gridRightPadding: 16

                onRequestShowSelectState: root.showSelectState = true
                onMenuActionClicked: function(actionType, fileId, fileIndex) {
                    if (actionType === CloudAlbumRecycleBinGridView.MenuAction.Restore) {
                        root.recycleBinModel.restoreAssets([fileId]);
                    } else if (actionType === CloudAlbumRecycleBinGridView.MenuAction.PermanentDelete) {
                        recycleBinDeletePopup.showPop([fileId]);
                    }
                }
                onSelectionChanged: root.updateSelectCount()
            }

            // 无内容时显示空状态
            Item {
                anchors.fill: parent
                visible: !root.hasContent

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 12

                    // TODO: 替换为回收站空状态图标
                    Image {
                        Layout.alignment: Qt.AlignHCenter
                        source: "qrc:/app_qrc/icons/cloud_album_empty_recycle.svg"
                        sourceSize: Qt.size(64, 64)
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: qsTr("pccut_cloud_album_recycle_empty")
                        font.pixelSize: 14
                        color: Colors.color_666666
                    }
                }
            }
        }
    }

    // 彻底删除确认弹框
    ConfirmPopup {
        id: recycleBinDeletePopup
        objectName: "cloudAlbumRecycleDeletePopup"
        parent: Overlay.overlay

        title: qsTr("pccut_cloud_album_recycle_delete_confirm_title")
        text: qsTr("pccut_cloud_album_recycle_delete_confirm").arg(deleteFileIds.length)
        leftButtonText: qsTr("pccut_device_batch_delete_all_cancel")
        rightButtonText: qsTr("pccut_device_batch_delete_all_yes")
        leftButtonObjectName: "cloudAlbumRecycleDeleteCancelBtn"
        rightButtonObjectName: "cloudAlbumRecycleDeleteConfirmBtn"

        property var deleteFileIds: []

        function showPop(fileIds) {
            deleteFileIds = fileIds;
            open();
        }

        onLeftButtonClicked: {
        }

        onRightButtonClicked: {
            root.recycleBinModel.permanentlyDeleteAssets(deleteFileIds);
            root.showSelectState = false;
        }
    }

    // 一键清空确认弹框
    ConfirmPopup {
        id: recycleBinClearAllPopup
        objectName: "cloudAlbumRecycleClearAllPopup"
        parent: Overlay.overlay

        title: qsTr("pccut_cloud_album_recycle_clear_all_confirm_title")
        text: qsTr("pccut_cloud_album_recycle_clear_all_confirm").arg(root.totalCount)
        leftButtonText: qsTr("pccut_device_batch_delete_all_cancel")
        rightButtonText: qsTr("pccut_device_batch_delete_all_yes")
        leftButtonObjectName: "cloudAlbumRecycleClearAllCancelBtn"
        rightButtonObjectName: "cloudAlbumRecycleClearAllConfirmBtn"

        onLeftButtonClicked: {
        }

        onRightButtonClicked: {
            root.recycleBinModel.clearAll();
        }
    }
}
