import QtQuick 2.15
import Config 1.0
import Controls 1.0
import Qt5Compat.GraphicalEffects
import AudioCategoryListModel 1.0
import AudioListModel 1.0
import QtQuick.Controls
import app_qrc 1.0
import QtQuick.Dialogs


MaterialTabBaseView{
    id: audiomaterialTabView
    property AudioCategoryListModel categoryModel: AudioCategoryListModel {}
    leftView: Component {
        AudioTypeSelector {
            id: audioTabLeft
            categoryModel: audiomaterialTabView.categoryModel
        }
    }

    rightView: Component {
        AudioPanel{
            categoryModel: audiomaterialTabView.categoryModel
        }
    }
}


