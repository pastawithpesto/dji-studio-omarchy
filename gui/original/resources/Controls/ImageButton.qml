import QtQuick 2.15
import QtQuick.Controls

Button {
    id: control
    property string normalImage: ""
    property string hoveredImage: ""
    property string pushedImage: ""
    property string disabledImage: ""
    property bool customHovered: false

    background: Item {
        implicitHeight: 12
        implicitWidth: 12

        BorderImage {
            anchors.fill: parent
            source: control.getImageSource()
        }
    }

    function getImageSource() {
        if (!control.enabled) {
            return control.disabledImage;
        }
        if (control.pressed) {
            return control.pushedImage;
        }
        if (control.hovered || control.customHovered) {
            return control.hoveredImage;
        }
        return control.normalImage;
    }
}