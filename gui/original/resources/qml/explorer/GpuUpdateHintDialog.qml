import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.15
import Controls 1.0
import Config 1.0
import Qt5Compat.GraphicalEffects
import app_qrc 1.0

LightPopup {
    id: gpuDriverUpdateHintDialog
    parent: Overlay.overlay
    width: parent.width
    height: parent.height
    dim: false
    needTransparent: true

    property alias titleText: title.text
    property alias contentText: content.text
    property alias updatebtnText: updatebtn.title
    property bool isConfirmDialog:false


    contentItem: Rectangle {
        id: popContent
        color: Colors.color_80000000

        // 窗口背景色
        Rectangle {
            id: popBackground
            anchors.centerIn: parent
            width: 360
            //height:168
            height: title.height + content.height + updatebtn.height + 12 + 36 + 20 + 24
            radius: 8
            clip: true
            color: Colors.color_2F3032
            border.color: Colors.color_454649

            border.width: 1
            Text {
                id: title
                color: Colors.color_EEEEEE
                font.pixelSize: 12
                height: 16
                horizontalAlignment: Text.AlignLeft
                anchors {
                    top: parent.top
                    topMargin: 12
                    horizontalCenter: parent.horizontalCenter
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
                            gpuDriverUpdateHintDialog.close()
                            if(!isConfirmDialog)
                            {
                                globalSignal.onOpenDriverUpdateConfirmMessagebox();
                            }else
                            {
                                globalSignal.onSaveAllowGpuDriverUpdatePopUp(!checkBox.checkState);
                            }
                        }
            }

            Text {
                id: content
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

            CheckBox {
                    id:checkBox
                    visible: isConfirmDialog?true:false
                    text: qsTr("pccut_graphics_upgrade_tip_3")
                    checked: false
                    width: 88
                    anchors {
                        top: content.bottom
                        topMargin: 26
                        left: parent.left
                        leftMargin: 29
                    }
                    height: 16

                    indicator: Rectangle {
                           id: indicator
                           width: 14
                           height: 14
                           anchors.left: checkBox.left
                           anchors.verticalCenter: parent.verticalCenter
                           color:  checkBox.checked ? ColorsConfig.color_brand : Colors.color_444444
                           radius: 4
                           Image {
                               id: icon2
                               visible: checkBox.checked
                               anchors.fill: parent
                               source: "qrc:/app_qrc/icons/icon_checkbox_check.svg"
                               sourceSize: Qt.size(parent.width, parent.height)
                           }
                       }
                       MouseArea {
                           anchors.fill: checkBox
                           onClicked: {
                               checkBox.checked = !checkBox.checked;
                           }
                       }
                       contentItem: HoverableText {
                           id: textItem
                           text: checkBox.text
                           font.pixelSize: 12
                           color: Colors.color_EEEEEE
                           verticalAlignment: Text.AlignVCenter  // 添加垂直居中对齐
                           leftPadding: checkBox.indicator.width + 6
                           cursorChanged: false
                           wrapMode: Text.NoWrap
                           anchors.fill: parent
                           anchors.verticalCenter: parent.verticalCenter
                       }
            }



            IconTextButton {
                id: updatebtn
                width: 88
                height: 28
                font.pixelSize: 12
                anchors {
                    top: content.bottom
                    topMargin: 20
                    right: parent.right
                    rightMargin: isConfirmDialog?32:136
                }
                alignment: Qt.AlignHCenter
                isTextOnly: true

                titleColorNormal: ColorsConfig.color_EEEEEE_000000
                backgroundColorNormal: ColorsConfig.color_brand
                backgroundColorPressed: ColorsConfig.color_F44C65_6DFFD3

                onCustomClicked: {
                    globalSignal.onOpenGpuGuideUrl();
                    gpuDriverUpdateHintDialog.close()
                }
            }
        }
    }
}
