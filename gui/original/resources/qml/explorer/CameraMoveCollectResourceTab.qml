import QtQuick 2.15
import Config 1.0
import Controls 1.0
import Qt5Compat.GraphicalEffects
import QtQuick.Layouts 1.3
import QtQuick.Controls
import app_qrc 1.0
import QtQuick.Dialogs
import CollectTabViewModel
import CameraMoveAssertModel
/**
 * @author mathy.shi
 * @desc 运镜模版收藏资源面板
 * @create_date 2025-10-15
 */

Item{
    id: cameraMoveCollectTab
    property CameraMoveAssertModel cameraMoveAssertModel
    anchors.fill: parent

    CollectTabViewModel{
        id: collectTabViewModel
        assertModel: cameraMoveAssertModel
    }

    // 如果没有内容，就显示空样式
    Item{
        anchors.centerIn: parent
        width: 72
        height: 68
        visible: !collectTabViewModel.hasCollect

        Image {
            id: emptyImage
            anchors{
                top: parent.top
                horizontalCenter: parent.horizontalCenter
            }
            source: "qrc:/icons/ic_movement_collect.svg"
            sourceSize: Qt.size(44, 44)
        }

        Text {
            anchors{
                top: emptyImage.bottom
                topMargin: 8
                horizontalCenter: parent.horizontalCenter
            }
            color: Colors.color_666666
            text: qsTr("pccut_resource_movement_like_tip")
        }
    }

    // 虽然只有一个分类，但是也保持在 ListView 下，标题和间距随内容一起滚动
    ListView {
        id: collectListView
        width: parent.width
        height: Math.min(collectListView.contentHeight, cameraMoveCollectTab.height)
        model: ListModel{
            ListElement{ name: "pccut_resource_movement_like_title" }
        }
        header: Item { height: 0 }
        footer: Item { height: 16 }
        spacing: 8
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
            Component.onCompleted: {
                contentItem.color = Colors.color_454649
            }
        }
        delegate: collectListDelegate
    }

    // 收藏单个分类对应的代理
    Component {
        id: collectListDelegate
        Item{
            id: containerItem
            height: resourceGridView.contentHeight + collectTitle.height + 24
            width: cameraMoveCollectTab.width

            // 每段的上间距
            Rectangle{
                id: headerRec
                width: parent.width
                height: 16
                color: Colors.transparent
            }

            // 收藏标题
            Text {
                id: collectTitle
                visible: collectTabViewModel.hasCollect
                anchors{
                    top: headerRec.bottom
                    left: parent.left
                    leftMargin: 12
                }
                font.pixelSize: 12
                height: 16
                width: 100
                text: qsTr(name)
                color: Colors.color_EEEEEE
            }

            // 其中展示收藏的所有资源
            GridView {
                id: resourceGridView
                interactive: false // 禁用自身滚动，由外层 ListView 负责
                anchors{
                    top: collectTitle.bottom
                    topMargin: 16
                    left: parent.left
                    right: parent.right
                    leftMargin: 12
                }
                visible: collectTabViewModel.hasCollect
                height: parent.height
                cellWidth: 80 + 12
                cellHeight: 100 + 12
                clip: true

                model: collectTabViewModel

                delegate: CameraMoveItemView {
                    visible: (typeof model.name !== "undefined")
                    cameraMoveAssertModel: cameraMoveCollectTab.cameraMoveAssertModel
                    resourceName: (typeof model.name !== "undefined") ? model.name : ""
                    imageUrl: (typeof model.imageUrl !== "undefined") ? model.imageUrl : ""
                    categorySlug: ""
                    resourceSlug: (typeof model.slug !== "undefined") ? model.slug : ""
                    implicitWidth: 80
                    implicitHeight: 100
                }
            }
        }
    }
}
