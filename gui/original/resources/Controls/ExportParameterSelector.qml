import QtQuick 2.15
import QtQuick.Controls
import Config 1.0
import app_qrc 1.0

/**
 * @brief 导出参数选择器组件
 * @details 通用的参数选择下拉框，用于分辨率、帧率、码率等选择
 *          复用于 MacComposePanel 和 DeviceExportSettingPopup
 * @author your-name
 * @date 2026-02-25
 */
Rectangle {
    id: root

    // ==================== 公共属性 ====================

    /**
     * @brief 标签文本（左侧显示）
     */
    property string labelText: ""

    /**
     * @brief 当前显示的按钮文本（右侧下拉框内容）
     */
    property string buttonText: ""

    /**
     * @brief 当前选中的类型值
     */
    property real selectedType: -1

    /**
     * @brief 是否正在选择（下拉框展开状态）
     */
    property bool isSelecting: false

    /**
     * @brief 设置面板对象引用（如 resolutionSettingPanel）
     */
    property var settingPanel: null

    /**
     * @brief 设置面板显示的额外参数（传递给 show() 方法）
     * @note 可以是单个值或函数（运行时求值）
     */
    property var showParams: null

    /**
     * @brief 左侧标签宽度（用于对齐）
     */
    property real labelWidth: 63

    // ==================== 信号 ====================

    /**
     * @brief 点击下拉框时触发（在显示面板之前）
     * @details 用于埋点等逻辑
     */
    signal beforeShow()

    /**
     * @brief 选择项变更信号
     * @param type 新选择的类型值
     * @param title 选择项的标题文本
     * @param value 选择项的值（仅 ResolutionSettingPanel 有此参数）
     */
    signal selectionChanged(real type, string title, var value)

    // ==================== UI 配置 ====================

    width: parent.width
    height: 28
    color: Colors.color_transparent

    // 左侧标签
    Text {
        id: label
        anchors {
            left: parent.left
            verticalCenter: parent.verticalCenter
        }
        text: labelText
        font.pixelSize: 12
        color: Colors.color_CCCCCC
    }

    // 右侧下拉选择框
    Rectangle {
        id: dropdownBox
        anchors {
            left: parent.left
            leftMargin: labelWidth
            top: parent.top
            bottom: parent.bottom
            right: parent.right
        }
        color: mouseArea.containsMouse ? Colors.color_68696D : Colors.color_454649
        radius: RadiusConfig.radius_4_8

        // 显示文本
        Text {
            id: buttonTextLabel
            anchors {
                left: parent.left
                leftMargin: 8
                verticalCenter: parent.verticalCenter
                right: arrowIcon.left
                rightMargin: 4
            }
            color: Colors.color_FFFFFF
            font.pixelSize: 12
            font.weight: Font.DemiBold
            text: buttonText
            elide: Text.ElideRight
        }

        // 下拉箭头图标
        Image {
            id: arrowIcon
            anchors {
                right: parent.right
                rightMargin: 8
                verticalCenter: parent.verticalCenter
            }
            width: 20
            height: 20
            source: isSelecting
                ? "qrc:/icons/adjustment/icon_drop_down_menu_collapse.svg"
                : "qrc:/icons/adjustment/icon_drop_down_menu_expand.svg"
            sourceSize: Qt.size(20, 20)
        }

        // 点击区域
        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            //cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (settingPanel === null) {
                    console.warn("[ExportParameterSelector] settingPanel is null!");
                    return;
                }

                isSelecting = true;

                // 触发埋点等前置逻辑
                beforeShow();

                // 调用设置面板的 show 方法
                // 支持动态求值（如果 showParams 是函数）
                var params = (typeof showParams === "function") ? showParams() : showParams;

                if (params !== null && params !== undefined) {
                    settingPanel.show(dropdownBox, selectedType, params);
                } else {
                    settingPanel.show(dropdownBox, selectedType);
                }
            }
        }
    }

    // ==================== 连接设置面板信号 ====================

    Connections {
        target: settingPanel

        // 监听选择项变更
        function onSelectedItemSignal(title, value, type) {
            // ResolutionSettingPanel 有 value 参数 (title, value, type)
            // FrameRateSettingPanel 和 BitrateSettingPanel 只有 (title, type)
            isSelecting = false;

            if (arguments.length >= 3) {
                // 有 value 参数（分辨率）
                selectionChanged(type, title, value);
            } else {
                // 没有 value 参数（帧率、码率）
                selectionChanged(arguments[1], arguments[0], undefined);
            }
        }

        // 监听关闭信号
        function onCloseSignal() {
            isSelecting = false;
        }
    }

    // ==================== 公共方法 ====================

    /**
     * @brief 设置当前选择（外部调用）
     */
    function setSelection(type, text) {
        selectedType = type;
        buttonText = text;
    }
}
