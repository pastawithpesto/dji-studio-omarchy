import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.3
import Config 1.0
import Controls 1.0
import app_qrc 1.0
import ExportEventReport 1.0

/**
 * @author tengsen.zhang
 * @desc 导出队列进度条
 * @create_date 2024-10-08
 */
Rectangle {
    property real progress: 0
    signal cancelClicked
    signal retryClicked
    color: Colors.color_transparent
    property bool isWaitting
    property bool isFail: false
    property string error:""

    ColumnLayout {
        anchors.fill: parent
        spacing: 8
        ProgressBar {
            id: progressBar
            Layout.fillWidth: true
            Layout.preferredHeight: 2
            visible: !isWaitting  && !isFail
            value: progress / 360
            from: 0
            to: 1
            // 设置背景矩形的颜色
            background: Rectangle {
                implicitWidth: parent.width
                implicitHeight: parent.height
                color: Colors.color_666666
                radius: parent.height / 2
            }

            // 设置进度矩形的颜色
            contentItem: Item {
                Rectangle {
                    width: progressBar.value * parent.width
                    height: parent.height
                    color: ColorsConfig.color_brand
                    radius: parent.height / 2
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            Text {
                text: isWaitting ? qsTr("pccut_exporting_waiting") : qsTr("pccut_exporting_exporting") + " " + Math.round(progress / 360 * 100) + "%"
                color: isWaitting ? Colors.color_666666 : Colors.color_EEEEEE
                Layout.alignment: Qt.AlignLeft
                font.pixelSize: 11
                visible: !isFail
            }

            Text {
                text: qsTr("pccut_export_task_exporting_text_fail")
                color: Colors.color_F22443
                Layout.alignment: Qt.AlignLeft
                font.pixelSize: 12
                visible: isFail
            }
            Image {
                id: failTipsIcon
                source: "qrc:/icons/icon_export_fail_tips.svg"
                visible: isFail
                sourceSize: Qt.size(12, 12)
                Layout.leftMargin: -6
                Layout.topMargin: -1
                MouseArea {
                    id: tipsArea
                    anchors.fill: parent
                    hoverEnabled: true
                    
                    onEntered: {
                        if(error.length === 0){
                            return;
                        }
                        if(error === String(ExportEventReport.ERROR_CODE_4503)){
                            //分段导出如果文件夹不存在（只读），根据错误码给出对应提示
                            error = qsTr("pccut_editor_fail_warn_4");
                        }
                        var globalPos = failTipsIcon.mapToItem(Overlay.overlay, 0, 0);
                        globalSignal.showComposeFailToast(globalPos.x,globalPos.y,error)
                    }
                    
                    onExited: {
                        globalSignal.hideComposeFailToast()
                    }
                }
            }

            Item {
                Layout.fillWidth: true
            }
            Image {
                source: retryArea.containsMouse ? "qrc:/icons/icon_export_retry_hover.svg" : "qrc:/icons/icon_export_retry.svg"
                visible: isFail
                MouseArea {
                    id: retryArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        retryClicked()  // 发出信号
                    }
                }
            }
            Image {
                source: deleteArea.containsMouse ? "qrc:/icons/icon_export_task_delete_hover.svg" : "qrc:/icons/icon_export_task_delete.svg"
                MouseArea {
                    id: deleteArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        cancelClicked()  // 发出信号
                    }
                }
            }
        }

    }
}
