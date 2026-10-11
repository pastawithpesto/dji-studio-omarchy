import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.3
import LightRectangle 1.0
import Config 1.0
import Controls 1.0
import VideoFragmentViewModel 1.0
import SettingPanelViewModel 1.0
import Nova 1.0
import app_qrc 1.0

/**
 *  @File        : AdjustSettingPanel.qml
 *  @Brief       : 画面、滤镜，色彩还原 调节UI
 *  @Details     : 详细说明
 *  @Author      : mathy.shi
 *  @Date        : 2024-11-04 11:52:39
 */
Rectangle {
    id: root
    // tableview 的currentIndex
    property int currentIndex: 0
    // 外部传入的初始子tab索引
    property int initSubTabIndex: 0
    // 片段数据模型
    
    property VideoFragmentViewModel viewModel
    // 素材是否携带 DLog2 元数据（由 SettingPanel 从 PropertyPanelViewModel 下发），供 LutSetting 的 D-LOG 2 风格门控
    property bool hasDLog2Metadata: false

    // [NOVA] 风格滤镜存在性改读 nova 内核（StyleFilterViewModel），老 VideoSourceModel 已不再持有该滤镜
    StyleFilterViewModel { id: styleVM }
    readonly property bool hasStyleFilter: styleVM.hasClip && styleVM.slug.length > 0

    anchors.fill: parent
    color: Colors.color_content_area_background

    Item {
        id:contentRectangle
        anchors.fill: parent
        visible: true
        Rectangle {
            id: tabBackGround
            visible: true
            width: tableView.width
            height: 24
            anchors {
                top: parent.top
                topMargin: 17
                left: tableView.left
                leftMargin: 12
                right: tableView.right
                rightMargin: 12
            }
            radius: RadiusConfig.radius_4_88
            color: Colors.color_19191A
            ListView {
                id: hederList
                width: parent.width
                height: parent.height
                spacing: 0
                orientation: ListView.Horizontal
                model: tableView.dataList
                delegate: MouseArea {
                    width: hederList.width / 3
                    height: hederList.height
                    property bool isSelected: tableView.currentIndex === index
                    hoverEnabled: true
                    onClicked: {
                        tableView.currentIndex = index;
                        if (model.trackEventName.length > 0) {
                            eventTracker.trackEvent(model.trackEventName)
                        }
                    }
                    Rectangle {
                        anchors.fill: parent
                        color: isSelected ? Colors.color_2F3032 : Colors.color_transparent
                        radius: RadiusConfig.radius_4_88
                    }
                    Text {
                        id: label
                        anchors.centerIn: parent
                        text: model.text
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        color: {
                            if (isSelected) {
                                return Theme.settingTabSelectedTitleColor;
                            } else if (parent.containsMouse) {
                                return Colors.color_EEEEEE;
                            } else {
                                return Theme.settingTabNormalTitleColor;
                            }
                        }
                    }
                }
            }
        }
        LightTabView {
            id: tableView
            anchors {
                top: tabBackGround.bottom
                topMargin: 12
                left: parent.left
                leftMargin: 0
                right: parent.right
                rightMargin: 0
                bottom: parent.bottom
            }
            //2：滤镜页面 1：色轮页面 0：lut页面
            currentIndex: root.hasStyleFilter ? 2 : 0
            onCurrentIndexChanged: {
                root.currentIndex = tableView.currentIndex;
            }
        }

        Component {
            id: imageQualityTab
            ImageQualityPanel {
                viewModel: root.viewModel
                hasDLog2Metadata: root.hasDLog2Metadata
                isShowStylePanel: root.hasStyleFilter
                Accessible.role: Accessible.Button
                Accessible.description: "videoedit_image"
            }
        }

        Component {
            id: colorWheelTab
            Item {
                // 填满 StackLayout，为内部 ColorWheelPanel 提供确定高度（小屏可滚动的前提）
                Layout.fillWidth: true
                Layout.fillHeight: true
                ColorWheelFilterViewModel {
                    id: colorWheelAdjustPanel
                }
                Loader {
                    anchors.fill: parent
                    source: "../color_wheel/ColorWheelPanel.qml"
                    onLoaded: {
                        if (item) item.colorWheelAdjust = colorWheelAdjustPanel;
                    }
                }
            }
        }

        Component {
            id: styleFilterTab
            Item {
                visible: true
                Loader {
                    id: filterLoader
                    anchors.fill: parent
                    active: root.hasStyleFilter
                    sourceComponent: Component {
                        StyleFilterPanel {
			                viewModel: root.viewModel
			                Accessible.role: Accessible.Button
			                Accessible.description: "videoedit_image"
                        }
                    }
                }
                Text {
                    visible: !root.hasStyleFilter
                    anchors.centerIn: parent
                    text: qsTr("pccut_panel_adjust_filter_empty_desc")
                    color: Colors.color_666666
                    font.pixelSize: 12
                }
            }
        }

        Component.onCompleted: {
            refreshUI();
            tableView.currentIndex = Math.min(initSubTabIndex, tableView.count - 1);
        }

        // 刷新Tab
        function refreshUI() {
            tableView.addTab(qsTr("pccut_panel_adjust_tab_basic_title"), imageQualityTab, "pccut_panel_tab");
            tableView.addTab(qsTr("pccut_panel_adjust_tab_colorwheel_title"), colorWheelTab, "pccut_color_wheel_tab");
            tableView.addTab(qsTr("pccut_panel_adjust_tab_filter_title"), styleFilterTab, "");
            tableView.syncTab();
        }
    }

    // 顶部分割线
    Rectangle {
        color: Colors.color_141414
        width: parent.width
        height: 1
    }

    Connections {
        target: globalSignal

        function onSwitchToAdjustTab() {
            if (tableView.count === 0) {
                contentRectangle.refreshUI();
            }
            tableView.currentIndex = 0;
        }

        function onSwitchToFilterTab() {
            if (tableView.count === 0) {
                contentRectangle.refreshUI();
            }
            tableView.currentIndex = 2;
        }
    }
}
