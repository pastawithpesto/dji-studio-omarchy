import QtQuick
import Qt5Compat.GraphicalEffects

// UIIcon
//   SVG 图标的极简封装。基于 Qt 原生 Image，约定:
//     - source     建议传 qrc 路径或 svg 资源路径
//     - iconSize   统一控制宽高(默认 16)。SVG 矢量,缩放无锯齿
//     - iconColor  指定颜色时 svg 整体染色为该颜色；不指定（transparent）则保留 svg 原色
//
//   注意:
//     在使用UIIcon的时候应当保持sourceSize的width和height和width和height保持一致
//     在未设置sourceSize的时候导入大小取决于svg中设置的大小,此时width和height属性会自动修改为sourceSize的大小
//
//   用例:
//     UIIcon { source: "qrc:/UIComponent/Resources/Common/icons/check.svg"; iconSize: 24 }
//     UIIcon { source: "qrc:/UIComponent/Resources/Common/icons/check.svg"; iconSize: 24; iconColor: "#FFFFFF" }
Image {
    id: root
    property real iconSize: 16
    property real iconWidth: iconSize
    property real iconHeight: iconSize
    property color iconColor: "transparent"

    sourceSize.width: iconWidth
    sourceSize.height: iconHeight
    width:  iconWidth
    height: iconHeight
    fillMode: Image.PreserveAspectFit
    smooth: true
    mipmap: false

    layer.enabled: iconColor.a > 0
    layer.smooth: true
    layer.effect: ColorOverlay {
        color: root.iconColor
    }
}
