import QtQuick 2.15
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Config 1.0

/**
 *  @File        : LightCenterSlider.qml
 *  @Brief       : 一个滑块，并位于中间
 *  @Details     : 详细说明
 *  @Author      : pansy.guo
 *  @Date        : 2024-03-14 10:55:53
 */
Slider {
    id: control
    // 手柄的直径
    property real handleWidth: 12
    // 可视的颜色
    property color visualColor: Colors.color_D8D8D8
    // 不可视的颜色
    property color unVisualColor: Colors.color_4D4D4D
    // 防止onValueChanged自动调用
    property bool initialized: false
    // 渐变颜色:需要两种
    property var linearGradientColors: []

    background: Rectangle {
        x: control.leftPadding
        y: control.topPadding + control.availableHeight / 2 - height / 2
        implicitWidth: 200
        implicitHeight: 4
        width: control.availableWidth
        height: 2
        radius: 1
        color: enabled ? (linearGradientColors.length > 0 ? Colors.color_transparent : unVisualColor) : Colors.color_2D2D2D
        LinearGradient {
            anchors.fill: parent
            start: Qt.point(0, 0)
            end: Qt.point(control.width, 0)
            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: enabled ? (linearGradientColors.length > 0 ? linearGradientColors[0] : Colors.color_transparent) : Colors.color_2D2D2D
                }
                GradientStop {
                    position: 1.0
                    color: enabled ? (linearGradientColors.length > 0 ? linearGradientColors[1] : Colors.color_transparent) : Colors.color_2D2D2D
                }
            }
        }

        Rectangle {
            x: control.visualPosition < 0.5 ? control.visualPosition * parent.width : 0.5 * parent.width
            width: Math.abs(0.5 - control.visualPosition) * parent.width
            height: parent.height
            color: enabled ? (linearGradientColors.length > 0 ? Colors.color_transparent : visualColor) : Colors.color_4B4B4B
            radius: 1
        }
    }

    // // 手柄
    handle: Rectangle {
        // 备注： (control.visualPosition === 0 ? 1 : 0) 是当在最左端时，会有一些漏出
        x: control.leftPadding + control.visualPosition * (control.availableWidth - width) - (control.visualPosition === 0 ? 1 : 0)
        y: control.topPadding + control.availableHeight / 2 - height / 2
        implicitWidth: handleWidth
        implicitHeight: handleWidth
        color: enabled ? Colors.color_E8E8E8 : Colors.color_4B4B4B
        radius: handleWidth / 2
    }
}
