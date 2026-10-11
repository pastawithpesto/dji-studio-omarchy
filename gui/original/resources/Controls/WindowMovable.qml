import QtQuick 2.15
import QtQuick.Window 2.15
import Config 1.0

// 提供窗口拖动能力
MouseArea {
    id: dragArea
    anchors {
        top: parent.top
        left: parent.left
        right: parent.right
        bottom: parent.bottom
        topMargin: 8
        leftMargin: 8
        rightMargin: 8
    }
    property int virtualX: 0
    property int virtualY: 0
    property var window
    property var sizeHandler
    property var resizableBar

    onPositionChanged: mouse => {
        Window.window.startSystemMove();
    }

    onDoubleClicked: mouse => {
        // double click 一定是左键双击，不用额外判断是左键还是右键
        if (resizableBar.resizable) {
            if (CommonUtils.isNull(Window.window)) {
                return
            }
            if (Window.window.visibility === Window.Maximized) {
                Window.window.showNormal()
            } else {
                Window.window.showMaximized()
            }
        }
    }

    acceptedButtons: Qt.LeftButton | Qt.RightButton
}
