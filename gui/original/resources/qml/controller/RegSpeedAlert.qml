import QtQuick 2.15
import QtQuick.Controls
import Nova 1.0
import Config 1.0
import Controls 1.0
import Qt5Compat.GraphicalEffects
import MediaTypeModel 1.0
import app_qrc 1.0

//倍速调整弹窗（nova SpeedViewModel 驱动）
LightPopup {
    id: toastPopup
    // 点击item的信号
    signal quickRegSpeedItemClicked(double newRegSpeed)
    // 数据源
    property SpeedViewModel viewModel
    property double contentRectangleX: 0
    property double contentRectangleY: 0
    property double maxHeight: 0
    property real maxItemTextWidth: 0

    parent: Overlay.overlay
    width: parent.width
    height: parent.height
    closePolicy: Popup.NoAutoClose
    dim: false

    background: Rectangle {
        color: Colors.color_transparent
    }

    contentItem: Item {
        anchors.fill: parent
        MouseArea {
            anchors.fill: parent
            onClicked: toastPopup.close()
        }
        Rectangle {
            id: contentRectangle
            // 选项的高度
            property real itemHeight: 28
            // listview的上、下的内间隙
            property real listViewMargin: 4
            // listview 每个item的间隙
            property real listViewSpace: 4

            width: Math.max(maxItemTextWidth + 34, 101)
            height: toastPopup.maxHeight
            x: contentRectangleX
            y: contentRectangleY - contentRectangle.height / 2

            color: Colors.color_141414
            radius: 8
            opacity: 1
            clip: true
            border {
                width: 1
                color: Colors.color_444444
            }

            layer.enabled: true
            layer.samples: 10
            layer.effect: DropShadow {
                horizontalOffset: 0
                verticalOffset: 0
                radius: 50
                transparentBorder: true
                color: Colors.color_000000_40
            }

            ListView {
                id: listView
                anchors.fill: parent
                interactive: false
                clip: true

                topMargin: contentRectangle.listViewMargin
                bottomMargin: contentRectangle.listViewMargin
                spacing: contentRectangle.listViewSpace

                model: listModel
                delegate: Rectangle {
                    x: 4
                    width: contentRectangle.width - 8
                    height: contentRectangle.itemHeight
                    radius: RadiusConfig.radius_4_8
                    // 选中、hover的颜色
                    color: model.selected ? ColorsConfig.color_353738_4DFFC920 : (model.hovered ? ColorsConfig.color_353738_4DFFC920 : Colors.color_transparent)
                    Component.onCompleted: {
                        maxItemTextWidth = Math.max(maxItemTextWidth, itemText.width + 28);
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
                        source: model.selected ? "qrc:/app_qrc/icons/icon_compose_check.svg" : ""
                        sourceSize: Qt.size(16, 16)
                    }
                    Text {
                        id: itemText
                        anchors {
                            left: icon.right
                            leftMargin: 4
                            verticalCenter: parent.verticalCenter
                        }
                        color: (model.selected || model.hovered) ? ColorsConfig.color_EEEEEE_4DFFC9 : Colors.color_EEEEEE
                        font {
                            pixelSize: 11
                        }

                        text: model.value
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: {
                            if (!model.selected) {
                                model.hovered = true;
                            }
                        }
                        onExited: {
                            clearAllHover();
                        }
                        onClicked: {
                            quickRegSpeedItemClicked(model.speed);
                            close();
                        }
                    }
                }
            }
        }
    }

    onOpened: {
        refreshMaxHeight();
    }

    function refreshMaxHeight() {
        if (CommonUtils.isNull(viewModel) || !viewModel.hasClip) {
            return;
        }
        listModel.clear();
        var arr = [];
        var speedArr = [0.1, 0.2, 0.5, 1, 1.5, 2, 10];
        // 子弹时间素材快捷档差异：P1 简化，按 speedForBulletTimeVideo() 判定
        var matched = viewModel.speedForBulletTimeVideo();
        if (Math.abs(matched - 1.0) > 1e-6) {
            speedArr = [0.125, 0.25, 0.5, 1, 1.5, 2, 10];
        }

        for (var j = 0; j < speedArr.length; j++) {
            let speed = speedArr[j];
            let value = getValueString(speed);
            var selected = false;
            if (Math.abs(speed - viewModel.regSpeed) < 1e-6) {
                selected = true;
            }
            arr.push({
                value: value,
                selected: selected,
                hovered: false,
                speed: speed
            });
        }
        listModel.append(arr);
        toastPopup.maxHeight = listModel.count * contentRectangle.itemHeight + contentRectangle.listViewMargin * 2 + (listModel.count - 1) * contentRectangle.listViewSpace;
    }

    onClosed: {
        listModel.clear();
        globalSignal.regSpeedAlertClosed();
    }

    // 获取model.value，对应的内容
    function getValueString(speed) {
        var speedStr = "";
        if (speed < 1) {
            speedStr = qsTr("pccut_speed_popup_slow");
        } else if (speed === 1) {
            speedStr = qsTr("pccut_speed_popup_normal");
        } else {
            speedStr = qsTr("pccut_speed_popup_fast");
        }
        return speedStr + " " + speed + "x"
    }
    // 清空模型中的hovered
    function clearAllHover() {
        for (var i = 0; i < listModel.count; i++) {
            var model = listModel.get(i);
            model.hovered = false;
        }
    }

    ListModel {
        id: listModel
    }
}
