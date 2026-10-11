import QtQuick.Window 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.3
import QtQuick 2.15
import LightRectangle 1.0

LightFullArea{

    default property alias content: container.data

    Flickable{
        id:flickview
        clip: true
        anchors.fill: parent
        contentWidth: parent.width
        contentHeight: container.height
        ScrollBar.vertical: ScrollBar {
            anchors.right: flickview.right
            anchors.rightMargin: 2
        }
        boundsBehavior: Flickable.StopAtBounds
        ColumnLayout{
            id:container
            clip: true
            anchors{
                left: parent.left
                right: parent.right
                top: parent.top
            }
            width: parent.width

        }
    }
}
