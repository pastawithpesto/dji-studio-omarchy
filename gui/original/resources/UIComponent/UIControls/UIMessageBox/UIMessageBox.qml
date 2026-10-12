import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import UIComponent

// UIMessageBox
//   模态弹窗,带遮罩。Esc/点遮罩(可选) → cancel role;Enter → accept role。
//   通常由 UIMessageBoxHost.show(opts) 创建。
//
//   配置(opts):
//     title       string
//     text        string
//     checkbox    { label: string, checked: bool } | null
//     buttons     [{ text, role, type }]    role 至少需有 "accept" 或 "cancel"
//     progress    real
//                   小于 0 且非 -1     → 不显示进度区
//                   -1                → 显示 UISpinner(indeterminate)
//                   0.0 ~ 1.0         → 显示 UIProgress 条形进度
//     spinnerText string                    progress = -1 时 spinner 副文案
//     closeOnMaskClick bool                 默认 false
//
//   信号:
//     sigDismissed(role, checked)   role: "accept" | "cancel" | 其他自定义
Popup {
    id: root

    // ===== 变体 =====
    property int size: UIControlSize.M
    property int msgType: UIMessageBoxType.Normal
    property string title: ""
    property string text: ""
    property var    checkbox: null
    property var    buttons: [{ text: qsTr("确定"), role: "accept", type: UIButtonType.Brand }]
    property real   progress: -2
    property string spinnerText: ""
    property bool   closeOnMaskClick: false

    signal sigDismissed(string role, bool checked)

    readonly property var _style: UITheme.messageBox.of(size, msgType)

    property int    minHeight: _style.minHeight
    property int    contentMaxWidth: _style.contentMaxWidth
    property int    buttonMaxWidth: 0

    // ===== 9 态扁平字段（cascade 后大多走 base，与范式一致）=====
    property color bgColor:               _style.bg.base
    property color bgColorHovered:        _style.bg.hovered
    property color bgColorPressed:        _style.bg.pressed
    property color bgColorDisabled:       _style.bg.disabled
    property color bgColorChecked:        _style.bg.checked
    property color bgColorCheckedHovered: _style.bg.checkedHovered
    property color bgColorCheckedPressed: _style.bg.checkedPressed
    property color bgColorLoading:        _style.bg.loading
    property color bgColorFocused:        _style.bg.focused

    property color textColor:               _style.text.base
    property color textColorHovered:        _style.text.hovered
    property color textColorPressed:        _style.text.pressed
    property color textColorDisabled:       _style.text.disabled
    property color textColorChecked:        _style.text.checked
    property color textColorCheckedHovered: _style.text.checkedHovered
    property color textColorCheckedPressed: _style.text.checkedPressed
    property color textColorLoading:        _style.text.loading
    property color textColorFocused:        _style.text.focused

    property color textSecondaryColor:               _style.textSecondary.base
    property color textSecondaryColorHovered:        _style.textSecondary.hovered
    property color textSecondaryColorPressed:        _style.textSecondary.pressed
    property color textSecondaryColorDisabled:       _style.textSecondary.disabled
    property color textSecondaryColorChecked:        _style.textSecondary.checked
    property color textSecondaryColorCheckedHovered: _style.textSecondary.checkedHovered
    property color textSecondaryColorCheckedPressed: _style.textSecondary.checkedPressed
    property color textSecondaryColorLoading:        _style.textSecondary.loading
    property color textSecondaryColorFocused:        _style.textSecondary.focused

    property color maskColor:   _style.maskColor
    property color borderColor: _style.borderColor

    readonly property color resolvedBgColor:            bgColor
    readonly property color resolvedTextColor:          textColor
    readonly property color resolvedTextSecondaryColor: textSecondaryColor

    readonly property bool _hasProgress: progress >= 0 && progress <= 1
    readonly property bool _hasSpinner:  progress === -1

    modal: true
    focus: true
    parent: Overlay.overlay
    anchors.centerIn: Overlay.overlay
    closePolicy: closeOnMaskClick
                 ? (Popup.CloseOnEscape | Popup.CloseOnPressOutside)
                 : Popup.CloseOnEscape
    leftPadding:   _style.paddingH
    rightPadding:  _style.paddingH
    topPadding:    _style.paddingTop
    bottomPadding: _style.paddingBottom

    // 面板宽度由 token 决定，内部 Text 才能据此 wrap
    implicitWidth: root.contentMaxWidth + leftPadding + rightPadding
    implicitHeight: Math.max(topPadding + contentItem.implicitHeight + bottomPadding, root.minHeight)

    Overlay.modal: Rectangle { color: root.maskColor }

    background: Rectangle {
        color: root.resolvedBgColor
        radius: root._style.borderRadius
        border.width: root._style.borderWidth
        border.color: root.borderColor
    }

    contentItem: ColumnLayout {
        spacing: 0
        focus: true

        Keys.onReturnPressed: root._dismissByRole("accept")
        Keys.onEnterPressed:  root._dismissByRole("accept")

        ColumnLayout {
            id: _body
            spacing: 0
            visible: !root._hasSpinner
            Layout.fillWidth: true

            UIText {
                id: _titleText
                visible: root.title.length > 0
                text: root.title
                type: UITextType.Primary
                font.pixelSize: root._style.titleFontSize
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                Layout.maximumWidth: root.contentMaxWidth
                // Normal 类型有最小高度约束，内容不足时撑高 title 补齐差值
                Layout.minimumHeight: root.msgType === UIMessageBoxType.Normal
                    ? Math.max(-1, root.minHeight - root.topPadding - root.bottomPadding
                        - _bodyContent.implicitHeight - root._style.buttonTopMargin - _buttonRow.implicitHeight)
                    : -1
                Layout.alignment: Qt.AlignHCenter
                horizontalAlignment: Text.AlignHCenter
            }

            ColumnLayout {
                id: _bodyContent
                spacing: 0
                Layout.fillWidth: true

                UIText {
                    visible: root.text.length > 0
                    text: root.text
                    type: UITextType.Secondary
                    font.pixelSize: root._style.bodyFontSize
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                    Layout.maximumWidth: root.contentMaxWidth
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: root._style.sectionSpacing
                    horizontalAlignment: Text.AlignHCenter
                }

                Loader {
                    id: progressLoader
                    visible: active
                    active: root._hasProgress
                    Layout.fillWidth: true
                    Layout.preferredWidth: root.contentMaxWidth
                    Layout.topMargin: root._style.progressTopMargin
                    sourceComponent: UIProgress {
                        value: root.progress
                        width: progressLoader.width
                    }
                }

                Item {
                    visible: !!root.checkbox
                    Layout.fillWidth: true
                    Layout.preferredHeight: cbLoader.item ? cbLoader.item.implicitHeight : 0
                    Layout.topMargin: root._style.sectionSpacing
                    Loader {
                        id: cbLoader
                        active: !!root.checkbox
                        anchors.horizontalCenter: parent.horizontalCenter
                        sourceComponent: UICheckBox {
                            size: root.size
                            textColor: UIColors.colorTextSecondary
                            text: root.checkbox ? root.checkbox.label || "" : ""
                            checked: root.checkbox ? !!root.checkbox.checked : false
                        }
                    }
                }
            }
        }

        Loader {
            visible: active
            active: root._hasSpinner
            Layout.fillWidth: true
            Layout.fillHeight: true
            sourceComponent: Item {
                UISpinner {
                    anchors.centerIn: parent
                    size: UIControlSize.XL
                    text: root.spinnerText
                    progress: -1
                }
            }
        }

        RowLayout {
            id: _buttonRow
            visible: !root._hasSpinner
            spacing: root._style.buttonSpacing
            // Load 类型有最小高度约束，内容不足时增大 topMargin 补齐差值
            Layout.topMargin: root.msgType === UIMessageBoxType.Load
                ? Math.max(root._style.buttonTopMargin,
                    root.minHeight - root.topPadding - root.bottomPadding
                    - _body.implicitHeight - _buttonRow.implicitHeight)
                : root._style.buttonTopMargin
            Layout.alignment: Qt.AlignHCenter
            Repeater {
                model: root.buttons
                delegate: UIButton {
                    required property var modelData
                    text: modelData.text || ""
                    type: modelData.type !== undefined ? modelData.type : UIButtonType.Light
                    size: root._style.buttonSize
                    minWidth: root._style.buttonMinWidth
                    maxWidth: root.buttonMaxWidth
                    implicitHeight: root._style.buttonHeight
                    onClicked: root._dismiss(modelData.role || "accept")
                }
            }
        }
    }

    // closePolicy 触发的关闭(Esc / 点遮罩)→ 视为 cancel
    onClosed: {
        if (_suppressClosed) { _suppressClosed = false; return }
        root.sigDismissed("cancel", _checkboxState())
    }

    property bool _suppressClosed: false
    function _checkboxState() {
        return cbLoader.item ? cbLoader.item.checked : false
    }
    function _dismiss(role) {
        _suppressClosed = true
        root.sigDismissed(role, _checkboxState())
        close()
    }
    function _dismissByRole(role) {
        for (let i = 0; i < root.buttons.length; ++i) {
            if (root.buttons[i].role === role) { _dismiss(role); return }
        }
    }
}
