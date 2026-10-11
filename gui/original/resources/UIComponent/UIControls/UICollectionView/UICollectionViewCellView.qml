import QtQuick
import QtQuick.Window

Item {
    id: root
    property var viewModel: null
    default property alias content: contentArea.data

    property bool _isDragging: false
    property bool _wasDragging: false
    property point _dragStartPos: Qt.point(0, 0)
    readonly property int _dragThreshold: 5

    MouseArea {
        id: cellMouseArea
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: true
        preventStealing: true

        onPressed: (mouse) => {
            root._dragStartPos = Qt.point(mouse.x, mouse.y)
            if (root.viewModel) {
                if (mouse.button === Qt.RightButton) {
                    root.viewModel.handleRightClicked(mouse.modifiers)
                } else {
                    root.viewModel.handlePressed(mouse.button, mouse.modifiers)
                }
            }
        }

        onPositionChanged: (mouse) => {
            if (!pressed || root._isDragging) {
                if (root._isDragging && dragCoverLoader.item) {
                    var scenePos = cellMouseArea.mapToItem(null, mouse.x, mouse.y)
                    dragCoverLoader.item.x = scenePos.x - dragCoverLoader.item.width / 2
                    dragCoverLoader.item.y = scenePos.y - dragCoverLoader.item.height / 2
                    if (root.viewModel)
                        root.viewModel.handleDragPositionChanged(scenePos.x, scenePos.y)
                }
                return
            }
            if (!root.viewModel || !root.viewModel.isDraggable) return

            var dx = mouse.x - root._dragStartPos.x
            var dy = mouse.y - root._dragStartPos.y
            if (dx * dx + dy * dy > root._dragThreshold * root._dragThreshold) {
                root._isDragging = true
                root._wasDragging = true
                root.viewModel.handleDragStarted()
                dragCoverLoader.active = true

                if (dragCoverLoader.item) {
                    var scenePos = cellMouseArea.mapToItem(null, mouse.x, mouse.y)
                    dragCoverLoader.item.x = scenePos.x - dragCoverLoader.item.width / 2
                    dragCoverLoader.item.y = scenePos.y - dragCoverLoader.item.height / 2
                }
            }
        }

        onReleased: {
            if (root._isDragging) {
                root._isDragging = false
                var dropResult = (dragCoverLoader.item && dragCoverLoader.item.Drag)
                    ? dragCoverLoader.item.Drag.drop() : Qt.IgnoreAction
                if (root.viewModel) {
                    root.viewModel.handleDragEnded(dropResult !== Qt.IgnoreAction)
                }
                dragCoverLoader.active = false
                return
            }
            if (root.viewModel) {
                root.viewModel.handleReleased()
            }
        }

        onClicked: (mouse) => {
            if (root._wasDragging) {
                root._wasDragging = false
                return
            }
            if (root.viewModel) {
                root.viewModel.handleClicked(mouse.button, mouse.modifiers)
            }
        }

        onDoubleClicked: {
            if (root.viewModel) {
                root.viewModel.handleDoubleClicked()
            }
        }

        onEntered: {
            if (root.viewModel) {
                root.viewModel.handleHovered(true)
            }
        }

        onExited: {
            if (root.viewModel) {
                root.viewModel.handleHovered(false)
            }
        }
    }

    Item {
        id: contentArea
        anchors.fill: parent
        opacity: root._isDragging ? 0.4 : 1.0
        Behavior on opacity { NumberAnimation { duration: 150 } }
    }

    Loader {
        id: dragCoverLoader
        active: false
        sourceComponent: UICollectionViewDragCover {
            sourceItem: contentArea
            cellWidth: root.width
            cellHeight: root.height
            selectedCount: root.viewModel ? root.viewModel.selectedCount() : 1
            dragData: root.viewModel ? root.viewModel.dragData() : ({})
            dragSource: root
        }
    }
}
