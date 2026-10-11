import QtQuick 2.15
import Config 1.0
import Nova 1.0

Item {
    id: delegateItem
    required property int index
    required property var multiView

    width: multiView.itemSize.width
    height: multiView.itemSize.height

    // 本 item 始终占布局槽位(visible 恒 true)，保证平面视频仅首窗时首窗贴顶而非上下居中。
    // 内容显隐由 active 控制：全景(支持多视角)=4 窗全显；平面=仅首窗(index 0)有内容、其余透明占位。
    visible: true
    readonly property bool active: index === 0 || multiView.supportMultiView

    Component.onCompleted: {
        attachRender(multiView.extraViewAt(index))
    }

    Component.onDestruction: {
        detachRender(multiView.extraViewAt(index))
    }

    // visible/opacity/size 由 C++ setExtraViewsVisible 统一管（MKPlayerExtraView.setSize 非
    // Q_INVOKABLE，QML 调必 TypeError）；本 delegate 不再绑定这三者，避免元对象告警与时序竞争。
    function attachRender(render) {
        if (!render) {
            return
        }
        render.parent = delegateItem
        render.anchors.centerIn = delegateItem
        render.z = delegateItem.z + 2
    }

    function detachRender(render) {
        if (!render) {
            return
        }
        render.anchors.centerIn = null
        render.parent = null
    }

    Image {
        id: lostImage
        visible: multiView.mediaLost && delegateItem.active
        opacity: delegateItem.active ? 1 : 0
        anchors.fill: parent
        fillMode: Image.PreserveAspectFit
        source: "qrc:/app_qrc/resources/media_lost.png"
        z: delegateItem.z + 2
    }

    Rectangle {
        id: cover
        color: Colors.color_transparent
        border.color: (ma.containsMouse && multiView.isFreedomView) ? Colors.color_FFFFFF_50 : Colors.color_transparent
        border.width: 1.5
        opacity: delegateItem.active ? 1 : 0
        anchors.fill: parent
        z: delegateItem.z + 3

        Image {
            source: multiView.iconSource(index)
            width: 16
            height: 16
            visible: multiView.supportMultiView

            anchors {
                top: parent.top
                right: parent.right
                margins: 4
            }
        }

        MouseArea {
            id: ma
            enabled: multiView.supportMultiView
            anchors.fill: parent
            hoverEnabled: multiView.supportMultiView
            acceptedButtons: Qt.LeftButton
            propagateComposedEvents: false
            preventStealing: true

            onClicked: {
                logger.d("[multiview] onClicked index: " + index)
                multiView.onViewSelected(index)
            }
        }
    }
}
