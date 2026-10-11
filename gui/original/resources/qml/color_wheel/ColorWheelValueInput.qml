import QtQuick 2.15
import QtQuick.Controls
import Config 1.0
import Controls 1.0

// ════════════════════════════════════════
// RGB 数值输入框组件
// 编辑逻辑（状态机/表达式解析/TextInput/失焦遮罩）继承自 ColorWheelValueEditorBase，
// 本文件仅负责显示态文本与底线。
// hover / 按下 / 拖拽 / 松手 warp / 光标对账全部由行级大 MouseArea（ColorWheel.qml
// rgbMouseArea）统一承载——照搬色轮弧针 arcMouseArea 的结构：小框只作“几何命中目标”，
// 不自行处理事件，从而避免 warp 冻结吞掉小框唯一一次 HoverLeave 导致光标卡死。
// ════════════════════════════════════════
ColorWheelValueEditorBase {
    id: inputRoot
    width: 36
    height: 20
    property bool bottomLineRequired: true
    // 拖拽状态由行级大 MouseArea 写入（用于 isRgbDragging / FilterAdjust 起止同步）。
    property bool isDragging: false

    // ── ValueInput 专属属性 ──
    property real stepSize: 0.01
    step: stepSize                  // 桥接到基类 step，供 ↑/↓ 步进使用
    property color textColor: Colors.color_EEEEEE
    property color channelColor: Colors.color_FFFFFF
    property real fontSize: 10

    readonly property bool hasActiveEditor: editing

    // ── 把基类 editInput 参数化为 ValueInput 样式 ──
    editInputContainer: inputBg
    editTextColor: Colors.color_EEEEEE
    editFontSize: inputRoot.fontSize
    editHorizontalAlignment: TextInput.AlignHCenter
    editLeftMargin: 3
    editRightMargin: 3

    // 关闭正在进行的编辑（供外部 ColorWheel.dismissAllEditing 调用）
    function applyInput() {
        commitEditing();
    }

    function dismissAllEditing() {
        if (editing) commitEditing();
    }

    // ── 显示态 ──
    // anchors.fill 让 Column 覆盖组件区域；底部色条 2px 自然溢出到 18px 高度之外形成下划线。
    // （原先同时设 anchors.centerIn 与 anchors.fill 会冲突并产生 QML 警告，centerIn 在 fill 下被忽略，故移除。）
    Column {
        spacing: 2
        anchors.fill: parent

        Rectangle {
            id: inputBg
            color: Colors.color_141414
            width: inputRoot.width
            height: inputRoot.height
            radius: 4

            Text {
                id: valueText
                visible: !inputRoot.editing
                text: inputRoot.displayText(inputRoot.value)
                color: inputRoot.textColor
                font.pixelSize: inputRoot.fontSize
                anchors.centerIn: parent
                // macOS/Windows 字体 ascent 度量不同导致视觉垂直中心偏移，用平台判断直接修正
                anchors.verticalCenterOffset: Qt.platform.os === "windows" ? 1 : 0
            }
        }

        Rectangle {
            visible: inputRoot.bottomLineRequired
            width: inputRoot.width - 4
            height: 2
            radius: 1
            color: inputRoot.channelColor
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }
}
