import QtQuick 2.15
import Controls 1.0
import Config 1.0
import QtQml.Models 2.15
import QPanoramaLimit 1.0
import app_qrc 1.0

/**
 * @author robert.guo
 * @desc 取景右侧面板UI的ViewModel
 * @create_date 2024-06-12
 */
QtObject {
    property ListModel selectPerspectiveListModel: ListModel {
        ListElement {
            text: qsTr("pccut_panel_video_tinyplanet")
            selectSource: "qrc:/app_qrc/icons/asteroid_select.svg"
            unselectSource: "qrc:/icons/panorama/asteroid_unselect.svg"
            disableSource: "qrc:/icons/panorama/asteroid_disable.svg"
        }
        ListElement {
            text: qsTr("pccut_panel_video_rultrawide")
            selectSource: "qrc:/app_qrc/icons/super_wide_angle_select.svg"
            unselectSource: "qrc:/icons/panorama/super_wide_angle_unselect.svg"
            disableSource: "qrc:/icons/panorama/super_wide_angle_disable.svg"
        }
        ListElement {
            text: qsTr("pccut_panel_video_wide")
            selectSource: "qrc:/app_qrc/icons/wide_angle_select.svg"
            unselectSource: "qrc:/icons/panorama/wide_angle_unselect.svg"
            disableSource: "qrc:/icons/panorama/wide_angle_disable.svg"
        }
        ListElement {
            text: qsTr("pccut_panel_video_dewarp")
            selectSource: "qrc:/app_qrc/icons/standard_select.svg"
            unselectSource: "qrc:/icons/panorama/standard_unselect.svg"
            disableSource: "qrc:/icons/panorama/standard_disable.svg"
        }
    }

    property ListModel selectPerspectiveSetArgumentListModel: ListModel {}

    property ListModel transitionEffectListModel: ListModel {
        ListElement {
            text: qsTr("pccut_panel_video_transition_no")
            selectSource: "qrc:/app_qrc/icons/transition_effect_none_select.svg"
            unselectSource: "qrc:/icons/panorama/transition_effect_none_unselect.svg"
            unenableSource: "qrc:/icons/panorama/transition_effect_none_unenable.svg"
            type: 0
            trackEventName: "none"
        }
        ListElement {
            text: qsTr("pccut_panel_video_transition_smooth_dlssolve")
            selectSource: "qrc:/app_qrc/icons/transition_effect_linear_smooth_select.svg"
            unselectSource: "qrc:/icons/panorama/transition_effect_linear_smooth_unselect.svg"
            unenableSource: "qrc:/icons/panorama/transition_effect_linear_smooth_unenable.svg"
            type: 3
            trackEventName: "linear_smoothing"
        }
        ListElement {
            text: qsTr("pccut_panel_video_transition_sllpin_fadeout")
            selectSource: "qrc:/app_qrc/icons/transition_effect_quick_in_slow_out_select.svg"
            unselectSource: "qrc:/icons/panorama/transition_effect_quick_in_slow_out_unselect.svg"
            unenableSource: "qrc:/icons/panorama/transition_effect_quick_in_slow_out_unenable.svg"
            type: 8
            trackEventName: "fastin_slowout"
        }
        ListElement {
            text: qsTr("pccut_panel_video_transition_fadein_sllpout")
            selectSource: "qrc:/app_qrc/icons/transition_effect_slow_in_quick_out_select.svg"
            unselectSource: "qrc:/icons/panorama/transition_effect_slow_in_quick_out_unselect.svg"
            unenableSource: "qrc:/icons/panorama/transition_effect_slow_in_quick_out_unenable.svg"
            type: 7
            trackEventName: "slowin_fastout"
        }

        ListElement {
            text: qsTr("pccut_panel_video_transition_sllpin_sllpout")
            selectSource: "qrc:/app_qrc/icons/transition_effect_quick_in_quick_out_select.svg"
            unselectSource: "qrc:/icons/panorama/transition_effect_quick_in_quick_out_unselect.svg"
            unenableSource: "qrc:/icons/panorama/transition_effect_quick_in_quick_out_unenable.svg"
            type: 37
            trackEventName: "fastin_fastout"
        }
        ListElement {
            text: qsTr("pccut_panel_video_transition_fadein_fadeout")
            selectSource: "qrc:/app_qrc/icons/transition_effect_slow_in_slow_out_select.svg"
            unselectSource: "qrc:/icons/panorama/transition_effect_slow_in_slow_out_unselect.svg"
            unenableSource: "qrc:/icons/panorama/transition_effect_slow_in_slow_out_unenable.svg"
            type: 9
            trackEventName: "slowin_slowout"
        }
        ListElement {
            text: qsTr("pccut_panel_video_transition_smoothy_dlssolve")
            selectSource: "qrc:/app_qrc/icons/transition_effect_linear_select.svg"
            unselectSource: "qrc:/icons/panorama/transition_effect_linear_unselect.svg"
            unenableSource: "qrc:/icons/panorama/transition_effect_linear_unenable.svg"
            type: 1
            trackEventName: "linear_smoothy"
        }
    }

    Component.onCompleted: {
        selectPerspectiveSetArgumentListModel.append({
            text: qsTr("pccut_panel_video_fov"),
            selectSource: "qrc:/icons/panorama/field_angle.svg",
            disableSource: "qrc:/icons/panorama/field_angle_disabled.svg",
            canModify: true,
            dragCoeff: 1,
            value: 0,
            enableMulpleText: false,
            minValue: QPanoramaLimit.FOV_MIN,
            maxValue: QPanoramaLimit.FOV_MAX
        });
        selectPerspectiveSetArgumentListModel.append({
            text: qsTr("pccut_panel_video_distortion"),
            selectSource: "qrc:/icons/panorama/distortion_control.svg",
            disableSource: "qrc:/icons/panorama/distortion_control_disabled.svg",
            canModify: true,
            dragCoeff: 0.01,
            value: 0,
            enableMulpleText: false,
            minValue: QPanoramaLimit.DISTORTION_MIN,
            maxValue: QPanoramaLimit.DISTORTION_MAX
        });
        selectPerspectiveSetArgumentListModel.append({
            text: qsTr("pccut_panel_video_pan"),
            selectSource: "qrc:/icons/panorama/horizontal_angle.svg",
            disableSource: "qrc:/icons/panorama/horizontal_angle_disabled.svg",
            canModify: true,
            dragCoeff: 1,
            value: 0,
            enableMulpleText: true,
            minValue: QPanoramaLimit.ANGLE_MIN,
            maxValue: QPanoramaLimit.ANGLE_MAX
        });
        selectPerspectiveSetArgumentListModel.append({
            text: qsTr("pccut_panel_video_tilt"),
            selectSource: "qrc:/icons/panorama/vertical_angle.svg",
            disableSource: "qrc:/icons/panorama/vertical_angle_disabled.svg",
            canModify: true,
            dragCoeff: 1,
            value: 0,
            enableMulpleText: true,
            minValue: QPanoramaLimit.ANGLE_MIN,
            maxValue: QPanoramaLimit.ANGLE_MAX
        });
        selectPerspectiveSetArgumentListModel.append({
            text: qsTr("pccut_panel_video_roll"),
            selectSource: "qrc:/icons/panorama/rolling_angle.svg",
            disableSource: "qrc:/icons/panorama/rolling_angle_disabled.svg",
            canModify: true,
            dragCoeff: 1,
            value: 0,
            enableMulpleText: true,
            minValue: QPanoramaLimit.ANGLE_MIN,
            maxValue: QPanoramaLimit.ANGLE_MAX
        });
    }

    // 过渡效果是否使能
    property bool transitionEffectEnable: keyframeEnable || trackingKeyframeEnable

    // 关键帧的过渡效果是否使能
    property bool keyframeEnable: false

    // tracking的过渡效果是否使能
    property bool trackingKeyframeEnable: false

    // 当前过渡效果类型
    property int transitionEffectIndex: -1

    // 当前光标位置是否有关键帧
    property bool hasKeyFrame: false

    // 是否进入tk编辑状态
    property bool isEnteringTkEdit: false


    function getTransitonEffectSource(index) {
        if (transitionEffectEnable) {
            return index === transitionEffectIndex ? transitionEffectListModel.get(index).selectSource : transitionEffectListModel.get(index).unselectSource
        } else {
            return transitionEffectListModel.get(index).unenableSource
        }
    }

    function getIndexByType(type) {
        for (var i = 0; i < transitionEffectListModel.count; i++) {
            if (transitionEffectListModel.get(i).type === type) {
               return i;
            }
        }
        return -1;
    }

    /**
     * @desc 获取选择视角，各个参数选项的text的展示颜色
     *
     * @param index 当前参数选项索引
     * @return 当前参数选项展示颜色
     */
    function getSelectPerspectiveConfigColor(index) {
        if (!selectPerspectiveSetArgumentListModel.get(index).canModify) {
            return Colors.color_panorama_enter_tk_edit_normal
        } else {
            return Colors.color_999999
        }
    }

    /**
     * @desc 获取选择视角，各个参数选项是否使能
     *
     * @param index 当前参数选项索引
     * @return 当前参数选项是否使能
     */
    function getSelectPerspectiveConfigEnable(index) {
        if (!selectPerspectiveSetArgumentListModel.get(index).canModify) {
            return false
        } else {
            return true
        }
    }

    /**
     * @desc 获取选择视角item的图片source
     *
     * @param selected 当前item是否被选择
     * @param index 当前item的索引
     * @return 当前item的source
     */
    function getSelectePerspectiveSource(selected, index) {

        if (selected) {
            return panoramaPanelViewModel.selectPerspectiveListModel.get(index).selectSource
        } else {
            return panoramaPanelViewModel.selectPerspectiveListModel.get(index).unselectSource
        }
    }

    function setPerspectiveArgumentValue(value, index) {
        if (index >= 0 && index < selectPerspectiveSetArgumentListModel.count) {
            selectPerspectiveSetArgumentListModel.setProperty(index, "value", value)
        }
    }

    function getAllPerspectiveArgumentValue() {
        let valueList = []
        for (let i = 0; i < selectPerspectiveSetArgumentListModel.count; ++i) {
            valueList.push(selectPerspectiveSetArgumentListModel.get(i).value)
        }
        return valueList
    }
}
