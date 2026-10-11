import QtQuick 2.15
import QtQuick.Controls
import Config 1.0
import QtQuick.Window 2.15
import app_qrc 1.0
import UserGuideTypeModel 1.0

// 主要是提供下拉选择的Text
Rectangle {
    id: root

    property real hPadding: 8
    property color textColor: Colors.color_EEEEEE
    property real textSize: 12
    property alias text: contentText.text

    default property alias menuItems: menuContainer.data
    width: parent.width

    radius: RadiusConfig.radius_4_8
    property bool isHovered:false
    color: enabled?(isHovered?Colors.color_68696D:Colors.color_454649):Colors.transparent

    signal menuShown
    signal menuHidden

    Image {
        id: menuIndicator
        visible: parent.enabled
        anchors {
            right: parent.right
            rightMargin: hPadding
            verticalCenter: parent.verticalCenter
        }
        width: 20
        height: 20
        source: menuPop.visible ? "qrc:/icons/adjustment/icon_drop_down_menu_collapse.svg" : "qrc:/icons/adjustment/icon_drop_down_menu_expand.svg"
        sourceSize: Qt.size(20, 20)
    }

    Text {
        id: contentText
        anchors {
            left: parent.left
            right: menuIndicator.left
            leftMargin: hPadding
            rightMargin: hPadding
        }
        height: parent.height
        verticalAlignment: Text.AlignVCenter
        color: textColor
        wrapMode: Text.WrapAnywhere
        font.pixelSize: textSize
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        onEntered: {
            root.isHovered = true;
        }
        onExited: {
            root.isHovered = false;
        }
        onClicked: {
            if (!menuPop.visible) {
                show();
                if(editorManager.isInUserGuideStatus && mask.userGuideType === UserGuideType.REGIONKEYFRAME && mask.visible){
                    globalSignal.exitRegionKfGuide();
                }
            }
        }
    }

    LightPopup {
        id: menuPop
        modal:false
        customRadius: RadiusConfig.radius_4_8
        Overlay.modal: Rectangle {
            color: Colors.transparent
        }
        parent: Overlay.overlay
        width: parent.width
        height: parent.width
        needTransparent:true

        contentItem: Item {
            anchors.fill: parent
            // 这里的MouseArea PinchArea WheelHandler 是为了屏蔽其他地方的操作
            MouseArea {
                anchors.fill: parent
                // propagateComposedEvents: true
                // preventStealing: true
                // acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                onPositionChanged: hide();
                onClicked: hide();
            }

            PinchArea {
                anchors.fill: parent
                onPinchStarted: hide();
            }

            WheelHandler {
                enabled: menuPop.opened
                acceptedDevices: PointerDevice.TouchPad | PointerDevice.Mouse
                onActiveChanged: Qt.callLater(() => hide());
            }

            Item {
                id: menuContainer
                width: root.width
            }
        }
    }

    function show() {
        menuContainer.x = UiUtils.getGlobalPosition(root).x;
        menuContainer.y = UiUtils.getGlobalPosition(root).y + root.height + 4;
        menuPop.open();
        menuShown();
    }

    function hide() {
        menuPop.close();
        menuHidden();
    }
}
