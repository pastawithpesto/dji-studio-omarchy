import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.3
import Qt.labs.platform 1.1
import Config 1.0
import Controls 1.0
import ShortcutAction 1.0
import app_qrc 1.0

/**
 * @author tengsen.zhang
 * @desc 时间对齐弹窗
 * @create_date 2024-10-16
 */
LightPopup{
    id: popup
    parent: Overlay.overlay
    width: 254
    //多语言高度自适应，要求text距离底边16
    height: 155 + (46 > description.implicitHeight + 16 ? 0 : description.implicitHeight + 16 - 46)
    modal: true
    Overlay.modal: Rectangle {
        color: Colors.transparent
    }
    closePolicy: Popup.CloseOnPressOutside
    // 窗口失去焦点时关闭弹窗
    Connections {
        target: appStateDetector
        function onAppActiveChanged() {
            if (!appStateDetector.appActive && timeSelectionPopup.opened) {
               timeSelectionPopup.close();
            }
        }
    }
    //数据开始时间
    property string currentTime

    function showTimeSelectionPopup() {
        var position = UiUtils.getGlobalPosition(timeSelectionRect);
        timeSelectionPopup.x = position.x + timeSelectionRect.width - timeSelectionPopup.width;
        timeSelectionPopup.y = position.y + timeSelectionRect.height + 4;
        timeSelectionPopup.open();
    }

    Shortcut {
        sequence: "Ctrl+Z"
        context: Qt.WindowShortcut
        onActivated: {
            ShortcutObserver.shortcutActivated(ShortcutAction.UN_DO,"Undo")
        }
    }

    Shortcut {
        sequence: "Ctrl+Shift+Z"
        context: Qt.WindowShortcut
        onActivated: {
            ShortcutObserver.shortcutActivated(ShortcutAction.RE_DO,"Redo")
        }
    }

    TimeSelectionPopup {
        id: timeSelectionPopup
        onClickTimeType: (timeType) => {
            dashboardManager.setTimeType(timeType);
        }
    }

    contentItem: Item{
        Rectangle {
            id: contentRectangle
            width: parent.width
            height: parent.height
            radius: 8
            color: Colors.color_141414
            border {
                color: Colors.color_444444
                width: 0.5
            }

            Column {
                spacing: 0

                //运动数据导入
                Rectangle {
                    width: contentRectangle.width
                    height: 56
                    color: Colors.color_transparent
                    clip: true

                    // 文件日期
                    Text {
                        id: fileDate
                        anchors {
                            left: parent.left
                            leftMargin: 12
                            top: parent.top
                            topMargin: 16
                        }
                        color: Colors.color_EEEEEE
                        font.pixelSize: 12
                        text: qsTr("pccut_media_info_date")
                    }
                    HoverableText {
                        anchors {
                            left: fileDate.right
                            leftMargin: 8
                            right: timeSelectionRect.left
                            rightMargin: 12
                            top: parent.top
                            topMargin: 16
                        }
                        cursorChanged: false
                        wrapMode: Text.NoWrap
                        font.pixelSize: 12
                        color: Colors.color_EEEEEE
                        text: popup.currentTime;
                    }

                    Rectangle {
                        id: timeSelectionRect
                        anchors {
                            top: parent.top
                            topMargin: 12
                            right: parent.right
                            rightMargin: 12
                        }
                        width: textElement.implicitWidth + 33
                        height: 24
                        radius: RadiusConfig.radius_4_88
                        color: Colors.color_FFFFFF_15
                        Accessible.role: Accessible.Button

                        Text {
                            id: textElement
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            verticalAlignment: Text.AlignVCenter
                            horizontalAlignment: Text.AlignLeft
                            font.pixelSize: 12
                            color: Colors.color_FFFFFF
                            text: timeSelectionPopup.currentName
                        }

                        Image {
                            anchors {
                                right: parent.right
                                rightMargin: 2
                                verticalCenter: parent.verticalCenter
                            }
                            width: 20
                            height: 20
                            source: timeSelectionPopup.visible ? "qrc:/icons/player/ic_canvas_up.svg" : "qrc:/icons/player/ic_canvas_down.svg"
                            sourceSize: Qt.size(20, 20)
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                showTimeSelectionPopup();
                            }
                        }
                    }
                }

                //时间调整
                Rectangle {
                    width: contentRectangle.width
                    height: 52
                    color: Colors.color_transparent
                    clip: true

                    AdjustAlignmentTimeView{
                        id: adjustAlignmentTimeView
                    }
                }
                //说明
                Rectangle {
                    width: contentRectangle.width
                    height: 46 > description.implicitHeight + 16 ? 46 : description.implicitHeight + 16
                    color: Colors.color_transparent
                    clip: true

                    Text {
                        id: description
                        width: 234
                        x: 16
                        y: 0
                        horizontalAlignment: Text.AlignLeft
                        verticalAlignment: Text.AlignVCenter
                        wrapMode: Text.WordWrap
                        font.pixelSize: 11
                        color: Colors.color_999999
                        text: qsTr("pccut_dashboard_time_alignment_description")
                    }
                }
            }
        }
    }
}
