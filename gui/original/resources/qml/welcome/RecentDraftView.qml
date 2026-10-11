import Controls 1.0
import Config 1.0
import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.15
import QtQuick.Dialogs
import Qt5Compat.GraphicalEffects
import "../controller"

Item {
    id: control
    property bool showDraftSelectState: false

    function addDraft() {
        DraftListViewModel.addNewDraft()
    }
    function getDraftName(){
        return "temp name";
    }
    function getDraftSize(){
        return 100;
    }
    function getDraftLength(){
        return 200;
    }
    function extractFileName(filePath) {
        return filePath.substring(filePath.lastIndexOf("/") + 1);
    }
    // 检查没人调用，我先注释了。如果要用建议考虑下是否需要平台换算
    // function formatBytes(bytes) {
    //     if (bytes === 0) return '0 B';
    //     // 平台换算风险：mac - 1000
    //     const k = 1024;
    //     const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
    //     const i = Math.floor(Math.log(bytes) / Math.log(k));
    //     return parseFloat((bytes / Math.pow(k, i)).toFixed(0)) + sizes[i];
    // }

    signal messageTips(var type)

    anchors.fill: parent

    // 边距
    property int padding: 33

    // Item 间隔
    property int spacing: 32

    // Item 宽
    property int itemWidth: 120

    // Item 高
    property int itemHeight: 166

    // Delegate 宽
    property int delegateWidth: itemWidth + spacing

    // Delegate 高
    property int delegateHeight: itemHeight + spacing

    // 列数根据可视宽度和 Item 宽度计算 (非必要不用改)
    //                               view整体宽度                /    每一项宽度  < 1 ? 窗口宽度过小，一列展示 : 多列情况(总宽度 / 每一项宽度 = 列数)
    property int columns: Math.max(1, Math.floor((list_view.width + spacing - padding) / delegateWidth))

    property int sectionHeaderHeight: 0

    property string selectedDevice;

    function openDraftOperatePopup(popupLoader, fromItem, offsetX, offsetY) {
        popupLoader.active = true
        var popup = popupLoader.item
        if (!popup) return
        var relativePos = fromItem.mapToItem(popup.parent, offsetX, offsetY)
        popup.x = relativePos.x
        popup.y = relativePos.y
        popup.open()
    }

    // 套一层 Item clip 剪去 ListView 尾巴上多余的部分不显示出来
    Item {
        anchors.fill: parent

        clip: true

        MouseArea {
            anchors.fill: parent
            enabled: control.showDraftSelectState
            onClicked: {
                draftListViewModel.resetSelectedDrafts()
                eventTracker.trackEvent("pccut_draft_batch_delete_click", {"button_type": "select_cancel", "use_method": "draft"})
            }
        }

        GridView {
            id: list_view
            anchors.fill: parent
            objectName: actionableItemName.homeViewListView
            flow: GridView.FlowLeftToRight
            cellWidth: control.delegateWidth
            cellHeight: control.delegateHeight
            interactive: !draftDragSelect.pressed
            cacheBuffer: 300
            anchors {
                bottom: parent.bottom
                bottomMargin: 10
            }

            model: draftListViewModel

            ScrollBar.vertical: ScrollBar {
                rightPadding: 6
                Component.onCompleted: {
                    contentItem.color = Colors.color_444444
                }
            }

            property real animationY: 0
            delegate: Item {
                objectName: actionableItemName.delegateItemForHomeViewListView + index
                width: control.delegateWidth
                height: control.delegateHeight
                property int _selectCount: draftListViewModel.selectCount
                property bool isSelected: _selectCount >= 0 && draftListViewModel.isSelectedForDraftId(model.id)
                // 放置真正的内容
                Item {
                    width: control.itemWidth
                    height: control.itemHeight

                    LightClipRectangle {
                        id: imageClip
                        width: control.itemWidth
                        height: control.itemHeight
                        color: Colors.transparent
                        radius: [6, 6, 6, 6]

                        MouseArea {
                            id: draftArea
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            hoverEnabled: true
                            onEntered: moreButton.visible = !control.showDraftSelectState
                            onExited: moreButton.visible = false
                            onClicked: (mouse) => {
                                if (mouse.button === Qt.RightButton) {
                                    if (control.showDraftSelectState && draftListViewModel.selectCount > 0) {
                                        var pos = mapToItem(batchContextMenu.parent, mouse.x, mouse.y)
                                        batchContextMenu.listModel.clear()
                                        batchContextMenu.listModel.append({"title": qsTr("pccut_draft_delete"), "type": 0})
                                        batchContextMenu.x = pos.x
                                        batchContextMenu.y = pos.y
                                        batchContextMenu.open()
                                    }
                                    return
                                }
                                if (control.showDraftSelectState) {
                                    if (mouse.modifiers & Qt.ShiftModifier) {
                                        draftListViewModel.continuousSelect(index)
                                        eventTracker.trackEvent("pccut_draft_batch_delete_click", {"button_type": "select", "use_method": "draft"})
                                    } else {
                                        if (draftListViewModel.isSelectedForDraftId(model.id)) {
                                            draftListViewModel.removeSelectedDraftId(model.id)
                                            eventTracker.trackEvent("pccut_draft_batch_delete_click", {"button_type": "select_cancel", "use_method": "draft"})
                                        } else {
                                            draftListViewModel.appendSelectedDraftId(model.id)
                                            eventTracker.trackEvent("pccut_draft_batch_delete_click", {"button_type": "select", "use_method": "draft"})
                                        }
                                    }
                                    return
                                }
                                eventTracker.trackEvent("pccut_draft_click")
                                if(draftManager.openDraft(model.id)) {
                                    eventTracker.trackEvent("pccut_create_project_click", {"use_method": "draft"});
                                }
                            }
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 0

                            Rectangle {
                                id: imageRect
                                width: 120
                                height: 120
                                radius: 6
                                color: Colors.color_1F2021
                                layer.enabled: true
                                layer.effect: OpacityMask{
                                    maskSource: Rectangle {
                                        width: 120
                                        height: 120
                                        radius: 6
                                    }
                                }

                                Image {
                                    id: image
                                    anchors.fill: parent
                                    fillMode: Image.PreserveAspectCrop
                                    cache: true
                                    asynchronous: true

                                    // TODO: 这里使用file:///指定绝对路径，目的是防止qml自动在路径前加qrc:前缀，是否存在windows适配问题需再确认
                                    source: draftManager.isFileExist(model.coverPath) ? "file:///" + model.coverPath : ""
                                    visible: image.source !== ""

                                    width: 120
                                    height: 120
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 6
                                    color: Colors.transparent
                                    border.color: Colors.color_FFFFFF_30
                                    border.width: 2
                                    visible: draftArea.containsMouse
                                }

                                Image {
                                    id: selectIcon
                                    anchors.right: parent.right
                                    anchors.rightMargin: 8
                                    anchors.top: parent.top
                                    anchors.topMargin: 8
                                    source: isSelected ? "qrc:/app_qrc/icons/media_selected.svg" : "qrc:/icons/media_normal.svg"
                                    visible: control.showDraftSelectState
                                    width: 20
                                    height: 20
                                    sourceSize: Qt.size(20, 20)
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    acceptedButtons: Qt.RightButton
                                    propagateComposedEvents: true

                                    onClicked: (mouse) => {
                                        if (control.showDraftSelectState) {
                                            // 多选模式：未选中时先选中该项，再弹出菜单
                                            if (!isSelected) {
                                                draftListViewModel.appendSelectedDraftId(model.id)
                                                eventTracker.trackEvent("pccut_draft_batch_delete_click", {"button_type": "select", "use_method": "draft"})
                                            }
                                            batchContextMenu.listModel.clear()
                                            batchContextMenu.listModel.append({"title": qsTr("pccut_draft_delete"), "type": 0})
                                            var relativePos = parent.mapToItem(batchContextMenu.parent, mouse.x, mouse.y)
                                            batchContextMenu.x = relativePos.x
                                            batchContextMenu.y = relativePos.y
                                            batchContextMenu.open()
                                            return
                                        }
                                        openDraftOperatePopup(draftOperatePopupLoader, parent, mouse.x, mouse.y)
                                    }

                                }
                            }

                            Rectangle {
                                id: textRect
                                Layout.fillWidth: true
                                height: 16
                                Layout.topMargin: 12
                                color: Colors.transparent

                                Text {
                                    id: titleText
                                    anchors.fill: parent
                                    color: Colors.color_FFFFFF
                                    font.pixelSize: 12
                                    text: model.draftName
                                    elide: Text.ElideMiddle
                                    horizontalAlignment: Text.AlignLeft
                                    MouseArea {
                                        id: hoverArea
                                        anchors.fill: parent
                                        hoverEnabled: true

                                        onEntered: {
                                            toolTipLoader.active = true
                                            if (toolTipLoader.item) toolTipLoader.item.visible = true
                                        }
                                        onExited: {
                                            if (toolTipLoader.item) toolTipLoader.item.visible = false
                                            toolTipLoader.active = false
                                        }
                                        onDoubleClicked: {
                                            titleText.visible = false
                                            textEdit.open()
                                            valueTextInput.selectAll()
                                        }
                                           
                                    }
                                    Loader {
                                        id: toolTipLoader
                                        active: false
                                        sourceComponent: ToolTip {
                                            x: -(width - imageClip.width) / 2
                                            y: titleText.height + sizeLabel.height
                                            opacity: 0
                                            delay: 500
                                            background: Rectangle {
                                                border.color: Colors.color_444444
                                                border.width: 0.5
                                                color: Colors.color_141414_85
                                                radius: 4
                                            }
                                            contentItem: Text {
                                                text: model.draftName
                                                color: Colors.color_EEEEEE
                                            }
                                            Behavior on opacity {
                                                NumberAnimation {
                                                    duration: 300
                                                }
                                            }
                                            onVisibleChanged: {
                                                if (visible) {
                                                    opacity = 1.0
                                                } else {
                                                    opacity = 0.0
                                                }
                                            }
                                        }
                                    }
                                }
                                Popup {
                                    id: textEdit
                                    width: textRect.width
                                    height: textRect.height
                                    anchors.centerIn: textRect
                                    padding: 0

                                    property string originalName: ""

                                    background: Rectangle{
                                        color: Colors.color_transparent
                                    }

                                    TextInput {
                                        id: valueTextInput
                                        width: parent.width

                                        color: Colors.color_FFFFFF
                                        selectedTextColor: Colors.color_141414
                                        selectionColor: Colors.color_EEEEEE
                                        cursorDelegate: Rectangle {
                                            id: cursor
                                            width: 2
                                            height: 17
                                            color: Colors.color_EEEEEE
                                            Timer {
                                                id: cursorTimer
                                                interval: 500
                                                running: valueTextInput.activeFocus
                                                repeat: true
                                                onTriggered: cursor.visible = !cursor.visible
                                            }
                                        }
                                        font.pixelSize: 12
                                        readOnly: false
                                        selectByMouse: true
                                        maximumLength: 50
                                        focus: true
                                        clip: true
                                        text: model.draftName
                                        horizontalAlignment: Text.AlignLeft

                                        onTextChanged: {
                                            var filteredText = CommonUtils.sanitizeString(valueTextInput.text);

                                            if (valueTextInput.text !== filteredText) {
                                                var cursorPos = valueTextInput.cursorPosition;
                                                valueTextInput.text = filteredText;
                                                valueTextInput.cursorPosition = Math.max(0, cursorPos - 1);
                                            }
                                        }

                                        Keys.onPressed: (event) => {
                                            if (event.key === Qt.Key_Return) {
                                                textEdit.close()
                                            }
                                        }

                                        Keys.onEscapePressed: {
                                            valueTextInput.text = textEdit.originalName
                                            textEdit.close()
                                        }
                                    }
                                    onOpened: {
                                        originalName = titleText.text
                                        valueTextInput.forceActiveFocus()
                                        valueTextInput.cursorPosition = valueTextInput.length
                                    }

                                    onClosed: {
                                        // titleText.visible = true

                                        var str = Tools.formatString(valueTextInput.text)
                                        
                                        if(str.length === 0) {
                                            toast.showToast(qsTr("pccut_draft_name_invalid"))
                                            Qt.callLater(function() {
                                                valueTextInput.text = titleText.text
                                                textEdit.open()
                                            })

                                            return
                                        } 

                                        // 检验字符合法性，目前不检查字符，但后续可能需要检查，所以可以暂时不删
                                        // else if(!Tools.checkStringValidity(str)) {
                                        //     messageTips(MessageType.NAME_INVALID)
                                        // }
                                        else if(!draftManager.renameDraft(index, str)) {
                                            toast.showToast(qsTr("pccut_files_missing_samename"))
                                            Qt.callLater(function() {
                                                valueTextInput.text = titleText.text
                                                textEdit.open()
                                            })
                                            return
                                        }
                                        titleText.visible = true
                                    }
                                }

                            }

                            Text {
                                // 大小及时长
                                id: sizeLabel
                                Layout.fillWidth: true
                                Layout.topMargin: 4
                                color: Colors.color_666666
                                font.pixelSize: 11
                                // 遍历子文件夹操作如果能缓存，理论上还能加快十几秒
                                text: model.displayText
                            }
                        }

                        Loader {
                            id: draftOperatePopupLoader
                            active: false
                            sourceComponent: DraftOperatePopup {
                                closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
                                onClickType: (modeType) => {
                                    if (modeType === Instance.DRAFT_OPERATE_TYPE.TYPE_OF_RENAME) {
                                        // 重命名
                                        eventTracker.trackEvent("pccut_draft_rename_click");
                                        titleText.visible = false
                                        textEdit.open()
                                        valueTextInput.selectAll()
                                    } else if(modeType === Instance.DRAFT_OPERATE_TYPE.TYPE_OF_COPY) {
                                        // 复制草稿
                                        eventTracker.trackEvent("pccut_draft_copy_click");
                                        var copyResult = draftManager.copyDraft(index)
                                        if(copyResult === 0) {
                                            list_view.positionViewAtBeginning()
                                            messageTips(MessageType.COPY_SUCCESSED)
                                        }else if(copyResult === 1){
                                            messageTips(MessageType.COPY_FAILED_DAMAGED_DRAFT)
                                        }else if(copyResult === 2){
                                            messageTips(MessageType.COPY_FAILED_INSUFFICIENT_SPACE)
                                        }
                                    } else if(modeType === Instance.DRAFT_OPERATE_TYPE.TYPE_OF_DELETE) {
                                        // 删除草稿
                                        eventTracker.trackEvent("pccut_draft_delete_click");
                                        globalSignal.draftDeleteConfirm(index)
                                    } else if (modeType === Instance.DRAFT_OPERATE_TYPE.TYPE_OF_PATH) {
                                        fileOperator.openExplorerAtFile(draftManager.getDraftDir(index))
                                    }
                                }
                                onClosed: {
                                    modeType = Instance.DRAFT_OPERATE_TYPE.TYPE_OF_NONE
                                    draftOperatePopupLoader.active = false
                                }
                            }
                        }

                        Item {
                            id: moreButton
                            width: 20
                            height: 20
                            visible: false

                            x: 92
                            y: 92
                            anchors {
                                rightMargin: 8
                                bottomMargin: 8
                            }

                            Image {
                                anchors.centerIn: parent
                                source: "qrc:/icons/icon_more.svg"
                                sourceSize: Qt.size(20, 20)
                                asynchronous: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton
                                onClicked: {
                                    openDraftOperatePopup(draftOperatePopupLoader, parent, 7, 8)
                                }
                            }
                        }
                    }
                }
            }
        }

        DragSelectOverlay {
            id: draftDragSelect
            property bool dragTracked: false
            targetGridView: list_view
            showSelectState: control.showDraftSelectState
            columns: control.columns
            delegateWidth: control.delegateWidth
            delegateHeight: control.delegateHeight
            itemWidth: control.itemWidth
            itemHeight: control.itemHeight
            onSelectStateChanged: (active) => {
                if (active) {
                    homeView.showDraftSelectState = true
                    eventTracker.trackEvent("pccut_draft_batch_delete_click", {"button_type": "select", "use_method": "draft"})
                    dragTracked = true
                }
            }
            onDragSelectUpdated: (selectRect) => {
                var adjusted = Qt.rect(selectRect.x, selectRect.y - list_view.originY, selectRect.width, selectRect.height)
                var originX = draftDragSelect.startX
                var originY = draftDragSelect.startY + draftDragSelect.startContentY - list_view.originY
                draftListViewModel.dragSelect(adjusted, control.columns, control.delegateWidth, control.delegateHeight, control.itemWidth, control.itemHeight, originX, originY)
                if (!dragTracked) {
                    eventTracker.trackEvent("pccut_draft_batch_delete_click", {"button_type": "select", "use_method": "draft"})
                    dragTracked = true
                }
            }
        }

        Connections {
            target: draftDragSelect
            function onPressedChanged() {
                if (draftDragSelect.pressed) {
                    draftDragSelect.dragTracked = false
                }
            }
        }
    }

    Loader {
        anchors.fill: parent
        sourceComponent: draftManager.draftCount <= 0 ? emptyPage : undefined
    }

    Connections {
        target: draftManager
        function onCurrentDraftChanged() {
            if(draftManager.currentDraft === -1) {
                list_view.positionViewAtBeginning()
            }
        }
    }
    Component {
        id: emptyPage
        Rectangle {
            anchors.fill: parent
            color: Colors.color_141414
            Image {
                id: image
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.topMargin: 100
                anchors.top: parent.top
                source: "qrc:/icons/icon_draft_empty.svg"
                sourceSize: Qt.size(108 ,67)
            }
            Text {
                anchors.horizontalCenter: image.horizontalCenter
                anchors.top: image.bottom
                anchors.topMargin: 24
                text: qsTr("pccut_quick_clipped_works_saved")
                color: Colors.color_CCCCCC
            }
        }
    }

    OperatePopup {
        id: batchContextMenu
        shaderSourceItem: control
        width: 123
        onClickType: (modeType) => {
            if (modeType === 0) {
                if (draftListViewModel.selectCount > 0) {
                    eventTracker.trackEvent("pccut_draft_batch_delete_click", {"button_type": "delete", "use_method": "draft"})
                    homeView.currentDraftIndex = -1
                    deleteConfirmPopupLoader.active = true
                }
            }
        }
    }
}
