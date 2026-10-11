import QtQuick 2.15
import Config 1.0
import Controls 1.0
import Qt5Compat.GraphicalEffects
import QtQuick.Controls
import app_qrc 1.0
import QtQuick.Dialogs
import TransitionCollectViewModel 1.0
/**
 * @author hugo.li
 * @desc 转场收藏资源面板
 * @create_date 2025-11-14
 */

Item{
    id: transitionCollectTab
    property double lastSelectTime : 0.0

    // 收藏的素材数据列表（只有一个）
    TransitionCollectViewModel{
        id:collectViewModel
    }


    function cancelSelect(){
        transitionMaterialModel.select("")
        transitionManager.stopTransitionPreview()
    }

    // 监听点击背景 (为了做取消选中)
    Item {
        id: bgView
        visible: transitionCollectTab.visible
        parent: UiUtils.getTopParent(transitionCollectTab)
        anchors.fill: parent
        PointHandler {
            onGrabChanged: (transition, point) => {
                point.accepted = false;
                //确保同一物理操作（无论触摸还是鼠标）在短时间内只触发一次
                if (Date.now() - lastSelectTime < 200) {
                    return;
                }
                if (point.timeHeld !== 0) {
                    return;
                }
                lastSelectTime = Date.now();

                var mousePoint = point.position;
                var clickPoint;

                var needContinue = true;
                clickPoint = bgView.mapToItem(playerPanel, mousePoint);
                // 点击了播放器区域
                if (playerPanel.contains(clickPoint)) {
                    needContinue = false;
                }
                if (needContinue) {
                    clickPoint = bgView.mapToItem(transitionCollectTab, mousePoint);
                    if (!transitionCollectTab.contains(clickPoint)) {
                       cancelSelect()
                    }
                }
            }
        }
    }


    // 分类中的取消选中
    MouseArea{
        anchors.fill: parent
        onClicked: {
            cancelSelect()
        }
    }

    // 如果没有内容，就显示空样式
    Item{
        anchors.centerIn: parent
        width: 72
        height: 68
        visible: collectViewModel.isEmpty

        Image {
            id: emptyImage
            width: 44
            height: 44
            source: "qrc:/icons/ic_collect_empty.svg"
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            smooth: true
        }

        Text {
            anchors{
                horizontalCenter: emptyImage.horizontalCenter
                top: emptyImage.bottom
                topMargin: 8
            }

            text: qsTr("pccut_resource_transition_like_tip")
            color: Colors.color_666666
        }
    }


    // 虽然只有一个分类，但是也保持在listView下
    ListView {
        id: collectListView
        width:parent.width
        height:Math.min(collectListView.contentHeight,transitionCollectTab.height)
        model: ListModel{
            ListElement{name:"pccut_resource_transition_like_title";srcUrl:""} // 收藏数据
        }
        header: Item {
            height: 0
        }
        footer: Item {
            height: 16
        }
        spacing:8
        boundsBehavior:Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
            Component.onCompleted: {
				contentItem.color = Colors.color_444444
			}

        }
        delegate: collectListDelegate
    }


    // 收藏单个分类对应的代理
    Component {
        id: collectListDelegate
        Item{
            id: containerItem
            height: resourceGridView.contentHeight + collectTitle.height+24
            width: transitionCollectTab.width

            // 每段的上间距
            Rectangle{
                id:headerRec
                width: parent.width
                height: 16
                color: Colors.transparent
            }

            // 标题
            Text {
                visible: !collectViewModel.isEmpty
                id: collectTitle
                anchors{
                    top:headerRec.bottom
                    left: parent.left
                    leftMargin: 12
                }
                font.pixelSize: 12
                height: 16
                width: 100
                text: qsTr(name)
                color: Colors.color_EEEEEE
            }

            // 分类中的取消选中
            MouseArea{
                anchors.fill: parent
                onClicked: {
                    cancelSelect()
                }
            }

            // 其中展示某一个分类下的所有资源
            GridView {
                id: resourceGridView
                interactive: false // 禁用所有交互（包括滚动和拖拽）
                anchors{
                    top: collectTitle.bottom
                    topMargin: 16
                    left: parent.left
                    right:parent.right
                    leftMargin: 12
                }
                visible: !collectViewModel.isEmpty
                height: parent.height
                width: parent.width
                cellWidth: 80+12
                cellHeight: 100+12
                clip: true

                model: collectViewModel

                delegate: TransitionMaterialItemView {
                    id:itemView
                    visible: (typeof model.name !== "undefined")
                    resourceName: (typeof model.name !== "undefined") ? model.name : ""
                    imageUrl: (typeof model.imageUrl !== "undefined") ? model.imageUrl : "";
                    hoverImage: (typeof model.hoverImage !== "undefined") ? model.hoverImage : "";
                    resourceSlug:(typeof model.slug !== "undefined") ? model.slug : "";
                    currentSelectGrid:transitionMaterialModel.currentCategory !== ""

                    inCollectGridView: true
                    implicitWidth: 80
                    implicitHeight: 100

                    Connections{
                        target: itemView
                        function onDownload(index){
                            collectViewModel.download(index)
                        }
                        function onCollect(index,isCollect){
                            collectViewModel.collect(index,isCollect)
                        }
                        function onAddTransition(slug){
                            transitionMaterialModel.addTransition(slug)
                        }
                        function onPreview(slug){
                            transitionMaterialModel.preview(slug)
                        }
                        function onSelectItem(slug){
                            transitionMaterialModel.select("collect_category")
                        }
                    }
                }
            }
        }
    }
}


