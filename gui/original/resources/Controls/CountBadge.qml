import QtQuick 2.15

Rectangle {
    id: countBadge

    property real count: 0
    property color badgeColor: "red"
    property color badgeBorderColor: "transparent"
    property real badgeBorderWidth: 0
    property color textColor: "white"
    property real plusWidth: 3
    property real plusHeight: 8

    readonly property bool hasPlus: count > 99
    readonly property string displayText: hasPlus ? "99" : count.toString()

    width: count > 9 ? 18 : 14
    height: 12
    radius: height / 2
    color: badgeColor
    border.width: badgeBorderWidth
    border.color: badgeBorderColor

    Row {
        anchors.centerIn: parent
        height: parent.height
        spacing: 0

        Text {
            height: parent.height
            text: countBadge.displayText
            font.pixelSize: countBadge.hasPlus ? 8 : 9
            color: countBadge.textColor
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        Text {
            width: countBadge.plusWidth
            height: countBadge.plusHeight
            anchors.verticalCenter: parent.verticalCenter
            text: "+"
            font.pixelSize: 4
            color: countBadge.textColor
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            visible: countBadge.hasPlus
        }
    }
}
