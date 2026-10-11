import QtQuick

Item {
    id: root
    objectName: "frameMetricsProbe"

    property bool collecting: false
    property var frameTimes: []
    property var smoothFrameTimes: []
    property double startTimeMs: 0
    property double endTimeMs: 0

    function startCollecting() {
        frameTimes = []
        smoothFrameTimes = []
        startTimeMs = Date.now()
        endTimeMs = 0
        collecting = true
    }

    function stopCollecting() {
        collecting = false
        endTimeMs = Date.now()
        return {
            "frameTimes": frameTimes,
            "smoothFrameTimes": smoothFrameTimes,
            "durationMs": Number(Math.max(0, endTimeMs - startTimeMs))
        }
    }

    FrameAnimation {
        running: root.collecting
        onTriggered: {
            root.frameTimes.push(frameTime * 1000)
            root.smoothFrameTimes.push(smoothFrameTime * 1000)
        }
    }
}
