import QtQuick 2.15
import QtQuick.Controls
import Nova 1.0
import Config 1.0
import Controls 1.0
import PanoramaConfig 1.0
import Qt5Compat.GraphicalEffects
import app_qrc 1.0

LightPopup {
    id: toastPopup

    // nova: 取景模式数据从片段绑定的 TimelineVideoClipViewModel 直接投影读取
    property TimelineVideoClipViewModel viewModel
    property double contentRectangleX: 0
    property double contentRectangleY: 0
    property double maxHeight: 0
    property real maxItemTextWidth: 0

    parent: lightWindow.contentItem
    width: Math.max(maxItemTextWidth + 34, 101)
    height: toastPopup.maxHeight
    x: contentRectangleX
    y: contentRectangleY - height / 2
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    Overlay.modal: Rectangle {
        color: Colors.color_transparent
    }

    background: Rectangle {
        color: Colors.color_transparent
    }

    ListModel {
        id: listModel
    }

    contentItem: Rectangle {
        id: contentRectangle
        anchors.fill: parent
        // 选项的高度
        property real itemHeight: 28
        // listview的上、下的内间隙
        property real listViewMargin: 4
        // listview 每个item的间隙
        property real listViewSpace: 4

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
                            model.hovered = true
                        }
                    }
                    onExited: {
                        clearAllHover()
                    }
                    onClicked: {
                        if (!model.selected) {
                            globalSignal.trackViewingModeChanged(model.mode)
                        }
                        close()
                    }
                }
            }
        }
    }

    onOpened: {
        refreshMaxHeight()
    }

    property var modeNames: ({
        [PanoramaConfig.SHOT_VIEW]: qsTr("pccut_image_preview_switch"),
        [PanoramaConfig.FREEDOM_VIEW]: qsTr("pccut_image_liberty_switch"),
        [PanoramaConfig.DIRECTION_LOCK]: qsTr("pccut_panel_image_directionlock"),
        [PanoramaConfig.SELFIE_VIEW]: qsTr("pccut_editing_assistant"),
        [PanoramaConfig.FORWARD_VIEW]: qsTr("pccut_editing_perspective_forward"),
        [PanoramaConfig.FRONTSHOT_VIEW]: qsTr("pccut_editing_perspective_towards")
    })

    // 支持选择的模式列表
    property var supportModes: ({
        [PanoramaConfig.SHOT_VIEW]: !CommonUtils.isNull(viewModel) && viewModel.hasFragment && viewModel.shotViewSupport,
        [PanoramaConfig.FREEDOM_VIEW]: !CommonUtils.isNull(viewModel) && viewModel.hasFragment && viewModel.freeViewSupport,
        [PanoramaConfig.DIRECTION_LOCK]: !CommonUtils.isNull(viewModel) && viewModel.hasFragment && viewModel.fixViewSupport,
        [PanoramaConfig.SELFIE_VIEW]: !CommonUtils.isNull(viewModel) && viewModel.hasFragment && viewModel.selfieViewSupport,
        [PanoramaConfig.FORWARD_VIEW]: !CommonUtils.isNull(viewModel) && viewModel.hasFragment && viewModel.forwardViewSupport,
        [PanoramaConfig.FRONTSHOT_VIEW]: !CommonUtils.isNull(viewModel) && viewModel.hasFragment && viewModel.frontShotViewSupport
    })

    function refreshMaxHeight() {
        if (CommonUtils.isNull(viewModel) || !viewModel.hasFragment) {
            return;
        }
        listModel.clear()
        var arr = []
        for (var modeKey in modeNames) {
            if (!supportModes[modeKey]) {
                continue
            }

            let value = modeNames[modeKey]
            var selected = false
            if (Number(modeKey) === viewModel.panoramaViewingMode) {
                selected = true
            }
            arr.push({
                mode: Number(modeKey),
                value: value,
                selected: selected,
                hovered: false
            });
        }
        listModel.append(arr);
        toastPopup.maxHeight = listModel.count * contentRectangle.itemHeight + contentRectangle.listViewMargin * 2 + (listModel.count - 1) * contentRectangle.listViewSpace;
    }

    function clearAllHover() {
        for (var i = 0; i < listModel.count; i++) {
            var model = listModel.get(i);
            model.hovered = false;
        }
    }
}
