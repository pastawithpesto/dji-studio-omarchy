
/**
 * Created by whiskey.cao on 2024-02-06 .
 * ClassName : LightSlider
 * Description : 自定义Slider
 * Copyright : ©2024 Light All Rights Reserved.
 */
import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Controls.impl 2.12
import QtQuick.Templates 2.15 as T
import Config 1.0

T.Slider {
    id: control
    //滑杆宽度
    property int lineWitdh: 3
    //选中的进度颜色
    property color selectedColor: "red"
    //未选中的进度颜色
    property color unSelectedColor: "gray"
    //滑杆点宽度
    property int pointWitdh: 12
    
    property color handleBorderColor: Colors.color_141414

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            implicitHandleWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             implicitHandleHeight + topPadding + bottomPadding)

    padding: 6

    handle: Rectangle {
        x: control.leftPadding + (control.horizontal ? control.visualPosition
                                                       * (control.availableWidth
                                                          - width) : (control.availableWidth - width) / 2)
        y: control.topPadding + (control.horizontal ? (control.availableHeight - height) / 2 : control.visualPosition
                                                      * (control.availableHeight - height))
        implicitWidth: pointWitdh
        implicitHeight: pointWitdh
        radius: width / 2
        color: Colors.color_FFFFFF
        border.width: 1
        border.color: handleBorderColor
    }

    background: Rectangle {
        x: control.leftPadding + (control.horizontal ? 0 : (control.availableWidth - width) / 2)
        y: control.topPadding + (control.horizontal ? (control.availableHeight - height) / 2 : 0)
        implicitWidth: control.horizontal ? 200 : lineWitdh
        implicitHeight: control.horizontal ? lineWitdh : 200
        width: control.horizontal ? control.availableWidth : implicitWidth
        height: control.horizontal ? implicitHeight : control.availableHeight
        radius: 3
        color: unSelectedColor
        scale: control.horizontal && control.mirrored ? -1 : 1

        Rectangle {
            y: control.horizontal ? 0 : control.visualPosition * parent.height
            width: control.horizontal ? control.position * parent.width : lineWitdh
            height: control.horizontal ? lineWitdh : control.position * parent.height

            radius: 3
            color: selectedColor
        }
    }
}
