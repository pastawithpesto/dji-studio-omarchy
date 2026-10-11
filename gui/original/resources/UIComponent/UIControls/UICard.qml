import QtQuick
import QtQuick.Layouts
import UIComponent

// UICard
//   素材卡片：cover + 4 角 slot + 可选 title/subtitle。
//   layout: UICardLayout.Vertical  → 纵向：cover 在上 + 文字在下（默认）
//   layout: UICardLayout.Horizontal → 横向：cover 在左 + 文字在右 + rightSlot 最右
//   每个角 slot 支持 hover 显隐 (xxxShowOnHover)。
Rectangle {
    id: root

    property int size: UIControlSize.M
    property int layout: UICardLayout.Vertical

    readonly property var _style: UITheme.card.of(size, layout)

    // ---- cover + 4 角 slot ----
    property string title: ""
    property string subtitle: ""
    property url    coverSource: ""
    property real   coverSize:   _style.coverSize
    property real   coverWidth:  coverSize
    property real   coverHeight: coverSize
    property real   coverRadius: _style.coverRadius
    property real   coverBorderWidth: 0
    property real   coverBorderWidthHovered: 0
    property color  coverBorderColor: _style.coverBorderColor
    property int    borderRadius: _style.borderRadius
    property real   slotMargin: _style.slotMargin
    property bool   topLeftShowOnHover: false
    property bool   topRightShowOnHover: false
    property bool   bottomLeftShowOnHover: false
    property bool   bottomRightShowOnHover: false
    property bool   centerShowOnHover: false
    readonly property bool hovered: hoverHandler.hovered
    property alias  topLeftSlot:     tlSlot.data
    property alias  topRightSlot:    trSlot.data
    property alias  bottomLeftSlot:  blSlot.data
    property alias  bottomRightSlot: brSlot.data
    property alias  centerSlot:      cSlot.data

    // ---- 横向模式 rightSlot ----
    property alias  rightSlot: rSlot.data
    property int    rightSlotAlignment: Qt.AlignVCenter

    HoverHandler { id: hoverHandler }

    color: (root.layout === UICardLayout.Horizontal && root.hovered) ? _style.bgHovered : _style.bg
    radius: root.borderRadius
    implicitWidth: coverWidth
    implicitHeight: root.layout === UICardLayout.Horizontal
                    ? hLayout.implicitHeight + 2 * _style.padding
                    : vLayout.implicitHeight + 2 * _style.padding

    clip: true

    // ==================== 纵向布局 ====================
    ColumnLayout {
        id: vLayout
        anchors.fill: parent
        anchors.margins: root._style.padding
        spacing: root._style.spacing
        visible: root.layout === UICardLayout.Vertical

        Item {
            id: _vCoverItem
            Layout.preferredWidth: root.coverWidth
            Layout.preferredHeight: root.coverHeight

            UIImage {
                id: vCover
                radius: root.coverRadius
                borderWidth: root.hovered ? root.coverBorderWidthHovered : root.coverBorderWidth
                borderColor: root.coverBorderColor
                anchors.fill: parent
                source: root.coverSource
                fillMode: Image.PreserveAspectCrop
            }

            Row {
                id: tlSlot
                spacing: root._style.slotSpacing
                anchors.left: parent.left;   anchors.top: parent.top
                anchors.leftMargin: root.slotMargin; anchors.topMargin: root.slotMargin
                visible: tlSlot.children.length > 0 && (!root.topLeftShowOnHover || root.hovered)
            }
            Row {
                id: trSlot
                spacing: root._style.slotSpacing
                layoutDirection: Qt.RightToLeft
                anchors.right: parent.right; anchors.top: parent.top
                anchors.rightMargin: root.slotMargin; anchors.topMargin: root.slotMargin
                visible: trSlot.children.length > 0 && (!root.topRightShowOnHover || root.hovered)
            }
            Row {
                id: blSlot
                spacing: root._style.slotSpacing
                anchors.left: parent.left;   anchors.bottom: parent.bottom
                anchors.leftMargin: root.slotMargin; anchors.bottomMargin: root.slotMargin
                visible: blSlot.children.length > 0 && (!root.bottomLeftShowOnHover || root.hovered)
            }
            Row {
                id: brSlot
                spacing: root._style.slotSpacing
                layoutDirection: Qt.RightToLeft
                anchors.right: parent.right; anchors.bottom: parent.bottom
                anchors.rightMargin: root.slotMargin; anchors.bottomMargin: root.slotMargin
                visible: brSlot.children.length > 0 && (!root.bottomRightShowOnHover || root.hovered)
            }
        }
    }

    // ==================== 横向布局 ====================
    RowLayout {
        id: hLayout
        anchors.fill: parent
        anchors.margins: root._style.padding
        spacing: root._style.spacing
        visible: root.layout === UICardLayout.Horizontal

        Item {
            id: _hCoverItem
            Layout.preferredWidth: root.coverWidth
            Layout.preferredHeight: root.coverHeight
            Layout.alignment: Qt.AlignVCenter

            UIImage {
                id: hCover
                radius: root.coverRadius
                borderWidth: root.hovered ? root.coverBorderWidthHovered : root.coverBorderWidth
                borderColor: root.coverBorderColor
                source: root.coverSource
                fillMode: Image.PreserveAspectCrop
                anchors.fill: parent
            }

            Row {
                id: cSlot
                spacing: root._style.slotSpacing
                anchors.centerIn: parent
                visible: !root.centerShowOnHover || root.hovered
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: root._style.titleSpacing

            UIText {
                visible: root.title.length > 0
                text: root.title
                type: UITextType.Primary
                size: UIControlSize.M
                Layout.fillWidth: true
                elide: Text.ElideMiddle
            }
            UIText {
                visible: root.subtitle.length > 0
                text: root.subtitle
                type: UITextType.Secondary
                size: UIControlSize.S
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
        }

        Row {
            id: rSlot
            spacing: root._style.slotSpacing
            Layout.alignment: root.rightSlotAlignment
            Layout.rightMargin: 12
        }
    }
}
