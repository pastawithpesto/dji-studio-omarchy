/**
    * @author: dendi.zheng
    * @details:  多轨道上的音频片段布局
    * @date: 2024-07-17 15:13:47
    */

import QtQuick 2.15
import QtQuick.Controls
import Config 1.0
import AudioWavePaint 1.0
import CursorHelper 1.0
import QTractorType 1.0
import MultiTrackView 1.0
import Controls 1.0
import app_qrc 1.0
import Nova 1.0
import "markPoint"

Item {
    id: root

    // nova: fragmentInfo 现为 TimelineAudioClipViewModel（modelData），仅投影布局子集。
    required property var fragmentInfo

    // 选中框左右耳朵宽度
    property int selectedGripWidth: 2
    // 选中框上下线宽度
    property int selectedLineWidth: 1
    // 是否处于选中状态
    property bool selected: CommonUtils.isNull(fragmentInfo) ? false : fragmentInfo.selected
    // 是否正在拖拽
    property bool isDragging: false

    // 标记带在 root.parent 后相对 root.z 的 z 偏移：取 0.5，使音频标记带 z(=音频体0+0.5=0.5)
    // 落在区间 (音频体0, 主视频轨背景1) 内——既高于自身/相邻同轨音频片段体(0) 正常显示，
    // 又低于固定主视频轨的背景(1) 与片段体(2)。主视频轨(track=0)垂直滚动时像表头一样被固定，
    // 音频轨会滑入其区域；若音频标记 z≥主轨背景，会透出盖在固定主轨的空白区(无片段体处)或视频上。
    // 视频侧标记带偏移仍保持 9，不受此约束影响。
    readonly property real markRibbonZOffset: 0.5

    // 反向拖动标记的吸附数据源(multiTrackDataProvider)，由 TrackDock 注入并下发给标记带
    property var snappingProvider: null

    // 片段的可视区域长度，单位px
    property real trackLength: 1000
    // 轨道可见的最左边x坐标， 单位px，其实就是滚动的x轴距离
    property real visibleLeft: 0

    property real visibleRight: 0
    // 每个片段对应的时长，单位ms
    property real msPerFragment: 1

    // 每个片段对应的px长度， 给了个默认值16
    property double pxPerFragment: Instance.audio_wave_track_length
    // 每个片段对应的最小刻度的数量，比如最小刻度是100ms， 片段间隔是1s， 那这个数量就是10
    property int countForFragment: 0
    // 是否需要刷新
    property bool needRefresh: false
    // 请求数据的最小粒度，单位ms
    property int requestDataMiniScale: 1
    // 轨道缩放 px per frame
    property double pxPerFrame: 0
    // 帧率
    property int outputFps: 0
    //相邻两个片段中间的间隙， 片段整体宽度不变，填充内容时，左边留1像素，右边留1像素
    property real itemGap: 1

    property int trackIndex: -1
    property int clipIndex: -1

    property int  oneFrameToTimes : 1000
    property real trackVisibleLeft: 0
    property real trackVisibleRight: 0
    property int scrollClipArea : 30
    // 左右裁切控件默认触发区域宽度
    property int clipAreaWidth : 5

    // 保存上一步裁切的结果, 用于执行撤销，恢复操作
    property int lastTrackFreamIn: 0
    property int lastFreamIn: 0
    property int lastLength: 0

    // 原始的片段长度
    property int originFragmentLength : 0

    property real isClipping: leftClipDragArea.isStartclip || rightClipDragArea.isStartclip

    property bool isMouseMoved: false // 鼠标位置是否发生移动
    property bool isSnapped: false // 是否吸附成功
    property real snappingPos: -1 // 吸附位置

    property bool mediaLost: CommonUtils.isNull(fragmentInfo) || !fragmentInfo.mediaSourceExists;

    // 信号: 开始裁切
    signal startClip()
    // 信号:剪切结束
    signal fragmentChange(bool isLeftClip, bool isScroll, bool isClipping)
    // 信号： 是否开启滚动裁切
    signal scrollClip(bool isScroll, bool isLeftClip, bool isScrollToLeft)
    // 信号: 查看当前位置是否可以吸附
    signal getSnappingPosSig(real pos)

    CursorHelper {
        id: cursorhelper
    }

    // 点击
    signal itemClicked(bool isRightButton)
    // 片段拖拽 移动
    signal itemDragMove(point point, bool isFirst)
    // 片段拖拽 结束
    signal itemDragRelease(point point, bool isCancel)

    // 信号： 右键打开片段操作弹窗
    signal openOperatorPop(real windowPointX, real windowPointY, bool isMediaLost, bool isSelectFile, bool isComposeFragmentValid);
    Item {
        id: fragment

        // frameOut/frameIn 为半开区间端点，长度即二者之差
        property real totalTimebase: CommonUtils.isNull(fragmentInfo) ? 0 : (fragmentInfo.frameOut - fragmentInfo.frameIn)
        property real displayFrames: totalTimebase / 30000.0 * outputFps
        property real displayLength: displayFrames * pxPerFrame
        property color borderColor: Colors.color_EEEEEE
        property int rectRadius: RadiusConfig.radius_4_8
        property bool audioVisibility: CommonUtils.isNull(fragmentInfo) ? false : fragmentInfo.audioVisibility
    }

    // 点击片段选中
    MouseArea {
        anchors.fill: parent
        // 是否是拖拽中
        property bool isSortDragging: false
        property bool isRightButton: false
        // 拖拽阈值相关
        property real dragThreshold: 3           // 拖拽像素阈值
        property real dragTimeSlop: 150          // 拖拽时间阈值（毫秒）
        property real dragStartX: 0              // 拖拽开始的X坐标
        property real dragStartY: 0              // 拖拽开始的Y坐标
        property double dragStartTime: 0         // 拖拽开始时间
        property bool hasDragExceededThreshold: false  // 是否超出阈值
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: (mouse) => {
            // 先不认为是拖拽, 如果位置变化就是拖拽
            if (mouse.button === Qt.LeftButton){
                isSortDragging = false;
                isRightButton = false;
                // 初始化拖拽阈值检查
                dragStartX = mouse.x
                dragStartY = mouse.y
                dragStartTime = new Date().getTime()
                hasDragExceededThreshold = false
            } else if (mouse.button === Qt.RightButton){
                isSortDragging = false;
                isRightButton = true;
            }
        }
        onReleased: (mouse) => {
            if (mouse.button === Qt.RightButton && !isSortDragging) {
                // 先选中
                itemClicked(true);
                let windowPoint = mapToItem(lightWindow.contentItem, mouse.x, mouse.y);
                let isMediaLost = root.mediaLost;
                let isSelectFile = (multiTrackDataProvider.getSelectedCount() > 0);
                root.openOperatorPop(windowPoint.x, windowPoint.y, isMediaLost, isSelectFile, false);
            } else {
                isRightButton = false;
                root.isDragging = false;
                itemDragRelease(Qt.point(mouseX, mouseY), false);
            }
        }
        onCanceled: {
            root.isDragging = false;
            itemDragRelease(Qt.point(mouseX, mouseY), true);
        }
        onPositionChanged: {
            if(isRightButton){
                isSortDragging = true;
                return;
            }

            // 检查是否超出拖拽像素阈值
            if (!hasDragExceededThreshold) {
                var pixelXMoved = Math.abs(mouseX - dragStartX)
                var pixelYMoved = Math.abs(mouseY - dragStartY)

                if (pixelXMoved > dragThreshold || pixelYMoved > dragThreshold) {
                    hasDragExceededThreshold = true
                } else {
                    return  // 未超出阈值，不响应拖拽
                }
            }

            // 鼠标按下, 并改变了位置,就响应为拖拽,参考剪映
            if (!isSortDragging) {
                isSortDragging = true;
                root.isDragging = true;
                // 先选中
                itemClicked(false);
                itemDragMove(Qt.point(dragStartX, dragStartY), true);
            } else {
                itemDragMove(Qt.point(mouseX, mouseY), false);
            }
        }

        onClicked: (mouse) => {
            // 如果已经响应了拖拽就不再响应点击
            if (isSortDragging) {
                return;
            }
            itemClicked(mouse.button === Qt.RightButton);
        }
    }

    width: fragment.displayLength
    z: isDragging ? 100 : 0

    Rectangle {
        id: itemRectangle
        anchors {
            left: parent.left
            top: parent.top
            bottom: parent.bottom
        }
        width: parent.width - itemGap
        color: mediaLost ? ColorsConfig.color_brand : ColorsConfig.color_2E276D_0F3058
        radius: fragment.rectRadius
        clip: true
        z: 1

        // 音频波形
        AudioWavePaint {
            id: audioWavePaint
            anchors {
                top: audioNameRect.bottom
                bottom: parent.bottom
                topMargin: 4
            }
            width: trackLength + pxPerFragment + 20
            visibility: !mediaLost && fragment.audioVisibility
            isAudio: true
            layer.enabled: true
            paintWidth: root.width - root.visibleLeft - itemGap

            audioPath: fragmentInfo.path
            x: root.visibleLeft
            compositeProperty: {
                "visibleLeft": root.visibleLeft,
                "visibleLength": root.trackLength,
                "pxPerFrame": root.pxPerFrame,
                "outputFps": root.outputFps,
                "fragmentLength": fragmentInfo.length,
                "stripOriginMk": fragmentInfo.stripOriginMk,
                "speed": 1.0,
                "fragmentInfo": fragmentInfo
            }
        }
        Canvas {
            id: fade_in
            property color triangleColor: Colors.color_000000
            visible: fragmentInfo.fadeIn
            opacity: 0.7
            width: fragmentInfo.fadeInDuration / fragmentInfo.length * parent.width
            height: audioWavePaint.height
            anchors{
                top: audioWavePaint.top
                left: parent.left
            }
            contextType: "2d"
            property real fadeInLength : fragmentInfo.fadeInDuration / fragmentInfo.length * parent.width
            onPaint: {
                var ctx = getContext("2d")
                if (!CommonUtils.isNull(ctx)) {
                    ctx.lineWidth = 0
                    ctx.strokeStyle = Colors.color_000000
                    ctx.fillStyle = triangleColor
                    ctx.beginPath();
                    ctx.moveTo(0, 0)
                    ctx.lineTo(fadeInLength, 0);
                    ctx.quadraticCurveTo(fade_in.width / 5, fade_in.height / 5, 0, fade_in.height);
                    ctx.closePath();
                    ctx.fill()
                    ctx.stroke();
                }
            }
        }

        Canvas {
            id: fade_out
            property color triangleColor: Colors.color_000000
            visible: fragmentInfo.fadeOut
            opacity: 0.7
            width: fragmentInfo.fadeOutDuration / fragmentInfo.length * itemRectangle.width
            height: audioWavePaint.height
            anchors{
                top: audioWavePaint.top
                right: parent.right
            }
            contextType: "2d"
            property real fadeOutLength : fragmentInfo.fadeOutDuration / fragmentInfo.length * itemRectangle.width
            onPaint: {
                var ctx = getContext("2d")
                if (!CommonUtils.isNull(ctx)) {
                    ctx.lineWidth = 0
                    ctx.strokeStyle = Colors.color_000000
                    ctx.fillStyle = triangleColor
                    ctx.beginPath();
                    ctx.moveTo(fade_out.width, 0)
                    ctx.lineTo(fade_out.width - fadeOutLength, 0);
                    ctx.quadraticCurveTo(fade_out.width / 5 * 4, fade_out.height / 5, fade_out.width, fade_out.height);
                    ctx.closePath();
                    ctx.fill()
                    ctx.stroke();
                }
            }
        }
        // 音频名称
        Rectangle {
            id: audioNameRect
            anchors {
                left: parent.left
                leftMargin: 4
                top: parent.top
                topMargin: 4
            }
            color: Colors.color_transparent
            height: 13
            width: Math.max(Math.min(parent.width - 8, 40), fontMetrics.advanceWidth(audioNameRectText.text) + 8)
            Text {
                id: audioNameRectText
                // nova: 显示名取自 VM 的 clipName（资源文件名），不再经老 dramaSource。
                text: CommonUtils.isNull(fragmentInfo) ? "" : fragmentInfo.clipName
                anchors.fill: parent
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: 10
                color: mediaLost ? ColorsConfig.color_EEEEEE_000000 :ColorsConfig.color_9D92F3_68AAFC
            }
            // 用于获取音乐名称的宽度
            FontMetrics {
                id: fontMetrics
                font: audioNameRectText.font
            }
        }

        Rectangle {
            id: lostUI
            anchors {
                top: audioNameRect.bottom
                bottom: parent.bottom
                left: parent.left
                right: parent.right
                topMargin: 4
            }
            color: ColorsConfig.color_492C2D_15473C
            visible: mediaLost
            radius: fragment.rectRadius

            // 补个两个角的缺，如果将lostUI改成LightRectangle，当尺寸过长的时候，会出现绘制问题
            Rectangle {
                anchors {
                    top: lostUI.top
                    left: lostUI.left
                }
                width: fragment.rectRadius
                height: fragment.rectRadius
                color: ColorsConfig.color_492C2D_15473C
            }

            Rectangle {
                anchors {
                    top: lostUI.top
                    right: lostUI.right
                }
                width: fragment.rectRadius
                height: fragment.rectRadius
                color: ColorsConfig.color_492C2D_15473C
            }

            Column {
                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }

                Text {
                    anchors {
                        left: parent.left
                        right: parent.right
                    }
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: 10
                    color: ColorsConfig.color_brand
                    // 这里不要翻译
                    text: "音乐丢失"
                }

                Text {
                    anchors {
                        left: parent.left
                        right: parent.right
                    }
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: 10
                    color: ColorsConfig.color_brand
                    // 这里不要翻译
                    text: "Music Not Found"
                }
            }
        }

        // 选中框
        Rectangle {
            visible: selected
            width: root.width - itemGap
            height: root.height
            color: Colors.transparent
            radius: fragment.rectRadius
            border.width: selectedGripWidth
            border.color: fragment.borderColor
        }

        MouseArea{
            id:leftClipDragArea
            property real delPosX: 0
            property real startGlobalX: 0  // 拖拽起点在 multiTrackView 内容坐标系的 x
            property int startClipTrackFrameIn: 0  // 按下时的 trackFrameIn, 用于算已应用位移
            property bool isStartclip: false
            property bool isScrollClipping: false
            property bool isGroupClip: false  // 本次拖拽是否为多选整组裁切
            property real startPosX: 0 // 音频波形起始点, 只与裁切有关，与面板滚动时为了性能优化调整波形起始点的逻辑无关
            property real leftframelengthLimit: 0  // 右侧可恢复最长帧限制

            hoverEnabled:true
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            height: parent.height
            width: clipAreaWidth
            onReleased: {
                finishDrag();
            }
            
            onCanceled: {
                finishDrag();
            }

            function finishDrag() {
                isStartclip = false
                if(!leftClipDragArea.containsMouse){
                    cursorhelper.restoreOverrideCursor()
                }

                if(isScrollClipping){
                    isScrollClipping = false
                    scrollClip(false, true, false)
                }
                var clipPosition = fragmentInfo.trackFrameIn
                root.updateLastResult()            // 清理滚动裁切残留的不足一帧尾部
                if(leftClipDragArea.isGroupClip){
                    // nova: 多选整组裁切一次事务提交(单步 undo,含 base)，内部按涉及类型回读并请重排。
                    TimelineEditController.commitGroupTrim();
                    leftClipDragArea.isGroupClip = false;
                } else {
                    fragmentInfo.commitTrim()          // nova: 裁切提交落 nle(源范围+时间线，单步 undo)
                }
                fragmentChange(true, false, false)
                ShortcutObserver.disableAllShortcut(false);
                fragmentChange(false, false, false);
                root.isSnapped = false;
                delPosX = 0
                editorManager.sendTrackEventForDragCLip(root.trackIndex, root.clipIndex, clipPosition, true, "audio", 3)
            }
            onEntered: {
                if(!isStartclip){
                    if(rightClipDragArea.containsMouse){
                        cursorhelper.restoreOverrideCursor()
                    }
                    cursorhelper.setCustomCursor(":/icons/ic_cutleft.svg", 24, 24)
                }
            }
            onExited: {
                if(!isStartclip){
                    cursorhelper.restoreOverrideCursor()
                }
                ShortcutObserver.disableAllShortcut(false);
            }

            onPressed: {
                // 未选中片段边缘按下：先独占选中再进入裁切，selectedClipCount 随之归 1，不会误开整组裁切
                if (!root.selected) {
                    root.itemClicked(false);
                }
                isStartclip = true;
                leftClipDragArea.isGroupClip = TimelineEditController.selectedClipCount() > 1;  // 多选则整组裁切
                startGlobalX = mapToItem(multiTrackView, mouseX, 0).x;  // 拖拽起点在内容坐标系的 x
                startClipTrackFrameIn = fragmentInfo.trackFrameIn;
                delPosX = 0;
                if(leftClipDragArea.isGroupClip){
                    TimelineEditController.beginGroupTrim(fragmentInfo.clipNodeId, true);
                }
                startClip();
                root.updateLastResult();
                ShortcutObserver.disableAllShortcut(true);
            }
            Component.onCompleted: {
                leftframelengthLimit = fragmentInfo.frameIn
            }
            onPositionChanged: {
                if(!isStartclip)
                    return
                root.isMouseMoved = true;
                // 自校正残差公式(与 VideoItemView 左裁切一致): delPosX = 鼠标目标位移 - 已应用位移(以内容坐标系为基准).
                // 鼠标目标位移 = globalX - startGlobalX; 已应用位移 = (trackFrameIn - startClipTrackFrameIn) 换算像素.
                // 外部改写 frameIn/trackFrameIn(滚动裁切、C++ clampGroupDelta)会自动纳入"已应用位移", 无需手动清账;
                // 组裁切触顶时片段不动, 残差保持"鼠标与片段真实间隙", 反向拖动立即响应(不再累积溢出导致灵敏度漂移).
                var globalX = mapToItem(multiTrackView, mouseX, 0).x
                var appliedPx = (fragmentInfo.trackFrameIn - startClipTrackFrameIn) / oneFrameToTimes * pxPerFrame
                if(mouseX < 0 && (fragmentInfo.frameIn === 0 || fragmentInfo.trackFrameIn === 0)){
                    if(isScrollClipping){
                        scrollClip(false, true, false);
                        isScrollClipping = false;
                    }
                    // 边界到达, 重锚起点使 delPosX 归零(保持旧行为: 反向拖动立即响应)
                    startGlobalX = globalX - appliedPx
                    delPosX = 0
                    return
                }

                if(mouseX > 0 && fragmentInfo.frameOut - fragmentInfo.frameIn === oneFrameToTimes){
                    // 只剩一帧(最小长度): 不重锚, delPosX 保留"鼠标越过最小位置的量"(粘滞)
                    return
                }

                /*将鼠标移动距离转化为时间片，向下取整为整帧对应的时间片*/
                delPosX = (globalX - startGlobalX) - appliedPx

                var deltaFullFrame = Math.floor(delPosX / pxPerFrame); // 取整操作，保证裁切为整帧数

                // 查看是否可以吸附
                let isSnappedSuc = false;
                if(!isScrollClipping){
                    let tempPos = fragmentInfo.trackFrameIn + delPosX / pxPerFrame * oneFrameToTimes;
                    getSnappingPosSig(tempPos);
                    if(snappingPos !== -1){
                        deltaFullFrame = Math.floor((snappingPos - fragmentInfo.trackFrameIn) / oneFrameToTimes);
                        isSnappedSuc = true;
                    }
                }
                root.isSnapped = isSnappedSuc;

                // 多选整组裁切: 钳制到所有选中片段都可行的帧数(锁步, 以最受限为准)
                if(leftClipDragArea.isGroupClip){
                    deltaFullFrame = TimelineEditController.clampGroupTrimDelta(deltaFullFrame);
                }

                var deltaBaseTimeFrames = deltaFullFrame * oneFrameToTimes  // 单位：时间片
                var tempFrameIn = fragmentInfo.frameIn + deltaBaseTimeFrames

                var tempTrackIn = fragmentInfo.trackFrameIn + deltaBaseTimeFrames

                /*先处理是否需要滚动裁切的逻辑*/
                if(trackVisibleRight - tempTrackIn / oneFrameToTimes * pxPerFrame <= scrollClipArea){ // 进入右侧滚动裁切区域
                    if(fragmentInfo.trackFrameOut / oneFrameToTimes * pxPerFrame > trackVisibleRight){  // 判断片段尾部是否全部在可视区域内
                        if(!isScrollClipping){
                            isScrollClipping = true;
                            scrollClip(true, true, true); // 发送开始滚动信号
                        }
                    }
                    return;
                }else if(tempTrackIn / oneFrameToTimes * pxPerFrame < trackVisibleLeft){  // 进入左侧滚动恢复区域 ， todo: 这里是否也需要判断片段是否还有出于可视区域之外的部分
                    if(tempFrameIn <= 0 || trackVisibleLeft === 0){  // 已经恢复到头
                        // fragmentInfo.frameIn = 0;
                        scrollClip(false, true, false);
                        isScrollClipping = false;
                    }else{
                        if(!isScrollClipping){
                            isScrollClipping = true;
                            scrollClip(true, true, false);
                        }
                        return;
                    }
                }
                else{ // 在滚动区域之外
                    if(isScrollClipping){
                        isScrollClipping = false;
                        scrollClip(false, true, false);
                    }
                }

                /*处理常规区域内的裁切恢复操作*/
                if(fragmentInfo.frameOut - tempFrameIn < oneFrameToTimes){  // case: 裁切到最后一帧
                    if(isScrollClipping){
                        isScrollClipping = false;
                        scrollClip(false, true, true);

                    }
                    fragmentInfo.trackFrameIn = fragmentInfo.trackFrameOut - oneFrameToTimes
                    fragmentInfo.frameIn = fragmentInfo.frameOut - oneFrameToTimes
                }
                else if(fragmentInfo.frameIn + deltaBaseTimeFrames < 0){  // case: 片段恢复到头
                    var tempIn = fragmentInfo.frameIn
                    var trackFrameIn = fragmentInfo.trackFrameIn;
                    fragmentInfo.frameIn = 0
                    fragmentInfo.trackFrameIn -= tempIn;
                    if(isCloseToOtherFragment(true)){   // 判断恢复方向是否已经与紧邻的片段紧贴
                        fragmentInfo.frameIn = tempIn;
                        fragmentInfo.trackFrameIn = trackFrameIn;
                    }
                    // 恢复到头(或邻接回滚)后, 用当前 trackFrameIn 重锚起点使 delPosX 归零(保持旧行为: 反向拖动立即响应)
                    startGlobalX = globalX - (fragmentInfo.trackFrameIn - startClipTrackFrameIn) / oneFrameToTimes * pxPerFrame
                    delPosX = 0
                }
                else{  // 常规情况
                    startPosX += deltaFullFrame * pxPerFrame;
                    if(isScrollClipping){
                        isScrollClipping = false;
                        scrollClip(false, true, true);
                    }
                    var curTrackFrameIn = fragmentInfo.trackFrameIn;
                    if(fragmentInfo.trackFrameIn + deltaBaseTimeFrames <= 0){  // 片段头部恢复到轨道头部
                        fragmentInfo.frameIn = fragmentInfo.frameIn - fragmentInfo.trackFrameIn;
                        fragmentInfo.trackFrameIn = 0;
                    }else{
                        fragmentInfo.frameIn += deltaBaseTimeFrames
                        fragmentInfo.trackFrameIn += deltaBaseTimeFrames
                    }
                    fragmentChange(true, false, true)
                }
                editorManager.clipSeek(Math.round(fragmentInfo.trackFrameIn / root.oneFrameToTimes));
                fragmentChange(true, false, true)
                // 多选整组裁切: 将相同帧位移施加到其余选中片段
                if(leftClipDragArea.isGroupClip && deltaFullFrame !== 0){
                    TimelineEditController.applyGroupTrimToOthers(deltaFullFrame);
                }
            }
        }

        MouseArea{
            id:rightClipDragArea
            property real lastMousePosX: 0
            property real delPosX: 0
            property real rightframelengthLimit: 0  // 右侧可恢复最长帧限制
            property bool isStartclip: false
            property bool isScrollClipping: false
            property bool isGroupClip: false  // 本次拖拽是否为多选整组裁切
            property real startPosX: 0 // 音频波形起始点
            hoverEnabled:true
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            height: parent.height
            width: clipAreaWidth

            property int maxFrameOut: -1

            Component.onCompleted: {
                rightframelengthLimit = fragmentInfo.frameOut
            }

            onEntered: {
                if(!isStartclip){
                    if(leftClipDragArea.containsMouse){
                        cursorhelper.restoreOverrideCursor()
                    }
                    cursorhelper.setCustomCursor(":/icons/ic_cutright.svg", 24, 24)
                }
            }

            onExited: {
                if(!isStartclip){
                    cursorhelper.restoreOverrideCursor()
                }
                ShortcutObserver.disableAllShortcut(false);
            }

            onPressed: {
                // 未选中片段边缘按下：先独占选中再进入裁切，selectedClipCount 随之归 1，不会误开整组裁切
                if (!root.selected) {
                    root.itemClicked(false);
                }
                lastMousePosX = mouseX; // 初始化位置
                isStartclip = true;
                rightClipDragArea.isGroupClip = TimelineEditController.selectedClipCount() > 1;  // 多选则整组裁切
                if(rightClipDragArea.isGroupClip){
                    TimelineEditController.beginGroupTrim(fragmentInfo.clipNodeId, false);
                }
                startClip();
                root.updateLastResult()
                ShortcutObserver.disableAllShortcut(true)
            }

            onReleased: {
                finishDrag();
            }
            
            onCanceled: {
                finishDrag();
            }

            function finishDrag() {
                delPosX = 0;
                lastMousePosX = 0
                if(isScrollClipping){
                    isScrollClipping = false
                    scrollClip(false, false, false)
                }
                isStartclip = false
                if(!rightClipDragArea.containsMouse){
                    cursorhelper.restoreOverrideCursor()
                }

                root.updateLastResult()            // 清理滚动裁切残留的不足一帧尾部
                if(rightClipDragArea.isGroupClip){
                    // nova: 多选整组裁切一次事务提交(单步 undo,含 base)，内部按涉及类型回读并请重排。
                    TimelineEditController.commitGroupTrim();
                    rightClipDragArea.isGroupClip = false;
                } else {
                    fragmentInfo.commitTrim()          // nova: 裁切提交落 nle(源范围+时间线，单步 undo)
                }
                ShortcutObserver.disableAllShortcut(false)
                fragmentChange(false, false, false);
                root.isSnapped = false;
                editorManager.sendTrackEventForDragCLip(root.trackIndex, root.clipIndex, fragmentInfo.trackFrameOut, false, "audio", 3)
                rightClipDragArea.maxFrameOut = -1;
            }

            onPositionChanged: {
                if(!isStartclip)
                    return
                if (rightClipDragArea.maxFrameOut < 0) {
                    // nova: 源全长上限取自 VM(originLength)
                    rightClipDragArea.maxFrameOut = fragmentInfo.originLength;
                }
                root.isMouseMoved = true;
                /*将鼠标移动距离转化为时间片，向下取整为整帧对应的时间片*/
                delPosX = mouseX - lastMousePosX + delPosX;
                lastMousePosX = mouseX;
                var deltaFullFrame = Math.ceil(delPosX / pxPerFrame);

                // 查看是否可以吸附
                var isSnappedSuc = false;
                if(!isScrollClipping){
                    let tempPos = fragmentInfo.trackFrameOut + delPosX / pxPerFrame * oneFrameToTimes;

                    getSnappingPosSig(tempPos);
                    if(snappingPos !== -1){
                        deltaFullFrame = Math.floor((snappingPos - fragmentInfo.trackFrameOut) / oneFrameToTimes);
                        isSnappedSuc = true;
                    }
                }
                root.isSnapped = isSnappedSuc;

                // 多选整组裁切: 钳制到所有选中片段都可行的帧数(锁步, 以最受限为准)
                if(rightClipDragArea.isGroupClip){
                    deltaFullFrame = TimelineEditController.clampGroupTrimDelta(deltaFullFrame);
                }

                var deltaBaseTimeFrames = deltaFullFrame * oneFrameToTimes // 单位：时间片
                var tempFrameOut = fragmentInfo.frameOut + deltaBaseTimeFrames
                var tempTrackFrameOut = fragmentInfo.trackFrameOut + deltaBaseTimeFrames;

                if(deltaFullFrame > 0){ // 尾部恢复方向
                    if(fragmentInfo.frameOut >= rightClipDragArea.maxFrameOut){ // 尾部恢复已经到头
                        return;
                    }
                }

                /*先处理是否需要滚动裁切的逻辑*/
                if(tempTrackFrameOut / oneFrameToTimes * pxPerFrame - trackVisibleLeft <= scrollClipArea){
                    if(fragmentInfo.trackFrameIn / oneFrameToTimes * pxPerFrame < trackVisibleLeft){
                        if(!isScrollClipping){
                            isScrollClipping = true;
                            scrollClip(true, false, false);
                        }
                        return;
                    }
                    else{
                        if(isScrollClipping){
                            isScrollClipping = false;
                            scrollClip(false, false, false);
                        }
                    }
                }else if(tempTrackFrameOut / oneFrameToTimes * pxPerFrame >= trackVisibleRight){
                    if(!isScrollClipping){
                        isScrollClipping = true;
                        scrollClip(true, false, true);
                    }
                    return;
                }
                else if(isScrollClipping){
                    isScrollClipping = false;
                    scrollClip(false, false, false);
                }

                /*处理常规区域内的裁切恢复操作*/
                if((tempFrameOut - fragmentInfo.frameIn) < oneFrameToTimes){  // 裁切到剩余一帧
                    fragmentInfo.frameOut = fragmentInfo.frameIn + oneFrameToTimes
                }
                else if(tempFrameOut > rightClipDragArea.maxFrameOut){  // 右侧恢复到头
                    fragmentInfo.frameOut = rightClipDragArea.maxFrameOut;
                }
                else{  // 正常情况
                    fragmentInfo.frameOut += deltaBaseTimeFrames
                    startPosX += deltaFullFrame * pxPerFrame;
                }

                // nova: 邻居钳制交由 C++ relayoutTrimPreview(单一数据源)，QML 不再做二次修正——
                // 旧 deltaMove 修正会与内核钳制叠加，快速裁切时把右缘拉回本帧起点，导致与相邻片段间隙。
                fragmentChange(false, false, true);

                editorManager.clipSeek(Math.floor(fragmentInfo.trackFrameOut / oneFrameToTimes));
                fragmentChange(false, false, true);
                // 多选整组裁切: 将相同帧位移施加到其余选中片段
                if(rightClipDragArea.isGroupClip && deltaFullFrame !== 0){
                    TimelineEditController.applyGroupTrimToOthers(deltaFullFrame);
                }
            }
        }
    }

    // 特效、滤镜等向轨道拖拽时的蒙层样式
    TrackItemCover {
        anchors.fill: itemRectangle
        fragmentInfo: root.fragmentInfo
        rectRadius: fragment.rectRadius
    }

    onVisibleLeftChanged: {
        setTrackLength(visibleRight - visibleLeft);
    }

    onVisibleRightChanged: {
        setTrackLength(visibleRight - visibleLeft);
    }

    /**
     * @desc 设置轨道长度
     * @param length 长度，单位px
     */
    function setTrackLength(length) {
        trackLength = length;
    }

    Component.onCompleted: {
        if (CommonUtils.isNull(fragmentInfo)) {
            return;
        }
        originFragmentLength = fragmentInfo.length;
    }

    Component.onDestruction: {
        cursorhelper.restoreOverrideCursor();
    }

    // ========== 离屏片段对象池(轨道区域缓存)==========
    // enterPool: 离屏入池前由 C++ 调用,清瞬态(光标/裁切进行态),不触碰 fragmentInfo 绑定。
    function enterPool() {
        // 还原被裁切占用的系统光标,避免离屏后仍残留
        cursorhelper.restoreOverrideCursor()
        // 退出任何进行中的裁切状态(片段不可见,裁切无意义)
        if (leftClipDragArea.isStartclip) {
            leftClipDragArea.isStartclip = false
        }
        if (rightClipDragArea.isStartclip) {
            rightClipDragArea.isStartclip = false
        }
    }

    // rebind: 回屏复用时由 C++ 调用(无参,track/clip 已由 C++ 写入 context property)。
    // fragmentInfo 已由 C++ 在调用本函数前命令式喂好(rebindPooledView 里 setProperty),此处同步读即为新片段,
    // 不依赖声明式绑定重算(fragmentInfo 已非绑定,`fragmentInfo: modelData` 已从 TrackDock 移除)。
    // 音波兜底【同步段】:复用当场立即重算 audioPath + refreshUI。
    // 原因:callLater 推迟的 1 帧内,池中冻结的旧 _dataList 仍会被 paint 画 → 1 帧旧波形闪烁(串台)。
    // 显式重设 audioPath(触发 setAudioPath 重算 _audioMD5 + addAudio)+ 同步 refreshUI,当场归位。
    // 其余命令式初始化(音频名/trim 上下限)丢 Qt.callLater,等声明式绑定(trackIndex/clipIndex)重算落定再跑。
    function rebind() {
        // 同步段:立即重算音波,杜绝 callLater 前 1 帧画池中旧波形。
        if (!CommonUtils.isNull(fragmentInfo)) {
            audioWavePaint.audioPath = fragmentInfo.path
            audioWavePaint.refreshUI()
        }
        Qt.callLater(function() { _rebindImpl(); })
    }

    // 复用换绑后重跑命令式初始化(对应 Component.onCompleted 里跑过的内容)。
    // fragmentInfo 由 C++ 命令式喂(非绑定);trackIndex/clipIndex 仍是随 context property 自动重算的声明式绑定。
    // 音波已在 rebind() 同步段重算,此处不重复。
    function _rebindImpl() {
        if (CommonUtils.isNull(fragmentInfo)) {
            return;
        }
        // trackIndex/clipIndex 是 TrackDock 中 `trackIndex: track_index` 的声明式绑定,
        // C++ rebindPooledView 已改 context property,绑定自动重算,这里不可命令式赋值(会断绑定)。
        // 音频名同理由声明式绑定(:318 fragmentInfo.clipName)承接,rebind 无需命令式重赋。
        // 重跑主 onCompleted(:777):原始长度
        originFragmentLength = fragmentInfo.length;
        // 重跑 leftClipDragArea.onCompleted(:475):左裁切上限
        leftClipDragArea.leftframelengthLimit = fragmentInfo.frameIn
        // 重跑 rightClipDragArea.onCompleted(:611):右裁切上限
        rightClipDragArea.rightframelengthLimit = fragmentInfo.frameOut
    }

    // 片段头部进行滚动裁切时更新被裁切片段的相关属性
    function leftScrollClipUpdate(fixPos, scrollToLeft){
        let newTrackFrameIn = fixPos / pxPerFrame * oneFrameToTimes;
        let delta = newTrackFrameIn - fragmentInfo.trackFrameIn
        if(scrollToLeft){
            // 裁切之后小于等于一帧
            if(fragmentInfo.length + delta <= oneFrameToTimes){
                fragmentInfo.frameIn = fragmentInfo.frameOut - oneFrameToTimes;
                fragmentInfo.trackFrameIn = fragmentInfo.trackFrameOut - oneFrameToTimes;

                scrollClip(false, true, true);
                // cursorhelper.restoreOverrideCursor();
                fragmentChange(true, true, false);
                return;
            }
        }else{
            if(fragmentInfo.frameIn + delta <= 0){   // 片段头部恢复到头
                var tempFrameIn = fragmentInfo.frameIn;
                fragmentInfo.frameIn = 0;
                fragmentInfo.trackFrameIn -= tempFrameIn;
                scrollClip(false, true, false);
                // cursorhelper.restoreOverrideCursor();
                fragmentChange(true, true, false);
                return;
            }
            if(trackVisibleLeft / pxPerFrame * oneFrameToTimes === 0 ||  fragmentInfo.trackFrameIn === 0 ){  // 滚动到轨道头部
                // 这里需要更新trackFrameIn 和 frameIn
                var tempTrackFrameIn = fragmentInfo.trackFrameIn;
                fragmentInfo.frameIn -= tempTrackFrameIn;
                fragmentInfo.trackFrameIn = 0;
                scrollClip(false, true, false);
                fragmentChange(true, true, false);
                return;
            }
        }

        var trackFrameIn = fragmentInfo.trackFrameIn;
        fragmentInfo.trackFrameIn = newTrackFrameIn;
        if(isCloseToOtherFragment(true)){   // 判断恢复方向是否已经与紧邻的片段紧贴, 紧贴则停止滚动
            var deltaMove = trackFrameIn - fragmentInfo.trackFrameIn;
            fragmentInfo.frameIn -= deltaMove;
            scrollClip(false, true, false);
        }else{
            fragmentInfo.frameIn += delta;
            leftClipDragArea.startPosX += delta / oneFrameToTimes * pxPerFrame;
        }
        editorManager.clipSeek(Math.ceil(fragmentInfo.trackFrameIn / oneFrameToTimes));
    }

    // 片段尾部进行滚动裁切时更新被裁切片段的相关属性
    function rightScrollClipUpdate(fixPos, maxFrameOut, isScrollToLeft){
        let newTrackFrameOut = fixPos / pxPerFrame * oneFrameToTimes;
        let delta = newTrackFrameOut - (fragmentInfo.trackFrameIn + fragmentInfo.length);
        if(!isScrollToLeft){
            if(fragmentInfo.length + delta <= oneFrameToTimes){
                fragmentInfo.frameOut = fragmentInfo.frameOut - oneFrameToTimes;
                fragmentInfo.trackFrameIn = fragmentInfo.trackFrameOut - oneFrameToTimes;

                scrollClip(false, false, false);
                // cursorhelper.restoreOverrideCursor();
                fragmentChange(false, true, false);
                return;
            }
        }else{
            if(fragmentInfo.frameOut + delta >= maxFrameOut){
                // fragmentInfo.frameOut = rightClipDragArea.rightframelengthLimit;
                scrollClip(false, false, false);
                // cursorhelper.restoreOverrideCursor();
                fragmentChange(false, true, false);
                return;
            }
        }

        fragmentInfo.frameOut += delta;
        if(isCloseToOtherFragment(false)){   // 紧贴相邻片段(C++ 已钳制 frameOut)：仅停止滚动，不再 QML 二次修正
            scrollClip(false, true, false);
        }else{
            leftClipDragArea.startPosX += delta / oneFrameToTimes * pxPerFrame;
        }
        editorManager.clipSeek(Math.floor(fragmentInfo.trackFrameOut / oneFrameToTimes));
    }

    // 保存最近一次裁切之后的结果
    function updateLastResult(){
        var delta = fragmentInfo.length - Math.floor(fragmentInfo.length / oneFrameToTimes) * oneFrameToTimes; // 尾部不足一帧的长度，主要是滚动裁切时尾部生成的, 解决滚动裁切后片段尾部可能出现半帧的问题
        fragmentInfo.frameOut -= delta;

        root.lastTrackFreamIn = fragmentInfo.trackFrameIn;
        root.lastFreamIn = fragmentInfo.frameIn;
        root.lastLength = fragmentInfo.length;
    }

    // 片段恢复时判断前边是否与相邻片段已经紧挨
    function isCloseToOtherFragment(isLeft){
        var trackFrameIn = fragmentInfo.trackFrameIn;
        var tempFrameOut = fragmentInfo.frameOut;
        fragmentChange(isLeft, false, true)  // 如果紧贴相邻片段，C++中的裁切类中会将trackFrameIn重置

        if(isLeft){
            return trackFrameIn !== fragmentInfo.trackFrameIn;
        }else{
            return tempFrameOut !== fragmentInfo.frameOut;
        }
    }

    // 将此次裁切操作添加进撤销堆栈中
    function addClipAction(){
        undoManger.doFragmentClipChangAction(QTractorType.audio, root.trackIndex, root.clipIndex, lastTrackFreamIn, lastFreamIn, lastLength,
                                             fragmentInfo.trackFrameIn, fragmentInfo.frameIn, fragmentInfo.length);
    }

    // 标记点标记带（素材层）
    MarkPointRibbon {
        id: markPointRibbon
        parent: root.parent
        x: root.x
        // 底对齐 + 压顶
        y: root.y + (5 - height)
        width: root.width
        height: 18
        z: root.z + markRibbonZOffset
        bottomAligned: true
        pxPerFrame: root.pxPerFrame
        // 多轨道下标记带逃逸成 MTV 兄弟、非阻断 HoverHandler 多播无视 z 遮挡：音频片段滚到固定主视频轨(scrollModel
        // TOP/BOTTOM)后视觉被主轨盖住却仍响应鼠标。据标记带 y 与"已钉住主轨背景 rect"求交注入 occludedByMainTrack，
        // ribbon 内每枚标记的 HoverHandler/MouseArea 会据此禁用——只断响应、不动 visible(露出段仍显示、z 序自然被盖)。
        // 用真实钉住 rect(multiTrackView.mainTrackRect)直接求交，避免 visibleRect±高度 拼带的偏移致"露出仍响应"。
        // 音频轨永非主轨(主轨=视频轨0)，故无 trackIndex 豁免。
        occludedByMainTrack: {
            if (CommonUtils.isNull(multiTrackView)) {
                return false;
            }
            if (multiTrackView.scrollModel === MultiTrackView.SCROLL_MODEL_NORMAL) {
                return false;  // 未钉住，主轨在自然位，音频标记不与其重叠
            }
            let mtr = multiTrackView.mainTrackRect;
            // 标记 icon 底对齐、实占底部 12px(上方 6px 空)：用 icon 实占段求交，否则空段会戳进相邻主轨 rect 底边误判。
            // 再留 gap 级容差(4px)：相邻第一音频轨会与主轨底边贴边数 px，超过此深度才算真滚到主轨身后。
            let markTop = markPointRibbon.y + markPointRibbon.height - 12;
            let markBottom = markPointRibbon.y + markPointRibbon.height;
            let overlap = Math.min(markBottom, mtr.y + mtr.height) - Math.max(markTop, mtr.y);
            return overlap > 4;
        }
        fragmentHost: CommonUtils.isNull(root.fragmentInfo) ? null : root.fragmentInfo
        visible: !CommonUtils.isNull(root.fragmentInfo)
        // 拖动标记贴边时横向自动滚动
        scroller: flickable
        // 反向拖动吸附数据源
        snappingProvider: root.snappingProvider
        // playing 有意不绑定：播放中允许拖动，拖动起始由 MarkPointItem.onDraggingChanged 显式调 editorManager.pause() 暂停，绑定 playing 反而会禁止这一交互。
        // playing 属性保留为可选硬防护（如需"播放中禁止拖动"可一行绑定生效）。
    }
}
