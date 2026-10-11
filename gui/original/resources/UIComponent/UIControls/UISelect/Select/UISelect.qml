import UIComponent

// UISelect Select单列的默认实现 这里不和多列合并原因是不想使用Loader
UISelectTemplate {
    id: root

    popup: UISelectPopup {
        controlHeight: root.height
        controlWidth:  root.width
        delegateModel: root.delegateModel
        currentIndex:  root.currentIndex
        size: root.size
    }

    delegate: UIDelegateTemplate {
        textRole: root.textRole
        size: root.size
    }
}
