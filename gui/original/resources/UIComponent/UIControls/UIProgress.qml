import QtQuick
import UIComponent

// UIProgress
//   value: 0.0 ~ 1.0（当前进度）
//   type:  UIProgressType.Default / .Danger / .Success
Item {
    id: root

    property real value: 0.0           // 0.0 ~ 1.0
    property int  type: UIProgressType.Default
    property int size: UIControlSize.M

    readonly property var _style: UITheme.progress.of(type)

    property color fillColor:  _style.fillColor
    property color trackColor: _style.trackColor
    property int   trackHeight:_style.trackHeight

    implicitHeight: trackHeight
    implicitWidth:  UISize.progressWidth

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.trackColor

        Rectangle {
            width: Math.max(0, Math.min(1, root.value)) * parent.width
            height: parent.height
            radius: parent.radius
            color: root.fillColor
        }
    }
}
