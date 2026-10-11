import QtQuick 2.15
import QtQuick.Controls 2.15
import Controls 1.0
import Config 1.0

Popup {
    id: popupPanel

    // ====== indicator 方向控制 ======
    // 可选值: "top" / "bottom" / "left" / "right"
    // ====== indicator 控制属性 ======
    property string indicatorEdge:    "bottom"   // top / bottom / left / right
    property bool   indicatorVisible: true
    property real   indicatorWidth:   20
    property real   indicatorHeight:  14
    property real   indicatorOffset:  0          // 沿边滑动：0=居中
    property real   indicatorGap:     -4          // 垂直贴边：0=紧贴，负=往框里咬

    property double radius: 12

    property string titleText: ""
    property string titleColor: Colors.color_141414
    property int    titlefontSize: 14

    property string descriptionText: ""
    property string descriptionColor: Colors.color_666666
    property int    descriptionfontSize: 12

    anchors.centerIn: parent
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    padding: 20
    implicitWidth: 248

    contentItem: Item {
        id: userCustomItem
        implicitHeight: contentColumn.implicitHeight

        Column {
            id: contentColumn
            width: parent.width
            spacing: 12

            Text {
                id: title
                visible: titleText.length > 0
                text: titleText
                horizontalAlignment: Text.AlignHCenter
                width: parent.width
                font.pixelSize: titlefontSize
                font.bold: true
                font.letterSpacing: 0
                color: titleColor
                lineHeight: 18
                lineHeightMode: Text.FixedHeight
                elide: Text.ElideRight
                maximumLineCount: 1
                wrapMode: Text.NoWrap
            }

            Text {
                id: bodyText
                visible: descriptionText.length > 0
                text: descriptionText
                width: parent.width
                font.pixelSize: descriptionfontSize
                font.weight: Font.Medium
                color: descriptionColor
                lineHeight: 16
                lineHeightMode: Text.FixedHeight
                wrapMode: Text.Wrap
            }
        }

        // ============ indicator ============
        Image {
            id: indicator
            visible: popupPanel.indicatorVisible
            width:  popupPanel.indicatorWidth
            height: popupPanel.indicatorHeight
            source: "qrc:/icons/region_guide_begin_bottom.svg"
            transformOrigin: Item.Center

            // 背景框四边（在 contentItem 局部坐标系）
            readonly property real bgLeft:   -popupPanel.leftPadding
            readonly property real bgRight:   parent.width  + popupPanel.rightPadding
            readonly property real bgTop:    -popupPanel.topPadding
            readonly property real bgBottom:  parent.height + popupPanel.bottomPadding
            readonly property real bgCX:      parent.width  / 2
            readonly property real bgCY:      parent.height / 2

            // 垂直于边方向，箭头“尖端深度”= height，半深度 = height/2
            readonly property real halfDepth: height / 2

            readonly property real targetCX: {
                switch (popupPanel.indicatorEdge) {
                case "left":  return bgLeft  - halfDepth - popupPanel.indicatorGap
                case "right": return bgRight + halfDepth + popupPanel.indicatorGap
                default:      return bgCX + popupPanel.indicatorOffset          // top/bottom 沿水平滑
                }
            }
            readonly property real targetCY: {
                switch (popupPanel.indicatorEdge) {
                case "top":    return bgTop    - halfDepth - popupPanel.indicatorGap
                case "bottom": return bgBottom + halfDepth + popupPanel.indicatorGap
                default:       return bgCY + popupPanel.indicatorOffset         // left/right 沿垂直滑
                }
            }

            x: targetCX - width / 2
            y: targetCY - height / 2

            rotation: {
                switch (popupPanel.indicatorEdge) {
                case "top":   return 180
                case "left":  return 90
                case "right": return -90
                default:      return 0
                }
            }
        }
    }

    // 背景矩形
    background: Rectangle {
        id: bg
        color: Colors.color_FFFFFF
        radius: popupPanel.radius
        // 阴影效果
        layer.enabled: true
    }
}
