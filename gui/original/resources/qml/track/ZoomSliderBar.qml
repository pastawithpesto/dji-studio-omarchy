import Config 1.0

/**
 * Created by whiskey.cao on 2024-02-06 .
 * ClassName : ZoomSliderBar
 * Description :带左右zoom按钮的Slider
 * Copyright : ©2024 Light All Rights Reserved.
 */
import QtQuick 2.15
import QtQuick.Controls

Item {
    id: zoomSliderBar
    // 左侧的图标
    property url leftIcon: "qrc:/icons/trackToolBar/toolbar_zoom_in.svg"
    // 右侧的图标
    property url rightIcon: "qrc:/icons/trackToolBar/toolbar_zoom_out.svg"
    // 滑杆选中的颜色
    property color sliderSelectedColor: Colors.color_D8D8D8
    // 滑杆未选中的颜色
    property color sliderUnSelectedColor: Colors.color_D8D8D8
    property color buttonHoverColor: Colors.color_track_tool_button_background_hovered
    property color buttonPressedColor: Colors.color_19191A
    property color sliderHandleBorderColor: Colors.color_141414
    property alias value: slider_id.value
    signal dragging(int value)
    signal btnClickZoom(int value)
    signal released()

    width: parent.width
    height: parent.height

    Rectangle {
        id: root

        width: parent.width
        height: parent.height
        color: "transparent"

        TrackToolsButton {
            id: zoom_out
            iconSource: leftIcon
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            hoverColor: buttonHoverColor
            pressedColor: buttonPressedColor

            disabled: !enabled || value === slider_id.from

            onClicked: {
                zoomOut()
                eventTracker.trackEvent("pccut_scroll_bar_click", {"use_method": "navigation_bar"})
            }
        }

        LightSlider {
            id: slider_id

            from: 0
            value: 50
            to: 100
            stepSize: 1
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: zoom_out.right
            anchors.rightMargin: 3
            anchors.leftMargin: 3
            anchors.right: zoom_in.left
            lineWitdh: 2
            selectedColor: sliderSelectedColor
            unSelectedColor: sliderUnSelectedColor
            handleBorderColor: sliderHandleBorderColor
            onMoved: {
                dragging(value)
            }
            onPressedChanged: {
                if (!pressed) {
                    released()
                }
            }
        }

        TrackToolsButton {
            id: zoom_in

            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            iconSource: rightIcon
            hoverColor: buttonHoverColor
            pressedColor: buttonPressedColor

            disabled: !enabled || value === slider_id.to

            onClicked: {
                eventTracker.trackEvent("pccut_scroll_bar_click", {"use_method": "navigation_bar"})
                zoomIn()
            }
        }
    }

    // 拉进，放大
    function zoomIn() {
        if (!zoomIn.disabled) {
            const target = Math.min(slider_id.value + 10, slider_id.to)
            btnClickZoom(target)
        }
    }

    // 远离，缩小
    function zoomOut() {
        if (!zoomOut.disabled) {
            const target = Math.max(slider_id.value - 10, slider_id.from)
            btnClickZoom(target)
        }
    }
}
