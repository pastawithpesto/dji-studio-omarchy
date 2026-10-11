import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.3
//自定义titlebar 包含title和icon
Item {
    width: parent.width
    height: parent.height
    property alias text: title.text
    property alias source: icon.source

    Rectangle{
        id:root
        width: parent.width
        height: parent.height
        color: Colors.color_545457

        Label {
            id:title
            text: "默认title"
            color: Colors.color_FFFFFF
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 10
        }

        Image{
            id:icon
            height: 20
            width: 20
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: 10
            visible: source ? true:false
        }
    }
}
