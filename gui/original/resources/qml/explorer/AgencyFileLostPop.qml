import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.3
import Controls 1.0
import Config 1.0
import Qt5Compat.GraphicalEffects
import app_qrc 1.0
import "../menubar"
import AgencyFileLostViewModel 1.0

LightPopup {
    property bool isHideOpenAgencyBtn: false
    signal leftButtonClicked
    signal rightButtonClicked
    width: lightWindow.width
    height: lightWindow.height
    dim: false
    z: 100
    contentItem: Item{
        id:content
        Rectangle {
            anchors.fill: contentLayout
            color: Colors.color_2F3032
            radius: 8
            clip: true
            border.width:1
            border.color:Colors.color_454649
        }

        MouseArea{
            anchors.fill: parent
        }

        Column{
            id: contentLayout
            anchors.centerIn: parent
            width: 360
            height: 388
            WindowTitleBar {
                id: titleBar
                height: 40
                width: parent.width
                title: qsTr("pccut_player_preview_mode_smooth_tex_1")
                onCloseClick: {
                    close();
                }
            }


            Text {
                id: titleLabel
                anchors{
                    top: titleBar.bottom
                    topMargin: 24
                    horizontalCenter: parent.horizontalCenter
                }
                width: 304
                height: 32
                text: qsTr("pccut_player_preview_mode_smooth_tex")
                color: Colors.color_FFFFFF
                font.pixelSize: 12
                wrapMode: Text.Wrap
            }

            Rectangle{
                id: line
                height: 1
                width: 304
                anchors{
                    top: titleLabel.bottom
                    topMargin: 24
                    horizontalCenter: parent.horizontalCenter
                }
                color: Colors.color_454649
            }

            Text {
                id: listviewTitle
                anchors{
                    top: line.bottom
                    topMargin: 24
                    left: line.left
                }
                width: 200
                height: 16
                text: qsTr("pccut_player_preview_mode_smooth_tex_2")
                color: Colors.color_EEEEEE
                font.pixelSize: 12
                wrapMode: Text.Wrap
            }

            Item{
                id: contain
                height: 128
                width: parent.width - 36
                anchors{
                    top: listviewTitle.bottom
                    topMargin: 12
                    left:parent.left
                    leftMargin: 28
                }



            ListView {
                    id: devlistView
                    height: 128
                    width: parent.width
                    clip: true
                    spacing: 8
                    model: agencyFileLostViewModel
                    delegate: contactDelegate

                    // 垂直滚动条
                    ScrollBar.vertical: ScrollBar {
                        id: vbar
                        visible: devlistView.contentHeight > devlistView.height
                        // policy: ScrollBar.AsNeeded
                        // 设置滚动条样式
                        background: Rectangle {
                            color: Colors.color_transparent
                        }
                        contentItem: Rectangle {
                            implicitWidth: 6
                            radius: 72
                            color: Colors.color_454649
                        }
                    }
                }
            }

            // 定义delegate组件
            Component {
                id: contactDelegate

                Rectangle {
                    width: devlistView.width
                    height: 16
                    radius: 2
                    color: Colors.transparent

                    Text {
                        text: model.lostFileName
                        font.pixelSize: 12
                        color: Colors.color_999999;
                    }
                }
            }


            Item {
                id: actionButton
                height: 26
                width: parent.width

                anchors {
                    right: parent.right
                    bottom: parent.bottom
                    rightMargin: 28
                    bottomMargin: 24
                }

                Rectangle {
                    id: confirmBtn
                     visible: !isHideOpenAgencyBtn
                    color: confirmMouseArea.containsMouse ? ColorsConfig.color_F44C65_6DFFD3 : ColorsConfig.color_brand
                    radius: RadiusConfig.radius_4_88
                    width: Math.max(confirmBtn.defaultWidth, cancelBtn.defaultWidth)
                    height: 26
                    property real defaultWidth: confirmText.width + 26
                    anchors.right: parent.right
                    Text {
                        id: confirmText
                        text: !isHideOpenAgencyBtn ? qsTr("pccut_player_preview_mode_smooth_skip") : qsTr("pccut_draft_delete_popup_cancel")
                        color: ColorsConfig.color_FFFFFF_000000
                        anchors.centerIn: parent
                        font.pixelSize: 12
                    }

                    MouseArea {
                        id: confirmMouseArea
                        hoverEnabled: true
                        anchors.fill: parent
                        onClicked: {
                            rightButtonClicked();
                        }
                    }
                }

                Rectangle {
                    id: cancelBtn
                    visible: !isHideOpenAgencyBtn
                    color: cancelMouseArea.containsMouse ? Colors.color_777777 : Colors.color_666666
                    radius: RadiusConfig.radius_4_88
                    width: Math.max(confirmBtn.defaultWidth, cancelBtn.defaultWidth)
                    height: 26
                    property real defaultWidth: cancelText.width + 26
                    anchors.right: confirmBtn.left
                    anchors.rightMargin: 8
                    Text {
                        id: cancelText
                        text: qsTr("pccut_draft_delete_popup_cancel")
                        color: Colors.color_FFFFFF
                        anchors.centerIn: parent
                        font.pixelSize: 12
                    }

                    MouseArea {
                        id: cancelMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            leftButtonClicked();

                        }
                    }
                }

                Rectangle {
                    visible: isHideOpenAgencyBtn
                    color: mouseArea.containsMouse ? Colors.color_777777 : Colors.color_666666
                    radius: RadiusConfig.radius_4_88
                    width: 80
                    height: 26
                    anchors.right: parent.right
                    Text {
                        text: qsTr("pccut_draft_delete_popup_cancel")
                        color: Colors.color_FFFFFF
                        anchors.centerIn: parent
                        font.pixelSize: 12
                    }

                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            leftButtonClicked();
                        }
                    }
                }
            }
        }
    }
}
