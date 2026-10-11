import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import UIComponent

// UIDialog
//   弹层容器，支持两种布局模式（layout 属性）：
//
//   UIDialogLayout.Custom（默认）：
//     仅提供 Header（标题 + 关闭按钮）+ Divider，其余区域通过 default property body
//     由用户自由填充。适合复杂自定义布局。
//
//   UIDialogLayout.Structured：
//     提供结构化布局：leftColumn / rightColumn（带滚动条的双列内容区）
//     + bottomLeft / bottomRight（底部操作槽）。
//   ┌─────────────────────────────┐
//   │  Header (title + close btn) │
//   ├─────────────────────────────┤
//   │                             │
//   │  leftColumn │ rightColumn   │  ← 中间，可滚动
//   │                             │
//   ├─────────────────────────────┤
//   │  bottomLeft    bottomRight  │  ← 底部区域
//   └─────────────────────────────┘
//
//   通用属性：
//     title / iconSource              标题文字和图标
//     closeOnMaskClick                点遮罩是否关闭，默认 false
//     paddingH                        内容区水平内边距（可覆盖）
//     contentTopMargin / contentBottomMargin  内容区上下边距（可覆盖）
//
//   Structured 模式专属：
//     leftColumnRatio / rightColumnRatio    两列宽度比，默认 1 : 1.564
//     leftColumnWidth / rightColumnWidth    固定列宽（非 0 时覆盖 ratio）
//
//   关闭按钮按平台自适应（mac 居左 / win 居右），支持 Gallery 平台切换预览。
//   closePolicy 触发的关闭 (Esc / 点遮罩) 统一发 sigClosed。

