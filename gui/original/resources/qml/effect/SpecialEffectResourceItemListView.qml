import QtQuick 2.15
import QtQuick.Controls
import Config 1.0
import Controls 1.0
import SpecialEffectResourceModel 1.0
import SpecialEffectCategoriesModel 1.0
import app_qrc 1.0
import "../explorer"

Item {
    id: control
    objectName: "specialEffectListView"

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
    property int columns: Math.max(1, Math.floor((list_view.width + spacing - padding) / delegateWidth))

    property int sectionHeaderHeight: 48
    property SpecialEffectResourceModel allEffectModels: null
    property SpecialEffectCategoriesModel allEffectCategoryModels: allEffectModels.categoriesModel
    property double lastSelectTime: 0.0  // PointHandler 防抖时间戳，避免同一次操作触发多次取消选中

    function deselectEffect() {
        allEffectModels.clickAtIndex(-1, false)
        allEffectModels.selectedEffectIndex = -1
    }

    // 离开 tab 时自动取消选中（取消选中会同步停止特效预览）
    onVisibleChanged: {
        if (!visible && allEffectModels && allEffectModels.selectedEffectIndex >= 0) {
            deselectEffect()
        }
    }

    // 下载完成后自动选中并预览（参考滤镜 onFilterDownloadFinish）。
    // 仅当前选中的卡片下载完成才自动预览：并发下载多个特效时，未被选中的卡片完成
    // 不得抢占预览态（预览态下时间指示器置灰不可拖动，被抢占后无从退出）。
    Connections {
        target: allEffectModels
        function onEffectDownloadFinish(selectIndex, slug) {
            if (allEffectModels.selectedEffectIndex !== selectIndex) {
                return
            }
            allEffectModels.selectedEffectIndex = -1
            allEffectModels.clickAtIndex(selectIndex, true)
            allEffectModels.selectedEffectIndex = selectIndex
        }
    }

    // 套一层 Item clip 剪去 ListView 尾巴上多余的部分不显示出来
    Item {
        id: resourcelistItems
        visible: !emptyPanel.visible
        anchors {
            fill: parent
            leftMargin: control.padding
        }
        clip: true

        ListView {
            id: list_view
            objectName: actionableItemName.filterContentListView
            // 如果用户电脑配置较差，由于动画只有250ms，从头到尾滚动时可能无法加载所有delegate，导致高度出现错误，这会导致滤镜列表错位
            // 现在加上700像素的缓存，这部分的delegate作为缓存不会实时创建，减少一次性创建的delegate，可以避免上面的问题
            cacheBuffer: 700
            width: parent.width
            // 多出一个 delegateHeight 使底部新行的非首列 delegate（高度为0）能进入 ListView 可视区域，
            // 超出部分由外层 Item clip 裁剪
            height: parent.height + control.delegateHeight + control.spacing
            headerPositioning: ListView.OverlayHeader

            ScrollBar.vertical: ScrollBar {
                bottomPadding: control.delegateHeight + control.spacing
                Component.onCompleted: {
                    contentItem.color = Colors.color_444444;
                }
            }
            footer: Item {
                width: list_view.width
                height: control.delegateHeight * 3 - control.spacing - 8
                MouseArea {
                    anchors.fill: parent
                    enabled: allEffectModels.selectedEffectIndex >= 0
                    onClicked: control.deselectEffect()
                }
            }
            model: allEffectModels
            boundsBehavior: Flickable.StopAtBounds
            flickDeceleration: 7000

            onContentYChanged: {
                var indexInt = indexAt(0, contentY + sectionHeaderHeight);
                var section = allEffectModels.sectionFromItem(indexInt);
                if (section >= 0 && scrollToTopAnimation.running === false) {
                    allEffectCategoryModels.selectIndex = section;
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
                allEffectModels.fetchEffectResources();
                allEffectCategoryModels.viewClickSection.connect(_onViewClickSection);
            }

            Component.onDestruction: {
                allEffectCategoryModels.viewClickSection.disconnect(_onViewClickSection);
            }

            function _onViewClickSection(section) {
                var y = 0;
                for (var i = 0; i < section; i++) {
                    var count = allEffectModels.itemCountAtSection(i);
                    var height = Math.ceil(count * 1.0 / control.columns) * delegateHeight;
                    y += height;
                    y += sectionHeaderHeight;
                }
                animationY = y;
                scrollToTopAnimation.start();
            }

            section {
                property: "groupName"
                criteria: ViewSection.FullString
                delegate: Item {
                    width: list_view.width - control.padding
                    height: sectionHeaderHeight
                    MouseArea {
                        anchors.fill: parent
                        enabled: allEffectModels.selectedEffectIndex >= 0
                        onClicked: control.deselectEffect()
                    }
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
                width: control.delegateWidth
                // 每行第一个 Item 有高度，后面的没高度，这样就能排列到一行
                // 因为 0 高度 Item 在末尾，超出范围 visible 就置为 false 了，所以才需要 footer 撑高多显示一行的内容
                // delegate 高度不一致会导致滚动条滚动时长度变化
                height: (model.groupIndex % control.columns === 0) ? control.delegateHeight : 0

                // 预览中，首列delegate铺满整行宽度，捕获空卡片位置的点击
                MouseArea {
                    visible: (model.groupIndex % control.columns === 0) && allEffectModels.selectedEffectIndex >= 0
                    x: 0
                    y: 0
                    width: list_view.width
                    height: control.delegateHeight
                    z: -1
                    onClicked: control.deselectEffect()
                }

                SpecialEffectItemView {
                    id: itemView
                    // 根据列号计算 x，负 y 使非首列 item 与首列对齐
                    x: (model.groupIndex % control.columns) * control.delegateWidth
                    y: (model.groupIndex % control.columns !== 0) ? -control.delegateHeight : 0
                    width: control.itemWidth
                    height: control.itemHeight

                    resourceSlug: model.slug ?? ""
                    resourceName: model.name ?? ""
                    imageUrl: model.imageUrl ?? ""
                    hoverImage: model.hoverImage ?? ""
                    effectConfig: model.dragConfig
                    supportTypeName: (typeof model.supportType !== "undefined") ? model.supportType : ""
                    locationTypeName: (typeof model.locationType !== "undefined") ? model.locationType : ""
                    currentSelectGrid: allEffectModels.selectedEffectIndex === index
                    onlyForPanorama: allEffectModels.onlyForPanorama(index)
                    playedPercentage: allEffectModels.selectedEffectIndex === index ? allEffectModels.effectPreviewPlayedPercentage : 0.0

                    Connections {
                        target: itemView
                        function onDownloadClicked() {
                            allEffectModels.downloadSingleEffect(index)
                        }
                        function onCollectClicked(isCollect) {
                            allEffectModels.collectEffect(index, isCollect)
                        }
                        function onAddClicked() {
                            allEffectModels.addEffectFromIndex(index)
                        }
                        function onCardClicked() {
                            console.log("[EffectClick] onCardClicked index=" + index
                                        + " prevSelectedIndex=" + allEffectModels.selectedEffectIndex)
                            allEffectModels.clickAtIndex(index, true)
                            allEffectModels.selectedEffectIndex = index
                        }
                        function onSeekClicked(percentage) {
                            allEffectModels.effectSeekAtPercentage(percentage)
                        }
                    }
                }
            }
        }

    }

    EmptyPanel {
        id: emptyPanel
        visible: allEffectModels.state === SpecialEffectResourceModel.StateOffline
        width: parent.width
        height: parent.height
        anchors.centerIn: parent
        no_network_mode: true
        network_request_type: Instance.request_type_audio
        onClick: {
            allEffectModels.fetchEffectResources();
        }
    }

    // 监听点击背景（取消选中）
    // 仅处理控件外部的点击，控件内部由行级 MouseArea(z:-1)、section header、footer 的 MouseArea 处理取消选中
    Item {
        id: selectHandle
        parent: UiUtils.getTopParent(control)
        visible: control.visible && allEffectModels.selectedEffectIndex >= 0
        anchors.fill: parent
        PointHandler {
            onGrabChanged: (transition, point) => {
                point.accepted = false
                if (Date.now() - control.lastSelectTime < 200) {
                    return;
                }
                if (point.timeHeld !== 0) {
                    return;
                }
                control.lastSelectTime = Date.now()
                var mousePoint = point.position
                let needContinue = true
                // 点击了播放器区域
                let pointInPlayerPanel = selectHandle.mapToItem(playerPanel, mousePoint)
                if (playerPanel.contains(pointInPlayerPanel)) {
                    needContinue = false
                }
                if (needContinue) {
                    let pointInSelectHandle = selectHandle.mapToItem(control, mousePoint)
                    if (!control.contains(pointInSelectHandle)) {
                        control.deselectEffect()
                    }
                }
            }
        }
    }

    Connections {
        target: globalSignal

        // 草稿切换时，二级tab切换回第一个
        function onActivedProjectChanged(id) {
            if (draftUIManager.isActiveProjectExist()) {
                allEffectCategoryModels.selectIndex = 0;
                allEffectCategoryModels.clickSection(0);
            }
        }
        function onEffectApplyFailed(info) {
            toast.showToast(qsTr(info))
        }
    }
}
