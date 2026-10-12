import QtQuick
import QtQuick.Window

Item {
    id: dragCover

    property Item sourceItem: null
    property real cellWidth: 80
    property real cellHeight: 80
    property int selectedCount: 1
    property var dragData: ({})
    property var dragSource: null

    readonly property int coverStyle: dragSource && dragSource.viewModel
                                      ? dragSource.viewModel.dragCoverStyle : 0

    parent: Window.contentItem
    width: coverStyle === 0 ? cellWidth + stackOffset * stackCount : inTrackRect.width
    height: coverStyle === 0 ? cellHeight + stackOffset * stackCount : inTrackRect.height
    z: 999999

    readonly property int maxStackLayers: 2
    readonly property real stackOffset: 4
    readonly property int stackCount: Math.min(selectedCount - 1, maxStackLayers)

    Drag.active: true
    Drag.source: dragSource
    Drag.mimeData: dragData
    Drag.hotSpot: Qt.point(width / 2, height / 2)

    Repeater {
        model: coverStyle === 0 ? stackCount : 0

        Rectangle {
            required property int index
            property int ri: stackCount - 1 - index

            x: ri * dragCover.stackOffset
            y: ri * dragCover.stackOffset
            width: dragCover.cellWidth
            height: dragCover.cellHeight
            radius: 6
            color: "#555555"
            border.width: 1
            border.color: "#777777"
            opacity: 0.5
        }
    }

    ShaderEffectSource {
        visible: coverStyle === 0
        x: stackCount * dragCover.stackOffset
        y: stackCount * dragCover.stackOffset
        width: dragCover.cellWidth
        height: dragCover.cellHeight
        sourceItem: dragCover.sourceItem
        live: false
        opacity: 0.85
    }

    Rectangle {
        id: inTrackRect
        visible: coverStyle === 1
        width: {
            var w = dragSource && dragSource.viewModel ? dragSource.viewModel.dragCoverWidth : 0
            return w > 0 ? w : 55
        }
        height: 72
        color: "#4CFFFFFF"
        radius: 4

        Image {
            anchors.centerIn: parent
            width: 16
            height: 16
            visible: inTrackRect.width >= 17
            source: "qrc:/app_qrc/icons/tab_transition.svg"
        }
    }

    Rectangle {
        id: countBadge
        visible: coverStyle === 0 && dragCover.selectedCount > 3
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: -4
        anchors.topMargin: -4
        width: 22
        height: 22
        radius: 11
        color: "#E04040"
        z: 1

        Text {
            anchors.centerIn: parent
            text: dragCover.selectedCount
            color: "#FFFFFF"
            font.pixelSize: 11
            font.bold: true
        }
    }
}
