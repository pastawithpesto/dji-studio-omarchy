import QtQuick 2.15
import QtQuick.Controls 2.15

import Config 1.0

Rectangle {
    id: voiceSlider

    property color backgroundColor: Colors.color_202020
    property color accentColor: Colors.color_9F9E9F
    property color baseColor: Colors.color_3F3E3F
    property color handleColor: Colors.color_FFFFFF
    property real trackWidth: 4
    property real trackHeight: 66
    property real handleSize: 12
    property alias volume: slider.value

    implicitWidth: 32
    implicitHeight: 93
    radius: 8
    color: backgroundColor

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.AllButtons
        preventStealing: true
        onWheel: (wheel) => { wheel.accepted = true }
    }

    Slider {
        id: slider

        orientation: Qt.Vertical
        from: 0
        to: 100
        stepSize: 1
        value: 100

        implicitWidth: handleSize
        implicitHeight: trackHeight
        anchors.centerIn: parent

        background: Rectangle {
            x: slider.leftPadding + (slider.availableWidth - width) / 2
            y: slider.topPadding
            implicitWidth: trackWidth
            implicitHeight: slider.availableHeight
            width: implicitWidth
            height: slider.availableHeight
            color: baseColor
            radius: width / 2

            Rectangle {
                width: parent.width
                height: (1 - slider.visualPosition) * parent.height
                color: accentColor
                radius: width / 2
                anchors.bottom: parent.bottom
            }
        }

        handle: Rectangle {
            x: slider.leftPadding + (slider.availableWidth - width) / 2
            y: slider.topPadding + slider.visualPosition * (slider.availableHeight - height)

            width: handleSize
            height: handleSize
            radius: width / 2
            color: handleColor
        }
    }
}
