import QtQuick 2.15
import Config 1.0
import Controls 1.0
import QtQuick.Controls
import ShortcutAction 1.0
import AudioPlayerView 1.0
import UsedFunctionManager 1.0
import app_qrc 1.0

/**
 * @author robert.guo
 * @desc 音乐播放器面板
 * @create_date 2024-05-09
 */
Item {
    id: audioPlayerPanelRoot
    // 音乐路径
    property string path: ""
    // 音乐封面路径
    property string albumPath: ""
    // 音乐歌曲名称
    property string songName: ""
    // 音乐资源 id(埋点用)
    property int audioId: 0
    // 帧率，默认30
    property real fps: 30

    // drame还没创建成功信号
    signal drameNoCreated
    // 是否在播放中
    property alias playing: player.playing
    /**
     * @desc 停止播放
     * @return
     */
    function stop() {
        player.stop();
    }
    // 页面不可见时需要暂停播放
    onVisibleChanged: {
        if (!visible) {
            // 切换tab的时候, 隐藏播放器
            visible = false;
            player.pause();
        }
    }
    function seek(position) {
        player.seek(position)
    }

    /**
     * @desc 播放
     * @return
     */
    function play() {
        player.play();
    }
    /**
     * @desc 暂停播放
     * @return
     */
    function pause() {
        player.pause();
    }
    //事件拦截防止穿透
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
    }

    Rectangle {
        anchors.fill: parent
        color: Colors.color_353738

        AudioPlayerView {

            // 在这里执行其他操作，使用 dramaSource
            id: player
            property real total_length: 0
            anchors.bottom: parent.bottom

            Component.onCompleted: {
                audioManager.dramaSourceRelease.connect(function () {
                    stop();
                });
                // dramaSource 创建成功的信号
                audioManager.dramaSourceInitSuccess.connect(function () {
                    player.start();
                    player.total_length = audioManager.getLength();
                });
                editorManager.onVideoPlayed.connect(function (pause) {
                    if (!pause) {
                        player.pause();
                    }
                });

                audioManager.onExitAuidoPanel.connect(function () {
                    player.pause();
                });

                /// 如果要想播放视频的话，这块需要给设置给宽高，否则视频图像不显示。
                // player.width = 200
                // player.height = 30
            }
        }

        LightClipRectangle {
            id: song_album
            width: 32
            height: 32
            radius: [6, 6, 6, 6]
            anchors {
                left: parent.left
                top: parent.top
                leftMargin: 8
                topMargin: 8
            }

            Image {
                id: album
                anchors.fill: parent
                source: albumPath
                Rectangle {
                    color: Colors.color_000000_50
                    anchors.fill: parent
                }
            }

            Image {
                id: play
                width: 16
                height: 16
                source: player.playing ? "qrc:/icons/player/ic_pause.svg" : "qrc:/icons/player/ic_play.svg"
                sourceSize: Qt.size(width, height)
                anchors {
                    centerIn: parent
                }
            }
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    player.playing ? player.pause() : player.play();
                }
            }
        }

        HoverableText {
            id: song_name
            text: songName
            cursorChanged: false
            wrapMode: Text.NoWrap
            color: Colors.color_FFFFFF
            font.pixelSize: 12
            anchors {
                left: song_album.right
                leftMargin: 8
                right: play_slider.right
                verticalCenter: song_album.verticalCenter
            }
        }

        Image {
            id: closePanel
            width: 20
            height: 20
            source: "qrc:/icons/ic_close_music.svg"
            sourceSize: Qt.size(width, height)
            anchors {
                top: parent.top
                topMargin: 8
                horizontalCenter: addMusic.horizontalCenter
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    logger.d("closePanael()");
                    player.stop();
                    audioPlayerPanelRoot.visible = false;
                }
            }
        }

        Text {
            id: audioDuration
            property real playedFrame: Math.floor((player.playedTimebase + 1) / 30000 * fps)
            property real totalFrames: player.total_length / 30000 * fps

            property string progress: getProgress()

            text: getProgress()
            color: Colors.color_FFFFFF_45
            font.pixelSize: 11

            anchors {
                top: song_album.bottom
                topMargin: 11
                left: song_album.left
            }

            function getProgress() {
                if (playedFrame < 0 || totalFrames <= 0 || fps <= 0) {
                    return "";
                }
                const playedProgress = DurationFormatter.format(playedFrame, fps, false, false);
                const totalProgress = DurationFormatter.format(totalFrames, fps, false, false);
                return `${playedProgress}/${totalProgress}`;
            }
        }

        Image {
            id: addMusic
            source: addMouseArea.containsMouse ? "qrc:/app_qrc/icons/filter_add.svg" : "qrc:/icons/filter_add_white.svg"
            sourceSize: Qt.size(20, 20)
            Accessible.role: Accessible.Button
            Accessible.description: "audioedit_player_addmusic"
            anchors {
                right: parent.right
                verticalCenter: audioDuration.verticalCenter
                rightMargin: 8
            }
            LightToolTip {
                visible: addMouseArea.containsMouse
                tip: qsTr("pccut_music_add")
            }
            MouseArea {
                id: addMouseArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    // 发送添加信号
                    allAudioModels.addAudioClick(path);
                    var projectId = draftManager.activeProjectEnvId();
                    UsedFunctionManager.addFunction(projectId,UsedFunctionManager.EditorFunctionType.MUSIC);
                    eventTracker.trackEvent("pccut_music_add", {"use_method": "add_icon", "music_code": audioPlayerPanelRoot.audioId})
                    // 关闭音乐播放器
                    player.stop();
                    audioPlayerPanelRoot.visible = false;
                }
            }
        }

        LightBaseSlider {
            id: play_slider
            property bool lastPlayingStatus: false
            visualColor: ColorsConfig.color_brand
            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: audioDuration.verticalCenter
                leftMargin: 80
                rightMargin: 36
            }
            from: 0
            to: 100
            value: player.playedTimebase / player.total_length * 100
            stepSize: 1
            snapMode: Slider.SnapAlways

            onPressedChanged: {
                if (play_slider.pressed) {
                    lastPlayingStatus = player.playing;
                    player.pause();
                } else if (lastPlayingStatus) {
                    player.play();
                }
            }

            onMoved: {
                player.seek(player.total_length * play_slider.value / 100);
            }
        }

        CShortcut {
            action: ShortcutAction.PAUSE
            priority: player.visible ? 3 : 0
            onActivated: {
                if(player.playing && player.visible) {
                    player.pause();
                } else if(player.visible){
                    player.play();
                }
            }
        }
    }
}
