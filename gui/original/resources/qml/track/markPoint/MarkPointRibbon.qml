/**
 * @details: 一条标记带。内置 MarkPointRibbonViewModel，Repeater 绑定其 model(QAbstractListModel)。
 *           宿主二选一：fragmentHost(素材) 或 timelineHost(时间轴)。右键菜单按需创建。
 */
import QtQuick 2.15
import QtQuick.Window 2.15
import Config 1.0
import MarkPointRibbonViewModel 1.0

Item {
    id: ribbonRoot

    // 每帧像素（缩放比），由宿主 QML 传入
    property real pxPerFrame: 0
    // 播放中禁止拖动（可选硬防护，当前宿主有意不绑定；实际播放安全由 MarkPointItem.onDraggingChanged 显式 pause() 保障）
    property bool playing: false
    // 标记纵向对齐：true=底对齐(素材标记贴素材上方)；false=顶对齐(时间轴标记，整体位置由宿主对本 ribbon 定位调整)
    property bool bottomAligned: false
    // 拖动贴边时用于横向自动滚动的滚动容器(TrackFlickable)；null 时不启用自动滚动
    property var scroller: null
    // 右侧拖动上界覆盖：>=0 时透传给 item 优先于 VM；时间轴标记设为"可滚动最右"，素材标记保持 -1(用片段长度)
    property int maxDragFrame: -1
    // 时间指示器视觉项(FrameIndicator)：注入后，标记按下点落在其命中区时让位给指示器(详见 MarkPointItem.isOnTimeIndicator)。
    // 仅时间轴标记带需要注入(与指示器拖动头重叠)；素材标记在轨道体上不与指示器拖动头重叠，保持 null。
    property var indicatorItem: null

    // 本带是否正在悬停驱动预览(供宿主 OR 进 previewIndicator 可见性)。与标记自身的 markPointPreviewActive
    // 各自独立、由宿主做 OR，避免两个布尔互相覆盖造成"离开标记进入空白"瞬间闪灭。
    // 由宿主(时间轴标记带=TrackDock timelineMarkClip 全视口 HoverHandler)调 driveBandPreview/clearBandPreview 驱动。
    property bool bandPreviewing: false

    // 整条带被固定主视频轨遮挡(多轨道纵向滚动、非主轨片段滚到固定主轨背景后)：由宿主(素材 ItemView)按标记带 y 与
    // 主轨钉住 rect 求交算出注入。为 true 时每枚标记的 HoverHandler/MouseArea 均禁用——只断鼠标响应、不动 visible，
    // 露出段仍显示(z 序自然被主轨背景盖住)。别靠祖先 Item.enabled 传导(HoverHandler 不可靠)，须在 handler 直接门控。
    property bool occludedByMainTrack: false

    // 宿主绑定：二选一
    property alias fragmentHost: ribbonViewModel.fragmentHost
    property alias timelineHost: ribbonViewModel.timelineHost
    // 吸附数据源(multiTrackDataProvider)，由宿主 QML 注入，供反向拖动查询片段头尾候选
    property alias snappingProvider: ribbonViewModel.snappingProvider

    MarkPointRibbonViewModel {
        id: ribbonViewModel
    }

    // hover 仲裁：同一 ribbon 内同时 hovered 的 mark 可能有多个（HoverHandler 非阻断），
    // 通过"最后进入者获得激活权"保证任意时刻至多一个 mark 显示 hover 视觉效果（放大+tooltip+预览轴）。
    // item 在 HoverHandler.onHoveredChanged 时调用 onMarkHoverEnter/onMarkHoverLeave 维护此状态。
    property var hoveredMarks: []       // 当前所有物理 hovered 的 mark item 引用列表
    property var activeHoveredMark: null  // 仲裁结果：唯一获得 hover 视觉效果的 mark

    function onMarkHoverEnter(mark) {
        if (hoveredMarks.indexOf(mark) === -1) hoveredMarks.push(mark);
        activeHoveredMark = mark;
    }

    function onMarkHoverLeave(mark) {
        let i = hoveredMarks.indexOf(mark);
        if (i !== -1) hoveredMarks.splice(i, 1);
        if (activeHoveredMark === mark) {
            activeHoveredMark = hoveredMarks.length > 0 ? hoveredMarks[hoveredMarks.length - 1] : null;
        }
    }

    // 拖动中的标记（驱动共享自动滚动定时器）；一条 ribbon 仅一个，避免每个标记各自建 Timer
    property var activeDragItem: null
    function beginAutoScroll(item) {
        if (scroller) {
            activeDragItem = item;
            autoScrollTimer.start();
        }
    }
    function endAutoScroll(item) {
        if (activeDragItem === item) {
            activeDragItem = null;
            autoScrollTimer.stop();
        }
    }
    // 共享自动滚动定时器：仅拖动期运行，离开即停
    Timer {
        id: autoScrollTimer
        interval: 20
        repeat: true
        onTriggered: {
            if (ribbonRoot.activeDragItem) {
                ribbonRoot.activeDragItem.autoScrollTick();
            }
        }
    }

    // 整条标记带的悬停预览驱动入口(由宿主全视口 HoverHandler 调用，覆盖 totalFrame 之外空白，与轨道行一致)。
    // 吸附走 OPERATE_PREVIEW_AXIS、不画线。拖动期由标记自身驱动落帧并以 markPointPreviewActive 维持可见，故让位。
    function driveBandPreview(displayFrame) {
        if (activeDragItem) {
            return;
        }
        if (pxPerFrame <= 0 || !ribbonViewModel.hoverPreviewEnabled()) {
            bandPreviewing = false;
            return;
        }
        let frame = Math.max(0, ribbonViewModel.snapHoverPreviewDisplayFrame(Math.max(0, displayFrame)));
        bandPreviewing = true;
        ribbonViewModel.previewAtDisplayFrame(frame);
    }
    function clearBandPreview() {
        bandPreviewing = false;
    }

    Repeater {
        id: repeater
        model: ribbonViewModel.model
        delegate: MarkPointItem {
            pxPerFrame: ribbonRoot.pxPerFrame
            // 注意：用与 delegate 同名的属性名会被 delegate 自身遮蔽，故 id 取 ribbonViewModel。
            ribbonVm: ribbonViewModel
            ribbon: ribbonRoot
            playing: ribbonRoot.playing
            bottomAligned: ribbonRoot.bottomAligned
            maxDragFrame: ribbonRoot.maxDragFrame
        }
    }

    Component {
        id: menuComp
        MarkPointContextMenu {}
    }

    function openMenu(markId, posX, posY) {
        let menu = menuComp.createObject(ribbonRoot, {
            ribbonVm: ribbonViewModel,
            targetId: markId,
            isTimeline: ribbonViewModel.timelineHost
        });
        if (menu) {
            let p = ribbonRoot.mapToItem(null, posX, posY);
            let margin = 4;
            // 菜单整体往右下错开一点，避免出现在光标正下被指针遮挡
            let cursorOffsetX = 8;
            let cursorOffsetY = 8;
            // 用所属窗口尺寸钳位(与 overlay 同覆盖整窗、坐标原点一致)；不直接用 Overlay.overlay(当变量用可能引起退出崩溃)。
            let win = Window.window;
            let availW = win ? win.width : (p.x + menu.width);
            let availH = win ? win.height : (p.y + menu.height);
            let maxX = availW - menu.width - margin;
            let maxY = availH - menu.height - margin;
            menu.x = Math.round(Math.max(margin, Math.min(p.x + cursorOffsetX, maxX)));
            menu.y = Math.round(Math.max(margin, Math.min(p.y + cursorOffsetY, maxY)));
            menu.closed.connect(function () { menu.destroy(); });
            menu.open();
        }
    }
}
