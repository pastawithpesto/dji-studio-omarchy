import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls
import QtQuick.Dialogs
import Qt5Compat.GraphicalEffects
import Controls 1.0
import Config 1.0
import MediaListViewModel 1.0
import app_qrc 1.0

Popup {
    id: diffColorPopup

    property real itemBgWidth: width - 8
    property var intensityModel
    property int ownerRadius: 4
    // 当前选中的 index
    property int selectedIndex: -1
    property string selectedText: {
        if (!intensityModel || selectedIndex < 0 || selectedIndex >= intensityModel.length)
            return ""
        return intensityModel.get(selectedIndex).text
    }

    signal itemClicked(int index, var value)

    closePolicy: Popup.CloseOnEscape
    modal: false // 默认不阻塞
    width: 184
    height: 100


    background: Rectangle {
        color: Colors.color_19191A
        border.color: Colors.color_454649
        border.width:  1
        radius: ownerRadius
    }

    contentItem: Item {
        anchors.fill: parent
        clip: true
        anchors.leftMargin: 4   // 左内边距
        anchors.topMargin: 4    // 上内边距由父容器控制
        anchors.rightMargin: 4 // 右内边距
        anchors.bottomMargin: 0 // 下内边距

        Column {
            width: 176
            height: 28
            spacing: 4

            Repeater {
                model: intensityModel
                anchors.fill: parent

                delegate: Rectangle {
                    id: rec
                    property bool isHovered: false

                    radius: 2
                    width: itemBgWidth
                    height: 28
                    color: rec.isHovered ? Colors.color_37383A : Colors.color_transparent //悬浮背景色
                    anchors.horizontalCenter: parent.horizontalCenter

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        spacing: 8
                        //勾选号
                        Item {
                            width: 16
                            height: 16
                            Image {
                                anchors.fill: parent
                                source: "qrc:/app_qrc/icons/icon_compose_check.svg"
                                anchors.verticalCenter: parent.verticalCenter
                                visible: index === diffColorPopup.selectedIndex
                            }
                        }
                        //文本
                        Text {
                            id: positionText
                            text: model.text
                            width: 53
                            height: 15
                            font.pixelSize: 11
                            color: (index === diffColorPopup.selectedIndex || rec.isHovered) ? ColorsConfig.color_EEEEEE_4DFFC9 : Colors.color_EEEEEE
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                    //点击区
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: rec.isHovered = true;
                        onExited: rec.isHovered = false;
                        onClicked: {
                            itemClicked(index, model.value)
                            close();
                        }
                    }
                }
            }
        }
    }
}
