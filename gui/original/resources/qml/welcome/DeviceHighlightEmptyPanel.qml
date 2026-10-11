import QtQuick 2.15
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

    // 对外属性
    property string titleText: qsTr("pccut_home_highlight_switch_1")
    property string descriptionText: qsTr("pccut_home_highlight_newbie")
    property string buttonText: qsTr("pccut_home_highlight_edit_newbie_switch")

    // 回调函数
    signal backOriginalPage()

    // 默认尺寸
    width: 654
    height: 476

    Item {
        id: backgroundImageContent
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
        }

        height: 280
        Image {
            id: highlightEmptyMain
            anchors.horizontalCenter: parent.horizontalCenter
            width: 657
            height: 295.5
            source:"qrc:/icons/highlight/highlight_empty_main.png"
            smooth: true
            mipmap: true
            fillMode: Image.PreserveAspectFit

            Rectangle {
                anchors {
                    left: parent.left
                    leftMargin: 30.5
                    bottom: parent.bottom
                    bottomMargin: 35.5
                }
                color: Colors.color_FFFFFF
                radius: 3
                height: 16
                width: 8 + personHighlightTitle.implicitWidth
                Text {
                    id: personHighlightTitle
                    anchors.centerIn: parent
                    text: qsTr("pccut_home_highlight_newbie_character")
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    color: Colors.color_141414
                }
            }

            Rectangle {
                anchors {
                    left: parent.left
                    leftMargin: 186.5
                    bottom: parent.bottom
                    bottomMargin: 35.5
                }
                color: Colors.color_FFFFFF
                radius: 3
                height: 16
                width: 8 + skiHighlightTitle.implicitWidth
                Text {
                    id: skiHighlightTitle
                    anchors.centerIn: parent
                    text: qsTr("pccut_home_highlight_newbie_skiing")
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    color: Colors.color_141414
                }
            }

            Rectangle {
                anchors {
                    left: parent.left
                    leftMargin: 342.5
                    bottom: parent.bottom
                    bottomMargin: 35.5
                }
                color: Colors.color_FFFFFF
                radius: 3
                height: 16
                width: 8 + sceneryHighlightTitle.implicitWidth
                Text {
                    id: sceneryHighlightTitle
                    anchors.centerIn: parent
                    text: qsTr("pccut_home_highlight_newbie_view")
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    color: Colors.color_141414
                }
            }

            Rectangle {
                anchors {
                    left: parent.left
                    leftMargin: 498.5
                    bottom: parent.bottom
                    bottomMargin: 35.5
                }
                color: Colors.color_FFFFFF
                radius: 3
                height: 16
                width: 8 + directionHighlightTitle.implicitWidth
                Text {
                    id: directionHighlightTitle
                    anchors.centerIn: parent
                    text: qsTr("pccut_home_highlight_newbie_forward")
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    color: Colors.color_141414
                }
            }
        }

        LightClipRectangle {
            id: titleBarClip
            radius: [5, 5, 0, 0]
            width: 497.78
            height: 18
            color: Colors.color_1F2021
            anchors.horizontalCenter: parent.horizontalCenter
            clip: true

            Rectangle {
                id: redRect
                anchors {
                    left: parent.left
                    leftMargin: 5.33
                    verticalCenter: parent.verticalCenter
                }
                color: Colors.color_FF5F57
                width: 5.33
                height: 5.55
                radius: 2.67
                border.width: 0.22
                border.color: Colors.color_000000_20
            }

            Rectangle {
                id: yellowRect
                anchors {
                    left: redRect.right
                    leftMargin: 3.56
                    verticalCenter: parent.verticalCenter
                }
                color: Colors.color_FEBC2E
                width: 5.33
                height: 5.55
                radius: 2.67
                border.width: 0.22
                border.color: Colors.color_000000_20
            }

            Rectangle {
                id: greenRect
                anchors {
                    left: yellowRect.right
                    leftMargin: 3.56
                    verticalCenter: parent.verticalCenter
                }
                color: Colors.color_28C840
                width: 5.33
                height: 5.55
                radius: 2.67
                border.width: 0.22
                border.color: Colors.color_000000_20
            }
        }

        Image {
            id: highlightEmptyAi
            anchors {
                top: titleBarClip.top
                topMargin: 30
                right: titleBarClip.right
                rightMargin: 16.78
            }
            width: 28
            height:16
            source:"qrc:/icons/highlight/highlight_empty_ai.svg"
            fillMode: Image.PreserveAspectFit
        }

        Rectangle {
            anchors {
                left: backgroundImageContent.left
                leftMargin: 86.89
                top: backgroundImageContent.top
                topMargin: 26.67
            }
            color: Colors.color_000000_50
            height: 14.22
            radius: 2.67
            width: 8.9 + 8.9 + panoLabel.implicitWidth

            Image {
                id: panoIcon
                anchors {
                    verticalCenter: parent.verticalCenter
                    left: parent.left
                    leftMargin: 3.56
                }
                width: 8.89
                height: 8.89
                source:"qrc:/icons/highlight/device_highlight_empty_pano.svg"
                sourceSize: Qt.size(width, height)
                fillMode: Image.PreserveAspectFit
            }

            Text {
                id: panoLabel
                anchors {
                    verticalCenter: parent.verticalCenter
                    left: panoIcon.right
                    leftMargin: 1.78
                }
                
                text: qsTr("pccut_media_panoramic_video")
                font.pixelSize: 5
                font.weight: Font.Medium
                color: Colors.color_EEEEEE
            }
        }
    }

    Item {
        anchors {
            left: parent.left
            right: parent.right
            top: backgroundImageContent.bottom
            topMargin: 48
        }

        height: 148
        // 标题
        Text {
            id: titleLabel
            anchors {
                top: parent.top
                horizontalCenter: parent.horizontalCenter
            }
            text: root.titleText
            font.pixelSize: 20
            font.weight: Font.Medium
            height: 24
            color: Colors.color_EEEEEE
        }

        // 副标题（支持多行）
        Text {
            id: descriptionLabel
            anchors {
                top: titleLabel.bottom
                topMargin: 12
                left: parent.left
                right: parent.right
            }
            height: 44
            text: root.descriptionText
            font.pixelSize: 14
            font.weight: Font.Medium
            color: Colors.color_999999
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }

        // 按钮
        IconTextButton {
            id: actionButton
            anchors {
                top: descriptionLabel.bottom
                topMargin: 24
                horizontalCenter: parent.horizontalCenter
            }
           
            height: 44
            leftPadding: (140 - textImplicitWidth) / 2
            rightPadding: (140 - textImplicitWidth) / 2
            // 文字配置
            title: root.buttonText  // 高光
            titleFontSize: 16
            titleFontWeight: Font.Medium
            titleColorNormal: Colors.color_FFFFFF  // 白色文字
            isTextOnly: true

            // 背景配置：渐变色
            // 使用自定义背景实现渐变效果
            backgroundColorNormal: "transparent"  // 设为透明，使用下面的自定义背景
            backgroundColorHover: "transparent"
            radius: 6  // 圆角 6px

            // 布局配置（关键 - 居中）
            alignment: Qt.AlignHCenter  // 图标+文字整体在按钮内居中
            horPadding: 0  // 去除默认的水平内边距

            // 自定义 SVG 背景
            background: Rectangle {
                radius: 6
                color: "transparent"
                antialiasing: true

                // SVG 背景图片
                Image {
                    anchors.fill: parent
                    source: actionButton.hovered ? "qrc:/icons/highlight/ic_hl_bg_highlight.svg" : "qrc:/icons/highlight/ic_hl_bg.svg"
                    sourceSize: Qt.size(parent.width, parent.height)
                }
            }

            onCustomClicked: {
                root.backOriginalPage()
            }
        }
    }
}
