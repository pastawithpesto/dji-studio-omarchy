/**
    * @author: dendi.zheng
    * @details:  多轨道上的视频片段
    * @date: 2024-07-17 15:14:52
    */

import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.15
import Qt5Compat.GraphicalEffects
import QtQuick.Window 2.15
import Controls 1.0
import Config 1.0
import MediaFrame 1.0
import VideoFragmentViewModel 1.0
import ShortcutAction 1.0
import KeyframeLayerView 1.0
import AudioWavePaint 1.0
import KeyframeItemData 1.0
import CursorHelper 1.0
import MultiTrackView 1.0
import ThumbnailListModel 1.0
import SettingPanelViewModel 1.0
import Qt.labs.platform 1.1
import app_qrc 1.0
import PanoramaConfig 1.0
import TransitionClipViewModel 1.0
import Nova 1.0
import "../transition/"
import Nova 1.0
import KeyframeBtnViewModel 1.0
import TrackingManager 1.0
import "markPoint"


// MediaFragment的作用是展示一段视频片段，包括视频的缩略图、音频波形、片段名称、片段时长、所用滤镜等信息
// 由于存在缩放，所以本身轨道可以无限长，这种情况下缩略图肯定是不能全展示完，只展示能看得见的部分即可。
// 为了实现这个功能，目前粗糙的先用repeat重复N张图片，然后在滚动的过程中不断改变offset，使缩略图始终能展示出来。
// 等后面对model/delegate理解一些后，看看是否有可借鉴之处，到时再来优化这里的实现。
Item {
    id: root
    signal itemDidClickedSignal

    // nova: viewModel 现为 TimelineVideoClipViewModel，布局字段直接 viewModel.X 读取。
    //required property VideoFragmentViewModel fragmentViewModel
    required property TimelineVideoClipViewModel viewModel
    required property KeyframeBtnViewModel keyframeBtnViewModel



    // 反向拖动标记的吸附数据源(multiTrackDataProvider)，由 TrackDock 注入并下发给标记带
    property var snappingProvider: null

    // 选中框宽度
    property int selectedGripWidth: 2

    // 是否处于选中状态
    property bool selected: CommonUtils.isNull(viewModel) || !viewModel.hasFragment ? false : viewModel.selected
    // 增稳生效态(nova: 从片段绑定的 TimelineVideoClipViewModel 投影)：视角标签下拉门控
    readonly property bool isUseStabilize: CommonUtils.isNull(viewModel) || !viewModel.hasFragment ? false : viewModel.isUseStabilize
    // 特效预览临时挂的 EffectClip：预览期间隐藏轨道上的 clip 样式(本体/缩略图/角标/选中框)，预览结束回滚后自然消失。
    readonly property bool isEffectClip: CommonUtils.isNull(viewModel) || !viewModel.hasFragment ? false : viewModel.isEffectClip
    // 特效预览尾部黑帧补位片段：同 EffectClip，预览期间隐藏轨道上的 clip 样式。
    readonly property bool isPreviewFillerClip: CommonUtils.isNull(viewModel) || !viewModel.hasFragment ? false : viewModel.isPreviewFillerClip
    // 特效预览尾部黑帧补位片段：预览期间隐藏轨道上的 clip 样式；EffectClip 本体保留显示。
    readonly property bool hideClipStyle: isPreviewFillerClip && previewAssetsManager.isPreviewing
    // 输出的帧率
    property int outputFps: 30
    // 每帧的宽度 == scaleBase
    property real pxPerFrame: 0
    // 视频路径
    property string mediaPath: container.sourceLost || CommonUtils.isNull(viewModel) || !viewModel.hasFragment ? "" : viewModel.path
    // 视频分段MD5(上游预算)，随缩略图 URL 下传给 provider，避免其在 UI 线程重算导致卡死
    property string mediaMd5: CommonUtils.isNull(viewModel) || !viewModel.hasFragment ? "" : viewModel.cachedMd5
    // 视频名称
    property string mediaName: CommonUtils.isNull(viewModel) || !viewModel.hasFragment ? "" : viewModel.path.split('/').pop()
    // 速度
    property double speed: CommonUtils.isNull(viewModel) || !viewModel.hasFragment ? 1 : viewModel.speed
    // 变速名称
    property string speedName: qsTr("pccut_panel_speed") + " " + parseFloat(speed.toFixed(4)) + "x"
    property string speedCurveString: {
        if (CommonUtils.isNull(viewModel) || !viewModel.hasFragment) {
            return "";
        }

        var list = viewModel.speedList;  // 确保绑定到 speedList
        return viewModel.convertToPositionCurvedSpeedString();
    }
    property int speedType: CommonUtils.isNull(viewModel) || !viewModel.hasFragment ? 0 : viewModel.speedType
    // 可见的开始像素
    property real visibleLeft: 0
    // 可见的结束像素
    property real visibleRight: width

    property real indicatorFrame
    //相邻两个片段中间的间隙， 片段整体宽度不变，填充内容时，左边留1像素，右边留1像素
    property real itemGap: 1

    property int trackIndex: -1
    property int clipIndex: -1
    property real offset: 0

    property real trackVisibleLeft: 0
    property real trackVisibleRight: 0
    // 一帧视频对应的时间片
    property int  oneFrameToTimes : 30000 / root.outputFps
    property int scrollClipArea : 30
    // 左右裁切控件触发区域宽度
    property int clipAreaWidth : 5

    property real rightframelengthLimit: 0  // 右侧可恢复最长帧限制
    property real isClipping: leftClipDragArea.isStartclip || rightClipDragArea.isStartclip
    property bool isCursorEnterClipArea: false // 鼠标是否进入裁切区域
    property bool isMouseMoved: false // 鼠标位置是否发生移动
    // 是否是高亮状态, 滤镜拖拽添加的时候使用
    property bool showHighlight: false
    property bool isSnapped: false // 是否吸附成功
    property real snappingPos: -1 // 吸附位置
    property real keyframeLayerX: CommonUtils.isNull(viewModel) || !viewModel.hasFragment ? 0 : -viewModel.frameIn / oneFrameToTimes * pxPerFrame
    property bool showInfoTitle: !superSlowItemView.visible

    // 点击
    signal itemClicked(bool isRightButton)
    // 片段拖拽 移动
    signal itemDragMove(point point, bool isFirst)
    // 片段拖拽 结束
    signal itemDragRelease(point point, bool isCancel)

    // 信号:剪切结束
    signal fragmentChange(bool isHeadClip, bool isClipping, bool isScroll)
    // 信号: 开始裁切
    signal startClip()
    // 裁切结束
    signal endClip()
    // 信号： 是否开启滚动裁切
    signal scrollClip(bool isScroll, bool isLeftClip, bool isScrollToLeft)
    // 信号： 关键帧变化
    signal keyFrameChange()
    // 信号： tracking变化
    signal trackingChange()
    // 信号： 区域关键帧变化
    signal regionChange()
    // 信号: 运镜模版片段发生改变
    signal movementClipChange()
    // 信号： 查看当前位置是否可以吸附
    signal getSnappingPosSig(real pos)

    // 信号： 右键打开片段操作弹窗
    signal openOperatorPop(real windowPointX, real windowPointY, bool isMediaLost, bool isSelectFile, bool topasteKeyframe, bool composeFragmentValid);
    signal openOperatorPop_Keyframe(real windowPointX, real windowPointY, bool tocopy, bool topaste);

    // 标签是否处于激活态：本片段单选且右侧当前 tab 为对应类型时为 true
    property bool singleSelectedTag: selected && settingPanel.currentTabType !== SettingPanelViewModel.SETTINGPANELTABTYPE_AUDIO
    property bool panoramaTagFocus: singleSelectedTag && settingPanel.currentTabType === SettingPanelViewModel.SETTINGPANELTABTYPE_PANORAMA
    property bool qualityTagFocus: singleSelectedTag && settingPanel.currentTabType === SettingPanelViewModel.SETTINGPANELTABTYPE_QUALITY
    property bool regSpeedTagFocus: singleSelectedTag && settingPanel.currentTabType === SettingPanelViewModel.SETTINGPANELTABTYPE_REGSPEED
    property bool superSlowTagFocus: singleSelectedTag && settingPanel.currentTabType === SettingPanelViewModel.SETTINGPANELTABTYPE_SUPER_SLOW
    property bool lutTagFocus: singleSelectedTag && settingPanel.currentTabType === SettingPanelViewModel.SETTINGPANELTABTYPE_ADJUST_LUT
    property bool styleFilterTagFocus: singleSelectedTag && settingPanel.currentTabType === SettingPanelViewModel.SETTINGPANELTABTYPE_ADJUST_STYLEFILTER
    property bool effectTagFocus: singleSelectedTag && settingPanel.currentTabType === SettingPanelViewModel.SETTINGPANELTABTYPE_EFFECT
    property bool dashboardTagFocus: singleSelectedTag && settingPanel.currentTabType === SettingPanelViewModel.SETTINGPANELTABTYPE_DASHBOARD
    property bool viewingModeTagFocus: singleSelectedTag && settingPanel.currentTabType === SettingPanelViewModel.SETTINGPANELTABTYPE_PANORAMA
    property bool transitionTagFocus: singleSelectedTag && settingPanel.currentTabType === SettingPanelViewModel.SETTINGPANELTABTYPE_TRANSITION
    property bool curveSpeedTagFocus: singleSelectedTag && settingPanel.currentTabType === SettingPanelViewModel.SETTINGPANELTABTYPE_SPEED
    property bool beautyTagFocus: singleSelectedTag && settingPanel.currentTabType === SettingPanelViewModel.SETTINGPANELTABTYPE_BEAUTY

    // 快捷变速弹框是否正在展示
    property bool regSpeedAlertDisplayed: false
    // speedType 0=普通 1=曲线 2=超慢；仅普通变速显常规角标，与曲线角标(curveSpeedTemplateName)互斥
    property bool speedTagDisplayed: (speedType === 0 && speed != 1)
    property bool viewModeChooseDisplayed: false

    property bool isDragging: false

    readonly property bool hasTransition: transitionViewModel.isValid
    readonly property string transitionName: transitionViewModel.displayName
    readonly property int transitionLength: transitionViewModel.transitionLength

    property bool showTransitionPlaceholder: false
    // Z-Index 层级管理常量
    // 主轨道的片段层级是51（背景50，阴影52），其他轨道的片段层级是0
    readonly property int zIndexBase: trackIndex === 0 ? 51 : 0           // 未选中
    readonly property int zIndexDragging: 100     // 拖拽
    readonly property int zIndexTransition: 10    // 转场偏移
    readonly property int zIndexBorder: 20        // 选中框偏移
    readonly property int zIndexClipArea: 30      // 裁切区域偏移
    // 标记带在 root.parent 后相对 root.z 的 z 偏移：高于相邻同轨片段体(差≥1)、
    // 高于自身选中框/关键帧层/转场/追踪/运镜/转场占位(最高 +21)，又远低于 zIndexDragging 以保证拖动片段时标记仍在最上
    readonly property int markRibbonZOffset: 22

    readonly property int currentZIndex: isDragging ? zIndexDragging : zIndexBase

    onViewModelChanged: {
        updateViewModeChooseDisplayedStatus();
    }

    Connections {
        target: trackDockViewModel
        function onIndicatorFrameChanged() {
            updateViewModeChooseDisplayedStatus();
        }
    }
    function updateViewModeChooseDisplayedStatus() {
        if (CommonUtils.isNull(root.viewModel) || !root.viewModel.hasFragment) {
            root.viewModeChooseDisplayed = false;
            return;
        }
        const indicatorPos = editorManager.positionForFrame(trackDockViewModel.indicatorFrame);
        const fragmentIn = root.viewModel.trackFrameIn;
        const fragmentOut = root.viewModel.trackFrameOut;
        root.viewModeChooseDisplayed = indicatorPos >= fragmentIn && indicatorPos <= fragmentOut + 1;
    }

    width: fragment.displayLength
    height: 64
    z: currentZIndex

    CursorHelper {
        id: cursorhelper
    }

    TransitionClipViewModel {
        id: transitionViewModel
        objectName: "transitionViewModel"
        // 工程打开/delegate 创建时，已有转场首次渲染
        Component.onCompleted: transitionViewModel.refreshFromTrack()
    }
    // 轨道片段 色彩还原/滤镜 徽标数据(按 clip 节点绑定，子滤镜变化自动刷新)
    BadgeFilterClipViewModel {
        id: clipFilterBadgeVM
        Component.onCompleted: clipFilterBadgeVM.refreshFromTrack()
    }
    // 轨道片段 仪表盘 徽标数据(按 clip 节点绑定，custom_render 滤镜变化自动刷新)
    BadgeDashboardClipViewModel {
        id: clipDashboardBadgeVM
        Component.onCompleted: clipDashboardBadgeVM.refreshFromTrack()
    }
    // 轨道片段 全景散点关键帧绘制数据(nova)：面板/工具栏经 nova 改帧 → onChanged → 重绘 keyframeLayerView
    PanoramaClipViewModel {
        id: panoClipVM
        Component.onCompleted: panoClipVM.refreshFromTrack()
    }
    // 上次已绘制的散点 position(MK) -> transition；用于增量 diff，避免每次 onChanged 全量重建
    property var _panoKfByPos: ({})
    // 片段身份变化后强制一次全量重建（清掉旧 clip 残留），之后转增量
    property bool _panoKfFullRebuild: true
    function rebuildPanoKeyframes() {
        var l = panoClipVM.keyframes();
        var next = {};
        for (var i = 0; i < l.length; i++) {
            next[l[i].position] = { transition: l[i].transition, hide: l[i].hide === true };
        }
        if (_panoKfFullRebuild) {
            keyframeLayerView.removeAllKeyFrame(root.trackIndex, root.clipIndex);
            for (var k in next) {
                keyframeLayerView.addKeyFrame(root.trackIndex, root.clipIndex, Number(k), "", next[k].transition, next[k].hide);
            }
            _panoKfFullRebuild = false;
        } else {
            var prev = _panoKfByPos;
            for (var p in prev) {  // 删除：旧有新无
                if (!(p in next)) {
                    keyframeLayerView.removeKeyFrame(root.trackIndex, root.clipIndex, Number(p));
                }
            }
            for (var q in next) {  // 新增 / 过渡或隐藏变化
                if (!(q in prev)) {
                    keyframeLayerView.addKeyFrame(root.trackIndex, root.clipIndex, Number(q), "", next[q].transition, next[q].hide);
                } else if (prev[q].transition !== next[q].transition) {
                    keyframeLayerView.changeKeyFrameTransition(root.trackIndex, root.clipIndex, Number(q), next[q].transition);
                } else if (prev[q].hide !== next[q].hide) {
                    // 隐藏态翻转(变速重叠隐藏)：销毁旧 delegate 重建，重应用 setVisible(!hide)
                    keyframeLayerView.removeKeyFrame(root.trackIndex, root.clipIndex, Number(q));
                    keyframeLayerView.addKeyFrame(root.trackIndex, root.clipIndex, Number(q), "", next[q].transition, next[q].hide);
                }
            }
        }
        _panoKfByPos = next;
        // 复用老选中机制：本次有新增关键帧 → delegate 已建好，发 keyframeClicked 选中它(对齐老 addKeyframe@2039)
        var added = panoClipVM.addedKeyframePosition();
        if (added >= 0) {
            globalSignal.keyframeClicked(root.trackIndex, root.clipIndex, added);
        }
    }
    // 上次已绘制区域组签名: groupId -> 签名串(边界+内部帧)，用于增量 diff
    property var _panoRegionSig: ({})
    // 上次已绘制区域组内帧过渡: groupId -> {position: transition}，用于仅过渡变化时就地更新
    property var _panoRegionTrans: ({})
    // 片段身份变化后强制一次区域全量重建
    property bool _panoRegionFullRebuild: true
    // 上次已绘制运镜组签名 / 强制全量重建(同区域机制)
    property var _panoMovementSig: ({})
    property var _panoMovementTrans: ({})
    property bool _panoMovementFullRebuild: true
    // 区域结构签名：边界 + 内部帧(位置:隐藏)；过渡与参数值不入签名。
    // 过渡就地更新(changeKeyFrameTransition)不销毁 delegate，故不参与「先删后加」的判定。
    function _panoRegionSig1(r) {
        var s = r.sourceStart + "," + r.sourceEnd + "," + r.firstKfPos + "," + r.lastKfPos + ";";
        var kfs = r.keyframes || [];
        for (var i = 0; i < kfs.length; i++) s += kfs[i].position + ":" + (kfs[i].hide === true) + ",";
        return s;
    }
    // 组内帧过渡表：position -> transition，用于结构未变时的就地过渡 diff
    function _panoRegionTrans1(r) {
        var m = {};
        var kfs = r.keyframes || [];
        for (var i = 0; i < kfs.length; i++) m[kfs[i].position] = kfs[i].transition;
        return m;
    }
    // 结构未变、仅过渡变化：按帧就地改过渡(保留 delegate 与选中态)
    function _panoApplyTransDiff(prevTrans, nextTrans) {
        if (prevTrans === undefined) {
            return;
        }
        for (var p in nextTrans) {
            if (prevTrans[p] !== nextTrans[p]) {
                keyframeLayerView.changeKeyFrameTransition(root.trackIndex, root.clipIndex, Number(p), nextTrans[p]);
            }
        }
    }
    function _panoAddRegion(r) {
        // 段几何基准用区域自身源区间(sourceStart/sourceEnd)，对齐运镜修复：比例分母 originSegmentWidth
        // 恒非 0(避免旧写法 0/mkOriginLength 在探测未就绪时塌缩为 0 致比例发散/拖不动)。
        // 外扩边界不再依赖此 start/end，由 C++ 按片段源几何(frameIn/frameOut)夹断，区域仍可扩到整片段头尾。
        keyframeLayerView.addRegionSegment(r.groupId, root.trackIndex, root.clipIndex,
            r.sourceStart, r.sourceStart, r.sourceEnd, r.sourceStart, r.sourceEnd, r.firstKfPos, r.lastKfPos);
        var kfs = r.keyframes || [];
        if (kfs.length > 0) {
            var map = {};
            for (var i = 0; i < kfs.length; i++) map[kfs[i].position] = { transition: kfs[i].transition, hide: kfs[i].hide === true };
            keyframeLayerView.addRegionKeyFrames(root.trackIndex, root.clipIndex, r.groupId, map);
        }
    }
    // 区域组(nova)：读 panoClipVM.regions() 按 groupId diff 重建区域段(边界/内部帧变化→先删后加)
    function rebuildPanoRegions() {
        var regions = panoClipVM.regions();
        var nextSig = {};
        var nextTrans = {};
        var nextById = {};
        var rebuiltIds = [];  // 本次「先删后加」重建的已有区域(删帧/移动/裁边界)，用于重建后恢复展开态
        for (var i = 0; i < regions.length; i++) {
            nextSig[regions[i].groupId] = _panoRegionSig1(regions[i]);
            nextTrans[regions[i].groupId] = _panoRegionTrans1(regions[i]);
            nextById[regions[i].groupId] = regions[i];
        }
        if (_panoRegionFullRebuild) {
            for (var oldId in _panoRegionSig) {
                keyframeLayerView.removeSegment(root.trackIndex, root.clipIndex, oldId);
            }
            for (var nid in nextById) {
                _panoAddRegion(nextById[nid]);
                rebuiltIds.push(nid);
            }
            _panoRegionFullRebuild = false;
        } else {
            for (var pid in _panoRegionSig) {  // 删除：旧有新无
                if (!(pid in nextSig)) keyframeLayerView.removeSegment(root.trackIndex, root.clipIndex, pid);
            }
            for (var qid in nextById) {  // 新增 / 边界或内部帧变化 → 先删后加
                if (!(qid in _panoRegionSig)) {
                    _panoAddRegion(nextById[qid]);
                    rebuiltIds.push(qid);
                } else if (_panoRegionSig[qid] !== nextSig[qid]) {
                    keyframeLayerView.removeSegment(root.trackIndex, root.clipIndex, qid);
                    _panoAddRegion(nextById[qid]);
                    rebuiltIds.push(qid);
                } else {
                    _panoApplyTransDiff(_panoRegionTrans[qid], nextTrans[qid]);
                }
            }
        }
        _panoRegionSig = nextSig;
        _panoRegionTrans = nextTrans;
        regionChange();
        // 区域选中只跟随内核 _selectedKeyframeGroup(唯一真相)：重建后据内核恢复，避免靠 diff 在重开时误选。
        // 加区域时 addRegionKeyframe 已 setSelectedKeyframeGroup；重开内核为空 → 不选中。
        var selGroupR = panoClipVM.selectedGroupId();
        if (selGroupR !== "" && (selGroupR in nextById)) {
            var addedId = panoClipVM.addedRegionId();
            var addedKfPos = panoClipVM.addedRegionKeyframePosition();
            if (addedId === selGroupR) {
                globalSignal.keyframeClicked(root.trackIndex, root.clipIndex, nextById[selGroupR].firstKfPos);  // 新区域:选中心帧
            } else if (addedKfPos >= 0) {
                globalSignal.keyframeClicked(root.trackIndex, root.clipIndex, addedKfPos);  // 已有区域内新增帧:选该帧
            } else if (rebuiltIds.indexOf(selGroupR) >= 0) {
                globalSignal.selectRegion(root.trackIndex, root.clipIndex, selGroupR);  // 重建已有的选中区域:恢复选中
            }
        }
    }
    function _panoAddMovement(m) {
        // 段几何基准用运镜自身源区间(sourceStart/sourceEnd)，对齐 tk 段(addTrackingSegment)：
        // 裁剪比例分母 originSegmentWidth = 段自身速度域宽度，恒非 0 且恒在片段源范围内，
        // 避免旧写法(0/mkOriginLength)在 mkOriginLength 未探测就绪时塌缩为 0 致裁剪比例发散(右裁向左/左裁弹到开头)。
        keyframeLayerView.addCameraMoveSegment(m.groupId, root.trackIndex, root.clipIndex,
            m.sourceStart, m.sourceStart, m.sourceEnd, m.sourceStart, m.sourceEnd, m.firstKfPos, m.lastKfPos);
        var kfs = m.keyframes || [];
        if (kfs.length > 0) {
            var map = {};
            for (var i = 0; i < kfs.length; i++) map[kfs[i].position] = { transition: kfs[i].transition, hide: kfs[i].hide === true };
            keyframeLayerView.addCameraMoveKeyFrames(root.trackIndex, root.clipIndex, m.groupId, map);
        }
    }
    // 运镜组(nova)：读 panoClipVM.movements() 按 groupId diff 重建运镜段(边界/内部帧变化→先删后加)。机制同 rebuildPanoRegions。
    function rebuildPanoMovements() {
        // 运镜悬停预览期间植入的运镜组仅供播放器预览，不在轨道上绘制运镜段；预览结束回滚后由再次重建恢复。
        if (previewAssetsManager.isPreviewing) {
            return;
        }
        var movements = panoClipVM.movements();
        var selKfRef = keyframeLayerView.selectedMovementKeyframeRef(root.trackIndex, root.clipIndex);  // 重建前捕获选中的内部帧"segId|索引"，重建后按新位置重选
        var nextSig = {};
        var nextTrans = {};
        var nextById = {};
        var rebuiltIds = [];
        for (var i = 0; i < movements.length; i++) {
            nextSig[movements[i].groupId] = _panoRegionSig1(movements[i]);
            nextTrans[movements[i].groupId] = _panoRegionTrans1(movements[i]);
            nextById[movements[i].groupId] = movements[i];
        }
        if (_panoMovementFullRebuild) {
            for (var oldId in _panoMovementSig) {
                keyframeLayerView.removeSegment(root.trackIndex, root.clipIndex, oldId);
            }
            for (var nid in nextById) {
                _panoAddMovement(nextById[nid]);
                rebuiltIds.push(nid);
            }
            _panoMovementFullRebuild = false;
        } else {
            for (var pid in _panoMovementSig) {
                if (!(pid in nextSig)) keyframeLayerView.removeSegment(root.trackIndex, root.clipIndex, pid);
            }
            for (var qid in nextById) {
                if (!(qid in _panoMovementSig)) {
                    _panoAddMovement(nextById[qid]);
                    rebuiltIds.push(qid);
                } else if (_panoMovementSig[qid] !== nextSig[qid]) {
                    keyframeLayerView.removeSegment(root.trackIndex, root.clipIndex, qid);
                    _panoAddMovement(nextById[qid]);
                    rebuiltIds.push(qid);
                } else {
                    _panoApplyTransDiff(_panoMovementTrans[qid], nextTrans[qid]);
                }
            }
        }
        _panoMovementSig = nextSig;
        _panoMovementTrans = nextTrans;
        movementClipChange();
        // 运镜段选中只跟随内核 _selectedKeyframeGroup(唯一真相)：重建后选中内核当前选中的运镜段。
        var selGroup = panoClipVM.selectedGroupId();
        if (selGroup !== "" && (selGroup in nextById) && rebuiltIds.indexOf(selGroup) >= 0) {
            globalSignal.selectRegion(root.trackIndex, root.clipIndex, selGroup);
        }
        // 恢复「内部帧」选中：playhead 派生，重建前捕获其索引、重建后按新位重选(会一并重选所属段)。
        if (selKfRef !== "") {
            var parts = selKfRef.split("|");
            var seg = parts[0];
            var idx = parseInt(parts[1]);
            if ((seg in nextById) && rebuiltIds.indexOf(seg) >= 0) {
                var kfs = nextById[seg].keyframes;
                if (idx >= 0 && idx < kfs.length) {
                    globalSignal.keyframeClicked(root.trackIndex, root.clipIndex, kfs[idx].position);
                }
            }
        }
    }
    Connections {
        target: panoClipVM
        function onChanged() {
            rebuildPanoKeyframes(); rebuildPanoRegions(); rebuildPanoTracking(); rebuildPanoMovements()
        }
        // 裁剪只改片段 source_range 几何，不改关键帧数据，onChanged 的内容 diff 无感不重建。
        // geometryChanged 在几何变化时驱动 refreshUI：layoutItemView 据新入/出点重算关键帧 x 并对
        // 越界项销毁/回界内 create 重建，覆盖左右手柄 commitTrim、整组裁切、undo/redo 等所有提交路径。
        function onGeometryChanged() {
            keyframeLayerView.refreshUI()
        }
    }
    // 上次已绘制的 tracking 片段 segmentId -> {start,end}；用于增量 diff
    property var _panoTkById: ({})
    property bool _panoTkFullRebuild: true
    // tk 生成中的活动组 id(base64)：由 C++ novaTkGroupCreated 广播(建组时)、TK_EXIT 清空。
    // 仅"正在生成的那一段"(== _liveTkGroupId)需 isGenerated=false 以铺满整个片段高度；其余(撤销恢复/打开草稿/
    // 已完成的历史 tk 段)为 true(收起态、可 seek 取消选中)。用组 id 而非 addedTrackingId 的 diff 检测，
    // 变速触发 recreateLayer 重建后该组已非"新增"，diff 会失效 → 段错误收起。
    property string _liveTkGroupId: ""
    function rebuildPanoTracking() {
        var l = panoClipVM.trackingSegments();
        // 生成中的活动段 id：以此判定是否铺满高度，非生成态恒为空串。
        var liveTkId = root._liveTkGroupId;
        var next = {};
        for (var i = 0; i < l.length; i++) {
            next[l[i].segmentId] = { start: l[i].start, end: l[i].end,
                                     clipStart: l[i].clipStart, clipEnd: l[i].clipEnd, transition: l[i].transition };
        }
        if (_panoTkFullRebuild) {
            for (var id0 in _panoTkById) {
                keyframeLayerView.removeSegment(root.trackIndex, root.clipIndex, id0);
            }
            for (var k in next) {
                keyframeLayerView.addTrackingSegment(k, root.trackIndex, root.clipIndex,
                                                     next[k].start, next[k].start, next[k].end,
                                                     next[k].clipStart, next[k].clipEnd, (k !== liveTkId), next[k].transition);
            }
            _panoTkFullRebuild = false;
        } else {
            var prev = _panoTkById;
            for (var p in prev) {  // 删除：旧有新无
                if (!(p in next)) {
                    keyframeLayerView.removeSegment(root.trackIndex, root.clipIndex, p);
                }
            }
            for (var q in next) {  // 新增 / 生成中尾增长 / 已完成段几何变化(裁切·放大还原·undo)
                if (!(q in prev)) {
                    keyframeLayerView.addTrackingSegment(q, root.trackIndex, root.clipIndex,
                                                         next[q].start, next[q].start, next[q].end,
                                                         next[q].clipStart, next[q].clipEnd, (q !== liveTkId), next[q].transition);
                } else if (q === liveTkId) {
                    // 生成中：尾部增长(窗口随原始范围一起长)，targeted 只更新结束点，不重建 delegate
                    if (prev[q].end !== next[q].end) {
                        keyframeLayerView.updateKeyFrame(root.trackIndex, root.clipIndex, next[q].start, next[q].end);
                    }
                    if (prev[q].transition !== next[q].transition) {
                        keyframeLayerView.changeTrackingSegmentTransition(root.trackIndex, root.clipIndex, q, next[q].transition);
                    }
                } else if (prev[q].start !== next[q].start || prev[q].end !== next[q].end
                           || prev[q].clipStart !== next[q].clipStart || prev[q].clipEnd !== next[q].clipEnd) {
                    // 已完成 tk 段几何变化(裁切落库·放大还原·undo)：就地更新，保留选中/展开态，不重建 delegate
                    keyframeLayerView.updateTrackingSegmentWindow(root.trackIndex, root.clipIndex, q,
                                                                  next[q].start, next[q].end, next[q].clipStart, next[q].clipEnd);
                    if (prev[q].transition !== next[q].transition) {
                        keyframeLayerView.changeTrackingSegmentTransition(root.trackIndex, root.clipIndex, q, next[q].transition);
                    }
                } else if (prev[q].transition !== next[q].transition) {
                    // 仅过渡效果变化：就地更新，不重建 delegate
                    keyframeLayerView.changeTrackingSegmentTransition(root.trackIndex, root.clipIndex, q, next[q].transition);
                }
            }
        }
        _panoTkById = next;
    }
    Connections {
        target: root
        // 片段数据/位置变化时，按 nova 草稿重新定位本片段的后置转场 + 徽标 + 全景关键帧/区域
        function onViewModelChanged() { transitionViewModel.refreshFromTrack(); clipFilterBadgeVM.refreshFromTrack(); clipDashboardBadgeVM.refreshFromTrack(); root._panoKfFullRebuild = true; root._panoRegionFullRebuild = true; root._panoMovementFullRebuild = true; panoClipVM.refreshFromTrack(); }
        function onTrackIndexChanged() { transitionViewModel.refreshFromTrack(); clipFilterBadgeVM.refreshFromTrack(); clipDashboardBadgeVM.refreshFromTrack(); root._panoKfFullRebuild = true; root._panoRegionFullRebuild = true; root._panoMovementFullRebuild = true; panoClipVM.refreshFromTrack(); }
        function onClipIndexChanged() { transitionViewModel.refreshFromTrack(); clipFilterBadgeVM.refreshFromTrack(); clipDashboardBadgeVM.refreshFromTrack(); root._panoKfFullRebuild = true; root._panoRegionFullRebuild = true; root._panoMovementFullRebuild = true; panoClipVM.refreshFromTrack(); }
    }
    Connections {
        target: transitionManager
        // 转场增删后，各片段各自按 nova 草稿重新定位本片段后置转场(未变者 pinToNode 守卫为空操作)
        function onTransitionNodeCreated(trackId, clipId, nodeId) { transitionViewModel.refreshFromTrack(); }
        function onTransitionNodeRemoved(trackId, clipId) { transitionViewModel.refreshFromTrack(); }
        // 拖拽转场时在命中边界的片段尾部展示可添加占位UI
        function onTransitionPlaceholderChanged(trackId, clipId, show) {
            root.showTransitionPlaceholder = show && trackId === root.trackIndex && clipId === root.clipIndex;
        }
    }
    onSelectedChanged: {
        if (!selected) {
            superSlowItemView.visible = false;
        }
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
        enabled: !editorManager.isInUserGuideStatus && !multiTrackView.isClipping
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
            // 拖拽过程中在某些条件下可以调出右键弹框
            if (mouse.button === Qt.RightButton && !isSortDragging) {
                itemClicked(true);
                let windowPoint = mapToItem(lightWindow.contentItem, mouse.x, mouse.y);
                let mediaLost = container.mediaLost;
                let isSelectFile = (multiTrackDataProvider.getSelectedCount() > 0);
                let topasteKeyframe = keyframeBtnViewModel.pasteOneSelectedKeyframe(false);
                let isComposeFragmentValid = (multiTrackDataProvider.getAudioSelectCount() === 0 && multiTrackDataProvider.getVideoSelectCount() > 0);

                // 计算实际显示的菜单项数量
                let visibleMenuCount = 1;//默认有一个菜单
                if (mediaLost) visibleMenuCount++;
                if (isSelectFile) visibleMenuCount++;
                if (topasteKeyframe) visibleMenuCount++;
                if (isComposeFragmentValid) visibleMenuCount++;

                // 菜单项高度和间距
                let itemHeight = 28;
                let menuHeight = visibleMenuCount * itemHeight;

                // 将相对坐标转换为屏幕绝对坐标
                let globalPos = mapToGlobal(mouse.x, mouse.y);

                // 计算菜单在屏幕上的底部位置
                let menuBottom = globalPos.y + menuHeight;

                // 获取屏幕可用高度
                let screenAvailableHeight = Screen.desktopAvailableHeight;

                //console.log("globalPos.y:", globalPos.y, "menuBottom:", menuBottom, "screenAvailableHeight:", screenAvailableHeight);

                // 如果菜单超出屏幕底部，向上移动
                if (menuBottom > screenAvailableHeight) {
                    let overflow = menuBottom - screenAvailableHeight;
                    let moveUpItems = Math.ceil(overflow / itemHeight);
                    // 注意：这里要修改的是 windowPoint.y（相对坐标）
                    windowPoint.y -= moveUpItems * itemHeight;

                    // 确保不会移到窗口顶部以上
                    windowPoint.y = Math.max(0, windowPoint.y);
                }
                openOperatorPop(windowPoint.x, windowPoint.y, mediaLost, isSelectFile, topasteKeyframe, isComposeFragmentValid);
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
            if (mouse.button === Qt.LeftButton) {
                // 如果已经响应了拖拽就不再响应点击
                if (isSortDragging) {
                    return;
                }
                itemClicked(false);
            }
        }
    }

    Rectangle {
        id: container

        property real curStartPosX: 0 // 第一帧缩略图的起始位置
        property bool mediaLost: CommonUtils.isNull(viewModel) || !viewModel.hasFragment || !viewModel.mediaSourceExists;
        property bool agency16KTimelapseLost: !CommonUtils.isNull(viewModel) && viewModel.hasFragment && viewModel.is16KTimelapse && !viewModel.agencySourceExists
        property bool sourceLost: mediaLost || agency16KTimelapseLost;

        // 特效预览临时 EffectClip：隐藏本体(子节点缩略图/角标/名称等随父级不可见一并隐藏)。
        visible: !hideClipStyle
        width: parent.width - itemGap
        x: itemGap / 2
        height: parent.height
        anchors.verticalCenter: parent.verticalCenter
        radius: fragment.rectRadius
        color: {
            if(container.mediaLost) {
                return ColorsConfig.color_brand;
            } else if(container.agency16KTimelapseLost) {
                return ColorsConfig.color_454649_transparent;
            }
            return ColorsConfig.color_143668_045858;
        }

        clip: true

        Item {
            id:leftClipDragArea
            property real delPosX: 0
            property real startGlobalX: 0  // 拖拽起点锚: 鼠标在 multiTrackView 内容坐标系的 x(边界重锚时会调整)
            property bool isStartclip: false
            property bool isScrollClipping: false
            property bool isGroupClip: false  // 本次拖拽是否为多选整组裁切

            property bool select: false
            property real validWidth: clipAreaWidth
            property KeyframeItemData selectTkFragment: null
            property real startClipFrameIn: 0  // 一次裁切动作开始时片段frameIn，在确定seek位置时使用，因为左侧恢复时trackFrameIn与底层的帧位置不能对齐
            property real startClipTrackFrameIn: 0  // 一次裁切动作开始时片段TrackframeIn，在确定seek位置时使用，因为左侧恢复时trackFrameIn与底层的帧位置不能对齐
            property bool containsMouse: leftClipMouseArea.containsMouse

            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            height: parent.height
            width: validWidth

            function finishDrag() {
                isStartclip = false
                root.isCursorEnterClipArea = leftClipDragArea.containsMouse;
                if(!leftClipDragArea.containsMouse){
                    cursorhelper.restoreOverrideCursor()
                }

                if(isScrollClipping){
                    isScrollClipping = false
                    scrollClip(false, true, false)
                }
                var clipPosition = viewModel.trackFrameIn
                if(leftClipDragArea.isGroupClip){
                    // nova: 多选整组裁切一次事务提交(单步 undo)，内部按涉及类型回读覆盖预览本地值。
                    TimelineEditController.commitGroupTrim()
                } else {
                    // nova: 裁切松手提交到 nle（源范围 + 时间线，单步 undo）；提交算法在 TrackUtil。
                    viewModel.commitTrim()
                    // nova: 提交后强制回读所有视频片段（含被动重排的未选中相邻片段），回正轨道头对齐/消除空隙。
                    TimelineEditController.syncVideoFromKernel()
                }
                // 裁切中关键帧图层布局被 isClipping 挡掉、整段拖拽未重排过；松手 commitTrim 后源入点已更新，
                // 此处同步重排一次让 tk 段内 x 立即按新源入点归正，避免补偿归 0 与异步重排之间出现跳变。
                keyframeLayerView.refreshUI()
                leftClipDragArea.isGroupClip = false;
                startClipFrameIn = viewModel.frameIn
                startClipTrackFrameIn = viewModel.trackFrameIn
                ShortcutObserver.disableAllShortcut(false);
                root.isSnapped = false;
                multiTrackView.isPressClip = false;
                // nova: 老 fragmentChange(false) 提交路径已停用，需在此显式复位 isClipping，
                // 否则其停留为 true 会使片段 MouseArea 失效，裁切后无法点击选中片段。
                multiTrackView.isClipping = false;
                // 裁切结束把播放位置收回时间指示器所指帧，否则下次播放从裁切落点开始。
                editorManager.clipSeek(trackDockViewModel.indicatorFrame);
                trackDockViewModel.indicatorFrameChanged();
                multiTrackView.adjustFlickable();
                leftClipDragArea.delPosX = 0
                editorManager.sendTrackEventForDragCLip(root.trackIndex, root.clipIndex, clipPosition, true, "video", 3)
                endClip();
            }

            MouseArea{
                id: leftClipMouseArea
                hoverEnabled:true
                anchors.fill: parent
                enabled: !editorManager.isInUserGuideStatus

            onWidthChanged: {
                logger.d("[VideoItemView] leftClipDragArea.width = " + leftClipDragArea.width);
            }

            Connections {
                target: lightWindow
                function onActiveChanged() {
                    if (!lightWindow.active && leftClipDragArea.isStartclip) {
                        leftClipDragArea.finishDrag()
                    }
                }
            }

            onReleased: {
                leftClipDragArea.finishDrag();
            }

            onCanceled: {
                leftClipDragArea.finishDrag();
            }
                onEntered: {
                    logger.d("[VideoItemView] leftClipDragArea::onEntered leftClipDragArea.width = " + leftClipDragArea.width
                            + ", leftClipDragArea.x = " + leftClipDragArea.x + ", leftClipDragArea.y = " + leftClipDragArea.y + ", isStartclip = " + leftClipDragArea.isStartclip);
                    if(!leftClipDragArea.isStartclip){
                        if(rightClipDragArea.containsMouse){
                            cursorhelper.restoreOverrideCursor()
                        }
                        cursorhelper.setCustomCursor(":/icons/ic_cutleft.svg", 24, 24)
                        multiTrackView.isEnterClip = true
                    }
                    root.isCursorEnterClipArea = true;
                }
                onExited: {
                    logger.d("[VideoItemView] leftClipDragArea::onExited leftClipDragArea.width = " + leftClipDragArea.width
                            + ", leftClipDragArea.x = " + leftClipDragArea.x + ", leftClipDragArea.y = " + leftClipDragArea.y + ", isStartclip = " + leftClipDragArea.isStartclip);
                    if(!leftClipDragArea.isStartclip){
                        cursorhelper.restoreOverrideCursor()
                        multiTrackView.isEnterClip = false
                        root.isCursorEnterClipArea = false;
                        ShortcutObserver.disableAllShortcut(false)
                    }
                }

                onPressed: {
                    // 未选中片段边缘按下：先独占选中再进入裁切，selectedClipCount 随之归 1，不会误开整组裁切
                    if (!root.selected) {
                        root.itemClicked(false);
                    }
                    leftClipDragArea.startClipFrameIn = viewModel.frameIn
                    leftClipDragArea.startClipTrackFrameIn = viewModel.trackFrameIn
                    leftClipDragArea.startGlobalX = mapToItem(multiTrackView, mouseX, 0).x;  // 拖拽起点在内容坐标系的 x
                    leftClipDragArea.delPosX = 0;
                    leftClipDragArea.isStartclip = true;
                    // 多选则整组裁切：以本片段为 base 开启会话（成员取当前 nle 选中集合）
                    leftClipDragArea.isGroupClip = TimelineEditController.selectedClipCount() > 1;
                    if(leftClipDragArea.isGroupClip){
                        TimelineEditController.beginGroupTrim(viewModel.clipNodeId, true);
                    }
                    ShortcutObserver.disableAllShortcut(true);
                    startClip();
                    multiTrackView.isPressClip = true;
                }
                onPositionChanged: {
                    if(!leftClipDragArea.isStartclip)
                        return
                    root.isMouseMoved = true;
                    // 自校正残差公式: delPosX = 鼠标目标位移 - 已应用位移(以内容坐标系为基准).
                    // 鼠标目标位移 = globalX - startGlobalX(不依赖片段自身位置, 主轨片段视觉 x 被钳制/负值时同样成立);
                    // 已应用位移 = (trackFrameIn - startClipTrackFrameIn) 换算像素.
                    // 每 tick 应用 floor(delPosX/pxPerFrame) 帧后, 残差自动 < 1帧, 不会像"绝对位移每 tick 重复施加"
                    // 那样按 tick 数放大(裁切一放就裁没/展开秒到头), 也不会像旧公式在片段不动时退化为纯累积(极限环闪动).
                    // 外部改写 frameIn/trackFrameIn(滚动裁切、C++ 钳制)会自动纳入"已应用位移", 无需手动清账.
                    var globalX = mapToItem(multiTrackView, mouseX, 0).x
                    var appliedPx = (viewModel.trackFrameIn - leftClipDragArea.startClipTrackFrameIn) / oneFrameToTimes * pxPerFrame
                    // case: 片段已经恢复到头
                    if(mouseX < 0 && leftEdgeArrived(viewModel.frameIn)){
                        // 边界到达, 重锚起点使 delPosX 归零(保持旧行为: 反向拖动立即响应)
                        leftClipDragArea.startGlobalX = globalX - appliedPx
                        leftClipDragArea.delPosX = 0
                        return
                    }

                    // case: 只剩下一帧(最小长度), 继续向右推没有意义, 直接返回.
                    // 不重锚: delPosX 保留"鼠标越过最小位置的量", 需拖回越过片段头才开始恢复(粘滞, 与旧公式行为一致)
                    if(mouseX > 0 && viewModel.frameOut - viewModel.frameIn < root.oneFrameToTimes){
                        return
                    }

                    /*将鼠标移动距离转化为时间片，向下取整为整帧对应的时间片*/
                    leftClipDragArea.delPosX = (globalX - leftClipDragArea.startGlobalX) - appliedPx

                    var deltaFullFrame = Math.floor(leftClipDragArea.delPosX / pxPerFrame); // 取整操作，保证裁切为整帧数
                    if(!leftClipDragArea.isScrollClipping){
                        var adjustDeltaFullFrame = container.adjustClipPosBySnapping(leftClipDragArea.delPosX, viewModel.trackFrameIn);
                        if(root.isSnapped){
                            deltaFullFrame = adjustDeltaFullFrame;
                        }
                    }
                    // 多选整组裁切: 钳制到所有选中片段都可行的帧数(锁步, 以最受限为准)
                    if(leftClipDragArea.isGroupClip){
                        deltaFullFrame = TimelineEditController.clampGroupTrimDelta(deltaFullFrame);
                    }
                    var deltaBaseTimeFrames = deltaFullFrame * oneFrameToTimes  // 单位：时间片
                    var tempFrameIn = viewModel.frameIn + deltaBaseTimeFrames
                    var tempTrackIn = viewModel.trackFrameIn + deltaBaseTimeFrames

                    // 记录本 tick 应用前的帧值, 应用后若无实际变化则跳过 seek/落库(避免边界处每 tick 重复重配 producer)
                    var prevFrameIn = viewModel.frameIn
                    var prevTrackFrameIn = viewModel.trackFrameIn

                    /*判断是否已经进入到轨道右侧滚动裁切区域, 进入滚动裁切区域时开启滚动裁切*/
                    if(trackVisibleRight - (viewModel.trackFrameIn / oneFrameToTimes * pxPerFrame + leftClipDragArea.delPosX) <= scrollClipArea){  // 鼠标进入轨道右侧滚动裁切触发区域
                        if(viewModel.trackFrameOut / oneFrameToTimes * pxPerFrame > trackVisibleRight){  // 判断片段尾部是否全部在可视区域内
                            if(!leftClipDragArea.isScrollClipping){
                                leftClipDragArea.isScrollClipping = true;
                                scrollClip(true, true, true);  // 开始滚动裁切信号
                            }
                        }
                        return;
                    }else if(tempTrackIn / oneFrameToTimes * pxPerFrame < trackVisibleLeft){  // 鼠标进入轨道左侧滚动恢复触发区域
                        if(leftEdgeArrived(tempFrameIn)){ // 片段已经恢复到头
                            if(leftClipDragArea.isScrollClipping){
                                var lastTrackFrameIn = viewModel.trackFrameIn;
                                viewModel.setTrimFrameIn(0);  // 源域归零, 时间线边缘曲线派生
                                scrollClip(false, true, false);  // 停止滚动裁切
                                var deltaX = Math.min((lastTrackFrameIn - viewModel.trackFrameIn) / oneFrameToTimes * pxPerFrame, trackVisibleLeft) + coverRectangle.width; // 保证滚动恢复停止时，片段的头部在轨道可视区域
                                flickable.scrollByX(-deltaX);
                                leftClipDragArea.isScrollClipping = false;
                            }
                        }else{ // 片段还未恢复到头
                            if(trackVisibleLeft > 0){  // 判断是否可以滚动， 轨道头不在原点，还可以继续滚动恢复
                                if(!leftClipDragArea.isScrollClipping){
                                    leftClipDragArea.isScrollClipping = true;
                                    scrollClip(true, true, false);  // 开始滚动裁切
                                }
                                return;
                            }
                        }

                    }else{  // 鼠标在非滚动裁切触发区域内，停止滚动裁切
                        if(leftClipDragArea.isScrollClipping){
                            leftClipDragArea.isScrollClipping = false;
                            scrollClip(false, true, false);
                        }
                    }

                    /*常规的非滚动裁切操作*/
                    if(viewModel.frameOut - tempFrameIn < root.oneFrameToTimes){  // case: 裁切到剩余一帧
                        if(leftClipDragArea.isScrollClipping){
                            leftClipDragArea.isScrollClipping = false;
                            scrollClip(false, true, false);
                            cursorhelper.restoreOverrideCursor();
                        }
                        viewModel.setTrimFrameIn(viewModel.frameOut - root.oneFrameToTimes)  // 源域最小一帧, 时间线边缘曲线派生
                        // 不重锚: 残差公式下一 tick 会以钳后 trackFrameIn 自动校正, 鼠标越过最小位置的量保留为粘滞
                    }
                    else if(deltaBaseTimeFrames < 0 && leftEdgeArrived(viewModel.frameIn + deltaBaseTimeFrames)){  // case: 恢复到片段头部
                        viewModel.setTrimFrameIn(0)  // 源域归零, 时间线边缘曲线派生
                        // 恢复到头后重锚起点使 delPosX 归零(保持旧行为: 反向拖动立即响应)
                        leftClipDragArea.startGlobalX = globalX - (viewModel.trackFrameIn - leftClipDragArea.startClipTrackFrameIn) / oneFrameToTimes * pxPerFrame
                        leftClipDragArea.delPosX = 0
                    }
                    else{  // 常规裁切，恢复动作，常规情况下都会执行这里的裁切逻辑进行裁切及恢复
                        container.curStartPosX -= deltaFullFrame * pxPerFrame
                        viewModel.setTrimFrameIn(viewModel.clampAndMapTrackFrameInToSource(tempTrackIn))  // 提议时间线→曲线映射源, 时间线边缘曲线派生回钩鼠标
                        if(leftClipDragArea.isScrollClipping){
                            leftClipDragArea.isScrollClipping = false;
                            scrollClip(false, true, false);
                        }
                    }
                    // 本 tick 帧值无实际变化(边界重复钳制/位移不足一帧)时直接返回,
                    // 不再重复 seek + fragmentChange(边界处 producer 反复重配是闪动源之一)
                    if(viewModel.frameIn === prevFrameIn && viewModel.trackFrameIn === prevTrackFrameIn){
                        return;
                    }
                    var appliedDeltaTime = viewModel.frameIn - prevFrameIn  // 本 tick 实际应用的帧变化(时间片)

                    // 确定seek位置
                    var seekPos = leftClipDragArea.startClipTrackFrameIn / root.oneFrameToTimes;
                    let isMustRefresh = true;
                    if(viewModel.trackFrameIn - leftClipDragArea.startClipTrackFrameIn > 0){
                        seekPos += (viewModel.trackFrameIn - leftClipDragArea.startClipTrackFrameIn) / root.oneFrameToTimes;
                        isMustRefresh = false;
                    }

                    // 根据拖动方向决定调用顺序，确保consumer始终在producer有效范围内(以实际应用的变化方向为准)
                    if(appliedDeltaTime > 0) {
                        // 往右拖 frameIn增大范围缩小 先seek到新位置 再重排
                        editorManager.clipSeek(seekPos, isMustRefresh);
                        fragmentChange(true, true, false)
                    } else {
                        // 往左拖 frameIn减小 范围扩大 先重排 再seek到新位置
                        fragmentChange(true, true, false)
                        editorManager.clipSeek(seekPos, isMustRefresh);
                    }
                    // 多选整组裁切: 将相同帧位移施加到其余选中片段(clampGroupDelta 已保证对全组可行)
                    if(leftClipDragArea.isGroupClip && deltaFullFrame !== 0){
                        TimelineEditController.applyGroupTrimToOthers(deltaFullFrame);
                    }
                }
            }
        }
        Item{
            id:rightClipDragArea
            property real lastMousePosX: 0
            property real delPosX: 0
            property bool isStartclip: false
            property bool isScrollClipping: false
            property bool isGroupClip: false  // 本次拖拽是否为多选整组裁切

            property real validWidth: clipAreaWidth
            property bool containsMouse: rightClipMouseArea.containsMouse

            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            height: parent.height
            width: validWidth


            property int maxFrameOut: -1

            Component.onCompleted: {
                root.rightframelengthLimit =  Math.max(root.rightframelengthLimit, viewModel.frameOut)
            }

            function finishDrag() {
                rightClipDragArea.delPosX = 0;
                rightClipDragArea.lastMousePosX = 0
                if(rightClipDragArea.isScrollClipping){
                    rightClipDragArea.isScrollClipping = false
                    scrollClip(false, false, false)
                }
                // nova: 裁切松手提交到 nle（源范围 + 时间线，单步 undo）；提交算法在 TrackUtil。
                if(rightClipDragArea.isGroupClip){
                    // nova: 多选整组裁切一次事务提交(单步 undo)，内部按涉及类型回读覆盖预览本地值。
                    TimelineEditController.commitGroupTrim()
                } else {
                    viewModel.commitTrim()
                    // nova: 提交后强制回读所有视频片段（含被动重排的未选中相邻片段），回正轨道头对齐/消除空隙。
                    TimelineEditController.syncVideoFromKernel()
                }
                // 裁切中关键帧图层布局被 isClipping 挡掉；松手 commitTrim 后源出点已更新，
                // 此处同步重排一次让关键帧 x 立即按新源几何归正(对齐左手柄 finishDrag)。
                // undo/redo 与 onDraftChanged 的几何变化由 panoClipVM.geometryChanged → refreshUI 覆盖。
                keyframeLayerView.refreshUI()
                rightClipDragArea.isStartclip = false
                rightClipDragArea.isGroupClip = false

                root.isCursorEnterClipArea = rightClipDragArea.containsMouse;
                if(!rightClipDragArea.containsMouse){
                    cursorhelper.restoreOverrideCursor()
                    root.isCursorEnterClipArea = false
                }
                ShortcutObserver.disableAllShortcut(false);
                root.isSnapped = false;
                multiTrackView.isPressClip = false
                // nova: 老 fragmentChange(false) 提交路径已停用，需在此显式复位 isClipping，
                // 否则其停留为 true 会使片段 MouseArea 失效，裁切后无法点击选中片段。
                multiTrackView.isClipping = false;
                // 裁切结束把播放位置收回时间指示器所指帧，否则下次播放从裁切落点开始。
                editorManager.clipSeek(trackDockViewModel.indicatorFrame);
                trackDockViewModel.indicatorFrameChanged();
                multiTrackView.adjustFlickable();
                editorManager.sendTrackEventForDragCLip(root.trackIndex, root.clipIndex, viewModel.trackFrameOut, false, "video", 3)
                rightClipDragArea.maxFrameOut = -1;
                endClip();
            }

            MouseArea{
                id: rightClipMouseArea
                hoverEnabled:true
                anchors.fill: parent
                enabled: !editorManager.isInUserGuideStatus

                Connections {
                    target: lightWindow
                    function onActiveChanged() {
                        if (!lightWindow.active && rightClipDragArea.isStartclip) {
                            rightClipDragArea.finishDrag();
                        }
                    }
                }

                onWidthChanged: {
                    logger.d("[VideoItemView] rightClipDragArea.width = " + rightClipDragArea.width);
                }
                onEntered: {
                    logger.d("[VideoItemView] rightClipDragArea::onEntered rightClipDragArea.width = " + rightClipDragArea.width
                            + ", rightClipDragArea.x = " + rightClipDragArea.x + ", rightClipDragArea.y = " + rightClipDragArea.y + ", isStartclip = " + rightClipDragArea.isStartclip);
                    if(!rightClipDragArea.isStartclip){
                        if(leftClipDragArea.containsMouse){
                            cursorhelper.restoreOverrideCursor()
                        }
                        cursorhelper.setCustomCursor(":/icons/ic_cutright.svg", 24, 24)
                        multiTrackView.isEnterClip = true
                    }
                    root.isCursorEnterClipArea = true
                }

                onExited: {
                    logger.d("[VideoItemView] rightClipDragArea::onExited rightClipDragArea.width = " + rightClipDragArea.width
                            + ", rightClipDragArea.x = " + rightClipDragArea.x + ", rightClipDragArea.y = " + rightClipDragArea.y + ", isStartclip = " + rightClipDragArea.isStartclip);
                    if(!rightClipDragArea.isStartclip){
                        cursorhelper.restoreOverrideCursor()
                        multiTrackView.isEnterClip = false
                        root.isCursorEnterClipArea = false
                    }
                }

                onPressed: {
                    // 未选中片段边缘按下：先独占选中再进入裁切，selectedClipCount 随之归 1，不会误开整组裁切
                    if (!root.selected) {
                        root.itemClicked(false);
                    }
                    rightClipDragArea.lastMousePosX = mouseX; // 初始化位置
                    rightClipDragArea.isStartclip = true;
                    rightClipDragArea.isGroupClip = TimelineEditController.selectedClipCount() > 1;  // 多选则整组裁切
                    if(rightClipDragArea.isGroupClip){
                        TimelineEditController.beginGroupTrim(viewModel.clipNodeId, false);
                    }
                    startClip();
                    ShortcutObserver.disableAllShortcut(true);
                    multiTrackView.isPressClip = true
                }

                onReleased: {
                    rightClipDragArea.finishDrag();
                }

                onCanceled: {
                    rightClipDragArea.finishDrag();
                }

                onPositionChanged: {
                    if(!rightClipDragArea.isStartclip)
                        return
                    if (rightClipDragArea.maxFrameOut < 0) {
                        rightClipDragArea.maxFrameOut = viewModel.originLength;
                    }

                    root.isMouseMoved = true;
                    /*将鼠标移动距离转化为时间片，向下取整为整帧对应的时间片*/
                    rightClipDragArea.delPosX = mouseX - rightClipDragArea.lastMousePosX + rightClipDragArea.delPosX;
                    var deltaFullFrame = Math.ceil(rightClipDragArea.delPosX / pxPerFrame); // // 这里需要保证裁切的是一整帧
                    rightClipDragArea.lastMousePosX = mouseX;

                    if(!rightClipDragArea.isScrollClipping){
                        var adjustDeltaFullFrame = container.adjustClipPosBySnapping(rightClipDragArea.delPosX, viewModel.trackFrameOut);
                        if(root.isSnapped){
                            deltaFullFrame = adjustDeltaFullFrame;
                        }
                    }
                    // 多选整组裁切: 钳制到所有选中片段都可行的帧数(锁步, 以最受限为准)
                    if(rightClipDragArea.isGroupClip){
                        deltaFullFrame = TimelineEditController.clampGroupTrimDelta(deltaFullFrame);
                    }

                    var deltaBaseTimeFrames = deltaFullFrame * oneFrameToTimes // 单位：时间片
                    var tempTrackFrameOut = viewModel.trackFrameOut + deltaBaseTimeFrames;
                    // 变速感知：Timeline 域提议 → VM 映射回 Source frameOut（曲线/匀速统一）
                    var tempFrameOut = viewModel.clampAndMapTrackFrameOutToSource(tempTrackFrameOut);


                    if(deltaFullFrame > 0){ // 尾部恢复方向
                        if(viewModel.frameOut >= rightClipDragArea.maxFrameOut){ // 尾部恢复已经到头
                            return;
                        }
                    }

                    /*判断是否已经进入到轨道右侧滚动裁切区域, 进入滚动裁切区域时开启滚动裁切*/
                    if((viewModel.trackFrameOut / oneFrameToTimes * pxPerFrame + rightClipDragArea.delPosX) - trackVisibleLeft <= scrollClipArea){  // 鼠标进入轨道左侧滚动裁切触发区域
                        if(viewModel.trackFrameIn / oneFrameToTimes * pxPerFrame < trackVisibleLeft){  // 判断的当前片段头部是否全部在可视区域内
                            if(!rightClipDragArea.isScrollClipping){
                                rightClipDragArea.isScrollClipping = true;
                                scrollClip(true, false, false);
                            }
                            return;
                        }
                    }else if(tempTrackFrameOut / oneFrameToTimes * pxPerFrame >= trackVisibleRight){  // 鼠标进入轨道右侧滚动恢复触发区域
                        if(!rightClipDragArea.isScrollClipping && viewModel.length < rightClipDragArea.maxFrameOut){
                            rightClipDragArea.isScrollClipping = true;
                            scrollClip(true, false, true);
                        }
                        return;
                    }else if(rightClipDragArea.isScrollClipping){
                        rightClipDragArea.isScrollClipping = false;
                        scrollClip(false, false, false);
                    }

                    /*常规的非滚动裁切操作*/
                    if((tempFrameOut - viewModel.frameIn) < oneFrameToTimes){  // case : 裁切到一帧
                        viewModel.setTrimFrameOut(viewModel.frameIn + oneFrameToTimes)
                    }
                    else if(tempFrameOut > rightClipDragArea.maxFrameOut){ // case: 右侧恢复到头
                        viewModel.setTrimFrameOut(rightClipDragArea.maxFrameOut);
                    }
                    else{ // 常规情况：写 VM 映射后的 Source frameOut, 时间线边缘曲线派生回钩鼠标
                        viewModel.setTrimFrameOut(tempFrameOut)
                        // 当右侧的visibleright未变化，导致关键帧未绘制
                        // 先向左滚动裁剪，再向右恢复
                        if (deltaBaseTimeFrames >= 0) {
                            keyframeLayerView.refreshUI();
                        }
                    }

                    fragmentChange(false, true, false);
                    //TODO
                    //这个clipseek需要做大的改造才能彻底矫正帧对不齐的问题
                    //本期先还原
                    editorManager.clipSeek(Math.floor((viewModel.trackFrameOut) / oneFrameToTimes));
                    globalSignal.previewFrame(Math.floor((viewModel.trackFrameOut) / oneFrameToTimes));
                    // 多选整组裁切: 将相同帧位移施加到其余选中片段
                    if(rightClipDragArea.isGroupClip && deltaFullFrame !== 0){
                        TimelineEditController.applyGroupTrimToOthers(deltaFullFrame);
                    }
                }
            }
        }

        SuperSlowItemView{
            id: superSlowItemView
            clipIndex: root.clipIndex
            trackIndex: root.trackIndex
            visibleLeft: root.visibleLeft
            visibleRight: root.visibleRight
            anchors{
                top: parent.top
                topMargin: 2
            }
            z: 1
            viewModel: root.viewModel

            onVisibleChanged: {
                if(visible){
                    keyframeLayerView.clearClipUiSelected();  // 显示超慢设置条是, TK, 区域关键帧，运镜模版片段显示为非选中态
                    superSlowLineTemp.visible = false;
                }
            }

            onEnableSuperSlowChanged: {
                if(superSlowItemView.visible && !superSlowItemView.enableSuperSlow){
                    superSlowItemView.visible = false;
                }

                superSlowLineClip.visible = superSlowItemView.enableSuperSlow
                superSlowLineTemp.visible = superSlowItemView.enableSuperSlow
            }

            Connections {
                target: root

                function onEndClip(){
                    superSlowItemView.changeClipRange()
                }
            }

            Connections {
                target: globalSignal
                function  onKeyframeSegmentClicked() {
                    superSlowItemView.visible = false;
                }
            }

            Component.onCompleted: {
                // 主要用于首次创建ItemView时是否直接展示(主要是针对分割场景，如果分割的位置在超慢设置片段中，则分割后的第二个片段需要展示超慢设置item)
                superSlowItemView.visible = (selected && superSlowItemView.enableSuperSlow)
                superSlowLineClip.visible = superSlowItemView.enableSuperSlow
                superSlowLineTemp.visible = superSlowItemView.enableSuperSlow
            }
        }

        // 超慢常驻线条
        Item {
            id: superSlowLineClip
            z: 1
            anchors.fill: parent
            visible: false
            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: superSlowLineClip.width
                    height: superSlowLineClip.height
                    radius: container.radius
                }
            }
            Rectangle {
                id: superSlowLine
                anchors.top: parent.top
                x: superSlowItemView.x
                color: Colors.color_009DFF
                height: 2
                width: superSlowItemView.width
                radius: 1
            }
        }

        function adjustClipPosBySnapping(deltaX, targetPos){
            var deltaFullFrame = 0
            let isSnappedSuc = false;
            let tempPos = targetPos + deltaX / pxPerFrame * oneFrameToTimes;
            getSnappingPosSig(tempPos);

            if(root.snappingPos !== -1){
                deltaFullFrame = Math.floor((root.snappingPos - targetPos) / oneFrameToTimes);
                isSnappedSuc = true;
            }
            root.isSnapped = isSnappedSuc;
            return deltaFullFrame;
        }

        Loader {
            id: titleLoader

            anchors.top: parent.top
            width: parent.width
            height: 20
            sourceComponent: titleInfo
        }

        Rectangle {
            id: audioWave

            property bool needRefresh: false
            property real msPerFragment: 1
            property real trackLength: 1000
            property double pxPerFragment: Instance.audio_wave_track_length
            property int countForFragment: 0

            anchors {
                bottom: parent.bottom
            }
            width: parent.width
            height: 16

            color: Colors.color_transparent
            radius: fragment.rectRadius

            Rectangle {
                anchors.fill: parent
                color: Colors.color_transparent
                clip: true

                // 音频波形
                AudioWavePaint {
                    id: audioWavePaint
                    anchors {
                        top: parent.top
                        bottom: parent.bottom
                    }
                    width: root.visibleRight - root.visibleLeft
                    visibility: !container.sourceLost && fragment.audioVisibility
                    visible: !container.sourceLost
                    isAudio: false
                    layer.enabled: true

                    paintWidth: root.width - x - itemGap
                    audioPath: viewModel.path
                    x: root.visibleLeft - viewModel.stripOriginMk / oneFrameToTimes * pxPerFrame
                    compositeProperty: {
                        "visibleLeft": root.visibleLeft - viewModel.stripOriginMk / oneFrameToTimes * pxPerFrame,
                        "visibleLength": root.visibleRight - root.visibleLeft,
                        "pxPerFrame": root.pxPerFrame,
                        "outputFps": root.outputFps,
                        "fragmentLength": viewModel.length,
                        "stripOriginMk": viewModel.stripOriginMk,
                        "speed": root.speed,
                        "fragmentInfo": viewModel
                    }
                }
            }

            Item {
                // 语音高光标记
                Repeater {

                    model : viewModel.audioHighlightModel
                    delegate: AudioHighlightItemView {

                        required property double rectXPos
                        required property double rectWidth
                        required property double rectType

                        xPos : rectXPos * pxPerFrame / oneFrameToTimes
                        nWidth: rectWidth * pxPerFrame / oneFrameToTimes
                        type: rectType

                        onHighlightItemClicked: {
                            var absoluteFrame = Math.floor((viewModel.trackFrameIn + rectXPos) / oneFrameToTimes)
                            editorManager.pause()
                            editorManager.seek(absoluteFrame)
                        }
                    }
                }
                Component.onCompleted: {
                    // 语音高光模型由 nle VM 持有；created() 为有意空实现(数据请求由 AudioHighlightTaskManager 经 MessageBus 草稿变化统一驱动，遍历 nle clip VM)。
                    if (!CommonUtils.isNull(viewModel.audioHighlightModel)) {
                        viewModel.audioHighlightModel.created()
                    }
                }
            }
        }

        Item {
            id: trackFrame
            width: parent.width + root.visibleLeft
            height: 32
            x: -viewModel.stripOriginMk / oneFrameToTimes * pxPerFrame
            anchors {
                top: titleLoader.bottom
                bottom: audioWave.top
            }

            // 展示缩略图
            ListView{
                id:  thumbnailList
                width: parent.width
                height: parent.height
                interactive: false
                anchors{
                    top: parent.top
                    left: parent.left
                    leftMargin: Math.floor(root.visibleLeft / fragment.frameSize.width) * fragment.frameSize.width
                }

                orientation: ListView.Horizontal
                focus: true
                model:ThumbnailListModel{
                    id: thumbnailListModel
                    videoPath: root.mediaPath
                    videoMd5: root.mediaMd5
                    frameSize: fragment.frameSize.width
                    compositeProperty: {
                        "displayIndexOffset": Math.floor(root.visibleLeft / fragment.frameSize.width),
                        "pxPerFrame": root.pxPerFrame,
                        "itemCount": (root.visibleRight - root.visibleLeft) / fragment.frameSize.width + 2,
                        "speed": root.speed,
                        "oneFrameTime": root.oneFrameToTimes,
                        "fragmentLength": viewModel.length,
                        "speedCurveString": root.speedCurveString,
                        "speedType": root.speedType,
                        "fragmentInfo": viewModel
                    }
                }
                delegate:Item{
                    width: fragment.frameSize.width
                    height: fragment.frameSize.height
                    MediaFrameImageLoader {
                        anchors.fill: parent
                        requestSource: (model !== null && model.path !== undefined) ? model.path : ""
                        cacheSource: (model !== null && model.cache !== undefined) ? model.cache : ""
                    }
                }

                Component.onCompleted: {
                    thumbnailListModel.listViewCompleted = true;
                }
            }
        }

        Rectangle {
            id: lostAgency16KTimelapseUI
            anchors {
                top: trackFrame.top
                bottom: trackFrame.bottom
                left: parent.left
                right: parent.right
            }
            color: ColorsConfig.color_1F2021_000000
            visible: container.agency16KTimelapseLost

            property bool isCameraFile: viewModel.isFromRemovable();
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
                    color: ColorsConfig.color_68696D_4DFFC920
                    // 这里不要翻译
                    text: lostAgency16KTimelapseUI.isCameraFile ? "相机代理文件丢失" : "媒体代理文件丢失"
                }

                Text {
                    anchors {
                        left: parent.left
                        right: parent.right
                    }
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: 10
                    color: ColorsConfig.color_68696D_4DFFC920
                    // 这里不要翻译
                    text: "No Proxy File"
                }
            }

            onVisibleChanged: {
                if (visible) {
                    // 手动更新一下，因为没写信号
                    isCameraFile = viewModel.isFromRemovable();
                }
            }
        }

        Rectangle {
            id: lostUI
            anchors {
                top: trackFrame.top
                bottom: trackFrame.bottom
                left: parent.left
                right: parent.right
            }
            color: ColorsConfig.color_492C2D_15473C
            visible: container.mediaLost

            property bool isCameraFile: viewModel.isFromRemovable();
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
                    text: lostUI.isCameraFile ? "相机文件丢失" : "媒体丢失"
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
                    text: lostUI.isCameraFile ? "Camera Files Not Found" : "Media Not Found"
                }
            }

            onVisibleChanged: {
                if (visible) {
                    // 手动更新一下，因为没写信号
                    isCameraFile = viewModel.isFromRemovable();
                }
            }
        }


        KeyframeLayerView {
            id: keyframeLayerView

            parent: root.parent

            // 这里使用 root.x + itemGap / 2 会导致偏
            x: root.x
            y: root.y
            width: root.width - itemGap
            height: root.height  // 覆盖整个高度，包括音频波形区域

            z: root.selected ? (root.z + zIndexTransition + 1) : (root.z + zIndexTransition - 1)
            clip: true

            trackIndex: root.trackIndex
            clipIndex: root.clipIndex
            pxPerFrame: root.pxPerFrame
            visibleRect: Qt.rect(root.visibleLeft, 0, root.visibleRight, height);
            visible: !container.sourceLost

            function clearClipUiSelected() {
                // 获取所有符合条件的 KeyFrameItemView 对象
                var keyFrameItems = findChildrenByObjectName("keyFrameDelegate");
                // 遍历所有对象并调用函数
                for (var i = 0; i < keyFrameItems.length; i++) {
                    var keyFrameItem = keyFrameItems[i];
                    if (keyFrameItem && keyFrameItem.clearClipUiSelected) {
                        keyFrameItem.clearClipUiSelected();
                    }
                }
            }

            function findChildrenByObjectName(name) {
                var result = [];
                for (var i = 0; i < children.length; i++) {
                    var child = children[i];
                    if (child.objectName === name) {
                        if (child.isTrackingFragment && child.isTrackingFragment()) {
                            result.push(child);
                        }
                    }
                }
                return result;
            }

            // 单个关键帧
            keyFrameDelegate: KeyFrameItemView {
                objectName: "keyFrameDelegate"
                trackIndex: root.trackIndex
                clipIndex: root.clipIndex
                keyframeInfo: modelData
                videoItemSelected: root.selected
                viewModel: root.viewModel   // nova TimelineVideoClipViewModel：提供 frameIn/trackFrameIn 等几何
                indicator_frame: root.indicatorFrame
                pxPerFrame: root.pxPerFrame
                trackVisibleLeft: root.visibleLeft
                trackVisibleRight: root.visibleRight
                parentX: root.x
                parentWidth: root.width
                regionKfSupport: !CommonUtils.isNull(viewModel) && viewModel.hasFragment && PanoramaConfig.regionKeyframeSupport(viewModel.panoramaViewingMode)
                // 关键帧点击回调
                onKeyframeClick: {
                    root.itemClicked(false);
                }

                onKeyframeRightClick: (selected, windowPointX, windowPointY) => {
                    if(selected === true) {
                        let cancopy = keyframeBtnViewModel.copyOneSelectedKeyframe(false);
                        if(cancopy === true) {
                            let tocopy = true;
                            let topaste = keyframeBtnViewModel.pasteOneSelectedKeyframe(false);
                            root.openOperatorPop_Keyframe(windowPointX, windowPointY, tocopy, topaste);
                        }
                    } else {
                        let isMediaLost = container.mediaLost;
                        let isSelectFile = (multiTrackDataProvider.getSelectedCount() > 0);
                        let topaste = keyframeBtnViewModel.pasteOneSelectedKeyframe(false);
                        root.openOperatorPop(windowPointX, windowPointY, isMediaLost, isSelectFile, topaste);
                    }
                }

                // 关键帧拖拽回调
                onKeyframeDrag: (keyframe, newX, originPositon, end) => {
                    keyframeLayerView.dragKeyFrame(keyframe, newX, originPositon, end)
                }
            }

            Connections {
                target: globalSignal

                // 关键帧位置移动(多处 emit，活 handler)；区域/运镜/关键帧增删的旧 globalSignal 通知已由
                // panoClipVM.changed()→rebuildPanoKeyframes/Regions/Tracking/Movements 接管，旧 handler 已移除。
                function onKeyframePositionRefreshed() {
                    keyFrameChange();
                }

                // [NOVA] tk 过程中绕开逐帧 commit 的性能开销：C++ 发全局信号携带 clip NodeID + 组源区间，
                // 命中本片段（viewModel.clipNodeId）时直接 updateKeyFrame 让 tk 片段右缘跟随播放头增长。
                function onNovaTkSegmentGrowing(clipNodeIdB64, startPos, endPos) {
                    if (!CommonUtils.isNull(viewModel) && viewModel.clipNodeId === clipNodeIdB64) {
                        keyframeLayerView.updateKeyFrame(root.trackIndex, root.clipIndex, startPos, endPos);
                    }
                }

                // tk 建组时记下本片段正在生成的活动组 id（供 rebuildPanoTracking 判满高，变速重建后仍有效）。
                function onNovaTkGroupCreated(clipNodeIdB64, groupNodeIdB64) {
                    if (!CommonUtils.isNull(viewModel) && viewModel.clipNodeId === clipNodeIdB64) {
                        root._liveTkGroupId = groupNodeIdB64;
                    }
                }

                // 关键帧图层被 recreateLayer 清空后全量重建（散点/区域/运镜/追踪四类共用 _keyframeList）：
                // 清层后 pinToNode 同 id 不 reload、四类源位置不变也不 emit changed，故须主动重读草稿并全量重建四类，
                // 否则被清的 delegate 不复位（需重开草稿才恢复）。触发来源：变速、视角模式切换。
                function onRefreshPanoramaKeyframeUi(track, clip) {
                    if (track !== root.trackIndex || clip !== root.clipIndex) {
                        return;
                    }
                    root._panoKfFullRebuild = true;
                    root._panoRegionFullRebuild = true;
                    root._panoMovementFullRebuild = true;
                    root._panoTkFullRebuild = true;
                    panoClipVM.reloadNow();
                    root.rebuildPanoKeyframes();
                    root.rebuildPanoRegions();
                    root.rebuildPanoMovements();
                    root.rebuildPanoTracking();
                }
                
                function onUpdateMovementSegmentClip(itemData, pressedClipStart, pressedClipEnd, isFinished) {
                    keyframeLayerView.updateMovementSegmentClip(itemData, pressedClipStart, pressedClipEnd, isFinished);
                    movementClipChange();
                }

                function onUpdateTrackingSegmentClip(itemArgument, oldClipStart, oldClipEnd, isUndo) {
                    keyframeLayerView.updateTrackingSegmentClip(itemArgument, oldClipStart, oldClipEnd, isUndo);
                }

                function onTrackingSegmentRemoveAction(cancelTracking, isTkEndEqualStart) {
                    if (!root.selected) {
                        logger.d("[TK] VideoItemView::onTrackingSegmentRemoveAction() 片段没有选中")
                        return
                    }

                    if (!viewModel || !viewModel.hasFragment) {
                        if (!cancelTracking) {
                            globalSignal.removeTrackingFragmentFail()
                        }
                        return
                    }
                    var indicatePosition = editorManager.positionForFrame(root.indicatorFrame)
                    keyframeLayerView.trackingSegmentRemove(root.trackIndex, root.clipIndex, indicatePosition - viewModel.trackFrameIn + viewModel.frameIn, cancelTracking, isTkEndEqualStart);
                    trackingChange();
                }
            }

            Connections {
                target: keyframeLayerView
                function onWidthChanged() {
                    if(!isClipping){
                        keyframeLayerView.refreshUI();  // 使用按钮进行裁切后需要刷新关键帧图层
                    }
                }
            }

            Component.onCompleted: {
                keyframeLayerView.setTrackClip(root.trackIndex, root.clipIndex);
            }
        }

        // 根据最外层矩形圆角，遮住内部小矩形超出部分
        Rectangle {
            anchors.centerIn: parent
            width: parent.width + border.width * 2
            height: parent.height + border.width * 2
            color: Colors.transparent
            radius: parent.radius + border.width //外圆角=内圆角+border.width
            border.color: Colors.color_content_area_background
            border.width: parent.radius / 2
            z: 10
        }

        Connections {
            target: null  // NOVATODO 关键帧未接入 nle，VM 无 pathChanged 信号，置空降级

            function onPathChanged() {
                // 刷新关键帧UI
                keyframeLayerView.refreshUI();
            }
        }

        Connections {
            target: globalSignal
            // tk 生成结束(TK_EXIT)：清活动组 id 并收起本片段的活动段(isGenerated=true)。
            // 主动重建以免变速收尾(restore→recreateLayer)重建时序落在清除之前而使段卡在满高态。
            function onTrackingStateChanged(status) {
                if (status === TrackingManager.TK_EXIT && root._liveTkGroupId !== "") {
                    root._liveTkGroupId = "";
                    root._panoTkFullRebuild = true;
                    panoClipVM.reloadNow();
                    rebuildPanoTracking();
                }
            }
            function  onKeyframeSelect(keyframeItemData) {
                if (CommonUtils.isNull(keyframeItemData)) {
                    return;
                }
                // 运镜模版的片段不需要做此特殊处理来解决与片段裁切层级的冲突，理论上TK也不需要做次特殊逻辑，后续需要排查一下TK是否还需要保留此逻辑
                if (keyframeItemData.dataType == KeyframeItemData.Keyframe || keyframeItemData.dataType === KeyframeItemData.CameraMove) {
                    return;
                }

                const select = keyframeItemData.select

                if (keyframeItemData.track === root.trackIndex && keyframeItemData.clip === root.clipIndex
                        && (select || (leftClipDragArea.selectTkFragment !== null
                        && keyframeItemData.segmentId === leftClipDragArea.selectTkFragment.segmentId))) {
                    leftClipDragArea.select = select

                    if (select) {
                        leftClipDragArea.selectTkFragment = keyframeItemData

                        if (viewModel.frameIn > keyframeItemData.speedClipStart) {
                            leftClipDragArea.validWidth = clipAreaWidth
                        } else {
                            leftClipDragArea.validWidth = Math.min(editorManager.frameByPosition(keyframeItemData.speedClipStart - viewModel.frameIn) * pxPerFrame, clipAreaWidth)
                        }

                        if (viewModel.frameOut < keyframeItemData.speedClipEnd) {
                            rightClipDragArea.validWidth =  clipAreaWidth
                        } else {
                            rightClipDragArea.validWidth = Math.min(editorManager.frameByPosition(viewModel.frameOut - keyframeItemData.speedClipEnd) * pxPerFrame, clipAreaWidth)
                        }
                    } else {
                        leftClipDragArea.selectTkFragment = null

                        leftClipDragArea.validWidth = clipAreaWidth
                        rightClipDragArea.validWidth = clipAreaWidth
                    }
                }
            }

            function onUpdateTrackingFragmentData(keyframeItemData, isRelease) {
                if (keyframeItemData === null) {
                    return
                }

                if (keyframeItemData.track === root.trackIndex
                        && keyframeItemData.clip === root.clipIndex
                        && leftClipDragArea.selectTkFragment !== null
                        && keyframeItemData.start === leftClipDragArea.selectTkFragment.start
                        && keyframeItemData.end === leftClipDragArea.selectTkFragment.end
                        && leftClipDragArea.select) {

                    if (viewModel.frameIn > keyframeItemData.speedClipStart) {
                        leftClipDragArea.validWidth = clipAreaWidth
                    } else {
                        leftClipDragArea.validWidth = Math.min(editorManager.frameByPosition(keyframeItemData.speedClipStart - viewModel.frameIn) * pxPerFrame, clipAreaWidth)
                        logger.d("[VideoItemView] onUpdateTrackingFragmentData: leftClipDragArea.validWidth =  " + leftClipDragArea.validWidth + ", keyframeItemData.speedClipStart = " +
                                keyframeItemData.speedClipStart + ", viewModel.frameIn = " + viewModel.frameIn + ", pxPerFrame = " + pxPerFrame + ", clipAreaWidth = " + clipAreaWidth);
                    }


                    if (viewModel.frameOut < keyframeItemData.speedClipEnd) {
                        rightClipDragArea.validWidth =  clipAreaWidth
                    } else {
                        rightClipDragArea.validWidth = Math.min(editorManager.frameByPosition(viewModel.frameOut - keyframeItemData.speedClipEnd) * pxPerFrame, clipAreaWidth)
                        logger.d("[VideoItemView] onUpdateTrackingFragmentData: rightClipDragArea.validWidth =  " + rightClipDragArea.validWidth + ", viewModel.frameOut = " +
                                viewModel.frameOut + ", keyframeItemData.speedClipEnd = " + keyframeItemData.speedClipEnd + ", pxPerFrame = " + pxPerFrame + ", clipAreaWidth = " + clipAreaWidth);
                    }
                }
            }

            function onTrackingSegmentRemove(keyframeItemData) {
                if (keyframeItemData === null) {
                    return
                }

                if (keyframeItemData.track === root.trackIndex
                        && keyframeItemData.clip === root.clipIndex
                        && leftClipDragArea.selectTkFragment !== null
                        && keyframeItemData.start === leftClipDragArea.selectTkFragment.start
                        && keyframeItemData.end === leftClipDragArea.selectTkFragment.end) {

                    leftClipDragArea.validWidth = clipAreaWidth
                    rightClipDragArea.validWidth =  clipAreaWidth
                }
            }
        }
    }

    function getMediaIcon() {
        if (CommonUtils.isNull(viewModel) || !viewModel.hasFragment) {
            return ""
        }
        let mediaIconPath = fileOperator.getMediaIconByMediaType(viewModel.path)
        if(!(typeof mediaIconPath === "string") || mediaIconPath.length === 0) {
            return "";
        }

        let lastSlashIndex = mediaIconPath.lastIndexOf('/')
        let prePath = mediaIconPath.substring(0, lastSlashIndex + 1)
        let fileName = mediaIconPath.substring(lastSlashIndex + 1)
        fileName = "fragment_" + fileName
        return prePath + fileName
    }

    function getMediaIconOriginal() {
        if (CommonUtils.isNull(viewModel) || !viewModel.hasFragment) {
            return ""
        }
        let mediaIconPath = fileOperator.getMediaIconByMediaType(viewModel.path);
        return mediaIconPath;
    }

    Component {
        id: titleInfo
        Item {
            id: titleInfoRoot
            visible: showInfoTitle

            // 修复：QML Rectangle: Binding loop detected for property "visible"
            // 修复 visible 绑定环：visible→rightMargin→宽度回流→重发 implicitWidth→回写 contentOverflow→visible。
            // 用 Qt.callLater 把测量推迟到绑定求值之外(并合并多次调用)，配合 bool 缓存仅按值变化通知，打断该环。
            property bool contentOverflow: false
            function updateContentOverflow() {
                Qt.callLater(applyContentOverflow);
            }
            function applyContentOverflow() {
                contentOverflow = titleInfoRoot.width < titleInfoRow.implicitWidth;
            }
            onWidthChanged: updateContentOverflow()
            Component.onCompleted: updateContentOverflow()
            Item {
                anchors.fill: parent
                anchors.rightMargin: moreButton.visible ? 20 : 4
                clip: true
                RowLayout {
                    id:titleInfoRow
                    anchors {
                        fill: parent
                        leftMargin: 4
                    }

                    spacing: 3
                    // 修复：QML Rectangle: Binding loop detected for property "visible"
                    onImplicitWidthChanged: titleInfoRoot.updateContentOverflow()
                    // 全景片段图标
                    Image {
                        visible: CommonUtils.isNull(viewModel) || !viewModel.hasFragment || !container.mediaLost
                        Layout.preferredWidth: 14
                        Layout.preferredHeight: 14
                        Layout.alignment: Qt.AlignVCenter
                        source: container.agency16KTimelapseLost ? getMediaIconOriginal() : getMediaIcon()
                    }

                    // 开启代理
                    IconTextButton {
                        visible: CommonUtils.isNull(viewModel) || !viewModel.hasFragment ? false : (viewModel.isEnableAgency || viewModel.is16KTimelapse)
                        Layout.alignment: Qt.AlignVCenter
                        leftPadding: 4
                        rightPadding: 4
                        isTextOnly: true
                        backgroundColorNormal: Colors.transparent
                        title: qsTr("pccut_project_modify_proxy")
                        titleColor: container.sourceLost ? ColorsConfig.color_EEEEEE_000000 : ColorsConfig.color_78A7EC_78E5DE
                        titleFontSize: 10
                        alignment: Qt.AlignHCenter
                        enabled:false
                    }

                    // 视角
                    IconTextButton {
                        visible: CommonUtils.isNull(viewModel) || !viewModel.hasFragment || container.sourceLost ? false :
                                 (viewModel.shotViewSupport || viewModel.freeViewSupport || viewModel.fixViewSupport ||
                                  viewModel.selfieViewSupport || viewModel.forwardViewSupport || viewModel.frontShotViewSupport)
                        Layout.preferredHeight: 14
                        Layout.alignment: Qt.AlignVCenter
                        leftPadding: 4
                        rightPadding: viewingModeTagFocus && viewModeChooseDisplayed && root.isUseStabilize? 16 : 4
                        radius: RadiusConfig.radius_2_88
                        isTextOnly: true
                        backgroundColorNormal: {
                            if(container.mediaLost) {
                                return ColorsConfig.color_brand;
                            } else if(container.agency16KTimelapseLost) {
                                return ColorsConfig.color_454649_transparent;
                            }
                            return ColorsConfig.color_1C4B91_0E7E7E;
                        }
                        backgroundColorHover: {
                            if(container.mediaLost) {
                                return ColorsConfig.color_brand;
                            } else if(container.agency16KTimelapseLost) {
                                return ColorsConfig.color_454649_transparent;
                            }
                            return ColorsConfig.color_2460B9_15A4A4;
                        }
                        backgroundColorPressed: {
                            if(container.mediaLost) {
                                return ColorsConfig.color_brand;
                            } else if(container.agency16KTimelapseLost) {
                                return ColorsConfig.color_454649_transparent;
                            }
                            return ColorsConfig.color_0C213F_154747;
                        }
                        hoveredCursor: Qt.PointingHandCursor

                        title: CommonUtils.isNull(viewModel) || !viewModel.hasFragment ? "" : viewModel.panoramaViewingModeName
                        titleColor: container.sourceLost ? ColorsConfig.color_EEEEEE_000000 : ColorsConfig.color_C4D8F7_CDFFF0
                        titleFontSize: 10
                        alignment: Qt.AlignHCenter
                        focus: viewingModeTagFocus
                        enabled: !container.sourceLost
                        hoverEnabled: true
                        onCustomClicked: {
                            if (!focus) {
                                clickTabType(SettingPanelViewModel.SETTINGPANELTABTYPE_PANORAMA);
                            }
                            else if(viewModeChooseDisplayed && root.isUseStabilize){
                                playerPanel.controller.pause();
                                var rect = UiUtils.getGlobalPosition(this);
                                panoramaViewingModeAlert.refreshMaxHeight();
                                var contentRectangleY = rect.y + height / 2;
                                if (windowSizeManager.getCurrentGeometry().height < panoramaViewingModeAlert.maxHeight / 2 + 12 + contentRectangleY) {
                                    contentRectangleY -= 10 + stackLayout.anchors.bottomMargin;
                                }
                                var buttonRightEdge = rect.x + width + 4;
                                var parentRightEdge = UiUtils.getGlobalPosition(parent).x + parent.width + 4;
                                panoramaViewingModeAlert.contentRectangleX = buttonRightEdge > parentRightEdge ? parentRightEdge : buttonRightEdge;
                                panoramaViewingModeAlert.contentRectangleY = contentRectangleY;
                                panoramaViewingModeAlert.open();
                            }
                        }
                        Image {
                            anchors {
                                top: parent.top
                                right: parent.right
                                bottom: parent.bottom
                            }
                            visible: viewingModeTagFocus && viewModeChooseDisplayed && root.isUseStabilize && !container.sourceLost
                            source: panoramaViewingModeAlert.visible ? "qrc:/app_qrc/icons/icon_regspeed_more_up.svg":"qrc:/app_qrc/icons/icon_regspeed_more_down.svg"
                            sourceSize: Qt.size(14,14)
                        }
                        LightToolTip {
                            visible: !container.sourceLost && parent.hovered
                            tip: qsTr("pccut_image_view_position_tip")
                        }
                    }

                    //  超级慢动作
                    IconTextButton {
                        id: superSlowIcon
                        visible: superSlowItemView.enableSuperSlow
                        Layout.preferredHeight: 14
                        Layout.alignment: Qt.AlignVCenter
                        leftPadding: 6
                        rightPadding: 4
                        radius: RadiusConfig.radius_2_88
                        isTextOnly: true
                        backgroundColorNormal: {
                            if(container.mediaLost) {
                                return ColorsConfig.color_brand;
                            } else if(container.agency16KTimelapseLost) {
                                return ColorsConfig.color_454649_transparent;
                            }
                            return ColorsConfig.color_1C4B91_0E7E7E;
                        }
                        backgroundColorHover: {
                            if(container.mediaLost) {
                                return ColorsConfig.color_brand;
                            } else if(container.agency16KTimelapseLost) {
                                return ColorsConfig.color_454649_transparent;
                            }
                            return ColorsConfig.color_2460B9_15A4A4;
                        }
                        backgroundColorPressed: {
                            if(container.mediaLost) {
                                return ColorsConfig.color_brand;
                            } else if(container.agency16KTimelapseLost) {
                                return ColorsConfig.color_454649_transparent;
                            }
                            return ColorsConfig.color_0C213F_154747;
                        }
                        // backgroundColorNormal: container.mediaLost ? ColorsConfig.color_brand : ColorsConfig.color_1C4B91_0E7E7E
                        // backgroundColorHover: container.mediaLost ? ColorsConfig.color_brand : ColorsConfig.color_2460B9_15A4A4
                        // backgroundColorPressed:  container.mediaLost ? ColorsConfig.color_brand : ColorsConfig.color_0C213F_154747
                        hoveredCursor: Qt.PointingHandCursor

                        title:  qsTr("pccut_superslow_btn") + " " + qsTr(superSlowItemView.tagString)
                        titleColor: container.sourceLost ? ColorsConfig.color_EEEEEE_000000 : ColorsConfig.color_C4D8F7_CDFFF0
                        titleFontSize: 10
                        alignment: Qt.AlignHCenter
                        focus: superSlowTagFocus
                        enabled: !container.sourceLost
                        hoverEnabled: true

                        onCustomClicked: {
                            // superSlowItemView.visible = true;
                            if (!focus) {
                                clickTabType(SettingPanelViewModel.SETTINGPANELTABTYPE_SUPER_SLOW);
                            }
                            superSlowItemView.visible = true;
                        }
                        LightToolTip {
                            visible: !container.sourceLost && parent.hovered
                            tip: superSlowIcon.title
                        }
                    }
                    // 色彩还原
                    IconTextButton {
                        visible: clipFilterBadgeVM.isEnableLut && clipFilterBadgeVM.lutName.length !== 0
                        Layout.preferredHeight: 14
                        Layout.alignment: Qt.AlignVCenter
                        leftPadding: 4
                        rightPadding: 4
                        radius: RadiusConfig.radius_2_88
                        isTextOnly: true
                        backgroundColorNormal: {
                            if(container.mediaLost) {
                                return ColorsConfig.color_brand;
                            } else if(container.agency16KTimelapseLost) {
                                return ColorsConfig.color_454649_transparent;
                            }
                            return ColorsConfig.color_1C4B91_0E7E7E;
                        }
                        backgroundColorHover: {
                            if(container.mediaLost) {
                                return ColorsConfig.color_brand;
                            } else if(container.agency16KTimelapseLost) {
                                return ColorsConfig.color_454649_transparent;
                            }
                            return ColorsConfig.color_2460B9_15A4A4;
                        }
                        backgroundColorPressed: {
                            if(container.mediaLost) {
                                return ColorsConfig.color_brand;
                            } else if(container.agency16KTimelapseLost) {
                                return ColorsConfig.color_454649_transparent;
                            }
                            return ColorsConfig.color_0C213F_154747;
                        }
                        hoveredCursor: Qt.PointingHandCursor

                        title: clipFilterBadgeVM.lutName.length === 0 ? "" : qsTr("pccut_panel_colorrecovery") + " " + clipFilterBadgeVM.lutName
                        titleColor: container.sourceLost ? ColorsConfig.color_EEEEEE_000000 : ColorsConfig.color_C4D8F7_CDFFF0
                        titleFontSize: 10
                        alignment: Qt.AlignHCenter
                        focus: lutTagFocus
                        enabled: !container.sourceLost
                        hoverEnabled: true
                        onCustomClicked: {
                            if (!focus) {
                                clickTabType(SettingPanelViewModel.SETTINGPANELTABTYPE_ADJUST_LUT);
                            }
                        }
                        LightToolTip {
                            visible: !container.sourceLost && parent.hovered
                            tip: qsTr("pccut_panel_colorrecovery_introduction")
                        }
                    }
                    // 滤镜
                    IconTextButton {
                        visible: clipFilterBadgeVM.isEnableStyleFilter && clipFilterBadgeVM.styleFilterName.length !== 0
                        Layout.preferredHeight: 14
                        Layout.alignment: Qt.AlignVCenter
                        leftPadding: 4
                        rightPadding: 4
                        radius: RadiusConfig.radius_2_88
                        isTextOnly: true
                        backgroundColorNormal: {
                            if(container.mediaLost) {
                                return ColorsConfig.color_brand;
                            } else if(container.agency16KTimelapseLost) {
                                return ColorsConfig.color_454649_transparent;
                            }
                            return ColorsConfig.color_1C4B91_0E7E7E;
                        }
                        backgroundColorHover: {
                            if(container.mediaLost) {
                                return ColorsConfig.color_brand;
                            } else if(container.agency16KTimelapseLost) {
                                return ColorsConfig.color_454649_transparent;
                            }
                            return ColorsConfig.color_2460B9_15A4A4;
                        }
                        backgroundColorPressed: {
                            if(container.mediaLost) {
                                return ColorsConfig.color_brand;
                            } else if(container.agency16KTimelapseLost) {
                                return ColorsConfig.color_454649_transparent;
                            }
                            return ColorsConfig.color_0C213F_154747;
                        }
                        hoveredCursor: Qt.PointingHandCursor

                        focus: styleFilterTagFocus
                        title: clipFilterBadgeVM.styleFilterName.length === 0 ? "" : qsTr("pccut_filter") + " " + clipFilterBadgeVM.styleFilterName
                        titleColor: container.sourceLost ? ColorsConfig.color_EEEEEE_000000 : ColorsConfig.color_C4D8F7_CDFFF0
                        titleFontSize: 10
                        alignment: Qt.AlignHCenter
                        hoverEnabled: true
                        enabled: !container.sourceLost
                        onCustomClicked: {
                            if (!focus) {
                                clickTabType(SettingPanelViewModel.SETTINGPANELTABTYPE_ADJUST_STYLEFILTER);
                            }
                        }
                        LightToolTip {
                            visible: !container.sourceLost && parent.hovered
                            tip: qsTr("pccut_filter_introduction")
                        }
                    }

                    // 特效
                    IconTextButton {
                        visible: clipFilterBadgeVM.isEnableEffect && clipFilterBadgeVM.effectName.length !== 0
                        Layout.preferredHeight: 14
                        Layout.alignment: Qt.AlignVCenter
                        leftPadding: 4
                        rightPadding: 4
                        radius: RadiusConfig.radius_2_88
                        isTextOnly: true
                        backgroundColorNormal: {
                            if(container.mediaLost) {
                                return ColorsConfig.color_brand;
                            } else if(container.agency16KTimelapseLost) {
                                return ColorsConfig.color_454649_transparent;
                            }
                            return ColorsConfig.color_1C4B91_0E7E7E;
                        }
                        backgroundColorHover: {
                            if(container.mediaLost) {
                                return ColorsConfig.color_brand;
                            } else if(container.agency16KTimelapseLost) {
                                return ColorsConfig.color_454649_transparent;
                            }
                            return ColorsConfig.color_2460B9_15A4A4;
                        }
                        backgroundColorPressed: {
                            if(container.mediaLost) {
                                return ColorsConfig.color_brand;
                            } else if(container.agency16KTimelapseLost) {
                                return ColorsConfig.color_454649_transparent;
                            }
                            return ColorsConfig.color_0C213F_154747;
                        }
                        hoveredCursor: Qt.PointingHandCursor

                        focus: effectTagFocus
                        title: clipFilterBadgeVM.effectName.length === 0 ? "" : qsTr("pccut_tab_effects") + " " + clipFilterBadgeVM.effectName
                        titleColor: container.sourceLost ? ColorsConfig.color_EEEEEE_000000 : ColorsConfig.color_C4D8F7_CDFFF0
                        titleFontSize: 10
                        alignment: Qt.AlignHCenter
                        hoverEnabled: true
                        enabled: !container.sourceLost
                        onCustomClicked: {
                            if (!focus) {
                                clickTabType(SettingPanelViewModel.SETTINGPANELTABTYPE_EFFECT);
                            }
                        }
                        LightToolTip {
                            visible: !container.sourceLost && parent.hovered
                            tip: qsTr("pccut_timeline_effect_edit_tooltip")
                        }
                    }

                    // 仪表盘
                    IconTextButton {
                        visible: clipDashboardBadgeVM.isEnableDashboard && clipDashboardBadgeVM.dashboardName.length !== 0
                        Layout.preferredHeight: 14
                        Layout.alignment: Qt.AlignVCenter
                        leftPadding: 4
                        rightPadding: 4
                        radius: RadiusConfig.radius_2_88
                        isTextOnly: true
                        backgroundColorNormal: {
                            if(container.mediaLost) {
                                return ColorsConfig.color_brand;
                            } else if(container.agency16KTimelapseLost) {
                                return ColorsConfig.color_454649_transparent;
                            }
                            return ColorsConfig.color_1C4B91_0E7E7E;
                        }
                        backgroundColorHover: {
                            if(container.mediaLost) {
                                return ColorsConfig.color_brand;
                            } else if(container.agency16KTimelapseLost) {
                                return ColorsConfig.color_454649_transparent;
                            }
                            return ColorsConfig.color_2460B9_15A4A4;
                        }
                        backgroundColorPressed: {
                            if(container.mediaLost) {
                                return ColorsConfig.color_brand;
                            } else if(container.agency16KTimelapseLost) {
                                return ColorsConfig.color_454649_transparent;
                            }
                            return ColorsConfig.color_0C213F_154747;
                        }
                        hoveredCursor: Qt.PointingHandCursor
                        focus: dashboardTagFocus

                        title: clipDashboardBadgeVM.dashboardName.length === 0 ? "" : qsTr("pccut_dashboard") + " " + qsTr(clipDashboardBadgeVM.dashboardName)
                        titleColor: container.sourceLost ? ColorsConfig.color_EEEEEE_000000 : ColorsConfig.color_C4D8F7_CDFFF0
                        titleFontSize: 10
                        alignment: Qt.AlignHCenter
                        hoverEnabled: true
                        enabled: !container.sourceLost
                        onCustomClicked: {
                            if (!focus) {
                                clickTabType(SettingPanelViewModel.SETTINGPANELTABTYPE_DASHBOARD);
                            }
                        }
                        LightToolTip {
                            visible: parent.hovered
                            tip: qsTr("pccut_dashboard_edit")
                        }
                    }


                    // 变速
                    IconTextButton {
                        visible: speedTagDisplayed && !container.sourceLost
                        Layout.preferredHeight: 14
                        Layout.alignment: Qt.AlignVCenter
                        leftPadding: 4
                        rightPadding: focus ? 16 : 4
                        radius: RadiusConfig.radius_2_88
                        isTextOnly: true
                        backgroundColorNormal: {
                            if(container.mediaLost) {
                                return ColorsConfig.color_brand;
                            } else if(container.agency16KTimelapseLost) {
                                return ColorsConfig.color_454649_transparent;
                            }
                            return ColorsConfig.color_1C4B91_0E7E7E;
                        }
                        backgroundColorHover: {
                            if(container.mediaLost) {
                                return ColorsConfig.color_brand;
                            } else if(container.agency16KTimelapseLost) {
                                return ColorsConfig.color_454649_transparent;
                            }
                            return ColorsConfig.color_2460B9_15A4A4;
                        }
                        backgroundColorPressed: {
                            if(container.mediaLost) {
                                return ColorsConfig.color_brand;
                            } else if(container.agency16KTimelapseLost) {
                                return ColorsConfig.color_454649_transparent;
                            }
                            return ColorsConfig.color_0C213F_154747;
                        }
                        hoveredCursor: Qt.PointingHandCursor

                        focus: regSpeedTagFocus
                        title: speedName
                        titleColor: container.sourceLost ? ColorsConfig.color_EEEEEE_000000 : ColorsConfig.color_C4D8F7_CDFFF0
                        titleFontSize: 10
                        alignment: Qt.AlignLeft
                        enabled: !container.sourceLost
                        hoverEnabled: true
                        onCustomClicked: {
                            if (regSpeedTagFocus) {
                                playerPanel.controller.pause();
                                globalSignal.quickRegSpeedBtnClicked(this);
                                regSpeedAlertDisplayed = true;
                            } else {
                                regSpeedAlertDisplayed = false;
                                clickTabType(SettingPanelViewModel.SETTINGPANELTABTYPE_REGSPEED);
                            }
                        }

                        Image {
                            anchors {
                                top: parent.top
                                right: parent.right
                                bottom: parent.bottom
                            }
                            visible: regSpeedTagFocus
                            width: 14
                            source: regSpeedAlertDisplayed ? "qrc:/app_qrc/icons/icon_regspeed_more_up.svg":"qrc:/app_qrc/icons/icon_regspeed_more_down.svg"
                            sourceSize: Qt.size(14,14)
                        }
                        LightToolTip {
                            visible: !container.sourceLost && parent.hovered
                            tip: qsTr("pccut_panel_speed_introduction")
                        }
                    }

                    // 曲线变速
                    IconTextButton {
                        id: curveSpeedIcon
                        visible: CommonUtils.isNull(viewModel) || !viewModel.hasFragment ? false : viewModel.curveSpeedTemplateName.length != 0
                        Layout.preferredHeight: 14
                        Layout.alignment: Qt.AlignVCenter
                        leftPadding: 4
                        rightPadding: 4
                        radius: RadiusConfig.radius_2_88
                        isTextOnly: true
                        backgroundColorNormal: {
                            if(container.mediaLost) {
                                return ColorsConfig.color_brand;
                            } else if(container.agency16KTimelapseLost) {
                                return ColorsConfig.color_454649_transparent;
                            }
                            return ColorsConfig.color_1C4B91_0E7E7E;
                        }
                        backgroundColorHover: {
                            if(container.mediaLost) {
                                return ColorsConfig.color_brand;
                            } else if(container.agency16KTimelapseLost) {
                                return ColorsConfig.color_454649_transparent;
                            }
                            return ColorsConfig.color_2460B9_15A4A4;
                        }
                        backgroundColorPressed: {
                            if(container.mediaLost) {
                                return ColorsConfig.color_brand;
                            } else if(container.agency16KTimelapseLost) {
                                return ColorsConfig.color_454649_transparent;
                            }
                            return ColorsConfig.color_0C213F_154747;
                        }
                        hoveredCursor: Qt.PointingHandCursor
                        focus: curveSpeedTagFocus

                        title: CommonUtils.isNull(viewModel) || !viewModel.hasFragment ? "" : viewModel.curveSpeedTemplateName
                        titleColor: container.sourceLost ? ColorsConfig.color_EEEEEE_000000 : ColorsConfig.color_C4D8F7_CDFFF0
                        titleFontSize: 10
                        alignment: Qt.AlignHCenter
                        hoverEnabled: true
                        enabled: !container.sourceLost
                        onCustomClicked: {
                            if (!focus) {
                                clickTabType(SettingPanelViewModel.SETTINGPANELTABTYPE_SPEED);
                            }
                        }
                        LightToolTip {
                            visible: !container.mediaLost && parent.hovered
                            tip: curveSpeedIcon.title
                        }
                    }

                    // 素材名称
                    IconTextButton {
                        Layout.alignment: Qt.AlignVCenter
                        leftPadding: 4
                        rightPadding: 4
                        isTextOnly: true
                        backgroundColorNormal: Colors.transparent
                        title: root.mediaName
                        titleColor: container.sourceLost ? ColorsConfig.color_EEEEEE_000000 : ColorsConfig.color_78A7EC_78E5DE
                        titleFontSize: 10
                        alignment: Qt.AlignHCenter
                        enabled:false
                    }

                    // 时长
                    Text {
                        property string durationStr: DurationFormatter.format(fragment.displayFrames, root.outputFps)
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: 65
                        horizontalAlignment: Qt.AlignLeft
                        font.pixelSize: 10
                        color: container.sourceLost ? ColorsConfig.color_EEEEEE_000000 : ColorsConfig.color_78A7EC_78E5DE
                        text: durationStr
                    }
                    Item {
                        Layout.fillWidth: true
                    }
                }
            }


            // 更多
            Rectangle {
                id: moreButton
                anchors {
                    top: parent.top
                    right: parent.right
                    bottom: parent.bottom
                }
                width: 24
                color: Colors.color_transparent
                opacity: 1

                // 修复：QML Rectangle: Binding loop detected for property "visible"
                visible: !container.sourceLost
                        && titleInfoRoot.contentOverflow
                        && (clipFilterBadgeVM.isEnableLut || clipFilterBadgeVM.isEnableStyleFilter || clipFilterBadgeVM.isEnableEffect || clipDashboardBadgeVM.isEnableDashboard || viewModel.speed !== 1)
                Rectangle {
                    id: gradientRectangle
                    anchors {
                        left: parent.left
                        top: parent.top
                        bottom: parent.bottom
                    }
                    width: 4
                    clip: true
                    gradient: Gradient {
                        orientation: Qt.Horizontal
                        GradientStop {
                            position: 0
                            color: Colors.color_transparent
                        }
                        GradientStop {
                            position: 0.98
                            color: ColorsConfig.color_143668_045858
                        }
                    }
                }
                Rectangle {
                    id: moreButtonImageArea
                    anchors {
                        left: gradientRectangle.right
                        top: parent.top
                        bottom: parent.bottom
                        right: parent.right
                    }
                    color: Colors.transparent
                    Image {
                        anchors {
                            verticalCenter: parent.verticalCenter
                            left: parent.left
                            leftMargin: 3
                            right: parent.right
                            rightMargin: 3
                        }
                        width: 14
                        height: 14
                        source: "qrc:/icons/icon_videoItem_more_tab.svg"
                        sourceSize: Qt.size(14, 14)
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        // 先选中片段
                        if (!viewModel.selected) {
                            itemClicked(false);
                        }
                        var rect = UiUtils.getGlobalPosition(parent);
                        moreTabAlert.refreshMaxHeight();
                        moreTabAlert.contentRectangleX = rect.x + parent.width;
                        let contentRectangleY = rect.y - titleInfoRow.anchors.topMargin
                        if (windowSizeManager.getCurrentGeometry().height < moreTabAlert.maxHeight + contentRectangleY) {
                            contentRectangleY -= 10 + stackLayout.anchors.bottomMargin;
                        }
                        moreTabAlert.contentRectangleY = contentRectangleY;
                        moreTabAlert.open();
                    }
                }
            }
        }
    }

    Item {
        id: fragment

        // 变速后片段在时间线上的时长：用 trackFrameOut/trackFrameIn（含变速），而非 frameOut/frameIn（源裁剪范围）
        property real totalTimebase: CommonUtils.isNull(viewModel) || !viewModel.hasFragment ? 0 : (viewModel.trackFrameOut - viewModel.trackFrameIn)
        property real displayFrames: totalTimebase / 30000.0 * outputFps
        property real displayLength: displayFrames * pxPerFrame
        property size frameSize: Qt.size(36, 36)
        property int itemCount: (visibleRight - visibleLeft) / frameSize.width + 2
        property color borderColor: Colors.color_EEEEEE
        property int rectRadius: RadiusConfig.radius_4_8
        property string path: CommonUtils.isNull(viewModel) || !viewModel.hasFragment ? "" : viewModel.path
        property bool audioVisibility: CommonUtils.isNull(viewModel) || !viewModel.hasFragment ? false : viewModel.audioVisibility
        property real originLength: CommonUtils.isNull(viewModel) || !viewModel.hasFragment ? 0 : viewModel.mkOriginLength
    }

    VideoItemMoreTabAlert {
        id:moreTabAlert
        // nova: 下拉项数据源全部 per-clip VM，与 VideoItemView 角标同源（滤镜/LUT/仪表盘/变速）。
        clipViewModel: root.viewModel
        clipFilterBadgeVM: clipFilterBadgeVM
        clipDashboardBadgeVM: clipDashboardBadgeVM
    }

    PanoramaViewingModeAlert {
        id:panoramaViewingModeAlert
        // nova: 取景模式数据从片段绑定的 TimelineVideoClipViewModel 投影；切换走 globalSignal.trackViewingModeChanged → PanoramaPanel → nova SwitchPanoramaViewCmd
        viewModel: root.viewModel
    }

    onPxPerFrameChanged: {
        if (leftClipDragArea.selectTkFragment !== null
                && leftClipDragArea.selectTkFragment.track === root.trackIndex
                && leftClipDragArea.selectTkFragment.clip === root.clipIndex
                && leftClipDragArea.select) {

            if (CommonUtils.isNull(viewModel) || !viewModel.hasFragment || CommonUtils.isNull(keyframeItemData)) {
                return
            }

            leftClipDragArea.validWidth = Math.min(editorManager.frameByPosition(leftClipDragArea.selectTkFragment.speedClipStart - viewModel.frameIn) * pxPerFrame, clipAreaWidth)
            rightClipDragArea.validWidth = Math.min(editorManager.frameByPosition(leftClipDragArea.selectTkFragment.frameOut - keyframeItemData.speedClipEnd) * pxPerFrame, clipAreaWidth)
        }
    }

    // 滤镜拖拽添加的时候拖拽当当前片段的高亮的状态
    Rectangle {
        id: highlightItem
        visible: showHighlight
        anchors.fill: container
        color: Colors.color_000000_40
        radius: fragment.rectRadius
    }

    // 特效、滤镜等向轨道拖拽时的蒙层样式；素材拖拽替换悬停(变小图)时由 coverStyle=EnableCover 显示高亮蒙层
    TrackItemCover {
        anchors.fill: container
        fragmentInfo: viewModel  // coverStyle 已投影(拖拽替换悬停蒙层)；其余特效/滤镜拖拽蒙层 NOVATODO
        rectRadius: fragment.rectRadius
    }

    Connections {
        target: globalSignal

        // 全局信号，通知选中片段
        function onCallItemSelected(track, clip) {
            if (track === root.trackIndex && clip === root.clipIndex) {
                root.itemClicked(false);
            }
        }
        // 快捷变速弹框关闭后，将【变速】标签的图标变成向下
        function onRegSpeedAlertClosed() {
            if (!viewModel.selected) {
                return;
            }
            regSpeedAlertDisplayed = false;
        }
        function onUseStabilizeChanged(trackIndex, clipIndex) {
            // nova: 增稳态由 TimelineVideoClipViewModel.isUseStabilize 投影，写入经 nova 落库后
            // onDraftChanged→reload 自动回灌绑定，无需在此手动刷新；该老信号 nova 写入路径不再发射。
        }
    }

    // superSlow 浮层随 tab 切换收起：currentTabType 非 SUPER_SLOW 时收起（对齐老 onSettingPanelFocusTabType 语义）。
    Connections {
        target: settingPanel
        function onCurrentTabTypeChanged() {
            if (settingPanel.currentTabType !== SettingPanelViewModel.SETTINGPANELTABTYPE_SUPER_SLOW) {
                superSlowItemView.visible = false;
            }
        }
    }

    // 片段头部进行滚动裁切，恢复时更新被裁切片段的相关属性
    function leftScrollClipUpdate(fixPos){
        let newTrackFrameIn = fixPos / pxPerFrame * oneFrameToTimes;
        let delta = newTrackFrameIn - viewModel.trackFrameIn
        container.curStartPosX -= (delta / oneFrameToTimes) * pxPerFrame;

        let isStopClip = false;
        // 处理边界case, 裁切及恢复
        if(viewModel.length + delta <= oneFrameToTimes){  // 裁切到小于等于一帧
            isStopClip = true;
            viewModel.frameIn = viewModel.frameOut - oneFrameToTimes;
            viewModel.trackFrameIn = viewModel.trackFrameOut - oneFrameToTimes;

        }else if(leftEdgeArrived(viewModel.frameIn + delta)){  // 头部已经恢复到片段最初的长度
            isStopClip = true;
            viewModel.frameIn = 0;
            var trackFrameIn = viewModel.trackFrameIn;
            viewModel.trackFrameIn = trackVisibleLeft / pxPerFrame * oneFrameToTimes;

            var deltaX = Math.min((trackFrameIn - viewModel.trackFrameIn) /oneFrameToTimes * pxPerFrame, trackVisibleLeft)
            flickable.scrollByX(-deltaX)
        }else{
            // 原来的写法是 isStopClip = false; 之所以改成 isStopClip = delta == 0 是因为目前的实现不允许当delta==0的时候继续滑动
            isStopClip = delta == 0
            viewModel.frameIn += delta;
            viewModel.trackFrameIn = newTrackFrameIn;
        }

        let deltaFrameIn = leftClipDragArea.startClipFrameIn - viewModel.frameIn;
        let deltaSeelPos = deltaFrameIn > 0 ? deltaFrameIn : 0;
        let isMustRefresh = (deltaFrameIn > 0);
        editorManager.clipSeek(Math.ceil((viewModel.trackFrameIn + deltaSeelPos) / oneFrameToTimes), isMustRefresh);
        TimelineEditController.relayoutPreview(viewModel.clipNodeId);  // nova: 滚动裁切预览（setVisibleRect 此时不重排）
        if(isStopClip){
            scrollClip(false, true, false);
        }
    }

    // 片段尾部进行滚动裁切恢复时更新被裁切片段的相关属性
    function rightScrollClipUpdate(fixPos, maxFrameOut){
        let newTrackFrameOut = fixPos / pxPerFrame * oneFrameToTimes;
        let delta = newTrackFrameOut - (viewModel.trackFrameIn + viewModel.length);

        let isStopClip = false;
        // 处理边界case, 裁切及恢复
        if(viewModel.length + delta <= oneFrameToTimes){   // 裁切到小于等于一帧
            viewModel.frameOut = viewModel.frameIn + oneFrameToTimes;
        }else if(viewModel.frameOut + delta > maxFrameOut){   // 尾部已经恢复到片段最初的长度
            isStopClip = true;
            viewModel.frameOut = maxFrameOut;
        }else{
            isStopClip = false
            viewModel.frameOut += delta;
        }
        editorManager.clipSeek(Math.floor(viewModel.trackFrameOut / oneFrameToTimes));
        TimelineEditController.relayoutPreview(viewModel.clipNodeId);  // nova: 滚动裁切预览（setVisibleRect 此时不重排）

        if(isStopClip){
            scrollClip(false, false, false);
            fragmentChange(false, false, false);
        }
    }

    // 将此次裁切操作添加进撤销堆栈中
    function addClipAction(){
    }

    // 点击tag，右侧面板切换不同的tab
    function clickTabType(tabType) {
        playerPanel.controller.pause();
        // 先选中片段
        itemClicked(false);
        globalSignal.videoItemViewClickTabType(tabType);
    }
    function leftEdgeArrived(frameIn) {
        if (CommonUtils.isNull(viewModel) || !viewModel.hasFragment) {
            return false;
        }
        if (!viewModel.clipDirectionUnlimite()) {
            return frameIn <= 0;
        }
        return (viewModel.frameOut - frameIn >= viewModel.originLength);
    }

    function showLinkMediaPop() {
        const tfInfo = viewModel.getTrackingFileInfo();
        globalSignal.manualLinkMedia([tfInfo]);
    }

    // 转场加载器
    Loader {
        id: transitionLoader
        active: transitionViewModel.isValid
        objectName: "transitionLoader"

        sourceComponent: Component {
            TransitionItemView {
                id: transitionItem
                parent: root.parent
                rootItem: root
                rootHeight: root.height
                currentZIndex: root.currentZIndex
                viewModel: transitionViewModel
                pxPerFrame: root.pxPerFrame
                outputFps: root.outputFps
                dataProvider: multiTrackDataProvider

                onRequestDeactivate: {
                    console.log("TransitionItemView requesting deactivation");
                }
            }
        }
    }

    Loader {
        id: transitionPlaceholderLoader
        active: showTransitionPlaceholder

        sourceComponent: Component {
            TransitionPlaceholderView {
                id: placeholderItem
                parent: root.parent
                rootItem: root
                rootHeight: root.height
                currentZIndex: root.currentZIndex
                // 占位须在选中框(root.z+zIndexBorder=+20)之下、绿框(+11)之上
                zIndexTransition: 12
                pxPerFrame: root.pxPerFrame
                outputFps: root.outputFps
                maxDuration: {
                    // 如果当前片段有转场，使用转场的实际duration
                    if (hasTransition && transitionLength > 0) {
                        return transitionLength;
                    }
                    // 转场删除以后 maxDuration = 0  所以这里自己算一下
                    var totalFrame = (viewModel.frameOut-viewModel.frameIn)
                    var maxDuration = totalFrame / 2
                    return maxDuration > 0 ? Math.min(maxDuration, 27000) : 27000;
                }
            }
        }
    }

    // 选中框
    // 逃逸到 root.parent 兄弟层(仿 keyframeLayerView 范式)，用相对 z root.z+zIndexBorder：
    // 须压住绿框(+11)/转场(+10)/转场占位(+12)，又低于标记带(+22)使标记带显示在选中框之上。
    // 用绑定式定位替代命令式 updatePosition。
    Rectangle {
        id: selectedBorderOverlay
        visible: selected && root.visible && !hideClipStyle

        parent: root.parent
        x: root.x + itemGap / 2
        y: root.y
        width: root.width - itemGap
        height: root.height

        color: Colors.transparent
        radius: fragment.rectRadius
        border.width: selectedGripWidth
        border.color: fragment.borderColor
        z: root.z + zIndexBorder

        onVisibleChanged: {
            if(selectedBorderOverlay.visible){
                superSlowLineTemp.visible = superSlowItemView.enableSuperSlow
            }
        }

        // 超慢常驻线条
        Item {
            id: superSlowLineTemp
            z: 1
            anchors.fill: parent
            visible: false
            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: superSlowLineTemp.width
                    height: superSlowLineTemp.height
                    radius: container.radius
                }
            }
            Rectangle {
                anchors.top: parent.top
                x: superSlowItemView.x
                color: Colors.color_009DFF
                height: 2
                width: superSlowItemView.width
                radius: 1
            }
        }
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
        // 多轨道下标记带逃逸成 MTV 兄弟、非阻断 HoverHandler 多播无视 z 遮挡：非主轨片段滚到固定主轨(scrollModel
        // TOP/BOTTOM)后视觉被主轨盖住却仍响应鼠标。据标记带 y 与"已钉住主轨背景 rect"求交注入 occludedByMainTrack，
        // ribbon 内每枚标记的 HoverHandler/MouseArea 会据此禁用——只断响应、不动 visible(露出段仍显示、z 序自然被盖)。
        // 用真实钉住 rect(multiTrackView.mainTrackRect)直接求交，避免 visibleRect±高度 拼带的偏移致"露出仍响应"。
        // 主轨自身(trackIndex 0)永不遮挡。
        occludedByMainTrack: {
            if (root.trackIndex === 0 || CommonUtils.isNull(multiTrackView)) {
                return false;
            }
            if (multiTrackView.scrollModel === MultiTrackView.SCROLL_MODEL_NORMAL) {
                return false;  // 未钉住，主轨在自然位，非主轨标记不与其重叠
            }
            let mtr = multiTrackView.mainTrackRect;
            // 标记 icon 底对齐、实占底部 12px(上方 6px 空)：用 icon 实占段求交，否则空段会戳进相邻主轨 rect 底边误判。
            // 再留 gap 级容差(4px)：相邻第一音频轨会与主轨底边贴边数 px，超过此深度才算真滚到主轨身后。
            let markTop = markPointRibbon.y + markPointRibbon.height - 12;
            let markBottom = markPointRibbon.y + markPointRibbon.height;
            let overlap = Math.min(markBottom, mtr.y + mtr.height) - Math.max(markTop, mtr.y);
            return overlap > 4;
        }
        fragmentHost: (CommonUtils.isNull(root.viewModel) || !root.viewModel.hasFragment) ? null : root.viewModel
        visible: !CommonUtils.isNull(root.viewModel) && root.viewModel.hasFragment && !container.sourceLost
        // 拖动标记贴边时横向自动滚动
        scroller: flickable
        // 反向拖动吸附数据源
        snappingProvider: root.snappingProvider
        // playing 有意不绑定：播放中允许拖动，拖动起始由 MarkPointItem.onDraggingChanged 显式调 editorManager.pause() 暂停，绑定 playing 反而会禁止这一交互。
        // playing 属性保留为可选硬防护（如需"播放中禁止拖动"可一行绑定生效）。
    }

    Component.onDestruction:{
        if(root.isCursorEnterClipArea){
            cursorhelper.restoreOverrideCursor();
        }
    }

    // ========== 离屏片段对象池(轨道区域缓存)==========
    // exitPool: 缓存命中回屏时由 C++ 调用(layoutFragment 视频缓存命中分支)。
    // 入池时曾 setParentItem(nullptr) 脱离场景图,缩略图 ListView/音波的画面来源可能停在入池前口径,
    // 零重绑不会重算 → 回屏空白。缩略图/音波由声明式绑定(thumbnailListModel.videoPath、audioWavePaint.audioPath)
    // 自动重算,此处只重激活高光,不触碰 trackIndex/clipIndex(声明式绑定,C++ 已就位)与 keyframe 身份 ——
    // 缓存键 (片段,track,clip) 未变,不会重现旧 rebind 的关键帧串台。
    function exitPool() {
        if (!CommonUtils.isNull(viewModel) && viewModel.hasFragment) {
            if (!CommonUtils.isNull(viewModel.audioHighlightModel)) {
                viewModel.audioHighlightModel.created()
            }
            thumbnailListModel.listViewCompleted = true
        }
    }

    // enterPool: 离屏入池前由 C++ 调用(releaseToPool 视频分支),清瞬态(光标/裁切进行态),不触碰 viewModel 绑定。
    function enterPool() {
        if (root.isCursorEnterClipArea) {
            cursorhelper.restoreOverrideCursor()
            root.isCursorEnterClipArea = false
        }
        if (leftClipDragArea.isStartclip) {
            leftClipDragArea.isStartclip = false
        }
        if (rightClipDragArea.isStartclip) {
            rightClipDragArea.isStartclip = false
        }
    }

    // rebind/_rebindImpl: 视频轨改为按 (片段,track,clip) 缓存零重绑后,C++ 不再对本组件调 rebind()
    // (音频轨复用的是 AudioItemView,其 rebind 在 AudioItemView.qml 内)。本组函数现为视频轨的死代码,
    // 保留以备将来若视频重新启用 rebind 路径可复用;当前视频复用命中即原样复用,不重跑命令式初始化。
    // onCompleted 的命令式初始化(setTrackClip(关键帧)/audioHighlightModel.created() 等 C++ 模型绑定)
    // 声明式绑定无法替代,复用换主时需显式重跑,否则串台
    // (缩略图/音波显示上个片段、关键帧写入错误 clip、标签 focus 残留等)。
    // 分同步段(callLater 前)与推迟段:
    // - 同步段:画面来源类(缩略图/音波/高光),callLater 前 1 帧若仍显示旧片段画面会闪现串台,当场重算。
    // - 推迟段:非画面瞬态(裁切上限/标签 focus/超慢 visible/关键帧 setTrackClip),等声明式绑定重算落定再跑。
    // keyframeLayerView.setTrackClip 依赖 trackIndex/clipIndex 声明式绑定重算,故丢推迟段。
    function rebind() {
        // 同步段:高光——画面来源,立即重算杜绝 callLater 前 1 帧串台。
        // 缩略图/音波由声明式绑定(thumbnailListModel.videoPath: root.mediaPath、audioWavePaint.audioPath:
        // viewModel.path)驱动,C++ 改 context property 后自动重算。
        if (!CommonUtils.isNull(viewModel) && viewModel.hasFragment) {
            if (!CommonUtils.isNull(viewModel.audioHighlightModel)) {
                viewModel.audioHighlightModel.created()
            }
            thumbnailListModel.listViewCompleted = true
        }
        Qt.callLater(function() { _rebindImpl(); })
    }

    // 推迟段:重跑非画面瞬态的命令式初始化(对应 Component.onCompleted 里的内容)。
    function _rebindImpl() {
        if (CommonUtils.isNull(viewModel) || !viewModel.hasFragment) {
            return
        }
        // trackIndex/clipIndex 是声明式绑定,C++ 已改 context property,这里不命令式赋值(会断绑定)。
        // 重跑 rightClipDragArea.onCompleted(:640):右裁切上限
        root.rightframelengthLimit = Math.max(root.rightframelengthLimit, viewModel.frameOut)
        // 重跑 container 块 onCompleted(:867):超慢 UI 可见性
        superSlowItemView.visible = (selected && superSlowItemView.enableSuperSlow)
        superSlowLineClip.visible = superSlowItemView.enableSuperSlow
        superSlowLineTemp.visible = superSlowItemView.enableSuperSlow
        // 重跑 keyframeLayerView.onCompleted(:1444):关键帧绑定到当前 track/clip
        keyframeLayerView.setTrackClip(root.trackIndex, root.clipIndex)
        // 重跑 root.onCompleted(:184):标签 focus 态
        settingPanelFocusTabType(settingPanel.getSettingPanelTabType())
        // 视频复用现已零重绑,本函数当前为死代码;若将来重新启用 rebind,转场 VM 的 setFragmentFromQml
        // 需由 C++ 复用分支补调(新建路径靠 onCompleted 时序),此处不重复。
        // selectedBorderOverlay.onCompleted(:2617) 仅 Qt.callLater(updatePosition),
        // 其 onXChanged/onYChanged Connections 已覆盖自动同步,无需重跑。
    }
}
