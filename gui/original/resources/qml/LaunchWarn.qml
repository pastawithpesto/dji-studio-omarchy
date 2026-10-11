import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.3
import Controls 1.0
import Config 1.0
import Qt5Compat.GraphicalEffects
import QmlConstants 1.0
import app_qrc 1.0

Window {
    id:launchWarn
    width: popContent.width
    height: popContent.height
    visible: true
    flags: Qt.Window | Qt.FramelessWindowHint
    color: Colors.color_transparent

    property string gl_version:"4.1"
    property string content_info: qsTr("pccut_open_graphics_upgrade_tip").arg(gl_version)


    Connections{
        target: globalSignal
        function onMinOpenGlVersion(version){
            gl_version = version;
        }
    }


    Rectangle {
        id: popContent
        color: Colors.color_2F3032
        width: 360
        radius: 8
        height: title.height + content.height + updatebtn.height + 12 + 36 + 20 + 24
        border.color: Colors.color_454649
        border.width: 1

        // 窗口背景色
        Item  {
            id: popBackground
            anchors.centerIn: parent
            width: 360
            height: title.height + content.height + updatebtn.height + 12 + 36 + 20 + 24


            Rectangle {
                width: 20
                height: 20
                color: "transparent"

                Image {
                    anchors.fill: parent
                    source: "qrc:/app_qrc/app_icon.png"
                    fillMode: Image.PreserveAspectCrop
                }
                anchors {
                        left: parent.left
                        leftMargin: 12
                        top: parent.top
                        topMargin: 10.3
                       }
            }

            Text {
                id: title
                text: QmlConstants.appShowName()
                color: Colors.color_EEEEEE
                font.pixelSize: 12
                height: 16
                horizontalAlignment: Text.AlignLeft
                verticalAlignment:Text.AlignVCenter
                anchors {
                    top: parent.top
                    topMargin: 12
                    left: parent.left
                    leftMargin: 36
                }
            }

            Rectangle {
                id: titleLine
                width: 360
                height:1
                color: Colors.color_444444
                anchors {
                    top: parent.top
                    topMargin: 40
                }
            }
            IconButton {
                id: btn_close
                anchors {
                        right: parent.right
                        rightMargin: 12
                        top: parent.top
                        topMargin: 10
                       }
                       width: 20
                       height: 20
                       iconMargins: 0
                       visible: CommonUtils.isWindows()

                       iconSource: "qrc:/icons/WindowsIcon/icon_close_modal.svg"
                       hoverIconSource: "qrc:/icons/WindowsIcon/icon_close_modal_hover.svg"
                       pressedIconSource: "qrc:/icons/WindowsIcon/icon_close_modal_hover.svg"
                       disabledIconSource: "qrc:/icons/WindowsIcon/icon_close_modal.svg"
                       onClicked: {
                            launchWarn.close()
                        }
            }

            Text {
                id: content
                text: content_info
                color: Colors.color_EEEEEE
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                anchors {
                    top: title.bottom
                    left: parent.left
                    right: parent.right
                    topMargin: 36
                    leftMargin: 28
                    rightMargin: 28
                }
                horizontalAlignment: Text.AlignLeft
            }


            IconTextButton {
                id: updatebtn
                title: qsTr("pccut_graphics_upgrade_tip_switch")
                width: 88
                height: 28
                font.pixelSize: 12
                anchors {
                    top: content.bottom
                    topMargin: 20
                    right: parent.right
                    rightMargin: 136
                }
                alignment: Qt.AlignHCenter
                isTextOnly: true

                titleColorNormal: ColorsConfig.color_EEEEEE_000000
                backgroundColorNormal: ColorsConfig.color_brand
                backgroundColorPressed: ColorsConfig.color_F44C65_6DFFD3

                onCustomClicked: {
                    globalSignal.onOpenGpuGuideUrl();
                    launchWarn.close()
                }
            }
        }
    }

}
