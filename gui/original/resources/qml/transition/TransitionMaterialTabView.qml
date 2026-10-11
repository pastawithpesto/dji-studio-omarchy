import QtQuick 2.15
import Config 1.0
import Controls 1.0
import Qt5Compat.GraphicalEffects
import TransitionMaterialViewModel 1.0
import QtQuick.Controls
import app_qrc 1.0
import QtQuick.Dialogs
import "../explorer"
MaterialTabBaseView{
    id: transitionMaterialTabView
    property TransitionMaterialViewModel transitionMaterialViewModel: TransitionMaterialViewModel {}
    property string selectCategorySlug: ""; // 当前选中的左侧目录列表中的项对应的slug
    property int selectCategoryIndex: -1; // 当前选中的左侧目录列表中索引
    property int selectTabIndex: 1; // 当前选中的右侧资源列表tab索引: 收藏Tab(0), 非收藏资源Tab(1), 默认是1
    leftView: Component {
        TransitionTypeSelector {
            transitionCategorysModel: transitionMaterialViewModel.cateogrysModel
        }
    }

    rightView: Component {
        TransitionListPanel{
            transitionMaterialModel: transitionMaterialViewModel
        }
    }
}

