import QtQuick 2.15
import QtQuick.Controls
import Config 1.0
import QtQuick.Window 2.15
import QtQuick.Layouts 1.15

import "qrc:/qml/controller"
Item{
    id:root
    property string titleText
    property string contentText
    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: root.top
        anchors.bottom: root.bottom
        spacing: 12  // 控制子项间距
        HoverableText {
            id: title
            Layout.preferredWidth: 51
            verticalAlignment: Text.AlignVCenter
            maximumLineCount: 2
            cursorChanged: false
            wrapMode: Text.WrapAnywhere
            color: Colors.color_CCCCCC
            font.pixelSize: 12
            text: titleText
        }
        Text {
            id: valueText
            verticalAlignment: Text.AlignVCenter
            color: Colors.color_CCCCCC
            Layout.fillWidth: true
            height: root.height
            elide: Text.ElideMiddle
            font.pixelSize: 12
            text: contentText
        }
    }

}
