import QtQuick 2.15
import Config 1.0

MouseArea {
    id: root

    required property GridView targetGridView
    required property bool showSelectState
    required property int columns
    required property real delegateWidth
    required property real delegateHeight
    required property real itemWidth
    required property real itemHeight

    signal selectStateChanged(bool active)
    signal dragSelectUpdated(rect selectRect)

    anchors.fill: parent
    anchors.rightMargin: 14
    parent: targetGridView
    acceptedButtons: Qt.LeftButton
    z: Number.MAX_SAFE_INTEGER
    propagateComposedEvents: true

    property real startX: 0
    property real startY: 0
    property real currentX: 0
    property real currentY: 0
    property real startContentY: 0
    property bool isDragSelect: false

    onClicked: (mouse) => {
        if (!isDragSelect) {
            mouse.accepted = false
        }
        isDragSelect = false
    }

    onPressedChanged: {
        if (!pressed) {
            scrollTimer.stop()
        }
    }

    onPressed: (mouse) => {
        if (pressed) {
            isDragSelect = false
            let point = mapToItem(targetGridView, Qt.point(mouse.x, mouse.y))
            startX = point.x
            startY = point.y
            currentX = startX
            currentY = startY
            startContentY = targetGridView.contentY
            scrollTimer.scrollDirectionY = 0
        }
    }

    onPositionChanged: (mouse) => {
        if (mouse.buttons === Qt.LeftButton) {
            let point = mapToItem(targetGridView, Qt.point(mouse.x, mouse.y))
            currentX = point.x
            currentY = point.y
            let parentPoint = mapToItem(targetGridView.parent, Qt.point(mouse.x, mouse.y))
            let edge = 30
            let distance = 5
            var speed = 0
            if (parentPoint.y < edge) {
                speed = (parentPoint.y - edge) / (edge * 2)
            } else if (targetGridView.parent.height - edge < parentPoint.y) {
                speed = (parentPoint.y + edge - targetGridView.parent.height) / (edge * 2)
            }
            scrollTimer.scrollDirectionY = speed * distance
            if (scrollTimer.scrollDirectionY !== 0 && !scrollTimer.running) {
                scrollTimer.start()
            } else if (scrollTimer.scrollDirectionY === 0 && scrollTimer.running) {
                scrollTimer.stop()
            }
        }
    }

    onCanceled: {
        scrollTimer.stop()
    }

    onReleased: {
        scrollTimer.stop()
    }

    Rectangle {
        id: bgSelectionRect
        parent: root.targetGridView.contentItem
        color: Colors.color_FFFFFF_10
        radius: 2
        border.width: 1
        border.color: Colors.color_FFFFFF_20
        z: Number.MAX_SAFE_INTEGER
        visible: root.pressed
        x: Math.min(root.startX, root.currentX)
        width: Math.abs(root.startX - root.currentX)
        y: Math.min(root.startY + root.startContentY,
                    root.currentY + root.targetGridView.contentY)
        height: Math.abs((root.startY + root.startContentY)
                         - (root.currentY + root.targetGridView.contentY))

        onWidthChanged: refreshDragSelect()
        onHeightChanged: refreshDragSelect()

        function refreshDragSelect() {
            if (!bgSelectionRect.visible || !root.pressed) {
                return
            }
            if (bgSelectionRect.width < 2 || bgSelectionRect.height < 2) {
                return
            }
            if (root.targetGridView.count === 0) {
                return
            }
            root.isDragSelect = true
            if (!root.showSelectState) {
                root.selectStateChanged(true)
            }
            var selectRect = Qt.rect(bgSelectionRect.x, bgSelectionRect.y, bgSelectionRect.width, bgSelectionRect.height)
            root.dragSelectUpdated(selectRect)
        }
    }

    Timer {
        id: scrollTimer
        interval: 20
        repeat: true
        running: false
        property real scrollDirectionY: 0
        onTriggered: {
            if (scrollDirectionY !== 0 && root.targetGridView.visible) {
                var maxContentY = Math.max(root.targetGridView.originY, root.targetGridView.contentHeight - root.targetGridView.height)
                var contentY = root.targetGridView.contentY + scrollDirectionY * 10
                contentY = Math.max(root.targetGridView.originY, Math.min(contentY, maxContentY))
                root.targetGridView.contentY = contentY
            }
        }
    }
}
