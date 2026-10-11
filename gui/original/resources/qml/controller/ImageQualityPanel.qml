import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls
//import QtQuick.Controls.Styles 1.4
import QtQuick.Controls.Material 2.15
import Config 1.0
import Controls 1.0
import Nova 1.0
import VideoFragmentViewModel 1.0
import LutListModel 1.0
import QtQuick.Layouts 1.3
import app_qrc 1.0
import UsedFunctionManager 1.0
import ProjectSettingsInfo 1.0

/**
 *  @File        : FilterSettingPanel.qml
 *  @Brief       : 画面、LUT, 滤镜调节UI
 *  @Details     : 详细说明
 *  @Author      : pansy.guo
 *  @Date        : 2024-03-08 14:12:39
 */

Rectangle {
    id: root
    anchors.fill: parent
    color: Colors.color_content_area_background

    property VideoFragmentViewModel viewModel
    // 素材是否携带 DLog2 元数据；供 LutSetting 的 D-LOG 2 风格 Natural/Clear 门控
    property bool hasDLog2Metadata: false
    property bool isShowStylePanel : false
    property bool isDefaultStatus : true

    property real maxItemTextWidth: Math.max(brightnessSetting.maxItemTextWidth, colorsSetting.maxItemTextWidth, effectSetting.maxItemTextWidth)

    property real textLeftPadding: Math.max(70, maxItemTextWidth + 12)

    property bool isSupportLensProtective: !CommonUtils.isNull(viewModel) && viewModel.hasFragment && viewModel.videoFragment.supportLensProtective
    property bool isSupportLutUnderWater: underWaterVM.hasClip && underWaterVM.isSupport

    ScrollView {
        id: scrollView
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            bottom: bottomFixedArea.top  // 底部连接到固定区域
            leftMargin:12
            rightMargin:12
            topMargin: 0
        }
        // 隐藏滚动条
        ScrollBar.vertical.policy: ScrollBar.AlwaysOff
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        clip: true
        Component.onCompleted: {
            contentItem.boundsBehavior = Flickable.StopAtBounds
        }
        contentItem: Flickable {
            id: flickable
            contentHeight: columnLayout.implicitHeight
            onContentYChanged: {
                 waterMarkSetting.closeAllPopup();
            }
            ColumnLayout {
                id: columnLayout
                spacing: 15.5
                anchors {
                    left: parent.left
                    leftMargin: 0
                    top: parent.top
                }
                width: scrollView.width
                LutSetting {
                    id: lutSetting
                    Layout.preferredWidth: width
                    Layout.preferredHeight: height
                    viewModel: root.viewModel
                    hasDLog2Metadata: root.hasDLog2Metadata
                }

                Rectangle {
                    visible: lutSetting.visible && isSupportLutUnderWater
                    height: 1
                    Layout.fillWidth: true
                    color: Colors.color_333333
                }

                //水下增强区域
                UnderWaterEnhanceSetting{
                    id: underWaterEnhanceSetting
                    visible: isSupportLutUnderWater
                    Layout.preferredWidth: width
                    Layout.preferredHeight: height
                    viewModel: underWaterVM
                }

                // [NOVA] 水下增强启用态/颜色矫正/效果增强走 nova
                UnderWaterFilterAdjust { id: underWaterVM }


                Rectangle {
                    visible: tonalEnhanceControl.visible
                    height: 1
                    Layout.fillWidth: true
                    color: Colors.color_333333
                }

                // 影调增强
                Item {
                    id: tonalEnhanceControl
                    Layout.fillWidth: true
                    height: 16
                    visible: tonalVM.hasClip && tonalVM.isSupportDevice

                    // [NOVA] 影调增强启用态与设备/素材能力门控均走 nova
                    TonalEnhanceViewModel { id: tonalVM }

                    LightCheckBox {
                        id:checkBoxTonalEnhance
                        maxTextWidth: root.width - 180
                        text: qsTr("pccut_single_fragment_effects_tone_enhancement")
                        checked: tonalVM.isEnable
                        anchors.verticalCenter: parent.verticalCenter
                        isDisabled: !tonalVM.isSupport
                        MouseArea {
                            anchors.fill: checkBoxTonalEnhance
                            onClicked: {
                                if(checkBoxTonalEnhance.isDisabled){
                                    toast.showToast(qsTr("pccut_tone_enhancement_toast"), "playerPanel");
                                    return;
                                }

                                tonalVM.isEnable = !checkBoxTonalEnhance.checked
                            }
                        }
                    }
                    Image {
                        id:tonalEnhanceDescIcon
                        anchors{
                            left: parent.left
                            leftMargin: checkBoxTonalEnhance.width - 6
                            verticalCenter: parent.verticalCenter
                        }
                        source: tonalEnhanceDescIconMouseArea.containsMouse ? "qrc:/icons/ic_explain.svg" : "qrc:/icons/ic_explain_hover.svg"
                        sourceSize: Qt.size(14, 14)
                        MouseArea {
                            id: tonalEnhanceDescIconMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                        }
                    }

                    ColorDiffClearTips {
                        id: tonalEnhanceTips
                        tipText: qsTr("pccut_tone_enhancement_tooltip")
                        property real offset: {

                            return (tonalEnhanceDescIcon.x + tonalEnhanceDescIcon.width / 2) / width > 0.6 ? 50 : 0
                        }

                        arrowLeftMargin: Math.min(checkBoxTonalEnhance.width - 6,  (tonalEnhanceTips.width - tonalEnhanceDescIcon.width) / 2 + offset) + tonalEnhanceDescIcon.width / 2
                        width: parent.width
                        height: 28
                        anchors {
                            left: tonalEnhanceDescIcon.left
                            leftMargin: Math.max(-checkBoxTonalEnhance.width + 6,  -(tonalEnhanceTips.width - tonalEnhanceDescIcon.width) / 2 - offset)
                            bottom: tonalEnhanceDescIcon.top
                        }
                        visible: tonalEnhanceDescIconMouseArea.containsMouse
                    }

                }


                Rectangle {
                    visible: true
                    height: 1
                    Layout.fillWidth: true
                    color: Colors.color_333333
                }

                Item{
                    id: imageAdControl
                    property bool isDisable: !checkBox2.checked
                    Layout.fillWidth: true
                    height: 20

                    LightCheckBox {
                        id:checkBox2
                        maxTextWidth: root.width - 180
                        text: qsTr("pccut_panel_adjus")
                        checked: brightnessModel.isEnable
                        anchors.verticalCenter: parent.verticalCenter
                        Component.onCompleted:
                        {
                            // 从业务层获取功能实际状态
                            var projectId = draftManager.activeProjectEnvId();
                            var isFuncExist = UsedFunctionManager.hasFunction(projectId,UsedFunctionManager.EditorFunctionType.ADJUST);

                            if(!isFuncExist && checked)
                            {
                                UsedFunctionManager.addFunction(projectId,UsedFunctionManager.EditorFunctionType.ADJUST);
                            }
                        }
                        MouseArea {
                            anchors.fill: checkBox2
                            onClicked: {
                                var newChecked = !checkBox2.checked;
                                brightnessModel.isEnable = newChecked
                            }
                        }
                    }

                    Rectangle{
                        id: resetBtn
                        property bool isHovered: false
                        anchors{
                            right: parent.right
                        }
                        color: Colors.color_transparent
                        width: 20
                        height: 20
                        anchors.verticalCenter: parent.verticalCenter
                        Image {
                            anchors.fill: parent
                            source: (imageAdControl.isDisable || root.isDefaultStatus) ? "qrc:/icons/ic_reset.svg" :  resetBtn.isHovered ? "qrc:/icons/ic_reset_hover.svg" : "qrc:/icons/ic_reset.svg"
                            sourceSize: Qt.size(parent.width, parent.height)
                            opacity: (imageAdControl.isDisable || root.isDefaultStatus) ? 0.2 : 1
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: resetBtn.isHovered = true
                            onExited: resetBtn.isHovered = false
                            onClicked: {
                                if(!imageAdControl.isDisable && !root.isDefaultStatus) {
                                    brightnessModel.reset();
                                    eventTracker.trackEvent("pccut_panel_basic_correction_reset")
                                }
                            }
                        }
                    }
                }


                FilterInfoSetting {
                    id: brightnessSetting
                    sliderLeft: textLeftPadding
                    isDisable: imageAdControl.isDisable
                    Layout.preferredWidth: width
                    Layout.preferredHeight: height
                    itemVerticalSpacing: 12
                    headerTextColor: Colors.color_EEEEEE
                    subTitleTextColor: Colors.color_999999
                    subTitleTextValueColor: Colors.color_999999
                    adjustModel: BrightnessFilterAdjust {
                        id: brightnessModel
                    }
                    onIsDefaultStatusChanged: {
                        root.checkIfDefaultStatus();
                    }
                }

                Rectangle {
                    visible: true
                    height: 1
                    Layout.fillWidth: true
                    color: Colors.color_333333
                }

                FilterInfoSetting {
                    id: colorsSetting
                    sliderLeft: textLeftPadding
                    isDisable: imageAdControl.isDisable
                    Layout.preferredWidth: width
                    Layout.preferredHeight: height
                    itemVerticalSpacing: 12
                    headerTextColor: Colors.color_EEEEEE
                    subTitleTextColor: Colors.color_999999
                    subTitleTextValueColor: Colors.color_999999
                    adjustModel: ColorsFilterAdjust {
                        id: colorsModel
                    }
                    onIsDefaultStatusChanged: {
                        root.checkIfDefaultStatus();
                    }
                }

                Rectangle {
                    visible: true
                    height: 1
                    Layout.fillWidth: true
                    color: Colors.color_333333
                }

                FilterInfoSetting {
                    id: effectSetting
                    sliderLeft: textLeftPadding
                    isDisable: imageAdControl.isDisable
                    Layout.preferredWidth: width
                    Layout.preferredHeight: height
                    itemVerticalSpacing: 12
                    headerTextColor: Colors.color_EEEEEE
                    subTitleTextColor: Colors.color_999999
                    subTitleTextValueColor: Colors.color_999999
                    adjustModel: EffectFilterAdjust {
                        id: effectModel
                    }
                    onIsDefaultStatusChanged: {
                        root.checkIfDefaultStatus();
                    }
                }

                Rectangle {
                    height: 1
                    Layout.fillWidth: true
                    color: Colors.color_333333
                }

                WaterMarkSetting {
                    id: waterMarkSetting
                    Layout.preferredWidth: width
                    Layout.preferredHeight: height
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 0
                }
            }
        }

    }

    Rectangle {
        id: bottomFixedArea
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        height: 32
        color: Colors.color_262626

        // 底部固定的应用到全局按钮
        Rectangle{
            id: bottomAllUseBtn
            property bool isHovered: false
            color: bottomAllUseBtn.isHovered ? Colors.color_414344 : Colors.color_353738
            radius: RadiusConfig.radius_4_88
            opacity: 1
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin:12
            width: 73
            height: 20
            
            Text{
                id: bottomAllUseBtnText
                text: qsTr("pccut_panel_colorrecovery_applyglobally")
                anchors.centerIn: parent
                font.pixelSize: 11
                font.weight: Font.Medium
                color: Colors.color_EEEEEE
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                enabled: true
                onEntered: bottomAllUseBtn.isHovered = true
                onExited: bottomAllUseBtn.isHovered = false
                onClicked: {
                    brightnessModel.applyToAll();
                    lutSetting.applyLutToAll();
                    underWaterVM.applyToAll();
                    tonalVM.applyToAll();
                    toast.showToast(qsTr("pccut_adjust_applied_all"), "tracks");
                }
            }
        }
    }

    function checkIfDefaultStatus() {
        root.isDefaultStatus = brightnessSetting.isDefaultStatus && colorsSetting.isDefaultStatus && effectSetting.isDefaultStatus
    }
}
