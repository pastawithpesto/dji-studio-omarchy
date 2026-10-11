import QtQuick 2.15
import Controls 1.0
import Config 1.0
import VideoConfig 1.0
import QtQuick.Controls
import QtQuick.Window 2.15
import Qt5Compat.GraphicalEffects
import app_qrc 1.0

/**
  * @author: pansy.guo
  * @details 码率选择界面
  * @date: 2024-05-23 10:15:44
  */
LightPopup {
    // 点击空白，关闭的信号
    signal closeSignal
    // 点击item的信号
    signal selectedItemSignal(string title, real type)

    property real rectangleWidth: 0
    property real rectangleHeight: 0

    width: parent.width
    height: parent.height
    z: Infinity
    modal:false
    Overlay.modal: Rectangle {
        color: Colors.transparent
    }
    parent: Overlay.overlay
    needTransparent:true

    contentItem: Item {
        MouseArea {
            anchors.fill: parent
            onClicked: {
                closeSignal();
                close();
            }
        }

        Rectangle {
            id: rectangle
            width: rectangleWidth
            height: rectangleHeight
            radius: RadiusConfig.radius_4_8
            clip: true

            color: Colors.color_454649

            // 添加阴影效果
            layer.enabled: true
            layer.effect: DropShadow {
                horizontalOffset: 0
                verticalOffset: 0
                radius: 10
                color: Colors.color_000000_40
            }

            ListModel {
                id: itemModels
                property int itemHeight: 28
                property int itemSpacing: 4
            }

            Column {
                topPadding: 4
                bottomPadding: 4
                leftPadding: 4
                rightPadding: 4
                spacing: itemModels.itemSpacing
                Repeater {
                    model: itemModels
                    Rectangle {
                        property bool hovered:false
                        height: itemModels.itemHeight
                        width: rectangleWidth-8
                        radius: RadiusConfig.radius_4_8
                        color: hovered ? Colors.color_FFFFFF_15 : Colors.color_transparent
                        Image {
                            id: icon
                            anchors {
                                left: parent.left
                                leftMargin: 8
                                verticalCenter: parent.verticalCenter
                            }
                            width: 16
                            height: 16
                            source: model.checked ? "qrc:/app_qrc/icons/icon_compose_check.svg" : ""
                            sourceSize: Qt.size(16, 16)
                        }
                        Text {
                            anchors {
                                left: icon.right
                                leftMargin: 5
                                top: parent.top
                                bottom: parent.bottom
                                right: parent.right
                            }
                            color: hovered ? ColorsConfig.color_EEEEEE_4DFFC9 : Colors.color_EEEEEE
                            verticalAlignment: Text.AlignVCenter
                            font.pixelSize: 11
                            text: model.title
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                for (var i = 0; i < itemModels.count; i++) {
                                    let item = itemModels.get(i);
                                    item.checked = false;
                                    if (i == index) {
                                        item.checked = true;
                                        selectedItemSignal(item.title, item.type);
                                        close();
                                    }
                                }
                            }
                            onEntered: {
                                parent.hovered = true
                            }

                            onExited: {
                                parent.hovered = false
                            }

                        }
                    }
                }
            }
        }
    }

    function show(widget, selectedType) {
        itemModels.clear();
        let types = [VideoConfig.BITRATETYPE_LOW, VideoConfig.BITRATETYPE_RECOMMEND, VideoConfig.BITRATETYPE_HIGH, VideoConfig.BITRATETYPE_CUSTOM];
        for (var i = 0; i < types.length; i++) {
            let type = types[i];
            let title = videoConfig.getItemByBitrateType(type);
            let checked = type === selectedType;
            itemModels.append({
                title: title,
                type: type,
                checked: checked
            });
        }
        rectangleWidth = widget.width;
        rectangleHeight = itemModels.count * itemModels.itemHeight + (itemModels.count - 1) * itemModels.itemSpacing + 8;
        rectangle.x = UiUtils.getGlobalPosition(widget).x;
        rectangle.y = UiUtils.getGlobalPosition(widget).y + widget.height + 4;
        open();
    }
}
