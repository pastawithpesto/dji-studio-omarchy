import QtQuick 2.15
import Config 1.0
import Controls 1.0
import Qt5Compat.GraphicalEffects
import app_qrc 1.0
import QtQuick.Controls
import QtQuick.Layouts 1.3
import QtQuick.Dialogs
import OverlayTextListModel 1.0


MaterialTabBaseView{
    id: overlayTextMaterialTabView
    property OverlayTextListModel textListModel: OverlayTextListModel {}
    property int selectCategoryIndex: 0; //当前选中的左侧目录列表中索引  //0: 默认文本  1: 花字  2: 文字模板

    leftView: Component {
        TextTypeSelector {
            textListModel: overlayTextMaterialTabView.textListModel
        }
    }

    rightView: Component {
        // TextPanel {
        //     textListModel: overlayTextMaterialTabView.textListModel
        // }
        Item {
            id: textResourcesTab
            width: parent.width
            StackLayout {
                id: stackLayout
                anchors.fill: parent
                anchors{
                    top: parent.top; topMargin: 16;
                }
                clip: true
                currentIndex: 0 //overlayTextMaterialTabView.selectTabIndex

                TextResourceTab {
                    textListModel: overlayTextMaterialTabView.textListModel
                }
                //花字panel
                //文字模板penel
            }

        }
    }
}
