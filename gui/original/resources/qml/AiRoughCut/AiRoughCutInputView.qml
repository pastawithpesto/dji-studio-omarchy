import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.15
import Config 1.0
import Controls 1.0
import Qt5Compat.GraphicalEffects
import app_qrc 1.0
import UIComponent

/**
 * 输入页：画面描述（卡片内输入框+快捷标签）、时长选择、远端动态配置项、开始分析按钮
 */
Item {
    id: root

    property var context: null
    property var viewModel: null

    // 下拉框数据
    property var durationOptions: [qsTr("pccut_roughcut_duration_short"), qsTr("pccut_roughcut_duration_medium")]

    // 从 context 恢复 durationIndex（30→0, 60→1，否则默认 0）
    property int durationIndex: {
        if (!context || context.targetDuration === 0) return 0;
        var durations = [30, 60, 120];
        var idx = durations.indexOf(context.targetDuration);
        return idx >= 0 ? idx : 0;
    }

    // 动态配置项选中索引（与 dynamicSettings 数组一一对应）
    property var dynamicSelections: context ? context.dynamicSelections : []

    // 初始化 context 默认参数（仅首次，返回时不覆盖已有值）
    Component.onCompleted: {
        if (!context) return;

        // targetDuration === 0 表示 reset 后的初始状态，设为默认值
        if (context.targetDuration === 0) {
            context.targetDuration = 30;
        }

        // 动态配置项：仅当 context 中无已保存选中时初始化
        if (viewModel && viewModel.dynamicSettings) {
            var settings = viewModel.dynamicSettings;
            var saved = context.dynamicSelections;
            if (saved && saved.length === settings.length) {
                // 已有保存值，同步到 viewModel
                dynamicSelections = saved;
                viewModel.setDynamicSelections(saved);
            } else {
                // 首次：初始化为每项第一个有效选项
                var arr = [];
                for (var i = 0; i < settings.length; i++) {
                    var firstValid = 0;
                    var cfg = settings[i].config;
                    if (cfg) {
                        for (var j = 0; j < cfg.length; j++) {
                            if (cfg[j].promptKey && cfg[j].promptKey.length > 0) {
                                firstValid = j;
                                break;
                            }
                        }
                    }
                    arr.push(firstValid);
                }
                dynamicSelections = arr;
                context.dynamicSelections = arr;
                viewModel.setDynamicSelections(arr);
            }
        }
    }

    // 每次显示输入页时，从磁盘刷新协议勾选状态
    // hasEverAccepted：是否曾从协议页点过"同意"，首次必须走协议页，不能手动勾选
    property bool hasEverAccepted: lightSetting.getBool("aiAgreementEverAccepted", false)
    // 点击"开始分析"时若未授权，弹窗确认后自动开始分析
    property bool _startAfterAgreement: false

    onVisibleChanged: {
        if (visible) {
            lightSetting.sync();
            hasEverAccepted = lightSetting.getBool("aiAgreementEverAccepted", false);
            agreementCheckBox.checked = lightSetting.getBool("aiAgreementAccepted", false);
        }
    }

    // 当前选中的快捷标签索引（-1 表示未选中）
    property int selectedTagIndex: -1

    // 可滚动内容区
    ScrollView {
        id: scrollView
        anchors.top: parent.top
        anchors.topMargin: 24
        anchors.left: parent.left
        anchors.leftMargin: 28
        anchors.right: parent.right
        anchors.rightMargin: 2
        anchors.bottom: bottomBar.top
        anchors.bottomMargin: 36

        Component.onCompleted: {
            scrollView.contentItem.boundsBehavior = Flickable.StopAtBounds;
        }

        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        ScrollBar.vertical: ScrollBar {
            policy: contentColumn.implicitHeight > scrollView.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
            anchors {
                right: parent.right
                top: parent.top
                bottom: parent.bottom
            }
            contentItem: Rectangle {
                implicitWidth: 6
                implicitHeight: 0
                radius: 3
                color: Colors.color_454649
            }
        }

        clip: true

    ColumnLayout {
        id: contentColumn
        width: scrollView.width - 26
        spacing: 16

        // ===== 画面描述 =====
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 12

            UIText {
                type: UITextType.Primary
                size: UIControlSize.M
                font.weight: Font.Medium
                text: qsTr("pccut_roughcut_description_label")
            }

            // 深色卡片（输入框 + 快捷标签）
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 94
                radius: 8
                color: Colors.color_1F2021

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 10

                    // 输入框
                    UITextArea {
                        id: promptInput
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        paddingH: 0
                        paddingV: 0
                        borderVisible: false
                        bgColor: "transparent"
                        placeholderText: qsTr("pccut_roughcut_description_placeholder")
                        maxLength: 800
                        text: context.prompt
                        onTextChanged: {
                            context.prompt = text;
                            if (text.length === 0) root.selectedTagIndex = -1;
                        }
                    }

                    // 快捷标签
                    Row {
                        id: tagRow
                        Layout.fillWidth: true
                        spacing: 8

                        Repeater {
                            model: [
                                { label: qsTr("pccut_roughcut_tag_slow"), desc: qsTr("pccut_roughcut_tag_slow_tex") },
                                { label: qsTr("pccut_roughcut_tag_vlog"), desc: qsTr("pccut_roughcut_tag_vlog_tex") },
                                { label: qsTr("pccut_auto_edit_style_rhythm"), desc: qsTr("pccut_auto_edit_style_rhythm_tex") }
                            ]
                            delegate: Rectangle {
                                property bool isSelected: root.selectedTagIndex === index

                                width: 60//Math.min(tagText.implicitWidth + 16, (tagRow.width - tagRow.spacing * 2) / 3)
                                height: 24
                                radius: 4
                                color: "transparent"
                                border.width: 1
                                border.color: isSelected ? Colors.color_EEEEEE
                                             : pbtMouseArea.containsMouse ? Colors.color_EEEEEE : Colors.color_454649

                                UIText {
                                    id: tagText
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    // anchors.leftMargin: 8
                                    // anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.label
                                    type: UITextType.Secondary
                                    size: UIControlSize.M
                                    elide: Text.ElideRight
                                    horizontalAlignment: Text.AlignHCenter
                                    color: isSelected ? Colors.color_EEEEEE
                                         : pbtMouseArea.containsMouse ? Colors.color_EEEEEE : Colors.color_999999
                                }

                                LightToolTip {
                                    visible: tagText.truncated && pbtMouseArea.containsMouse
                                    tip: modelData.label
                                }

                                MouseArea {
                                    id: pbtMouseArea
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    onClicked: {
                                        if (root.selectedTagIndex === index) {
                                            // 再次点击取消选中，清空输入
                                            root.selectedTagIndex = -1;
                                            promptInput.text = "";
                                        } else {
                                            root.selectedTagIndex = index;
                                            promptInput.text = modelData.desc;
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ===== 时长选择 =====
        RowLayout {
            Layout.fillWidth: true
            spacing: 11

            UIText {
                type: UITextType.Primary
                size: UIControlSize.M
                text: qsTr("pccut_roughcut_duration_label")
                Layout.preferredWidth: 49
                elide: Text.ElideRight
            }

            Rectangle {
                id: durationSelector
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                radius: 4
                color: durationArea.containsMouse ? Colors.color_68696D : Colors.color_454649

                UIText {
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: durationOptions[durationIndex]
                    type: UITextType.Primary
                    size: UIControlSize.M
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Image {
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 20
                    height: 20
                    source: durationPopup.visible
                        ? "qrc:/icons/adjustment/icon_drop_down_menu_collapse.svg"
                        : "qrc:/icons/adjustment/icon_drop_down_menu_expand.svg"
                    sourceSize: Qt.size(20, 20)
                }

                MouseArea {
                    id: durationArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var pos = durationSelector.mapToItem(null, 0, durationSelector.height + 4)
                        durationDropRect.x = pos.x
                        durationDropRect.y = pos.y
                        durationPopup.open()
                    }
                }

                LightPopup {
                    id: durationPopup
                    width: root.Window.window ? root.Window.window.width : 800
                    height: root.Window.window ? root.Window.window.height : 600
                    z: 9999
                    modal: false
                    parent: Overlay.overlay
                    needTransparent: true
                    contentItem: Item {
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: durationPopup.close()
                            onWheel: function(wheel) { wheel.accepted = true; }
                        }
                        Rectangle {
                            id: durationDropRect
                            width: durationSelector.width
                            height: 28 * durationOptions.length + 4 * (durationOptions.length - 1) + 8
                            radius: 4
                            color: Colors.color_454649
                            layer.enabled: true
                            layer.effect: DropShadow {
                                horizontalOffset: 0
                                verticalOffset: 0
                                radius: 10
                                color: Colors.color_000000_40
                            }
                            Column {
                                topPadding: 4; bottomPadding: 4; leftPadding: 4; rightPadding: 4
                                spacing: 4
                                Repeater {
                                    model: durationOptions
                                    Rectangle {
                                        width: durationDropRect.width - 8
                                        height: 28
                                        radius: 4
                                        color: durationItemArea.containsMouse ? Colors.color_FFFFFF_15 : "transparent"
                                        UIText { anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter
                                            text: modelData; type: UITextType.Primary; size: UIControlSize.M
                                        }
                                        Image {
                                            anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                                            width: 16; height: 16; sourceSize: Qt.size(16, 16); visible: index === durationIndex
                                            source: "qrc:/icons/adjustment/icon_compose_check.svg"
                                        }
                                        MouseArea {
                                            id: durationItemArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: { durationIndex = index; var durations = [30, 60, 120]; context.targetDuration = durations[index]; durationPopup.close(); }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ===== 远端动态配置项 =====
        Repeater {
            model: viewModel ? viewModel.dynamicSettings : []

            delegate: RowLayout {
                id: dynamicRow

                property int settingIndex: index
                property var settingData: modelData
                property var configItems: {
                    var cfg = settingData.config;
                    if (!cfg) return [];
                    var valid = [];
                    for (var i = 0; i < cfg.length; i++) {
                        if (cfg[i].promptKey && cfg[i].promptKey.length > 0) valid.push(cfg[i]);
                    }
                    return valid;
                }
                property bool hasSub: {
                    for (var i = 0; i < configItems.length; i++) {
                        if (configItems[i].subtitleKey && configItems[i].subtitleKey.length > 0) return true;
                    }
                    return false;
                }
                property int selectedIndex: (settingIndex < dynamicSelections.length) ? dynamicSelections[settingIndex] : 0
                property var selectedItem: {
                    var cfg = settingData.config;
                    if (!cfg || selectedIndex < 0 || selectedIndex >= cfg.length) return null;
                    return cfg[selectedIndex];
                }

                visible: configItems.length > 0
                Layout.fillWidth: true
                spacing: 11

                UIText {
                    type: UITextType.Primary
                    size: UIControlSize.M
                    text: dynamicRow.settingData.titleKey ? qsTr(dynamicRow.settingData.titleKey) : ""
                    Layout.preferredWidth: 49
                    elide: Text.ElideRight
                }

                Rectangle {
                    id: dynSelector
                    Layout.fillWidth: true
                    Layout.preferredHeight: dynamicRow.hasSub ? 51 : 28
                    radius: 4
                    color: dynTriggerArea.containsMouse ? Colors.color_68696D : Colors.color_454649

                    // 双行样式
                    Column {
                        visible: dynamicRow.hasSub && dynamicRow.selectedItem !== null
                        anchors.left: parent.left
                        anchors.right: dynArrow.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 12
                        spacing: 4

                        UIText {
                            text: (dynamicRow.selectedItem && dynamicRow.selectedItem.titleKey) ? qsTr(dynamicRow.selectedItem.titleKey) : ""
                            type: UITextType.Primary
                            size: UIControlSize.M
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                        }
                        UIText {
                            text: (dynamicRow.selectedItem && dynamicRow.selectedItem.subtitleKey) ? qsTr(dynamicRow.selectedItem.subtitleKey) : ""
                            type: UITextType.Secondary
                            size: UIControlSize.S
                            elide: Text.ElideRight
                            width: parent.width
                            visible: text.length > 0
                        }
                    }

                    // 单行样式
                    UIText {
                        visible: !dynamicRow.hasSub && dynamicRow.selectedItem !== null
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: (dynamicRow.selectedItem && dynamicRow.selectedItem.titleKey) ? qsTr(dynamicRow.selectedItem.titleKey) : ""
                        type: UITextType.Primary
                        size: UIControlSize.M
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    Image {
                        id: dynArrow
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: 20; height: 20
                        source: dynPopup.visible
                            ? "qrc:/icons/adjustment/icon_drop_down_menu_collapse.svg"
                            : "qrc:/icons/adjustment/icon_drop_down_menu_expand.svg"
                        sourceSize: Qt.size(20, 20)
                    }

                    MouseArea {
                        id: dynTriggerArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var pos = dynSelector.mapToItem(null, 0, dynSelector.height + 4)
                            dynDropRect.x = pos.x
                            dynDropRect.y = pos.y
                            dynPopup.open()
                        }
                    }

                    LightPopup {
                        id: dynPopup
                        width: root.Window.window ? root.Window.window.width : 800
                        height: root.Window.window ? root.Window.window.height : 600
                        z: 9999
                        modal: false
                        parent: Overlay.overlay
                        needTransparent: true
                        contentItem: Item {
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: dynPopup.close()
                                onWheel: function(wheel) { wheel.accepted = true; }
                            }
                            Rectangle {
                                id: dynDropRect
                                width: dynSelector.width
                                height: dynamicRow.hasSub
                                    ? dynamicRow.configItems.length * 55 + 4 * (dynamicRow.configItems.length - 1) + 8
                                    : dynamicRow.configItems.length * 28 + 4 * (dynamicRow.configItems.length - 1) + 8
                                radius: 4
                                color: Colors.color_454649
                                layer.enabled: true
                                layer.effect: DropShadow {
                                    horizontalOffset: 0; verticalOffset: 0; radius: 10
                                    color: Colors.color_000000_40
                                }

                                Column {
                                    topPadding: 4; bottomPadding: 4; leftPadding: dynamicRow.hasSub ? 0 : 4; rightPadding: dynamicRow.hasSub ? 0 : 4
                                    spacing: 4
                                    Repeater {
                                        model: dynamicRow.configItems

                                        Item {
                                            property int originalIndex: {
                                                var cfg = dynamicRow.settingData.config;
                                                if (!cfg) return index;
                                                var validCount = 0;
                                                for (var i = 0; i < cfg.length; i++) {
                                                    if (cfg[i].promptKey && cfg[i].promptKey.length > 0) {
                                                        if (validCount === index) return i;
                                                        validCount++;
                                                    }
                                                }
                                                return index;
                                            }

                                            width: dynSelector.width - (dynamicRow.hasSub ? 0 : 8)
                                            height: dynamicRow.hasSub ? 55 : 28

                                            Rectangle {
                                                visible: dynItemArea.containsMouse
                                                color: dynamicRow.hasSub ? Colors.color_68696D : Colors.color_FFFFFF_15
                                                radius: 4
                                                anchors {
                                                    fill: parent
                                                    leftMargin: dynamicRow.hasSub ? 4 : 0
                                                    rightMargin: dynamicRow.hasSub ? 4 : 0
                                                    topMargin: dynamicRow.hasSub ? 4 : 0
                                                    bottomMargin: 0
                                                }
                                            }

                                            // 双行：title + subtitle
                                            UIText {
                                                visible: dynamicRow.hasSub
                                                anchors.left: parent.left
                                                anchors.leftMargin: 12
                                                anchors.top: parent.top
                                                anchors.topMargin: 11
                                                text: modelData.titleKey ? qsTr(modelData.titleKey) : ""
                                                type: UITextType.Primary
                                                size: UIControlSize.M
                                                elide: Text.ElideRight
                                            }
                                            UIText {
                                                visible: dynamicRow.hasSub && modelData.subtitleKey && modelData.subtitleKey.length > 0
                                                anchors.left: parent.left
                                                anchors.leftMargin: 12
                                                anchors.bottom: parent.bottom
                                                anchors.bottomMargin: 8
                                                text: modelData.subtitleKey ? qsTr(modelData.subtitleKey) : ""
                                                type: UITextType.Secondary
                                                size: UIControlSize.S
                                                elide: Text.ElideRight
                                            }

                                            // 单行：title only
                                            UIText {
                                                visible: !dynamicRow.hasSub
                                                anchors.left: parent.left
                                                anchors.leftMargin: 8
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: modelData.titleKey ? qsTr(modelData.titleKey) : ""
                                                type: UITextType.Primary
                                                size: UIControlSize.M
                                                elide: Text.ElideRight
                                            }

                                            Image {
                                                anchors.right: parent.right
                                                anchors.rightMargin: dynamicRow.hasSub ? 16 : 12
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 16; height: 16
                                                sourceSize: Qt.size(16, 16)
                                                visible: originalIndex === dynamicRow.selectedIndex
                                                source: "qrc:/icons/adjustment/icon_compose_check.svg"
                                            }

                                            MouseArea {
                                                id: dynItemArea
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    var arr = dynamicSelections.slice();
                                                    arr[dynamicRow.settingIndex] = originalIndex;
                                                    dynamicSelections = arr;
                                                    context.dynamicSelections = arr;
                                                    viewModel.setDynamicSelections(arr);
                                                    dynPopup.close();
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

    }
    }
    // ===== 固定底部栏：协议勾选 + 开始分析按钮（同一行） =====
    Item {
        id: bottomBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 28
        anchors.rightMargin: 28
        anchors.bottomMargin: 24
        height: 28

        // 左侧：checkbox + 授权提示文案
        Item {
            id: agreementArea
            anchors.left: parent.left
            anchors.right: startBtn.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            height: 16

            property bool _overflow: agreementTextRow.implicitWidth > (agreementArea.width - 20)

            LightToolTip {
                visible: agreementArea._overflow && agreementAreaHover.hovered
                tip: qsTr("pccut_roughcut_agreement_prefix") + qsTr("pccut_roughcut_agreement_link") + qsTr("pccut_roughcut_agreement_suffix")
            }
            HoverHandler { id: agreementAreaHover }

            // checkbox 容器：首次未授权时点击打开协议页
            Item {
                id: agreementCheckItem
                width: 16
                height: 16

                UICheckBox {
                    id: agreementCheckBox
                    anchors.fill: parent
                    size: UIControlSize.M
                    checked: lightSetting.getBool("aiAgreementAccepted", false)
                    enabled: root.hasEverAccepted
                    bgColor: Colors.color_454649
                    bgColorChecked: ColorsConfig.color_brand
                    disabledOpacity: 0.4
                    onCheckedChanged: {
                        lightSetting.save("aiAgreementAccepted", checked);
                    }
                }

                // 首次未授权时覆盖在 checkbox 上，拦截点击打开协议页
                MouseArea {
                    anchors.fill: parent
                    visible: !root.hasEverAccepted
                    cursorShape: Qt.PointingHandCursor
                    z: 1
                    onClicked: {
                        aiAgreementLoader.active = true;
                    }
                }
            }

            Row {
                id: agreementTextRow
                anchors.left: agreementCheckItem.right
                anchors.leftMargin: 4
                anchors.right: agreementArea._overflow ? ellipsisText.left : parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                clip: true

                UIText {
                    type: UITextType.Secondary
                    size: UIControlSize.M
                    text: qsTr("pccut_roughcut_agreement_prefix")
                }

                UIText {
                    type: UITextType.Secondary
                    size: UIControlSize.M
                    text: qsTr("pccut_roughcut_agreement_link")
                    color: ColorsConfig.color_3392FF_4DFFC9

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            aiAgreementLoader.active = true;
                        }
                    }
                }

                UIText {
                    type: UITextType.Secondary
                    size: UIControlSize.M
                    text: qsTr("pccut_roughcut_agreement_suffix")
                }
            }

            UIText {
                id: ellipsisText
                visible: agreementArea._overflow
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                type: UITextType.Secondary
                size: UIControlSize.M
                text: "…"
            }
        }

        // 右侧：开始分析按钮
        UIButton {
            id: startBtn
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            type: UIButtonType.Brand
            size: UIControlSize.L
            text: qsTr("pccut_roughcut_start_analysis")
            enabled: true
            onClicked: {
                if (!viewModel.hasRemainingCount()) {
                    globalSignal.toast(qsTr("pccut_roughcut_fail_limit"))
                    return
                }
                if (!agreementCheckBox.checked) {
                    // 未授权：弹协议弹窗，确认后自动开始分析
                    root._startAfterAgreement = true
                    aiAgreementLoader.active = true
                } else {
                    viewModel.startAnalysis()
                }
            }
        }

        // 调试用：剩余次数标识（DEBUG菜单开启后可见）
        Text {
            id: _debugRemainingText
            visible: lightSetting.getBool("debug_ai_roughcut_show_remaining", false)
            anchors.top: startBtn.top
            anchors.right: startBtn.right
            anchors.topMargin: -16
            font.pixelSize: 11
            color: "#FF4444"
            Component.onCompleted: _updateRemainingText()
            function _updateRemainingText() {
                text = viewModel ? ("剩余:" + viewModel.remainingCount) : ""
            }
            Connections {
                target: viewModel
                function onRemainingCountChanged() { _debugRemainingText._updateRemainingText() }
            }
        }
    }

    // AI 使用协议弹窗 Loader
    Loader {
        id: aiAgreementLoader
        active: false
        source: "../menubar/AiAgreementView.qml"
        onLoaded: {
            item.destorySource.connect(function() {
                aiAgreementLoader.active = false;
                root._startAfterAgreement = false;
            });
            item.agreementAccepted.connect(function() {
                root.hasEverAccepted = true;
                lightSetting.save("aiAgreementEverAccepted", true);
                agreementCheckBox.checked = true;
                if (root._startAfterAgreement) {
                    root._startAfterAgreement = false;
                    viewModel.startAnalysis();
                }
            });
        }
    }
}
