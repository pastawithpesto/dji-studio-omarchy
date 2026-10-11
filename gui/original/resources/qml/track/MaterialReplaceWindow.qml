/**
* @author: mathy.shi
* @details:  素材替换时裁切素材的窗口
* @date: 2024-12-31 10:58:23
*/

import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Window 2.15
import Config 1.0
import ThumbnailListModel 1.0
import Controls 1.0
import Qt5Compat.GraphicalEffects
import ShortcutAction 1.0
import "../player"
import app_qrc 1.0

Window {
    id: replaceWindow
    // 被替换素材的路径
    property string mediaPath: ""
    // 每帧的宽度
    property real pxPerFrame: 0
    // 速度
    property double speed: 0
    // 素材长度
    property real mediaLength: 0

    // 素材替换时首帧位置(主要针对粗剪之后替换的场景)
    property real startFrameIn: 0
    // 轨道上片段的长度(1倍速)
    property real fragmentLength: 0

    // 新素材是否是图片
    property bool newMediaIsImage: false
    // 新素材是否是全景
    property bool mediaIsPanoramaImage: false
    // 是否是图片替换全景视频
    property bool isImageToPanorama: false
    property bool isVideoToPanorama: false

    property bool signalsConnected: false
    property bool isRightClick: false
    property bool isSameLength: false

    signal replaceMedia(bool isReuse, real frameIn);
    flags: Qt.FramelessWindowHint
    modality: Qt.WindowModal
    
    minimumWidth: 360  // 固定最小宽度
    maximumWidth: 360  // 固定最大宽度
    minimumHeight: (isImageToPanorama || isVideoToPanorama) ? 471 : 444  // 固定最小高度
    maximumHeight: (isImageToPanorama || isVideoToPanorama) ? 471 : 444  // 固定最大高度
    color: Colors.color_transparent
    visible: true;

    onScreenChanged: {
        clipPreviewPlayerManager.checkScreenIsApple()

    }

    onVisibleChanged: {
        // 窗口关闭时，重置相关的数据
        if(!replaceWindow.visible){
            startFrameIn = 0;
            trackFrame.x = (thumbnailView.width - 240) / 2;
            checkBox.checked = true;
            clipPreviewPlayerManager.pause();
            clipPreviewPlayerManager.seek(0);
        }
    }

    // 每次打开赋值新尺寸，按新素材画幅比例适配显示区域
    function updateDisplayViewSize() {
        const size = clipPreviewPlayerManager.canvasRatioSize();
        if (size.width > 0 && size.height > 0) {
            player.displayView.updateSizeWithFrameSize(size.width, size.height);
        }
    }

    Item {
        id: name
        focus: true;
        anchors.left: parent.left
        anchors.top: parent.top
        width: 360
        height:(isImageToPanorama || isVideoToPanorama) ? 471 : 444
        // 处理键盘事件
        Keys.onPressed: {
            if (event.key === Qt.Key_Escape) {
                clipPreviewPlayerManager.pause();
                replaceWindow.close();
            } else if (event.key === Qt.Key_Space) {
                if(clipPreviewPlayerManager.playing){
                    clipPreviewPlayerManager.pause();
                }else{
                    if(previewAxis.x >= 240){
                        clipPreviewPlayerManager.seek((trackFrame.clipAreaLeft - trackFrame.x) / trackFrame.pxPerFrame);
                    }

                    clipPreviewPlayerManager.play();
                }
            }else if(event.key === Qt.Key_Left){
                clipPreviewPlayerManager.seek(clipPreviewPlayerManager.playedFrame - 1);
            }else if(event.key === Qt.Key_Right){
                clipPreviewPlayerManager.seek(clipPreviewPlayerManager.playedFrame + 1);
            }

            event.accepted = true
        }

    Rectangle{
        id: titile
        height: 40
        width: 360
        anchors {
            left: parent.left
            top: parent.top
        }
        color: Colors.color_transparent
        Text {
            height: 20
            color: Colors.color_CCCCCC
            font.pixelSize: 12
            anchors.centerIn: parent
            text: qsTr("pccut_replace_clip")
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }

    Rectangle {
        id: player_container
        anchors {
            left: parent.left
            top: titile.bottom
        }

        width: 360
        height: 201
        color: Colors.color_transparent

        // 全景播放器
        PanoramaPlayerView {
            id: player
            property real startFrame: (canvas.clipAreaLeftPos - trackFrame.x) / (240 / (replaceWindow.fragmentLength / 1000))
            anchors.fill: parent
            enabled: true
            // 视角手势交给 clipPreviewPlayerManager(预览片段在 detached env)，外抛 move/zoom/rotate 信号。
            playerHandleGesture: false
            // 手势门控改判 detached env 的预览素材(默认绑 controller 查主时间线，与预览画面不同源)；
            // 全景铺满画布，命中测试恒真。赋值只作用于本窗口实例。
            Connections {
                target: clipPreviewPlayerManager
                function onPreviewIsPanoramaChanged() {
                    player.playerViewGesture.isPanorama = clipPreviewPlayerManager.previewIsPanorama
                }
            }
            Component.onCompleted: {
                clipPreviewPlayerManager.attachView(this.displayView); // 这里必须得有， 绑定底层需要展示的view
                player.playerViewGesture.isPanorama = clipPreviewPlayerManager.previewIsPanorama
                player.playerViewGesture.hitTestPanorama = (nx, ny) => true
            }

            // 手势起止驱动 clipPreviewPlayerManager 视角编辑。
            Connections {
                target: player
                function onGesturingChanged() {
                    if (player.playerHandleGesture) {
                        return;
                    }
                    if (player.gesturing) {
                        clipPreviewPlayerManager.previewGestureStart();
                    } else {
                        clipPreviewPlayerManager.previewGestureEnd();
                    }
                }

                function onMove(deltaX, deltaY, fling) {
                    const normalizedDX = deltaX / player.width / 2;
                    const normalizedDY = deltaY / player.height / 2;
                    const params = clipPreviewPlayerManager.params;
                    // 图片宽高取不到，回落引擎画布尺寸
                    const profileSize = clipPreviewPlayerManager.gestureProfileSize();
                    const hDegree = params.hDegree + (profileSize.width * 2 * normalizedDX / 5);
                    const vDegree = params.vDegree + (profileSize.height * 2 * normalizedDY / 5);
                    clipPreviewPlayerManager.updatePreviewViewDegree(hDegree, vDegree);
                }

                function onZoom(deltaPercentage) {
                    const fovRange = QPanoramaLimit.FOV_MAX - QPanoramaLimit.FOV_MIN;
                    const distortionRange = QPanoramaLimit.DISTORTION_MAX - QPanoramaLimit.DISTORTION_MIN;
                    if (fovRange <= 0 || distortionRange <= 0) {
                        return;
                    }
                    const deltaFov = fovRange * deltaPercentage;
                    const params = clipPreviewPlayerManager.params;
                    const fov = params.fov + deltaFov;
                    const deltaDistortion = distortionRange * deltaPercentage;
                    const distortion = params.distortion + deltaDistortion;
                    clipPreviewPlayerManager.updatePreviewFov(fov, distortion);
                }

                function onRotate(rotation) {
                    const params = clipPreviewPlayerManager.params;
                    const rotationZ = params.rotationZ + rotation;
                    clipPreviewPlayerManager.updatePreviewRotationZ(rotationZ);
                }
            }
        }
    }
    Item{
        id: playerShow
        height: 115
        width: 360
        anchors {
            left: parent.left
            top: player_container.bottom
        }

        Rectangle{
            id: playerControl
            height: 44
            width: 360
            color: Colors.color_transparent
            anchors {
                left: parent.left
                top: parent.top
            }

            Image {
                id: playIcon
                anchors.centerIn: parent
                width: 20
                height: 20
                source: clipPreviewPlayerManager.playing ? "qrc:/icons/player/ic_pause.svg" : "qrc:/icons/player/ic_play.svg"
                sourceSize: Qt.size(20, 20)
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if(clipPreviewPlayerManager.playing){
                            clipPreviewPlayerManager.pause();
                        }else{
                            if(previewAxis.x >= 240){
                                clipPreviewPlayerManager.seek((trackFrame.clipAreaLeft - trackFrame.x) / trackFrame.pxPerFrame);
                            }
                            clipPreviewPlayerManager.playFromSeekPos();
                        }
                    }

                }
            }
        }

        // 缩略图展示
        Rectangle{
            id: thumbnailView
            property real visibleLeft: trackFrame.x < 0 ? -trackFrame.x : 0
            property real visibleRight: Math.min(trackFrame.width, thumbnailView.width) + visibleLeft
            property real visibleWidth: calVisibleWidth()

            function calVisibleWidth(){
                var width = 0;
                if(trackFrame.x > 0){
                    if((trackFrame.x + trackFrame.width) > thumbnailView.width){
                        width = thumbnailView.width - trackFrame.x;
                    }else{
                        width = trackFrame.width - visibleLeft;
                    }
                }else{
                    if((trackFrame.x + trackFrame.width) > thumbnailView.width){
                        width = thumbnailView.width - trackFrame.x;
                    }else{
                        width = trackFrame.width - visibleLeft;
                    }
                }
                return width
            }

            height: 48
            width: 360
            anchors {
                left: parent.left
                top: playerControl.bottom
            }
            color: Colors.color_transparent
            radius: 4

            Item {
                id: trackFrame
                // 缩略图轨道上1帧对应的像素数
                property int frame: replaceWindow.fragmentLength / 1000
                property real pxPerFrame: 240 / frame
                property real clipAreaLeft: (canvas.width - 240) / 2
                property real clipAreaRight: clipAreaLeft + 240
                // 裁剪之后片段的起点frameIn
                property real startFrameIn: ((parent.width - 240) / 2 - trackFrame.x) / pxPerFrame * 1000 + replaceWindow.startFrameIn;
                width: (newMediaIsImage || mediaIsPanoramaImage) ? 240 :  (replaceWindow.fragmentLength === 0 ? 0 :  Math.floor(replaceWindow.mediaLength / 1000) * 1000 / replaceWindow.fragmentLength * 240)  // todo: 需要使用新素材的长度计算对应的片段长度
                height: parent.height
                x: (parent.width - 240) / 2;
                y:0
                property real lastPosX: 0
                property real initialWidth: thumbnailView.width
                clip:true
                // 展示缩略图
                ListView{
                    id:  thumbnailList
                    width: parent.width
                    height: parent.height
                    interactive: false
                    cacheBuffer: 0
                    anchors{
                        top: parent.top
                        left: parent.left
                        leftMargin: Math.floor(thumbnailView.visibleLeft / 48) * 48
                    }
                    orientation: ListView.Horizontal
                    focus: true
                    model:ThumbnailListModel{
                        id: thumbnailListModel
                        videoPath: replaceWindow.mediaPath
                        frameSize: Qt.size(48, 48).width
                        compositeProperty: {
                            "displayIndexOffset": Math.floor((thumbnailView.visibleLeft + replaceWindow.startFrameIn / 1000 * trackFrame.pxPerFrame) / 48),
                            "pxPerFrame": 240 / (replaceWindow.fragmentLength / 1000),
                            "itemCount":  thumbnailView.visibleWidth > 0 ? Math.floor(thumbnailView.visibleWidth / 48) + 2 : Math.floor(thumbnailView.width / 48) + 2,
                            "speed": 1, // 这里固定为1倍速下的缩略图
                            "oneFrameTime": 1000,
                            "fragmentLength": replaceWindow.fragmentLength
                        }
                    }
                    delegate:Item{
                        width: 48
                        height: 48
                        MediaFrameImageLoader {
                            anchors.fill: parent
                            requestSource: model.path !== undefined ? model.path : ""
                            cacheSource: model.cache !== undefined ? model.cache : ""
                        }
                    }

                    Component.onCompleted: {
                        thumbnailListModel.listViewCompleted = true;
                    }
                }
            }

            Item {
                id: maskItem
                width: parent.width
                height: parent.height
                anchors.centerIn: parent
                z:4
                Rectangle{
                    anchors{
                        left:parent.left
                        leftMargin: Math.max(trackFrame.x, 0)
                        top: parent.top
                    }

                    width: (parent.width - 240) / 2 - Math.max(trackFrame.x, 0)
                    height: parent.height
                    color: Colors.color_141414
                    opacity: 0.5
                }

                Rectangle{
                    anchors{
                        left:parent.left
                        leftMargin: (parent.width - 240) / 2
                        top: parent.top
                    }

                    width: 240
                    height: parent.height
                    color: Colors.color_transparent
                    radius: 4
                    border.width: 2
                    border.color: Colors.color_FFFFFF
                }

                Rectangle{
                    anchors{
                        left:parent.left
                        leftMargin: parent.width - (parent.width - 240) / 2
                        top: parent.top
                    }

                    width: (parent.width - 240) / 2 - Math.max((thumbnailView.width - (trackFrame.x + trackFrame.width)), 0)
                    height: parent.height
                    color: Colors.color_141414
                    opacity: 0.5
                }
            }

            Canvas {
                    id: canvas
                    width: parent.width
                    height: parent.height
                    property int clipAreaLeftPos: (canvas.width - 240) / 2 // 裁切矩形左边界位置
                    anchors.centerIn: parent
                    z:1
                    // 定义拖拽区域
                    MouseArea {
                        id: mouseArea
                        property bool isDragging: false
                        anchors.fill: parent
                        drag.target: trackFrame

                        hoverEnabled: true
                        // 设置拖拽的边界
                        drag.axis: Drag.XAndYAxis
                        drag.minimumX: canvas.clipAreaLeftPos + 240 - trackFrame.width;
                        drag.maximumX: canvas.clipAreaLeftPos
                        drag.minimumY: 0
                        drag.maximumY: parent.height - trackFrame.height

                        onEntered: {
                            if(mouseX >= canvas.clipAreaLeftPos && mouseX <= (canvas.clipAreaLeftPos + 240)){
                                cursorShape = Qt.PointingHandCursor;
                            }else{
                                cursorShape = Qt.ArrowCursor;
                            }
                        }

                        onExited: {
                            cursorShape = Qt.ArrowCursor;
                        }

                        onPressed: {
                            if(mouseX >= canvas.clipAreaLeftPos && mouseX <= (canvas.clipAreaLeftPos + 240)){
                                cursorShape = Qt.ClosedHandCursor
                            }
                            previewAxis.visible = false;
                            isDragging = true
                        }

                        onReleased: {
                            if(mouseX >= canvas.clipAreaLeftPos && mouseX <= (canvas.clipAreaLeftPos + 240)){
                                cursorShape = Qt.PointingHandCursor;
                            }else{
                                cursorShape = Qt.ArrowCursor;
                            }
                            previewAxis.visible = true;
                            isDragging = false
                        }
                        onPositionChanged: {
                            // 在这里需要进行seek到头部的位置
                            if(isDragging){
                                var pxPerFrame = 240 / (replaceWindow.fragmentLength / 1000)
                                clipPreviewPlayerManager.seek((canvas.clipAreaLeftPos - trackFrame.x) / pxPerFrame);
                            }else{
                                if(mouseX >= canvas.clipAreaLeftPos && mouseX <= (canvas.clipAreaLeftPos + 240)){
                                    if(!clipPreviewPlayerManager.playing){
                                        var pxPerFrames = 240 / (replaceWindow.fragmentLength / 1000)
                                        clipPreviewPlayerManager.seek((mouseX - trackFrame.x) / pxPerFrames);
                                    }
                                }
                            }
                        }
                    }

                }

            Rectangle{
                id: previewAxis
                height: parent.height
                width: 1
                color: ColorsConfig.color_brand
                x: Math.min(trackFrame.clipAreaRight, Math.max(trackFrame.clipAreaLeft, trackFrame.clipAreaLeft  + (clipPreviewPlayerManager.playedFrame - player.startFrame)* trackFrame.pxPerFrame))
                z:2
                onXChanged: {
                    if(x >= trackFrame.clipAreaRight){
                        clipPreviewPlayerManager.pause();
                    }
                }
            }
        }

        // 播放时间
        Text {
            id: playTime
            property string progress: getProgress()
            text: progress
            width: 46
            height: 15
            color: Colors.color_EEEEEE
            font.pixelSize: 11
            anchors {
                left: replaceWindow.left
                top: thumbnailView.bottom
                topMargin: 8
            }
            x:150
            function getProgress() {
                const fps = clipPreviewPlayerManager.fps();
                if (clipPreviewPlayerManager.playedFrame < 0 || clipPreviewPlayerManager.totalFrames <= 0 || fps <= 0) {
                    return "";
                }
                var curframe = Math.max(clipPreviewPlayerManager.playedFrame - player.startFrame, 0)

                const playedProgress = DurationFormatter.format(curframe, fps);
                return `${playedProgress}`;
            }
        }
    }

    HoverableText {
        id: tips
        text:  isImageToPanorama ? qsTr("pccut_replace_clip_tips1") : qsTr("pccut_replace_clip_tips2")
        visible: isImageToPanorama || isVideoToPanorama

        font.pixelSize: 11
        font.weight: Font.Medium
        color: Colors.color_666666
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter


        width: 304
        anchors {
            horizontalCenter: parent.horizontalCenter
            top: playerShow.bottom
            bottom: line.top
        }
        cursorChanged: false
        toastVisible: truncated
    }
    BaseSpliter {
        id: line
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: selectItem.top
            bottomMargin: 20
        }
        width: 304
    }

    Item{
        id: selectItem
        height: 28
        width: 360

        anchors {
            left: parent.left
            bottom: parent.bottom
            bottomMargin: 24
        }

        CheckBox {
            id:checkBox
            text: qsTr("pccut_replace_reuse_effects")
            checked: true
            width: 120
            anchors {
                left: parent.left
                leftMargin: 28
                verticalCenter: parent.verticalCenter
            }
            height: 16

            indicator: Rectangle {
                id: indicator
                width: 14
                height: 14
                anchors.left: checkBox.left
                anchors.verticalCenter: parent.verticalCenter
                color:  checkBox.checked ? ColorsConfig.color_brand : Colors.color_444444
                radius: 4
                Image {
                    id: icon2
                    visible: checkBox.checked
                    anchors.fill: parent
                    source: "qrc:/app_qrc/icons/icon_checkbox_check.svg"
                    sourceSize: Qt.size(parent.width, parent.height)
                }
            }
            MouseArea {
                anchors.fill: checkBox
                onClicked: {
                    checkBox.checked = !checkBox.checked;
                }
            }
            contentItem: HoverableText {
                id: textItem
                text: checkBox.text
                font.pixelSize: 12
                color: Colors.color_EEEEEE
                verticalAlignment: Text.AlignVCenter  // 添加垂直居中对齐
                leftPadding: checkBox.indicator.width + 6
                cursorChanged: false
                wrapMode: Text.NoWrap
                anchors.fill: parent
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        BaseConfirmBtn {
            id: cancelBtn
            btnText:qsTr("pccut_replace_clip_cancel")
            width: 80
            height: 28
            type: 1
            anchors{
                left: selectItem.left
                leftMargin: 164
                verticalCenter: parent.verticalCenter
            }
            onCustomClick:() => {
                clipPreviewPlayerManager.pause();
                replaceWindow.close()
            }
        }

        BaseConfirmBtn {
            id: okBtn
            btnText:qsTr("pccut_replace_clip_yes")
            width: 80
            height: 28
            type: 0
            anchors{
                left: cancelBtn.right
                leftMargin: 8
                verticalCenter: parent.verticalCenter
            }
            onCustomClick:() => {
                clipPreviewPlayerManager.pause();
                replaceWindow.close();
                replaceMedia(checkBox.checked, trackFrame.startFrameIn);
            }
        }
    }

    Item {
        id: shadowContainer
        visible: CommonUtils.isWindows()
        anchors.fill: parent
        z: -1

        // 阴影层（仅用于绘制阴影）
        Rectangle {
            id: shadowSource
            anchors.fill: parent
            color: "transparent"
            radius: 8
            layer.enabled: true
            layer.effect: DropShadow {
                radius: 50
                color: Colors.color_80000000
                transparentBorder: true
            }
        }

        // 实际背景层（覆盖在阴影上）
        Rectangle {
            id: windowBackground
            anchors.fill: parent
            radius: 8
            color: Colors.color_2F3032
            // 仅在 Windows 平台设置边框
            border.width: CommonUtils.isWindows() ? 1 : 0
            border.color: Colors.color_454649
        }
    }
}
}
