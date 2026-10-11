import QtQuick 2.15
import QtQuick.Controls
import Config 1.0
import Controls 1.0
import Nova 1.0
import UsedFunctionManager 1.0

/**
 * @author: mathy.shi
 * @details ND 滤镜（运动模糊）设置 - 共享组件，被 QualitySettingsPanel（全景）和 RegSpeedPanel（普通视频）复用
 */
Item {
    id: root
    property NdFilterViewModel controller
    property var projectId
    // true：入口+展开模式（关闭时只显示标题行 + 开关），用于 RegSpeedPanel
    // false：始终展开模式（关闭时滑杆灰显），保持 QualitySettingsPanel 旧行为
    property bool collapsible: false
    // ndFilter 标题行高度。默认 48（QualitySettingsPanel 设计），
    // RegularImagePanel 用 20 以与音频面板"音量"标签行高对齐。
    property int headerHeight: 48
    // 标题行变矮后到模糊范围滑杆之间需要补偿的间距，使"标题文字 → 滑杆"垂直距离
    // 与原设计 (headerHeight=48) 一致。公式 = (48 - headerHeight) / 2。
    readonly property int detailsTopMargin: Math.max(0, (48 - headerHeight) / 2)

    property bool detailsVisible: collapsible ? lightBaseSwitch1.checked : true

    width: parent ? parent.width : 0
    height: ndFilter.height + (detailsVisible ? (detailsTopMargin + vagueRange.height + spilitRec.height + vagueStrength.height) : 0)

    // 运动模糊开关
    Rectangle {
        id: ndFilter
        z:2
        width: parent.width
        height: root.headerHeight
        // color: "red"

        anchors.left: parent.left
        visible: true
        color: Colors.color_transparent
        Text {
            id: filterTitle
            anchors.left: parent.left
            anchors.topMargin: 0;
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignLeft
            font {
                pixelSize: 12
            }
            color: Colors.color_EEEEEE
            text: qsTr("pccut_image_nd_switch")
        }

        Image {
            id:descriptIcon
            anchors{
                left: filterTitle.right
                leftMargin: 4
                verticalCenter: parent.verticalCenter
            }

            source: descriptIconMouseArea.containsMouse ? "qrc:/icons/ic_explain.svg" : "qrc:/icons/ic_explain_hover.svg"
            sourceSize: Qt.size(14, 14)

            MouseArea {
                id: descriptIconMouseArea
                anchors.fill: parent
                hoverEnabled: true
            }
        }


        Rectangle{
            id: ndDescriptTips
            z:10
            visible: descriptIconMouseArea.containsMouse
            width: 256
            height: 42

            anchors{
                top: descriptIcon.bottom
                topMargin: 4
                left: ndFilter.left
            }

            Text{
                text: qsTr("pccut_image_nd_switch_tip")
                width: parent.width - 8 * 2
                height: parent.height
                anchors.centerIn: parent
                verticalAlignment: Text.AlignVCenter
                wrapMode: Text.WordWrap
                font {
                    pixelSize: 11
                }
                color: Colors.color_EEEEEE
            }

            radius: 4
            color: Colors.color_19191A
            border.width: 1
            border.color: Colors.color_454649
        }

        // 重置
        Image {
            id:resetIcon
            enabled: lightBaseSwitch1.checked
            anchors{
                right: userInAll.left
                rightMargin: 16
                verticalCenter: parent.verticalCenter
            }

            source: !resetIcon.enabled ? "qrc:/icons/ic_reset.svg" :  resetMouseArea.containsMouse ? "qrc:/icons/ic_reset_hover.svg" : "qrc:/icons/ic_reset.svg"

            sourceSize: Qt.size(20, 20)
            opacity: lightBaseSwitch1.checked ? 1 : 0.2
            MouseArea {
                id: resetMouseArea
                anchors.fill: parent
                onClicked: {
                    root.controller.resetValue();
                }

                hoverEnabled: true
            }
        }

        Rectangle{
            id: userInAll
            enabled: lightBaseSwitch1.checked
            width: 73;
            height: 20;
            color: !enabled ? Colors.color_353738 : useAllBtn.containsMouse ? Colors.color_414344 : Colors.color_353738
            radius: 4
            anchors{
                right: lightBaseSwitch1.left
                rightMargin: 16
                verticalCenter: parent.verticalCenter
            }
            opacity: lightBaseSwitch1.checked ? 1 : 0.2

            Text {
                text: qsTr("pccut_image_nd_all")
                anchors.centerIn: parent
                verticalAlignment: Text.AlignVCenter
                wrapMode: Text.WordWrap
                font {
                    pixelSize: 11
                }
                color: Colors.color_EEEEEE
            }

            MouseArea {
                id: useAllBtn
                anchors.fill: parent
                onClicked: {
                    root.controller.applyToAll();
                    toast.showToast(qsTr("pccut_adjust_applied_all"));
                }
                hoverEnabled: true
            }

        }

        LightBaseSwitch {
            id: lightBaseSwitch1
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 24
            height: 14
            checked: root.controller ? root.controller.isEnable : false

            onToggledSignal: {
                if(checked) {
                    UsedFunctionManager.removeFunction(root.projectId,UsedFunctionManager.EditorFunctionType.MOTION_BLUR);
                    UsedFunctionManager.addFunction(root.projectId,UsedFunctionManager.EditorFunctionType.MOTION_BLUR);
                    toast.showToast(qsTr("pccut_image_nd_on_tip"));
                }else{
                    UsedFunctionManager.removeFunction(root.projectId,UsedFunctionManager.EditorFunctionType.MOTION_BLUR);
                    toast.showToast(qsTr("pccut_image_nd_off_tip"));
                }
            }

            onCheckedChanged: {
                if (root.controller) {
                    root.controller.isEnable = lightBaseSwitch1.checked;
                }
            }

            Connections{
                target: root.controller
                function onIsEnableChanged() {
                    lightBaseSwitch1.checked = root.controller.isEnable;
                }
            }
        }
    }

    // 模糊范围设置
    Rectangle{
        id: vagueRange
        enabled: lightBaseSwitch1.checked
        visible: root.detailsVisible
        height: visible ? 24 : 0
        anchors.top: ndFilter.bottom
        anchors.topMargin: root.detailsTopMargin
        anchors.left: parent.left
        anchors.right: parent.right
        color: Colors.transparent
        Text {
            id: title
            width: 63
            height: 16
            anchors.verticalCenter: parent.verticalCenter
            font {
                pixelSize: 11
            }
            color: Colors.color_999999
            opacity: lightBaseSwitch1.checked ? 1 : 0.2
            text: qsTr("pccut_image_nd_fuzzy_range")
        }

        LightBaseSlider {
            id: baseSlider
            property int lastValue : 100
            property real sliderLeft: 70
            leftPadding: 0
            anchors{
                left: title.right
                right:rangeValue.left
                leftMargin: 12
                rightMargin:12
                verticalCenter: parent.verticalCenter
            }

            enabled: true
            visible: true
            height: 12
            from: 0
            to: 100
            value: 85
            stepSize: 1
            snapMode: Slider.SnapAlways
            Accessible.role: Accessible.Slider
            onMoved: {
                root.controller.ndLength = baseSlider.value;
            }

            onValueChanged:{
                rangeValueTextField.text = value;
            }

            onPressedChanged: {
                forceActiveFocus()
                if (!pressed) {
                    root.controller.ndLength = baseSlider.value;  // 保证当前的片段的filterModel已经更新
                    root.controller.addParamsChangedUnDoAction();  // 添加撤销恢复栈
                }
            }

            Component.onCompleted: {
                if (root.controller) {
                    baseSlider.value = root.controller.ndLength;
                }
            }

            Connections{
                target: root.controller
                function onNdLengthChanged(){
                    baseSlider.value = root.controller.ndLength;
                }
            }
        }

        Rectangle{
            id: rangeValue
            width: 50
            height: parent.height
            anchors{
                right: adjustContainer.left
                rightMargin: 2
            }

            radius: 4
            color: Colors.color_19191A
            opacity: lightBaseSwitch1.checked ? 1 : 0.2

                TextField {
                    id: rangeValueTextField
                    color: Colors.color_EEEEEE
                    anchors.fill: parent
                    font {
                        pixelSize: 11
                    }
                    horizontalAlignment: TextInput.AlignHCenter
                    text: qsTr(baseSlider.value.toString())
                    selectionColor: Colors.color_EEEEEE
                    selectedTextColor: Colors.color_1F2021
                    background: Rectangle {
                        color: Colors.color_19191A
                        radius: 4
                    }
                    property int minValue: 0
                    property int maxValue: 100
                    // 输入限制：只能输入数字
                    validator: IntValidator {
                        bottom: rangeValueTextField.minValue
                        top: rangeValueTextField.maxValue
                    }
                    Keys.onReturnPressed: {
                        focus = false
                    }
                    Keys.onEscapePressed: {
                        text = baseSlider.value.toString()
                        focus = false
                    }
                    // 编辑结束（Enter / 失去 activeFocus）时把值写入 controller。
                    // 不用 onFocusChanged：`focus` 受 focus scope 影响，鼠标点其他区域
                    // 时 activeFocus 已为 false 但 focus 未必同步，会漏触发。
                    // 不用 onEditingFinished：当输入 >100 时 IntValidator 返回 Intermediate，
                    // editingFinished 在非 Acceptable 状态下不会发，clamp 逻辑跑不到。
                    // onActiveFocusChanged 对 validator 状态无感，焦点一离开就触发。
                    onActiveFocusChanged: {
                        if (activeFocus) return;
                        if (text.length > 0) {
                            var value = parseInt(text);
                            if (!isNaN(value)) {
                                if (value < minValue) {
                                    value = minValue;
                                }
                                if (value > maxValue) {
                                    value = maxValue;
                                }
                                baseSlider.value = value;
                                text = value
                                root.controller.ndLength = value;
                                root.controller.addParamsChangedUnDoAction()
                            } else {
                                text = baseSlider.value.toString()
                            }
                        } else {
                            text = baseSlider.value.toString()
                        }
                    }
                    Keys.onShortcutOverride: function(event) {
                        if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                            focus = false;
                            event.accepted = true
                        }
                    }
                    Keys.onPressed: function(event) {
                        if (event.text < '0' || event.text > '9') {
                            event.accepted = false;
                        }
                    }
                }
            }

        Item{
            id: adjustContainer
            height: parent.height
            width: 16
            anchors{
                right: parent.right
                verticalCenter: parent.verticalCenter
            }

            // 使用 Column 布局避免重叠
            Column {
                anchors.centerIn: parent
                spacing: 2  // 两个按钮之间的间距

                // 上箭头
                Rectangle {
                    width: 10
                    height: 10
                    radius: 2
                    color: upMouseArea.containsMouse && lightBaseSwitch1.checked ? Colors.color_353738 : Colors.color_transparent

                    Image{
                        anchors.centerIn: parent
                        source: "qrc:/icons/ic_next_up.svg"
                        sourceSize: Qt.size(10, 10)
                        opacity: lightBaseSwitch1.checked ? (upMouseArea.containsMouse ? 1 : 0.8) : 0.2
                        Behavior on opacity {
                            NumberAnimation {
                                duration: 100
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    MouseArea {
                        id: upMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: lightBaseSwitch1.checked ? Qt.PointingHandCursor : Qt.ArrowCursor

                        onClicked: {
                            forceActiveFocus()
                            baseSlider.value = Math.min(baseSlider.value + 1, 100)
                            root.controller.ndLength = baseSlider.value;
                            root.controller.addParamsChangedUnDoAction();
                        }
                    }
                }

                // 下箭头
                Rectangle {
                    width: 10
                    height: 10
                    radius: 2
                    color: downMouseArea.containsMouse && lightBaseSwitch1.checked ? Colors.color_353738 : Colors.color_transparent

            Image{
                anchors.centerIn: parent
                source: "qrc:/icons/ic_next_down.svg"
                sourceSize: Qt.size(10, 10)
                opacity: lightBaseSwitch1.checked ? (downMouseArea.containsMouse ? 1 : 0.8) : 0.2
                Behavior on opacity {
                    NumberAnimation {
                        duration: 100
                        easing.type: Easing.OutCubic
                    }
                    }
                }

                MouseArea {
                    id: downMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: lightBaseSwitch1.checked ? Qt.PointingHandCursor : Qt.ArrowCursor

                    onClicked: {
                        forceActiveFocus()
                        baseSlider.value = Math.max(baseSlider.value - 1, 0)
                        root.controller.ndLength = baseSlider.value;  // 保证当前的片段的filterModel已经更新
                        root.controller.addParamsChangedUnDoAction();  // 添加撤销恢复栈
                    }
                }
            }
            }
        }
    }

    Rectangle{
        id: spilitRec
        visible: root.detailsVisible
        height: visible ? 12 : 0
        anchors.top: vagueRange.bottom
    }

    // 模糊强度设置
    Rectangle{
        id: vagueStrength
        enabled: lightBaseSwitch1.checked
        visible: root.detailsVisible
        height: visible ? 24 : 0
        anchors.top: spilitRec.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        color: Colors.transparent
        opacity: 1

        Text {
            id: strengthText
            width: 63
            height: 16
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            font {
                pixelSize: 11
            }
            color: Colors.color_999999
            opacity: lightBaseSwitch1.checked ? 1 : 0.2
            text: qsTr("pccut_image_nd_fuzzy_strength")
        }

        LightBaseSlider {
            id: strengthSlider
            property int lastValue : 100
            property real sliderLeft: 70
            leftPadding: 0
            anchors{
                left: strengthText.right
                right:strengthValue.left
                leftMargin: 12
                rightMargin:12
                verticalCenter: parent.verticalCenter
            }
            visible: true
            height: 12
            from: 0
            to: 100
            value: root.controller ? root.controller.ndStrength : 50
            stepSize: 1
            snapMode: Slider.SnapAlways
            Accessible.role: Accessible.Slider
            onMoved: {
                root.controller.ndStrength = strengthSlider.value;
            }

            onPressedChanged: {
                forceActiveFocus()
                if (!pressed) {
                    root.controller.ndStrength = strengthSlider.value;
                    root.controller.addParamsChangedUnDoAction();  // 添加撤销恢复栈
                }
            }

            Connections{
                target: root.controller
                function onNdStrengthChanged(){
                    strengthSlider.value = root.controller.ndStrength;
                }
            }
        }

        Rectangle{
            id: strengthValue
            width: 50
            height: parent.height
            anchors{
                right: strengthAdjustContainer.left
                leftMargin: 12
            }

            radius: 4
            color: Colors.color_19191A
            opacity: lightBaseSwitch1.checked ? 1 : 0.2

            TextField {
                id: strengthValueTextField
                color: Colors.color_EEEEEE
                anchors.centerIn: parent
                font {
                    pixelSize: 11
                }
                horizontalAlignment: TextInput.AlignHCenter
                text: strengthSlider.value.toString()
                width: 45
                height: 24
                background: Rectangle {
                    color: Colors.color_19191A
                    radius: 4
                }
                selectionColor: Colors.color_EEEEEE
                selectedTextColor: Colors.color_1F2021

                property int minValue: 0
                property int maxValue: 100
                validator: IntValidator {
                    bottom: strengthValueTextField.minValue
                    top: strengthValueTextField.maxValue
                }

                Keys.onReturnPressed: {
                    focus = false
                }
                Keys.onEscapePressed: {
                    text = strengthSlider.value.toString()
                    focus = false
                }
                // 同 rangeValueTextField：用 onActiveFocusChanged 才能在输入超过 maxValue
                // （IntValidator 返回 Intermediate，editingFinished 不发）时也触发 clamp。
                onActiveFocusChanged: {
                    if (activeFocus) return;
                    if (text.length > 0) {
                        var value = parseInt(text)
                        if (!isNaN(value)) {
                            if (value < minValue) value = minValue
                            if (value > maxValue) value = maxValue
                            strengthSlider.value = value
                            text = value
                            root.controller.ndStrength = value
                            root.controller.addParamsChangedUnDoAction()
                        } else {
                            text = strengthSlider.value.toString()
                        }
                    } else {
                        text = strengthSlider.value.toString()
                    }
                }

                Keys.onShortcutOverride: function(event) {
                    if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                        focus = false
                        event.accepted = true
                    }
                }

                Keys.onPressed: function(event) {
                    if (event.text < '0' || event.text > '9') {
                        event.accepted = false
                    }
                }

                Connections {
                    target: strengthSlider
                    function onValueChanged() {
                        if (!strengthValueTextField.activeFocus) {
                            strengthValueTextField.text = strengthSlider.value.toString()
                        }
                    }
                }
            }
        }

        Item{
            id: strengthAdjustContainer
            height: parent.height
            width: 16
            anchors{
                right: parent.right
                verticalCenter: parent.verticalCenter
            }

            // 使用 Column 布局避免重叠
            Column {
                anchors.centerIn: parent
                spacing: 2  // 两个按钮之间的间距

                // 上箭头
                Rectangle {
                    width: 10
                    height: 10
                    radius: 2
                    color: strengthUpMouseArea.containsMouse && lightBaseSwitch1.checked ? Colors.color_353738 : Colors.color_transparent

                    Image{
                        anchors.centerIn: parent
                        source: "qrc:/icons/ic_next_up.svg"
                        opacity: lightBaseSwitch1.checked ? (strengthUpMouseArea.containsMouse ? 1 : 0.8) : 0.2
                        sourceSize: Qt.size(10, 10)
                        Behavior on opacity {
                            NumberAnimation {
                                duration: 100
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    MouseArea {
                        id: strengthUpMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: lightBaseSwitch1.checked ? Qt.PointingHandCursor : Qt.ArrowCursor

                        onClicked: {
                            forceActiveFocus()
                            strengthSlider.value = Math.min(strengthSlider.value + 1, 100)
                            root.controller.ndStrength = strengthSlider.value;
                            root.controller.addParamsChangedUnDoAction();
                        }
                    }
                }

                // 下箭头
                Rectangle {
                    width: 10
                    height: 10
                    radius: 2
                    color: strengthDownMouseArea.containsMouse && lightBaseSwitch1.checked ? Colors.color_353738 : Colors.color_transparent

                    Image{
                        anchors.centerIn: parent
                        source: "qrc:/icons/ic_next_down.svg"
                        sourceSize: Qt.size(10, 10)
                        opacity: lightBaseSwitch1.checked ? (strengthDownMouseArea.containsMouse ? 1 : 0.8) : 0.2
                        Behavior on opacity {
                            NumberAnimation {
                                duration: 100
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    MouseArea {
                        id: strengthDownMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: lightBaseSwitch1.checked ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            forceActiveFocus()
                            strengthSlider.value = Math.max(strengthSlider.value - 1, 0)
                            root.controller.ndStrength = strengthSlider.value
                            root.controller.addParamsChangedUnDoAction();
                        }
                    }
                }
            }
        }
    }

    // 模糊方向 由于底层暂不支持设置模糊方向，暂时屏蔽， 不要删除这段代码
    //     Rectangle{
    //         id: vagueDirect
    //         enabled: lightBaseSwitch1.checked
    //         visible: false;  // 由于底层暂不支持设置模糊方向，暂时屏蔽
    //         width: parent.width
    //         height: 24
    //         color: Colors.transparent
    //         anchors{
    //             top: vagueStrength.bottom
    //             topMargin: 0
    //         }
    //         // ... 详见旧 QualitySettingsPanel motionBlurItem 中 vagueDirect 完整代码
    //     }
}
