import QtQuick
import QtQuick.Controls
import QtQuick.Templates as T
import UIComponent

// UISelectMultiPopup — N 列级联弹窗

T.Popup {
    id: root

    required property real controlHeight // ComboBox 自身高度，用于 y 定位
    required property var  data          // selectModel.data

    property int size: UIControlSize.M
    readonly property var _style: UITheme.select.of(size)


    property var  colWidths:       []    // 每列宽度数组；元素缺失时回退到 defaultColWidth
    property var  colLabels:       []    // 可选列头文字数组
    property string textRole:    "label" // 条目显示字段，与 SelectViewModel.textRole 对应
    property var  columnDelegates: []    // 每列自定义 delegate；null/越界时用内置样式
    property int maxHeight:    _style.popMaxH
    property int headerHeight: _style.headerHeight
    property int borderWidth:  _style.borderWidth
    property int defaultColWidth: _style.colWidth
    signal sigPathSelected(var path)

    property var _columnData: []
    property var _activeIdx:  []
    property var _selectedIdx: []  // 持久化已选路径，打开时用于恢复状态

    // 从 _selectedIdx 重建 _columnData 和 _activeIdx
    function _rebuildFromSelected() {
        const colData = [root.data]
        const idx     = root._selectedIdx.slice()
        for (let i = 0; i < idx.length; i++) {
            const item = colData[i]?.[idx[i]]
            if (item?.children?.length > 0) colData.push(item.children)
            else break
        }
        root._columnData = colData
        root._activeIdx  = idx
    }

    readonly property int   _dividerW:       borderWidth
    readonly property color _divColor:       _style.popBorder
    readonly property color _bgColor:        _style.popBg
    
    // 取第 idx 列宽度，空数组或越界时回退到 defaultColWidth
    function _getColWidth(idx) {
        if (!colWidths || colWidths.length === 0) return defaultColWidth
        return (idx < colWidths.length) ? colWidths[idx] : defaultColWidth
    }

    Component {
        id: _defaultColDelegate
        UIMultiDelegateTemplate {
            textRole: root.textRole
        }
    }

    // 根据列下标选择 delegate：有自定义用自定义，否则用内置默认
    function _colDelegate(colIdx) {
        const d = columnDelegates;
        return (d && colIdx < d.length && d[colIdx]) ? d[colIdx] : _defaultColDelegate;
    }

    // hover 某列某行：更新激活路径，展开或裁剪子列
    function _onHover(colIdx, itemIdx, hasChildren, children) {
        const newIdx = _activeIdx.slice(0, colIdx)
        newIdx.push(itemIdx)
        _activeIdx = newIdx

        const newData = _columnData.slice(0, colIdx + 1)
        if (hasChildren) newData.push(children)
        _columnData = newData
    }

    // 点击叶子节点：还原祖先路径，追加当前节点后发出信号
    function _onSelect(colIdx, itemData) {
        const path = _activeIdx.slice(0, colIdx)
                               .map((ai, c) => _columnData[c]?.[ai])
                               .filter(Boolean)
        path.push(itemData)
        root._selectedIdx = root._activeIdx.slice(0, colIdx + 1)
        sigPathSelected(path)
        close()
    }

    y:       controlHeight + _style.popOffsetY
    padding: 0

    width: {
        let total = 0
        for (let i = 0; i < _columnData.length; ++i)
            total += _getColWidth(i)
        return total + Math.max(_columnData.length - 1, 0) * _dividerW
    }

    height: maxHeight
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

    onAboutToShow: _rebuildFromSelected()

    onClosed: {
        root._columnData = [root.data]
        root._activeIdx  = []
    }

    background: Rectangle {
        color:        root._bgColor
        radius:       UISize.borderRadius
        border.width: root.borderWidth
        border.color: root._divColor
    }

    contentItem: Row {
        clip:    true
        spacing: 0

        Repeater {
            id: _colRepeater
            model: root._columnData.length

            Row {
                id: _colRow
                required property int index // repeater 注入

                readonly property int    colIdx:   _colRow.index
                readonly property var    colItems: root._columnData[colIdx] ?? []
                readonly property string colLabel: root.colLabels?.[colIdx] ?? ""

                height: root.height
                width:  root._getColWidth(colIdx) + (colIdx < _colRepeater.count - 1 ? root._dividerW : 0)

                Item {
                    width:  root._getColWidth(colIdx)
                    height: parent.height

                    // 列头（有 label 时显示）
                    Item {
                        id: _colHeader
                        width:   parent.width
                        height:  _colRow.colLabel ? root.headerHeight : 0
                        visible: !!_colRow.colLabel

                        Text {
                            anchors {
                                fill:       parent
                                leftMargin: UISize.sizeSM
                            }
                            text:              _colRow.colLabel
                            color:             _style.headerTextColor
                            verticalAlignment: Text.AlignVCenter
                            elide:             Text.ElideRight
                        }

                        Rectangle {
                            anchors {
                                left:   parent.left
                                right:  parent.right
                                bottom: parent.bottom
                            }
                            height: root.borderWidth
                            color:  root._divColor
                        }
                    }

                    // 选项列表
                    ListView {
                        id:   colList
                        anchors {
                            top:    _colHeader.bottom
                            left:   parent.left
                            right:  parent.right
                            bottom: parent.bottom
                        }

                        clip:            true
                        currentIndex:    root._activeIdx[colIdx] ?? -1
                        model:           _colRow.colItems
                        boundsBehavior:  Flickable.StopAtBounds
                        highlightMoveDuration: 0
                        ScrollBar.vertical: UIScrollBar { policy: ScrollBar.AsNeeded }

                        delegate: root._colDelegate(colIdx)

                        Connections {
                            target: colList.currentItem

                            function onItemHovered(idx) {
                                const item = _colRow.colItems[idx]
                                root._onHover(_colRow.colIdx, idx,
                                              !!(item?.children?.length > 0),
                                              item?.children ?? [])
                            }

                            function onItemClicked(idx) {
                                const item = _colRow.colItems[idx]
                                if (!(item?.children?.length > 0))
                                    root._onSelect(_colRow.colIdx, item)
                            }
                        }
                    }
                }

                // 列间分割线（最后一列不显示）
                Rectangle {
                    visible: colIdx < _colRepeater.count - 1
                    width:   root._dividerW
                    height:  parent.height
                    color:   root._divColor
                }
            }
        }
    }

    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 300 }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 300 }
    }
}
