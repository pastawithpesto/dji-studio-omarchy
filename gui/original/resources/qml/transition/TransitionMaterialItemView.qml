import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.3
import Qt5Compat.GraphicalEffects
import Config 1.0
import Controls 1.0
import app_qrc 1.0
import QtQuick.Dialogs
import NetworkGifCache
import MultiTrackView 1.0
import MaterialDragController 1.0
import ShortcutAction 1.0
import TransitionDragBussiness 1.0

/**
 * @author hugo.li
 * @desc 转场素材单个Item
 * @create_date 2025-11-14
 */

Item {
    id: materialItem

    // anchors.fill: parent

    // 素材属性部分
    property string resourceSlug: ""
    property string resourceName: ""
    property string currFragmentResourceSlug:""
    property string imageUrl: ""
    property string hoverImage: ""
    property bool inCollectGridView:false
    property bool currentSelectGrid:false

    focus: true


    signal download(int index)
    signal collect(int index, bool isCollect)
    signal addTransition(string slug)
    signal selectItem(string slug)
    signal preview(string slug)

    // 全局区域的信号在这里接收
    Connections {
        target: globalSignal
    }

    onImageUrlChanged: {
        if (imageUrl !== "") {
            imageCache.getCachedImage(imageUrl);
        }
    }

    onHoverImageChanged: {
        if (hoverImage !== "") {
            imageCache.getCachedImage(hoverImage);
        }
    }

    // 单项的展示区域，主要是动态图、还有所有的按钮，不包括文字
    Rectangle{
        id:itemShowRec
        anchors{
            top:parent.top
            right: parent.right
        }

        width: 80
        height: 80


        color: Colors.color_444444


        radius: 6

        // 静态封面
        Image {
            id: coverStatic
            anchors.fill: parent
            source: imageUrl
            asynchronous: true
            cache: true
            visible: coverAnimated.status !== AnimatedImage.Ready || !coverAnimated.playing
            fillMode: Image.PreserveAspectCrop
        }

        // 动图（hover 时播放）
        AnimatedImage {
            id: coverAnimated
            visible: status === AnimatedImage.Ready && playing
            anchors.fill: parent
            source: hoverImage
            asynchronous: true
            cache: true
            playing: false
            fillMode: Image.PreserveAspectCrop
        }

        NetworkGifCache {
            id: imageCache
            onImageCached:function(url,localPath) {
                if (url === imageUrl) {
                    coverStatic.source = "file:///" + localPath;
                }
                if (url === hoverImage) {
                    coverAnimated.source = "file:///" + localPath;
                }
            }
        }

        // 选中框
        Rectangle{
            id:selectRect
            // 判断的逻辑是是否选中以及是否作用于当前grid
            visible: itemMouseArea.focus
            anchors.fill: parent
            color: "transparent"
            radius: 6
            // 这里判断是否选择当前的item，然后展示选择框
            border.width:currentSelectGrid?1.5:0
            border.color: Colors.color_F22443
        }

        // item鼠标交互
        MouseArea{
            id: itemMouseArea
            anchors.fill: parent
            hoverEnabled: true

            drag.target: materialDragController.dragCoverItem  // 必须设置

            onEntered: {
                coverAnimated.playing = true;

            }
            onExited: {
                coverAnimated.currentFrame = 0;
                coverAnimated.playing = false;
            }

            onClicked: {
                // 如果已经是选中状态，就不去预览
                if(selectRect.visible && currentSelectGrid){
                    return
                }

                forceActiveFocus()
                selectItem(resourceSlug)

                // 如果已经是下载完成的，就可以直接预览，否则是走下载的逻辑
                if(model.progress >= 1){
                    preview(resourceSlug)
                }
            }

            onPressed: {
                // 因为有时候拖拽也想做直接下载，所以按下就下载
                download(index)
            }

            onPositionChanged: {
                if(pressed){
                    if(!materialDragController.visible){
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
                if (!lightWindow.active &&materialDragController.visible === true) {
                    materialDragController.visible = false
                }

                if(coverAnimated.playing){
                    coverAnimated.currentFrame = 0;
                    coverAnimated.playing = false;
                }
            }
        }

        Rectangle{
            id:dragControllRec
            anchors.fill: parent
            color: Colors.transparent
            visible:transitionAdd.visible

            // // 处理封面拖拽的组件
            MaterialDragController{
                id: materialDragController
                visible: false
                parentItem: lightWindow.contentItem // 必须设置: 确保可以在整个窗口中进行拖拽
                dragBusinessManager: TransitionDragBussiness{
                    view: tracks.multiTrackView
                    slug:resourceSlug
                }

                dragItemInTrack: Rectangle{
                    id:itemInTrack
                    layer.enabled: true // 启用图片自身的裁剪层
                    height: 72
                    width: 55
                    color: Colors.color_FFFFFF_30
                    radius: 4

                    onVisibleChanged: {
                        // 如果当前轨道没有片段，我需要有一个自己的界面，不然直接变成空了
                        var expectedWidth = transitionManager.getTransitionUIWidth(0,0)
                        if(expectedWidth <= 0 ){
                            width = 55
                        }else{
                            width = expectedWidth
                        }
                    }

                    Image{
                        anchors{
                            centerIn: parent
                        }

                        width:16
                        height: 16

                        visible: parent.width >= 17
                        source: "qrc:/app_qrc/icons/tab_transition.svg"
                    }
                    // 图片圆角遮罩
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: itemInTrack.width
                            height: itemInTrack.height
                            radius: itemInTrack.radius
                        }
                    }
                }

                dragCoverItem: Rectangle {
                     id: dragItemDelegate
                     height: 72
                     width: 72
                     radius: 6
                     border {
                         width: 1.5
                         color: Colors.color_F22443
                     }
                     color: Colors.color_444444

                     Rectangle {
                         id: imageContainer1
                         anchors.fill: parent
                         anchors.margins: parent.border.width // 留出边框空间
                         radius: parent.radius - parent.border.width // 圆角减去边框宽度
                         clip: true // 应用圆角裁剪
                         color: Colors.color_444444

                         Image {
                             id: contentImage
                             anchors.fill: parent
                             anchors.margins: 0
                             source: hoverImage !== "" ? hoverImage : imageUrl
                             fillMode: Image.PreserveAspectCrop
                             asynchronous: true
                             layer.enabled: true // 启用图片自身的裁剪层

                             // 图片圆角遮罩
                             layer.effect: OpacityMask {
                                 maskSource: Rectangle {
                                     width: imageContainer1.width
                                     height: imageContainer1.height
                                     radius: imageContainer1.radius
                                 }
                             }
                         }
                     }
                 }

            }
        }


        LightClipRectangle {
            id: downloadIcon
            visible: model.progress < 1 /*&& !isShowImportTab*/
            width: 20
            height: 20
            radius: [10,10,10,10]
            anchors.right: parent.right
            anchors.rightMargin: 4
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 4

            ShaderEffectSource {
                id: shaderSource
                sourceItem: (coverAnimated.status === AnimatedImage.Ready) ? coverAnimated : coverStatic
                sourceRect: Qt.rect(downloadIcon.x, downloadIcon.y, downloadIcon.width, downloadIcon.height)
                live: true
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
            visible: model.progress < 0 /*&& !isShowImportTab*/
            sourceSize: Qt.size(20, 20)
            // objectName: actionableItemName.downloadIconForFilter + index

            MouseAreaWithHover {
                id:downloadMouseArea
                contentItemY: (20)
                text: qsTr("pccut_resource_transition_download_button")
                onClicked: {
                    download(index);
                }
            }
        }

        Image {
            id: transitionAdd
            source: "qrc:/app_qrc/icons/filter_add.svg"
            visible: (itemMouseArea.containsMouse || collectBtnArea.containsMouse || addMouseArea.containsMouse) && model.progress >= 1
            anchors.centerIn: downloadIcon
            sourceSize: Qt.size(20, 20)

            MouseAreaWithHover {
                id:addMouseArea
                focus: true
                contentItemY: (20)
                text: qsTr("pccut_resource_transition_add")
                onClicked: {
                     addTransition(resourceSlug)
                }
            }
        }

        Image {
            id: rotatingImage
            width: 16
            height: 16
            source: "qrc:/icons/ic_download_loading.png"
            visible: (model.progress >= 0 && model.progress < 1 && model.progress !== -1)
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
                     || downloadMouseArea.containsMouse ||collectBtnArea.containsMouse
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
                text: model.isCollect ? qsTr("pccut_resource_transition_like_cancel"): qsTr("pccut_resource_transition_like_confirm")
                onClicked: {
                    var curIsCollected = model.isCollect;
                    collect(index,!curIsCollected)
                }
            }

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
