import Config 1.0
import Controls 1.0
import Qt5Compat.GraphicalEffects
import QtQuick 2.15

Rectangle {
    id: typeTip

    // 辅助属性，用于确定要显示的图片路径
    property string imageSource

    readonly property var iconKeywordMap: [
        { keyword: "quick_video_rocket", textKey: "pccut_panel_rocket" },
        { keyword: "quick_video_dronie", textKey: "pccut_panel_dronie" },
        { keyword: "quick_video_orbit", textKey: "pccut_panel_orbit" },
        { keyword: "quick_video_circle", textKey: "pccut_panel_circle" },
        { keyword: "quick_video_helix", textKey: "pccut_panel_helix" },
        { keyword: "quick_video_comet", textKey: "pccut_panel_comet" }
    ]

    // 辅助属性，用于确定要显示的文字
    property string textSource: {
        // 优先检查图标关键字（一键短片类型）
        for (var i = 0; i < iconKeywordMap.length; i++) {
            if (imageSource.indexOf(iconKeywordMap[i].keyword) !== -1) {
                return qsTr(iconKeywordMap[i].textKey);
            }
        }
        if (isSlowMotionVideo) {
            return qsTr("pccut_superslow_motion_title");
        } else if (isLoopVideo) {
            return qsTr("pccut_material_loop_recording");
        } else if (isSelfieModeVideo) {
            return qsTr("pccut_media_selfie_mode");
        } else if (isBullefTimeVideo) {
            return qsTr("pccut_material_bullet_time");
        } else if (isHyperlapseVideo) {
            return qsTr("pccut_material_hyperlapse");
        } else if (isTimelapseVideo) {
            return qsTr("pccut_material_fixed_angle");
        } else if (isPanoFlatVideo) {
            return qsTr("pccut_framing_auto_track_title");
        } else if (isPanoVideo) {
            return qsTr("pccut_media_panoramic_video");
        } else if (isPanoImage) {
            return qsTr("pccut_media_panoramic_image");
        } else if (isVideo) {
            return qsTr("pccut_material_video");
        } else if (isImage) {
            return qsTr("pccut_material_photo");
        }
        return "";
    }

    property var sourceView
    property bool isVideo
    property bool isImage
    property bool isPanoImage
    property bool isPanoVideo
    property bool isLoopVideo
    property bool isHyperlapseVideo
    property bool isTimelapseVideo
    property bool isSelfieModeVideo
    property bool isBullefTimeVideo
    property bool isSlowMotionVideo
    property bool isPanoFlatVideo
    property int fontWeight: Font.Medium
    property string videoPath: ""

    // 是否有类型图标：边下边播（云相册）路径下文件非本地，getIconType 返回空 →
    // 无图标。此时图标不占位、文字左移，避免宽度公式塌陷导致文字溢出圆角背景。
    readonly property bool hasIcon: imageSource.length > 0

    //自适应宽度。有图标：8(左边距)+20(图标)+4(间距)+文字+8(右边距)=文字+40（与原逻辑一致）；
    //无图标：8+文字+8=文字+16。
    width: 8 + (hasIcon ? 24 : 0) + tipImgText.implicitWidth + 8
    height: 32
    radius: 6
    color: Colors.transparent

    // 高斯模糊，控件按x、y、width、height和播放控件对齐， 因为在全屏过程中发生了位移，不能用相对布局
    // 默认非全屏， 隐藏
    LightClipRectangle {
        id: blurArea

        property var target: typeTip

        anchors.left: target.left
        anchors.right: target.right
        anchors.top: target.top
        anchors.bottom: target.bottom
        width: target.width
        height: target.height
        radius: [target.radius, target.radius, target.radius, target.radius]

        // 高斯模糊的画面数据源设置
        ShaderEffectSource {
            id: effectsource

            // 模糊的画面数据来自player
            sourceItem: sourceView
            sourceRect: Qt.rect(blurArea.target.x - sourceView.x, blurArea.target.y - sourceView.y, blurArea.target.width, blurArea.target.height)
            live: true
            smooth: true
        }

        //高斯模糊配置入口
        FastBlur {
            anchors.fill: parent
            source: effectsource
            // 模糊采样半径，越高越模糊
            radius: 64
        }
        
        Rectangle {
            anchors.fill: parent
            radius: 6
            color: Colors.color_000000_30
        }
    }

    Image {
        id: tipImg
        width: 20
        height: 20
        visible: hasIcon
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: 8
        anchors.topMargin: 6
        source: imageSource
        sourceSize: Qt.size(20, 20)
    }

    Text {
        id: tipImgText
        text: textSource
        font.pixelSize: 12
        font.weight: fontWeight
        color: Colors.color_EEEEEE
        // 有图标：跟在图标右侧 +4；无图标：直接距左边 8，保持水平居中于圆角背景。
        anchors.left: hasIcon ? tipImg.right : parent.left
        anchors.leftMargin: hasIcon ? 4 : 8
        anchors.verticalCenter: parent.verticalCenter
    }
}
