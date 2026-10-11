import QtQuick.Window 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.3
import QtQuick 2.15
import Controls 1.0
import Config 1.0

Item {
    id: loadingContainer
    
    property var waitingPopupObj: null

    Connections {
        target: editorManager
    
        function onFetchMetaShotDataLoadingChanged(flag) {
            if (flag) {
                if (!waitingPopupObj) {
                    var component = Qt.createComponent("qrc:/Controls/WaitingPopup.qml")
                    if (component.status === Component.Ready) {
                        waitingPopupObj = component.createObject(loadingContainer)
                        waitingPopupObj.loadingText = qsTr("pccut_image_preview_tip")
                        waitingPopupObj.open()
                        ShortcutObserver.disableAllShortcut(true)
                    }
                }
            } else {
                if (waitingPopupObj) {
                    waitingPopupObj.close()
                    waitingPopupObj.destroy()
                    waitingPopupObj = null
                    ShortcutObserver.disableAllShortcut(false)
                }
            }
        }
    }
}