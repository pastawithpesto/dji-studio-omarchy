import QtQuick 2.15
import Controls 1.0
import Config 1.0
import QtQuick.Controls
import QtQuick.Window 2.15
import app_qrc 1.0

/**
 * @author: mark.zhu
 * @details 通用导出下拉面板组件（兼容 BitrateSettingPanel、FrameRateSettingPanel、ResolutionSettingPanel）
 * @date: 2026-03-04
 *
 * 使用示例：
 *
 * // 基本使用（默认样式）
 * ExportDropdown {
 *     id: dropdown
 *
 *     onItemSelected: function(index, itemData) {
 *         console.log("Selected:", itemData.title, itemData.value)
 *     }
 * }
 *
 * dropdown.show(triggerWidget, [
 *     { title: "选项1", checked: true, enabled: true, value: 1 },
 *     { title: "选项2", checked: false, enabled: true, value: 2 },
 *     { title: "选项3", checked: false, enabled: false, value: 3, tip: "qrc:/icons/tip.svg" }
 * ])
 *
 * // FrameRateSettingPanel 样式（最大显示5项，始终显示滚动条，自动定位）
 * ExportDropdown {
 *     id: frameRateDropdown
 *     maxVisibleItems: 5           // 最大高度约 164px
 *     scrollBarPolicy: "always"    // 始终显示滚动条
 *     autoPositionToSelected: true // 自动滚动到选中项
 * }
 *
 * // BitrateSettingPanel 样式（不滚动，不显示滚动条）
 * ExportDropdown {
 *     id: bitrateDropdown
 *     maxVisibleItems: 999         // 大值，禁用滚动
 *     scrollBarPolicy: "never"     // 不显示滚动条
 * }
 */
