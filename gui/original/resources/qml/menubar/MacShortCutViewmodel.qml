import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.15
import Controls 1.0
import Config 1.0
import "../controller"

/**
 * @author robert.guo
 * @desc windows 快捷键ui面板的数据model类
 * @create_date 2024-12-13
 */
QtObject {
    // 快捷键类型选择时，发送该信号
    signal typeChanged(int type)

    // 标志当前快捷键选择类型索引
    property int currentShortcutType : 0

    /**
     * @desc 设置快捷键tab类型选择
     * @param type 类型
     */
    function setShortCutType(type) {
        currentShortcutType = type
        typeChanged(currentShortcutType)
    }

    /**
     * @desc 获取快捷键面板的右侧按键组合列表
     */
    function getShortcutList() {
        if (currentShortcutType === 0) {
            return playerShortcuts
        } else if (currentShortcutType === 1) {
            return cutShortcuts
        } else {
            return otherShortcuts
        }
    }

    /**
     * @desc 获取当前面板左侧的数据model
     */
    function getLeftModel() {
        if (currentShortcutType == 0) {
            return playerLeftModel
        } else if (currentShortcutType == 1) {
            return cutLeftModel
        } else {
            return otherLeftModel
        }
    }

    /**
     * @desc 获取当前面板右侧的数据model
     */
    function getRightModel() {
        if (currentShortcutType == 0) {
            return playerRightModel
        } else if (currentShortcutType == 1) {
            return cutRightModel
        } else {
            return otherRightModel
        }
    }
    // 播放器左侧数据model
    property ListModel playerLeftModel: ListModel {
        ListElement {action: 16} // PAUSE
        ListElement {action: 17} // FULL_SCREEN / SECOND_FULL_SCREEN
        ListElement {action: 1} // PREVIOUS_FRAME
        ListElement {action: 2} // NEXT_FRAME
        ListElement {action: 3} // PREVIOUS_TEN_FRAME
        ListElement {action: 4} // NEXT_TEN_FRAME
    }

    // 播放器右侧数据model
    property ListModel playerRightModel: ListModel {
        ListElement {action: 14} // START_FRAME
        ListElement {action: 15} // END_FRAME
        ListElement {action: 6} // UP
        ListElement {action: 7} // DOWN
        ListElement {action: 5} // SCREEN_SHOT
    }

    // 剪辑左侧数据model
    property ListModel cutLeftModel: ListModel {
        ListElement {action: 20} // TRACK_ENLARGE
        ListElement {action: 21} // TRACK_SHRINK
        ListElement {action: 8} // PREVIEW_AXIS
        ListElement {action: 9} // ADSORPTION
        ListElement {action: 25} // ROUGH_IN
        ListElement {action: 26} // ROUGH_OUT
        ListElement {action: 28} // CUT_LEFT
        ListElement {action: 29} // CUT_RIGHT
        ListElement {action: 24} // SPLIT
    }

    // 剪辑右侧数据model
    property ListModel cutRightModel: ListModel {
        ListElement {action: 30} // ADD_PANORAMA_KEYFRAME
        ListElement {action: 31} // REMOVE_PANORAMA_KEYFRAME
        // ListElement {action: 40} // ADD_PANORAMA_REGION_KEYFRAME
        // ListElement {action: 41} // REMOVE_PANORAMA_REGION_KEYFRAME
        ListElement {action: 32} // OPEN_TRACKING_POPUP
        ListElement {action: 44} // ADD_DEFAULT_TEXT
        ListElement {action: 45} // CUT_LEFT
        ListElement {action: 46} // CUT_RIGHT
        ListElement {action: 47} // AUDIO_HIGHLIGHT
        ListElement {action: 49} // ADD_MARK_POINT
    }

    // 其他左侧数据model
    property ListModel otherLeftModel:ListModel {
        ListElement {action: 0} // DELETE
        ListElement {action: 22} // UN_DO
        ListElement {action: 23} // RE_DO
        ListElement {action: 35} // IMPORT
        ListElement {action: 34} // EXPORT
    }

    // 其他右侧数据model
    property ListModel otherRightModel: ListModel {
        ListElement {action: 33} // ONEW_PROJECT
        ListElement {action: 27} // CLOSE_PROJECT
        ListElement {action: 100} // QUIT
        ListElement {action: 19} // ESCAPE_FULL_SCREEN
    }
}
