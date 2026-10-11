import QtQuick 2.15
import QtQuick.Controls
import Controls 1.0
import Config 1.0
import TrackingManager 1.0
import QmlConstants 1.0
import "../tracking"
import app_qrc 1.0
import UsedFunctionManager 1.0
import ProjectSettingsInfo 1.0

/**
 * @author robert.guo
 * @desc 取景右侧面板中tk部分
 * @create_date 2024-07-16
 */
Rectangle {
    width: parent.width
    height: 32
    radius: RadiusConfig.radius_4_88

    // tk 状态读自 SettingPanel 持久变量，面板重建后不丢失
    property bool isEditMode: settingPanel.isInTrackingFragment
    property bool trackingEnable: true
    property bool panoramaPanleVisible: !settingPanel.isTkSupported && !settingPanel.isInTrackingFragment

    color: panoramaPanleVisible ? Colors.color_2F3032_40 : !trackingEnable ? Colors.color_2F3032_40 : mouseArea.containsMouse ? Colors.color_button_background_hovered : Colors.color_button_background_normal

    Item {
        anchors.centerIn: parent
        width: childrenRect.width
        height: parent.height

        Image {
            id: tkOperate
            width: 16
            height: 16
            source: panoramaPanleVisible ? "qrc:/icons/trackToolBar/toolbar_track_disable.svg" : !trackingEnable ? "qrc:/icons/trackToolBar/toolbar_track_disable.svg" : isEditMode ?
                                          "qrc:/icons/trackToolBar/toolbar_track_delete.svg" : "qrc:/icons/trackToolBar/toolbar_track.svg"

            sourceSize: Qt.size(16, 16)
            anchors.verticalCenter: parent.verticalCenter
            opacity: panoramaPanleVisible ? 0.2 : 1
        }

        Text {
            text: panoramaPanleVisible ? qsTr("pccut_panel_video_track") : isEditMode ? qsTr("pccut_panel_video_track_delete") : qsTr("pccut_panel_video_track")
            color: panoramaPanleVisible ? Colors.color_EEEEEE_20 : !trackingEnable ? Colors.color_666666 : Colors.color_EEEEEE
            y: (parent.height - height) / 2 // 不用anchors是因为text的高度为奇数，anchors的对齐模式只能为整数导致对其后中心有0.5px偏差
            anchors.left: tkOperate.right
            anchors.leftMargin: 5
            font.pixelSize: 12
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: {
            if (isEditMode) {
                // 删除轨道上所选择的tk片段
                globalSignal.trackingSegmentRemoveAction(true)
                var projectId = draftManager.activeProjectEnvId();
                UsedFunctionManager.removeFunction(projectId,UsedFunctionManager.EditorFunctionType.TRACKING);
                eventTracker.trackEvent("pccut_tk_delete", {"use_method": "video_button"})
            } else {
                globalSignal.trackingSwitchSpeed(1)
                eventTracker.trackEvent("pccut_tk_enter", {"use_method": "video_button", "tk_sdk": QmlConstants.trackingSDKVersion})
            }
        }
    }

    // 置灰
    Rectangle {
        id: visibleRectangle
        anchors.fill: parent
        visible: panoramaPanleVisible
        color:  Colors.color_transparent
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
            }
        }
    }
}
