import QtQuick 2.15
import QtQml 2.15
import Config 1.0
import Nova 1.0

Item {
    id: multiView
    property size itemSize: vm.itemSize
    property int itemSpace: 4
    readonly property alias previewMode: vm.previewMode

    function setPreviewMode(mode) {
        vm.setPreviewMode(mode)
    }

    function restorePreviewMode() {
        vm.restorePreviewMode()
    }

    function hideExtraViews() {
        vm.setExtraViewsVisible(false)
    }

    function showExtraViews() {
        vm.setExtraViewsVisible(true)
    }

    Component.onCompleted: {
        vm.updateSize(multiView.width, multiView.height)
    }

    onWidthChanged: resizeTimer.restart()
    onHeightChanged: resizeTimer.restart()

    Timer {
        id: resizeTimer
        interval: 0
        onTriggered: vm.updateSize(multiView.width, multiView.height)
    }

    PlayerMultiViewModel {
        id: vm
    }

    Column {
        id: list
        anchors.centerIn: parent
        spacing: itemSpace

        Repeater {
            model: vm.viewCount

            delegate: PlayerMultiItemView {
                multiView: vm
            }
        }
    }
}
