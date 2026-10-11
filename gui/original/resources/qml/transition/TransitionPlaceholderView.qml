/**
    * @author: congmu.li
    * @details: 转场占位符组件
    * @date: 2025-11-17
    */

import QtQuick 2.15
import QtQuick.Controls
import Config 1.0

Rectangle {
    id: placeholderItem

    property real rootHeight: 64
    property int currentZIndex: 0
    property int zIndexTransition: 10
    property Item rootItem: null
    property real pxPerFrame: 0
    property int outputFps: 30
    property double maxDuration: 27000

    // 计算属性：动态计算宽度
    readonly property real calculatedWidth: {
        if (pxPerFrame <= 0 || maxDuration <= 0) {
            return TransitionConstants.minTransitionWidth;
        }

        var oneFrameToTimes = TransitionConstants.oneFrameDuration(outputFps);
        // 向下取整 和转场拖动的长度保持一致
        var frames = Math.floor(maxDuration / oneFrameToTimes);
        var width = frames * pxPerFrame;

        return Math.max(width, TransitionConstants.minTransitionWidth);
    }

    width: calculatedWidth
    height: rootHeight
    z: currentZIndex + zIndexTransition

    color: Colors.color_80000000
    radius: 4
    border.width: 0

    x: rootItem ? rootItem.x + rootItem.width - placeholderItem.width / 2 : 0
    y: rootItem ? rootItem.y : 0
}
