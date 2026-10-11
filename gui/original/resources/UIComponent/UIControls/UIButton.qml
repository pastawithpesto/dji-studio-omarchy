import QtQuick
import QtQuick.Templates as T
import Qt5Compat.GraphicalEffects
import UIComponent

// UIButton —— 范式参考实现，其他 UIXxx 按此结构复制。
// 设计契约 / 设计思路：见 docs/COMPONENT_SPEC.md（命名 / 状态 / resolvedXxx / ComponentToken）。
T.Button {
    id: root

    // ===== 变体 =====
    property int type: UIButtonType.White
    property int size: UIControlSize.M
    property bool loading: false

    hoverEnabled: true

    // T.Button 长按超过 pressAndHoldInterval 后 wasHeld=true，release 时跳过 toggle
    property bool _checkedOnPress: false
    onPressed: _checkedOnPress = checked
    onReleased: {
        if (checkable && hovered) {
            let expected = _checkedOnPress
            Qt.callLater(function() {
                if (root.checkable && root.checked === expected) {
                    root.checked = !root.checked
                }
            })
        }
    }

    // 单点绑定 ComponentToken：注意是 .of(...)，不是直接 UITheme.button(...)，
    // 否则 variant 切换时绑定不会重算（QML 不追 Q_INVOKABLE，详见 COMPONENT_SPEC.md §ComponentToken）
    readonly property var _style: UITheme.button.of(size, type)

    // ===== 暴露 9 态扁平字段：业务可逐项覆盖 (UIButton { bgColorChecked: "red" }) =====
    property color bgColor:                _style.bg.base
    property color bgColorHovered:         _style.bg.hovered
    property color bgColorPressed:         _style.bg.pressed
    property color bgColorDisabled:        _style.bg.disabled
    property color bgColorChecked:         _style.bg.checked
    property color bgColorCheckedHovered:  _style.bg.checkedHovered
    property color bgColorCheckedPressed:  _style.bg.checkedPressed
    property color bgColorLoading:         _style.bg.loading
    property color bgColorFocused:         _style.bg.focused

    property color textColor:                _style.text.base
    property color textColorHovered:         _style.text.hovered
    property color textColorPressed:         _style.text.pressed
    property color textColorDisabled:        _style.text.disabled
    property color textColorChecked:         _style.text.checked
    property color textColorCheckedHovered:  _style.text.checkedHovered
    property color textColorCheckedPressed:  _style.text.checkedPressed
    property color textColorLoading:         _style.text.loading
    property color textColorFocused:         _style.text.focused

    property color borderColor:              _style.border.base
    property color borderColorHovered:       _style.border.hovered
    property color borderColorPressed:       _style.border.pressed
    property color borderColorDisabled:      _style.border.disabled
    property color borderColorChecked:       _style.border.checked
    property color borderColorCheckedHovered:_style.border.checkedHovered
    property color borderColorCheckedPressed:_style.border.checkedPressed
    property color borderColorLoading:       _style.border.loading
    property color borderColorFocused:       _style.border.focused
    property int   borderWidth:              _style.borderWidth
    property int   borderRadius:             _style.borderRadius

    property string iconSource:                _style.icon.base
    property string iconSourceHovered:         _style.icon.hovered
    property string iconSourcePressed:         _style.icon.pressed
    property string iconSourceDisabled:        _style.icon.disabled
    property string iconSourceChecked:         _style.icon.checked
    property string iconSourceCheckedHovered:  _style.icon.checkedHovered
    property string iconSourceCheckedPressed:  _style.icon.checkedPressed
    property string iconSourceLoading:         _style.icon.loading
    property string iconSourceFocused:         _style.icon.focused
    property int    iconSize:                  _style.iconSize
    property int    iconWidth:                 iconSize
    property int    iconHeight:                iconSize
    property int    minWidth:                  _style.minWidth
    property int    maxWidth:                  0
    property real   disabledOpacity:           _style.opacity.disable

    property string bgImage:             _style.bgImage.base ? UITheme.isolationIcon(_style.bgImage.base) : ""
    property string bgImageHovered:      _style.bgImage.hovered ? UITheme.isolationIcon(_style.bgImage.hovered) : ""
    property string bgImagePressed:      _style.bgImage.pressed ? UITheme.isolationIcon(_style.bgImage.pressed) : ""
    property string bgImageDisabled:     _style.bgImage.disabled ? UITheme.isolationIcon(_style.bgImage.disabled) : ""
    property string bgImageChecked:      _style.bgImage.checked ? UITheme.isolationIcon(_style.bgImage.checked) : ""

    // ===== 尺寸 =====
    readonly property bool _isIconOnly: type === UIButtonType.IconOnly
    implicitHeight: _isIconOnly ? iconHeight : _style.height
    implicitWidth: {
        if (_isIconOnly) return iconWidth
        var w = Math.max(minWidth, implicitContentWidth + leftPadding + rightPadding)
        return maxWidth > 0 ? Math.min(w, maxWidth) : w
    }
    leftPadding: _isIconOnly ? 0 : _style.paddingH
    rightPadding: _isIconOnly ? 0 : _style.paddingH
    topPadding: 0
    bottomPadding: 0
    font.pixelSize: _style.fontSize
    font.weight: _style.fontWeight

    // 状态优先级: disabled > loading > pressed×checked > hovered×checked > pressed > hovered > focused > checked > normal

    // 只有在没自定义禁用背景色 且 没设置禁用态图标时才通过降低透明度表示禁用态
    readonly property bool _useDisableOpacity: Qt.colorEqual(bgColorDisabled, _style.bg.disabled) && iconSourceDisabled === ""

    readonly property color resolvedBgColor: {
        if (!enabled)            return _useDisableOpacity ? bgColor : bgColorDisabled
        if (loading)             return bgColorLoading
        if (pressed && checked)  return bgColorCheckedPressed
        if (hovered && checked)  return bgColorCheckedHovered
        if (pressed)             return bgColorPressed
        if (hovered)             return bgColorHovered
        if (checked)             return bgColorChecked
        return bgColor
    }
    readonly property color resolvedTextColor: {
        if (!enabled)            return _useDisableOpacity ? textColor : textColorDisabled
        if (loading)             return textColorLoading
        if (pressed && checked)  return textColorCheckedPressed
        if (hovered && checked)  return textColorCheckedHovered
        if (pressed)             return textColorPressed
        if (hovered)             return textColorHovered
        if (checked)             return textColorChecked
        return textColor
    }
    readonly property color resolvedBorderColor: {
        if (!enabled)            return _useDisableOpacity ? borderColor : borderColorDisabled
        if (loading)             return borderColorLoading
        if (pressed && checked)  return borderColorCheckedPressed
        if (hovered && checked)  return borderColorCheckedHovered
        if (pressed)             return borderColorPressed
        if (hovered)             return borderColorHovered
        if (checked)             return borderColorChecked
        return borderColor
    }
    readonly property string resolvedIconSource: {
        if (!enabled)            return iconSourceDisabled            || iconSource
        if (loading)             return iconSourceLoading             || iconSource
        if (pressed && checked)  return iconSourceCheckedPressed      || iconSourceChecked || iconSource
        if (hovered && checked)  return iconSourceCheckedHovered      || iconSourceChecked || iconSource
        if (pressed)             return iconSourcePressed             || iconSource
        if (hovered)             return iconSourceHovered             || iconSource
        if (checked)             return iconSourceChecked             || iconSource
        return iconSource
    }
    readonly property string resolvedBgImage: {
        if (!enabled)            return bgImageDisabled  || bgImage
        if (pressed && checked)  return bgImageChecked   || bgImage
        if (hovered && checked)  return bgImageChecked   || bgImage
        if (pressed)             return bgImagePressed   || bgImage
        if (hovered)             return bgImageHovered   || bgImage
        if (checked)             return bgImageChecked   || bgImage
        return bgImage
    }

    layer.enabled: !enabled && _useDisableOpacity
    layer.effect: OpacityMask {
        maskSource: Rectangle {
            width: root.width
            height: root.height
            color: Qt.rgba(1, 1, 1, root.disabledOpacity)
        }
    }

    background: Item {
        Rectangle {
            anchors.fill: parent
            visible: !_bgImageLoader.active
            radius: root.borderRadius
            color: root.resolvedBgColor
            border.width: root._isIconOnly ? 0 : root.borderWidth
            border.color: root.resolvedBorderColor
        }
        Loader {
            id: _bgImageLoader
            anchors.fill: parent
            active: root.resolvedBgImage !== ""
            sourceComponent: Component {
                UIImage {
                    anchors.fill: parent
                    source: root.resolvedBgImage
                    sourceSize: Qt.size(width * 2, height * 2)
                    radius: root.borderRadius
                    fillMode: Image.Stretch
                }
            }
        }
    }

    contentItem: Item {
        implicitWidth:  row.implicitWidth
        implicitHeight: row.implicitHeight
        clip: root.maxWidth > 0
        Row {
            id: row
            anchors.centerIn: parent
            width: Math.min(implicitWidth, parent.width)
            spacing: UISize.sizeXS
            // Loader 而非 visible:false：loading=false 时整体释放（QML_GUIDELINES §8.5）
            Loader {
                active: root.loading
                anchors.verticalCenter: parent.verticalCenter
                sourceComponent: Component {
                    UISpinner {
                        size: UIControlSize.M
                        trackColor: root.resolvedTextColor
                    }
                }
            }
            // 业务 icon: 有 icon 资源且非 loading 时才创建实例
            Loader {
                active: !root.loading && root.resolvedIconSource !== ""
                anchors.verticalCenter: parent.verticalCenter
                sourceComponent: Component {
                    Image {
                        source: root.resolvedIconSource
                        width: root.iconWidth
                        height: root.iconHeight
                        sourceSize.width: root.iconWidth * 2
                        sourceSize.height: root.iconHeight * 2
                    }
                }
            }
            Loader {
                active: root.text.length > 0
                anchors.verticalCenter: parent.verticalCenter
                sourceComponent: Component {
                    UIText {
                        width: root.maxWidth > 0 ? Math.min(implicitWidth, root.maxWidth - root.leftPadding - root.rightPadding - (root.resolvedIconSource !== "" ? root.iconWidth + UISize.sizeXS : 0)) : implicitWidth
                        text: root.text
                        font: root.font
                        color: root.resolvedTextColor
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
