import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.15
import LightRectangle 1.0
import Config 1.0
import Qt5Compat.GraphicalEffects
/**
 * Created by whiskey.cao on 2024-02-06 .
 * ClassName : LightPopup
 * Description :定义Popup基类
 * Copyright : ©2024 Light All Rights Reserved.
 */
Popup {
    id: popup
    property int customRadius:8
    padding: 0
    modal:true
    // 先把居中注释掉，要不所有自定义Popup显示都居中，无法自定义显示位置
    // anchors.centerIn: Overlay.overlay
    closePolicy: Popup.CloseOnEscape
    property bool needTransparent: false
    property bool needNoBorder: false
    property var exitDuration: 100
    enter: Transition {
        NumberAnimation {
            property: "opacity"
            duration: 100
            from:0
            to:1
        }
    }
    exit:Transition {
        NumberAnimation {
            property: "opacity"
            duration: exitDuration
            from:1
            to:0
        }
    }
    parent: Overlay.overlay
    background: Rectangle {
        color: popup.needTransparent?Colors.transparent:Colors.color_80000000
        layer.enabled: true
        radius: popup.customRadius
        anchors.fill: parent
        border {
            width: (popup.needTransparent || popup.needNoBorder)?0:1
            color: Colors.color_454649
        }
        layer.effect: DropShadow {
            horizontalOffset: 0
            verticalOffset: 0
            radius: 50
            color: Colors.color_80000000 
            transparentBorder: true
        }
    }

    onOpened: {
        globalSignal.enableMenuBar(false)
    }

    onClosed: {
        globalSignal.enableMenuBar(true)
    }

}
