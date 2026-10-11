import QtQuick
import Qt5Compat.GraphicalEffects

import Config 1.0

Item {
    id: root
    property alias source: bg.source
    property int radius: 4

    width: 120
    height: 40

    layer.enabled: true
    layer.effect: OpacityMask {
        maskSource: Rectangle {
            width: root.width
            height: root.height
            radius: root.radius
            color: Colors.color_000000
        }
    }

    Image {
        id: bg
        anchors.fill: parent
        fillMode: Image.Stretch
        smooth: true
    }
}
