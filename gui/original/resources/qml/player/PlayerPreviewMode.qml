import QtQuick 2.15
import Controls 1.0
import Config 1.0

Item {
    id: previewMode

    enum Type {
        Single,
        Multi
    }
    readonly property int iconSize: 20
    property int type: PlayerPreviewMode.Type.Single

    Rectangle {
        width: 136
        height: 28
        anchors.centerIn: parent
        color: Colors.color_1F2021
        radius: 4

        IconButton {
            id: mainMode
            radius: 4
            iconHeight: iconSize
            iconWidth: iconSize
            normalColor: type === PlayerPreviewMode.Type.Single ? Colors.color_454649 : Colors.transparent
            useNormalBgColor: true
            iconSource: type === PlayerPreviewMode.Type.Single
                ? "qrc:/icons/player/ic_previewmode_single_white.svg"
                : "qrc:/icons/player/ic_previewmode_single_gray.svg"
            hoverIconSource: "qrc:/icons/player/ic_previewmode_single_white.svg"
            pressedIconSource: hoverIconSource
            externalOpacity: true
            anchors {
                left: parent.left
                right: parent.horizontalCenter
                top: parent.top
                bottom: parent.bottom
            }
            hoverTextFunc: function() {
                return qsTr("pccut_panel_preview_single");
            }
            onClicked: {
                type = PlayerPreviewMode.Type.Single
                logger.d("single perspective clicked")
                eventTracker.trackEvent("pccut_panel_preview_single_click")
            }
        }

        IconButton {
            id: multiMode
            radius: 4
            iconHeight: iconSize
            iconWidth: iconSize
            normalColor: type === PlayerPreviewMode.Type.Multi ? Colors.color_454649 : Colors.transparent
            useNormalBgColor: true
            iconSource: type === PlayerPreviewMode.Type.Multi
                ? "qrc:/icons/player/ic_previewmode_multi_white.svg"
                : "qrc:/icons/player/ic_previewmode_multi_gray.svg"
            hoverIconSource: "qrc:/icons/player/ic_previewmode_multi_white.svg"
            pressedIconSource: hoverIconSource
            externalOpacity: true
            anchors {
                left: mainMode.right
                top: parent.top
                bottom: parent.bottom
                right: parent.right
            }
            hoverTextFunc: function() {
                return qsTr("pccut_panel_preview_multiple");
            }
            onClicked: {
                type = PlayerPreviewMode.Type.Multi
                logger.d("multi perspective clicked")
                eventTracker.trackEvent("pccut_panel_preview_multiple_click")
            }
        }
    }
}
