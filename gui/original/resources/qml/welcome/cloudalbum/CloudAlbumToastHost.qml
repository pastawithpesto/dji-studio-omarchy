import QtQuick 2.15
import Controls 1.0

Item {
    id: root

    readonly property string toastPanelName: "cloudAlbum"
    readonly property int toastSwitchDelayMs: 500
    property var toastQueue: []
    property bool toastShowing: false

    function showNextToast() {
        if (!root.visible || root.toastQueue.length === 0) {
            root.toastShowing = false
            return
        }

        var message = root.toastQueue.shift()
        console.log("[CloudAlbumToast] host shows toast",
                    "message=" + message,
                    "remaining=" + root.toastQueue.length)
        root.toastShowing = true
        cloudAlbumToast.showToastAtItem(message, root)
        toastSwitchTimer.restart()
    }

    function enqueueToast(message) {
        root.toastQueue.push(message)
        console.log("[CloudAlbumToast] host queued toast",
                    "message=" + message,
                    "queueSize=" + root.toastQueue.length)
        if (!root.toastShowing) {
            root.showNextToast()
        }
    }

    onVisibleChanged: {
        if (!root.visible) {
            root.toastQueue = []
            root.toastShowing = false
            toastSwitchTimer.stop()
        }
    }

    LightToastManager {
        id: cloudAlbumToast
        objectName: "cloudAlbumToast"
    }

    Timer {
        id: toastSwitchTimer
        interval: root.toastSwitchDelayMs
        repeat: false
        onTriggered: {
            root.toastShowing = false
            root.showNextToast()
        }
    }

    Connections {
        target: globalSignal
        function onToast(message, panelName) {
            console.log("[CloudAlbumToast] host received",
                        "panel=" + panelName,
                        "visible=" + root.visible,
                        "message=" + message)
            if (panelName !== root.toastPanelName || !root.visible) {
                console.log("[CloudAlbumToast] host skipped")
                return
            }
            root.enqueueToast(message)
        }
    }
}
