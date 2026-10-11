import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.3
import Config 1.0
import Controls 1.0
import Nova 1.0
import app_qrc 1.0

/**
 *  @File        : SpecialEffectPanel.qml
 *  @Brief       : 特效属性面板（滑杆参数调节）
 *  @Author      : albert.lbrayim
 *  @Date        : 2026-03-12
 */
Rectangle {
    id: root

    // 保留 viewModel 属性以兼容父组件赋值，内部不使用（nova VM 自绑 active env + 选中节点）
    property var viewModel
    // 参数名称列宽
    property real labelWidth: 60
    // 右侧 SpinBox 宽度
    property real spinBoxWidth: 56

    readonly property int leftRightMargin: 12
    readonly property int normalSpacing: 12
    readonly property int expandedSpacing : 16
    readonly property int commonHeight : 16

    // 特效是否处于启用状态（复选框勾选）
    readonly property bool isEffectEnabled: effectVM.isEnable

    anchors.fill: parent
    color: Colors.color_content_area_background

    EffectFilterViewModel {
        id: effectVM
    }

    Flickable {
        id: flickable
        anchors {
            fill: parent
            leftMargin: leftRightMargin
            rightMargin: leftRightMargin
            topMargin: 16 + 3 // TODO:临时措施，与“色彩还原”复选框对齐
        }
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: column
            width: flickable.width
            spacing: 0

            // ── 头部：特效名称 + 重置按钮 ──────────────────────────
            Item {
                id: header
                width: parent.width
                height: commonHeight
                // 有特效即显示开关/重置：用 slug 判断（有特效 filter 即非空），不依赖云名称查询，
                // 避免云端特效在本地资源列表查不到名称时整个 header（含 enable 复选框）被隐藏
                visible: effectVM.slug.length > 0

                CheckBox{
                    id: checkBox_effect
                    text: qsTr("pccut_tab_effects")
                    anchors.verticalCenter: parent.verticalCenter
                    checked: effectVM.isEnable
                    verticalPadding: 0.5
                    indicator: Rectangle {
                        implicitWidth: 14
                        implicitHeight: 14
                        anchors.left: checkBox_effect.left
                        anchors.verticalCenter: parent.verticalCenter
                        color: checkBox_effect.checked ? ColorsConfig.color_brand : Colors.color_454649
                        radius: 4
                        Image {
                            id: icon
                            visible: checkBox_effect.checked
                            anchors.fill: parent
                            source: "qrc:/app_qrc/icons/icon_checkbox_check.svg"
                            sourceSize: Qt.size(parent.width, parent.height)
                        }
                    }

                    contentItem: Text {
                        text: checkBox_effect.text
                        font.pixelSize: 12
                        color: Colors.color_EEEEEE
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: checkBox_effect.indicator.width + 2
                    }

                    onClicked: {
                        // nova：启用/禁用特效节点（保留节点、可撤销）
                        effectVM.isEnable = checkBox_effect.checked
                        editorManager.refreshEffectSlugList()
                        eventTracker.trackEvent("pccut_effect_switch", {
                                                    "effect_slug_string": effectVM.slug,
                                                    "is_open": checkBox_effect.checked
                                                })
                    }
                }

                Image {
                    id: resetBtn
                    anchors {
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }
                    source: resetMouseArea.containsMouse && checkBox_effect.checked
                            ? "qrc:/icons/ic_reset_hover.svg"
                            : "qrc:/icons/ic_reset.svg"
                    sourceSize: Qt.size(20, 20)
                    opacity: checkBox_effect.checked ? 1 : 0.2

                    MouseArea {
                        id: resetMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: checkBox_effect.checked
                        onClicked: {
                            effectVM.resetAllParams();
                            eventTracker.trackEvent("pccut_effect_reset", {"effect_slug_string": effectVM.slug})
                        }
                    }
                }
            }

            // 间距
            Item {
                width: parent.width
                height: commonHeight
                visible: header.visible
            }

            Item{
                id: subName
                width: parent.width
                height: commonHeight
                opacity: root.isEffectEnabled ? 1 : 0.2

                Text{
                    id: nameLabel
                    text: qsTr("pccut_panel_colorrecovery_name") // TODO:此处key是否用特效专用key（暂无）替换？
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: labelWidth

                    font.pixelSize: 11
                    font.weight: Font.Medium
                    color: Colors.color_CCCCCC
                }

                Text {
                    id: nameText
                    // 名称取资源目录显示名(effectNameBySlug)，与轨道 badge 一致；不再用 pccut_effect_name_<slug> 拼 key
                    text: effectVM.effectName
                    anchors.left: nameLabel.right
                    anchors.leftMargin: leftRightMargin
                    anchors.right: parent.right
                    anchors.rightMargin: leftRightMargin
                    anchors.verticalCenter: parent.verticalCenter

                    elide: Text.ElideMiddle
                    horizontalAlignment: Text.AlignLeft
                    font.pixelSize: 11
                    color: Colors.color_EEEEEE
                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        LightToolTip {
                            visible: mouseArea.containsMouse && nameText.implicitWidth > nameText.width
                            tip: nameText.text
                        }
                    }
                }
            }

            // 间距
            Item {
                width: parent.width
                height: commonHeight
            }

            // ── 无特效时的空提示 ──────────────────────────────────
            Item {
                width: parent.width
                height: 60
                visible: effectVM.slug.length === 0

                Text {
                    anchors.centerIn: parent
                    font.pixelSize: 12
                    color: Colors.color_666666
                    text: qsTr("")
                }
            }

            // ── 滑杆列表 ─────────────────────────────────────────
            Column {
                width: parent.width
                spacing: normalSpacing

                Repeater {
                id: paramsRepeater
                model: effectVM.allParams

                delegate: Item {
                    id: paramDelegate
                    width: column.width
                    height: 24
                    clip: true

                    // 0 = LeftRight (center), 1 = RightOnly
                    readonly property int sliderDirection: modelData.direction
                    // 0 = Integer, 1 = Decimal
                    readonly property int sliderScale: modelData.scale
                    // 根据参数范围自动计算步长，保证滑杆约 100 个步进
                    readonly property real autoStepSize: {
                        if (sliderScale === 0) return 1.0;
                        var range = modelData.maxValue - modelData.minValue;
                        if (range <= 0) return 0.1;
                        var raw = range / 100.0;
                        // 取整到最近的 10 的幂次（如 0.001, 0.01, 0.1, 1）
                        var mag = Math.pow(10, Math.floor(Math.log10(raw)));
                        return mag;
                    }
                    // 根据步长推算小数位数
                    readonly property int decimalDigits: {
                        if (sliderScale === 0) return 0;
                        if (autoStepSize >= 1) return 0;
                        return Math.max(0, Math.ceil(-Math.log10(autoStepSize)));
                    }

                    // 格式化数值为显示字符串
                    function formatValue(v) {
                        return sliderScale === 0 ? Math.round(v).toString()
                                                 : v.toFixed(decimalDigits);
                    }

                    // SpinBox 步进值
                    function stepSize() {
                        return autoStepSize;
                    }

                    // 规整、截断并提交数值（step=2 表示一次完整操作结束）
                    function commitRawValue(raw) {
                        var factor = Math.pow(10, decimalDigits);
                        var rounded = Math.round(raw * factor) / factor;
                        var clamped = Math.max(modelData.minValue, Math.min(modelData.maxValue, rounded));
                        editorManager.pause();
                        modelData.updateValue(clamped, 2);
                        editorManager.refreshPlayer();
                        editorDraftManager.saveDraft();
                    }

                    // 执行单次加/减并提交
                    function applyStep(delta) {
                        commitRawValue(modelData.value + delta);
                    }

                    // 名称 label
                    Text {
                        id: labelText
                        anchors {
                            left: parent.left
                            verticalCenter: parent.verticalCenter
                        }
                        width: labelWidth
                        elide: Text.ElideRight
                        font.pixelSize: 11
                        color: Colors.color_CCCCCC
                        opacity: root.isEffectEnabled ? 1 : 0.2
                        text: qsTr("pccut_effect_param_" + modelData.title)
                    }

                    // RightOnly 滑杆（从左边起始）
                    LightBaseSlider {
                        id: baseSlider
                        visible: sliderDirection === 1
                        enabled: visible && root.isEffectEnabled
                        anchors {
                            verticalCenter: parent.verticalCenter
                            left: labelText.right
                            leftMargin: normalSpacing
                            right: spinBox.left
                            rightMargin: normalSpacing
                        }
                        leftPadding: 0
                        from: modelData.minValue
                        to: modelData.maxValue
                        value: modelData.value
                        stepSize: paramDelegate.autoStepSize
                        snapMode: sliderScale === 0 ? Slider.SnapAlways : Slider.NoSnap

                        onMoved: {
                            if (pressed) {
                                editorManager.pause();
                                modelData.updateValue(value, 1);
                                editorManager.refreshPlayer();
                            }
                        }
                        onPressedChanged: {
                            modelData.updateValue(value, pressed ? 0 : 2);
                            editorManager.refreshPlayer();
                            if (!pressed) {
                                editorDraftManager.saveDraft();
                                enabled = false;
                                enabled = Qt.binding(function() { return baseSlider.visible && root.isEffectEnabled; });
                            }
                        }
                    }

                    // LeftRight 滑杆（居中对称）
                    LightCenterSlider {
                        id: centerSlider
                        visible: sliderDirection === 0
                        enabled: visible && root.isEffectEnabled
                        anchors {
                            verticalCenter: parent.verticalCenter
                            left: labelText.right
                            leftMargin: normalSpacing
                            right: spinBox.left
                            rightMargin: normalSpacing
                        }
                        leftPadding: 0
                        from: modelData.minValue
                        to: modelData.maxValue
                        value: modelData.value
                        stepSize: paramDelegate.autoStepSize
                        snapMode: sliderScale === 0 ? Slider.SnapAlways : Slider.NoSnap

                        onMoved: {
                            if (pressed) {
                                editorManager.pause();
                                modelData.updateValue(value, 1);
                                editorManager.refreshPlayer();
                            }
                        }
                        onPressedChanged: {
                            modelData.updateValue(value, pressed ? 0 : 2);
                            editorManager.refreshPlayer();
                            if (!pressed) {
                                editorDraftManager.saveDraft();
                                enabled = false;
                                enabled = Qt.binding(function() { return centerSlider.visible && root.isEffectEnabled; });
                            }
                        }
                    }


                    // ── 自定义 SpinBox（数值显示 + Popup 可编辑输入）──────────
                    Rectangle {
                        id: spinBox
                        anchors {
                            right: arrowsColumn.left
                            rightMargin: 2
                            verticalCenter: parent.verticalCenter
                        }
                        width: spinBoxWidth
                        height: 24
                        radius: 4
                        color: Colors.color_19191A
                        border.width: spinEditPopup.visible ? 1 : 0
                        border.color: ColorsConfig.color_brand
                        opacity: root.isEffectEnabled ? 1 : 0.2

                        // 非编辑状态：只读文本
                        Text {
                            id: spinDisplayText
                            visible: !spinEditPopup.visible
                            anchors.centerIn: parent
                            horizontalAlignment: Text.AlignHCenter
                            font.pixelSize: 11
                            color: Colors.color_EEEEEE
                            text: paramDelegate.formatValue(modelData.value)
                        }

                        // 点击打开编辑 Popup
                        MouseArea {
                            anchors.fill: parent
                            enabled: root.isEffectEnabled
                            onClicked: spinEditPopup.open()
                        }

                        // 编辑 Popup —— 与 TextEditPopup.qml / LightTextEditPopup.qml 同款模式
                        // Popup 脱离 Flickable 层，焦点和按键事件不受 Flickable 干扰
                        Popup {
                            id: spinEditPopup
                            x: 0
                            y: 0
                            width: spinBox.width
                            height: spinBox.height
                            padding: 0

                            // 标记是否已在关闭前主动提交/丢弃，防止 onAboutToHide 重复提交
                            property bool _committed: false

                            function commitValue() {
                                var parsed = parseFloat(valueInput.text)
                                if (!isNaN(parsed)) {
                                    paramDelegate.commitRawValue(parsed)
                                }
                            }

                            onOpened: {
                                _committed = false
                                valueInput.text = spinDisplayText.text
                                valueInput.forceActiveFocus()
                                valueInput.selectAll()
                            }

                            // 点击外部关闭时自动提交当前输入值
                            onAboutToHide: {
                                if (!_committed) {
                                    commitValue()
                                }
                                _committed = false
                            }

                            background: Rectangle {
                                color: Colors.color_19191A
                                border.width: 1
                                border.color: ColorsConfig.color_brand
                                radius: 4
                            }

                            // contentItem 持有 focus，Keys 放在这里捕获从 TextInput 冒泡的按键
                            contentItem: Item {
                                focus: true

                                TextInput {
                                    id: valueInput
                                    anchors.centerIn: parent
                                    width: parent.width - 4
                                    horizontalAlignment: TextInput.AlignHCenter
                                    font.pixelSize: 11
                                    color: Colors.color_EEEEEE
                                    selectByMouse: true
                                    clip: true
                                    // sliderScale=0：仅整数；sliderScale≠0：最多一位小数
                                    validator: RegularExpressionValidator {
                                        regularExpression: sliderScale === 0
                                                           ? /^-?[0-9]*$/
                                                           : /^-?[0-9]*\.?[0-9]?$/
                                    }
                                }

                                Keys.onPressed: function(event) {
                                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                        spinEditPopup._committed = true
                                        spinEditPopup.commitValue()
                                        spinEditPopup.close()
                                        event.accepted = true
                                    } else if (event.key === Qt.Key_Escape) {
                                        spinEditPopup._committed = true  // 丢弃，跳过 onAboutToHide 提交
                                        spinEditPopup.close()
                                        event.accepted = true
                                    }
                                }
                            }
                        }
                    }

                    // 上下箭头
                    Item {
                        id: arrowsColumn
                        anchors {
                            right: parent.right
                            // rightMargin: 2
                            verticalCenter: parent.verticalCenter
                        }
                        width: 10
                        height: parent.height
                        opacity: root.isEffectEnabled ? 1 : 0.2

                        Image {
                            id: upArea
                            anchors {
                                top: parent.top
                                topMargin: 1
                            }
                            source: "qrc:/icons/ic_next_up.svg"
                            sourceSize: Qt.size(10, 10)

                            MouseArea {
                                anchors.fill: parent
                                enabled: root.isEffectEnabled
                                onClicked: paramDelegate.applyStep(paramDelegate.stepSize())
                            }
                        }

                        Image {
                            id: downArea
                            anchors {
                                bottom: parent.bottom
                                bottomMargin: 1
                            }
                            source: "qrc:/icons/ic_next_down.svg"
                            sourceSize: Qt.size(10, 10)

                            MouseArea {
                                anchors.fill: parent
                                enabled: root.isEffectEnabled
                                onClicked: paramDelegate.applyStep(-paramDelegate.stepSize())
                            }
                        }
                    }
                }
                }
            }
        }
    }
}
