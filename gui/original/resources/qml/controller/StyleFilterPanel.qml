import QtQuick 2.15
import QtQuick.Controls
import Config 1.0
import Controls 1.0
import app_qrc 1.0
import Nova 1.0

/**
 *  @File        : StyleFilterPanel.qml
 *  @Brief       : 滤镜调节UI（nova StyleFilterViewModel 驱动）
 */

Rectangle {
    signal haveNoItemVisibleSig()
    anchors.fill: parent
    color: Colors.color_content_area_background

    // 保留 viewModel 属性以兼容父组件赋值，内部不使用
    property var viewModel

    // 两边边距之和
    property int bothSidePadding: 100

    StyleFilterViewModel { id: styleVM }

    Flickable {
        id: scrollView
        contentHeight: 410
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            bottom: parent.bottom
            leftMargin: 12
            rightMargin: 12
            topMargin: 1
        }
        signal clickReset()
        property double defultOpacity: header_filter.isDisable ? 0.2 : 1
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: false

        Column {
            spacing: 12
            anchors.left: parent.left
            anchors.top: parent.top
            width: scrollView.width

            Item { width: parent.width; height: 1 }

            Item {
                id: header_filter
                property bool isDisable: !styleVM.hasClip || !styleVM.isEnable
                width: parent.width
                height: 20

                CheckBox {
                    id: checkBox_filter
                    text: qsTr("pccut_filter")
                    anchors.verticalCenter: parent.verticalCenter
                    checked: styleVM.hasClip && styleVM.isEnable
                    indicator: Rectangle {
                        implicitWidth: 14
                        implicitHeight: 14
                        anchors.left: checkBox_filter.left
                        anchors.verticalCenter: parent.verticalCenter
                        color: checkBox_filter.checked ? ColorsConfig.color_brand : Colors.color_444444
                        radius: 4
                        Image {
                            visible: checkBox_filter.checked
                            anchors.fill: parent
                            source: "qrc:/app_qrc/icons/icon_checkbox_check.svg"
                            sourceSize: Qt.size(parent.width, parent.height)
                        }
                    }
                    onClicked: {
                        styleVM.isEnable = checkBox_filter.checked
                        editorDraftManager.saveDraft();
                    }
                    contentItem: Text {
                        text: checkBox_filter.text
                        font.pixelSize: 12
                        color: Colors.color_EEEEEE
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: checkBox_filter.indicator.width
                    }
                }

                Rectangle {
                    id: resetBtn
                    property bool isHovered: false
                    anchors {
                        right: allUseBtn.left
                        rightMargin: 12
                        verticalCenter: parent.verticalCenter
                    }
                    color: Colors.color_transparent
                    width: 20
                    height: 20

                    // 当前强度与默认值 0.8 相比，偏差超过 0.5% 时才激活重置
                    property bool atDefault: Math.abs(styleVM.factor - 0.8) < 0.005

                    Image {
                        anchors.fill: parent
                        source: (header_filter.isDisable || resetBtn.atDefault)
                                ? "qrc:/icons/ic_reset.svg"
                                : resetBtn.isHovered ? "qrc:/icons/ic_reset_hover.svg"
                                                     : "qrc:/icons/ic_reset.svg"
                        sourceSize: Qt.size(parent.width, parent.height)
                        opacity: (header_filter.isDisable || resetBtn.atDefault) ? 0.2 : 1
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: resetBtn.isHovered = true
                        onExited:  resetBtn.isHovered = false
                        onClicked: {
                            if (!header_filter.isDisable && !resetBtn.atDefault) {
                                scrollView.clickReset()
                            }
                        }
                    }
                }

                Rectangle {
                    id: allUseBtn
                    property bool isHovered: false
                    color: header_filter.isDisable ? Colors.color_353738
                                                   : allUseBtn.isHovered ? Colors.color_414344
                                                                         : Colors.color_353738
                    radius: RadiusConfig.radius_4_88
                    opacity: header_filter.isDisable ? 0.3 : 1
                    anchors {
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }
                    width: allUseBtnText.width + 16
                    height: 20

                    Text {
                        id: allUseBtnText
                        text: qsTr("pccut_panel_colorrecovery_applyglobally")
                        anchors.centerIn: parent
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: Colors.color_EEEEEE
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !header_filter.isDisable
                        onEntered: allUseBtn.isHovered = true
                        onExited:  allUseBtn.isHovered = false
                        onClicked: {
                            editorManager.pause();
                            styleVM.applyToAll(styleVM.slug, styleVM.factor, styleVM.resourcePath)
                        }
                    }
                }
            }
            Item{
                id: subName
                opacity: scrollView.defultOpacity
                width: parent.width
                height: 24

                Text {
                    text: qsTr("pccut_panel_colorrecovery_name")
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22
                    height: 15
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    color: Colors.color_999999
                }

                Text {
                    id: nameText
                    text: styleVM.displayName
                    anchors.left: parent.left
                    anchors.leftMargin: 69
                    width: 187
                    anchors.verticalCenter: parent.verticalCenter
                    height: 15
                    elide: Text.ElideMiddle
                    horizontalAlignment: Text.AlignLeft
                    font.pixelSize: 11
                    color: Colors.color_EEEEEE
                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        LightToolTip {
                            visible: mouseArea.containsMouse && nameText.implicitWidth > nameText.width
                            tip: nameText.text
                        }
                    }
                }
            }

            Item { width: parent.width; height: 12 }

            // 强度滑杆（0-100，对应内部 0.0-1.0）
            Item {
                width: parent.width
                height: 15
                enabled: checkBox_filter.checked
                clip: true

                Connections {
                    target: scrollView
                    function onClickReset() {
                        styleVM.factor = 0.8
                        styleVM.editing = false
                    }
                }

                Text {
                    id: factorLabel
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    horizontalAlignment: Text.AlignLeft
                    font.pixelSize: 11
                    color: Colors.color_999999
                    opacity: scrollView.defultOpacity
                    text: styleVM.factorTitle
                }

                Text {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    horizontalAlignment: Text.AlignRight
                    font.pixelSize: 11
                    color: Colors.color_CCCCCC
                    opacity: scrollView.defultOpacity
                    text: factorSlider.value
                }

                LightBaseSlider {
                    id: factorSlider
                    anchors {
                        verticalCenter: parent.verticalCenter
                        left: parent.left
                        leftMargin: 70
                    }
                    leftPadding: 0
                    width: parent.width - bothSidePadding
                    from: 0
                    to: 100
                    value: Math.round(styleVM.factor * 100)
                    stepSize: 1
                    snapMode: Slider.SnapAlways

                    onMoved: {
                        if (pressed) {
                            styleVM.factor  = value / 100.0
                            styleVM.editing = true
                        }
                    }
                    onPressedChanged: {
                        if (pressed) {
                            editorManager.pause()
                            styleVM.editing = true
                        } else {
                            styleVM.factor  = value / 100.0
                            styleVM.editing = false
                            enabled = false
                            enabled = true
                        }
                    }
                }
            }
        }
    }
}
