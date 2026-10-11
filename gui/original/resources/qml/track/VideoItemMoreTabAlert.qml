import QtQuick 2.15
import QtQuick.Controls
import Config 1.0
import Controls 1.0
import Qt5Compat.GraphicalEffects
import SettingPanelViewModel 1.0
import Nova 1.0

LightPopup {
    id: toastPopup
    // 数据源（per-clip，由 VideoItemView 注入）
    // 变速下拉项读 clipViewModel.speed；滤镜/LUT/仪表盘下拉项分别读对应徽标 VM（子滤镜变化自动刷新）。
    property TimelineVideoClipViewModel clipViewModel
    property BadgeFilterClipViewModel clipFilterBadgeVM
    property BadgeDashboardClipViewModel clipDashboardBadgeVM
    property double contentRectangleX: 0
    property double contentRectangleY: 0
    property double maxWidth: 141
    property double maxHeight: 0

    parent: Overlay.overlay
    width: parent.width
    height: parent.height
    closePolicy: Popup.NoAutoClose
    dim: false

    background: Rectangle {
        color: Colors.color_transparent
    }

    contentItem: Item {
        anchors.fill: parent
        MouseArea {
            anchors.fill: parent
            onClicked: toastPopup.close()
        }

        Rectangle {
            id: contentRectangle

            // 选项的高度
            property real itemHeight: 28
            // listview的上、下的内间隙
            property real listViewMargin: 4
            // listview 每个item的间隙
            property real listViewSpace: 4

            width: toastPopup.maxWidth + 8
            height: toastPopup.maxHeight
            x: contentRectangleX
            y: contentRectangleY

            color: Colors.color_141414
            radius: 8
            opacity: 1
            clip: true
            border {
                width: 1
                color: Colors.color_444444
            }

            Text {
                id: titleText
                anchors {
                    left: parent.left
                    leftMargin: 12
                    top: parent.top
                    topMargin: 8
                    right: parent.right
                }
                height: 14
                font {
                    pixelSize: 10
                }

                text: qsTr("pccut_effect_added")
                color: Colors.color_666666
            }

            ListView {
                id: listView
                anchors {
                    left: parent.left
                    top: titleText.bottom
                    topMargin: contentRectangle.listViewMargin
                    right: parent.right
                    bottom: parent.bottom
                }
                topMargin: contentRectangle.listViewMargin
                bottomMargin: contentRectangle.listViewMargin

                interactive: false
                clip: true

                spacing: contentRectangle.listViewSpace

                model: listModel
                delegate: Rectangle {
                    x: 4
                    width: maxWidth
                    height: contentRectangle.itemHeight
                    radius: 4
                    // 选中、hover的颜色
                    color: model.selected ? Colors.color_353738 : (model.hovered ? Colors.color_353738 : Colors.color_transparent)
                    Rectangle {
                        id: icon
                        anchors {
                            left: parent.left
                            leftMargin: 8
                            verticalCenter: parent.verticalCenter
                        }
                        width: 16
                        height: 16
                        color: Colors.color_transparent
                        Image {
                            anchors.centerIn: parent
                            source: model.icon
                            sourceSize: Qt.size(model.iconWidth, model.iconHeight)
                        }
                    }

                    Text {
                        id: textLabel
                        anchors {
                            left: icon.right
                            leftMargin: 4
                            verticalCenter: parent.verticalCenter
                        }
                        color: Colors.color_EEEEEE
                        font {
                            pixelSize: 11
                        }

                        text: model.title

                        FontMetrics {
                            id: fontMetrics
                            font: textLabel.font
                        }

                        onTextChanged: {
                            let width = icon.anchors.leftMargin * 2 + model.iconWidth + textLabel.anchors.leftMargin + fontMetrics.advanceWidth(textLabel.text) + textLabel.anchors.leftMargin;
                            maxWidth = Math.max(maxWidth, width);
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: {
                            if (!model.selected) {
                                model.hovered = true;
                            }
                        }
                        onExited: {
                            clearAllHover();
                        }
                        onClicked: {
                            globalSignal.videoItemViewClickTabType(model.tabType);
                            close();
                        }
                    }
                }
            }
        }
    }

    ListModel {
        id: listModel
    }
    onOpened: {
        refreshMaxHeight();
        // 设置选中态
        for (var i = 0; i < listModel.count; i++) {
            var model = listModel.get(i);
            if (model.tabType === settingPanel.getSettingPanelTabType()) {
                model.selected = true;
            } else {
                model.selected = false;
            }
        }
    }

    // 清空模型中的hovered
    function clearAllHover() {
        for (var i = 0; i < listModel.count; i++) {
            var model = listModel.get(i);
            model.hovered = false;
        }
    }

    function refreshMaxHeight() {
        listModel.clear();
        var arr = [];
        // 滤镜/LUT/仪表盘/变速下拉项均改用 per-clip VM，与 VideoItemView 角标同源。
        if (clipFilterBadgeVM && clipFilterBadgeVM.isEnableLut && clipFilterBadgeVM.lutName.length !== 0) {
            arr.push({
                icon: "qrc:/icons/icon_videoItem_more_lut.svg",
                iconWidth: 14.2,
                iconHeight: 12.2,
                title: qsTr("pccut_panel_colorrecovery") + ": " + clipFilterBadgeVM.lutName,
                tabType: SettingPanelViewModel.SETTINGPANELTABTYPE_ADJUST_LUT,
                hovered: false,
                selected: false
            });
        }
        if (clipFilterBadgeVM && clipFilterBadgeVM.isEnableStyleFilter && clipFilterBadgeVM.styleFilterName.length !== 0) {
            arr.push({
                icon: "qrc:/icons/icon_videoItem_more_stylefilter.svg",
                iconWidth: 14,
                iconHeight: 13,
                title: qsTr("pccut_filter") + ": " + clipFilterBadgeVM.styleFilterName,
                tabType: SettingPanelViewModel.SETTINGPANELTABTYPE_ADJUST_STYLEFILTER,
                hovered: false,
                selected: false
            });
        }
        // TODO: 曲线变速如何适配这个more_speed
        if (clipViewModel && clipViewModel.hasFragment && clipViewModel.speed != 1) {
            arr.push({
                icon: "qrc:/icons/icon_videoItem_more_speed.svg",
                iconWidth: 16,
                iconHeight: 16,
                title: qsTr("pccut_panel_speed") + ": " + parseFloat(clipViewModel.speed.toFixed(4)) + "x",
                tabType: SettingPanelViewModel.SETTINGPANELTABTYPE_REGSPEED,
                hovered: false,
                selected: false
            });
        }

        if (clipDashboardBadgeVM && clipDashboardBadgeVM.isEnableDashboard && clipDashboardBadgeVM.dashboardName.length !== 0) {
            var dashboardStr = qsTr("pccut_dashboard") + ": " + qsTr(clipDashboardBadgeVM.dashboardName)
            arr.push({
                icon: "qrc:/icons/icon_videoItem_more_dashboard.svg",
                iconWidth: 16,
                iconHeight: 16,
                title: dashboardStr,
                tabType: SettingPanelViewModel.SETTINGPANELTABTYPE_DASHBOARD,
                hovered: false,
                selected: false
            });
        }
        listModel.append(arr);
        toastPopup.maxHeight = titleText.anchors.topMargin + titleText.height + contentRectangle.listViewMargin + listModel.count * contentRectangle.itemHeight + contentRectangle.listViewMargin * 2 + (listModel.count - 1) * contentRectangle.listViewSpace;
    }

    onClosed: {
        listModel.clear();
    }

    Component.onDestruction: {
        if (opened) {
            close();
        }
    }
}
