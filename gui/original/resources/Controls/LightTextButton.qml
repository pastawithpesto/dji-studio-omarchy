import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.3

/**
 * Created by whiskey.cao on 2024-02-06 .
 * ClassName : LightTextButton
 * Description :实现一个文字button
 * Copyright : ©2024 Light All Rights Reserved.
 */
Button{
    id: control
    property bool disabled: false
    // 该属性是为了避免button自带的checked属性行为，该行为导致每次点击button时，checked属性都会在true和false之间轮换
    property bool customChecked: false

    property int elide: Text.ElideNone
    enabled: !disabled

    property color normalColor: "darkblue"
    property color hoverColor: "cadetblue"
    property color pressedColor: "crimson"
    property color disableColor: "darkgoldenrod"
    property color checkedColor: "crimson"

    property color backgroundHoverColor: "aliceblue"
    property color backgroundPressedColor: "antiquewhite"
    property color backgroundNormalColor: "aqua"
    property color backgroundDisableColor: "aquamarine"
    property color backgroundCheckedColor: "antiquewhite"

    property color textColor: {
        if(!enabled){
            return disableColor
        }
        if(pressed){
            return pressedColor
        }
        if(hovered){
            return hoverColor
        }
        if(checked || customChecked){
            return checkedColor
        }
        return normalColor
    }

    property color bgColor: {
        if(!enabled){
            return backgroundDisableColor
        }
        if(pressed){
            return backgroundPressedColor
        }
        if(hovered){
            return backgroundHoverColor
        }
        if(checked || customChecked){
            return backgroundCheckedColor
        }
        return backgroundNormalColor
    }

    horizontalPadding:6
    focusPolicy:Qt.TabFocus
    background: Rectangle{
        implicitWidth: 28
        implicitHeight: 28
        radius: 4
        color: bgColor
    }
    contentItem: Text {
        id:btn_text
        text: control.text
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        color: control.textColor
        elide: control.elide
    }
}
