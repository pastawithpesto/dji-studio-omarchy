import QtQuick 2.15
import Controls 1.0
import Config 1.0
import VideoConfig 1.0
import QtQuick.Controls
import QtQuick.Window 2.15
import Qt5Compat.GraphicalEffects
import app_qrc 1.0

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
    modal: false

    Overlay.modal: Rectangle {
        color: Colors.transparent
    }
    parent: Overlay.overlay
    needTransparent: true

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
            color: Colors.color_454649 // 原有整体底色

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
                        id: itemRect
                        property bool hovered: false
                        height: itemModels.itemHeight
                        width: rectangleWidth - 8
                        radius: RadiusConfig.radius_4_8
                        color: {
                            if (!model.enabled) {
                                // 禁用：不高亮，保持底色
                                return Colors.color_transparent;
                            }
                            // 只有 hover 时显示背景
                            return hovered ? Colors.color_FFFFFF_15
                                           : Colors.color_transparent;
                        }

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
                            // 对禁用不做特别处理，保持原样或略微淡一点都可以
                            opacity: model.enabled ? 1.0 : 0.6
                        }

                        Text {
                            anchors {
                                left: icon.right
                                leftMargin: 5
                                top: parent.top
                                bottom: parent.bottom
                                right: parent.right
                            }
                            color: model.enabled
                                   ? (itemRect.hovered
                                      ? ColorsConfig.color_EEEEEE_4DFFC9
                                      : Colors.color_EEEEEE) // from fragmentoperatorpopup (启用白字)
                                   : Colors.color_666666  // from fragmentoperatorpopup (禁用灰字)

                            verticalAlignment: Text.AlignVCenter
                            font.pixelSize: 11
                            text: model.title
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true

                            // 完全跟 fragmentoperatorpopup 一致：禁用时 MouseArea 不可用
                            onClicked: {
                                //如果被禁用掉
                                if (!model.enabled) {
                                    return
                                }
                                for (var i = 0; i < itemModels.count; i++) {
                                    let item = itemModels.get(i);
                                    item.checked = false;
                                    if (i === index && item.enabled) {
                                        item.checked = true;
                                        selectedItemSignal(item.title, item.type);
                                        close();
                                    }
                                }
                            }

                            onEntered: {
                                if(index == 0 && !model.enabled) {
                                    rangeOperationTip.visible = true;
                                }
                                itemRect.hovered = true;
                            }
                            onExited: {
                                if(index == 0) {
                                    rangeOperationTip.visible = false;
                                }
                                itemRect.hovered = false;
                            }
                        }
                    }

                }
            }
        }

        LightToolTip {
            id: rangeOperationTip
            tip: qsTr("pccut_track_scope_tip_2")
            z: Infinity
        }
    }



    // show 增加 disableType：为哪个值就禁用哪个菜单
    function show(widget, selectedType, disableType) {
        itemModels.clear();
        let types = [VideoConfig.COMPOSERANGE_RANGE, VideoConfig.COMPOSERANGE_WHOLE];

        for (var i = 0; i < types.length; i++) {
            let type = types[i];
            let title = videoConfig.getItemByComposeRange(type);
            let checked = (type === selectedType);

            // disableType 可能是 VideoConfig.COMPOSERANGE_WHOLE 或 VideoConfig.COMPOSERANGE_RANGE
            let enabled = (disableType !== type);

            itemModels.append({
                                  title: title,
                                  type: type,
                                  checked: checked,
                                  enabled: enabled
                              });
        }

        rectangleWidth = widget.width;
        rectangleHeight =
                itemModels.count * itemModels.itemHeight +
                (itemModels.count - 1) * itemModels.itemSpacing + 8;

        rectangle.x = UiUtils.getGlobalPosition(widget).x;
        rectangle.y = UiUtils.getGlobalPosition(widget).y + widget.height + 4;
        //调整提示框位置
        rangeOperationTip.x = rectangle.x + 80
        rangeOperationTip.y = rectangle.y + 5
        open();
    }
}
