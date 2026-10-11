import QtQuick 2.15

// 不知道如何在加载过程中展示placeholder，所以出此下策，搞两个Image，一个展示缓存，一个展示最终加载的图片

Item {

    property alias requestSource: request.source
    property alias cacheSource: cache.source

    // 这里cache就不使用asynchronous了，因为异步会导致画面闪烁
    Image {
        id: cache
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        visible: request.status !== Image.Ready
        sourceSize: Qt.size(36, 36)
    }

    Image {
        id: request
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: status === Image.Ready
        sourceSize: Qt.size(36, 36)
    }
}
