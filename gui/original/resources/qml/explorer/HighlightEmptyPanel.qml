import QtQuick 2.15
import Qt5Compat.GraphicalEffects
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

import Config 1.0
import Controls 1.0

/**
 * 高光空状态提示面板
 * 当高光 Tab 下没有数据时显示的引导界面
 */
Item {
    id: root
    
    property string descriptionText: qsTr("pccut_home_highlight_edit_newbie")

    // 回调函数
    signal buttonClicked()

    // 默认尺寸
    width: 236
    height: 176

    Image {
        id: backgroundRect
        x: 0
        y: 0
        width: 236
        height: 132
        source:"qrc:/icons/highlight/highlight_empty_back_rect"
        fillMode: Image.PreserveAspectFit

        Image {
            id: highlightEmptyAi
            anchors {
                top: backgroundRect.top
                topMargin: 8
                right: backgroundRect.right
                rightMargin: 8
            }
            width: 16
            height: 10
            source:"qrc:/icons/highlight/highlight_empty_ai.svg"
            fillMode: Image.PreserveAspectFit
        }

        Image {
            id: highlightEmptyMain
            anchors.centerIn: parent
            width: 221.21
            height: 99.33
            source:"qrc:/icons/highlight/highlight_empty_main.png"
            //sourceSize: Qt.size(width, height)
            smooth: true
            mipmap: true
            fillMode: Image.PreserveAspectFit

            Rectangle {
                anchors {
                    left: parent.left
                    leftMargin: 10.27
                    bottom: parent.bottom
                    bottomMargin: 11.96
                }
                color: Colors.color_FFFFFF
                radius: 1
                height: 6
                width: 2 + personHighlightTitle.implicitWidth
                Text {
                    id: personHighlightTitle
                    anchors.centerIn: parent
                    text: qsTr("pccut_home_highlight_newbie_character")
                    font.pixelSize: 4
                    font.weight: Font.DemiBold
                    color: Colors.color_141414
                }
            }

            Rectangle {
                anchors {
                    left: parent.left
                    leftMargin: 62.79
                    bottom: parent.bottom
                    bottomMargin: 11.96
                }
                color: Colors.color_FFFFFF
                radius: 1
                height: 6
                width: 2 + skiHighlightTitle.implicitWidth
                Text {
                    id: skiHighlightTitle
                    anchors.centerIn: parent
                    text: qsTr("pccut_home_highlight_newbie_skiing")
                    font.pixelSize: 4
                    font.weight: Font.DemiBold
                    color: Colors.color_141414
                }
            }

            Rectangle {
                anchors {
                    left: parent.left
                    leftMargin: 115.32
                    bottom: parent.bottom
                    bottomMargin: 11.96
                }
                color: Colors.color_FFFFFF
                radius: 1
                height: 6
                width: 2 + sceneryHighlightTitle.implicitWidth
                Text {
                    id: sceneryHighlightTitle
                    anchors.centerIn: parent
                    text: qsTr("pccut_home_highlight_newbie_view")
                    font.pixelSize: 4
                    font.weight: Font.DemiBold
                    color: Colors.color_141414
                }
            }

            Rectangle {
                anchors {
                    left: parent.left
                    leftMargin: 167.85
                    bottom: parent.bottom
                    bottomMargin: 11.96
                }
                color: Colors.color_FFFFFF
                radius: 1
                height: 6
                width: 2 + directionHighlightTitle.implicitWidth
                Text {
                    id: directionHighlightTitle
                    anchors.centerIn: parent
                    text: qsTr("pccut_home_highlight_newbie_forward")
                    font.pixelSize: 4
                    font.weight: Font.DemiBold
                    color: Colors.color_141414
                }
            }
        }
    }

    Item {
        anchors {
            left: parent.left
            right: parent.right
            top: backgroundRect.bottom
            topMargin: 12
        }

        height: 32
        // 标题
        Text {
            id: titleLabel
            anchors {
                top: parent.top
                horizontalCenter: parent.horizontalCenter
            }

            width: 212
            text: root.descriptionText
            font.pixelSize: 12
            font.weight: Font.Medium
            color: Colors.color_999999
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }
    }
}
