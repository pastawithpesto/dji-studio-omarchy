import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.3

/**
 * Created by whiskey.cao on 2024-02-06 .
 * ClassName : LightIconButton
 * Description :自定义实现一个icon button，有点击、鼠标经过、默认颜色设置
 * Copyright : ©2024 Light All Rights Reserved.
 */
Item {
    id: root
    property bool disabled: false // 是否禁用的属性
    property bool hovered: mouseArea.containsMouse // 是否禁用的属性
    property bool enabled: !disabled // 是否启用的属性，根据 disabled 的值取反
    property color normalColor: "transparent" // 正常状态下的背景颜色
    property color hoverColor: "cadetblue" // 悬停状态下的背景颜色
    property color pressedColor: "red" // 按下状态下的背景颜色
    property color disableColor: "darkgoldenrod" // 禁用状态下的背景颜色
    property alias iconSource: icon.source // 图标的源
    property alias radius: background.radius // 背景的圆角半径
    property alias iconMargins: icon.anchors.margins // 图标的边距

    property color color: {
        if (!enabled) { // 如果禁用状态，则返回禁用状态的背景颜色
            return disableColor
        }
        if (mouseArea.containsPress) { // 如果鼠标在按下状态下，则返回按下状态的背景颜色
            return pressedColor
        }
        return mouseArea.containsMouse ? hoverColor : normalColor // 如果鼠标在悬停状态下，则返回悬停状态的背景颜色；否则返回正常状态的背景颜色
    }

    signal clicked();

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true

        Rectangle {
            id: background
            anchors.fill: parent
            radius: 4
            color: root.color // 背景颜色绑定为 root 的 color 属性

            Image {
                id: icon
                anchors.fill: parent
                anchors.margins: 4
            }
        }

        onClicked: {
            if (root.enabled) {
                root.clicked()
            }
        }
    }
}
