import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls
import QtQuick.Dialogs
import Qt5Compat.GraphicalEffects
import Controls 1.0
import Config 1.0
import MediaListViewModel 1.0
import app_qrc 1.0

Popup {
    id: customLightPopup
    closePolicy: Popup.CloseOnEscape

    modal: false
    property int currentPositionType: 0
    // 点击切换位置
    signal clickPositionType(var positionType)
    width: parent.width
    implicitHeight: 196
    property real itemBgWidth: width - 8
    property var positionModel
    property bool isExport: false
    property int ownerRadius: isExport ? RadiusConfig.radius_4_8 : 8

    background: Rectangle {
        color: isExport ? Colors.color_454649 : Colors.color_141414
        border.color: Colors.color_444444
        border.width: isExport ? 0 : 1
        radius: ownerRadius
        // 阴影
        layer.enabled: isExport ? true : false
        layer.effect: DropShadow {
            horizontalOffset: 0
            verticalOffset: 0
            radius: 10
            color: Colors.color_000000_40
        }
    }

    contentItem: Item {
        anchors.fill: parent
        clip: true

        Item {
            id: topItem
            height: 4
        }

        Column {
            width: parent.width
            height: 128
            spacing: 4
            anchors {
                top: topItem.bottom
            }

            Repeater {
                model: positionModel
                anchors.fill: parent

                delegate: Rectangle {
                    id: rec
                    property bool isHovered: false
                    property bool isSelected: positionType === currentPositionType
                    radius: RadiusConfig.radius_4_8
                    width: itemBgWidth
                    height: 28
                    color: rec.isHovered ? (isExport ? ColorsConfig.color_68696D_4DFFC920 : ColorsConfig.color_353738_4DFFC920) : Colors.color_transparent
                    anchors.horizontalCenter: parent.horizontalCenter
                    Image {
                        width: 16
                        height: 16
                        source: "qrc:/app_qrc/icons/icon_compose_check.svg"
                        anchors.verticalCenter: parent.verticalCenter
                        x: 8
                        visible: positionType === currentPositionType
                    }

                    Text {
                        id: positionText
                        text: model.name
                        height: parent.height
                        font.pixelSize: 11
                        color: (positionType === currentPositionType || rec.isHovered) ? ColorsConfig.color_EEEEEE_4DFFC9 : Colors.color_EEEEEE
                        leftPadding: 30
                        verticalAlignment: Text.AlignVCenter
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: rec.isHovered = true;
                        onExited: rec.isHovered = false;
                        onClicked: {
                            close();
                            clickPositionType(positionType);
                        }
                    }
                }
            }
        }
    }
}
