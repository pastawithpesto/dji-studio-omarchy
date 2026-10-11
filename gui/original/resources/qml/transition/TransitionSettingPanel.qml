import QtQuick 2.15
import QtQuick.Controls
import Config 1.0
import Controls 1.0
import MediaTypeModel 1.0
import QmlConstants 1.0
import TransitionSettingViewModel 1.0
import app_qrc 1.0


/**
  * @author: hugo.li
  * @details 【转场设置】界面
  * @date: 2025年11月25日
  */
Rectangle {
    id:panel

    anchors.fill: parent
    property string transitionName :model.name
    property double maxDuration:model.maxDuration / timeCalculate
    property double minDuration:0.1
    property double timeCalculate:1000000
    property TransitionSettingViewModel model

    color: Colors.color_content_area_background

    // 顶部分割线
    Rectangle {
        color: Colors.color_141414
        width: parent.width
        height: 1
    }

    ScrollView {
        id: scrollView
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        bottomPadding: 20
        ScrollBar.vertical.policy: ScrollBar.AlwaysOff
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        clip: true
        contentHeight: column.implicitHeight
        Component.onCompleted: {
            contentItem.boundsBehavior = Flickable.StopAtBounds
        }

        // 覆盖整个 scrollView 的 MouseArea，用于清除焦点
        MouseArea {
            anchors.fill: parent
            z: -1
            onClicked: {
                forceActiveFocus()
            }
        }
        Column {
            id: column
            spacing: 16
            topPadding: 16

            // 转场启用、转场还原
            Rectangle{
                id:transitionSwitchRec
                width: scrollView.width
                height: 16
                color: Colors.color_transparent


                Rectangle {
                    id: transitionTitleRec
                    width: scrollView.width
                    height: 20
                    anchors.left: parent.left
                    color: Colors.color_transparent
                    clip: true
                    Text {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignLeft
                        font {
                            pixelSize: 12
                        }
                        color: Colors.color_EEEEEE
                        text: qsTr("pccut_resource_transition_title")
                    }
                }

                // 重置
                Image {
                    id:resetIcon
                    enabled: true
                    anchors{
                        right: transitionSwitchRec.right
                        verticalCenter: parent.verticalCenter
                    }

                    source:"qrc:/icons/ic_reset_hover.svg"
                    sourceSize: Qt.size(20, 20)
                    opacity: resetIcon.enabled ? 1 : 0.2
                    MouseArea {
                        id: resetMouseArea
                        anchors.fill: parent
                        onClicked: {
                            transitionManager.resetTransition()
                        }

                        hoverEnabled: true
                    }
                }
            }

            // 转场名称
            Rectangle{
                id: transitionNameRec
                height: 16
                width: scrollView.width
                color: Colors.color_transparent

                Text {
                    id: transitionLabel
                    width: 57
                    height: 16
                    anchors.verticalCenter: parent.verticalCenter
                    font {
                        pixelSize: 12
                    }
                    color: Colors.color_999999
                    text: qsTr("pccut_resource_transition_name")
                }

                Text {
                    id: transitionLabelName
                    anchors{
                        left: transitionLabel.right
                        leftMargin: 12
                        verticalCenter: parent.verticalCenter
                    }

                    height: 16
                    font {
                        pixelSize: 12
                    }
                    color: Colors.color_FFFFFF
                    text: transitionName
                }
            }

            // 转场时长设置
            Rectangle{
                id: transitionTimeSettingRec
                height: 24
                width:scrollView.width
                color: Colors.color_transparent

                Text {
                    id: timeText
                    width: 57
                    height: 16
                    anchors.verticalCenter: parent.verticalCenter
                    font {
                        pixelSize: 12
                    }
                    color: Colors.color_999999
                    text: qsTr("pccut_resource_transition_time")
                }

                LightBaseSlider {
                    id: timeSlider
                    property int lastValue : 100
                    property real sliderLeft: 70
                    leftPadding: 0
                    anchors{
                        left: timeText.right
                        right:timeValue.left
                        rightMargin:12
                        leftMargin: 12
                        verticalCenter: parent.verticalCenter
                    }
                    visible: true
                    width: 107
                    height: 12
                    from: minDuration.toFixed(1)
                    to: maxDuration.toFixed(1)
                    // value: videoMotionBlurController.ndStrength
                    stepSize: 0.1
                    snapMode: Slider.SnapAlways
                    Accessible.role: Accessible.Slider
                    onMoved: {
                        // 这里调用过于频繁
                        // model.updateDuration(timeSlider.value)
                    }

                    onPressedChanged: {
                        if (!pressed) {
                            model.updateDuration(timeSlider.value)
                        }
                    }


                    Component.onCompleted: {
                        timeSlider.value = model.currentDuration / timeCalculate
                    }

                    Connections{
                        target: model
                        function onCurrentDurationChanged(){
                            timeSlider.value = model.currentDuration / timeCalculate
                        }
                    }
                }

                Rectangle{
                    id: timeValue
                    width: 56
                    height: 24
                    anchors.verticalCenter: parent.verticalCenter
                    anchors{
                        right:adjustItem.left
                        leftMargin: 12
                    }

                    radius: 4
                    color: Colors.color_19191A

                    TextField {
                        id: timeValueTextField
                        text: qsTr(timeSlider.value.toFixed(1).toString()+"s")
                        color: Colors.color_EEEEEE
                        anchors.centerIn: parent
                        width: 45
                        height: 24
                        horizontalAlignment: TextInput.AlignHCenter
                        font {
                            pixelSize: 11
                        }
                        background: Rectangle {
                            color: Colors.color_19191A
                            radius: 4
                        }
                        selectionColor: Colors.color_EEEEEE
                        selectedTextColor: Colors.color_1F2021
                        Keys.onReturnPressed: {
                            focus = false
                        }
                        Keys.onEscapePressed: {
                            text = timeSlider.value.toFixed(1).toString() + "s"
                            focus = false
                        }
                        onFocusChanged: {
                            if (!focus) {
                                if (text.length > 0) {
                                    var value = parseFloat(text)
                                    if (!isNaN(value)) {
                                        if (value < minDuration) value = minDuration
                                        if (value > maxDuration) value = maxDuration
                                        timeSlider.value = value
                                        text = value.toFixed(1).toString()
                                        text = text+"s";
                                        model.updateDuration(value)
                                    }
                                }
                            }
                        }

                        onActiveFocusChanged: {
                            if (!activeFocus && text === "") {
                                timeSlider.value = timeSlider.value
                            }
                        }

                        Keys.onShortcutOverride: function(event) {
                            if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                                focus = false
                                event.accepted = true
                            }
                        }

                        Keys.onPressed: function(event) {
                            // 允许数字和小数点
                            if (event.text < '0' || event.text > '9') {
                                if (event.text !== '.') {
                                    event.accepted = false
                                }
                            }
                        }

                        Connections {
                            target: timeSlider
                            function onValueChanged() {
                                if (!timeValueTextField.activeFocus) {
                                    timeValueTextField.text = timeSlider.value.toFixed(1).toString() + "s"
                                }
                            }
                        }
                    }
                }

                Item{
                    id: adjustItem
                    height: 24
                    anchors.verticalCenter: parent.verticalCenter
                    width: 10
                    anchors{
                        right:transitionTimeSettingRec.right
                        leftMargin: 2
                    }

                    Image{
                        anchors{
                            top: parent.top
                            topMargin: 1
                        }

                        source: "qrc:/icons/ic_next_up.svg"
                        sourceSize: Qt.size(10, 10)
                        MouseArea {
                            id: timeUpMouseArea
                            anchors.fill: parent
                            hoverEnabled: true

                            onClicked: {
                                forceActiveFocus()
                                timeSlider.value = Math.min(timeSlider.value + 0.1,maxDuration)
                                model.updateDuration(timeSlider.value)
                            }
                        }

                    }

                    Image{
                        anchors{
                            bottom: parent.bottom
                            bottomMargin: 1
                        }

                        source: "qrc:/icons/ic_next_down.svg"
                        sourceSize: Qt.size(10, 10)

                        MouseArea {
                            id: timeDownMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                forceActiveFocus()
                                timeSlider.value = Math.max(timeSlider.value - 0.1, minDuration)
                                model.updateDuration(timeSlider.value)
                            }
                        }
                    }
                }
            }
        }
    }
       Item {
        id: bgView
        visible: panel.visible
        parent: UiUtils.getTopParent(panel)
        anchors.fill: parent
        PointHandler {
            onGrabChanged: (transition, point) => {
                point.accepted = false
                if (point.timeHeld !== 0) {
                    return;
                }
                // 判断点击是否发生在nowSpeedText区域内
                var mousePoint = point.position;
                var clickPoint = bgView.mapToItem(timeValueTextField, mousePoint);
                var insideTimeValueTextField = timeValueTextField.contains(clickPoint);

                // 如果点击发生在nowSpeedText之外且它当前有焦点
                if (!insideTimeValueTextField && timeValueTextField.activeFocus) {
                    // 强制取消nowSpeedText的焦点
                    timeValueTextField.focus = false;
                }
            }
        }
    }
}
