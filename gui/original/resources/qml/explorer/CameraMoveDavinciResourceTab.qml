import QtQuick 2.15
import Config 1.0
import Controls 1.0
import Qt5Compat.GraphicalEffects
import QtQuick.Controls
import app_qrc 1.0
import QtQuick.Dialogs
import CameraMoveAssertViewModel
import CameraMoveAssertModel
import MovementCategoryListViewModel
import MovementGrideViewModel

/**
 * @author mathy.shi
 * @desc 运镜模版上云资源面板
 * @create_date 2025-10-21
 */
    Item{
        id: root
        height: 200
        width: parent.width
        property int categoryIndex: selectCategoryIndex; // 当前选中的左侧目录列表类型索引
        property CameraMoveAssertModel assertModel;
        MovementCategoryListViewModel{
            id: categoryListViewModel
            assertModel:root.assertModel
        }

        // 每一个分类下的所有资源为ListView中的一个Item，每一个Item(delegate)使用GridView来实现
        ListView {
            id: resourceListView
            anchors.fill: parent
            // interactive: false // 禁用所有交互（包括滚动和拖拽）
            anchors{
                left: parent.left
                leftMargin: 12
            }
            // 可以观测界面的四倍，防止滚动的时候突然加载，导致滚动条卡顿引起的滚动效果不流畅问题
            cacheBuffer: root.height * 4
            property int categoryIndex: root.categoryIndex
            property int currentState: 0  // 0 代表默认状态
            boundsBehavior: Flickable.StopAtBounds
            model: categoryListViewModel
            spacing: 8
            header: Item { height: 0 }
            footer: Item { height: 16 }
            delegate: resourceListDelegate

            function getCurrentIndex(contentY, height) {
                if (contentY <= 0) return 0
                if (contentY >= resourceListView.contentHeight - height) return resourceListView.count - 1
                return indexAt(0, contentY + height / 2)
            }

            // 滚动时同步更新左侧导航选中项
            onContentYChanged: {
                if (currentState === 0) {
                    currentState = 1
                }
                if (currentState === 2) {
                    return
                }
                var currentIndex = getCurrentIndex(contentY, height)
                // 两个分类之间会出现 -1
                if (currentIndex < 0) {
                    if (currentState === 1) {
                        currentState = 0
                    }
                    return
                }
                if (categoryIndex !== currentIndex) {
                    cameraMoveAssetTab.selectCategoryIndex = currentIndex
                    cameraMoveAssetTab.selectCategorySlug = categoryListViewModel.getCategorySlug(currentIndex)
                }
                if (currentState === 1) {
                    currentState = 0
                }
            }

            // 左侧导航点击时滚动右侧列表到对应分类
            onCategoryIndexChanged: {
                if (currentState === 0) {
                    currentState = 2
                }
                if (currentState === 1) {
                    return
                }
                if (categoryIndex >= 0 && categoryIndex < resourceListView.count) {
                    resourceListView.positionViewAtIndex(categoryIndex, ListView.Beginning)
                }
                if (currentState === 2) {
                    currentState = 0
                }
            }

            ScrollBar.vertical: ScrollBar{
                Component.onCompleted: {
                    contentItem.color = Colors.color_454649
                }
            }
        }

        onCategoryIndexChanged: {
            // 已移至 resourceListView.onCategoryIndexChanged 处理
        }


        // 在需要时调用此函数
        function getItemPosition(index) {
            // 获取该项在内容区域内的y坐标
            var item = resourceListView.itemAtIndex(index);
            if (item) {
                return item.y;
            }
            return -1;
        }

    // 某一个分类下的所有资源的展示，使用TableView展示
    // 某一个分类下的所有资源实现为ListView中的一个Item，每一个Item(delegate)使用TableView来实现
    Component {  // 某一个分类的TableView
        id: resourceListDelegate
        Item{
            id: containerItem
            height: resourceTableView.contentHeight + categoryTitle.height + 24  // 绑定高度到内容高度
            width: root.width
            MovementGrideViewModel{
                id: movementListViewModel
                assertModel:cameraMoveAssertModel
                categorySlug: model.slug
            }

            // 每段的上间距
            Rectangle{
                id: headerRec
                width: parent.width
                height: 16
                color: Colors.transparent
            }

            Text {
                id: categoryTitle
                anchors.top: headerRec.bottom
                height: 16
                width: containerItem.width
                text: movementListViewModel.categoryName
                color: Colors.color_EEEEEE
                font {
                    pixelSize: 12
                }
            }

            // 其中展示某一个分类下的所有资源
            GridView {
                id: resourceTableView
                interactive: false // 禁用所有交互（包括滚动和拖拽）,必须禁用，否则会与外层的ListView双指滚动操作冲突
                height: parent.height
                width: parent.width

                anchors{
                    top: categoryTitle.bottom
                    topMargin: 16
                    left: parent.left
                }
                // 设置单元格大小  14代表单元格之间的间距
                cellWidth: 80 + 12
                cellHeight: 100 + 12

                model: movementListViewModel
                delegate: CameraMoveItemView {
                    visible: (typeof model.name !== "undefined")
                    cameraMoveAssertModel: cameraMoveAssetTab.cameraMoveAssertModel
                    resourceName: (typeof model.name !== "undefined") ? model.name : ""
                    imageUrl: (typeof model.imageUrl !== "undefined") ? model.imageUrl : "";
                    // categorySlug: cameraMoveAssetTab.selectCategorySlug;
                    categorySlug: movementListViewModel.categorySlug;
                    resourceSlug:(typeof model.slug !== "undefined") ? model.slug : "";
                    implicitWidth: 80
                    implicitHeight: 100
                }
            }
        }
    }
}


