import QtQuick 2.15
import QtQuick.Controls
import Config 1.0
import Controls 1.0
import Qt5Compat.GraphicalEffects
import app_qrc 1.0
import DashboardLocationViewModel 1.0

Item {
    id: root

    property alias viewModel: viewModel
    property bool isActive: enabled

    height: titleRow.height + selectorRect.height + 24

    DashboardLocationViewModel {
        id: viewModel
    }

    // 标题
    Text {
        id: titleRow
        anchors {
            left: parent.left
            top: parent.top
            topMargin: 13
        }
        font.pixelSize: 11
        color: Colors.color_EEEEEE
        text: qsTr("pccut_panel_dashboard_gps_info_title")
    }

    // 位置下拉选择器
    Rectangle {
        id: selectorRect
        anchors {
            left: parent.left
            right: parent.right
            rightMargin: 12
            top: titleRow.bottom
            topMargin: 11.5
        }
        height: 25
        radius: RadiusConfig.radius_4_8
        color: selectorMouseArea.containsMouse ? Colors.color_414344 : Colors.color_2F3032
        opacity: root.isActive ? 1 : 0.2

        Text {
            id: selectorText
            anchors {
                left: parent.left
                leftMargin: 8
                right: arrowIcon.left
                rightMargin: 4
                verticalCenter: parent.verticalCenter
            }
            verticalAlignment: Text.AlignVCenter
            font.pixelSize: 11
            elide: Text.ElideRight
            color: Colors.color_EEEEEE
            text: viewModel.selectedLocation

            HoverHandler {
                id: selectorHover
            }

            LightToolTip {
                visible: selectorHover.hovered && selectorText.truncated
                tip: selectorText.text
                z: 200
            }
        }

        Image {
            id: arrowIcon
            anchors {
                right: parent.right
                rightMargin: 4
                verticalCenter: parent.verticalCenter
            }
            width: 20
            height: 20
            source: locationPopup.visible
                    ? "qrc:/icons/player/ic_canvas_up.svg"
                    : "qrc:/icons/player/ic_canvas_down.svg"
            sourceSize: Qt.size(20, 20)
        }

        MouseArea {
            id: selectorMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (!root.isActive) {
                    toast.showToast(qsTr("pccut_panel_dashboard_gps_enable_toast"), "playerMainView");
                    return;
                }

                // CloseOnPressOutside closes the popup before this handler runs,
                // so visible is always false here. Use timing to detect that case.
                if (Date.now() - locationPopup.lastClosedTime < 200) {
                    return;
                }

                showLocationPopup();
            }
        }
    }

    function showLocationPopup() {
        var position = UiUtils.getGlobalPosition(selectorRect);
        locationPopup.parent = lightWindow.contentItem;
        locationPopup.width = selectorRect.width;
        locationPopup.x = position.x;
        locationPopup.y = position.y + selectorRect.height + 4;
        customInput.isEditing = false;
        locationPopup.open();
    }

    // 下拉弹窗
    Popup {
        id: locationPopup
        modal: false
        focus: true
        closePolicy: Popup.CloseOnPressOutside | Popup.CloseOnEscape
        padding: 0
        topPadding: 10
        bottomPadding: 4
        leftPadding: 4
        rightPadding: 4

        property bool hasSelection: false
        property real lastClosedTime: 0

        onOpened: {
            hasSelection = false;
        }

        onClosed: {
            lastClosedTime = Date.now();
            if (!hasSelection) {
                viewModel.trackGpsAddressEdit("none");
            }
        }
        background: Rectangle {
            color: Colors.color_161616
            radius: RadiusConfig.radius_4_8
            border.color: Colors.color_444444
            border.width: 0.5
            layer.enabled: true
            layer.effect: DropShadow {
                horizontalOffset: 0
                verticalOffset: 0
                radius: 10
                color: Colors.color_000000_40
            }
        }

        contentItem: Column {
            id: popupContent
            property Popup popup: locationPopup
            spacing: 9.5

            // 自定义位置输入
            Rectangle {
                id: customInput
                property bool isEditing: false
                width: popupContent.popup.width - 8
                height: 16
                color: Colors.color_transparent

                Image {
                    id: customCheckIcon
                    visible: !customInput.isEditing
                    anchors {
                        left: parent.left
                        leftMargin: 8
                        verticalCenter: parent.verticalCenter
                    }
                    width: 16
                    height: 16
                    source: viewModel.isCustom
                            ? "qrc:/app_qrc/icons/icon_compose_check.svg" : ""
                    sourceSize: Qt.size(16, 16)
                }

                TextInput {
                    id: customTextInput
                    visible: customInput.isEditing
                    anchors {
                        left: customCheckIcon.right
                        leftMargin: 8
                        right: saveButton.left
                        rightMargin: 8
                        verticalCenter: parent.verticalCenter
                    }
                    font.pixelSize: 11
                    color: Colors.color_EEEEEE
                    clip: true
                    maximumLength: 32
                    selectByMouse: true
                    selectedTextColor: Colors.color_2E2E2E
                    selectionColor: Colors.color_EEEEEE
                    onTextChanged: {
                        // 输入法组合中（如拼音候选）不拦截，等上屏后再处理
                        if (inputMethodComposing) return;
                        // 过滤Emoji：surrogate pair(U+10000以上) | 杂项符号☀⛄❤ | 技术符号⌚⌨ | 图形符号⭐⭕
                        let emojiRegex = /[\uD800-\uDBFF][\uDC00-\uDFFF]|[☀-➿]|[⌀-⏿]|[⬀-⯿]/g;
                        let cleaned = text.replace(emojiRegex, "");
                        if (cleaned !== text) {
                            let pos = cursorPosition;
                            let oldLen = text.length;
                            text = cleaned;
                            cursorPosition = Math.max(0, pos - (oldLen - cleaned.length));
                        }
                    }
                    onAccepted: {
                        customInput.isEditing = false;
                        if (text.length > 0) {
                            viewModel.setCustomLocation(text);
                        }
                    }
                    Keys.onEscapePressed: {
                        customInput.isEditing = false;
                        locationPopup.close();
                    }
                    onActiveFocusChanged: {
                        if (!activeFocus && customInput.isEditing && locationPopup.visible) {
                            customInput.isEditing = false;
                            if (text.length > 0) {
                                viewModel.setCustomLocation(text);
                            }
                        }
                    }
                }

                Text {
                    id: customDisplayText
                    visible: !customInput.isEditing
                    anchors {
                        left: customCheckIcon.right
                        leftMargin: 8
                        right: pencilIcon.left
                        rightMargin: 4
                        verticalCenter: parent.verticalCenter
                    }
                    font.pixelSize: 11
                    color: (viewModel.isCustom || viewModel.lastCustomText.length > 0) ? Colors.color_EEEEEE : Colors.color_999999
                    text: viewModel.isCustom ? viewModel.selectedLocation
                        : (viewModel.lastCustomText.length > 0 ? viewModel.lastCustomText : qsTr("pccut_panel_dashboard_gps_custom_location_option"))
                    elide: Text.ElideRight

                    LightToolTip {
                        visible: customMouseArea.containsMouse && customDisplayText.truncated
                        tip: customDisplayText.text
                        z: 200
                    }
                }

                Rectangle {
                    id: saveButton
                    visible: customInput.isEditing
                    anchors {
                        right: parent.right
                        rightMargin: 4
                        verticalCenter: parent.verticalCenter
                    }
                    width: saveText.implicitWidth + 12
                    height: 20
                    radius: RadiusConfig.radius_4_8
                    color: (customTextInput.text.length > 0 && saveMouseArea.containsMouse)
                           ? Colors.color_37383A : Colors.color_2F3032

                    Text {
                        id: saveText
                        anchors.centerIn: parent
                        font.pixelSize: 11
                        color: customTextInput.text.length > 0 ? Colors.color_EEEEEE : Colors.color_444444
                        text: qsTr("pccut_shortcut_space__customize_save")
                    }

                    MouseArea {
                        id: saveMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: customTextInput.text.length > 0
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            customInput.isEditing = false;
                            viewModel.setCustomLocation(customTextInput.text);
                        }
                    }
                }

                Image {
                    id: pencilIcon
                    visible: !customInput.isEditing
                    anchors {
                        right: parent.right
                        rightMargin: 8
                        verticalCenter: parent.verticalCenter
                    }
                    width: 16
                    height: 16
                    source: customMouseArea.containsMouse
                            ? "qrc:/app_qrc/icons/ic_pen_hover.svg"
                            : "qrc:/app_qrc/icons/ic_pen_normal.svg"
                    sourceSize: Qt.size(16, 16)
                }

                MouseArea {
                    id: customMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    visible: !customInput.isEditing
                    onClicked: {
                        customInput.isEditing = true;
                        customTextInput.text = viewModel.isCustom ? viewModel.selectedLocation : viewModel.lastCustomText;
                        customTextInput.forceActiveFocus();
                    }
                }
            }

            // POI列表
            Flickable {
                id: poiFlick
                visible: viewModel.locationList.length > 0
                width: popupContent.popup.width - 8
                height: Math.min(contentHeight, 224)
                contentHeight: poiColumn.height + separatorLine.height + 4
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Rectangle {
                    id: separatorLine
                    width: parent.width
                    height: 1
                    color: Colors.color_2F3032
                }

                Column {
                    id: poiColumn
                    width: parent.width
                    anchors.top: separatorLine.bottom
                    anchors.topMargin: 4
                    spacing: 4

                    Repeater {
                        id: poiRepeater
                        model: viewModel.locationList
                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            width: poiColumn.width
                            height: 28
                            radius: RadiusConfig.radius_4_8
                            color: itemMouse.containsMouse ? Colors.color_2F3032 : Colors.color_transparent

                            Image {
                                id: checkIcon
                                anchors {
                                    left: parent.left
                                    leftMargin: 8
                                    verticalCenter: parent.verticalCenter
                                }
                                width: 16
                                height: 16
                                source: modelData.checked
                                        ? "qrc:/app_qrc/icons/icon_compose_check.svg" : ""
                                sourceSize: Qt.size(16, 16)
                            }

                            Text {
                                id: poiNameText
                                anchors {
                                    left: checkIcon.right
                                    leftMargin: 8
                                    right: categoryText.left
                                    rightMargin: 8
                                    verticalCenter: parent.verticalCenter
                                }
                                font.pixelSize: 11
                                color: Colors.color_EEEEEE
                                text: modelData.name
                                elide: Text.ElideRight

                                LightToolTip {
                                    visible: itemMouse.containsMouse && poiNameText.truncated
                                    tip: poiNameText.text
                                    z: 200
                                }
                            }

                            Text {
                                id: categoryText
                                anchors {
                                    right: parent.right
                                    rightMargin: 8
                                    verticalCenter: parent.verticalCenter
                                }
                                font.pixelSize: 11
                                color: Colors.color_999999
                                text: modelData.category
                            }

                            MouseArea {
                                id: itemMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.ArrowCursor
                                onClicked: {
                                    viewModel.selectLocation(index);
                                }
                            }
                        }
                    }
                }
            }
        }

        Connections {
            target: viewModel
            function onSelectedLocationChanged() {
                locationPopup.hasSelection = true;
                locationPopup.close();
            }
        }
    }
}
