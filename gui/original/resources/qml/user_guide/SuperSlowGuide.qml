import QtQuick 2.15
import Controls 1.0
import Config 1.0
import Qt5Compat.GraphicalEffects
import app_qrc 1.0

GuideBeginPopup {
    hasTopImage: true
    imageSource: "qrc:/icons/icon_super_slow_guide.png"
    isAnimatedImage: false
    imageRounded: true
    popupWidth: 266
    nextBtnRightMargin: 0
    isShowStep: false

    titleText: qsTr("pccut_superslow_btn")
    descriptionText: qsTr("pccut_superslow_beginner_text_1")
    nextBtnText: qsTr("pccut_guide_start")
    finishBtnText: qsTr("pccut_guide_done")
}
