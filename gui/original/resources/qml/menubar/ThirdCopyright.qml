import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.15
import Controls 1.0
import Config 1.0

Item {
    property real windowWidth: 600
    property real windowHeight: 540
    signal destorySource()
    // 模态窗口关闭
    function closeWinowd() {
        mainWindow.visible = false
        destorySource()
    }

    CustomWindow {
        id: mainWindow
        width: windowWidth
        height: windowHeight
        // 模态窗口的宽高
        Component.onCompleted: {
            textArea.text = fileOperator.thirdCopyrightText();
        }
        
        Shortcut {
            sequence: "Escape"
            context: Qt.WindowShortcut
            onActivated: {
                closeWinowd()
            }
        }

        WindowTitleBar { // 自定义的标题栏
            id: titleBar
            title: qsTr("pccut_menu_thirdparty_copyright")
            height: 40
            width: windowWidth
            onCloseClick: {
                closeWinowd();
            }
        }
        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: 1
            anchors.right: parent.right
            anchors.rightMargin: 1
            anchors.top: titleBar.bottom
            anchors.bottomMargin: 1
            anchors.bottom: parent.bottom
            color: Colors.color_FFFFFF
            ScrollView {
                id: scrollView
                width: parent.width
                height: parent.height
                TextArea {
                    id: textArea
                    color: Colors.color_141414
                    leftPadding: 72
                    rightPadding: 72
                    topPadding: 0
                    bottomPadding: 0
                    font.pixelSize: 14
                    wrapMode: TextArea.Wrap // 自动换行
                    readOnly: true          // 设为只读模式（纯展示场景）
                }
            }
            // 设计觉得滚动的速度不够快, 所以需要自定义, 覆盖滚轮事件以加快速度
            MouseArea {
                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                    top: parent.top
                    rightMargin: 20
                }
                onWheel: (wheel) => {
                    // 动态计算新的滚动位置
                    var newContentY = scrollView.contentItem.contentY - wheel.angleDelta.y * 30 / 120;
                    // 限制新位置在允许的边界内
                    newContentY = Math.max(0, Math.min(newContentY, scrollView.contentItem.contentHeight - scrollView.height));
                    // 设置滚动位置
                    scrollView.contentItem.contentY = newContentY;
                    // 阻止事件继续传播
                    wheel.accepted = false;
                }
            }
        }
    }
}
