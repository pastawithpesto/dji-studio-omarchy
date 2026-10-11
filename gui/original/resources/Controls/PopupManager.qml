import QtQuick 2.15
import QtQuick.Controls

QtObject {
    id: popupManager

    property var popups: ({})

    function getPopup(popupQml) {
        if (!popups[popupQml]) {
            var component = Qt.createComponent(popupQml);
            if (component.status === Component.Ready) {
                var instance = component.createObject();
                if (instance !== null) {
                    popups[popupQml] = instance;
                } else {
                    logger.d("Failed to create popup instance for " + popupQml);
                }
            } else {
                logger.d("Failed to load " + popupQml);
            }
        }
        return popups[popupQml];
    }

    Component.onDestruction: {
        // 在对象销毁时，销毁所有弹出窗口
        for (var key in popups) {
            if (popups.hasOwnProperty(key)) {
                popups[key].destroy();
            }
        }
        popups = {};
    }
}
