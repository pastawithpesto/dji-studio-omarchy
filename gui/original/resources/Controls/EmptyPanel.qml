import QtQuick 2.15
import Config 1.0
import QmlConstants 1.0
import app_qrc 1.0

/**
 * @author robert.guo
 * @desc 空列表展示面板
 * @create_date 2024-04-30
 */
Item {
    // 一级文案
    property string desc_tip1: qsTr("pccut_network_error") + ","
    // 二级文案
    property string desc_tip2: qsTr("pccut_feedback_retry")
    // 三级文案
    property string desc_tip3

    // 一级文案色值
    property color color_tip1: Colors.color_D8D8D8
    // 二级文案色值
    property color color_tip2: ColorsConfig.color_brand
    // 三级文案色值
    property color color_tip3
    // 无网icon
    property string no_network_source: "qrc:/icons/icon_reload_red.svg"

    // 数据为空icon
    property alias source: importIv.source
    property alias sourceSize: importIv.sourceSize
    // 是否是无网模式
    property bool no_network_mode: false
    // 网络请求类型，音乐，滤镜等
    property string network_request_type: ""

    // 列表为空，点击发送的signal
    signal click

    // 列表为空样式
    Rectangle {
        anchors.fill: parent
        layer.enabled: true
        anchors.centerIn: parent
        visible: !no_network_mode
        color: emptyMouse.containsMouse ? Colors.color_FFFFFF_10 : Colors.color_2F3032
        border.color: Colors.color_454649
        border.width: QmlConstants.isWhiteXtra() ? 0 : 1
        radius: 8
        Image {
            id: importIv
            height: 44
            width: 44
            anchors {
                top: parent.top
                horizontalCenter: parent.horizontalCenter
                topMargin: 35
            }
        }

        Text {
            id: tip1
            font.pixelSize: 12
            anchors {
                top: importIv.bottom
                horizontalCenter: parent.horizontalCenter
                topMargin: 12
            }
            text: desc_tip1
            color: color_tip1
        }

        Text {
            id: tip2
            font.pixelSize: 12
            anchors {
                top: tip1.bottom
                horizontalCenter: parent.horizontalCenter
                topMargin: 8
            }
            text: desc_tip2
            color: color_tip2
        }

        MouseArea {
            id: emptyMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
                click();
            }
        }

        HoverableText {
            id: tip3
            font.pixelSize: 11
            maximumLineCount: 2
            anchors {
                top: tip2.bottom
                left: parent.left
                leftMargin: 12
                right: parent.right
                rightMargin: 12
            }
            text: desc_tip3
            wrapMode: Text.WordWrap
            cursorChanged: false
            horizontalAlignment: Text.AlignHCenter
            color: color_tip3

            onClicked: {
                click();
            }
        }
    }

    // 无网样式
    Item {
        width: childrenRect.width
        height: 20
        anchors.centerIn: parent
        visible: no_network_mode

        Text {
            id: network_error
            text: desc_tip1
            color: color_tip1
            font.pixelSize: 11
            anchors {
                verticalCenter: parent.verticalCenter
            }
        }

        Image {
            id: no_network_icon
            width: 16
            height: 16
            source: no_network_source
            anchors {
                left: network_error.right
                leftMargin: 4
                verticalCenter: parent.verticalCenter
            }
        }

        Text {
            text: desc_tip2
            color: color_tip2
            font.pixelSize: 11
            anchors {
                left: no_network_icon.right
                leftMargin: 4
                verticalCenter: parent.verticalCenter
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
                click();
            }
        }
    }
}
