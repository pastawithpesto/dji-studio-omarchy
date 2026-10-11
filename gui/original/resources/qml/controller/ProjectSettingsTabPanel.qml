import QtQuick 2.15
import QtQuick.Controls
import Config 1.0
import Controls 1.0
import QtQuick.Layouts 1.15
import ProjectSettingsInfo 1.0
import VideoConfig 1.0
import Nova 1.0
import Qt5Compat.GraphicalEffects
import app_qrc 1.0

// 项目信息面板
Rectangle {
    id: root
    color: Colors.color_content_area_background

    property real hItemMargin: 16
    property real vItemMargin: 16

    property int colorSpaceType: 0
    // 等待 ProjectSettingsEditorPopup 完全关闭后再开启 switchHdrPopup 的标记
    property bool _pendingSwitchHdrOpen: false

    function showEditorPop() {
        editorManager.pause();
        openEditorPop();
    }

    // 编辑弹窗的统一入口。重新打开编辑弹窗意味着上一次待确认的色彩空间切换已被放弃，
    // 必须清掉 _pendingSwitchHdrOpen，否则这一次即使只改画幅，
    // 残留的标记也会在弹窗关闭时再弹一次 HDR 提示
    function openEditorPop() {
        _pendingSwitchHdrOpen = false;
        editorPopLoader.sourceComponent = editorPop;
    }

    ProjectSettingsInfo {
        id: projectSettingsInfo

        // name/useMaterialProxy 已自权威读 legacy 并自反应，无需 editorManager 绑定
        composePath: editorManager.draftDir
        canvasType: editorManager.canvasType
        colorSpaceType: editorManager.colorSpaceType
        fps: editorManager.fps
    }

    // 顶部分割线
    Rectangle {
        color: Colors.color_141414
        width: parent.width
        height: 1
    }

    // 实在不知道应该如何处理左侧标签的对齐，所以全部展开了，没有用任何repeater之类的逻辑
    ScrollView {
        id: scrollView
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.topMargin: 16
        bottomPadding: 20

        ScrollBar.vertical.policy: ScrollBar.AlwaysOff
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        Item {
            property real labelGuide: Math.max(projectNameTitleText.width, savePathTitleText.width, canvasTitleText.width, proxyModeTitleText.width) + hItemMargin
            anchors.fill: parent

            // 项目名称
            HoverableText {
                id: projectNameTitleText
                color: Colors.color_999999
                font.pixelSize: 12
                text: qsTr("pccut_project_info_name")
            }
            Text {
                id: projectNameValueText
                color: Colors.color_EEEEEE
                anchors {
                    left: parent.left
                    leftMargin: parent.labelGuide
                    right: parent.right
                    top: projectNameTitleText.top
                }
                wrapMode: Text.WrapAnywhere
                font.pixelSize: 12
                text: projectSettingsInfo.name
            }

            // 保存位置
            HoverableText {
                id: savePathTitleText
                anchors {
                    top: projectNameValueText.bottom
                    topMargin: vItemMargin
                }
                color: Colors.color_999999
                font.pixelSize: 12
                text: qsTr("pccut_project_info_path")
            }
            Text {
                id: savePathValueText
                color: Colors.color_EEEEEE
                anchors {
                    left: parent.left
                    leftMargin: parent.labelGuide
                    right: parent.right
                    top: savePathTitleText.top
                }
                wrapMode: Text.WrapAnywhere
                font.pixelSize: 12
                text: projectSettingsInfo.composePath
            }

            // 比例
            HoverableText {
                id: canvasTitleText
                anchors {
                    top: savePathValueText.bottom
                    topMargin: vItemMargin
                }
                color: Colors.color_999999
                font.pixelSize: 12
                text: qsTr("pccut_player_ratio")
            }
            Text {
                id: canvasValueText
                color: Colors.color_EEEEEE
                anchors {
                    left: parent.left
                    leftMargin: parent.labelGuide
                    right: parent.right
                    top: canvasTitleText.top
                }
                wrapMode: Text.WrapAnywhere
                font.pixelSize: 12
                text: projectSettingsInfo.canvasTypeName
            }

            // 色彩空间
            HoverableText {
                id: colorSpaceTitleText
                anchors {
                    top: canvasValueText.bottom
                    topMargin: vItemMargin
                }
                color: Colors.color_999999
                font.pixelSize: 12
                visible: !CommonUtils.isWindows()
                text: qsTr("pccut_hdr_project_setting_colorspace_label")
            }
            Text {
                id: colorSpaceValueText
                color: Colors.color_EEEEEE
                anchors {
                    left: parent.left
                    leftMargin: parent.labelGuide
                    right: parent.right
                    top: colorSpaceTitleText.top
                }
                wrapMode: Text.WrapAnywhere
                font.pixelSize: 12
                visible: !CommonUtils.isWindows()
                text: videoConfig.getItemByColorSpaceType(projectSettingsInfo.colorSpaceType)
            }

            // 代理模式
            HoverableText {
                id: proxyModeTitleText
                anchors {
                    top: CommonUtils.isWindows() ? canvasValueText.bottom : colorSpaceValueText.bottom
                    topMargin: vItemMargin
                }
                color: Colors.color_999999
                font.pixelSize: 12
                text: qsTr("pccut_project_proxy")
            }
            Text {
                id: proxyModeValueText
                color: Colors.color_EEEEEE
                anchors {
                    left: parent.left
                    leftMargin: parent.labelGuide
                    right: parent.right
                    top: proxyModeTitleText.top
                }
                wrapMode: Text.WrapAnywhere
                font.pixelSize: 12
                text: getProxyText()

                function getProxyText() {
                    const waitCount = agencyManager.waitingAgencyCount;
                    const finishCount = agencyManager.finishAgencyCount;
                    const proxyOpen = projectSettingsInfo.useMaterialProxy;
                    return !proxyOpen ? qsTr("pccut_project_proxy_noproxy") : (waitCount == 0 ? qsTr("pccut_project_modify_proxy_open") : qsTr("pccut_project_proxy_transcoding") + " " + finishCount + "/" + (waitCount + finishCount))
                }
            }
            Image {
                id: iconExplain
                width: 16
                height: 16
                sourceSize: Qt.size(width, height)
                anchors {
                    right: parent.right
                    verticalCenter: proxyModeValueText.verticalCenter
                }
                source: iconExplainArea.containsMouse ? "qrc:/icons/ic_explain.svg" : "qrc:/icons/ic_explain_hover.svg"

                MouseArea {
                    id: iconExplainArea
                    anchors.fill: parent
                    hoverEnabled: true
                }
            }
            
            Item {
                id: explainPop
                anchors {
                    bottom: iconExplain.top
                    right: iconExplain.right
                    bottomMargin: 4
                }
                
                width: parent.width
                height: dynamicText.implicitHeight + 12
                visible: iconExplainArea.containsMouse

                LightClipRectangle {
                    anchors.fill: parent
                    clip: true
                    radius: [4,4,4,4]

                    ShaderEffectSource {
                        id: shaderSource
                        sourceItem: mainPanel
                        sourceRect: Qt.rect(explainPop.mapToItem(mainPanel, 0, 0).x, explainPop.mapToItem(mainPanel, 0, 0).y, explainPop.width, explainPop.height)
                        width: parent.width
                        height: parent.height
                        live: true
                        smooth: true
                    }

                    // 高斯调节
                    FastBlur {
                        anchors.fill: parent
                        source: shaderSource
                        radius: 48
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: Colors.color_141414_85
                        border.color: Colors.color_444444
                        border.width: 0.5
                        radius: 4
                    }
                }
                
                Text {
                    id: dynamicText
                    width: parent.width - 16
                    text: qsTr("pccut_project_proxy_description")
                    color: Colors.color_EEEEEE
                    font.pixelSize: 11
                    wrapMode: Text.WordWrap
                    lineHeight: 15
                    font.letterSpacing: 1
                    lineHeightMode: Text.FixedHeight
                    anchors.centerIn: parent
                }
            }
            Canvas {
                anchors {
                    top: explainPop.bottom
                    horizontalCenter: iconExplain.horizontalCenter
                    topMargin: -0.5
                }
                width: 6
                height: 4
                property int radius: 4
                onPaint: {
                    var ctx = getContext("2d");
                    // 设置颜色
                    ctx.fillStyle = Colors.color_141414_85
                    ctx.lineWidth = 0.5
                    
                    ctx.strokeStyle = Colors.color_161616
                    ctx.beginPath()
                    ctx.moveTo(0, 0)
                    ctx.lineTo(width, 0)
                    ctx.lineTo(width / 2, height)
                    ctx.fill()
                    ctx.stroke()
                    
                    ctx.strokeStyle = Colors.color_444444
                    ctx.beginPath()
                    ctx.moveTo(0, 0)
                    ctx.lineTo(width / 2, height)
                    ctx.lineTo(width, 0)
                    ctx.stroke()
                    
                }
            }
        }
    }

    Rectangle {
        width: modifyButtomAreaText.width + 24 * 2
        height: 25
        radius: RadiusConfig.radius_4_88
        color: modifyButtomArea.containsMouse ? Colors.color_414344 : Colors.color_353738

        anchors {
            right: parent.right
            bottom: parent.bottom
            rightMargin: 16
            bottomMargin: 16
        }

        Text {
            id: modifyButtomAreaText
            color: Colors.color_EEEEEE
            font.pixelSize: 12
            text: qsTr("pccut_project_modify")
            anchors.centerIn: parent
        }

        MouseArea {
            id: modifyButtomArea
            hoverEnabled: true
            anchors.fill: parent
            onClicked: {
                editorManager.pause();
                openEditorPop();
                eventTracker.trackEvent("pccut_project_setting_click")
            }
        }
    }

    Component {
        id: editorPop
        ProjectSettingsEditorPopup {
            anchors.centerIn: Overlay.overlay
        }
    }

    // 说明：undo/redo 的 hdrChanged 会被 HdrController 接住并调用 setColorSpace，
    // 后者会发出 editorManager.colorSpaceTypeChanged，projectSettingsInfo.colorSpaceType
    // 的 binding 会自动跟着刷新。这里不再直接赋值，避免打断 binding 后
    // 面板展示值与工程真实色彩空间长期不一致（参考下方 canvasType 的同类说明）。

    ConfirmPopup {
        id: switchHdrPopup
        title: qsTr("pccut_hdr_project_setting_switch_to_hdr_dialog_title")
        text: qsTr("pccut_draft_exception_popup_title")
        leftButtonText: qsTr("pccut_draft_exception_popup_cancel")
        rightButtonText: qsTr("pccut_draft_exception_popup_yes")

        onLeftButtonClicked: {
            eventTracker.trackEvent("pccut_project_setting_result", {button_name: qsTr("pccut_draft_exception_popup_cancel"),
                                        "from_colorspace": playerPanel.getColorSpaceStr(editorManager.colorSpaceType),
                                        "to_colorspace": playerPanel.getColorSpaceStr(editorManager.colorSpaceType),
                                        "project_colorspace": playerPanel.getColorSpaceStr(editorManager.colorSpaceType),
                                        "has_hdr_display": projectSettingsInfo.isSupportHdr(),
                                    })
        }
        onRightButtonClicked: {
            // 判断基准取 editorManager.colorSpaceType（工程真实值），
            // projectSettingsInfo 仅用于面板展示，不能作为比较依据
            const currentColorSpace = editorManager.colorSpaceType;
            if (colorSpaceType != currentColorSpace) {
                eventTracker.trackEvent("pccut_project_setting_result", {button_name: qsTr("pccut_draft_exception_popup_yes"),
                                            "from_colorspace": playerPanel.getColorSpaceStr(currentColorSpace),
                                            "to_colorspace": playerPanel.getColorSpaceStr(colorSpaceType),
                                            "project_colorspace": playerPanel.getColorSpaceStr(colorSpaceType),
                                            "has_hdr_display": projectSettingsInfo.isSupportHdr(),
                                        })

                // setColorSpace 内部会发出 colorSpaceTypeChanged，
                // projectSettingsInfo.colorSpaceType 的 binding 会自动刷新，无需在此赋值
                playerPanel.setColorDepth(colorSpaceType === VideoConfig.HDR_BT2020_HLG ? 10 : 8)
                playerPanel.setColorSpace(colorSpaceType)
                if (colorSpaceType === VideoConfig.HDR_BT2020_HLG) {
                    Qt.callLater(function() {
                        projectStateController.checkScreenSupportHdr(lightWindow, false)
                    });
                }
            }
        }
    }

    Loader {
        id: editorPopLoader
        onLoaded: {
            if (item) {
                item.closed.connect(function () {
                        editorPopLoader.sourceComponent = null;
                        // closed 在退场动画结束后触发，此时再开启 switchHdrPopup 不会重叠
                        if (root._pendingSwitchHdrOpen) {
                            root._pendingSwitchHdrOpen = false;
                            // 退场动画期间工程色彩空间可能已被其它入口改掉，开之前再核对一次
                            if (root.colorSpaceType !== editorManager.colorSpaceType) {
                                switchHdrPopup.open();
                            }
                        }
                    });
                item.projectSettingsChanged.connect(function (updateInfo) {
                        if (root.onSettingsUpdate(updateInfo)) {
                            item.close();
                        }
                    });
                item.open();
            }
        }
    }

    function onSettingsUpdate(updateInfo) {
        // 这里的业务逻辑参考RecentDraftView.qml
        const newName = updateInfo.name.trim();
        if (CommonUtils.mixedTextLength(newName) > 50) {
            toast.showToast(qsTr("pccut_draft_name_limit"));
            return false;
        }
        if (newName.length <= 0) {
            toast.showToast(qsTr("pccut_draft_name_empty"));
            return false;
        }
        if (newName != projectSettingsInfo.name) {
            const draftIndex = draftManager.currentDraft;
            const draftId = draftManager.findOpenedDraftIdByIndex(draftIndex);
            if (!draftManager.renameDraftById(draftId, newName)) {
                toast.showToast(qsTr("pccut_files_missing_samename"));
                return false;
            }
            // legacy 持久化改名成功后镜像写 nle (运行期影子值)
            projectSettingsInfo.name = newName;
        }
        if (updateInfo.composePath != projectSettingsInfo.composePath) {
            projectSettingsInfo.composePath = updateInfo.composePath;
        }
        if (updateInfo.canvasType != projectSettingsInfo.canvasType) {
            const oldCanvasType = projectSettingsInfo.canvasType;
            // 注意：不直接赋值 projectSettingsInfo.canvasType，避免破坏其与 editorManager.canvasType 的 QML binding。
            // 若直接赋值，binding 断裂后工具栏切换画幅不会再同步到 projectSettingsInfo，
            // 导致下次打开项目设置时比较值相等、无法触发画幅切换。
            // CANVASRATIOTYPE_16_9(5) → CANVASRATIOTYPE_16_9_SETTING(8) 仅是内部标记变更（区分系统默认与用户手动确认），
            // 画幅实际比例未改变，不应触发画幅切换
            if (!(oldCanvasType === VideoConfig.CANVASRATIOTYPE_16_9 &&
                  updateInfo.canvasType === VideoConfig.CANVASRATIOTYPE_16_9_SETTING)) {
                CanvasController.setRatioByCanvasType(updateInfo.canvasType);
            }
        }
        if (updateInfo.fps != projectSettingsInfo.fps) {
            projectSettingsInfo.fps = updateInfo.fps;
        }
        if (updateInfo.useMaterialProxy != projectSettingsInfo.useMaterialProxy) {
            // C++ setter 双写 legacy + nle
            projectSettingsInfo.useMaterialProxy = updateInfo.useMaterialProxy;
        }
        colorSpaceType = updateInfo.colorSpaceType
        // 与工程真实色彩空间比较。projectSettingsInfo.colorSpaceType 只是面板展示值，
        // 用它做基准会在两者不同步时对「只改画幅」这类操作误弹 HDR 提示
        if (colorSpaceType != editorManager.colorSpaceType) {
            if (colorSpaceType == VideoConfig.HDR_BT2020_HLG) { // sdr 切换到 hdr
                switchHdrPopup.title = qsTr("pccut_hdr_project_setting_switch_to_hdr_dialog_title");
                switchHdrPopup.text = qsTr("pccut_hdr_project_setting_switch_to_hdr_dialog_content");
            } else { // hdr 切换到 sdr
                switchHdrPopup.title = qsTr("pccut_hdr_project_setting_switch_to_sdr_dialog_title");
                switchHdrPopup.text = qsTr("pccut_hdr_project_setting_switch_to_sdr_dialog_content");
            }

            root._pendingSwitchHdrOpen = true;
        }
        return true;
    }
}
