import QtQuick 2.15
import QtQuick.Controls
import Config 1.0
import Controls 1.0

// ════════════════════════════════════════
// 弧形滑轨滑针 + 可编辑 Tooltip 组件
// 编辑逻辑（状态机/表达式解析/TextInput/失焦遮罩）继承自 ColorWheelValueEditorBase，
// 本文件仅保留 Tooltip 弹出层与显示态布局。
// ════════════════════════════════════════
ColorWheelValueEditorBase {
    id: handleRoot
    width: 14
    height: 14

    // ── Tooltip 专属属性 ──
    property string label: ""          // 提示标题（如"饱和度"）

    // ── Tooltip 是否显示 ──
    // 由外部 hovered（arcMouseArea 检测滑针）触发；一旦鼠标进入桥接条或 tooltip 自身，
    // 由 Popup 内 MouseArea 粘住可见——这两个区域在顶层 Popup 内，不会被下层 RGB 输入框抢占。
    property bool hovered: false
    property bool arrowOnTop: false    // true: 箭头在上方（tooltip在滑针下方）
    property bool tipVisible: hovered || editing || tipHover.containsMouse || bridgeHover.containsMouse

    // 桥接条高度：连接滑针与 tooltip。tooltip 落到 RGB 输入框上方时，桥接条随之落在顶层 Popup 内，
    // 鼠标经桥接条走向 tooltip 的整个过程都在顶层，避免被 RGB 输入框截断 hover。
    readonly property real bridgeHeight: 11

    // 暴露 tooltip 矩形的实际尺寸和相对位置（供外部桥接区计算）
    // 宽度基于label和value文本预估，不依赖Popup内部布局
    readonly property real _estimatedTextWidth: _labelMetrics.advanceWidth + _valueMetrics.advanceWidth + (label !== "" ? 4 : 0)
    readonly property real tooltipRealWidth: _estimatedTextWidth + 16
    readonly property real tooltipRealHeight: 24
    readonly property real tooltipLocalX: (handleRoot.width - tooltipRealWidth) / 2
    readonly property real tooltipLocalY: arrowOnTop ? 5 : -tooltipRealHeight - 5

    TextMetrics { id: _labelMetrics; font.pixelSize: 11; text: label !== "" ? label + ":" : "" }
    TextMetrics { id: _valueMetrics; font.pixelSize: 11; text: displayText(value) }

    // 把基类的 editInput 重定向到 Popup 内的 tooltipContent 容器（脱离父级裁剪）
    editInputContainer: tooltipContent

    // 暴露 tooltip / 桥接条 区域的鼠标 hover 状态（供外部管理光标）
    readonly property alias tooltipContainsMouse: tipHover.containsMouse
    readonly property alias bridgeContainsMouse: bridgeHover.containsMouse

    // ════════════════════════════════════════
    // Tooltip 弹出层（使用 Popup 脱离父级裁剪；覆盖 桥接条 + tooltip）
    // ════════════════════════════════════════
    Popup {
        id: tooltipPopup
        visible: tipVisible
        padding: 0
        background: null
        modal: false
        closePolicy: Popup.NoAutoClose

        // Popup 覆盖 桥接条 + tooltip：arrowOnTop 时桥接条在上（朝上方滑针），否则在下。
        x: handleRoot.tooltipLocalX
        y: handleRoot.arrowOnTop ? (handleRoot.tooltipLocalY - handleRoot.bridgeHeight)
                                 : handleRoot.tooltipLocalY
        width: handleRoot.tooltipRealWidth
        height: handleRoot.tooltipRealHeight + handleRoot.bridgeHeight

        // 桥接条（透明）：落在顶层 Popup 内，鼠标经过时保持 tooltip 可见，不被下层 RGB 输入框抢占。
        MouseArea {
            id: bridgeHover
            width: parent.width
            height: handleRoot.bridgeHeight
            y: handleRoot.arrowOnTop ? 0 : handleRoot.tooltipRealHeight
            hoverEnabled: true
            cursorShape: Qt.ArrowCursor
            onClicked: handleRoot.enterEditing()
        }

        Rectangle {
            id: tooltipContent
            width: handleRoot.tooltipRealWidth
            height: handleRoot.tooltipRealHeight
            y: handleRoot.arrowOnTop ? handleRoot.bridgeHeight : 0
            radius: 4
            color: Colors.color_141414

            MouseArea {
                id: tipHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.ArrowCursor
                onClicked: handleRoot.enterEditing()
            }

            // 小三角指示箭头（下方朝下 或 上方朝上）
            Canvas {
                width: 10; height: 5
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: arrowOnTop ? undefined : parent.bottom
                anchors.topMargin: arrowOnTop ? 0 : -1
                anchors.bottom: arrowOnTop ? parent.top : undefined
                anchors.bottomMargin: arrowOnTop ? -1 : 0
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    ctx.fillStyle = tooltipContent.color;
                    ctx.beginPath();
                    if (handleRoot.arrowOnTop) {
                        ctx.moveTo(0, height);
                        ctx.lineTo(width, height);
                        ctx.lineTo(width / 2, 0);
                    } else {
                        ctx.moveTo(0, 0);
                        ctx.lineTo(width, 0);
                        ctx.lineTo(width / 2, height);
                    }
                    ctx.closePath();
                    ctx.fill();
                }
            }

            // ── 显示态内容 ──
            Row {
                id: tipContent
                anchors.centerIn: parent
                spacing: 4
                visible: !handleRoot.editing

                Text {
                    visible: handleRoot.label !== ""
                    text: handleRoot.label + ":"
                    color: Colors.color_EEEEEE
                    font.pixelSize: 11
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: handleRoot.displayText(handleRoot.value)
                    color: Colors.color_EEEEEE
                    font.pixelSize: 11
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }
}
