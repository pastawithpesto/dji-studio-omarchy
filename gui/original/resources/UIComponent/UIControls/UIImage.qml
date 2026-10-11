import QtQuick
import QtQuick.Effects

// UIImage
//   位图(png/jpg)的极简封装。默认按比例缩放,异步加载,缓存开启。
//   radius > 0 时自动启用圆角裁剪。
//
//   用例:
//     UIImage { source: "qrc:/UIComponent/Resources/Common/images/loading.png"; width: 200; height: 200 }
//     UIImage { source: "..."; fillMode: Image.PreserveAspectCrop }   // 等比裁剪填满
//     UIImage { source: "..."; width: 120; height: 120; radius: 12 }  // 圆角图片
Image {
    id: root

    property int radius: 0
    property real borderWidth: 0
    property color borderColor: "transparent"

    fillMode: Image.PreserveAspectFit
    smooth: true
    asynchronous: true
    cache: true

    layer.enabled: radius > 0
    layer.effect: MultiEffect {
        maskEnabled: true
        maskSource: _mask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
    }

    Rectangle {
        id: _mask
        width: parent.width
        height: parent.height
        radius: root.radius
        visible: false
        layer.enabled: true
        layer.smooth: true
        layer.samples: 2
        antialiasing: true
        smooth: true
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        border.width: root.borderWidth
        border.color: root.borderColor
        visible: root.borderWidth > 0
    }
}
