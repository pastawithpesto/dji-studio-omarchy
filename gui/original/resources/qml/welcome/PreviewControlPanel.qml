import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts

import Config 1.0
import MKPlayerController 1.0
import Controls 1.0
import PreviewSourceHandler 1.0
import DeviceMediaCategory 1.0

Rectangle {
    id: controlPanel
    width: 460
    height: {
        // 自动根据高光状态和可见性计算高度
        if (!isHighlightRectEnable) return 72;
        return isHighlightRectVisible ? 138 : 80;
    }
    radius: 8
    border.width: 0
    border.color: Colors.transparent
    color: Colors.color_1F2021
    property int playIconSize: 20
    property int iconSize: 20
    property MKPlayerController controller
    property PreviewSourceHandler handler
    property bool isFullScreen: false
    // 【云相册边下边播·缓冲进度·正式】已缓冲帧区间 [{begin,end},...]（支持多段），
    //    由 PreviewPlayer 传入 conductor.cachedRanges，绑定到进度条灰条。
    property var cachedRanges: []

    // 支持折叠显示/隐藏原片和高光，支持高光过多时显示滚动条
    property bool isHighlightRectEnable: handler.highlightState != PreviewSourceHandler.Highlight_Disabled && handler.mediaCategory == DeviceMediaCategory.Original
    property bool isHighlightRectVisible: true  // 默认展开
    property bool isHighlightScrollable: false  // 高光列表是否需要滚动条

    onIsFullScreenChanged: {
        enterFullScreen.refreshTips();
    }
    signal fullScreenClicked

    function getPlayedProgress() {
        const fps = controller.fps();
        if (controller.playedFrame < 0 || controller.totalFrames <= 0 || fps <= 0) {
            return "";
        }
        const playedProgress = DurationFormatter.format(controller.playedFrame, fps, false);
        return `${playedProgress}`;
    }

    function getTotalProgress() {
        const fps = controller.fps();
        if (controller.playedFrame < 0 || controller.totalFrames <= 0 || fps <= 0) {
            return "";
        }
        const totalProgress = DurationFormatter.format(controller.totalFrames, fps, false);
        return `${totalProgress}`;
    }

    function getPrecentage() {

        return controller.playedFrame / controller.totalFrames
    }

    function isEnter() {
        // 检查所有可交互元素的 hover 状态
        // 底部播放控制按钮
        return playToggle.hovered || playLast.hovered || playNext.hovered || enterFullScreen.hovered || playSlider.isHovered
    }

    // 统一的折叠按钮（放在最顶层）
    Rectangle {
        id: toggleHighlightBtn
        width: 16
        height: 8
        color: Colors.color_1F2021
        visible: controlPanel.isHighlightRectEnable
        z: 1  // 确保在最上层
        property var hovered: false

        anchors {
            top: parent.top
            topMargin: 4
            horizontalCenter: parent.horizontalCenter
        }

        Image {
            anchors.centerIn: parent
            source: toggleHighlightBtn.hovered ? (controlPanel.isHighlightRectVisible ? "qrc:/icons/highlight/icon_hl_hide_highlight.svg" :
                                                                                        "qrc:/icons/highlight/icon_hl_show_highlight.svg") :
                                                 (controlPanel.isHighlightRectVisible ? "qrc:/icons/highlight/icon_hl_hide.svg" :
                                                                                        "qrc:/icons/highlight/icon_hl_show.svg")
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onEntered: {
                toggleHighlightBtn.hovered = true;
            }

            onExited: {
                toggleHighlightBtn.hovered = false;
            }
            onClicked: {
                controlPanel.isHighlightRectVisible = !controlPanel.isHighlightRectVisible
            }
        }
    }

    Column {
        id: colItem
        spacing: {
            // 折叠时无间距
            if (!isHighlightRectVisible) return 0;
            // 展开时，滚动条显示则减去8px间距
            if (isHighlightScrollable) return 0;
            return 8;
        }

        anchors {
            top: parent.top
            topMargin: {
                // 根据总高度反推：不支持=0, 折叠=8, 展开=0
                if (!isHighlightRectEnable) return 0;
                return isHighlightRectVisible ? 0 : 8;
            }
            left: parent.left
        }

        Rectangle {
            id: hlItem
            width: 460
            height: {
                if(isHighlightScrollable)
                    return 66;
                else
                    return 58;
            }
            visible: isHighlightRectEnable && isHighlightRectVisible
            color: Colors.color_1F2021  // test ok
            radius: 8  // 与 controlPanel 的圆角保持一致

            // ✨ 新增：hover 状态属性
            property bool hovered: false

            // 一行显示的内容： 原片、分割线、高光等.
            Rectangle {
                width: 432
                height: 48
               // x:12
                //y:16
                color: Colors.color_1F2021
                anchors {
                    top: parent.top
                    topMargin: 16
                   left: parent.left
                   leftMargin: 12
               }
                // 原片
                LightClipRectangle {
                    id: ori
                    width: 48
                    height: 48
                    color: Colors.color_444444
                    clip: true
                    radius: [6, 6, 6, 6]

                    property bool hovered: false
                    property bool isSelected: handler.currentPreviewHighlight === ""

                    Image {
                        source: "image://image_provider/" + controlPanel.handler.currentSource + ";0;0;0;1;1"
                        sourceSize: Qt.size(parent.width, parent.height)
                        fillMode: Image.PreserveAspectCrop
                        anchors.fill: parent
                        visible: true
                    }

                    // 默认状态黑色遮罩层
                    Rectangle {
                        anchors.fill: parent
                        radius: 6
                        color: Colors.color_000000_20
                        visible: !ori.hovered && !ori.isSelected
                    }

                    TooltipText {
                        anchors {
                            left: parent.left
                            leftMargin: 4
                            right: parent.right
                            rightMargin: 4
                            bottom: parent.bottom
                            bottomMargin: 2
                        }
                        height: 15
                        opacity: 1
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        //font.family: "PingFang SC"
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        lineHeight: 15
                        color: Colors.color_EEEEEE
                        text: qsTr("pccut_home_original")
                        externalHovered: ori.hovered  // 使用父节点的 hover 状态
                        tooltipY: height + anchors.bottomMargin + 4  // 在 ori 下方 4px
                    }
                    // select item
                    Rectangle {
                        id: oriCover
                        visible: handler.isSelectModel

                        width: 12
                        height: 12
                        radius: 3
                        color: "transparent"   // 必须
                        anchors{
                            top: parent.top
                            topMargin: 4
                            left: parent.left
                            leftMargin: 4
                        }

                        Image {
                            source: handler.isOriginalSelected
                                        ? "qrc:/icons/highlight/icon_hl_selectd_red.svg"
                                        : "qrc:/icons/highlight/icon_hl_select.svg"
                        }
                    }
                    
                    // 原片-选中预览边框效果
                    Rectangle {
                        id: currentPreviewBorder
                        width: parent.width
                        height: parent.height
                        radius: 6
                        anchors.centerIn: parent
                        color: "transparent"
                        border.color: ori.isSelected ? Colors.color_EEEEEE : Colors.color_EEEEEE_30
                        border.width: 1.5
                        visible: ori.hovered || ori.isSelected
                        opacity: 1
                    }
                        
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true

                        onEntered: {
                            ori.hovered = true;
                        }

                        onExited: {
                            ori.hovered = false;
                        }

                        onClicked: {
                            if (handler.isSelectModel) {
                                handler.isOriginalSelected = !handler.isOriginalSelected;
                            } else {
                                handler.currentPreviewHighlight = "";
                            }
                        }
                    }
                }
                // 分割线1
                Rectangle {
                    id: splitLine
                    width: 1
                    height: 16
                    color: Colors.color_454649
                    anchors.left: ori.right
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                }

                // ========== 0: 开始分析按钮 ==========
                Rectangle {
                    id: startAnalysisBtn
                    width: 359
                    height: 48
                    color: startAnalysisBtn.hovered ? Colors.color_37383A : Colors.color_2F3032
                    radius: 6
                    visible: handler.highlightState === PreviewSourceHandler.Highlight_WaitForTask

                    property bool hovered: false

                    anchors {
                        left: splitLine.right
                        leftMargin: 12
                        verticalCenter: parent.verticalCenter
                    }

                    Row {
                        anchors.centerIn: parent
                        spacing: 4

                        Image {
                            width: 16
                            height: 16
                            source: "qrc:/icons/highlight/ic_create.svg"
                        }

                        Text {
                            text: qsTr("pccut_home_highlight_preview_switch")
                            color: Colors.color_EEEEEE
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            font.letterSpacing: 0
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        
                        onEntered: {
                            startAnalysisBtn.hovered = true;
                        }
                        onExited: {
                            startAnalysisBtn.hovered = false;
                        }
                        onClicked: {
                            handler.startHighlightTask();
                        }
                    }
                }

                // ========== 1: 进度显示 ==========
                Rectangle {
                    id: progressIndicator
                    width: 359
                    height: 48
                    color: Colors.color_transparent
                    radius: 6
                    visible: handler.highlightState === PreviewSourceHandler.Highlight_TaskRunning

                    anchors {
                        left: splitLine.right
                        leftMargin: 12
                        verticalCenter: parent.verticalCenter
                    }

                    Item {
                        anchors {
                            left: parent.left
                            leftMargin: 125
                            verticalCenter: parent.verticalCenter
                        }

                        height: 18
                        width: 18 + 4 + analyzeText.implicitWidth
                        Image {
                            id: rotatingImage
                            width: 18
                            height: 18
                            source: "qrc:/icons/highlight/ic_loading.png"
                            smooth: true
                            RotationAnimation on rotation {
                                loops: Animation.Infinite
                                running: rotatingImage.visible
                                from: 0
                                to: 360
                                duration: 1000 // 持续时间为1秒
                            }
                        }

                        Text {
                            id: analyzeText
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: rotatingImage.right
                            anchors.leftMargin: 4
                            text: qsTr("pccut_home_highlight_preview_loading") + " " + Math.floor(handler.highlightTaskProgress * 100) + "%"
                            color: Colors.color_EEEEEE
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            font.letterSpacing: 0
                        }
                    }
                }

                // ========== 2: 高光列表（带横向滚动） ==========
                RowLayout {
                    id: highlightList
                    height: 48
                    spacing: 0
                    visible: handler.highlightState === PreviewSourceHandler.Highlight_TaskFinished

                    anchors {
                        left: splitLine.right
                        leftMargin: 12
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }

                    // 横向滚动的高光列表
                    Item {
                        id: hlListContainer
                        Layout.fillWidth: true  // 自动填充剩余空间
                        Layout.preferredHeight: isHighlightScrollable ? 56 : 48
                        Layout.alignment: Qt.AlignVCenter
                        clip: true

                        // 横向滚动辅助函数（定义在最前面，确保子元素可以访问）
                        function scrollHorizontalBy(delta) {
                            // console.log("[scrollHorizontalBy] Called with delta:", delta);
                            // console.log("  - Current contentX:", hlList.contentX);
                            // console.log("  - contentWidth:", hlList.contentWidth);
                            // console.log("  - List width:", hlList.width);

                            if (delta === 0) {
                                // console.log("  -> Delta is 0, skipping");
                                return;
                            }

                            const newContentX = Math.max(0, Math.min(
                                hlList.contentWidth - hlList.width,
                                hlList.contentX + delta
                            ));

                            // console.log("  -> New contentX:", newContentX);
                            hlList.contentX = newContentX;
                            // console.log("  -> Applied. Current contentX:", hlList.contentX);
                        }

                        ListView {
                            id: hlList
                            anchors {
                                top: parent.top
                                left: parent.left
                                right: parent.right
                                bottom: parent.bottom
                            }
                            spacing: 12

                            model: handler.hlListItems
                            orientation: ListView.Horizontal
                            layoutDirection: Qt.LeftToRight

                            // 显式计算内容宽度：每个项 48px + 间距 12px
                            contentWidth: count * 48 + (count > 0 ? (count - 1) * 12 : 0)

                            interactive: true
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds  // 边界处停止
                            flickableDirection: Flickable.HorizontalFlick  // 只允许横向滚动

                            // 仅在内容超出容器宽度时显示滚动条
                            property bool needsScrollbar: contentWidth > width
                            onNeedsScrollbarChanged: {
                                controlPanel.isHighlightScrollable = needsScrollbar;
                            }

                            delegate: LightClipRectangle {
                                id: hlListItem

                                property var itemData : modelData  // QML提供
                                property bool hovered: false
                                property bool isSelected: handler.currentPreviewHighlight === (modelData ? modelData.id : "")

                                width: 48
                                height: 48
                                color: Colors.color_444444
                                clip: true
                                radius: [6, 6, 6, 6]

                                Image {
                                    source: "image://image_provider/" + (modelData ? modelData.coverPath : "") + ";0;0;0;1;1"
                                    sourceSize: Qt.size(parent.width, parent.height)
                                    fillMode: Image.PreserveAspectCrop
                                    anchors.fill: parent
                                    visible: true
                                }

                                // 默认状态黑色遮罩层
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 6
                                    color: Colors.color_000000_20
                                    visible: !hlListItem.hovered && !hlListItem.isSelected
                                }

                                Text {
                                    anchors {
                                        left: parent.left
                                        leftMargin: 10
                                        right: parent.right
                                        rightMargin: 10
                                        bottom: parent.bottom
                                        bottomMargin: 2
                                    }
                                    width: 28
                                    height: 15
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                    lineHeight: 15
                                    color: Colors.color_EEEEEE
                                    text: modelData?.sourceLengthFormatMMSS() ?? ""
                                }

                                // 高光-选中预览边框效果
                                Rectangle {
                                    id: currentPreviewHighlightBorder
                                    width: parent.width
                                    height: parent.height
                                    radius: 6
                                    anchors.centerIn: parent
                                    color: "transparent"
                                    border.color: hlListItem.isSelected ? Colors.color_EEEEEE : Colors.color_EEEEEE_30
                                    border.width: 1.5
                                    visible: hlListItem.hovered || hlListItem.isSelected
                                    opacity: 1
                                }

                                // 右上角复选框
                                Rectangle {
                                    visible: handler.isSelectModel
                                    width: 12
                                    height: 12
                                    radius: 3
                                    color: "transparent"
                                    anchors {
                                        top: parent.top
                                        topMargin: 4
                                        left: parent.left
                                        leftMargin: 4
                                    }
                                    Image {
                                        source: handler.highlightSelectedList.includes(modelData ? modelData.id : "")
                                                    ? "qrc:/icons/highlight/icon_hl_selectd_red.svg"
                                                    : "qrc:/icons/highlight/icon_hl_select.svg"
                                    }
                                }

                                MouseArea {
                                    id: hlMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true

                                    onEntered: {
                                        hlListItem.hovered = true;
                                        hlTooltipLoader.showTooltip();
                                    }

                                    onExited: {
                                        hlListItem.hovered = false;
                                        hlTooltipLoader.hideTooltip();
                                    }

                                    onClicked: {
                                        if (handler.isSelectModel) {
                                            handler.switchHighlightSelected(modelData ? modelData.id : "");
                                        } else {
                                            handler.currentPreviewHighlight = modelData ? modelData.id : "";
                                        }
                                    }

                                    // Tooltip展示高光主题类型
                                    Loader {
                                        id: hlTooltipLoader
                                        active: false
                                        anchors.fill: parent
                                    
                                        function showTooltip() {
                                            active = true;
                                            if (item) {
                                                item.tip = modelData?.highlightThemeName() ?? "";
                                                item.visible = true;
                                            }
                                        }
                                    
                                        function hideTooltip() {
                                            active = false;
                                        }
                                    
                                        sourceComponent: LightToolTip {
                                            y: hlListItem.height + 4  // 在文本下方 4px
                                        }
                                    }
                                }
                            }
                        }

                        // ========== 横向滚动条 ==========
                        Rectangle {
                            id: hlScrollBar
                            width: parent.width
                            height: 4
                            radius: 88
                            visible: isHighlightScrollable
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 0

                            color: "transparent"

                            MouseArea {
                                id: hlScrollBarMouseArea
                                // 扩大纵向热区，方便用户点击拖拽
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    verticalCenter: parent.verticalCenter
                                }
                                height: 16
                                hoverEnabled: true
                                preventStealing: true

                                property real pressStartX: 0
                                property real pressStartContentX: 0

                                onPressed: (mouse) => {
                                    pressStartX = mouse.x;
                                    pressStartContentX = hlList.contentX;
                                }

                                onPositionChanged: (mouse) => {
                                    if (pressed) {
                                        const maxScrollable = hlList.contentWidth - hlList.width;
                                        if (maxScrollable <= 0) return;
                                        const scrollRatio = maxScrollable / (hlScrollBar.width - hlScrollThumb.width);
                                        const delta = (mouse.x - pressStartX) * scrollRatio;
                                        hlList.contentX = Math.max(0, Math.min(maxScrollable, pressStartContentX + delta));
                                    }
                                }
                            }

                            Rectangle {
                                id: hlScrollThumb
                                height: parent.height
                                radius: parent.radius
                                color: {
                                    if (hlScrollBarMouseArea.containsMouse || hlScrollBarMouseArea.pressed) {
                                        return "#56575B";
                                    }
                                    return "#454649";
                                }

                                width: {
                                    if (hlList.contentWidth <= hlList.width) return parent.width;
                                    return Math.max(20, parent.width * (hlList.width / hlList.contentWidth));
                                }

                                x: {
                                    const maxScrollable = hlList.contentWidth - hlList.width;
                                    if (maxScrollable <= 0) return 0;
                                    const ratio = hlList.contentX / maxScrollable;
                                    return ratio * (parent.width - width);
                                }
                            }
                        }

                        // ========== 横向滚动支持 ==========
                        // 使用 WheelHandler 替代 MouseArea，避免拦截 hover 事件

                        WheelHandler {
                            id: wheelHandler
                            orientation: Qt.Vertical  // 接收纵向滚轮

                            property real scrollStep: 60  // 每次滚动步长

                            onWheel: (event) => {
                                // 纵向滚轮转为横向滚动
                                const delta = event.angleDelta.y > 0 ? -scrollStep : scrollStep;
                                hlListContainer.scrollHorizontalBy(delta);
                                event.accepted = true;
                            }
                        }
                    }

                    // 高光列表和分割线的间距 (12px)
                    Item {
                        Layout.preferredWidth: 12
                        Layout.preferredHeight: 1
                    }

                    // 分割线2
                    Rectangle {
                        id: splitLine2
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: 16
                        Layout.alignment: Qt.AlignVCenter
                        color: Colors.color_454649
                    }

                    // 分割线和复选框的间距 (12px)
                    Item {
                        Layout.preferredWidth: 12
                        Layout.preferredHeight: 1
                    }

                    // 复选框入口
                    Rectangle {
                        id: selectList
                        Layout.preferredWidth: 20
                        Layout.preferredHeight: 20
                        Layout.alignment: Qt.AlignVCenter
                        color: Colors.color_1F2021

                        property bool hovered: false

                        Image {
                            source: handler.isSelectModel
                                        ? "qrc:/icons/highlight/batch_select_on.svg"
                                        : (selectList.hovered
                                            ? "qrc:/icons/highlight/batch_select_hover.svg"
                                            : "qrc:/icons/highlight/batch_select_off.svg")
                        }

                        MouseArea {
                            id: mouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: {
                                selectList.hovered = true;
                            }
                            onExited: {
                                selectList.hovered = false;
                            }
                            onClicked: {
                                handler.isSelectModel = !handler.isSelectModel
                            }
                        }
                    }
                }
                // =========================================
            }

        }

       // lex-包裹旧播放控件，并添加隐藏新的高光部分的按钮.
       // 与新增高光部分是 column 的布局.
        Item {
            id: playItem
            width: 460
            height: 72
            anchors.left: parent.left

    Text {
        id: playlist
        text: `${handler.currentIndex + 1}/${handler.totalSize}`
        visible: handler.totalSize > 1
        color: Colors.color_EEEEEE
        font.pixelSize: 12
        font.weight: Font.Medium
        font.letterSpacing: 0.26
        anchors.top: parent.top
        anchors.topMargin: 16
        anchors.left: parent.left
        anchors.leftMargin: 16
    }

    Text {
        id: progress
        text: getPlayedProgress()
        font.pixelSize: 12
        color: controller.totalFrames > 1 ? Colors.color_D8D8D8 : Colors.color_444444
        font.weight: Font.Medium
        font.letterSpacing: 0
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.bottomMargin: 11
        anchors.leftMargin: 16
    }

    Text {
        id: duration
        text: getTotalProgress()
        font.pixelSize: 12
        color: controller.totalFrames > 1 ? Colors.color_D8D8D8 : Colors.color_444444
        font.weight: Font.Medium
        font.letterSpacing: 0
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.bottomMargin: 11
        anchors.rightMargin: 16
    }

    IconButton {
        id: playToggle
        iconSource: controller.playing ? "qrc:/icons/preview/preview_pause_normal.svg" : "qrc:/icons/preview/preview_play_normal.svg"
        pressedIconSource: controller.playing ? "qrc:/icons/preview/preview_pause_normal.svg" : "qrc:/icons/preview/preview_play_normal.svg"
        hoverIconSource: controller.playing ? "qrc:/icons/preview/preview_pause_hover.svg" : "qrc:/icons/preview/preview_play_hover.svg"
        disabledIconSource: "qrc:/icons/preview/preview_play_disable.svg"
        width: playIconSize
        height: playIconSize
        disableOpacity:1
        iconMargins:0
        property bool playing: controller.playing
        onPlayingChanged: {
            refreshTips();
        }
        hoverTextFunc: function() {
            return controller.playing ? qsTr("pccut_quick_pause") : qsTr("pccut_quick_start");
        }
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 14
        normalColor: Colors.transparent
        hoverColor: Colors.transparent
        pressedColor: Colors.transparent
        disabled: controller.totalFrames <= 1
        // disabled是咱自己定义的属性，用来展示不同的disable的状态，但是我还想真正disable，所以又设置了enabled属性
        enabled: !disabled

        onClicked: {
            controller.togglePlayState()
            let eventName = controller.playing ? "pccut_player_play_click" : "pccut_player_pause_click"
            if (eventName === "pccut_player_pause_click") {
                editorManager.trackPauseClickEventAsync("player_page", handler.currentSource)
            } else {
                eventTracker.trackEvent(eventName, {"use_method": "player_page"})
            }
        }
    }

    IconButton {
        id: playLast
        iconSource: "qrc:/app_qrc/icons/preview_last_normal.svg"
        pressedIconSource: "qrc:/app_qrc/icons/preview_last_normal.svg"
        hoverIconSource: "qrc:/app_qrc/icons/preview_last_hover.svg"
        disabledIconSource: "qrc:/app_qrc/icons/preview_last_disable.svg"
        width:iconSize
        height:iconSize
        disableOpacity:1
        iconMargins:0
        hoverTextFunc: function() {
            return qsTr("pccut_shortcut_last");
        }
        disabled: !handler.isLastAvailable
        anchors.top: parent.top
        anchors.topMargin: 14
        anchors.left: parent.left
        anchors.leftMargin: 178
        normalColor: Colors.transparent
        hoverColor: Colors.transparent
        pressedColor: Colors.transparent

        onClicked: {
            playSlider.value = 0;
            if (handler.turnLast() === true) {
                toast.showToast(qsTr("pccut_player_lost"), "playerPanel")
            }
            eventTracker.trackEvent("pccut_player_last_next_click")
        }
    }

    IconButton {
        id: playNext
        iconSource: "qrc:/app_qrc/icons/preview_next_normal.svg"
        pressedIconSource: "qrc:/app_qrc/icons/preview_next_normal.svg"
        hoverIconSource: "qrc:/app_qrc/icons/preview_next_hover.svg"
        disabledIconSource: "qrc:/app_qrc/icons/preview_next_disable.svg"
        width:iconSize
        height:iconSize
        disableOpacity:1
        iconMargins:0
        hoverTextFunc: function() {
            return qsTr("pccut_shortcut_next");
        }
        disabled: !handler.isNextAvailable
        anchors.top: parent.top
        anchors.topMargin: 14
        anchors.right: parent.right
        anchors.rightMargin: 178
        normalColor: Colors.transparent
        hoverColor: Colors.transparent
        pressedColor: Colors.transparent

        onClicked: {
            playSlider.value = 0;
            if (handler.turnNext() === true) {
                toast.showToast(qsTr("pccut_player_lost"), "playerPanel")
            }
            eventTracker.trackEvent("pccut_player_last_next_click")
        }
    }

    IconButton {
        id: enterFullScreen
        iconSource: isFullScreen ? "qrc:/icons/preview/preview_exit_full_frame_normal.svg" : "qrc:/icons/preview/preview_enter_full_frame_normal"
        pressedIconSource: isFullScreen ? "qrc:/icons/preview/preview_exit_full_frame_normal" :  "qrc:/icons/preview/preview_enter_full_frame_normal"
        hoverIconSource: isFullScreen ? "qrc:/icons/preview/preview_exit_full_frame_hover" : "qrc:/icons/preview/preview_enter_full_frame_hover"
        disabledIconSource: isFullScreen ? "qrc:/icons/preview/preview_exit_full_frame_disable" : "qrc:/icons/preview/preview_enter_full_frame_disable"
        width:iconSize
        height:iconSize
        iconMargins:0
        hoverTextFunc: function() {
            return isFullScreen?qsTr("pccut_shortcut_esc"):qsTr("pccut_player_fullscreen");
        }
        anchors.top: parent.top
        anchors.topMargin: 14
        anchors.right: parent.right
        anchors.rightMargin: 16
        normalColor: Colors.transparent
        hoverColor: Colors.transparent
        pressedColor: Colors.transparent

        onClicked: {
            fullScreenClicked()
        }
    }

    LightBaseSlider {
        id: playSlider
        property double valueOnPressDown: 0.0
        property var lastPlayingStatus

        enabled: controller.totalFrames > 1

        height: 10
        anchors.bottomMargin: 14
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 78
        anchors.rightMargin: 78
        anchors.bottom: parent.bottom

        handleWidth: 4
        handleHeight: 10
        handleRadius:4
        visualColor: Colors.color_EEEEEE
        unVisualColor: Colors.color_button_background_hovered

        from: 0
        to: enabled ? controller.totalFrames : 0
        stepSize: 1
        snapMode: Slider.SnapAlways
        anchors.fill: parent.anchors.fill

        // 【云相册边下边播·缓冲进度·正式】重写 background：复刻 LightBaseSlider 的
        //    轨道 + 已播条，并在两者之间插入"已缓冲"灰条（支持多段稀疏缓冲）。
        //    放进 background 里，天然位于 handle 手柄之下（background < handle），不盖滑块。
        //    数据源 controlPanel.cachedRanges 由 conductor 提供（真回调 / mock 通用）。
        background: Rectangle {
            // 已缓冲灰条颜色（介于未播暗底 unVisualColor 与已播白 visualColor 之间）
            readonly property color bufferedColor: "#999999"

            x: playSlider.leftPadding
            y: playSlider.topPadding + playSlider.availableHeight / 2 - height / 2
            width: playSlider.availableWidth - 1
            height: 2
            radius: 1
            color: playSlider.enabled ? playSlider.unVisualColor : Colors.color_2D2D2D

            // ── 已缓冲灰条：在底轨之上、已播白条之下；一段 = 一个 Rectangle（支持多段） ──
            Repeater {
                model: controlPanel.cachedRanges
                Rectangle {
                    // modelData = { begin, end }（C++ 传 QVariantMap，避免嵌套 list 被拍平）
                    readonly property real totalFrames: controlPanel.controller ? controlPanel.controller.totalFrames : 0
                    readonly property real beginFrame: Math.min(modelData ? modelData.begin : 0, totalFrames)
                    readonly property real endFrame: Math.min(modelData ? modelData.end : 0, totalFrames)
                    visible: totalFrames > 0 && endFrame > beginFrame
                    x: totalFrames > 0 ? (beginFrame / totalFrames) * parent.width : 0
                    width: totalFrames > 0 ? ((endFrame - beginFrame) / totalFrames) * parent.width : 0
                    height: parent.height
                    radius: parent.radius
                    color: parent.bufferedColor
                }
            }

            // ── 已播放高亮条（复刻 LightBaseSlider 原样式，盖在灰条之上） ──
            Rectangle {
                width: playSlider.visualPosition * parent.width
                height: parent.height
                radius: 1
                color: playSlider.enabled ? playSlider.visualColor : Colors.color_4B4B4B
            }
        }

        onValueChanged: {
            if (pressed) {
                controller.seekFrame(value);
            }
        }

        onPressedChanged: {
            if (playSlider.pressed) {
                lastPlayingStatus = controller.playing
                controller.pause();
            } else if (lastPlayingStatus) {
                controller.togglePlayState();
            }
        }
        Connections {
            target: controller
            function onPlayedFrameChanged(role) {
                playSlider.value = controller.playedFrame;
            }
        }
    }
}
}

    // ==================== 🛡️ 事件穿透防护层 ====================
    // 问题：播放器的 DragHandler 会捕获拖拽事件导致穿透
    // 解决：在控制面板添加自己的 DragHandler 抢占事件
    DragHandler {
        id: dragBlockerHandler
        target: null  // 不移动任何对象，只用于拦截
        dragThreshold: 0  // 立即激活，和播放器的 DragHandler 同步竞争
        grabPermissions: PointerHandler.CanTakeOverFromAnything  // 可以从任何 handler 抢占
    }
    // =========================================================
}
