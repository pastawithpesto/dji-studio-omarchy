import QtQuick 2.15
import Config 1.0
import Controls 1.0
import QtQuick.Controls
import Nova 1.0
import MediaTypeModel 1.0
import SettingPanelViewModel 1.0

/**
  * @details 【变速设置】界面 包含常规设置和曲线变速（nova SpeedViewModel 驱动）
  * P1：普通变速 + 曲线变速面板核心；超级慢动作留 P2。
  */
Rectangle {
    id: root
    anchors.fill: parent
    color: Colors.color_content_area_background
    visible: true

    property int currentIndex: 0
    // 目标子 Tab 索引：0=常规变速，1=曲线变速（由外部在切换时传入）
    property int subTabIndex: 0

    property SpeedViewModel viewModel

    // 滑杆抬手信号
    signal regSpeedSliderSignal(double newRegSpeed)
    // 曲线变速变更
    signal curveSpeedSignal(var points)

    onSubTabIndexChanged: {
        tableView.currentIndex = subTabIndex;
        tabBackGround.currentIndex = subTabIndex;
    }

    Item {
        id:contentRectangle
        anchors.fill: parent
        visible: true

        // 标签栏，切换常规变速和曲线变速
        LightTabbar {
            id: tabBackGround
            anchors {
                left: parent.left
                right: parent.right
                leftMargin: 12
                rightMargin: 12
            }
            visible: true
            dataList: tableView.dataList

            onCurrentIndexChanged: {
                tableView.currentIndex = tabBackGround.currentIndex;
            }
        }
        // 变速面板容器
        LightTabView {
            id: tableView

            anchors {
                top: tabBackGround.bottom
                topMargin: 16
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }
            onCurrentIndexChanged: {
                root.currentIndex = tableView.currentIndex;
                if (tabBackGround.currentIndex !== tableView.currentIndex) {
                    tabBackGround.currentIndex = tableView.currentIndex;
                }
            }
        }


        // 常规变速面板
        Component {
            id: regSpeedTab
            RegSpeedPanel {
                id: regSpeedPanel
                viewModel: root.viewModel
                showDivideLine: false
                onSpeedSliderSignal: (newRegSpeed) => {
                    regSpeedSliderSignal(newRegSpeed);
                }
            }
        }
        // 曲线变速面板
        Component {
            id: curveSpeedTab
            CurveSpeedPanel {
                id: curveSpeedPanel
                viewModel: root.viewModel
                onSpeedCurveChanged: (points) => {
                    curveSpeedSignal(points);
                }
            }
        }

        Component.onCompleted: {
            refreshUI();
            tableView.currentIndex = subTabIndex;
            tabBackGround.currentIndex = subTabIndex;
        }

        // 刷新Tab
        function refreshUI() {
            tableView.addTab(qsTr("pccut_panel_speed_normal"), regSpeedTab, "");
            tableView.addTab(qsTr("pccut_panel_speed_curve"), curveSpeedTab, "");
            tableView.syncTab();
        }
    }
}
