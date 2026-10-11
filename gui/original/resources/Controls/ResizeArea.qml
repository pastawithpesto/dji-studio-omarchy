import QtQuick 2.15
import Config 1.0

Item {
    id: root
    property alias mouseArea: internalMouseArea // 暴露内部 MouseArea

    // 背景 Rectangle
    Rectangle {
        id: background
        anchors.fill: parent
        color: Colors.transparent
    }

    // 内部 MouseArea
    MouseArea {
        id: internalMouseArea
        enabled: !CommonUtils.isNull(Window.window) && Window.window.visibility !== Window.FullScreen
        anchors.fill: parent
        preventStealing: true
    }
}
