import QtQuick 2.15
import QtQuick.Window 2.15
import Config 1.0
import app_qrc 1.0

Item {

    property bool isSnapped: false // 时间指示器是否被吸附上
    property bool atTrackEnd: false // 时间指示器是否在最后一帧
    // 指示器头(针头)显示尺寸：单一来源，改大小只动这两个值(须匹配 SVG 原始 9:12 比例，否则拉伸)
    property int handleWidth: 9
    property int handleHeightSize: 12
    // 指示器头(可抓取的针头)的高度：供标记带判定"按下/悬停是否落在指示器头上"以让位(详见 MarkPointItem.isOnTimeIndicator)
    readonly property alias handleHeight: indicatorHandle.height
    width: handleWidth

    Image {
        id: indicatorHandle
        antialiasing: true
        smooth: true
        width: parent.width
        height: parent.handleHeightSize
        // 如果isSnapped的时候不判断时间指示器是否在最后一帧，那么向左拖动裁剪最后一个片段的时候，时间指示器会反反复复处于snap和!snap的状态，这个时候就会闪来闪去，这样的话还不如直接不处理
        source: enabled ? (isSnapped && !atTrackEnd ? "qrc:/icons/track_play_pos_indicator_snapping.svg" : "qrc:/icons/track_play_pos_indicator.svg") : "qrc:/icons/track_play_pos_indicator_disabled.svg"

        // 栅格化分辨率随显示尺寸×dpr(高dpi清晰、低dpi不浪费纹理)，比例恒等于显示框，避免写死值与 width/height 比例不符导致 SVG 被拉伸发虚；dpr 向上取整保证非整数缩放时不发虚
        sourceSize: {
            let scale = Math.ceil(Screen.devicePixelRatio);
            return Qt.size(width * scale, height * scale);
        }
    }

    Rectangle {
        // 因为有一个radius，这里如果不减一的话，看上去中间会有缝隙
        property real yOffset: indicatorHandle.height - 1

        anchors.horizontalCenter: parent.horizontalCenter
        y: yOffset
        width: 1
        radius: 1
        height: parent.height - yOffset
        // 如果isSnapped的时候不判断时间指示器是否在最后一帧，那么向左拖动裁剪最后一个片段的时候，时间指示器会反反复复处于snap和!snap的状态，这个时候就会闪来闪去，这样的话还不如直接不处理
        color: enabled ? (isSnapped && !atTrackEnd ? ColorsConfig.color_brand : Colors.color_EEEEEE) : Colors.color_track_indicator_disabled
    }
}
