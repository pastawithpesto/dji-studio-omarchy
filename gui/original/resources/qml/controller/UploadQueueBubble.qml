import QtQuick 2.15
import QtQuick.Controls
import Controls 1.0
import Config 1.0

Popup {
    id: root
    modal: false
    closePolicy: Popup.NoAutoClose
    padding: 0
    background: null
    parent: Overlay.overlay
    height: bubbleTip.height

    property int fileCount: 0
    property real originY: 0
    property int floatOffset: 4

    function showBubble(count, anchorItem) {
        globalSignal.toast(qsTr("pccut_upload_queue_bubble_tip").arg(count), "cloudAlbum")
        return
        if (!cloudAlbumFeatureFlags.enable) {
            return
        }
        fileCount = count
        var bubbleWidth = Math.ceil(bubbleTextMetrics.width) + 16
        width = bubbleWidth
        var pos = anchorItem.mapToItem(Overlay.overlay, 0, anchorItem.height + 2)
        x = pos.x + anchorItem.width / 2 - bubbleWidth / 2
        originY = pos.y
        y = pos.y
        open()
        restartFloatAnimation()
        closeTimer.restart()
    }

    function restartFloatAnimation() {
        floatAnimation.stop()
        y = originY
        floatAnimation.start()
    }

    function resetFloatAnimation() {
        floatAnimation.stop()
        y = originY
    }

    onClosed: resetFloatAnimation()
    onVisibleChanged: {
        if (!visible) {
            resetFloatAnimation()
        }
    }

    TextMetrics {
        id: bubbleTextMetrics
        font.pixelSize: 12
        font.weight: Font.Medium
        text: qsTr("pccut_upload_queue_bubble_tip").arg(root.fileCount)
    }

    SequentialAnimation {
        id: floatAnimation
        loops: root.visible ? Animation.Infinite : 0
        NumberAnimation {
            target: root
            property: "y"
            from: root.originY
            to: root.originY + root.floatOffset
            duration: 300
            easing.type: Easing.InOutQuad
        }
        NumberAnimation {
            target: root
            property: "y"
            from: root.originY + root.floatOffset
            to: root.originY
            duration: 300
            easing.type: Easing.InOutQuad
        }
    }

    BaseNotificationTips {
        id: bubbleTip
        width: root.width
        text: qsTr("pccut_upload_queue_bubble_tip").arg(root.fileCount)
        arrowPosition: 1
        showArrow: true
        arrowLeftMargin: width / 2
        arrowSource: "qrc:/icons/panorama/transition_effect_arrow_white.svg"
        backgroundColor: Colors.color_EEEEEE
        textColor: Colors.color_141414
        fontSize: 12
        fontWeight: Font.Medium
        lineHeight: 16
        letterSpacing: 0
        enableBlur: false
        contentTopMargin: 7
        contentBottomMargin: 7
        textWrapMode: Text.NoWrap
    }

    Timer {
        id: closeTimer
        interval: 5000
        repeat: false
        onTriggered: root.close()
    }
}
