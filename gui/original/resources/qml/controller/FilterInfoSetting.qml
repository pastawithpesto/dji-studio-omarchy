import QtQuick 2.15
import Nova 1.0
import Config 1.0
import Controls 1.0
//import QtQuick.Controls.Styles 1.4
import QtQuick.Controls.Material 2.15
import QtQuick.Window 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.15

Item {
    id: root
    property var adjustModel
    readonly property int styleBaseSlider: 3
    property bool isDisable: false
    // 是否展示顶部 title/icon 头部行（DLog2 三项精细参数场景关掉 —— 外层"更多设置"折叠行已承担入口）
    property bool showHeader: true
    // 元素之间的垂直间距
    property real itemVerticalSpacing: 0
    // 两边边距之和
    property int bothSidePadding: sliderLeft + 36

    property real headerTextFontSize: 11
    property real subTitleTextFontSize: 11
    property color headerTextColor: Colors.color_666666
    property color subTitleTextColor: Colors.color_CCCCCC
    property color subTitleTextValueColor: Colors.color_CCCCCC

    property real sliderLeft: 0
    property real maxItemTextWidth: 0
    property real minValue: -100
    property real maxValue: 100
    // 输入框是否支持四则运算/公式输入（默认关闭，保持原生纯数字输入不影响其他调节面板）；
    // 开启后走 CommonUtils.validateFormulaInput：+ - * / ( )、中文全角括号、以及基于原值的相对运算（+10 / *2 / /2）
    property bool supportFormula: false
    // 滑杆/输入框抬手后触发，paramName 为 adjust 项 mltName（brightness/highlight/clarity/...）
    signal sliderReleased(string paramName)
    //所有参数是否都是默认值
    property bool isDefaultStatus : true
    function checkDefaultStatus() {
        var allDefault = true;
        for (var i = 0; i < adjustModel.allParameter.length; i++) {
            var param = adjustModel.allParameter[i];
            if (param.value !== param.defaultValue) {
                allDefault = false;
                break;
            }
        }
        root.isDefaultStatus = allDefault;
    }

    width: parent.width
    property double itemHeight: 16
    height: colum.implicitHeight

    // 失焦遮罩 Popup，放 root 下避免其隐式尺寸参与 ColumnLayout 布局导致控件下移
    Loader {
        active: colum.activeInputText
        visible: active
        sourceComponent: TextInputOverlay {
            activeInputContainer: colum.activeInputText
        }
    }

    ColumnLayout {
        id: colum
        spacing: itemVerticalSpacing
        width: parent.width
        anchors.top: parent.top
        property TextInput activeInputText: null

        Item {
            id: header
            Layout.fillWidth: true
            visible: root.showHeader
            height: !visible ? 0 : (icon.visible ? Math.max(title.implicitHeight, icon.implicitHeight) : title.implicitHeight)

            Text {
                id: title
                anchors.left: parent.left
                anchors.verticalCenter: icon.verticalCenter
                horizontalAlignment: Text.AlignLeft
                font {
                    pixelSize: headerTextFontSize
                }
                color: headerTextColor
                text: adjustModel.title
                opacity: isDisable ? 0.2 : 1
            }
            IconButton {
                id: icon
                visible: iconSource.length > 0
                height: 20
                width: 20
                radius: 4
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                iconSource: adjustModel.icon
                hoverTextFunc: function() {
                    return adjustModel.iconTips;
                }
                onClicked: {
                    adjustModel.iconAction();
                }
            }
        }
        RowLayout {
            id: subTitle
            spacing: 0
            visible: adjustModel.subTitle.length > 0
            Text {
                Layout.preferredWidth: 70
                horizontalAlignment: Text.AlignLeft
                font.pixelSize: 11
                color: Colors.color_CCCCCC
                text: qsTr("pccut_panel_colorrecovery_name")
            }
            Text {
                horizontalAlignment: Text.AlignLeft
                font.pixelSize: 11
                color: Colors.color_EEEEEE
                text: adjustModel.subTitle
            }
        }
        
        Repeater {
            model: adjustModel.allParameter
            delegate: Item {
                Layout.fillWidth: true
                height: itemHeight
                clip: true
                property bool isEditing: false
                property var previousValue: null
                // supportFormula 下用于判断相对运算是否可用（全选态键入替换后禁用 "+10" 等基于原值的写法）
                property bool replacedSelection: false
                // 本次编辑期间是否通过 step=1 触发过实时预览。用于失焦时判断：若最终公式无效/未改，
                // 但中途已经把 model 推到过中间值，需要显式 step=2 归位到 previousValue，避免留下"半改"脏状态
                property bool _hasLivePreview: false

                Component.onCompleted: {
                    maxItemTextWidth = Math.max(maxItemTextWidth, textLabel.implicitWidth);
                }

                Text {
                    id: textLabel
                    anchors {
                        left: parent.left
                        verticalCenter: parent.verticalCenter
                    }
                    width: sliderLeft > 0 ? sliderLeft - 4 : implicitWidth
                    horizontalAlignment: Text.AlignLeft
                    font.pixelSize: 11
                    color: model.value === 0 ? subTitleTextColor : subTitleTextValueColor
                    opacity: isDisable ? 0.2 : 1
                    text: model.title
                    elide: Text.ElideRight
                    Accessible.role: Accessible.Button
                    Accessible.description: "videoedit_" + model.mltName + "_name"
                    MouseArea {
                        anchors.fill: parent
                        enabled: !isDisable
                        onDoubleClicked: {
                            editorManager.pause();
                            model.modelData.updateDouble(model.defaultValue, 2);
                        }
                    }
                }



                Rectangle {
                    id: inputRect
                    anchors {
                        // right: parent.right
                        left: baseSlider.right
                        leftMargin: 8
                        verticalCenter: parent.verticalCenter
                    }
                    width: 28
                    height: 16
                    color: Colors.color_141414
                    radius: 4

                    Text {
                        id: sliderText
                        visible: !isEditing
                        anchors.fill:parent

                        horizontalAlignment: Text.AlignHCenter
                        font.pixelSize: 11
                        color: Colors.color_CCCCCC
                        opacity: isDisable ? 0.2 : 1
                        text: centerSlider.visible ? centerSlider.value : baseSlider.value
                        Accessible.role: Accessible.Button
                        Accessible.description: "videoedit_" + model.mltName + "_value"

                        MouseArea {
                            anchors.fill: parent
                            enabled:!isDisable

                            onClicked: {
                                sliderInputText.text = sliderText.text
                                previousValue = sliderText.text
                                colum.activeInputText = sliderInputText
                                isEditing = true
                                replacedSelection = false
                                sliderInputText.forceActiveFocus()
                                sliderInputText.selectAll()
                                ShortcutObserver.disableAllShortcut(true)

                            }
                        }
                    }

                    TextInput {
                        id: sliderInputText
                        inputMethodHints: Qt.ImhNoEditMenu | Qt.ImhNoPredictiveText
                        selectByMouse: true
                        color: Colors.color_EEEEEE
                        selectionColor: Colors.color_EEEEEE
                        selectedTextColor: Colors.color_1F2021

                        visible: isEditing
                        anchors.fill:parent

                        //输入校验
                        validator: RegularExpressionValidator {
                            // supportFormula 开启后放开运算符/括号/中文全角括号；关闭时保持原有仅数字/负号/小数点
                            regularExpression: root.supportFormula ? /[0-9+\-*/.() （）。．\s]*/ : /^-?\d*\.?\d*$/
                        }

                        maximumLength: 10
                        clip: true
                        horizontalAlignment: TextInput.AlignHCenter
                        font.pixelSize: 11
                        opacity: isDisable ? 0.2 : 1
                        text: centerSlider.visible ? centerSlider.value : baseSlider.value

                        // supportFormula：把中文全角圆括号/句号实时归一化为半角（与 ColorWheelValueEditorBase 同规则），
                        // 并在解析成功时同步做实时预览（step=1 + refreshPlayer，与滑杆拖动同款语义，不入撤销栈）
                        onTextEdited: {
                            if (!root.supportFormula) return
                            var normalized = text.replace(/（/g, '(').replace(/）/g, ')').replace(/。/g, '.').replace(/．/g, '.')
                            if (normalized !== text) {
                                var p = cursorPosition
                                text = normalized
                                cursorPosition = p
                            }
                            // 实时预览：仅在编辑态生效；无效表达式（如 "50+" 输入未完成）不动 model，保留上一次有效预览的视觉
                            if (!isEditing) return
                            let fromValue = model.style === styleBaseSlider?baseSlider.from:centerSlider.from;
                            let toValue = model.style === styleBaseSlider?baseSlider.to:centerSlider.to;
                            let origin = parseFloat(previousValue)
                            if (isNaN(origin)) origin = null
                            let previewResult = CommonUtils.validateFormulaInput(text, fromValue, toValue, origin, replacedSelection)
                            if (previewResult !== null) {
                                editorManager.pause()
                                model.modelData.updateDouble(centerSlider.isBlackPoint ? -previewResult : previewResult, 1)
                                editorManager.refreshPlayer()
                                _hasLivePreview = true
                            }
                        }

                        // supportFormula：在文字被修改"前"检测——若全选状态下键入可见字符，则标记为替换态，
                        // 之后即便首字符是 '+'/'*'/'/'，也走整表达式解析而非"原值 +/*/÷ N"
                        Keys.onPressed: (event) => {
                            if (root.supportFormula
                                    && !replacedSelection
                                    && sliderInputText.text.length > 0
                                    && sliderInputText.selectedText.length === sliderInputText.text.length
                                    && event.text.length === 1
                                    && /[0-9+\-*/.() （）。．]/.test(event.text)
                                    && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier))) {
                                replacedSelection = true
                            }
                        }

                        //优先占用enter键
                        Keys.onShortcutOverride: (event) => {
                            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Tab) {
                                event.accepted = true
                                focus = false
                            }
                        }

                        // 失去焦点时（点击其他区域、Tab）
                        onActiveFocusChanged: {
                            if (!activeFocus && isEditing) {
                                colum.activeInputText = null
                                let fromValue = model.style === styleBaseSlider?baseSlider.from:centerSlider.from;
                                let toValue = model.style === styleBaseSlider?baseSlider.to:centerSlider.to;
                                let result
                                if (root.supportFormula) {
                                    // 相对运算基于 previousValue（进入编辑前的显示值）；对 isBlackPoint 项也是显示值（正向），
                                    // 写回时统一由 centerSlider.isBlackPoint ? -result : result 处理符号，语义保持一致
                                    let origin = parseFloat(previousValue)
                                    if (isNaN(origin)) origin = null
                                    result = CommonUtils.validateFormulaInput(sliderInputText.text, fromValue, toValue, origin, replacedSelection)
                                } else {
                                    result = CommonUtils.validateNumberInput(sliderInputText.text, fromValue, toValue)
                                }
                                if (result !== null) {
                                    //如果本次输入的数值与上次不一致，记入撤销栈
                                    if (!isNaN(previousValue) && result !== Math.round(parseFloat(previousValue))) {
                                        // 数值不相等
                                        //如果不加上这个,会在增加片段的时候,第一次修改参数时无法保存的问题
                                        model.modelData.updateDouble(centerSlider.isBlackPoint ? -result : result, 0)
                                        model.modelData.updateDouble(centerSlider.isBlackPoint ? -result : result, 2)
                                        editorManager.refreshPlayer()      // 刷新视频预览
                                        editorDraftManager.saveDraft()     // 保存草稿
                                    } else if (_hasLivePreview) {
                                        // 结果与原值相同，但实时预览过程中 model 可能已被推到过中间值；
                                        // step=2 归位到 previousValue，不产生撤销条目
                                        let originVal = Math.round(parseFloat(previousValue))
                                        if (!isNaN(originVal)) {
                                            model.modelData.updateDouble(centerSlider.isBlackPoint ? -originVal : originVal, 2)
                                            editorManager.refreshPlayer()
                                        }
                                    }

                                } else if (_hasLivePreview) {
                                    // 最终公式无效（如空/仅剩运算符），但已预览过——把 model 归位到编辑前的值
                                    let originVal = Math.round(parseFloat(previousValue))
                                    if (!isNaN(originVal)) {
                                        model.modelData.updateDouble(centerSlider.isBlackPoint ? -originVal : originVal, 2)
                                        editorManager.refreshPlayer()
                                    }
                                }


                                root.checkDefaultStatus()
                                isEditing = false
                                replacedSelection = false
                                _hasLivePreview = false
                                ShortcutObserver.disableAllShortcut(false)
                            }
                        }
                    }
                }

                LightBaseSlider {
                    id: baseSlider
                    anchors {
                        verticalCenter: parent.verticalCenter
                        left: parent.left
                        leftMargin: sliderLeft
                    }
                    leftPadding: 0
                    width: parent.width - bothSidePadding
                    visible: model.style === 3
                    enabled: !root.isDisable
                    from: 0
                    to: 100
                    value: model.value
                    stepSize: 1
                    snapMode: Slider.SnapAlways
                    anchors.fill: parent.anchors.fill
                    Accessible.role: Accessible.Slider
                    Accessible.description: "videoedit_" + model.mltName + "_tune"

                    onMoved: {
                        if (pressed) {
                            editorManager.pause();
                            model.modelData.updateDouble(value, 1);
                        }
                    }

                    onPressedChanged: {
                        model.modelData.updateDouble(value, pressed ? 0 : 2);
                        if (!pressed) {
                            // 抬手存稿
                            editorDraftManager.saveDraft();
                            eventTracker.trackEvent("pccut_panel_basic_correction", {"correction_value": model.trackEventName})
                        }
                    }
                }

                LightCenterSlider {
                    id: centerSlider
                    visible: model.style !== 3
                    enabled: !root.isDisable
                    width: parent.width - bothSidePadding
                    leftPadding: 0
                    anchors {
                        verticalCenter: parent.verticalCenter
                        left: parent.left
                        leftMargin: sliderLeft
                    }
                    from: minValue
                    to: maxValue
                    value: isBlackPoint ? -model.value : model.value
                    stepSize: 1
                    snapMode: Slider.SnapAlways
                    Accessible.role: Accessible.Slider
                    Accessible.description: "videoedit_exposuretune"
                    // 调节"黑色"和“暗角”的特殊处理
                    // 要求调节"黑色"时,值越小->画面越黑,此处与底层逻辑相反,因为移动端存在历史包袱,底层无法进行修改,这里pc端进行特殊逻辑处理
                    readonly property bool isBlackPoint: model.modelData.mltName === "black_point" || model.modelData.mltName === "mask_ratio"
                    linearGradientColors: {
                        if (model.style === 1) {
                            return [Colors.color_3B6CDF, Colors.color_F6C234];
                        } else if (model.style === 2) {
                            return [Colors.color_26FF31, Colors.color_E312FF];
                        } else {
                            return [];
                        }
                    }
                    onMoved: {
                        if (pressed) {
                            editorManager.pause();
                            model.modelData.updateDouble(isBlackPoint ? -value : value, 1);
                        }
                    }

                    onPressedChanged: {
                        model.modelData.updateDouble(isBlackPoint ? -value : value, pressed ? 0 : 2);
                        if (!pressed) {
                            root.checkDefaultStatus();
                            eventTracker.trackEvent("pccut_panel_basic_correction", {"correction_value": model.trackEventName})
                            root.sliderReleased(model.modelData.mltName || "");
                        }
                    }
                    onValueChanged: {
                        root.checkDefaultStatus();
                    }
                    /**
                     * @desc 撤销、恢复触发， 模拟点击时的行为
                     * @param mltName 滤镜底层名称
                     * @param filter_value 滤镜value
                     */
                    property var onFilterAdjustChanged: function (mltName, filter_value) {
                        if (mltName !== model.modelData.mltName) {
                            return;
                        }
                        model.modelData.updateDouble(isBlackPoint ? -filter_value : filter_value, 2);
                    }
                }
            }
        }
    }
}
