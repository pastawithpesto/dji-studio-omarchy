import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.3
import Config 1.0
import ExportTabViewModel 1.0
import app_qrc 1.0

Button {
    id: exportListRectangle
    property real itemProgress: 0
    property real exportCount: 0
    property real pausedFailedCount: 0
    property bool showFinishImage: false
    property bool showHistoryDot: false

    implicitHeight: 26
    Accessible.role: Accessible.Button
    hoverEnabled: true

    verticalPadding: 4
    background: Rectangle {
        color: exportListRectangle.hovered ? Colors.color_button_background_hovered : Colors.color_button_background_normal
        radius: RadiusConfig.radius_6_88
    }

    contentItem: RowLayout {
        spacing: 4
        Item {
            Layout.fillWidth: true
        }
        Image {
            id: exportListImage
            z: 1
            Layout.preferredWidth: 16
            Layout.preferredHeight: 16
            Layout.alignment: Qt.AlignVCenter
            source: "qrc:/app_qrc/icons/btn_exportlist.svg"
            sourceSize: Qt.size(16, 16)

            Rectangle {
                x: 10
                y: -1
                width: 7
                height: 7
                radius: 5
                color: ColorsConfig.color_brand
                border.width: 1
                border.color: exportListRectangle.hovered ? Colors.color_button_background_hovered : Colors.color_button_background_normal
                visible: showFinishImage || (exportCount === 0 && pausedFailedCount === 0 && showHistoryDot)
            }

            CountBadge {
                id: countRectangle
                x: 7
                y: -3
                count: exportCount
                badgeColor: ColorsConfig.color_brand
                badgeBorderWidth: 1
                badgeBorderColor: exportListRectangle.hovered ? Colors.color_button_background_hovered : Colors.color_button_background_normal
                textColor: ColorsConfig.color_FFFFFF_000000
                visible: exportCount > 0

                SequentialAnimation {
                    id: animation
                    NumberAnimation {
                        target: countRectangle
                        property: "scale"
                        from: 0
                        to: 1.2
                        duration: 200
                    }
                    NumberAnimation {
                        target: countRectangle
                        property: "scale"
                        from: 1.2
                        to: 1
                        duration: 100
                    }
                }

                Connections {
                    target: globalSignal

                    function onClickExportButton() {
                        animation.start()
                    }
                }
            }

            CountBadge {
                id: pausedFailedCountRectangle
                x: 7
                y: -3
                count: pausedFailedCount
                badgeColor: Colors.color_EEEEEE
                badgeBorderWidth: 1
                badgeBorderColor: exportListRectangle.hovered ? Colors.color_button_background_hovered : Colors.color_button_background_normal
                textColor: Colors.color_141414
                visible: exportCount <= 0 && pausedFailedCount > 0
            }
        }
        //导出队列文本
        Text {
            id: exportListText
            Layout.alignment: Qt.AlignVCenter
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            color: Colors.color_FFFFFF
            text: qsTr("pccut_queue")
        }
        Item {
            Layout.fillWidth: true
        }
    }

    Connections {
        target: projectExportEnvManager
        // 正在导出的信号
        function onExportProgress(compose_draft_path, taskId, exportPath, progress) {
            exportListRectangle.itemProgress = progress * 360;
        }
        //导出停止时进度归零
        function onExportFinished(compose_draft_path, taskId, exportPath, success, context) {
            exportListRectangle.itemProgress = 0;
        }
        function onExportError(compose_draft_path, taskId, exportPath, error_code, error_str, context) {
            exportListRectangle.itemProgress = 0;
        }
    }
}
