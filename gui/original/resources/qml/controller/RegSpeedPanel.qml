import QtQuick 2.15
import Config 1.0
import QtQuick.Controls
import Nova 1.0
import MediaTypeModel 1.0
import QtQuick.Window 2.15
import Controls 1.0

/**
  * @details 【常规变速】界面（nova SpeedViewModel 驱动）
  * 普通变速滑杆 + 超级慢动作开关（supportsSuperSlow 门控）。
  */
Rectangle {
    id: root
    // nova 变速 VM
    property SpeedViewModel viewModel
    property int currentSeedTypeIndex: viewModel.superSlowEnable ? 2 : (viewModel.isCurveSpeed ? 1 : 0)
    property bool showDivideLine: true
    // 滑杆抬手信号
    signal speedSliderSignal(double newRegSpeed)

    anchors.fill: parent
    color: Colors.color_content_area_background

    Connections {
        target: globalSignal
        function onEnableSuperSlowByGuide() {
            if (viewModel && viewModel.hasClip) {
                viewModel.superSlowEnable = true
            }
        }
    }

    // 顶部分割线
    Rectangle {
        color: Colors.color_141414
        width: parent.width
        height: 1
        visible: showDivideLine
    }

    ScrollView {
        id: scrollView
        anchors.fill: parent
        anchors.topMargin: showDivideLine ? 16 : 0
        bottomPadding: 20
        ScrollBar.vertical.policy: ScrollBar.AlwaysOff
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        clip: true
        Rectangle {
            anchors.fill: textLabel
            color: Colors.color_transparent
        }

        // 常规变速
        Item {
            id: textLabel
            width: scrollView.width
            height: 20
            anchors.left: parent.left
            anchors.leftMargin: 12
            clip: true
            Text {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignLeft
                font {
                    pixelSize: 12
                }
                color: Colors.color_EEEEEE
                text: qsTr("pccut_panel_speed_double")
            }
            MouseArea {
                anchors.fill: parent
                onDoubleClicked: {
                    var speed = 1.0;
                    if (!CommonUtils.isNull(viewModel) && viewModel.hasClip) {
                        var matched = viewModel.speedForBulletTimeVideo();
                        if (Math.abs(matched - 1.0) > 1e-6) speed = matched;
                        viewModel.updateRegSpeed(speed);
                    }
                    speedSliderSignal(speed);
                }
            }
        }
        // 滑杆
        SpeedSlider {
            id: speedSlider
            anchors {
                left: parent.left
                top: textLabel.bottom
                right: parent.right
                rightMargin: 12
            }
            height: 40
            viewModel: root.viewModel

            onPressedSingal: {
                if (!CommonUtils.isNull(viewModel) && viewModel.hasClip) {
                    viewModel.updateRegSpeed(speedSlider.speed);
                }
                speedSliderSignal(speedSlider.speed);
            }

            onSpeedChanged: {
                if (Math.abs(speedSlider.speed - 1) < 1e-10) {
                    return;
                }
                currentSeedTypeIndex = 0;
            }
        }

        // 智能补帧开关（位于速度滑杆与超慢区之间，仅 macOS）
        Item {
            id: smartFrameItem
            anchors {
                top: speedSlider.bottom
                topMargin: visible ? 8 : 0
                left: textLabel.left
                right: parent.right
                rightMargin: 12
            }
            visible: viewModel.supportsSmartFrame
            height: visible ? 16 : 0

            HoverableText {
                id: smartFrameText
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 36 - smartFrameSwitch.width
                cursorChanged: false
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignLeft
                font {
                    pixelSize: 11
                    weight: Font.Medium
                }
                lineHeight: 15
                lineHeightMode: Text.FixedHeight
                color: Colors.color_999999
                opacity: smartFrameSwitch.isEnabled ? 1 : 0.2
                text: qsTr("pccut_speed_frame_filler_btn")
            }

            Rectangle {
                id: smartFrameTipBtn
                anchors.left: smartFrameText.left
                anchors.leftMargin: Math.min(smartFrameText.implicitWidth, smartFrameText.width) + 4
                anchors.verticalCenter: smartFrameText.verticalCenter
                width: 14
                height: 14
                color: Colors.color_transparent
                Image {
                    anchors.fill: parent
                    source: !smartFrameSwitch.enabled
                            ? "qrc:/icons/ic_explain_disable.svg"
                            : (smartFrameTipMouseArea.containsMouse ? "qrc:/icons/ic_explain.svg" : "qrc:/icons/ic_explain_hover.svg")
                    sourceSize: Qt.size(14, 14)
                }
                MouseArea {
                    id: smartFrameTipMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                }
                Loader {
                    id: smartFrameTipLoader
                    active: smartFrameTipMouseArea.containsMouse
                    sourceComponent: Popup {
                        id: smartFrameTip
                        parent: smartFrameTipBtn
                        x: (smartFrameTipBtn.width - width) / 2
                        y: smartFrameTipBtn.height + 4
                        width: Math.min(smartFrameTipText.implicitWidth, 347)
                        height: smartFrameTipText.implicitHeight + 12
                        padding: 0
                        closePolicy: Popup.NoAutoClose
                        visible: true

                        background: Rectangle {
                            radius: 4
                            color: Colors.color_19191A
                            border.color: Colors.color_454649
                            border.width: 1
                        }

                        contentItem: Text {
                            id: smartFrameTipText
                            text: qsTr("pccut_speed_frame_filler_btn_tip")
                            color: Colors.color_EEEEEE
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                            horizontalAlignment: Text.AlignLeft
                            verticalAlignment: Text.AlignVCenter
                            leftPadding: 8
                            rightPadding: 8
                        }
                    }
                }
            }

            LightBaseSwitch {
                id: smartFrameSwitch
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                // 常规变速慢速(speed<1)且帧率 >=30 才允许开补帧（NTSC 帧率向上取整放行）
                enabled: viewModel ? (viewModel.regSpeed < 1 && Math.ceil(viewModel.mediaFps) >= 30) : false
                checked: viewModel ? viewModel.smartFrameInterpolationEnabled : false

                onToggledSignal: {
                    if (!smartFrameSwitch.enabled) {
                        smartFrameSwitch.checked = viewModel ? viewModel.smartFrameInterpolationEnabled : false
                        return
                    }
                    viewModel.smartFrameInterpolationEnabled = smartFrameSwitch.checked
                    if (smartFrameSwitch.checked) {
                        toast.showToast(qsTr("pccut_speed_frame_filler_success"))
                    }
                }

                Connections {
                    target: viewModel
                    function onSmartFrameInterpolationEnabledChanged() {
                        smartFrameSwitch.checked = viewModel.smartFrameInterpolationEnabled
                    }
                    function onRegSpeedChanged() {
                        // 慢速切到 >=1 自动关闭补帧
                        Qt.callLater(function() {
                            if (viewModel.regSpeed >= 1 && viewModel.smartFrameInterpolationEnabled)
                                viewModel.smartFrameInterpolationEnabled = false
                        })
                    }
                }
            }
        }

        Rectangle{
            id: splitLine
            visible: viewModel.supportsSuperSlow
            width: parent.width - 12 * 2
            height: 1
            color: Colors.color_333333
            anchors.top: smartFrameItem.bottom
            anchors.topMargin: 8
            anchors.left: parent.left
            anchors.leftMargin: 12
        }

        // 超级慢动作面板
        SuperSlowSettingView {
            id: superSlowSetting
            viewModel: root.viewModel
            visible: viewModel.supportsSuperSlow
            width: parent.width - 24
            // 实际内容: checkBoxItem(16) + 16 + vagueDirect(24) + 16 + range(24) = 96
            height: 96
            anchors{
                top: splitLine.bottom
                topMargin: 16
                left: textLabel.left
            }
        }
    }
}
