import QtQuick 2.15
import LightRectangle 1.0
import Config 1.0
import Controls 1.0
import DashboardListModel 1.0
import DashboardCategorysModel 1.0
import app_qrc 1.0

/**
 * @author tengsen.zhang
 * @desc 仪表盘左侧列表面板
 * @create_date 2024-10-11
 */
Item {
    property DashboardCategorysModel dashboardCategorysModel
    property int selectIndex: dashboardCategorysModel.selectIndex
    onSelectIndexChanged: {
        listView.positionViewAtIndex(selectIndex, ListView.Contain);
    }

    ListView {
        id: listView
        anchors.fill: parent
        model: dashboardCategorysModel
        header: Item {
            height: 16
        }
        footer: Item {
            height: 16
        }
        spacing: 16
        delegate: Rectangle {
            height: 28
            width: parent.width - 32
            color: selectIndex === index ? Colors.color_2F3032 : Colors.transparent
            radius: 4
            anchors.horizontalCenter: parent.horizontalCenter

            MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true
                LightToolTip {
                    visible: mouseArea.containsMouse && menuText.implicitWidth > menuText.width
                    tip: name
                }
                onClicked: {
                    dashboardCategorysModel.selectIndex = index;
                    dashboardCategorysModel.clickSection(index);
                }
            }

            Text {
                id: menuText
                text: name
                font.pixelSize: 12
                color: selectIndex === index ? ColorsConfig.color_brand : Colors.color_EEEEEE
                elide: Text.ElideMiddle
                wrapMode: Text.NoWrap
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignLeft
            }
        }
    }
}
