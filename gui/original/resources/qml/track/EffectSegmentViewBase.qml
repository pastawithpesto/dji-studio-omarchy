import QtQuick 2.15
import Config 1.0
import KeyframeItemData 1.0
import KeyframeItemArgument 1.0
import TrackingManager 1.0
import app_qrc 1.0
import PanoMovementClipViewModel 1.0

/**
 * @author mathy.shi
 * @desc 轨道上的运镜片段
 * @create_date 2025-11-12
 */

Rectangle {
    id: trackRoot
    // 片段唯一id
    property string segmentId: ""
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

    property real pressClipStart
    property real pressClipEnd

    // 定义片段最小宽度
    readonly property real fragmentMinimumWidth: Math.max(10, pxPerFrame)

    // 运镜的关键帧数据
    property KeyframeItemData trackingframeInfo

    property bool trackingGenerateEnd: trackingframeInfo != null && trackingframeInfo.trackingTkFragmentGenerated ? true : false

    property real visibleLeft: 0
    property real visibleRight: 0

    property real oldRatioX: 0
    property real oldRatioWidth: 0

    property bool videoTrackIsUnSelectWhenClickTkFragment: false
    property bool isShowKeyframeIcon: false  // 是否展示关键帧

    property color segmentColor: Colors.color_FF9333_60
    property color segmentHoverColor: Colors.color_FFAA5E_60
    property color segmentBorderColor: Colors.color_FF9333

    signal clickTrackingSegment(real ratio)

    property real collapseHeight: 20
    property bool collapse: height === collapseHeight

    color: trackingFragmentMouseArea.containsMouse ? segmentHoverColor : segmentColor
    border.color: segmentBorderColor
    border.width: trackingframeInfo != null && !trackingframeInfo.trackingTkFragmentGenerated ? 0 : 2
    radius: 4
    height: !visible ? 0 : trackingframeInfo != null && !trackingframeInfo.trackingTkFragmentGenerated && trackingframeInfo.dataType != KeyframeItemData.CameraMove ? parent.height : collapseHeight

    anchors.verticalCenter: parent.verticalCenter
    // 这里的2的原因是需要片段在抽帧图的空间内垂直居中，所以不能直接删除。轨道的title是20，音频波形是16，2 = (20 - 16) / 2
    anchors.verticalCenterOffset: collapse ? 2 : 0

    PanoMovementClipViewModel{
        id: panoMovementClipViewModel
        clipIndex: videoClipIndex
        trackIndex: videoTrackIndex
        movementId: !CommonUtils.isNull(trackingframeInfo) && trackingframeInfo.dataType == KeyframeItemData.CameraMove ? segmentId : ""
    }

    Component.onCompleted: {
        if (!trackingGenerateEnd) {
            return
        }
        // 段创建即全选展开；播放头不在段内的由 KeyFrameItemView.refreshKeyFrameEditing() 随后收起，
        // 只留播放头所在的运镜选中(选中+指示器在内 → 重开仍选中，与区域机制不同)。
        if (trackingframeInfo.select) {
            updateFragmentUi(true, false)
        } else {
            updateFragmentUi(true, false)
        }
    }

    function updateIsTrackingChanged(inTracking, isPlaying) {
        if (CommonUtils.isNull(trackingframeInfo) || (!trackingGenerateEnd && trackingframeInfo.dataType == KeyframeItemData.CameraMove)) {
            return
        }

        if (inTracking === false) {
            updateFragmentUi(false, isPlaying)
        }
    }

    function updateFragmentUi(fillHeight, isPlaying) {
        if (CommonUtils.isNull(trackingframeInfo) || trackingframeInfo.dataType !== KeyframeItemData.CameraMove) {
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
            globalSignal.keyframeSelect(trackingframeInfo, false)
            if(!trackingframeInfo.select){
                movementClipChange();
            }
        }
    }

    // 拖拽片段时的逻辑
    function updateTrackingSegmentClip(ratioForX, ratioForWidth, end, clipLeft, release) {
        if (CommonUtils.isNull(trackingframeInfo)) {
            return;
        }
        if (release) {
            oldRatioX = 0
            oldRatioWidth = 0
        }
        panoMovementClipViewModel.updateTrackingSegmentClip(trackingframeInfo.dataType, ratioForX, ratioForWidth, trackingframeInfo.start, trackingframeInfo.end, pressClipStart,
                                                            pressClipEnd, end, clipLeft, release);
    }

    Connections {
        target: globalSignal

        function onSelectRegion(trackIndex, clipIndex, segmentId) {
            if (CommonUtils.isNull(trackingframeInfo) || trackIndex !== videoTrackIndex || clipIndex !== videoClipIndex || trackingframeInfo.dataType != KeyframeItemData.CameraMove
                    || CommonUtils.isEmptyStr(trackingframeInfo.segmentId)) {
                return;
            }
            if (trackingframeInfo.select || trackingframeInfo.segmentId !== segmentId) {
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

        // 关键帧组单选互斥：本运镜组被切走(成为 oldGroupId) → 收起；展开由 onSelectRegion 负责。
        function onPanoramaGroupSelectionChanged(oldGroupId, newGroupId) {
            if (CommonUtils.isNull(trackingframeInfo) || trackingframeInfo.dataType != KeyframeItemData.CameraMove
                    || CommonUtils.isEmptyStr(trackingframeInfo.segmentId)) {
                return;
            }
            if (trackingframeInfo.segmentId === oldGroupId && trackingframeInfo.select) {
                updateFragmentUi(false, false);
            }
        }

        // 响应点击片段
        function onKeyframeClicked(_trackIndex, _clipIndex, clipStart) {
            if (CommonUtils.isNull(trackingframeInfo) || _trackIndex !== videoTrackIndex || _clipIndex !== videoClipIndex || trackingframeInfo.dataType !== KeyframeItemData.CameraMove) {
                return;
            }
            if (clipStart >= trackingframeInfo.clipStart && clipStart <= trackingframeInfo.clipEnd) {
                isSelected = true
                updateFragmentUi(true, false)
                globalSignal.keyframeSegmentClicked();
            } else {
                isSelected = false
                // updateFragmentUi(false, false)
            }

            isShowKeyframeIcon = true;
        }

        function onVideoSelected(fragment) {
            if (CommonUtils.isNull(trackingframeInfo) || trackingframeInfo.dataType !== KeyframeItemData.CameraMove) {
                return;
            }

            if (!videoTrackIsUnSelectWhenClickTkFragment) {
                // updateFragmentUi(false, false)
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
            if (CommonUtils.isNull(trackingframeInfo) || trackingframeInfo.dataType != KeyframeItemData.CameraMove) {
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
            // 点选运镜段 → 设内核选中组(KeyframeBtnViewModel.selectRegion → selectKeyframeGroup)
            globalSignal.selectRegion(videoTrackIndex, videoClipIndex, trackingframeInfo.segmentId)
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

                var currentPoint = leftClipRectangle.mapToItem(rightClipRectangle, mouse.x, mouse.y)
                // 计算当前的相对距离和按下时的相对距离的差值，来获得滑动距离
                var deltaX = (currentPoint.x - pressX)
                // 还原最小宽度限制的代码
                //拖拽到最右侧，有个限制
                deltaX = Math.min(deltaX, pressSegmentWidth - fragmentMinimumWidth);

                // 这里ratioForX的计算改成和 positionChanged里一样，不然会抖动，导致抬起时候的数据计算的和位置移动时候不一样。原因未查明
                var ratioForX = (pressParentX + deltaX) / originSegmentWidth
                var ratioForWidth = (pressSegmentWidth - deltaX) / originSegmentWidth
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

            onReleased: {
                rightClipRectangle.isStartClip = false;
                rightBarPressed = false

                var ratioForX = trackRoot.x / originSegmentWidth
                var ratioForWidth = (segmentWidth) / originSegmentWidth

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
