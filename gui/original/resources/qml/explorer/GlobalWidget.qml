import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.3

import Controls 1.0
import Config 1.0

import "../controller"

Item {
    id: root
    signal widgetSourceChanged(bool isShow)

    Loader {
        id: widgetLoader
        anchors.fill: parent
    }

    Loader {
        id: popupLoader
    }

    Loader {
        id: globalMaskLoader
    }

    Connections {
        target: globalSignal

        // 弹出消息提示窗口
        function onOpenMessagePopup(title, text) {
            if(popupLoader.sourceComponent !== messagePopupComponent) {
                popupLoader.sourceComponent = messagePopupComponent
            }

            popupLoader.item.setMessage(title, text)
            popupLoader.item.open()
        }

        function onShowGlobalMask() {
            globalMaskLoader.sourceComponent = globalMaskComponent
            globalMaskLoader.item.open()
        }

        function onHideGlobalMask() {
            if (!CommonUtils.isNull(globalMaskLoader.sourceComponent)) {
                globalMaskLoader.item.close()
                globalMaskLoader.sourceComponent = null
            }
        }
    }

    Component {
        id: messagePopupComponent
        LightWarningPopup {}
    }

    Component {
        id: globalMaskComponent
        Popup {
            id: popup
            padding: 0
            modal:true
            width: lightWindow.width
            height: lightWindow.height
            anchors.centerIn: Overlay.overlay
            background: Rectangle {
                radius: 10
                color: Colors.color_000000_50
            }
        }
    }

    Connections {
        target: widgetLoader

        function onSourceComponentChanged() {
            widgetSourceChanged(widgetLoader.sourceComponent !== null
                                && widgetLoader.item.visible === true)
            if (widgetLoader.sourceComponent !== null) {
                createConnections(widgetLoader.item)
            }
        }
    }

    // 动态绑定widgetLoader加载的页面的onVisibleChanged函数
    function createConnections(item) {
        let connections = connectionsComponent.createObject(item, {
                                                                "target": item
                                                            })
    }

    Component {
        id: connectionsComponent
        Connections {
            function onVisibleChanged() {
                widgetSourceChanged(target !== null && target.visible === true)
            }
        }
    }
}
