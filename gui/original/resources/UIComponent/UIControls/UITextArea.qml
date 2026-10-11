import QtQuick
import QtQuick.Controls
import QtQuick.Templates as T
import UIComponent

// UITextArea
//   多行文本输入框。Templates 基类 TextArea + Flickable 纵向 UIScrollBar。
//   borderVisible    控制边框显隐
//   readOnly         只读态 (alias 到内部 TextArea)
//   bgColorReadOnly  readOnly 态背景色，默认与 bgColorDisabled 同色
FocusScope {
    id: root

    property int size: UIControlSize.M
    property bool borderVisible: false

    property alias text: _textArea.text
    property alias placeholderText: _textArea.placeholderText
    property alias readOnly: _textArea.readOnly
    property alias wrapMode: _textArea.wrapMode
    property alias font: _textArea.font
    property alias length: _textArea.length
    property alias preeditText: _textArea.preeditText
    property alias activeFocusOnPress: _textArea.activeFocusOnPress
    property int maxLength: -1

    readonly property var _style: UITheme.textArea.of(size)
    readonly property int _borderWidth: borderVisible ? 1 : 0

    property color textColor:         _style.text.base
    property color textColorDisabled: _style.text.disabled
    property color bgColor:           _style.bg.base
    property color bgColorDisabled:   _style.bg.disabled
    property color bgColorReadOnly:   _style.bg.disabled
    property color borderColor:       _style.border.base
    property color borderColorFocused:_style.border.focused
    property color placeholderTextColor: _style.text.disabled
    property int   borderRadius:      _style.borderRadius
    property int   paddingH:          _style.paddingH
    property int   paddingV:          _style.paddingV

    readonly property color resolvedTextColor:
        enabled ? textColor : textColorDisabled
    readonly property color resolvedBgColor: {
        if (!enabled)            return bgColorDisabled
        if (_textArea.readOnly)  return bgColorReadOnly
        return bgColor
    }
    readonly property color resolvedBorderColor:
        _textArea.activeFocus && !_textArea.readOnly ? borderColorFocused : borderColor

    Rectangle {
        anchors.fill: parent
        radius: root.borderRadius
        color:  root.resolvedBgColor
        border.width: root._borderWidth
        border.color: root.resolvedBorderColor
    }

    Flickable {
        id: _flickable
        anchors.fill: parent
        anchors.margins: root._borderWidth
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        contentWidth: width
        contentHeight: Math.max(_textArea.contentHeight + _textArea.topPadding, height)

        UIText {
            x: root.paddingH
            y: root.paddingV
            width: _flickable.width - root.paddingH * 2
            text: root.placeholderText
            color: root.placeholderTextColor
            font: _textArea.font
            wrapMode: Text.Wrap
            visible: !root.length && !root.preeditText
                     && (root.placeholderText ?? "").length > 0
        }

        T.TextArea {
            id: _textArea

            leftPadding:   root.paddingH
            rightPadding:  root.paddingH
            topPadding:    root.paddingV
            bottomPadding: root.paddingV

            focus: true
            width: _flickable.width
            implicitHeight: Math.max(contentHeight + topPadding + bottomPadding,
                                     _flickable.height)

            font.pixelSize: root._style.fontSize

            color:                root.resolvedTextColor
            selectionColor:       root._style.selectionColor
            selectedTextColor:    root._style.selectedTextColor

            wrapMode: TextEdit.Wrap
            hoverEnabled: true

            background: null

            Keys.onPressed: function(event) {
                if (root.maxLength < 0) return
                if (event.text.length === 0) return
                if (event.matches(StandardKey.Paste) || event.matches(StandardKey.Cut)
                    || event.matches(StandardKey.Undo) || event.matches(StandardKey.Redo))
                    return
                if (event.key === Qt.Key_Backspace || event.key === Qt.Key_Delete)
                    return
                if (event.modifiers & Qt.ControlModifier) return
                if (text.length >= root.maxLength && !_textArea.selectedText) {
                    event.accepted = true
                }
            }

            property bool _truncating: false
            onTextChanged: {
                if (_truncating) return
                if (root.maxLength >= 0 && text.length > root.maxLength) {
                    _truncating = true
                    var excess = text.length - root.maxLength
                    var pos = cursorPosition
                    var cutStart = Math.max(0, pos - excess)
                    text = text.substring(0, cutStart) + text.substring(pos)
                    cursorPosition = cutStart
                    _truncating = false
                }
            }

            onCursorRectangleChanged: {
                var cy = cursorRectangle.y
                var ch = cursorRectangle.height
                if (cy < _flickable.contentY)
                    _flickable.contentY = cy
                else if (cy + ch > _flickable.contentY + _flickable.height)
                    _flickable.contentY = cy + ch - _flickable.height
            }
        }

        ScrollBar.vertical: UIScrollBar {
            policy: ScrollBar.AsNeeded
        }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: function(event) {
            let step = event.angleDelta.y
            if (step !== 0) {
                let maxY = Math.max(0, _flickable.contentHeight - _flickable.height)
                _flickable.contentY = Math.max(0, Math.min(maxY, _flickable.contentY - step))
            }
            event.accepted = true
        }
    }

    HoverHandler {
        cursorShape: root.enabled && !_textArea.readOnly ? Qt.IBeamCursor : Qt.ArrowCursor
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: root.enabled && !_textArea.readOnly ? Qt.IBeamCursor : Qt.ArrowCursor
        onPressed: (mouse) => {
            root.forceActiveFocus()
            mouse.accepted = false
        }
    }
}
