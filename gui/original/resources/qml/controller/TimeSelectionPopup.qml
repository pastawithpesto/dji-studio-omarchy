import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls
import QtQuick.Dialogs
import Controls 1.0
import Config 1.0
import Qt5Compat.GraphicalEffects
import MediaListViewModel 1.0
import app_qrc 1.0

/**
 * @author tengsen.zhang
 * @desc 时间选择弹窗
 * @create_date 2024-10-16
 */
LightPopup {
    id: popup
    parent: Overlay.overlay
    modal: true
    closePolicy: Popup.CloseOnPressOutside
    width: 90
    height: 196

    property string currentName: getTypeName(currentTimeType)
    // 点击根据哪个字段筛选
    signal clickTimeType(var timeType)
    property int currentTimeType: dashboardManager.timeType

    function getTypeName(type) {
        switch(type){
        case 0:
            return qsTr("pccut_dashboard_100ms");
        case 1:
            return qsTr("pccut_dashboard_1s");
        case 2:
            return qsTr("pccut_dashboard_10s");
        case 3:
            return qsTr("pccut_dashboard_1min");
        case 4:
            return qsTr("pccut_dashboard_10min");
        case 5:
            return qsTr("pccut_dashboard_60min");
        }
        return qsTr("pccut_dashboard_1min");
    }

    contentItem: LightClipRectangle {
        anchors.fill: parent
        clip: true
        radius: [8,8,8,8]

        ShaderEffectSource {
            id: shaderSources
            sourceItem: mainPanel
            sourceRect: Qt.rect(popup.x, popup.y, popup.width, popup.height)
            width: parent.width
            height: parent.height
            live: true
            smooth: true
        }

        // 高斯调节
        FastBlur {
            anchors.fill: parent
            source: shaderSources
            radius: 48
        }

        Rectangle {
            anchors.fill: parent
            border.color: Colors.color_444444
            border.width: 0.5
            color: Colors.color_141414_85
            radius: 8
        }

        ListModel {
            id: timeModel
            ListElement {
                timeType: 0
                title: qsTr("pccut_dashboard_100ms")
            }
            ListElement {
                timeType: 1
                title: qsTr("pccut_dashboard_1s")
            }
            ListElement {
                timeType: 2
                title: qsTr("pccut_dashboard_10s")
            }
            ListElement {
                timeType: 3
                title: qsTr("pccut_dashboard_1min")
            }
            ListElement {
                timeType: 4
                title: qsTr("pccut_dashboard_10min")
            }
            ListElement {
                timeType: 5
                title: qsTr("pccut_dashboard_60min")
            }
        }

        Column {
            width: parent.width - 8
            height: 180
            anchors {
                top: parent.top
                topMargin: 4
                horizontalCenter: parent.horizontalCenter
            }
            spacing: 4

            Repeater {
                model: timeModel
                anchors.fill: parent

                delegate: Rectangle {
                    id: timeRect
                    property bool isHovered: false
                    width: parent.width
                    height: 28
                    radius: RadiusConfig.radius_4_8
                    color: timeRect.isHovered ? ColorsConfig.color_FFFFFF15_4DFFC920 : Colors.color_transparent
                    anchors.horizontalCenter: parent.horizontalCenter
                    Image {
                        width: 16
                        height: 16
                        source: "qrc:/app_qrc/icons/icon_compose_check.svg"
                        anchors.verticalCenter: parent.verticalCenter
                        x: 7
                        visible: timeType === dashboardManager.timeType
                    }

                    Text {
                        id: timeText
                        text: model.title
                        height: parent.height
                        font.pixelSize: 11
                        color: (timeType === dashboardManager.timeType ||timeRect.isHovered) ? ColorsConfig.color_EEEEEE_4DFFC9 : Colors.color_EEEEEE
                        leftPadding: 28
                        verticalAlignment: Text.AlignVCenter
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: timeRect.isHovered = true;
                        onExited: timeRect.isHovered = false;
                        onClicked: {
                            close();
                            clickTimeType(timeType);
                        }
                    }
                }
            }
        }
    }
}
