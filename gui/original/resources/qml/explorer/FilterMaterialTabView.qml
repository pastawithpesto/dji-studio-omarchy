import QtQuick 2.15
import Config 1.0
import Controls 1.0
import Qt5Compat.GraphicalEffects
import FilterListModel 1.0
import QtQuick.Controls
import app_qrc 1.0
import QtQuick.Dialogs


MaterialTabBaseView{
    id: filterTabBaseView
    property FilterListModel allFilterModels: FilterListModel {}
    leftView: Component {
        FilterTypeSelector {
            allFilterCategoryModels: filterTabBaseView.allFilterModels.cateogrysModel
        }
    }

    rightView: Component {
        FilterTab {
            allFilterModels: filterTabBaseView.allFilterModels
        }
    }
}


