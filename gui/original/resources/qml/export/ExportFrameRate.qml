import QtQuick 2.15
import QtQuick.Controls
import Controls 1.0
import Config 1.0
import VideoConfig 1.0
import app_qrc 1.0

/**
 * @author: mark.zhu
 * @details 导出帧率选择（内部封装 FrameRateSettingPanel）
 * @date: 2026-03-02
 */
Column {
    id: root

    // 必需属性：外部传入 MediaExportSettingsProtocol 实例
    required property var viewModel

    // 可选属性：样式定制
    property int titleLeftMargin: 63
    property bool isSelecting: false

    width: parent.width
    spacing: 8

    // 帧率选择框
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
            text: qsTr("pccut_media_info_rate")
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
                text: viewModel.frameRateDisplayText
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
                    dropdown.show(selectionBox, prepareFrameRateItems())
                }
            }
        }
    }

    // 帧率提示
    HoverableText {
        id: frameRateTip
        anchors {
            left: parent.left
            leftMargin: root.titleLeftMargin
            right: parent.right
        }
        height: visible ? implicitHeight : 0  // 动态高度，隐藏时高度为 0
        font.pixelSize: 11
        visible: viewModel.showFrameRateTip
        text: viewModel.frameRateTipText
        cursorChanged: false
        color: Colors.color_666666
        lineHeight: 16
        toastVisible: implicitWidth / 2 > width
    }

    // ✅ 使用通用下拉组件（替代 FrameRateSettingPanel）
    ExportDropdown {
        id: dropdown
        maxVisibleItems: 5           // 最大显示5项（约 164px，FrameRateSettingPanel 行为）
        scrollBarPolicy: "always"    // 始终显示滚动条（FrameRateSettingPanel 行为）
        autoPositionToSelected: true // 自动滚动到选中项（FrameRateSettingPanel 行为）

        onItemSelected: function(index, itemData) {
            root.isSelecting = false
            viewModel.frameRateType = itemData.value

            if (root.viewModel.enableEventTracking) {
                eventTracker.trackEvent("pccut_home_export_frame_rate",
                    {"export_frame_rate": itemData.title});
            }
        }

        onCloseSignal: {
            root.isSelecting = false
        }

        Component.onCompleted: {
            if (root.viewModel.enableEventTracking) {
                eventTracker.trackEvent("pccut_home_export_frame_rate",
                    {"export_frame_rate": viewModel.frameRateDisplayText});
            }
        }
    }

    // ==================== 数据准备函数 ====================

    /**
     * @brief 准备帧率选项数据（对应 FrameRateSettingPanel 的内部逻辑）
     * @return 选项数组
     *
     * ⚠️ 保留原有的复杂逻辑：
     * 1. 向下匹配：找到最接近且不大于 selectedType 的帧率作为选中项
     * 2. 特殊过滤：type <= maxFrameRate || type <= 60fps（低帧率选项总是显示）
     */
    function prepareFrameRateItems() {
        let types = [
            VideoConfig.FRAMERATETYPE_24,
            VideoConfig.FRAMERATETYPE_25,
            VideoConfig.FRAMERATETYPE_30,
            VideoConfig.FRAMERATETYPE_48,
            VideoConfig.FRAMERATETYPE_50,
            VideoConfig.FRAMERATETYPE_60,
            VideoConfig.FRAMERATETYPE_100,
            VideoConfig.FRAMERATETYPE_120,
            VideoConfig.FRAMERATETYPE_200,
            VideoConfig.FRAMERATETYPE_240
        ];

        // 🔴 复杂的选中匹配逻辑：获取最接近 selectedType 且不大于 selectedType 的 type
        // 这么做的原因是 types 定义的类型不等于 VideoConfig 中所有的枚举，types 只是展示出来的类型
        // 因此如果视频选择的类型是不被展示的，则向下进行匹配
        let closestTypeBelowSelected = types[0];
        for (var j = 0; j < types.length; ++j) {
            if (types[j] <= viewModel.frameRateType && types[j] <= viewModel.maxFrameRate) {
                closestTypeBelowSelected = types[j];
            }
        }

        var items = [];
        for (var i = 0; i < types.length; i++) {
            let type = types[i];
            let title = videoConfig.getQmlItemByFrameRateType(type).name;

            // 🔴 特殊过滤逻辑：低于等于 60fps 的选项总是显示，高于 60fps 的选项需要满足 maxFrameRate
            if (type <= viewModel.maxFrameRate || type <= VideoConfig.FRAMERATETYPE_60) {
                let checked = type === closestTypeBelowSelected;
                items.push({
                    title: title,
                    value: type,
                    checked: checked,
                    enabled: true
                });
            }
        }
        return items;
    }
}
