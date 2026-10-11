import QtQuick 2.15
import QtQuick.Controls
import Controls 1.0
import Config 1.0
import VideoConfig 1.0
import app_qrc 1.0

/**
 * @author: mark.zhu
 * @details 导出分辨率选择（内部封装 ResolutionSettingPanel）
 * @date: 2026-03-02
 */
Rectangle {
    id: root

    // 必需属性：外部传入 MediaExportSettingsProtocol 实例
    required property var viewModel

    // 可选属性：样式定制
    property int titleLeftMargin: 63
    property bool isSelecting: false

    width: parent.width
    height: 28
    implicitHeight: 28  // 显式设置 implicitHeight，确保 Column 布局正确
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
        text: qsTr("pccut_media_info_resolution")
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
            id: displayText
            anchors {
                left: parent.left
                leftMargin: 8
                top: parent.top
                bottom: parent.bottom
                right: arrowIcon.left
            }
            text: viewModel.resolutionDisplayText
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
                dropdown.show(selectionBox, prepareResolutionItems())
            }
        }
    }

    // ✅ 使用通用下拉组件（替代 ResolutionSettingPanel）
    ExportDropdown {
        id: dropdown
        maxVisibleItems: 999         // 大值，禁用滚动（最多4个选项全部显示）
        scrollBarPolicy: "never"     // 不显示滚动条（ResolutionSettingPanel 行为）
        autoPositionToSelected: false // 不需要自动定位

        onItemSelected: function(index, itemData) {
            root.isSelecting = false
            viewModel.resolutionType = itemData.value

            if (root.viewModel.enableEventTracking) {
                eventTracker.trackEvent("pccut_home_export_resolution",
                    {"export_resolution": itemData.title});
            }
        }

        onCloseSignal: {
            root.isSelecting = false
        }

        Component.onCompleted: {
            if (root.viewModel.enableEventTracking) {
                eventTracker.trackEvent("pccut_home_export_resolution",
                    {"export_resolution": viewModel.resolutionDisplayText});
            }
        }
    }

    // ==================== 数据准备函数 ====================

    /**
     * @brief 准备分辨率选项数据（对应 ResolutionSettingPanel 的内部逻辑）
     * @return 选项数组
     */
    function prepareResolutionItems() {
        // 根据是否全景模式选择不同的分辨率列表
        var types = videoConfig.getExportResolutionTypes(viewModel.isPanoramaMode);

        var items = [];
        for (var i = 0; i < types.length; i++) {
            let type = types[i];
            let title = videoConfig.getQmlItemByResolutionType(type).name;
            let resolutionValue = videoConfig.getQmlItemByResolutionType(type).width + "x" + videoConfig.getQmlItemByResolutionType(type).height;
            let checked = type === viewModel.resolutionType;
            items.push({
                title: title,
                value: type,
                extraValue: resolutionValue,  // 额外保存分辨率字符串（如 "3840x2160"）
                checked: checked,
                enabled: true
            });
        }
        return items;
    }
}
