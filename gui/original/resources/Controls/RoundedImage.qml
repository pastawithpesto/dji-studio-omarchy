import QtQuick 2.15
import Qt5Compat.GraphicalEffects

/**
 * @brief 带圆角裁剪的图片组件
 * @details 内部使用 OpacityMask 实现圆角裁剪，默认填满父容器
 */
Rectangle {
    id: root
    property alias source: image.source
    property int imageRadius: 4

    anchors.fill: parent
    radius: imageRadius
    clip: true
    color: "transparent"

    Image {
        id: image
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        layer.enabled: true

        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: root.width
                height: root.height
                radius: root.radius
            }
        }
    }
}
