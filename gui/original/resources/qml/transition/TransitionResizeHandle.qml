/**
 * @author: congmu.li
 * @details: 转场拖动调整手柄（可复用组件）
 * @date: 2025-12-02
 */

import QtQuick 2.15
import QtQuick.Controls
import Config 1.0

Item {
    id: resizeHandle

    // 公共属性
    property bool isLeftHandle: true  // true=左侧手柄，false=右侧手柄
    property bool isSelected: false
    property bool isDragging: false
    property int handleWidth: TransitionConstants.clipAreaWidth
    property real parentWidth: parent ? parent.width : 0  // 父转场的宽度

    // 绑定到父转场的属性
    property var viewModel: null
    property real pxPerFrame: 0
    property int oneFrameToTimes: Math.round(1000000 / TransitionConstants.defaultFps)

    // 拖动状态
    property real startDuration: 0
    property real startWidth: 0
    property real dragPixelDelta: 0
    property bool containsMouse: mouseArea.containsMouse


    function calculateHandleWidth() {
        var minHandleWidth = 1;
        var maxHandleWidth = TransitionConstants.clipAreaWidth;
        var transitionWidth = parentWidth;


        var threshold = maxHandleWidth * 2;
        if (transitionWidth < threshold) {
            var dynamicWidth = transitionWidth * 0.25;
            return Math.max(minHandleWidth, Math.min(dynamicWidth, maxHandleWidth));
        }

        return maxHandleWidth;
    }

    width: calculateHandleWidth()
    anchors.top: parent.top
    anchors.bottom: parent.bottom

    // 鼠标区域
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        enabled: resizeHandle.isSelected
    }

    // 覆盖层（提升 z-index）
    Item {
        id: overlay
        parent: resizeHandle.parent ? resizeHandle.parent.parent : null
        z: resizeHandle.parent ? resizeHandle.parent.z + TransitionConstants.zIndexClipArea : 0

        width: resizeHandle.width
        height: resizeHandle.parent ? resizeHandle.parent.height : 0
        visible: true  // 始终显示，允许未选中时也能拖动手柄

        function updatePosition() {
            if (!resizeHandle.parent || !resizeHandle) {
                return;
            }

            var offsetX = resizeHandle.isLeftHandle ? 0 : (resizeHandle.parent.width - resizeHandle.width);
            var globalPos = resizeHandle.parent.mapToItem(overlay.parent, offsetX, 0);
            overlay.x = globalPos.x;
            overlay.y = globalPos.y;
        }

        Component.onCompleted: {
            Qt.callLater(updatePosition);
        }

        Connections {
            target: resizeHandle.parent
            function onXChanged() { overlay.updatePosition(); }
            function onYChanged() { overlay.updatePosition(); }
            function onWidthChanged() {
                if (!resizeHandle.isLeftHandle) {
                    overlay.updatePosition();
                }
            }
        }

        Connections {
            target: resizeHandle
            function onWidthChanged() { overlay.updatePosition(); }
        }

        Connections {
            target: lightWindow
            function onActiveChanged() {
                if (lightWindow.active && !resizeHandle.isDragging && !overlayMouseArea.containsMouse) {
                    cursorhelper.restoreOverrideCursor();
                }
            }
        }

        Component.onDestruction: {
            if (overlayMouseArea.containsMouse || resizeHandle.isDragging) {
                cursorhelper.restoreOverrideCursor();
            }
        }

        // 覆盖层鼠标区域
        MouseArea {
            id: overlayMouseArea
            anchors.fill: parent
            hoverEnabled: true
            enabled: parent.visible
            propagateComposedEvents: false

            property real startMouseGlobalX: 0

            onEntered: {
                if (!resizeHandle.isDragging) {
                    var cursorIcon = resizeHandle.isLeftHandle
                        ? TransitionConstants.cursorCutLeft
                        : TransitionConstants.cursorCutRight;
                    cursorhelper.setCustomCursor(cursorIcon, TransitionConstants.cursorSize, TransitionConstants.cursorSize);
                }
            }

            onExited: {
                if (!resizeHandle.isDragging) {
                    cursorhelper.restoreOverrideCursor();
                }
            }

            onPressed: (mouse) => {
                startMouseGlobalX = overlayMouseArea.mapToGlobal(mouse.x, mouse.y).x;
                resizeHandle.startDuration = viewModel.duration;
                resizeHandle.startWidth = resizeHandle.parent.width;
                resizeHandle.dragPixelDelta = 0;

                resizeHandle.isDragging = true;
                resizeHandle.dragStarted();
            }

            onReleased: {
                // 未产生位移的点击不写草稿：帧对齐会把原时长改成邻近帧值，白白改动节点并压入 undo 栈
                if (viewModel && resizeHandle.pxPerFrame > 0 && resizeHandle.dragPixelDelta !== 0) {
                    var deltaFrames = resizeHandle.dragPixelDelta / resizeHandle.pxPerFrame;

                    var deltaTime = deltaFrames * resizeHandle.oneFrameToTimes;

                    var newDuration = resizeHandle.startDuration + deltaTime;

                    var frames = Math.round(newDuration / resizeHandle.oneFrameToTimes);
                    var alignedDuration = frames * resizeHandle.oneFrameToTimes;

                    alignedDuration = Math.max(resizeHandle.oneFrameToTimes, alignedDuration);
                    alignedDuration = Math.min(viewModel.maxDuration, alignedDuration);

                    if (alignedDuration !== viewModel.duration) {
                        viewModel.duration = alignedDuration;
                    }
                }

                resizeHandle.isDragging = false;
                resizeHandle.dragPixelDelta = 0;

                if (!resizeHandle.containsMouse) {
                    cursorhelper.restoreOverrideCursor();
                }

                resizeHandle.dragEnded();
            }

            onPositionChanged: (mouse) => {
                if (resizeHandle.isDragging) {
                    var globalX = overlayMouseArea.mapToGlobal(mouse.x, mouse.y).x;
                    var deltaX = globalX - startMouseGlobalX;
                    // 转场以中心点为锚点双向扩展，宽度变化量是 handle 移动量的 2 倍
                    // 乘以 2 使 handle 与鼠标保持跟手
                    resizeHandle.dragPixelDelta = resizeHandle.isLeftHandle ? -deltaX * 2 : deltaX * 2;
                }
            }
        }
    }

    // 信号
    signal dragStarted()
    signal dragEnded()
}
