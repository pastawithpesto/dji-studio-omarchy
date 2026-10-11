import QtQuick 2.15
import QtQuick.Controls
import Controls 1.0
import Config 1.0

import KeyframeBtnViewModel 1.0
import app_qrc 1.0
import UsedFunctionManager 1.0
import ProjectSettingsInfo 1.0
import Nova 1.0

/**
 * @author robert.guo
 * @desc 取景右侧面板, 顶部工具栏
 * @create_date 2024-06-12
 */
Item {
    id: root
    property bool isTabVisible: panoKfVm.tabMaskVisible
    property bool isPresetViewMode: panoKfVm.presetViewMode
    // 是否有上一个关键帧
    property bool hasPreviousKeyFrame: panoKfVm.hasPreviousKeyFrame && !root.isTabVisible
    // 是否有下一个关键帧
    property bool hasNextKeyFrame: panoKfVm.hasNextKeyFrame && !root.isTabVisible

    property int topMarginToParent: 0
    // 关键帧增删 + 上一帧/下一帧/reset 已接入 nova，状态与动作走此 VM。
    property PanoramaKeyframeViewModel panoKfVm

    Rectangle {
        anchors.fill: parent
        color: Colors.color_transparent
        anchors {
            left: parent.left
            leftMargin: 12
            right: parent.right
            rightMargin: 12
        }

        Text {
            id: panoramaToolTitleName
            text: qsTr("pccut_panel_video_reframe_parameter")
            color: Colors.color_EEEEEE
            font.pixelSize: 12
            anchors {
                verticalCenter: parent.verticalCenter
            }
        }

        PanoramaTitleToolItem {
            id: previousKeyFrame
            width: 20
            height: 20
            anchors {
                right: addKeyFrame.left
            }
            imgSource: hasPreviousKeyFrame ? "qrc:/icons/panorama/previous_key_frame.svg" : "qrc:/icons/panorama/previous_key_frame_disable.svg"
            hoverImgSource: hasPreviousKeyFrame ? "qrc:/app_qrc/icons/previous_hover_key_frame.svg" : "qrc:/icons/panorama/previous_key_frame_disable.svg"
            toolTip: qsTr("pccut_panel_video_lastkeyframe")
            onClick: {
                if (!hasPreviousKeyFrame) {
                    return;
                }
                editorManager.pause();
                panoKfVm.previousKeyframe();
                editorDraftManager.saveDraft();
                eventTracker.trackEvent("pccut_keyframe_last_click")
            }
        }

        PanoramaTitleToolItem {
            id: addKeyFrame
            width: 20
            height: 20

            anchors {
                right: nextKeyFrame.left
            }
            imgSource: panoKfVm.normalKeyframeEnable && !root.isTabVisible
                        ? (panoKfVm.hasKeyFrame ? "qrc:/icons/panorama/remove_key_frame.svg" : "qrc:/icons/panorama/add_key_frame.svg")
                        : (panoKfVm.hasKeyFrame ? "qrc:/icons/panorama/remove_key_frame_disable.svg" : "qrc:/icons/panorama/add_key_frame_disable.svg")
            hoverImgSource: panoKfVm.normalKeyframeEnable && !root.isTabVisible
                        ? (panoKfVm.hasKeyFrame ? "qrc:/app_qrc/icons/remove_hover_key_frame.svg" : "qrc:/app_qrc/icons/add_hover_key_frame.svg")
                        : (panoKfVm.hasKeyFrame ? "qrc:/icons/panorama/remove_key_frame_disable.svg" : "qrc:/icons/panorama/add_key_frame_disable.svg")
            toolTip: panoKfVm.hasKeyFrame ? qsTr("pccut_panel_video_removekeyframe") : qsTr("pccut_panel_video_addkeyframe")
            onClick: {
                if(!panoKfVm.normalKeyframeEnable){
                    return;
                }
                editorManager.pause();
                panoKfVm.hasKeyFrame ? panoKfVm.removeKeyframe() : panoKfVm.addKeyframe();
                let eventName = !panoKfVm.hasKeyFrame ? "pccut_keyframe_delete" : "pccut_keyframe_add"
                var projectId = draftManager.activeProjectEnvId();
                eventTracker.trackEvent(eventName, {"use_method": "video_tab"})
                editorDraftManager.saveDraft();
                if(editorManager.isInUserGuideStatus){
                    globalSignal.nextStepInKfGuide();
                }
            }
            onXChanged: {
                globalSignal.addKeyFrameBtnPosUpadate(addKeyFrame.x + parent.anchors.leftMargin, addKeyFrame.y + root.y, addKeyFrame.width, addKeyFrame.height);
            }
        }

        PanoramaTitleToolItem {
            id: nextKeyFrame
            width: 20
            height: 20

            anchors {
                right: reset.left
                rightMargin: 4
            }

            imgSource: hasNextKeyFrame ? "qrc:/icons/panorama/next_key_frame.svg" : "qrc:/icons/panorama/next_key_frame_disable.svg"
            hoverImgSource: hasNextKeyFrame ? "qrc:/app_qrc/icons/next_hover_key_frame.svg" : "qrc:/icons/panorama/next_key_frame_disable.svg"
            toolTip: qsTr("pccut_panel_video_nestkeyframe")
            onClick: {
                if (!hasNextKeyFrame) {
                    return;
                }
                editorManager.pause();
                panoKfVm.nextKeyframe();
                editorDraftManager.saveDraft();
                eventTracker.trackEvent("pccut_keyframe_next_click")
            }
        }

        PanoramaTitleToolItem {
            id: reset
            width: 20
            height: 20

            anchors {
                right: parent.right
            }

            // reset 清散点关键帧 + 区域/运镜/tk 组 + offset；对应启用项：散点/区域/运镜(hasKeyFrame/前后帧)、
            // tk 组(hasTrackingGroup，对齐老 hasTrackingFragment)、拖画面改基准不建帧(hasChangedParam)。
            disabled: (panoKfVm.hasKeyFrame || panoKfVm.hasPreviousKeyFrame || panoKfVm.hasNextKeyFrame
                       || panoKfVm.hasChangedParam || panoKfVm.hasTrackingGroup)
                       && (!root.isTabVisible || isPresetViewMode) ? false : true

            imgSource: "qrc:/icons/ic_reset.svg"
            hoverImgSource: disabled ? "qrc:/icons/ic_reset.svg" :"qrc:/icons/ic_reset_hover.svg"
            toolTip: qsTr("pccut_panel_video_clearkeyframe")
            onClick: {
                if(!disabled)
                {
                    editorManager.pause();
                    panoKfVm.resetKeyframe();
                    editorDraftManager.saveDraft();
                    eventTracker.trackEvent("pccut_keyframe_reset_click")
                }
            }
        }
    }
}
