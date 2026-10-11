import Controls 1.0
import Config 1.0
import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.15
import Qt5Compat.GraphicalEffects
import ShortcutAction 1.0

import "../controller"

Item {
    id: control
    anchors.fill: parent

    CShortcut {
        action: ShortcutAction.ESCAPE_FULL_SCREEN
        enabled: control.visible && control.showSelectState
        priority: 1
        onActivated: {
            control.showSelectState = false
            recycleBinViewModel.resetSelectedDrafts()
        }
    }

    property bool showSelectState: false
    property int rightClickedIndex: -1
    property int singleDeleteIndex: -1

    function doBatchRestore(indexes) {
        var totalCount = indexes.length
        var successCount = draftManager.batchRestoreDrafts(indexes)
        eventTracker.trackEvent("pccut_draft_batch_restore_result", {
            "is_success": successCount === totalCount,
            "success_count": successCount,
            "fail_count": totalCount - successCount
        })
    }

    function restoreSelectedDrafts() {
        if (recycleBinViewModel.selectCount < 1) return
        eventTracker.trackEvent("pccut_draft_batch_delete_click", {"button_type": "restore", "use_method": "bin"})
        var indexes = recycleBinViewModel.selectedIndexes()
        doBatchRestore(indexes)
        recycleBinViewModel.resetSelectedDrafts()
        if (recycleBinViewModel.deletedCount === 0) {
            control.showSelectState = false
        }
    }

    onVisibleChanged: {
        if (visible) {
            gridView.positionViewAtBeginning()
        }
    }

    property int padding: 33
    property int spacing: 32
    property int itemWidth: 120
    property int itemHeight: 184
    property int delegateWidth: itemWidth + spacing
    property int delegateHeight: itemHeight + spacing
    property int columns: Math.max(1, Math.floor((gridView.width + spacing - padding) / delegateWidth))

    component IconTextLocalSelectionButton : IconTextButton {

        visible: control.showSelectState
        height: 28
        radius: 6
        imageRectWidth: 16
        imageRectHeight: 16
        internalSpacing: 4
        backgroundColorNormal: Colors.color_transparent
        backgroundColorHover: Colors.color_transparent
    }

    component IconTextLocalNormalButton : IconTextButton {

        height: 28        
        radius: 6
        imageRectWidth: 16
        imageRectHeight: 16
        internalSpacing: 4
        backgroundColorNormal: Colors.color_button_background_normal
        backgroundColorHover: Colors.color_button_background_hovered
        enabled: recycleBinViewModel.deletedCount > 0
        titleColorNormal: enabled ? Colors.color_EEEEEE : Colors.color_444444
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // 顶部导航行
        Item {
            Layout.leftMargin: 40
            Layout.rightMargin: 40
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            Layout.topMargin: 36

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                IconTextLocalSelectionButton {
                    visible: true
                    iconPathNormal: "qrc:/icons/recycle/icon_back.svg"
                    imageRectWidth: 8
                    imageRectHeight: 20
                    onCustomClicked: {
                        control.showSelectState = false
                        recycleBinViewModel.resetSelectedDrafts()
                        homeView.recycleBinRedDot = false
                        stackView.changeTab(homeView.homeButtonIndex)
                    }
                }

                Text {
                    text: qsTr("pccut_draft_recycle_title") + " (" + recycleBinViewModel.deletedCount + ")"
                    color: Colors.color_EEEEEE
                    font.pixelSize: 16
                    anchors.verticalCenter: parent.verticalCenter
                    rightPadding: 16
                }

                Text {
                    text: control.showSelectState
                          ? qsTr("pccut_draft_batch_selected_count_status").arg("<font color='" + Colors.color_EEEEEE + "'>" + recycleBinViewModel.selectCount + "</font>")
                          : qsTr("pccut_draft_recycle_expire_countdown_status").arg(30)
                    textFormat: control.showSelectState ? Text.RichText : Text.PlainText
                    color: Colors.color_666666
                    font.pixelSize: 12
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                // 恢复按钮
                IconTextLocalSelectionButton {
                    enabled: recycleBinViewModel.selectCount > 0
                    title: qsTr("pccut_draft_recycle_restore_btn")
                    titleColorNormal: enabled ? hovered ? Colors.color_FFFFFF : Colors.color_EEEEEE : Colors.color_444444
                    iconPathNormal: "qrc:/icons/recycle/icon_recycle_restore_normal.svg"
                    iconPathDisable: "qrc:/icons/recycle/icon_recycle_restore_disabled.svg"
                    iconPathHover: "qrc:/icons/recycle/icon_recycle_restore_hover.svg"
                    rightPadding: 16

                    onCustomClicked: {
                        restoreSelectedDrafts()
                    }
                }

                // 彻底删除按钮
                IconTextLocalSelectionButton {
                    enabled: recycleBinViewModel.selectCount > 0
                    title: qsTr("pccut_draft_recycle_permanent_delete_btn")
                    titleColorNormal: enabled ? hovered ? Colors.color_FFFFFF : Colors.color_EEEEEE : Colors.color_444444
                    iconPathNormal: "qrc:/icons/multiple_delete.svg"
                    iconPathDisable: "qrc:/icons/multiple_delete_disable.svg"
                    iconPathHover: "qrc:/icons/multiple_delete_highlight.svg"
                    internalSpacing: 4
                    rightPadding: 16

                    onCustomClicked: {
                        if (recycleBinViewModel.selectCount < 1) return
                        eventTracker.trackEvent("pccut_draft_batch_delete_click", {"button_type": "delete", "use_method": "bin"})
                        permanentDeletePopup.open()
                    }
                }

                // 全选/取消全选
                IconTextLocalSelectionButton {
                    title: recycleBinViewModel.selectCount === recycleBinViewModel.deletedCount
                        ? qsTr("pccut_draft_batch_deselect_all_btn") : qsTr("pccut_draft_batch_select_all_btn")
                    titleColorNormal: hovered ? Colors.color_FFFFFF : Colors.color_EEEEEE
                    isTextOnly: true
                    width: 96
                    backgroundColorNormal: Colors.color_button_background_normal
                    backgroundColorHover: Colors.color_button_background_hovered
                    onCustomClicked: {
                        if (recycleBinViewModel.selectCount === recycleBinViewModel.deletedCount) {
                            eventTracker.trackEvent("pccut_draft_batch_delete_click", {"button_type": "select_cancel", "use_method": "bin"})
                            recycleBinViewModel.resetSelectedDrafts()
                        } else {
                            eventTracker.trackEvent("pccut_draft_batch_delete_click", {"button_type": "select_all", "use_method": "bin"})
                            recycleBinViewModel.selectAll()
                        }
                    }
                }

                // 清空回收站 + 批量选择 组合
                Row {
                    spacing: 8
                    anchors.verticalCenter: parent.verticalCenter

                    // 清空回收站图标按钮
                    IconTextLocalNormalButton {
                        visible: !control.showSelectState
                        width: 28
                        iconPathNormal: "qrc:/icons/recycle/icon_recycle_clear_all.svg"
                        iconPathDisable: "qrc:/icons/recycle/icon_recycle_clear_all_disabled.svg"
                        iconPathHover: "qrc:/icons/recycle/icon_recycle_clear_all_hover.svg"
                        leftPadding: 6
                        rightPadding: 6
                        // opacity: enabled ? 1.0 : 0.4
                        onCustomClicked: {
                            eventTracker.trackEvent("pccut_draft_batch_delete_click", {"button_type": "delete_all", "use_method": "bin"})
                            emptyRecycleBinPopup.open()
                        }
                    }

                    // 批量选择按钮
                    IconTextLocalNormalButton {
                        visible: true
                        width: 96
                        isTextOnly: control.showSelectState
                        title: control.showSelectState ? qsTr("pccut_draft_batch_select_cancel_btn") : qsTr("pccut_draft_batch_select_btn")
                        iconPathNormal: control.showSelectState ? "" : "qrc:/app_qrc/icons/multiple_select.svg"
                        iconPathDisable: "qrc:/icons/recycle/icon_batch_selection_disabled.svg"
                        iconPathHover: "qrc:/icons/recycle/icon_batch_selection_hover.svg"

                        leftPadding: 12
                        rightPadding: 12
                        topPadding: 6
                        bottomPadding: 6
                        onCustomClicked: {
                            control.showSelectState = !control.showSelectState
                            if (!control.showSelectState) {
                                eventTracker.trackEvent("pccut_draft_batch_delete_click", {"button_type": "select_cancel", "use_method": "bin"})
                                recycleBinViewModel.resetSelectedDrafts()
                            } else {
                                eventTracker.trackEvent("pccut_draft_batch_delete_click", {"button_type": "select", "use_method": "bin"})
                            }
                        }
                    }
                }
            }
        }

        // 草稿网格
        Item {
            Layout.leftMargin: 40
            Layout.rightMargin: 6
            Layout.topMargin: 16
            Layout.fillHeight: true
            Layout.fillWidth: true

            Item {
                anchors.fill: parent
                clip: true

                MouseArea {
                    anchors.fill: parent
                    enabled: control.showSelectState
                    onClicked: {
                        recycleBinViewModel.resetSelectedDrafts()
                        eventTracker.trackEvent("pccut_draft_batch_delete_click", {"button_type": "select_cancel", "use_method": "bin"})
                    }
                }

                GridView {
                    id: gridView
                    anchors.fill: parent
                    flow: GridView.FlowLeftToRight
                    cellWidth: control.delegateWidth
                    cellHeight: control.delegateHeight
                    interactive: !recycleBinDragSelect.pressed

                    model: recycleBinViewModel

                    ScrollBar.vertical: ScrollBar {
                        rightPadding: 6
                        Component.onCompleted: {
                            contentItem.color = Colors.color_444444
                        }
                    }

                    delegate: Item {
                        width: control.delegateWidth
                        height: control.delegateHeight
                        property int _selectCount: recycleBinViewModel.selectCount
                        property bool isSelected: _selectCount >= 0 && recycleBinViewModel.isSelectedForDraftId(model.id)

                        Item {
                            width: control.itemWidth
                            height: control.itemHeight

                            ColumnLayout {
                                anchors.fill: parent
                                spacing: 0

                                // 缩略图
                                Rectangle {
                                    width: 120
                                    height: 120
                                    radius: 6
                                    color: Colors.color_1F2021
                                    layer.enabled: true
                                    layer.effect: OpacityMask {
                                        maskSource: Rectangle {
                                            width: 120
                                            height: 120
                                            radius: 6
                                        }
                                    }

                                    Image {
                                        anchors.fill: parent
                                        fillMode: Image.PreserveAspectCrop
                                        cache: false
                                        asynchronous: true
                                        source: draftManager.isFileExist(model.coverPath) ? "file:///" + model.coverPath : ""
                                        visible: source !== ""
                                        clip: true
                                        width: 120
                                        height: 120
                                    }

                                    // 选择图标
                                    Image {
                                        anchors.right: parent.right
                                        anchors.rightMargin: 8
                                        anchors.top: parent.top
                                        anchors.topMargin: 8
                                        source: isSelected ? "qrc:/app_qrc/icons/media_selected.svg" : "qrc:/icons/media_normal.svg"
                                        visible: control.showSelectState
                                        width: 20
                                        height: 20
                                        sourceSize: Qt.size(20, 20)
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                        onClicked: (mouse) => {
                                            if (mouse.button === Qt.RightButton) {
                                                if (!isSelected) {
                                                    recycleBinViewModel.appendSelectedDraftId(model.id)
                                                    eventTracker.trackEvent("pccut_draft_batch_delete_click",
                                                                            {"button_type": "select", "use_method": "bin"})
                                                }
                                                var pos = mapToItem(recycleBinContextMenu.parent, mouse.x, mouse.y)
                                                recycleBinContextMenu.listModel.clear()
                                                recycleBinContextMenu.listModel.append({"title": qsTr("pccut_draft_recycle_restore_btn"), "type": 0})
                                                recycleBinContextMenu.listModel.append({"title": qsTr("pccut_draft_recycle_permanent_delete_btn"), "type": 1})
                                                recycleBinContextMenu.x = pos.x
                                                recycleBinContextMenu.y = pos.y
                                                if (!control.showSelectState) {
                                                    control.rightClickedIndex = index
                                                }
                                                recycleBinContextMenu.open()
                                                return
                                            }
                                            if (control.showSelectState) {
                                                if (mouse.modifiers & Qt.ShiftModifier) {
                                                    recycleBinViewModel.continuousSelect(index)
                                                    eventTracker.trackEvent("pccut_draft_batch_delete_click", {"button_type": "select", "use_method": "bin"})
                                                } else {
                                                    if (recycleBinViewModel.isSelectedForDraftId(model.id)) {
                                                        recycleBinViewModel.removeSelectedDraftId(model.id)
                                                        eventTracker.trackEvent("pccut_draft_batch_delete_click", {"button_type": "select_cancel", "use_method": "bin"})
                                                    } else {
                                                        recycleBinViewModel.appendSelectedDraftId(model.id)
                                                        eventTracker.trackEvent("pccut_draft_batch_delete_click", {"button_type": "select", "use_method": "bin"})
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                // 名称
                                Text {
                                    Layout.fillWidth: true
                                    Layout.topMargin: 8
                                    color: Colors.color_FFFFFF
                                    font.pixelSize: 12
                                    text: model.draftName
                                    elide: Text.ElideMiddle
                                }

                                // 大小和时长
                                Text {
                                    Layout.fillWidth: true
                                    Layout.topMargin: 2
                                    color: Colors.color_666666
                                    font.pixelSize: 11
                                    text: model.displayText
                                }

                                // 删除日期
                                Text {
                                    Layout.fillWidth: true
                                    Layout.topMargin: 2
                                    color: Colors.color_F22443
                                    font.pixelSize: 11
                                    text: model.deleteDateText
                                }
                            }
                        }
                    }
                }

                DragSelectOverlay {
                    id: recycleBinDragSelect
                    property bool dragTracked: false
                    targetGridView: gridView
                    showSelectState: control.showSelectState
                    columns: control.columns
                    delegateWidth: control.delegateWidth
                    delegateHeight: control.delegateHeight
                    itemWidth: control.itemWidth
                    itemHeight: control.itemHeight
                    onSelectStateChanged: (active) => {
                        if (active) {
                            control.showSelectState = true
                            eventTracker.trackEvent("pccut_draft_batch_delete_click", {"button_type": "select", "use_method": "bin"})
                            dragTracked = true
                        }
                    }
                    onDragSelectUpdated: (selectRect) => {
                        var adjusted = Qt.rect(selectRect.x, selectRect.y - gridView.originY, selectRect.width, selectRect.height)
                        var originX = recycleBinDragSelect.startX
                        var originY = recycleBinDragSelect.startY + recycleBinDragSelect.startContentY - gridView.originY
                        recycleBinViewModel.dragSelect(adjusted, control.columns, control.delegateWidth, control.delegateHeight, control.itemWidth, control.itemHeight, originX, originY)
                        if (!dragTracked) {
                            eventTracker.trackEvent("pccut_draft_batch_delete_click", {"button_type": "select", "use_method": "bin"})
                            dragTracked = true
                        }
                    }
                }

                Connections {
                    target: recycleBinDragSelect
                    function onPressedChanged() {
                        if (recycleBinDragSelect.pressed) {
                            recycleBinDragSelect.dragTracked = false
                        }
                    }
                }
            }

            // 空状态
            Loader {
                anchors.fill: parent
                sourceComponent: recycleBinViewModel.deletedCount <= 0 ? emptyRecycleBin : undefined
            }
        }
    }

    ConfirmPopup {
        id: permanentDeletePopup
        title: qsTr("pccut_draft_recycle_permanent_delete_dialog_title")
        text: qsTr("pccut_draft_recycle_permanent_delete_dialog_desc")
        leftButtonText: qsTr("pccut_draft_delete_popup_cancel")
        rightButtonText: qsTr("pccut_draft_delete_popup_yes")
        onRightButtonClicked: {
            var deleteCount = 0
            var totalCount = 0
            if (control.singleDeleteIndex >= 0) {
                totalCount = 1
                var res = draftManager.permanentDeleteDraft(control.singleDeleteIndex)
                deleteCount = res ? 1 : 0
                control.singleDeleteIndex = -1
            } else {
                var indexes = recycleBinViewModel.selectedIndexes()
                totalCount = indexes.length
                deleteCount = draftManager.batchPermanentDeleteDrafts(indexes)
                recycleBinViewModel.resetSelectedDrafts()
            }
            eventTracker.trackEvent("pccut_draft_batch_delete_result", {
                "is_success": deleteCount > 0,
                "success_count": deleteCount,
                "fail_count": totalCount - deleteCount
            })
            if (recycleBinViewModel.deletedCount === 0) {
                control.showSelectState = false
            }
        }
    }

    ConfirmPopup {
        id: emptyRecycleBinPopup
        title: qsTr("pccut_draft_recycle_clear_all_dialog_title")
        text: qsTr("pccut_draft_recycle_clear_all_dialog_desc").arg("<font color='" + Colors.color_EEEEEE + "'>" + recycleBinViewModel.deletedCount + "</font>")
        leftButtonText: qsTr("pccut_draft_delete_popup_cancel")
        rightButtonText: qsTr("pccut_draft_delete_popup_yes")
        onRightButtonClicked: {
            var totalCount = recycleBinViewModel.deletedCount
            var successCount = draftManager.emptyRecycleBin()
            eventTracker.trackEvent("pccut_draft_batch_delete_result", {
                "is_success": successCount > 0,
                "success_count": successCount,
                "fail_count": totalCount - successCount
            })
            control.showSelectState = false
        }
    }

    Component {
        id: emptyRecycleBin
        Rectangle {
            anchors.fill: parent
            color: Colors.color_141414
            Column {
                anchors.centerIn: parent
                spacing: 12
                Image {
                    anchors.horizontalCenter: parent.horizontalCenter
                    source: "qrc:/icons/recycle/icon_recycle_bin_empty.svg"
                    sourceSize: Qt.size(56, 56)
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: qsTr("pccut_draft_recycle_empty_state_desc")
                    color: Colors.color_666666
                    font.pixelSize: 12
                }
            }
        }
    }

    OperatePopup {
        id: recycleBinContextMenu
        shaderSourceItem: control
        width: 123
        onClickType: (modeType) => {
            if (control.showSelectState) {
                if (modeType === 0) {
                    restoreSelectedDrafts()
                } else if (modeType === 1) {
                    if (recycleBinViewModel.selectCount > 0) {
                        eventTracker.trackEvent("pccut_draft_batch_delete_click", {"button_type": "delete", "use_method": "bin"})
                        permanentDeletePopup.open()
                    }
                }
            } else {
                if (control.rightClickedIndex < 0) return
                if (modeType === 0) {
                    draftManager.restoreDraft(control.rightClickedIndex)
                    eventTracker.trackEvent("pccut_draft_batch_delete_click", {"button_type": "restore", "use_method": "bin"})
                } else if (modeType === 1) {
                    eventTracker.trackEvent("pccut_draft_batch_delete_click", {"button_type": "delete", "use_method": "bin"})
                    control.singleDeleteIndex = control.rightClickedIndex
                    permanentDeletePopup.open()
                }
                control.rightClickedIndex = -1
            }
        }
    }
}
