import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.15
import Controls 1.0
import Config 1.0
import Qt5Compat.GraphicalEffects
/**
 * @author tengsen.zhang
 * @desc 圆角window控件
 * @create_date 2025-03-04
 */
Window {
    width: parent.width
    height: parent.height
    visible: true
    color: Colors.color_transparent
    flags: Qt.FramelessWindowHint
    modality: Qt.WindowModal // 设置窗口模态显示，mac下会隐藏掉标题栏

    Rectangle { // 窗口背景色
        id: windowBackground
        width: parent.width
        height: parent.height
        anchors.left: parent.left
        anchors.top: parent.top
        color: Colors.color_2F3032
        // 仅在 Windows 平台设置边框
        border.width: CommonUtils.isWindows() ? 1 : 0
        border.color: CommonUtils.isWindows() ? Colors.color_454649 : Colors.color_transparent
        radius: 8
    }
}
