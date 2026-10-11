/**
 * @details: 单个标记点 icon。delegate 内只通过 model.xxx role 访问数据，唯一坐标算术为
 *           x: model.displayFrame * pxPerFrame
 */
import QtQuick 2.15
import QtQuick.Window 2.15
import Config 1.0
import Controls 1.0
import MarkPointToolbarViewModel 1.0

Item {
    id: markItem

    // 每帧像素（缩放比），由 Ribbon 传入
    property real pxPerFrame: 0
    // 所属 Ribbon 的 ViewModel
    property var ribbonVm
    // 所属 Ribbon（用于右键菜单坐标映射 + 取高度做底对齐）
    property var ribbon
    // 播放中禁止拖动（可选硬防护，当前宿主有意不绑定；实际播放安全由 onDraggingChanged 显式 pause() 保障）
    property bool playing: false
    // true: 图标底部对齐容器底部（素材标记：贴在素材上方不重叠）；false: 顶部对齐容器顶部（时间轴标记，整体位置由宿主对 ribbon 定位调整）
    property bool bottomAligned: false

    // 拖动态
    property bool dragging: false
    property real dragX: 0
    // 拖动中的当前帧（量化后），供落点提交与预览轴跟随
    property int dragFrame: 0
    // 按下时光标在 ribbon(稳定父坐标系)中的 x；用它算位移，避免"MouseArea 随 item 移动导致局部坐标漂移"的抖动
    property real pressCursorX: 0
    property real startX: 0
    // 光标在 ribbon.scroller(viewport)坐标系下的 x：鼠标静止时此值不随内容滚动改变，供自动滚动定时器判边缘/回算落帧
    property real lastCursorViewportX: 0
    // 右侧上界覆盖（由 ribbon 透传）：>=0 时优先于 VM 的 maxClipDisplayFrame()，用于时间轴标记"可滚动最右"限位
    property int maxDragFrame: -1
    // 自动滚动触发边距：光标进入距 viewport 左/右边缘此距离内即开始滚动(右侧借此预留空间避免标记贴住滚动条)
    property real autoScrollEdge: 60

    // ribbon 级 hover 仲裁结果：同一 ribbon 内多个标记可同时被 HoverHandler 报告为 hovered（非阻断，
    // 缩放后 bounds 重叠时尤其常见），此属性在 hoverHandler.hovered 基础上额外要求本 item 是 ribbon
    // 当前指定的 activeHoveredMark，保证任意时刻只有一个标记显示 hover 视觉效果（放大+tooltip+预览轴）。
    readonly property bool isHoveredAndActive: hoverHandler.hovered && !!ribbon && ribbon.activeHoveredMark === markItem

    // tooltip 是否需要显示：仅"悬停且未按下"时显示；按下(点击/拖动)或移走立即隐藏，
    // 避免吸附拖动时 tooltip 遮挡上下相邻轨道元素；悬停落在指示器头上时也不显示(让位给指示器头)
    property bool tipWanted: isHoveredAndActive && !markArea.pressed && !overIndicator
    // tooltip 淡入/淡出动画时长（单一来源，供 LightToolTip 动画与"淡出后销毁"定时器共用）
    readonly property int tipAnimDuration: 100

    readonly property int iconWidth: 12
    readonly property int iconHeight: 12

    // 是否为当前单击选中的标记（全局单选，id 存于工具栏单例）：驱动选中变色 + 持续放大
    readonly property bool isSelected: MarkPointToolbarViewModel.selectedMarkId === model.id
    // 选中/hover 放大 scale 过渡时长
    readonly property int selectAnimDuration: 100

    // 尺寸由图标自身决定：固定渲染高度，宽度按 svg 纵横比，避免拉伸
    width: iconWidth
    height: iconHeight
    // 纵向对齐：底对齐时 y = 容器高 - 图标高（图标底边贴容器底边）；否则顶部对齐容器顶部（y=0，整体偏移由宿主定位 ribbon 实现）
    y: (bottomAligned && ribbon) ? (ribbon.height - height) : 0
    // 唯一坐标算术：显示帧 → 像素，并左移半个图标使中心对齐时间（中心对齐到该帧）
    x: dragging ? dragX : (model.displayFrame * pxPerFrame - width / 2)
    z: dragging ? 100 : 1

    // 拖动标记期间通知工具栏单例，使 M 快捷键 / icon 点击在拖动中不触发加删点（避免与落点抢改标记集合）。
    // 同时通知播放器进度条(playerSlider)：拖动预览 seek 时进度条跟随预览帧同步移动（仅拖动，不含悬停）。
    onDraggingChanged: {
        MarkPointToolbarViewModel.setMarkDragging(dragging);
        globalSignal.markPointDragging(dragging);
        // 拖动期间一刀切禁用所有快捷键：拖动时鼠标已被占用，唯一能触发的入口就是键盘快捷键，
        // 在此整体屏蔽，避免任意快捷键(M/撤销/删除等)在拖动中触发与落点提交冲突。
        ShortcutObserver.disableAllShortcut(dragging);
        // 拖动起始显式暂停播放：原依赖 previewSeek(ROLE_PREVIEW_SEEK) 内部检测 isPlaying() 暂停的副作用，
        // 此处显式化，与 previewSeek 实现解耦，避免日后 previewSeek 改动导致播放中拖动出现画面跳动。
        if (dragging) {
            editorManager.pause();
        }
    }

    // 拖动中若 delegate 被模型重建/撤销销毁，onDraggingChanged/onReleased 都不会触发，
    // 此处兜底清理拖动态，避免工具栏单例、进度条、自动滚动定时器、吸附线状态泄漏。
    Component.onDestruction: {
        if (dragging) {
            MarkPointToolbarViewModel.setMarkDragging(false);
            globalSignal.markPointDragging(false);
            ShortcutObserver.disableAllShortcut(false);
            if (ribbon) {
                ribbon.endAutoScroll(markItem);
            }
            if (ribbonVm) {
                ribbonVm.endMarkSnap();
            }
        }
        // delegate 销毁时（模型重建/撤销）hoverHandler 不再发 onHoveredChanged，手动从 ribbon 仲裁表移除
        if (ribbon && hoverHandler.hovered) ribbon.onMarkHoverLeave(markItem);
    }

    Image {
        id: iconImage
        // 选中态直接换预染色图(无 MultiEffect/ColorOverlay)：每标记挂一个 effect 节点常驻 shader/FBO 不划算(Repeater 全量、可达数千标记)，
        // 换图零额外渲染节点、放大同样清晰。选中优先于 debug 备用图(备用图无选中态)。
        source: markItem.isSelected ? "qrc:/icons/markPoint/ic_mark_point_selected.svg"
                                    : (Instance.debugMarkPointUseAltIcon ? "qrc:/icons/markPoint/ic_mark_point_2.svg" : "qrc:/icons/markPoint/ic_mark_point.svg")
        width: markItem.iconWidth
        height: markItem.iconHeight
        // 栅格化分辨率随显示尺寸×dpr(高dpi清晰、低dpi不浪费纹理)；dpr 向上取整保证非整数缩放时不发虚
        sourceSize.width: markItem.iconWidth * Math.ceil(Screen.devicePixelRatio)
        sourceSize.height: markItem.iconHeight * Math.ceil(Screen.devicePixelRatio)
        smooth: true
        transformOrigin: Item.Bottom
        // hover 或拖动中放大 1.2 倍（等比 scale）；选中态持续放大；拖动时标签与光标分离也保持放大，不闪烁；
        // 悬停落在指示器头上时不放大（让位给指示器头）
        scale: ((markItem.isHoveredAndActive && !markItem.overIndicator) || markItem.dragging || markItem.isSelected) ? 1.2 : 1.0
        // 放大动画：仅由状态切换触发的过渡
        Behavior on scale {
            NumberAnimation { duration: markItem.selectAnimDuration }
        }
    }

    // 由光标在 ribbon 坐标系下的 x 算出量化落帧并写回拖动态（onPositionChanged 与自动滚动定时器共用，保证两条路径一致）
    function applyDragToCursorInRibbon(cursorXInRibbon) {
        // 与 pushHoverPreview 一致：pxPerFrame 未就绪(=0)时直接返回，避免除零产生 NaN/Infinity 帧号
        if (pxPerFrame <= 0) {
            return;
        }
        // 与时间指示器一致：按整帧量化(round(realX/scaleBase))，标记一格一格地移动
        let rawCenterX = startX + (cursorXInRibbon - pressCursorX) + width / 2;
        let frame = Math.max(0, Math.round(rawCenterX / pxPerFrame));
        // 右侧上界先钳制，再吸附：避免光标越过边界时以界外帧号查吸附、在标签停在边界处时错误显示吸附线
        let cap = (maxDragFrame >= 0) ? maxDragFrame : ribbonVm.maxClipDisplayFrame();
        if (cap >= 0) {
            frame = Math.min(frame, cap);
        }
        // 反向吸附到片段头/尾/时间指示器（关吸附/未命中时原样返回）
        frame = Math.max(0, ribbonVm.snapClipDisplayFrame(frame));
        dragFrame = frame;
        dragX = clampedDragX(frame);
        // 拖动中把目标帧推给预览轴（竖线跟随拖动 + 画面 previewSeek，时间指示器不动），与 hover 共用同一路径
        ribbonVm.previewAtDisplayFrame(frame);
    }

    // 标记中心在 viewport([0, scroller.width])内。
    function clampedDragX(frame) {
        let centerContent = frame * pxPerFrame;   // 标记中心在 ribbon 内容坐标
        if (ribbon && ribbon.scroller) {
            let s = ribbon.scroller;
            let centerVp = ribbon.mapToItem(s, centerContent, 0).x;
            let clampedVp = Math.max(0, Math.min(centerVp, s.width));
            if (clampedVp !== centerVp) {
                centerContent = s.mapToItem(ribbon, clampedVp, 0).x;
            }
        }
        return centerContent - width / 2;
    }

    function applyDragFromViewportX(viewportX) {
        let s = ribbon.scroller;
        let clampedX = Math.min(viewportX, s.width - autoScrollEdge);
        let cursorInRibbon = s.mapToItem(ribbon, clampedX, 0).x;
        applyDragToCursorInRibbon(cursorInRibbon);
    }

    // 自动滚动定时器每拍回调（由 ribbon 的共享 Timer 调用）：原始光标贴近 viewport 左/右边缘时滚动时间轴
    function autoScrollTick() {
        if (!dragging || ribbon === undefined || ribbon === null || !ribbon.scroller) {
            return;
        }
        let s = ribbon.scroller;
        let edge = autoScrollEdge;
        let step = 20;
        let speed = 0;
        let p = lastCursorViewportX;
        if (p < edge) {
            speed = (p - edge) / edge;                       // 负=向左滚
        } else if (s.width - edge < p) {
            speed = (p - (s.width - edge)) / edge;           // 正=向右滚
        } else {
            return;
        }
        // 标记已到拖动边界则不再滚动
        let cap = (maxDragFrame >= 0) ? maxDragFrame : ribbonVm.maxClipDisplayFrame();
        if (speed > 0 && cap >= 0 && dragFrame >= cap) {
            return;
        }
        if (speed < 0 && dragFrame <= 0) {
            let centerVp = ribbon.mapToItem(s, dragFrame * pxPerFrame, 0).x;  // 标记真实中心(数据位置)在 viewport 的 x
            if (centerVp >= 0) {
                return;
            }
        }
        s.scrollBy(speed * step, 0); // scrollBy 自带 min/max；到边界即不再滚动
        applyDragFromViewportX(lastCursorViewportX);
    }

    // hover 检测用非阻断 HoverHandler（blocking 默认 false）驱动放大/tooltip；MouseArea 只管按下/拖动/释放。
    // 标记会消费 hover、使下方 TrackFlickable 不再驱动预览轴，故由标记接管预览轴（悬停与拖动共用同一套）：
    //  ① previewActive(=hover 或拖动) 经 globalSignal.markPointPreviewActive 通知 TrackDock 保持预览轴可见；
    //     拖动期 hover 可能丢失，故含 dragging，避免拖动时预览轴消失（同悬停片段用 isClip 兜底）；
    //  ② hover 时 hoverCursorX 变化、拖动时 applyDragToCursorInRibbon 均调 previewAtDisplayFrame，
    //     把目标帧推给预览轴(竖线跟随+画面 previewSeek)，否则预览轴会停在标签旁不跟随。
    HoverHandler {
        id: hoverHandler
        // 被固定主轨遮挡时禁用(多轨道滚动，标记滑到固定主轨背景后不应再响应 hover)——须在 handler 直接门控，
        // 靠祖先 Item.enabled 传导对 HoverReceiver 不可靠。与指示器头重叠区由逐点 overIndicator/isOnTimeIndicator 让位，
        // 不整枚禁用(标记视觉在指示器头下方、仅头区让位，其余仍可操作，与轨道片段一致)。
        enabled: !(markItem.ribbon && markItem.ribbon.occludedByMainTrack)
        onHoveredChanged: {
            if (hovered) { if (markItem.ribbon) markItem.ribbon.onMarkHoverEnter(markItem); }
            else          { if (markItem.ribbon) markItem.ribbon.onMarkHoverLeave(markItem); }
        }
    }
    // 悬停点是否落在时间指示器"头"上：指示器头视觉(z61)压在标记(z60)之上，重叠处 hover 应只归指示器头，
    // 标记不放大/不弹 tooltip/不驱动预览轴，避免"指示器头在上、标记却仍同时响应 hover"。
    readonly property bool overIndicator: hoverHandler.hovered
                                          && isOnTimeIndicator(hoverHandler.point.position.x, hoverHandler.point.position.y)
    // 标记预览态：悬停(且非指示器头)或拖动期间由标记接管预览轴（保持可见 + 跟随）
    readonly property bool previewActive: (isHoveredAndActive && !overIndicator) || dragging
    onPreviewActiveChanged: globalSignal.markPointPreviewActive(previewActive)
    // 光标在标记内的 x（仅 isHoveredAndActive 时有效，否则置 -1）；变化即把光标所在帧推给预览轴
    readonly property real hoverCursorX: isHoveredAndActive ? hoverHandler.point.position.x : -1
    onHoverCursorXChanged: pushHoverPreview()

    // 把光标所在显示帧推给预览轴（VM 换算全局帧后移竖线+previewSeek）；拖动中不走此路（拖动走 applyDragToCursorInRibbon）。
    // 仅预览轴开启时悬停才跟随：预览轴关闭时悬停路过不应 seek（否则播放会从该标签开始）；点击/拖动不受此限。
    function pushHoverPreview() {
        if (!isHoveredAndActive || overIndicator || dragging || pxPerFrame <= 0 || !ribbonVm.hoverPreviewEnabled()) {
            return;
        }
        let cursorXInRibbon = markItem.mapToItem(ribbon, hoverHandler.point.position.x, 0).x;
        let frame = Math.max(0, Math.round(cursorXInRibbon / pxPerFrame));
        // 悬停预览轴吸附（含标记点/片段头尾/关键帧/指示器，不画线；关吸附/未命中原样返回），与轨道空白区预览一致
        frame = Math.max(0, ribbonVm.snapHoverPreviewDisplayFrame(frame));
        ribbonVm.previewAtDisplayFrame(frame);
    }

    // 按下/悬停点是否落在时间指示器"头"(可抓取针头)上：把点映射到指示器自身坐标系，命中即 x∈[0,width] 且 y∈[0,handleHeight]。
    // 只认指示器头(7×14)、不认下方细竖线——竖线交给标记(符合预期)。指示器视觉层(z61)压在标记带(z60)之上，
    // 但其交互区(刻度尺 rulerMouseArea / 轨道区 indicatorArea)在标记之下：onPressed 命中头时置 mouse.accepted=false
    // 让事件穿透到下层播放头拖动区(拖到指示器而非标记)；hover 命中头时由 overIndicator 抑制标记响应(放大/tooltip/预览轴)。
    // 指示器未注入/未启用/隐藏则返回 false（不让位）。
    function isOnTimeIndicator(localX, localY) {
        let ind = ribbon ? ribbon.indicatorItem : null;
        if (!ind || !ind.enabled || !ind.visible) {
            return false;
        }
        let p = markArea.mapToItem(ind, localX, localY);
        return p.x >= 0 && p.x <= ind.width && p.y >= 0 && p.y <= ind.handleHeight;
    }

    // 拖动收尾（真拖动才执行，幂等）：正常松手拖动分支与 onCanceled（失焦/grab 被抢/模型重建）共用。
    // 落点提交在 commitDrag，其内部末尾清标记选中高亮；没拖动时卫语句直接返回，故 onCanceled 无拖动即 no-op。
    function finishDrag() {
        if (!markItem.dragging) {
            return;
        }
        if (ribbon) {
            ribbon.endAutoScroll(markItem);
        }
        if (ribbonVm) {
            ribbonVm.endMarkSnap();
        }
        ribbonVm.commitDrag(model.id, dragFrame);
        markItem.dragging = false;
    }

    MouseArea {
        id: markArea
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        preventStealing: true
        // 被固定主轨遮挡时禁用(多轨道滚动，标记滑到固定主轨背景后不应再响应按下/点击)；
        // 与指示器头重叠区由 onPressed 内逐点 isOnTimeIndicator 让位(穿透给指示器)，非头区仍可按下/拖动，与轨道片段一致。
        enabled: !(markItem.ribbon && markItem.ribbon.occludedByMainTrack)

        onPressed: (mouse) => {
            // 与时间指示器重叠时让位：仅左键且按下点落在指示器命中区内才拒绝事件，使其穿透到下层播放头拖动区
            // (刻度尺 rulerMouseArea / indicatorArea)，从而拖动指示器而非标记；标记其余区域仍可拖动，右键菜单不受影响。
            if (mouse.button === Qt.LeftButton && isOnTimeIndicator(mouse.x, mouse.y)) {
                mouse.accepted = false;
                return;
            }
            // 仅左键按下置顶：右键只为开菜单，不应改变 z 序（避免右键无谓重排+写盘且不可撤销）。
            // 注意：选中态不在此设置——按下/拖动都不选中，只有点击(无拖动)或右键在 onReleased 才选中。
            if (mouse.button === Qt.LeftButton && ribbonVm) {
                ribbonVm.markPressed(model.id);
            }
            startX = markItem.x;
            dragX = markItem.x;
            pressCursorX = markItem.mapToItem(ribbon, mouse.x, 0).x;
        }

        onPositionChanged: (mouse) => {
            if (!markArea.pressed || markItem.playing || !(mouse.buttons & Qt.LeftButton)) {
                return;
            }
            let cursorX = markItem.mapToItem(ribbon, mouse.x, 0).x;
            if (!dragging && Math.abs(cursorX - pressCursorX) < 3) {
                return;
            }
            dragging = true;
            if (ribbon && ribbon.scroller) {
                lastCursorViewportX = markItem.mapToItem(ribbon.scroller, mouse.x, 0).x;
                ribbon.beginAutoScroll(markItem);
                applyDragFromViewportX(lastCursorViewportX);
            } else {
                applyDragToCursorInRibbon(cursorX);
            }
        }

        onReleased: (mouse) => {
            // 左键拖动进行中,忽略次要键(右键)松开:不中断拖动、不停自动滚动/吸附线、不弹菜单。
            // 否则拖动被静默丢弃(不走 commitDrag),标记弹回原位且菜单乱弹;左键最终松开才正常提交。
            if (markItem.dragging && mouse.button !== Qt.LeftButton) {
                return;
            }
            if (ribbon) {
                ribbon.endAutoScroll(markItem);
            }
            if (ribbonVm) {
                ribbonVm.endMarkSnap();  // 隐藏吸附线（落点/单击/右键都覆盖）
            }
            if (mouse.button === Qt.RightButton) {
                if (markItem.dragging) {
                    markItem.dragging = false;
                }
                // 右键只开菜单，不动任何选中态：不联动素材选中(否则会取消其它片段已选中的素材)，
                // 也不清标记高亮(右键选中态标记应保持高亮)。菜单删除走 targetId、与选中态无关。
                let p = markItem.mapToItem(ribbon, mouse.x, mouse.y);
                ribbon.openMenu(model.id, p.x, p.y);
                return;
            }
            if (dragging) {
                // 拖动落点提交（收尾统一走 finishDrag，与 onCanceled 共用）；commitDrag 内部清标记选中高亮
                markItem.finishDrag();
            } else {
                // 纯点击(无拖动)：seek + 选中本标记 + 联动选中其素材
                ribbonVm.seekTo(model.id);
                ribbonVm.selectMark(model.id);
            }
        }

        // 拖动中失焦(Alt+Tab)/grab 被抢/模型重建时 MouseArea 发 onCanceled(不发 onReleased)：
        // 走 finishDrag 与正常松手一致收尾，避免 dragging 卡 true 导致切回后无法再拖、残留放大态。
        // 没拖动时 finishDrag 卫语句直接返回（no-op，不 seek、不改选中）。
        onCanceled: markItem.finishDrag()
    }

    // hover tooltip
    Loader {
        id: tooltipLoader
        anchors.fill: parent
        // active 由 onTipWantedChanged 手动控制，以便淡出动画完整播放后再销毁
        active: false
        sourceComponent: LightToolTip {
            id: markTooltip
            pixelAligned: true
            liveBackground: false
            // visible 只在创建时 false→true 置一次(打开 Popup 并经 onVisibleChanged 触发 opacity 0→1 淡入)；
            // 之后保持 visible=true，显隐全靠 onTipWantedChanged 改 opacity，避免 visible=false 立即关闭 Popup 而看不到淡出
            visible: false
            z: 200
            delay: 0
            animationDuration: markItem.tipAnimDuration
            Component.onCompleted: markTooltip.visible = true
            contentItem: Column {
                spacing: 2
                Text {
                    font.pixelSize: 11
                    text: model.displayName
                    color: Colors.color_EEEEEE
                }
                Text {
                    font.pixelSize: 11
                    text: model.displayTime
                    color: Colors.color_999999
                }
            }
        }
    }

    // 淡出动画结束后再销毁懒加载的 tooltip（interval 与淡入淡出时长一致）
    Timer {
        id: tipDestroyTimer
        interval: markItem.tipAnimDuration
        onTriggered: tooltipLoader.active = false
    }

    // 需要显示→创建并淡入；不需要→淡出(只降 opacity，不动 visible 否则 Popup 立即关闭看不到淡出)，待动画结束由定时器销毁；
    // 淡出期间重新需要则把 opacity 拉回 1 淡回并取消销毁
    onTipWantedChanged: {
        if (tipWanted) {
            tipDestroyTimer.stop();
            tooltipLoader.active = true;
            if (tooltipLoader.item) {
                tooltipLoader.item.opacity = 1;
            }
        } else if (tooltipLoader.active && tooltipLoader.item) {
            tooltipLoader.item.opacity = 0;
            tipDestroyTimer.restart();
        }
    }
}
