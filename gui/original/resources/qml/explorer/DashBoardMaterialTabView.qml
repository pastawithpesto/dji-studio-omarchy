import QtQuick 2.15
import Config 1.0
import Controls 1.0
import Qt5Compat.GraphicalEffects
import DashboardListModel 1.0
import QtQuick.Controls
import app_qrc 1.0
import QtQuick.Dialogs

MaterialTabBaseView{
    id: dashboardMaterialTabView
    property DashboardListModel dashboardListModel: DashboardListModel {}
    leftView: Component {

        DashboardTypeSelector {
            dashboardCategorysModel: dashboardMaterialTabView.dashboardListModel.cateogrysModel
        }
    }

    rightView: Component {
        DashboardPanel{
            dashboardListModel: dashboardMaterialTabView.dashboardListModel

        }
    }
}


