import QtQuick 2.15
import QtQuick.Controls
import Controls 1.0
import Config 1.0
import CursorHelper 1.0
import QtQuick.Layouts 1.15
import app_qrc 1.0

/**
 * @author robert.guo
 * @desc 取景右侧面板, 可自动编辑文本框
 * @create_date 2024-06-12
 */
Item {
    width: 60
    height: 24

    property bool disableClick: false
    property bool enableMulpleText: false
    property real originValue: 0.0
    // 目前只支持int，且不支持初始化完成后再次更新
    property int maxValue: 0
    property int minValue: 0
    property real value: 0.0
    // 精确的小数位数
    property int accurate: isDistorition() ? 2 : 1
    // 滑动的时候计算使用，避免number的精度问题
    property int valueMultiply10: 0
    property real tempValue: 0.0
    property bool editing: false
    property real startX: 0
    property int itemIndex: -1
    // 标志单次touch事件有没有被消费，每次拖拽完成后，会走onPress->onPositionChanged->onRelease->onClick，主要处理这种情况，最后的onClick将不会被处理
    property bool singleTouchEventConsumered: false
    // 是否存在关键帧
    property bool hasKeyFrame: false
    property bool isPlaying: false
    property bool isDisableMode: false
    property bool isTabVisible
    // 鼠标拖动调整的系数，越小意味着调整的幅度越小，控制越精细。越大意味着调整的幅度越大，控制更迅速。
    property double dragCoeff: 0.1
    property double multiplyDragCoeff: 1
    property double mouseDeltaX: 0

    property int coeffValue: valueMultiply10 / (360 * accurateScale)
    // 只所以再写一遍而不是写成 value - coeffValue的原因是不希望remainderValue变两次
    // 这里乘了10，目的是转换成int，不比较小数
    property int remainderValueMultiply10: valueMultiply10 % (360 * accurateScale)

    signal argumentChanged(var value, var index, bool isEditing)
    // 当长按拖动精细化调整参数时，瞬间会触发多次argumentChanged信号发射，如果草稿存稿时机选择在
    // 监听argumentChanged时，会有多次存稿操作，新增这个信号只有抬手时才发送，这样只会存稿一次
    signal release(var value, var index)

    property int accurateScale: Math.pow(10, Math.max(1, accurate))

    property alias valueText: valueText

    onValueChanged: {
        valueMultiply10 = Math.round(value * accurateScale);
        valueMultiply10 = clamp(valueMultiply10, minValue * accurateScale, maxValue * accurateScale)
    }

    CursorHelper {
        id: cursorhelper
    }

    // 数据是否有变更
    function dataNoChange() {
        return Math.abs(originValue - value) < 0.001
    }

    // 是否是畸变控制模型
    function isDistorition() {
        return itemIndex == 1
    }

    Item {
        id: displayRect
        anchors.fill: parent

        Item {
            height: parent.height

            property real multiplyTextGuideline: coeffText.visible ? coeffText.width + 6 : coeffEditPopup.opened ? coeffEditPopup.width + 6 : 0
            property real valueTextGuideline: multiplyText.visible ? multiplyTextGuideline + multiplyText.width + 6 : 0

            Text {
                id: coeffText
                font.pixelSize: 12
                color: displayRect.getTextColor()
                text: coeffValue
                visible: enableMulpleText && (coeffValue !== 0 || coeffTextArea.dragging) && !coeffEditPopup.opened
                anchors {
                    left: parent.left
                    verticalCenter: parent.verticalCenter  // 垂直居中展示
                }

                MouseArea {
                    id: coeffTextArea
                    anchors.fill: parent
                    cursorShape: Qt.SizeHorCursor
                    // 防止Mouse时间被父控件拦截
                    preventStealing: true

                    property real startMoveX: -1
                    property real startMoveY: -1
                    property bool dragging: false
                    onClicked: {
                        if (singleTouchEventConsumered) {
                            return
                        }
                        singleTouchEventConsumered = true
                        editing = true

                        coeffText.focus = true
                        coeffEditPopup.text = coeffValue
                        coeffEditPopup.open()
                    }

                    onPositionChanged: (mouse) => {
                        const globalPosition = mapToGlobal(mouse.x, mouse.y)
                        if (startMoveX !== -1 && startMoveY !== -1 && (globalPosition.x - startMoveX) * (globalPosition.x - startMoveX) + (globalPosition.y - startMoveY) * (globalPosition.y - startMoveY)  < 9) {
                            return;
                        }

                        singleTouchEventConsumered = true
                        dragging = true
                        // 根据鼠标位置的变化来判断是左滑还是右滑
                        var deltaX = globalPosition.x - startX
                        deltaX *= multiplyDragCoeff
                        var deltacoeff = Math.trunc(deltaX)
                        valueMultiply10 = deltacoeff * 360 * accurateScale + remainderValueMultiply10
                        valueMultiply10 = clamp(valueMultiply10, minValue * accurateScale, maxValue * accurateScale)
                        argumentChanged(valueMultiply10 / (accurateScale * 1.0), itemIndex, false)
                    }
                    onPressed: (mouse) => {
                        const globalPosition = mapToGlobal(mouse.x, mouse.y)
                        startMoveX = globalPosition.x
                        startMoveY = globalPosition.y
                        singleTouchEventConsumered = false
                        dragging = false
                        // 记录鼠标按下时的位置
                        startX = globalPosition.x
                        tempValue = valueMultiply10
                        argumentChanged(valueMultiply10 / (accurateScale * 1.0), itemIndex, false)
                        cursorhelper.setOverrideCursor(Qt.SizeHorCursor);
                    }
                    onReleased: (mouse) => {
                        // 长按抬起时，鼠标形状恢复原状
                        cursorhelper.restoreOverrideCursor();
                        if (dragging) {
                            const globalPosition = mapToGlobal(mouse.x, mouse.y)
                            var deltaX = globalPosition.x - startX
                            deltaX *= multiplyDragCoeff
                            var deltacoeff = Math.trunc(deltaX)
                            valueMultiply10 = deltacoeff * 360 * accurateScale + remainderValueMultiply10
                            valueMultiply10 = clamp(valueMultiply10, minValue * accurateScale, maxValue * accurateScale)
                            release(valueMultiply10 / ((accurateScale * 1.0)), itemIndex)
                        }
                        dragging = false
                        startMoveX = -1
                        startMoveY = -1
                    }
                }
            }

            Text {
                id: multiplyText
                font.pixelSize: 12
                text: "x"
                visible: coeffText.visible || coeffEditPopup.opened
                color: isDisableMode || isTabVisible ? Colors.color_444444 : Colors.color_EEEEEE
                anchors {
                    verticalCenter: parent.verticalCenter  // 垂直居中展示
                    left: parent.left
                    leftMargin: parent.multiplyTextGuideline
                }
            }

            Text {
                id: valueText
                text: remainderValueMultiply10 === 0 ? "0.0" : (remainderValueMultiply10 / ((accurateScale * 1.0))).toFixed(accurate);
                font.pixelSize: 12
                visible: !textEditPopup.opened
                color: displayRect.getTextColor()
                anchors {
                    verticalCenter: parent.verticalCenter  // 垂直居中展示
                    left: parent.left
                    leftMargin: parent.valueTextGuideline
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.SizeHorCursor
                    // 防止Mouse时间被父控件拦截
                    preventStealing: true
                    property bool dragging: false

                    property real startMoveX: -1
                    property real startMoveY: -1
                    onClicked: {
                        if (singleTouchEventConsumered) {
                            return
                        }
                        singleTouchEventConsumered = true
                        if (disableClick) {
                            return
                        }
                        editing = true

                        valueText.focus = true
                        var result = parseFloat(valueText.text.trim("°"))
                        textEditPopup.text = result.toFixed(1)
                        textEditPopup.open()
                    }

                    onPositionChanged: (mouse) => {
                        const globalPosition = mapToGlobal(mouse.x, mouse.y)
                        if (startMoveX !== -1 && startMoveY !== -1 && (globalPosition.x - startMoveX) * (globalPosition.x - startMoveX) + (globalPosition.y - startMoveY) * (globalPosition.y - startMoveY)  < 9) {
                            return;
                        }

                        singleTouchEventConsumered = true
                        dragging = true
                        // 根据鼠标位置的变化来判断是左滑还是右滑
                        var deltaX = globalPosition.x - startX
                        deltaX *= dragCoeff
                        mouseDeltaX = deltaX 
                        var result = tempValue + Math.trunc(deltaX * accurateScale)
                        argumentChanged(result / (accurateScale * 1.0), itemIndex, false)
                    }
                    onPressed: (mouse) => {
                        // 这里计算一下相对于全局的位置，不然的话如果本身元素移动了，这里计算的就会出现错误
                        const globalPosition = mapToGlobal(mouse.x, mouse.y)
                        startMoveX = globalPosition.x
                        startMoveY = globalPosition.y
                        singleTouchEventConsumered = false
                        dragging = false
                        // 记录鼠标按下时的位置
                        startX = globalPosition.x
                        tempValue = valueMultiply10
                        mouseDeltaX = 0 
                        argumentChanged(valueMultiply10 / (accurateScale * 1.0), itemIndex, false)
                        cursorhelper.setOverrideCursor(Qt.SizeHorCursor);
                    }
                    onReleased: (mouse) => {
                        // 长按抬起时，鼠标形状恢复原状
                        cursorhelper.restoreOverrideCursor();
                        if (dragging) {
                            const globalPosition = mapToGlobal(mouse.x, mouse.y)
                            var deltaX = globalPosition.x - startX
                            deltaX *= dragCoeff
                            var result = tempValue + Math.trunc(deltaX * accurateScale)
                            release(result / (accurateScale * 1.0), itemIndex)
                            if(editorManager.isInUserGuideStatus){
                                globalSignal.nextStepInKfGuide();
                            }
                    }
                        dragging = false
                        startMoveX = -1
                        startMoveY = -1
                    }
                }
            }

            Text {
                id: degreeText
                text: "°"
                font.pixelSize: 12
                visible: valueText.visible && !isDistorition()
                color: displayRect.getTextColor(false)
                anchors {
                    left: valueText.right
                    verticalCenter: parent.verticalCenter  // 垂直居中展示
                }
            }
        }

        function getTextColor(changeWhenModified = true) {
            if (isDisableMode || isTabVisible) {
                return Colors.color_444444
            } else {
                return (changeWhenModified && hasKeyFrame && !isPlaying && !dataNoChange()) ? ColorsConfig.color_brand : Colors.color_EEEEEE
            }
        }

        TextEditPopup {
            id: coeffEditPopup
            text: coeffValue
            width: 30
            height: 24
            showDegreeLabel: false
            closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
            inputValidator: IntValidator {
                bottom: -99999
                top: 99
            }
            maxCharsNum: 6
            onOpened: {
                coeffEditPopup.autoFocus()
            }

            onClosed: {
                editing = false
                var tempValue = parseInt(coeffEditPopup.text)
                if (isNaN(tempValue)) {
                    valueMultiply10 = remainderValueMultiply10
                } else {
                    valueMultiply10 = tempValue * 360 * (accurateScale) + remainderValueMultiply10
                }
                valueMultiply10 = clamp(valueMultiply10, minValue * accurateScale, maxValue * accurateScale)
                coeffEditPopup.visible = false
                argumentChanged(valueMultiply10 / (accurateScale * 1.0), itemIndex, true)
            }
        }

        TextEditPopup {
            id: textEditPopup
            width: 52
            height: 24
            text: valueText.text
            showDegreeLabel: !isDistorition()
            closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
            inputValidator: DoubleValidator { 
                decimals: accurate // 设置只能有1位小数
            }
            onOpened: {
                x = valueText.x
                textEditPopup.autoFocus()
            }

            onClosed: {
                editing = false
                var tempValue = parseFloat(textEditPopup.text)
                if (isNaN(tempValue)) {
                    valueMultiply10 = coeffValue * 360 * accurateScale
                } else {
                    valueMultiply10 = coeffValue * 360 * accurateScale + Math.trunc(tempValue * accurateScale)
                }
                valueMultiply10 = clamp(valueMultiply10, minValue * accurateScale, maxValue * accurateScale)
                textEditPopup.visible = false
                argumentChanged(valueMultiply10 / (accurateScale * 1.0), itemIndex, true)
            }
        }
    }

    function clamp(value, min, max) {
        if (max <= min) {
            return value;
        }
        return Math.min(Math.max(value, min), max);
    }
}
