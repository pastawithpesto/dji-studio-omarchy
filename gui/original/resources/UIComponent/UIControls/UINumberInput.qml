import QtQuick
import QtQuick.Layouts
import UIComponent

// UINumberInput — 数值输入框（含可选步进按钮）
//
// spinLayout 控制步进按钮布局：
//   UISpinLayout.None       — 纯输入框（默认）
//   UISpinLayout.Horizontal — [−] [input] [+]  左右横排
//   UISpinLayout.Vertical   — [input][▴/▾]  右侧上下
//
// 按钮自定义：
//   decreaseDelegate / increaseDelegate 接受 QML Component；
//   null → 使用内置默认样式。

Item {
    id: root

    // ── 样式 ──────────────────────────────────────────────────────
    property int size: UIControlSize.M
    readonly property var _style: UITheme.numberInput.of(size)

    property color textColor:          _style.text.base
    property color textColorDisabled:  _style.text.disabled
    property color textColorSelected: _style.selectedTextColor

    property color bgColor:            _style.bg.base
    property color bgColorDisabled:    _style.bg.disabled
    property color bgColorSelection:   _style.selectionColor

    property color borderColor:        _style.border.base
    property color borderColorFocused: _style.border.focused

    property color iconBgColor:        _style.iconBg.base
    property color iconBgColorHovered: _style.iconBg.hovered
    property color unitColor:          _style.suffixColor

    property int   borderRadius:       _style.borderRadius
    property bool  borderVisible:      false
    property int   fontSize:           _style.fontSize
    property int   inputWidth: UISize.numberInputWidth // 设置输入框宽度不要直接使用width

    property bool _isInputFocused: false

    readonly property color resolvedTextColor:
        enabled ? textColor : textColorDisabled
    readonly property color resolvedBgColor:
        enabled ? bgColor : bgColorDisabled
    readonly property color resolvedBorderColor:
        _isInputFocused ? borderColorFocused : borderColor

    // ── 数值 API ──────────────────────────────────────────────────
    property real min:      0
    property real max:      100
    property real value:    0
    property real step:     1
    property int  decimals: 0
    property real epsilon: 1e-9

    // ── 展示 API ──────────────────────────────────────────────────
    property bool   isFillWidth:           false
    property int    inputHAlignment:       Qt.AlignHCenter
    property bool   hasThousandsSeparator: false
    property bool   selectable:            true
    property string thousandsSeparator:    ","
    property string unit:                  ""
    property bool   readOnly:              false
    property bool   wheelEnabled:          true

    // ── 步进布局 ──────────────────────────────────────────────────
    property int spinLayout: UISpinLayout.None

    property Component decreaseDelegate: null
    property Component increaseDelegate: null

    // 按钮尺寸：Horizontal 默认正方形（= 控件高度），Vertical 默认 20px
    property int btnWidth: _isVertical ? _style.height / 2 : _style.height
    property int btnMargin: 2

    // 暴露输入框背景体，允许外部直接访问 / 覆盖属性（color / radius / border 等）
    property alias background: _inputBody

    // ── 信号 ──────────────────────────────────────────────────────
    signal editingFinished()

    // ── 公开方法 ──────────────────────────────────────────────────
    function increase() { _stepBy(1)  }
    function decrease() { _stepBy(-1) }

    // ── 内部派生 ──────────────────────────────────────────────────
    readonly property bool _isHorizontal: spinLayout === UISpinLayout.Horizontal
    readonly property bool _isVertical:   spinLayout === UISpinLayout.Vertical
    readonly property bool _hasButtons:   _isHorizontal || _isVertical

    readonly property bool _canNeg:         min < 0

    readonly property string _sepEscaped: {
        const s = thousandsSeparator
        if (!s) return ""
        return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
    }

    // ── 隐式尺寸 ──────────────────────────────────────────────────
    implicitHeight: _style.height
    implicitWidth: {
        if (_isHorizontal) return btnWidth + inputWidth + btnWidth + 2 * btnMargin
        if (_isVertical)   return inputWidth + btnWidth + btnMargin
        return inputWidth
    }

    // ── 工具方法 ──────────────────────────────────────────────────
    function _clamp(v) { return Math.max(min, Math.min(max, v)) }

    function _stripSep(s) {
        return !thousandsSeparator ? String(s) : String(s).split(thousandsSeparator).join("")
    }

    function _addSep(s) {
        s = _stripSep(s)
        return s.replace(/(\d)(?=(\d{3})+$)/g, "$1" + thousandsSeparator)
    }

    function _fmt(v) {
        let n = isNaN(Number(v)) ? 0 : _clamp(Number(v))
        let s = n.toFixed(decimals)
        let neg = s.startsWith("-")
        let body = neg ? s.slice(1) : s
        let parts = body.split(".")
        if (hasThousandsSeparator) parts[0] = _addSep(parts[0])
        return (neg ? "-" : "") + parts.join(".")
    }

    function _stepBy(dir) {
        let next = parseFloat(_clamp(value + dir * step).toFixed(decimals))
        value = next
        _inputItem._commit(_fmt(next))
    }

    // 将用户正在输入的文本规范化为合法的显示字符串。
    // 返回规范化文本；返回 null 表示用户仍在输入过渡状态（如末尾 "-" 或 "."），不需要修改。
    function _buildTarget(inputText) {
        const raw = _stripSep(inputText)
        let neg   = raw.startsWith("-")
        const abs = neg ? raw.slice(1) : raw
        if (abs === "") return null

        if (decimals > 0) {
            const dotEnd = abs.endsWith(".")
            const parts  = abs.split(".")
            let iStr = parts[0] || "0"
            let dStr = parts.length > 1 ? parts[1].slice(0, decimals) : ""

            // 仅在非末尾点时做值域校验和 clamp
            if (!dotEnd) {
                const num = parseFloat((neg ? "-" : "") + iStr + (dStr ? "." + dStr : ""))
                if (isNaN(num)) return null
                const clamped = _clamp(num)
                if (Math.abs(clamped - num) > 1e-10) {
                    const fp = Math.abs(clamped).toFixed(decimals).split(".")
                    iStr = fp[0]
                    dStr = fp[1] ?? ""
                    neg  = clamped < 0
                }
            }

            const fi = hasThousandsSeparator ? _addSep(iStr) : _stripSep(iStr)
            if (dotEnd) return (neg ? "-" : "") + fi + "."
            return (neg ? "-" : "") + (dStr ? fi + "." + dStr : fi)
        } else {
            const n  = parseInt(abs, 10)
            if (isNaN(n)) return null
            const sv = _clamp(neg ? -n : n)
            const absStr = hasThousandsSeparator
                ? _addSep(Math.abs(sv).toString())
                : Math.abs(sv).toString()
            return (sv < 0 ? "-" : "") + absStr
        }
    }

    // 将光标位置从旧文本映射到新文本（按剥离千分位后的裸字符数对齐）。
    function _remapCursor(oldText, newText, oldPos) {
        if (!thousandsSeparator) return Math.min(oldPos, newText.length)
        const sep = thousandsSeparator
        const rawBefore = oldText.slice(0, oldPos).split(sep).join("").length
        let count = 0
        for (let i = 0; i < newText.length; i++) {
            if (count === rawBefore) return i
            if (newText[i] !== sep) count++
        }
        return newText.length
    }

    onValueChanged: {
        const v = _clamp(value)
        if (Math.abs(v - value) > 1e-10) { value = v; return }
        if (!_isInputFocused) _inputItem._commit(_fmt(value))
    }
    onHasThousandsSeparatorChanged: { if (!_isInputFocused) _inputItem._commit(_fmt(value)) }
    onThousandsSeparatorChanged:    { if (!_isInputFocused) _inputItem._commit(_fmt(value)) }
    onDecimalsChanged: {
        value = _clamp(parseFloat(Number(value).toFixed(decimals)))
        if (!_isInputFocused) _inputItem._commit(_fmt(value))
    }

    // ══════════════════════════════════════════════════════════════
    // 左减按钮（Horizontal 专用）
    // ══════════════════════════════════════════════════════════════
    Loader {
        id:      _decBtnLoader
        z:       1
        active:  root._isHorizontal
        visible: active
        width:   root.btnWidth
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom; }
        sourceComponent: root.decreaseDelegate ?? _defaultHDecBtn
        enabled: root.enabled && Math.abs(root.value - root.min) > root.epsilon
    }

    // ══════════════════════════════════════════════════════════════
    // 输入主体
    // ══════════════════════════════════════════════════════════════
    UIRadiusRectangle {
        id: _inputBody

        radius: {
            const r = root.borderRadius
            if (root._isHorizontal) return [0, 0, 0, 0]
            if (root._isVertical && root.btnMargin == 0) {
                return [r, 0, 0, r]
            }
            return [r, r, r, r]
        }

        color:        root.resolvedBgColor
        border.width: root.borderVisible ? 1 : 0
        border.color: root.resolvedBorderColor

        anchors {
            top:         parent.top
            bottom:      parent.bottom
            left:        root._isHorizontal ? _decBtnLoader.right : parent.left
            right:       root._hasButtons   ? _rightSide.left     : parent.right
            leftMargin:  root._isHorizontal ? (root.btnMargin > 0 ? root.btnMargin : -1) : 0
            rightMargin: root._hasButtons   ? (root.btnMargin > 0 ? root.btnMargin : -1) : 0
        }

        Item {
            id: _contentArea
            anchors.fill: parent
            clip: true

            MouseArea {
                anchors.fill: parent
                cursorShape: root.enabled && !root.readOnly ? Qt.IBeamCursor : Qt.ArrowCursor
                preventStealing: true
                enabled: root.enabled && !root.readOnly && root.selectable

                onPressed: function(mouse) {
                    _inputItem.forceActiveFocus()
                    var pos = mapToItem(_inputItem, mouse.x, mouse.y)
                    _inputItem.cursorPosition = _inputItem.positionAt(pos.x, pos.y)
                }

                onPositionChanged: function(mouse) {
                    var pos = mapToItem(_inputItem, mouse.x, mouse.y)
                    _inputItem.moveCursorSelection(_inputItem.positionAt(pos.x, pos.y))
                }

                onDoubleClicked: function(mouse) {
                    _inputItem.selectAll()
                }
            }

            RowLayout {
                anchors.fill: parent
                spacing: 0

                // 左侧 spacer：
                //   isFillWidth=true         → 固定宽度（左内边距）
                //   isFillWidth=false 左对齐 → 固定宽度（左内边距）
                //   isFillWidth=false 居中/右 → 弹性拉伸，将内容推向右侧
                Item {
                    Layout.fillWidth: !root.isFillWidth && root.inputHAlignment !== Qt.AlignLeft
                    implicitWidth:    root._style.paddingH
                }

                TextInput {
                    id: _inputItem

                    Layout.fillWidth:  root.isFillWidth
                    Layout.fillHeight: true
                    horizontalAlignment: root.inputHAlignment
                    verticalAlignment:   Qt.AlignVCenter
                    text:                root._fmt(root.value)
                    color:               root.resolvedTextColor
                    selectionColor:      root.bgColorSelection
                    selectedTextColor:   root.textColorSelected
                    font.pixelSize:      root.fontSize
                    selectByMouse:       root.selectable
                    readOnly:           !root.enabled || root.readOnly
                    activeFocusOnPress:  true
                    activeFocusOnTab:    true

                    RegularExpressionValidator { id: _vPosInt; regularExpression: new RegExp("^[\\d" + root._sepEscaped + "]*$") }
                    RegularExpressionValidator { id: _vPosDec; regularExpression: new RegExp("^[\\d" + root._sepEscaped + "]*\\.?\\d*$") }
                    RegularExpressionValidator { id: _vNegInt; regularExpression: new RegExp("^-?[\\d" + root._sepEscaped + "]*$") }
                    RegularExpressionValidator { id: _vNegDec; regularExpression: new RegExp("^-?[\\d" + root._sepEscaped + "]*\\.?\\d*$") }

                    validator: {
                        if (root._canNeg && root.decimals > 0) return _vNegDec
                        if (root._canNeg)                      return _vNegInt
                        if (root.decimals > 0)                 return _vPosDec
                        return _vPosInt
                    }

                    property bool _isBusy: false

                    function _commit(s) {
                        _isBusy = true
                        text = s
                        cursorPosition = text.length
                        _isBusy = false
                    }

                    function _commitCurrentText() {
                        let raw = root._stripSep(text)
                        let n = parseFloat(raw)
                        if (isNaN(n)) n = root.value
                        n = parseFloat(root._clamp(n).toFixed(root.decimals))
                        root.value = n
                        _commit(root._fmt(n))
                        root.editingFinished()
                    }

                    onActiveFocusChanged: {
                        root._isInputFocused = activeFocus
                        if (!activeFocus) _commitCurrentText()
                    }

                    Keys.onUpPressed:     function(e) { root.increase(); e.accepted = true }
                    Keys.onDownPressed:   function(e) { root.decrease(); e.accepted = true }
                    Keys.onReturnPressed: function(e) { root.forceActiveFocus(); e.accepted = true }
                    Keys.onEnterPressed:  function(e) { root.forceActiveFocus(); e.accepted = true }

                    onTextChanged: {
                        if (_isBusy) return
                        const target = root._buildTarget(text)
                        if (target === null) return

                        if (target !== text) {
                            const newPos = root._remapCursor(text, target, cursorPosition)
                            _isBusy = true
                            text = target
                            cursorPosition = newPos
                            _isBusy = false
                        }

                        if (!target.endsWith(".")) {
                            const fv = parseFloat(root._stripSep(target))
                            if (!isNaN(fv) && Math.abs(fv - root.value) > 1e-10) root.value = fv
                        }
                    }
                }

                Text {
                    id: _unitText
                    visible:           root.unit.length > 0
                    text:              root.unit
                    Layout.fillHeight: true
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize:    root.fontSize
                    color:             root.unitColor
                    opacity:           root.enabled ? 1.0 : 0.4
                }

                // 右侧 spacer：
                //   isFillWidth=true         → 固定宽度（右内边距）
                //   isFillWidth=false 右对齐 → 固定宽度（右内边距）
                //   isFillWidth=false 居中/左 → 弹性拉伸，将内容推向左侧
                Item {
                    Layout.fillWidth: !root.isFillWidth && root.inputHAlignment !== Qt.AlignRight
                    implicitWidth:    root._style.paddingH
                }
            }
        }
    }

    // ══════════════════════════════════════════════════════════════
    // 右侧区域：Horizontal = 右加按钮；Vertical = 上下按钮列
    // ══════════════════════════════════════════════════════════════
    Item {
        id:      _rightSide
        z:       1
        visible: root._hasButtons
        width:   root._hasButtons ? root.btnWidth : 0
        anchors { right: parent.right; top: parent.top; bottom: parent.bottom; }
        // Horizontal：右增按钮
        Loader {
            active:  root._isHorizontal
            visible: active
            anchors.fill: parent
            sourceComponent: root.increaseDelegate ?? _defaultHIncBtn
            enabled: root.enabled && Math.abs(root.value - root.max) > root.epsilon
        }

        // Vertical：上增按钮
        Loader {
            active:  root._isVertical
            visible: active
            width:   parent.width
            height: parent.height / 2
            anchors { top: parent.top; }
            sourceComponent: root.increaseDelegate ?? _defaultVIncBtn
            enabled: root.enabled && Math.abs(root.value - root.max) > root.epsilon
        }

        Loader {
            active:  root._isVertical
            visible: active
            z:       1
            width:   parent.width
            height: parent.height / 2
            anchors { bottom: parent.bottom }
            sourceComponent: root.decreaseDelegate ?? _defaultVDecBtn
            enabled: root.enabled && Math.abs(root.value - root.min) > root.epsilon
        }
    }

    // ── 滚轮 ──────────────────────────────────────────────────────
    WheelHandler {
        enabled:         root._isInputFocused && root.wheelEnabled
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: function(event) {
            if (event.angleDelta.y > 0) root.increase()
            else                        root.decrease()
            event.accepted = true
        }
    }

    Component {
        id: _defaultHDecBtn
        UIRadiusRectangle {
            width:        root.btnWidth
            radius:       [root.borderRadius, 0, 0, root.borderRadius]
            color: _h.hovered && root.enabled && !_tap.pressed ? root.iconBgColorHovered : root.iconBgColor

            UIIcon {
                anchors.centerIn: parent
                iconSize: root._style.indicatorSize
                source:   UITheme.isolationIcon("zoom_in.svg")
            }
            HoverHandler { id: _h;   cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor }
            TapHandler   { id: _tap; enabled: root.enabled; onTapped: root.decrease() }
        }
    }

    Component {
        id: _defaultHIncBtn
        UIRadiusRectangle {
            width:        root.btnWidth
            radius:       [0, root.borderRadius, root.borderRadius, 0]
            color: _h.hovered && root.enabled && !_tap.pressed ? root.iconBgColorHovered : root.iconBgColor
            UIIcon {
                anchors.centerIn: parent
                iconSize: root._style.indicatorSize
                source:   UITheme.isolationIcon("zoom_out.svg")
            }
            HoverHandler { id: _h;   cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor }
            TapHandler   { id: _tap; enabled: root.enabled; onTapped: root.increase() }
        }
    }

    Component {
        id: _defaultVIncBtn
        UIButton {
            anchors.fill: parent
            iconSource: UITheme.isolationIcon("button/Button_Increase_Default.svg")
            iconSourceHovered: UITheme.isolationIcon("button/Button_Increase_Hover.svg")
            iconSourceDisabled: UITheme.isolationIcon("button/Button_Increase_Disabled.svg")
            type: UIButtonType.IconOnly
            iconSize: parent.height
            onClicked: {
                root.increase()
            }
        }
    }
    
    Component {
        id: _defaultVDecBtn
        UIButton {
            anchors.fill: parent
            iconSource: UITheme.isolationIcon("button/Button_Decrease_Default.svg")
            iconSourceHovered: UITheme.isolationIcon("button/Button_Decrease_Hover.svg")
            iconSourceDisabled: UITheme.isolationIcon("button/Button_Decrease_Disabled.svg")
            type: UIButtonType.IconOnly
            iconSize: parent.height
            onClicked: {
                root.decrease()
            }
        }
    }
}
