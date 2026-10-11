/**
 * @author: congmu.li
 * @details: 转场UI组件
 * @date: 2025-12-02
 */

import QtQuick 2.15
import QtQuick.Controls
import Config 1.0
import TransitionClipViewModel 1.0

Rectangle {
    id: transitionItem

    required property TransitionClipViewModel viewModel
    property real rootHeight: 64
    property int currentZIndex: 0
    property Item rootItem: null
    property real pxPerFrame: 0  // 每帧的像素宽度
    property int outputFps: 30  // 输出帧率
    property var dataProvider: null  //用于判断是否有片段选中

    // 内部属性
    property real itemGap: TransitionConstants.itemGap
    property int oneFrameToTimes: Math.round(1000000 / outputFps)
    property bool hasFragmentSelected: false  // 是否有片段被选中

    // 拖动状态标志和位置缓存
    property bool isDragging: leftHandle.isDragging || rightHandle.isDragging
    property real dragStartIconX: 0  // 拖动开始时图标的全局 x 位置

    signal requestDeactivate()

    function getDisplayWidth() {
        if (leftHandle.isDragging || rightHandle.isDragging) {
            var handle = leftHandle.isDragging ? leftHandle : rightHandle;

            var newWidth = handle.startWidth + handle.dragPixelDelta;

            var minWidthPixels = TransitionConstants.minTransitionWidth;
            var maxDurationFrames = viewModel.maxDuration * outputFps / 1000000;
            var maxWidthPixels = maxDurationFrames * pxPerFrame;

            newWidth = Math.max(minWidthPixels, newWidth);
            newWidth = Math.min(maxWidthPixels, newWidth);

            return newWidth;
        } else {
            return viewModel.width > 0 ? viewModel.width : TransitionConstants.minTransitionWidth;
        }
    }

    // 判断是否 hover
    property bool isHovered: mouseArea.containsMouse || (clickOverlay.visible && clickOverlay.overlayContainsMouse)

    width: getDisplayWidth()
    height: rootHeight
    z: currentZIndex + TransitionConstants.zIndexTransition
    color:  Colors.color_000000_60

    enabled: viewModel.isValid
    visible: viewModel.isValid
    x: rootItem && viewModel.isValid ? rootItem.x + rootItem.width - transitionItem.width / 2 : 0
    y: rootItem && viewModel.isValid ? rootItem.y : 0

    radius: 4

    border.color: viewModel.selected ? Colors.color_FFFFFF : Colors.color_FFFFFF_20
    border.width: viewModel.selected ? 2 : 1

    onEnabledChanged: {
        if (!enabled) {
            requestDeactivate();
        }
    }

    // 转场图标 - 使用独立容器避免被圆角裁剪
    Item {
        id: iconContainer
        anchors.fill: parent
        clip: false

        Image {
            id: transitionIcon
            width: TransitionConstants.transitionIconSize
            height: TransitionConstants.transitionIconSize
            source: TransitionConstants.transitionIconPath
            sourceSize: Qt.size(TransitionConstants.transitionIconSize, TransitionConstants.transitionIconSize)
            visible: transitionItem.width >= TransitionConstants.transitionIconSize + 4

            x: {
                if (transitionItem.isDragging) {
                    // 拖动时：固定在初始全局位置
                    return transitionItem.dragStartIconX - transitionItem.x - width / 2;
                } else {
                    // 非拖动时：完全居中
                    return (parent.width - width) / 2;
                }
            }
            y: (parent.height - height) / 2
        }
    }

    // 主鼠标区域（选中功能）
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        enabled: false 
        onClicked: viewModel.selected = true
    }

    // 当片段选中时的覆盖层，提升到更高层级以捕获鼠标事件
    // 同时避让中间区域，不挡住片段的裁切手柄
    // z-index 必须小于关键帧层，这样关键帧按钮才能在转场之上
    Item {
        id: clickOverlay
        parent: transitionItem.parent
        visible: true  
        z: transitionItem.z  //低于关键帧层

        width: transitionItem.width
        height: transitionItem.height
        x: transitionItem.x
        y: transitionItem.y

        property bool overlayContainsMouse: leftMouseArea.containsMouse || rightMouseArea.containsMouse || middleMouseArea.containsMouse

        MouseArea {
            id: leftMouseArea
            x: leftHandle.width
            y: 0
            width: {
                var centerGap = viewModel.selected ? 0 : TransitionConstants.clipAreaWidth;
                return Math.max(0, transitionItem.width / 2 - centerGap - leftHandle.width);
            }
            height: parent.height
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: viewModel.selected = true
        }

        // 中间区域，未选中时覆盖以阻止点击事件穿透到片段
        MouseArea {
            id: middleMouseArea
            x: transitionItem.width / 2 - TransitionConstants.clipAreaWidth
            y: 0
            width: TransitionConstants.clipAreaWidth * 2
            height: parent.height
            visible: !viewModel.selected  // 只在未选中时显示
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            enabled: viewModel.selected || !hasFragmentSelected
            onClicked: viewModel.selected = true
        }

        MouseArea {
            id: rightMouseArea
            x: {
                var centerGap = viewModel.selected ? 0 : TransitionConstants.clipAreaWidth;
                return transitionItem.width / 2 + centerGap;
            }
            y: 0
            width: {
                var centerGap = viewModel.selected ? 0 : TransitionConstants.clipAreaWidth;
                return Math.max(0, transitionItem.width / 2 - centerGap - rightHandle.width);
            }
            height: parent.height
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: viewModel.selected = true
        }
    }

    // 左侧调整手柄
    TransitionResizeHandle {
        id: leftHandle
        anchors.left: parent.left
        isLeftHandle: true
        isSelected: viewModel.selected
        viewModel: transitionItem.viewModel
        pxPerFrame: transitionItem.pxPerFrame
        oneFrameToTimes: transitionItem.oneFrameToTimes

        onDragStarted: {
            transitionItem.dragStartIconX = transitionItem.x + transitionItem.width / 2;
            viewModel.selected = true
        }
    }

    // 右侧调整手柄
    TransitionResizeHandle {
        id: rightHandle
        anchors.right: parent.right
        isLeftHandle: false
        isSelected: viewModel.selected
        viewModel: transitionItem.viewModel
        pxPerFrame: transitionItem.pxPerFrame
        oneFrameToTimes: transitionItem.oneFrameToTimes

        onDragStarted: {
            transitionItem.dragStartIconX = transitionItem.x + transitionItem.width / 2;
            viewModel.selected = true
        }
    }

    // 监听片段选中状态变化
    // nova: 选中真源为 nle，multiTrackView.novaSelectionChanged 随内核选中派发；
    // 老 globalSignal 信号仅在少数残留路径触发，作兜底。
    Connections {
        target: multiTrackView
        function onNovaSelectionChanged() {
            updateFragmentSelectedState();
        }
    }

    Connections {
        target: globalSignal
        function onMultiSelectStateChanged() {
            updateFragmentSelectedState();
        }
        function onVideoSelected() {
            updateFragmentSelectedState();
        }
    }

    // 更新片段选中状态
    function updateFragmentSelectedState() {
        if (dataProvider) {
            hasFragmentSelected = (dataProvider.getVideoSelectCount() > 0 || dataProvider.getAudioSelectCount() > 0);
        }
    }

    Component.onCompleted: {
        updateFragmentSelectedState();
    }

}
