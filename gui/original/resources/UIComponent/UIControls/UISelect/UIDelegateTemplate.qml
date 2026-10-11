import QtQuick
import QtQuick.Templates as T
import UIComponent

// UIDelegateTemplate — UISelect 条目 delegate

T.ItemDelegate {
    id: root

    // ── DelegateModel 注入（由 ListView/DelegateModel 机制填充）──────
    required property var model
    required property int index
    required property string textRole

    property int size: UIControlSize.M
    readonly property var _style: UITheme.select.of(size)

    property bool isCurrent: ListView.isCurrentItem

    // 内部使用自读字段
    readonly property bool _isActive: hovered || ListView.isCurrentItem

    width:          ListView.view.width
    implicitHeight: _style.itemH

    hoverEnabled: true
    highlighted:  isCurrent

    text: {
        const modelData = model.modelData;
        if (!textRole) return String(modelData ?? model.display ?? "");
        // modelData?.[textRole]：JS 数组 / ListModel；model[textRole]：QAbstractItemModel role
        return String(modelData?.[textRole] ?? model[textRole] ?? "");
    }
    
    background: Rectangle {
        anchors {
            fill: parent
            margins: UISize.sizeXS
        }
        radius: _style.itemRadius
        color: root.hovered ? _style.itemBgHover : "transparent"
    }

    contentItem: Item {
        anchors {
            fill: parent
            margins: UISize.sizeXS
        }

        Image {
            id: _checkIcon
            anchors {
                verticalCenter: parent.verticalCenter
            }
            visible:    root.isCurrent
            width:      20
            height:     20
            sourceSize: Qt.size(_style.indicatorSize * 2, _style.indicatorSize * 2)
            source:     UITheme.isolationIcon("check.svg")
        }

        // 这里不用UIText的原因是UIText里面有HoverHandler
        Text {
            anchors {
                left:           _checkIcon.right
                right:          parent.right
                top:            parent.top
                bottom:         parent.bottom
            }

            leftPadding: UISize.sizeSM
            text:              root.text
            color:             root._isActive ? _style.text.hovered : _style.text.base
            verticalAlignment: Text.AlignVCenter
            elide:             Text.ElideRight

            UITooltip {
                visible: parent.truncated && root.hovered
                text: parent.text
            }
        }
    }
}
