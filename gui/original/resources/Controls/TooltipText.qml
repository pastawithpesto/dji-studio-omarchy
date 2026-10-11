import QtQuick 2.15
import QtQuick.Controls
import Config 1.0

/**
 * Description: 带 Tooltip 提示的文本控件
 * Use case: 当文本超出宽度被截断时，hover 显示完整文本
 * Usage: 和 Text 控件使用完全一致，当 elide 截断时自动显示 tooltip
 *
 * 技术说明：
 * - 支持外部传入 externalHovered 状态（适用于父节点有 MouseArea 的场景）
 * - 内置 HoverHandler 作为兜底（独立使用时自动生效）
 * - 使用 || 逻辑，外部状态或内部检测任一生效即可
 * - 支持自定义 Tooltip 位置（tooltipX/tooltipY）
 */
Text {
    id: tooltipText

    // ========== Tooltip 配置 ==========
    property string tooltipText: text  // 提示文本（默认使用 text 属性）
    property bool tooltipEnabled: true  // 是否启用 tooltip（默认启用）

    // ========== Tooltip 位置配置 ==========
    // 可选：设置后覆盖 LightToolTip 的默认定位
    property real tooltipX: Number.NaN  // Tooltip X 坐标（默认 NaN，由 LightToolTip 自动定位）
    property real tooltipY: Number.NaN  // Tooltip Y 坐标（默认 NaN，由 LightToolTip 自动定位）

    // ========== Hover 状态 ==========
    property bool externalHovered: false  // 外部传入的 hover 状态（可选）

    // 内部计算的最终 hover 状态：外部状态 或 内部检测
    readonly property bool _effectiveHovered: externalHovered || hoverHandler.hovered

    // ========== Tooltip 组件 ==========
    Loader {
        active: true
        asynchronous: true
        sourceComponent: LightToolTip {
            id: tooltip
            tip: tooltipText.tooltipText
            z: 200
            visible: tooltipEnabled && tooltipText._effectiveHovered && tooltipText.implicitWidth > tooltipText.width

            // 只有在用户显式设置时才绑定坐标
            Binding on x {
                when: !isNaN(tooltipText.tooltipX)
                value: tooltipText.tooltipX
            }

            Binding on y {
                when: !isNaN(tooltipText.tooltipY)
                value: tooltipText.tooltipY
            }
        }
    }

    // ========== HoverHandler 用于检测 hover ==========
    // 作为兜底，当没有外部状态或父节点 MouseArea 未拦截时生效
    HoverHandler {
        id: hoverHandler
        cursorShape: Qt.ArrowCursor
    }
}
