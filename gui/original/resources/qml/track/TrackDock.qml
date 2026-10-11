import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Window 2.15
import QtQuick.Shapes 1.15
import Qt5Compat.GraphicalEffects
import TrackDockViewModel 1.0
import TrackHeadViewModel 1.0
import TrackHeadListViewModel 1.0
import MultiTrackView 1.0
import MultiTrackDataProvider 1.0
import MousePositionTracker 1.0
import AddOrDeleteFragmentController 1.0
import MultiSelectController 1.0
import Config 1.0
import Controls 1.0
import ShortcutAction 1.0
import "../tracking"
import "../controller"
import QTractorType 1.0
import LightRectangle 1.0
import KeyframeBtnViewModel 1.0
import KeyframeItemData 1.0
import MarkPointToolbarViewModel 1.0
import QPlayType 1.0
import SnappingTypeModel 1.0
import MediaTypeModel 1.0
import MediaListViewModel 1.0
import Qt.labs.platform 1.1
import PanoramaConfig 1.0
import "markPoint"
import Clipboard 1.0
import app_qrc 1.0
import UsedFunctionManager 1.0
import ProjectSettingsInfo 1.0
import PreviewTracker 1.0
import Nova 1.0
import VideoFragmentViewModel 1.0
Rectangle {
    id: root
    anchors.fill: parent
    visible: true
    color: Colors.color_content_area_background

    property alias multiTrackView: multiTrackView
    readonly property alias flickable: flickable
    // 轨道处于编辑状态 主要用于区分是否空轨状态(如果是拖拽添加过程中也算是编辑状态)
    readonly property bool isInEditeState: editorManager.isInEditeState || flickable.isUnderFickableDrag

    // 空轨首次添加素材时, scaleBase 会在同一次更新里被重算(见 RulerGear::updateTotalTimebase 的 firstAddData 分支),
    // 若立即显示真实轨道, 会先用未定稿的 scaleBase 渲染一帧宽度再自适应, 造成"闪一下"。
    // 这里把真实轨道的显示延后到 scaleBase 定稿之后(Qt.callLater 到本轮事件循环末尾), 用空轨占位遮住中间帧。
    // 拖拽添加走 isUnderFickableDrag 分支保持实时预览, 不受此延迟影响。
    property bool contentReady: false
    readonly property bool showTrackContent: contentReady || flickable.isUnderFickableDrag
    onIsInEditeStateChanged: {
        if (isInEditeState) {
            // 延后到本轮事件循环末尾, 此时 scaleBase 已定稿; 回调里重新判定状态, 避免同一 tick 内 true->false 抖动
            Qt.callLater(() => { if (root.isInEditeState) root.contentReady = true })
        } else {
            root.contentReady = false
        }
    }

    readonly property int fixBlankPx: Math.round(flickable.width / 4)

    // tk 片段选中态：选中 tk 片段时 Delete 只删 tk 片段，不删整段轨道片段。
    // 由 globalSignal.keyframeSelect(Tracking) 维护一组选中 segmentId(增删 tk 片段时 select 切换会回灌)。
    property var _selectedTkSegmentIds: ({})
    property bool hasSelectedTrackingFragment: false
    function clearTrackingSelection() {
        root._selectedTkSegmentIds = ({});
        root.hasSelectedTrackingFragment = false;
    }

    function getSelectItemRect() {
        return multiTrackView.getSelectItemRect()
    }

    function clearFragmentSelection() {
        trackViewModel.clearSelection()
        globalSignal.videoSelected(null)
    }

    // 轨道区域被按下时兜底退出素材预览，恢复被预览态置灰的时间指示器
    function ensureIndicatorInteractive() {
        if (previewAssetsManager.isPreviewing) {
            previewAssetsManager.forceExitPreview()
        }
    }

    // 音乐列表选中的音乐(做轨道的指针置灰逻辑)
    property string audioListSelectedPath: ""

    property int  oneFrameToTimes : 30000 / trackDockViewModel.fps
    property Item trackToastArea: trackToastArea

    property var selectedTrackViewItems: []  // 所有选中片段所在的轨道背景Item数组
    property int draggingTractorType: -1     // 拖拽时的轨道类型

    // 辅助函数：添加选中片段所在的轨道到高亮列表
    function addSelectedTrackItem(sourceModel) {
        multiTrackView.updateTrackBackgrounds()
        if (sourceModel !== null && sourceModel !== undefined) {
            rangeCompose.isSelectFragment = true
        }
    }

    Connections {
        target: globalSignal

        function onClearSelected() {
            multiTrackView.updateTrackBackgrounds()
            draggingTractorType = -1
            rangeCompose.isSelectFragment = false;
        }

        function onVideoSelected(sourceModel) {
            root.addSelectedTrackItem(sourceModel)
        }

        // 打开草稿恢复上次滚动位置: 绝对复位, 只触发一次, 不依赖片段委托生命周期。
        function onResumeScrollDistance(scrollDistance) {
            flickable.restoreScrollX(scrollDistance)
        }
    }

    Clipboard {
        id: clipboard
    }

    TrackDockViewModel {
        id: trackDockViewModel
        onShowHoverPreviewChanged: {
            let point = Qt.point(flickable.mouseX, flickable.mouseY);
            let isInClip = multiTrackView.isInFragmentAt(flickable.mapToItem(multiTrackView, point));
            let isInTrack = isInClip || flickable.containsMouse;
            globalSignal.showHoverPreviewChanged(showHoverPreview, isInTrack);
            if (editorManager.isEditorPlay()) {
                if (!showHoverPreview) {
                    if (!trackDockViewModel.playing) {
                        // 回到时间指示器位置
                        editorManager.seek(trackDockViewModel.indicatorFrame);
                    }
                } else {
                    // 重新刷新预览轴位置
                    if (flickable.containsMouse) {
                        seekByX(flickable.mouseX + flickable.contentX - coverRectangle.width, true);
                    }
                }
            }

            if(showHoverPreview){
                var visiblelog = {
                        "currentFrame": trackDockViewModel.currentFrame,
                        "indicatorFrame": trackDockViewModel.indicatorFrame,
                        "previewFrame": trackDockViewModel.previewFrame,
                        "totalFrame": trackDockViewModel.totalFrame,
                        "isEnterClip": multiTrackView.isEnterClip,
                        "isPressClip": multiTrackView.isPressClip,
                        "showHoverPreview": trackDockViewModel.showHoverPreview,
                        "playing": trackDockViewModel.playing,
                        "containsMouse": flickable.containsMouse,
                        "isDragging": multiTrackView.isDragging,
                        "indicatorEnabled": indicator.enabled,
                        "indicatorSeekDragging": indicatorSeek.isDragging,
                        "isClipping": multiTrackView.isClipping,
                        "multiIndicatorSeekDragging": multiIndicatorSeek.isDragging
                };

                logger.d("[PreviewIndicator] " + JSON.stringify(visiblelog, null, 2));
            }
        }
        property real previewFrame: 0
    }
    Component.onCompleted: {
        viewportManager.outputFps = trackDockViewModel.fps
        viewportManager.pxPerFrame = trackDockViewModel.scaleBase
        // 组件创建时若已处于编辑状态(如打开已有工程), scaleBase 已定稿, 直接显示真实轨道,
        // 否则会因 onIsInEditeStateChanged 不触发而导致轨道一直不显示。
        root.contentReady = isInEditeState
    }

    Connections {
        target: trackDockViewModel
        function onFpsChanged() {
            ViewportManager.outputFps = trackDockViewModel.fps
        }
        function onScaleBaseChanged() {
            ViewportManager.pxPerFrame = trackDockViewModel.scaleBase
        }
    }


    // 控件对应的 ViewModel
    KeyframeBtnViewModel {
        id: keyframeViewModel
        indicatorFrame: trackDockViewModel.indicatorFrame
        clipboard: clipboard
    }

    Column {
        id: trackToolsBar
        width: parent.width

        TrackToolsBar {
            id: trackTools
            width: parent.width
            height: 40
            trackInfo: trackDockViewModel
            indicatorFrame: trackDockViewModel.indicatorFrame
            keyFrameViewModel: keyframeViewModel
            isInEditeState: root.isInEditeState

            Connections {
                function onClickTrackingEntance() {
                    // 先让轨道滚动到光标位置
                    // var distance = trackDockViewModel.indicatorPosition() / multiTrackView.getPositionPxRatio() -
                    // multiTrackView.getVisibleRect().x;
                    // flickable.scrollBy(distance, 0);

                    // 多轨道,目前以唯一选中的全景视频进行追踪,不需要清空选中状态了
                }
            }
        }

        Rectangle {
            color: Colors.color_141414
            width: parent.width
            height: 1
        }
    }

    // toast显示区域
    Item {
        id: trackToastArea
        height: 64
        anchors {
            left: parent.left
            top: trackToolsBar.bottom
            right: parent.right
        }
    }

    Item {
        id: trackDockContent
        // 删除 width 和 height 属性，避免与 anchors 冲突
        // QML 中同时设置 anchors 和 width/height 是反模式
        enabled: root.isInEditeState

        anchors {
            left: parent.left
            top: trackToolsBar.bottom
            right: parent.right
            bottom: parent.bottom
        }
        clip: true

        // 被动监听轨道区域按下（不抢子控件的事件），用于兜底退出素材预览
        PointHandler {
            target: null
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onActiveChanged: {
                if (active) {
                    root.ensureIndicatorInteractive()
                }
            }
        }

        // 空轨状态
        TrackEmptyView {
            id: emptyContent

            anchors.fill: parent
            anchors.leftMargin: trackDockHeader.trackDockHeaderWidth

            visible: !root.showTrackContent
        }
        // 模拟滚动的容器
        TrackFlickable {
            id: flickable
            visible: root.showTrackContent
            anchors {
                left: trackDockHeader.right
                top: rulerRectangle.bottom
                right: parent.right
                bottom: parent.bottom
            }
            objectName: actionableItemName.trackdockFlickableArea

            scaleBase: trackDockViewModel.scaleBase
            rulerThresholdY: rulerRectangle.y + rulerRectangle.height + 5
            contentWidth: coverRectangle.width + multiTrackView.width + fixBlankPx
            contentHeight: multiTrackView.height
            isFragmentClipping: multiTrackView.isClipping
            // 拖拽排序的时候鼠标在 TrackFlickable 的坐标
            // (不能是 MultiTrackView 的坐标, 因为MultiTrackView 会根据缩放宽度进而变化,导致坐标不对)
            property point dragMousePoint: Qt.point(0, 0)
            // nova 素材拖拽(从素材区拖入)种类：0 无, 1 视频/图片, 2 音频, 3 文字；非 0 即拖入中
            property int novaMaterialDragKind: 0
            // nova 素材拖拽最近一次窗口坐标，供自动滚动时重放落位
            property point novaMaterialDragWindowPoint: Qt.point(0, 0)
            // 拖拽 (移动 | 添加) 是否在轨道上进行
            property bool isUnderFickableDrag: multiTrackView.isDragging  || multiTrackView.isDraggingMaterial || multiTrackView.novaDragClipId !== "" || novaMaterialDragKind !== 0
            // 拖拽期间屏蔽全局快捷键，覆盖轨道内拖片段与素材区拖入(视频/图片、音频、文字)
            onIsUnderFickableDragChanged: {
                ShortcutObserver.disableAllShortcut(isUnderFickableDrag)
            }
            // 轨道距离上下的间距
            property real trackSpacing: 15

            // 主要给其他控件提供基准
            Item {
                id: guidline
                anchors.fill: parent
            }

            onContentXChanged: {
                globalSignal.trackVisisbleLeftChanged(contentX)
                rangeCompose.scrollX = contentX;
                rangeCompose.updateRangeComposeViewLocation();
            }

            // 封面
            Rectangle {
                id: coverRectangle
                anchors {
                    left: guidline.left
                    top: guidline.top
                    bottom: guidline.bottom
                }
                width: 0 // 50

                color: Colors.color_transparent
            }

            Item {
                id: multiIndicatorSeek
                width: indicator.width
                height: Math.max(indicator.height, multiTrackView.height)

                property bool isDragging: false

                MouseArea {
                    id: dragSelectMouseArea
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    property real pressPointX: 0
                    property real pressPointY: 0
                    property real startX: 0
                    property real startY: 0
                    property real currentX: 0
                    property real currentY: 0
                    property bool isMove: false
                    property bool pressedOnRuler: false

                    property real tempPositon: 0
                    property bool isStartFromTopMainTrack: false
                    property bool isStartFromBottomMainTrack: false

                    onPressed: (mouse) => {
                       if (checkHoverIndicator()) {
                           return
                       }

                       multiIndicatorSeek.isDragging = true
                        isMove = false
                        pressedOnRuler = (flickable.mouseY + flickable.contentY) < 0
                        if (pressed) {
                            let point = mapToItem(multiIndicatorSeek, Qt.point(mouse.x, mouse.y));
                            pressPointX = mouse.x;
                            pressPointY = mouse.y;
                            startX = flickable.mouseX + flickable.contentX;
                            startY = flickable.mouseY + flickable.contentY;
                            currentX = startX;
                            currentY = startY;
                            isStartFromBottomMainTrack = false
                            isStartFromTopMainTrack = false
                            // 判断是否从顶部/底部固定轨道时开始拖拽
                            if(multiTrackView.scrollModel === 1) {
                                if(dragSelectMouseArea.y + dragSelectMouseArea.startY <= multiTrackView.visibleRect.y + mainVideoTrackHead.height){
                                    isStartFromTopMainTrack = true;
                                }
                            }
                            else if(multiTrackView.scrollModel === 2) {
                                if(dragSelectMouseArea.y + dragSelectMouseArea.startY >= multiTrackView.visibleRect.y + multiTrackView.visibleRect.height - mainVideoTrackHead.height){
                                    isStartFromBottomMainTrack = true;
                                }
                            }
                        }
                    }

                    onPositionChanged: (mouse) => {
                       if (checkHoverIndicator()) {
                           return
                       }
                        if (mouse.buttons === Qt.LeftButton) {
                            let point = mapToItem(multiIndicatorSeek, Qt.point(mouse.x, mouse.y));
                            currentX = startX + (mouse.x - pressPointX);
                            currentY = startY + (mouse.y - pressPointY);
                            if (!isMove) {
                                // 这是个手感的阈值, 太小了容易以为点击之后没有响应seek
                                let distance = 5;
                                isMove = Math.abs(currentX-startX) >= distance || Math.abs(currentY-startY) >= distance
                               if (isMove && !multiIndicatorScrollTimer.running) {
                                   multiIndicatorScrollTimer.start();
                               }
                            }
                        }
                    }

                    onReleased: {
                        if (checkHoverIndicator()) {
                            return
                        }
                        // 松手时，检测是否是点击行为，如果是则执行seek操作
                        if (!isMove) {
                            // pressed在刻度尺区域外才清空选中状态
                            if (!pressedOnRuler) {
                                trackViewModel.clearSelection();  // nova: 同步清空 nle 选中（取消片段高亮）
                                // 说明：选中集已为空时 clearSelection 不派发选中变化，标记高亮须显式清
                                MarkPointToolbarViewModel.clearSelectedMark();
                                globalSignal.multiSelectStateChanged(false);
                            }
                            var position = multiIndicatorSeek.x + parent.width / 2 - coverRectangle.width
                            const trackScaleBase = trackDockViewModel.scaleBase;
                            if (trackScaleBase <= 0) {
                                return;
                            }
                            position = Math.round(position / trackScaleBase) * trackScaleBase;
                            seekByX(position, false);
                            indicatorSeek.x = position - indicatorSeek.width/2

                            // 不要删除，这里只是一个保险措施，防止当前位置和seek位置一致，没有真正产生seek行为，从而没有正确更新的情况
                            trackDockViewModel.syncIndicator();
                            trackDockViewModel.previewFrame = trackDockViewModel.currentFrame;

                            KeyframeGuideViewModel.maybeRequestScatterKfGuide(trackDockViewModel.currentFrame);
                            // 拖动结束后更新仪表的添加状态
                            globalSignal.usedStickerChanged();

                            PreviewTracker.setUserSeek(true)

                        } else {
                            multiIndicatorScrollTimer.stop();
                        }
                        multiIndicatorSeek.isDragging = false
                    }
                }
            }

            Item {
                id: indicatorSeek
                width: indicator.width
                // 拖拽手柄需覆盖整个可滚动内容高度（与 multiIndicatorSeek 一致），
                // 否则轨道纵向滚动后手柄随内容移出视口，导致无法拖拽时间指示器。
                height: Math.max(indicator.height, multiTrackView.height)
                // z: 100//设置在范围导出上层，确保优先拖动指示器
                // 当鼠标在时间指示器上时，需要展示可滑动的鼠标样式，indicatorShadow用于跟随indicator的位置
                property real indicatorX: coverRectangle.width + indicator.indicatorPos - indicator.width / 2
                property real centerX: x + width / 2
                property bool showCursor: centerX >= indicatorX && centerX <= indicatorX + width
                // 按下的时候是否展示拖拽的鼠标样式, 用于点击空白区域是否取消轨道的选中状态
                property bool pressedShowCursor: false
                property bool isDragging: false
                property real curSnappingPos : -1   // 当前吸附点
                property bool isAdjustingX: false   // 吸附回写x时的防递归标志
                property int lastSeekFrame: -1      // 上次seek的帧，用于节流避免重复seek

                // 拖拽（含边缘自动滚动）时统一处理吸附 + seek。
                // 必须基于当前indicatorSeek.x计算，保证吸附状态与位置始终新鲜，避免拆分到
                // onPositionChanged导致的状态落后一帧与重复执行问题。
                function updateSeekByDrag() {
                    const trackScaleBase = trackDockViewModel.scaleBase;
                    if (trackScaleBase <= 0 || !editorManager.isEditorPlay()) {
                        return;
                    }
                    const epsilon = 1e-10;

                    let targetX = indicatorSeek.x;
                    indicatorSeek.curSnappingPos = -1;

                    if (multiTrackDataProvider.enableSnapping) {
                        const isScaleBaseZero = Math.abs(root.oneFrameToTimes * trackScaleBase) < epsilon;
                        const centerX = indicatorSeek.x + indicatorSeek.width / 2;
                        let pos = multiTrackDataProvider.getSnappingPos(SnappingOperateType.OPERATE_TIME_INDICATOR, centerX / trackScaleBase * root.oneFrameToTimes);
                        if (pos !== -1 && !isScaleBaseZero) {
                            // multiTrackView.x - (width / 2)是为了适配seek的实际位置
                            targetX = pos / root.oneFrameToTimes * trackScaleBase + multiTrackView.x - (indicatorSeek.width / 2);
                            indicatorSeek.curSnappingPos = targetX;
                            // 命中吸附时把指示器回写到吸附位置（防递归保护）
                            if (Math.abs(indicatorSeek.x - targetX) > epsilon) {
                                indicatorSeek.isAdjustingX = true;
                                indicatorSeek.x = targetX;
                                indicatorSeek.isAdjustingX = false;
                            }
                        }
                    }

                    const realX = targetX - multiTrackView.x + (indicatorSeek.width / 2);
                    let seekFrame = Math.round(realX / trackScaleBase);
                    seekFrame = Math.min(Math.max(seekFrame, 0), trackDockViewModel.totalFrame);

                    // 目标帧未变化就不重复seek
                    if (seekFrame !== indicatorSeek.lastSeekFrame) {
                        editorManager.seek(seekFrame);
                        indicatorSeek.lastSeekFrame = seekFrame;
                    }

                    // 不要删除，这里只是一个保险措施，防止当前位置和seek位置一致，没有真正产生seek行为，从而没有正确更新的情况
                    trackDockViewModel.syncIndicator();
                    if (!indicatorScrollTimer.running) {
                        indicatorScrollTimer.start();
                    }
                }

                MouseArea {
                    id: indicatorArea
                    anchors.fill: parent
                    propagateComposedEvents: true
                    drag {
                        axis: Drag.XAxis
                        target: parent
                        threshold: 0

                        // 指针不能拖动超轨道边缘
                        // 因为指针有一定的宽度，所以指针指向的位置到底是什么地方，这个计算要统一，目前先都按照width/2来计算吧
                        minimumX: multiTrackView.x + flickable.contentX - indicator.width / 2 - (Math.min(multiTrackView.x, flickable.contentX))
                        maximumX: flickable.contentX + flickable.width - (indicator.width - indicator.width / 2)
                    }
                    hoverEnabled: true
                    onEntered: {
                        rangeCompose.allowInRangeComposeDrag = false;
                        rangeCompose.allowOutRangeComposeDrag = false;
                    }
                    onExited: {
                        rangeCompose.allowInRangeComposeDrag = true;
                        rangeCompose.allowOutRangeComposeDrag = true;
                    }
                    // 响应拖动事件
                    // 吸附 + seek 已统一在 indicatorSeek.updateSeekByDrag() 中处理，
                    // 由 onXChanged 在 x 变化（drag 写入 / 自动滚动）时调用，保证状态新鲜。
                    onPositionChanged: (mouse) => {
                        if (!checkHoverIndicator()) {
                            return
                        }
                    }
                    Connections {
                        target: indicatorArea.drag
                        function onActiveChanged() {
                            if (!indicatorArea.drag.active) {
                                indicatorScrollTimer.stop();
                            } else {
                                // 每次新拖拽重置，保证首帧必定 seek
                                indicatorSeek.lastSeekFrame = -1;
                            }
                            indicatorSeek.isDragging = indicatorArea.drag.active;
                        }
                    }

                    states: State {
                        // 拖动标记时鼠标路过指示器线不应变成指示器(SizeHor)样式：标记拖动期 previewIndicator.isMarkPreviewing 为真，
                        // 此时即便光标落在 indicatorArea 上(时间轴标记停在标记带、光标却下探到轨道区指示器线)也不切指示器样式
                        when: (indicatorArea.drag.active || indicatorSeek.showCursor) && !previewIndicator.isMarkPreviewing
                        PropertyChanges {
                            target: indicatorArea
                            cursorShape: Qt.SizeHorCursor
                        }
                    }

                    // chengquan.li希望按下的时候就更新位置并能直接拖动关键帧，所以onPressed的时候就更新了位置
                    // 但其实这个逻辑应该会影响到后续片段多选的交互，那个时候应该会修改这里的实现
                    onPressed: (mouse) => {
                        if (!checkHoverIndicator()) {
                            multiIndicatorSeek.x = indicatorSeek.x + parent.width / 2 - coverRectangle.width
                            return
                        }

                        if (pressed) {
                            indicatorSeek.pressedShowCursor = indicatorSeek.showCursor;
                        }
                    }

                    onReleased:{
                        if (!checkHoverIndicator()) {
                            return
                        }
                        KeyframeGuideViewModel.maybeRequestScatterKfGuide(trackDockViewModel.currentFrame);
                        // 拖动结束后更新仪表的添加状态
                        globalSignal.usedStickerChanged();
                        indicatorSeek.x =  trackDockViewModel.scaleBase * trackDockViewModel.currentFrame- indicatorSeek.width/2
                    }
                }

                onXChanged: {
                    // x 变化来源：drag 写入鼠标位置，或 indicatorScrollTimer 自动滚动写入。
                    // 统一走 updateSeekByDrag()，基于当前 x 做新鲜的吸附 + seek。
                    // isAdjustingX 用于跳过吸附回写 x 触发的递归调用。
                    if (indicatorSeek.isDragging && !indicatorSeek.isAdjustingX) {
                        indicatorSeek.updateSeekByDrag();
                    }
                }
            }

            // 轨道背景，用于定位多轨道的垂直中心
            Item {
                id: multiTrackViewBg
                width: parent.width
                height: Math.min(multiTrackView.height, parent.height)

                anchors.verticalCenter: guidline.verticalCenter
            }

            MultiTrackDataProvider{
                id: multiTrackDataProvider
                objectName: actionableItemName.multiTrackDataProvider
                enableSnapping: trackDockViewModel.autoSnapping
            }
            // nova: 轨道增删管理 VM（AddTrackCmd/DeleteTrackCmd/空轨回收）
            TrackViewModel {
                id: trackViewModel
            }
            // 多轨道整体的view
            MultiTrackView {
                id: multiTrackView
                objectName: actionableItemName.multitrackView
                property bool isEnterClip: false//这两个属性是为了记录片段是否处于裁剪状态
                property bool isPressClip: false
                property bool isDraggingMaterial: false
                // nova: 轨道内被拖片段的 nle NodeID(base64)，非空即拖动中，用于驱动自动滚动
                property string novaDragClipId: ""
                viewModel: multiTrackDataProvider
                anchors.left: coverRectangle.right
                anchors.top: multiTrackViewBg.top
                scaleBase: trackDockViewModel.scaleBase
                indicatorFrame: trackDockViewModel.indicatorFrame

                AddOrDeleteFragmentController{
                    id: addOrDeleteFragmentController
                    view: multiTrackView
                    viewModel: multiTrackDataProvider
                    clipboard: clipboard
                    indicatorFrame: trackDockViewModel.currentFrame
                    onHdrVideoAdded:(paths)=> {
                        projectStateController.checkHdrPopup(paths);
                    }
                }

                MultiSelectController {
                    id: multiSelectController
                    view: multiTrackView
                    viewModel: multiTrackDataProvider
                }

                Component.onDestruction:{
                    //解决转qt6之后关闭软件崩溃的问题，multiTrackView里的videoitem等对象会析构失败
                    console.log("MultItem is about to be destroyed");
                }

                // 测试数据，可见区域
                visibleRect: Qt.rect(-parent.x - x < 0 ? 0 : -parent.x - x, -parent.y, flickable.width - coverRectangle.width, flickable.height)
                isScrollClip: false
                width: trackDockViewModel.totalFrame * trackDockViewModel.scaleBase

                property int scrollClipArea : 30
                property int scrollClipSpeed: 10
                // 是否在拖拽排序中
                property bool isDragging: trackState === MultiTrackView.TRACK_STATE_DRAGGING
                // 是否在裁切中
                property bool isClipping: false

                onIsDraggingChanged: {
                    if (isDragging) {
                        scrollTimer.restart();
                    } else {
                        scrollTimer.stop();
                    }
                }
                // nova: 轨道内拖片段的自动滚动由 novaDragClipId 驱动(nova 路径不走 trackState/isDragging)
                onNovaDragClipIdChanged: {
                    if (novaDragClipId !== "") {
                        scrollTimer.restart();
                    } else {
                        scrollTimer.stop();
                    }
                }
                // 参考剪映: 片段右侧进行裁切时，如果轨道上所有片段的尾部在轨道3/4位置以内，且片段头部在可视区域之外时，裁切松手后，自动滚动轨道，使得轨道上片段的尾部位置位于轨道3/4处
                // 以上的操作同时解决了一个bug: 右侧裁切结束后，存在片段头部在可视区域外，但是轨道Flickable的滚动条不能滚动的问题
                function adjustFlickable(){
                    // 判断是否轨道上所有片段的尾部在轨道3/4位置以内，且片段头部在可视区域之外
                    if((editorManager.totalFrames() / 1000 * trackDockViewModel.scaleBase < (multiTrackView.visibleRect.x + fixBlankPx * 3)) && multiTrackView.visibleRect.x > 0){
                        var diff = (multiTrackView.visibleRect.x + fixBlankPx * 3) - editorManager.totalFrames() / 1000 * trackDockViewModel.scaleBase;
                        var adjust = Math.min(diff, multiTrackView.visibleRect.x);
                        flickable.scrollByX(-adjust);
                    }
                }
                //字幕贴纸片段布局
                overlayItemDelegate: OverlayItemView {
                    id: overlayItem
                    fragmentInfo: modelData
                    trackIndex: track_index
                    clipIndex: clip_index
                    pxPerFrame: trackDockViewModel.scaleBase
                    outputFps: trackDockViewModel.fps
                    trackVisibleLeft: multiTrackView.visibleRect.x
                    trackVisibleRight: multiTrackView.visibleRect.x + multiTrackView.visibleRect.width

                    property real startDragMouseX: 0  // 开始拖动时，鼠标的位置

                    // 右键菜单懒加载: 首次右键时创建, 关闭后销毁
                    Loader {
                        id: textOperatePopupLoader
                        active: false

                        function ensurePopup() {
                            active = true;
                            var overlay = textOperatePopupLoader.Overlay.overlay;
                            if (overlay) {
                                item.parent = overlay;
                            }
                            return item;
                        }

                        sourceComponent: Component {
                            FragmentOperatorPopUp {
                                curTrackIndex: overlayItem.trackIndex
                                curClipIndex: overlayItem.clipIndex
                                x: 0
                                y: 0
                                closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
                                Overlay.modal: Rectangle {
                                    color: Colors.transparent
                                }

                                onClosed: {
                                    textOperatePopupLoader.active = false;
                                }

                                onDeleteAllSelectFragment: {
                                    realDeleteAllSelectFragment()
                                }
                            }
                        }
                    }

                    onStartClip: {
                        // nova: 选中走 VM 的 nle selectedNodeIds（对齐 audio/video）。
                        // 被拖片段已在多选集合内时, 保留整组选区以支持整组裁切(选中数与整组入口同源 nle)
                        if(!(overlayItem.fragmentInfo.selected && TimelineEditController.selectedClipCount() > 1)){
                            overlayItem.fragmentInfo.selectExclusive();
                            overlayItem.fragmentInfo.selected = true;
                            globalSignal.multiSelectStateChanged(false)
                        }
                    }

                    onItemClicked: (isRightButton) =>  {
                        // nova: 选中走 VM 的 nle selectedNodeIds（与高亮 fragmentInfo.selected 同源），对齐 audio/video。
                        // 点击轨道叠加片段：若处于云相册主播放器临时预览态，先退出预览、切回时间轴
                        editorManager.exitCloudPreview(-1);
                        if (multiSelectController.isPressCommandKey() && !isRightButton) {
                            overlayItem.fragmentInfo.selected = !overlayItem.fragmentInfo.selected
                            globalSignal.multiSelectStateChanged(false)
                        } else if(overlayItem.fragmentInfo.selected){
                            return;
                        } else {
                            overlayItem.fragmentInfo.selectExclusive();
                            globalSignal.multiSelectStateChanged(false)
                        }
                    }

                    // nova: 文本整体移动走 nle（MoveClipCmd），与 audio 同一套类型无关链路。
                    // 拖动中本地预览（multiTrackView 内挪 item，不落内核），松手按鼠标终点解析目标轨/位置提交。
                    onItemDragMove: (point, isFirst) => {
                        let trackViewPoint = overlayItem.mapToItem(multiTrackView, point);
                        if (isFirst) {
                            editorManager.pause();
                            multiTrackView.novaDragClipId = overlayItem.fragmentInfo.clipNodeId;
                        }
                        // nova: 拖拽吸附(探针/查询/落位/吸附线)全在 novaClipDragMove(C++)，QML 不再算。
                        flickable.dragMousePoint = overlayItem.mapToItem(flickable, point);
                        multiTrackView.novaClipDragMove(overlayItem.fragmentInfo.clipNodeId, trackViewPoint, isFirst);
                    }
                    onItemDragRelease: (point, isCancel) => {
                        let trackViewPoint = overlayItem.mapToItem(multiTrackView, point);
                        multiTrackView.novaClipDragRelease(overlayItem.fragmentInfo.clipNodeId, trackViewPoint, isCancel);
                        multiTrackView.novaDragClipId = "";
                    }

                    onOpenOperatorPop:(windowPointX, windowPointY, isMediaLost, isSelectFile)  => {
                        textOperatePopupLoader.ensurePopup().showPop_Overlay(windowPointX, windowPointY, isMediaLost, isSelectFile);
                    }


                    Connections{
                        target: overlayItem

                        function onGetSnappingPosSig(pos){
                            if(multiTrackDataProvider.enableSnapping){
                                let snappingPos = multiTrackDataProvider.getSnappingPos(SnappingOperateType.OPERATE_CLIP_FRAGMENT, pos, QTractorType.overlay, overlayItem.trackIndex, overlayItem.clipIndex);
                                overlayItem.snappingPos = snappingPos;
                            }else{
                                overlayItem.snappingPos = -1;
                            }
                        }

                        function onIsSnappedChanged(){
                            multiTrackView.snappedChanged(overlayItem);
                        }
                        function onScrollClip(isScroll, isLeftClip, isScrollToLeft){
                            if(isScroll){
                                multiTrackView.isScrollClip = true;
                                overlayScrollClipTimer.isLeftClip = isLeftClip;
                                overlayScrollClipTimer.isScrollToLeft = isScrollToLeft;
                                overlayScrollClipTimer.isStopScroll = false;
                                overlayScrollClipTimer.start();
                            }else{
                                overlayScrollClipTimer.stop();
                                multiTrackView.isScrollClip = false;
                            }
                        }
                        function onFragmentChange(isLeftClip, isScroll, isClipping){
                            // 文本裁切提交由 OverlayItemView.finishDrag → fragmentInfo.commitTrim() 落 nle；
                            // 这里按 VM 本地预览值重排 + 邻居钳制。
                            TimelineEditController.relayoutPreview(overlayItem.fragmentInfo.clipNodeId);
                            if(!isClipping){
                                editorManager.seek(trackDockViewModel.indicatorFrame);
                                multiTrackView.adjustFlickable();
                            }
                            multiTrackView.isClipping = isClipping;

                            if(!isClipping){
                                indicator.isSnapped = false; // 时间指示器颜色恢复
                            }
                        }
                    }

                    // 滚动裁切定时任务
                    Timer{
                        id: overlayScrollClipTimer
                        interval: 10
                        repeat: true
                        triggeredOnStart: true
                        property bool isLeftClip : true // 是否时是片段左侧裁切
                        property bool isScrollToLeft : true // 面板是否向左滚动
                        property bool isStopScroll : false
                        onTriggered: {
                            let scrollLength = calScrollLength();
                            flickable.scrollByX(scrollLength);

                            fragmentClippedUpdate();
                            // 滚动裁切预览/提交由 overlayItem.*ScrollClipUpdate + finishDrag(commitTrim) 处理

                            if(isStopScroll){
                                overlayScrollClipTimer.stop();
                                // isStopScroll = false;
                            }
                        }

                        // 计算此次应该滚动的长度
                        function calScrollLength(){
                            let scrollLength = multiTrackView.scrollClipSpeed;
                            // 裁短方向(左手柄向右滚 / 右手柄向左滚)：步长收敛到剩余可裁长度，避免一步裁过最短 1 帧。
                            // 文本无源范围，可裁长度取时间线区间(length 为源域值，拖拽中不刷新)。
                            if(isLeftClip === isScrollToLeft){
                                let trimmableLength = ((overlayItem.fragmentInfo.trackFrameOut - overlayItem.fragmentInfo.trackFrameIn)
                                                       / overlayItem.oneFrameToTimes - 1) * overlayItem.pxPerFrame;
                                trimmableLength = Math.max(0, trimmableLength);
                                scrollLength = scrollLength < trimmableLength ? scrollLength : trimmableLength;
                            }

                            // 片段右侧滚动裁切(不包括右侧滚动恢复)， 且可视区域小于单次滚动的距离scrollClipSpeed
                            if(!isLeftClip && !isScrollToLeft && multiTrackView.visibleRect.x < multiTrackView.scrollClipSpeed){
                                let canScrollMaxLength = flickable.contentX; // 解决轨道头部滚动归零问题
                                scrollLength = scrollLength < canScrollMaxLength ? scrollLength : canScrollMaxLength;
                                isStopScroll = true;
                            }

                            scrollLength = isScrollToLeft ? scrollLength : -scrollLength;
                            return scrollLength;
                        }

                        // 更新被裁切片段的相关属性
                        function fragmentClippedUpdate(){
                            let leftScrollFixPos = multiTrackView.visibleRect.x + multiTrackView.visibleRect.width - scrollClipArea;
                            let rightScrollFixPos = multiTrackView.visibleRect.x + scrollClipArea;
                            let fixPos = isLeftClip ? leftScrollFixPos : rightScrollFixPos;

                            if(isLeftClip){
                                fixPos = isScrollToLeft ? leftScrollFixPos : multiTrackView.visibleRect.x;
                            }else{
                                fixPos = isScrollToLeft ?  multiTrackView.visibleRect.x + multiTrackView.visibleRect.width : rightScrollFixPos;
                            }

                            if(isLeftClip){
                                overlayItem.leftScrollClipUpdate(fixPos, isScrollToLeft);
                            }else{
                                overlayItem.rightScrollClipUpdate(fixPos, isScrollToLeft);
                            }
                        }
                    }

                }
                //视频片段布局
                videoItemDelegate: VideoItemView {
                    id: videoItem
                    objectName: "videoItem_track_" + trackIndex.toString() + "_clip_" + clipIndex.toString()
                    // viewModel 由 C++ 显式喂:新建走 createWithInitialProperties,复用走按片段缓存零重绑。
                    // 故此处不写 `viewModel: videoFragmentViewModel` 声明式绑定。
                    pxPerFrame: trackDockViewModel.scaleBase
                    property real startDragMouseX: 0  // 开始拖动时，鼠标的位置
                    outputFps: trackDockViewModel.fps
                    // 目前没有拖动，左可见边界只和滚动有关
                    visibleLeft: Math.max(0, flickable.contentX - coverRectangle.width - x)  + viewModel.stripOriginMk / oneFrameToTimes * pxPerFrame
                    visibleRight: Math.min(width, root.width - coverRectangle.width - trackDockHeader.width) + visibleLeft
                    trackIndex: track_index
                    clipIndex: clip_index
                    indicatorFrame: trackDockViewModel.indicatorFrame
                    trackVisibleLeft: multiTrackView.visibleRect.x
                    trackVisibleRight: multiTrackView.visibleRect.x + multiTrackView.visibleRect.width
                    scrollClipArea: multiTrackView.scrollClipArea
                    // 滤镜拖拽添加的时候是否是高亮状态, 默认没有设置此字段, 为(undefined)不高亮
                    showHighlight: typeof show_highlight === 'undefined' ? false : show_highlight
                    keyframeBtnViewModel: keyframeViewModel
                    // 反向拖动标记的吸附数据源
                    snappingProvider: multiTrackDataProvider

                    // 右键菜单懒加载: 首次右键时创建, 关闭后销毁
                    Loader {
                        id: fileOperatePopupLoader
                        active: false

                        function ensurePopup() {
                            active = true;
                            var overlay = fileOperatePopupLoader.Overlay.overlay;
                            if (overlay) {
                                item.parent = overlay;
                            }
                            return item;
                        }

                        sourceComponent: Component {
                            FragmentOperatorPopUp {
                                id: fileOperatePopup
                                curTrackIndex: videoItem.trackIndex
                                curClipIndex: videoItem.clipIndex
                                x: 0
                                y: 0
                                closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
                                Overlay.modal: Rectangle {
                                    color: Colors.transparent
                                }

                                onClosed: {
                                    fileOperatePopupLoader.active = false;
                                }

                                onRepalceMedia: {
                                    // 右键替换：暂存当前视频片段的 nle NodeID，供选定新素材后经 nle 原地替换。
                                    addOrDeleteFragmentController.beginRightClickReplace(videoItem.viewModel.clipNodeId);
                                    importFileDialog.curTrackIndex = fileOperatePopup.curTrackIndex;
                                    importFileDialog.curClipIndex = fileOperatePopup.curClipIndex;
                                    importFileDialog.open();
                                }

                                onLinkMediaClicked: {
                                    const tfInfo = videoItem.viewModel.getTrackingFileInfo();
                                    globalSignal.manualLinkMedia([tfInfo]);
                                }

                                onDeleteAllSelectFragment: {
                                    realDeleteAllSelectFragment()
                                }

                                onCopyKeyframe: {
                                    keyframeViewModel.copyOneSelectedKeyframe(true);
                                }

                                onPasteKeyframe: {
                                    keyframeViewModel.pasteOneSelectedKeyframe(true);
                                }

                                onShowInMediaLibrary: {
                                    var paths = editorManager.getSelectedFragmentsPaths();
                                    if (paths.length === 0) {
                                        paths = [videoItem.viewModel.path]
                                    }

                                    globalSignal.showInMediaLibrary(paths)
                                }

                                onComposeFragment: {
                                    //直接唤醒导出面板，show(1)标记为菜单入口
                                    logger.i("[Compose] onMenuClickExportAction");
                                    if (editorManager.isInEditeState) {
                                        if (!composeLoader.active) {
                                            composeLoader.active = true;
                                        }
                                        if (!composeLoader.item.visible) {
                                            playerPanel.controller.pause()
                                            //异步生成所选fragment封面
                                            draftManager.generateSelectFragmentCover();
                                            //显示对话框
                                            composeLoader.item.show(1)
                                            logger.i("[Compose] show compose panel");
                                        }
                                    } else {
                                        toast.showToast(qsTr("pccut_export_novideo"))
                                    }
                                }
                            }
                        }
                    }

                    // 片段被点击选中更新数据和UI， 其他的片段取消选中， 发送信号通知外部片段选中了

                    onItemClicked: (isRightButton) => {
                        // 点击轨道视频片段：若处于云相册主播放器临时预览态，先退出预览、切回时间轴
                        editorManager.exitCloudPreview(-1);
                        // @author ran.zheng @date 2026-06-29
                        // nova: 选中走 VM 的 nle selectedNodeIds（与高亮 viewModel.selected 同源）。
                        // NOVATODO 老选中系统(EditorManager/selectController)未同步，相关其他业务暂降级。
                        
                        // 点击素材(左键)清除标记选中态；拖动起始也会发 itemClicked(false)("先选中")，
                        // 此时 isDragging 已置 true，借此排除拖动，保证"拖动素材不取消标记选中"（右键也不取消）
                        if (!isRightButton && !videoItem.isDragging) {
                            MarkPointToolbarViewModel.clearSelectedMark();
                        }
                        if (multiSelectController.isPressCommandKey() && !isRightButton) {
                            videoItem.viewModel.selected = !videoItem.viewModel.selected;
                            globalSignal.multiSelectStateChanged(false)
                        } else if(videoItem.viewModel.selected){
                            return;
                        } else {
                            videoItem.viewModel.selectExclusive();
                        }
                    }

                    onItemDragMove: (point, isFirst) => {
                        let trackViewPoint = videoItem.mapToItem(multiTrackView, point);
                        flickable.dragMousePoint = videoItem.mapToItem(flickable, point);
                        if (isFirst) {
                            editorManager.pause();
                            multiTrackView.novaDragClipId = videoItem.viewModel.clipNodeId;
                        }
                        multiTrackView.novaClipDragMove(videoItem.viewModel.clipNodeId, trackViewPoint, isFirst);
                    }
                    onItemDragRelease: (point, isCancel) => {
                        let trackViewPoint = videoItem.mapToItem(multiTrackView, point);
                        multiTrackView.novaClipDragRelease(videoItem.viewModel.clipNodeId, trackViewPoint, isCancel);
                        multiTrackView.novaDragClipId = "";
                    }
                    // 点击鼠标开始裁剪，本片段设置为选中态， 其他的片段取消选中， 发送信号通知外部片段选中了
                    onStartClip: {
                        // 被拖片段已在多选集合内时, 保留整组选区以支持整组裁切(选中数与整组入口同源 nle)
                        if(!(videoItem.viewModel.selected && TimelineEditController.selectedClipCount() > 1)){
                            // nova: 独占选中走 VM 的 nle selectedNodeIds(与 onItemClicked 同源)；tk 片段选中态单独清除。
                            // 禁用 globalSignal.videoSelected(null)：它会清空素材选中并经
                            // TransitionManager.notifyTransitionSelected(-1,-1) 清掉 nle selectedNodeIds。
                            videoItem.viewModel.selectExclusive();
                            root.clearTrackingSelection();
                        }
                    }

                    Connections{
                        target: videoItem
                        function onFragmentChange(isHeadClip, isClipping, isScroll){
                            // 视频裁切提交由 VideoItemView.finishDrag → viewModel.commitTrim() 落 nle；
                            // 这里在拖拽中按 VM 本地预览值重排出预览。
                            TimelineEditController.relayoutPreview(videoItem.viewModel.clipNodeId);
                            // 裁切动作结束后，需要seek到时间指示器所指向的视频帧
                            if(!isClipping){
                                editorManager.clipSeek(indicator.indicatorPos / videoItem.pxPerFrame);
                                trackDockViewModel.indicatorFrameChanged();
                                multiTrackView.adjustFlickable();
                            }
                            multiTrackView.isClipping = isClipping;
                            globalSignal.fragmentClipping()
                        }

                        function onOpenOperatorPop(windowPointX, windowPointY, isMediaLost, isSelectFile, topasteKeyframe, composeFragmentValid){
                            fileOperatePopupLoader.ensurePopup().showPop_Video(windowPointX, windowPointY, isMediaLost, isSelectFile, topasteKeyframe, composeFragmentValid);
                        }

                        function onOpenOperatorPop_Keyframe(windowPointX, windowPointY, tocopy, topaste) {
                            fileOperatePopupLoader.ensurePopup().showPop_Keyframe(windowPointX, windowPointY, tocopy, topaste);
                        }
                    }

                    Connections{
                        target: videoItem
                        function onScrollClip(isScroll, isLeftClip, isScrollToLeft){
                            if(isScroll){
                                multiTrackView.isScrollClip = true;
                                scrollClipTimer.isLeftClip = isLeftClip;
                                scrollClipTimer.isScrollToLeft = isScrollToLeft;
                                scrollClipTimer.start();
                            }else{
                                scrollClipTimer.stop();
                                multiTrackView.isScrollClip = false;
                            }
                        }
                    }

                    Connections{
                        target: videoItem
                        function onGetSnappingPosSig(pos){
                            if(multiTrackDataProvider.enableSnapping){
                                let snappingPos = multiTrackDataProvider.getSnappingPos(SnappingOperateType.OPERATE_CLIP_FRAGMENT, pos, QTractorType.video, videoItem.trackIndex, videoItem.clipIndex);
                                videoItem.snappingPos = snappingPos;
                            }else{
                                videoItem.snappingPos = -1;
                            }
                        }

                        function onKeyFrameChange(){
                            if(multiTrackDataProvider.enableSnapping){
                                multiTrackDataProvider.updatePosByFragment(QTractorType.video, videoItem.trackIndex, videoItem.clipIndex, SnappingPosType.POS_KEY_FRAME);
                            }
                        }
                        function onTrackingChange(){
                            if(multiTrackDataProvider.enableSnapping){
                                multiTrackDataProvider.updatePosByFragment(QTractorType.video, videoItem.trackIndex, videoItem.clipIndex, SnappingPosType.POS_TRACKING);
                            }
                        }
                        function onRegionChange(){
                            if(multiTrackDataProvider.enableSnapping){
                                multiTrackDataProvider.updatePosByFragment(QTractorType.video, videoItem.trackIndex, videoItem.clipIndex, SnappingPosType.POS_KEY_FRAME);
                                multiTrackDataProvider.updatePosByFragment(QTractorType.video, videoItem.trackIndex, videoItem.clipIndex, SnappingPosType.POS_REGION);
                            }
                        }

                        function onMovementClipChange(){
                            if(multiTrackDataProvider.enableSnapping){
                                multiTrackDataProvider.updatePosByFragment(QTractorType.video, videoItem.trackIndex, videoItem.clipIndex, SnappingPosType.POS_KEY_FRAME);
                                multiTrackDataProvider.updatePosByFragment(QTractorType.video, videoItem.trackIndex, videoItem.clipIndex, SnappingPosType.POS_MOVEMENT);
                            }
                        }

                        function onIsSnappedChanged(){
                            if(multiTrackDataProvider.enableSnapping){
                                multiTrackView.snappedChanged(videoItem);
                            }
                        }
                    }

                    Connections {
                        target: globalSignal
                        function onTrackingStopAction(cancel) {
                            if(multiTrackDataProvider.enableSnapping){
                                multiTrackDataProvider.updatePosByFragment(QTractorType.video, videoItem.trackIndex, videoItem.clipIndex, SnappingPosType.POS_TRACKING);
                            }
                        }
                    }

                    // 滚动裁切定时任务
                    Timer{
                        id: scrollClipTimer
                        interval: 10
                        repeat: true
                        triggeredOnStart: true
                        property bool isLeftClip : true
                        property bool isScrollToLeft : true // 面板是否向左滚动
                        property bool isStopScroll : false
                        property int maxFrameOut: -1

                        onTriggered: {
                            let scrollLength = calScrollLength(); // todo: 需要在这里解决好最后一次裁切的问题，最后一次不足一次滚动时的case
                            flickable.scrollByX(scrollLength);
                            fragmentClippedUpdate();
                            // 滚动裁切预览/提交由 videoItem.*ScrollClipUpdate + finishDrag(commitTrim) 处理

                            if(isStopScroll){
                                scrollClipTimer.stop();
                                isStopScroll = false;
                            }
                        }

                        onRunningChanged: {
                            if (!running) {
                                maxFrameOut = -1;
                            }
                        }

                        // 计算此次应该滚动的长度
                        function calScrollLength(){
                            let canScrollLength  = (videoItem.viewModel.length / videoItem.oneFrameToTimes - 1) * videoItem.pxPerFrame;
                            let scrollLength = canScrollLength < multiTrackView.scrollClipSpeed ?  canScrollLength : multiTrackView.scrollClipSpeed;
                            canScrollLength = videoItem.viewModel.frameIn / videoItem.oneFrameToTimes * videoItem.pxPerFrame;

                            // 使用片段右侧裁切控件向左侧进行滚动才裁切时的边界case
                            if(!isLeftClip && !isScrollToLeft){
                                if(multiTrackView.visibleRect.x < multiTrackView.scrollClipSpeed){  // case1: 可视区域小于单次滚动的距离scrollClipSpeed
                                    let canScrollMaxLength = flickable.contentX; // 解决轨道头部滚动归零问题
                                    scrollLength = scrollLength < canScrollMaxLength ? scrollLength : canScrollMaxLength;
                                    isStopScroll = true;
                                }
                                if(videoItem.trackIndex == 0 && videoItem.clipIndex == 0 && videoItem.viewModel.length === videoItem.oneFrameToTimes){ // case2: 主轨道视频首片段裁切到小于等于一帧
                                    let canScrollMaxLength = flickable.contentX; // 解决轨道头部滚动归零问题
                                    scrollLength = scrollLength > canScrollMaxLength ? scrollLength : canScrollMaxLength;
                                    isStopScroll = true;
                                }
                            }
                            scrollLength = isScrollToLeft ? scrollLength : -scrollLength;
                            return scrollLength;
                        }

                        // 更新被裁切片段的相关属性
                        function fragmentClippedUpdate(){
                            if (maxFrameOut < 0) {
                                // nova: 源全长上限取自 VM(originLength)
                                maxFrameOut = videoItem.viewModel.originLength - 1;
                            }
                            let leftScrollFixPos = multiTrackView.visibleRect.x + multiTrackView.visibleRect.width - scrollClipArea;
                            let rightScrollFixPos = multiTrackView.visibleRect.x + scrollClipArea;
                            let fixPos = isLeftClip ? leftScrollFixPos : rightScrollFixPos;

                            if(isLeftClip){
                                fixPos = isScrollToLeft ? leftScrollFixPos : multiTrackView.visibleRect.x;
                            }else{
                                fixPos = isScrollToLeft ?  multiTrackView.visibleRect.x + multiTrackView.visibleRect.width : rightScrollFixPos;
                            }

                            if(isLeftClip){
                                videoItem.leftScrollClipUpdate(fixPos);
                            }else{
                                videoItem.rightScrollClipUpdate(fixPos, maxFrameOut, maxFrameOut);
                            }
                        }
                    }
                }
                //音频片段布局
                audioItemDelegate: AudioItemView {
                    id: audioItemView
                    objectName: actionableItemName.trackdockAudioFragment
                    property real startDragMouseX: 0  // 开始拖动时，鼠标的位置
                    // fragmentInfo 由 C++ 显式喂(创建:createWithInitialProperties;复用:setProperty),
                    // 故此处不再写 `fragmentInfo: modelData` 声明式绑定(与视频 viewModel 对称,规避池化复用时
                    // required property 绑定不随 context property 重算导致的串台/片段拖不动)。
                    pxPerFrame: trackDockViewModel.scaleBase
                    outputFps: trackDockViewModel.fps
                    visibleLeft: Math.max(0, flickable.contentX - coverRectangle.width - x)
                    visibleRight: Math.min(width, root.width - coverRectangle.width - trackDockHeader.width) + visibleLeft
                    // 反向拖动标记的吸附数据源
                    snappingProvider: multiTrackDataProvider
                    // 右键菜单懒加载: 首次右键时创建, 关闭后销毁
                    Loader {
                        id: audiofileOperatePopupLoader
                        active: false

                        function ensurePopup() {
                            active = true;
                            var overlay = audiofileOperatePopupLoader.Overlay.overlay;
                            if (overlay) {
                                item.parent = overlay;
                            }
                            return item;
                        }

                        sourceComponent: Component {
                            FragmentOperatorPopUp {
                                curTrackIndex: audioItemView.trackIndex
                                curClipIndex: audioItemView.clipIndex
                                x: 0
                                y: 0
                                closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
                                Overlay.modal: Rectangle {
                                    color: Colors.transparent
                                }

                                onClosed: {
                                    audiofileOperatePopupLoader.active = false;
                                }

                                onLinkMediaClicked: {
                                    const tfInfo = audioItemView.fragmentInfo.getTrackingFileInfo();
                                    globalSignal.manualLinkMedia([tfInfo]);
                                }

                                onDeleteAllSelectFragment: {
                                    realDeleteAllSelectFragment()
                                }
                            }
                        }
                    }
                    // 计算音频片段的右侧可视区域
                    function calVisibleRight() {
                        if(fragmentInfo === null){
                            return -1;
                        }

                        var visibleRight = Math.min(width, root.width - coverRectangle.width - trackDockHeader.width) + visibleLeft + editorManager.frameByPosition(fragmentInfo.frameIn) * pxPerFrame ;
                        if(audioItemView.visibleLeft > 0){
                            if(visibleRight - audioItemView.visibleLeft > root.width - coverRectangle.width - trackDockHeader.width){
                                visibleRight = root.width - coverRectangle.width - trackDockHeader.width + audioItemView.visibleLeft;
                            }
                        }
                        return visibleRight;
                    }
                    trackIndex: track_index
                    clipIndex: clip_index
                    trackVisibleLeft: multiTrackView.visibleRect.x
                    trackVisibleRight: multiTrackView.visibleRect.x + multiTrackView.visibleRect.width
                    onStartClip: {
                        // 被拖片段已在多选集合内时, 保留整组选区以支持整组裁切(选中数与整组入口同源 nle)
                        if(!(audioItemView.fragmentInfo.selected && TimelineEditController.selectedClipCount() > 1)){
                            audioItemView.fragmentInfo.selectExclusive();
                        }
                    }

                    onItemClicked: (isRightButton) => {
                        // 点击轨道音频片段：若处于云相册主播放器临时预览态，先退出预览、切回时间轴
                        editorManager.exitCloudPreview(-1);
                        // @author ran.zheng @date 2026-06-29
                        // 点击素材(左键)清除标记选中态；拖动起始也会发 itemClicked(false)("先选中")，
                        // 此时 isDragging 已置 true，借此排除拖动，保证"拖动素材不取消标记选中"（右键也不取消）
                        if (!isRightButton && !audioItemView.isDragging) {
                            MarkPointToolbarViewModel.clearSelectedMark();
                        }
                        if (multiSelectController.isPressCommandKey() && !isRightButton) {
                            audioItemView.fragmentInfo.selected = !audioItemView.fragmentInfo.selected
                            globalSignal.multiSelectStateChanged(false)
                        } else if(audioItemView.fragmentInfo.selected){
                            return;
                        } else {
                            audioItemView.fragmentInfo.selectExclusive();
                            globalSignal.multiSelectStateChanged(false)
                        }
                    }

                    onItemDragMove: (point, isFirst) => {
                        // nova: 音频片段整体移动走 nle（MoveClipCmd）。拖动中本地预览（multiTrackView 内挪 item），不落内核。
                        // 拖拽吸附(探针/查询/落位/吸附线)全在 novaClipDragMove(C++)，QML 不再算。
                        let trackViewPoint = audioItemView.mapToItem(multiTrackView, point);
                        if (isFirst) {
                            editorManager.pause();
                            multiTrackView.novaDragClipId = audioItemView.fragmentInfo.clipNodeId;
                        }
                        flickable.dragMousePoint = audioItemView.mapToItem(flickable, point);
                        multiTrackView.novaClipDragMove(audioItemView.fragmentInfo.clipNodeId, trackViewPoint, isFirst);
                    }
                    onItemDragRelease: (point, isCancel) => {
                        // nova: 松手按鼠标终点解析目标轨/位置 → MoveClipCmd + commit（单步 undo）。
                        let trackViewPoint = audioItemView.mapToItem(multiTrackView, point);
                        multiTrackView.novaClipDragRelease(audioItemView.fragmentInfo.clipNodeId, trackViewPoint, isCancel);
                        multiTrackView.novaDragClipId = "";
                    }

                    // 点击鼠标开始裁剪，本片段设置为选中态， 其他的片段取消选中， 发送信号通知外部片段选中了
                    Connections{
                        target: audioItemView
                        function onFragmentChange(isLeftClip, isScroll, isClipping){
                            // 音频裁切提交由 AudioItemView.finishDrag → fragmentInfo.commitTrim() 落 nle；
                            // 这里按 VM 本地预览值重排本片段。
                            TimelineEditController.relayoutPreview(audioItemView.fragmentInfo.clipNodeId);
                            if(!isClipping){
                                editorManager.seek(trackDockViewModel.indicatorFrame);
                                multiTrackView.adjustFlickable();
                            }
                            multiTrackView.isClipping = isClipping;

                            if(!isClipping){
                                indicator.isSnapped = false; // 时间指示器颜色恢复
                            }
                        }

                        function onGetSnappingPosSig(pos){
                            if(multiTrackDataProvider.enableSnapping){
                                let snappingPos = multiTrackDataProvider.getSnappingPos(SnappingOperateType.OPERATE_CLIP_FRAGMENT, pos, QTractorType.audio, audioItemView.trackIndex, audioItemView.clipIndex);
                                audioItemView.snappingPos = snappingPos;
                            }
                        }

                        function onIsSnappedChanged(){
                            multiTrackView.snappedChanged(audioItemView);
                        }

                        function onOpenOperatorPop(windowPointX, windowPointY, isMediaLost, isSelectFile, composeFragmentValid){
                            audiofileOperatePopupLoader.ensurePopup().showPop_Audio(windowPointX, windowPointY, isMediaLost, isSelectFile, composeFragmentValid);
                        }
                    }

                    Connections{
                        target: audioItemView
                        function onScrollClip(isScroll, isLeftClip, isScrollToLeft){
                            if(isScroll){
                                multiTrackView.isScrollClip = true;
                                audioScrollClipTimer.isLeftClip = isLeftClip;
                                audioScrollClipTimer.isScrollToLeft = isScrollToLeft;
                                audioScrollClipTimer.isStopScroll = false;
                                audioScrollClipTimer.start();
                            }else{
                                audioScrollClipTimer.stop();
                                multiTrackView.isScrollClip = false;
                            }
                        }
                    }

                    // 滚动裁切定时任务
                    Timer{
                        id: audioScrollClipTimer
                        interval: 10
                        repeat: true
                        triggeredOnStart: true
                        property bool isLeftClip : true // 是否时是片段左侧裁切
                        property bool isScrollToLeft : true // 面板是否向左滚动
                        property bool isStopScroll : false
                        property int maxFrameOut: -1

                        onTriggered: {
                            let scrollLength = calScrollLength();
                            flickable.scrollByX(scrollLength);

                            fragmentClippedUpdate();
                            // 滚动裁切预览/提交由 audioItemView.*ScrollClipUpdate + finishDrag(commitTrim) 处理

                            if(isStopScroll){
                                audioScrollClipTimer.stop();
                                // isStopScroll = false;
                            }
                        }

                        onRunningChanged: {
                            if (!running) {
                                maxFrameOut = -1;
                            }
                        }

                        // 计算此次应该滚动的长度
                        function calScrollLength(){
                            let canScrollLength = (audioItemView.fragmentInfo.length / audioItemView.oneFrameToTimes - 1) * audioItemView.pxPerFrame; // 可滚动裁切的最大长度
                            let scrollLength = canScrollLength < multiTrackView.scrollClipSpeed ?  canScrollLength : multiTrackView.scrollClipSpeed;

                            // 片段右侧滚动裁切(不包括右侧滚动恢复)， 且可视区域小于单次滚动的距离scrollClipSpeed
                            if(!isLeftClip && !isScrollToLeft && multiTrackView.visibleRect.x < multiTrackView.scrollClipSpeed){
                                let canScrollMaxLength = flickable.contentX; // 解决轨道头部滚动归零问题
                                scrollLength = scrollLength < canScrollMaxLength ? scrollLength : canScrollMaxLength;
                                isStopScroll = true;
                            }

                            scrollLength = isScrollToLeft ? scrollLength : -scrollLength;
                            return scrollLength;
                        }

                        // 更新被裁切片段的相关属性
                        function fragmentClippedUpdate(){
                            if (maxFrameOut < 0) {
                                // nova: 源全长上限取自 VM(originLength)
                                maxFrameOut = audioItemView.fragmentInfo.originLength - 1;
                            }
                            let leftScrollFixPos = multiTrackView.visibleRect.x + multiTrackView.visibleRect.width - scrollClipArea;
                            let rightScrollFixPos = multiTrackView.visibleRect.x + scrollClipArea;
                            let fixPos = isLeftClip ? leftScrollFixPos : rightScrollFixPos;

                            if(isLeftClip){
                                fixPos = isScrollToLeft ? leftScrollFixPos : multiTrackView.visibleRect.x;
                            }else{
                                fixPos = isScrollToLeft ?  multiTrackView.visibleRect.x + multiTrackView.visibleRect.width : rightScrollFixPos;
                            }

                            if(isLeftClip){
                                audioItemView.leftScrollClipUpdate(fixPos, isScrollToLeft);
                            }else{
                                audioItemView.rightScrollClipUpdate(fixPos, maxFrameOut, isScrollToLeft);
                            }
                        }
                    }
                }

                //轨道背景的填充view
                trackDelegate: Rectangle {
                    radius: 0
                    color: root.celectedTrackType === trackType ? ColorsConfig.color_track_dock_line_background_selected : ColorsConfig.color_track_dock_line_background_normal
                    property bool showBorders: false
                    // 上黑边
                    Rectangle {
                        anchors {
                            top: parent.top
                            left: parent.left
                            right: parent.right
                        }
                        height: 1
                        color: Colors.color_141414
                        visible: showBorders
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
                        visible: showBorders
                    }
                }

                // 拖拽添加的占位
                dragAddItemDelegate: TrackAddItemView {
                    id: trackAddItemView
                    pxPerFrame: trackDockViewModel.scaleBase
                    showName: show_name
                    frameLength: file_frame_length
                    color: bg_color
                    textColor: {
                        switch(fragmentType) {
                        case QTractorType.audio: {
                            return ColorsConfig.color_9D92F3_68AAFC
                        }
                        case QTractorType.video: {
                            return ColorsConfig.color_78A7EC_78E5DE
                        }
                        case QTractorType.overlay:{
                            return ColorsConfig.color_95FCEB_95FCEB
                        }
                        }
                    }
                }

                // 轨道拖动时候的投影
                placeholderDelegate: PlaceholderItemView {
                    shadowType: {
                        switch(trackType) {
                        case QTractorType.audio: {
                            return MultiTrackView.Audio
                        }
                        case QTractorType.video: {
                            return MultiTrackView.Video
                        }
                        case QTractorType.overlay: {
                            return MultiTrackView.Text
                        }
                        }
                    }
                }

                // 轨道新增提示线
                trackAddIndicatorDelegate: Rectangle {
                    height: 1
                    color: Colors.color_F22443
                    visible: false
                }

                // 随吸附状态变化更改吸附线和时间指示器的状态
                function snappedChanged(itemView){
                    // 更改时间时间指示器的状态
                    if(itemView.isSnapped){
                        if(itemView.snappingPos === indicator.indicatorPos / trackDockViewModel.scaleBase * itemView.oneFrameToTimes){ // 判断是否吸附在时间指示器上
                            indicator.isSnapped = true;
                        }
                    }else{
                        indicator.isSnapped = false;
                    }
                    // 更改吸附线的状态
                    if(!indicator.isSnapped){
                        snappingLine.visible = itemView.isSnapped;
                        snappingLine.indicatorPos = itemView.snappingPos / itemView.oneFrameToTimes * trackDockViewModel.scaleBase;
                    }else{
                        snappingLine.visible = false;
                        snappingLine.indicatorPos = -1;
                    }
                }

                onScrollVisiableForFrame: (position, itemHeight) => {
                    if (position.x >= 0 || position.y >= 0) {
                        let rectX = position.x * trackDockViewModel.scaleBase;
                        let rectTop = position.y;
                        let rectBottom = position.y + itemHeight;
                        let scrollX = 0, scrollY = 0;
                        // 判断是否在轨道上展示
                        if (rectX < flickable.contentX || rectX > (flickable.contentX + flickable.width)) {
                            // 滚动到中间
                            scrollX = rectX - flickable.width / 2 - flickable.contentX;
                        }
                        // 主轨道视频片段rectTop一直是0(itemHeight 也为 0)；其余轨判断整条轨是否完全可见——
                        // 不仅看顶部(rectTop)，也看底部(rectBottom)，避免片段顶部在视口内但底部被裁导致只露一部分。
                        // 固定主轨道头(mainVideoTrackHead)会遮挡视口顶部，故可视上边界下移 head 高度。
                        let visTop = flickable.contentY + mainVideoTrackHead.height;
                        let visBottom = flickable.contentY + flickable.height;
                        if (rectTop > 0 && (rectTop < visTop || rectBottom > visBottom)) {
                            // 把目标轨顶部对齐到固定主轨道头下方(+5px 留白)，整条轨完全露出
                            scrollY = rectTop - mainVideoTrackHead.height - flickable.contentY + 5;
                        }
                        // 滚动
                        if (scrollX !== 0 || scrollY !== 0) {
                            flickable.scrollWith(scrollX, scrollY);
                        }
                    }
                }

                Connections {
                    target: globalSignal

                    function onTrackScrollByX(distance, isMoving) {
                        flickable.dragMousePoint.x = distance
                        if (!isMoving) {
                            flickable.isUnderFickableDrag = false;
                            multiTrackView.isDragging = false;
                            scrollTimer.stop()
                        } else {
                            if (!scrollTimer.running) {
                                flickable.isUnderFickableDrag = true;
                                multiTrackView.isDragging = true;
                                scrollTimer.restart()
                            }
                        }
                    }

                    // 素材移除列表
                    function onRemoveFileFromList(fileInfos) {
                        // 暂停播放
                        editorManager.pause();
                        // 在数据、底层、UI上删除
                        TimelineEditController.deleteByPaths(fileInfos);
                        editorDraftManager.saveDraft();
                    }

                    function onMediaSelected(selectedPaths) {
                        if (selectedPaths.length !== 0) {
                            trackViewModel.clearSelection();
                            globalSignal.videoSelected(null);
                        }
                    }
                    function onAudioPlayerSelected(selectPath) {
                        audioListSelectedPath = selectPath;
                    }

                    // 取消轨道的选中状态
                    function onCleanTrackSelectState() {
                        root.clearTrackingSelection();
                        trackViewModel.clearSelection();
                        globalSignal.videoSelected(null);
                    }

                    function onRemoveTrackingFragmentFail() {
                        // 收到这个信号表示删除tracking片段失败了，即当前时间指示器没有指向tracking片段
                        editorManager.pause();
                        TimelineEditController.deleteSelected();
                        // 刷新总时长
                        editorManager.syncTotalFrames(true);
                        // 更新草稿
                        editorDraftManager.saveDraft();
                    }
                    function onVideoSelected(fragment){
                        // nova: nle 选中由发起方经 selectExclusive/setSelectedNodeIds 落（片段 VM 回灌高亮），
                        // 此处仅联动 tk 选中清理与老 fm 置选（fm 高亮已不驱动 nova，仅老面板读态）。
                        if (fragment === null) {
                            root.clearTrackingSelection();
                        }
                        if(fragment !== null){
                            fragment.selected = true;
                        }
                    }

                    // 维护 tk 片段选中态：选中/取消选中 tk 片段时回灌，供 Delete 判断删 tk 还是删轨道片段。
                    function onKeyframeSelect(itemData, isPlaying) {
                        if (CommonUtils.isNull(itemData) || itemData.dataType !== KeyframeItemData.Tracking) {
                            return;
                        }
                        if (itemData.select) {
                            root._selectedTkSegmentIds[itemData.segmentId] = true;
                        } else {
                            delete root._selectedTkSegmentIds[itemData.segmentId];
                        }
                        root.hasSelectedTrackingFragment = Object.keys(root._selectedTkSegmentIds).length > 0;
                    }

                    property MaterialReplaceWindow replaceDialog: null
                    function onReplaceMediaInFragment(newPath, length, targetLength, frameIn, isImage, isPanoramaImage, isImageToPanorama, isVideoToPanorama, isTooShort, isRightClick, isSameLength){
                        if(isTooShort){
                            var method = isRightClick ? "right_click" : "drag";
                            eventTracker.trackEvent("pccut_audio_replace", {"use_method": method, "replace_result": "too_short"});
                            toast.showToast(qsTr("pccut_replace_clip_too_short"), "tracks");
                            return;
                        }

                        if (CommonUtils.isNull(replaceDialog))
                        {
                            var component = Qt.createComponent("MaterialReplaceWindow.qml");
                            if (component.status === Component.Ready) {
                                replaceDialog = component.createObject(root);
                            }
                        }

                        if (!CommonUtils.isNull(replaceDialog)){
                            replaceDialog.mediaPath = newPath;
                            replaceDialog.mediaLength = length;
                            replaceDialog.fragmentLength = targetLength;
                            replaceDialog.newMediaIsImage = isImage;
                            replaceDialog.mediaIsPanoramaImage = isPanoramaImage;
                            replaceDialog.isImageToPanorama = isImageToPanorama;
                            replaceDialog.isVideoToPanorama = isVideoToPanorama;
                            replaceDialog.startFrameIn = frameIn;
                            replaceDialog.isRightClick = isRightClick;
                            replaceDialog.isSameLength = isSameLength;
                            if(!replaceDialog.signalsConnected) {
                                replaceDialog.replaceMedia.connect(function(isReuse, frameIn) {
                                    // nova: 拖拽替换与右键替换统一走 nle(confirmDragReplace)；右键目标由 beginRightClickReplace 暂存。
                                    addOrDeleteFragmentController.confirmDragReplace(isReuse, frameIn);
                                    var method = replaceDialog.isRightClick ? "right_click" : "drag";
                                    var result = replaceDialog.isSameLength ? "equal" : "cut";
                                    eventTracker.trackEvent("pccut_audio_replace", {"use_method": method, "replace_result": result});
                                });
                                replaceDialog.signalsConnected = true;
                            }
                            replaceDialog.show();

                            clipPreviewPlayerManager.setClipByMedia(newPath, frameIn, length, isImage);
                            // 每次预览新素材都刷新显示尺寸（共用 detached env，9:16 素材覆盖上次 16:9 时避免拉伸）
                            replaceDialog.updateDisplayViewSize();
                            clipPreviewPlayerManager.play();
                        }
                    }
                }
            }

            // 轨道上手势拖拽滑框控件
            Rectangle {
                id: bgSelectionRect
                color: Colors.color_FFFFFF_10
                radius: 2
                border.width: 1
                border.color: Colors.color_FFFFFF_20
                visible: dragSelectMouseArea.pressed
                x: Math.min(dragSelectMouseArea.startX, dragSelectMouseArea.currentX)
                width: Math.abs(dragSelectMouseArea.startX - dragSelectMouseArea.currentX)
                y: Math.min(dragSelectMouseArea.startY, dragSelectMouseArea.currentY)
                height: Math.abs(dragSelectMouseArea.startY - dragSelectMouseArea.currentY)
                onWidthChanged: {
                    refreshDragSelect();
                }

                onHeightChanged: {
                    refreshDragSelect();
                }

                function refreshDragSelect() {
                    // 判定一定是鼠标拖拽画框的过程中
                    if (!bgSelectionRect.visible || !dragSelectMouseArea.pressed) {
                        return;
                    }
                    // selectRect 需要映射到 MultiTrackView 的坐标系
                    const selectRect = Qt.rect(bgSelectionRect.x,
                                               bgSelectionRect.y - multiTrackView.y,
                                               bgSelectionRect.width, bgSelectionRect.height);
                    // 内部自动遍历所有轨道，计算坐标交集并选中相交片段
                    // nova: 框选走 nle（与单击/高亮同源）；老 multiSelectController.dragSelect 不再驱动 nle。
                    multiTrackView.dragSelectNle(selectRect);
                }
            }
        }

        // 刻度尺
        TrackRuler {
            id: rulerRectangle
            visible: root.isInEditeState
            anchors.left: flickable.left
            anchors.right: flickable.right
            anchors.rightMargin: 10
            height: 24
            scaleBase: trackDockViewModel.scaleBase
            groupSlots: trackDockViewModel.gearPos.groupSlots
            slotFrames: trackDockViewModel.gearPos.slotFrames
            scrollX: flickable.contentX
            paddingLeft: coverRectangle.width
            clip: true
        }
        
        // 刻度尺顶部的鼠标交互区域，支持点击和拖拽播放头
        Item {
            id: rulerMouseAreaContainer
            anchors.fill: rulerRectangle

            property bool isDragging: false
            property real pressX: 0

            MouseArea {
                id: rulerMouseArea
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                hoverEnabled: true

                property bool hasPositionChanged: false

                onPressed: (mouse) => {
                    indicatorSeek.isDragging = true
                    indicatorSeek.lastSeekFrame = -1   // 重置节流，保证本次交互首帧必定 seek
                    hasPositionChanged = false
                    rulerMouseAreaContainer.pressX = mouse.x

                    // 点击刻度尺(移动播放头)取消标记单选，与点击轨道空白处同口径
                    MarkPointToolbarViewModel.clearSelectedMark()

                    ShortcutObserver.disableAllShortcut(true)
                }

                onPositionChanged: (mouse) => {
                    if (mouse.buttons === Qt.LeftButton) {
                        hasPositionChanged = true
                        indicatorSeek.isDragging = true

                        // 计算新的播放头位置
                        // mouse.x 是相对于 rulerMouseArea 的坐标
                        // 需要转换为 timeline 坐标
                        const newX = mouse.x
                        const timelineX = newX + flickable.contentX - coverRectangle.width
                        // 仅更新 indicatorSeek.x，由 onXChanged -> updateSeekByDrag() 统一处理吸附 + seek，
                        // 与拖动指示器手柄走同一套逻辑，刻度尺拖拽即可获得一致的吸附效果。
                        indicatorSeek.x = timelineX - indicatorSeek.width/2
                    }
                }

                onReleased: (mouse) => {
                    // 先结束拖拽状态，保证纯点击 seek 走精确位置（不吸附）
                    indicatorSeek.isDragging = false
                    if (!hasPositionChanged) {
                        // 纯点击行为，seek 到点击位置（精确，不吸附）
                        const clickX = mouse.x
                        const timelineX = clickX + flickable.contentX - coverRectangle.width
                        seekByX(timelineX)
                        indicatorSeek.x = timelineX - indicatorSeek.width/2

                        trackDockViewModel.syncIndicator()
                        trackDockViewModel.previewFrame = trackDockViewModel.currentFrame
                    }
                    // 无论点击还是拖拽结束，都刷新全景媒体首帧编辑（与拖动指示器手柄的收尾保持一致）
                    KeyframeGuideViewModel.maybeRequestScatterKfGuide(trackDockViewModel.currentFrame)
                    globalSignal.usedStickerChanged()

                    ShortcutObserver.disableAllShortcut(false)
                    indicatorScrollTimer.stop();
                }

                onExited: {
                    indicatorSeek.isDragging = false
                }

                onCanceled: {
                    indicatorSeek.isDragging = false
                    ShortcutObserver.disableAllShortcut(false)
                    indicatorScrollTimer.stop();
                }
            }
        }

        RangeCompose {
            id: rangeCompose
            anchors {
                left: trackDockHeader.right
                top: parent.top
                right: parent.right
            }
            height: parent.height - flickable.scrollBarHeight
            scrollX: flickable.contentX
            contentWidth: Math.max(flickable.contentWidth, parent.width)
            paddingLeft: trackDockHeader.width + coverRectangle.width
            scaleBase: trackDockViewModel.scaleBase
            enableRangeCompose: trackDockViewModel.rangeComposeEnable
            inRangeCompose: trackDockViewModel.rangeComposeIn
            outRangeCompose: trackDockViewModel.rangeComposeOut
            totalFrame: trackDockViewModel.totalFrame
            fps: trackDockViewModel.fps
            indicatorX: indicatorSeek.x
            visible: trackDockViewModel.rangeComposeEnable
            // 高于时间轴标记带(timelineMarkClip z:60)，低于播放头(indicator z:62)
            z: 61
            Connections {
                target: rangeCompose

                // 范围导出入/出点吸附标记点：经自动吸附系统查最近标记(只吸标记，关吸附/未命中返回 -1)，命中则落到标记帧。
                function snapRangeFrameToMark(frame) {
                    if (trackDockViewModel.scaleBase <= 0) { return frame; }
                    let pos = multiTrackDataProvider.getSnappingPos(SnappingOperateType.OPERATE_DRAG_RANGE_COMPOSE, frame * root.oneFrameToTimes);
                    return pos < 0 ? frame : Math.round(pos / root.oneFrameToTimes);
                }

                function onRangeComposeInUpdate(newRangeInFrame) {
                    if (!rangeComposeInScrollTimer.running) {
                        rangeComposeInScrollTimer.start();
                    }
                    newRangeInFrame = Math.min(snapRangeFrameToMark(newRangeInFrame), trackDockViewModel.rangeComposeOut);
                    trackDockViewModel.rangeComposeIn = newRangeInFrame;
                    // rangeComposeScroll(rangeCompose.inRangeCompose);
                    //发送范围导出入点位置变化，范围导出控件才会变化
                    trackDockViewModel.isRangeComposeChanged();
                }
                function onRangeComposeOutUpdate(newRangeOutFrame) {
                    if (!rangeComposeOutScrollTimer.running) {
                        rangeComposeOutScrollTimer.start();
                    }
                    newRangeOutFrame = Math.max(snapRangeFrameToMark(newRangeOutFrame), trackDockViewModel.rangeComposeIn);
                    trackDockViewModel.rangeComposeOut = newRangeOutFrame;
                    // rangeComposeScroll(rangeCompose.outRangeCompose);
                    trackDockViewModel.isRangeComposeChanged();
                }

                function onRangeComposeInDrag(newRangeInFrame) {
                    var params = {"subActionCode": 4, "rangeIn": newRangeInFrame};
                    trackDockViewModel.changeRangeComposeByManual(params)
                    if (rangeComposeInScrollTimer.running) {
                        rangeComposeInScrollTimer.stop();
                    }
                }
                function onRangeComposeOutDrag(newRangeOutFrame) {
                    var params = {"subActionCode": 5, "rangeOut": newRangeOutFrame};
                    trackDockViewModel.changeRangeComposeByManual(params)
                    if (rangeComposeOutScrollTimer.running) {
                        rangeComposeOutScrollTimer.stop();
                    }
                }

                function onRangeComposeEnableChanged(newRangeEnable) {
                    var params = {"subActionCode": 3};
                    trackDockViewModel.changeRangeComposeByManual(params)
                }
            }
        }

        Connections {
            target: trackDockViewModel

            function onRulerDataChanged() {
                rulerRectangle.refreshData();
            }

            function onIsRangeComposeChanged() {
                //更新View控件的边界值
                rangeCompose.updateRangeComposeViewLocation();
            }
        }

        // 时间轴标记带
        Item {
            id: timelineMarkClip
            anchors.left: trackDockHeader.right
            anchors.right: parent.right
            // 底边锚刻度尺底：标记带压在刻度尺上、随刻度尺增高一并下移(内部 Ribbon bottomAligned 保持贴容器底)
            anchors.bottom: rulerRectangle.bottom
            anchors.bottomMargin: 0
            height: 18
            clip: true
            // 素材清空、时间轴隐藏时一并隐藏
            visible: root.isInEditeState
            // 高于 rulerMouseAreaContainer(z:50)，低于范围导出(z:61)与播放头(indicator z:62)
            z: 60

            MarkPointRibbon {
                id: timelineMarkRibbon
                timelineHost: true
                pxPerFrame: trackDockViewModel.scaleBase
                height: parent.height
                x: coverRectangle.width - flickable.contentX
                // 底对齐：图标贴容器(18px)底部，与 Audio/VideoItemView 用 bottomAligned 同口径
                // 距底的上移由容器 anchors.bottomMargin 单点控制，此处 ribbon 不再叠 y 偏移
                bottomAligned: true
                width: trackDockViewModel.totalFrame * trackDockViewModel.scaleBase + coverRectangle.width
                // 拖动标记贴边时横向自动滚动
                scroller: flickable
                // 反向拖动吸附数据源
                snappingProvider: multiTrackDataProvider
                // 注入时间指示器：标记与指示器拖动头重叠时让位给指示器(见 MarkPointItem.isOnTimeIndicator)
                indicatorItem: indicator
                // playing 有意不绑定：播放中允许拖动，拖动起始由 MarkPointItem.onDraggingChanged 显式调 editorManager.pause() 暂停，绑定 playing 反而会禁止这一交互。
                // playing 属性保留为可选硬防护（如需"播放中禁止拖动"可一行绑定生效）。
            }

            // 整条标记带(全视口，含素材末尾之后的空白)悬停驱动预览轴，与轨道行(flickable 全视口 mouseHandler)一致：
            // 标记带在刻度尺之上、不属于 flickable，通用悬停预览覆盖不到，故在此整条带全视口自驱。
            // 用全视口 HoverHandler(非阻断、不抢按下，刻度尺播放头拖拽仍穿透)，落帧换算与 onMouseXChanged 同口径。
            HoverHandler {
                id: timelineBandHover
                onHoveredChanged: {
                    if (!hovered) {
                        timelineMarkRibbon.clearBandPreview();
                    }
                }
            }
            // 光标所在显示帧(全局帧)：position.x 为本带视口局部坐标，−cover+contentX 还原到内容帧，与轨道行换算一致。
            // 离带置 -1；变化即驱动预览轴(含 totalFrame 之外，落帧 > totalFrame 时 previewIndicator.isValidFrame 仍成立)。
            readonly property real bandCursorFrame: timelineBandHover.hovered
                ? Math.round((timelineBandHover.point.position.x - coverRectangle.width + flickable.contentX) / trackDockViewModel.scaleBase)
                : -1
            onBandCursorFrameChanged: {
                if (timelineBandHover.hovered) {
                    timelineMarkRibbon.driveBandPreview(bandCursorFrame);
                }
            }
        }

        // 预览轴指示器
        Rectangle {
            id: previewIndicator
            property real indicatorPos: trackDockViewModel.scaleBase * trackDockViewModel.previewFrame
            width: 1
            height: parent.height - 12
            // 高于时间轴标记带(timelineMarkClip z:60)，低于播放头(indicator z:62)：预览轴须压在时间轴标记之上
            z: 61
            // 左边缘吸附到物理像素网格：1px 竖线随光标连续移动时若落在非整数物理像素会被抗锯齿摊成 2px，
            // 表现为 Windows(dpr=1) 下时粗时细；mac(dpr=2) 半像素恰好对齐物理像素故无感。按 devicePixelRatio 取整消除抖动。
            x: {
                let raw = trackDockHeader.width + coverRectangle.width - flickable.contentX + indicatorPos - width / 2;
                let dpr = Screen.devicePixelRatio;
                return Math.round(raw * dpr) / dpr;
            }
            property bool isClip: multiTrackView.isEnterClip && (!multiTrackView.isPressClip)
            // 是否正在与标记交互（悬停或拖动）：标记会消费 hover 使 flickable.containsMouse 翻 false，
            // 与悬停片段用 isClip 同理，用该标志兜底，避免交互标记时预览轴消失（拖动时由标记主动推竖线跟随）
            property bool isMarkPreviewing: false
            // 时间轴标记带整条带悬停驱动的预览态(标记之间空白处)；与 isMarkPreviewing 各自独立、此处做 OR，
            // 避免两个布尔互相覆盖造成"离开标记进入空白"瞬间闪灭。见 MarkPointRibbon.bandPreviewing
            property bool isBandPreviewing: timelineMarkRibbon.bandPreviewing
            property bool isValidFrame: trackDockViewModel.currentFrame !== trackDockViewModel.indicatorFrame || trackDockViewModel.previewFrame > trackDockViewModel.totalFrame || isClip || isMarkPreviewing || isBandPreviewing
            // hover 项与 root.previewHoverActive 同源用 previewRawHover 去重；末尾 pointerInsideEditRegion 几何门控兜底 macOS hover-leave 丢失。
            // hoverVisible 与 visible 分开：visible 多加 x 视口范围判断(与播放头同口径)，横向滚动滑出可视区
            // 只停绘制、不改 hoverVisible，播放对齐逻辑的语义(是否在悬停预览)不受滚动影响。
            readonly property bool hoverVisible:
                trackDockViewModel.showHoverPreview && !trackDockViewModel.playing && root.previewRawHover && isValidFrame &&
                !multiTrackView.isDragging && indicator.enabled && !indicatorSeek.isDragging && !multiTrackView.isClipping && !multiIndicatorSeek.isDragging && root.pointerInsideEditRegion
            visible: hoverVisible && x > (trackDockHeader.width - width / 2 - 1) && x < (parent.width - 10 - width / 2)
            onHoverVisibleChanged: {
                globalSignal.isTrackDockHoverSeek(hoverVisible);
            }

            Component.onCompleted: {
                globalSignal.isTrackDockHoverSeek(hoverVisible);
            }

            Component.onDestruction: {
                globalSignal.isTrackDockHoverSeek(false);
            }

            Connections {
                target: globalSignal
                function onPreviewFrame(frame) {
                    trackDockViewModel.previewFrame = frame
                }
                function onMarkPointPreviewActive(active) {
                    previewIndicator.isMarkPreviewing = active
                }
            }

            color: ColorsConfig.color_FD5050_4DFFC9
        }

        // 预览轴权威时把悬停帧推给标记工具栏单例作为加/删点基准帧；否则推 -1 回退到时间指示器
        // (用 previewHoverActive 而非 previewIndicator.visible，规避 isValidFrame 竞态，见 previewHoverActive 注释)
        Binding {
            target: MarkPointToolbarViewModel
            property: "previewBaseFrame"
            value: root.previewHoverActive ? Math.round(trackDockViewModel.previewFrame) : -1
        }


        // 吸附线
        Rectangle {
            id: snappingLine
            property real indicatorPos: 0 // 吸附位置

            width: 1
            height: parent.height - 12
            // 高于时间轴标记带(timelineMarkClip z:60)：拖动时间轴标记命中吸附时，吸附线须压在时间轴标记之上
            z: 61
            // 左边缘吸附到物理像素网格：1px 竖线随滚动落在非整数物理像素会被抗锯齿摊成 2px，
            // 表现为时粗时细。按 devicePixelRatio 取整对齐物理像素消除抖动。与 previewIndicator 同。
            x: {
                let raw = trackDockHeader.width + coverRectangle.width - flickable.contentX + indicatorPos - width / 2;
                let dpr = Screen.devicePixelRatio;
                return Math.round(raw * dpr) / dpr;
            }
            visible: false
            color: ColorsConfig.color_brand
            opacity: 0.4

            // 反向拖动标记命中片段头/尾时驱动吸附线：globalFrame×scaleBase 即内容坐标偏移，x 绑定已含 header+cover−contentX
            Connections {
                target: globalSignal
                function onMarkPointSnapLine(globalFrame, visible) {
                    // 命中时间指示器帧：与拖片段/裁剪同范式(见 snappedChanged)——指示器自身变吸附色，不再画会被指示器(z62)盖住的冗余吸附线(z61)；
                    // 命中其它候选(片段头尾/关键帧)才画吸附线；未命中/结束(visible=false)两者都复位
                    if (visible && globalFrame === trackDockViewModel.indicatorFrame) {
                        indicator.isSnapped = true;
                        snappingLine.visible = false;
                    } else {
                        indicator.isSnapped = false;
                        snappingLine.visible = visible;
                        snappingLine.indicatorPos = globalFrame * trackDockViewModel.scaleBase;
                    }
                }
            }
            // nova: 拖片段吸附线由 C++(novaClipDragMove)驱动。novaDragSnapPosMk<0 复位；命中时间指示器则指示器变色不画线；
            // 命中其它候选画吸附线(mk→内容 px：/oneFrameToTimes*scaleBase，与裁剪 snappedChanged 同范式)。
            Connections {
                target: multiTrackView
                function onNovaDragSnapChanged() {
                    let posMk = multiTrackView.novaDragSnapPosMk;
                    if (posMk < 0) {
                        indicator.isSnapped = false;
                        snappingLine.visible = false;
                    } else if (multiTrackView.novaDragSnapOnIndicator) {
                        indicator.isSnapped = true;
                        snappingLine.visible = false;
                    } else {
                        indicator.isSnapped = false;
                        snappingLine.visible = true;
                        snappingLine.indicatorPos = posMk / root.oneFrameToTimes * trackDockViewModel.scaleBase;
                    }
                }
            }
        }

        // 主要是用来盖住刻度尺的，想要当刻度尺移动到轨道头左边的时候不展示出来，这里就直接用这个矩形盖住
        Rectangle {
            id: trackDockHeaderTop
            visible: root.isInEditeState
            anchors {
                left: parent.left
                top: parent.top
                bottom: rulerRectangle.bottom
                bottomMargin: -4
            }
            width: trackDockHeader.width
            color: Colors.color_content_area_background
            clip: true
        }

        // 只添加轨道头右侧的阴影，当滚动最左侧时，阴影消失
        Rectangle {
            x: trackDockHeader.x + trackDockHeader.width
            y: trackDockHeader.y
            width: 15
            height: trackDockHeader.height
            visible: flickable.contentX > 0
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Colors.color_000000_50 }
                GradientStop { position: 1.0; color: Colors.transparent }
            }
        }
        // 轨道头
        Rectangle {
            id: trackDockHeader
            visible: root.isInEditeState
            property bool isCollapsed: false
            property real trackDockHeaderWidth: 76
            readonly property TrackHeadListViewModel trackHeadListViewModel: multiTrackDataProvider.getHeadeListViewModel();
            // 第一个轨道距离顶部的间隙
            readonly property real tracksHeadSpace: (trackDockHeader.height - trackHeadListViewModel.trackHeadTotalHeight) / 2
            // 最后一个轨道距离顶部的间隙
            readonly property real tracksFootSpace: (trackDockHeader.height - trackHeadListViewModel.trackHeadTotalHeight) / 2

            anchors {
                left: parent.left
                top: rulerRectangle.bottom
                bottom: parent.bottom
            }

            width: trackDockHeaderWidth
            color: Colors.color_content_area_background
            clip: true

            Item {
                id: trackDockHeaderBg
                width: parent.width
                height: Math.min(trackDockHeader.trackHeadListViewModel.trackHeadTotalHeight, parent.height)

                anchors.verticalCenter: parent.verticalCenter
                ListView {
                    id: trackDockListView
                    spacing: multiTrackDataProvider.getHeadeListViewModel().listSpacing
                    anchors.fill: parent
                    // 禁用弹性滚动
                    boundsBehavior: Flickable.StopAtBounds
                    // 需要缓存所有的轨道头，否则会导致滚动时轨道头会因为缓存不足导致与flickable的滚动位置不一致，导致轨道头显示异常
                    cacheBuffer: 10000

                    //interactive: false // 禁用滚动
                    model: trackDockHeader.trackHeadListViewModel

                    // 列表顶部占位符
                    header: Item {
                        id: listHeader
                        width: trackDockListView.width
                        height: flickable.trackSpacing
                    }

                    delegate: TrackHead {
                        // 这个参考剪映, 空轨拖拽添加先不显示
                        // 文本轨道不显示音量按钮
                        volumeVisible: !(!editorManager.isInEditeState && flickable.isUnderFickableDrag)
                        height: model.trackHeight
                        width: trackDockHeader.width
                        viewModel: model
                        isCollapsed: trackDockHeader.isCollapsed
                        color: model.trackBgColor
                        onTrackHeightChangedSignal: {
                            trackDockViewModel.trackHeadTotalHeightchanged();
                        }
                    }

                    // 列表底部占位符
                    footer: Item {
                        id: listFooter
                        width: trackDockListView.width
                        height: flickable.trackSpacing + 20
                    }

                    // 当trackDockListView滚动时，同步flickable的垂直滚动位置
                    onContentYChanged: {
                        // 只有用户直接在轨道头列表上滚动（moving/dragging）时才允许左侧驱动右侧。
                        // 删除/插入轨道头行时，ListView内部fixup也会触发contentYChanged（contentY/originY跳变），
                        // 这类非用户滚动如果同步给flickable，会把右侧内容错误滚动约一行的高度，
                        // 造成整个轨道区跳变、误触发主轨固定逻辑导致轨道错位。
                        const isUserScrolling = trackDockListView.moving || trackDockListView.dragging;
                        Qt.callLater(() => {
                            if (isUserScrolling) {
                                // 与反向同步保持同一换算关系：flickable.contentY = contentY - originY
                                const targetY = trackDockListView.contentY - trackDockListView.originY;
                                if (Math.abs(flickable.contentY - targetY) > 0.1) {
                                    // 必须走scrollBy做边界clamp，不能直接写contentItem.y
                                    flickable.scrollBy(0, targetY - flickable.contentY);
                                }
                            } else {
                                // 非用户滚动：以flickable为准把轨道头列表回正，
                                // 保证行增删fixup后左右两侧仍然对齐
                                const targetContentY = flickable.contentY + trackDockListView.originY;
                                if (Math.abs(trackDockListView.contentY - targetContentY) > 0.1) {
                                    trackDockListView.contentY = targetContentY;
                                }
                            }
                        });
                    }
                }
                // 最下发保留10px，跟右侧滚动条对齐
                Rectangle {
                    id: headerBottomHover
                    width: parent.width
                    height: 10
                    anchors.bottom: parent.bottom
                    color: Colors.color_1F2021
                }
            }
            // 主轨道视频轨道头，当主视频的轨道滚到顶部或底部时显示
            TrackHead {
                id: mainVideoTrackHead
                volumeVisible: !(!editorManager.isInEditeState && flickable.isUnderFickableDrag)
                anchors.left: trackDockHeader.left
                width: trackDockHeader.width
                isCollapsed: trackDockHeader.isCollapsed
                visible: multiTrackView.scrollModel !== 0
                color: ColorsConfig.color_1F2021_000000
                showBorders: true

                // 根据滚动模式动态调整位置
                y: {
                    if(multiTrackView.scrollModel === 1) {
                        return 0;
                    } else {
                        return trackDockHeader.height - height - 10;
                    }
                }
                Component.onCompleted: {
                    console.log("onTrackViewScrollModelChanged mainVideoTrackHead completed", multiTrackView.scrollModel)
                }

                Connections {
                    target: multiTrackView
                    function onScrollModelChanged() {
                        if(mainVideoTrackHead.visible) {
                            var model = trackDockHeader.trackHeadListViewModel
                            // 从下往上遍历，找到第一个视频轨道头
                            for(var i = model.rowCount() - 1; i >= 0; i--) {
                                if(model.at(i).trackType === TrackHeadViewModel.TRACKTYPE_VIDEO) {
                                    mainVideoTrackHead.viewModel = model.at(i)
                                    mainVideoTrackHead.height = model.at(i).trackHeight
                                    break
                                }
                            }
                        }
                    }
                }
            }


            // 当flickable垂直滚动时，同步trackDockListView的滚动位置
            Connections {
                target: flickable
                function onContentYChanged() {
                    Qt.callLater(() => {
                        if (Math.abs(trackDockListView.contentY - flickable.contentY- trackDockListView.originY) > 0.1) {
                            trackDockListView.contentY = flickable.contentY + trackDockListView.originY ;
                        }
                    })
                }
            }

            // 用来实现对轨道头的收缩/展开
            Item {
                id: trackDockHeaderLine
                anchors {
                    top: parent.top
                    right: parent.right
                    bottom: parent.bottom
                }
                width: 2
                MouseArea {
                    enabled: false
                    hoverEnabled: false
                    anchors.fill: parent
                    // cursorShape: Qt.SplitHCursor
                    drag.target: trackDockHeaderLine
                    drag.axis: Drag.XAxis
                    property real initialX: 0
                    property bool isDragging: false

                    onEntered: {
                        trackDockHeaderLine.color = Colors.color_121212;
                    }

                    onExited: {
                        trackDockHeaderLine.color = Colors.color_transparent;
                    }

                    onPressed: (mouse) => {
                        initialX = mouse.x;
                        isDragging = true;
                    }

                    onPositionChanged: (mouse) => {
                        if (!isDragging) {
                            return;
                        }
                        if (mouse.x > initialX) {
                            if (trackDockHeader.isCollapsed) {
                                trackDockHeader.trackDockHeaderWidth = 90;
                                trackDockHeader.isCollapsed = false;
                                isDragging = false;
                            }
                        } else if (mouse.x < initialX) {
                            if (!trackDockHeader.isCollapsed) {
                                trackDockHeader.trackDockHeaderWidth = 57;
                                trackDockHeader.isCollapsed = true;
                                isDragging = false;
                            }
                        }
                    }
                }
            }
        }

        // 底部和右侧滚动条的线
        Rectangle{
            id: bottomLine
            width: parent.width - 10
            height: 1
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 10
            color: Colors.color_141414
        }
        Rectangle{
            id: rightLine
            width: 1
            height: parent.height - 10
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.rightMargin: 10
            color: Colors.color_141414
        }

        // 播放进度指示器
        FrameIndicator {
            id: indicator
            // 高于范围导出(rangeCompose z:61)与标记带(z:60)，保证播放头始终压在最上层
            z: 62
            // 这里乘scaleBase修改的是UI，下边的Item是用来修改底层数据trackDockViewModel.indicatorFrame
            property real indicatorPos: trackDockViewModel.scaleBase * trackDockViewModel.indicatorFrame

            x: trackDockHeader.width + coverRectangle.width - flickable.contentX + indicatorPos - width / 2
            enabled: editorManager.playType === QPlayType.editor &&
                     CommonUtils.isEmptyStr(audioListSelectedPath) &&
                     !previewAssetsManager.isPreviewing
            height: parent.height - 12
            visible: root.isInEditeState && x > (trackDockHeader.width - width / 2 - 1) && x < (parent.width - 10 - width / 2)
            atTrackEnd: trackDockViewModel.indicatorFrame == trackDockViewModel.totalFrame
            Accessible.role: Accessible.Button
            Accessible.description: "videoedit_timeindicator"

            onXChanged: {
                if(multiTrackDataProvider.enableSnapping){
                    const epsilon = 1e-10;
                    var isScaleBaseZero = Math.abs(root.oneFrameToTimes * trackDockViewModel.scaleBase) < epsilon
                    if(isScaleBaseZero){
                        return;
                    }
                    multiTrackDataProvider.updateIndicatorSnapingPos(indicator.indicatorPos / trackDockViewModel.scaleBase * root.oneFrameToTimes);
                }
                if (!indicatorSeek.isDragging) {
                    indicatorSeek.x =  trackDockViewModel.scaleBase * trackDockViewModel.currentFrame- indicatorSeek.width/2
                }
            }
        }

        KeyframeTransitionTips {
            id: keyframeTransitionTips
            width: 98
            height:30
            anchors.top: trackDockHeader.top
            anchors.topMargin: 65
            clip: false
            visible: false
        }


        FileDialog {
            id: importFileDialog
            property int curTrackIndex: 0
            property int curClipIndex: 0
            fileMode: FileDialog.OpenFile
            // 支持的格式
            nameFilters: [ fileOperator.fileSuffixes() ]
            onAccepted: {
                globalSignal.addToMediaTab(files, curTrackIndex, curClipIndex);
            }
        }
    }

    // 监听拖拽事件
    DropArea {
        enabled: lightWindow.topPopupCount <= 0
        anchors.fill: trackDockContent
        // 拖入时实时过滤
        onEntered: (drag) => {
            // 新手引导过程中不支持拖拽导入
            if(editorManager.isInUserGuideStatus){
                drag.accepted = false
                return
            }
            const allInvalid = fileOperator.isAllFilesInvalid(drag.urls)
            // 如果所有文件都不支持，则拒绝拖入
            if (allInvalid) {
                drag.accepted = false
            }
        }
        onDropped: (drop) => {
            drop.accept()
            if (drop.hasUrls) {
                globalSignal.importMedia(drop.urls, MediaListViewModel.DragTimeline, false)
            }
        }
    }

    property VideoClipWindow videoClipWindow: null
    Connections {
        target: globalSignal
        function onUpdateTransitionPosition(rect) {
            if (!lightSetting.getBool("showTransitionTips")) {
                keyframeTransitionTips.x = rect.x - keyframeTransitionTips.width / 2 + 3
                keyframeTransitionTips.visible = true
                lightSetting.save("showTransitionTips", true)
            }
        }

        function onOpenFrameCropWindow(){
            if (CommonUtils.isNull(videoClipWindow))
            {
                var component = Qt.createComponent("VideoClipWindow.qml");
                if (component.status === Component.Ready) {
                    videoClipWindow = component.createObject(root);
                }
            }

            if (!CommonUtils.isNull(videoClipWindow)){
                videoClipWindow.show();
            }
        }

        function onDragAddInTrackEvent(isStart, point){
            var dragMousePoint = multiTrackView.mapToItem(flickable, point);
            flickable.dragMousePoint.x = dragMousePoint.x;
            flickable.dragMousePoint.y = dragMousePoint.y;

            // 视频素材的滚动定时器由 isDragging(trackState) 统一管理，这里只更新坐标，避免误停
            if(multiTrackView.isDragging){
                return;
            }

            // 非视频素材：进入轨道纵向区域才启动定时器，离开则停止
            if(scrollTimer.running && !isStart){
                scrollTimer.stop()
                return;
            }

            if(!scrollTimer.running && isStart){
                scrollTimer.restart();
            }
        }

        // 素材区拖拽开始/结束：用于纵向自动滚动判定（仅当从素材区拖入时才限制鼠标须在轨道内）
        function onMaterialDragActiveChanged(isActive){
            multiTrackView.isDraggingMaterial = isActive;
            // nova 素材拖拽不走 trackState DRAGGING，此处统一在拖拽期间禁用所有快捷键(与 main 经 trackState 的实现同语义)
            ShortcutObserver.disableAllShortcut(isActive);
        }

        // nova 素材(视频/图片、音频、文字)从素材区拖入：驱动自动滚动 + 滚动中回喂落位
        // by zhongshan 此处滚动处理的不是很好，后面可以再统一一下
        function onMediaDragAddMove(windowPoint){ root.handleNovaMaterialDragMove(1, windowPoint); }
        function onAudioDragMove(windowPoint){ root.handleNovaMaterialDragMove(2, windowPoint); }
        function onOverlayTextDragMove(windowPoint){ root.handleNovaMaterialDragMove(3, windowPoint); }
        function onMediaDragAddRelease(windowPoint, isCancel){ root.endNovaMaterialDrag(); }
        function onAudioDragRelease(windowPoint, isCancel){ root.endNovaMaterialDrag(); }
        function onOverlayTextDragRelease(windowPoint, isCancel){ root.endNovaMaterialDrag(); }
    }

    // 预览轴原始 hover 项(未加几何门控)：三来源 hover 布尔的 OR，作 tracker 启停触发 + visible/previewHoverActive 共用去重。
    readonly property bool previewRawHover:
        flickable.containsMouse || previewIndicator.isClip
        || previewIndicator.isMarkPreviewing || previewIndicator.isBandPreviewing

    // hover-leave 兜底：Qt 在 macOS/Windows 均偶发丢 leave 事件，致 containsMouse /
    // HoverHandler.hovered 卡 true、预览轴冻结在最后位置不隐藏。既有兜底都反过来依赖 leave 先翻假，救不了。
    // 故悬停期间轮询真实光标，几何判定出编辑区即置假，门控 visible/previewHoverActive，不依赖 leave 事件。
    property bool pointerInsideEditRegion: true

    onPreviewRawHoverChanged: {
        // 起点用 raw hover(enter 事件可靠、不受 leave 丢失影响)启停，避免"门控了 visible 又用 visible 启停 tracker"死锁。
        if (previewRawHover) {
            pointerInsideEditRegion = true;
            cursorGuardTracker.startTracking();
        } else {
            cursorGuardTracker.stopTracking(); // raw 翻假即停轮询
        }
    }

    MousePositionTracker {
        id: cursorGuardTracker
        onMousePositionChanged: {
            // 拖动豁免：拖标记/拖片段/裁剪/拖指示器时预览由拖动主动驱动，光标可能上飘出区，几何判假会误隐藏、断跟随。
            if (multiTrackView.isDragging || multiTrackView.isClipping
                    || indicatorSeek.isDragging || multiIndicatorSeek.isDragging
                    || timelineMarkRibbon.activeDragItem) {
                root.pointerInsideEditRegion = true;
                return;
            }
            let win = root.Window.window;
            if (!win) {
                return;
            }
            let p = cursorGuardTracker.mapFromGlobal(win, cursorGuardTracker.mouseX, cursorGuardTracker.mouseY);
            // 编辑区窗口坐标矩形：纵向刻度尺顶→flickable 底；横向取 trackDockContent 全宽
            // (标记带铺满视口到 coverRectangle，比 flickable 更宽，必须用 content 全宽兜住最外沿)。
            let tl = trackDockContent.mapToItem(null, 0, 0);
            let regionTop = rulerRectangle.mapToItem(null, 0, 0).y;
            let regionBottom = flickable.mapToItem(null, 0, flickable.height).y;
            root.pointerInsideEditRegion = (p.x >= tl.x && p.x <= tl.x + trackDockContent.width
                                            && p.y >= regionTop && p.y <= regionBottom);
        }
    }

    // 预览轴权威态：真实 hover 意图存在、未播放、非操作态时预览轴才是基准。基准决策与退出复位统一用它，
    // 不用 previewIndicator.visible——后者含 isValidFrame(currentFrame!==indicatorFrame) 噪声，previewSeek 只推
    // currentFrame、seek-back 又是异步的，离开编辑区那一刻 visible 会在异步窗口内误判为真、令基准读到陈旧 previewFrame。
    // 末尾接入 pointerInsideEditRegion 几何门控，兜底 macOS hover-leave 丢失。
    // 编辑器播放态判据用 playType 属性(与 indicator.enabled 同口径)，不用 isEditorPlay() 方法：方法调用不进
    // QML 依赖表，返回假时 && 短路又令其后各项都不登记依赖，绑定会冻结在假(退出素材/转场预览后不再重算)。
    readonly property bool previewHoverActive:
        trackDockViewModel.showHoverPreview && !trackDockViewModel.playing
        && editorManager.playType === QPlayType.editor
        && previewRawHover
        && indicator.enabled && !multiTrackView.isDragging && !multiTrackView.isClipping
        && !indicatorSeek.isDragging && !multiIndicatorSeek.isDragging
        && pointerInsideEditRegion

    onPreviewHoverActiveChanged: {
        // 去抖：鼠标扫过播放头线时 indicatorArea(hoverEnabled)被 onMouseXChanged 滑到光标下、抢走 flickable 的 hover，
        // 致 containsMouse 瞬时抖 false → previewHoverActive 瞬时 false。立即 seek 回指示器会打断连续预览(画面闪回指示器再闪回预览)。
        // 故延后一拍再复位：抖动在 80ms 内恢复(变回 true)则取消，真正离开(持续 false)才触发。
        if (previewHoverActive) {
            previewSeekBackTimer.stop();
        } else {
            previewSeekBackTimer.restart();
        }
    }

    // 预览态结束后把画面(currentFrame，经 seek)与预览帧(previewFrame)拉回时间指示器，消除 previewSeek 泄漏——
    // 后续播放、分割/trim/加删点、帧步进都以播放指示器为准。去抖触发(见 onPreviewHoverActiveChanged)。
    // 触发前复检：仍非预览态、未播放、非操作态、且确有泄漏(currentFrame≠indicatorFrame)才 seek。
    Timer {
        id: previewSeekBackTimer
        interval: 80
        repeat: false
        onTriggered: {
            if (root.previewHoverActive)
                return;
            if (!trackDockViewModel.playing && editorManager.isEditorPlay()
                    && trackDockViewModel.currentFrame !== trackDockViewModel.indicatorFrame
                    && !multiTrackView.isDragging && !multiTrackView.isClipping
                    && !indicatorSeek.isDragging && !multiIndicatorSeek.isDragging) {
                editorManager.seek(trackDockViewModel.indicatorFrame);
                trackDockViewModel.previewFrame = trackDockViewModel.indicatorFrame;
            }
        }
    }

    // 分割/裁剪基准位置：预览轴权威时取预览轴帧，否则取时间指示器帧；不用 currentTimebase()
    // (=currentFrame)——拖动标记的 previewSeek 会把 currentFrame 留在标记处、与时间指示器解耦
    function editBasePosition() {
        var frame = previewHoverActive ? Math.round(trackDockViewModel.previewFrame)
                                       : trackDockViewModel.indicatorFrame;
        return trackDockViewModel.frameToTimebase(frame);
    }

    Connections {
        target: trackTools

        function onSplitClicked(operationType) {
            editorManager.pause();
            const position = editBasePosition();
            // nova: 分割走 nle 剃刀(SplitClipCmd,单步 undo);提交+回读在 TimelineEditController 内完成。
            if(!TimelineEditController.split(position)){
                toast.showToast(qsTr("pccut_navigation_split_unable"), "tracks");
                return;
            }
            const use_method = operationType === MultiTrackView.ShortCut ? "shortcut" : "navigation_bar";
            eventTracker.trackEvent("pccut_split_click", {"use_method": use_method});
            const projectId = draftManager.activeProjectEnvId();
            UsedFunctionManager.addFunction(projectId, UsedFunctionManager.EditorFunctionType.CUT);
        }

        function onTrackScale(scale) {
            updateScale(scale);
        }

        function onCutBtnClickedSignal(isLeftCut, operationType){
            editorManager.pause();
            const position = editBasePosition();
            // nova: 导航裁头/裁尾走 nle(裁到播放头,单步 undo);提交+回读在 TimelineEditController 内完成。
            if(!TimelineEditController.trim(position, isLeftCut)){
                if(isLeftCut){
                    toast.showToast(qsTr("pccut_navigation_trim_end_unable"), "tracks");
                }else{
                    toast.showToast(qsTr("pccut_navigation_trim_beginning_unable"), "tracks");
                }
            }else{
                const use_method = operationType === MultiTrackView.ShortCut ? "shortcut" : "navigation_bar";
                const eventName = isLeftCut ? "pccut_cropleft_click" : "pccut_cropright_click";
                eventTracker.trackEvent(eventName, {"use_method": use_method});
                const projectId = draftManager.activeProjectEnvId();
                UsedFunctionManager.addFunction(projectId, UsedFunctionManager.EditorFunctionType.CLIP);
            }
        }

        function onVideoClipClickedSignal(){
            if (CommonUtils.isNull(videoClipWindow))
            {
                var component = Qt.createComponent("VideoClipWindow.qml");
                if (component.status === Component.Ready) {
                    videoClipWindow = component.createObject(root);
                }
            }

            if (!CommonUtils.isNull(videoClipWindow)){
                videoClipWindow.show();
            }

        }
    }

    function checkHoverIndicator() {
        // 不能直接用 indicatorArea.containsMouse 判定：indicatorArea 贴在 indicatorSeek 上，
        // 而 onMouseXChanged 会把 indicatorSeek.x 移到鼠标正下方，导致 containsMouse 自我强化、
        // 偶发卡死为 true（表现为预览轴不生效、鼠标一直是时间指示器的拖拽样式）。
        // 改为基于鼠标真实位置与真实播放头位置(indicatorSeek.indicatorX)做几何判定，
        // 与 indicatorSeek.showCursor 的基准保持一致，鼠标一旦移出指示器宽度范围立即返回 false。
        const mouseContentX = flickable.mouseX + flickable.contentX;
        return mouseContentX >= indicatorSeek.indicatorX && mouseContentX <= indicatorSeek.indicatorX + indicator.width;
    }
    Connections {
        target: flickable

        function onTrackScale(scale) {
            updateScale(scale);
        }

        function onTrackClick(position, pressedY) {
            // 清空选中态
            var needCleanSelected = true;
            if (indicatorSeek.pressedShowCursor) {
                needCleanSelected = false;
            } else if (position.y < flickable.rulerThresholdY || pressedY < flickable.rulerThresholdY) {
                // 如果release位置或pressed位置在刻度尺上就不清空
                needCleanSelected = false;
            }
            if (needCleanSelected) {
                trackViewModel.clearSelection();
                globalSignal.videoSelected(null);
            }
        }


        function onMouseXChanged() {
            if (!checkHoverIndicator()) {
                multiIndicatorSeek.x = flickable.mouseX + flickable.contentX - multiIndicatorSeek.width / 2;
            } else {
                indicatorSeek.x = flickable.mouseX + flickable.contentX - indicatorSeek.width / 2;
            }

            if (trackDockViewModel.showHoverPreview && !trackDockViewModel.playing && flickable.containsMouse && editorManager.isEditorPlay() && indicator.enabled) {
                var posX = flickable.mouseX + (flickable.contentX - coverRectangle.width)

                if(multiTrackDataProvider.enableSnapping){
                    var deltaX = (multiTrackView.visibleRect.x == 0) ? multiTrackView.x : 0
                    var pos = multiTrackDataProvider.getSnappingPos(SnappingOperateType.OPERATE_PREVIEW_AXIS, (flickable.mouseX - deltaX + multiTrackView.visibleRect.x) / trackDockViewModel.scaleBase * root.oneFrameToTimes);
                    if(pos !== -1){
                        posX = pos / root.oneFrameToTimes * trackDockViewModel.scaleBase;
                    }
                }
                seekByX(posX, true);
            }
        }

        function onContainsMouseChanged() {
            let point = Qt.point(flickable.mouseX, flickable.mouseY);
            let isInClip = multiTrackView.isInFragmentAt(flickable.mapToItem(multiTrackView, point));
            // 因为片段上有鼠标hover, 当值 flickable的鼠标hover失效, 所以增加了片段的判断
            if (!isInClip && !flickable.containsMouse) {
                globalSignal.trackDockContainsMouseChanged(false);
            } else if (flickable.containsMouse) {
                globalSignal.trackDockContainsMouseChanged(true);
            }
            // seek 回指示器统一由 previewHoverActive 去抖路径承担（见 previewSeekBackTimer），此处不再单独 seek——
            // 否则鼠标扫过播放头致 containsMouse 瞬时抖 false 时会立即 seek 回指示器造成画面闪烁。
        }
    }

    Connections {
        target: trackDockViewModel
        function onPlayingChanged() {
            // 播放停止的时候，如果指针移动到轨道之外了，就尽可能的将它调整到中间位置
            // 转场预览时不要自动滚动时间轴
            if (!trackDockViewModel.playing && trackDockViewModel.totalFrame > 0 && !previewAssetsManager.isPreviewing) {
                // 为啥搞个这玩意儿，还是信号的问题，就是这里的暂停可能是seek造成的暂停，如果是这样，就得先seek完再调整位置，看需不需要让指针移动出来
                // 但是这个条件在这里很难知道，最简单的方式就是等一圈。
                Qt.callLater(function() { displayIndicatorIfNecessary(indicator.indicatorPos, 0, flickable.width / 2); });
            }
        }
    }

    // 如果当前位置positionX，距离轨道边缘的距离小于triggerPosition，那么就滚动轨道，使得indicator尽量在targetPosition的位置上
    function displayIndicatorIfNecessary(positionX, triggerPosition, targetPosition) {
        const distanceToEnd = flickable.contentX + flickable.width - positionX;
        const distanceToStart = positionX - flickable.contentX;
        // 如果满足这个条件，那说明距离轨道边缘的距离大于triggerPosition，
        // 当triggerPosition==0的时候，可以认为当前指示器就是在屏幕中可见的
        if (distanceToStart >= triggerPosition && distanceToEnd >= triggerPosition) {
            return;
        }
        let targetContentX = flickable.contentX;
        if (distanceToEnd < targetPosition) {
            // 指示器处于屏幕右侧不可见处，计算出需要移动的距离
            targetContentX = Math.min(flickable.contentWidth - flickable.width, flickable.contentX + (targetPosition - distanceToEnd));
        } else if (distanceToStart < targetPosition) {
            // 指示器处于屏幕左侧不可见处，计算出需要移动的距离
            targetContentX = Math.max(0, flickable.contentX - (targetPosition - distanceToStart));
        }
        const distance = targetContentX - flickable.contentX;
        flickable.scrollBy(distance, 0);
    }

    // 尝试更新轨道缩放级别
    function updateScale(targetScale) {
        const totalFrame = trackDockViewModel.totalFrame;
        // 居中锚点：预览轴权威时以预览轴帧(previewFrame)为准，否则用时间指示器帧(indicatorFrame)。判据与
        // editBasePosition / previewBaseFrame Binding 同源(previewHoverActive，规避 previewIndicator.visible 的
        // isValidFrame 竞态)。indicatorFrame 不用 currentFrame：拖动/预览标记走 previewSeek 只动 currentFrame
        // 不动 indicatorFrame，用 currentFrame 会以陈旧预览帧居中致指示器漂移。
        const anchorFrame = root.previewHoverActive ? trackDockViewModel.previewFrame : trackDockViewModel.indicatorFrame;
        if (totalFrame <= 0 || anchorFrame < 0) {
            return;
        }
        const originScale = trackDockViewModel.scaleBase;
        targetScale = trackDockViewModel.clampScale(targetScale);
        if (originScale === targetScale) {
            return;
        }

        // 保持指示器位置不变更
        // offset是当前指示器距离左侧边界的距离，保持指示器位置不变，其实就是这个距离不变
        const offset = originScale * anchorFrame - flickable.contentX
        trackDockViewModel.scaleBase = targetScale;
        // 这里不做clamp，因为scrollBy自己会做
        const targetContentX = targetScale * anchorFrame - offset;
        // 这里展开以后其实就等于 deltaX = targetScale * anchorFrame - (originScale * anchorFrame - flickable.contentX(原)) - flickable.contentX(现)
        // 如果更新scaleBase之后flickable.contentX没有发生变化，那么deltaX的计算就可以简化为(targetScale - originScale) * anchorFrame
        // 但是更新scaleBase之后，contentX是会发生变化的，原因是scaleBase的变化会引起flickable的content的长度的变化，
        // 这么依赖原来的contentX就可能会超出边界，TrackFlickable内部有根据边界重新更正contentX的逻辑，
        // 所以更新scaleBase前后 flickable.contentX的值会发生变化
        const deltaX = targetContentX - flickable.contentX;
        indicatorSeek.x =  trackDockViewModel.scaleBase * trackDockViewModel.indicatorFrame- indicatorSeek.width/2
        rangeCompose.updateRangeComposeViewLocation();
        flickable.scrollBy(deltaX, 0);
    }

    function seekByX(x, preview) {
        // 若处于云相册主播放器临时预览态，点时间轴即退出预览、恢复时间轴（必须在 isEditorPlay 守卫前）
        editorManager.exitCloudPreview(-1);
        // 如果播放的是非编辑的视频就不seek
        if (!editorManager.isEditorPlay()) {
            return;
        }
        // 拖拽排序过程中不进行seek
        if (multiTrackView.isDragging) {
            return;
        }

        // 如果正在转场预览，先停止转场预览再执行 seek
        if (previewAssetsManager.isPreviewing) {
            transitionManager.stopTransitionPreview();
        }

        const trackTotalFrame = trackDockViewModel.totalFrame;
        const trackScaleBase = trackDockViewModel.scaleBase;
        if (trackTotalFrame <= 0 || trackScaleBase <= 0) {
            return;
        }
        const requestFrame = Math.round(x / trackScaleBase);
        trackDockViewModel.previewFrame = requestFrame;
        const seekFrame = Math.min(Math.max(requestFrame, 0), trackTotalFrame);
        if (preview) {
            editorManager.previewSeek(seekFrame);
        } else {
            editorManager.seek(seekFrame);
        }
    }
    // 检测拖拽的点是否在轨道上
    function checkIsInVideoTrack(flickablePoint) {
        return multiTrackView.isInVideoTrackAt(multiTrackView.mapFromItem(flickable, flickablePoint));
    }

    Timer {
        id: indicatorScrollTimer
        interval: 20
        repeat: true

        onTriggered: {
            const pxPerFrame = trackDockViewModel.scaleBase
            if (pxPerFrame <= 0 || !editorManager.isEditorPlay()) {
                return;
            }

            // 触发距离
            const triggerDistance = 30;
            // 左侧边缘，并不简单是0，因为轨道片段内容距离flickable最左侧还有东西，目前就是一个封面，也许后面还有其他
            const leftEdge = Math.max(0, multiTrackView.x - flickable.contentX);
            // 右侧边缘
            const rightEdge = flickable.width
            // 这里就是指针拖动位置
            const triggerPos = indicatorSeek.x - flickable.contentX + indicatorSeek.width / 2;
            // 指针拖动位置距离左侧边缘距离
            const distanceToLeftEdge = triggerPos - leftEdge;
            // 指针拖动位置距离右侧边缘距离
            const distanceToRightEdge = rightEdge - triggerPos;
            let speed = 0;
            if (distanceToLeftEdge < triggerDistance) {
                speed = (distanceToLeftEdge - triggerDistance) / triggerDistance;
            } else if (distanceToRightEdge < triggerDistance) {
                speed = (triggerDistance - distanceToRightEdge) / triggerDistance;
            } else {
                return;
            }

            // 至少移动一帧的位置
            const sign = speed > 0 ? 1 : -1;
            const step = 120
            let targetMoveDistance = sign * Math.max(pxPerFrame, Math.abs(speed) * step);
            // 这里需要尽可能移动到整帧的位置，做法就是多移动一点直到整帧位置
            const targetIndicatorX = indicatorSeek.x + targetMoveDistance;
            const realX = targetIndicatorX - multiTrackView.x + (indicatorSeek.width / 2);
            // 触发了左侧边缘，需要向右移动轨道，此时需要帧的位置向小的方向多移动一些，所以用floor
            // 触发了右侧边缘，需要向左移动轨道，此时需要帧的位置向大的方向多移动一些，所以用ceil
            const seekFrame = speed < 0 ? Math.floor(realX / pxPerFrame) : Math.ceil(realX / pxPerFrame);
            const oldContentX = flickable.contentX;
            let targetContentX = seekFrame * pxPerFrame + multiTrackView.x;
            if (speed > 0) {
                // 右侧触发，向左移动，此时计算的targetContentX需要再减去轨道的显示长度
                targetContentX -= flickable.width;
            }
            targetMoveDistance = targetContentX - oldContentX;
            // 因为我们修改了目标位置，有可能导致反向，所以限制一下
            if (speed > 0) {
                targetMoveDistance = Math.max(0, targetMoveDistance);
            } else {
                targetMoveDistance = Math.min(0, targetMoveDistance);
            }

            flickable.scrollBy(targetMoveDistance, 0);
            const newContentX = flickable.contentX;
            // 这里重新触发更新一下indicatorSeek.x
            // 一个作用是不更新指针就飘走了，需要更新触发seek的逻辑
            // 另一个作用是下次onTriggered也要用
            // 但是必须用newContentX - oldContentX，而不是直接 += targetMoveDistance，因为实际scrollBy还要受范围控制
            indicatorSeek.x += (newContentX - oldContentX);
        }
    }

    // 这个timer主要处理框选滑动到边缘时，自动滚动的逻辑
    Timer {
        id: multiIndicatorScrollTimer
        interval: 20
        repeat: true

        onTriggered: {
            const pxPerFrame = trackDockViewModel.scaleBase
            if (pxPerFrame <= 0 || !editorManager.isEditorPlay()) {
                return;
            }

            // 触发距离
            const triggerDistance = 30;
            const srcollSpeed = 10;
            // 左侧边缘，并不简单是0，因为轨道片段内容距离flickable最左侧还有东西，目前就是一个封面，也许后面还有其他
            const leftEdge = multiTrackView.visibleRect.x
            // 右侧边缘
            const rightEdge = multiTrackView.visibleRect.x + multiTrackView.visibleRect.width;
            // 轨道上下边缘（需要明确获取 multiTrackView 的可见范围）
            const topEdge = multiTrackView.visibleRect.y;
            const bottomEdge = multiTrackView.visibleRect.y + multiTrackView.visibleRect.height;
            // 这里就是指针拖动位置
            const triggerPos = Qt.point(dragSelectMouseArea.x + dragSelectMouseArea.currentX,
                                dragSelectMouseArea.y + dragSelectMouseArea.currentY);

            let fixedTopOffsetY = 0 , fixedBottomOffsetY = 0;
            // 顶部固定时，顶部偏移量为轨道高度减触发距离
            if(multiTrackView.scrollModel === 1 && !dragSelectMouseArea.isStartFromTopMainTrack) {
                fixedTopOffsetY = mainVideoTrackHead.height - triggerDistance;
            }
            else if(multiTrackView.scrollModel === 2 && !dragSelectMouseArea.isStartFromBottomMainTrack) {
                fixedBottomOffsetY = mainVideoTrackHead.height - triggerDistance + headerBottomHover.height;
            }

            // 指针拖动位置距离左侧边缘距离
            const distanceToLeftEdge = triggerPos.x - leftEdge;
            // 指针拖动位置距离右侧边缘距离
            const distanceToRightEdge = rightEdge - triggerPos.x;
            // 指针拖动位置距离顶部边缘距离
            const distanceToTopEdge = triggerPos.y - topEdge - fixedTopOffsetY;
            // 指针拖动位置距离底部边缘距离
            const distanceToBottomEdge = bottomEdge - triggerPos.y - fixedBottomOffsetY;


            let speedX = 0, speedY = 0;
            if (distanceToLeftEdge < triggerDistance) {
                speedX = (distanceToLeftEdge - triggerDistance) / triggerDistance;
            } else if (distanceToRightEdge < triggerDistance) {
                speedX = (triggerDistance - distanceToRightEdge) / triggerDistance;
            } 
            // 贴近顶部，且初始位置不在主轨道上
            if (distanceToTopEdge < triggerDistance && !dragSelectMouseArea.isStartFromTopMainTrack) {
                speedY = (distanceToTopEdge - triggerDistance) / triggerDistance;
            }
            // 贴近底部，且初始位置不在主轨道上
            else if (distanceToBottomEdge < triggerDistance && !dragSelectMouseArea.isStartFromBottomMainTrack) {
                speedY = (triggerDistance - distanceToBottomEdge) / triggerDistance;
            } 
            if (speedX === 0 && speedY === 0) {
                return;
            }
            let scrollDistanceX = speedX * srcollSpeed;
            let scrollDistanceY = speedY * srcollSpeed;
            flickable.scrollBy(scrollDistanceX, scrollDistanceY);
            if (multiTrackView.visibleRect.x > 0) {
                dragSelectMouseArea.currentX += scrollDistanceX
            }
            if (multiTrackView.visibleRect.y > 0) {
                dragSelectMouseArea.currentY += scrollDistanceY
            }
        }
    }

    // 拖拽过程中自动滚动
    Timer {
        id: scrollTimer
        interval: 20
        repeat: true
        onTriggered: {
            if (!flickable.isUnderFickableDrag) {
                return;
            }
            let x = flickable.dragMousePoint.x;
            let y = flickable.dragMousePoint.y;
            // 左右边缘距离
            let edge = 30;
            // 滑动的速度
            let distance = 20;
            var speedX = 0, speedY = 0;
            if (x < edge) {
                speedX = (x - edge) / (edge * 2);
                flickable.scrollBy(speedX * distance, 0);
            } else if (flickable.width - edge < x) {
                speedX = (x + edge - flickable.width) / (edge * 2);
                flickable.scrollBy(speedX * distance, 0);
            }
            let fixedTopOffsetY = 0 , fixedBottomOffsetY = 0;
            // 顶部固定时，顶部偏移量为轨道高度减触发距离
            if(multiTrackView.scrollModel === 1) {
                fixedTopOffsetY = mainVideoTrackHead.height
            }
            else if(multiTrackView.scrollModel === 2) {
                fixedBottomOffsetY = mainVideoTrackHead.height + headerBottomHover.height;
            }
            // 从素材区拖拽时，素材区位于轨道上方，拖拽起始鼠标尚未进入轨道区域。
            // 此时不应上下滚动轨道（否则会立刻滚到最顶部），只有鼠标进入轨道纵向区域后才允许上下滚动。
            let canScrollVertical = !multiTrackView.isDraggingMaterial || (y >= 0 && y <= flickable.height);
            if(canScrollVertical) {
                if(y - fixedTopOffsetY < edge) {
                    speedY = (y - fixedTopOffsetY - edge) / (edge * 2);
                    flickable.scrollBy(0, speedY * distance);
                } else if (flickable.height- edge < y + fixedBottomOffsetY ) {
                    speedY = (y + fixedBottomOffsetY + edge - flickable.height) / (edge * 2);
                    flickable.scrollBy(0, speedY * distance);
                }
            }

            let viewMousePoint = flickable.mapToItem(multiTrackView, flickable.dragMousePoint);
            if(speedX !== 0 || speedY !== 0) {
                // nova: 轨道内拖片段时，把自动滚动后的鼠标位置回喂给内核，片段随滚动跟随重排
                if (multiTrackView.novaDragClipId !== "") {
                    multiTrackView.novaClipDragMove(multiTrackView.novaDragClipId, viewMousePoint, false);
                } else if (flickable.novaMaterialDragKind !== 0) {
                    // nova: 素材拖入时，用记录的窗口坐标重放对应 move，内核按滚动后的内容坐标刷新落位
                    let wp = flickable.novaMaterialDragWindowPoint;
                    if (flickable.novaMaterialDragKind === 1) {
                        globalSignal.mediaDragAddMove(wp);
                    } else if (flickable.novaMaterialDragKind === 2) {
                        globalSignal.audioDragMove(wp);
                    } else if (flickable.novaMaterialDragKind === 3) {
                        globalSignal.overlayTextDragMove(wp);
                    }
                } else {
                    globalSignal.trackScrollStatus(viewMousePoint);
                }
            }
        }
    }
    // nova 素材拖入的自动滚动：记录种类/窗口坐标，回填滚动用鼠标位置，进入轨道纵向可视区才启停定时器
    function handleNovaMaterialDragMove(kind, windowPoint) {
        flickable.novaMaterialDragKind = kind;
        flickable.novaMaterialDragWindowPoint = windowPoint;
        // 统一回填滚动用坐标(flickable 局部)，兼容自身未更新 dragMousePoint 的素材(如文字)
        flickable.dragMousePoint = flickable.mapFromItem(null, windowPoint);
        let y = flickable.dragMousePoint.y;
        let inTrack = y >= 0 && y <= flickable.height;
        if (inTrack && !scrollTimer.running) {
            scrollTimer.restart();
        } else if (!inTrack && scrollTimer.running && !multiTrackView.isDragging) {
            // 文字素材另由 trackState 驱动定时器(isDragging)，此处不打断
            scrollTimer.stop();
        }
    }
    function endNovaMaterialDrag() {
        flickable.novaMaterialDragKind = 0;
        if (!multiTrackView.isDragging) {
            scrollTimer.stop();
        }
    }
    function rangeComposeScroll(originIndicator) {
        const pxPerFrame = trackDockViewModel.scaleBase
        if (pxPerFrame <= 0 || !editorManager.isEditorPlay()) {
            return
        }
        // 触发距离
        const triggerDistance = 30
        // 左侧边缘，并不简单是0，因为轨道片段内容距离flickable最左侧还有东西，目前就是一个封面，也许后面还有其他
        const leftEdge = Math.max(0, multiTrackView.x - flickable.contentX)
        // 右侧边缘
        const rightEdge = flickable.width
        // 这里就是指针拖动位置
        const triggerPos = originIndicator * pxPerFrame - flickable.contentX
        // 指针拖动位置距离左侧边缘距离
        const distanceToLeftEdge = triggerPos - leftEdge
        // 指针拖动位置距离右侧边缘距离
        const distanceToRightEdge = rightEdge - triggerPos
        let speed = 0
        if (distanceToLeftEdge < triggerDistance) {
            speed = (distanceToLeftEdge - triggerDistance) / triggerDistance
        } else if (distanceToRightEdge < triggerDistance) {
            speed = (triggerDistance - distanceToRightEdge) / triggerDistance
        } else {
            return
        }

        // 至少移动一帧的位置
        const sign = speed > 0 ? 1 : -1
        const step = 120
        let targetMoveDistance = sign * Math.max(pxPerFrame, Math.abs(speed) * step)
        // 这里需要尽可能移动到整帧的位置，做法就是多移动一点直到整帧位置
        const targetIndicatorX = originIndicator * pxPerFrame + targetMoveDistance
        const realX = targetIndicatorX
        // 触发了左侧边缘，需要向右移动轨道，此时需要帧的位置向小的方向多移动一些，所以用floor
        // 触发了右侧边缘，需要向左移动轨道，此时需要帧的位置向大的方向多移动一些，所以用ceil
        const seekFrame = speed < 0 ? Math.floor(realX / pxPerFrame) : Math.ceil(realX / pxPerFrame)
        const oldContentX = flickable.contentX
        let targetContentX = seekFrame * pxPerFrame
        if (speed > 0) {
            // 右侧触发，向左移动，此时计算的targetContentX需要再减去轨道的显示长度
            targetContentX -= flickable.width
        }
        targetMoveDistance = targetContentX - oldContentX
        // 因为我们修改了目标位置，有可能导致反向，所以限制一下
        if (speed > 0) {
            targetMoveDistance = Math.max(0, targetMoveDistance)
        } else {
            targetMoveDistance = Math.min(0, targetMoveDistance)
        }
        flickable.scrollBy(targetMoveDistance, 0)
    }
    //范围导出自动滚动
    Timer {
        id: rangeComposeInScrollTimer
        interval: 20
        repeat: true

        onTriggered: {
            const oldContentX = flickable.contentX;
            //此处只需要自动滚动，onRangeComposeUpdate负责更新位置
            rangeComposeScroll(rangeCompose.inRangeCompose);
            const newContentX = flickable.contentX;
            if(newContentX != oldContentX) {
                let newRangeInFrame = trackDockViewModel.rangeComposeIn + Math.round((newContentX - oldContentX) / trackDockViewModel.scaleBase);
                newRangeInFrame = Math.max(0, newRangeInFrame);
                newRangeInFrame = Math.min(newRangeInFrame, trackDockViewModel.rangeComposeOut)
                trackDockViewModel.rangeComposeIn = newRangeInFrame;
                trackDockViewModel.isRangeComposeChanged();
            }
        }
    }
    //范围导出自动滚动
    Timer {
        id: rangeComposeOutScrollTimer
        interval: 20
        repeat: true

        onTriggered: {
            //此处只需要自动滚动，onRangeComposeUpdate负责更新位置
            const oldContentX = flickable.contentX;
            //此处只需要自动滚动，onRangeComposeUpdate负责更新位置
            rangeComposeScroll(rangeCompose.outRangeCompose);
            const newContentX = flickable.contentX;
            if(newContentX != oldContentX) {
                let newRangeOutFrame = trackDockViewModel.rangeComposeOut + Math.round((newContentX - oldContentX) / trackDockViewModel.scaleBase);
                newRangeOutFrame = Math.max(trackDockViewModel.rangeComposeIn, newRangeOutFrame);
                newRangeOutFrame = Math.min(newRangeOutFrame, trackDockViewModel.totalFrame)
                trackDockViewModel.rangeComposeOut = newRangeOutFrame;
                trackDockViewModel.isRangeComposeChanged();
            }
        }
    }
    CShortcut {
        action: ShortcutAction.PREVIOUS_FRAME
        onActivated: {
            if (editorManager.playType === QPlayType.assetsPreview) return
            // 交互逻辑，当预览轴开启的时候，如果两个值不一致，快捷键seek会先将指针移动到当前预览轴的位置
            // 两个值不一致一定意味着当前是开启预览轴的
            if (trackDockViewModel.currentFrame === trackDockViewModel.indicatorFrame) {

                editorManager.seekPreFrame();
            }
            // 不要删除，这里只是一个保险措施，防止当前位置和seek位置一致，没有真正产生seek行为，从而没有正确更新的情况
            trackDockViewModel.syncIndicator();
            trackDockViewModel.previewFrame = trackDockViewModel.currentFrame;
        }
    }

    CShortcut {
        action: ShortcutAction.NEXT_FRAME
        onActivated: {
            if (editorManager.playType === QPlayType.assetsPreview) return
            // 交互逻辑，当预览轴开启的时候，如果两个值不一致，快捷键seek会先将指针移动到当前预览轴的位置
            // 两个值不一致一定意味着当前是开启预览轴的
            if (trackDockViewModel.currentFrame === trackDockViewModel.indicatorFrame) {
                editorManager.seekNextFrame();
            }
            // 不要删除，这里只是一个保险措施，防止当前位置和seek位置一致，没有真正产生seek行为，从而没有正确更新的情况
            trackDockViewModel.syncIndicator();
            trackDockViewModel.previewFrame = trackDockViewModel.currentFrame;
        }
    }

    CShortcut {
        action: ShortcutAction.PREVIOUS_TEN_FRAME
        onActivated: {
            if (editorManager.playType === QPlayType.assetsPreview) return
            if (trackDockViewModel.currentFrame === trackDockViewModel.indicatorFrame) {
                editorManager.seekPreviousNFrame(10);
            }

            // 不要删除，这里只是一个保险措施，防止当前位置和seek位置一致，没有真正产生seek行为，从而没有正确更新的情况
            trackDockViewModel.syncIndicator();
            trackDockViewModel.previewFrame = trackDockViewModel.currentFrame;
        }
    }

    CShortcut {
        action: ShortcutAction.NEXT_TEN_FRAME
        onActivated: {
            if (editorManager.playType === QPlayType.assetsPreview) return
            // 交互逻辑，当预览轴开启的时候，如果两个值不一致，快捷键seek会先将指针移动到当前预览轴的位置
            // 两个值不一致一定意味着当前是开启预览轴的
            if (trackDockViewModel.currentFrame === trackDockViewModel.indicatorFrame) {
                editorManager.seekNextNFrame(10);
            }
            // 不要删除，这里只是一个保险措施，防止当前位置和seek位置一致，没有真正产生seek行为，从而没有正确更新的情况
            trackDockViewModel.syncIndicator();
            trackDockViewModel.previewFrame = trackDockViewModel.currentFrame;
        }
    }

    CShortcut {
        action: ShortcutAction.UP
        onActivated: {
            if (editorManager.playType === QPlayType.assetsPreview) return
            // 交互逻辑，当预览轴开启的时候，如果两个值不一致，快捷键seek会先将指针移动到当前预览轴的位置
            // 两个值不一致一定意味着当前是开启预览轴的
            if (trackDockViewModel.currentFrame === trackDockViewModel.indicatorFrame) {
                editorManager.seekPreviousTrackHead();
            }
            // 不要删除，这里只是一个保险措施，防止当前位置和seek位置一致，没有真正产生seek行为，从而没有正确更新的情况
            trackDockViewModel.syncIndicator();
            trackDockViewModel.previewFrame = trackDockViewModel.currentFrame;
        }
    }

    CShortcut {
        action: ShortcutAction.DOWN
        onActivated: {
            if (editorManager.playType === QPlayType.assetsPreview) return
            if (trackDockViewModel.currentFrame === trackDockViewModel.indicatorFrame) {
                editorManager.seekNextTrackEnd();
            }
            // 不要删除，这里只是一个保险措施，防止当前位置和seek位置一致，没有真正产生seek行为，从而没有正确更新的情况
            trackDockViewModel.syncIndicator();
            trackDockViewModel.previewFrame = trackDockViewModel.currentFrame;
        }
    }

    function realDeleteAllSelectFragment() {
        // nova: video/audio 片段删除走 nle 选中。单选且选中 tk 片段时跳过(应删 tk 片段而非整段轨道片段)；
        // 多选下仍按删素材处理。
        if ((!root.hasSelectedTrackingFragment || multiTrackDataProvider.isMultiSelect()) &&
                TimelineEditController.deleteSelected()) {
            return;
        }
        globalSignal.trackingSegmentRemoveAction(false)
        root.clearTrackingSelection();
    }

    // 删除关键帧或片段
    CShortcut {
        action: ShortcutAction.DELETE
        enabled: root.visible
        onActivated: {
            // 判断是否有仪表被选中，有则删除
            if (dashboardManager.isStickerSelected()) {
                globalSignal.removeSticker(dashboardManager.getSelectedStickerType());
                return;
            }
            //看看当前是否有选中的转场片段
            if (transitionManager.isTransitionSelected()) {
                transitionManager.deleteTransition(transitionManager.selectedTrackId(), transitionManager.selectedClipId());
                return;
            }

            // 看看当前有没有普通关键帧或选中的区域关键帧
            // 多选状态下不删除关键帧，直接删除素材，避免单次删除关键帧后选中状态被清除导致素材无法继续删除
            if (!multiTrackDataProvider.isMultiSelect() &&
                    keyframeViewModel.onClick(KeyframeBtnViewModel.ShortCut, KeyframeBtnViewModel.Delete)) {
                return;
            }

            // nova: video/audio 片段删除走 nle 选中（与单击/框选高亮同源）。
            // 单选且选中 tk 片段时跳过：应删 tk 片段而非整段轨道片段（tk 删除在下方 trackingSegmentRemoveAction）；
            // 多选下仍按删素材处理。
            if ((!root.hasSelectedTrackingFragment || multiTrackDataProvider.isMultiSelect()) &&
                    TimelineEditController.deleteSelected()) {
                return;
            }

            // 因为tracking片段在视频轨上，所以监听到DELETE键时，先执行删除tracking片段的逻辑，删除失败后，再删除视频片段
            globalSignal.trackingSegmentRemoveAction(false)
            root.clearTrackingSelection();
        }
    }

    // 添加关键帧快捷键
    CShortcut {
        action: ShortcutAction.ADD_PANORAMA_KEYFRAME
        onActivated: {
            keyframeViewModel.onClick(KeyframeBtnViewModel.ShortCut, KeyframeBtnViewModel.AddNormalKeyframe);
        }
    }

    // 删除关键帧快捷键
    CShortcut {
        action: ShortcutAction.REMOVE_PANORAMA_KEYFRAME
        onActivated: {
            keyframeViewModel.onClick(KeyframeBtnViewModel.ShortCut, KeyframeBtnViewModel.RemoveNormalKeyframe);
        }
    }

    // 添加区域关键帧快捷键
    CShortcut {
        action: ShortcutAction.ADD_PANORAMA_REGION_KEYFRAME
        onActivated: {
            keyframeViewModel.onClick(KeyframeBtnViewModel.ShortCut, KeyframeBtnViewModel.AddRegionKeyframe);
        }
    }

    // 删除区域关键帧快捷键
    CShortcut {
        action: ShortcutAction.REMOVE_PANORAMA_REGION_KEYFRAME
        onActivated: {
            keyframeViewModel.onClick(KeyframeBtnViewModel.ShortCut, KeyframeBtnViewModel.RemoveRegionKeyframe);
        }
    }

    // 复制关键帧或者片段快捷键
    CShortcut {
        action: ShortcutAction.COPY
        enabled: root.visible === true
        onActivated: {
            eventTracker.trackEvent("pccut_copy_click", {"use_method": "shortcut"});
            // 优先复制选中关键帧(nova)；无选中关键帧则回落复制片段。与 Ctrl+V 路径对称。
            if (keyframeViewModel.copyOneSelectedKeyframe(true) === false) {
                // nova: 复制片段走 nle(暂存选中片段视图，Cmd+V 用 CopyClipFromViewCmd 粘贴)。
                if (TimelineEditController.copy()) {
                    // 关键帧/片段剪贴板互斥，最后一次复制生效。
                    keyframeViewModel.clearKeyframeClipboard();
                }
            }
        }
    }

    // 粘贴关键帧或者片段快捷键
    CShortcut {
        action: ShortcutAction.PASTE
        enabled: root.visible === true
        onActivated: {
            eventTracker.trackEvent("pccut_paste_click", {"use_method": "shortcut"});
            // 单选粘贴关键帧
            var pasted = keyframeViewModel.pasteOneSelectedKeyframe(true);
            if(pasted === false) {
                // nova: 粘贴片段走 nle(CopyClipFromViewCmd 复制到主视频轨，播放头处就近吸附插入，单步 undo)。
                TimelineEditController.paste(editBasePosition());
            }
        }
    }
    // 快速添加默认文本
    CShortcut {
        action: ShortcutAction.ADD_DEFAULT_TEXT
        enabled: root.visible === true
        onActivated: {
            // eventTracker.trackEvent("pccut_add_default_text_click", {"use_method": "shortcut"});、
            addOrDeleteFragmentController.addDefaultText();
        }
    }

    // 范围导出入点快捷键
    CShortcut {
        action: ShortcutAction.ROUGH_IN
        enabled: indicator.enabled && root.visible === true
        onActivated: {
            if(rangeComposeInScrollTimer.running){
                rangeComposeInScrollTimer.stop();
            }
            var params = {"subActionCode": 1, "rangeIn": trackDockViewModel.indicatorFrame};
            trackDockViewModel.changeRangeComposeByManual(params)
        }
    }

    // 范围导出入点快捷键
    CShortcut {
        action: ShortcutAction.ROUGH_OUT
        enabled: indicator.enabled && root.visible === true
        onActivated: {
            if(rangeComposeOutScrollTimer.running){
                rangeComposeOutScrollTimer.stop();
            }
            var params = {"subActionCode": 2, "rangeOut": trackDockViewModel.indicatorFrame};
            trackDockViewModel.changeRangeComposeByManual(params)
        }
    }

    //全选
    CShortcut {
        action: ShortcutAction.SELECT_ALL
        enabled: root.visible === true
        onActivated: {
            multiSelectController.selectAllFragments();
            globalSignal.multiSelectStateChanged(false)
        }
    }
}
