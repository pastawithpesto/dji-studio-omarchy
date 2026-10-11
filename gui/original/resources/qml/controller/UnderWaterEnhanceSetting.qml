import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls
import QtQuick.Controls.Material 2.15
import Config 1.0
import Controls 1.0
import Nova 1.0
import app_qrc 1.0

/**
 *  @File        : UnderWaterEnhanceSetting.qml
 *  @Brief       : 简化版LUT控制
 *  @Details     : 包含颜色矫正和水下增强两个选项
 *  @Note        : [NOVA] 启用态/颜色矫正/效果增强走 UnderWaterFilterAdjust(继承 ofa::FilterAdjust)
 */
Item {
    id: underWaterEnhanceSetting
    property UnderWaterFilterAdjust viewModel
    // 颜色矫正/效果增强分别取 allParameter 的第 0/1 个 FilterAdjustProperty
    readonly property var colorParam: (!CommonUtils.isNull(viewModel) && viewModel.allParameter.length >= 2) ? viewModel.allParameter[0] : null
    readonly property var enhanceParam: (!CommonUtils.isNull(viewModel) && viewModel.allParameter.length >= 2) ? viewModel.allParameter[1] : null
    property double defultOpacity : checkBox.checked ? 1 : 0.2
    property int bothSidePadding: 100

    width: parent.width
    height: childrenRect.height

    Rectangle {
        id: underWaterRect
        property bool isDisable: !checkBox.checked
        property bool isDefaultStatus:checkIfDefaultStatus()
        width: parent.width
        height: checkBox.implicitHeight
        color: Colors.color_transparent
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top

        LightCheckBox {
            id: checkBox
            maxTextWidth: underWaterEnhanceSetting.width - 180
            text: qsTr("pccut_panel_underwater_color_enhance")
            anchors.verticalCenter: parent.verticalCenter
            checked: CommonUtils.isNull(viewModel) ? false : viewModel.isEnable
            verticalPadding: 1.5
            MouseArea {
                anchors.fill: checkBox
                onClicked: {
                    if (CommonUtils.isNull(viewModel)) {
                        return;
                    }
                    viewModel.isEnable = !checkBox.checked;
                }
            }
        }

        // 重置按钮
        Rectangle {
            id: resetBtn
            property bool isHovered: false
            anchors {
                right: parent.right
            }
            color: Colors.color_transparent
            width: 20
            height: 20
            anchors.verticalCenter: parent.verticalCenter

            Image {
                anchors.fill: parent
                source: (underWaterRect.isDisable || underWaterRect.isDefaultStatus) ? "qrc:/icons/ic_reset.svg" :  resetBtn.isHovered ? "qrc:/icons/ic_reset_hover.svg" : "qrc:/icons/ic_reset.svg"
                sourceSize: Qt.size(parent.width, parent.height)
                opacity: (underWaterRect.isDisable || underWaterRect.isDefaultStatus) ? 0.2 : 1
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: resetBtn.isHovered = true
                onExited: resetBtn.isHovered = false
                onClicked: {
                    if(!underWaterRect.isDisable && !underWaterRect.isDefaultStatus && !CommonUtils.isNull(viewModel)) {
                        viewModel.reset();
                    }
                }
            }
        }
        function checkIfDefaultStatus() {
            underWaterRect.isDefaultStatus = (colorSlider.value == 80) && (waterEnhanceSlider.value == 100)
        }
    }

    Item {
        id: colorCorrect
        anchors {
            left: parent.left
            top: underWaterRect.bottom
            topMargin: 12
        }
        width: parent.width
        height: 15

        HoverableText {
            id: colorCorrectText
            anchors {
                verticalCenter: parent.verticalCenter
                left: parent.left
            }
            height: 15
            maximumLineCount: 1
            color: Colors.color_CCCCCC
            opacity: checkBox.checked ? 1 : 0.2
            font.pixelSize: 11
            horizontalAlignment: Text.AlignLeft
            verticalAlignment: Text.AlignVCenter
            text: qsTr("pccut_panel_underwater_color_correction")

            MouseArea {
                anchors.fill: parent
                onDoubleClicked: {
                    if(!underWaterRect.isDisable && colorParam) {
                        colorParam.updateDouble(colorParam.defaultValue, 2);
                    }
                }
            }
        }

        LightBaseSlider {
            id: colorSlider
            property real sliderLeft: 70
            leftPadding: 0
            anchors {
                left: parent.left
                leftMargin: sliderLeft
                verticalCenter: parent.verticalCenter
            }

            enabled: checkBox.checked
            visible: true
            width: parent.width - bothSidePadding
            height: 12
            from: 0
            to: 100
            value: colorParam ? colorParam.value : 80
            stepSize: 1
            snapMode: Slider.SnapAlways

            onMoved: {
                if (pressed && colorParam){
                    colorParam.updateDouble(value, 1);
                }
            }

            onPressedChanged: {
                if (colorParam) {
                    // 按下 step0、抬手 step2(入撤销栈)
                    colorParam.updateDouble(value, pressed ? 0 : 2);
                }
            }

            onValueChanged: {
                underWaterRect.checkIfDefaultStatus()
            }
        }

        Text {
            anchors {
                right: parent.right
                rightMargin: 0
                verticalCenter: parent.verticalCenter
            }
            id: colorValue
            height: 15
            width: 19
            color: Colors.color_CCCCCC
            opacity: checkBox.checked ? 1 : 0.2
            font.pixelSize: 11
            horizontalAlignment: Text.AlignRight
            verticalAlignment: Text.AlignVCenter
            text: colorSlider.value
        }
    }

    Item {
        id: waterEnhance
        anchors {
            left: parent.left
            top: colorCorrect.bottom
            topMargin: 12
        }
        width: parent.width
        height: 15

        HoverableText {
            id: underWaterText
            anchors {
                verticalCenter: parent.verticalCenter
                left: parent.left
            }
            height: 15
            maximumLineCount: 1
            color: Colors.color_CCCCCC
            opacity: checkBox.checked ? 1 : 0.2
            font.pixelSize: 11
            horizontalAlignment: Text.AlignLeft
            verticalAlignment: Text.AlignVCenter
            text: qsTr("pccut_panel_underwater_color_enhance")

            MouseArea {
                anchors.fill: parent
                onDoubleClicked: {
                    if(!underWaterRect.isDisable && enhanceParam) {
                        enhanceParam.updateDouble(enhanceParam.defaultValue, 2);
                    }
                }
            }
        }

        LightBaseSlider {
            id: waterEnhanceSlider
            property real sliderLeft: 70
            leftPadding: 0
            anchors {
                left: parent.left
                leftMargin: sliderLeft
                verticalCenter: parent.verticalCenter
            }

            enabled: checkBox.checked
            visible: true
            width: parent.width - bothSidePadding
            height: 12
            from: 0
            to: 100
            value: enhanceParam ? enhanceParam.value : 100
            stepSize: 1
            snapMode: Slider.SnapAlways

            onMoved: {
                if (pressed && enhanceParam){
                    enhanceParam.updateDouble(value, 1);
                }
            }

            onPressedChanged: {
                if (enhanceParam) {
                    // 按下 step0、抬手 step2(入撤销栈)
                    enhanceParam.updateDouble(value, pressed ? 0 : 2);
                }
            }

            onValueChanged: {
                underWaterRect.checkIfDefaultStatus()
            }
        }

        Text {
            anchors {
                right: parent.right
                rightMargin: 0
                verticalCenter: parent.verticalCenter
            }
            id: enhanceValue
            height: 15
            width: 19
            color: Colors.color_CCCCCC
            opacity: checkBox.checked ? 1 : 0.2
            font.pixelSize: 11
            horizontalAlignment: Text.AlignRight
            verticalAlignment: Text.AlignVCenter
            text: waterEnhanceSlider.value
        }
    }

}
