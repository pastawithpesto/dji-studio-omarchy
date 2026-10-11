import QtQuick 2.15
import Config 1.0
import Nova 1.0
/**
 * @brief 轨道Clip的拖拽蒙层样式
 * @details 拖拽滤镜、特效等到轨道时，根据 fragmentInfo.coverStyle 显示不同蒙层:
 *          0 = 不支持当前拖拽(禁用蒙层), 1 = 支持当前拖拽(高亮蒙层), 2 = 不显示
 * @author andy.du
 * @date 2026/03/05
 */
Item {
    id: coverItem
    required property var fragmentInfo
    property int rectRadius: 0
    z: 100

    // 不支持当前拖拽的禁用蒙层
    Rectangle {
        id: disableCover
        visible: fragmentInfo.coverStyle === TimelineClipViewModel.DisableCover
        anchors.fill: parent
        color: Colors.color_141414_50
        radius: coverItem.rectRadius
    }

    // 支持当前拖拽的高亮蒙层
    Rectangle {
        id: enableCover
        visible: fragmentInfo.coverStyle === TimelineClipViewModel.EnableCover
        anchors.fill: parent
        color: Colors.color_FFFFFF_20
        radius: coverItem.rectRadius
        border.width: 2
        border.color: Colors.color_FFFFFF
    }
}
