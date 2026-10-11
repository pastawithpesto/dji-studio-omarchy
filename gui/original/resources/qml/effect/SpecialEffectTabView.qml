import QtQuick 2.15
import Config 1.0
import Controls 1.0
import Qt5Compat.GraphicalEffects
import SpecialEffectResourceModel 1.0
import QtQuick.Controls
import app_qrc 1.0
import QtQuick.Dialogs
import QtQuick.Layouts 1.3
import "../explorer"


MaterialTabBaseView
{
    id: effectTabBaseView
    property SpecialEffectResourceModel allEffectModels: SpecialEffectResourceModel {}
    property int selectedTabIndex: 1; // 当前选中的右侧资源列表tab索引: 收藏Tab(0), 非收藏资源Tab(1), 默认是1

    leftView: Component {

        SpecialEffectTypeSelector {

            allEffectCategoryModels: effectTabBaseView.allEffectModels.categoriesModel

            onCurTabIndexChanged: {
                selectedTabIndex = curTabIndex < 0 ? 0 : 1
            }
        }
    }

    rightView : Component {

        Item{
            id: resourcesTab
            height: 200
            width: parent.width

            StackLayout {
                id: stackLayout
                anchors.fill: parent
                clip: true
                currentIndex: effectTabBaseView.selectedTabIndex  // 用来进行页面切换

                SpecialEffectCollectItemListView {

                    id: collectItemList
                    allEffectModels: effectTabBaseView.allEffectModels
                }

                SpecialEffectResourceItemListView {

                    id: resourceItemList
                    allEffectModels: effectTabBaseView.allEffectModels
                }
            }
        }
    }
}


