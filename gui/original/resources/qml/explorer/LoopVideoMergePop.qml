import QtQuick 2.15
import QtQuick.Controls
import Config 1.0
import Controls 1.0
import app_qrc 1.0
import LoopVideoMergePopViewModel 1.0

LightPopup {
    id: popup

    signal leftButtonClicked   // 取消
    signal rightButtonClicked  // 合并

    width: lightWindow.width
    height: lightWindow.height
    dim: false
    z: 100

    // ViewModel：在 View 内部初始化，管理复选框状态和按钮动作
    LoopVideoMergePopViewModel {
        id: viewModel
        onCancelClicked: {
            popup.close()
            leftButtonClicked()
        }
        onMergeClicked: {
            popup.close()
            rightButtonClicked()
        }
    }

    contentItem: Item {
        // 背景矩形只贴合内容区，不铺满全屏
        Rectangle {
            anchors.fill: contentLayout
            color: Colors.color_2F3032
            radius: 8
            clip: true
            border.width: 1
            border.color: Colors.color_454649
        }

        // 拦截穿透到底层的事件
        MouseArea {
            anchors.fill: parent
        }

        Item {
            id: contentLayout
            anchors.centerIn: parent
            width: 248
            height: 156

            Column {
                anchors {
                    top: parent.top
                    topMargin: 24
                    horizontalCenter: parent.horizontalCenter
                }
                width: 192
                spacing: 8

                Text {
                    id: mergePopText
                    width: 192
                    text: qsTr("pccut_material_video_merge") //识别到有同次拍摄的连续循环录影视频，是否将其合并展示？合并后视频在素材库、时间轨道上均会合并
                    font.pixelSize: 14
                    wrapMode: Text.Wrap
                    color: Colors.color_EEEEEE
                    horizontalAlignment: Text.AlignHCenter
                    maximumLineCount: 2
                    elide: Text.ElideRight

                    MouseArea {
                        id: mergePopTextMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                    }

                    LightToolTip {
                        visible: mergePopTextMouseArea.containsMouse && mergePopText.truncated
                        tip: mergePopText.text
                    }
                }

                LightCheckBox {
                    id: noRemindCheckBox
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: 16
                    maxTextWidth: 80
                    font.pixelSize: 12
                    text: qsTr("pccut_material_not_show_again") //不再提示
                    checked: viewModel.noRemind
                    onCheckedChanged: viewModel.noRemind = checked
                    textColor: checked ? Colors.color_EEEEEE : Colors.color_999999
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (mouseX >= noRemindCheckBox.indicator.x &&
                                mouseX <= noRemindCheckBox.indicator.x + noRemindCheckBox.indicator.width &&
                                mouseY >= noRemindCheckBox.indicator.y &&
                                mouseY <= noRemindCheckBox.indicator.y + noRemindCheckBox.indicator.height) {
                                noRemindCheckBox.toggle()
                            }
                        }
                    }
                }
            }

            IconTextButton {
                id: cancelBtn
                width: 88
                height: 28
                anchors {
                    left: parent.left
                    leftMargin: 28
                    bottom: parent.bottom
                    bottomMargin: 20
                }
                isTextOnly: true
                title: qsTr("pccut_material_cancel") //取消
                titleColorNormal: Colors.color_FFFFFF
                backgroundColorNormal: Colors.color_68696D
                backgroundColorHover: Colors.color_7A7B80
                onCustomClicked: viewModel.onCancel()
            }

            IconTextButton {
                id: mergeBtn
                width: 88
                height: 28
                anchors {
                    right: parent.right
                    rightMargin: 28
                    bottom: parent.bottom
                    bottomMargin: 20
                }
                isTextOnly: true
                title: qsTr("pccut_material_merge") //合并
                titleColorNormal: ColorsConfig.color_FFFFFF_000000
                backgroundColorNormal: ColorsConfig.color_brand
                backgroundColorHover: ColorsConfig.color_F44C65_6DFFD3
                onCustomClicked: viewModel.onMerge()
            }
        }
    }
}
