import QtQuick
import UIComponent

// UIDivider
//   分割线组件，支持水平 / 垂直方向。
//
//   用例:
//     UIDivider {}                                           // 水平，撑满父宽
//     UIDivider { orientation: Qt.Vertical; height: 40 }     // 垂直，高 40
//     UIDivider { color: UIColors.colorFillDark5 }     // 自定义颜色
//     UIDivider { thickness: 2; opacity: 0.5 }               // 粗细 + 透明度
Rectangle {
    id: root

    property int orientation: Qt.Horizontal
    property int thickness: 1

    color: UIColors.colorFillDark3
    implicitWidth:  orientation === Qt.Horizontal ? 200 : thickness
    implicitHeight: orientation === Qt.Horizontal ? thickness : 200
}
