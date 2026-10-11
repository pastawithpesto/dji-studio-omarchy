import QtQuick 2.15
import Controls 1.0
import Config 1.0
import Qt5Compat.GraphicalEffects
import app_qrc 1.0

GuideBeginPopup {
    hasTopImage: true
    imageSource: "qrc:/icons/region_keyframe_begin.webp"
    imageRounded: true
    popupWidth: 266
    nextBtnRightMargin: 0

    titleText: qsTr("pccut_guide_start_keyframe_regional_1")
    stepText: qsTr("pccut_guide_start_keyframe_regional_2")
    descriptionText: qsTr("pccut_guide_start_keyframe_regional_3")
    nextBtnText: qsTr("pccut_guide_start")
    finishBtnText: qsTr("pccut_guide_done")
}
