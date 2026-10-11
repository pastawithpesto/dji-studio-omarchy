import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import UIComponent

// UIToast
//   单条 Toast 视觉，由 UIToastHost.show(...) 创建，业务侧不直接实例化。
//   复用 Qt 原生信号 closed()（动画结束后触发，Host 用此从 model 中移除）。
//   type      UIToastType.Info / Success / Warning / Error
//   duration  毫秒；0 = 常驻不消失
Rectangle {
    id: root

    // ===== 变体 =====
    property int    type: UIToastType.Info
    property int size: UIControlSize.M
    property string text: ""
    property int    duration: UIToastDuration.Medium  // 0 = 常驻
    property bool   closing: false

    signal closed()

    readonly property var _style: UITheme.toast.of(size, type)

    // ===== 颜色字段（Toast 无交互态，cascade 后全 base，仅暴露 base + accent）=====
    property color bgColor:     _style.bg.base
    property color textColor:   _style.text.base
    property color accentColor: _style.accent

    readonly property color resolvedBgColor:   bgColor
    readonly property color resolvedTextColor: textColor

    radius: _style.borderRadius
    color: resolvedBgColor
    implicitWidth:  row.implicitWidth + _style.paddingH * 2
    implicitHeight: Math.max(_style.minHeight, label.implicitHeight + _style.paddingV * 2)
    opacity: 0

    // 阴影
    layer.enabled: true
    layer.effect: DropShadow {
        horizontalOffset: 0
        verticalOffset:   0
        radius:           root._style.shadowRadius
        color:            root._style.shadowColor
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: _style.spacing

        // accent 指示器：仅非 Info 类型创建实例
        Loader {
            active: root.type !== UIToastType.Info
            sourceComponent: Component {
                Rectangle {
                    width: root._style.indicatorSize
                    height: root._style.indicatorSize
                    radius: width / 2
                    color: root.accentColor
                }
            }
        }
        UIText {
            id: label
            text: root.text
            color: root.resolvedTextColor
            font.pixelSize: root._style.fontSize
            wrapMode: Text.WordWrap
            Layout.maximumWidth: root._style.maxWidth
        }
    }

    NumberAnimation on opacity {
        from: 0; to: root._style.stayOpacity
        duration: root._style.fadeInDuration
        easing.type: Easing.OutCubic
        running: !root.closing
    }

    Timer {
        id: lifeTimer
        interval: root.duration
        running: root.duration > 0 && !root.closing
        onTriggered: root.startClose()
    }

    function startClose() {
        if (closing) return
        closing = true
        outAnim.start()
    }

    NumberAnimation {
        id: outAnim
        target: root
        property: "opacity"
        from: root._style.stayOpacity; to: 0
        duration: root._style.fadeOutDuration
        easing.type: Easing.InCubic
        onFinished: root.closed()
    }
}
