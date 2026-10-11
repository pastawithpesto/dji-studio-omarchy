/**
 * @author: robert.guo
 * @details: Common工具类，有重复使用的方法可以在这儿定义
 * @date: 2024-04-17 21:50:08
 */

pragma Singleton
import QtQuick 2.15

QtObject {

    /**
     * @desc 字符串替换筛选特殊字符 \/?<>*"
     *
     * @text 字符串
     * @return 筛选后的字符串
     */
    function sanitizeString(text) {
      return text.replace(/[\\\/:\*\?"<>|]/g, '');
    }

    /**
     * @desc 非法字符校验 / \ : * ? " < > |
     *
     * @text 字符串
     * @return 判断结果
     */
    function hasInvalidChar(text) {
      return /[\/\\:*?"<>|]/.test(text);
    }


    /**
     * @desc 从列表中删除文件，并返回新的新列表
     *
     * @file 删除文件
     * @files 列表集
     * @return 删除后的新列表
     */
    function deleteFileWithReturnResult(file, files) {
        if (file === null || files === null) {
            return files
        }

        for (var i = 0; i < files.length; i++) {
            if (file.path === files[i].path) {
                break;
            }
        }
        if (i < files.length) {
            files.splice(i, 1)
            files = files
        }
        return files
    }

    /**
     * @desc 根据文件路径查找文件索引
     *
     * @path 文件路径
     * @files ListModel数据
     * @return 文件索引
     */
    function lookupFileIndexByPath(path, files) {
        var index = -1;
        if (isNull(files)) {
            return index
        }

        for (var i = 0; i < files.count; i++) {
            if (!isNull(files.get(i)) && path === files.get(i).path) {
                index = i;
                break;
            }
        }
        return index;
    }

    /**
     * @desc 判断item是否为空
     *
     * @item 输入
     * @return 是否为空
     */
    function isNull(item) {
        if (item === null || item === undefined) {
            return true
        } else {
            return false
        }
    }

    /**
     * @desc 判断字符串是否为空
     *
     * @item 入参
     * @return 是否为空
     */
    function isEmptyStr(item) {
        if (item === null || item === undefined || item === "") {
            return true
        } else {
            return false
        }
    }

    // 基数系数，原则上应该是1024， 之所以定义为1000，因为这样算出来的数值和系统展示的文件大小才一致
    property int base_file_number: isWindows() ? 1024 : 1000
    // 获取文件大小信息，返回M单位。sep 为数字与单位间的分隔符（默认空，兼容已有调用方）
    function getFileSizeInfo(size, sep) {
        sep = sep || "";
        if (size < base_file_number)
            return size.toFixed(1) + sep + "B";
        else if (size < base_file_number * base_file_number)
            return (size * 1 / base_file_number).toFixed(1) + sep + "KB";
        else if (size < base_file_number * base_file_number * base_file_number)
            return (size * 1 / base_file_number / base_file_number).toFixed(1) + sep + "MB";
        else if (size < base_file_number * base_file_number * base_file_number * base_file_number)
            return (size * 1 / base_file_number / base_file_number / base_file_number).toFixed(1) + sep + "GB";
        else if (size < base_file_number * base_file_number * base_file_number * base_file_number * base_file_number)
            return (size * 1 / base_file_number / base_file_number / base_file_number / base_file_number).toFixed(1) + sep + "TB";
    }

    //判断是否为Windows
    function isWindows() {
        return Qt.platform.os === "windows";
    }

    //限制值在一个区间内
    function clampValue(value, min, max) {
        if (value < min) {
            return min;
        } else if (value > max) {
            return max;
        } else {
            return value;
        }
    }

    //判断是否显示防水壳
    function isEnableWaterProof() {
        return lightSetting.getString("ProofEnable") === "1";
    }

    //字符的最大长度,一个汉字=2个字符宽度
    function mixedTextLength(text) {
        var len = 0;
        for (var i = 0; i < text.length; i++) {
            len += text.charCodeAt(i) > 127 ? 2 : 1;
        }
        return len;
    }

    function truncateByMixedLength(text, maxLen) {
        var len = 0;
        for (var i = 0; i < text.length; i++) {
            len += text.charCodeAt(i) > 127 ? 2 : 1;
            if (len > maxLen) {
                return text.substring(0, i);
            }
        }
        return text;
    }
    /**
    * @desc 校验数字输入，支持负号、小数点，四舍五入到整数并截断到 [min, max] 范围
    * @param text 输入字符串
    * @param min 最小值
    * @param max 最大值
    * @return 有效数字或 null
     */
    function validateNumberInput(text, min, max) {

        if (max < min)
            return null

        let str = text.trim()

        // 空、只有符号的无效输入，恢复原值
        if (str === "" || str === "-" || str === "." || str === "-.") {
            return null
        }

        // 多个小数点或多个负号视为非法
        if ((str.match(/\./g) || []).length > 1 || (str.match(/-/g) || []).length > 1) {
            return null
        }

        // .5 → 0.5，-.5 → -0.5
        str = str.replace(/^(-?)\./, "$10.")

        let value = parseFloat(str)

        if (isNaN(value)) {
            return null
        }

        // 四舍五入到整数
        value = value >= 0 ? Math.round(value) : -Math.round(-value)
        // 超出范围截断
        value = Math.max(min, Math.min(max, value))

        return value
    }

    // 递归下降解析器：仅支持 + - * / ( ) 和数字（与 ColorWheelValueEditorBase._safeEval 同构，
    // 抽到此处后 FilterInfoSetting 等场景可复用；不用 eval / new Function，安全）
    function _safeEvalFormula(expr) {
        var pos = 0
        var ch = expr.charAt(0)

        function nextChar() { ch = (++pos < expr.length) ? expr.charAt(pos) : '\0' }
        function skipSpaces() { while (ch === ' ') nextChar() }

        function parseFactor() {
            skipSpaces()
            var neg = false
            if (ch === '+') { nextChar() }
            else if (ch === '-') { neg = true; nextChar() }
            skipSpaces()

            var x
            if (ch === '(') {
                nextChar()
                x = parseExpr()
                if (ch === ')') nextChar()
            } else {
                var start = pos
                while ((ch >= '0' && ch <= '9') || ch === '.') nextChar()
                var token = expr.substring(start, pos)
                x = (token.length > 0) ? Number(token) : NaN
            }
            return neg ? -x : x
        }

        function parseTerm() {
            var x = parseFactor()
            for (;;) {
                skipSpaces()
                if (ch === '*') { nextChar(); x *= parseFactor() }
                else if (ch === '/') { nextChar(); var d = parseFactor(); x = (d === 0) ? NaN : x / d }
                else break
            }
            return x
        }

        function parseExpr() {
            var x = parseTerm()
            for (;;) {
                skipSpaces()
                if (ch === '+') { nextChar(); x += parseTerm() }
                else if (ch === '-') { nextChar(); x -= parseTerm() }
                else break
            }
            return x
        }

        var result = parseExpr()
        return (pos >= expr.length) ? result : NaN
    }

    /**
    * @desc 校验公式输入：支持 + - * / ( ) 与中文全角括号/句号，以及基于原值的相对运算
    *       ("+10" 加、"*2" 乘、"/2" 除，仅当 originalValue 有效且非全选替换态时生效）。
    *       结果四舍五入到整数并截断到 [min, max]；非法输入返回 null。
    * @param text 输入字符串
    * @param min 最小值
    * @param max 最大值
    * @param originalValue 原值（用于相对运算），null/undefined 关闭相对运算
    * @param replacedSelection 全选态下键入替换过：true 时禁用相对运算（避免 "+10" 误判为原值+10）
    * @return 有效整数或 null
    */
    function validateFormulaInput(text, min, max, originalValue, replacedSelection) {
        if (max < min)
            return null

        let str = text.trim()
        if (str === "" || str === "-" || str === "." || str === "-.")
            return null

        // 中文全角圆括号/句号归一化为半角
        str = str.replace(/（/g, '(').replace(/）/g, ')').replace(/。/g, '.').replace(/．/g, '.')

        // 白名单：仅允许数字/运算符/括号/小数点/空白
        if (!/^[0-9+\-*/.()\s]+$/.test(str))
            return null

        let value = NaN
        const hasOrigin = (originalValue !== null && originalValue !== undefined && !isNaN(originalValue))

        // 相对运算："*N" / "/N" / "+N"（仅在非替换态且提供原值时启用）
        if (hasOrigin && !replacedSelection) {
            const first = str.charAt(0)
            if (first === '*') {
                const m = Number(str.substring(1))
                if (!isNaN(m)) value = originalValue * m
            } else if (first === '/') {
                const d = Number(str.substring(1))
                if (!isNaN(d) && d !== 0) value = originalValue / d
            } else if (first === '+' && (str.match(/[+\-]/g) || []).length <= 1) {
                const a = Number(str)
                if (!isNaN(a)) value = originalValue + a
            }
        }

        // 相对运算未命中：走安全四则解析（含括号/多元运算），或纯数字
        if (isNaN(value)) {
            if (str.indexOf('(') >= 0 || (str.match(/[+\-*/]/g) || []).length > 0) {
                value = _safeEvalFormula(str)
            } else {
                value = Number(str)
            }
        }

        if (isNaN(value) || !isFinite(value))
            return null

        value = value >= 0 ? Math.round(value) : -Math.round(-value)
        value = Math.max(min, Math.min(max, value))
        return value
    }
}
