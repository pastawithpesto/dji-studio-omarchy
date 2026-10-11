import QtQuick

Item {
    id: root
    property var galleryWindow: null

    function open() {
        if (!galleryWindow) {
            const comp = Qt.createComponent("qrc:/qml/debug/UIComponentGalleryWindow.qml");
            if (comp.status === Component.Ready) {
                galleryWindow = comp.createObject(root);
            } else {
                console.error("UIComponentGalleryWindow load failed:", comp.errorString());
                return;
            }
        }
        galleryWindow.show();
        galleryWindow.raise();
        galleryWindow.requestActivate();
    }
}
