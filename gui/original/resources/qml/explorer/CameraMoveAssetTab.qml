import QtQuick 2.15
import Config 1.0
import Controls 1.0
import Qt5Compat.GraphicalEffects
import QtQuick.Controls
import app_qrc 1.0
import QtQuick.Layouts 1.3
import QtQuick.Dialogs
import CameraMoveAssertViewModel
import CameraMoveAssertModel
import MovementCategoryListViewModel
import QmlConstants 1.0

/**
 * @author mathy.shi
 * @desc 运镜模版资源面板
 * @create_date 2025-10-15
 */

MaterialTabBaseView{
    id: cameraMoveAssetTab
    property CameraMoveAssertModel cameraMoveAssertModel: CameraMoveAssertModel {}
    property string selectCategorySlug: ""; // 当前选中的左侧目录列表中的项对应的slug
    property int selectCategoryIndex: -1; // 当前选中的左侧目录列表中索引
    property int selectTabIndex: 1; // 当前选中的右侧资源列表tab索引: 收藏Tab(0), 非收藏资源Tab(1), 默认是1

    CameraMoveAssertViewModel{
        id: cameraMoveAssertViewModel
        assertModel:cameraMoveAssertModel
        Component.onCompleted:{
            if(!cameraMoveAssertViewModel.hasLoadedAssert){
                cameraMoveAssertViewModel.loadAssert();
            }
        }
    }

    // 左侧分类列表
    leftView: Component {
        Item{
            id: categorysList

            height: parent.height
            width: parent.width
            anchors{
                top: parent.top
                topMargin: 16
            }

            MovementCategoryListViewModel{
                id: categoryListViewModel
                assertModel:cameraMoveAssertModel
            }

            // 状态管理：收藏Tab 和 分类Tab 的切换
            StateGroup {
                states: [
                    State {
                        name: "collectState"
                        when: cameraMoveAssetTab.selectTabIndex === 0
                        PropertyChanges { target: uncollectBtn; isExpanded: false }
                    },
                    State {
                        name: "categoryState"
                        when: cameraMoveAssetTab.selectTabIndex === 1
                        PropertyChanges { target: uncollectBtn; isExpanded: true }
                    }
                ]
            }

            // 监听数据加载完成，自动选中第一个分类
            Connections {
                target: categoryListViewModel
                function onRowsInserted(parent, first, last) {
                    // 当在分类Tab且数据首次加载完成时，自动选中第一个
                    if (cameraMoveAssetTab.selectTabIndex === 1 &&
                        cameraMoveAssetTab.selectCategorySlug === "" &&
                        categoryListViewModel.rowCount() > 0) {
                        cameraMoveAssetTab.selectCategoryIndex = 0
                        cameraMoveAssetTab.selectCategorySlug = categoryListViewModel.getCategorySlug(0)
                    }
                }
            }

            Rectangle{
                id: collectBtn
                height: 28
                width: parent.width - 32
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                color:  Colors.color_2F3032
                radius: 4

                Text {
                    anchors{
                        left: parent.left
                        leftMargin: 12
                    }
                    text: qsTr("pccut_resource_movement_like_title")
                    font.pixelSize: 12
                    color: cameraMoveAssetTab.selectTabIndex == 0 ? ColorsConfig.color_brand : Colors.color_FFFFFF
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                    anchors.verticalCenter: parent.verticalCenter

                }

                MouseArea{
                    anchors.fill: parent

                    onClicked: {
                        selectTabIndex = 0
                    }
                }

            }

            FoldListButton{
                id: uncollectBtn
                height: 28
                width: parent.width - 32
                anchors{
                    top: collectBtn.isExpanded ? collectListView.bottom : collectBtn.bottom
                    topMargin: 16
                    horizontalCenter: parent.horizontalCenter
                }
                title: qsTr("pccut_resource_movement_title_2")
                isSelect: cameraMoveAssetTab.selectTabIndex == 1
                isShowImg: true
                onCusClicked: {
                    cameraMoveAssetTab.selectTabIndex = 1
                }
            }

            // 展开的分类资源列表
            ListView {
                id: categorysListView
                visible: uncollectBtn.isExpanded
                clip: true
                height: visible ? Math.min(contentHeight, parent.height - collectBtn.height - uncollectBtn.height - 56) : 0
                width: parent.width
                anchors{
                    top: uncollectBtn.bottom
                    topMargin: 0
                    left: parent.left
                }

                model: categoryListViewModel
                header: Item {
                    height: 8
                }
                footer: Item {
                    height: 0
                }
                spacing: 8
                delegate: Rectangle {
                    height: 28
                    width: parent.width - 32
                    color: Colors.transparent
                    radius: 4
                    anchors.horizontalCenter: parent.horizontalCenter

                    clip: true

                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        LightToolTip {
                            visible: mouseArea.containsMouse && menuText.implicitWidth > menuText.width
                            tip: name
                        }

                        onClicked: {
                            cameraMoveAssetTab.selectCategorySlug = categoryListViewModel.getCategorySlug(index);
                            cameraMoveAssetTab.selectCategoryIndex = index;
                            cameraMoveAssetTab.selectTabIndex = 1;
                        }
                    }

                    Text {
                        id: menuText
                        width: parent.width - 24
                        text: name
                        anchors{
                            left: parent.left
                            right: parent.right
                            rightMargin: QmlConstants.isWhiteXtra() ? 12 : 8
                            leftMargin: QmlConstants.isWhiteXtra() ? 18 : 12
                        }
                        font.pixelSize: 12
                        color: cameraMoveAssetTab.selectCategorySlug === categoryListViewModel.getCategorySlug(index) && cameraMoveAssetTab.selectTabIndex == 1 ? ColorsConfig.color_brand : Colors.color_check_button_text_normal
                        elide: Text.ElideRight
                        wrapMode: Text.NoWrap
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

        }
    }

    rightView: Component{
        Item{
            id: resourcesTab
            property bool hasClearSelectItem: false
            height: 200
            width: parent.width

            StackLayout {
                id: stackLayout
                anchors.fill: parent
                clip: true
                currentIndex: cameraMoveAssetTab.selectTabIndex  // 用来进行页面切换

                CameraMoveCollectResourceTab{
                    id: collectResourceTab
                    cameraMoveAssertModel:cameraMoveAssetTab.cameraMoveAssertModel
                }

                CameraMoveDavinciResourceTab{
                    categoryIndex: selectCategoryIndex
                    assertModel:cameraMoveAssertModel
                }
            }

            // 监听点击背景 (为了做取消选中)
            Item {
                id: bgView
                visible: resourcesTab.hasClearSelectItem
                parent: UiUtils.getTopParent(resourcesTab)
                anchors.fill: parent
                PointHandler {
                    onGrabChanged: (transition, point) => {
                        var clickPoint = bgView.mapToItem(playerPanel, point.position);
                        if(playerPanel.contains(clickPoint)) {
                            return;
                        }
                        point.accepted = false;
                        if(point.timeHeld !== 0){
                            return;
                        }
                        resourcesTab.hasClearSelectItem = false;
                        //globalSignal.unPreviewMovementAction();
                    }
                }
            }
        }
    }
}


