import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.15
import Config 1.0
import Controls 1.0

LightPopup {
    id: root
    signal cancelSignal
    property string text: ""
    property int currentIndex: 1  // 当前进度
    property int totalCount: 0    // 总个数
    property real segmentProgress: 0.0  // 当前片段的进度

    // 计算整体进度：当前完成的视频数 + 当前视频的进度
    property real overallProgress: totalCount > 0 ? ((currentIndex - 1) + Math.min(segmentProgress, 1.0)) / totalCount : Math.min(segmentProgress, 1.0)

    parent: lightWindow.contentItem
    anchors.centerIn: parent
    modal:true
    closePolicy: Popup.NoAutoClose
    Overlay.modal: Rectangle {
        color: Colors.color_80000000
    }
    width: 362

    // 背景
    contentItem: Rectangle {
        anchors.fill: parent
        color: Colors.color_2F3032
        border.color: Colors.color_454649
        border.width: 1
        radius: 8

        Column {
            id: mainColumn
            width: parent.width

            Text {
                id: textDec
                width: 304
                anchors.horizontalCenter: parent.horizontalCenter
                topPadding: 24
                bottomPadding: 22
                text: root.totalCount <= 0 ? root.text : qsTr("pccut_editing_perspective_apply_loading").arg(root.currentIndex).arg(root.totalCount)
                font.pixelSize: 14
                wrapMode: Text.Wrap
                color: Colors.color_EEEEEE
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
            }

            ProgressBar {
                id: progressBar
                anchors.horizontalCenter: parent.horizontalCenter
                width: 304
                height: 4
                value: root.overallProgress
                from: 0
                to: 1
                // 设置背景矩形的颜色
                background: Rectangle {
                    implicitWidth: parent.width
                    implicitHeight: parent.height
                    color: Colors.color_454649
                    radius: parent.height / 2
                }
                // 设置进度矩形的颜色
                contentItem: Item {
                    Rectangle {
                        width: progressBar.value * parent.width
                        height: parent.height
                        color: Colors.color_F22443
                        radius: parent.height / 2
                    }
                }
            }

            Item {
                width: parent.width
                height: 24
            }
            IconButton {
                id: cancelBtn
                width: 88
                height: 28
                anchors.horizontalCenter: parent.horizontalCenter
                normalColor: Colors.color_454649
                hoverColor: Colors.color_68696D
                pressedColor: Colors.color_68696D
                disableColor: Colors.color_454649
                radius: 4

                Text {
                    anchors.centerIn: parent
                    text: qsTr("pccut_draft_delete_popup_cancel")
                    color: Colors.color_EEEEEE
                    font.pixelSize: 12
                }
                onClicked: {
                    cancelSignal()
                    close()
                }
            }
            Item {
                width: parent.width
                height: 20
            }
        }
    }
}
