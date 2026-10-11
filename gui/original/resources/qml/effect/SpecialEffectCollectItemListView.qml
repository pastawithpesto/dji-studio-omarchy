/**
 * @author albert.lbrayim
 * @desc 特效收藏资源面板
 * @create_date 2025-11-14
 */
import QtQuick 2.15
import Config 1.0
import Controls 1.0
import Qt5Compat.GraphicalEffects
import QtQuick.Controls
import app_qrc 1.0
import QtQuick.Dialogs
import SpecialEffectResourceModel 1.0

Item {
    id: collectionListTabView

    // 资源列表特效
    property SpecialEffectResourceModel allEffectModels: null
    property double lastSelectTime : 0.0
    // 当前正在预览的特效 slug
    property string selectedSlug: ""
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

    // 收藏的素材数据列表（只有一个）
    SpecialEffectResourceModel {
        id: collectedItemModel
        isCollectionMode: true
    }

    function cancelSelect(){
        collectedItemModel.clickAtIndex(-1, false)
        selectedSlug = ""
    }

    // 当资源列表点击 item 时（QML 直接赋值 selectedEffectIndex），清除收藏列表选中
    Connections {
        target: allEffectModels
        function onSelectedEffectIndexChanged() {
            if (allEffectModels.selectedEffectIndex >= 0) {
                collectionListTabView.selectedSlug = ""
            }
            else
            {
                collectedItemModel.unPreviewEffect();
            }
        }
    }

    // 收藏页：下载完成后自动选中并预览。
    // 仅当前选中的卡片下载完成才自动预览：并发下载多个特效时，未被选中的卡片完成
    // 不得抢占预览态（预览态下时间指示器置灰不可拖动，被抢占后无从退出）。
    Connections {
        target: collectedItemModel
        function onEffectDownloadFinish(selectIndex, slug) {
            if (collectionListTabView.selectedSlug !== slug) {
                return
            }
            collectionListTabView.selectedSlug = ""
            collectedItemModel.clickAtIndex(selectIndex, true)
            collectionListTabView.selectedSlug = slug
        }
    }

    // 监听点击背景 (为了做取消选中)
    Item {
        id: bgView
        visible: collectionListTabView.visible
        parent: UiUtils.getTopParent(collectionListTabView)
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
                    clickPoint = bgView.mapToItem(collectionListTabView, mousePoint);
                    if (!collectionListTabView.contains(clickPoint)) {
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
        visible: collectedItemModel.isEmpty

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
        height:Math.min(collectListView.contentHeight,collectionListTabView.height)
        model: ListModel{
            ListElement{name:"pccut_resource_transition_like_title";srcUrl:""} // 收藏数据
        }
        header: Item {
            height: 0
        }
        footer: Item {
            height: 0
        }
        spacing: 8
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

        Item {
            id: containerItem
            height: resourceGridView.contentHeight + collectTitle.height+24
            width: collectionListTabView.width
            // 每段的上间距
            Rectangle{
                id:headerRec
                width: parent.width
                height: 16
                color: Colors.transparent
            }

            // 标题
            Text {
                visible: !collectedItemModel.isEmpty
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
                color: Colors.color_FFFFFF
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
                    leftMargin: spacing
                }
                visible: !collectedItemModel.isEmpty
                height: parent.height
                width: parent.width
                cellWidth: delegateWidth
                cellHeight: delegateHeight
                clip: true

                model: collectedItemModel

                delegate: SpecialEffectItemView {

                    id:itemView
                    visible: (typeof model.name !== "undefined")
                    resourceName: (typeof model.name !== "undefined") ? model.name : ""
                    imageUrl: (typeof model.imageUrl !== "undefined") ? model.imageUrl : "";
                    hoverImage: (typeof model.hoverImage !== "undefined") ? model.hoverImage : ""
                    resourceSlug:(typeof model.slug !== "undefined") ? model.slug : "";
                    effectConfig: model.dragConfig
                    currentSelectGrid: resourceSlug === collectionListTabView.selectedSlug
                    onlyForPanorama: allEffectModels.onlyForPanorama(index)
                    supportTypeName: (typeof model.supportType !== "undefined") ? model.supportType : ""
                    locationTypeName: (typeof model.locationType !== "undefined") ? model.locationType : ""
                    inCollectGridView: true
                    implicitWidth: itemWidth
                    implicitHeight: itemHeight
                    playedPercentage: resourceSlug === collectionListTabView.selectedSlug ? allEffectModels.effectPreviewPlayedPercentage : 0.0

                    Connections{
                        target: itemView
                        function onDownloadClicked(){
                            collectedItemModel.downloadSingleEffect(index)
                        }
                        function onCollectClicked(isCollect){
                            collectedItemModel.collectEffect(index, isCollect)
                        }
                        function onAddClicked(){
                            collectedItemModel.addEffectFromIndex(index)
                        }
                        function onCardClicked(){
                            collectionListTabView.selectedSlug = resourceSlug
                            collectedItemModel.clickAtIndex(index, true)
                        }
                        function onSeekClicked(percentage){
                            collectedItemModel.effectSeekAtPercentage(percentage)
                        }
                    }
                }
            }
        }
    }
}


