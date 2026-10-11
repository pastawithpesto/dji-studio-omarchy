import QtQuick 2.15
import QtQuick.Controls
import Config 1.0
import Controls 1.0

// ════════════════════════════════════════
// 可编辑数值组件公共基类
// 承载共享的编辑状态机、表达式解析、编辑态 TextInput 及失焦遮罩。
// 外壳（ColorWheelEditableTooltip / ColorWheelValueInput）通过设置
// editInputContainer 等参数化属性，把 editInput 重定向到各自容器。
// ════════════════════════════════════════
Item {
    id: handleRoot

    // ── 数据属性（外壳不得重复声明）──
    property real value: 0.0
    property real minValue: -1.0
    property real maxValue: 1.0
    property int  precision: 2

    // ── 状态 ──
    property bool editing: false
    property real originalValue: 0
    property bool replacedSelection: false   // 是否在全选状态下替换原内容

    signal valueModified(real newValue)
    signal tabPressed()              // Tab 循环通知，由父级色轮连线到下一个输入框

    // ── 步进属性 ──
    property real step: 0.01        // ↑/↓ 单步步长；Shift+↑/↓ 步长 ×10

    // ── TextInput 参数化（两个外壳在此差异化）──
    property color  editTextColor: Colors.color_EEEEEE
    property real   editFontSize: 11
    property int    editHorizontalAlignment: TextInput.AlignHCenter
    property real   editLeftMargin: 6
    property real   editRightMargin: 6
    property Item   editInputContainer: handleRoot   // 外壳指定 editInput 的父容器，默认自身避免 null

    // ── 工具函数 ──
    function displayText(v) {
        var s = v.toFixed(precision);
        if (v > 0) s = "+" + s;
        return s;
    }

    function editText(v) { return v.toFixed(precision); }

    function clampValue(v) {
        return Math.round(Math.min(maxValue, Math.max(minValue, v)) * Math.pow(10, precision)) / Math.pow(10, precision);
    }

    // ── 表达式解析 ──
    function evaluateExpression(expr) {
        if (expr === "") return originalValue;

        // 将中文全角/半角圆括号和句号归一化为英文字符
        expr = expr.replace(/（/g, '(').replace(/）/g, ')').replace(/。/g, '.').replace(/．/g, '.');

        // 仅当"未在全选状态下替换"时，才启用基于原值的相对运算
        if (!replacedSelection) {
            var first = expr.charAt(0);

            // 以 * 或 / 开头：基于原值的乘除
            if (first === '*') { var m = Number(expr.substring(1)); return isNaN(m) ? NaN : originalValue * m; }
            if (first === '/') { var d = Number(expr.substring(1)); return (isNaN(d) || d === 0) ? NaN : originalValue / d; }

            // 以 + 开头且无其他运算符：基于原值的加法
            if (first === '+' && (expr.match(/[+\-]/g) || []).length <= 1) {
                var a = Number(expr); return isNaN(a) ? NaN : originalValue + a;
            }
        }

        // 含运算符或括号：安全四则运算解析
        if (expr.indexOf('(') >= 0 || (expr.match(/[+\-*/]/g) || []).length > 0) {
            var result = _safeEval(expr);
            return isFinite(result) ? result : NaN;
        }

        // 纯数字
        var num = Number(expr);
        return isNaN(num) ? NaN : num;
    }

    // 递归下降解析器：仅支持 + - * / ( ) 和数字
    function _safeEval(expr) {
        var pos = 0;
        var ch = expr.charAt(0);

        function nextChar() { ch = (++pos < expr.length) ? expr.charAt(pos) : '\0'; }
        function skipSpaces() { while (ch === ' ') nextChar(); }

        function parseExpr() {
            var x = parseTerm();
            for (;;) {
                skipSpaces();
                if (ch === '+') { nextChar(); x += parseTerm(); }
                else if (ch === '-') { nextChar(); x -= parseTerm(); }
                else break;
            }
            return x;
        }

        function parseTerm() {
            var x = parseFactor();
            for (;;) {
                skipSpaces();
                if (ch === '*') { nextChar(); x *= parseFactor(); }
                else if (ch === '/') { nextChar(); var d = parseFactor(); x = (d === 0) ? NaN : x / d; }
                else break;
            }
            return x;
        }

        function parseFactor() {
            skipSpaces();
            var neg = false;
            if (ch === '+') { nextChar(); }
            else if (ch === '-') { neg = true; nextChar(); }
            skipSpaces();

            var x;
            if (ch === '(') {
                nextChar();
                x = parseExpr();
                if (ch === ')') nextChar();
            } else {
                var start = pos;
                while ((ch >= '0' && ch <= '9') || ch === '.') nextChar();
                var token = expr.substring(start, pos);
                x = (token.length > 0) ? Number(token) : NaN;
            }
            return neg ? -x : x;
        }

        var result = parseExpr();
        return (pos >= expr.length) ? result : NaN;
    }

    // ════════════════════════════════════════
    // 编辑逻辑
    // ════════════════════════════════════════
    function enterEditing() {
        if (editing || !enabled) return;
        editing = true;
        replacedSelection = false;   // 每次进入编辑先重置
        originalValue = value;
        editInput.text = editText(value);
        editInput.forceActiveFocus();
        editInput.selectAll();
        overlayLoader.active = true;
    }

    function commitEditing() {
        if (!editing) return;
        var result = evaluateExpression(editInput.text.trim());
        var newVal = isNaN(result) ? originalValue : clampValue(result);
        editing = false;
        overlayLoader.active = false;
        valueModified(newVal);
    }

    function cancelEditing() {
        if (!editing) return;
        editing = false;
        overlayLoader.active = false;
    }

    function applyStep(delta) {
        var current = evaluateExpression(editInput.text.trim());
        if (isNaN(current)) current = originalValue;
        var newVal = clampValue(current + delta);
        originalValue = newVal;
        editInput.text = editText(newVal);
        editInput.selectAll();
        valueModified(newVal);
    }

    // ── 共享编辑态输入框 ──
    // 通过 parent 绑定重定向到外壳指定的容器（Tooltip 的 Popup 内 / ValueInput 的 inputBg 内）
    TextInput {
        id: editInput
        parent: handleRoot.editInputContainer
        visible: handleRoot.editing
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            verticalCenterOffset: 1      // 文本向下微调 1px，补偿字体 ascent/descent 不对称导致的视觉偏移
            leftMargin: handleRoot.editLeftMargin
            rightMargin: handleRoot.editRightMargin
        }

        horizontalAlignment: handleRoot.editHorizontalAlignment
        color: handleRoot.editTextColor
        font.pixelSize: handleRoot.editFontSize
        selectByMouse: true
        selectionColor: Colors.color_EEEEEE
        selectedTextColor: Colors.color_141414
        clip: true  // 有了宽度约束，clip 才真正生效
        inputMethodHints: Qt.ImhNoEditMenu | Qt.ImhNoPredictiveText

        // 只允许数字和数学运算符（含中文全角圆括号和句号，提交时自动转为英文）
        validator: RegularExpressionValidator {
            regularExpression: /[0-9+\-*/.() （）。．]*/
        }

        // 实时将中文全角圆括号归一化为英文圆括号（句号由 IME 直接上屏为英文小数点，无需处理）
        onTextEdited: {
            var normalized = text.replace(/（/g, '(').replace(/）/g, ')').replace(/。/g, '.').replace(/．/g, '.');
            if (normalized !== text) {
                var pos = cursorPosition;
                text = normalized;
                cursorPosition = pos;
            }
        }

        // 在文字被修改"前"检测——若全选状态下键入可见字符，则标记为替换
        Keys.onPressed: (event) => {
            if (!handleRoot.replacedSelection
                    && editInput.text.length > 0
                    && editInput.selectedText.length === editInput.text.length   // 当前为全选
                    && event.text.length === 1
                    && /[0-9+\-*/.() （）。．]/.test(event.text)                          // 可插入字符
                    && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier))) {
                handleRoot.replacedSelection = true;
            }
            // 不 accept，字符照常输入并替换选区
        }

        // 拦截特殊键，防止被全局快捷键吃掉（项目标准方式）
        Keys.onShortcutOverride: (event) => {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                event.accepted = true;
                editInput.focus = false;
            } else if (event.key === Qt.Key_Tab) {
                event.accepted = true;
                editInput.focus = false;    // 先提交（触发 onActiveFocusChanged → commitEditing）
                handleRoot.tabPressed();    // 再通知父级聚焦下一个输入框
            } else if (event.key === Qt.Key_Escape) {
                event.accepted = true;
                handleRoot.cancelEditing();
            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
                event.accepted = true;
                var sign = (event.key === Qt.Key_Up) ? 1 : -1;
                var mult = (event.modifiers & Qt.ShiftModifier) ? 10 : 1;
                handleRoot.applyStep(sign * mult * handleRoot.step);
            }
        }

        // 失去焦点时确认输入（点击外部 / Enter / Tab 都走这里）
        onActiveFocusChanged: {
            if (!activeFocus && handleRoot.editing) {
                handleRoot.commitEditing();
            }
        }
    }

    // ── 点击外部失焦遮罩（项目标准 TextInputOverlay）──
    Loader {
        id: overlayLoader
        active: false
        sourceComponent: TextInputOverlay {
            activeInputContainer: editInput
        }
    }
}
