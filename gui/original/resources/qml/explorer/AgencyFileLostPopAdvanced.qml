import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.3
import Controls 1.0
import Config 1.0
import Qt5Compat.GraphicalEffects
import app_qrc 1.0
import "../menubar"

// 循环录影代理文件部分缺失弹窗
// 场景：循环录影所有子视频均无代理文件时弹出，展示所有缺失的代理文件名
// 与 AgencyFileLostPop 的区别：
//   1. 主文案描述循环录影特有的 .LRF/.OSV 操作指引
//   2. 按钮变为 [打开.OSV目录] [继续切换]（无"打开代理"按钮）
//   3. model 由外部通过 lostFileList 属性注入，不依赖 agencyFileLostViewModel
LightPopup {
    // 缺失的代理文件名列表，由调用方传入（字符串数组）
    property var lostFileList: []

    signal openOsvDirClicked   // 打开.OSV目录
    signal continueClicked     // 继续切换

    width: lightWindow.width
    height: lightWindow.height
    dim: false
    z: 100

    contentItem: Item {
        id: content

        Rectangle {
            anchors.fill: contentLayout
            color: Colors.color_2F3032
            radius: 8
            clip: true
            border.width: 1
            border.color: Colors.color_454649
        }

        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            id: contentLayout
            anchors.centerIn: parent
            width: 360
            height: 388
            spacing: 0

            WindowTitleBar {
                id: titleBar
                Layout.preferredHeight: 40
                Layout.preferredWidth: parent.width
                title: qsTr("pccut_player_preview_mode_smooth_tex_1")
                onCloseClick: {
                    close()
                }
            }

            Text {
                id: titleLabel
                Layout.topMargin: 16
                Layout.preferredWidth: 304
                Layout.alignment: Qt.AlignHCenter
                text:qsTr("pccut_material_partial_proxy_missing") // "部分代理文件缺失，点击继续切换，缺失代理文件的部分将采用高清模式预览。您也可通过\"打开.OSV目录\"的方式，将机内同名.LRF文件拷贝至.OSV同目录下。"
                color: Colors.color_FFFFFF
                font.pixelSize: 12
                wrapMode: Text.Wrap
                maximumLineCount: 3
                elide: Text.ElideRight

                MouseArea {
                    id: titleLabelMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                }

                LightToolTip {
                    visible: titleLabelMouseArea.containsMouse && titleLabel.truncated
                    tip: titleLabel.text
                }
            }

            Rectangle {
                id: line
                Layout.topMargin: 16
                Layout.preferredWidth: 304
                Layout.preferredHeight: 1
                Layout.alignment: Qt.AlignHCenter
                color: Colors.color_454649
            }

            Text {
                id: listviewTitle
                Layout.topMargin: 18
                Layout.preferredWidth: 200
                Layout.preferredHeight: 16
                Layout.alignment: Qt.AlignLeft
                Layout.leftMargin: 28
                text: qsTr("pccut_player_preview_mode_smooth_tex_2")
                color: Colors.color_EEEEEE
                font.pixelSize: 12
                wrapMode: Text.Wrap
            }

            Item {
                id: contain
                Layout.topMargin: 10
                Layout.preferredWidth: parent.width - 36
                Layout.preferredHeight: 128
                Layout.alignment: Qt.AlignLeft
                Layout.leftMargin: 28

                ListView {
                    id: devlistView
                    height: 108
                    width: parent.width
                    clip: true
                    spacing: 8
                    model: lostFileList
                    delegate: contactDelegate

                    ScrollBar.vertical: ScrollBar {
                        id: vbar
                        visible: devlistView.contentHeight > devlistView.height
                        background: Rectangle {
                            color: Colors.color_transparent
                        }
                        contentItem: Rectangle {
                            implicitWidth: 6
                            radius: 72
                            color: vbar.hovered ? Colors.color_56575B : Colors.color_454649
                        }
                    }
                }
            }

            Component {
                id: contactDelegate

                Rectangle {
                    width: devlistView.width
                    height: 16
                    radius: 2
                    color: Colors.transparent

                    Text {
                        text: modelData
                        font.pixelSize: 12
                        color: Colors.color_999999
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            Item {
                id: actionButton
                Layout.preferredHeight: 28
                Layout.preferredWidth: parent.width
                Layout.bottomMargin: 24
                Layout.rightMargin: 28
                Layout.alignment: Qt.AlignRight | Qt.AlignBottom
                Layout.fillWidth: true

                // 继续切换（右侧）
                Rectangle {
                    id: continueBtn
                    color: continueMouseArea.containsMouse ? Colors.color_F44C65 : Colors.color_F22443
                    radius: RadiusConfig.radius_4_88
                    width: 80
                    height: 28
                    anchors.right: parent.right

                    Text {
                        id: continueBtnText
                        text: qsTr("pccut_material_continue_switch") //"继续切换"
                        color: Colors.color_FFFFFF
                        anchors.centerIn: parent
                        font.pixelSize: 12
                    }

                    MouseArea {
                        id: continueMouseArea
                        hoverEnabled: true
                        anchors.fill: parent
                        onClicked: {
                            continueClicked()
                        }
                    }
                }

                // 打开.OSV目录（继续切换左侧8px）
                Rectangle {
                    id: openOsvBtn
                    color: openOsvMouseArea.containsMouse ? Colors.color_777777 : Colors.color_666666
                    radius: RadiusConfig.radius_4_88
                    width: openOsvBtnText.width + 28
                    height: 28
                    anchors.right: continueBtn.left
                    anchors.rightMargin: 8

                    Text {
                        id: openOsvBtnText
                        text: qsTr("pccut_material_open_osv_directory") //"打开.OSV目录"
                        color: Colors.color_FFFFFF
                        anchors.centerIn: parent
                        font.pixelSize: 12
                    }

                    MouseArea {
                        id: openOsvMouseArea
                        hoverEnabled: true
                        anchors.fill: parent
                        onClicked: {
                            openOsvDirClicked()
                        }
                    }
                }
            }
        }
    }
}
