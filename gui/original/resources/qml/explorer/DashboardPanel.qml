import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.3
import Qt5Compat.GraphicalEffects
import Config 1.0
import Controls 1.0
import DashboardListModel 1.0
import DashboardCategorysModel 1.0
import MaterialDragController 1.0
import DashBoardMoveDragBusiness 1.0
import app_qrc 1.0

/**
 * @author tengsen.zhang
 * @desc 仪表盘模版展示面板
 * @create_date 2024-10-11
 */
Item {
    id: control
    // 边距
    property int padding: 12
    // Item列间隔
    property int columnSpacing: 12
    // Item行间隔
    property int rowSpacing: 30
    // Item 宽
    property int itemWidth: 128
    // Item 高
    property int itemHeight: 72
    // Delegate 宽
    property int delegateWidth: itemWidth + columnSpacing
    // Delegate 高
    property int delegateHeight: itemHeight + rowSpacing
    property int columns: (list_view.width + columnSpacing - padding) / delegateWidth < 1 ? 1 : (list_view.width + columnSpacing - padding) / delegateWidth
    property int sectionHeaderHeight: 43
    property real lastTime: 0.0
    property DashboardCategorysModel dashboardCategorysModel: dashboardListModel.cateogrysModel
    property DashboardListModel dashboardListModel: null

    // 点击背景做取消选中
    function clickBgView(point) {
        var isInCover = false;
        var gridPoint = control.mapToItem(list_view.contentItem, point.x, point.y);
        // 点击到右侧的滚动条
        if (list_view.contentHeight > list_view.height && list_view.width - gridPoint.x < 10) {
            isInCover = true;
        } else {
            const selectPoint = Qt.point(gridPoint.x, gridPoint.y);
            const cellSize = Qt.size(control.delegateWidth, control.delegateHeight);
            const itemRect = Qt.rect(0, 0, control.itemWidth, control.itemHeight);
            isInCover = dashboardListModel.isInCover(selectPoint, sectionHeaderHeight, columns, cellSize,itemRect);
        }
        // 如果没有点击在封面上就取消选中
        if (!isInCover) {
            dashboardListModel.clickAtIndex(-1, true);
            dashboardListModel.selectedDashboardIndex = -1;
        }
    }
    // 套一层 Item clip 剪去 ListView 尾巴上多余的部分不显示出来
    Item {

        visible: dashboardListModel.state === 1
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            bottom: parent.bottom
            leftMargin: control.padding
        }

        clip: true
        ListView {
            id: list_view
            objectName: actionableItemName.dashBoardContentListView
            width: parent.width
            // 高度多一个 delegate 放置 footer，防止末尾的一行滑倒底部后隐藏
            // 多出来的一部分会被外部 Item clip 掉
            height: parent.height + control.delegateHeight + control.rowSpacing
            headerPositioning: ListView.OverlayHeader
            // 底部多一个 footer 撑高可显示范围，防止末尾的一行滑倒底部后隐藏
            footerPositioning: ListView.OverlayFooter
            ScrollBar.vertical: ScrollBar {
                // padding 加上 ListView 多出来的一部分
                bottomPadding: padding + (control.delegateHeight + control.rowSpacing)
                Component.onCompleted: {
                    contentItem.color = Colors.color_444444;
                }
            }
            footer: Item {
                width: control.delegateWidth
                // 高度大于等于 delegate 高度才能保证显示
                height: delegateHeight + control.rowSpacing
            }
            model: dashboardListModel
            onContentYChanged: {
                var indexInt = indexAt(0, contentY + sectionHeaderHeight);
                var section = dashboardListModel.sectionFromItem(indexInt);
                if (section >= 0 && scrollToTopAnimation.running == false) {
                    dashboardCategorysModel.selectIndex = section;
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
                dashboardListModel.fetchDashboardData();
                dashboardCategorysModel.viewClickSection.connect(function (section) {
                    var y = 0;
                    for (var i = 0; i < section; i++) {
                        var count = dashboardListModel.itemCountAtSection(i);
                        var height = Math.ceil(count * 1.0 / control.columns) * delegateHeight;
                        y += height;
                        y += sectionHeaderHeight;
                    }
                    animationY = y;
                    scrollToTopAnimation.start();
                });
            }
            //仪表分组标题
            section {
                property: "groupName"
                criteria: ViewSection.FullString
                delegate: Item {
                    width: list_view.width - control.padding
                    height: sectionHeaderHeight
                    Text {
                        text: section
                        font.pixelSize: 12
                        anchors.top: parent.top
                        anchors.topMargin: 16
                        color: Colors.color_EEEEEE
                    }
                }
                labelPositioning: ViewSection.InlineLabels
            }

            delegate: Item {
                id: list_item_root
                objectName: actionableItemName.delegateItemForDashBoardContentListView + index
                property real currentProgress: progress

                width: control.delegateWidth
                // 每行第一个 Item 有高度，后面的没高度，这样就能排列到一行
                // 因为 0 高度 Item 在末尾，超出范围 visible 就置为 false 了，所以才需要 footer 撑高多显示一行的内容
                // delegate 高度不一致会导致滚动条滚动时长度变化
                height: (model.groupIndex % control.columns === 0) ? control.delegateHeight : 0
                // 是否点击在图片上
                function imageCoverContains(point) {
                    var itemPoint = mapToItem(imageClip, point);
                    return imageClip.contains(itemPoint);
                }
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
                        height: control.itemHeight
                        color: Colors.color_444444
                        Image {
                            id: imageElement
                            anchors.fill: parent
                            source: imageUrl
                            anchors.top: parent.top
                            anchors.horizontalCenter: parent.horizontalCenter
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            Rectangle {
                                visible: dashboardListModel.selectedDashboardIndex === index
                                anchors.fill: parent
                                radius: 6
                                border.color: ColorsConfig.color_brand
                                border.width: 2
                                color: Colors.transparent
                            }
                        }

                        LightClipRectangle {
                            id: downloadIcon
                            visible: currentProgress <= 1 && !addedTag.visible
                            width: 20
                            height: 20
                            radius: [10,10,10,10]
                            anchors.right: parent.right
                            anchors.rightMargin: 4
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 4

                            ShaderEffectSource {
                                id: shaderSource
                                sourceItem: imageElement
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
                        // 已添加标签
                        Rectangle {
                            id: addedTag
                            visible: added
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
                        Connections {
                            target: globalSignal
                            function onUsedStickerChanged() {
                                dashboardListModel.triggerAddedChanged();
                            }
                            function onDashboardDownloadFinish(selectIndex){
                                dashboardListModel.clickAtIndex(selectIndex, false, true)
                                dashboardListModel.selectedDashboardIndex = selectIndex
                            }
                        }
                        //鼠标掠过效果
                        MouseArea {
                            id: mouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            propagateComposedEvents: true
                            drag.target: dashboardDragController.dragCoverItem
                            onEntered: (mouse) =>{
                                var point = Qt.point(mouseArea.mouseX, mouseArea.mouseY);
                                var mousePos = mapToItem(dashboardAdd, mouseArea.mouseX, mouseArea.mouseY);
                                if(!download_state_img.contains(mousePos)) {
                                    dashboardListModel.refreshProgress(index);
                                }
                            }
                            onPressed: {
                                ShortcutObserver.disableAllShortcut(true)
                            }
                            onPositionChanged: (mouse) => {
                                mouse.accepted = false;

                                if(pressed) {
                                    if(!dashboardDragController.visible) {
                                        // 前置检查: 仅已下载的模板可拖拽
                                        if(currentProgress <= 1) {
                                            return;
                                        }
                                        if(dashboardMoveDragBusiness.isEmptyVideoTrack()){
                                            toast.showToast(qsTr("pccut_dashboard_cannot_add"), "tracks");
                                            return;
                                        }
                                        dashboardDragController.visible = true;
                                        var pos = mapToItem(lightWindow.contentItem, mouseX, mouseY);
                                        dashboardDragController.mousePoint = pos;
                                        // 设置被拖拽的 Dashboard 索引
                                        dashboardMoveDragBusiness.dashboardIndex = index;
                                    }

                                    // 持续更新鼠标位置
                                    var posInWindow = mapToItem(lightWindow.contentItem, mouseX, mouseY);
                                    dashboardDragController.mousePoint = posInWindow;
                                }

                                var point = Qt.point(mouseArea.mouseX, mouseArea.mouseY);
                                var mousePos = mapToItem(dashboardAdd, mouseArea.mouseX, mouseArea.mouseY);
                                dashboardAdd.containsMouse = dashboardAdd.contains(mousePos);
                            }
                            onExited: {
                                if (currentProgress > 1) {
                                    dashboardListModel.hoverAtIndex(index, true);
                                }
                            }

                            onReleased: {
                                ShortcutObserver.disableAllShortcut(false)
                                if(dashboardDragController.visible) {
                                    dashboardDragController.visible = false;
                                    dashboardMoveDragBusiness.dashboardIndex = -1;
                                }
                            }

                             onCanceled: {
                                ShortcutObserver.disableAllShortcut(false)
                                if(dashboardDragController.visible) {
                                    dashboardDragController.visible = false;
                                    dashboardMoveDragBusiness.dashboardIndex = -1;
                                }
                            }

                            onClicked: {
                                globalSignal.videoSelected(null);
                                if (dashboardAdd.visible) {
                                    editorDraftManager.saveDraft();
                                } else if (download_state_img.visible) {
                                    dashboardListModel.download(index);
                                    dashboardListModel.selectedDashboardIndex = index;
                                    return;
                                }
                                var isEnd = false;
                                if(addedTag.visible) {
                                    isEnd = true;
                                }
                                dashboardListModel.clickAtIndex(index, isEnd);
                                dashboardListModel.selectedDashboardIndex = index;
                                eventTracker.trackEvent("pccut_dashboard_preview", {"dashboard_tab": model.slug})
                            }
                        }

                        Image {
                            id: dashboardAdd
                            objectName: actionableItemName.dashboardAdd
                            property bool containsMouse: false
                            source: "qrc:/app_qrc/icons/filter_add.svg"
                            visible: (mouseArea.containsMouse) && currentProgress > 1 && !addedTag.visible
                            onVisibleChanged: {
                                if (visible) {
                                    dashboardListModel.hoverAtIndex(index, false);
                                }
                            }
                            anchors.centerIn: downloadIcon
                            sourceSize: Qt.size(20, 20)
                            LightToolTip {
                                id: dashboardAddTip
                                visible: dashboardAdd.visible && dashboardAdd.containsMouse
                                tip: qsTr("pccut_dashboard_add_orbit")
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    globalSignal.videoSelected(null);
                                    editorManager.pause();
                                    dashboardListModel.selectedDashboardIndex = -1;
                                    // 加号添加：目标取时间指示器所在片段，与轨道上已选中的片段无关
                                    dashboardListModel.addDashboardFromIndex(index, false, true);
                                }
                            }
                        }

                        Image {
                            id: download_state_img
                            source: "qrc:/icons/download_need.svg"
                            anchors.centerIn: downloadIcon
                            visible: currentProgress < 0 && !addedTag.visible
                            sourceSize: Qt.size(20, 20)
                            MouseAreaWithHover {
                                anchors.fill: parent
                                contentItemY: (20)
                                text: qsTr("pccut_dashboard_download_orbit")
                                onClicked: {
                                    dashboardListModel.download(index);
                                }
                            }
                        }

                        Image {
                            id: rotatingImage
                            width: 12
                            height: 12
                            sourceSize: Qt.size(width, height)
                            source: "qrc:/icons/ic_download_loading.png"
                            visible: currentProgress >= 0 && currentProgress <= 1 && !addedTag.visible

                            anchors.centerIn: downloadIcon
                            smooth: true
                            RotationAnimation on rotation {
                                loops: Animation.Infinite
                                running: rotatingImage.visible
                                from: 0
                                to: 360
                                duration: 1000 // 持续时间为1秒
                            }
                        }
                    }
                    Text {
                        id: text
                        text: name
                        topPadding: 4
                        anchors.top: imageClip.bottom
                        anchors.left: imageClip.left
                        font.pixelSize: 12
                        color: Colors.color_959595
                    }
                }

                // 处理封面拖拽的组件
                MaterialDragController{
                    id: dashboardDragController
                    visible: false;
                    parentItem: lightWindow.contentItem // 必须设置: 确保可以在整个窗口中进行拖拽
                    dragBusinessManager: DashBoardMoveDragBusiness{
                        id: dashboardMoveDragBusiness
                        view: tracks.multiTrackView
                        listModel: dashboardListModel
                    }

                    // ========== dragCoverItem: 拖拽时显示 ==========
                    dragCoverItem: Rectangle {
                        width: control.itemWidth * 0.9
                        height: control.itemHeight * 0.9
                        radius: 6
                        border {
                            width: 1.5
                            color: ColorsConfig.color_brand
                        }
                        color: Colors.color_444444

                        Rectangle {
                            id: dragCoverImageContainer
                            anchors.fill: parent
                            anchors.margins: parent.border.width
                            radius: parent.radius - parent.border.width
                            clip: true
                            border.color: ColorsConfig.color_brand
                            color: Colors.color_000000

                            Image {
                                anchors.fill: parent
                                source: imageUrl
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                layer.enabled: true
                                layer.effect: OpacityMask {
                                    maskSource: Rectangle {
                                        width: dragCoverImageContainer.width
                                        height: dragCoverImageContainer.height
                                        radius: 6
                                    }
                                }
                            }
                        }
                    }

                    // ========== dragItemInTrack: 放在轨道上 ==========
                    dragItemInTrack: Rectangle {
                        width: control.itemWidth * 0.7
                        height: control.itemHeight * 0.7
                        radius: 6
                        color: Colors.color_444444

                        Rectangle {
                            id: imageRectangleInTrack
                            anchors.fill: parent
                            radius: 6
                            clip: true
                            color: Colors.color_000000

                            Image {
                                anchors.fill: parent
                                source: imageUrl
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                layer.enabled: true
                                layer.effect: OpacityMask {
                                    maskSource: Rectangle {
                                        width: imageRectangleInTrack.width
                                        height: imageRectangleInTrack.height
                                        radius: 6
                                    }
                                }
                            }
                        }
                    }

                }
            }
        }

        // 监听点击背景 (为了做取消选中)
        Item {
            id: bgView
            visible: control.visible && dashboardListModel.selectedDashboardIndex >= 0
            parent: UiUtils.getTopParent(control)
            anchors.fill: parent
            PointHandler {
                onGrabChanged: (transition, point) => {
                    point.accepted = false;
                    //确保同一物理操作（无论触摸还是鼠标）在短时间内只触发一次
                    if (Date.now() - lastTime < 200) {
                        return;
                    }
                    if (point.timeHeld !== 0) {
                        return;
                    }
                    lastTime = Date.now();

                    var mousePoint = point.position;
                    var clickPoint;

                    var needContinue = true;
                    clickPoint = bgView.mapToItem(playerPanel, mousePoint);
                    // 点击了播放器区域
                    if (playerPanel.contains(clickPoint)) {
                        needContinue = false;
                    }
                    if (needContinue) {
                        clickPoint = bgView.mapToItem(control, mousePoint);
                        if (control.contains(clickPoint)) {
                            control.clickBgView(clickPoint);
                        } else {
                            control.dashboardListModel.clickAtIndex(-1, true);
                            control.dashboardListModel.selectedDashboardIndex = -1;
                        }
                    }
                }
            }
        }
    }

    WaitingPopup {
        id: waitingPopup
        loadingText: qsTr("pccut_dashboard_importing_data")
        // 添加计时器
        Timer {
            id: timeoutTimer
            interval: 60000 // 60秒
            onTriggered: {
                waitingPopup.loadingText = qsTr("pccut_dashboard_importing_data_timeout")
            }
        }

        onOpened: timeoutTimer.start() // 弹窗打开时启动计时
        onClosed: timeoutTimer.stop()  // 弹窗关闭时停止计时
    }
    Connections {
        target: globalSignal
        function onFitDataLoaded(success, isMatch) {
            logger.i("[NOVA][TEMP] fitDataLoaded arrived success=" + success
                     + " isMatch=" + isMatch + " popupVisible=" + waitingPopup.visible);
            if(!waitingPopup.visible){
                return;
            }

            timeoutTimer.stop();
            waitingPopup.close();
            if(success) {
                if(isMatch) {
                    toast.showToast(qsTr("pccut_dashboard_import_success"), "tracks");
                }
                else {
                    toast.showToast(qsTr("pccut_dashboard_import_success_mismatch"), "tracks");
                }
            }
            else {
                toast.showToast(qsTr("pccut_dashboard_import_fail"), "tracks");
            }
        }

        function onOpenFitWaitingPopup() {
            logger.i("[NOVA][TEMP] waiting popup open, alreadyVisible=" + waitingPopup.visible);
            waitingPopup.loadingText = qsTr("pccut_dashboard_importing_data");
            waitingPopup.open();
            timeoutTimer.restart();
        }
    }
    EmptyPanel {
        id: emptyPanel
        visible: dashboardListModel.state === 2
        width: parent.width
        height: parent.height
        anchors.centerIn: parent
        no_network_mode: true
        network_request_type: Instance.request_type_audio
        onClick: {
            dashboardListModel.fetchDashboardData();
        }
    }
}
