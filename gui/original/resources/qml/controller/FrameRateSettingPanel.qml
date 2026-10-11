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
  * @details 帧率选择界面
  * @date: 2024-05-21 16:01:10
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

            ListView {
                id: listView
                anchors.fill: parent
                anchors.margins: 4
                spacing: itemModels.itemSpacing
                boundsBehavior: Flickable.StopAtBounds
                model: itemModels
                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AlwaysOn
                    bottomPadding: padding
                    rightPadding: 0
                    Component.onCompleted: {
                        contentItem.color = Colors.color_56575B
                    }
                }
                delegate: Rectangle {
                    height: itemModels.itemHeight
                    width: rectangleWidth-8
                    radius: RadiusConfig.radius_4_8
                    property bool hovered:false
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

    function show(widget, selectedType, maxFrameRate) {
        itemModels.clear();
        let types = [VideoConfig.FRAMERATETYPE_24, VideoConfig.FRAMERATETYPE_25, VideoConfig.FRAMERATETYPE_30, VideoConfig.FRAMERATETYPE_48,
                     VideoConfig.FRAMERATETYPE_50, VideoConfig.FRAMERATETYPE_60, VideoConfig.FRAMERATETYPE_100,
                     VideoConfig.FRAMERATETYPE_120, VideoConfig.FRAMERATETYPE_200, VideoConfig.FRAMERATETYPE_240]; // 需和枚举FrameRateType 相对应
        
        // 获取最接近selectedType且不大于selectedType的type。这么做的原因是types定义的类型不等于VideoConfig中所有的枚举，types只是展示出来的类型，因此如果视频选择的类型是不被展示的，则向下进行匹配
        // 预选上限取 max(maxFrameRate, FRAMERATETYPE_60)，原因：下方展示条件（type <= maxFrameRate || type <= FRAMERATETYPE_60）
        // 决定了 <=60fps 的选项始终展示，因此用户可选上限为 max(maxFrameRate, FRAMERATETYPE_60)。
        // C++ 侧 FileOperator::getExportFrameRate() 的钳制逻辑与此保持一致。
        let effectiveMax = Math.max(maxFrameRate, VideoConfig.FRAMERATETYPE_60)
        let j = 0
        let closestTypeBelowSelected = types[0]
        for (; j < types.length; ++j) {
            if (types[j] <= selectedType && types[j] <= effectiveMax) {
                closestTypeBelowSelected = types[j]
            }
        }

        let selectedIndex = 0
        for (var i = 0; i < types.length; i++) {
            let type = types[i];
            let title = videoConfig.getQmlItemByFrameRateType(type).name;
            if (type <= maxFrameRate || type <= VideoConfig.FRAMERATETYPE_60) {
                let checked = type === closestTypeBelowSelected;
                if (checked === true) {
                    selectedIndex = i
                }
                itemModels.append({
                    title: title,
                    type: type,
                    checked: checked
                });
            }
        }
        rectangleWidth = widget.width;
        rectangleHeight = Math.min(itemModels.count * itemModels.itemHeight + (itemModels.count - 1) * itemModels.itemSpacing + 8, 164)
        rectangle.x = UiUtils.getGlobalPosition(widget).x;
        rectangle.y = UiUtils.getGlobalPosition(widget).y + widget.height + 4;
        open();
        listView.positionViewAtIndex(selectedIndex, ListView.Contain)
    }
}
