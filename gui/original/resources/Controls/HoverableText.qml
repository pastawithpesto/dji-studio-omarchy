import QtQuick 2.15

Text {
    id: textLabel
    property real maxTextWidth: 51
    property bool cursorChanged: true
    property bool noWarp: false
    property int lineCount:2
    property bool toastVisible: textLabel.implicitWidth > textLabel.width
    property alias containsMouse: mouseArea.containsMouse
    width: Math.min(implicitWidth, maxTextWidth)
    elide: Text.ElideRight
    wrapMode: noWarp ? Text.NoWrap : Text.Wrap
    maximumLineCount: lineCount
    lineHeight: font.pixelSize * 1.17
    lineHeightMode: Text.FixedHeight
    signal clicked
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: cursorChanged ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            textLabel.clicked();
        }
        LightToolTip {
            visible: mouseArea.containsMouse && toastVisible
            tip: textLabel.text
            z: 200
        }
    }
}
