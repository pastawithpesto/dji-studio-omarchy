import QtQuick
import QtQuick.Controls
import UIComponent

// UIScrollBar
//   颜色走 UIStyle token，仅 active/default 两态（不引入 hover），避免滚动时
// 鼠标在 thumb 边缘抖动引起色彩闪烁。
//
// 选 QtQuick.Controls.ScrollBar（而非 QtQuick.Templates）：style 层提供 implicitWidth、
// visible、size/position 计算、hover 区域等完整 macOS overlay 行为；自行在
// T.ScrollBar 上复刻覆盖不全且与既有视觉差异明显。这是 QML_GUIDELINES §8.1 的合理
// 例外（ScrollBar 极度依赖 style 层）。整库统一使用 Fusion style，
// 由 UIComponentRegister 兜底。
//
// contentItem 覆写后，Fusion 内置的 opacity/states/transitions 状态机会丢失，
// 必须随之手动搬过来，否则滚动条无法淡出。

ScrollBar {
    id: root

    signal reachedBottom()

    onPositionChanged: {
        if (size < 1.0 && position + size >= 1.0) {
            reachedBottom()
        }
    }

    contentItem: Rectangle {
        implicitWidth:  UISize.scrollbarThickness
        implicitHeight: UISize.scrollbarThickness
        radius:         width / 2
        color:          root.hovered ? UIColors.colorScrollbarThumbHover : UIColors.colorScrollbarThumb
        opacity:        0.0

        Behavior on implicitWidth {
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
        }
        Behavior on color {
            ColorAnimation { duration: 150 }
        }

        states: [
            State {
                name: "active"
                when: (root.policy === ScrollBar.AlwaysOn && root.size < 1.0)
                      || ((root.active && root.size < 1.0) && root.policy !== ScrollBar.AlwaysOff)
                PropertyChanges { root.contentItem.opacity: 1.0 }
            },
            State {
                name: "hovered"
                when: root.hovered && root.size < 1.0
                PropertyChanges {
                    root.contentItem.opacity: 1.0
                    root.contentItem.implicitWidth: UISize.scrollbarThickness + 2
                }
            }
        ]

        transitions: Transition {
            from: "active"
            SequentialAnimation {
                PauseAnimation  { duration: 450 }
                NumberAnimation { target: root.contentItem; property: "opacity"; to: 0.0; duration: 200 }
            }
        }
    }
}
