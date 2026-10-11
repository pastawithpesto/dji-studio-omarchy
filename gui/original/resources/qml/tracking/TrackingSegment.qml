import QtQuick 2.15
import Config 1.0
import KeyframeItemData 1.0
import KeyframeItemArgument 1.0
import TrackingManager 1.0
import app_qrc 1.0

/**
 * @author robert.guo
 * @desc 轨道上的tracking片段
 * @create_date 2024-08-26
 */
Rectangle {
    id: trackRoot
    // 片段唯一id
    property int id: 0
    // 片段所在个轨道索引
    property int videoTrackIndex: 0
    // 片段索引
    property int videoClipIndex: 0
    // 当前片段是否处于选中状态
    property bool isSelected: false
    // 当前片段的宽度
    property alias segmentWidth: trackRoot.width

    // 记录左裁切按钮是否按下
    property bool leftBarPressed: false
    // 记录右裁切按钮是否按下
    property bool rightBarPressed: false
    // 记录按下左、右按钮按下时的父控件的宽度
    property real pressSegmentWidth

    // 记录鼠标按下左或右裁切按钮时的相对x距离
    property real pressX: 0

    // 记录鼠标按下左裁切按钮时，父控件的x位置
    property real pressParentX: 0

    // 记录鼠标按下时，水平方向x的绝对位置
    property real pressAbsoluteX: 0

    // 片段的原始的宽度
    property real originSegmentWidth

    // 裁切按下时的tracking片段的clipStart
    property real pressClipStart
    // 裁切按下时的tracking片段的clipEnd
    property real pressClipEnd

    // 定义片段最小宽度
    readonly property real fragmentMinimumWidth: Math.max(10, pxPerFrame)

    // tracking的关键帧数据
    property KeyframeItemData trackingframeInfo

    // 当前trackng片段是否生成结束
    property bool trackingGenerateEnd: trackingframeInfo != null && trackingframeInfo.trackingTkFragmentGenerated ? true : false

    property real visibleLeft: 0
    property real visibleRight: 0

    property real oldRatioX: 0
    property real oldRatioWidth: 0

    // 当点击tk片段时，如果当前tk片段处于未选择状态，则该状态置为true
    property bool videoTrackIsUnSelectWhenClickTkFragment: false

    property color segmentColor: (!CommonUtils.isNull(trackingframeInfo) && trackingframeInfo.dataType == KeyframeItemData.Tracking) ? Colors.color_32E494_60 : Colors.color_3392FF_60
    property color segmentHoverColor: (!CommonUtils.isNull(trackingframeInfo) && trackingframeInfo.dataType == KeyframeItemData.Tracking) ? Colors.color_5BF7B1_60 : Colors.color_5BA6F7_60
    property color segmentBorderColor: (!CommonUtils.isNull(trackingframeInfo) && trackingframeInfo.dataType == KeyframeItemData.Tracking) ? Colors.color_32E494 : Colors.color_3392FF

    // 点击tracking片段的信号
    signal clickTrackingSegment(real ratio)

    property real collapseHeight: 20
    property bool collapse: height === collapseHeight

    color: trackingFragmentMouseArea.containsMouse ? segmentHoverColor : segmentColor
    border.color: segmentBorderColor
    border.width: trackingframeInfo != null && !trackingframeInfo.trackingTkFragmentGenerated ? 0 : 2
    radius: 4
    height: !visible ? 0 : trackingframeInfo != null && !trackingframeInfo.trackingTkFragmentGenerated && trackingframeInfo.dataType != KeyframeItemData.Region ? parent.height : collapseHeight
    anchors.verticalCenter: parent.verticalCenter
    // 这里的2的原因是需要片段在抽帧图的空间内垂直居中，所以不能直接删除。轨道的title是20，音频波形是16，2 = (20 - 16) / 2
    anchors.verticalCenterOffset: collapse ? 2 : 0
    Component.onCompleted: {
        if (!trackingGenerateEnd) {
            return
        }
        if (trackingframeInfo.select) {
            updateFragmentUi(true, false)
        } else {
            updateFragmentUi(false, false)
        }
    }

    function updateIsTrackingChanged(inTracking, isPlaying) {
        if (CommonUtils.isNull(trackingframeInfo) || (!trackingGenerateEnd && trackingframeInfo.dataType == KeyframeItemData.Tracking)) {
            return
        }

        // 正在裁切本段时不收起：裁切会 seek 到裁切边缘，播放头落在段边界(帧对齐后可能判为段外)，
        // 经 refreshKeyFrameEditing 误触发收起，导致片段高度变窄。裁切中的段保持展开铺满。
        if (leftBarPressed || rightBarPressed) {
            return
        }

        if (inTracking === false) {
            updateFragmentUi(false, isPlaying)
        }
    }

    function updateFragmentUi(fillHeight, isPlaying) {
        if(trackRoot.visible === false) {
            // BUG: 在KeyFrameItemView.qml中TrackingSegment.qml同时监听globalSignal，并且共用同一个trackingframeInfo，此时TrackingSegment未必可视
            return;
        }
        if (fillHeight) {
            height = 72
            border.width = 2
            // 处于选中状态时，才可以执行裁切操作
            leftClipRectangle.width = 6
            rightClipRectangle.width = 6
        } else {
            height = collapseHeight
            border.width = 2
            // 处于非选中状态时，不可以执行裁切操作
            leftClipRectangle.width = 0
            rightClipRectangle.width = 0
        }

        if (!CommonUtils.isNull(trackingframeInfo)) {
            trackingframeInfo.select = fillHeight
            if(trackRoot.visible){
                globalSignal.keyframeSelect(trackingframeInfo, isPlaying)
            }
        }
    }

    function updateTrackingSegmentClip(ratioForX, ratioForWidth, end, clipLeft, release) {
        var keyframeItemArgument = editorManager.getKeyframeItemArgument()
        if (keyframeItemArgument === null) {
            return
        }

        if (release) {
            oldRatioX = 0
            oldRatioWidth = 0
        }

        if (!CommonUtils.isNull(trackingframeInfo)) {
            keyframeItemArgument.setSegmentId(trackingframeInfo.segmentId);
            keyframeItemArgument.setDataType(trackingframeInfo.dataType);
        }
        keyframeItemArgument.setTrackIndex(trackIndex)
        keyframeItemArgument.setClipIndex(clipIndex)
        keyframeItemArgument.setStart(trackingframeInfo.start)
        keyframeItemArgument.setEnd(trackingframeInfo.end)
        keyframeItemArgument.setRatioForX(ratioForX)
        keyframeItemArgument.setRatioForWidth(ratioForWidth)
        keyframeItemArgument.setUpdateKeyFrameData(end)
        keyframeItemArgument.setIsClipLeft(clipLeft)
        keyframeItemArgument.setIsRelease(release)
        globalSignal.updateTrackingSegmentClip(keyframeItemArgument, pressClipStart, pressClipEnd)
    }


    // 处理tracking左裁切，鼠标移动到轨道外侧时，触发轨道自动滚动且鼠标位置不动时，没有触发onPositionChanged导致ui不更新的问题
    // onVisibleLeftChanged: {
    //     if (trackingframeInfo == null || !leftBarPressed) {
    //         return
    //     }

    //     var speedStart = trackingframeInfo.speedStart
    //     var speedClipEnd = trackingframeInfo.speedClipEnd
    //     var speedLastTkFragmentClipEnd = trackingframeInfo.speedLastTkFragmentClipEnd

    //     // 计算当前状态左裁切到达的最大值
    //     var end = (speedLastTkFragmentClipEnd >= 0 && speedLastTkFragmentClipEnd > speedStart)
    //             ? speedLastTkFragmentClipEnd : speedStart

    //     // 优化进度问题
    //     if (visibleLeft <= editorManager.frameByPosition(end) *pxPerFrame) {
    //         globalSignal.trackScrollByX(0, false)
    //         var ratioForX = (editorManager.frameByPosition(end - speedStart) *pxPerFrame) / originSegmentWidth
    //         var ratioForWidth = (editorManager.frameByPosition(speedClipEnd)* pxPerFrame - editorManager.frameByPosition(end) *pxPerFrame) / originSegmentWidth
    //         updateTrackingSegmentClip(ratioForX, ratioForWidth, false)
    //         return
    //     }

    //     trackRoot.x = visibleLeft - editorManager.frameByPosition(speedStart)* pxPerFrame
    //     trackRoot.segmentWidth = (editorManager.frameByPosition(speedClipEnd)* pxPerFrame - visibleLeft)
    // }

    // // 处理tracking右裁切，鼠标移动到轨道外侧时，触发轨道自动滚动且鼠标位置不动时，没有触发onPositionChanged导致ui不更新的问题
    // onVisibleRightChanged: {
    //     if (trackingframeInfo == null || !rightBarPressed) {
    //         return
    //     }

    //     var speedNextTkFragmentClipStart = trackingframeInfo.speedNextTkFragmentClipStart
    //     var speedEnd = trackingframeInfo.speedEnd
    //     var speedClipStart = trackingframeInfo.speedClipStart
    //     // 计算当前状态右裁切到达的最大值
    //     var end = (speedNextTkFragmentClipStart >= 0 &&
    //             speedNextTkFragmentClipStart) < speedEnd ? speedNextTkFragmentClipStart : speedEnd

    //     // 优化精度问题
    //     if (visibleRight >= editorManager.frameByPosition(end) *pxPerFrame) {
    //         globalSignal.trackScrollByX(0, false)

    //         var ratioForX = (editorManager.frameByPosition(speedClipStart - trackingframeInfo.speedStart) *pxPerFrame) / originSegmentWidth
    //         var ratioForWidth = (editorManager.frameByPosition(end) *pxPerFrame - editorManager.frameByPosition(speedClipStart)* pxPerFrame - visibleLeft) / originSegmentWidth
    //         updateTrackingSegmentClip(ratioForX, ratioForWidth, false)
    //         return
    //     }
    //     trackRoot.segmentWidth = visibleRight - (editorManager.frameByPosition(speedClipStart)* pxPerFrame)
    // }

    Connections {
        target: globalSignal

        function onSelectRegion(trackIndex, clipIndex, segmentId) {
            if (CommonUtils.isNull(trackingframeInfo) || trackIndex != videoTrackIndex || clipIndex != videoClipIndex || trackingframeInfo.dataType != KeyframeItemData.Region || CommonUtils.isEmptyStr(trackingframeInfo.segmentId)) {
                return;
            }
            if (trackingframeInfo.select || trackingframeInfo.segmentId != segmentId) {
                return;
            }
            if (videoItem !== null && !videoItem.selected) {
                videoTrackIsUnSelectWhenClickTkFragment = true
            }
            trackingframeInfo.select = true
            globalSignal.keyframeSelect(trackingframeInfo)
            onKeyframeClicked(trackIndex, clipIndex, trackingframeInfo.clipStart)
            // 区域关键帧下这个ratio不起作用
            clickTrackingSegment(-1);
        }

        // 区域组单选互斥：本组被切走(成为 oldGroupId) → 收起；展开由 onSelectRegion 负责。
        function onPanoramaGroupSelectionChanged(oldGroupId, newGroupId) {
            if (CommonUtils.isNull(trackingframeInfo) || trackingframeInfo.dataType != KeyframeItemData.Region
                    || CommonUtils.isEmptyStr(trackingframeInfo.segmentId)) {
                return;
            }
            if (trackingframeInfo.segmentId === oldGroupId && trackingframeInfo.select) {
                updateFragmentUi(false, false);
            }
        }

        function onKeyframeClicked(_trackIndex, _clipIndex, clipStart) {
            if(trackRoot.visible === false) {
                // BUG: 在KeyFrameItemView.qml中TrackingSegment.qml同时监听globalSignal，并且共用同一个trackingframeInfo，此时TrackingSegment未必可视
                return;
            }

            if (clipStart === trackingframeInfo.clipStart && _trackIndex === videoTrackIndex && _clipIndex === videoClipIndex) {
                isSelected = true
                updateFragmentUi(true, false)
                globalSignal.keyframeSegmentClicked();
            } else {
                isSelected = false
                updateFragmentUi(false, false)
            }
        }

        function onTrackingStateChanged(status) {
            if (CommonUtils.isNull(trackingframeInfo) || trackingframeInfo.dataType != KeyframeItemData.Tracking) {
                return;
            }
            if (status === TrackingManager.TK_EXIT) {
                trackingGenerateEnd = true
                updateFragmentUi(false, false)
            }
        }

        function onVideoSelected(fragment) {
            if (!videoTrackIsUnSelectWhenClickTkFragment) {
                updateFragmentUi(false, false)
            }

            videoTrackIsUnSelectWhenClickTkFragment = false
        }
        // 去掉tk的选中状态
        function onRemoveTrackingSelect() {
            if (!CommonUtils.isNull(trackingframeInfo) && trackingframeInfo.select) {
                updateFragmentUi(false, false);
            }
        }

        function onInsertTrackingFragmentComplete(track, clip) {
            if (CommonUtils.isNull(trackingframeInfo) || trackingframeInfo.dataType != KeyframeItemData.Tracking) {
                return;
            }
            if (videoTrackIndex === track && videoClipIndex === clip) {
                updateFragmentUi(false, false)
            }
        }
    }

    MouseArea {
        id: trackingFragmentMouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: (mouse) => {
            if (videoItem !== null && !videoItem.selected) {
                videoTrackIsUnSelectWhenClickTkFragment = true
            }
            trackingframeInfo.select = true
            globalSignal.keyframeSelect(trackingframeInfo)
            globalSignal.keyframeClicked(videoTrackIndex, videoClipIndex, trackingframeInfo.clipStart)
            clickTrackingSegment(mouse.x / segmentWidth)
        }
    }

    Rectangle {
        id: leftClipRectangle
        property bool isStartClip: false
        width: 0
        height: parent.height - 12
        clip: true
        anchors {
            left: parent.left
            verticalCenter: parent.verticalCenter
        }
        color: /*leftBarPressed ? Colors.color_32E494 :*/ Colors.transparent

        MouseArea {
            id: leftMouseArea
            hoverEnabled: true
            anchors.fill: parent
            cursorShape: Qt.SizeHorCursor

            onEntered: {
                if(editorManager.isInUserGuideStatusChanged() && !CommonUtils.isNull(trackingframeInfo) && trackingframeInfo.dataType == KeyframeItemData.Tracking) {
                    globalSignal.enterTkClipArea();
                }
            }

            onExited: {
                if(editorManager.isInUserGuideStatusChanged() && !CommonUtils.isNull(trackingframeInfo) && trackingframeInfo.dataType == KeyframeItemData.Tracking) {
                    globalSignal.exitTkClipArea();
                }
            }

            onCanceled: {
                keyframeViewModel.isCuttingKeyFrame = false;
            }

            onPositionChanged: (mouse) => {
               if(!leftClipRectangle.isStartClip){
                   return;
               }

                var currentPoint = leftClipRectangle.mapToItem(rightClipRectangle, mouse.x, mouse.y)
                // 计算当前的相对距离和按下时的相对距离的差值，来获得滑动距离
                var deltaX = (currentPoint.x - pressX)

                // 还原最小宽度限制的代码
                //拖拽到最右侧，有个限制
                deltaX = Math.min(deltaX, pressSegmentWidth - fragmentMinimumWidth);

                var ratioForX = (pressParentX + deltaX) / originSegmentWidth
                var ratioForWidth = (pressSegmentWidth - deltaX) / originSegmentWidth

                if (oldRatioX === ratioForX && oldRatioWidth === ratioForWidth) {
                   return;
                }

                oldRatioX = ratioForX   
                oldRatioWidth = ratioForWidth

                updateTrackingSegmentClip(ratioForX, ratioForWidth, false, true, false)
                globalSignal.keyframePositionRefreshed()
            }

            onPressed: (mouse) => {
                           leftClipRectangle.isStartClip = true;
                var point = leftClipRectangle.mapToItem(rightClipRectangle, mouse.x, mouse.y)
                // 记录下左侧按钮按下时，相对x位置
                pressX = point.x
                pressParentX = trackRoot.x

                if (!CommonUtils.isNull(trackingframeInfo)) {
                    pressClipStart = trackingframeInfo.clipStart
                    pressClipEnd = trackingframeInfo.clipEnd
                }

                pressSegmentWidth = segmentWidth
                leftBarPressed = true
                keyframeViewModel.isCuttingKeyFrame = true;
            }

            onReleased: {
                leftClipRectangle.isStartClip = false;
                // 长按抬起时，鼠标形状恢复原状
                leftBarPressed = false

                var ratioForX = trackRoot.x / originSegmentWidth
                var ratioForWidth = (segmentWidth) / originSegmentWidth

                updateTrackingSegmentClip(ratioForX, ratioForWidth, true, true, true)
                if (!CommonUtils.isNull(trackingframeInfo) && trackingframeInfo.dataType == KeyframeItemData.Tracking) {
                    globalSignal.finishTkGuideModel();
                }
                keyframeViewModel.isCuttingKeyFrame = false;
            }
        }
    }

    Rectangle {
        id: rightClipRectangle
        property bool isStartClip: false
        width: 0
        height: parent.height - 12
        clip: true
        anchors {
            right: parent.right
            verticalCenter: parent.verticalCenter
        }

        color: /*rightBarPressed ? Colors.color_32E494 :*/ Colors.transparent

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.SizeHorCursor
            hoverEnabled: true
            onEntered: {
                if (!CommonUtils.isNull(trackingframeInfo) && trackingframeInfo.dataType == KeyframeItemData.Tracking) {
                    globalSignal.enterTkClipArea();
                }
            }

            onExited: {
                if (!CommonUtils.isNull(trackingframeInfo) && trackingframeInfo.dataType == KeyframeItemData.Tracking) {
                    globalSignal.exitTkClipArea();
                }
            }

            onCanceled: {
                keyframeViewModel.isCuttingKeyFrame = false;
            }

            onPositionChanged: (mouse) => {
               if(!rightClipRectangle.isStartClip){
                   return;
               }
                var currentPoint = rightClipRectangle.mapToItem(root, mouse.x, mouse.y)
                var deltaX = currentPoint.x - pressX

                // 还原最小宽度限制的代码
                // 处理滑动到最左侧时，copy一下左侧的代码
                deltaX = Math.max(deltaX, fragmentMinimumWidth - pressSegmentWidth);

                var ratioForX = trackRoot.x / originSegmentWidth
                var ratioForWidth = (pressSegmentWidth + deltaX) / originSegmentWidth

                if (oldRatioX === ratioForX && oldRatioWidth === ratioForWidth) {
                   return;
                }

                oldRatioX = ratioForX
                oldRatioWidth = ratioForWidth

                updateTrackingSegmentClip(ratioForX, ratioForWidth, false, false, false)
                globalSignal.keyframePositionRefreshed();
            }

            onPressed: (mouse) => {
                rightClipRectangle.isStartClip = true;
                keyframeViewModel.isCuttingKeyFrame = true;
                // 记录鼠标按下时的位置
                var point = rightClipRectangle.mapToItem(root, mouse.x, mouse.y)
                pressX = point.x

                if (!CommonUtils.isNull(trackingframeInfo)) {
                    pressClipStart = trackingframeInfo.clipStart
                    pressClipEnd = trackingframeInfo.clipEnd
                }

                pressAbsoluteX = trackRoot.x
                pressSegmentWidth = segmentWidth
                rightBarPressed = true
            }

            onReleased: (mouse) => {
                rightClipRectangle.isStartClip = false;
                rightBarPressed = false

                // var ratioForX = trackRoot.x / originSegmentWidth
                // var ratioForWidth = (segmentWidth) / originSegmentWidth

                var currentPoint = rightClipRectangle.mapToItem(root, mouse.x, mouse.y)
                var deltaX = currentPoint.x - pressX

                // 还原最小宽度限制的代码
                // 处理滑动到最左侧时，copy一下左侧的代码
                deltaX = Math.max(deltaX, fragmentMinimumWidth - pressSegmentWidth);

                var ratioForX = trackRoot.x / originSegmentWidth
                var ratioForWidth = (pressSegmentWidth + deltaX) / originSegmentWidth

                updateTrackingSegmentClip(ratioForX, ratioForWidth, true, false, true)
                if (!CommonUtils.isNull(trackingframeInfo) && trackingframeInfo.dataType == KeyframeItemData.Tracking) {
                    globalSignal.finishTkGuideModel();
                }
                keyframeViewModel.isCuttingKeyFrame = false;
            }
        }
    }

    // TODO: yahui.li 注意一个问题，拖动的时候一些关键帧的快捷键不应该可用
}
