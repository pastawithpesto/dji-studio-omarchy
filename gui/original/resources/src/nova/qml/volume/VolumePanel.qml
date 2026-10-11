import QtQuick 2.15
import QtQuick.Controls
import Config 1.0
import Controls 1.0
import Nova 1.0

/**
 *  @Brief : nova 音量调节面板（音量 + 淡入淡出）
 *  面板自持 VolumeViewModel，作用于当前单选的 clip。
 */
Rectangle {
    id: root

    anchors.fill: parent
    color: Colors.color_content_area_background

    // 面板自持 VM，生命周期=面板
    VolumeViewModel {
        id: vm
    }

    // 顶部分割线
    Rectangle {
        width: parent.width
        height: 1
        color: Colors.color_141414
    }

    Column {
        id: column
        spacing: 0
        anchors {
            left: parent.left
            leftMargin: 12
            top: parent.top
            topMargin: 16
            right: parent.right
            rightMargin: 12
        }

        // 区块标题
        Rectangle {
            width: parent.width
            height: 20
            color: Colors.color_transparent
            clip: true
            Text {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignLeft
                font.pixelSize: 12
                color: Colors.color_EEEEEE
                text: qsTr("pccut_panel_audio_basics")
            }
        }

        // 音量
        Rectangle {
            width: parent.width
            height: 40
            color: Colors.color_transparent
            clip: true

            Text {
                id: volumeLabel
                anchors {
                    left: parent.left
                    top: parent.top
                    bottom: parent.bottom
                }
                horizontalAlignment: Text.AlignLeft
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: 11
                color: Colors.color_999999
                text: qsTr("pccut_panel_audio_volume")

                MouseArea {
                    anchors.fill: parent
                    onDoubleClicked: vm.volume = 100
                }
            }

            Text {
                id: volumeText
                anchors {
                    top: parent.top
                    right: parent.right
                    bottom: parent.bottom
                }
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: 11
                color: Colors.color_CCCCCC
                width: 18
                text: Math.round(volumeSlider.value)
            }

            LightBaseSlider {
                id: volumeSlider
                anchors {
                    left: volumeLabel.right
                    leftMargin: 16
                    top: parent.top
                    right: volumeText.left
                    rightMargin: 20
                    bottom: parent.bottom
                }
                from: 0
                to: 100
                stepSize: 1
                snapMode: Slider.SnapAlways

                Component.onCompleted: value = vm.volume
                onMoved: vm.volume = Math.round(value)
                onPressedChanged: vm.editing = pressed

                Connections {
                    target: vm
                    // 拖动中不打断用户操作，仅在松手后回灌
                    function onVolumeChanged() {
                        if (!volumeSlider.pressed) {
                            volumeSlider.value = vm.volume;
                        }
                    }
                }
            }
        }

        // 第二路音量（仅视频 clip 带 attach 音轨时）
        Rectangle {
            width: parent.width
            height: 40
            visible: vm.hasAttachAudio
            color: Colors.color_transparent
            clip: true

            Text {
                id: attachVolumeLabel
                anchors {
                    left: parent.left
                    top: parent.top
                    bottom: parent.bottom
                }
                horizontalAlignment: Text.AlignLeft
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: 11
                color: Colors.color_999999
                text: qsTr("pccut_panel_audio_v2")

                MouseArea {
                    anchors.fill: parent
                    onDoubleClicked: vm.attachVolume = 100
                }
            }

            Text {
                id: attachVolumeText
                anchors {
                    top: parent.top
                    right: parent.right
                    bottom: parent.bottom
                }
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: 11
                color: Colors.color_CCCCCC
                width: 18
                text: Math.round(attachVolumeSlider.value)
            }

            LightBaseSlider {
                id: attachVolumeSlider
                anchors {
                    left: attachVolumeLabel.right
                    leftMargin: 16
                    top: parent.top
                    right: attachVolumeText.left
                    rightMargin: 20
                    bottom: parent.bottom
                }
                from: 0
                to: 100
                stepSize: 1
                snapMode: Slider.SnapAlways

                Component.onCompleted: value = vm.attachVolume
                onMoved: vm.attachVolume = Math.round(value)
                onPressedChanged: vm.editing = pressed

                Connections {
                    target: vm
                    function onAttachVolumeChanged() {
                        if (!attachVolumeSlider.pressed) {
                            attachVolumeSlider.value = vm.attachVolume;
                        }
                    }
                }
            }
        }

        // 淡入（仅音频 clip）
        Rectangle {
            width: parent.width
            height: 28
            visible: vm.isAudioClip
            color: Colors.color_transparent
            clip: true
            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignLeft
                font.pixelSize: 11
                color: Colors.color_CCCCCC
                text: qsTr("pccut_panel_music_fadein")
            }
            LightBaseSwitch {
                id: fadeInSwitch
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter

                Component.onCompleted: checked = vm.fadeIn
                onToggledSignal: vm.fadeIn = checked

                Connections {
                    target: vm
                    function onFadeInChanged() {
                        fadeInSwitch.checked = vm.fadeIn;
                    }
                }
            }
        }

        // 淡出（仅音频 clip）
        Rectangle {
            width: parent.width
            height: 28
            visible: vm.isAudioClip
            color: Colors.color_transparent
            clip: true
            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignLeft
                font.pixelSize: 11
                color: Colors.color_CCCCCC
                text: qsTr("pccut_panel_music_fadeout")
            }
            LightBaseSwitch {
                id: fadeOutSwitch
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter

                Component.onCompleted: checked = vm.fadeOut
                onToggledSignal: vm.fadeOut = checked

                Connections {
                    target: vm
                    function onFadeOutChanged() {
                        fadeOutSwitch.checked = vm.fadeOut;
                    }
                }
            }
        }
    }
}
