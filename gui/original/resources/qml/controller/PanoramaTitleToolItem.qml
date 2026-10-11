import QtQuick 2.15
import QtQuick.Controls
import Controls 1.0
import Config 1.0

/**
 * @author robert.guo
 * @desc 取景右侧面板, 顶部工具栏
 * @create_date 2024-06-12
 */
Item {
    property alias toolTip: tip.tip
    property var imgSource
    property var hoverImgSource: imgSource
    property bool hover: false
    property bool disabled: false
    signal click()

    Rectangle {
        anchors.fill: parent
        radius: 4
        color: Colors.color_transparent

        Image {
            id: icon
            anchors.fill: parent
            sourceSize: Qt.size(20, 20)
            source: mouseArea.containsMouse ? hoverImgSource : imgSource

            opacity: disabled ? 0.2 : 1
            MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    click()
                }
            }

            LightToolTip {
                id: tip
                visible: mouseArea.containsMouse
            }
        }
    }
}
