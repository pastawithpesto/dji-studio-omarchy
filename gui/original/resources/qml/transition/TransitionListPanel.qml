import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.3
import Qt5Compat.GraphicalEffects
import Config 1.0
import Controls 1.0
import TransitionCategorysModel 1.0
import TransitionMaterialViewModel 1.0
import app_qrc 1.0

/**
 * @author hugo.li
 * @desc 转场右侧素材区域
 * @create_date 2025-11-14
 */
Item {
    id: resourcesTab
    property TransitionMaterialViewModel transitionMaterialModel

    StackLayout {
        id: stackLayout
        anchors.fill: parent
        anchors{
            top: parent.top
        }

        clip: true

        currentIndex: transitionMaterialModel.cateogrysModel.selectIndex < 0 ? 0 : 1


        TransitionCollectResourceTab{
            id: collectResourceTab
        }

        TransitionDavinciResourceTab{
            id: davinciResourceTab
        }
    }

    EmptyPanel {
        id: emptyPanel
        visible:( transitionMaterialModel.cateogrysModel.state === 2 ||  transitionMaterialModel.cateogrysModel.state === 0 )&& stackLayout.currentIndex === 1
        width: parent.width
        height: parent.height
        anchors.centerIn: parent
        no_network_mode: true
        onClick: {
            transitionMaterialModel.loadResource();
        }
    }
}
