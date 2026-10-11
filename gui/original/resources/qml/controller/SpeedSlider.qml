import QtQuick 2.15
import QtQuick.Controls
import Config 1.0
import Nova 1.0

/**
  * @details 速度的滑杆（nova SpeedViewModel 驱动）
  * 滑杆值 ↔ regSpeed 双向绑定；抬手 pressedSingal 单次提交（一条 undo）。
  */
Rectangle {
    id: control
    property SpeedViewModel viewModel
    property double speed: 1.0
    property bool isTriggerOnValueChanged: true // 外部改 speed 时不触发 onValueChanged 逻辑
    // 抬手信号
    signal pressedSingal
    // 步进
    property double stepSize: {
        if (speed < 1) {
            return 0.2 / 9
        } else if (speed >= 1 && speed < 2) {
            return 0.2 / 10
        } else if (speed >= 2 && speed < 5) {
            return 0.2 / 30
        } else if (speed >= 5 && speed < 8) {
            return 0.2 / 30
        } else if (speed >= 8 && speed <= 64) {
            return 0.2 / 52
        } else {
            return 1;
        }
    }

    function getSpeedBySliderValue(sliderValue) {
        if (sliderValue <= 0.2) {
            return mapRange(sliderValue, 0.0, 0.2, 0.1, 1.0, 0.1);
        } else if (sliderValue <= 0.4) {
            return mapRange(sliderValue, 0.2, 0.4, 1.0, 2.0, 0.1);
        } else if (sliderValue <= 0.6) {
            return mapRange(sliderValue, 0.4, 0.6, 2.0, 5.0, 0.1);
        } else if (sliderValue <= 0.8) {
            return mapRange(sliderValue, 0.6, 0.8, 5.0, 8.0, 0.1);
        } else {
            return mapRange(sliderValue, 0.8, 1.0, 8.0, 64.0, 1);
        }
    }

    function getSliderValueBySpeed(speed) {
        if (speed <= 1.0) {
            return mapRange(speed, 0.1, 1.0, 0.0, 0.2, 0.01);
        } else if (speed <= 2.0) {
            return mapRange(speed, 1.0, 2.0, 0.2, 0.4, 0.01);
        } else if (speed <= 5.0) {
            return mapRange(speed, 2.0, 5.0, 0.4, 0.6, 0.01);
        } else if (speed <= 8.0) {
            return mapRange(speed, 5.0, 8.0, 0.6, 0.8, 0.01);
        } else {
            return mapRange(speed, 8.0, 64.0, 0.8, 1.0, 0.01);
        }
    }

    function mapRange(value, fromLow, fromHigh, toLow, toHigh, increment) {
        var fromSpan = fromHigh - fromLow;
        var toSpan = toHigh - toLow;
        var normalizedValue = (value - fromLow) / fromSpan;
        var steps = Math.round(normalizedValue * (toSpan / increment));
        var mappedValue = toLow + (steps * increment);
        return Math.min(Math.max(mappedValue, toLow), toHigh);
    }

    color: Colors.color_transparent

    Slider {
        id: mySlider
        anchors {
            left: parent.left
            leftMargin: 12
            right: nowSpeedText.left
            rightMargin: 16
            verticalCenter: parent.verticalCenter
        }
        from: 0
        to: 1
        value: 0
        stepSize: parent.stepSize
        height: 12
        onValueChanged: {
            if (isTriggerOnValueChanged) {
                speed = getSpeedBySliderValue(value).toFixed(4);
            }
            nowSpeedText.text = speed + "x";
        }

        onPressedChanged: {
            if (pressed) {
                if (playerPanel.controller.playing) {
                    playerPanel.controller.pause();
                }
            } else {
                pressedSingal();
            }
        }

        background: Rectangle {
            x: 0
            y: mySlider.height / 2 - 1
            width: parent.width
            height: 2
            radius: 1
            color: Colors.color_4D4D4D

            Repeater {
                model: 6
                Rectangle {
                    width: 2
                    height: 10
                    radius: 1
                    color: Colors.color_D8D8D8
                    x: index * (mySlider.width / 5)
                    y: parent.height / 2 - height / 2
                }
            }
            Rectangle {
                width: mySlider.value * parent.width
                height: parent.height
                radius: 1
                color: Colors.color_D8D8D8
            }
        }
        handle: Rectangle {
            width: 12
            height: width
            x: mySlider.value * mySlider.width - width / 2
            y: 0
            color: Colors.color_E8E8E8
            radius: width / 2
        }
    }

    TextField {
        id: nowSpeedText
        width: 56
        height: 24
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter
        selectByMouse: true
        anchors {
            verticalCenter: parent.verticalCenter
            right: parent.right
        }
        font.pixelSize: 11
        text: speed + "x"
        color: Colors.color_FFFFFF
        property string previousText: text

        palette {
            highlight: Colors.color_EEEEEE
            highlightedText: Colors.color_444444
        }

        background: Rectangle {
            border.width: 0
            color: Colors.color_19191A
            radius: 4;
        }

        Keys.onPressed: function(event){
            if ((event.modifiers === Qt.ControlModifier) && (event.key === Qt.Key_A)) {
                event.accepted = true;
                if (length > 0) {
                    select(0, length - 1);
                }
            }
        }

        Keys.onReturnPressed: {
            focus = false
        }

        Keys.onEscapePressed: {
            text = previousText
            focus = false
        }

        Keys.onShortcutOverride: function(event) {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                event.accepted = true
            }
        }

        onCursorPositionChanged: {
            const maxPos = text.length - 1;
            if (cursorPosition > maxPos) {
                cursorPosition = maxPos;
            }
        }
        onSelectionEndChanged: {
            if (selectionEnd > text.length - 1) {
                var newEnd = text.length - 1
                var newStart = Math.min(selectionStart, newEnd)
                select(newStart, newEnd)
            }
        }

        onActiveFocusChanged: {
            if (!nowSpeedText.activeFocus) {
                previousText = nowSpeedText.text;
            }
        }

        onEditingFinished: {
            var currentText = nowSpeedText.text;
            var numericText = currentText.substring(0, currentText.length - 1);
            var isNumber = !isNaN(numericText) && numericText !== "" && !numericText.startsWith(".");
            if (!isNumber) {
                if(previousText === "x"){
                    nowSpeedText.text = "0.1x"
                    speed = 0.1;
                }else{
                    nowSpeedText.text = previousText;
                }
            } else {
                var numericValue = parseFloat(numericText);
                if (numericValue < 0.1) {
                    numericValue = 0.1;
                    nowSpeedText.text = numericValue + "x";
                }
                if (numericValue > 64) {
                    numericValue = 64;
                    nowSpeedText.text = numericValue + "x";
                }
                speed = numericValue;
                pressedSingal();
            }
            nowSpeedText.focus = false;
        }

        onTextChanged: {
            var text = nowSpeedText.text;
            var filteredText = text.replace(/[^0-9.]/g, "");
            var decimalCount = (filteredText.match(/\./g) || []).length;
            if (decimalCount > 1) {
                var firstDecimalIndex = filteredText.indexOf(".");
                filteredText = filteredText.substring(0, firstDecimalIndex + 1) +
                               filteredText.substring(firstDecimalIndex + 1).replace(/\./g, "");
            }
            var decimalIndex = filteredText.indexOf(".");
            if (decimalIndex !== -1) {
                var decimalPart = filteredText.substring(decimalIndex + 1);
                if (decimalPart.length > 4) {
                    filteredText = filteredText.substring(0, decimalIndex + 5);
                }
            }
            if (!text.endsWith("x")) {
                filteredText += "x";
            } else {
                filteredText = filteredText + "x";
            }
            if (nowSpeedText.text !== filteredText) {
                nowSpeedText.text = filteredText;
            }
        }
    }

    Component.onCompleted: {
        refreshSlider();
    }

    Connections {
        target: viewModel

        function onRegSpeedChanged() {
            refreshSlider();
        }
    }

    function refreshSlider() {
        isTriggerOnValueChanged = false;
        speed = CommonUtils.isNull(viewModel) || !viewModel.hasClip ? 1 : viewModel.regSpeed.toFixed(4);
        if (speed < 1) {
            mySlider.value = (speed - 0.1) / 0.1 * stepSize;
        } else {
            mySlider.value = getSliderValueBySpeed(speed);
        }
        isTriggerOnValueChanged = true;
    }

    function resetSpeedToOne(){
        mySlider.value = getSliderValueBySpeed(1);
    }

    Item {
        id: bgView
        visible: control.visible
        parent: UiUtils.getTopParent(control)
        anchors.fill: parent
        PointHandler {
            onGrabChanged: (transition, point) => {
                point.accepted = false
                if (point.timeHeld !== 0) {
                    return;
                }
                var mousePoint = point.position;
                var clickPoint = bgView.mapToItem(nowSpeedText, mousePoint);
                var insideNowSpeedText = nowSpeedText.contains(clickPoint);
                if (!insideNowSpeedText && nowSpeedText.activeFocus) {
                    nowSpeedText.focus = false;
                }
            }
        }
    }
}
