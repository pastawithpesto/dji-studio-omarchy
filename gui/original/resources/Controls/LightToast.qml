import QtQuick 2.15
import Config 1.0
import Qt5Compat.GraphicalEffects
import app_qrc 1.0

/**
 *  @File        : LightToast.qml
 *  @Brief       : toast的UI
 *  @Details     : 详细说明
 *  @Author      : pansy.guo
 *  @Date        : 2024-03-08 14:54:25
 */
Rectangle {
    id: toast

    signal hiding

    property real time: defaultTime // 消息显示的时长
    readonly property real defaultTime: 1000 // 消息默认显示的时长
    readonly property real fadeTime: 100 //淡入淡出的时长

    property real margin: 10

    anchors.horizontalCenter: parent.horizontalCenter
    width: fontMetrics.advanceWidth(textView.text) + 40
    height: fontMetrics.boundingRect(textView.text).height + 22
    radius: RadiusConfig.radius_4_88
    opacity: 0
    color: Colors.color_FFFFFF
    // 阴影
    layer.enabled: true
    layer.effect: DropShadow {
        horizontalOffset: 0
        verticalOffset: 0
        radius: 10
        color: Colors.color_000000_30
    }

    function show(text, duration = time) {
        if (text === "" || text === undefined || text === null) {
            logger.d("检查text");
        }
        anim.stop();
        textView.text = text;
        if (typeof duration !== "undefined") {
            if (duration >= 2 * fadeTime) {
                time = duration;
            } else {
                time = 2 * fadeTime;
            }
        } else {
            time = defaultTime;
        }
        anim.start();
    }

    Text {
        id: textView
        text: ""
        wrapMode: Text.Wrap
        horizontalAlignment: Text.AlignHCenter
        width: textView.implicitWidth
        height: textView.implicitHeight
        anchors.centerIn: parent
        font.pixelSize: 12
        color: Colors.color_141414
        FontMetrics {
            id: fontMetrics
            font: textView.font
        }
    }

    // SequentialAnimation on opacity可以理解为在某个元素上按顺序执行一系列控制不透明度的动画，这些动画可能会逐渐改变元素的不透明度，实现淡入淡出或其他不透明度变化效果
    SequentialAnimation on opacity {
        id: anim
        running: false

        NumberAnimation {
            to: 0.9
            duration: fadeTime
        }

        PauseAnimation {
            duration: time - 2 * fadeTime
        }

        NumberAnimation {
            to: 0
            duration: fadeTime
        }

        onRunningChanged: {
            if (!running) {
                hiding();
                // toast.destroy()
            }
        }
    }
}
