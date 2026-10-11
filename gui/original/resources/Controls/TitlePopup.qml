import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.15
import LightRectangle 1.0
import Config 1.0

/**
 * Created by fread.zhang on 2024-06-03 .
 * ClassName : TitlePopup
 * Description :一个标题列表的pop
 * Copyright : ©2024 Light All Rights Reserved.
 */
LightPopup {
    id: popup
    padding: 0
    width: 52
    height: contentItem.height
    // 需要写一个 ListModel 类型的model 进行赋值
    property ListModel titleArray

    closePolicy: Popup.CloseOnPressOutside
    signal clickIndex(int index)
    contentItem: Rectangle {
        width: popup.width
        height: 6 + 6 + 24 * titleArray.count
        radius: 8
        clip: true
        layer.enabled: true
        color: Colors.color_292B30
        border {
            color: Colors.color_FFFFFF_20
            width: 1
        }
        Column {
            spacing: 0
            anchors {
                fill: parent
                topMargin: 6
                bottomMargin: 6
            }

            Repeater {
                model: titleArray
                anchors.fill: parent
                delegate: Rectangle {
                    width: parent.width
                    height: 24
                    clip: true
                    color: mouseArea.containsMouse ? Colors.color_CCCCCC_10 : Colors.color_transparent
                    Text {
                        text: model.text
                        anchors.fill: parent
                        font.pixelSize: 10
                        color: Colors.color_EEEEEE
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            clickIndex(index);
                            close();
                        }
                    }
                }
            }
        }
    }
}
