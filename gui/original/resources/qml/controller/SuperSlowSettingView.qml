import QtQuick 2.15
import Config 1.0
import QtQuick.Controls
import Nova 1.0
import Controls 1.0

/**
  * @details 超级慢动作设置View（nova SpeedViewModel 驱动）
  * 复选框开关 + 速度档(0.5/0.25/0.125x) + 时长档(1/2/3/5/8s/整段)。
  * supportsSuperSlow 门控由 RegSpeedPanel 控制 visible。
  */
Item {
    id: root
    property SpeedViewModel viewModel
    property bool isChecked: checkBox.checked
    property bool indicatorIsInfragment: viewModel.isIndicatorInClip

    Connections {
        target: viewModel
        function onSuperSlowSpeedLevelChanged() {
            vagueDirectControl.currentIndex = viewModel.superSlowSpeedLevel
        }
        function onSuperSlowRangeLevelChanged() {
            vagueDirectControl1.currentIndex = viewModel.superSlowRangeLevel
        }
        function onSuperSlowEnableChanged() {
            checkBox.checked = viewModel.superSlowEnable
        }
    }

    function disableSuperSlow() {
        viewModel.superSlowEnable = false
    }

    Item {
        id: checkBoxItem
        width: parent.width
        height: 16
        anchors {
            top: parent.top
            left: parent.left
        }
        LightCheckBox {
            id: checkBox
            objectName: actionableItemName.superSlowButton
            enabled: (viewModel.superSlowCanUse === 0 && viewModel.isIndicatorInClip) || viewModel.superSlowEnable
            maxTextWidth: 200
            text: qsTr("pccut_superslow_btn")
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            checked: viewModel.superSlowEnable
            textColor: enabled ? Colors.color_EEEEEE : Colors.color_444444

            onClicked: {
                viewModel.superSlowEnable = checkBox.checked
                if (checkBox.checked && editorManager.isInUserGuideStatus) {
                    globalSignal.enterNextStepSuperSlowGuide()
                }
            }
        }

        // fps 不足(-1)或裁切后超慢区间失效(-4)时点复选框方块弹 toast
        MouseArea {
            id: checkBoxBtn
            visible: viewModel.superSlowCanUse === -1 || viewModel.superSlowCanUse === -4
            x: checkBox.x + checkBox.indicator.x
            y: checkBox.y + checkBox.indicator.y
            width: checkBox.indicator.width
            height: checkBox.indicator.height
            onClicked: toast.showToast(qsTr(viewModel.superSlowCanUse === -1
                                            ? "pccut_superslow_fail_toast_1"
                                            : "pccut_superslow_fail_toast"))
        }

        Rectangle {
            id: descriptionBtn
            anchors.left: checkBox.left
            anchors.leftMargin: checkBox.width - 6
            anchors.top: parent.top
            anchors.topMargin: (checkBoxItem.height - descriptionBtn.height) / 2
            width: 14
            height: 14
            color: Colors.color_transparent
            Image {
                id: descriptIcon
                anchors.fill: parent
                source: !checkBox.enabled
                        ? "qrc:/icons/ic_explain_disable.svg"
                        : (descriptionBtnMouseArea.containsMouse ? "qrc:/icons/ic_explain.svg" : "qrc:/icons/ic_explain_hover.svg")
                sourceSize: Qt.size(descriptionBtn.width, descriptionBtn.height)
            }
            MouseArea {
                id: descriptionBtnMouseArea
                anchors.fill: parent
                hoverEnabled: true
            }
            ColorDiffClearTips {
                id: deDistortionTips
                tipText: qsTr("pccut_superslow_function_tip")
                arrowLeftMargin: descriptionBtn.x + descriptionBtn.width / 2
                width: vagueDirectControl.x + vagueDirectControl.width - directtext.x
                height: 28
                anchors {
                    left: descriptionBtn.left
                    leftMargin: Math.max(-checkBox.x - descriptionBtn.x, -(deDistortionTips.width - descriptionBtn.width) / 2)
                    bottom: descriptionBtn.top
                }
                visible: descriptionBtnMouseArea.containsMouse
            }
        }

        // 速度档
        Rectangle {
            id: vagueDirect
            enabled: checkBox.checked
            visible: true
            width: parent.width
            height: 24
            color: Colors.transparent
            anchors {
                top: checkBoxItem.bottom
                topMargin: 16
                left: checkBoxItem.left
            }

            Text {
                id: directtext
                width: 57
                height: 16
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: 11
                color: Colors.color_999999
                opacity: checkBox.checked ? 1 : 0.2
                text: qsTr("pccut_superslow_function_speed")
            }

            ComboBox {
                id: vagueDirectControl
                anchors {
                    top: parent.top
                    left: directtext.right
                    leftMargin: 12
                    verticalCenter: parent.verticalCenter
                }
                width: vagueDirect.width - directtext.width - 12
                height: 24
                currentIndex: viewModel.superSlowSpeedLevel
                opacity: checkBox.checked ? 1 : 0.2

                background: Rectangle {
                    radius: 4
                    color: enabled ? (mouseArea4.entered ? Colors.color_37383A : Colors.color_2F3032) : Colors.color_2F3032
                    MouseArea {
                        id: mouseArea4
                        property bool entered: false
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: mouseArea4.entered = true
                        onExited: mouseArea4.entered = false
                    }
                }

                contentItem: Text {
                    anchors.left: parent.left
                    leftPadding: 8
                    text: vagueDirectControl.getCurrentText()
                    font.pixelSize: 12
                    color: Colors.color_EEEEEE
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }

                function getCurrentText() {
                    var item = vagueDirectControl.model.get(vagueDirectControl.currentIndex)
                    return item && item.text !== undefined ? item.text : ""
                }

                model: ListModel {
                    ListElement { text: "0.5x" }
                    ListElement { text: "0.25x" }
                    ListElement { text: "0.125x" }
                }

                popup: Popup {
                    id: selectListPopup
                    y: vagueDirectControl.height + 4
                    x: parent.width / 2 - selectListPopup.width / 2
                    width: vagueDirectControl.width
                    height: 100
                    padding: 1
                    background: Rectangle {
                        color: Colors.color_141414
                        border.width: 1
                        border.color: Colors.color_444444
                        radius: 4
                    }
                    contentItem: Rectangle {
                                implicitWidth: selectListPopup.width
                                implicitHeight: selectListPopup.height
                                color: Colors.color_transparent

                                radius: 4
                                border.color: Colors.color_transparent

                                ListView {
                                    id: speedListView
                                    clip: true
                                    model: vagueDirectControl.model
                                    currentIndex: vagueDirectControl.currentIndex
                                    height: 164
                                    implicitWidth: parent.width
                                    anchors.top: parent.top
                                    anchors.topMargin: 4
                                    spacing: 3.5

                                    delegate: Item {
                                        width: speedListView.width - 8
                                        height: 28
                                        x: 4

                                        Rectangle {
                                            anchors.fill: parent
                                            color: index === vagueDirectControl.currentIndex
                                                       ? Colors.color_353738
                                                       : (mouseArea2.entered ? Colors.color_353738 : Colors.color_transparent)
                                            radius: 4
                                        }

                                        Rectangle{
                                            id: selectedFlag
                                            width: 20
                                            height: 20
                                            anchors.verticalCenter: parent.verticalCenter
                                            anchors{
                                                left: parent.left
                                                leftMargin: 8
                                            }

                                            Image {
                                                id: icon
                                                visible: vagueDirectControl.currentIndex == index ? true : false
                                                anchors.fill: parent
                                                source: "qrc:/icons/adjustment/icon_compose_check.svg"
                                                sourceSize: Qt.size(parent.width, parent.height)
                                            }
                                            color: Colors.color_transparent
                                        }

                                        Text {
                                            text: model.text
                                            anchors{
                                                left: parent.left
                                                leftMargin: 36
                                                verticalCenter: parent.verticalCenter
                                            }

                                            verticalAlignment: Text.AlignVCenter
                                            // color: "white"
                                            color: Colors.color_EEEEEE
                                            font.pixelSize: 11
                                            elide: Text.ElideRight
                                        }

                                        MouseArea {
                                            id: mouseArea2
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            property bool entered: false
                                            onClicked: {
                                                viewModel.superSlowSpeedLevel = index
                                                selectListPopup.close()
                                            }

                                            onEntered: {
                                                mouseArea2.entered = true;
                                            }

                                            onExited: {
                                                mouseArea2.entered = false;
                                            }
                                        }
                                    }
                                }
                            }
                }

                indicator: Rectangle {
                    id: indicator
                    anchors.right: parent.right
                    anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    width: 20
                    height: 20
                    color: Colors.color_transparent
                    property string iconPath: "qrc:/icons/ic_close_triangle.svg"
                    Image {
                        anchors.fill: parent
                        source: indicator.iconPath
                        sourceSize: Qt.size(parent.width, parent.height)
                        opacity: vagueDirectControl.enabled ? 1 : 0.2
                    }
                    Connections {
                        target: vagueDirectControl
                        function onDownChanged() {
                            indicator.iconPath = vagueDirectControl.popup.visible
                                    ? "qrc:/icons/ic_open_triangle.svg"
                                    : "qrc:/icons/ic_close_triangle.svg"
                        }
                    }
                }
            }
        }

        // 时长档
        Rectangle {
            id: range
            enabled: checkBox.checked
            visible: true
            width: parent.width
            height: 24
            color: Colors.transparent
            anchors {
                top: vagueDirect.bottom
                topMargin: 16
            }

            Text {
                id: directtext1
                width: 57
                height: 16
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: 11
                color: Colors.color_999999
                opacity: checkBox.checked ? 1 : 0.2
                text: qsTr("pccut_superslow_function_range")
            }

            ComboBox {
                id: vagueDirectControl1
                anchors {
                    top: parent.top
                    left: directtext1.right
                    leftMargin: 12
                    verticalCenter: parent.verticalCenter
                }
                width: range.width - directtext1.width - 12
                height: 24
                currentIndex: viewModel.superSlowRangeLevel
                opacity: checkBox.checked ? 1 : 0.2

                background: Rectangle {
                    radius: 4
                    color: enabled ? (mouseArea41.entered ? Colors.color_37383A : Colors.color_2F3032) : Colors.color_2F3032
                    MouseArea {
                        id: mouseArea41
                        property bool entered: false
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: mouseArea41.entered = true
                        onExited: mouseArea41.entered = false
                    }
                }

                contentItem: Text {
                    anchors.left: parent.left
                    leftPadding: 8
                    text: vagueDirectControl1.model.get(vagueDirectControl1.currentIndex).text
                    font.pixelSize: 12
                    color: Colors.color_EEEEEE
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }

                model: ListModel {
                    ListElement { text: "1s" }
                    ListElement { text: "2s" }
                    ListElement { text: "3s" }
                    ListElement { text: "5s" }
                    ListElement { text: "8s" }
                    ListElement { text: qsTr("pccut_superslow_function_range_entire") }
                }

                popup: Popup {
                    id: selectListPopup1
                    y: vagueDirectControl1.height + 4
                    x: parent.width / 2 - selectListPopup1.width / 2
                    width: vagueDirectControl1.width
                    height: 196
                    padding: 1
                    background: Rectangle {
                        color: Colors.color_141414
                        border.width: 1
                        border.color: Colors.color_444444
                        radius: 4
                    }
                    contentItem: Rectangle {
                        implicitWidth: selectListPopup1.width
                        implicitHeight: selectListPopup1.height
                        color: Colors.color_transparent
                        radius: 4
                        border.color: Colors.color_transparent
                        ListView {
                            clip: true
                            id: listView
                            model: vagueDirectControl1.model
                            currentIndex: vagueDirectControl1.currentIndex
                            height: 196
                            implicitWidth: parent.width
                            anchors.top: parent.top
                            anchors.topMargin: 4
                            spacing: 3.5
                            delegate: Item {
                                width: listView.width - 8
                                height: 28
                                x: 4
                                Rectangle {
                                    anchors.fill: parent
                                    color: index === vagueDirectControl1.currentIndex
                                           ? Colors.color_353738
                                           : (mouseArea21.entered ? Colors.color_353738 : Colors.color_transparent)
                                    radius: 4
                                }
                                Rectangle {
                                    id: selectedFlag1
                                    width: 20
                                    height: 20
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8
                                    Image {
                                        visible: vagueDirectControl1.currentIndex === index
                                        anchors.fill: parent
                                        source: "qrc:/icons/adjustment/icon_compose_check.svg"
                                        sourceSize: Qt.size(parent.width, parent.height)
                                    }
                                    color: Colors.color_transparent
                                }
                                Text {
                                    text: model.text
                                    anchors.left: parent.left
                                    anchors.leftMargin: 36
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Colors.color_EEEEEE
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                }
                                MouseArea {
                                    id: mouseArea21
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    property bool entered: false
                                    onClicked: {
                                        var rangeValue = (index === 5) ? 10000 : [1, 2, 3, 5, 8][index]
                                        if (!viewModel.hasEnoughLengthForRange(rangeValue)) {
                                            toast.showToast(qsTr("pccut_superslow_fail_toast"))
                                            return
                                        }
                                        viewModel.superSlowRangeLevel = index
                                        selectListPopup1.close()
                                    }
                                    onEntered: mouseArea21.entered = true
                                    onExited: mouseArea21.entered = false
                                }
                            }
                        }
                    }
                }

                indicator: Rectangle {
                    id: indicator1
                    anchors.right: parent.right
                    anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    width: 20
                    height: 20
                    color: Colors.color_transparent
                    property string iconPath: "qrc:/icons/ic_close_triangle.svg"
                    Image {
                        anchors.fill: parent
                        source: indicator1.iconPath
                        sourceSize: Qt.size(parent.width, parent.height)
                        opacity: vagueDirectControl1.enabled ? 1 : 0.2
                    }
                    Connections {
                        target: vagueDirectControl1
                        function onDownChanged() {
                            indicator1.iconPath = vagueDirectControl1.popup.visible
                                    ? "qrc:/icons/ic_open_triangle.svg"
                                    : "qrc:/icons/ic_close_triangle.svg"
                        }
                    }
                }
            }
        }
    }
}
