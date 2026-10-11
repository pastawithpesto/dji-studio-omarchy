import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.3
import Qt5Compat.GraphicalEffects
import Config 1.0
import Controls 1.0
import ShortcutAction 1.0
import FilterListModel 1.0
import UserGuideFilterListModel 1.0
import FilterCategorysModel 1.0
import app_qrc 1.0
import QtQuick.Dialogs
import ImportLutHandler 1.0
import MaterialDragController 1.0
import FilterDragBussiness 1.0

Item {
    id: control
    objectName: "filterListView"

    // 边距
    property int padding: 12
    // Item 间隔
    property int spacing: 12
    // Item 宽
    property int itemWidth: 80
    // Item 高
    property int itemHeight: 100
    // Delegate 宽
    property int delegateWidth: itemWidth + spacing
    // Delegate 高
    property int delegateHeight: itemHeight + spacing
    // 列数根据可视宽度和 Item 宽度计算
    property int columns: (list_view.width + spacing - padding) / delegateWidth < 1 ? 1 : (list_view.width + spacing - padding) / delegateWidth

    property int sectionHeaderHeight: isShowImportList ? 0 : 43
    property FilterCategorysModel allFilterCategoryModels: allFilterModels.cateogrysModel
    property FilterListModel allFilterModels: null
    property UserGuideFilterListModel userguideFilterModels: UserGuideFilterListModel {}  // 新建一个listModel即可
    // 拖拽滤镜进行中：暂停列表滚动，避免命中片段被销毁
    property bool filterDragActive: false
    property ImportLutHandler importHandler: allFilterModels.importHandler

    property bool isShowImportList: isShowImportTab && allFilterModels.importFilterCount > 0

    property Text curDisplayText// 当前选中的Item的显示文本控件
    property LightTextEditPopup curTextField// 当前选中的Item的文本编辑器
    property string curName// 当前选中Item的名称
    // 是否显示导入tab
    property bool isShowImportTab: allFilterCategoryModels.selectIndex < 0
    readonly property var customLutNameFilters: [
        "All (*.CUBE)"
    ]

    Connections {
        target: allFilterModels
        function onImportedResult(errorCount, successCount) {
            importProgressLoader.item.close();
            importProgressLoader.active = false
        }
    }

    Connections {
        target: importProgressLoader.item
        function onCancelClick(){
            importHandler.cancel();
        }
    }

    Loader {
        id: importProgressLoader
        active: false
        sourceComponent: LightLoadPopup {
            id: importLoading
            processCount: importHandler.finishCount
            totalCount: importHandler.allCount
            text: qsTr("pccut_filter_cube_add_loading_tip") + "..." + "(" + importHandler.finishCount + "/" + (importHandler.allCount) + ")"
        }
    }

    function clickSelectHandle(point) {
        var isInCover = false;
        var gridPoint = filterTab.mapToItem(list_view.contentItem, point.x, point.y);
        // 点击到右侧的滚动条
        if (list_view.width - gridPoint.x < 10) {
            isInCover = true;
        } else {
            const selectPoint = Qt.point(gridPoint.x, gridPoint.y);
            const cellSize = Qt.size(control.delegateWidth, control.delegateHeight);
            const itemRect = Qt.rect(0, 0, control.itemWidth, control.itemHeight);
            isInCover = allFilterModels.isInCover(selectPoint, sectionHeaderHeight, columns, cellSize, itemRect);
        }
        // 如果没有点击在封面上就取消选中
        if (!isInCover) {
            allFilterModels.clickAtIndex(-1, true)
            allFilterModels.selectedFilterIndex = -1
        }
    }

    Item{
        visible: editorManager.isInUserGuideStatus
        z:3
        width: 100
        height: 100
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            topMargin: sectionHeaderHeight
            bottom: parent.bottom
            leftMargin: control.padding
        }

        clip: true
        ListView {
            id: listView
            anchors.fill: parent
            model: userguideFilterModels
            delegate: itemDelegateComponent
        }
    }
    // 导入按钮
    Item {
        id: topBarItem
        width: parent.width
        height: 57
        visible: isShowImportList
        LeftIconButton {
            id: importBtn

            property bool isImportButtonEnabled: allFilterModels.importFilterCount < allFilterModels.maxImportLutCount

            height: 24
            rowSpace: 2
            width: 16 + 8 * 2 + textLabelWidth + 2
            x: 12
            y: 16
            enabled: isImportButtonEnabled
            hoverEnabled: isImportButtonEnabled
            bgRadius: 4
            normalColor: ColorsConfig.color_brand_10
            hoverColor: ColorsConfig.color_brand_20
            textColor: enabled ? ColorsConfig.color_brand : "#6F111F"
            enableIconColor: true
            iconColor: textColor
            text: qsTr("pccut_menu_import")
            source: "qrc:/app_qrc/icons/editor_material_add.svg"
            onClickBtn: {
                importLutDlgLoader.active = true
                var importLutDlg = importLutDlgLoader.item
                importLutDlg.open()
            }
        }
    }
    // 套一层 Item clip 剪去 ListView 尾巴上多余的部分不显示出来
    Item {
        id: filterListContent
        visible: !importFilterItem.showTab && !emptyPanel.visible && (!editorManager.isInUserGuideStatus)
        anchors {
            left: parent.left
            right: parent.right
            top: topBarItem.visible ? topBarItem.bottom : parent.top
            bottom: parent.bottom
            leftMargin: control.padding
        }
        clip: true

        ListView {
            id: list_view
            objectName: actionableItemName.filterContentListView
            //如果用户电脑配置较差，由于动画只有250ms，从头到尾滚动时可能无法加载所有delegate，导致高度出现错误，这会导致滤镜列表错位
            //现在加上700像素的缓存，这部分的delegate作为缓存不会实时创建，减少一次性创建的delegate，可以避免上面的问题
            cacheBuffer: 700
            width: parent.width
            // 高度多一个 delegate 放置 footer，防止末尾的一行滑倒底部后隐藏
            // 多出来的一部分会被外部 Item clip 掉
            // height: parent.height
            height: parent.height + control.delegateHeight + control.spacing
            // flickableDirection: Flickable.HorizontalAndVerticalFlick
            // boundsBehavior: Flickable.StopAtBounds
            headerPositioning: ListView.OverlayHeader
            // 底部多一个 footer 撑高可显示范围，防止末尾的一行滑倒底部后隐藏
            footerPositioning: ListView.InlineFooter

            ScrollBar.vertical: ScrollBar {
                // padding 加上 ListView 多出来的一部分
                bottomPadding: padding + (control.delegateHeight + control.spacing)
                Component.onCompleted: {
                    contentItem.color = Colors.color_444444;
                }
            }
            footer: Item {
                // 竖向的 ListView 宽度无所谓
                width: control.delegateWidth
                // 高度大于等于 delegate 高度才能保证显示
                height: control.delegateHeight * (isShowImportTab ? 2 : 3) - control.spacing - 8
            }
            model: allFilterModels
            boundsBehavior: Flickable.StopAtBounds
            flickDeceleration: 7000

            // 因为鼠标是添加每个片段上, 列表滑动 片段可能被销毁导致拖拽失效
            interactive: !control.filterDragActive
            onContentYChanged: {
                var indexInt = indexAt(0, contentY + sectionHeaderHeight);
                var section = allFilterModels.sectionFromItem(indexInt);
                if (!isShowImportList && section >= 0 && scrollToTopAnimation.running === false) {
                    allFilterCategoryModels.selectIndex = section;
                }
            }

            property real animationY: 0
            PropertyAnimation {
                id: scrollToTopAnimation
                target: list_view
                property: "contentY"
                duration: 250
                from: list_view.contentY
                to: list_view.animationY
                easing.type: Easing.OutQuad
            }

            Component.onCompleted: {
                allFilterModels.fetchFilterData();
                allFilterCategoryModels.viewClickSection.connect(function (section) {
                    var y = 0;
                    for (var i = 0; i < section; i++) {
                        var count = allFilterModels.itemCountAtSection(i);
                        var height = Math.ceil(count * 1.0 / control.columns) * delegateHeight;
                        y += height;
                        y += sectionHeaderHeight;
                    }
                    animationY = y;
                    scrollToTopAnimation.start();
                });
            }
            section {
                property: "groupName"
                criteria: ViewSection.FullString
                delegate: Item {
                    width: list_view.width - control.padding
                    height: sectionHeaderHeight
                    visible: !isShowImportList
                    Text {
                        text: section
                        font.pixelSize: 12
                        anchors.topMargin: 16
                        anchors.top: parent.top
                        color: Colors.color_EEEEEE
                    }
                }
                labelPositioning: ViewSection.InlineLabels
            }
            delegate: itemDelegateComponent
        }

    }

    Component{
        id: itemDelegateComponent
    Item {
        id: list_item_root
        objectName: actionableItemName.delegateItemForFilterContentListView + index
        property real currentProgress: editorManager.isInUserGuideStatus ? 2 : (progress === " " ? -1 : progress)

        width: control.delegateWidth
        // 每行第一个 Item 有高度，后面的没高度，这样就能排列到一行
        // 因为 0 高度 Item 在末尾，超出范围 visible 就置为 false 了，所以才需要 footer 撑高多显示一行的内容
        // delegate 高度不一致会导致滚动条滚动时长度变化
        height: (model.groupIndex % control.columns === 0) ? control.delegateHeight : 0

        // 放置真正的内容
        Item {
            // 根据列号计算 x
            x: (model.groupIndex % control.columns) * control.delegateWidth
            // 负高度就能和每行第一个的 y 一样
            y: (model.groupIndex % control.columns !== 0) ? -control.delegateHeight : 0
            width: control.itemWidth
            height: control.itemHeight

            LightClipRectangle {
                id: imageClip
                radius: [6, 6, 6, 6]
                width: control.itemWidth
                height: control.itemWidth
                color: Colors.color_444444
                objectName: actionableItemName.downloadForFilter + index
                Image {
                    id: clipSource
                    anchors.fill: parent
                    // TODO: Fread 完善损坏图标
                    source: filterAdd.isCanAdd ? imageUrl : "qrc:icons/ic_resource_damaged.png"
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    fillMode: Image.PreserveAspectFit
                    Rectangle {
                        id: rectangle
                        visible: allFilterModels.selectedFilterIndex === index
                        anchors.fill: parent
                        radius: 6
                        border.color: ColorsConfig.color_brand
                        border.width: 2
                        color: Colors.transparent
                    }
                }

                LightClipRectangle {
                    id: downloadIcon
                    visible: currentProgress <= 1 && !isShowImportTab
                    width: 20
                    height: 20
                    radius: [10,10,10,10]
                    anchors.right: parent.right
                    anchors.rightMargin: 4
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 4

                    ShaderEffectSource {
                        id: shaderSource
                        sourceItem: clipSource
                        sourceRect: Qt.rect(downloadIcon.x, downloadIcon.y, downloadIcon.width, downloadIcon.height)
                        live: true
                        smooth: true
                    }

                    // 高斯调节
                    FastBlur {
                        anchors.fill: parent
                        source: shaderSource
                        radius: 48
                    }
                    Rectangle {
                        anchors.fill: parent
                        color: Colors.color_444444_50
                        radius: 10
                    }
                }
                //鼠标掠过效果
                MouseArea {
                    id: mouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    drag.target: materialDragController.dragCoverItem  // 必须设置
                    // 用户开始点击的位置
                    property point pressedPoint: Qt.point(0, 0)
                    onEntered: {
                    }
                    onPressed: (mouse) => {
                        pressedPoint = Qt.point(mouseX, mouseY);
                    }
                    onPositionChanged: (mouse) => {
                        mouse.accepted = false;
                        var mousePos = mapToItem(filterAdd, mouseArea.mouseX, mouseArea.mouseY);
                        filterAdd.containsMouse = filterAdd.contains(mousePos);
                        if (!pressed) {
                            return;
                        }
                        // 未下载完成或损坏不允许拖拽
                        if (currentProgress <= 1 || !filterAdd.isCanAdd) {
                            return;
                        }
                        // 增加容错,某些鼠标一点击就有位置移动,鼠标移动多少才认为是拖动
                        let distance = 2;
                        if (Math.abs(pressedPoint.x - mouseX) < distance && Math.abs(pressedPoint.y - mouseY) < distance && !materialDragController.visible) {
                            return;
                        }
                        if (!materialDragController.visible) {
                            editorManager.pause();
                            if (!editorManager.isInUserGuideStatus) {
                                allFilterModels.hoverAtIndex(index, true);
                            }
                            materialDragController.visible = true;
                            control.filterDragActive = true;
                            var pos = mapToItem(lightWindow.contentItem, mouseX, mouseY);
                            materialDragController.mousePoint = pos;
                        }
                        var posInWindow = mapToItem(lightWindow.contentItem, mouseX, mouseY);
                        materialDragController.mousePoint = posInWindow;
                    }
                    onClicked: (mouse) => {
                           if (filterAdd.visible) {
                               editorDraftManager.saveDraft();
                           } else if (download_state_img.visible) {
                               allFilterModels.download(index);
                           }
                            allFilterModels.clickAtIndex(index, false);
                            allFilterModels.selectedFilterIndex = index;
                    }
                    onExited: {
                        if (currentProgress > 1) {
                            allFilterModels.hoverAtIndex(index, true);
                        }
                    }
                    onReleased: {
                        if (materialDragController.visible) {
                            materialDragController.visible = false;
                        }
                        control.filterDragActive = false;
                    }
                    onCanceled: {
                        if (materialDragController.visible) {
                            materialDragController.visible = false;
                        }
                        control.filterDragActive = false;
                    }
                }

                // 处理封面拖拽的组件
                MaterialDragController {
                    id: materialDragController
                    visible: false
                    parentItem: lightWindow.contentItem // 必须设置: 确保可以在整个窗口中进行拖拽
                    dragBusinessManager: FilterDragBussiness {
                        view: tracks.multiTrackView
                        slug: model.slug
                        resourcePath: model.configPath
                        factor: 0.8
                    }
                    dragCoverItem: Rectangle {
                        height: 72
                        width: 72
                        radius: 6
                        border {
                            width: 1.5
                            color: ColorsConfig.color_brand
                        }
                        color: Colors.color_000000
                        Image {
                            anchors.fill: parent
                            anchors.margins: parent.border.width
                            source: imageUrl
                            fillMode: Image.PreserveAspectCrop
                            layer.enabled: true
                            layer.effect: OpacityMask {
                                maskSource: Rectangle {
                                    width: 72
                                    height: 72
                                    radius: 6
                                }
                            }
                        }
                    }
                    dragItemInTrack: Rectangle {
                        height: 56
                        width: 56
                        radius: 6
                        color: Colors.color_1E1E1E
                        Image {
                            anchors.fill: parent
                            source: imageUrl
                            fillMode: Image.PreserveAspectCrop
                            layer.enabled: true
                            layer.effect: OpacityMask {
                                maskSource: Rectangle {
                                    width: 56
                                    height: 56
                                    radius: 6
                                }
                            }
                        }
                    }
                }

                Image {
                    id: download_state_img
                    source: "qrc:/icons/download_need.svg"
                    anchors.centerIn: downloadIcon
                    visible: currentProgress < 0 && !isShowImportTab
                    sourceSize: Qt.size(20, 20)
                    objectName: actionableItemName.downloadIconForFilter + index

                    MouseAreaWithHover {
                        contentItemY: (20)
                        text: qsTr("pccut_filter_download")
                        onClicked: {
                            allFilterModels.download(index);
                        }
                    }
                }
                // 已添加标签
                Rectangle {
                    id: addedTag
                    visible: editorManager.filterSlugList.indexOf(model.slug) != -1
                    radius: 4
                    color: Colors.color_000000_50
                    height: 20
                    width: addedTagText.width + 8
                    x: 4
                    y: 4
                    Text {
                        id: addedTagText
                        text: qsTr("pccut_media_added")
                        color: Colors.color_EEEEEE
                        font.pixelSize: 10
                        x: 4
                        y: 3
                    }
                }

                Image {
                    id: filterAdd
                    property bool containsMouse: false
                    property bool isCanAdd: isShowImportTab ? !model.isDamaged : true
                    source: "qrc:/app_qrc/icons/filter_add.svg"
                    visible: (mouseArea.containsMouse) && currentProgress > 1 && isCanAdd
                    anchors.centerIn: downloadIcon
                    sourceSize: Qt.size(20, 20)
                    onVisibleChanged: {
                        if (visible) {
                            allFilterModels.hoverAtIndex(index, false);
                        }
                    }
                    MouseArea {
                        id: addMouseArea
                        anchors.fill: parent
                        onClicked: {
                            editorManager.pause();
                            if(!editorManager.isInUserGuideStatus){
                                allFilterModels.addFilterFromIndex(index);
                            }else{
                                userguideFilterModels.addFilterFromIndex(0);
                                globalSignal.nextStepInAllGuide();
                            }

                            editorDraftManager.saveDraft();
                        }
                        LightToolTip {
                            id: filterAddTip
                            visible: filterAdd.visible && filterAdd.containsMouse
                            tip: qsTr("pccut_filter_add")
                        }
                    }
                }

                Image {
                    id: rotatingImage
                    width: 16
                    height: 16
                    source: "qrc:/icons/ic_download_loading.png"
                    visible: currentProgress >= 0 && currentProgress <= 1
                    anchors.centerIn: downloadIcon
                    smooth: true
                    RotationAnimation on rotation {
                        loops: Animation.Infinite
                        running: rotatingImage.visible
                        from: 0
                        to: 360
                        duration: 1000 // 持续时间为1秒
                    }
                    MouseAreaWithHover {
                        contentItemY: (20)
                        text: qsTr("pccut_filter_download")
                        onClicked: {
                            allFilterModels.download(index);
                        }
                    }
                }
            }

            Text {
                id: displayText
                width: rectangle.width
                text: name
                topPadding: 4
                anchors.top: imageClip.bottom
                anchors.left: imageClip.left
                font.pixelSize: 12
                color: Colors.color_959595
                elide: Text.ElideMiddle
                visible: !textField.visible

                // 存在添加后不能编辑的问题，暂时屏蔽
                MouseArea {
                    id: textMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    propagateComposedEvents: true
                    onEntered: {
                        if (displayText.implicitWidth > displayText.width)
                        {
                            nameToolTipLoader.active = true
                            var toolTip = nameToolTipLoader.item
                            toolTip.visible = true; // 显示ToolTip

                            var newPoint = textMouseArea.mapToItem(toolTip.parent, textMouseArea.x, textMouseArea.y)

                            // 显示在文本位置
                            toolTip.x = newPoint.x
                            toolTip.y = newPoint.y
                            toolTip.tip = displayText.text; // 鼠标进入时设置ToolTip的文本
                        }
                    }
                    onExited: {
                        nameToolTipLoader.active = false
                    }
                }

                Loader {
                    id: nameToolTipLoader
                    // 默认不加载
                    active: false
                    // 完整名称ToolTip
                    sourceComponent: LightToolTip{
                                            }
                }
            }

            LightTextEditPopup {
                id: textField
                x: displayText.x
                y: displayText.y
                width: displayText.width
                height: displayText.height
                popTopPadding: 4
                visible: false
                maximumLength: 32
                closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
                onOpened: {
                    textField.autoFocus()
                    textField.textInput.selectAll()
                }

                onClosed: {
                    visible = false
                    displayText.visible = true
                    var str = Tools.formatString(text)
                    if (str.length === 0){
                        // 不能输入空文本
                        return;
                    }
                    allFilterModels.renameImportedLut(str, model.groupIndex)
                }
            }

            MouseArea {
                id: mouseArea2
                anchors.fill: parent
                acceptedButtons: Qt.RightButton
                onClicked: (mouse) => {
                    if (mouse.button === Qt.RightButton) {
                        // 调用右键，先选中
                        allFilterModels.setSelectedFilterIndex(index)
                        var bLutSelected = allFilterModels.isLutSelected()
                        if (!bLutSelected) {
                            return;
                        }

                        if (contextMenuLoader.active == false)
                        {
                            contextMenuLoader.active = true
                        }

                        // 右键操作，先赋值当前
                        curDisplayText = displayText
                        curTextField = textField
                        curName = name

                        // 显示右键菜单
                        var contextMenu = contextMenuLoader.item
                        var newPoint = mouseArea2.mapToItem(contextMenu.parent, mouseX, mouseY);
                        contextMenu.listModel.append({"title": qsTr("pccut_filter_cube_add_rename"), "type": Instance.CUSTOM_LUT_OPERATE_TYPE.TYPE_OF_RENAME});
                        contextMenu.listModel.append({"title": qsTr("pccut_filter_cube_add_delete"), "type": Instance.CUSTOM_LUT_OPERATE_TYPE.TYPE_OF_DELETE});

                        contextMenu.x = newPoint.x;
                        contextMenu.y = newPoint.y;
                        contextMenu.open();
                    }
                }
            }
        }
    }
    }

    // 删除自定义LUT的快捷键
    CShortcut {
        action: ShortcutAction.DELETE
        enabled: root.visible
        onActivated: {
            allFilterModels.deleteSelectedCustomLut()
        }
    }

    Loader {
        id: contextMenuLoader
        active: false
        sourceComponent: OperatePopup {
            parent: Overlay.overlay
            property string slug: ""
            property bool isClicked: false
            shaderSourceItem: mainPanel
            onClickType: (modeType) => {
                switch (modeType) {
                case Instance.CUSTOM_LUT_OPERATE_TYPE.TYPE_OF_RENAME: {
                         curTextField.text = curName
                         curTextField.visible = true
                         curDisplayText.visible = false
                    }
                    break;
                case Instance.CUSTOM_LUT_OPERATE_TYPE.TYPE_OF_DELETE: {
                        allFilterModels.deleteSelectedCustomLut()
                    }
                    break;
                default:
                    break;
                }
                isClicked = true
            }
            onClosed: {
                if (!isClicked) {
                    eventTracker.trackEvent("pccut_assets_rightclick", {"function": "no"})
                }
                isClicked = false
                contextMenuLoader.active = false
            }
        }
    }
        Item {  // 新增容器
            id: importFilterItem
            property bool showTab: isShowImportTab && allFilterModels.importFilterCount === 0
            visible: showTab
            anchors.fill: parent  // 填满 Loader
            Rectangle {
                anchors.centerIn: parent
                width: 180
                height: descText.y + descText.height + 27
                radius: 8
                color: emptyMouse.containsMouse ? Colors.color_FFFFFF_10 : Colors.color_2F3032
                border {
                    width: 1
                    color: Colors.color_454649
                }
                MouseArea {
                    id: emptyMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        importLutDlgLoader.active = true
                        var importLutDlg = importLutDlgLoader.item
                        importLutDlg.open()
                    }
                }
                // 44x44图标
                Image {
                    id: icon
                    anchors {
                        horizontalCenter: parent.horizontalCenter
                        top: parent.top
                        topMargin: 43
                    }
                    width: 44
                    height: 44
                    source: "qrc:/icons/filter/ic_lut_import.svg"
                    Text {
                        text: "LUT"
                        anchors.centerIn: parent
                        width: 23
                        height: 14
                        font.family: "Roboto Condensed"
                        font.pixelSize: 14
                        font.weight: 900
                        color: Colors.color_EEEEEE
                    }
                }

                // "提取CUBE"文字
                Text {
                    id: titleText
                    text: qsTr("pccut_filter_cube_add_tab_name")
                    anchors {
                        horizontalCenter: parent.horizontalCenter
                        top: icon.bottom
                        topMargin: 12
                    }
                    width: 122
                    font.pixelSize: 12
                    color: Colors.color_EEEEEE
                    horizontalAlignment: Text.AlignHCenter
                }

                // 描述文字
                Text {
                    id: descText
                    text: qsTr("pccut_filter_cube_add_tip")
                    anchors {
                        horizontalCenter: parent.horizontalCenter
                        top: titleText.bottom
                        topMargin: 8
                    }
                    width: 122
                    font.pixelSize: 11
                    color: Colors.color_999999
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }
            }
        }

    Loader {
        id: importLutDlgLoader
        active: false
        sourceComponent: FileDialog {
            id: importLutDlg
            fileMode: FileDialog.OpenFiles
            nameFilters: customLutNameFilters
            onAccepted: {
                importProgressLoader.active = true;
                importProgressLoader.item.open();
                console.log("importLutDlg.accepted", importHandler, currentFiles);
                var count = allFilterModels.allowImportCount()
                importHandler.setAllowImportCount(count)
                importHandler.importFilterList(currentFiles)
                importLutDlgLoader.active = false
            }
        }

    }

    // 监听拖拽事件
    DropArea {
        enabled: lightWindow.topPopupCount <= 0 && isShowImportTab
        anchors.fill: parent
        // 拖入时实时过滤
        onEntered: (drag) => {
            // 如果所有文件都不支持，则拒绝拖入
            if (fileOperator.isAllFilesSuffixes(drag.urls, "*.cube")) {
                drag.accepted = false;
            }
        }
        onDropped: (drop) => {
            drop.accept();
            if (drop.hasUrls) {
                importProgressLoader.active = true;
                importProgressLoader.item.open();
                var count = allFilterModels.allowImportCount()
                importHandler.setAllowImportCount(count)
                importHandler.importFilterList(drop.urls)
            }
        }
    }

    EmptyPanel {
        id: emptyPanel
        visible: allFilterModels.state === 2 && !isShowImportTab
        width: parent.width
        height: parent.height
        anchors.centerIn: parent
        no_network_mode: true
        network_request_type: Instance.request_type_audio
        onClick: {
            allFilterModels.fetchFilterData();
        }
    }

    Item {
        id: selectHandle
        parent: UiUtils.getTopParent(control)
        visible: control.visible && allFilterModels.selectedFilterIndex >= 0
        anchors.fill: parent
        PointHandler {
            onGrabChanged: (transition, point) =>  {
                point.accepted = false
                if (point.timeHeld !== 0) {
                    return;
                }
                var mousePoint = point.position
                let needContinue = true
                // 点击了播放器区域
                let pointInPlayerPanel = selectHandle.mapToItem(playerPanel, mousePoint)
                if (playerPanel.contains(pointInPlayerPanel)) {
                    needContinue = false
                }
                if (needContinue) {
                    let pointInSelectHandle = selectHandle.mapToItem(filterTab, mousePoint)
                    if (filterTab.contains(pointInSelectHandle)) {
                        control.clickSelectHandle(pointInSelectHandle)
                    } else {
                        allFilterModels.clickAtIndex(-1, true)
                        control.allFilterModels.selectedFilterIndex = -1
                    }
                }
            }
        }
    }

    Connections {
        target: globalSignal
        function onAddLocalFilter(){
            editorManager.pause();
            userguideFilterModels.addFilterFromIndex(0);
            editorDraftManager.saveDraft();
        }

        function onRefreshMaterialView() {
            allFilterModels.refresh()
        }
        function onVideoSelected(info) {
            allFilterModels.selectedFilterIndex = -1
        }

        function onFilterDownloadFinish(selectIndex){
            // clickAtIndex 里有判重逻辑导致没有生效, 所以有了取消选中, 再选中的逻辑
            allFilterModels.selectedFilterIndex = -1
            allFilterModels.clickAtIndex(selectIndex, false)
            allFilterModels.selectedFilterIndex = selectIndex
        }

        //草稿切换时，滤镜二级tab切换回第一个
        function onActivedProjectChanged(id) {
            if(draftUIManager.isActiveProjectExist()) {
                allFilterCategoryModels.selectIndex = 0;
                allFilterCategoryModels.clickSection(0);
            }
        }
    }
}
