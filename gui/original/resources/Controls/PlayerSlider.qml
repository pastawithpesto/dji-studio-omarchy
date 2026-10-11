import QtQuick 2.15
import QtQuick.Controls
import Config 1.0
import app_qrc 1.0

Slider {
    id: control
    stepSize: 1
    snapMode: Slider.SnapAlways
    // 边下边播已缓冲区间：[{begin,end}]（帧单位）。默认空 → 无灰条，对其它使用者零影响。
    property var cachedRanges: []
    background: Rectangle {
        y: control.availableHeight / 2 - height / 2
        width: control.availableWidth
        height: 2
        color: Colors.color_button_background_hovered
        // 已缓冲灰条：底轨之上、已播高亮之下；一段 = 一个 Rectangle（支持多段稀疏缓冲）
        Repeater {
            model: control.cachedRanges
            Rectangle {
                readonly property real totalFrames: control.to
                readonly property real beginFrame: Math.min(modelData ? modelData.begin : 0, totalFrames)
                readonly property real endFrame: Math.min(modelData ? modelData.end : 0, totalFrames)
                visible: totalFrames > 0 && endFrame > beginFrame
                x: totalFrames > 0 ? (beginFrame / totalFrames) * parent.width : 0
                width: totalFrames > 0 ? ((endFrame - beginFrame) / totalFrames) * parent.width : 0
                height: parent.height
                color: "#999999"
            }
        }
        Rectangle {
            width: control.visualPosition * parent.width
            height: parent.height
            color: ColorsConfig.color_EEEEEE_4DFFC9
        }
    }
    handle: Rectangle {
        // 备注： 最后两个括号内对control.visualPosition的判断，是当在最左端或最右端时，会有一些漏出
        x: control.visualPosition * (control.availableWidth - width) - (control.visualPosition === 0 ? 1 : 0) + (control.visualPosition === 1 ? 1 : 0)
        y: control.availableHeight / 2 - height / 2
        implicitWidth: 6
        implicitHeight: 12
        color: enabled ? ColorsConfig.color_EEEEEE_4DFFC9 : Colors.color_button_background_hovered
        radius: 3
        border.color: Colors.color_1F2021
        border.width: 1
    }

}
