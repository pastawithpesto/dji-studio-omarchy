import QtQuick
import QtQuick.Templates as T
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import UIComponent

// UIIconButton
//   layout: UIButtonLayout.Vertical  → tile 模式：icon 在上，label 在下
//   layout: UIButtonLayout.Horizontal → 内联模式：icon 左 + label 右
//   状态优先级：disabled > pressed×checked > hovered×checked > pressed > hovered > checked > normal
T.AbstractButton {
    id: root

    property int layout: UIButtonLayout.Horizontal
    property int size: UIControlSize.M
    property int type: UIButtonType.Dark

    property url    iconSource: ""
    property url    iconSourceHovered: ""
    property url    iconSourcePressed: ""
    property url    iconSourceDisabled: ""
    property url    iconSourceChecked: ""
    property url    iconSourceCheckedHovered: ""
    property url    iconSourceCheckedPressed: ""
    property string iconText: ""        // Unicode 字符占位（无 svg 时）
    property bool   showLabel: text.length > 0
    property string tooltipText: ""
    property bool   labelInside: true
    property int    contentAlignment: Qt.AlignHCenter

    readonly property var _style: UITheme.iconButton.of(size, layout, labelInside, type)

    // ===== 暴露的可覆盖口子 =====
    property int    iconSpacing: _style.iconSpacing

    property color bgColor:             _style.bg.base
    property color bgColorHovered:      _style.bg.hovered
    property color bgColorPressed:      _style.bg.pressed
    property color bgColorDisabled:     _style.bg.disabled
    property color bgColorChecked:      _style.bg.checked
    property color bgColorCheckedHovered: _style.bg.checkedHovered

    property color textColor:           _style.text.base
    property color textColorChecked:    _style.text.checked
    property color textColorDisabled:   _style.text.disabled

    property color borderColorChecked:  _style.border.checked

    property int tileSize:  _style.tileSize
    property int hHeight:   _style.hHeight
    property int iconSize: _style.iconSize
    property int iconWidth: iconSize
    property int iconHeight: iconSize
    property int paddingH: _style.paddingH
    property int iconRadius:_style.borderRadius
    property int minWidth:  _style.minWidth
    property int maxWidth:  0
    property real disabledOpacity: _style.opacity.disable

    property string bgImage:             _style.bgImage.base ? UITheme.isolationIcon(_style.bgImage.base) : ""
    property string bgImageHovered:      _style.bgImage.hovered ? UITheme.isolationIcon(_style.bgImage.hovered) : ""
    property string bgImagePressed:      _style.bgImage.pressed ? UITheme.isolationIcon(_style.bgImage.pressed) : ""
    property string bgImageDisabled:     _style.bgImage.disabled ? UITheme.isolationIcon(_style.bgImage.disabled) : ""
    property string bgImageChecked:      _style.bgImage.checked ? UITheme.isolationIcon(_style.bgImage.checked) : ""
    property string bgImageCheckedHovered: _style.bgImage.checkedHovered ? UITheme.isolationIcon(_style.bgImage.checkedHovered) : ""

    hoverEnabled: true
    checkable: false

    // T.AbstractButton 长按超过 pressAndHoldInterval 后 wasHeld=true，release 时跳过 toggle
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

    // ---- 纵向 tile 布局：icon 上 + label 下 ----
    property int vPaddingV: (tileSize - iconHeight
        - (showLabel ? iconSpacing + _style.fontSize : 0)) / 2

    UITooltip {
        visible: root.tooltipText.length > 0 && root.hovered
        text: root.tooltipText
    }

    // ===== resolvedXxx 状态机 =====

    // 只有在没自定义禁用背景色 且 没设置禁用态图标时才通过降低透明度表示禁用态
    readonly property bool _useDisableOpacity: Qt.colorEqual(bgColorDisabled, _style.bg.disabled) && iconSourceDisabled.toString() === ""

    readonly property color resolvedBgColor: {
        if (!enabled)            return _useDisableOpacity ? bgColor : bgColorDisabled
        if (pressed && checked)  return bgColorCheckedHovered
        if (hovered && checked)  return bgColorCheckedHovered
        if (pressed)             return bgColorPressed
        if (hovered)             return bgColorHovered
        if (checked)             return bgColorChecked
        return bgColor
    }
    readonly property color resolvedTextColor: {
        if (!enabled) return _useDisableOpacity ? textColor : textColorDisabled
        if (checked)  return textColorChecked
        return textColor
    }
    readonly property url resolvedIconSource: {
        if (!enabled)            return iconSourceDisabled.toString()       || iconSource
        if (pressed && checked)  return iconSourceCheckedPressed.toString() || iconSourceChecked.toString() || iconSource
        if (hovered && checked)  return iconSourceCheckedHovered.toString() || iconSourceChecked.toString() || iconSource
        if (pressed)             return iconSourcePressed.toString()        || iconSource
        if (hovered)             return iconSourceHovered.toString()        || iconSource
        if (checked)             return iconSourceChecked.toString()        || iconSource
        return iconSource
    }
    readonly property string resolvedBgImage: {
        if (!enabled)            return bgImageDisabled  || bgImage
        if (pressed && checked)  return bgImageChecked   || bgImage
        if (hovered && checked)  return bgImageCheckedHovered || bgImageChecked || bgImage
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
        width: root.layout === UIButtonLayout.Vertical ? root.tileSize : root.width
        height: root.layout === UIButtonLayout.Vertical ? root.tileSize : root.height
        Rectangle {
            anchors.fill: parent
            visible: !_bgImageLoader.active
            radius: root.iconRadius
            color: root.resolvedBgColor
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
                    radius: root.iconRadius
                    fillMode: Image.Stretch
                }
            }
        }
    }

    contentItem: Loader {
        clip: root.maxWidth > 0
        sourceComponent: root.layout === UIButtonLayout.Horizontal ? _hzComp : _vtComp
    }

    // ---- 横向布局：icon + label 内联 ----
    Component {
        id: _hzComp
        RowLayout {
            width: Math.min(implicitWidth, parent.width)
            height: parent.height
            anchors.left: root.contentAlignment === Qt.AlignLeft ? parent.left : undefined
            anchors.right: root.contentAlignment === Qt.AlignRight ? parent.right : undefined
            anchors.horizontalCenter: root.contentAlignment === Qt.AlignHCenter ? parent.horizontalCenter : undefined
            spacing: root.iconSpacing

            Item {
                Layout.preferredWidth:  root.iconWidth
                Layout.preferredHeight: root.iconHeight
                Layout.alignment: Qt.AlignVCenter
                visible: root.resolvedIconSource.toString().length > 0 || root.iconText.length > 0
                // 有 iconSource 时显示图片，否则显示 iconText
                Loader {
                    anchors.fill: parent
                    active: root.resolvedIconSource.toString().length > 0
                    sourceComponent: Component {
                        UIImage {
                            anchors.fill: parent
                            source: root.resolvedIconSource
                            sourceSize: Qt.size(width * 2, height * 2)
                        }
                    }
                }

                Loader {
                    anchors.fill: parent
                    active: root.resolvedIconSource.toString().length === 0 && root.iconText.length > 0
                    sourceComponent: Component {
                        UIText {
                            anchors.centerIn: parent
                            text: root.iconText
                            font.pixelSize: root.iconSize
                            color: root.resolvedTextColor
                        }
                    }
                }
            }
            UIText {
                Layout.fillWidth: true
                visible: root.showLabel
                text: root.text
                font.pixelSize: root._style.fontSize
                color: root.resolvedTextColor
                elide: Text.ElideRight
            }
        }
    }

    Component {
        id: _vtComp
        ColumnLayout {
            id: _vtContent
            width: Math.min(implicitWidth, parent.width)
            height: Math.min(implicitHeight, parent.height)
            anchors.left: root.contentAlignment === Qt.AlignLeft ? parent.left : undefined
            anchors.right: root.contentAlignment === Qt.AlignRight ? parent.right : undefined
            anchors.horizontalCenter: root.contentAlignment === Qt.AlignHCenter ? parent.horizontalCenter : undefined
            spacing: root.iconSpacing

            Item {
                Layout.topMargin: root.labelInside ? root.vPaddingV : 0
                Layout.preferredWidth:  root.tileSize
                Layout.preferredHeight: root.labelInside ? root.iconHeight : root.tileSize
                Layout.alignment: Qt.AlignHCenter
                Loader {
                    anchors.centerIn: parent
                    width: root.iconWidth
                    height: root.iconHeight
                    active: root.resolvedIconSource.toString().length > 0
                    sourceComponent: Component {
                        UIImage {
                            anchors.fill: parent
                            source: root.resolvedIconSource
                            sourceSize: Qt.size(width * 2, height * 2)
                        }
                    }
                }
                UIText {
                    anchors.centerIn: parent
                    visible: root.resolvedIconSource.toString().length === 0 && root.iconText.length > 0
                    text: root.iconText
                    font.pixelSize: root._style.fontSize
                    color: root.resolvedTextColor
                }
            }
            UIText {
                Layout.alignment: Qt.AlignHCenter
                Layout.bottomMargin: root.labelInside ? root.vPaddingV : 0
                Layout.maximumWidth: root.labelInside ? root.tileSize - 2 * root.paddingH : -1
                visible: root.showLabel
                text: root.text
                font.pixelSize: root._style.fontSize
                color: root.resolvedTextColor
                elide: Text.ElideRight
            }
        }
    }

    leftPadding:   layout === UIButtonLayout.Horizontal && type !== UIButtonType.IconOnly ? paddingH : 0
    rightPadding:  layout === UIButtonLayout.Horizontal && type !== UIButtonType.IconOnly ? paddingH : 0
    topPadding:    0
    bottomPadding: 0
    leftInset:  layout === UIButtonLayout.Vertical ? (width - tileSize) / 2 : 0
    rightInset: layout === UIButtonLayout.Vertical ? (width - tileSize) / 2 : 0

    implicitWidth: {
        var w
        if (layout === UIButtonLayout.Horizontal) {
            w = (type === UIButtonType.IconOnly
                ? iconWidth
                : Math.max(minWidth, contentItem.implicitWidth + leftPadding + rightPadding))
        } else {
            w = !labelInside
                ? Math.max(tileSize, contentItem.implicitWidth)
                : tileSize
        }
        return maxWidth > 0 ? Math.min(w, maxWidth) : w
    }
    implicitHeight: layout === UIButtonLayout.Horizontal
                  ? (type === UIButtonType.IconOnly ? iconHeight : hHeight)
                  : labelInside
                      ? tileSize
                      : showLabel
                          ? tileSize + iconSpacing + _style.fontSize
                          : tileSize
}
