import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Dialogs
import Controls 1.0
import Config 1.0
import VideoConfig 1.0
import QtQuick.Layouts 1.15
import Qt5Compat.GraphicalEffects
import ComposePanelSettingModel 1.0
import LightRectangle 1.0
import Qt.labs.platform
import MediaTypeModel 1.0
import "../menubar"
import "../export"
import QmlConstants 1.0
import app_qrc 1.0
import ExportEventReport 1.0
import ExportDataManager 1.0
import UsedFunctionManager 1.0
import MarkPointToolbarViewModel 1.0
import ProjectSettingsInfo 1.0
import Nova 1.0

/**
  * @author: pansy.guo
  * @details 导出设置界面
  * @date: 2024-04-23 11:56:29
  */

LightPopup {
    id: composePopup
    // 保存的文件名的后缀
    property string fileNameSuffix: ".mp4"
    // 选择的分辨率type
    property real selectResolutionType: -1
    // 选择的帧率type
    property real selectFrameRateType: -1
    // 选择的码率type
    property real selectBitrateType: -1
    // 选择导出范围range
    property real selectComposeRange: VideoConfig.COMPOSERANGE_WHOLE
    // 选择导出类型type
    property real selectComposeType: -1
    // 选择的自定义码率
    property real selectBitrateCustom: 30
    // 选择的降噪类型
    property real selectDenoiseType: 0
    property string selectDenoiseTypeName: ""
    //记录当前缩略图的地址
    property string coverpath:""
    // 左边label 最长的
    //property real maxLeftItemTextWidth: Math.max(fileNameText.width, filePathText.width, resolutionNameText.width, frameRateText.width, bitrateText.width) + 16
    // 预览图是否加载成功
    property bool imageLoadSuccess: false
    property real maxLeftItemTextWidth: 0
    property int unifiedFrame: -1
    // 是否支持杜比导出
    property bool isSupportDolbyVision: false
    // 是否选择达芬奇格式（从 composeSetting.mediaExportType 计算）
    readonly property bool isDaVinciFormat: composeSetting.mediaExportType === ComposePanelSettingModel.DaVinci
    // 全局首次进入达芬奇模式时应用最高规格预设，之后不再自动应用
    property bool hasDaVinciApplied: lightSetting.getBool("davinci_defaults_applied", false)
    onIsDaVinciFormatChanged: {
        if (!composePopup.opened) return
        // 全局仅首次 apply，退出不恢复
        if (isDaVinciFormat && !hasDaVinciApplied) {
            Qt.callLater(function() {
                applyDaVinciDefaults()
                hasDaVinciApplied = true
                lightSetting.save("davinci_defaults_applied", true)
            })
        } else {
            // AB off: 原始逻辑——每次进入都 apply，退出时恢复
            if (isDaVinciFormat) {
                Qt.callLater(function() {
                    applyDaVinciDefaults()
                })
            } else {
                Qt.callLater(function() {
                    if (panoCheckBox.checked) {
                        // 退出达芬奇且仍在全景模式，还原全景参数
                        restoreOriginalSettings()
                    } else {
                        // 退出达芬奇且已切换到视频模式，不能用全景参数覆盖
                        // 用进达芬奇前保存的 origState 还原帧率/码率/降噪/色深，保留用户本次会话的修改
                        // 分辨率由 videoCheckBox 的 refreshResolution() 已正确处理，无需重复
                        if (_daVinciOrigState === null) return
                        selectFrameRateType = _daVinciOrigState.frameRateType
                        frameRateChooseBtn.text = _daVinciOrigState.frameRateText
                        selectBitrateType = _daVinciOrigState.bitrateType
                        bitrateChooseBtn.text = _daVinciOrigState.bitrateText
                        selectDenoiseType = _daVinciOrigState.denoiseType
                        selectDenoiseTypeName = _daVinciOrigState.denoiseTypeName
                        denoiseVM.isEnable = _daVinciOrigState.denoiseChecked
                        composeSetting.setColorDepth(_daVinciOrigState.colorDepthChecked ? 10 : 8)
                        _daVinciOrigState = null
                        changeSwitchState()
                        refreshFileMB(true)
                    }
                })
            }
        }
    }

    // 弹框入口标识 0导入按钮进入  1视频轨道右键菜单进入
    property int entranceType : 0
    //项目ID
    property var  projectId: draftManager.activeProjectEnvId()

    modal:false
    Overlay.modal: Rectangle {
        color: Colors.transparent
    }
    parent: Overlay.overlay
    width: parent.width
    height: parent.height
    z: 100

    // background: LightRectangle{
    //     radius: [5,5,5,5]
    //     color: "transparent"
    // }
    ComposePanelSettingModel {
        id: composeSetting
    }

    // 导出画面降噪设置 VM（enable 按项目、type/checked 按全局，导出时作为参数透传）
    ExportDenoiseViewModel {
        id: denoiseVM
    }

    // AB 实验开关：导出交互优化
    property bool abExportOptEnabled: lightSetting.getBool("pccut_export_interaction_opt", false)

    // 导出文件大小预估 VM：时长取 nle 草稿快照，画布尺寸暂读 legacy ProfileModel（替代 EditorManager）
    ExportEstimateViewModel {
        id: exportEstimateVM
    }

    // AB on: 视频/全景模式各自的导出参数内存缓存，切换模式时保留用户选择
    // 仅缓存 refreshResolution/refreshBitrate 会覆盖的值：resolutionType, bitrateType, bitrateCustom
    property var _videoParams: null
    property var _panoParams: null
    // 全景子格式缓存（Panorama=1 / DaVinci=2），-1 表示本次未选择过
    property int cachedPanoFormat: -1

    // 轻量 viewModel，供 ExportFileNameUnified / ExportSavePath 走已验证的 viewModel 链路
    QtObject {
        id: composeExportViewModel
        readonly property bool isSingleMode: true
        readonly property bool isBatchMode: false
        property var fileNameList: [""]
        property bool showSuffix: selectComposeType === 0
        property string fileNameSuffix: composePopup.fileNameSuffix
        property string savePath: ""
        property real estimatedFileSizeMB: videoConfig.estimateComposeFileSizeWithOriginalSize(
            getBitrate(), exportEstimateVM.totalDurationSec)
        readonly property bool enableEventTracking: false
        readonly property string displayFileNames: ""
        readonly property string displayFileNamesTips: ""
        function updateSingleFileName(name) {
            if (fileNameList.length > 0 && fileNameList[0] !== name) {
                fileNameList = [name]
            }
        }
    }

    // 统一读接口：从 viewModel 读取当前保存路径与文件名
    readonly property string currentSavePath: composeExportViewModel.savePath
    readonly property string currentFileName: composeExportViewModel.fileNameList.length > 0 ? composeExportViewModel.fileNameList[0] : ""

    // 磁盘空间实时检测（由 ExportSavePath 驱动）
    readonly property bool pathAccessible: filePathControl.pathAccessible

    // 实时计算当前预估导出大小（MB）
    function currentEstimatedFileSizeMB() {
        if (entranceType === 0) {
            if (selectComposeRange === VideoConfig.COMPOSERANGE_RANGE) {
                syncExportRangeToVM();
                return videoConfig.estimateComposeFileSizeWithOriginalSize(getBitrate(), exportEstimateVM.rangeDurationSec);
            }
            return videoConfig.estimateComposeFileSizeWithOriginalSize(getBitrate(), exportEstimateVM.totalDurationSec);
        }
        return videoConfig.estimateComposeFileSizeWithOriginalSize(getBitrate(), exportEstimateVM.selectedDurationSec);
    }

    // 常规清理（统一逻辑见 Config/ExportCacheHelper）
    function autoCacheCleaner() {
        ExportCacheHelper.autoCacheCleaner("[Compose][CacheCleaner]")
    }

    // 按保存路径判断是否需要应急清理（统一逻辑见 ExportCacheHelper）。返回是否触发了应急。
    function tryEmergencyCleanForExport(savePath, scene) {
        return ExportCacheHelper.tryEmergencyCleanForExport(
            [{ path: savePath, estimatedMB: Math.max(0, currentEstimatedFileSizeMB()) }],
            "[Compose][CacheCleaner]", scene)
    }

    onOpened: {
        logger.i("[Compose] ComposePanel onOpened");
        refreshCover(panoCheckBox.checked, !panoCheckBox.checked);
        changeSwitchState();
        content.enabled = false;

        // 进入导出页：保存路径同盘且预测剩余不足 → 应急清理；否则 → 常规清理
        if (!tryEmergencyCleanForExport(currentSavePath, "onOpened")) {
            autoCacheCleaner();
        }
    }

    // 统一清理全景提示气泡：停止动画 → 关闭弹窗 → 卸载 Loader
    function closePanoRadioHint() {
        panoRadioHintPositionTimer.stop()
        if (panoRadioHintLoader.active) {
            panoRadioHintShowAnim.stop()
            panoRadioHintLoader.item.close()
            panoRadioHintLoader.active = false
        }
    }

    onClosed: {
        logger.i("[Compose] ComposePanel onClosed");
        imageLoader.active = false; // 卸载当前组件
        closePanoRadioHint()
        videoCheckBox.checked = true;
        panoCheckBox.checked = false;
        composeSetting.mediaExportType = ComposePanelSettingModel.Video; // 重置为视频模式，避免下次打开仍显示达芬奇格式
        dolbyVisionSwitch.checked = false;
        scrollView.ScrollBar.vertical.position = 0;
        content.enabled = true;
    }

    contentItem: Item {
        MouseArea {
            anchors.fill: parent
            onClicked: {
                //closeSignal();
                //close();
            }
        }
        Rectangle {
            id: contentRect
            anchors {
                centerIn: parent
            }
            width: 600
            height: 502 + deNoiseRectangle.height + colorDepthRectangle.height
            radius: 8
            color: Colors.color_2F3032
            border.width:1
            border.color:Colors.color_454649
            layer.enabled: true
            MouseArea {
                anchors.fill: parent
                onClicked: {}
            }
            // 点击输入框外部自动清除焦点
            FocusClearArea { }

            WindowTitleBar {
                id: titleBar
                width: parent.width
                title: qsTr("pccut_export_settings")
                onCloseClick: {
                    close();
                    eventTracker.trackEvent("pccut_export_close_click");
                }
            }
            //时间轴截图
            Rectangle {
                id: picRectangle
                width: 212
                height: 159
                color: Colors.color_transparent
                radius: 6
                clip: true // 启用裁剪以实现圆角效果
                anchors {
                    left: parent.left
                    leftMargin: 28
                    top: titleBar.bottom
                    topMargin: 24
                }
                Component {
                    id: picComponent
                    LightClipRectangle {
                        id:imageWrapper
                        width: 212
                        height: 159
                        color: Colors.color_000000
                        radius: [6,6,6,6]
                        Image {
                            id: picComponentImage
                            anchors.fill: parent
                            cache: false
                            source: "file:///" + composePopup.coverpath
                            fillMode: Image.PreserveAspectCrop
                        }
                    }
                }
                Component {
                    id: picLoadingComponent
                    LightClipRectangle {
                        id:imageLoadingWrapper
                        anchors.fill: parent
                        color: Colors.color_000000
                        radius: [6,6,6,6]
                        Image {
                            anchors.fill: parent
                            cache: false
                            source: translationHandler.isChineseLang() ? "qrc:/icons/cover_loading.svg" : "qrc:/icons/cover_loading_en.svg"
                            sourceSize: Qt.size(57, 57)
                            fillMode: Image.Pad
                        }
                    }
                }

                Loader {
                    id: imageLoader
                    anchors.fill: parent
                    sourceComponent: picLoadingComponent

                }

            }

            // 提示文字
            Text {
                id: picTips
                anchors {
                    left: parent.left
                    leftMargin: 27
                    right: picRectangle.right
                    top: picRectangle.bottom
                    topMargin: 12
                }
                maximumLineCount: 2
                wrapMode: Text.WordWrap
                text: qsTr("")
                font.pixelSize: 11
                color: Colors.color_666666
                visible: text !== ""  // 文本为空时自动隐藏
            }


            // 分段导出提示文字
            Text {
                id: multiFragmentTips
                width: picRectangle.width

                visible : selectComposeType === 1 && !panoCheckBox.checked

                anchors {
                    left: picRectangle.left
                    top: picTips.visible ? picTips.bottom : picRectangle.bottom
                    topMargin: picTips.visible ? 10 : 12  // 保持相同的间距
                }
                font.pixelSize: 11
                color: Colors.color_666666
                text: qsTr("pccut_editor_result_type_clip_tip")
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignLeft

            }

            // 16K静止延时提示文字
            Text {
                id: has16KTimelapseTips
                width: picRectangle.width
                anchors {
                    left: picRectangle.left
                    top: multiFragmentTips.visible ? multiFragmentTips.bottom : (picTips.visible ? picTips.bottom : picRectangle.bottom)
                    topMargin: (multiFragmentTips.visible || picTips.visible) ? 10 : 12  // 保持相同的间距
                }
                font.pixelSize: 11
                color: Colors.color_666666
                text: qsTr("pccut_timelapse_tip_2")
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignLeft
                visible: false
            }

            ScrollView {
                id: scrollView
                anchors {
                    left: parent.left
                    leftMargin: 268
                    top: titleBar.bottom
                    topMargin: 24
                    right: parent.right
                    rightMargin: 4
                    bottom: fileSizeArea.top
                    bottomMargin: 36
                }
                Component.onCompleted: {
                    scrollView.contentItem.boundsBehavior = Flickable.StopAtBounds
                }
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AlwaysOn
                    anchors {
                        right: parent.right
                    }
                    height: parent.height
                    contentItem: Rectangle {
                        implicitWidth: 6
                        radius: 3
                        // color: Colors.color_454649
                        color: scrollBarMouseArea.containsMouse ? Colors.color_56575B : Colors.color_454649
                        Behavior on color {
                            ColorAnimation { duration: 200 }  // 平滑过渡
                        }
                    }

                    MouseArea {
                        id: scrollBarMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                    }
                    onPositionChanged: {
                        waterMarkSetting.closeAllPopup()
                    }
                }

                clip: true
                contentHeight: scrollContent.implicitHeight
                // 滚动区域内容容器
                Column {
                    id: scrollContent
                    width: parent.width - 20
                    spacing: 16 // 控件间距
                    // 类型选择
                    Rectangle {
                        id: typeRectangle
                        width: parent.width
                        height: 28
                        color: Colors.color_transparent
                        Text {
                            id: typeText
                            anchors {
                                left: parent.left
                                top: parent.top
                                bottom: parent.bottom
                            }
                            width: 51
                            horizontalAlignment: Text.AlignLeft
                            verticalAlignment: Text.AlignVCenter
                            maximumLineCount: 2
                            wrapMode: Text.WrapAnywhere
                            font.pixelSize: 12
                            color: Colors.color_CCCCCC

                            text: qsTr("pccut_export_as")
                        }
                        CheckBox {
                            id:videoCheckBox
                            text: qsTr("pccut_media_filter_video")
                            anchors {
                                left: typeText.right
                                leftMargin: 12
                            }
                            checked: true
                            anchors.verticalCenter: parent.verticalCenter
                            indicator: Rectangle {
                                implicitWidth: 16
                                implicitHeight: 16
                                anchors.left: videoCheckBox.left
                                anchors.verticalCenter: parent.verticalCenter
                                color:  Colors.color_transparent
                                radius: 8
                                Image {
                                    visible: true
                                    anchors.fill: parent
                                    source: videoCheckBox.checked ? "qrc:/app_qrc/icons/icon_radio_selected.svg":"qrc:/icons/icon_radio_button_no.svg"
                                    sourceSize: Qt.size(parent.width, parent.height)
                                }
                            }
                            MouseArea {
                                anchors.fill: videoCheckBox
                                onClicked: {
                                    if(videoCheckBox.checked){
                                        return;
                                    }else{
                                        saveCurrentModeParams()
                                        videoCheckBox.checked = true;
                                        panoCheckBox.checked = false;
                                        composeSetting.mediaExportType = ComposePanelSettingModel.Video;
                                        refreshCover(false, true);
                                        restoreModeParams(false)
                                        refreshFileMB(true);
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
                        Item {
                            id: panoCheckBoxItem
                            anchors {
                                left: videoCheckBox.right
                                leftMargin: 45
                                verticalCenter: parent.verticalCenter
                            }
                            implicitWidth: panoCheckBox.implicitWidth + 9
                            implicitHeight: panoCheckBox.implicitHeight
                            CheckBox {
                            property bool canUse: composeSetting.isAllPanoClip()
                            id:panoCheckBox
                            text: qsTr("pccut_media_panoramic_video")
                            checked: false
                            anchors.verticalCenter: parent.verticalCenter
                            indicator: Rectangle {
                                implicitWidth: 16
                                implicitHeight: 16
                                anchors.left: panoCheckBox.left
                                anchors.verticalCenter: parent.verticalCenter
                                color:  Colors.color_transparent
                                radius: 8
                                opacity: panoCheckBox.canUse?1:0.4
                                Image {
                                    visible: true
                                    anchors.fill: parent
                                    source:panoCheckBox.checked ? "qrc:/app_qrc/icons/icon_radio_selected.svg" : "qrc:/icons/icon_radio_button_no.svg"
                                    sourceSize: Qt.size(parent.width, parent.height)
                                }
                            }
                            onVisibleChanged: {
                                //右键带单进入&分段导出，判断所选视频均支持全景
                                if(entranceType === 1 && selectComposeType === 1){
                                    canUse = editorManager.isAllSelectedPanoClip() && (editorManager.getCurVideoType() !== MediaType.DUSS_REMUX_RECORD_PANO_VIDEO_SEMI && editorManager.getCurVideoType() !== MediaType.DUSS_REMUX_RECORD_PANO_VIDEO_BULLET_TIME)
                                }else{
                                    if (visible) {
                                        canUse = composeSetting.isAllPanoClip() && (editorManager.getCurVideoType() !== MediaType.DUSS_REMUX_RECORD_PANO_VIDEO_SEMI && editorManager.getCurVideoType() !== MediaType.DUSS_REMUX_RECORD_PANO_VIDEO_BULLET_TIME)
                                    }
                                }
                                // 首次进入且全景可选时，在全景按钮上方显示达芬奇提示
                                // 注意：seen 标志在气泡确认展示后才保存（见 Component.onCompleted），
                                // 避免因面板提前关闭导致气泡未展示但标志已置位
                                if (visible && canUse && !lightSetting.getBool("pano_radio_hint_seen")) {
                                    panoRadioHintPositionTimer.start()
                                } else {
                                    // 覆盖所有非启动场景（!visible 或 !canUse），确保 timer 和气泡被正确清理
                                    closePanoRadioHint()
                                }
                            }

                            MouseArea {
                                anchors.fill: panoCheckBox
                                hoverEnabled: true // 启用悬停检测
                                onClicked: {
                                    if(panoCheckBox.checked){
                                        return;
                                    }else{
                                        if(panoCheckBox.canUse){
                                            saveCurrentModeParams()
                                            videoCheckBox.checked = false;
                                            panoCheckBox.checked = true;
                                            refreshCover(true, false);
                                            restoreModeParams(true)
                                            composeSetting.mediaExportType = cachedPanoFormat
                                            refreshFileMB(true);
                                            // 首次点击：显示提示callout（仅一次）
                                            if (!lightSetting.getBool("pano_hint_seen")) {
                                                lightSetting.save("pano_hint_seen", true)
                                                panoHintPositionTimer.start()
                                            }
                                        }
                                    }
                                }
                                onEntered: {
                                    if(!panoCheckBox.canUse){
                                        hoverRectangle.visible = true; // 鼠标进入时显示
                                    }

                                }
                                onExited: {
                                    hoverRectangle.visible = false; // 鼠标离开时隐藏
                                }
                            }
                            contentItem: Text {
                                text: panoCheckBox.text
                                font.pixelSize: 12
                                color: panoCheckBox.canUse?Colors.color_EEEEEE:Colors.color_444444
                                verticalAlignment: Text.AlignVCenter
                                leftPadding: panoCheckBox.indicator.width
                            }
                        }
                        }
                        Rectangle {
                            id:hoverRectangle
                            implicitWidth: 68
                            implicitHeight: 16
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            color:  Colors.color_transparent
                            visible: false
                            Image {
                                anchors.fill: parent
                                source:"qrc:/icons/icon_no_support_no_pano.svg"
                                sourceSize: Qt.size(parent.width, parent.height)
                            }
                        }
                    }
                    // 媒体类型下拉弹层（全景模式）
                    LightPopup {
                        id: mediaTypePopup
                        width: parent.width
                        height: parent.height
                        z: 9999
                        modal: false
                        parent: Overlay.overlay
                        needTransparent: true
                        contentItem: Item {
                            MouseArea {
                                anchors.fill: parent
                                onClicked: mediaTypePopup.close()
                            }
                            Rectangle {
                                id: mediaTypeDropRect
                                width: mediaTypeChoose.width
                                height: 68
                                radius: RadiusConfig.radius_4_8
                                color: Colors.color_454649
                                layer.enabled: true
                                layer.effect: DropShadow {
                                    horizontalOffset: 0
                                    verticalOffset: 0
                                    radius: 10
                                    color: Colors.color_000000_40
                                }
                                Column {
                                    topPadding: 4
                                    bottomPadding: 4
                                    leftPadding: 4
                                    rightPadding: 4
                                    spacing: 4
                                    Rectangle {
                                        width: mediaTypeDropRect.width - 8
                                        height: 28
                                        radius: RadiusConfig.radius_4_8
                                        color: videoTypeArea.containsMouse ? Colors.color_FFFFFF_15 : Colors.color_transparent
                                        Image {
                                            id: videoCheckIcon
                                            anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                                            width: 16; height: 16
                                            source: !isDaVinciFormat ? "qrc:/app_qrc/icons/icon_compose_check.svg" : ""
                                            sourceSize: Qt.size(16, 16)
                                        }
                                        Text {
                                            anchors { left: videoCheckIcon.right; leftMargin: 5; top: parent.top; bottom: parent.bottom; right: parent.right }
                                            verticalAlignment: Text.AlignVCenter
                                            font.pixelSize: 11
                                            color: videoTypeArea.containsMouse ? ColorsConfig.color_EEEEEE_4DFFC9 : Colors.color_EEEEEE
                                            text: qsTr("pccut_material_video")
                                        }
                                        MouseArea {
                                            id: videoTypeArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: {
                                                composeSetting.mediaExportType = ComposePanelSettingModel.Panorama
                                                cachedPanoFormat = ComposePanelSettingModel.Panorama
                                                mediaTypePopup.close()
                                            }
                                        }
                                    }
                                    Rectangle {
                                        width: mediaTypeDropRect.width - 8
                                        height: 28
                                        radius: RadiusConfig.radius_4_8
                                        color: daVinciTypeArea.containsMouse || daVinciDropQMarkArea.containsMouse ? Colors.color_FFFFFF_15 : Colors.color_transparent
                                        Image {
                                            id: daVinciCheckIcon
                                            anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                                            width: 16; height: 16
                                            source: isDaVinciFormat ? "qrc:/app_qrc/icons/icon_compose_check.svg" : ""
                                            sourceSize: Qt.size(16, 16)
                                        }
                                        Text {
                                            id: daVinciTitleText
                                            anchors { left: daVinciCheckIcon.right; leftMargin: 5; top: parent.top; bottom: parent.bottom; right: daVinciDropQMark.left; rightMargin: 4 }
                                            verticalAlignment: Text.AlignVCenter
                                            elide: Text.ElideRight
                                            font.pixelSize: 11
                                            color: daVinciTypeArea.containsMouse || daVinciDropQMarkArea.containsMouse? ColorsConfig.color_EEEEEE_4DFFC9 : Colors.color_EEEEEE
                                            text: qsTr("pccut_hdr_export_davinci_btn")
                                        }
                                        MouseArea {
                                            id: daVinciTypeArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: {
                                                console.log("[DaVinci] daVinciTypeArea clicked, setting isDaVinciFormat=true")
                                                composeSetting.mediaExportType = ComposePanelSettingModel.DaVinci
                                                cachedPanoFormat = ComposePanelSettingModel.DaVinci
                                                mediaTypePopup.close()
                                            }
                                        }
                                        // 问号图标（声明在 MouseArea 之后，z 轴更高，可正常接收 hover 事件）
                                        Rectangle {
                                            id: daVinciDropQMark
                                            x: Math.min(daVinciTitleText.x + daVinciTitleText.implicitWidth + 4, parent.width - width - 4)
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 14
                                            height: 14
                                            color: Colors.color_transparent
                                            Image {
                                                anchors.fill: parent
                                                source: daVinciDropQMarkArea.containsMouse ? "qrc:/icons/ic_explain.svg" : "qrc:/icons/ic_explain_hover.svg"
                                                sourceSize: Qt.size(14, 14)
                                            }
                                            MouseArea {
                                                id: daVinciDropQMarkArea
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                acceptedButtons: Qt.NoButton
                                            }
                                            LightToolTip {
                                                visible: daVinciDropQMarkArea.containsMouse
                                                x: - (width / 2)
                                                z: 9999
                                                tip: qsTr("pccut_hdr_export_davinci_tip")
                                                width: 410 // DaVinci tooltip needs fixed width for word wrap
                                                textWrapMode: Text.WordWrap
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    // 全景视频提示callout
                    LightPopup {
                        id: panoHintPopup
                        width: parent.width
                        height: parent.height
                        z: 9999
                        modal: false
                        parent: Overlay.overlay
                        needTransparent: true
                        contentItem: Item {
                            MouseArea {
                                anchors.fill: parent
                                propagateComposedEvents: true
                                onClicked: function(mouse) {
                                    panoHintPopup.close()
                                    mouse.accepted = false
                                }
                            }
                            Item {
                                id: panoHintCallout
                                width: hintBody.width
                                height: 33  // 10 (三角可见部分) + 28 (矩形)
                                opacity: 0
                                scale: 0.7
                                transformOrigin: Item.TopRight  // 从右上角（三角处）向外放大
                                property real slideY: -6
                                transform: Translate { y: panoHintCallout.slideY }
                                // 矩形体（先定义，供 Image 锚定）
                                Rectangle {
                                    id: hintBody
                                    width: hintText.contentWidth + 24  // 左右各 12px padding
                                    height: 28
                                    anchors.bottom: parent.bottom
                                    color: Colors.color_FFFFFF
                                    radius: 4
                                    layer.enabled: true
                                    layer.effect: DropShadow {
                                        horizontalOffset: 0
                                        verticalOffset: 0
                                        radius: 10
                                        color: Colors.color_000000_40
                                    }
                                    Text {
                                        id: hintText
                                        anchors.centerIn: parent
                                        text: qsTr("pccut_hdr_export_davinci_btn_new_tip")
                                        font.pixelSize: 12
                                        color: Colors.color_141414
                                    }
                                }
                                // 三角形（旋转180度，尖端朝上，底边与矩形顶部对齐）
                                Image {
                                    width: 12
                                    height: 8
                                    source: "qrc:/icons/region_guide_begin_bottom.svg"
                                    rotation: 180
                                    anchors.bottom: hintBody.top
                                    anchors.bottomMargin: -3  // 向下偏4px消除SVG内置空白，使底边与矩形顶部衔接
                                    anchors.right: parent.right
                                    anchors.rightMargin: 12  // 三角中心线距右侧18px (18-6=12)
                                }
                            }
                            // 出现动画：淡入 + 向下滑入 + 从小变大
                            ParallelAnimation {
                                id: panoHintShowAnim
                                NumberAnimation {
                                    target: panoHintCallout
                                    property: "opacity"
                                    from: 0; to: 1
                                    duration: 400
                                    easing.type: Easing.OutCubic
                                }
                                NumberAnimation {
                                    target: panoHintCallout
                                    property: "slideY"
                                    from: -6; to: 0
                                    duration: 400
                                    easing.type: Easing.OutCubic
                                }
                                NumberAnimation {
                                    target: panoHintCallout
                                    property: "scale"
                                    from: 0.7; to: 1.0
                                    duration: 400
                                    easing.type: Easing.OutBack  // 略微弹性，有"弹出"质感
                                }
                            }
                            Timer {
                                id: panoHintPositionTimer
                                interval: 250  // 等待 mediaTypeChoose 布局完成（首次 visible 时需要 2~3 帧）
                                onTriggered: {
                                    var pos = mediaTypeChoose.mapToItem(null, mediaTypeChoose.width - panoHintCallout.width, mediaTypeChoose.height - 1)
                                    panoHintCallout.x = pos.x
                                    panoHintCallout.y = pos.y
                                    panoHintCallout.opacity = 0
                                    panoHintCallout.scale = 0.7
                                    panoHintCallout.slideY = -6
                                    panoHintPopup.open()
                                    panoHintShowAnim.start()
                                    panoHintTimer.restart()
                                }
                            }
                            Timer {
                                id: panoHintTimer
                                interval: 15000
                                onTriggered: panoHintPopup.close()
                            }
                        }
                    }
                    // 全景视频 radio button 上方提示气泡（三角在下方指向文字）
                    // 媒体类型（全景模式下显示）
                    Rectangle {
                        id: mediaTypeRectangle
                        visible: panoCheckBox.checked
                        width: parent.width
                        height: 28
                        color: Colors.color_transparent

                        Text {
                            id: mediaTypeLabel
                            anchors {
                                left: parent.left
                                verticalCenter: parent.verticalCenter
                            }
                            font.pixelSize: 12
                            color: Colors.color_CCCCCC
                            text: qsTr("pccut_hdr_export_media_type")
                        }

                        Rectangle {
                            id: mediaTypeChoose
                            anchors {
                                left: parent.left
                                leftMargin: 63
                                top: parent.top
                                bottom: parent.bottom
                                right: parent.right
                            }
                            color: mediaTypeChooseArea.containsMouse ? Colors.color_68696D : Colors.color_454649
                            radius: RadiusConfig.radius_4_8

                            Image {
                                id: mediaTypeArrow
                                anchors {
                                    right: parent.right
                                    rightMargin: 8
                                    verticalCenter: parent.verticalCenter
                                }
                                width: 20
                                height: 20
                                source: mediaTypePopup.opened ? "qrc:/icons/adjustment/icon_drop_down_menu_collapse.svg" : "qrc:/icons/adjustment/icon_drop_down_menu_expand.svg"
                                sourceSize: Qt.size(20, 20)
                            }

                            Text {
                                id: mediaTypeChooseBtn
                                anchors {
                                    left: parent.left
                                    leftMargin: 8
                                    top: parent.top
                                    bottom: parent.bottom
                                    right: mediaTypeArrow.left
                                }
                                horizontalAlignment: Text.AlignLeft
                                verticalAlignment: Text.AlignVCenter
                                color: Colors.color_FFFFFF
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                text: isDaVinciFormat ? qsTr("pccut_hdr_export_davinci_btn") : qsTr("pccut_material_video")
                            }

                            MouseArea {
                                id: mediaTypeChooseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    var pos = mediaTypeChoose.mapToItem(null, 0, mediaTypeChoose.height + 4)
                                    mediaTypeDropRect.x = pos.x
                                    mediaTypeDropRect.y = pos.y
                                    mediaTypePopup.open()
                                }
                            }

                        }
                    }
                    // 文件名（统一组件，走 viewModel 链路，含文件重名提示）
                    ExportFileNameUnified {
                        id: fileNameControl
                        width: parent.width
                        height: 28
                        viewModel: composeExportViewModel
                        titleText: qsTr("pccut_export_name")
                    }
                    // 路径选择（统一组件，走 viewModel 链路，含磁盘空间/权限实时检测）
                    ExportSavePath {
                        id: filePathControl
                        width: parent.width
                        height: 28
                        viewModel: composeExportViewModel
                        accessCheckFunc: function(path) {
                            return (selectComposeType === 1)
                                ? fileOperator.hasSubdirCreateAccess(path)
                                : fileOperator.hasFileCreateAccess(path)
                        }
                        onDialogAccepted: function(newPath, isChanged) {
                            if (isChanged) {
                                refreshFileName(selectComposeType)
                                // 用户修改保存路径：同盘且预测剩余不足才应急清理，否则什么都不做。
                                tryEmergencyCleanForExport(newPath, "dialogAccepted")
                            }
                            eventTracker.trackEvent("pccut_export_change_location", {"is_change": isChanged})
                        }
                        onDialogRejected: {
                            eventTracker.trackEvent("pccut_export_change_location", {"is_change": false})
                        }
                    }

                    //导出范围选择
                    ComposeRangeSettingPanel{
                        id: composeRangeSettingPanel
                    }
                    // 导出范围
                    Column {
                        width: parent.width
                        spacing: 8  // 内部间距
                        Rectangle {
                            id: composeRangeRectangle
                            property bool composeRangeSelecting: false
                            width: parent.width
                            height: 28
                            color: Colors.color_transparent
                            HoverableText {
                                id: composeRangeText
                                anchors {
                                    left: parent.left
                                    verticalCenter: parent.verticalCenter
                                }
                                horizontalAlignment: Text.AlignLeft
                                verticalAlignment: Text.AlignVCenter
                                font.pixelSize: 12
                                color: Colors.color_CCCCCC
                                text: qsTr("pccut_track_scope_title")
                            }
                            Rectangle {
                                id: comopseRangeChoose
                                anchors {
                                    left: parent.left
                                    //leftMargin: maxLeftItemTextWidth
                                    leftMargin: 63
                                    top: parent.top
                                    bottom: parent.bottom
                                    right: parent.right
                                }
                                color: {
                                    if (composeRangeChooseArea.containsMouse) {
                                        return Colors.color_68696D
                                    } else if (composeRangeRectangle.resolutionSelecting) {
                                        return Colors.color_454649
                                    } else {
                                        return Colors.color_454649
                                    }
                                }
                                radius: RadiusConfig.radius_4_8
                                Image {
                                    id: composeRangeChooseImage
                                    anchors {
                                        right: parent.right
                                        rightMargin: 8
                                        verticalCenter: parent.verticalCenter
                                    }
                                    width: 20
                                    height: 20
                                    source: composeRangeRectangle.composeRangeSelecting ? "qrc:/icons/adjustment/icon_drop_down_menu_collapse.svg" : "qrc:/icons/adjustment/icon_drop_down_menu_expand.svg"
                                    sourceSize: Qt.size(20, 20)
                                }
                                Text {
                                    id: composeRangeChooseBtn
                                    anchors {
                                        left: parent.left
                                        leftMargin: 8
                                        top: parent.top
                                        bottom: parent.bottom
                                        right: composeRangeChooseImage.left
                                    }
                                    horizontalAlignment: Text.AlignLeft
                                    verticalAlignment: Text.AlignVCenter
                                    color: Colors.color_FFFFFF
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                }
                                MouseArea {
                                    id: composeRangeChooseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        let hasRangeCompose = editorManager.hasRangeCompose();
                                        composeRangeRectangle.composeRangeSelecting = true;
                                        //导入按钮进入，并且没有视频片段，禁用导出多个分段
                                        if(hasRangeCompose === true){
                                            composeRangeSettingPanel.show(comopseRangeChoose, selectComposeRange);
                                        }else{
                                            composeRangeSettingPanel.show(comopseRangeChoose, selectComposeRange, VideoConfig.COMPOSERANGE_RANGE)
                                        }
                                        eventTracker.trackEvent("pccut_editor_result_range_option")

                                    }
                                }
                            }
                            Connections {
                                target: composeRangeSettingPanel
                                function onSelectedItemSignal(title, range) {
                                    composeRangeRectangle.composeRangeSelecting = false;
                                    composeRangeChooseBtn.text = title;
                                    selectComposeRange = range;
                                    //添加导出范围选中标记区域时，导出方式强制单个片段，导出方式的多个独立片段选项不可用
                                    if(range === VideoConfig.COMPOSERANGE_RANGE) {
                                        selectComposeType = 0;
                                        let itemTitle = videoConfig.getItemByComposeType(selectComposeType);
                                        composeTypeSettingPanel.selectedItemSignal(itemTitle, selectComposeType);
                                        comopseTypeChoose.enabled = false;
                                    }else{
                                        comopseTypeChoose.enabled = true;
                                    }
                                    refreshCover(panoCheckBox.checked, false);
                                    refreshFileMB(true);
                                }
                                function onCloseSignal() {
                                    composeRangeRectangle.composeRangeSelecting = false;
                                }
                            }
                        }
                    }
                    //导出类型选择
                    ComposeTypeSettingPanel{
                        id: composeTypeSettingPanel
                    }
                    // 导出类型
                    Column {
                        width: parent.width
                        spacing: 8  // 内部间距

                        Rectangle {
                            id: composeTypeRectangle
                            property bool composeTypeSelecting: false

                            width: parent.width
                            height: 28
                            color: Colors.color_transparent

                            HoverableText {
                                id: composeTypeText
                                anchors {
                                    left: parent.left
                                    verticalCenter: parent.verticalCenter
                                }
                                horizontalAlignment: Text.AlignLeft
                                verticalAlignment: Text.AlignVCenter
                                font.pixelSize: 12
                                color: Colors.color_CCCCCC
                                text: qsTr("pccut_editor_result_type_option")
                            }

                            Rectangle {
                                id: comopseTypeChoose
                                anchors {
                                    left: parent.left
                                    //leftMargin: maxLeftItemTextWidth
                                    leftMargin: 63
                                    top: parent.top
                                    bottom: parent.bottom
                                    right: parent.right
                                }
                                color: {
                                    if(comopseTypeChoose.enabled === false) {
                                        return Colors.color_454649
                                    }
                                    if (composeTypeChooseArea.containsMouse) {
                                        return Colors.color_68696D
                                    } else if (composeTypeRectangle.resolutionSelecting) {
                                        return Colors.color_454649
                                    } else {
                                        return Colors.color_454649
                                    }
                                }
                                opacity: comopseTypeChoose.enabled ? 1:0.2
                                radius: RadiusConfig.radius_4_8

                                Image {
                                    id: composeTypeChooseImage
                                    anchors {
                                        right: parent.right
                                        rightMargin: 8
                                        verticalCenter: parent.verticalCenter
                                    }
                                    width: 20
                                    height: 20
                                    source: composeTypeRectangle.composeTypeSelecting ? "qrc:/icons/adjustment/icon_drop_down_menu_collapse.svg" : "qrc:/icons/adjustment/icon_drop_down_menu_expand.svg"
                                    sourceSize: Qt.size(20, 20)
                                }

                                Text {
                                    id: composeTypeChooseBtn
                                    anchors {
                                        left: parent.left
                                        leftMargin: 8
                                        top: parent.top
                                        bottom: parent.bottom
                                        right: composeTypeChooseImage.left
                                    }
                                    horizontalAlignment: Text.AlignLeft
                                    verticalAlignment: Text.AlignVCenter
                                    color: Colors.color_FFFFFF
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                }

                                MouseArea {
                                    id: composeTypeChooseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        composeTypeRectangle.composeTypeSelecting = true;
                                        //导入按钮进入，并且没有视频片段，禁用导出多个分段
                                        composeMultiFragmentValid() ? composeTypeSettingPanel.show(comopseTypeChoose, selectComposeType, -1, selectComposeRange) : composeTypeSettingPanel.show(comopseTypeChoose, selectComposeType, VideoConfig.COMPOSETYPE_MULTI, selectComposeRange);
                                        eventTracker.trackEvent("pccut_editor_result_type_option")
                                    }

                                    function composeMultiFragmentValid() {
                                        if(entranceType === 0){
                                            var dsm = editorManager.getVideoFragmentCount();
                                            logger.d("simmy:dsm=" + dsm);
                                            if (dsm === 0) {
                                                return false;
                                            }
                                        }
                                        return true;
                                    }
                                }
                            }

                            Connections {
                                target: composeTypeSettingPanel
                                function onSelectedItemSignal(title, type) {
                                    composeTypeRectangle.composeTypeSelecting = false;
                                    composeTypeChooseBtn.text = title;
                                    selectComposeType = type;
                                    refreshFileName(type);
                                    refreshFileMB(true);
                                    // 导出方式变化会影响所需权限类型和磁盘空间，重新检查
                                    filePathControl.checkPathAccess();
                                    filePathControl.checkDiskSpace();
                                }

                                function onCloseSignal() {
                                    composeTypeRectangle.composeTypeSelecting = false;
                                }
                            }
                        }
                    }
                    // 分割线
                    BaseSpliter {
                        id: line
                        width: parent.width
                    }

                    // 分辨率
                    Rectangle {
                        id: resolutionRectangle
                        property bool resolutionSelecting: false

                        width: parent.width
                        height: 28
                        color: Colors.color_transparent

                        HoverableText {
                            id: resolutionNameText
                            anchors {
                                left: parent.left
                                verticalCenter: parent.verticalCenter
                            }
                            horizontalAlignment: Text.AlignLeft
                            verticalAlignment: Text.AlignVCenter
                            font.pixelSize: 12
                            color: Colors.color_CCCCCC
                            text: qsTr("pccut_media_info_resolution")
                            Accessible.role: Accessible.Button
                            Accessible.description: "filmexport_exportresolutionname"
                        }

                        Rectangle {
                            id: resolutionChoose
                            anchors {
                                left: parent.left
                                //leftMargin: maxLeftItemTextWidth
                                leftMargin: 63
                                top: parent.top
                                bottom: parent.bottom
                                right: parent.right
                            }
                            color: {
                                if (resolutionChooseArea.containsMouse) {
                                    return Colors.color_68696D
                                } else if (resolutionRectangle.resolutionSelecting) {
                                    return Colors.color_454649
                                } else {
                                    return Colors.color_454649
                                }
                            }
                            radius: RadiusConfig.radius_4_8
                            Accessible.role: Accessible.Button
                            Accessible.description: "filmexport_exportresolutiontune"

                            Image {
                                id: resolutionChooseImage

                                anchors {
                                    right: parent.right
                                    rightMargin: 8
                                    verticalCenter: parent.verticalCenter
                                }
                                width: 20
                                height: 20
                                source: resolutionRectangle.resolutionSelecting ? "qrc:/icons/adjustment/icon_drop_down_menu_collapse.svg" : "qrc:/icons/adjustment/icon_drop_down_menu_expand.svg"
                                sourceSize: Qt.size(20, 20)
                            }

                            Text {
                                id: resolutionChooseBtn
                                anchors {
                                    left: parent.left
                                    leftMargin: 8
                                    top: parent.top
                                    bottom: parent.bottom
                                    right: resolutionChooseImage.left
                                }
                                horizontalAlignment: Text.AlignLeft
                                verticalAlignment: Text.AlignVCenter
                                color: Colors.color_FFFFFF
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                            }

                            MouseArea {
                                id: resolutionChooseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    resolutionRectangle.resolutionSelecting = true;
                                    eventTracker.trackEvent("pccut_export_resolution")
                                    resolutionSettingPanel.active = true
                                    const colorDepth = colorDepthSwitch.checked ? 10 : 8
                                    let cardParams = editorManager.getCardEncodeParams(colorDepth);
                                    resolutionSettingPanel.item.show(resolutionChoose, selectResolutionType,panoCheckBox.checked?true:false,false, cardParams);
                                }
                            }
                        }

                        Connections {
                            target: resolutionSettingPanel.item
                            function onSelectedItemSignal(title, value, type) {
                                resolutionRectangle.resolutionSelecting = false;
                                resolutionChooseBtn.text = title + " - " + value;
                                //resolutionLabel.text = value;
                                selectResolutionType = type;
                                refreshFileMB(true);
                            }
                            function onCloseSignal() {
                                resolutionRectangle.resolutionSelecting = false;
                            }
                        }
                    }
                    // 帧率
                    Column {
                        width: parent.width
                        spacing: 8  // 内部间距

                        // 帧率
                        Rectangle {
                            id: frameRateRectangle
                            property bool frameRateSelecting: false

                            width: parent.width
                            height: 28
                            color: Colors.color_transparent

                            HoverableText {
                                id: frameRateText
                                anchors {
                                    left: parent.left
                                    verticalCenter: parent.verticalCenter
                                }
                                horizontalAlignment: Text.AlignLeft
                                verticalAlignment: Text.AlignVCenter
                                font.pixelSize: 12
                                color: Colors.color_CCCCCC
                                text: qsTr("pccut_media_info_rate")
                            }

                            Rectangle {
                                id: frameRateChoose
                                anchors {
                                    left: parent.left
                                    //leftMargin: maxLeftItemTextWidth
                                    leftMargin: 63
                                    top: parent.top
                                    bottom: parent.bottom
                                    right: parent.right
                                }
                                color: {
                                    if (frameRateChooseArea.containsMouse) {
                                        return Colors.color_68696D
                                    } else if (frameRateRectangle.resolutionSelecting) {
                                        return Colors.color_454649
                                    } else {
                                        return Colors.color_454649
                                    }
                                }
                                radius: RadiusConfig.radius_4_8

                                Image {
                                    id: frameRateChooseImage

                                    anchors {
                                        right: parent.right
                                        rightMargin: 8
                                        verticalCenter: parent.verticalCenter
                                    }
                                    width: 20
                                    height: 20
                                    source: frameRateRectangle.frameRateSelecting ? "qrc:/icons/adjustment/icon_drop_down_menu_collapse.svg" : "qrc:/icons/adjustment/icon_drop_down_menu_expand.svg"
                                    sourceSize: Qt.size(20, 20)
                                }

                                Text {
                                    id: frameRateChooseBtn
                                    anchors {
                                        left: parent.left
                                        leftMargin: 8
                                        top: parent.top
                                        bottom: parent.bottom
                                        right: frameRateChooseImage.left
                                    }
                                    horizontalAlignment: Text.AlignLeft
                                    verticalAlignment: Text.AlignVCenter
                                    color: Colors.color_FFFFFF
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                }

                                MouseArea {
                                    id: frameRateChooseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        frameRateRectangle.frameRateSelecting = true;
                                        let maxFrameRate = editorManager.getTrackFragmentMaxFps()
                                        if(maxFrameRate === VideoConfig.UNKNOWTYPE) {
                                            maxFrameRate = VideoConfig.FRAMERATETYPE_60;
                                        }
                                        frameRateSettingPanel.active = true
                                        frameRateSettingPanel.item.show(frameRateChoose, selectFrameRateType, maxFrameRate);
                                        eventTracker.trackEvent("pccut_export_frame_rate")
                                    }
                                }
                            }

                            Connections {
                                target: frameRateSettingPanel.item
                                function onSelectedItemSignal(title, type) {
                                    frameRateRectangle.frameRateSelecting = false;
                                    frameRateChooseBtn.text = title;
                                    selectFrameRateType = type;
                                    refreshFileMB(true);
                                    if (composePopup.unifiedFrame !== -1 && composePopup.unifiedFrame !== type) {
                                        frameRateTip.text = qsTr("pccut_export_frame_rate_consistent")
                                    } else if (composePopup.unifiedFrame !== -1) {
                                        frameRateTip.text = ""
                                    }
                                }
                                function onCloseSignal() {
                                    frameRateRectangle.frameRateSelecting = false;
                                }
                            }
                        }

                        // 帧率提示
                        HoverableText {
                            id: frameRateTip
                            anchors {
                                left: parent.left
                                leftMargin: 63
                                right: parent.right
                            }
                            font.pixelSize: 11
                            visible: text !== ""
                            cursorChanged: false
                            color: Colors.color_666666
                            lineHeight: 16
                            toastVisible: implicitWidth / 2 > width
                        }
                    }
                    // 码率
                    Column {
                        width: parent.width
                        spacing: 8  // 内部间距

                        Rectangle {
                            id: bitrateRectangle
                            property bool bitrateSelecting: false

                            width: parent.width
                            height: 28
                            color: Colors.color_transparent

                            HoverableText {
                                id: bitrateText
                                anchors {
                                    left: parent.left
                                    verticalCenter: parent.verticalCenter
                                }
                                horizontalAlignment: Text.AlignLeft
                                verticalAlignment: Text.AlignVCenter
                                font.pixelSize: 12
                                color: Colors.color_CCCCCC
                                text: qsTr("pccut_export_bitrate")
                            }

                            Rectangle {
                                id: bitrateChoose
                                anchors {
                                    left: parent.left
                                    //leftMargin: maxLeftItemTextWidth
                                    leftMargin: 63
                                    top: parent.top
                                    bottom: parent.bottom
                                    right: parent.right
                                }
                                color: {
                                    if (bitrateChooseArea.containsMouse) {
                                        return Colors.color_68696D
                                    } else if (bitrateRectangle.resolutionSelecting) {
                                        return Colors.color_454649
                                    } else {
                                        return Colors.color_454649
                                    }
                                }
                                radius: RadiusConfig.radius_4_8

                                Image {
                                    id: bitrateChooseImage
                                    anchors {
                                        right: parent.right
                                        rightMargin: 8
                                        verticalCenter: parent.verticalCenter
                                    }
                                    width: 20
                                    height: 20
                                    source: bitrateRectangle.bitrateSelecting ? "qrc:/icons/adjustment/icon_drop_down_menu_collapse.svg" : "qrc:/icons/adjustment/icon_drop_down_menu_expand.svg"
                                    sourceSize: Qt.size(20, 20)
                                }

                                Text {
                                    id: bitrateChooseBtn
                                    anchors {
                                        left: parent.left
                                        leftMargin: 8
                                        top: parent.top
                                        bottom: parent.bottom
                                        right: bitrateChooseImage.left
                                    }
                                    horizontalAlignment: Text.AlignLeft
                                    verticalAlignment: Text.AlignVCenter
                                    color: Colors.color_FFFFFF
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                }

                                MouseArea {
                                    id: bitrateChooseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        bitrateRectangle.bitrateSelecting = true;
                                        bitrateSettingPanel.active = true
                                        bitrateSettingPanel.item.show(bitrateChoose, selectBitrateType);
                                        eventTracker.trackEvent("pccut_export_bitrate")
                                    }
                                }
                            }

                            Connections {
                                target: bitrateSettingPanel.item
                                function onSelectedItemSignal(title, type) {
                                    bitrateRectangle.bitrateSelecting = false;
                                    bitrateChooseBtn.text = title;
                                    selectBitrateType = type;
                                    refreshFileMB(true);
                                }
                                function onCloseSignal() {
                                    bitrateRectangle.bitrateSelecting = false;
                                }
                            }
                        }

                        // 码率自定义调整
                        Rectangle {
                            id: bitrateCustomRectangle
                            anchors.left: parent.left
                            anchors.leftMargin: 63
                            anchors.right: parent.right
                            visible: selectBitrateType === VideoConfig.BITRATETYPE_CUSTOM
                            height: 24
                            color: Colors.color_transparent

                            LightBaseSlider {
                                id: baseSlider
                                anchors {
                                    verticalCenter: parent.verticalCenter
                                    left: parent.left
                                }
                                leftPadding: 0
                                rightPadding: 0
                                width: 138
                                from: 1
                                to: {
                                    // 对应分辨率的enum，详情可查看video_config.h的ResolutionType类
                                    switch (selectResolutionType) {
                                    case 0:
                                    case 1:
                                    case 2:
                                    case 3:
                                        return 30
                                    case 4:
                                    case 5:
                                    case 6:
                                        return 50
                                    case 7:
                                        return 100
                                    case 8:
                                    case 9:
                                    case 10:
                                        return 160
                                    case 11:
                                    case 12:
                                        return 300
                                    case 13:
                                    case 14:
                                    case 15:
                                    case 16:
                                        return 480
                                    default:
                                        return 480
                                    }
                                }

                                value: 30
                                stepSize: 1
                                snapMode: Slider.SnapAlways
                                Accessible.role: Accessible.Slider

                                onMoved: {
                                    if (pressed) {
                                        refreshFileMB(true);
                                    }
                                }

                                onPressedChanged: {
                                    refreshFileMB(true);
                                }
                                onValueChanged: {
                                    bitrateCustomInput.text = value.toString();
                                }
                            }
                            Rectangle {
                                id: inputtext
                                anchors {
                                    left: baseSlider.right
                                    leftMargin: 8
                                    top: parent.top
                                    bottom: parent.bottom
                                }
                                width: 56
                                height: 24
                                color: Colors.color_666666_50
                                radius: 4
                                TextInput {
                                    id: bitrateCustomInput
                                    anchors.fill: parent
                                    clip: true
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    selectByMouse: true
                                    color: Colors.color_FFFFFF
                                    text: baseSlider.value.toString()

                                    inputMethodHints: Qt.ImhDigitsOnly
                                    // 设置选中文本的颜色
                                    selectedTextColor: Colors.color_2E2E2E
                                    // 设置选中背景的颜色
                                    selectionColor: Colors.color_EEEEEE
                                    onEditingFinished: {
                                        // 回车时保存当前文本
                                        changeText(text);
                                        bitrateCustomInput.focus = false;
                                    }
                                    onActiveFocusChanged: {
                                        if (!bitrateCustomInput.activeFocus) {
                                            // 失去焦点时保存当前文本
                                            changeText(text);
                                        }
                                    }
                                    onTextChanged: {
                                        if(text !== "") {
                                            var newValue = parseInt(text);
                                            if (newValue > baseSlider.to) {
                                                newValue = baseSlider.to;
                                            }
                                            text = newValue;
                                        }
                                    }
                                    function changeText(currentText) {
                                        if(currentText !== "") {
                                            var newValue = parseInt(currentText);
                                            if (newValue < baseSlider.from) {
                                                newValue = baseSlider.from;
                                            } else if (newValue > baseSlider.to) {
                                                newValue = baseSlider.to;
                                            }
                                            baseSlider.value = newValue;
                                        }
                                        bitrateCustomInput.text = baseSlider.value.toString();
                                        refreshFileMB(true);
                                    }
                                }
                            }
                            Text {
                                id:mbpsText
                                anchors {
                                    left: inputtext.right
                                    leftMargin: 8
                                    top: parent.top
                                    bottom: parent.bottom
                                }
                                horizontalAlignment: Text.AlignLeft
                                verticalAlignment: Text.AlignVCenter
                                color: Colors.color_FFFFFF
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                text:"Mbps"
                            }
                            Connections {
                                target: baseSlider
                                function onValueChanged() {
                                    bitrateCustomInput.text = baseSlider.value.toString();
                                }
                            }
                        }
                    }
                    // 色彩空间
                    
                    Item {
                        height: 28
                        width: parent.width
                        HoverableText {
                            anchors {
                                left: parent.left
                                verticalCenter: parent.verticalCenter
                            }
                            horizontalAlignment: Text.AlignLeft
                            verticalAlignment: Text.AlignVCenter
                            font.pixelSize: 12
                            color: Colors.color_CCCCCC
                            text: qsTr("pccut_hdr_project_setting_colorspace_label")
                        }
                        Text {
                            anchors {
                                left: parent.left
                                leftMargin: 63
                                top: parent.top
                                verticalCenter: parent.verticalCenter
                            }
                            horizontalAlignment: Text.AlignLeft
                            verticalAlignment: Text.AlignVCenter
                            font.pixelSize: 12
                            color: Colors.color_CCCCCC
                            opacity: parent.enabled?1:0.2
                            text: composeSetting.colorSpace
                        }
                    }
                    // 分割线
                    BaseSpliter {
                        id: line2
                        width: parent.width
                    }

                    Column {
                        width: parent.width
                        spacing: 8  // 内部间距

                        //画质降噪
                        Item {
                            id: deNoiseRectangle
                            visible: true
                            height: deNoiseText.height + deNoiseDesc.height + 4
                            width: parent.width
                            Text {
                                id: deNoiseText
                                anchors {
                                    left: parent.left
                                    top: parent.top
                                }
                                height: 16
                                horizontalAlignment: Text.AlignLeft
                                verticalAlignment: Text.AlignVCenter
                                font.pixelSize: 12
                                color: Colors.color_CCCCCC
                                opacity: parent.enabled?1:0.2
                                text: qsTr("pccut_export_noise_reduction")
                            }
                            LightBaseSwitch {
                                id: denoise_control
                                anchors {
                                    right: parent.right
                                    top: parent.top
                                }
                                onToggledSignal: {
                                    if (checked) {
                                        denoiseVM.isEnable = true
                                        if(editorManager.hasImageClip()){
                                            toast.showToast(qsTr("pccut_export_file_noise_reduction"));
                                        }
                                    } else {
                                        denoiseVM.isEnable = false
                                    }
                                }
                            }

                            Text {
                                id: deNoiseDesc
                                anchors {
                                    left: parent.left
                                    top: deNoiseText.bottom
                                    topMargin: 4
                                    right:parent.right
                                }
                                horizontalAlignment: Text.AlignLeft
                                verticalAlignment: Text.AlignVCenter
                                wrapMode: Text.Wrap
                                font.pixelSize: 11
                                color: Colors.color_666666
                                opacity: parent.enabled?1:0.2
                                text: qsTr("pccut_export_noise_reduction_description")
                            }
                        }

                        Loader {
                            id: denoiseLoader
                            active: denoise_control.checked
                            height: active ? 28 : 0

                            //选择降噪方式
                            sourceComponent:Rectangle {
                                id: denoiseRectangle
                                visible: denoise_control.checked
                                height: 28
                                width: scrollContent.width
                                color: Colors.color_transparent
                                property bool denoiseSelecting: false

                                // 降噪类型选择
                                DenoiseSettingPanel {
                                    id: denoiseSettingPanel
                                }

                                Rectangle {
                                    id: denoiseTypeChoose
                                    anchors {
                                        left: parent.left
                                        top: parent.top
                                        right: parent.right
                                        bottom: parent.bottom
                                    }
                                    color: {
                                        if (denoiseChooseArea.containsMouse) {
                                            return Colors.color_68696D
                                        } else {
                                            return Colors.color_454649
                                        }
                                    }
                                    radius: RadiusConfig.radius_4_8

                                    Image {
                                        id: denoiseChooseImage
                                        anchors {
                                            right: parent.right
                                            rightMargin: 8
                                            verticalCenter: parent.verticalCenter
                                        }
                                        width: 20
                                        height: 20
                                        source: denoiseRectangle.denoiseSelecting ? "qrc:/icons/adjustment/icon_drop_down_menu_collapse.svg" : "qrc:/icons/adjustment/icon_drop_down_menu_expand.svg"
                                        sourceSize: Qt.size(20, 20)
                                    }

                                    Text {
                                        id: denoiseChooseBtn
                                        text: selectDenoiseTypeName
                                        anchors {
                                            left: parent.left
                                            leftMargin: 8
                                            top: parent.top
                                            bottom: parent.bottom
                                            right: denoiseChooseImage.left
                                        }
                                        horizontalAlignment: Text.AlignLeft
                                        verticalAlignment: Text.AlignVCenter
                                        color: Colors.color_FFFFFF
                                        font.pixelSize: 12
                                        font.weight: Font.DemiBold
                                    }

                                    MouseArea {
                                        id: denoiseChooseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: {
                                            denoiseRectangle.denoiseSelecting = true;
                                            denoiseSettingPanel.show(denoiseTypeChoose, selectDenoiseType);
                                        }
                                    }

                                    Connections {
                                        target: denoiseSettingPanel
                                        function onSelectedItemSignal(title, type) {
                                            denoiseRectangle.denoiseSelecting = false;
                                            selectDenoiseTypeName = title;
                                            selectDenoiseType = type;
                                            let denoiseType = (selectDenoiseType == 0 ? "small_noise_reduction" : "noise_reduction");
                                            if(denoiseType === "small_noise_reduction")
                                            {
                                                UsedFunctionManager.removeFunction(projectId,UsedFunctionManager.EditorFunctionType.NOISE_REDUCTION);
                                                UsedFunctionManager.removeFunction(projectId,UsedFunctionManager.EditorFunctionType.SMALL_NOISE_REDUCTION);
                                                UsedFunctionManager.addFunction(projectId,UsedFunctionManager.EditorFunctionType.SMALL_NOISE_REDUCTION);
                                            }
                                            if(denoiseType === "noise_reduction")
                                            {
                                                UsedFunctionManager.removeFunction(projectId,UsedFunctionManager.EditorFunctionType.SMALL_NOISE_REDUCTION);
                                                UsedFunctionManager.removeFunction(projectId,UsedFunctionManager.EditorFunctionType.NOISE_REDUCTION);
                                                UsedFunctionManager.addFunction(projectId,UsedFunctionManager.EditorFunctionType.NOISE_REDUCTION);
                                            }
                                            refreshFileMB(true);
                                        }
                                        function onCloseSignal() {
                                            denoiseRectangle.denoiseSelecting = false;
                                        }
                                    }
                                }
                            }
                        }
                    }


                    //10bit选项
                    Item {
                        id: colorDepthRectangle
                        width: parent.width

                        height: colorDepthText.height + colorDepthDesc.height + 4 + (hdrTipDesc.visible ? hdrTipDesc.height + 2 : 0 )
                        Text {
                            id: colorDepthText
                            anchors {
                                left: parent.left
                                top: parent.top
                            }
                            height: 16
                            horizontalAlignment: Text.AlignLeft
                            verticalAlignment: Text.AlignVCenter
                            font.pixelSize: 12
                            color: Colors.color_CCCCCC
                            text: qsTr("pccut_export_10bit")
                        }
                        LightBaseSwitch {
                            id: colorDepthSwitch
                            anchors {
                                right: parent.right
                                top: parent.top
                            }
                            onToggledSignal: {
                                if (checked) {
                                    UsedFunctionManager.addFunction(projectId,UsedFunctionManager.EditorFunctionType.EXPORT_10BIT);
                                    composeSetting.setColorDepth(10)
                                    if(isSupportDolbyVision) {
                                        dolbyVisionSwitch.enabled = true
                                    }
                                } else {
                                    UsedFunctionManager.removeFunction(projectId,UsedFunctionManager.EditorFunctionType.EXPORT_10BIT);
                                    composeSetting.setColorDepth(8)
                                    dolbyVisionSwitch.checked = false
                                    dolbyVisionSwitch.enabled = false
                                }
                            }
                        }

                        Text {
                            id: colorDepthDesc
                            anchors {
                                left: parent.left
                                top: colorDepthText.bottom
                                topMargin: 4
                                right:parent.right
                            }
                            horizontalAlignment: Text.AlignLeft
                            verticalAlignment: Text.AlignVCenter
                            wrapMode: Text.Wrap
                            font.pixelSize: 11
                            color: Colors.color_666666
                            text: qsTr("pccut_export_10bit_tips")
                        }
                        Text {
                            id: hdrTipDesc
                            visible: composeSetting.isHdrEnabled
                            anchors {
                                left: parent.left
                                top: colorDepthDesc.bottom
                                topMargin: 4
                                right:parent.right
                            }
                            horizontalAlignment: Text.AlignLeft
                            verticalAlignment: Text.AlignVCenter
                            wrapMode: Text.Wrap
                            font.pixelSize: 11
                            color: Colors.color_3392FF
                            text: qsTr("pccut_hdr_export_10bit_warning_hint")
                        }
                    }

                    // 方向锁定（仅达芬奇格式 + 全景模式下显示）
                    Item {
                        id: orientationLockItem
                        visible: isDaVinciFormat && panoCheckBox.checked
                        width: parent.width
                        height: 16
                        Text {
                            anchors {
                                left: parent.left
                                verticalCenter: parent.verticalCenter
                            }
                            font.pixelSize: 12
                            color: Colors.color_CCCCCC
                            text: qsTr("pccut_panel_image_directionlock")
                        }
                        LightBaseSwitch {
                            id: orientationLockSwitch
                            anchors {
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                            }
                            checked: true
                        }
                    }

                    //杜比视界
                    Item {
                        id: dolbyVisionRectangle
                        visible: false
                        width: parent.width
                        height: dolbyVisionText.height + dolbyVisionDesc.height + 4
                        Text {
                            id: dolbyVisionText
                            anchors {
                                left: parent.left
                                top: parent.top
                            }
                            height: 16
                            horizontalAlignment: Text.AlignLeft
                            verticalAlignment: Text.AlignVCenter
                            font.pixelSize: 12
                            color: Colors.color_CCCCCC
                            text: qsTr("pccut_export_HDR_switch")
                        }
                        LightBaseSwitch {
                            id: dolbyVisionSwitch
                            anchors {
                                right: parent.right
                                top: parent.top
                            }
                        }

                        Text {
                            id: dolbyVisionDesc
                            anchors {
                                left: parent.left
                                top: dolbyVisionText.bottom
                                topMargin: 4
                                right:parent.right
                            }
                            horizontalAlignment: Text.AlignLeft
                            verticalAlignment: Text.AlignVCenter
                            wrapMode: Text.Wrap
                            font.pixelSize: 11
                            color: Colors.color_666666
                            text: qsTr("pccut_export_HDR_tip")
                        }
                    }

                    // 分割线
                    BaseSpliter {
                        id: line1
                        width: parent.width
                        visible: !panoCheckBox.checked && !isDaVinciFormat
                    }

                    Column {
                        width: parent.width
                        WaterMarkSetting {
                            id: waterMarkSetting
                            visible: !panoCheckBox.checked && !isDaVinciFormat
                            isExport: true
                            width: parent.width
                            onRefreshCoverImage: {
                                if(!panoCheckBox.checked) {
                                    refreshCover(false, false)
                                }
                            }
                        }
                        Item {
                            width: parent.width
                            height: 4
                        }
                    }
                }
            }

            // 文件大小
            Rectangle {
                id: fileSizeArea
                anchors {
                    left: parent.left
                    leftMargin: 28
                    right: parent.right
                    rightMargin: 28
                    bottom: parent.bottom
                    bottomMargin: 24
                }
                width: parent.width / 2
                height: 31
                color: Colors.color_transparent

                Text {
                    id: fileSizeText
                    anchors {
                        left: parent.left
                        top: parent.top
                        right: parent.right
                    }
                    height: 13
                    font.pixelSize: 9
                    color: Colors.color_FFFFFF_60
                    verticalAlignment: Text.AlignVCenter
                    text: qsTr("pccut_export_size")
                }

                Row {
                    anchors {
                        left: parent.left
                        top: fileSizeText.bottom
                        topMargin: 2
                    }
                    height: 18
                    spacing: 8

                    Text {
                        id: estimateText
                        height: parent.height
                        font.pixelSize: 14
                        color: Colors.color_FFFFFF
                        verticalAlignment: Text.AlignVCenter
                        text: "--"
                    }

                    SpaceWarningTip {
                        anchors.verticalCenter: parent.verticalCenter
                        spaceInsufficient: filePathControl.spaceInsufficient
                        spaceLow: filePathControl.spaceLow
                    }
                }
                // 导出按钮
                BaseConfirmBtn {
                    id: exportButton
                    objectName: actionableItemName.exportConfirm
                    btnText:qsTr("pccut_menu_export")
                    width: 88
                    height: 28
                    type: 0
                    clickEnabled: composePopup.pathAccessible
                    canUse: clickEnabled
                    Accessible.role: Accessible.Button
                    Accessible.description: "filmexport_exportconfirm"
                    anchors {
                        right: parent.right
                        top: parent.top
                    }
                    property bool canClick: true
                    Timer {
                        id: clickTimer
                        interval: 500 // 500 毫秒
                        onTriggered: {
                            exportButton.canClick = true
                        }
                    }
                    onCustomClick:() => {
                                      logger.i("[NOVA][EXPORT] ComposePanel confirm click, canClick=" + exportButton.canClick
                                               + " clickEnabled=" + exportButton.clickEnabled
                                               + " canUse=" + exportButton.canUse
                                               + " selectComposeRange=" + selectComposeRange
                                               + " selectComposeType=" + selectComposeType
                                               + " entranceType=" + entranceType);
                                      if (exportButton.canClick) {
                                          exportButton.canClick = false
                                          if(exportEventClick() === false) {
                                              clickTimer.start()
                                              return;
                                          }
                                          clickTimer.start()
                                          globalSignal.clickExportButton()
                                      } else {
                                          logger.i("[NOVA][EXPORT] confirm click dropped by canClick=false (500ms debounce)");
                                      }
                                  }
                }

                BaseConfirmBtn {
                    id: cancelBtn
                    btnText:qsTr("pccut_draft_delete_popup_cancel")
                    width: 88
                    height: 28
                    type: 1
                    Accessible.role: Accessible.Button
                    Accessible.description: "filmexport_exportconfirm"
                    anchors {
                        right: exportButton.left
                        top: exportButton.top
                        rightMargin: 8
                    }
                    onCustomClick:() => {
                                      logger.i("[Compose] ComposePanel cancel click");
                                      composePopup.close()
                                      onClosed()
                                      composeLoader.active = false
                                      eventTracker.trackEvent("pccut_export_cancel_click")
                                  }
                }
            }
        }

        // 全景视频达芬奇提示气泡，使用 Loader 按需创建，避免初始化时加载
        Timer {
            id: panoRadioHintPositionTimer
            interval: 250
            onTriggered: {
                if (!panoCheckBox.visible || !panoCheckBox.canUse) return
                panoRadioHintLoader.active = true
            }
        }

        Loader {
            id: panoRadioHintLoader
            active: false
            sourceComponent: Component {
                LightPopup {
                    width: composePopup.width
                    height: composePopup.height
                    z: 9999  // 确保提示气泡显示在 composePopup 所有子元素之上，与文件内其他 popup 保持一致
                    modal: false
                    needTransparent: true

                    Component.onDestruction: {
                        // Loader 销毁时自动停止内部动画，防止动画目标析构后引发访问异常
                        panoRadioHintShowAnim.stop()
                        panoRadioHintAutoCloseTimer.stop()
                    }

                    Component.onCompleted: {
                        Qt.callLater(function() {
                            // 居中对齐全景视频文字，弹窗在文字上方
                            var visualAdjustX = -3  // 视觉对齐微调
                            var pos = panoCheckBox.mapToItem(null,
                                panoCheckBox.width / 2 - panoRadioHintCallout.width / 2 + visualAdjustX,
                                -panoRadioHintCallout.height
                            )
                            panoRadioHintCallout.x = pos.x
                            panoRadioHintCallout.y = pos.y
                            panoRadioHintCallout.opacity = 0
                            panoRadioHintCallout.scale = 0.7
                            panoRadioHintCallout.slideY = 6
                            open()
                            // 气泡确认展示后才保存标志，防止面板提前关闭时标志被误置
                            lightSetting.save("pano_radio_hint_seen", true)
                            panoRadioHintShowAnim.start()
                            panoRadioHintAutoCloseTimer.start()
                        })
                    }

                    contentItem: Item {
                        MouseArea {
                            anchors.fill: parent
                            propagateComposedEvents: true
                            onClicked: function(mouse) {
                                panoRadioHintAutoCloseTimer.stop()
                                panoRadioHintShowAnim.stop()
                                close()
                                mouse.accepted = false
                                panoRadioHintLoader.active = false
                            }
                        }
                        Item {
                            id: panoRadioHintCallout
                            width: panoRadioHintBody.width
                            height: panoRadioHintBody.height + 5  // 5 = 三角可见部分 (图片高8 - topMargin重叠3)
                            opacity: 0
                            scale: 0.7
                            transformOrigin: Item.Bottom
                            property real slideY: 6
                            transform: Translate { y: panoRadioHintCallout.slideY }
                            Rectangle {
                                id: panoRadioHintBody
                                width: panoRadioHintText.contentWidth + 24
                                height: 28
                                anchors.top: parent.top
                                color: Colors.color_FFFFFF
                                radius: 4
                                layer.enabled: true
                                layer.effect: DropShadow {
                                    horizontalOffset: 0
                                    verticalOffset: 0
                                    radius: 10
                                    color: Colors.color_000000_40
                                }
                                Text {
                                    id: panoRadioHintText
                                    anchors.centerIn: parent
                                    text: qsTr("pccut_hdr_export_davinci_new_tip")
                                    font.pixelSize: 12
                                    color: Colors.color_141414
                                }
                            }
                            // 三角形：在矩形下方，尖端朝下指向全景视频文字
                            Image {
                                width: 12
                                height: 8
                                source: "qrc:/icons/region_guide_begin_bottom.svg"
                                rotation: 0
                                anchors.top: panoRadioHintBody.bottom
                                anchors.topMargin: -3
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }
                        ParallelAnimation {
                            id: panoRadioHintShowAnim
                            NumberAnimation { target: panoRadioHintCallout; property: "opacity"; from: 0; to: 1; duration: 400; easing.type: Easing.OutCubic }
                            NumberAnimation { target: panoRadioHintCallout; property: "slideY"; from: 6; to: 0; duration: 400; easing.type: Easing.OutCubic }
                            NumberAnimation { target: panoRadioHintCallout; property: "scale"; from: 0.7; to: 1.0; duration: 400; easing.type: Easing.OutBack }
                        }
                        Timer {
                            id: panoRadioHintAutoCloseTimer
                            interval: 15000
                            onTriggered: {
                                panoRadioHintShowAnim.stop()
                                close()
                                panoRadioHintLoader.active = false
                            }
                        }
                    }
                }
            }
        }

        // 导出目标路径已存在文件,询问是否覆盖
        ConfirmPopup {
            id: fileOverwriteAlert
            property string outputPath: ""
            property var videoInfo: ({})
            title: qsTr("pccut_export_still_export_exists")
            text: qsTr("pccut_export_still_export_exists_description")
            leftButtonText: qsTr("pccut_export_still_export_exists_cancel")
            rightButtonText: qsTr("pccut_shortcut_space_customize_warn_cover")
            onRightButtonClicked: {
                startExportEvent(outputPath, videoInfo);
            }
            onLeftButtonClicked: {
                // DB 记录在草稿异步保存成功后才写入（onSaveComposeDraftFileSuccessSignal），
                // 此处 startExportEvent 尚未被调用，exportDataTable 中无记录可删，不需要 delete。
                ExportEventReport.reportComposeFailed(ExportEventReport.ERROR_CODE_4108, videoInfo);
            }
        }

        // 导出目标路径已存在,询问是否覆盖
        ConfirmPopup {
            id: dirOverwriteAlert
            property string outputPath: ""
            property var videoInfo: ({})
            title: qsTr("pccut_export_clip_still_export_exists")
            text: qsTr("pccut_export_clip_still_export_exists_description")
            leftButtonText: qsTr("pccut_export_clip_still_export_exists_cancel")
            rightButtonText: qsTr("pccut_shortcut_space_customize_warn_cover")
            onRightButtonClicked: {
                startExportEvent(outputPath, videoInfo);
            }
            onLeftButtonClicked: {
                // DB 记录在草稿异步保存成功后才写入（onSaveComposeDraftFileSuccessSignal），
                // 此处 startExportEvent 尚未被调用，exportDataTable 中无记录可删，不需要 delete。
                ExportEventReport.reportComposeFailed(ExportEventReport.ERROR_CODE_4109, videoInfo);
            }
        }
    }

    Connections {
        target: globalSignal
        function onExportImageSaved(path,canvas){
            switch(canvas){
            case VideoConfig.CANVASRATIOTYPE_2_1:{
                picTips.text = qsTr("pccut_export_panorama_tips_4")
                picTips.visible = (picTips.text !== "");
                break;
            }
            }
            composePopup.coverpath = path
            //logger.d("simmy:cover path=" + path);
            imageLoader.sourceComponent = picComponent  // 再重新设置
            imageLoader.active = true; // 重新激活Loader
            imageLoadSuccess = true;
        }

        function onExportSelectFragmentImageSaved(path){
            composePopup.coverpath = path
            imageLoader.sourceComponent = picComponent;
            imageLoadSuccess = true;
        }
    }

    //刷新缩略图 useDraftCover(是否使用草稿中的封面)
    function refreshCover(useCylinder, useDraftCover){
        picRectangle.width = 212;
        picRectangle.height = 117;
        picRectangle.anchors.leftMargin = 28;

        imageLoader.sourceComponent = picLoadingComponent;
        imageLoader.active = true; // 重新激活Loader
        picTips.visible = false;

        switch(editorManager.getCurrentCanvasType()){
        case VideoConfig.CANVASRATIOTYPE_1_1:{
            picRectangle.width = 212;
            picRectangle.height = 212;
            picRectangle.anchors.leftMargin = 28;
            break;
        }
        case VideoConfig.CANVASRATIOTYPE_3_4:{
            picRectangle.width = 159;
            picRectangle.height = 212;
            picRectangle.anchors.leftMargin = 54;
            break;
        }
        case VideoConfig.CANVASRATIOTYPE_4_3:{
            picRectangle.width = 212;
            picRectangle.height = 159;
            picRectangle.anchors.leftMargin = 28;
            break;
        }
        case VideoConfig.CANVASRATIOTYPE_9_16:{
            picRectangle.width = 117;
            picRectangle.height = 212;
            picRectangle.anchors.leftMargin = 76;
            break;
        }
        case VideoConfig.CANVASRATIOTYPE_16_9:
        case VideoConfig.CANVASRATIOTYPE_16_9_SETTING:{
            picRectangle.width = 212;
            picRectangle.height = 117;
            picRectangle.anchors.leftMargin = 28;
            break;
        }
        default:{
            break;
        }
        }
        if(useCylinder){
            picRectangle.width = 212;
            picRectangle.height = 106;
            picRectangle.anchors.leftMargin = 28;
        }

        imageLoadSuccess = false;
        var isUpdate = editorDraftManager.lastSaveIsUpdateCover();
        // 导出按钮入口(entranceType===0)：当场抓帧(active env snapshot)反映最新编辑态，
        // 不读磁盘封面——存稿节流未落盘时磁盘封面仍是旧的，会致“打开两次才刷新”。
        // 右键菜单入口(entranceType===1)保留读选中片段持久化封面。
        if(entranceType === 1 && useDraftCover && isUpdate){
            refreshCoverSelectFragment();
        }else{
            //(entranceType === 1)右键菜单入口，获取的封面是用户选择的第一个视频的封面
            editorManager.generatePic(useCylinder, true, (entranceType === 1), selectComposeRange);
        }
    }
    // 保存当前模式下会被 refreshResolution/refreshBitrate 覆盖的参数
    function saveCurrentModeParams() {
        var params = {
            resolutionType: selectResolutionType,
            bitrateType: selectBitrateType,
            bitrateCustom: baseSlider.value,
            orientationLock: orientationLockSwitch.checked,
            frameRateType: selectFrameRateType,
            denoiseChecked: denoise_control.checked,
            denoiseType: selectDenoiseType,
            colorDepthChecked: colorDepthSwitch.checked,
            savePath: composeExportViewModel.savePath,
            composeType: selectComposeType,
            composeRange: selectComposeRange
        }
        if (panoCheckBox.checked) {
            _panoParams = params
        } else {
            _videoParams = params
        }
    }

    // 将参数对象落盘到 LightSetting
    function persistParams(params, isPano) {
        fileOperator.setExportFolder(params.savePath, isPano)
        fileOperator.setQMLExportResolution(params.resolutionType, isPano)
        fileOperator.setQMLExportFrameRate(params.frameRateType, isPano)
        fileOperator.setQMLExportBitrate(params.bitrateType, isPano)
        fileOperator.setExportBitrateCustom(params.bitrateCustom, isPano)
        denoiseVM.setDenoiseType(params.denoiseType, isPano)
        if (params.denoiseChecked !== undefined) {
            denoiseVM.setDenoiseChecked(params.denoiseChecked, isPano)
        }
        if (params.colorDepthChecked !== undefined) {
            fileOperator.setQMLExportColorDepthChecked(params.colorDepthChecked, isPano)
        }
        fileOperator.setQMLExportComposeType(params.composeType, isPano)
        fileOperator.setQMLExportComposeRange(params.composeRange, isPano)
    }

    // 恢复目标模式的参数（有内存缓存用缓存，否则从 fileOperator 读取）
    function restoreModeParams(isPano) {
        var params = isPano ? _panoParams : _videoParams
        if (params !== null) {
            selectResolutionType = params.resolutionType
            resolutionChooseBtn.text = (function() {
                let r = videoConfig.getQmlItemByResolutionType(params.resolutionType)
                return r.name + " - " + r.width + "x" + r.height
            })()
            selectBitrateType = params.bitrateType
            bitrateChooseBtn.text = videoConfig.getItemByBitrateType(params.bitrateType)
            selectBitrateCustom = params.bitrateCustom
            baseSlider.value = params.bitrateCustom
            if (params.orientationLock !== undefined) {
                orientationLockSwitch.checked = params.orientationLock
            }
            selectFrameRateType = params.frameRateType
            frameRateChooseBtn.text = videoConfig.getQmlItemByFrameRateType(params.frameRateType).name
            if (params.denoiseChecked !== undefined) {
                denoise_control.checked = params.denoiseChecked
                denoiseVM.isEnable = params.denoiseChecked
            }
            selectDenoiseType = params.denoiseType
            selectDenoiseTypeName = videoConfig.getItemByDenoiseType(params.denoiseType)
            if (params.colorDepthChecked !== undefined) {
                colorDepthSwitch.checked = params.colorDepthChecked
                composeSetting.setColorDepth(params.colorDepthChecked ? 10 : 8)
            }
            composeExportViewModel.savePath = params.savePath
            selectComposeType = params.composeType
            composeTypeChooseBtn.text = videoConfig.getItemByComposeType(params.composeType)
            selectComposeRange = params.composeRange
            composeRangeChooseBtn.text = videoConfig.getItemByComposeRange(params.composeRange)
        } else {
            refreshResolution(isPano)
            refreshBitrate()
            selectFrameRateType = fileOperator.getQMLExportFrameRate(isPano)
            frameRateChooseBtn.text = videoConfig.getQmlItemByFrameRateType(selectFrameRateType).name
            selectDenoiseType = denoiseVM.getDenoiseType(isPano)
            selectDenoiseTypeName = videoConfig.getItemByDenoiseType(selectDenoiseType)
            if (denoiseVM.hasDenoiseChecked(isPano)) {
                denoise_control.checked = denoiseVM.getDenoiseChecked(isPano)
                denoiseVM.isEnable = denoise_control.checked
            }
            let colorDepthKey = isPano ? "key_export_pano_color_depth_checked" : "key_export_color_depth_checked"
            if (lightSetting.contains(colorDepthKey)) {
                colorDepthSwitch.checked = fileOperator.getQMLExportColorDepthChecked(isPano)
                composeSetting.setColorDepth(colorDepthSwitch.checked ? 10 : 8)
            }
            composeExportViewModel.savePath = fileOperator.getExportFolder(isPano)
            selectComposeType = fileOperator.getQMLExportComposeType(isPano)
            composeTypeChooseBtn.text = videoConfig.getItemByComposeType(selectComposeType)
            selectComposeRange = fileOperator.getQMLExportComposeRange(isPano)
            composeRangeChooseBtn.text = videoConfig.getItemByComposeRange(selectComposeRange)
        }
        // 路径或导出方式变化后刷新文件名：
        // - 用户未修改过文件名 → 重新生成不重复的默认名
        // - 用户已修改 → 保持用户输入（DuplicateFileWarning 负责提示重复）
        refreshFileName(selectComposeType)
    }

    //刷新分辨率
    function refreshResolution(isPano){
        if (isPano === undefined) isPano = false;
        const validTypes = videoConfig.getExportResolutionTypes(isPano);
        let cached = fileOperator.getQMLExportResolution(isPano);
        selectResolutionType = validTypes.includes(cached) ? cached : validTypes[0];
        let resolution = videoConfig.getQmlItemByResolutionType(selectResolutionType);
        //判断是否支持4K
        let colorDepth = 8
        if(editorManager.has10bitClip() && composeSetting.colorDepth === 10){
            colorDepth = 10
        }
        let cardParams = editorManager.getCardEncodeParams(colorDepth);
        if(cardParams.abTest == true && cardParams.valid == true && CommonUtils.isWindows() && panoCheckBox.checked === false && selectResolutionType === VideoConfig.RESOLUTIONTYPE_4K) {
            let match = (resolution.width <= cardParams.maxWidth && resolution.height <= cardParams.maxHeight) ||
                        (resolution.width <= cardParams.maxHeight && resolution.height <= cardParams.maxWidth);
            if(!match) {
                selectResolutionType = VideoConfig.RESOLUTIONTYPE_1080P
                resolution = videoConfig.getQmlItemByResolutionType(selectResolutionType);
            }
        }
        resolutionChooseBtn.text = resolution.name + " - " + resolution.width + "x" + resolution.height;
    }

    //刷新码率
    function refreshBitrate(){
        var isPano = panoCheckBox.checked ? true : false;
        selectBitrateType = fileOperator.getQMLExportBitrate(isPano);
        bitrateChooseBtn.text = videoConfig.getItemByBitrateType(selectBitrateType);
        selectBitrateCustom = fileOperator.getExportBitrateCustom(isPano);
        baseSlider.value = selectBitrateCustom;
    }

    // 达芬奇格式默认参数（最高分辨率/帧率/码率，降噪效果优先，10bit开启）
    function applyDaVinciDefaults() {
        // 分辨率：全景最高档（RESOLUTIONTYPE_8K_PANO）
        selectResolutionType = VideoConfig.RESOLUTIONTYPE_8K_PANO
        let resolution = videoConfig.getQmlItemByResolutionType(selectResolutionType)
        resolutionChooseBtn.text = resolution.name + " - " + resolution.width + "x" + resolution.height

        // 帧率：下拉框中可选的最高帧率（素材上限 vs 面板最低保证FRAMERATETYPE_60，取最大值）
        // 无片段时 getTrackFragmentMaxFps 返回 UNKNOWTYPE，不参与比较，直接用 FRAMERATETYPE_60
        let maxFps = editorManager.getTrackFragmentMaxFps()
        if (maxFps === VideoConfig.UNKNOWTYPE) maxFps = VideoConfig.FRAMERATETYPE_60
        selectFrameRateType = Math.max(maxFps, VideoConfig.FRAMERATETYPE_60)
        frameRateChooseBtn.text = videoConfig.getQmlItemByFrameRateType(selectFrameRateType).name

        // 码率：较高（BITRATETYPE_HIGH = 2）
        selectBitrateType = 2
        bitrateChooseBtn.text = videoConfig.getItemByBitrateType(selectBitrateType)

        // 降噪：先同步 composeSetting，再开启开关，最后设效果优先（DENOISE_BETTER = 1）
        denoiseVM.isEnable = true
        denoise_control.enabled = true
        denoise_control.checked = true
        selectDenoiseType = 1
        selectDenoiseTypeName = videoConfig.getItemByDenoiseType(selectDenoiseType)

        // 10bit：达芬奇模式强制开启（不依赖素材是否有10bit）
        colorDepthSwitch.enabled = true
        colorDepthSwitch.checked = true
        composeSetting.setColorDepth(10)

        refreshFileMB(true)
    }

    // AB off: 切回非达芬奇格式时，还原之前保存的状态
    function restoreOriginalSettings() {
        if (_daVinciOrigState === null) return

        selectResolutionType = _daVinciOrigState.resolutionType
        resolutionChooseBtn.text = _daVinciOrigState.resolutionText

        selectFrameRateType = _daVinciOrigState.frameRateType
        frameRateChooseBtn.text = _daVinciOrigState.frameRateText

        selectBitrateType = _daVinciOrigState.bitrateType
        bitrateChooseBtn.text = _daVinciOrigState.bitrateText

        denoise_control.enabled = _daVinciOrigState.denoiseEnabled
        denoise_control.checked = _daVinciOrigState.denoiseChecked
        denoiseVM.isEnable = _daVinciOrigState.denoiseChecked
        selectDenoiseType = _daVinciOrigState.denoiseType
        selectDenoiseTypeName = _daVinciOrigState.denoiseTypeName

        colorDepthSwitch.enabled = _daVinciOrigState.colorDepthEnabled
        colorDepthSwitch.checked = _daVinciOrigState.colorDepthChecked
        composeSetting.setColorDepth(_daVinciOrigState.colorDepthChecked ? 10 : 8)

        _daVinciOrigState = null
        refreshFileMB(true)
    }

    //刷新封面（支持分段导出模式）
    function refreshCoverSelectFragment(){
        if(entranceType === 0){
            //导入按钮入口，走原来逻辑
            composePopup.coverpath = draftManager.getDraftCoverPath();
            imageLoader.sourceComponent = picComponent;
            imageLoadSuccess = true;
        }else{
            //右键菜单入口，显示第一个选中视频的封面（右键菜单会触发生成图片）
            var selCoverPath = draftManager.getSelectDraftCoverPath();
            //logger.d("simmy:selCoverPath=" + selCoverPath);
            if(selCoverPath.length === 0){
                //不存在就启动生成封面
                draftManager.generateSelectFragmentCover();
            }else{
                composePopup.coverpath = selCoverPath;
                imageLoader.sourceComponent = picComponent;
                imageLoadSuccess = true;
            }
        }
    }
    // 展示
    function show(entrance) {
        // 将上次记录的默认名字清空掉
        lastDefaultExportName = "";
        //入口类型（1右键菜单 0导出按钮）
        entranceType = (entrance !== undefined && entrance !== null && entrance === 1) ? 1 : 0;

        // 重置内存缓存，确保模式切换时从磁盘读取最新值
        _videoParams = null
        _panoParams = null

        // 从缓存恢复导出视频类型（需在 refreshResolution 前设置）
        let panoSupported = (entranceType === 1)
            ? (editorManager.isAllSelectedPanoClip() &&
               editorManager.getCurVideoType() !== MediaType.DUSS_REMUX_RECORD_PANO_VIDEO_SEMI &&
               editorManager.getCurVideoType() !== MediaType.DUSS_REMUX_RECORD_PANO_VIDEO_BULLET_TIME)
            : (editorManager.isAllPanoClip() &&
               editorManager.getCurVideoType() !== MediaType.DUSS_REMUX_RECORD_PANO_VIDEO_SEMI &&
               editorManager.getCurVideoType() !== MediaType.DUSS_REMUX_RECORD_PANO_VIDEO_BULLET_TIME)
        let isPano = fileOperator.getQMLExportVideoType() && panoSupported
        panoCheckBox.checked = isPano
        videoCheckBox.checked = !isPano
        // 全景模式下恢复上次选择的导出格式（普通全景/达芬奇）
        cachedPanoFormat = fileOperator.getQMLExportPanoFormat()
        if (isPano) {
            composeSetting.mediaExportType = cachedPanoFormat
        }
        // 跨会话恢复方向锁定开关（达芬奇 + 全景下可见，不可见时也无碍）
        orientationLockSwitch.checked = fileOperator.getQMLExportOrientationLock()

        // 分辨率
        refreshResolution(panoCheckBox.checked)
        //resolutionLabel.text = videoConfig.getQmlItemByResolutionType(selectResolutionType).width + "X" + videoConfig.getQmlItemByResolutionType(selectResolutionType).height;
        // 帧率
        selectFrameRateType = fileOperator.getQMLExportFrameRate(panoCheckBox.checked);
        frameRateChooseBtn.text = videoConfig.getQmlItemByFrameRateType(selectFrameRateType).name;
        // 降噪类型
        selectDenoiseType = abExportOptEnabled ? denoiseVM.getDenoiseType(panoCheckBox.checked) : 0;
        selectDenoiseTypeName = videoConfig.getItemByDenoiseType(selectDenoiseType);

        let denoiseType = (selectDenoiseType == 0 ? "small_noise_reduction" : "noise_reduction");
        if(denoiseType == "small_noise_reduction")
        {
            UsedFunctionManager.removeFunction(projectId,UsedFunctionManager.EditorFunctionType.NOISE_REDUCTION);
            UsedFunctionManager.addFunction(projectId,UsedFunctionManager.EditorFunctionType.SMALL_NOISE_REDUCTION);
        }
        else if(denoiseType == "noise_reduction")
        {
            UsedFunctionManager.removeFunction(projectId,UsedFunctionManager.EditorFunctionType.SMALL_NOISE_REDUCTION);
            UsedFunctionManager.addFunction(projectId,UsedFunctionManager.EditorFunctionType.NOISE_REDUCTION);
        }


        // 帧率提示
        composePopup.unifiedFrame = -1
        var isUnifiedFps = editorManager.isUnifiedFps()
        if (isUnifiedFps) {
            frameRateTip.text = ""
            composePopup.unifiedFrame = selectFrameRateType
        } else {
            frameRateTip.text = qsTr("pccut_export_frame_rate_inconsistent")
        }

        // 码率
        refreshBitrate()

        if(entranceType === 1) {
            composeRangeRectangle.visible = false;
        } else {
            composeRangeRectangle.visible = true;
            let hasRangeCompose = editorManager.hasRangeCompose();
            let cachedRange = fileOperator.getQMLExportComposeRange(panoCheckBox.checked);
            if (hasRangeCompose) {
                // 已标记出入点：默认导出标记区间
                selectComposeRange = VideoConfig.COMPOSERANGE_RANGE;
            } else if (cachedRange === VideoConfig.COMPOSERANGE_RANGE) {
                // 未标记区间：缓存的 RANGE 降级为整段
                selectComposeRange = VideoConfig.COMPOSERANGE_WHOLE;
            } else {
                selectComposeRange = cachedRange;
            }
            composeRangeChooseBtn.text = videoConfig.getItemByComposeRange(selectComposeRange);
            comopseTypeChoose.enabled = (selectComposeRange !== VideoConfig.COMPOSERANGE_RANGE);
        }
        // 导出方式
        // 右键菜单强制多段；导出按钮读缓存（标记区间时强制单段）
        if (entranceType === 1) {
            selectComposeType = 1;
        } else {
            selectComposeType = fileOperator.getQMLExportComposeType(panoCheckBox.checked);
            if (selectComposeRange === VideoConfig.COMPOSERANGE_RANGE) {
                selectComposeType = 0;
            }
        }
        composeTypeChooseBtn.text = videoConfig.getItemByComposeType(selectComposeType);

        // 保存路径
        composeExportViewModel.savePath = fileOperator.getExportFolder(panoCheckBox.checked);
        // 保存文件名 整段导出和分段导出名称重复要分别验证，一个是文件夹一个是文件
        refreshFileName(selectComposeType);

        //colorDepthSwitch.checked = false;
        refreshFileMB(true);
        composePopup.open();
    }

    // 点击导出按钮
    function exportEventClick() {
        // 检查文件夹是否存在，不存在则使用默认文件夹
        let contentDir = composePopup.currentSavePath
        logger.i("[NOVA][EXPORT] exportEventClick entry, savePath=" + contentDir
                 + " fileName=" + composePopup.currentFileName
                 + " range=" + selectComposeRange + " type=" + selectComposeType
                 + " res=" + selectResolutionType + " fps=" + selectFrameRateType
                 + " bitrate=" + selectBitrateType);
        // 这里fileOperator的操作没有考虑网络地址，目前最小改动，不进行扩充了
        if (!fileOperator.isDirExists(contentDir)) {
            fileOperator.createDir(contentDir);
        }
        // 再检查一遍，如果还是有问题，就使用默认路径
        if (!fileOperator.isDirExists(contentDir)) {
            const defaultFolder = fileOperator.getDefaultExportFolder();
            composeExportViewModel.savePath = defaultFolder;
            contentDir = defaultFolder;
        }
        const videoInfo = reportExportStartEvent();
        // 清除输入框焦点，并显式提交文件名编辑（确保空名恢复）
        contentRect.forceActiveFocus();
        fileNameControl.commitEdit();
        bitrateCustomInput.focus = false;
        var outputPath = composePopup.currentSavePath + "/" + composePopup.currentFileName + fileNameSuffix;
        //分段导出不需要后缀名
        if (selectComposeType === 1){
            outputPath = composePopup.currentSavePath + "/" + composePopup.currentFileName;
        }

        if (composePopup.currentFileName.trim().length === 0) {
            logger.i("[NOVA][EXPORT] guard reject: empty fileName");
            logger.d("文件名称有问题");
            ExportEventReport.reportComposeFailed(ExportEventReport.ERROR_CODE_4103, videoInfo);
            return;
        }
        if (composePopup.currentSavePath.trim().length === 0) {
            logger.i("[NOVA][EXPORT] guard reject: empty savePath");
            logger.d("选择的保存路径有问题");
            ExportEventReport.reportComposeFailed(ExportEventReport.ERROR_CODE_4104, videoInfo);
            return;
        }
        if (selectResolutionType === -1) {
            logger.i("[NOVA][EXPORT] guard reject: selectResolutionType=-1");
            logger.d("选择的分辨率有问题");
            ExportEventReport.reportComposeFailed(ExportEventReport.ERROR_CODE_4105, videoInfo);

            return;
        }
        if (selectFrameRateType === -1) {
            logger.i("[NOVA][EXPORT] guard reject: selectFrameRateType=-1");
            logger.d("选择的帧率有问题");
            ExportEventReport.reportComposeFailed(ExportEventReport.ERROR_CODE_4106, videoInfo);

            return;
        }
        if (selectBitrateType === -1) {
            logger.i("[NOVA][EXPORT] guard reject: selectBitrateType=-1");
            logger.d("选择的码率有问题");
            ExportEventReport.reportComposeFailed(ExportEventReport.ERROR_CODE_4107, videoInfo);
            // reportExportFiledEvent("选择的码率有问题");

            return;
        }

        if (selectComposeType === -1) {
            logger.i("[NOVA][EXPORT] guard reject: selectComposeType=-1");
            logger.d("选择的导出方式有问题");
            ExportEventReport.reportComposeFailed(ExportEventReport.ERROR_CODE_4110,videoInfo);
            return;
        }
        if (selectComposeRange === -1) {
            logger.i("[NOVA][EXPORT] guard reject: selectComposeRange=-1");
            logger.d("选择的导出范围有问题");
            ExportEventReport.reportComposeFailed(ExportEventReport.ERROR_CODE_4113, videoInfo);
            return;
        }
        // AB 实验 pccut_export_min_frame_reduce 命中时降为 1 帧，否则保持默认 3 帧，所有平台统一。
        // 统一走 C++ 侧 videoConfig.minExportFrame()，避免 QML 硬编码 key/默认值而与 C++ 走偏。
        const minExportFrame = videoConfig.minExportFrame();
        if(selectComposeRange === VideoConfig.COMPOSERANGE_RANGE) {
            let rangeFrameLength = editorManager.rangeComposeFrameLength();
            logger.i("[NOVA][EXPORT] range frame check: rangeComposeFrameLength=" + rangeFrameLength
                     + " minExportFrame=" + minExportFrame
                     + " rangeEnable=" + editorManager.hasRangeCompose());
            if(rangeFrameLength < minExportFrame) {
                logger.i("[NOVA][EXPORT] guard reject: rangeComposeFrameLength " + rangeFrameLength
                         + " < minExportFrame " + minExportFrame + " (range too short)");
                logger.d("导出范围长度小于最小帧数限制");
                toast.showToast(qsTr("pccut_export_notsupported"), "tracks");
                ExportEventReport.reportComposeFailed(ExportEventReport.ERROR_CODE_4205, videoInfo);
                return false;
            }
        }else{
            let timelineFrameLength = editorManager.timelineFrameLength();
            logger.i("[NOVA][EXPORT] timeline frame check: timelineFrameLength=" + timelineFrameLength
                     + " minExportFrame=" + minExportFrame);
            if(timelineFrameLength < minExportFrame) {
                logger.i("[NOVA][EXPORT] guard reject: timelineFrameLength " + timelineFrameLength
                         + " < minExportFrame " + minExportFrame);
                logger.d("整段长度小于最小帧数限制");
                toast.showToast(qsTr("pccut_export_notsupported"), "tracks");
                ExportEventReport.reportComposeFailed(ExportEventReport.ERROR_CODE_4205, videoInfo);
                return false;
            }
        }

        // 这个逻辑判断如果放在开头，会造成其他条件无法被校验，所以这里还是拿回到下面来
        if (selectComposeType === 1){
            if(!fileOperator.isDirExists(outputPath)){
                fileOperator.createDir(outputPath);
            }else{
                //文件夹已存在给出提示
                logger.i("[NOVA][EXPORT] dir exists, showing dirOverwriteAlert: " + outputPath);
                dirOverwriteAlert.videoInfo = videoInfo;
                dirOverwriteAlert.outputPath = outputPath;
                dirOverwriteAlert.open();
                return false;
            }
        }else{
            // 判断导出目标路径,是否已存在文件
            if (fileOperator.isExists(outputPath)) {
                logger.i("[NOVA][EXPORT] file exists, showing fileOverwriteAlert: " + outputPath);
                fileOverwriteAlert.videoInfo = videoInfo;
                fileOverwriteAlert.outputPath = outputPath;
                fileOverwriteAlert.open();
                return false;
            }
        }

        logger.i("[NOVA][EXPORT] guards passed -> startExportEvent, outputPath=" + outputPath);
        startExportEvent(outputPath, videoInfo);
        logger.i("[NOVA][EXPORT] exportEventClick done");
        return false;
    }

    function reportExportStartEvent(){
        logger.i("[NOVA][EXPORT][TEMP] reportExportStartEvent begin");
        const colorDepth = colorDepthSwitch.checked ? 10 : 8
        const denoise = denoise_control.checked ? true : false
        const dolbyVision = dolbyVisionSwitch.checked ? true : false
        const videoType = videoCheckBox.checked ? "video" : "panoramic"
        const exportId = ExportDataManager.createUuid();
        let outputPath= "";
        let exportType = "";
        let exportCnt;
        logger.i("[NOVA][EXPORT][TEMP] step1: before getComposeDataMap");
        let dataMap = editorManager.getComposeDataMap()
        logger.i("[NOVA][EXPORT][TEMP] step2: before getComposeMaterialDataMap");
        let materialDataMap = editorManager.getComposeMaterialDataMap()
        logger.i("[NOVA][EXPORT][TEMP] step3: before resolution/frameRate maps");
        let resolutionMap = videoConfig.getQmlItemByResolutionType(selectResolutionType)
        let frameRateMap = videoConfig.getQmlItemByFrameRateType(selectFrameRateType)
        let bitrateMap = { "frameRate": getBitrate() };
        logger.i("[NOVA][EXPORT][TEMP] step4: before getMediaSourceTypeList");
        let mediaSourceTypeList = editorManager.getMediaSourceTypeList()
        logger.i("[NOVA][EXPORT][TEMP] step5: before getEnableSuperSlowClips");

        let denoiseType = (selectDenoiseType == 0 ? "small_noise_reduction" : "noise_reduction");

        var enableSuperSlowClips = editorManager.getEnableSuperSlowClips();
        if(enableSuperSlowClips > 0)
        {
            UsedFunctionManager.addFunction(projectId,UsedFunctionManager.EditorFunctionType.SUPER_SLOW_MODE);
        }else{
            UsedFunctionManager.removeFunction(projectId,UsedFunctionManager.EditorFunctionType.SUPER_SLOW_MODE);
        }
        // 标记点埋点：草稿含任意标记（时间轴/素材）则记 DOT，否则清空。
        logger.i("[NOVA][EXPORT][TEMP] step6: before hasAnyMarkPoint");
        if (MarkPointToolbarViewModel.hasAnyMarkPoint(projectId)) {
            if (!UsedFunctionManager.hasFunction(projectId, UsedFunctionManager.EditorFunctionType.DOT)) {
                UsedFunctionManager.addFunction(projectId, UsedFunctionManager.EditorFunctionType.DOT);
            }
        } else {
            UsedFunctionManager.removeAllFunction(projectId, UsedFunctionManager.EditorFunctionType.DOT);
        }

        // 须在全部 add/removeFunction 之后取，UsedFunctionManager add/remove 等才进本次快照
        logger.i("[NOVA][EXPORT][TEMP] step7: before getUniqueFunctionNameList");
        let functionUsedList = UsedFunctionManager.getUniqueFunctionNameList(projectId)
        if (dataMap["dlog2_in_use"] === true) {
            functionUsedList.push("color_reproduction")
        }

        logger.i("[NOVA][EXPORT][TEMP] step8: before getSuperSlowSpeedList");
        var superSlowModeSpeedValue = editorManager.getSuperSlowSpeedList();

        if(selectComposeType === 0){
            if(selectComposeRange == VideoConfig.COMPOSERANGE_WHOLE)
            {
                exportType = "timeline";
            }
            if(selectComposeRange == VideoConfig.COMPOSERANGE_RANGE)
            {
                exportType = "scope";
            }

            exportCnt = 1;
            outputPath = composePopup.currentSavePath + "/" + composePopup.currentFileName + fileNameSuffix;
        }
        if(selectComposeType === 1){
            exportType = "clip";
            outputPath = composePopup.currentSavePath + "/" + composePopup.currentFileName;
            if(entranceType == 1){exportCnt = editorManager.getVideoFragmentCount(true);}
            if(entranceType == 0){exportCnt = editorManager.getVideoFragmentCount(false);}
        }

        // 预估导出文件大小（GB，2位小数），按入口/范围口径（与 refreshFileMB 一致）；算不出（入参非法）时为 -1
        logger.i("[NOVA][EXPORT][TEMP] step9: before composeLengthInSecond");
        const composeFileSizeMB = videoConfig.estimateComposeFileSizeWithOriginalSize(getBitrate(), composeLengthInSecond());
        const composeFileSizeGB = composeFileSizeMB > 0 ? Math.round(composeFileSizeMB / 1024 * 100) / 100 : -1;
        logger.i("[NOVA][EXPORT][TEMP] step10: before build videoInfo");

        const videoInfo = {exportId:exportId,colorDepth:colorDepth,denoise:denoise,dolbyVision:dolbyVision,export_media_type:videoType,
            dataMap:dataMap,materialDataMap:materialDataMap,function_used:functionUsedList,exportType:exportType,exportCnt:exportCnt,
            resolutionMap:resolutionMap,frameRateMap:frameRateMap,bitrateMap:bitrateMap,denoiseType:denoiseType,is_thumb_success:imageLoadSuccess,
            is_retry:false,scopeType:composeRangeToScopeType(),outputPath:outputPath,source:mediaSourceTypeList,super_slow_mode_count:enableSuperSlowClips,
            super_slow_mode_speed_value_list:superSlowModeSpeedValue,use_method:"edit",compose_file_size:composeFileSizeGB
        };


        // 保存成功后的业务逻辑（如更新UI、埋点）
        logger.i("[NOVA][EXPORT][TEMP] step11: before tempBytesAvailableWithTimeout");
        const freeStorageSizeGB = fileOperator.tempBytesAvailableWithTimeout(outputPath);
        logger.i("[NOVA][EXPORT][TEMP] step12: before getCurveSpeedTypeList/trackEvent");
        var curveSpeedTypeList = editorManager.getCurveSpeedTypeList();
        videoInfo.curve_speed_type = curveSpeedTypeList;
        logger.i("[NOVA][EXPORT][TEMP] step13: before trackEvent pccut_editor_result");
        eventTracker.trackEvent("pccut_editor_result",
                                {   "task_id": exportId || "",
                                    "number_of_materials": materialDataMap["number_of_material"] || 0,       //视频片段总数 number
                                    "clip_duration": materialDataMap["duration"] || 0,                    //原始素材时长
                                    "devices_name":materialDataMap["devices_name"] || [],            //素材包含的硬件类型
                                    "media_type": materialDataMap["media_type"] ||[],   //媒体类型 list
                                    "is_pano": materialDataMap["is_pano"]|| false,                       //是否包含全景素材
                                    "size":materialDataMap["size"]|| 0,                              //原视频大小
                                    "fps":materialDataMap["fps"]|| 0,                                //素材帧率
                                    "bitrate":materialDataMap["bitrate"]|| "",                        //素材码率
                                    "resolution":materialDataMap["resolution"]|| "",                  //素材分辨率
                                    "media_format":materialDataMap["media_format"]|| [],                //文件格式
                                    "file_format_list":materialDataMap["media_format"]|| [],            //文件格式 list
                                    "file_encode_format_list":materialDataMap["file_encode_format_list"]|| [],  //编码格式
                                    "file_color_mode_list":materialDataMap["file_color_mode_list"]|| [],        //色彩模式
                                    "is_device_material":(materialDataMap["is_device_material"] || false) ? 1 : 0,          //是否包含硬件素材
                                    "types_of_material":materialDataMap["types_of_material"]|| "",       //素材类型
                                    "is_localcube": dataMap["is_localcube"] || 0,                    //自定义lut
                                    "project_colorspace": materialDataMap["project_colorspace"]|| "", // 色彩空间
                                    "has_hdr_display": materialDataMap["has_hdr_display"]|| false, // 是否有hdr显示器
                                    "export_resolution": resolutionMap["name"]|| "",                 //分辨率 string
                                    "export_frame_rate": frameRateMap["name"]|| "",                  //帧率 string
                                    "export_frame_bitrate": bitrateMap["frameRate"] || 0,            //码率 number
                                    "export_media_type": videoCheckBox.checked ? "video" : "panoramic", //导出作品类型
                                    "export_type":exportType|| "",                                   //导出方式
                                    "export_cnt":exportCnt || 0,                                       //导出段数
                                    "work_duration": dataMap["work_duration"] || 0,                  //导出作品总时长  number
                                    "function_used":functionUsedList,                           //已使用功能列表
                                    "is_retry": false,                                         //导出重试标记
                                    "playback_speed_list": dataMap["playback_speed"]|| [],                //视频倍速 list
                                    "filter_list": dataMap["filter_slug_list"]|| [],                 //滤镜slug list
                                    "music_code_list": dataMap["music_code_list"]|| [],                //音乐slug list
                                    "movement_slug_list":dataMap["movement_slug_list"]|| [],                //运镜slug list
                                    "denoise_type": denoiseType|| "",                                //降噪类型
                                    "is_open_proxy": dataMap["is_proxy"]|| false,                        //是否代理模式 bool
                                    "is_open_10bit": colorDepthSwitch.checked,                  //是否开启10bit bool
                                    "is_open_hdr": dolbyVisionSwitch.checked,                   //是否杜比导出
                                    "is_thumb_success": imageLoadSuccess,                      //预览图是否加载成功
                                    "is_open_dashboard": dataMap["is_dashboard"]|| false,                //是否开启仪表盘 bool
                                    "dashboard_source_list": dataMap["dashboard_source_list"]|| [],  //仪表盘素材源
                                    "sticker_slug": dataMap["sticker_slug"] ||"",                    //仪表盘贴纸
                                    "dashboard_tab_list": dataMap["dashboard_tab_list"]|| [],         //仪表盘场景
                                    "stitching_list": dataMap["stitching_list"]|| [],                  // 拼接类型
                                    "tracking_cnt":dataMap["tracking_cnt"] || 0,                      //追踪段数
                                    "tracking_duration":dataMap["tracking_duration"] || 0,            //追踪时长
                                    "font_slug": dataMap["font_slug_list"] || false,                     // 字体slug list
                                    "is_open_tone_enhancement":dataMap["is_tonalenhance"]|| false,       //影调增强
                                    "is_beauty": dataMap["is_beauty"] || false,                          //美颜开关
                                    "beauty_open_cnt": dataMap["beauty_open_cnt"] || 0,                  //美颜开启片段数
                                    "beauty_clip_cnt": dataMap["beauty_clip_cnt"] || 0,                  //美颜调节片段数
                                    "beauty_duration": dataMap["beauty_duration"] || 0,                  //美颜总时长
                                    "reduce_color_jump_level":dataMap["reduce_color_jump_level"] ||[],//去频闪强度
                                    "scope_type": composeRangeToScopeType()|| "",                   //导出范围
                                    "super_slow_mode_count": enableSuperSlowClips,
                                    "super_slow_mode_speed_value_list": superSlowModeSpeedValue,
                                    "source": mediaSourceTypeList,  // 素材来源
                                    "use_method": "edit",           // 导出入口
                                    "free_storage_size": freeStorageSizeGB, //剩余磁盘空间（GB）
                                    "compose_file_size": composeFileSizeGB, //预估导出文件大小（GB，-1=算不出）
                                    "curve_speed_type": curveSpeedTypeList,
                                    "effect_count": dataMap["effect_count"] || 0,            //特效片段总数
                                    "effect_slug": dataMap["effect_slug"] || [],              //特效唯一id列表
                                    "effect_type_list": dataMap["effect_type_list"] || [],    //特效类型列表
                                    "total_effect_duration": dataMap["total_effect_duration"] || 0, //特效时长之和（秒）
                                    "track_id": dataMap["track_id"] || "", //轨道id列表（json字符串）
                                    "parameter": dataMap["color_wheel_param"] || "", //色轮参数JSON
                                    "color_slug": dataMap["color_slug_list"] || [],       // 素材色彩模式枚举 list（DLog2/DLog-M/HLG/D-CineLike/D-Log/Normal）
                                    "correction_value": dataMap["color_correction_value"] || "", // dlog2 预设+参数 JSON
                                    "ai_roughcut_job_ids": aiRoughCutManager.aiRoughCutJobIds(),
                                    })
        logger.i("[NOVA][EXPORT][TEMP] step14: reportExportStartEvent done");

        return videoInfo;
    }

    // 开始导出
    function startExportEvent(outputPath, videoInfo) {
        const colorDepth = colorDepthSwitch.checked ? 10 : 8;
        const denoise = denoise_control.checked ? true : false;
        let dataMap = editorManager.getComposeDataMap();
        let hasLostMedia = editorManager.trackHasLostMedia();
        logger.i("[NOVA][EXPORT] startExportEvent: trackHasLostMedia=" + hasLostMedia
                 + " outputPath=" + outputPath);
        // 需要手动链接媒体
        if (hasLostMedia) {
            showMediaLostExportDialog(composePopup.currentSavePath, selectResolutionType, selectFrameRateType, selectBitrateType, outputPath, colorDepth, denoise, videoInfo);
        } else {
            confirmExport(videoInfo, composePopup.currentSavePath, selectResolutionType, selectFrameRateType, selectBitrateType, outputPath, colorDepth, dataMap["is_device_material"]);
        }
    }

    property ConfirmPopup askForFindMediaDialog: null
    function showMediaLostExportDialog(folder, resolutionType, framerateType, bitrateType, outputPath, colorDepth, denoise, videoInfo) {
        if (CommonUtils.isNull(askForFindMediaDialog)) {
            askForFindMediaDialog = Qt.createComponent("qrc:/Controls/ConfirmPopup.qml").createObject(lightWindow, {
                                                                                                          "title": qsTr("pccut_files_missing_export"),
                                                                                                          "text": qsTr("pccut_files_missing_export_description"),
                                                                                                          "leftButtonText": qsTr("pccut_export_exit_abort_cancel"),
                                                                                                          "rightButtonText": qsTr("pccut_files_missing_search_document")
                                                                                                      });
            askForFindMediaDialog.onClosed.connect(function() {
                askForFindMediaDialog.destroy();
                askForFindMediaDialog = null;
            });
            askForFindMediaDialog.onLeftButtonClicked.connect(function() {
                confirmExport(videoInfo, folder, resolutionType, framerateType, bitrateType, outputPath, colorDepth, videoInfo.materialDataMap["is_device_material"] ?? false);
            });
            askForFindMediaDialog.onRightButtonClicked.connect(function() {
                globalSignal.manualLinkMedia();
                ExportEventReport.reportComposeFailed(ExportEventReport.ERROR_CODE_4601, videoInfo);
            })
            composePopup.close();
            askForFindMediaDialog.open();
        }
    }

    function confirmExport(videoInfo, folder, resolutionType, framerateType, bitrateType, outputPath, colorDepth, hasDeviceMaterial) {
        // 先快照当前 UI 状态到内存缓存，再统一落盘
        saveCurrentModeParams()
        if (_videoParams) persistParams(_videoParams, false)
        if (_panoParams) persistParams(_panoParams, true)
        fileOperator.setQMLExportVideoType(panoCheckBox.checked);
        fileOperator.setQMLExportPanoFormat(cachedPanoFormat)
        fileOperator.setQMLExportOrientationLock(orientationLockSwitch.checked);

        let size = videoConfig.estimateComposeFileSizeWithOriginalSize(getBitrate(), exportEstimateVM.totalDurationSec);

        // 磁盘空间检查（仅空间不足时弹窗，spaceLow 不弹窗）
        const availableMB = fileOperator.tempBytesAvailableWithTimeout(folder, 100, 1 /* MB */)
        const warnSize = fileOperator.getStorageWarnSize(folder, size)
        const spaceInsufficient = availableMB >= 0 && availableMB < warnSize
        logger.i("[NOVA][EXPORT] confirmExport: size=" + size + "MB availableMB=" + availableMB
                 + " warnSize=" + warnSize + " spaceInsufficient=" + spaceInsufficient
                 + " outputPath=" + outputPath);
        if (spaceInsufficient) {
            // storageWarnDialog在此处定义，否则运行提示未定义
            var storageWarnDialog = Qt.createComponent("qrc:/Controls/ConfirmPopup.qml").createObject(lightWindow, {
                                                                                                          "title": qsTr("pccut_export_still_export_low_storage"),
                                                                                                          "leftButtonText": qsTr("pccut_export_still_export_cancel"),
                                                                                                          "rightButtonText": qsTr("pccut_export_still_export")
                                                                                                      });
            storageWarnDialog.onClosed.connect(function() {
                storageWarnDialog.destroy();
                storageWarnDialog = null;
            });
            storageWarnDialog.onLeftButtonClicked.connect(function() {
                storageWarnDialog.close();
                onClosed()
                composeLoader.active = false
            });
            storageWarnDialog.objectName = actionableItemName.storageWarnDialog;
            var panoChecked = panoCheckBox.checked;
            var dolbyVisionChecked = dolbyVisionSwitch.checked;
            storageWarnDialog.onRightButtonClicked.connect(function() {

                waterMarkSetting.applyToExportDraft();
                composeDraftManager.saveQMLComposeDraftFile(selectResolutionType,
                                                            selectFrameRateType,
                                                            getBitrate(),
                                                            outputPath,
                                                            videoInfo.exportId,
                                                            videoInfo,
                                                            size,
                                                            colorDepthSwitch.checked ? 10 : 8,
                                                            panoChecked,
                                                            hasDeviceMaterial,
                                                            denoise_control.checked ? selectDenoiseType : -1,
                                                            -1,
                                                            dolbyVisionChecked,
                                                            (selectComposeType === 1),
                                                            entranceType,
                                                            selectComposeRange,
                                                            isDaVinciFormat && orientationLockSwitch.checked);

                storageWarnDialog.close();
                globalSignal.clickExportButton()
                onClosed()
                composeLoader.active = false
            });

            storageWarnDialog.onLeftButtonClicked.connect(function() {
                ExportEventReport.reportComposeFailed(ExportEventReport.ERROR_CODE_4002, videoInfo);
            });

            composePopup.close();
            storageWarnDialog.open();
        }
        else{
            var panoChecked = panoCheckBox.checked;
            logger.i("[NOVA][EXPORT] saveQMLComposeDraftFile: range=" + selectComposeRange
                     + " type=" + selectComposeType + " entrance=" + entranceType
                     + " out=" + outputPath + " exportId=" + videoInfo.exportId);
            waterMarkSetting.applyToExportDraft();
            composeDraftManager.saveQMLComposeDraftFile(selectResolutionType,
                                                        selectFrameRateType,
                                                        getBitrate(),
                                                        outputPath,
                                                        videoInfo.exportId,
                                                        videoInfo,
                                                        size,
                                                        colorDepthSwitch.checked ? 10 : 8,
                                                        panoChecked,
                                                        hasDeviceMaterial,
                                                        denoise_control.checked ? selectDenoiseType : -1,
                                                        -1,
                                                        dolbyVisionSwitch.checked,
                                                        (selectComposeType === 1),
                                                        entranceType,
                                                        selectComposeRange,
                                                        isDaVinciFormat && orientationLockSwitch.checked);

            composePopup.close();
            globalSignal.clickExportButton()
            onClosed()
            composeLoader.active = false
        }
    }

    // 默认的文件名
    function defaultFileName() {
        let filePath = editorManager.pathAtVideoTractorTrackClip(0, 0);
        var fileName = filePath.split('/').pop(); // 获取文件名
        var fileNameWithoutExtension = fileName.split('.').slice(0, -1).join('.'); // 去掉文件后缀
        return fileNameWithoutExtension;
    }
    // 当前的时间戳
    function getCurrentMillisecondsTimestamp() {
        var timestamp = new Date().getTime();
        return timestamp;
    }

    property string lastDefaultExportName: "";
    // 刷新下默认的文件名字
    function refreshFileName(composeType) {
        // 只有用户没有修改的时候，才自动刷新，否则保持用户手动输入的名字
        if (CommonUtils.isEmptyStr(lastDefaultExportName) || composePopup.currentFileName == lastDefaultExportName) {
            if (composeType === 0){
                lastDefaultExportName = fileOperator.getExportName(composePopup.currentSavePath);
            } else {
                lastDefaultExportName = fileOperator.getExportNameMultiFragment(composePopup.currentSavePath);
            }
            composeExportViewModel.fileNameList = [lastDefaultExportName];
        }
    }
    // 本次导出实际对应的时长（秒），按入口/范围选择，是文件大小预估与磁盘检查的唯一口径来源。
    // 右键入口：选中素材时长；导入入口且范围导出：范围时长；否则：整条时间线时长。
    // rangeCompose 为兼容 refreshFileMB 旧签名，缺省（undefined）按范围感知处理。
    function composeLengthInSecond(rangeCompose) {
        if (entranceType !== 0) {
            return exportEstimateVM.selectedDurationSec;
        }
        if (rangeCompose !== false && selectComposeRange === VideoConfig.COMPOSERANGE_RANGE) {
            syncExportRangeToVM();
            return exportEstimateVM.rangeDurationSec;
        }
        return exportEstimateVM.totalDurationSec;
    }
    //计算文件大小
    function refreshFileMB(rangeCompose) {
        syncExportRangeToVM()
        if(entranceType === 0){
            //导入按钮入口，计算所有视频大小
            if(rangeCompose === true && selectComposeRange === VideoConfig.COMPOSERANGE_RANGE) {
                let size = videoConfig.estimateComposeFileSizeWithOriginalSize(getBitrate(), exportEstimateVM.rangeDurationSec);
                estimateText.text = size + " M";
            } else {
                let size = videoConfig.estimateComposeFileSizeWithOriginalSize(getBitrate(), exportEstimateVM.totalDurationSec);
                estimateText.text = size + " M";
            }
        }else{
            //右键菜单入口，计算选中视频大小
            let size = videoConfig.estimateComposeFileSizeWithOriginalSize(getBitrate(), exportEstimateVM.selectedDurationSec);
            estimateText.text = size + " M";
        }
        let size = videoConfig.estimateComposeFileSizeWithOriginalSize(getBitrate(), composeLengthInSecond(rangeCompose));
        estimateText.text = size + " M";
    }
    // 把范围导出 In/Out/启用态同步给预估 VM，VM 据此重算 rangeDurationSec
    // In/Out 取 C++ EditorManager（MacComposePanel 作用域内没有 trackDockViewModel，直接引用会抛 ReferenceError）
    function syncExportRangeToVM() {
        let enabled = (selectComposeRange === VideoConfig.COMPOSERANGE_RANGE) && editorManager.hasRangeCompose()
        let inFrame = 0
        let outFrame = 0
        if (enabled) {
            outFrame = editorManager.rangeComposeFrameLength()
            // rangeComposeFrameLength 只给长度；入点经 nova 帧换算（MK_TIME_BASE=30000/帧，与 TrackDockViewModel::timebasePerFrame 同口径）
            inFrame = Math.round(editorManager.rangeComposeInUs() * exportEstimateVM.fps / 1000000)
            outFrame = inFrame + outFrame
        }
        logger.i("[NOVA][EXPORT] syncExportRangeToVM: enabled=" + enabled
                 + " in=" + inFrame + " out=" + outFrame
                 + " rangeDurationSec=" + exportEstimateVM.rangeDurationSec
                 + " fps=" + exportEstimateVM.fps);
        exportEstimateVM.setRangeFrame(inFrame, outFrame, enabled)
    }
    // 获取码率
    function getBitrate(resolutionType = selectResolutionType, frameRateType = selectFrameRateType, bitrateType = selectBitrateType) {
        let width = exportEstimateVM.canvasWidth;//videoConfig.getQmlItemByResolutionType(selectResolutionType).width;
        let height = exportEstimateVM.canvasHeight;//videoConfig.getQmlItemByResolutionType(selectResolutionType).height;
        let bitrate = 0;
        if(bitrateType === VideoConfig.BITRATETYPE_CUSTOM) {
            bitrate = baseSlider.value * 1024 * 1024; //设置自定义码率
        }
        else {
            bitrate = videoConfig.getBitrateWithOriginalSize(width, height, resolutionType, frameRateType, bitrateType);
        }
        let scale = 1;
        if (editorManager.isHdrProject()) {
            switch (bitrateType) {
            case VideoConfig.BITRATETYPE_LOW:
                scale = 1.12
                break;
            case VideoConfig.BITRATETYPE_RECOMMEND:
                scale = 1.22
                break;
            case VideoConfig.BITRATETYPE_HIGH:
                scale = 1.37
                break;
            case VideoConfig.BITRATETYPE_CUSTOM:
                scale = 1
                break;
            }
        }
        bitrate*= scale;

        return bitrate;
    }

    // 打开弹窗时修改开关状态
    function changeSwitchState() {
        isSupportDolbyVision = editorManager.hasDolbyVisionClip()
        if(editorManager.has10bitClip() && composeSetting.colorDepth === 10){
            UsedFunctionManager.removeFunction(projectId,UsedFunctionManager.EditorFunctionType.EXPORT_10BIT);
            UsedFunctionManager.addFunction(projectId,UsedFunctionManager.EditorFunctionType.EXPORT_10BIT);
            composeSetting.setColorDepth(10)
            colorDepthSwitch.enabled = true
            colorDepthSwitch.checked = true
            dolbyVisionSwitch.enabled = isSupportDolbyVision
        }else if(editorManager.has10bitClip() && composeSetting.colorDepth === 8){
            UsedFunctionManager.removeFunction(projectId,UsedFunctionManager.EditorFunctionType.EXPORT_10BIT);
            colorDepthSwitch.enabled = true
            colorDepthSwitch.checked = true
            dolbyVisionSwitch.enabled = false
        }else{
            UsedFunctionManager.removeFunction(projectId,UsedFunctionManager.EditorFunctionType.EXPORT_10BIT);
            colorDepthSwitch.enabled = false
            colorDepthSwitch.checked = false
            dolbyVisionSwitch.enabled = false
        }

        // 全图片草稿时，降噪不可用
        if (editorManager.allImageClip()) {
            denoise_control.enabled = false;
            denoise_control.opacity = 1;
            denoise_control.checked = false;
        } else if (denoiseVM.isEnable) {
            denoise_control.enabled = true;
            denoise_control.opacity = 1;
            denoise_control.checked = true;
        } else {
            denoise_control.enabled = true;
            denoise_control.opacity = 1;
            denoise_control.checked = false;
        }

        let isPano = panoCheckBox.checked
        if (!editorManager.allImageClip() && denoiseVM.hasDenoiseChecked(isPano)) {
            denoise_control.checked = denoiseVM.getDenoiseChecked(isPano)
            denoiseVM.isEnable = denoise_control.checked
        }

        // 10bit 开关按模式记忆覆盖上面的全局状态（仅在用户曾经导出过、key 已存在时才覆盖）
        let colorDepthKey = isPano ? "key_export_pano_color_depth_checked" : "key_export_color_depth_checked"
        if (editorManager.has10bitClip() && lightSetting.contains(colorDepthKey)) {
            colorDepthSwitch.checked = fileOperator.getQMLExportColorDepthChecked(isPano)
            composeSetting.setColorDepth(colorDepthSwitch.checked ? 10 : 8)
        }
    }

    function composeRangeToScopeType() {
        switch(selectComposeRange) {
        case VideoConfig.COMPOSERANGE_RANGE:
            return "scope";
        }
        return "all";
    }
}
