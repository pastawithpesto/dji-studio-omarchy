import QtQuick 2.15
import AgencyManager 1.0
import Config 1.0
import Controls 1.0
import app_qrc 1.0

Item {
    // 代理文件状态
    property int fileState: -1
    width: fileExist.visible ? fileExist.width + 4 : 15
    property real progress: 0 // 进度值，范围从0到1
    Rectangle {
        id: fileExist
        visible: fileState === AgencyManager.AGENCY_RESULT_AGENCY_EXISTS
        width: text.width + 4  // 减去左右边距
        height: 14
        radius: 3  // 圆角半径
        color: Colors.color_666666

        Text {
            id: text
            text: qsTr("pccut_project_modify_proxy")
            anchors.centerIn: parent
            font.pixelSize: 10
            color: Colors.color_262728
        }
    }

    Item {
        id: progressBar
        property real showProgress: fileState === AgencyManager.AGENCY_RESULT_AGENCY_WAIT ? 0 : progress
        onShowProgressChanged: {
            progressRingCanvas.requestPaint();
        }
        visible: fileState === AgencyManager.AGENCY_RESULT_AGENCY_WAIT || fileState === AgencyManager.AGENCY_RESULT_AGENCY_PROGRESS
        width: 10
        height: 10
        y: 2

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
        }

        LightToolTip {
            tip: fileState === AgencyManager.AGENCY_RESULT_AGENCY_WAIT ? qsTr("pccut_media_proxy_waiting") : qsTr("pccut_media_proxy_transcoding")
            visible: mouseArea.containsMouse
        }

        Canvas {
            id: progressRingCanvas
            // 这个比较大画的会清楚一些
            width: 20
            height: 20
            anchors.centerIn: parent
            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                var centerX = width / 2;
                var centerY = height / 2;
                var radius = 5; // 半径为5，直径为10

                // 绘制背景圆环
                ctx.beginPath();
                ctx.arc(centerX, centerY, radius, 0, 2 * Math.PI, false);
                ctx.lineWidth = 2;
                ctx.strokeStyle = Colors.color_999999;
                ctx.stroke();

                // 绘制进度圆环
                ctx.beginPath();
                ctx.arc(centerX, centerY, radius, -Math.PI / 2, (2 * Math.PI * progressBar.showProgress) - Math.PI / 2, false);
                ctx.lineWidth = 2;
                ctx.strokeStyle = ColorsConfig.color_brand;
                ctx.stroke();
            }
        }
    }
}
