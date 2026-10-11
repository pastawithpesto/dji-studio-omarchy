import QtQuick 2.15
import QtQuick.Controls
import Config 1.0

/**
 *  @File        : CustomSlider.qml
 *  @Brief       : 自定义的滑杆
 *  @Details     : 详细说明
 *  @Author      : pansy.guo
 *  @Date        : 2024-03-08 14:10:05
 */
Slider {
    id: control
    // 手柄的直径
    property real handleWidth: 12
    property real handleHeight: 12
    property real handleRadius: 6
    property real handleBorderWidth: 0
    property bool isDisable: false
    // 手柄的颜色
    property color handleColor: Colors.color_E8E8E8
    // 手柄描边️的颜色
    property color handleBorderColor: Colors.transparent
    // 可视的颜色
    property color visualColor: Colors.color_D8D8D8
    // 不可视的颜色
    property color unVisualColor: Colors.color_4D4D4D
    // 防止onValueChanged自动调用
    property bool initialized: false

    property bool isHovered: backgroundMouseArea.containsMouse

    background: Rectangle {
        x: control.leftPadding
        y: control.topPadding + control.availableHeight / 2 - height / 2
        width: control.availableWidth - 1
        height: 2
        radius: 1
        color: enabled ? unVisualColor : Colors.color_2D2D2D // 不可视的背景色Colors.color_2D2D2D

        Rectangle {
            width: control.visualPosition * parent.width
            height: parent.height
            radius: 1
            color: enabled ? visualColor : Colors.color_4B4B4B //可视的背景色
        }
    }

    // // 手柄
    handle: Rectangle {
        // 备注： (control.visualPosition === 0 ? 1 : 0) 是当在最左端时，会有一些漏出
        x: control.leftPadding + control.visualPosition * (control.availableWidth - width) - (control.visualPosition === 0 ? 1 : 0)
        y: control.topPadding + control.availableHeight / 2 - height / 2
        implicitWidth: handleWidth + handleBorderWidth * 2
        implicitHeight: handleHeight + handleBorderWidth * 2
        color: enabled ? handleColor : Colors.color_4B4B4B
        radius: handleRadius
        border.color: handleBorderColor
        border.width: handleBorderWidth
    }

    MouseArea {
        id: backgroundMouseArea
        anchors.fill: parent
        drag.target: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }
}
