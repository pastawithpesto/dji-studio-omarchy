import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.3
import Qt5Compat.GraphicalEffects
import Config 1.0
import Controls 1.0
import app_qrc 1.0
import MaterialDragController 1.0
import EffectDragBusiness 1.0
import NetworkGifCache


Item {
    id: materialItem

    // 素材属性部分
    property string resourceSlug: ""
    property string resourceName: ""
    property string imageUrl: ""
    property string hoverImage: ""
    property string supportTypeName: ""
    property string locationTypeName: ""
    property var effectConfig: null
    property bool inCollectGridView:false
    property bool currentSelectGrid:false
    property bool onlyForPanorama : false
    property real playedPercentage: 0.0   // 特效预览播放进度（0.0 ~ 1.0）

    focus: true

    NetworkGifCache {
        id: imageCache
        onImageCached: function(url, localPath) {
            if (url === imageUrl) {
                coverStatic.source = "file:///" + localPath;
            }
            if (url === hoverImage) {
                coverAnimated.source = "file:///" + localPath;
            }
        }
    }

    Component.onCompleted: {
        if (imageUrl !== "") {
            imageCache.getCachedImage(imageUrl);
        }
        if (hoverImage !== "") {
            imageCache.getCachedImage(hoverImage);
        }
    }

    onImageUrlChanged: {
        imageCache.getCachedImage(imageUrl);
    }
    onHoverImageChanged: {
        imageCache.getCachedImage(hoverImage);
    }

    // 此处原来的index与外围自动注入的index一致，因此此处不必要再传入index
    signal downloadClicked()
    signal collectClicked(bool isCollect)
    signal addClicked()
    signal cardClicked()
    signal seekClicked(real percentage)

    // 单项的展示区域，主要是动态图、按钮
    Rectangle{
        id:itemShowRec
        anchors{
            top:parent.top
            right: parent.right
        }

        width: 80
        height: 80
        radius: 6
        color: Colors.color_444444

        // 静态封面
        Image {
            id: coverStatic
            anchors.fill: parent
            source: imageUrl
            asynchronous: true
            cache: true
            visible: coverAnimated.status !== AnimatedImage.Ready || !coverAnimated.playing
            fillMode: Image.PreserveAspectCrop
            onStatusChanged: {
                if (status === Image.Ready) {
                    shaderSource.scheduleUpdate()
                }
            }
        }

        // 动图（hover 时播放，覆盖静态封面）
        AnimatedImage {
            id: coverAnimated
            visible: status === AnimatedImage.Ready && playing
            anchors.fill: parent
            source: hoverImage
            asynchronous: true
            cache: true
            playing: false
        }

        // 选中框
        Rectangle{
            id:selectRect
            // 判断的逻辑是是否选中以及是否作用于当前grid
            visible: itemMouseArea.focus || currentSelectGrid
            anchors.fill: parent
            color: "transparent"
            radius: 6
            // 这里判断是否选择当前的item，然后展示选择框
            border.width:currentSelectGrid?2:0
            border.color: Colors.color_F22443
        }

        // item鼠标交互
        MouseArea{
            id: itemMouseArea
            anchors.fill: parent
            hoverEnabled: true

            drag.target: materialDragController.dragCoverItem  // 必须设置

            onEntered: {
                //TODO:需确定埋点特效类型和位置类型
                coverAnimated.playing = true;
                if (coverAnimated.status !== AnimatedImage.Ready && hoverImage !== "") {
                    imageCache.getCachedImage(hoverImage);
                }
                eventTracker.trackEvent("pccut_effect_card_hover", {
                                            "effect_slug_string": resourceSlug,
                                            "type": supportTypeName,
                                            "position": locationTypeName
                                        })
            }
            onExited: {
                coverAnimated.currentFrame = 0;
                coverAnimated.playing = false;
            }

            onClicked: {

                // 立即选中（未下载时仅视觉选中，下载完成后通过信号触发预览）
                if (currentSelectGrid) {
                    seekClicked(mouseX / width)
                    return
                }

                forceActiveFocus()
                cardClicked()

                //TODO:需确定特效类型和位置类型
                eventTracker.trackEvent("pccut_effect_card_click", {
                                            "effect_slug_string": resourceSlug,
                                            "type": supportTypeName,
                                            "position": locationTypeName
                                        })
            }

            onPressed: {
                // 因为有时候拖拽也想做直接下载，所以按下就下载
                downloadClicked()
            }

            onPositionChanged: {
                if (pressed) {
                    // 未下载完成不允许拖拽
                    if (model.progress < 1) {
                        return;
                    }
                    if (!materialDragController.visible) {
                        materialDragController.visible = true;
                        var pos = mapToItem(lightWindow.contentItem, mouseX, mouseY);
                        materialDragController.mousePoint = pos;
                    }

                    var posInWindow = mapToItem(lightWindow.contentItem, mouseX, mouseY);
                    materialDragController.mousePoint = posInWindow;

                }
            }

            onReleased: {
                if(materialDragController.visible){
                    materialDragController.visible = false;
                }
            }
        }

        // 防止异常卡顿情况 没有及时隐藏拖拽窗口
        Connections {
            target: lightWindow
            function onActiveChanged() {
                if (!lightWindow.active && materialDragController.visible === true) {
                    materialDragController.visible = false
                }

                if(coverAnimated.playing){
                    coverAnimated.currentFrame = 0;
                    coverAnimated.playing = false;
                }
            }
        }

        Rectangle{
            anchors.fill: parent
            color: Colors.transparent
            visible:addBtn.visible

            // 处理封面拖拽的组件
            MaterialDragController{
                id: materialDragController
                visible: false
                parentItem: lightWindow.contentItem // 必须设置: 确保可以在整个窗口中进行拖拽
                dragBusinessManager: EffectDragBusiness {
                    id: effectDragBusiness
                    view: tracks.multiTrackView
                    effectConfig: materialItem.effectConfig
                }

                dragCoverItem: DragCoverItem {
                    RoundedImage {
                        source: imageUrl
                    }
                }

                dragItemInTrack: Rectangle {
                    height: 56
                    width: 56
                    radius: 6
                    color: Colors.color_1E1E1E

                    RoundedImage {
                        source: imageUrl
                        imageRadius: 6
                    }
                }

            }
        }


        LightClipRectangle {
            id: downloadIcon
            visible: model.progress < 1
            width: 20
            height: 20
            radius: [10,10,10,10]
            anchors.right: parent.right
            anchors.rightMargin: 4
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 4

            ShaderEffectSource {
                id: shaderSource
                sourceItem: coverStatic
                sourceRect: Qt.rect(downloadIcon.x, downloadIcon.y, downloadIcon.width, downloadIcon.height)
                live: false
                smooth: true
            }

            // 高斯调节
            FastBlur {
                anchors.fill: parent
                source: shaderSource
                radius: 48
            }
            Rectangle {
                anchors.fill: parent
                color: Colors.color_444444_50
                radius: 10
            }
        }

        Image {
            id: download_state_img
            source: "qrc:/icons/download_need.svg"
            anchors.centerIn: downloadIcon
            visible: model.progress < 0
            sourceSize: Qt.size(20, 20)

            MouseAreaWithHover {
                id:downloadMouseArea
                contentItemY: (20)
                text: qsTr("pccut_tooltip_download_effect")
                onClicked: {
                    downloadClicked();
                }
            }
        }

        Image {
            id: addBtn
            source: "qrc:/icons/icon_add.svg"
            visible: (itemMouseArea.containsMouse || collectBtnArea.containsMouse ||
                      addMouseArea.containsMouse || panoramaMouseArea.containsMouse)
                     && model.progress >= 1
            anchors.centerIn: downloadIcon
            sourceSize: Qt.size(20, 20)

            MouseAreaWithHover {
                id:addMouseArea
                focus: true
                contentItemY: (20)
                text: qsTr("pccut_tooltip_add_effect")
                onClicked: {
                     addClicked()
                }
            }
        }

        Image {
            id: rotatingImage
            width: 16
            height: 16
            source: "qrc:/icons/ic_download_loading.png"
            visible: (model.progress >= 0 && model.progress < 1)
            anchors.centerIn: downloadIcon
            smooth: true
            RotationAnimation on rotation {
                loops: Animation.Infinite
                running: rotatingImage.visible
                from: 0
                to: 360
                duration: 1000 // 持续时间为1秒
            }
        }

        Image {
            id: collectImage
            visible: itemMouseArea.containsMouse || addMouseArea.containsMouse
                     || downloadMouseArea.containsMouse || collectBtnArea.containsMouse
                     || ((typeof model.isCollect !== "undefined") ? model.isCollect : false)
            anchors{
                top: parent.top
                topMargin: 4
                right: parent.right
                rightMargin: 4
            }
            sourceSize: Qt.size(20, 20)
            source: model.isCollect ?  "qrc:/icons/icon_collect_red.svg" : "qrc:/icons/icon_collect.svg"

            MouseAreaWithHover {
                id:collectBtnArea
                focus: true
                contentItemY: (20)
                text: model.isCollect ? qsTr("pccut_media_unfavorite"): qsTr("pccut_tooltip_favorite_effect")
                onClicked: {

                    var toCollect = !model.isCollect

                    // 注意：eventTracker.trackEvent 必须 collectClicked 之前执行！！！
                    // 执行collectClicked时，在其下游处理逻辑当中，收藏列表取消收藏时触发了一个同步的 delegate 销毁过程，
                    // 因此在collectClicked执行后再执行eventTracker.trackEvent会报错。
                    eventTracker.trackEvent("pccut_effect_favorite", {
                                                "effect_slug": resourceSlug,
                                                "type": supportTypeName,
                                                "position": locationTypeName,
                                                "is_favorite": toCollect
                                            })
                    collectClicked(toCollect)
                }
            }
        }

        Image {
            id: panoramaIcon
            source: "qrc:/app_qrc/icons/icon_special_effect_videotype_360.svg"
            visible: onlyForPanorama
            sourceSize: Qt.size(20, 20)
            anchors{
                bottom: parent.bottom
                bottomMargin: 4
                left: parent.left
                leftMargin: 4
            }

            MouseAreaWithHover {
                id: panoramaMouseArea
                focus: true
                contentItemY: (20)
                text: qsTr("pccut_tooltip_effect_360_only")
            }
        }

        // 已添加标签
        Rectangle {
            id: addedTag
            visible: editorManager.effectSlugList.indexOf(resourceSlug) !== -1
            radius: 4
            color: Colors.color_000000_50
            height: 20
            width: addedTagText.width + 8
            x: 4
            y: 4
            Text {
                id: addedTagText
                text: qsTr("pccut_media_added")
                color: Colors.color_EEEEEE
                font.pixelSize: 10
                x: 4
                y: 3
            }
        }

        // 播放进度竖线（与素材区 playedLine 样式一致）
        Rectangle {
            id: progressLine
            width: 1
            height: parent.height
            color: Colors.color_FFFFFF
            x: Math.min(playedPercentage * parent.width, parent.width - width)
            visible: currentSelectGrid
        }

        // 圆角遮罩
        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: itemShowRec.width
                height: itemShowRec.height
                radius: itemShowRec.radius
                color: Colors.color_FFFFFF
            }
        }
    }

    // 文字显示区域
    Text {
        id: displayText
        width: itemShowRec.width
        text: resourceName
        topPadding: 4
        anchors{
            top: itemShowRec.bottom
            left: itemShowRec.left
        }
        font.pixelSize: 12
        color: Colors.color_959595
        elide: Text.ElideMiddle

        MouseArea {
            id: textMouseArea
            anchors.fill: parent
            hoverEnabled: true
            propagateComposedEvents: true
            onEntered: {
                if (displayText.implicitWidth > displayText.width)
                {
                    nameToolTipLoader.active = true
                    var toolTip = nameToolTipLoader.item
                    toolTip.visible = true; // 显示ToolTip

                    var newPoint = textMouseArea.mapToItem(toolTip.parent, textMouseArea.x, textMouseArea.y)

                    // 显示在文本位置
                    toolTip.x = newPoint.x
                    toolTip.y = newPoint.y
                    toolTip.tip = displayText.text; // 鼠标进入时设置ToolTip的文本
                }
            }
            onExited: {
                nameToolTipLoader.active = false
            }
        }
        Loader {
            id: nameToolTipLoader
            // 默认不加载
            active: false
            // 完整名称ToolTip
            sourceComponent: LightToolTip {
                                tip: displayText.text
                                z: 200
                            }
        }
    }
}
