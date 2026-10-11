/**
    * @author: dendi.zheng
    * @details:  单个关键帧布局，包括关键帧图标、当前关键帧和下一个关键帧图标的连接线、过渡效果图标， 当前view的x坐标会左移半个关键帧图标宽度，让关键帧图标中心恰好对应上时间
    * @date: 2024-08-14 21:23:34
    */
import QtQuick 2.15
import PanoramaKeyframe 1.0
import Config 1.0
import Controls 1.0
import KeyframeItemData 1.0
import VideoFragmentViewModel 1.0
import Nova 1.0
import QTractorType 1.0
import "../tracking"
import "../controller"
import app_qrc 1.0

Item {
    id: keyframeItemRoot
    // 变速后同位置重叠隐藏：隐藏的散点/区域/运镜组内帧整体不显示(图标/连线一并消隐)。
    // 段(tk/区域/运镜段)不参与重叠隐藏，恒显示。
    visible: CommonUtils.isNull(keyframeInfo) || keyframeInfo.dataType !== KeyframeItemData.Keyframe || keyframeInfo.visible
    z: !CommonUtils.isNull(keyframeInfo) && keyframeInfo.dataType == KeyframeItemData.Keyframe ? 10 : 1  // 运镜模版中的关键帧的层级是最高的
    // 关键帧是否在编辑中（点击选中就会进入编辑态）
    property bool isKeyFrameEditing: false
    // 轨道index
    property int trackIndex: -1
    // 片段index
    property int clipIndex: -1
    // 关键帧数据， 这里用的是一个自定义的数据结构，没有使用多轨道数据中的，避免轨道和播放器都在修改关键帧数据
    property KeyframeItemData keyframeInfo
    // 当前片段的数据（nova：TimelineVideoClipViewModel，frameIn/trackFrameIn 等直接读，单位 MK）
    property TimelineVideoClipViewModel viewModel
    // 当前片段是否被选中
    property bool videoItemSelected: false
    // 时间指示器的位置（帧）
    property real indicator_frame
    // 每帧多少像素，对应缩放比
    property real pxPerFrame

    // 记录关键帧按钮按下时，关键帧的原始位置，用来复位用
    property int pressPositon: -1
    // 记录关键帧按下拖拽距离，用来复位用
    property int pressDragLength: -1

    // 记录关键帧是否有实际拖动
    property bool keyFrameHasDrag: false

    // 防抖相关控制
    property bool hasPendingDrag: false
    property var pendingKeyframe: null
    property real pendingNewX: 0
    property int pendingOriginPosition: 0

    // tracking方框控件是否已加载
    property bool trackingSegmentLoaded: false

    // 视频轨可见的最左侧px
    property real trackVisibleLeft: 0
    // 视频轨可见的最右侧px
    property real trackVisibleRight: 0
    property real parentWidth: 0
    property real parentX
    property real oldParentX: 0

    // 鼠标是否hover在过渡效果上（过渡效果的icon上或过渡效果连线上）
    property bool keyframeConnectViewHover: false
    // 区域关键帧模式下，是有base数据的，此时连接线仅可能出现在同一段区域的普通关键帧身上
    property bool regionKfSupport: false

    // 点击关键帧的回调
    signal keyframeClick();
    signal keyframeRightClick(bool selected, real windowPointX, real windowPointY);

    // 关键帧对应的时间线帧号：优先读内核帧栅格(timelineFrame)，解析失败回退 MK 帧栅格换算；
    // mkEpsilon 为回退路径的浮点补偿(选中态判定传 1，对齐原 +1 MK)
    function keyframeTimelineFrame(mkEpsilon = 0) {
        if (!CommonUtils.isNull(keyframeInfo) && keyframeInfo.timelineFrame >= 0) {
            return keyframeInfo.timelineFrame
        }
        return Math.floor(editorManager.frameByPosition(trackFrameIn + keyframeInfo.speedPosition - frameIn + mkEpsilon))
    }

    property real frameIn: CommonUtils.isNull(viewModel) || !viewModel.hasFragment ? 0 : viewModel.frameIn
    property real frameOut: CommonUtils.isNull(viewModel) || !viewModel.hasFragment ? 0 : viewModel.frameOut

    property int trackFrameIn: CommonUtils.isNull(viewModel) || !viewModel.hasFragment ? 0 : viewModel.trackFrameIn

    property real speedNextTkFragmentClipStart: CommonUtils.isNull(keyframeInfo) ? 0 : keyframeInfo.speedNextTkFragmentClipStart
    property real speedClipEnd: CommonUtils.isNull(keyframeInfo) ? 0 : keyframeInfo.speedClipEnd

    property real nextTkFragmentClipStart: CommonUtils.isNull(keyframeInfo) ? 0 : keyframeInfo.nextTkFragmentClipStart
    property real clipEnd: CommonUtils.isNull(keyframeInfo) ? 0 : keyframeInfo.clipEnd

    // 标志关键帧是否处于选择状态
    property bool keyframeSelectStatus: false

    onKeyframeConnectViewHoverChanged: {
        keyFrameConnectionView.visible = getKeyFrameConnectionViewVisibleState()
    }

    // 排序或者删除后 trackFrameIn 会刷新 但是播放的位置可能没有变化, 关键帧的UI状态需要刷新
    onTrackFrameInChanged: {
        refreshKeyFrameEditing(true);
    }

    onFrameInChanged: {
        refreshKeyFrameEditing(true);
    }


    // 拖拽关键帧回调
    signal keyframeDrag(var keyframe, var newX, var originPositon, bool end)
    // 关键帧连接线， 要在UI层级的最下面，从当前关键帧的中心点画到下个关键帧的中心点

    // 是否是tracking片段类型
    function isTrackingFragment() {
        return !CommonUtils.isNull(keyframeInfo) && (keyframeInfo.dataType == KeyframeItemData.Tracking || keyframeInfo.dataType == KeyframeItemData.Region || keyframeInfo.dataType == KeyframeItemData.CameraMove);
    }

    // 是否是运镜模版的片段
    function isMovementFragment(){
        return !CommonUtils.isNull(keyframeInfo) && (keyframeInfo.dataType == KeyframeItemData.CameraMove);
    }

    function calcConnectLineWidth() {
        if (isTrackingFragment() && !isMovementFragment()) {
            return keyframeItemRoot.width - trackingSegment.segmentWidth
                   - keyFrameImageView.width / 2
                   - editorManager.frameByPosition(keyframeInfo.speedClipStart - keyframeInfo.speedStart) * pxPerFrame
        }
        return keyframeItemRoot.width - keyFrameImageView.width / 2
    }

    function refreshTrackingUi() {
        var xxx = editorManager.frameByPosition(keyframeInfo.speedClipStart - keyframeInfo.speedStart)*pxPerFrame
        var trackingSegmentWidth = editorManager.frameByPosition(keyframeInfo.speedClipEnd - keyframeInfo.speedClipStart)*pxPerFrame

        trackingSegment.segmentWidth = trackingSegmentWidth
        trackingSegment.originSegmentWidth = editorManager.frameByPosition(keyframeInfo.speedEnd - keyframeInfo.speedStart)*pxPerFrame
        trackingSegment.x = xxx
        keyFrameConnectLine.width = Qt.binding(calcConnectLineWidth)
        keyFrameConnectionView.visible = getKeyFrameConnectionViewVisibleState()
    }

    function refreshCameralMoveSegment() {
        var xxx = editorManager.frameByPosition(keyframeInfo.speedClipStart - keyframeInfo.speedStart)*pxPerFrame
        var trackingSegmentWidth = editorManager.frameByPosition(keyframeInfo.speedClipEnd - keyframeInfo.speedClipStart)*pxPerFrame

        effectSegmentViewBase.segmentWidth = trackingSegmentWidth
        effectSegmentViewBase.originSegmentWidth = editorManager.frameByPosition(keyframeInfo.speedEnd - keyframeInfo.speedStart)*pxPerFrame
        effectSegmentViewBase.x = xxx
        keyFrameConnectLine.width = Qt.binding(calcConnectLineWidth)
        keyFrameConnectionView.visible = getKeyFrameConnectionViewVisibleState()
    }

    // 取消TK, 区域关键帧，运镜模版片段UI的选中态
    function clearClipUiSelected(){
        if(trackingSegment.visible){
            trackingSegment.updateFragmentUi(false, false);
        }

        if(effectSegmentViewBase.visible){
            effectSegmentViewBase.updateFragmentUi(false, false);
        }
    }

    // 关键帧连接线
    Rectangle {
        id: keyFrameConnectLine

        property color hoverColor: (!CommonUtils.isNull(keyframeInfo) && keyframeInfo.isKeyframeInRegion()) ? Colors.color_FFFFFF : ColorsConfig.color_brand
        property color normalColor: (!CommonUtils.isNull(keyframeInfo) && keyframeInfo.isKeyframeInRegion()) ? Colors.color_FFFFFF_50 : ColorsConfig.color_brand_50
        property real segmentWidth: isMovementFragment() ? effectSegmentViewBase.segmentWidth : trackingSegment.segmentWidth

        width: calcConnectLineWidth()

        x : isTrackingFragment() ? segmentWidth + editorManager.frameByPosition(keyframeInfo.speedClipStart - keyframeInfo.speedStart) * pxPerFrame : keyFrameImageView.width / 2
        height: 2

        // 区域关键帧下，只有区域关键帧上的普通关键帧才能连接，其他的关键帧都被Base数据截断了
        // 在这里设置条件来实现
        visible: !CommonUtils.isNull(keyframeInfo) && keyframeInfo.dataType !== KeyframeItemData.CameraMove && keyframeInfo.nextDataType !== KeyframeItemData.DataTypeUnknown && (!regionKfSupport || (keyframeInfo.dataType == KeyframeItemData.Keyframe && keyframeInfo.nextDataType == KeyframeItemData.Keyframe)) && keyframeItemRoot.width - (keyFrameImageView.width * keyFrameImageView.scaleFactor) > 0 && !CommonUtils.isNull(keyframeInfo)

        function isVisble(){
            if(CommonUtils.isNull(keyframeInfo)){
                return false;
            }

            if(!(keyframeItemRoot.width - (keyFrameImageView.width * keyFrameImageView.scaleFactor) > 0)){
                return false;
            }

            if(keyframeInfo.dataType === KeyframeItemData.CameraMove){
                if(keyframeInfo.nextDataType == KeyframeItemData.Keyframe){
                    return true;
                }
                return false;
            }else {

            }
        }

        color: !CommonUtils.isNull(keyframeInfo) ? ((pxPerFrame > 0
                && keyframeItemRoot.indicator_frame >= ((trackFrameIn + (isTrackingFragment() ? (keyframeInfo.speedClipStart - frameIn) : (keyframeInfo.speedPosition - frameIn))) / (30000 / 30))
                && keyframeItemRoot.indicator_frame < ((trackFrameIn + keyframeInfo.speedPosition - frameIn) / (30000 / 30) + (parent.width - keyFrameImageView.width / 2) / pxPerFrame)
                && keyframeItemRoot.indicator_frame >= (trackFrameIn / (30000 / 30))
                && keyframeItemRoot.indicator_frame <= ((trackFrameIn + frameOut - frameIn) / (30000 / 30)))
                && keyframeSelectStatus && videoItemSelected) || (keyframeConnectViewHover)
                ? hoverColor : normalColor : Colors.transparent // 最后这个透明色是判空时兜底的默认值，无实际意义

        anchors.verticalCenter: isTrackingFragment() ? trackingSegment.verticalCenter : keyFrameImageView.verticalCenter
        anchors.verticalCenterOffset: isTrackingFragment() && !trackingSegment.collapse ? 2 : 0
        MouseArea {
            id: keyframeConnectLineMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: (mouse) => {
                if (keyframeInfo !== null && keyframeInfo.start < 0 && keyframeInfo.nextKeyFrameIsTkFragment) {
                    seek((mouse.x - 6)/ keyFrameConnectLine.width)
                } else {
                    seek(mouse.x / keyFrameConnectLine.width)
                }

                if (!videoItemSelected) {
                    keyframeItemRoot.keyframeClick()
                }

                keyframeSelectStatus = true
                keyFrameConnectionView.visible = getKeyFrameConnectionViewVisibleState()
                globalSignal.switchPanoromaPanel()
                
                // 点击过渡线也需要选中区域关键帧
                if (!CommonUtils.isNull(keyframeInfo) && (keyframeInfo.isKeyframeInRegion() || keyframeInfo.isKeyframeInMovement())) {
                    globalSignal.selectRegion(keyframeInfo.track, keyframeInfo.clip, keyframeInfo.segmentId);
                }
            }

            onEntered: {
                keyframeConnectViewHover = true
            }

            onExited: {
                keyframeConnectViewHover = false
            }
        }

        Connections {
            target: globalSignal
            function onKeyframeDrag(track, clip, keyframeInfo) {
                if (track !== root.trackIndex || clip !== root.clipIndex) {
                    return
                }

                keyFrameConnectLine.width = Qt.binding(calcConnectLineWidth)

            }
        }
    }

    // 片段退出选中态回调， 让关键帧和关键帧连接图标也退出编辑态，并且更新图标
    onVideoItemSelectedChanged: {
        if (!videoItemSelected) {
            isKeyFrameEditing = false;
            keyframeInfo.isTransitionEditing = false;
            keyframeSelectStatus = false
            keyFrameConnectionView.visible = getKeyFrameConnectionViewVisibleState();
            clearClipUiSelected();  // 片段取消选中时收起 TK/区域/运镜段，回到非选中收起态
        }
    }
    // 时间指示器位置移动，如果不在当前关键帧了， 需要刷新状态
    onIndicator_frameChanged: {
        refreshKeyFrameEditing(true);
    }
    function refreshKeyFrameEditing(isPlaying) {
        if (keyframeInfo === null) {
            return;
        }

        if (keyframeItemRoot.indicator_frame !== keyframeItemRoot.keyframeTimelineFrame()) {
            isKeyFrameEditing = false
        }

        // 段内窗口末端按变速域取 speedClipEnd（勿与源域 frameOut 混比：慢放下 frameOut 会误夹断）。
        var tmpEnd = keyframeInfo.speedClipEnd
        var tmpStart = frameIn >= keyframeInfo.speedClipStart ? frameIn : keyframeInfo.speedClipStart

        trackingSegment.updateIsTrackingChanged(keyframeItemRoot.indicator_frame >= editorManager.frameByPosition(trackFrameIn + tmpStart - frameIn) &&
                keyframeItemRoot.indicator_frame <= editorManager.frameByPosition(trackFrameIn + tmpEnd - frameIn), isPlaying)

        if(isMovementFragment()){
            effectSegmentViewBase.updateIsTrackingChanged(keyframeItemRoot.indicator_frame >= editorManager.frameByPosition(trackFrameIn + tmpStart - frameIn) &&
                                                keyframeItemRoot.indicator_frame <= editorManager.frameByPosition(trackFrameIn + tmpEnd - frameIn), isPlaying)
        }

        keyFrameConnectionView.visible = getKeyFrameConnectionViewVisibleState()
    }

    onIsKeyFrameEditingChanged: {
        globalSignal.panoramaKeyframeActiveChanged(trackIndex, clipIndex, keyframeInfo.position, isKeyFrameEditing);
    }

    // 监听parentX变化，来刷新轨道tracking的ui，主要处理轨道缩放时的ui刷新，原来是通过pxPerFrame的变化来刷新ui的，但是监听它时，绘制ui依赖parentX，有时候，parentX滞后pxPerFrame的变化，此时绘制ui就有问题，所以两个都监听
    // 改成了监听parentWidth的变化，这是为了防止parent的x没有发生变化，所以没有刷新的bug。比如start是0的情况下就会这样
    onParentWidthChanged: {
    // onParentXChanged: {
        if (!trackingSegmentLoaded || keyframeInfo == null) {
            return
        }
        if(isMovementFragment()){
            refreshCameralMoveSegment()
        }else{
            refreshTrackingUi()
        }
        oldParentX = parentX
    }

    // 监听pxPerFrame变化，主要为了处理tk片段左裁切时，更新tk片段的x值的逻辑
    onPxPerFrameChanged: {
        if (!trackingSegmentLoaded || keyframeInfo == null) {
            return
        }

        if(isMovementFragment()){
            refreshCameralMoveSegment()
        }else{
            refreshTrackingUi()
        }
    }

    EffectSegmentViewBase {
        id: effectSegmentViewBase
        enabled: isMovementFragment()
        segmentId: keyframeInfo != null ? keyframeInfo.segmentId : ""
        segmentWidth: keyframeInfo != null ? editorManager.frameByPosition(keyframeInfo.speedClipEnd - keyframeInfo.speedClipStart)*pxPerFrame : 0
        originSegmentWidth: keyframeInfo != null ? editorManager.frameByPosition(keyframeInfo.speedEnd - keyframeInfo.speedStart)*pxPerFrame : 0

        trackingframeInfo: keyframeInfo
        videoTrackIndex: trackIndex
        videoClipIndex: clipIndex
        visibleLeft: trackVisibleLeft
        visibleRight: trackVisibleRight
        visible: isMovementFragment()

        Connections {
            target: effectSegmentViewBase
            function onClickTrackingSegment(ratio) {

                if (keyframeInfo == null) {
                    return
                }
                // 代码优化，只有当前片段没有选中时，点击tk片段才会执行选中片段的逻辑
                if (!videoItemSelected) {
                    keyframeItemRoot.keyframeClick()
                }

                if (isMovementFragment()) {
                    var tmpEnd = keyframeInfo.speedClipEnd
                    var tmpStart = frameIn >= keyframeInfo.speedClipStart ? frameIn : keyframeInfo.speedClipStart
                    const inSegment = keyframeItemRoot.indicator_frame >= editorManager.frameByPosition(trackFrameIn + tmpStart - frameIn) && keyframeItemRoot.indicator_frame <= editorManager.frameByPosition(trackFrameIn + tmpEnd - frameIn)
                    // 删除需要指示器在中间，不然如果仅选中不跳转的话，删除可能会出问题
                    // 这里参数比较奇怪，其实是指针如果已经在区域关键帧内了，再在内部点击区域，指针不会跟着跳了
                    if (ratio >= 0 && (keyframeInfo.dataType == KeyframeItemData.Tracking || !inSegment) && !CommonUtils.isNull(viewModel) && viewModel.hasFragment) {
                        // 跳转到seek指定位置
                        var positon = -frameIn + keyframeInfo.speedClipStart + (keyframeInfo.speedClipEnd - keyframeInfo.speedClipStart) * ratio
                        editorManager.seek((viewModel.trackFrameIn + positon) / (30000 / 30))
                    }
                }

                keyframeSelectStatus = true
                keyFrameConnectionView.visible = getKeyFrameConnectionViewVisibleState()
                refreshKeyFrameEditing(false)
                globalSignal.switchPanoromaPanel()
                keyFrameChange();
            }
        }

        Connections {
            target: keyframeInfo
            function onClipStartChanged() {
                effectSegmentViewBase.x = keyframeInfo != null ? editorManager.frameByPosition(keyframeInfo.speedClipStart - keyframeInfo.speedStart)*pxPerFrame : 0
                effectSegmentViewBase.segmentWidth = keyframeInfo != null ? editorManager.frameByPosition(keyframeInfo.speedClipEnd - keyframeInfo.speedClipStart)*pxPerFrame : 0
            }

            function onClipEndChanged() {
                effectSegmentViewBase.segmentWidth = keyframeInfo != null ? editorManager.frameByPosition(keyframeInfo.speedClipEnd - keyframeInfo.speedClipStart)*pxPerFrame : 0
            }


            function onStartChanged() {
                effectSegmentViewBase.segmentWidth = keyframeInfo != null ? editorManager.frameByPosition(keyframeInfo.speedClipEnd - keyframeInfo.speedClipStart)*pxPerFrame : 0
                effectSegmentViewBase.originSegmentWidth = keyframeInfo != null ? editorManager.frameByPosition(keyframeInfo.speedEnd - keyframeInfo.speedStart)*pxPerFrame: 0
            }

            function onEndChanged() {
                effectSegmentViewBase.segmentWidth = keyframeInfo != null ? editorManager.frameByPosition(keyframeInfo.speedClipEnd - keyframeInfo.speedClipStart)*pxPerFrame : 0
                effectSegmentViewBase.originSegmentWidth = keyframeInfo != null ? editorManager.frameByPosition(keyframeInfo.speedEnd - keyframeInfo.speedStart)*pxPerFrame : 0
            }
        }

        Connections {
            target: globalSignal
            function onRefreshPanoramaKeyframeUi() {
                effectSegmentViewBase.x = keyframeInfo != null ? editorManager.frameByPosition(keyframeInfo.speedClipStart - keyframeInfo.speedStart)*pxPerFrame : 0
                effectSegmentViewBase.segmentWidth = keyframeInfo != null ? editorManager.frameByPosition(keyframeInfo.speedClipEnd - keyframeInfo.speedClipStart)*pxPerFrame : 0
                effectSegmentViewBase.originSegmentWidth = keyframeInfo != null ? editorManager.frameByPosition(keyframeInfo.speedEnd - keyframeInfo.speedStart)*pxPerFrame : 0
            }

            function onRemoveKeyFrameSelect() {
                isKeyFrameEditing = false;
                if (keyframeInfo != null) {
                    keyframeInfo.isTransitionEditing = false;
                }
                keyframeSelectStatus = false
                keyFrameConnectionView.visible = getKeyFrameConnectionViewVisibleState();
            }
        }

        Component.onCompleted: {
            trackingSegmentLoaded = true
            effectSegmentViewBase.x = editorManager.frameByPosition(keyframeInfo.speedClipStart - keyframeInfo.speedStart)*pxPerFrame
            // 段建好后立刻按当前播放头评估选中：onCompleted 已全选展开，这里把播放头不在段内的收起，
            // 在段内的维持选中。重开时属性不再变、refreshKeyFrameEditing 不会再触发，故须主动补一次。
            refreshKeyFrameEditing(false)
        }
    }

    TrackingSegment {
        id: trackingSegment
        segmentWidth: keyframeInfo != null ? editorManager.frameByPosition(keyframeInfo.speedClipEnd - keyframeInfo.speedClipStart)*pxPerFrame : 0
        originSegmentWidth: keyframeInfo != null ? editorManager.frameByPosition(keyframeInfo.speedEnd - keyframeInfo.speedStart)*pxPerFrame : 0

        trackingframeInfo: keyframeInfo
        videoTrackIndex: trackIndex
        videoClipIndex: clipIndex
        visibleLeft: trackVisibleLeft
        visibleRight: trackVisibleRight
        visible: isTrackingFragment() && !isMovementFragment()

        Connections {
            target: trackingSegment
            function onClickTrackingSegment(ratio) {

                if (keyframeInfo == null) {
                    return
                }
                // 代码优化，只有当前片段没有选中时，点击tk片段才会执行选中片段的逻辑
                if (!videoItemSelected) {
                    keyframeItemRoot.keyframeClick()
                }

                if (isTrackingFragment()) {
                    var tmpEnd = keyframeInfo.speedClipEnd
                    var tmpStart = frameIn >= keyframeInfo.speedClipStart ? frameIn : keyframeInfo.speedClipStart
                    const inSegment = keyframeItemRoot.indicator_frame >= editorManager.frameByPosition(trackFrameIn + tmpStart - frameIn) && keyframeItemRoot.indicator_frame <= editorManager.frameByPosition(trackFrameIn + tmpEnd - frameIn)
                    // 删除需要指示器在中间，不然如果仅选中不跳转的话，删除可能会出问题
                    // 这里参数比较奇怪，其实是指针如果已经在区域关键帧内了，再在内部点击区域，指针不会跟着跳了
                    if (ratio >= 0 && (keyframeInfo.dataType == KeyframeItemData.Tracking || !inSegment) && !CommonUtils.isNull(viewModel) && viewModel.hasFragment) {
                        // 跳转到seek指定位置
                        var positon = -frameIn + keyframeInfo.speedClipStart + (keyframeInfo.speedClipEnd - keyframeInfo.speedClipStart) * ratio
                        editorManager.seek((viewModel.trackFrameIn + positon) / (30000 / 30))
                    }
                }

                keyframeSelectStatus = true
                keyFrameConnectionView.visible = getKeyFrameConnectionViewVisibleState()
                refreshKeyFrameEditing(false)
                globalSignal.switchPanoromaPanel()
            }
        }

        Connections {
            target: keyframeInfo
            function onClipStartChanged() {
                trackingSegment.x = keyframeInfo != null ? editorManager.frameByPosition(keyframeInfo.speedClipStart - keyframeInfo.speedStart)*pxPerFrame : 0
                trackingSegment.segmentWidth = keyframeInfo != null ? editorManager.frameByPosition(keyframeInfo.speedClipEnd - keyframeInfo.speedClipStart)*pxPerFrame : 0
            }

            function onClipEndChanged() {
                trackingSegment.segmentWidth = keyframeInfo != null ? editorManager.frameByPosition(keyframeInfo.speedClipEnd - keyframeInfo.speedClipStart)*pxPerFrame : 0
            }


            function onStartChanged() {
                trackingSegment.segmentWidth = keyframeInfo != null ? editorManager.frameByPosition(keyframeInfo.speedClipEnd - keyframeInfo.speedClipStart)*pxPerFrame : 0
                trackingSegment.originSegmentWidth = keyframeInfo != null ? editorManager.frameByPosition(keyframeInfo.speedEnd - keyframeInfo.speedStart)*pxPerFrame: 0
            }

            function onEndChanged() {
                trackingSegment.segmentWidth = keyframeInfo != null ? editorManager.frameByPosition(keyframeInfo.speedClipEnd - keyframeInfo.speedClipStart)*pxPerFrame : 0
                trackingSegment.originSegmentWidth = keyframeInfo != null ? editorManager.frameByPosition(keyframeInfo.speedEnd - keyframeInfo.speedStart)*pxPerFrame : 0
            }
        }

        Connections {
            target: globalSignal
            function onRefreshPanoramaKeyframeUi() {
                trackingSegment.x = keyframeInfo != null ? editorManager.frameByPosition(keyframeInfo.speedClipStart - keyframeInfo.speedStart)*pxPerFrame : 0
                trackingSegment.segmentWidth = keyframeInfo != null ? editorManager.frameByPosition(keyframeInfo.speedClipEnd - keyframeInfo.speedClipStart)*pxPerFrame : 0
                trackingSegment.originSegmentWidth = keyframeInfo != null ? editorManager.frameByPosition(keyframeInfo.speedEnd - keyframeInfo.speedStart)*pxPerFrame : 0
            }

            // 接受手动裁切结束后，刷新tracking 连接线和连接状态ui
            function onUpdateTrackingFragmentData(keyframeItemData, isRelease) {
                keyFrameConnectLine.width = Qt.binding(calcConnectLineWidth)
                keyFrameConnectionView.visible = getKeyFrameConnectionViewVisibleState()
            }

            function onFragmentClipping() {
                trackingSegment.x = keyframeInfo != null ? editorManager.frameByPosition(keyframeInfo.speedClipStart - keyframeInfo.speedStart)*pxPerFrame : 0
                trackingSegment.segmentWidth = keyframeInfo != null ? editorManager.frameByPosition(keyframeInfo.speedClipEnd - keyframeInfo.speedClipStart)*pxPerFrame : 0
                trackingSegment.originSegmentWidth = keyframeInfo != null ? editorManager.frameByPosition(keyframeInfo.speedEnd - keyframeInfo.speedStart)*pxPerFrame : 0

                keyFrameConnectLine.width = Qt.binding(calcConnectLineWidth)
                keyFrameConnectionView.visible = getKeyFrameConnectionViewVisibleState()
            }

            function onRemoveKeyFrameSelect() {
                isKeyFrameEditing = false;
                if (keyframeInfo != null) {
                    keyframeInfo.isTransitionEditing = false;
                }
                keyframeSelectStatus = false
                keyFrameConnectionView.visible = getKeyFrameConnectionViewVisibleState();
            }

        }

        Component.onCompleted: {
            trackingSegmentLoaded = true
            trackingSegment.x = editorManager.frameByPosition(keyframeInfo.speedClipStart - keyframeInfo.speedStart)*pxPerFrame
        }
    }

    Timer {
        id: dragDebounceTimer
        interval: 33
        repeat: false

        onTriggered: {
            if (hasPendingDrag && pendingKeyframe !== null) {
                keyframeItemRoot.keyframeDrag(pendingKeyframe, pendingNewX, pendingOriginPosition, false)
                keyFrameHasDrag = true
                hasPendingDrag = false
            }
        }
    }

    // 关键帧图标
    Image {
        id: keyFrameImageView

        property bool isFirstVisible: true // 是否是显示

        // 最好的方式是这里能拿到关联的区域的keyframeInfo，不然如果区域的默认选中状态有变化，这里就不灵了
        property bool miniMode: !CommonUtils.isNull(keyframeInfo) && (keyframeInfo.isKeyframeInRegion() || keyframeInfo.keyframeRelatedSegmentType == KeyframeItemData.CameraMove)
        property real scaleFactor: calculateScaleFactor()
        property real srcScale: 1

        function calculateScaleFactor() {
            if (CommonUtils.isNull(keyframeInfo)){
                return 0;
            }

            if(keyframeInfo.keyframeRelatedSegmentType == KeyframeItemData.CameraMove && miniMode) {
                return isFirstVisible ? 1 : 0;
            }
            return miniMode && !keyframeLayerView.isInSelectRegion(keyframeInfo.position) ? 0.5 : 1;
        }

        source: {
            if (!CommonUtils.isNull(keyframeInfo)) {
                if (isKeyFrameEditing && keyframeItemRoot.indicator_frame === keyframeItemRoot.keyframeTimelineFrame(1)) {
                    if(keyframeInfo.keyframeRelatedSegmentType == KeyframeItemData.CameraMove){
                        return "qrc:/icons/icon_keyframe_4x.png";
                    }

                    return !keyframeInfo.isKeyframeInRegion() ? "qrc:/app_qrc/icons/ic_keyframe_edit.png" : "qrc:/icons/keyframe/ic_region_keyframe_edit.png";
                }else {
                    return "qrc:/app_qrc/icons/ic_keyframe_normal.png"
                }
            } else {
                return ""
            }
        }
        width: 31
        height: 31
        fillMode: Image.PreserveAspectCrop
        antialiasing: true
        transformOrigin: Item.Center
        visible: !isTrackingFragment()

        anchors.top: parent.top
        anchors.topMargin: titleLoader.height/2 - 8
        scale: scaleFactor * srcScale

        property bool keyframeSelect : !CommonUtils.isNull(keyframeInfo) ? isKeyFrameEditing && keyframeItemRoot.indicator_frame === keyframeItemRoot.keyframeTimelineFrame(1) : false

        Component.onCompleted: {
            if (keyframeInfo != null && keyframeInfo.select) {
                isKeyFrameEditing = true
            } else {
                isKeyFrameEditing = false
            }

            if(keyframeInfo.keyframeRelatedSegmentType == KeyframeItemData.CameraMove && miniMode) {
                // 内部帧随所属运镜段显隐：段是 onCompleted 强选+按播放头收起，已先于内部帧建好并定态。
                // 段选中→展开显示(miniMode=false)，段收起→隐藏(miniMode=true + isFirstVisible=false → scaleFactor 0)。
                // 按 segmentId 取段选中态(非位置)，因运镜内部帧可能正好落在 clipStart/clipEnd 边界上。
                isFirstVisible = false;
                miniMode = !keyframeLayerView.isSegmentSelected(keyframeInfo.segmentId);
            }
        }

        onKeyframeSelectChanged: {
            if (keyframeInfo !== null) {
                keyframeInfo.select = keyframeSelect
                if (keyframeSelect) {
                    keyframeSelectStatus = true
                    updateKeyframeTransition()
                }

                globalSignal.keyframeSelect(keyframeInfo)
            }
        }

        // 接收关键帧选中的全局信号
        Connections {
            target: globalSignal

            // 选中了某区域组(newGroupId 非空) → 清掉纯散点关键帧的编辑/选中态（散点与区域互斥）。
            function onPanoramaGroupSelectionChanged(oldGroupId, newGroupId) {
                if (newGroupId === "") {
                    return;
                }
                if (CommonUtils.isNull(keyframeInfo) || keyframeInfo.dataType != KeyframeItemData.Keyframe) {
                    return;
                }
                if (keyframeInfo.isKeyframeInRegion() || keyframeInfo.isKeyframeInMovement()) {
                    return;
                }
                if (isKeyFrameEditing) {
                    isKeyFrameEditing = false;
                    keyframeSelectStatus = false;
                }
            }

            function onKeyframeClicked(track, clip, position) {
                if (!keyFrameImageView.visible) {
                    return;
                }
                if (CommonUtils.isNull(keyframeInfo) || keyframeInfo.dataType != KeyframeItemData.Keyframe) {
                    return;
                }
                if (track === trackIndex && clip === clipIndex && position === keyframeInfo.position) {
                    isKeyFrameEditing = true
                    zoomInAnimation.stop()
                    keyFrameImageView.srcScale = 1;
                    // 信号错综复杂，最终不管是点击触发，还是上一帧下一帧触发，最终就会回调本信号，在这里判断，如果是区域关键帧，发送信号给Segment
                    if (keyframeInfo.isKeyframeInRegion() || keyframeInfo.isKeyframeInMovement()) {
                        globalSignal.selectRegion(track, clip, keyframeInfo.segmentId);
                    }
                } else {
                    isKeyFrameEditing = false
                }
            }

            // todo重要: 可以单独发送一个信号，在updateFragmentUi中发送信号处理显示隐藏操作
            function onKeyframeSelect(data) {
                if (CommonUtils.isNull(keyframeInfo) || CommonUtils.isNull(data)) {
                    return;
                }
                if(data.dataType === KeyframeItemData.Region &&  keyframeInfo.keyframeRelatedSegmentType == KeyframeItemData.CameraMove){
                    return;
                }
                if (keyframeInfo.track != data.track || keyframeInfo.clip != data.clip || (data.dataType != KeyframeItemData.Region && data.dataType != KeyframeItemData.CameraMove) || keyframeInfo.dataType != KeyframeItemData.Keyframe || keyframeInfo.segmentId != data.segmentId) {
                    return;
                }
                if (keyFrameImageView.miniMode != !data.select) {
                    keyFrameImageView.miniMode = !data.select;
                }
                keyFrameImageView.scaleFactor = keyFrameImageView.calculateScaleFactor();
            }


            function onKeyframePositionRefreshed() {
                keyFrameConnectLine.width = Qt.binding(calcConnectLineWidth)
                keyFrameConnectionView.visible = getKeyFrameConnectionViewVisibleState()

            }

            function onClickEndKeyframe(itemData) {
                if (itemData === null || keyframeInfo === null) {
                    return
                }
                if (keyframeInfo.nextKeyframePostion === itemData.position) {
                    var rect = UiUtils.getGlobalPosition(keyFrameConnectionView)
                    globalSignal.updateTransitionPosition(rect)
                }
            }
        }
        // 缩放动画
        SequentialAnimation {
            id: zoomInAnimation
            NumberAnimation {
                target: keyFrameImageView
                properties: "srcScale"
                to: 1.3
                duration: 100
            }
        }

        SequentialAnimation {
            id: zoomOutAnimation
            NumberAnimation {
                target: keyFrameImageView
                properties: "srcScale"
                to: 1.0 
                duration: 100
            }
        }
        // 关键帧图标上的鼠标操作
        MouseArea {
            id: keyframeMouseArea
            property real mouseStarX: -1

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton

            // hover进入， 执行放大动画
            onEntered: {
                if (isKeyFrameEditing) {
                    return;
                }
                zoomInAnimation.start()
            }
            //hover退出，执行缩小动画
            onExited: {
                if (isKeyFrameEditing) {
                    return;
                }
                zoomOutAnimation.start()
            }
            // 判断点击和拖拽的阈值， 如果是拖拽像素超过3个，或者按下时间超过150ms才会触发拖拽
            property real threshold: 3
            property real timeSlop: 150

            property double startTime ;

            // 开始拖拽前关键帧对应的1倍速下的position
            property real oldOriginalPosition: 0
            // 关键帧开始拖拽前，倍速下对应的position
            property double dragStartPosition: 0

            // 鼠标按下
            onPressed: (mouse) => {
                // 记录按下时间，移动的时候做阈值计算
                keyframeSelectStatus = false
                startTime = new Date().getTime()
                pressPositon = keyframeInfo.speedPosition
                // 如果关键帧此时不在编辑态， 要先进编辑态
                if (!isKeyFrameEditing) {
                    editorManager.pause()
                    // 关键帧进编辑态
                    keyFrameImageView.srcScale = 1.0
                    // 关键帧所在的片段进选中态
                    keyframeItemRoot.keyframeClick()
                    // seek到关键帧
                    editorManager.seek(keyframeItemRoot.keyframeTimelineFrame())
                    // 发送信号
                    globalSignal.keyframeClicked(trackIndex, clipIndex, keyframeInfo.position)
                }

                // 记录起始拖拽的x
                mouseStarX = mouse.x
                oldOriginalPosition = keyframeInfo.position
                dragStartPosition = keyframeInfo.speedPosition - frameIn
                // 通知播放器开始拖拽，切换到全局角度
                // console.log("mathy 关键帧拖拽 dragStartPosition = " + dragStartPosition + ", oldOriginalPosition = " + oldOriginalPosition)
                globalSignal.playerKeyFrameDragStart(keyframeInfo.position)
                keyframeSelectStatus = true
                keyFrameConnectionView.visible = getKeyFrameConnectionViewVisibleState()
            }
            // 抬手
            onReleased: {
                dragDebounceTimer.stop()
                if (hasPendingDrag) {
                    keyframeItemRoot.keyframeDrag(pendingKeyframe, pendingNewX, pendingOriginPosition, false)
                    hasPendingDrag = false
                }

                // 抬手时，需要处理关键帧是否复位的问题（当关键帧放在tk片段上以后）
                // keyframeItemRoot.x 已是最后一次生效的拖拽落点，不再叠加 pressDragLength
                keyframeItemRoot.keyframeDrag(keyframeInfo, keyframeItemRoot.x + root.offset,
                                              pressPositon, true)
                // 抬手，清空状态
                mouseStarX = -1
                var position = TimelinePlayerViewModel.playedPositionMk() - trackFrameIn;
                // 当变速后，拖拽一个关键帧不松手，再放回到原处，恢复成1倍速，需定位到原位置
                // 1倍速下再3、6帧处添加关键帧 ，变成5倍速，拖拽0帧处的关键帧，不松手，拖回到0帧处，再恢复1倍速，这时在3、6处显示关键帧
                if ((TimelinePlayerViewModel.playedPositionMk() - trackFrameIn) == dragStartPosition) {
                    keyframeInfo.position = oldOriginalPosition;
                }
                // 通知播放器结束拖拽更新关键帧数据，切换到关键帧角度
                globalSignal.playerKeyFrameDragEnd(keyframeInfo.position, trackIndex, clipIndex);
                // 落库后把时间指示器对齐到关键帧最终位置
                editorManager.seek(keyframeItemRoot.keyframeTimelineFrame())
                globalSignal.keyframePositionRefreshed()

                globalSignal.switchPanoromaPanel()
                if (keyframeInfo !== null && keyframeInfo.nextKeyframePostion < 0) {
                    globalSignal.clickEndKeyframe(keyframeInfo)
                }

                pressDragLength = -1
                refreshKeyFrameEditing(false)
                if (keyFrameHasDrag) {
                    eventTracker.trackEvent("pccut_keyframe_drag")
                }
                keyFrameHasDrag = false
            }
            // 拖拽
            onPositionChanged: (mouse) => {
                if(keyframeInfo.keyframeRelatedSegmentType == KeyframeItemData.CameraMove){ // 运镜模版中的关键帧不支持拖拽
                    return;
                }

                if (mouseStarX != -1) {

                    var currTime = new Date().getTime();
                    var len = mouse.x - mouseStarX
                    pressDragLength = len
                    // 如果超出阈值， 执行关键帧拖拽
                    if (currTime - startTime > timeSlop || Math.abs(len) > threshold) {
                        pendingKeyframe = keyframeInfo
                        pendingNewX = keyframeItemRoot.x + len + root.offset
                        pendingOriginPosition = pressPositon
                        hasPendingDrag = true

                        if (!dragDebounceTimer.running) {
                            dragDebounceTimer.restart()
                        }
                    }
                    globalSignal.keyframeDrag(root.trackIndex, root.clipIndex, keyframeInfo)
                }
            }
        }

        // 关键帧右键菜单
        MouseArea {
            id: mousearea_rightbutton
            anchors.fill: parent
            acceptedButtons: Qt.RightButton
            cursorShape: Qt.PointingHandCursor

            onClicked: (mouse) => {
                let selected = keyFrameImageView.keyframeSelect;
                let windowPoint = mapToItem(lightWindow.contentItem, mouse.x, mouse.y);
                keyframeItemRoot.keyframeRightClick(selected, windowPoint.x, windowPoint.y);
            }
        }
    }

    Connections {
        target: globalSignal
        function onKeyframeDrag(trackIndex, clipIndex, keyframeItemData) {
            if (keyframeItemData === null || keyframeInfo === null) {
                return
            }

            keyFrameConnectLine.width = Qt.binding(calcConnectLineWidth)

            if (keyframeItemData.position === keyframeInfo.position && keyframeItemData.nextKeyframePostion === keyframeInfo.nextKeyframePostion) {
                keyframeSelectStatus = true

            } else {
                keyframeSelectStatus = false
                keyframeConnectViewHover = false
            }
        }
    }


    /**
     * @desc 更新关键帧的过渡效果
     */
    function updateKeyframeTransition() {
        if (keyframeInfo === null) {
            return
        }

        var select = pxPerFrame > 0
                      && keyframeItemRoot.indicator_frame >= ((trackFrameIn +  (isTrackingFragment() ? (keyframeInfo.speedClipStart - frameIn) : (keyframeInfo.speedPosition - frameIn))) / (30000 / 30))
                      && keyframeItemRoot.indicator_frame < ((trackFrameIn + keyframeInfo.speedPosition - frameIn) / (30000 / 30) + (keyframeItemRoot.width - keyFrameImageView.width / 2) / pxPerFrame)
                      && keyframeItemRoot.indicator_frame >= (trackFrameIn / (30000 / 30))
                      && keyframeItemRoot.indicator_frame <= ((trackFrameIn + frameOut - frameIn) / (30000 / 30))

        if (!select && pressDragLength < 0) {
            keyframeSelectStatus = false
        }

        const regionConnection = !CommonUtils.isNull(keyframeInfo) && keyframeInfo.isKeyframeInRegion();
        if (select && keyframeSelectStatus) {
            keyFrameConnectionView.source = keyframeInfo.transitionIcon;
        } else if (keyframeConnectViewHover) {
            keyFrameConnectionView.source = regionConnection ? "qrc:/icons/keyframe/ic_region_keyframe_transition_hover.svg" : "qrc:/app_qrc/icons/ic_keyframe_transition_hover.svg";
        } else {
            keyFrameConnectionView.source = regionConnection ? "qrc:/icons/keyframe/ic_region_keyframe_transition_default.svg" : "qrc:/app_qrc/icons/ic_keyframe_transition_default.svg";
        }
    }


    /**
     * @desc 获取关键帧的显示、隐藏状态
     */
    function getKeyFrameConnectionViewVisibleState() {
        if (keyframeInfo === null) {
            return false
        }

        updateKeyframeTransition()

        return keyFrameConnectLine.visible && ((!isTrackingFragment() && (keyframeItemRoot.width - keyFrameImageView.width + (keyframeInfo.nextKeyFrameIsTkFragment ? keyFrameImageView.width / 2 : 0)) > 25) ||
                (isTrackingFragment() && (keyframeInfo.speedNextTkFragmentClipStart - keyframeInfo.speedClipEnd ) *pxPerFrame / (30000 / 30) - keyFrameImageView.width - (keyframeInfo.nextKeyFrameIsTkFragment ? -15 : -keyFrameImageView.width) > 25 ))
    }

    /**
     * @desc 点击过渡效果相关跳转的逻辑
     *
     * @param
     * @param
     * @return
     */
    function seek(ratio) {
        if (keyframeInfo === null || viewModel === null || !viewModel.hasFragment) {
            return
        }

        var position = 0
        if (keyframeInfo.start >= 0) {
            if (keyframeInfo.nextKeyFrameIsTkFragment) {
                position = (keyframeInfo.speedNextKeyframePosition - keyframeInfo.speedClipEnd) * ratio + keyframeInfo.speedClipEnd
            } else {
                // 下面的3.5主要是为了计算tk片段到下一个关键帧之间的seek位置，因为关键帧图标有两种状态（icon大小不一样），所以不知道默认态的大小，目测差不多搞了个3.5
                position = (keyframeInfo.speedNextKeyframePosition - keyframeInfo.speedClipEnd) * ratio + keyframeInfo.speedClipEnd - 3.5 * 1000 / pxPerFrame
            }
        } else {
            if (keyframeInfo.nextKeyFrameIsTkFragment) {
                // 这里的6和上面的3.5同理，处理的关键帧和tk片段的过渡效果seek位置
                position = (keyframeInfo.speedNextKeyframePosition - keyframeInfo.speedPosition) * ratio + keyframeInfo.speedPosition + 6 * 1000 / pxPerFrame
            } else {
                position = (keyframeInfo.speedNextKeyframePosition - keyframeInfo.speedPosition) * ratio + keyframeInfo.speedPosition
            }
        }

        position -= viewModel.frameIn
        var resultPostion = (viewModel.trackFrameIn + position) / (30000 / 30)
        editorManager.seek(resultPostion)
    }

    // 关键帧连接状态按钮
    Image {
        id: keyFrameConnectionView
        source: keyframeInfo.transitionIcon
        // 如果有下一个关键帧 && 时间指示器在两个关键帧之间，可见
        visible: keyFrameConnectLine.visible && ((!isTrackingFragment() && keyframeItemRoot.width - keyFrameImageView.width > 25) ||
                  (isTrackingFragment() && (keyframeInfo.speedNextTkFragmentClipStart - keyframeInfo.speedClipEnd ) *pxPerFrame / (30000 / 30) - keyFrameImageView.width - (keyframeInfo.nextKeyFrameIsTkFragment ? -15 : keyFrameImageView.width /2) > 25 ))
        width: 24
        height: 20
        sourceSize: Qt.size(24, 20)
        anchors.verticalCenter: keyFrameConnectLine.verticalCenter
        anchors.left: keyFrameConnectLine.left

        MouseArea {
            id: keyframeConnectionViewMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onClicked: {
                seek(0.5)

                if (!videoItemSelected) {
                    keyframeItemRoot.keyframeClick()
                }

                keyframeSelectStatus = true
                keyFrameConnectionView.visible = getKeyFrameConnectionViewVisibleState()

                globalSignal.switchPanoromaPanel()

                // 点击过渡线也需要选中区域关键帧
                if (!CommonUtils.isNull(keyframeInfo) && (keyframeInfo.isKeyframeInRegion() || keyframeInfo.isKeyframeInMovement())) {
                    globalSignal.selectRegion(keyframeInfo.track, keyframeInfo.clip, keyframeInfo.segmentId);
                }
            }

            onEntered: {
                keyframeConnectViewHover = true
            }

            onExited: {
                keyframeConnectViewHover = false
            }
        }

        anchors.leftMargin:
            // 左边关键帧右边tk
            keyframeInfo != null && keyframeInfo.start < 0 && keyframeInfo.nextKeyFrameIsTkFragment
            ? (keyFrameConnectLine.width - keyFrameConnectionView.width / 2) / 2 + keyFrameImageView.width/2 - keyFrameConnectionView.width / 2 - 2:
            // 左边tk右边关键帧
              keyframeInfo != null && keyframeInfo.start >= 0 && !keyframeInfo.nextKeyFrameIsTkFragment
            ? (keyFrameConnectLine.width  - keyFrameConnectionView.width / 2) / 2  - keyFrameImageView.width/2 + 2:
              keyFrameConnectLine.width / 2 - keyFrameConnectionView.width / 2

        Connections {
            target: keyframeInfo

            function onNextTkFragmentClipStartChanged() {
                keyFrameConnectionView.visible = getKeyFrameConnectionViewVisibleState()
            }

            function onClipEndChanged() {
                keyFrameConnectionView.visible = getKeyFrameConnectionViewVisibleState()
            }

            function onPositionChanged() {
                keyFrameConnectionView.visible = getKeyFrameConnectionViewVisibleState()
            }

            function onTransitionIconChanged() {
                keyframeSelectStatus = true
                keyFrameConnectionView.source = keyframeInfo.transitionIcon
            }
        }

        // 关键帧链接状态按钮的鼠标触摸事件
        // MouseArea {
        //     anchors.fill: parent

        //     onClicked: {
        //         // 给关键帧连接状态设置上选中态
        //         globalSignal.callItemSelected(trackIndex, clipIndex)
        //         globalSignal.keyframeTransitionClicked(trackIndex, clipIndex, keyframeInfo.position)
        //     }

        // }

        // Connections {
        //     target: globalSignal
        //     // 关键帧连接状态点击的全局回调，依靠方式一次性更新所有关键帧状态
        //     function onKeyframeTransitionClicked(track, clip, position) {
        //         if (track === trackIndex && clip === clipIndex && position === keyframeInfo.position) {
        //             keyframeInfo.isTransitionEditing = true;
        //         } else {
        //             keyframeInfo.isTransitionEditing = false;
        //         }
        //     }
        // }
    }

}
