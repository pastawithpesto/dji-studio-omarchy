import QtQuick 2.15
import QtQuick.Controls 2.15
import Config 1.0

SplitView {
    id: root
    // 暴露两个属性，允许外部自定义这两个视图
    property alias leftView: leftLoader.sourceComponent
    property alias rightView: rightLoader.sourceComponent

    property alias leftViewLoader: leftLoader
    property alias rightViewLoader: rightLoader

    property real lastAxisPos: 0 // 当前页面的分割线位置
    property real initSplitPosition: 120  // 切换到当前tab时分割线的初始位置, 主要是为了保证切换tab时每个tab的分割线位置保持一致

    signal leftPaneClicked()

    handle: Rectangle {
        id: handleRec
        implicitWidth: 1
        color: Colors.color_141414
        containmentMask: Item {
            x: -4
            width: 9
            height: root.height
        }

    }
    orientation: Qt.Horizontal

    // 内部使用两个Loader来加载左右视图
    Rectangle {
        id: leftContainer
        SplitView.preferredWidth: initSplitPosition
        SplitView.minimumWidth: 122
        SplitView.maximumWidth: 140
        color: Colors.color_content_area_background

        Loader {
            id: leftLoader
            anchors.fill: parent
            // asynchronous: editorABConfig.asyncLoadComponent
            active: editorABConfig.asyncLoadComponent === false?true:false
        }

        MouseArea {
            anchors.fill: parent
            onPressed: (mouse) => {
                root.leftPaneClicked();
                mouse.accepted = false;
            }
        }
        onWidthChanged: {
            lastAxisPos = leftContainer.width;
        }
    }

    Rectangle {
        id: rightContainer
        // 这里最小也不能小于287否则素材列表一行显示不了两个素材icon
        SplitView.minimumWidth: 290
        color: Colors.color_content_area_background

        Loader {
            id: rightLoader
            anchors.fill: parent
            // asynchronous: editorABConfig.asyncLoadComponent
            active: editorABConfig.asyncLoadComponent === false?true:false
        }
    }

}
