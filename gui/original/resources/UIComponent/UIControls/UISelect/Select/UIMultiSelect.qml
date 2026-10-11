import UIComponent

// UIMultiSelect — 多列级联下拉，数据由 SelectViewModel 驱动
UISelectTemplate {
    id: root

    required property SelectViewModel selectModel

    // 存储选择路径上的model
    property var _selectedPath: []

    displayText: {
        if (_selectedPath.length === 0) return "";
        // SelectViewModel 统一将显示字段归一化为 "label"
        for (let i = _selectedPath.length - 1; i>=0; --i) {
            const item = _selectedPath[i];
            if (item && item.label) {
                return String(item?.label);
            }
        }
        return "";
    }

    popup: UISelectMultiPopup {
        controlHeight:   root.height
        data:            root.selectModel?.data            ?? []
        colWidths:       root.selectModel?.columnWidths    ?? []
        colLabels:       root.selectModel?.columnLabels    ?? []
        columnDelegates: root.selectModel?.columnDelegates ?? []
        size: root.size

        onSigPathSelected: (path) => {
            root._selectedPath = path;
        }
    }
}
