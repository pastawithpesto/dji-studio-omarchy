import QtQuick 2.15
import QtQuick.Controls
import Config 1.0
import QtQuick.Window 2.15
import QtQuick.Layouts 1.15
import "qrc:/qml/controller"
import app_qrc 1.0

Item{
    id:root
    property string titleText
    property string contentText
    property string btnText
    property bool selectEnable:true
    property bool showWarning: false
    property color warningColor: Colors.color_F22443
    property string warningText: ""
    property var selectedItem
    property alias valueTextCom: valueText  // 暴露整个Text组件
    property int itemSpacing:0
    property int spacing_1:12
    property int spacing_2:8
    clip: false
    signal customClick()
    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: root.top
        anchors.bottom: root.bottom
        spacing: itemSpacing  // 控制子项间距
        HoverableText {
            id: title
            Layout.preferredWidth: 51
            verticalAlignment: Text.AlignVCenter
            color: Colors.color_CCCCCC
            font.pixelSize: 12
            text: titleText
            maximumLineCount: 2
            cursorChanged: false
            wrapMode: Text.WrapAnywhere
        }
        Item { Layout.preferredWidth: root.spacing_1 }  // 第一个间隔15像素

        Rectangle {
            id: filePathChooseRectangle
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            //height: root.height
            Layout.fillHeight: true
            color: valueArea.containsMouse ? Colors.color_68696D:Colors.color_454649
            radius: RadiusConfig.radius_4_8
            border.width: root.showWarning ? 1 : 0
            border.color: root.warningColor
            Text {
                id: valueText
                anchors {
                    left: parent.left
                    leftMargin: 8
                    top: parent.top
                    right: parent.right
                    rightMargin: 8
                    bottom: parent.bottom
                }
                text:contentText
                // 省略号
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignLeft
                verticalAlignment: Text.AlignVCenter
                color: Colors.color_FFFFFF
                font.pixelSize: 12
            }
            MouseArea {
                id:valueArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    customClick()
                }
            }
        }
        Item { Layout.preferredWidth: root.spacing_2 }  // 第2个间隔8像素
        //按钮
        Rectangle {
            id: btn
            Layout.fillHeight: true
            width: 56
            color: btnArea.containsMouse ? Colors.color_68696D:Colors.color_454649
            radius: RadiusConfig.radius_4_8

            HoverableText {
                id: btnArea
                anchors.fill: parent
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: 12
                color: Colors.color_EEEEEE
                text: root.btnText
                cursorChanged: false
                wrapMode: Text.NoWrap
                onClicked: {
                    customClick()
                }
            }
        }
    }

    // 警告文字（溢出到父容器间距区域）
    Text {
        visible: root.warningText.length > 0
        x: title.width + root.spacing_1
        y: root.height
        height: 16
        font.pixelSize: 11
        font.weight: Font.Medium
        color: root.warningColor
        text: root.warningText
        verticalAlignment: Text.AlignVCenter
    }
}
