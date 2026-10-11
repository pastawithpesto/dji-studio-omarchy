import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.3
import Config 1.0
import Controls 1.0
import StickerDataListModel 1.0
/**
 * @author tengsen.zhang
 * @desc 仪表选择面板
 * @create_date 2024-10-11
 */
Item {
    id: control

    readonly property int stateNormal: 0
    readonly property int stateSelected: 1
    readonly property int stateDisabled: 2
    readonly property int stateLoading: 3

    // 边距
    property int padding: 12
    // Item列间隔
    property int columnSpaceingDelt:(parent.width - 268) > 0 ? ( (parent.width - 268) / 4) :0    
    property int columnSpacing: 12 + columnSpaceingDelt
    // Item行间隔
    property int rowSpacing: 16
    // Item 宽
    property int itemWidth: 54
    // Item 高
    property int itemHeight: 55
    // Delegate 宽
    property int delegateWidth: itemWidth + columnSpacing
    // Delegate 高
    property int delegateHeight: itemHeight + rowSpacing
    property int columns: (list_view.width + columnSpacing - padding) / delegateWidth < 1 ? 1 : (list_view.width + columnSpacing - padding) / delegateWidth
    property int rows: Math.ceil(list_view.model.count / columns)

    property StickerDataListModel stickerDataListModel: StickerDataListModel {}

    property var pendingGpsOldJson
    property string pendingGpsSlug
    property string pendingGpsConfig
    property int pendingGpsGroupIndex: -1
    function addGpsStickerWithUndo(slug, config, groupIndex, oldJson) {
        globalSignal.addDashboardSticker(slug, config);
        stickerDataListModel.updateState(groupIndex, control.stateSelected);
        // 贴纸增删已由 DashboardManager.addSticker → pushCustomData → UpdateCustomRenderFilterCmd
        // 入 nova undo 栈；不再向老 UnDoManager 推 doUpdateStickerParams（避免双栈不对齐）。
        editorDraftManager.saveDraft();
    }

    // 动态调整 control 的高度
    height: control.rows * control.delegateHeight
    // 监听 control 的 enabled 属性变化
    onEnabledChanged: {
        control.stickerDataListModel.setEnabled(control.enabled);
    }
    // 套一层 Item clip 剪去 ListView 尾巴上多余的部分不显示出来
    Item {
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            bottom: parent.bottom
        }

        clip: true
        ListView {
            id: list_view
            objectName: actionableItemName.dashBoardDataListView
            width: parent.width
            // 高度多一个 delegate 放置 footer，防止末尾的一行滑倒底部后隐藏
            // 多出来的一部分会被外部 Item clip 掉
            height: control.rows * control.delegateHeight + control.delegateHeight
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
            header: Item{
                width: control.delegateWidth
                height: 10
            }
            footer: Item {
                width: control.delegateWidth
                // 高度大于等于 delegate 高度才能保证显示
                height: control.delegateHeight
            }
            interactive: false
            model: stickerDataListModel
            Component.onCompleted: {
                stickerDataListModel.fetchInstrumentData();
            }

            Connections {
                target: globalSignal
                function onRefreshStickersState() {
                    control.pendingGpsGroupIndex = -1;
                    stickerDataListModel.fetchInstrumentData();
                }
                function onUpdateStickerState(slug) {
                    stickerDataListModel.updateState(slug);
                }
            }
            Connections {
                target: dashboardManager
                function onReverseGeocodeCompleted(success) {
                    if (control.pendingGpsGroupIndex < 0) {
                        stickerDataListModel.fetchInstrumentData();
                        return;
                    }
                    if (!success) {
                        toast.showToast(qsTr("pccut_panel_dashboard_gps_resolve_fail_toast"), "playerMainView");
                    }
                    addGpsStickerWithUndo(control.pendingGpsSlug, control.pendingGpsConfig, control.pendingGpsGroupIndex, control.pendingGpsOldJson);
                    control.pendingGpsGroupIndex = -1;
                }
            }
            delegate: Item {
                id: list_item_root
                objectName: actionableItemName.delegateItemForDashBoardDataList + index
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
                        width: control.itemWidth
                        height: control.itemHeight
                        color: Colors.color_transparent
                        Rectangle {
                            id: circleRect
                            width: 36
                            height: 36
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.leftMargin: 9
                            radius: control.itemWidth / 2
                            color: Colors.color_353738
                            Image {
                                id: imageElement
                                source: imageUrl
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.horizontalCenter: parent.horizontalCenter
                                sourceSize: Qt.size(24, 24)
                                opacity: (model.state === control.stateDisabled || (!enabled && model.state !== control.stateLoading)) ? 0.2 : 1

                                RotationAnimation on rotation {
                                    id: loadingAnimation
                                    running: model.state === control.stateLoading
                                    from: 0
                                    to: 360
                                    duration: 1000
                                    loops: Animation.Infinite
                                    onRunningChanged: {
                                        if (!running) {
                                            imageElement.rotation = 0;
                                        }
                                    }
                                }
                            }
                        }

                        //鼠标掠过效果
                        MouseArea {
                            id: mouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                if (model.state === control.stateDisabled) {
                                    toast.showToast(qsTr("pccut_import_clip_missing_fail").arg(name), "playerPanel");
                                } else if (model.state === control.stateLoading) {
                                    return;
                                } else {
                                    var oldJsonObject = dashboardManager.getFitDataJsonObject();
                                    if (slug === "gpsLocation") {
                                        dashboardManager.trackGpsClick(model.state === control.stateNormal);
                                    }
                                    if (model.state === control.stateNormal) {
                                        if (slug === "gpsLocation") {
                                            if (dashboardManager.hasGpsData()) {
                                                control.pendingGpsOldJson = oldJsonObject;
                                                control.pendingGpsSlug = slug;
                                                control.pendingGpsConfig = config;
                                                control.pendingGpsGroupIndex = model.groupIndex;
                                                dashboardManager.fetchReverseGeocode();
                                            } else {
                                                dashboardManager.trackGpsNoData();
                                                toast.showToast(qsTr("pccut_panel_dashboard_gps_no_data_toast"), "playerMainView");
                                                addGpsStickerWithUndo(slug, config, model.groupIndex, oldJsonObject);
                                            }
                                            return;
                                        }
                                        // 添加（非GPS）
                                        globalSignal.addDashboardSticker(slug, config)
                                    } else {
                                        // 移除
                                        globalSignal.removeDashboardSticker(slug)
                                    }
                                    stickerDataListModel.updateState(model.groupIndex, model.state === control.stateNormal ? control.stateSelected : control.stateNormal);

                                    // 贴纸增删已由 DashboardManager.addSticker/removeSticker → pushCustomData
                                    // → UpdateCustomRenderFilterCmd 入 nova undo 栈；不再向老 UnDoManager 推
                                    // doUpdateStickerParams（避免双栈不对齐）。
                                    editorDraftManager.saveDraft();
                                }
                            }
                        }
                        HoverableText {
                            text: name
                            anchors.top: circleRect.bottom
                            anchors.topMargin: 4
                            font.pixelSize: 11
                            color: Colors.color_666666
                            width: parent.width
                            maxTextWidth: parent.width
                            cursorChanged: false
                            noWarp: true
                            lineCount: 1
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }
            }
        }
    }
}
