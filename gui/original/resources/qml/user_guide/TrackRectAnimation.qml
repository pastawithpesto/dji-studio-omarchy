import QtQuick 2.15
import Config 1.0
import QtQuick.Controls 2.15
/**
 * @author mathy.shi
 * @desc 追踪指引时追踪框绘制动画
 * @create_date 2024-02-11
 */

Rectangle {
    id: root
    visible: false
    width: 97
    height: 135
    color: Colors.color_transparent
    property real startPosX: 0
    property real startPosY: 0
    property real endPosX: 0
    property real endPosY: 0

    // 动态矩形框
    Rectangle {
        id: selectionRect
        visible: false
        color: Colors.transparent // 透明背景
        border.color: Colors.color_tk_rect_border // 边框颜色
        border.width: 2 // 边框宽度
    }

    Timer {
        id: timer
        interval: 10
        repeat: true
        running: false
        onTriggered: {
            if (root.endPosX < 97 && root.endPosY < 135) {
                root.endPosX += 0.97
                root.endPosY += 1.35
                selectionRect.x = root.startPosX
                selectionRect.y = root.startPosY
                selectionRect.width = root.endPosX - root.startPosX
                selectionRect.height = root.endPosY - root.startPosY

                fingerImage.x = selectionRect.x + selectionRect.width - 10;
                fingerImage.y = selectionRect.y + selectionRect.height - 10;
            } else {
                timer.stop()
                timerStop.start();
            }
        }
    }

    // 画框结束后，500ms后关闭动画
    Timer {
        id: timerStop
        interval: 500
        repeat: false
        running: false
        onTriggered: {
            root.visible = false
        }
    }

    Image {
        id: fingerImage
        width: 67
        height: 84
        visible: true
        x:0
        y:0
        source: "qrc:/icons/icon_finger.svg"
        sourceSize: Qt.size(67, 84)
    }

    function start(){
        selectionRect.visible = true
        timer.start();
    }
    function stop(){
        timer.stop();
    }
}
