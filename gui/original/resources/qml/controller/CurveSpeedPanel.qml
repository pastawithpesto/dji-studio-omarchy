import QtQuick 2.15
import Config 1.0
import QtQuick.Controls
import Nova 1.0
import MediaTypeModel 1.0
import Controls 1.0
import app_qrc 1.0
/**
  * @details 【变速曲线】界面（nova SpeedViewModel 驱动）
  * 预设 GridView + 曲线编辑区 CurveSpeedDetailView。
  */
Rectangle {
    id: root
    // nova 变速 VM
    property SpeedViewModel viewModel
    color: Colors.color_content_area_background

    signal speedCurveChanged(var points)

    // 预设列表模型（VM 提供 name + i18n key）
    property var listModel: viewModel ? viewModel.listModel() : []

    Connections {
        target: viewModel

        function onCurveTemplateChanged() {
            curveSpeedDetailView.refreshPanel(true);
            if (gridView.currentIndex !== viewModel.curveTemplate) {
                gridView.syncingFromVm = true;
                gridView.currentIndex = viewModel.curveTemplate;
                gridView.syncingFromVm = false;
            }
        }
        function onCurvePointsChanged() {
            curveSpeedDetailView.refreshPanel(false);
        }
        function onCurveSpeedChanged() {
            speedCurveChanged(viewModel.curvePoints);
        }
    }

    anchors.fill: parent

    ScrollView {
        id: scrollView
        anchors.fill: parent
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: ScrollBar.AlwaysOff
        clip: true
        Component.onCompleted: {
            contentItem.boundsBehavior = Flickable.StopAtBounds
        }
        contentItem: Flickable {
            id: flickable
            interactive: !curveSpeedDetailView.mousePressed
            contentWidth: scrollView.width
            contentHeight: contentContainer.height
            Column {
                id: contentContainer
                width: scrollView.width
                spacing: 6

                // 显示曲线变速预设场景
                GridView{
                    id: gridView
                    property bool initialized: false
                    // VM 回灌 currentIndex 期间为 true。
                    property bool syncingFromVm: false
                    interactive: false
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 6
                    height: contentHeight
                    flow: GridView.FlowLeftToRight
                    cellWidth: 55+12
                    cellHeight: 87
                    model: root.listModel
                    onCurrentIndexChanged: {
                        if (!initialized) return;
                        if (syncingFromVm) return;  // 回灌同步不下发命令
                        curveSpeedDetailView.resetDragState()
                        viewModel.applyCurveTemplate(currentIndex)
                    }
                    delegate: Rectangle{
                        id: outRect
                        width: gridView.cellWidth
                        height: gridView.cellHeight
                        color: Colors.color_content_area_background

                        property bool isDefault: index === 0
                        property bool isDisabled: !viewModel.isSupportApplyCurveSpeed && !isDefault

                        Rectangle {
                            id: image
                            radius: RadiusConfig.radius_4_88
                            width: 55
                            height: 55
                            anchors.top: parent.top
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: {
                                if (outRect.isDisabled) {
                                    return Colors.color_button_background_normal;
                                }
                                return mouseArea.containsMouse ? Colors.color_button_background_hovered : Colors.color_button_background_normal;
                            }

                            Image {
                                width: 40
                                height: 40
                                anchors.centerIn: parent
                                source: {
                                    var suffix = "";
                                    if (outRect.isDisabled) {
                                        suffix = "_disabled";
                                    } else if (gridView.currentIndex === index) {
                                        suffix = "_clicked";
                                    }
                                    return "qrc:/icons/curveSpeed/ic_curve_" + (gridView.model[index].name || "default") + suffix + ".svg";
                                }
                                sourceSize: Qt.size(40, 40)
                            }
                            MouseArea{
                                id: mouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    if (outRect.isDisabled) {
                                        toast.showToast(qsTr("pccut_speed_10f"));
                                    } else {
                                        gridView.currentIndex = index;
                                    }
                                }
                            }
                        }

                        HoverableText {
                            id: text
                            text: qsTr(gridView.model[index].key)
                            anchors.top: image.bottom
                            anchors.topMargin: 5
                            font.pixelSize: 11
                            color: Colors.color_666666
                            anchors.horizontalCenter: parent.horizontalCenter
                            maxTextWidth: image.width
                            cursorChanged: false
                            noWarp: true
                            lineCount: 1
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                    Component.onCompleted: {
                        currentIndex = viewModel.curveTemplate;
                        initialized = true;
                    }

                }

                // 变速控制曲线
                Item{
                    id: detailView
                    anchors {
                        left: parent.left
                        leftMargin: 12
                        right: parent.right
                        rightMargin: 12
                    }
                    height: 198
                    visible: viewModel ? viewModel.curveTemplate !== 0 : false
                    CurveSpeedDetailView{
                        id: curveSpeedDetailView
                        points: viewModel.curvePoints
                        visible: viewModel.curveTemplate !== 0
                        property var viewModel: root.viewModel
                        totalDuration: viewModel.curveTotalDuration
                        clipStart: viewModel.curveClipStart
                        clipEnd: viewModel.curveClipEnd
                        originalDuration: viewModel.sourceDuration
                        targetDuration: viewModel.targetDuration
                        currentPlayPosition: viewModel.currentPlayPosition

                        Component.onCompleted: {
                            refreshPanel(true);
                        }

                        onPointsChanged: {
                            Qt.callLater(function() {
                                if (!viewModel) return;
                                if (JSON.stringify(points) !== JSON.stringify(viewModel.curvePoints)) {
                                    viewModel.updateChangedPoints(points);
                                }
                            });
                        }
                    }
                }

                // 智能补帧开关（仅选中曲线且机型支持时显示，样式与常规变速面板一致）
                Item {
                    id: smartFrameItem
                    anchors {
                        left: parent.left
                        leftMargin: 12
                        right: parent.right
                        rightMargin: 12
                    }
                    visible: viewModel ? (viewModel.curveTemplate !== 0 && viewModel.supportsSmartFrame) : false
                    height: visible ? 30 : 0

                    Item {
                        id: smartFrameRow
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 16

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
                            // 曲线含 y<1 慢速点且帧率 >=30 才允许开补帧（NTSC 帧率向上取整放行）
                            enabled: viewModel ? (viewModel.hasSlowPoint && Math.ceil(viewModel.mediaFps) >= 30) : false
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
                                function onHasSlowPointChanged() {
                                    if (!viewModel.hasSlowPoint && viewModel.smartFrameInterpolationEnabled)
                                        viewModel.smartFrameInterpolationEnabled = false
                                }
                            }
                        }
                    }
                }

                // 底部添加一些空白，确保内容完全可见
                Item {
                    width: 1
                    height: 10
                }
            }
        }
    }
}
