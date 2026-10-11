/**
* @author: mathy.shi
* @details:  素材裁切窗口
* @date: 2025-07-03
*/

import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Window 2.15
import Config 1.0
import ThumbnailListModel 1.0
import Controls 1.0
import Qt5Compat.GraphicalEffects
import ShortcutAction 1.0
import QTractorType 1.0
import Nova 1.0

Window {
    id: root
    // 被替换素材的路径
    property string mediaPath: ""

    property int clipIndx: -1
    property int trackIndx: -1
    // 每帧的宽度
    property real pxPerFrame: 0
    // 速度
    property double speed: 0
    // 素材长度
    property real mediaLength: 0

    // 轨道上片段的长度(1倍速)
    property real totalFrames: frameCropViewModel.totalFrame
    property real startFrame: frameCropViewModel.startFrame

    // 新素材是否是图片
    property bool newMediaIsImage: false
    // 新素材是否是全景
    property bool mediaIsPanoramaImage: false

    property bool signalsConnected: false
    property bool isRightClick: false
    property bool isSameLength: false

    flags: Qt.Window | Qt.FramelessWindowHint
    modality: Qt.WindowModal

    minimumWidth: 600
    maximumWidth: 600
    minimumHeight: 543
    maximumHeight: 543


    color: Colors.color_transparent
    visible: true;

    onVisibleChanged: {
        // 窗口关闭时，重置相关的数据
        if(!root.visible){
            clipPreviewPlayerManager.pause();
            frameCropViewModel.removeSourceModel();
            globalSignal.enablePlayerViewGesture(true)  // 启用全景手势

        }else{
            setDefualtCanvasType()

            frameCropViewModel.updateSourceModel();
            frameCropViewModel.initPlayer();
            var size = frameCropViewModel.getVideoSize();
            displayView.updateSizeWithFrameSize(size.width, size.height);
            globalSignal.enablePlayerViewGesture(false)  // 禁用全景手势
        }
    }

    function setDefualtCanvasType(){
        var aspect = editorManager.canvasType;
        switch (aspect) {
            case 1:
                control.currentIndex = 2;
                break;
            case 2:
                control.currentIndex = 4;
                break;
            case 3:
                control.currentIndex = 3;
                break;
            case 4:
                control.currentIndex = 1;
                break;
            case 5:
            case 8: // CANVASRATIOTYPE_16_9_SETTING，与16:9同索引
                control.currentIndex = 0;
                break;
            default:
                break;
        }
    }

    FrameCropViewModel{
        id: frameCropViewModel
        seekPos: Number(-1)
        aspect: getCurAspect()
        translate: Qt.point(frameCropRect.traslateX, frameCropRect.traslateY)
        scale: frameCropRect.scale

        function getCurAspect(){
            const aspectStr = control.currentText;
            switch(aspectStr) {
                case "1:1":
                    return Qt.point(1, 1);
                case "16:9":
                    return Qt.point(16, 9);
                case "9:16":
                    return Qt.point(9, 16);
                case "4:3":
                    return Qt.point(4, 3);
                case "3:4":
                    return Qt.point(3, 4);
                default:
                    return Qt.point(16, 9); // 默认值
            }
        }
    }

    Item {
        id: content
        focus: true;
        anchors.left: parent.left
        anchors.top: parent.top
        width: root.width
        height: 543
        // 处理键盘事件
        Keys.onPressed: {
            if (event.key === Qt.Key_Escape) {
                clipPreviewPlayerManager.pause();
                root.close();
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
        height: 41
        width: root.width
        anchors {
            left: parent.left
            top: parent.top
        }
        color: Colors.color_transparent

        ImageButton {
            id: btn_close
            anchors{
                left: parent.left
                leftMargin: 16
                verticalCenter: parent.verticalCenter
            }

            hoverEnabled: true
            enabled: lightWindow.active
            normalImage: "qrc:/icons/appbar/btn_close_normal.svg"
            hoveredImage: "qrc:/icons/appbar/btn_close_hovered.svg"
            pushedImage: "qrc:/icons/appbar/btn_close_pushed.svg"
            disabledImage: "qrc:/icons/appbar/btn_appbar_disable.svg"
            onClicked: {
                root.close();
            }
        }


        Text {
            height: 20
            color: Colors.color_CCCCCC
            font.pixelSize: 12
            anchors.centerIn: parent
            text: qsTr("pccut_frame_cropping_title")
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

        FrameCropRect{
            id: frameCropRect
            anchors.fill: parent
            z:1
            visible: root.visible
            rectAspectRatio: control.currentText

            orignalVideoIsCropped: frameCropViewModel.hasCropped
            initAspect: frameCropViewModel.initAspect
            initScale: frameCropViewModel.initScale
            initTranselateX: frameCropViewModel.initTranselateX
            initTranselateY: frameCropViewModel.initTranselateY

            defultWidth: displayView.width  // 画面在播放器中的宽度
            defultHeight: displayView.height // 画面在播放器中的高度
            defultStartX: displayView.x // 画面左上角的x位置
            defultStartY: displayView.y // 画面左上角的y位置
            isAction6Pro4K: frameCropViewModel.isAction6Pro4k1()
            blackRatio: frameCropViewModel.getAcBlackRatio()

            property real scale: originalCropWidth / cropRect.width
            property real traslateX: -((cropRect.x + cropRect.width / 2) - (frameCropRect.x +  frameCropRect.width / 2)) / originalCropWidth * scale // X方向平移距离， 归一化处理
            property real traslateY: -((cropRect.y + cropRect.height / 2) - (frameCropRect.height / 2 + frameCropRect.y)) / originalCropHeight * scale // Y方向平移距离归一化处理

            property int snapFixPosLeft : defultWidth * frameCropViewModel.getAcBlackRatio()
            property int snapFixPosRight : defultWidth * (1 - frameCropViewModel.getAcBlackRatio())
            property int snapFixPosTop : defultWidth * frameCropViewModel.getAcBlackRatio()
            property int snapFixPosBottom : defultWidth * (1 - frameCropViewModel.getAcBlackRatio())

            onVisibleChanged: {
                isAction6Pro4K = frameCropViewModel.isAction6Pro4k1();
                blackRatio = frameCropViewModel.getAcBlackRatio();
                orignalVideoIsCropped = frameCropViewModel.hasCropped;
                frameCropRect.updateCropRect()
            }
        }

        width: root.width
        height: 350
        color: "black"

        // 裁切预览播放器
        Item {
            id: player
            property real startFrame: 1
            height: player_container.height - 24
            width: player_container.width
            anchors{
                top: player_container.top
                topMargin: 12
                bottom: player_container.bottom
                bottomMargin: 12
            }

            ClipPreviewDisplayView {
                id: displayView
                anchors.centerIn: parent
            }

            Component.onCompleted: {
                clipPreviewPlayerManager.attachView(displayView); // 绑定底层需要展示的view，必须在播放器所有相关的操作之前
                frameCropViewModel.initPlayer();
                var size = frameCropViewModel.getVideoSize();
                displayView.updateSizeWithFrameSize(size.width, size.height);
            }
        }
    }

    Item{
        id: playerShow
        height: 72
        width: parent.width
        anchors {
            left: parent.left
            top: player_container.bottom
        }
        Rectangle{
            id: rectangle
            color: "black"
            anchors.fill: parent
        }

        // 播放器进度条
        PlayerSlider {
            id: seekControl
            enabled: frameCropViewModel.totalFrame > 0

            anchors{
                left: playerShow.left
                leftMargin: 87
                top: playerShow.top
                topMargin: 32
            }

            value: root.startFrame
            // enabled: true
            y: 8
            height: 10
            width: 267
            from: 0
            to: frameCropViewModel.totalFrame
            onValueChanged: {
                if (pressed) {
                    frameCropViewModel.seekPos = value;
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
                left: seekControl.right
                leftMargin: 20
                top: seekControl.top
                topMargin: 0
            }
            function getProgress() {
                const fps = clipPreviewPlayerManager.fps();
                if (clipPreviewPlayerManager.playedFrame < 0 || clipPreviewPlayerManager.totalFrames <= 0 || fps <= 0) {
                    return "";
                }
                var curframe = Math.max(clipPreviewPlayerManager.playedFrame - player.startFrame + 1, 0)

                const playedProgress = DurationFormatter.format(curframe, fps);
                return `${playedProgress}`;
            }
        }

        Text {
            id: totalLength
            property string lengthText: "/ " + getTotalLength()
            text: lengthText
            width: 46
            height: 15
            color: "#666666"
            font.pixelSize: 11
            anchors {
                left: playTime.right
                leftMargin: 20
                top: seekControl.top
                topMargin: 0
            }

            function getTotalLength(){
                const fps = clipPreviewPlayerManager.fps();
                const totalLength = DurationFormatter.format(clipPreviewPlayerManager.totalFrames, fps);
                return `${totalLength}`;
            }
        }
    }

    Item{
        id: aspectRatioSelect
        height: 28
        width: root.width
        anchors {
            left: parent.left
            leftMargin: 0
            top: playerShow.bottom
            topMargin: 24
        }

        Text{
            id: title
            anchors {
                left: parent.left
                leftMargin: 27
                verticalCenter: parent.verticalCenter
            }
            text: qsTr("pccut_frame_cropping_ratio")
            font.pixelSize: 12
            color: "#EEEEEE"
        }

        ComboBox {
            id: control
            enabled: true
            anchors {
                top: parent.top
                left: title.right
                leftMargin: 12
                verticalCenter: parent.verticalCenter
            }
            width: 108
            height: 28
            background: Rectangle {
                implicitWidth: control.width
                implicitHeight: control.height
                radius: 4
                color: mouseArea.entered ? "#68696D" : "#454649"

                // 添加 MouseArea 来检测悬停
                MouseArea {
                    id: mouseArea
                    property bool entered: false
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: {
                        mouseArea.entered = true;
                    }

                    onExited:{
                        mouseArea.entered = false;
                    }
                }
            }

            contentItem: Text {
                anchors.left: parent.left
                leftPadding: 8
                text: control.model.get(control.currentIndex).text
                font.pixelSize: 12
                color: Colors.color_EEEEEE
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }

            model:ListModel {
                ListElement { text: "16:9" }
                ListElement { text: "9:16" }
                ListElement { text: "1:1" }
                ListElement { text: "4:3" }
                ListElement { text: "3:4" }
            }

            popup: Popup {
                id:selectListPopup
                y: control.height + 4
                x: parent.width / 2 - selectListPopup.width / 2
                width: 108
                height: 164
                padding: 1

                background: Rectangle {
                        color: "#454649"
                        radius: 4
                    }
                contentItem: Rectangle {
                            implicitWidth: selectListPopup.width
                            implicitHeight: selectListPopup.height
                            color: Colors.color_transparent

                            radius: 4
                            border.color: Colors.color_transparent

                            // 渲染下拉菜单内容
                            ListView {
                                clip: true
                                model: control.model
                                currentIndex: control.currentIndex
                                height: 164
                                implicitWidth: parent.width
                                anchors.top: parent.top
                                anchors.topMargin: 4
                                spacing: 3.5

                                delegate: Item {
                                    width: parent.width - 8
                                    height: 28
                                    anchors{
                                        left: parent.left
                                        leftMargin: 4
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        color: index === control.currentIndex
                                                   ? "#68696D"
                                                   : (itemMouseArea.entered ? "#68696D" : Colors.color_transparent)
                                        radius: 4
                                    }

                                    Rectangle{
                                        id: selectedFlag
                                        width: 20
                                        height: 20
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors{
                                            left: parent.left
                                            leftMargin: 6
                                        }

                                        Image {
                                            id: icon
                                            visible: control.currentIndex == index ? true : false
                                            anchors.fill: parent
                                            source: "qrc:/icons/adjustment/icon_compose_check.svg"
                                            sourceSize: Qt.size(parent.width, parent.height)
                                        }
                                        color: Colors.color_transparent
                                    }

                                    Text {
                                        text: model.text
                                        anchors{
                                            left: parent.left
                                            leftMargin: 36
                                        }

                                        anchors.centerIn: parent
                                        verticalAlignment: Text.AlignVCenter
                                        color: "white"
                                        font.pixelSize: 11
                                        elide: Text.ElideRight
                                    }

                                    MouseArea {
                                        id: itemMouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        property bool entered: false
                                        onClicked: {
                                            control.currentIndex = index
                                            selectListPopup.close()
                                        }

                                        onEntered: {
                                            itemMouseArea.entered = true;
                                        }

                                        onExited: {
                                            itemMouseArea.entered = false;
                                        }


                                    }
                                }
                            }
                        }
                    }


            indicator: Rectangle {
                id: indicator
                anchors{
                    right: parent.right
                    rightMargin: 8
                    verticalCenter: parent.verticalCenter
                }

                width: 20
                height: 20
                color: Colors.color_transparent
                property string iconPath : "qrc:/icons/ic_close_triangle.svg";

                Image {
                    anchors.fill: parent
                    source: indicator.iconPath
                    sourceSize: Qt.size(parent.width, parent.height)
                    opacity: control.enabled ? 1 : 0.2
                }

                Connections {
                    target: control
                    function onDownChanged(){
                        if(control.popup.visible){
                            indicator.iconPath = "qrc:/icons/ic_open_triangle.svg"
                        }else{
                            indicator.iconPath = "qrc:/icons/ic_close_triangle.svg"
                        }
                    }
                }
            }
        }

        BaseConfirmBtn {
            id: cancelBtn
            btnText:qsTr("pccut_replace_clip_cancel")
            width: 80
            height: 28
            type: 1
            anchors{
                left: aspectRatioSelect.left
                leftMargin: 404
                verticalCenter: parent.verticalCenter
            }
            onCustomClick:() => {
                clipPreviewPlayerManager.pause();
                root.close();
            }

        }

        BaseConfirmBtn {
            id: okBtn
            btnText:qsTr("pccut_draft_delete_popup_yes")
            width: 80
            height: 28
            type: 0
            anchors{
                left: cancelBtn.right
                leftMargin: 8
                verticalCenter: parent.verticalCenter
            }
            onCustomClick:() => {
                frameCropViewModel.setCropFilterModel();
                root.close();
            }
        }

    }

    Item {
        id: shadowContainer
        anchors.fill: parent
        z: -1
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
