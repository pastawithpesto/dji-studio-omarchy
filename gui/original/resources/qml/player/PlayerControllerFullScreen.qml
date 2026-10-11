/**
* @author: dendi.zheng
* @details:  全屏播放时的播放控件, 参考的yahui写的PlayerController
* @date: 2024-04-18 20:34:43
*/

import Config 1.0
import QtQuick 2.15
import QtQuick.Layouts 1.15
import Controls 1.0
import QtQuick.Controls
import MKPlayerController 1.0
import QPlayType 1.0

//全屏后悬浮在播放器上的按钮组合
Rectangle {
    required property MKPlayerController player
    property bool hovered: panelMouseArea.containsMouse || togglePlayArea.containsMouse || play_slider.isHovered || playTimeTextMouseArea.containsMouse || escapeFullScreenArea.containsMouse

    //退出全屏按钮点击
    signal escapeFullscreenClicked()
    
    MouseArea {
        id: panelMouseArea
        anchors.fill: parent
        hoverEnabled: true
        preventStealing: true
    }
    
    RowLayout {
        anchors.fill: parent
        spacing: 12
        //播放暂停
        Item {
            Layout.preferredWidth: 20
            Layout.preferredHeight: 20
            Layout.alignment: Qt.AlignVCenter
            Layout.leftMargin: 24
            Image {
                id: play
                anchors.fill: parent
                source: {
                    if (player.playing) {
                        if (togglePlayArea.containsMouse) {
                            return "qrc:/icons/player/ic_pause_hover.svg"
                        } else {
                            return "qrc:/icons/player/ic_pause.svg"
                        }
                    } else {
                        if (togglePlayArea.containsMouse) {
                            return "qrc:/icons/player/ic_play_hover.svg"
                        } else {
                            return "qrc:/icons/player/ic_play.svg"
                        }
                    }
                }
                sourceSize: Qt.size(24, 24)

                MouseArea {
                    id: togglePlayArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    preventStealing: true
                    onClicked: {
                        player.togglePlayState();
                    }
                }
            }
        }

        LightBaseSlider {
            id: play_slider
            property double valueOnPressDown: 0.0
            property var lastPlayingStatus

            height: 10
            Layout.preferredWidth: 321
            Layout.preferredHeight: 13

            handleWidth: 4
            handleHeight: 10
            handleRadius:4
            visualColor: Colors.color_EEEEEE
            unVisualColor: Colors.color_button_background_hovered

            from: 0
            to: player.totalFrames
            onValueChanged: {
                if (pressed) {
                    player.seekFrame(value);
                }
            }
            onPressedChanged: {
                if (play_slider.pressed) {
                    lastPlayingStatus = player.playing
                    player.pause();
                } else if (lastPlayingStatus) {
                    player.togglePlayState();
                }
            }
            Connections {
                target: player
                function onPlayedFrameChanged(role) {
                    // 裁切中更新这个UI跳动很频繁看着比较乱
                    // 轨道hover预览不更新
                    // 拖动中不回写：连续 seek 期间引擎异步回灌陈旧位置，会把 handle 从手指下拽走(反向拖动尤其明显)
                    if (play_slider.pressed) {
                        return;
                    }

                    if (!tracks.flickable.isFragmentClipping && !(role == 2 && editorManager.playType === QPlayType.editor)) {
                        play_slider.value = player.playedFrame;
                    }
                }
            }
        }

        Item {
            Layout.preferredWidth: 147
            Layout.preferredHeight: 16
            Layout.alignment: Qt.AlignVCenter
            Text {
                anchors {
                    verticalCenter: parent.verticalCenter
                    left: parent.left
                }
                color: Colors.color_EEEEEE
                text: DurationFormatter.format(player.playedFrame, player.fps())
                font {
                    pixelSize: 12
                    weight: Font.Medium
                }
            }

            Text {
                anchors {
                    verticalCenter: parent.verticalCenter
                    horizontalCenter: parent.horizontalCenter
                }
                color: Colors.color_666666
                text: "/"
                font {
                    pixelSize: 12
                    weight: Font.Medium
                }
            }

            Text {
                anchors {
                    verticalCenter: parent.verticalCenter
                    right: parent.right
                }
                color: Colors.color_666666
                text: DurationFormatter.format(player.totalFrames, player.fps())
                font {
                    pixelSize: 12
                    weight: Font.Medium
                }
            }
            
            MouseArea {
                id: playTimeTextMouseArea
                anchors.fill: parent
                preventStealing: true
                hoverEnabled: true
            }
        }

        Item {
            Layout.preferredWidth: 20
            Layout.preferredHeight: 20
            Layout.alignment: Qt.AlignVCenter
            Layout.leftMargin: 8
            Layout.rightMargin: 24

            MouseArea {
                id: escapeFullScreenArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                preventStealing: true
                onClicked: {
                    escapeFullscreenClicked();
                }
            }

            //退出全屏按钮
            Image {
                id: escapeFullScreen
                anchors.centerIn: parent
                source: escapeFullScreenArea.containsMouse ? "qrc:/icons/player/ic_escape_fullscreen_hover.svg" : "qrc:/icons/player/ic_escape_fullscreen.svg"
                sourceSize: Qt.size(24, 24)
            }
        }
    }
}
