
import QtQuick
import QtQuick.Controls
import QtQuick.Effects

import UIComponent

Item {
    id: root

    property EnumTabsViewModelProtocol viewModel: null

    // 布局参数
    property int spacing: 0
    property int orientation: ListView.Horizontal
    property int layoutDirection: Qt.LeftToRight

    property real minHeight: UISize.controlHeightXS  // 最小高度，可外部配置

    property real startPadding: 0  // 首尾的padding值，通过footer和header实现 不直接使用magins防止clip的时候无法滑动到边界
    property real endPadding: 0

    property real tabHorizontalPadding: 0
    property real tabVerticalPadding: 0

    property bool defaultSelectedFirst: true
    property bool interactive: false
    property bool canWheelAdjust: false // 当子项超过组件显示区域时，是否可以通过滚轮控制子项调整显示内容

    // 圆角裁剪，格式 [TL, TR, BR, BL]；非零时启用 layer 裁剪，使渐变阴影不溢出圆角
    property var   radius:  []
    property color bgColor: "transparent"
    readonly property bool _hasClipRadius: {
        for (let i = 0; i < radius.length; i++) {
            if (radius[i] > 0) return true
        }
        return false
    }

    // 滚动覆盖层：仅水平方向生效，默认关闭
    property bool showScrollOverlay: false
    property color scrollOverlayColor: UIColors.colorBgBar// 调用方按背景色传入，用于渐变遮罩
    property string scrollOverlayLeftIcon: UITheme.isolationIcon("Icon_Slider_Left.svg")        // 左箭头图标 URL
    property string scrollOverlayRightIcon: UITheme.isolationIcon("Icon_Slider_Right.svg")       // 右箭头图标 URL

    clip: true
    implicitWidth: orientation === ListView.Horizontal
        ? tabListView.contentWidth
        : tabListView.contentItem.childrenRect.width + root.startPadding + root.endPadding
    implicitHeight: Math.max(orientation === ListView.Horizontal ? tabListView.contentItem.childrenRect.height : tabListView.contentHeight, minHeight)

    ListView {
        id: tabListView

        property var tabViewModel: viewModel
        property int selectedIndex: viewModel ? viewModel.selectedIndex : defaultSelectedFirst ? 0 : -1

        readonly property int _vPolicy: (root.interactive && root.orientation === ListView.Vertical)
                                        ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
        readonly property int _hPolicy: (root.interactive && root.orientation === ListView.Horizontal)
                                        ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
        anchors.fill: parent
        anchors.leftMargin:  root.orientation === ListView.Horizontal ? 0 : root.startPadding
        anchors.rightMargin: root.orientation === ListView.Horizontal ? 0 : root.endPadding
        model: viewModel ? viewModel.tabItems : []
        spacing: root.spacing
        orientation: root.orientation
        layoutDirection: root.layoutDirection
        interactive: root.interactive || root.clip
        clip: root.clip
        boundsBehavior: Flickable.StopAtBounds
        delegate: viewModel && viewModel.config ? viewModel.config.tabItemViewDelegate : null

        header: Item {
                width:  root.orientation === ListView.Horizontal ? root.startPadding : 0
                height: root.orientation === ListView.Vertical   ? root.startPadding : 0
            }

        footer: Item {
                width:  root.orientation === ListView.Horizontal ? root.endPadding : 0
                height: root.orientation === ListView.Vertical   ? root.endPadding : 0
            }

        ScrollBar.vertical:   UIScrollBar { policy: tabListView._vPolicy }
        ScrollBar.horizontal: UIScrollBar { policy: tabListView._hPolicy }

        function centerSelectedTab(index) {
            if (root.orientation !== ListView.Horizontal) { return }
            if (contentWidth <= width) { return }

            var itemX = root.startPadding
            for (var i = 0; i < index; i++) {
                var prev = itemAtIndex(i)
                if (prev) { itemX += prev.width + root.spacing }
            }
            var current = itemAtIndex(index)
            if (!current) { return }

            var targetX = itemX + current.width / 2 - width / 2
            targetX = Math.max(originX, Math.min(targetX, contentWidth - width - root.endPadding))
            _scrollAnim.to = targetX
            _scrollAnim.start()
        }

        onSelectedIndexChanged: centerSelectedTab(selectedIndex)
    }

    WheelHandler {
        enabled: root.clip && root.canWheelAdjust
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            if (root.orientation === ListView.Horizontal) {
                var dx = event.angleDelta.x !== 0 ? event.angleDelta.x : event.angleDelta.y
                tabListView.contentX = Math.max(tabListView.originX,
                    Math.min(tabListView.contentWidth - tabListView.width,
                             tabListView.contentX - dx * 0.5))
            } else {
                tabListView.contentY = Math.max(tabListView.originY,
                    Math.min(tabListView.contentHeight - tabListView.height,
                             tabListView.contentY - event.angleDelta.y * 0.5))
            }
            event.accepted = true
        }
    }

    // --- 水平滚动覆盖层（showScrollOverlay=true 且 orientation=Horizontal 时生效）---

    HoverHandler {
        id: _overlayHover
        enabled: root.showScrollOverlay && root.orientation === ListView.Horizontal
    }

    NumberAnimation {
        id: _scrollAnim
        target: tabListView
        property: "contentX"
        duration: 200
        easing.type: Easing.OutCubic
    }

    readonly property bool _overlayActive: root.showScrollOverlay && root.orientation === ListView.Horizontal
    readonly property bool _canScroll: tabListView.contentWidth > tabListView.width
    readonly property bool _atStart: tabListView.contentX <= tabListView.originX
    readonly property bool _atEnd:   tabListView.contentX >= tabListView.contentWidth - tabListView.width - 0.5 - endPadding

    // 左侧渐变阴影
    Rectangle {
        x: 0
        y: 0
        width: 32
        height: parent.height
        visible: root._overlayActive && root._canScroll && !root._atStart
        z: 1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: root.scrollOverlayColor }
            GradientStop { position: 0.6; color: root.scrollOverlayColor }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    // 右侧渐变阴影
    Rectangle {
        x: parent.width - 32
        y: 0
        width: 32
        height: parent.height
        visible: root._overlayActive && root._canScroll && !root._atEnd
        z: 1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.4; color: root.scrollOverlayColor }
            GradientStop { position: 1.0; color: root.scrollOverlayColor }
        }
    }

    // 左侧箭头指示器
    Item {
        x: 0
        y: 0
        width: 20
        height: parent.height
        visible: root._overlayActive && root._canScroll && !root._atStart && _overlayHover.hovered
        z: 2

        HoverHandler { cursorShape: Qt.PointingHandCursor }
        TapHandler {
            onTapped: {
                _scrollAnim.to = tabListView.originX
                _scrollAnim.start()
            }
        }

        Image {
            anchors.centerIn: parent
            width: 16
            height: 16
            source: root.scrollOverlayLeftIcon
            sourceSize: Qt.size(16, 16)
            visible: root.scrollOverlayLeftIcon.length > 0
        }
    }

    // 右侧箭头指示器
    Item {
        x: parent.width - 20
        y: 0
        width: 20
        height: parent.height
        visible: root._overlayActive && root._canScroll && !root._atEnd && _overlayHover.hovered
        z: 2

        HoverHandler { cursorShape: Qt.PointingHandCursor }
        TapHandler {
            onTapped: {
                _scrollAnim.to = tabListView.contentWidth - tabListView.width - root.endPadding
                _scrollAnim.start()
            }
        }

        Image {
            anchors.centerIn: parent
            width: 16
            height: 16
            source: root.scrollOverlayRightIcon
            sourceSize: Qt.size(16, 16)
            visible: root.scrollOverlayRightIcon.length > 0
        }
    }

    UIRadiusRectangle {
        id: _bg
        anchors.fill: parent
        color: root.bgColor
        radius: root.radius
        visible: root.bgColor.a > 0
        z: -1
    }

    UIRadiusRectangle {
        id: _clipMask
        anchors.fill: parent
        color: "white"
        radius: root.radius
        visible: false
        layer.enabled: true
    }

    layer.enabled: root._hasClipRadius
    layer.effect: MultiEffect {
        maskEnabled: true
        maskSource: _clipMask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
    }
}
