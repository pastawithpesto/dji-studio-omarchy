import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.15
import Config 1.0
import Controls 1.0

/**
 * Created by whiskey.cao on 2024-02-06 .
 * ClassName : LightWindow
 * Description :定义Window基类
 * Copyright : ©2024 Light All Rights Reserved.
 */

ApplicationWindow {
    id: window
    visible: false
    // mac 参考 setupFramelessWindow 进而实现 FramelessWindowHint 否则会有 windowserver 占用异常的问题
    flags: CommonUtils.isWindows() ? Qt.Window | Qt.FramelessWindowHint : Qt.Window
    color: Colors.color_transparent
    //首次显示
    signal firstVisible
    // 是否是播放器全屏
    property bool isPlayerFullScreen: false
    //参数
    property var argument: ({})
    signal initArgument(var argument)
    property int resizeAreaSize: 8
    property bool dragging: false
    property bool savedLayerEnabled: false
    property bool savedLayerSmooth: false

    property int topPopupCount: 0
    // 弹窗数量变化信号
    Connections {
        target: globalSignal
        function onAddPopupQuantity() {
            topPopupCount++
        }
        function onReducePopupQuantity() {
            topPopupCount--
        }
    }

    //完成加载
    Component.onCompleted: {
        initArgument(argument);
        logger.d("[Startup] UI Loaded Completed")
    }

    //销毁
    Component.onDestruction: {
        console.log("onDestruction:" + this);
    }

    // 窗口可见性改变时的操作
    onVisibleChanged: {
        if (visible && d.isFirstVisible) {
            logger.d("[Startup] UI First Show")
            window.firstVisible();
            d.isFirstVisible = false;
            globalSignal.appFirstUIShow();
        }
    }

    // 开始拖拽
    function startDrag() {
        dragging = true
        if(CommonUtils.isWindows() === false){
            return;
        }
        // 保存当前状态
        savedLayerEnabled = content.layer.enabled
        savedLayerSmooth = content.layer.smooth

        // 设置拖拽优化
        content.layer.enabled = true
        content.layer.smooth = false
    }

    // 结束拖拽
    function stopDrag() {
        dragging = false
        windowSizeManager.saveWindowGeometrySettings()

        if(CommonUtils.isWindows() === false){
            return;
        }
        // 恢复所有记录的状态
        content.layer.enabled = savedLayerEnabled
        content.layer.smooth = savedLayerSmooth
    }

    QtObject {
        id: d
        property bool isFirstVisible: true
    }

    // 窗口边界颜色
    Rectangle {
        id: windowBorder
        anchors.fill: parent
        color: CommonUtils.isWindows() ? Colors.color_141414 : Colors.transparent
        border.color: Colors.color_56575B
        border.width: 1
        radius: 10
        antialiasing: true
        visible: !isPlayerFullScreen
    }
    // 顶部调整大小区域
    ResizeArea {
        id: topResizeArea
        anchors.left: topLeftResizeArea.right
        anchors.right: topRightResizeArea.left
        anchors.top: parent.top
        height: resizeAreaSize
        z: 65535

        mouseArea.cursorShape: Window.window.visibility === Window.FullScreen ? Qt.ArrowCursor : Qt.SizeVerCursor
        mouseArea.onPositionChanged: {
            windowSizeManager.resizeWindowBasedOnCursor(Qt.TopEdge);
        }
        mouseArea.onPressed:  window.startDrag()
        mouseArea.onReleased: window.stopDrag()
        mouseArea.onCanceled: window.stopDrag()

    }
    // 底部调整大小区域
    ResizeArea {
        id: bottomResizeArea
        anchors.left: bottomLeftResizeArea.right
        anchors.right: bottomRightResizeArea.left
        anchors.bottom: parent.bottom
        height: resizeAreaSize
        z: 65535

        mouseArea.cursorShape: Window.window.visibility === Window.FullScreen ? Qt.ArrowCursor : Qt.SizeVerCursor
        mouseArea.onPositionChanged: {
            windowSizeManager.resizeWindowBasedOnCursor(Qt.BottomEdge);
        }
        mouseArea.onPressed:  window.startDrag()
        mouseArea.onReleased: window.stopDrag()
        mouseArea.onCanceled: window.stopDrag()
    }
    // 左侧调整大小区域
    ResizeArea {
        id: leftResizeArea
        anchors.left: parent.left
        anchors.top: topLeftResizeArea.bottom
        anchors.bottom: bottomLeftResizeArea.top
        width: resizeAreaSize
        z: 65535
        mouseArea.cursorShape: Window.window.visibility === Window.FullScreen ? Qt.ArrowCursor : Qt.SizeHorCursor
        mouseArea.onPositionChanged: {
            windowSizeManager.resizeWindowBasedOnCursor(Qt.LeftEdge);
        }
        mouseArea.onPressed:  window.startDrag()
        mouseArea.onReleased: window.stopDrag()
        mouseArea.onCanceled: window.stopDrag()
    }

    // 右侧调整大小区域
    ResizeArea {
        id: rightResizeArea
        anchors.right: parent.right
        anchors.top: topRightResizeArea.bottom
        anchors.bottom: bottomRightResizeArea.top
        width: resizeAreaSize
        z: 65535

        mouseArea.cursorShape: Window.window.visibility === Window.FullScreen ? Qt.ArrowCursor : Qt.SizeHorCursor
        mouseArea.onPositionChanged: {
            windowSizeManager.resizeWindowBasedOnCursor(Qt.RightEdge);
        }
        mouseArea.onPressed:  window.startDrag()
        mouseArea.onReleased: window.stopDrag()
        mouseArea.onCanceled: window.stopDrag()
    }

    // 左上角调整大小区域
    ResizeArea {
        id: topLeftResizeArea
        anchors.left: parent.left
        anchors.top: parent.top
        width: resizeAreaSize
        height: resizeAreaSize
        z: 65535

        mouseArea.cursorShape: Window.window.visibility === Window.FullScreen ? Qt.ArrowCursor : Qt.SizeFDiagCursor
        mouseArea.onPositionChanged: {
            windowSizeManager.resizeWindowBasedOnCursor(Qt.LeftEdge | Qt.TopEdge);
        }
        mouseArea.onPressed:  window.startDrag()
        mouseArea.onReleased: window.stopDrag()
        mouseArea.onCanceled: window.stopDrag()
    }

    // 右上角调整大小区域
    ResizeArea {
        id: topRightResizeArea
        anchors.right: parent.right
        anchors.top: parent.top
        width: resizeAreaSize
        height: resizeAreaSize
        z: 65535

        mouseArea.cursorShape: Window.window.visibility === Window.FullScreen ? Qt.ArrowCursor : Qt.SizeBDiagCursor
        mouseArea.onPositionChanged: {
            windowSizeManager.resizeWindowBasedOnCursor(Qt.RightEdge | Qt.TopEdge);
        }
        mouseArea.onPressed:  window.startDrag()
        mouseArea.onReleased: window.stopDrag()
        mouseArea.onCanceled: window.stopDrag()
    }

    // 左下角调整大小区域
    ResizeArea {
        id: bottomLeftResizeArea
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        width: resizeAreaSize
        height: resizeAreaSize
        z: 65535
        mouseArea.cursorShape: Window.window.visibility === Window.FullScreen ? Qt.ArrowCursor : Qt.SizeBDiagCursor
        mouseArea.onPositionChanged: {
            windowSizeManager.resizeWindowBasedOnCursor(Qt.LeftEdge | Qt.BottomEdge);
        }
        mouseArea.onPressed:  window.startDrag()
        mouseArea.onReleased: window.stopDrag()
        mouseArea.onCanceled: window.stopDrag()
    }

    // 右下角调整大小区域
    ResizeArea {
        id: bottomRightResizeArea
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: resizeAreaSize
        height: resizeAreaSize
        z: 65535
        mouseArea.cursorShape: Window.window.visibility === Window.FullScreen ? Qt.ArrowCursor : Qt.SizeFDiagCursor
        mouseArea.onPositionChanged: {
            windowSizeManager.resizeWindowBasedOnCursor(Qt.RightEdge | Qt.BottomEdge);
        }
        mouseArea.onPressed:  window.startDrag()
        mouseArea.onReleased: window.stopDrag()
        mouseArea.onCanceled: window.stopDrag()
    }

    function saveWindowGeometrySettings() {
        if (dragging) {
            // 拖拽中不进行数据存储
            return;
        }
        windowSizeManager.saveWindowGeometrySettings()
    }

    onWidthChanged: saveWindowGeometrySettings()
    onHeightChanged: saveWindowGeometrySettings()
    onXChanged: saveWindowGeometrySettings()
    onYChanged: saveWindowGeometrySettings()
}