Popup {
    id: root

    property int size: UIControlSize.M
    property int layout: UIDialogLayout.Custom
    property string title: ""
    property string iconSource: ""
    property int    titleAlignment: Qt.AlignHCenter
    property bool   closeOnMaskClick: false
    property real   leftColumnRatio: 1
    property real   rightColumnRatio: 1.564
    property int    leftColumnWidth: 0
    property int    rightColumnWidth: 0

    property alias leftColumn:   leftSlot.data
    property alias rightColumn:  rightSlot.data
    property alias bottomLeft:   blSlot.data
    property alias bottomCenter: bcSlot.data
    property alias bottomRight:  brSlot.data
    default property alias body: _bodySlot.data

    signal sigClosed()
    signal leftColumnReachedBottom()
    signal rightColumnReachedBottom()

    readonly property var _style: UITheme.dialog.of(size)

    property int    contentTopMargin: _style.contentTopMargin
    property int    contentBottomMargin: _style.contentBottomMargin
    property int    paddingH: _style.paddingH
    property int    contentSpacing: _style.contentSpacing
    property int    footerSpacing: _style.footerSpacing
    property int    footerBottomMargin: _style.footerBottomMargin

    // leftColumn 和 rightColumn 的间距
    property int    columnSpacing: _style.columnSpacing

    property color bgColor:            _style.bg.base
    property color textColor:          _style.text.base
    property color textSecondaryColor: _style.textSecondary.base
    property color maskColor:          _style.maskColor
    property color borderColor:        _style.borderColor

    modal: true
    focus: true
    parent: Overlay.overlay
    anchors.centerIn: Overlay.overlay
    closePolicy: closeOnMaskClick
                 ? (Popup.CloseOnEscape | Popup.CloseOnPressOutside)
                 : Popup.CloseOnEscape
    padding: 0

    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 0 }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 0 }
    }

    Overlay.modal: Rectangle { color: root.maskColor }

    background: Rectangle {
        color: root.bgColor
        radius: root._style.borderRadius
        border.width: root._style.borderWidth
        border.color: root.borderColor
    }

    Component {
        id: _closeButtonComp
        UIButton {
            type: UIButtonType.IconOnly
            iconSource:        UITheme.systemIcon("Icon_Close_Normal.svg")
            iconSourceHovered: UITheme.systemIcon("Icon_Close_Hover.svg")
            iconSourcePressed: UITheme.systemIcon("Icon_Close_Press.svg")
            iconSize: root._style.closeButtonSize
            onClicked: { root.sigClosed(); root.close() }
        }
    }

    contentItem: Item {

        Column {
            id: _headerColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top

            Item {
                id: _header
                width: parent.width
                height: root._style.headerHeight

                Row {
                    spacing: 4
                    anchors.centerIn: parent

                    UIIcon {
                        visible: root.iconSource !== ""
                        source: root.iconSource
                        iconSize: root._style.titleFontSize
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    UIText {
                        text: root.title
                        type: UITextType.Emphasize
                        color: root.textColor
                        font.pixelSize: root._style.titleFontSize
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Loader {
                    active: !UITheme.isWindows
                    sourceComponent: _closeButtonComp
                    anchors.left: parent.left
                    anchors.leftMargin: root._style.closeButtonMarginH
                    anchors.verticalCenter: parent.verticalCenter
                }

                Loader {
                    active: UITheme.isWindows
                    sourceComponent: _closeButtonComp
                    anchors.right: parent.right
                    anchors.rightMargin: root._style.closeButtonMarginH
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            UIDivider {
                width: parent.width
                color: root.borderColor
            }
        }

        // Custom 模式：用户自由填充
        Item {
            id: _bodySlot
            visible: root.layout === UIDialogLayout.Custom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: _headerColumn.bottom
            anchors.bottom: parent.bottom
        }

        // Structured 模式：左右列
        RowLayout {
            visible: root.layout === UIDialogLayout.Structured
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: _headerColumn.bottom
            anchors.bottom: parent.bottom
            anchors.leftMargin:  root.paddingH
            anchors.rightMargin: root._style.scrollbarRightMargin
            anchors.topMargin:   root.contentTopMargin
            anchors.bottomMargin: root.contentBottomMargin
            spacing: root.columnSpacing

            Flickable {
                id: leftScroll
                visible: leftSlot.children.length > 0
                Layout.fillWidth: root.leftColumnWidth === 0
                Layout.preferredWidth: root.leftColumnWidth > 0 ? root.leftColumnWidth : root.leftColumnRatio
                Layout.fillHeight: true
                clip: true
                contentWidth: width
                contentHeight: leftSlot.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: leftSlot
                    property int _scrollbarReserve: leftScroll.contentHeight > leftScroll.height ? UISize.scrollbarThickness : 0
                    width: leftScroll.width - _scrollbarReserve
                           - (rightScroll.visible ? 0 : (root.paddingH - root._style.scrollbarRightMargin - _scrollbarReserve))
                    spacing: root.contentSpacing
                }

                ScrollBar.vertical: UIScrollBar {
                    policy: ScrollBar.AlwaysOn
                    onReachedBottom: root.leftColumnReachedBottom()
                }
            }

            Flickable {
                id: rightScroll
                visible: rightSlot.children.length > 0
                Layout.fillWidth: root.rightColumnWidth === 0
                Layout.preferredWidth: root.rightColumnWidth > 0 ? root.rightColumnWidth : root.rightColumnRatio
                Layout.fillHeight: true
                clip: true
                contentWidth: width
                contentHeight: rightSlot.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: rightSlot
                    property int _scrollbarReserve: rightScroll.contentHeight > rightScroll.height ? UISize.scrollbarThickness : 0
                    width: rightScroll.width - _scrollbarReserve
                           - (root.paddingH - root._style.scrollbarRightMargin - _scrollbarReserve)
                    spacing: root.contentSpacing
                }

                ScrollBar.vertical: UIScrollBar {
                    policy: ScrollBar.AlwaysOn
                    onReachedBottom: root.rightColumnReachedBottom()
                }
            }
        }

        // Structured 模式：底部按钮
        RowLayout {
            visible: root.layout === UIDialogLayout.Structured
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin:  root.paddingH
            anchors.rightMargin: root.paddingH
            anchors.bottomMargin: root.footerBottomMargin
            spacing: root.footerSpacing

            Row {
                id: blSlot
                spacing: root.footerSpacing
            }

            Item { Layout.fillWidth: true }

            Row {
                id: bcSlot
                spacing: root.footerSpacing
            }

            Item { Layout.fillWidth: true }

            Row {
                id: brSlot
                spacing: root.footerSpacing
                layoutDirection: Qt.RightToLeft
            }
        }
    }

    onClosed: root.sigClosed()
}
