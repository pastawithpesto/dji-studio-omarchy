import QtQuick 2.15
import Config 1.0

/**
 * @brief 拖拽时轨道外的通用封面样式
 * @details 带圆角边框的矩形容器，通过 default property 支持自定义内容（图片或文本）
 */
Rectangle {
    id: root

    width: 72
    height: 72
    radius: 6
    border.width: 2
    border.color: Colors.color_F22443
    color: Colors.color_1E1E1E

    default property alias content: contentContainer.data

    Item {
        id: contentContainer
        anchors.fill: parent
        anchors.margins: root.border.width
    }
}
