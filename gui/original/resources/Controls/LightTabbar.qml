import QtQuick 2.15
import QtQuick.Controls
import Config 1.0
import Controls 1.0
import app_qrc 1.0

Rectangle {
    id: root
    height: visible ? 24 : 0
    anchors {
        top: parent.top
        topMargin: 16
        rightMargin: 1
    }
    radius: RadiusConfig.radius_4_88
    color: Colors.color_353738

    property ListModel dataList: ListModel {}
    property int currentIndex: 0

    ListView {
        id: hederList
        width: parent.width
        height: parent.height
        spacing: 0
        orientation: ListView.Horizontal
        model: dataList
        interactive: false
        delegate: MouseArea {
            width: hederList.width / hederList.count
            height: hederList.height
            property bool isSelected: root.currentIndex === index
            hoverEnabled: true
            onClicked: {
                root.currentIndex = index;
            }
            Rectangle {
                anchors.fill: parent
                color: isSelected ? Colors.color_EEEEEE_20 : Colors.color_transparent
                radius: RadiusConfig.radius_4_88
            }
            HoverableText {
                id: label
                anchors.centerIn: parent
                text: model.text
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                color: isSelected ? Theme.settingTabSelectedTitleColor : (parent.containsMouse ? Colors.color_EEEEEE : Theme.settingTabNormalTitleColor)
                maxTextWidth: parent.width - 8
                cursorChanged: false
                noWarp: true
                lineCount: 1
                onClicked: {
                    root.currentIndex = index;
                }
            }
        }
    }
}
