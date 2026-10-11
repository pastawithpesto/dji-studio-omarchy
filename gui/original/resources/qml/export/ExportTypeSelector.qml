import QtQuick 2.15
import QtQuick.Controls
import Controls 1.0
import Config 1.0
import app_qrc 1.0

import "../controller"

/**
 * @author: mark.zhu
 * @details 导出类型选择器：视频/全景视频（支持多种样式）
 * @date: 2026-03-04
 *
 * 使用示例：
 * // 使用默认的 Dropdown 样式
 * ExportTypeSelector {
 *     viewModel: myViewModel
 * }
 *
 * // 使用 Radio Button 样式
 * ExportTypeSelector {
 *     viewModel: myViewModel
 *     displayStyle: ExportTypeSelector.DisplayStyle.RadioButton
 * }
 *
 * // 自定义标题文本
 * ExportTypeSelector {
 *     viewModel: myViewModel
 *     titleText: qsTr("pccut_custom_title")
 * }
 */
Rectangle {
    id: root

    // ==================== 枚举定义 ====================

    enum DisplayStyle {
        RadioButton,  // CheckBox (Radio Button) 样式
        Dropdown      // 下拉菜单样式
    }

    // ==================== 公共属性 ====================

    // 必需属性：外部传入 MediaExportSettingsProtocol 实例
    required property var viewModel

    // 样式选择（默认为 Dropdown）
    property int displayStyle: ExportTypeSelector.DisplayStyle.Dropdown

    // 样式定制
    property int titleLeftMargin: 63
    property int titleWidth: 51
    property string titleText: qsTr("pccut_home_highlight_export_type")
    property bool isSelecting: false  // 下拉菜单展开状态（用于样式控制）

    // ==================== 布局 ====================

    width: parent.width
    height: 28
    implicitHeight: 28
    color: Colors.color_transparent

    // 标题文本
    Text {
        id: titleText
        anchors {
            left: parent.left
            top: parent.top
            bottom: parent.bottom
        }
        width: root.titleWidth
        horizontalAlignment: Text.AlignLeft
        verticalAlignment: Text.AlignVCenter
        maximumLineCount: 2
        wrapMode: Text.WrapAnywhere
        font.pixelSize: 12
        color: Colors.color_EEEEEE
        text: root.titleText
    }

    // ==================== 动态样式加载器 ====================

    Loader {
        id: selectorLoader
        anchors {
            left: titleText.right
            leftMargin: 12
            top: parent.top
            bottom: parent.bottom
        }
        width: parent.width - titleText.width - titleText.anchors.leftMargin - 12

        sourceComponent: {
            switch(root.displayStyle) {
                case ExportTypeSelector.DisplayStyle.RadioButton:
                    return radioButtonStyle
                case ExportTypeSelector.DisplayStyle.Dropdown:
                    return dropdownStyle
                default:
                    return radioButtonStyle
            }
        }
    }

    // ==================== Radio Button 样式组件 ====================

    Component {
        id: radioButtonStyle

        Row {
            spacing: 45

            // 平面视频 CheckBox
            CheckBox {
                id: videoCheckBox
                text: qsTr("pccut_media_filter_video")
                checked: viewModel.isVideoMode && !viewModel.isDaVinciFormat
                anchors.verticalCenter: parent.verticalCenter

                indicator: Rectangle {
                    implicitWidth: 16
                    implicitHeight: 16
                    anchors.left: videoCheckBox.left
                    anchors.verticalCenter: parent.verticalCenter
                    color: Colors.color_transparent
                    radius: 8
                    Image {
                        anchors.fill: parent
                        source: videoCheckBox.checked
                            ? "qrc:/app_qrc/icons/icon_radio_selected.svg"
                            : "qrc:/icons/icon_radio_button_no.svg"
                        sourceSize: Qt.size(parent.width, parent.height)
                    }
                }

                MouseArea {
                    anchors.fill: videoCheckBox
                    onClicked: {
                        if (!videoCheckBox.checked) {
                            if (viewModel.isDaVinciFormat) {
                                viewModel.exitDaVinciFormat(true)
                            } else {
                                viewModel.isVideoMode = true
                            }
                        }
                    }
                }

                contentItem: Text {
                    text: videoCheckBox.text
                    font.pixelSize: 12
                    color: Colors.color_EEEEEE
                    verticalAlignment: Text.AlignVCenter
                    leftPadding: videoCheckBox.indicator.width
                }
            }

            // 全景视频 CheckBox
            CheckBox {
                id: panoCheckBox
                text: qsTr("pccut_media_panoramic_video")
                checked: viewModel.isPanoramaMode && !viewModel.isDaVinciFormat
                anchors.verticalCenter: parent.verticalCenter

                indicator: Rectangle {
                    implicitWidth: 16
                    implicitHeight: 16
                    anchors.left: panoCheckBox.left
                    anchors.verticalCenter: parent.verticalCenter
                    color: Colors.color_transparent
                    radius: 8
                    opacity: viewModel.canUsePanorama ? 1 : 0.4

                    Image {
                        anchors.fill: parent
                        source: panoCheckBox.checked
                            ? "qrc:/app_qrc/icons/icon_radio_selected.svg"
                            : "qrc:/icons/icon_radio_button_no.svg"
                        sourceSize: Qt.size(parent.width, parent.height)
                    }
                }

                MouseArea {
                    anchors.fill: panoCheckBox
                    hoverEnabled: true
                    onClicked: {
                        if (!panoCheckBox.checked && viewModel.canUsePanorama) {
                            if (viewModel.isDaVinciFormat) {
                                viewModel.exitDaVinciFormat(false)
                            } else {
                                viewModel.isVideoMode = false
                            }
                        }
                    }
                    onEntered: {
                        if (!viewModel.canUsePanorama) {
                            hoverRectangle.visible = true
                        }
                    }
                    onExited: {
                        hoverRectangle.visible = false
                    }
                }

                contentItem: Text {
                    text: panoCheckBox.text
                    font.pixelSize: 12
                    color: viewModel.canUsePanorama ? Colors.color_EEEEEE : Colors.color_444444
                    verticalAlignment: Text.AlignVCenter
                    leftPadding: panoCheckBox.indicator.width
                }
            }

            // TODO: 达芬奇格式选项（CheckBox + 问号图标）— 当前未使用，待确认是否可移除
            Item {
                enabled: viewModel.canUsePanorama
                opacity: viewModel.canUsePanorama ? 1 : 0.4
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: daVinciCheckBox.implicitWidth + (daVinciQuestionMark.visible ? daVinciQuestionMark.width + 4 : 0)
                implicitHeight: daVinciCheckBox.implicitHeight

                CheckBox {
                    id: daVinciCheckBox
                    text: qsTr("pccut_hdr_export_davinci_btn")
                    checked: viewModel.isDaVinciFormat
                    anchors.verticalCenter: parent.verticalCenter

                    indicator: Rectangle {
                        implicitWidth: 16
                        implicitHeight: 16
                        anchors.left: daVinciCheckBox.left
                        anchors.verticalCenter: parent.verticalCenter
                        color: Colors.color_transparent
                        radius: 8
                        Image {
                            anchors.fill: parent
                            source: daVinciCheckBox.checked
                                ? "qrc:/app_qrc/icons/icon_radio_selected.svg"
                                : "qrc:/icons/icon_radio_button_no.svg"
                            sourceSize: Qt.size(parent.width, parent.height)
                        }
                    }

                    MouseArea {
                        anchors.fill: daVinciCheckBox
                        onClicked: {
                            if (!daVinciCheckBox.checked && viewModel.canUsePanorama) {
                                viewModel.isDaVinciFormat = true
                            }
                        }
                    }

                    contentItem: Text {
                        text: daVinciCheckBox.text
                        font.pixelSize: 12
                        color: Colors.color_EEEEEE
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: daVinciCheckBox.indicator.width
                    }
                }

                // 问号图标（选中达芬奇格式时显示）
                Rectangle {
                    id: daVinciQuestionMark
                    visible: viewModel.isDaVinciFormat
                    anchors.left: daVinciCheckBox.right
                    anchors.leftMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    width: 14
                    height: 14
                    color: Colors.color_transparent
                    Image {
                        anchors.fill: parent
                        source: daVinciQuestionMarkArea.containsMouse ? "qrc:/icons/ic_explain.svg" : "qrc:/icons/ic_explain_hover.svg"
                        sourceSize: Qt.size(100, 100)
                    }
                    MouseArea {
                        id: daVinciQuestionMarkArea
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                    }
                    LightToolTip {
                        visible: daVinciQuestionMarkArea.containsMouse
                        x: - (width / 2)
                        z: 9999
                        tip: qsTr("pccut_hdr_export_davinci_tip")
                        width: 410 // DaVinci tooltip needs fixed width for word wrap
                        textWrapMode: Text.WordWrap
                    }
                }
            }

            // 不支持全景的提示图标
            Rectangle {
                id: hoverRectangle
                implicitWidth: 68
                implicitHeight: 16
                anchors.verticalCenter: parent.verticalCenter
                color: Colors.color_transparent
                visible: false

                Image {
                    anchors.fill: parent
                    source: "qrc:/icons/icon_no_support_no_pano.svg"
                    sourceSize: Qt.size(parent.width, parent.height)
                }
            }
        }
    }

    // ==================== Dropdown 样式组件 ====================

    Component {
        id: dropdownStyle

        // 下拉按钮（对齐 ExportResolution/ExportFrameRate 样式）
        Rectangle {
            id: selectionBox
            anchors {
                left: parent.left
                top: parent.top
                bottom: parent.bottom
                right: parent.right
            }

            color: {
                if (dropdownMouseArea.containsMouse) return Colors.color_68696D
                else if (root.isSelecting) return Colors.color_454649
                else return Colors.color_454649
            }
            radius: RadiusConfig.radius_4_8

            Image {
                id: arrowIcon
                anchors {
                    right: parent.right
                    rightMargin: 8
                    verticalCenter: parent.verticalCenter
                }
                width: 20
                height: 20
                source: root.isSelecting
                    ? "qrc:/icons/adjustment/icon_drop_down_menu_collapse.svg"
                    : "qrc:/icons/adjustment/icon_drop_down_menu_expand.svg"
                sourceSize: Qt.size(20, 20)
            }

            Text {
                anchors {
                    left: parent.left
                    leftMargin: 8
                    top: parent.top
                    bottom: parent.bottom
                    right: arrowIcon.left
                }
                text: viewModel.isDaVinciFormat
                    ? qsTr("pccut_hdr_export_davinci_btn")
                    : viewModel.isVideoMode
                        ? qsTr("pccut_media_filter_video")
                        : qsTr("pccut_media_panoramic_video")
                horizontalAlignment: Text.AlignLeft
                verticalAlignment: Text.AlignVCenter
                color: Colors.color_EEEEEE
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }

            MouseArea {
                id: dropdownMouseArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    root.isSelecting = true

                    // 准备下拉选项数据
                    var items = [
                        {
                            title: qsTr("pccut_media_filter_video"),
                            checked: viewModel.isVideoMode && !viewModel.isDaVinciFormat,
                            enabled: true,
                            value: "video"
                        },
                        {
                            title: qsTr("pccut_media_panoramic_video"),
                            checked: viewModel.isPanoramaMode && !viewModel.isDaVinciFormat,
                            enabled: viewModel.canUsePanorama,
                            value: "panorama",
                            tip: viewModel.canUsePanorama ? "" : "qrc:/icons/icon_no_support_no_pano.svg"
                        }
                    ];
                    items.push({
                            title: qsTr("pccut_hdr_export_davinci_btn"),
                            checked: viewModel.isDaVinciFormat,
                            enabled: viewModel.canUsePanorama,
                            value: "davinci",
                            tip: viewModel.canUsePanorama ? "" : "qrc:/icons/icon_no_support_no_pano.svg",
                            question: qsTr("pccut_hdr_export_davinci_tip")
                        });

                    dropdown.show(selectionBox, items)
                }
            }
        }
    }

    // ==================== 通用下拉面板 ====================

    ExportDropdown {
        id: dropdown

        onItemSelected: function(index, itemData) {
            root.isSelecting = false
            if (itemData.value === "davinci") {
                viewModel.isDaVinciFormat = true
            } else if (viewModel.isDaVinciFormat) {
                viewModel.exitDaVinciFormat(itemData.value === "video")
            } else {
                viewModel.isVideoMode = (itemData.value === "video")
            }
        }

        onCloseSignal: {
            root.isSelecting = false
        }
    }
}
