import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.3

/**
 * Created by whiskey.cao on 2024-02-06 .
 * ClassName : LightFullArea
 * Description :子布局撑满区域
 * Copyright : ©2024 Light All Rights Reserved.
 */
Rectangle {
    default property alias content: container.data
    property int paddings : 0
    property int leftPadding : 0
    property int rightPadding : 0
    property int topPadding : 0
    property int bottomPadding : 0
    radius: 0
    color: "lightblue"
    border.color: "black"
    border.width: 0
    implicitHeight: height
    implicitWidth: width
    Item {
        id: container
        anchors.fill: parent
        anchors.leftMargin: Math.max(paddings,leftPadding)
        anchors.rightMargin: Math.max(paddings,rightPadding)
        anchors.topMargin: Math.max(paddings,topPadding)
        anchors.bottomMargin: Math.max(paddings,bottomPadding)
    }
}
