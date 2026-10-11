import QtQuick 2.15
import QtQuick.Controls
import Config 1.0

Item {
    id: flickableRoot

    // 这个property不要删除，之所以声明的原因是如果之后想在本qml中调整content的顺序的话，调用者不需要做改动
    default property alias contentData: content.data
    property alias scrollBarHeight: scrollBar.height
    property alias contentItem: content

    required property real scaleBase

    // 之所以添加负号是因为正向滚动的时候，x和y为负值
    readonly property real contentX: -content.x
    readonly property real contentY: -content.y
    readonly property alias mouseX: mouseHandler.mouseX
    readonly property alias mouseY: mouseHandler.mouseY

    property real contentWidth: 0
    property real contentHeight: 0

    // TODO: yahui.li 好像有些鼠标滚轮是无极的，这个时候会发生什么呢？
    // 滚轮滚动一下移动的步长
    property real scrollStep: 50

    property alias containsMouse: mouseHandler.containsMouse

    // 是否正在裁切片段
    property bool isFragmentClipping: false
    // 打开草稿恢复滚动位置时的目标绝对 contentX; <0 表示无待恢复目标。
    // 布局(scaleBase→宽度)可能跨多个 tick 才定稿, 期间 maxX 处于中间态,
    // 记录目标并由 refreshScrollPosition 在每次范围变化时朝目标复位, 到位即清除。
    property real _pendingRestoreX: -1

    // 缩放意图
    signal trackScale(real scale)
    // 点击意图
    signal trackClick(point position, real pressedY)
    // 刻度尺区域Y阈值（内容坐标），由外部设置
    property real rulerThresholdY: 0

    QtObject {
        id: _data

        property real minX: 0
        property real maxX: Math.max(0, contentWidth - width)
        property real minY: 0
        property real maxY: Math.max(0, contentHeight - height)

        onMinXChanged: {
            refreshScrollPosition();
        }
        onMaxXChanged: {
            if(!isFragmentClipping){
                refreshScrollPosition();
            }
        }
        onMinYChanged: {
            refreshScrollPosition();
        }
        onMaxYChanged: {
            refreshScrollPosition();
        }
    }

    // 用来响应使用触摸板缩放
    PinchArea {
        id: pinchHandler
        enabled: !editorManager.isInUserGuideStatus
        property real initScale: 1
        anchors.fill: parent
        onPinchStarted: {
            initScale = scaleBase;
        }

        onPinchUpdated: (pinch) => {
            let targetScale = pinch.scale * initScale;
            trackScale(targetScale);
        }
    }

    // 手势使用MouseArea而不是WheelHandler的原因是WheelHandler的惯性处理的有点问题
    // 用来响应触摸板滚动
    MouseArea {
        anchors.fill: parent
        scrollGestureEnabled: true

        onWheel: (wheel) => {
            const x = wheel.pixelDelta.x;
            const y = wheel.pixelDelta.y;
            scrollBy(-x, -y);
        }
    }

    // 用来响应鼠标事件
    MouseArea {
        id: mouseHandler
        anchors.fill: parent
        scrollGestureEnabled: false
        hoverEnabled: true
        // 记录按下时的内容坐标Y，用于判断是否在刻度尺区域
        property real pressedContentY: 0

        onPressed: (mouse) => {
            pressedContentY = mouse.y + contentY;
        }

        onWheel: (wheel) => {
            // 当且仅当同时按下cmd键的时候才会认为是缩放操作
            const scaleEvent = wheel.modifiers === Qt.ControlModifier;
            if (scaleEvent) {
                scaleByWheel(wheel);
                return;
            }
            scrollByWheel(wheel);
        }

        onClicked: (mouse) => {
            // 如果按下时在刻度尺区域，不发送trackClick信号，避免清除选中状态
            if (pressedContentY < rulerThresholdY) {
                return;
            }
            trackClick(Qt.point(mouse.x + contentX, mouse.y + contentY), pressedContentY);
        }

        // 通过鼠标滚轮缩放
        function scaleByWheel(wheel) {
            // 这里固定使用angle来作为缩放的步长，测试下来angle不受mac滚轮速度的影响
            const angle = wheel.angleDelta.y;
            // 普通情况下，滚轮转动15度，对于的值为120，这样就是为什么除以8的原因，至于是不是都是8，这个目前不太清楚，后续观察是否合理
            let pinchScale = angle / 8 / 360;
            if (pinchScale === 1) {
                return;
            }
            pinchScale = pinchScale > 0 ? 1 + pinchScale : 1 / (1 - pinchScale);
            trackScale(scaleBase * pinchScale);
        }

        // 通过鼠标滚轮滚动
        function scrollByWheel(wheel) {
            // 只有当且仅当同时按下alt键的时候才会进行水平滚动
            const hScrollEvent = wheel.modifiers === Qt.AltModifier;
            const vScrollEvent = wheel.modifiers === Qt.NoModifier;
            // windows平台和mac平台拿到的数据不一样，当alt/opt按键按下的时候，mac上x为0，y有值，但是windows上x有值，y为0
            // 可以通过Qt.platform.os来判断平台从而使用不同的值，这里取巧直接相加，因为也仅仅是判断一个符号而已
            const angle = wheel.angleDelta.x + wheel.angleDelta.y;
            const sign = angle > 0 ? -1 : 1;
            scrollBy(hScrollEvent ? sign * scrollStep : 0, vScrollEvent ? sign * scrollStep : 0);
        }
    }

    // 正向滚动x和y，x,y为distance
    // 此处滚动会优先滚动幅度大的方向，限制只朝一个方向滚动
    function scrollBy(x, y) {
        if (x === 0 && y === 0) {
            return;
        }
        _pendingRestoreX = -1; // 任何主动滚动都优先于草稿恢复
        if (Math.abs(x) >= Math.abs(y)) {
            const targetX = Math.min(_data.maxX, Math.max(_data.minX, contentX + x));
            if (targetX != contentX) {
                content.x = -targetX;
            }
        } else {
            const targetY = Math.min(_data.maxY, Math.max(_data.minY, contentY + y));
            if (targetY != contentY) {
                content.y = -targetY;
            }
        }
    }

    // 同时滚动x和y
    function scrollWith(x, y) {
        scrollBy(x, 0);
        scrollBy(0, y);
    }

    // 恢复到绝对水平位置(打开草稿). 幂等: 多次调用/多个片段委托重复触发均安全。
    function restoreScrollX(targetX) {
        _pendingRestoreX = Math.max(0, targetX);
        refreshScrollPosition();
    }

    // 重新根据范围来做一下clamp操作
    function refreshScrollPosition() {
        // 有待恢复目标时朝目标钳制(而非当前 contentX), 使宽度定稿后能复位到期望位置。
        const desiredX = _pendingRestoreX >= 0 ? _pendingRestoreX : contentX;
        const targetX = Math.min(_data.maxX, Math.max(_data.minX, desiredX));
        if (targetX != contentX) {
            content.x = -targetX;
        }
        // 目标未被 maxX 钳制(已到位)则结束恢复; 否则等待宽度定稿后由 maxXChanged 再次触发。
        if (_pendingRestoreX >= 0 && targetX >= _pendingRestoreX) {
            _pendingRestoreX = -1;
        }
        const targetY = Math.min(_data.maxY, Math.max(_data.minY, contentY));
        if (targetY != contentY) {
            content.y = -targetY;
        }
    }
	
	// 水平双向滚动
    function scrollByX(x) {
        if (x === 0 ) {
            return;
        }
        _pendingRestoreX = -1;
        content.x -= x;
    }

    Item {
        id: content
        width: parent.width
        height: parent.height
    }

    ScrollBar {
        id: scrollBar
        policy: ScrollBar.AlwaysOn
        orientation: Qt.Horizontal
        // 范围0-1，最大等于flickableRoot.width，最小30
        minimumSize: 30 / flickableRoot.width
        // 抽出比率独立属性：position 用它而非自身 size，断开 position→自身 size 自引用（缩放改 contentWidth 时同帧互触发的绑定环）
        readonly property real sizeRatio: flickableRoot.contentWidth > 0 ? flickableRoot.width / flickableRoot.contentWidth : 0
        size: sizeRatio
        // 范围0-1，之所以乘以(1-size)是因为不希望滚动条滚出去，就是如果position为1的话，滚动条就是完全滚出去了
        position: (contentWidth > flickableRoot.width ? contentX / (contentWidth - flickableRoot.width) : 0) * (1 - sizeRatio)

        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            rightMargin: vScrollBar.width
        }

        contentItem: Rectangle {
            implicitWidth: flickableRoot.width
            implicitHeight: 6
            radius: width / 2
            color: scrollBar.active ? Colors.color_575A5B_100 : Colors.color_414344_100
        }

        background: Rectangle {
            color: Colors.color_1F2021
        }

        onPositionChanged: {
            if (active) {
                // 这个是拖动引起的，此时需要滚动TrackFlickable
                const newContentX = getContentXByPosition();
                scrollBy(newContentX - contentX, 0);
            }
        }

        function getPositionByContentX() {
            return contentWidth <= flickableRoot.width ? 0 : (contentX / (contentWidth - flickableRoot.width)) * (1 - size);
        }

        function getContentXByPosition() {
            // 其实contentWidth <= flickableRoot.width 和 size == 1 是一回事
            return (contentWidth <= flickableRoot.width || size == 1) ? 0 : position / (1 - size) * (contentWidth - flickableRoot.width);
        }
    }

    // 垂直滚动条
    ScrollBar {
        id: vScrollBar
        policy: ScrollBar.AsNeeded
        orientation: Qt.Vertical
        // 垂直滚动条的最小尺寸
        minimumSize: 30 / flickableRoot.height
        // 同水平条：抽出比率独立属性供 position 用，断开 position→自身 size 自引用的绑定环
        readonly property real sizeRatio: flickableRoot.contentHeight > 0 ? flickableRoot.height / flickableRoot.contentHeight : 0
        size: sizeRatio
        position: (contentHeight > flickableRoot.height ? contentY / (contentHeight - flickableRoot.height) : 0) * (1 - sizeRatio)

        anchors {
            top: parent.top
            right: parent.right
            bottom: parent.bottom
            bottomMargin: scrollBar.height  // 为水平滚动条预留空间
        }

        contentItem: Rectangle {
            implicitWidth: 6
            implicitHeight: flickableRoot.height
            radius: height / 2
            color: vScrollBar.active ? Colors.color_575A5B_100 : Colors.color_414344_100
        }

        background: Rectangle {
            color: Colors.color_1F2021
        }

        onPositionChanged: {
            if (active) {
                // 这个是拖动引起的，此时需要滚动TrackFlickable
                const newContentY = getContentYByPosition();
                scrollBy(0, newContentY - contentY);
            }
        }

        function getPositionByContentY() {
            return contentHeight <= flickableRoot.height ? 0 : (contentY / (contentHeight - flickableRoot.height)) * (1 - size);
        }

        function getContentYByPosition() {
            // 其实contentHeight <= flickableRoot.height 和 size == 1 是一回事
            return (contentHeight <= flickableRoot.height || size == 1) ? 0 : position / (1 - size) * (contentHeight - flickableRoot.height);
        }
    }

    // 右下角遮罩，覆盖两个滚动条相交处的空白区域
    Rectangle {
        anchors {
            right: parent.right
            bottom: parent.bottom
        }
        width: vScrollBar.width
        height: scrollBar.height
        color: Colors.color_1F2021
        visible: vScrollBar.visible
    }
}