LightPopup {
    id: root

    // ==================== 信号 ====================

    /**
     * @brief 点击空白区域关闭
     */
    signal closeSignal

    /**
     * @brief 选中某个选项
     * @param index 选项索引
     * @param itemData 选项数据对象 { title, checked, enabled, value, ... }
     */
    signal itemSelected(int index, var itemData)

    // ==================== 公共配置属性 ====================

    /**
     * @brief 最大可见项数（超过则滚动）
     * - 设置为 10: 默认行为（ExportTypeSelector）
     * - 设置为 5: FrameRateSettingPanel 行为（最大高度 164px）
     * - 设置为大值: BitrateSettingPanel/ResolutionSettingPanel 行为（不滚动）
     */
    property int maxVisibleItems: 5

    /**
     * @brief 滚动条显示策略
     * - "auto": 仅在超过 maxVisibleItems 时显示（默认）
     * - "always": 始终显示（FrameRateSettingPanel 行为）
     * - "never": 永不显示（BitrateSettingPanel/ResolutionSettingPanel 行为）
     */
    property string scrollBarPolicy: "auto"

    /**
     * @brief 是否自动定位到选中项（显示时）
     * - true: 自动滚动到选中项（FrameRateSettingPanel 行为，默认）
     * - false: 不自动定位
     */
    property bool autoPositionToSelected: true

    // ==================== 内部属性 ====================

    property real rectangleWidth: 0
    property real rectangleHeight: 0

    width: parent.width
    height: parent.height
    z: 100000
    modal: false
    Overlay.modal: Rectangle {
        color: Colors.transparent
    }
    parent: Overlay.overlay
    needTransparent: true

    // ==================== UI ====================

    contentItem: Item {
        // 点击空白关闭
        MouseArea {
            anchors.fill: parent
            onClicked: {
                closeSignal();
                close();
            }
        }

        // 下拉面板容器
        Rectangle {
            id: rectangle

            width: rectangleWidth
            height: rectangleHeight
            radius: RadiusConfig.radius_4_8
            clip: true
            color: Colors.color_454649

            ListModel {
                id: itemModels
                property int itemHeight: 28
                property int itemSpacing: 4
            }

            ListView {
                id: listView
                anchors.fill: parent
                anchors.margins: 4
                spacing: itemModels.itemSpacing
                boundsBehavior: Flickable.StopAtBounds
                model: itemModels
                interactive: itemModels.count > root.maxVisibleItems  // 超过最大可见项数才允许滚动

                ScrollBar.vertical: ScrollBar {
                    policy: {
                        if (root.scrollBarPolicy === "always") return ScrollBar.AlwaysOn
                        if (root.scrollBarPolicy === "never") return ScrollBar.AlwaysOff
                        // "auto" 策略：超过最大可见项数时显示
                        return itemModels.count > root.maxVisibleItems ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                    }
                    bottomPadding: padding
                    rightPadding: 0
                    Component.onCompleted: {
                        contentItem.color = Colors.color_56575B
                    }
                }

                delegate: Rectangle {
                    height: itemModels.itemHeight
                    width: rectangleWidth - 8
                    radius: RadiusConfig.radius_4_8
                    color: (model.checked || rowHoverHandler.hovered) ? ColorsConfig.color_68696D_4DFFC920 : Colors.color_454649
                    opacity: model.enabled ? 1 : 0.4

                    // HoverHandler 挂载在 Rectangle 上，不被子 MouseArea 抢占 hover 状态
                    HoverHandler {
                        id: rowHoverHandler
                    }

                    // 勾选图标
                    Image {
                        id: icon
                        anchors {
                            left: parent.left
                            leftMargin: 8
                            verticalCenter: parent.verticalCenter
                        }
                        width: 16
                        height: 16
                        source: model.checked ? "qrc:/app_qrc/icons/icon_compose_check.svg" : ""
                        sourceSize: Qt.size(16, 16)
                    }

                    // 文本
                    Text {
                        id: titleText
                        anchors {
                            left: icon.right
                            leftMargin: 5
                            top: parent.top
                            bottom: parent.bottom
                            right: questionIcon.visible ? questionIcon.left : (tipIcon.visible ? tipIcon.left : parent.right)
                            rightMargin: (questionIcon.visible || tipIcon.visible) ? 4 : 0
                        }
                        color: {
                            if (!model.enabled) return Colors.color_444444
                            return (model.checked || rowHoverHandler.hovered) ? ColorsConfig.color_EEEEEE_4DFFC9 : Colors.color_EEEEEE
                        }
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                        font.pixelSize: 11
                        text: model.title
                    }

                    // 提示图标（可选，用于显示禁用原因等）
                    Image {
                        id: tipIcon
                        anchors {
                            right: parent.right
                            rightMargin: 8
                            verticalCenter: parent.verticalCenter
                        }
                        width: model.tipWidth || 68
                        height: model.tipHeight || 16
                        visible: model.tip && rowHoverHandler.hovered && !model.enabled
                        source: model.tip || ""
                        sourceSize: Qt.size(width, height)
                    }

                    // 交互
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (!model.enabled) {
                                return
                            }

                            // 更新选中状态
                            for (var i = 0; i < itemModels.count; i++) {
                                let item = itemModels.get(i);
                                item.checked = (i === index);
                            }

                            // 发送信号
                            let itemData = {
                                title: model.title,
                                checked: true,
                                enabled: model.enabled,
                                value: model.value,
                                tip: model.tip
                            };
                            itemSelected(index, itemData);
                            close();
                        }
                    }

                    // 问号图标（如 达芬奇格式 专用提示，通过 question 字段控制）
                    // 声明在 click MouseArea 之后，z 轴更高，可正常接收 hover 事件
                    Rectangle {
                        id: questionIcon
                        visible: model.question !== ""
                        x: Math.min(titleText.x + titleText.implicitWidth + 4, (tipIcon.visible ? tipIcon.x : parent.width) - width - 4)
                        anchors.verticalCenter: parent.verticalCenter
                        width: 14
                        height: 14
                        color: Colors.color_transparent

                        Image {
                            anchors.fill: parent
                            source: questionMouseArea.containsMouse
                                ? "qrc:/icons/ic_explain.svg"
                                : "qrc:/icons/ic_explain_hover.svg"
                            sourceSize: Qt.size(100, 100)
                        }
                        MouseArea {
                            id: questionMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.NoButton
                        }
                        LightToolTip {
                            z: 9999
                            x: - (width / 2)
                            width: 410 // DaVinci tooltip needs fixed width for word wrap
                            visible: questionMouseArea.containsMouse
                            tip: model.question || ""
                            textWrapMode: Text.WordWrap
                        }
                    }
                }
            }
        }
    }

    // ==================== 公共方法 ====================

    /**
     * @brief 显示下拉面板
     * @param widget 触发控件（用于定位）
     * @param items 选项数组，每个选项包含：
     *   - title: string (必需) 显示文本
     *   - checked: bool (可选，默认 false) 是否选中
     *   - enabled: bool (可选，默认 true) 是否启用
     *   - value: any (可选) 自定义值
     *   - tip: string (可选) 禁用时的提示图标路径
     *   - tipWidth: int (可选) 提示图标宽度
     *   - tipHeight: int (可选) 提示图标高度
     *
     * 示例：
     * dropdown.show(button, [
     *     { title: "平面视频", checked: true, enabled: true, value: "video" },
     *     { title: "全景视频", checked: false, enabled: false, value: "pano", tip: "qrc:/icons/tip.svg" }
     * ])
     */
    function show(widget, items) {
        if (!items || items.length === 0) {
            console.warn("[ExportDropdown] No items provided");
            return;
        }

        // 清空并填充数据
        itemModels.clear();
        var selectedIndex = -1;
        for (var i = 0; i < items.length; i++) {
            let item = items[i];
            let isChecked = item.checked || false;
            if (isChecked) {
                selectedIndex = i;
            }
            itemModels.append({
                title: item.title || "",
                checked: isChecked,
                enabled: item.enabled !== undefined ? item.enabled : true,
                value: item.value !== undefined ? item.value : i,
                tip: item.tip || "",
                tipWidth: item.tipWidth || 68,
                tipHeight: item.tipHeight || 16,
                question: item.question || ""
            });
        }

        // 计算面板尺寸（使用配置的 maxVisibleItems）
        rectangleWidth = widget.width;
        let visibleItems = Math.min(itemModels.count, root.maxVisibleItems);
        // 正确公式：n 个项只有 (n-1) 个间隙，避免底部多余空白
        rectangleHeight = visibleItems * itemModels.itemHeight + (visibleItems - 1) * itemModels.itemSpacing + 8;

        // 定位面板（在触发控件下方）
        var pos = widget.mapToItem(Overlay.overlay, 0, widget.height);
        rectangle.x = pos.x;
        rectangle.y = pos.y + 4;

        // 显示
        open();

        // 自动定位到选中项（如果启用）
        if (root.autoPositionToSelected && selectedIndex >= 0) {
            positionViewAtIndex(selectedIndex);
        }
    }

    /**
     * @brief 更新选中项
     * @param index 要选中的选项索引
     */
    function setSelectedIndex(index) {
        if (index < 0 || index >= itemModels.count) {
            logger.w("[ExportDropdown] Invalid index:" + index);
            return;
        }

        for (var i = 0; i < itemModels.count; i++) {
            let item = itemModels.get(i);
            item.checked = (i === index);
        }
    }

    /**
     * @brief 根据 value 更新选中项
     * @param value 要选中的选项的 value 值
     */
    function setSelectedValue(value) {
        for (var i = 0; i < itemModels.count; i++) {
            let item = itemModels.get(i);
            if (item.value === value) {
                setSelectedIndex(i);
                return;
            }
        }
        console.warn("[ExportDropdown] Value not found:", value);
    }

    /**
     * @brief 滚动视图到指定索引位置
     * @param index 要定位的选项索引
     * @param mode 定位模式（默认 ListView.Contain）
     *   - ListView.Beginning: 将项定位到视图开头
     *   - ListView.Center: 将项定位到视图中心
     *   - ListView.End: 将项定位到视图末尾
     *   - ListView.Visible: 确保项可见
     *   - ListView.Contain: 确保项完全可见（默认）
     *
     * 用于 FrameRateSettingPanel 的自动定位功能
     */
    function positionViewAtIndex(index, mode) {
        if (index < 0 || index >= itemModels.count) {
            logger.w("[ExportDropdown] Invalid index for positioning:" + index);
            return;
        }

        // 默认使用 Contain 模式（确保项完全可见）
        var positionMode = mode !== undefined ? mode : ListView.Contain;
        listView.positionViewAtIndex(index, positionMode);
    }
}
