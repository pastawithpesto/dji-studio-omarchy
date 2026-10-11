/**
 * @author: congmu.li
 * @details: 转场常量配置
 * @date: 2025-12-02
 */

pragma Singleton
import QtQuick 2.15

QtObject {
    readonly property int zIndexTransition: 10
    readonly property int zIndexClipArea: 30
    readonly property int clipAreaWidth: 5
    readonly property real itemGap: 1.0
    readonly property real minTransitionWidth: 5.0

    readonly property int defaultFps: 30
    readonly property int timebase: 30000

    function oneFrameDuration(fps) {
        return timebase / (fps || defaultFps);
    }

    readonly property string cursorCutLeft: ":/icons/ic_cutleft.svg"
    readonly property string cursorCutRight: ":/icons/ic_cutright.svg"
    readonly property int cursorSize: 24

    readonly property string transitionIconPath: "qrc:/icons/transition/icon_transition.svg"
    readonly property int transitionIconSize: 16
}
