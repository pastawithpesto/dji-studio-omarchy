import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls
import TrackHeadViewModel 1.0
import Config 1.0
import LightRectangle 1.0

Item {
    id: trackHead
    // 轨道高度变化的信号
    signal trackHeightChangedSignal
    // 数据
    property TrackHeadViewModel viewModel
    // 是否折叠
    property bool isCollapsed: false

    property alias volumeVisible: volumeImage.visible

    property color color
    // 控制黑边显示，默认不显示
    property bool showBorders: false
    LightRectangle {
        anchors.fill: parent
        color: trackHead.color
        // 圆角
        radius: [0, 0, 0, 0]
        // 上黑边
        Rectangle {
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            height: 1
            color: Colors.color_141414
            visible: trackHead.showBorders
        }
        // 下黑边
        Rectangle {
            anchors {
                bottom: parent.bottom
                left: parent.left
                right: parent.right
            }
            height: 1
            color: Colors.color_141414
            visible: trackHead.showBorders
        }
        // 轨道类型图标
        Rectangle {
            id: typeRectangle
            anchors {
                left: parent.left
                leftMargin: 12
                verticalCenter: parent.verticalCenter
            }
            width: 16
            height: 16
            color: Colors.color_transparent
            Image {
                anchors.centerIn: parent.Center
                source: CommonUtils.isNull(viewModel) ? "" : viewModel.trackTypeIcon
                sourceSize: Qt.size(16, 16)
            }
        }

        StackLayout {
            id: stackLayout
            anchors {
                left: typeRectangle.right
                leftMargin: 12
                top: parent.top
                right: parent.right
                bottom: parent.bottom
            }
            currentIndex: isCollapsed ? -1 : 0

            Item {
                RowLayout {
                    anchors.fill: parent
                    spacing: 13
                    // 音量
                    Rectangle {
                        width: 16
                        height: 16
                        color: Colors.color_transparent
                        Image {
                            id: volumeImage
                            anchors.centerIn: parent.Center
                            source: CommonUtils.isNull(viewModel) ? "" : viewModel.trackVolumeIcon
                            sourceSize: Qt.size(16, 16)
                        }
                        MouseArea {
                            anchors.fill: parent
                            onPressed: {
                                if (CommonUtils.isNull(viewModel)) {
                                    return;
                                }
                                var isOpenVolume = !viewModel.trackVolumeState;
                                let eventName
                                switch(viewModel.trackType) {
                                case TrackHeadViewModel.TRACKTYPE_VIDEO: {
                                    eventName = "pccut_video_volume_click"
                                    break
                                }
                                case TrackHeadViewModel.TRACKTYPE_AUDIO: {
                                    eventName = "pccut_audio_volume_click"
                                    break
                                }
                                case TrackHeadViewModel.TRACKTYPE_TEXT: {
                                    // 文本轨道不响应静音
                                    return;
                                }
                                }
                                eventTracker.trackEvent(eventName, {"is_turnon": isOpenVolume})

                                if (isOpenVolume) {
                                    toast.showToast(qsTr("pccut_track_mute_cancel"), "tracks");
                                } else {
                                    toast.showToast(qsTr("pccut_track_mute_open"), "tracks");
                                }
                                viewModel.updateTrackVolumeState(isOpenVolume);
                            }
                        }
                    }
                }
            }
        }
    }
}
