import QtQuick 2.15
import QtQuick.Controls
import Controls 1.0
import Config 1.0
import VideoConfig 1.0
import app_qrc 1.0

/**
 * @author: mark.zhu
 * @details 导出码率选择（内部封装 BitrateSettingPanel 和自定义滑块）
 * @date: 2026-03-02
 */
Column {
    id: root

    // 必需属性：外部传入 MediaExportSettingsProtocol 实例
    required property var viewModel

    // 可选属性：样式定制
    property int titleLeftMargin: 63
    property bool isSelecting: false

    // 可选属性：滚动容器引用（用于自动滚动到可见区域）
    property Flickable scrollContainer: null

    // 内部标记：是否需要滚动
    property bool needScroll: false

    width: parent.width
    spacing: 8

    // 码率选择框
    Rectangle {
        width: parent.width
        height: 28
        implicitHeight: 28  // 显式设置 implicitHeight，确保 Column 能正确计算总高度
        color: Colors.color_transparent

        HoverableText {
            id: titleText
            anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
            }
            horizontalAlignment: Text.AlignLeft
            verticalAlignment: Text.AlignVCenter
            font.pixelSize: 12
            color: Colors.color_CCCCCC
            text: qsTr("pccut_export_bitrate")
        }

        Rectangle {
            id: selectionBox
            anchors {
                left: parent.left
                leftMargin: root.titleLeftMargin
                top: parent.top
                bottom: parent.bottom
                right: parent.right
            }

            color: {
                if (mouseArea.containsMouse) return Colors.color_68696D
                else if (root.isSelecting) return Colors.color_454649
                else return Colors.color_454649
            }
            radius: RadiusConfig.radius_4_8

            Image {
                id: arrowIcon
                anchors {
                    right: parent.right
                    rightMargin: 8
                    verticalCenter: parent.verticalCenter
                }
                width: 20
                height: 20
                source: root.isSelecting
                    ? "qrc:/icons/adjustment/icon_drop_down_menu_collapse.svg"
                    : "qrc:/icons/adjustment/icon_drop_down_menu_expand.svg"
                sourceSize: Qt.size(20, 20)
            }

            Text {
                anchors {
                    left: parent.left
                    leftMargin: 8
                    top: parent.top
                    bottom: parent.bottom
                    right: arrowIcon.left
                }
                text: viewModel.bitrateDisplayText
                horizontalAlignment: Text.AlignLeft
                verticalAlignment: Text.AlignVCenter
                color: Colors.color_EEEEEE
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }

            MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    root.isSelecting = true
                    dropdown.show(selectionBox, prepareBitrateItems())
                }
            }
        }
    }

    // 自定义码率滑块（条件加载）
    Loader {
        id: customBitrateLoader
        active: viewModel.isCustomBitrate
        width: parent.width
        height: active ? 24 : 0

        sourceComponent: Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: root.titleLeftMargin
            anchors.right: parent.right
            height: 24
            implicitHeight: 24  // 显式设置 implicitHeight
            color: Colors.color_transparent

            // Mbps 文本（最右侧，固定宽度）
            Text {
                id: mbpsText
                anchors {
                    right: parent.right
                    top: parent.top
                    bottom: parent.bottom
                }
                width: implicitWidth
                horizontalAlignment: Text.AlignLeft
                verticalAlignment: Text.AlignVCenter
                color: Colors.color_EEEEEE
                font.pixelSize: 12
                font.weight: Font.DemiBold
                text: "Mbps"
            }

            // 输入框（固定宽度 56px）
            Rectangle {
                id: inputBox
                anchors {
                    right: mbpsText.left
                    rightMargin: 8
                    top: parent.top
                    bottom: parent.bottom
                }
                width: 56
                height: 24
                color: Colors.color_666666_50
                radius: 4

                TextInput {
                    id: bitrateInput
                    anchors.fill: parent
                    clip: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    selectByMouse: true
                    color: Colors.color_EEEEEE
                    text: viewModel.customBitrateValue.toString()

                    inputMethodHints: Qt.ImhDigitsOnly
                    selectedTextColor: Colors.color_2E2E2E
                    selectionColor: Colors.color_EEEEEE

                    // 监听 viewModel 变化，更新输入框（仅在非编辑状态）
                    Connections {
                        target: viewModel
                        function onCustomBitrateValueChanged() {
                            if (!bitrateInput.activeFocus) {
                                bitrateInput.text = viewModel.customBitrateValue.toString()
                            }
                        }
                    }

                    onEditingFinished: {
                        updateValue()
                        bitrateInput.focus = false
                    }

                    onActiveFocusChanged: {
                        if (!bitrateInput.activeFocus) {
                            updateValue()
                        }
                    }

                    // 更新数值到 ViewModel（Protocol 内部会自动验证范围）
                    function updateValue() {
                        if (text !== "") {
                            var newValue = parseInt(text)
                            viewModel.customBitrateValue = newValue
                        }
                        // 更新显示为 ViewModel 的实际值（可能经过范围验证）
                        bitrateInput.text = viewModel.customBitrateValue.toString()
                    }
                }
            }

            // 滑块（弹性宽度，填充剩余空间）
            LightBaseSlider {
                id: bitrateSlider
                anchors {
                    left: parent.left
                    right: inputBox.left
                    rightMargin: 8
                    verticalCenter: parent.verticalCenter
                }
                leftPadding: 0
                rightPadding: 0
                from: viewModel.customBitrateMin
                to: viewModel.customBitrateMax
                value: viewModel.customBitrateValue
                stepSize: 1
                snapMode: Slider.SnapAlways

                onMoved: {
                    if (pressed) {
                        viewModel.customBitrateValue = value
                    }
                }

                onPressedChanged: {
                    viewModel.customBitrateValue = value
                }
            }
        }
    }

    // ✅ 使用通用下拉组件（替代 BitrateSettingPanel）
    ExportDropdown {
        id: dropdown
        maxVisibleItems: 999         // 大值，禁用滚动（4个选项全部显示）
        scrollBarPolicy: "never"     // 不显示滚动条（BitrateSettingPanel 行为）
        autoPositionToSelected: false // 不需要自动定位

        onItemSelected: function(index, itemData) {
            root.isSelecting = false
            viewModel.bitrateType = itemData.value

            if (root.viewModel.enableEventTracking) {
                eventTracker.trackEvent("pccut_home_export_bitrate",
                    {"export_bitrate": itemData.title});
            }
        }

        onCloseSignal: {
            root.isSelecting = false
        }

        Component.onCompleted: {
            if (root.viewModel.enableEventTracking) {
                eventTracker.trackEvent("pccut_home_export_bitrate",
                    {"export_bitrate": viewModel.bitrateDisplayText});
            }
        }
    }

    // ==================== 自动滚动逻辑 ====================

    /**
     * @brief 监听自定义码率展开，设置滚动标记
     */
    Connections {
        target: viewModel
        function onIsCustomBitrateChanged() {
            if (viewModel.isCustomBitrate && scrollContainer) {
                root.needScroll = true;
            }
        }
    }

    /**
     * @brief 监听滚动容器内容高度变化，触发滚动（布局完成后）
     */
    Connections {
        target: scrollContainer
        enabled: scrollContainer !== null
        function onContentHeightChanged() {
            if (root.needScroll) {
                Qt.callLater(function() {
                    ensureVisible();
                    root.needScroll = false;
                });
            }
        }
    }

    /**
     * @brief 确保组件完整显示在 ScrollView 可视区域内
     */
    function ensureVisible() {
        if (!scrollContainer) return;

        // 计算组件在 scrollContent 中的绝对位置
        var itemY = root.mapToItem(scrollContainer.contentItem, 0, 0).y;
        var itemBottom = itemY + root.height;

        // 获取 ScrollView 可视区域（需要获取 ScrollView，而不是 Flickable）
        var scrollView = scrollContainer.parent;
        if (!scrollView) return;

        var viewTop = scrollContainer.contentY;
        var viewBottom = viewTop + scrollView.height;

        // 计算最大可滚动位置
        var maxScrollY = Math.max(0, scrollContainer.contentHeight - scrollView.height);

        // 如果底部超出可视区域，滚动到底部对齐
        if (itemBottom > viewBottom) {
            var targetY = itemBottom - scrollView.height + 16; // 16px 底部留白
            scrollContainer.contentY = Math.min(targetY, maxScrollY);
        }
        // 如果顶部超出可视区域，滚动到顶部对齐
        else if (itemY < viewTop) {
            scrollContainer.contentY = Math.max(itemY - 16, 0); // 16px 顶部留白，最小为0
        }
    }

    // ==================== 数据准备函数 ====================

    /**
     * @brief 准备码率选项数据（对应 BitrateSettingPanel 的内部逻辑）
     * @return 选项数组
     */
    function prepareBitrateItems() {
        let types = [
            VideoConfig.BITRATETYPE_LOW,
            VideoConfig.BITRATETYPE_RECOMMEND,
            VideoConfig.BITRATETYPE_HIGH,
            VideoConfig.BITRATETYPE_CUSTOM
        ];

        var items = [];
        for (var i = 0; i < types.length; i++) {
            let type = types[i];
            let title = videoConfig.getItemByBitrateType(type);
            let checked = type === viewModel.bitrateType;
            items.push({
                title: title,
                value: type,
                checked: checked,
                enabled: true
            });
        }
        return items;
    }
}
