import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls
import QtQuick.Controls.Material 2.15
import QtQuick.Dialogs
import Qt5Compat.GraphicalEffects
import Config 1.0
import Controls 1.0
import Nova 1.0
import VideoFragmentViewModel 1.0
import LutListModel 1.0
import app_qrc 1.0
import UsedFunctionManager 1.0
import ProjectSettingsInfo 1.0

/**
 *  @File        : LutSetting.qml
 *  @Brief       : LUT设置（三级菜单：系列→产品→D-Log，含自定义LUT导入）
 *  @Author      : jack.sheng
 *  @Date        : 2026-06-01
 */
Item {
    id: lutSetting
    property VideoFragmentViewModel viewModel
    // 素材是否携带 DLog2 元数据（由父面板从 PropertyPanelViewModel 下发），供风格 Natural/Clear 门控
    property bool hasDLog2Metadata: false
    property double defultOpacity : checkBox.checked ? 1 : 0.2
    property int bothSidePadding: 100
    property real selectListPopupRatio: 56 / 127
    property bool customLutAtLimit: false
    property bool _isImporting: false
    // 以 slug 为 key 的下载进度表（0.0–1.0）；Connections 写入，delegate 读取
    property var lutDownloadProgress: ({})
    // 等待下载完成后应用的 LUT slug
    property string pendingApplyLutSlug: ""
    // 下载完成后是否关闭列表
    property string pendingCloseAfterApplyLut: ""
    // 名称=D-LOG 2 时，用算法方案（风格下拉 + 更多设置），此时浓度滑杆不显示
    // 权威判断：用选中 LUT 的 slug 反查（devList.isDlog2Slug），不依赖显示名 curLutName
    // （显示名带 "(推荐)" 后缀、受自定义 LUT 命名/初始化时序影响，前缀匹配易误判/漏判）
    readonly property bool _isDlog2: devList.isDlog2Slug(control.fixLutSlug)
    // DLog2 本期仅在 mac 上线，windows 侧完全不显示 DLog2 UI（下游代码路径也不会被触发）
    readonly property bool _dlog2Enabled: Qt.platform.os === "osx1" && _isDlog2
    width: parent.width
    height: childrenRect.height

    // [NOVA] 色彩还原(LUT) 状态/动作改走 nova 内核
    LutRevertAdjust { id: lutVM }

    DLog2Adjust { id: dlog2VM }

    // 供父面板「应用到全部」调用
    function applyLutToAll() {
        lutVM.applyToAll(devList);
        if (Qt.platform.os == "osx1") {
            dlog2VM.applyToAll();
        }
        // 应用到全局埋点：color_slug / correction_value 现按源片段最佳可得口径上报，
        // 全片段聚合口径后续由数据侧补齐。
        eventTracker.trackEvent("pccut_panel_colorrecovery_all", {
            "color_slug": [_lutColorSlugString()],
            "correction_value": (function() {
                const name = _presetName();
                var m = {};
                m[name] = JSON.parse(_presetParameters());
                return JSON.stringify(m);
            })()
        });
    }
    // C++ 数据源（三级结构）
    LutListModel { id: devList }

    // 左列展示模型（系列 + 分割线）
    ListModel { id: displaySeriesModel }

    // 右列展示模型（产品标题 + D-Log 选项）
    ListModel { id: groupedLutModel }

    // 自定义LUT列表模型
    ListModel { id: customLutModel }

    // 构建左列：custom-lut 入口 + series items + 类别横线分割线
    function buildSeriesDisplayModel() {
        displaySeriesModel.clear();
        // 自定义LUT 始终作为第一项，无论是否已导入
        displaySeriesModel.append({ type: "custom-lut", seriesName: qsTr("pccut_panel_colorrecovery_custom_lut"), seriesIdx: -2 });
        // 仅保留自定义LUT 与下方系列之间的分割线，其余系列之间不再添加分割线
        displaySeriesModel.append({ type: "divider", seriesName: "", seriesIdx: -1 });
        const count = devList.getSeriesCount();
        for (let i = 0; i < count; i++) {
            displaySeriesModel.append({ type: "series", seriesName: devList.getSeriesName(i), seriesIdx: i });
        }
    }

    // 构建右列：产品分组标题 + D-Log 选项
    function buildGroupedModel(seriesRealIdx) {
        groupedLutModel.clear();
        if (seriesRealIdx < 0) return;
        if (seriesRealIdx === 0) {
            // 「无」系列：slug 用 tr 字符串与旧版（pc_editor_3）对齐
            const noneText = devList.getSeriesName(0);
            let displayText = noneText;
            if (control.isNoneRecommended) {
                displayText += " (" + qsTr("pccut_export_bitrate_recommend") + ")";
            }
            groupedLutModel.append({ isHeader: false, displayText: displayText, slug: noneText, productIdx: 0, isLocal: true, url: "" });
            return;
        }
        const products = devList.getProductList(seriesRealIdx);
        const showHeader = products.length > 0;
        for (let pi = 0; pi < products.length; pi++) {
            if (showHeader) {
                groupedLutModel.append({ isHeader: true, displayText: products[pi].productName, slug: "", productIdx: pi, isLocal: true, url: "" });
            }
            const luts = devList.getLutList(seriesRealIdx, pi);
            const recName = devList.getRecommendName(seriesRealIdx, pi);
            for (let li = 0; li < luts.length; li++) {
                let text = luts[li].lutName;
                if (recName !== "" && luts[li].lutName === recName) {
                    text += " (" + qsTr("pccut_export_bitrate_recommend") + ")";
                }
                groupedLutModel.append({ isHeader: false, displayText: text, slug: luts[li].slug, productIdx: pi,
                                          isLocal: !!luts[li].isLocal, url: luts[li].url || "" });
            }
        }
    }

    // 构建自定义LUT右侧列表
    function buildCustomLutModel() {
        customLutModel.clear();
        customLutModel.append({ isImport: true,  isDivider: false, name: "", slug: "__import__",  isHeader: false });
        const luts = devList.getCustomLutList();
        if (luts.length > 0) {
            customLutModel.append({ isImport: false, isDivider: true,  name: "", slug: "__divider__", isHeader: false });
            for (let i = 0; i < luts.length; i++) {
                customLutModel.append({ isImport: false, isDivider: false, name: luts[i].name, slug: luts[i].slug, isHeader: false });
            }
        }
        customLutAtLimit = (luts.length >= 100);
    }

    // 同一系列内多个产品可能共用同一 LUT slug（如 Osmo 360 / Osmo 360 II / Osmo 360 AIR
    // 都用 LOG_Osmo360_DLogM），findProductIndex 只能返回列表中第一个命中的产品。
    // 若素材设备推荐的产品就在该系列内、且同样包含此 slug，则以设备推荐的产品为准，
    // 避免勾选标记跑到同系列的其它机型上。
    function resolveProductIndex(si, lutSlug, rec) {
        const pi = devList.findProductIndex(si, lutSlug);
        if (CommonUtils.isNull(rec) || rec.seriesIndex !== si || rec.productIndex === pi) return pi;
        const luts = devList.getLutList(si, rec.productIndex);
        for (let i = 0; i < luts.length; i++) {
            if (luts[i].slug === lutSlug) return rec.productIndex;
        }
        return pi;
    }

    // 从当前片段 slug 恢复状态
    function restoreFromSlug(lutSlug) {
        if (!lutVM.hasClip) return;
        // 无论是否有 slug，都先调用 recommendDevice 设置各产品的推荐标记（用于显示"推荐"字样）
        const rec = devList.recommendDevice(lutVM.mediaPath());
        control.isNoneRecommended = (rec.seriesIndex === 0);

        // 显式选「无」时内核无 LUT 节点（slug 为空且勾选开启），用「无」slug 走下方 si === 0 分支
        if (lutSlug === "" && lutVM.isEnable)
        {
            lutSlug = devList.getSeriesName(0);
        }

        const si = devList.findSeriesIndex(lutSlug);
        if (si === -2) {
            // 自定义LUT
            control.fixSeriesIndex = -2;
            control.fixProductIndex = -1;
            control.fixLutSlug = lutSlug;
            control.isSceneRecommended = false;
            buildCustomLutModel();
            // 从 slug 提取显示名（目录名即显示名）
            const filename = devList.customSlugToDir(lutSlug);
            control.curLutName = filename;
            return;
        }
        if (si === 0) {
            // 「无」系列：lutSlug 可能是 "" 或 tr("无")
            // 统一以 tr("无") 显示 + 写回 fixLutSlug，使勾选图标命中
            const noneText = devList.getSeriesName(0);
            control.fixSeriesIndex = 0;
            control.fixProductIndex = 0;
            control.fixLutSlug = noneText;
            control.isSceneRecommended = false;
            buildGroupedModel(0);
            control.curLutName = groupedLutModel.count > 0 ? groupedLutModel.get(0).displayText : noneText;
            return;
        }
        if (si !== -1) {
            // si >= 1 是内置系列
            const pi = resolveProductIndex(si, lutSlug, rec);
            control.fixSeriesIndex = si;
            control.fixProductIndex = pi;
            control.fixLutSlug = lutSlug;
            control.isSceneRecommended = false;
            buildGroupedModel(si);
            for (let i = 0; i < groupedLutModel.count; i++) {
                const item = groupedLutModel.get(i);
                if (!item.isHeader && item.slug === lutSlug && item.productIdx === pi) {
                    control.curLutName = item.displayText;
                    break;
                }
            }
            return;
        }
        // slug 非空但未在任何系列中找到 → 退回推荐结果（系统推荐）
        const recSi = rec.seriesIndex;
        const recPi = rec.productIndex;
        control.fixSeriesIndex = recSi;
        control.fixProductIndex = recPi;
        control.isSceneRecommended = true;
        buildGroupedModel(recSi);
        const recSlug = devList.recommendLutSlug(lutVM.mediaPath());
        let fallbackSlug = "";
        let fallbackName = "";
        let foundRec = false;
        for (let j = 0; j < groupedLutModel.count && !foundRec; j++) {
            const it = groupedLutModel.get(j);
            if (it.isHeader || it.productIdx !== recPi) continue;
            if (fallbackSlug === "") {
                fallbackSlug = it.slug;
                fallbackName = it.displayText;
            }
            if (recSlug !== "" && it.slug === recSlug) {
                control.fixLutSlug = recSlug;
                control.curLutName = it.displayText;
                foundRec = true;
            }
        }
        if (!foundRec) {
            control.fixLutSlug = fallbackSlug;
            control.curLutName = fallbackName;
        }
    }

    Component.onCompleted: {
        buildSeriesDisplayModel();
        buildCustomLutModel();
        if (!lutVM.hasClip) return;
        restoreFromSlug(lutVM.slug);
    }

    // ─── 埋点辅助函数 ──────────────────────────────────────────────────────────────
    function _lutColorSlugString() {
        if (control.fixSeriesIndex === -2) return "custom";
        if (control.fixSeriesIndex === 0) return "none";
        var lutName = devList.lutNameForSlug(control.fixLutSlug);
        return lutName || "";
    }
    function _lutDeviceCategory() {
        if (control.fixSeriesIndex === -2) return "custom";
        if (control.fixSeriesIndex === 0) return "none";
        return devList.getSeriesCategory(control.fixSeriesIndex) || "unknown";
    }
    function _lutDeviceModel() {
        if (!lutVM.hasClip) return "unknown";
        const m = devList.getDeviceModel(lutVM.mediaPath());
        return m !== "" ? m : "unknown";
    }
    // DLog2 风格枚举英文名：base / natural / clear；非 DLog2 或未开启返回空串
    function _presetName() {
        if (!_isDlog2) return "";
        return dlog2VM.currentStyle;
    }
    function _presetParameters() {
        if (Qt.platform.os !== "osx1" || !_isDlog2 || dlog2VM.currentStyle === "basic") return "{}";
        return JSON.stringify({
            brightness_gain:      Math.round(dlog2VM.readParamValue("brightness") * 100),
            highlight_protection: Math.round(dlog2VM.readParamValue("highlight") * 100),
            clarity:              Math.round(dlog2VM.readParamValue("clarity") * 100)
        });
    }

    // 应用指定 slug 的 LUT 并同步选中态、存草稿、埋点
    function applyLutAndClose(slug, needClose) {
        control.fixLutSlug = slug;
        control.isSceneRecommended = false;
        if (Qt.platform.os == "osx1" && devList.isDlog2Slug(slug) && hasDLog2Metadata) {
            dlog2VM.setStyle(dlog2VM.currentStyle == "basic" ? "natural" : dlog2VM.currentStyle);
        } else {
            lutVM.selectLut(slug);
        }
        if (needClose) lutListPopup.close();
        editorDraftManager.saveDraft();
        eventTracker.trackEvent("pccut_panel_colorrecovery", {
            "is_turnon": true,
            "color_slug_string": slug,
            "preset_name": _presetName(),
            "preset_parameters": _presetParameters(),
            "use_method": "switch",
            "device_model": _lutDeviceModel(),
            "device_category": _lutDeviceCategory(),
            "is_scene_recommend": false
        })
    }

    // 清除进度表中某 slug 的残留进度
    function clearLutProgress(slug) {
        var m = lutSetting.lutDownloadProgress;
        if (m[slug] === undefined) return;
        delete m[slug];
        lutSetting.lutDownloadProgress = m;
    }

    // 切到 [无] 显示态（仅 UI；filter / isEnableLut 由删除流程的 cancelCustomLutsForSlugs 清理）
    function showAsNone() {
        const noneText = devList.getSeriesName(0);
        control.fixSeriesIndex = 0;
        control.fixProductIndex = 0;
        control.fixLutSlug = noneText;
        buildGroupedModel(0);
        control.curLutName = groupedLutModel.count > 0 ? groupedLutModel.get(0).displayText : noneText;
    }

    // 自定义LUT列表变化（文件新增/删除）
    Connections {
        target: devList
        function onCustomLutListChanged() {
            buildCustomLutModel();
            // 仅当 fixLutSlug 本身是自定义 slug 时才检测是否已被删除；
            // 若 fixSeriesIndex === -2 但 slug 是内置（用户仅悬停到自定义区），
            // 不能用自定义列表来判断 slug 是否存在，否则会误清名称。
            if (control.fixSeriesIndex === -2 && devList.isCustomSlug(control.fixLutSlug)) {
                let stillExists = false;
                for (let i = 0; i < customLutModel.count; i++) {
                    if (customLutModel.get(i).slug === control.fixLutSlug) {
                        stillExists = true;
                        break;
                    }
                }
                if (!stillExists) {
                    // 当前选中的自定义LUT已被删除（外部或文件监听触发）：UI 切到 [无]
                    showAsNone();
                }
            }
        }

        // LUT 文件下载完成，刷新列表；若是待应用的下载则自动应用（并按需关闭）
        function onLutFileReady(slug) {
            buildGroupedModel(control.fixSeriesIndex);
            clearLutProgress(slug);
            if (slug !== lutSetting.pendingApplyLutSlug) return;
            lutSetting.pendingApplyLutSlug = "";
            var needClose = (lutSetting.pendingCloseAfterApplyLut === slug);
            lutSetting.pendingCloseAfterApplyLut = "";
            applyLutAndClose(slug, needClose);
        }

        // LUT 下载失败：刷新列表停止动画 + toast，清空待应用标记，列表保持打开
        function onLutDownloadFailed(slug) {
            buildGroupedModel(control.fixSeriesIndex);
            clearLutProgress(slug);
            if (slug === lutSetting.pendingApplyLutSlug) {
                lutSetting.pendingApplyLutSlug = "";
                lutSetting.pendingCloseAfterApplyLut = "";
            }
            globalSignal.toast(qsTr("pccut_cloud_resource_load_fail_toast"));
        }

        // LUT 下载进度更新（0.0–1.0），写入进度表驱动进度环
        function onLutDownloadProgressChanged(slug, progress) {
            var m = lutSetting.lutDownloadProgress;
            if (m[slug] === progress) return;
            m[slug] = progress;
            lutSetting.lutDownloadProgress = m;   // 重新赋值触发绑定刷新
        }
    }

    Rectangle{
        id:lutRect
        property bool isDisable: !checkBox.checked
        width: parent.width
        height: checkBox.implicitHeight
        color: Colors.color_transparent
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        LightCheckBox {
            id:checkBox
            maxTextWidth: lutSetting.width - 180
            text: qsTr("pccut_panel_colorrecovery")
            anchors.verticalCenter: parent.verticalCenter
            checked: lutVM.isEnable || dlog2VM.isEnable
            verticalPadding: 1.5
            Component.onCompleted:
            {
                var projectId = draftManager.activeProjectEnvId();
                var isFuncExist = UsedFunctionManager.hasFunction(projectId,UsedFunctionManager.EditorFunctionType.COLOR_REPRODUCTION);
                if (!isFuncExist && checked)
                {
                   UsedFunctionManager.addFunction(projectId,UsedFunctionManager.EditorFunctionType.COLOR_REPRODUCTION);
                }
            }

            onClicked:{
                if (!lutVM.hasClip) return;
                var projectId = draftManager.activeProjectEnvId();
                if(!checkBox.checked){
                    // 取消勾选前记录上次有效选择，供重新勾选恢复。
                    var noneText0 = devList.getSeriesName(0);
                    if (control.fixLutSlug !== "" && control.fixLutSlug !== noneText0) {
                        control.lastSelectedLutSlug = control.fixLutSlug;
                    }
                    if (Qt.platform.os == "osx1") {
                        if (lutVM.removeLut(false)) {
                            dlog2VM.removeDLog2();
                        }
                    } else {
                        lutVM.removeLut();
                    }
                }else{
                    // 优先用草稿里真实存在的 slug；取消勾选会清空 slug 并把 fixLutSlug 重置成「无」，
                    // 故 slug 为空时用 lastSelectedLutSlug 回填上次选择，避免落到「无」/推荐。
                    var lutSlug = lutVM.slug !== "" ? lutVM.slug : control.lastSelectedLutSlug;
                    var noneText = devList.getSeriesName(0);
                    if (lutSlug === "") {
                        lutSlug = devList.recommendLutSlug(lutVM.mediaPath());
                        control.isSceneRecommended = true;
                    }
                    // 无上次选择也无推荐：回落到「无」，避免下拉框空显示
                    if (lutSlug === "") {
                        lutSlug = noneText;
                    }
                    restoreFromSlug(lutSlug);
                    if (lutSlug !== noneText && control.fixSeriesIndex !== 0) {
                        if (Qt.platform.os == "osx1" && devList.isDlog2Slug(lutSlug) && hasDLog2Metadata) {
                            dlog2VM.setStyle("natural");
                        } else {
                            lutVM.selectLut(lutSlug);
                        }
                        UsedFunctionManager.addFunction(projectId,UsedFunctionManager.EditorFunctionType.COLOR_REPRODUCTION);
                    } else {
                        // 回落到「无」：仍需置为「无」选中态，否则勾选框与 lutVM.isEnable 脱节
                        lutVM.selectNone();
                    }
                }

                editorDraftManager.saveDraft();
                eventTracker.trackEvent("pccut_panel_colorrecovery", {
                    "is_turnon": checked,
                    "color_slug_string": _lutColorSlugString(),
                    "preset_name": _presetName(),
                    "preset_parameters": _presetParameters(),
                    "use_method": checked ? "choose" : "cancel",
                    "device_model": _lutDeviceModel(),
                    "device_category": _lutDeviceCategory(),
                    "is_scene_recommend": control.isSceneRecommended
                })
            }
        }
        Rectangle{
            id: descriptionBtn
            anchors.left: parent.left
            anchors.leftMargin: checkBox.width - 6
            width: 14
            height: 14
            anchors.verticalCenter: parent.verticalCenter
            color: Colors.color_transparent
            Image {
                id:descriptIcon
                anchors.fill: parent
                source: "qrc:/icons/ic_explain_hover.svg"
                sourceSize: Qt.size(parent.width, parent.height)
            }
            Loader {
                    id: popupLoader
                    sourceComponent:popupComponent
                    active: false
                }
            MouseArea {
                anchors.fill: parent
                hoverEnabled:true
                onEntered: {
                    popupLoader.active = true;
                    var popup = popupLoader.item
                    if(popup.visible !== true){
                        popup.visible = true;
                    }
                    descriptIcon.source = "qrc:/icons/ic_explain.svg"
                }
                onExited: {
                    var popup = popupLoader.item
                    popup.close()
                    descriptIcon.source = "qrc:/icons/ic_explain_hover.svg"
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
                source: lutRect.isDisable ? "qrc:/icons/ic_reset.svg" :  resetBtn.isHovered ? "qrc:/icons/ic_reset_hover.svg" : "qrc:/icons/ic_reset.svg"
                sourceSize: Qt.size(parent.width, parent.height)
                opacity: lutRect.isDisable ? 0.2 : 1
            }
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                enabled: !lutRect.isDisable && lutVM.hasClip
                onEntered: resetBtn.isHovered = true
                onExited: resetBtn.isHovered = false
                onClicked: {
                    if (!lutVM.hasClip) return;
                    // 重置：恢复推荐 LUT（无推荐则清回「无」），浓度复位 100
                    var recSlug = devList.recommendLutSlug(lutVM.mediaPath());
                    restoreFromSlug(recSlug);
                    if (Qt.platform.os == "osx1" && devList.isDlog2Slug(recSlug) && hasDLog2Metadata) {
                        dlog2VM.reset();
                    } else {
                        if (recSlug !== "") {
                            lutVM.selectLut(recSlug, 100);
                        } else {
                            lutVM.selectNone();
                        }
                        lutVM.reset();
                    }
                    eventTracker.trackEvent("pccut_panel_colorrecovery_reset");
                }
            }
        }
    }

    Item{
        id: selectItem
        width: parent.width
        height: 24
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: lutRect.bottom
        anchors.topMargin: 12
        Text{
            id:selectText
            anchors {
                top: parent.top
                topMargin: parent.height / 2 - height / 2
                left: selectItem.left
                verticalCenter: parent.verticalCenter
            }
            height: 15
            color: Colors.color_999999
            opacity: lutSetting.defultOpacity
            font.pixelSize: 11
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: qsTr("pccut_panel_colorrecovery_name")
        }

        // 状态属性持有者（无视觉）
        Item {
            id: control
            property int fixSeriesIndex: 0
            property int fixProductIndex: -1
            property string fixLutSlug: ""
            property string curLutName: " "
            property bool hasValidLut: fixSeriesIndex !== 0 && fixLutSlug !== ""
            property bool isSceneRecommended: false
            property bool isNoneRecommended: false
            // 取消勾选前用户最后选择的 LUT slug，用于重新勾选时恢复（避免 slug 被清空后丢失上次选择）。
            // 仅记录有效选择（fixSeriesIndex !== 0 且非「无」），重新勾选时若 slug 已空则用它回填。
            property string lastSelectedLutSlug: ""

            enabled: checkBox.checked
            anchors {
                left: parent.left
                leftMargin: 70
                verticalCenter: parent.verticalCenter
            }
            width: parent.width - 102
            height: 24
        }

        // 触发按钮（视觉替代 ComboBox contentItem + indicator）
        Rectangle {
            id: lutSelectTrigger
            property bool isHovered: false
            anchors {
                left: parent.left
                leftMargin: 70
                verticalCenter: parent.verticalCenter
            }
            width: parent.width - 102
            height: 24
            radius: 4
            color: isHovered && checkBox.checked ? Colors.color_37383A : Colors.color_2F3032
            opacity: checkBox.checked ? 1 : 0.2

            Text {
                anchors {
                    left: parent.left
                    leftMargin: 8
                    right: lutListOpenBtn.left
                    rightMargin: 4
                    verticalCenter: parent.verticalCenter
                }
                text: control.curLutName
                font.pixelSize: 12
                color: Colors.color_EEEEEE
                opacity: lutSetting.defultOpacity
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }


            Keys.onPressed: (event)=> {
                event.accepted = true; // 阻止按键事件的默认行为
            }

            Keys.onReleased: (event)=> {
                event.accepted = true; // 阻止按键事件的默认行为
            }
            // 捕获lut变化信号(主要是撤销恢复时触发的信号)
            Connections {
                target: lutVM
                function onSlugChanged(){
                    restoreFromSlug(lutVM.slug);
                }
                // 片段换源（替换素材）后按新素材重算推荐 LUT 与"(推荐)"文案
                function onMediaPathChanged(){
                    restoreFromSlug(lutVM.slug);
                }
            }
            Rectangle {
                id: lutListOpenBtn
                anchors {
                    right: parent.right
                    rightMargin: 4
                    verticalCenter: parent.verticalCenter
                }
                width: 20
                height: 20
                color: Colors.color_transparent
                Image {
                    anchors.fill: parent
                    source: lutListPopup.visible ? "qrc:/icons/ic_open_triangle.svg" : "qrc:/icons/ic_close_triangle.svg"
                    sourceSize: Qt.size(parent.width, parent.height)
                    opacity: checkBox.checked ? 1 : 0.2
                }
            }

            MouseArea {
                id: triggerArea
                anchors.fill: parent
                hoverEnabled: true
                enabled: checkBox.checked
                onEntered: lutSelectTrigger.isHovered = true
                onExited: lutSelectTrigger.isHovered = false
                onClicked: lutListPopup.visible ? lutListPopup.close() : lutListPopup.open()
            }
        }

        DoubleListPopup {
            id: lutListPopup
            property bool importDialogOpen: false

            parent: lutSelectTrigger
            y: lutSelectTrigger.height + 4
            x: -70
            width: lutSetting.width < 256 ? 256 : lutSetting.width
            popupHeight: 276
            closePolicy: Popup.CloseOnPressOutsideParent
            leftWidth: Math.round(lutListPopup.width * selectListPopupRatio)
            leftListSpacing: 4
            rightListSpacing: 0
            leftListTopMargin: 0
            leftListBottomMargin: 4
            rightListTopMargin: 0
            rightListBottomMargin: 4
            leftHeader: qsTr("pccut_panel_colorrecovery_device")
            leftHeaderHeight: 35
            rightHeader: qsTr("pccut_panel_colorrecovery_lut")
            rightHeaderHeight: 35
            leftModel: displaySeriesModel
            rightModel: control.fixSeriesIndex === -2 ? customLutModel : groupedLutModel

            function positionRightToSelected() {
                if (control.fixSeriesIndex === -2) {
                    for (var i = 0; i < customLutModel.count; i++) {
                        if (customLutModel.get(i).slug === control.fixLutSlug) {
                            lutListPopup.positionRightAt(i, ListView.Center);
                            return;
                        }
                    }
                } else {
                    for (var j = 0; j < groupedLutModel.count; j++) {
                        var it = groupedLutModel.get(j);
                        if (!it.isHeader && it.slug === control.fixLutSlug && it.productIdx === control.fixProductIndex) {
                            lutListPopup.positionRightAt(j, ListView.Center);
                            return;
                        }
                    }
                }
            }

            onOpened: {
                buildSeriesDisplayModel();
                buildCustomLutModel();
                if (!lutVM.hasClip) return;
                if (control.fixSeriesIndex === 0 && !lutVM.isEnable) {
                    restoreFromSlug(lutVM.slug);
                }
                if (control.fixSeriesIndex !== -2) {
                    buildGroupedModel(control.fixSeriesIndex);
                }
                if (control.fixSeriesIndex >= 0 || control.fixSeriesIndex === -2) {
                    for (var i = 0; i < displaySeriesModel.count; i++) {
                        if (displaySeriesModel.get(i).seriesIdx === control.fixSeriesIndex) {
                            lutListPopup.leftCurrentIndex = i;
                            lutListPopup.positionLeftAt(i, ListView.Center);
                            break;
                        }
                    }
                } else {
                    lutListPopup.leftCurrentIndex = -1;
                }
                Qt.callLater(positionRightToSelected);
            }

            leftDelegate: Component {
                Item {
                    width: ListView.view ? ListView.view.width : 0
                    height: model.type === "divider" ? 1 : 28

                    Rectangle {
                        visible: model.type === "divider"
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 4
                        anchors.rightMargin: 4
                        height: 1
                        color: Colors.color_37383A
                    }

                    Rectangle {
                        id: seriesItemBg
                        visible: model.type === "series" || model.type === "custom-lut"
                        width: parent.width - 8
                        height: parent.height
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: model.seriesIdx === control.fixSeriesIndex ?
                                   ColorsConfig.color_353738_4DFFC920 : Colors.color_transparent
                        radius: RadiusConfig.radius_4_8

                        Text {
                            id: seriesItemText
                            anchors {
                                left: parent.left
                                leftMargin: 8
                                right: parent.right
                                rightMargin: 8
                                verticalCenter: parent.verticalCenter
                            }
                            text: model.seriesName
                            color: ColorsConfig.color_EEEEEE_4DFFC9
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                        }

                        LightToolTip {
                            visible: seriesItemArea.containsMouse && seriesItemText.implicitWidth > seriesItemText.width
                            tip: seriesItemText.text
                            z: 200
                        }

                        MouseArea {
                            id: seriesItemArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: {
                                if (model.type === "series") {
                                    lutListPopup.leftCurrentIndex = index;
                                    control.fixSeriesIndex = model.seriesIdx;
                                    buildGroupedModel(model.seriesIdx);
                                } else if (model.type === "custom-lut") {
                                    lutListPopup.leftCurrentIndex = index;
                                    control.fixSeriesIndex = -2;
                                    buildCustomLutModel();
                                }
                            }
                        }
                    }
                }
            }


            background: Rectangle {
                color: Qt.rgba(20/255, 20/255, 20/255, 1)
                border.color: Colors.color_444444
                border.width: 1
                opacity: 1
                radius: 8
            }

            rightDelegate: Component {
                Item {
                    id: rightDelegateRoot
                    width: ListView.view ? ListView.view.width : 0

                    // 首项无顶部间距，后续项含分组间距（标题→行、行→行、行→标题）
                    readonly property int rowHeight: 28
                    readonly property int groupSpacing: 4
                    readonly property int intraGroupSpacing: 4
                    readonly property int headerHeightWithSpacing: rowHeight + groupSpacing
                    readonly property int rowHeightWithSpacing: rowHeight + intraGroupSpacing
                    // 右侧滚动条预留宽度（滚动条 width 6 + rightMargin 2），右侧元素需让出避免被遮挡
                    readonly property int scrollBarInset: 8

                    // ListView spacing 置 0，所有项间距统一由 delegate 内置（首项无顶部间距），
                    // 避免与 ListView spacing 叠加成双倍
                    height: {
                        if (model.isDivider === true) return index > 0 ? 1 + intraGroupSpacing : 1;
                        if (control.fixSeriesIndex === -2) return index > 0 ? rowHeightWithSpacing : rowHeight;
                        if (model.isHeader === true) return index > 0 ? headerHeightWithSpacing : rowHeight;
                        return index > 0 ? rowHeightWithSpacing : rowHeight;
                    }

                    // 分割线（与左列分割线对齐：线落在「上一项 + intraGroupSpacing」处）
                    Rectangle {
                        visible: model.isDivider === true
                        anchors.top: parent.top
                        anchors.topMargin: intraGroupSpacing
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 4
                        anchors.rightMargin: 4
                        height: 1
                        color: Colors.color_37383A
                    }

                    // 产品分组标题
                    Item {
                        visible: model.isHeader === true
                        height: rowHeight
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 10
                        anchors.rightMargin: 4
                        Text {
                            anchors {
                                left: parent.left
                                verticalCenter: parent.verticalCenter
                            }
                            text: (model.displayText || "").toUpperCase()
                            color: Colors.color_444444
                            font.pixelSize: 10
                            font.weight: Font.Medium
                        }
                    }

                    // 普通LUT行（含导入行 / 内置LUT行 / 自定义LUT行）
                    Rectangle {
                        id: lutRowBg
                        visible: model.isHeader !== true && model.isDivider !== true
                        width: parent.width - 8
                        height: rowHeight
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        color: ((lutRowHover.hovered || (deleteLutMenu.opened && deleteLutMenu.capturedSlug === model.slug)) && !(model.isImport && (lutSetting.customLutAtLimit || lutSetting._isImporting))) ? ColorsConfig.color_353738_4DFFC920 : Colors.color_transparent
                        radius: RadiusConfig.radius_4_8

                        // 导入自定义LUT标签
                        Text {
                            visible: model.isImport === true
                            anchors {
                                left: lutRowCheckIcon.right
                                leftMargin: 4
                                verticalCenter: parent.verticalCenter
                            }
                            text: qsTr("pccut_panel_colorrecovery_custom_lut_import_btn")
                            color: ColorsConfig.color_EEEEEE_4DFFC9
                            font.pixelSize: 11
                            font.weight: Font.Medium
                        }

                        // 选中勾（非导入行；始终保留用于 anchor，透明色不影响视觉）
                        Rectangle {
                            id: lutRowCheckIcon
                            width: 20
                            height: 20
                            anchors {
                                left: parent.left
                                leftMargin: 6
                                verticalCenter: parent.verticalCenter
                            }
                            color: Colors.color_transparent
                            Image {
                                visible: {
                                    if (model.isImport === true) return false;
                                    if (control.fixSeriesIndex === -2)
                                        return model.slug === control.fixLutSlug;
                                    return model.slug === control.fixLutSlug
                                        && model.productIdx === control.fixProductIndex;
                                }
                                anchors.fill: parent
                                source: "qrc:/app_qrc/icons/icon_compose_check.svg"
                                sourceSize: Qt.size(parent.width, parent.height)
                            }
                        }

                        // LUT文本
                        Text {
                            id: lutRowText
                            visible: model.isImport !== true
                            anchors {
                                left: lutRowCheckIcon.right
                                leftMargin: 4
                                right: parent.right
                                rightMargin: control.fixSeriesIndex === -2 && model.isImport !== true ? 30 : 6
                                verticalCenter: parent.verticalCenter
                            }
                            text: control.fixSeriesIndex === -2 ? (model.name || "") : (model.displayText || "")
                            color: ColorsConfig.color_EEEEEE_4DFFC9
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            font.letterSpacing: 0.33
                            elide: Text.ElideRight
                        }

                        LightToolTip {
                            visible: lutRowHover.hovered && !deleteLutMenu.opened && lutRowText.visible && lutRowText.implicitWidth > lutRowText.width
                            tip: lutRowText.text
                            z: 200
                        }

                        MouseArea {
                            id: lutRowArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                if (model.isImport === true) {
                                    if (lutSetting.customLutAtLimit || lutSetting._isImporting) return;
                                    if (devList.getCustomLutList().length >= 100) {
                                        lctToaster.showToast(qsTr("pccut_panel_colorrecovery_custom_lut_fail_max"), "editPanel", false);
                                        return;
                                    }
                                    lutListPopup.importDialogOpen = true;
                                    lutListPopup.closePolicy = Popup.NoAutoClose;
                                    eventTracker.trackEvent("pccut_panel_colorrecovery_custom_lut_import_click")
                                    customLutDialog.open();
                                    return;
                                }
                                if (control.fixSeriesIndex === -2) {
                                    if (lutMoreHover.hovered || deleteLutMenu.opened) return;
                                    control.fixLutSlug = model.slug;
                                    control.curLutName = model.name;
                                    control.isSceneRecommended = false;
                                    lutVM.selectLut(model.slug);
                                    lutListPopup.close();
                                    eventTracker.trackEvent("pccut_panel_colorrecovery", {
                                        "is_turnon": true,
                                        "color_slug_string": "custom",
                                        "preset_name": _presetName(),
                                        "preset_parameters": _presetParameters(),
                                        "use_method": "switch",
                                        "device_model": _lutDeviceModel(),
                                        "device_category": "custom",
                                        "is_scene_recommend": false
                                    })
                                    eventTracker.trackEvent("pccut_panel_colorrecovery_custom_lut_apply")
                                } else {
                                    const curIdx = lutListPopup.leftCurrentIndex;
                                    var si = control.fixSeriesIndex;
                                    if (curIdx >= 0 && curIdx < displaySeriesModel.count) {
                                        var row = displaySeriesModel.get(curIdx);
                                        if (row) si = row.seriesIdx;
                                    }
                                    control.curLutName = model.displayText;
                                    control.fixLutSlug = model.slug;
                                    control.fixProductIndex = model.productIdx;
                                    control.fixSeriesIndex = si;
                                    control.isSceneRecommended = false;
                                    // 「无」系列无对应 LUT 资源，直接清掉当前片段的用户 LUT
                                    if (si === 0) {
                                        lutVM.selectNone();
                                    } else if (model.isLocal || !(model.url && model.url.length > 0)) {
                                        // 本地已有（或无云端 url 的兜底）：立即应用
                                        if (Qt.platform.os == "osx1" && devList.isDlog2Slug(model.slug) && hasDLog2Metadata) {
                                            dlog2VM.setStyle(dlog2VM.currentStyle == "basic" ? "natural" : dlog2VM.currentStyle);
                                        } else {
                                            lutVM.selectLut(model.slug);
                                        }
                                    } else {
                                        // 未下载：记录待应用/待关闭，触发下载，列表保持打开，
                                        // 完成后由 onLutFileReady 自动应用并关闭
                                        lutSetting.pendingApplyLutSlug = model.slug;
                                        lutSetting.pendingCloseAfterApplyLut = model.slug;
                                        devList.requestLutDownload(model.slug);
                                        buildGroupedModel(control.fixSeriesIndex);
                                        return;
                                    }
                                    lutListPopup.close();
                                    eventTracker.trackEvent("pccut_panel_colorrecovery", {
                                        "is_turnon": true,
                                        "color_slug_string": model.slug,
                                        "preset_name": _presetName(),
                                        "preset_parameters": _presetParameters(),
                                        "use_method": "switch",
                                        "device_model": _lutDeviceModel(),
                                        "device_category": devList.getSeriesCategory(si) || "unknown",
                                        "is_scene_recommend": false
                                    })
                                }
                            }
                        }

                        // ── 云端下载图标（未下载 / 非下载中，仅非自定义LUT行）──────────
                        Item {
                            id: lutDownloadArea
                            visible: control.fixSeriesIndex !== -2
                                     && model.isImport !== true
                                     && model.isHeader !== true
                                     && !model.isLocal
                                     && !devList.isDownloadingLut(model.slug || "")
                                     && (model.url && model.url.length > 0)
                            width: 16
                            height: 16
                            anchors {
                                right: parent.right
                                rightMargin: 4
                                verticalCenter: parent.verticalCenter
                            }
                            z: 2

                            Image {
                                anchors.centerIn: parent
                                width: 12
                                height: 12
                                source: "qrc:/icons/ic_lut_download.svg"
                                sourceSize: Qt.size(12, 12)
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    // 点下载图标即选中该 LUT 并记录待应用/待关闭，
                                    // 下载中列表保持打开，完成后由 onLutFileReady 自动应用并关闭
                                    control.fixLutSlug = model.slug;
                                    control.fixProductIndex = model.productIdx;
                                    control.curLutName = model.displayText;
                                    control.isSceneRecommended = false;
                                    lutSetting.pendingApplyLutSlug = model.slug;
                                    lutSetting.pendingCloseAfterApplyLut = model.slug;
                                    devList.requestLutDownload(model.slug);
                                    // isDownloadingLut 是函数调用不会自动重求值，重建模型让下载动画显示
                                    buildGroupedModel(control.fixSeriesIndex);
                                }
                            }
                        }

                        // ── 下载中进度环（尺寸/位置与 lutDownloadArea 的下载图标一致）──
                        DownloadAnimation {
                            visible: control.fixSeriesIndex !== -2
                                     && model.isImport !== true
                                     && model.isHeader !== true
                                     && devList.isDownloadingLut(model.slug || "")
                            width: 12
                            height: 12
                            anchors {
                                right: parent.right
                                rightMargin: 4
                                verticalCenter: parent.verticalCenter
                            }
                            active: visible
                            progress: lutSetting.lutDownloadProgress[model.slug] || 0
                            alignment: Qt.AlignHCenter
                            alignmentMargin: 0
                            z: 2
                        }

                        // ··· 更多操作按钮（仅自定义LUT行，声明在 lutRowArea 之后确保点击优先级更高）
                        Rectangle {
                            id: lutRowMoreBtn
                            visible: control.fixSeriesIndex === -2 && model.isImport !== true
                            width: visible ? 20 : 0
                            height: 20
                            radius: 4
                            color: (lutMoreHover.hovered && !deleteLutMenu.opened) ? Colors.color_37383A : Colors.color_transparent
                            anchors {
                                right: parent.right
                                rightMargin: 6 + rightDelegateRoot.scrollBarInset
                            }
                            y: (parent.height - height) / 2

                            Row {
                                anchors.centerIn: parent
                                spacing: 2
                                Repeater {
                                    model: 3
                                    Rectangle {
                                        width: 2
                                        height: 2
                                        radius: 1
                                        color: (lutMoreHover.hovered && !deleteLutMenu.opened) ? Colors.color_EEEEEE : Colors.color_999999
                                    }
                                }
                            }

                            MouseArea {
                                id: lutRowMoreArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    deleteLutMenu.capturedSlug = model.slug;
                                    deleteLutMenu.popup(parent, parent.width - deleteLutMenu.implicitWidth + 20, parent.height + 2);
                                }
                            }

                            HoverHandler { id: lutMoreHover }
                        }

                        HoverHandler { id: lutRowHover }
                    }
                }
            }
        }

        Rectangle {
            id: importLutShortcutBtn
            property bool isHovered: false
            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
            }
            width: 24
            height: 24
            radius: 4
            color: isHovered && checkBox.checked && !lutSetting.customLutAtLimit && !lutSetting._isImporting ? Colors.color_37383A : Colors.color_2F3032
            opacity: checkBox.checked && !lutSetting.customLutAtLimit && !lutSetting._isImporting ? 1 : 0.2

            Image {
                id: importLutShortcutIcon
                anchors.centerIn: parent
                source: "qrc:/icons/editor_draft_add.svg"
                sourceSize: Qt.size(16, 16)
                ColorOverlay {
                    anchors.fill: parent
                    source: parent
                    color: "#EEEEEE"
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                enabled: checkBox.checked && !lutSetting.customLutAtLimit && !lutSetting._isImporting
                onEntered: importLutShortcutBtn.isHovered = true
                onExited: importLutShortcutBtn.isHovered = false
                onClicked: {
                    if (devList.getCustomLutList().length >= 100) {
                        lctToaster.showToast(qsTr("pccut_panel_colorrecovery_custom_lut_fail_max"), "editPanel", false);
                        return;
                    }
                    lutListPopup.importDialogOpen = true;
                    lutListPopup.closePolicy = Popup.NoAutoClose;
                    eventTracker.trackEvent("pccut_panel_colorrecovery_custom_lut_import_click")
                    customLutDialog.open();
                }
            }
        }
    }

    LightToaster { id: lctToaster }

    LightMenu {
        id: deleteLutMenu
        verticalPadding: 0
        property string capturedSlug: ""
        menuWidth: 90
        onClosed: capturedSlug = ""
        Action {
            text: qsTr("pccut_device_batch_delete")
            onTriggered: {
                // 删除当前选中的自定义LUT后，不关闭弹窗，
                // 由 onCustomLutListChanged → showAsNone() 把选中切到「无」
                devList.deleteCustomLut(deleteLutMenu.capturedSlug);
            }
        }
    }

    // 导入自定义LUT文件对话框
    FileDialog {
        id: customLutDialog
        fileMode: FileDialog.OpenFiles
        nameFilters: ["LUT files (*.cube *.3dl)"]

        // 将 FileDialog 返回的 file:// URL 转成本地路径
        // 处理：percent-decode（空格/unicode）、Windows 盘符、UNC 路径
        function urlToLocalPath(url) {
            var s = url.toString();
            if (s.startsWith("file:///")) {
                // Windows: file:///C:/path → C:/path
                // *nix:    file:///path    → /path
                s = s.substring(7);
                if (/^\/[A-Za-z]:/.test(s)) s = s.substring(1);
            } else if (s.startsWith("file://")) {
                // UNC: file://server/share/path → //server/share/path
                s = s.substring(5);
            }
            try {
                return decodeURIComponent(s);
            } catch (e) {
                return s;
            }
        }

        onAccepted: {
            lutListPopup.importDialogOpen = false;
            lutListPopup.closePolicy = Popup.CloseOnPressOutsideParent;
            control.fixSeriesIndex = -2;
            Qt.callLater(lutListPopup.open);

            const files = customLutDialog.selectedFiles.map(urlToLocalPath);
            lctToaster.showToast(qsTr("pccut_panel_colorrecovery_custom_lut_loading"), "editPanel", false);
            lutSetting._isImporting = true;
            devList.importCustomLuts(files);
        }

        onRejected: {
            lutListPopup.importDialogOpen = false;
            lutListPopup.closePolicy = Popup.CloseOnPressOutsideParent;
        }
    }

    Connections {
        target: devList
        function onImportFinished(result) {
            lutSetting._isImporting = false;
            const ok = result.successCount;
            const failures = result.failedFiles || [];
            const failed = failures.length;
            const total = result.totalCount || 1;
            var msg = "";
            if (failed === 0 && ok > 0) {
                msg = qsTr("pccut_panel_colorrecovery_custom_lut_success").arg(ok);
                eventTracker.trackEvent("pccut_panel_colorrecovery_custom_lut_import_success");
            } else if (total === 1 && failed === 1 && ok === 0) {
                const reason = failures[0].reason;
                if (reason === "format")
                    msg = qsTr("pccut_panel_colorrecovery_custom_lut_fail_format");
                else if (reason === "size")
                    msg = qsTr("pccut_panel_colorrecovery_custom_lut_fail_size");
                else if (reason === "limit")
                    msg = qsTr("pccut_panel_colorrecovery_custom_lut_fail_max");
                else if (reason === "duplicate")
                    msg = qsTr("pccut_panel_colorrecovery_custom_lut_fail_duplicate");
                else if (reason === "copy_failed")
                    msg = "导入失败：无法复制文件（检查磁盘权限）";
                else
                    msg = qsTr("pccut_panel_colorrecovery_custom_lut_fail_damage");
            } else if (ok === 0 && failed > 0) {
                msg = qsTr("pccut_panel_colorrecovery_custom_lut_fail_all").arg(failed);
            } else if (failed > 0) {
                msg = qsTr("pccut_panel_colorrecovery_custom_lut_partial").arg(failed).arg(ok);
            }
            if (msg !== "")
                lctToaster.showToast(msg, "editPanel", false);
            buildCustomLutModel();
        }
    }

    // ======== D-LOG 2 二期算法方案风格下拉 ========
    Item {
        id: styleSetting
        width: parent.width
        height: visible ? 24 : 0
        anchors {
            left: parent.left
            right: parent.right
            top: selectItem.bottom
            // 隐藏时不占 margin，避免下方 strengthSetting 出现 12px 死空档
            topMargin: visible ? 12 : 0
        }
        // 只在色彩还原开启 + 名称=D-LOG 2 + 平台启用 DLog2 时显示
        visible: checkBox.checked && lutSetting._dlog2Enabled

        // UI 展示 3 档：基础 / 自然 / 通透（鲜艳、明亮在算法侧未落地，暂不显示）
        // ⚠️ "basic" 是全栈统一的基础态 sentinel（QML/C++/JSON 共用）；C++ 端 DLog2Adjust::setStyle
        //    识别 "basic" 走 detach 分支；"natural"/"clear" 是 C++ DLog2Adjust::styleNames() 的算法子集
        // 预览图当前为占位，待设计稿原图直接同名替换 icons/dlog2/ 下文件即可，无需改代码/qrc
        readonly property string _BASE_KEY: "basic"
        readonly property var _styles: ({
            "basic":   { name: qsTr("pccut_panel_colorrecovery_style_basic_option"),    desc: qsTr("pccut_panel_colorrecovery_style_basic_desc"),    preview: "qrc:/icons/dlog2/style_preview_base.png" },
            "natural": { name: qsTr("pccut_panel_colorrecovery_style_natural_option"), desc: qsTr("pccut_panel_colorrecovery_style_natural_desc"), preview: "qrc:/icons/dlog2/style_preview_natural.png" },
            "clear":   { name: qsTr("pccut_panel_colorrecovery_style_crisp_option"),   desc: qsTr("pccut_panel_colorrecovery_style_crisp_desc"),   preview: "qrc:/icons/dlog2/style_preview_clear.png" }
        })
        // Repeater 依此展开、currentUiStyle 直接是 style_type canonical key ("basic"/"natural"/"clear")
        readonly property var _styleOrder: ["basic", "natural", "clear"]
        readonly property string currentUiStyle: dlog2VM.currentStyle
        readonly property bool _algoAvailable: lutSetting.hasDLog2Metadata

        Text {
            id: styleLabel
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            height: 15
            text: qsTr("pccut_panel_colorrecovery_style_title")
            color: Colors.color_999999
            opacity: 1
            font.pixelSize: 11
            verticalAlignment: Text.AlignVCenter
        }

        Rectangle {
            id: styleTrigger
            anchors {
                left: parent.left
                leftMargin: 70
                // 右缘与「名称」行最右侧的导入按钮（importLutShortcutBtn）对齐
                right: parent.right
                verticalCenter: parent.verticalCenter
            }
            height: 24
            radius: 4
            color: styleTriggerArea.containsMouse ? Colors.color_37383A : Colors.color_2F3032

            Text {
                anchors {
                    left: parent.left
                    leftMargin: 8
                    right: styleArrow.left
                    rightMargin: 4
                    verticalCenter: parent.verticalCenter
                }
                text: styleSetting._styles[styleSetting.currentUiStyle].name || ""
                font.pixelSize: 11
                color: Colors.color_EEEEEE
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
            Image {
                id: styleArrow
                anchors {
                    right: parent.right;
                    rightMargin: 4;
                    verticalCenter: parent.verticalCenter
                }
                source: stylePopup.visible ? "qrc:/icons/ic_open_triangle.svg" : "qrc:/icons/ic_close_triangle.svg"
                opacity: checkBox.checked ? 1 : 0.2
            }
            MouseArea {
                id: styleTriggerArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    if (stylePopup.opened) {
                        stylePopup.close();
                    } else {
                        stylePopup.open();
                    }
                }
            }
        }

        // 设计稿：256 宽弹层，内边距 12，3 列 72×72 缩略图卡片（12+72+8=92 列跨距），
        // 卡片=缩略图+标题+描述，高度随各语言描述行数自适应
        DoubleListPopup {
            id: stylePopup
            // parent 挂到触发按钮 + CloseOnPressOutsideParent：
            // 点击触发按钮不会先触发"点外部自动关闭"再被 onClicked 重新打开，
            // 开/关完全由 styleTriggerArea.onClicked 切换（与 lutListPopup 同方案）
            parent: styleTrigger
            x: -70
            y: styleTrigger.height + 4
            width: 256
            height: styleGrid.implicitHeight + topPadding + bottomPadding
            padding: 12
            closePolicy: Popup.CloseOnPressOutsideParent

            // 背景与 LUT 下拉（DoubleListPopup）一致：#141414 底、#37383A 描边、圆角 8
            background: Rectangle {
                color: Colors.color_141414
                radius: 8
                border.width: 1
                border.color: Colors.color_37383A
            }

            contentItem: Grid {
                id: styleGrid
                columns: 3
                columnSpacing: 8
                rowSpacing: 8
                verticalItemAlignment: Grid.AlignTop
                Repeater {
                    model: styleSetting._styleOrder
                    delegate: Item {
                        id: styleCard
                        // index=0 (基础) 永远可选；1..4 需要 Meta 可读
                        readonly property bool isAlgoOption: index !== 0
                        readonly property bool itemEnabled: !isAlgoOption || styleSetting._algoAvailable
                        readonly property bool isSelected: styleSetting.currentUiStyle === modelData
                        readonly property var styleData: styleSetting._styles[modelData]
                        width: 72
                        height: cardColumn.height

                        Column {
                            id: cardColumn
                            width: parent.width
                            spacing: 4

                            Item {
                                id: thumbBox
                                width: 72
                                height: 72

                                Image {
                                    id: thumbImg
                                    anchors.fill: parent
                                    source: styleCard.styleData.preview || ""
                                    fillMode: Image.PreserveAspectCrop
                                    sourceSize { width: 144; height: 144 }
                                    visible: false
                                }
                                Rectangle {
                                    id: thumbMask
                                    anchors.fill: parent
                                    radius: 4
                                    visible: false
                                }
                                // 图缺失/加载失败时的灰底兜底，不留空洞
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 4
                                    color: Colors.color_37383A
                                    visible: thumbImg.status !== Image.Ready
                                }
                                OpacityMask {
                                    anchors.fill: parent
                                    source: thumbImg
                                    maskSource: thumbMask
                                    visible: thumbImg.status === Image.Ready
                                    opacity: styleCard.itemEnabled ? 1 : 0.4
                                }
                                // 描边：选中为品牌红（studio 红 / xtra 绿），未选中悬停为 50% 白
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 4
                                    color: Colors.color_transparent
                                    border.width: 1.5
                                    border.color: styleCard.isSelected ? ColorsConfig.color_F22443_4DFFC9
                                                                       : Qt.rgba(1, 1, 1, 0.5)
                                    visible: styleCard.isSelected || (cardArea.containsMouse && styleCard.itemEnabled)
                                }
                            }

                            Text {
                                topPadding: 4
                                width: parent.width
                                text: styleCard.styleData.name
                                color: ColorsConfig.color_EEEEEE_4DFFC9
                                opacity: styleCard.itemEnabled ? 1 : 0.4
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                            }

                            Text {
                                topPadding: -2
                                width: parent.width
                                text: styleCard.styleData.desc
                                color: Colors.color_666666
                                opacity: styleCard.itemEnabled ? 1 : 0.4
                                font.pixelSize: 10
                                wrapMode: Text.Wrap
                                maximumLineCount: 3
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            id: cardArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                if (!styleCard.itemEnabled) {
                                    lctToaster.showToast(qsTr("pccut_panel_colorrecovery_meta_missing_toast"), "editPanel", false);
                                    return;
                                }
                                if (styleSetting.currentUiStyle !== modelData) {
                                    if (modelData === "basic") {
                                        lutVM.selectLut(lutVM.slug);
                                        dlog2VM.currentStyle = "basic";
                                    } else {
                                        dlog2VM.setStyle(modelData);
                                    }
                                    // 二期埋点（pageId=832148904）：风格切换视作 use_method=switch，
                                    // preset_name/preset_parameters 反映切换后的最新状态（helper 直接读 vf）
                                    eventTracker.trackEvent("pccut_panel_colorrecovery", {
                                        "is_turnon": checkBox.checked,
                                        "color_slug_string": _lutColorSlugString(),
                                        "device_model": _lutDeviceModel(),
                                        "device_category": _lutDeviceCategory(),
                                        "is_scene_recommend": control.isSceneRecommended,
                                        "preset_name": _presetName(),
                                        "preset_parameters": _presetParameters(),
                                        "use_method": "switch"
                                    });
                                }
                                stylePopup.close();
                            }
                        }
                    }
                }
            }
        }
    }

    // 浓度设置：mac 本期彻底移除 LUT 浓度 UI（无论是否 D-LOG 2、无论 DLog2 风格），windows 保留原行为
    Item{
        id: strengthSetting
        property bool isEditing: false
        anchors {
            left: parent.left
            top: styleSetting.bottom
            // styleSetting 隐藏时其自身 topMargin 也为 0，此处再叠 12 即紧贴 selectItem 下方
            topMargin: visible ? 12 : 0
        }
        width: parent.width
        height: visible ? 15 : 0
        visible: Qt.platform.os !== "osx1"
        HoverableText {
            id: strengthText
            anchors {
                verticalCenter: parent.verticalCenter
                left: parent.left
            }
            height: 15
            maximumLineCount: 1
            color: Colors.color_999999
            opacity: checkBox.checked && control.hasValidLut ? 1 : 0.2
            font.pixelSize: 11
            horizontalAlignment: Text.AlignLeft
            verticalAlignment: Text.AlignVCenter
            text: qsTr("pccut_panel_colorrecovery_concentration")
            MouseArea {
                anchors.fill: parent
                onDoubleClicked: {
                    lutVM.reset();
                }
            }
        }
        LightBaseSlider {
            id: baseSlider
            property int lastValue : 100
            property real sliderLeft: 70
            leftPadding: 0
            anchors{
                left: parent.left
                leftMargin: sliderLeft
                verticalCenter: parent.verticalCenter
            }

            enabled: checkBox.checked && control.hasValidLut
            visible: true
            width: parent.width - bothSidePadding
            height: 12
            from: 0
            to: 100
            value: lutVM.strength
            stepSize: 1
            snapMode: Slider.SnapAlways
            Accessible.role: Accessible.Slider
            onMoved: {
                if (pressed){
                    lutVM.updateStrength(value, 1);
                }
            }

            onPressedChanged: {
                if (!pressed) {
                    // 抬手入撤销栈
                    lutVM.updateStrength(value, 2);
                    lastValue = value;
                    eventTracker.trackEvent("pccut_panel_colorrecovery_strength", {
                        "color_slug_string": _lutColorSlugString(),
                        "strength_value": value
                    })
                }
            }

            onValueChanged:{
                if(!pressed){
                    lastValue = value;
                }
            }
        }

            // 点击非编辑框位置时失焦
            Loader {
                active: strengthSetting.isEditing
                sourceComponent: TextInputOverlay {
                    activeInputContainer: sliderInputText
                }
            }


            Text{
                id: strengthVaule
                anchors{
                    right: parent.right
                    rightMargin: 0
                    verticalCenter: parent.verticalCenter
                }
                height: 15
                width: 19
                color: Colors.color_CCCCCC
                opacity: checkBox.checked && control.hasValidLut ? 1 : 0.2
                font.pixelSize: 11
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: lutVM.strength
                visible: !strengthSetting.isEditing

                MouseArea {
                    anchors.fill: parent
                    enabled:checkBox.checked

                    onClicked: {
                        ShortcutObserver.disableAllShortcut(true)
                        sliderInputText.text = strengthVaule.text
                        strengthSetting.isEditing = true
                        sliderInputText.forceActiveFocus()
                        sliderInputText.selectAll()
                        baseSlider.lastValue = strengthVaule.text
                    }
                }
            }


            TextInput {
                id: sliderInputText
                inputMethodHints: Qt.ImhFormattedNumbersOnly

                visible: strengthSetting.isEditing
                anchors.fill:parent

                validator: RegularExpressionValidator {
                    regularExpression: /^-?\d*\.?\d*$/
                }
                maximumLength: 10
                clip: true
                horizontalAlignment: TextInput.AlignHCenter
                font.pixelSize: 11
                selectByMouse: true
                color: Colors.color_EEEEEE
                selectionColor: Colors.color_EEEEEE
                selectedTextColor: Colors.color_1F2021
                //  opacity: isDisable ? 0.2 : 1
                text: lutVM.strength

                    //优先占用enter键
                Keys.onShortcutOverride: (event) => {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Tab) {
                        event.accepted = true
                        focus = false
                    }
                }

                // 失去焦点时（点击其他区域、Tab）
                onActiveFocusChanged: {
                    if (!activeFocus && strengthSetting.isEditing) {
                        let result = CommonUtils.validateNumberInput(sliderInputText.text, baseSlider.from, baseSlider.to)
                        if (result !== null) {
                            //如果本次输入的数值与上次不一致,记入撤销栈
                            if (result !== parseFloat(baseSlider.lastValue)) {
                                lutVM.updateStrength(result, 2);  // 入撤销栈
                            }

                        }

                        // root.checkDefaultStatus()
                        strengthSetting.isEditing = false
                        ShortcutObserver.disableAllShortcut(false)
                    }
                }
            }
    }

    // ======== D-LOG 2 二期「更多设置」折叠区 ========
    Item {
        id: moreSettingsSetting
        width: parent.width
        anchors {
            left: parent.left
            right: parent.right
            // 排在 strengthSetting 之后；strengthSetting 隐藏时其 topMargin/height 都为 0，此处自动上移
            top: strengthSetting.bottom
            // 隐藏时 margin 同步归零，不在面板上留 12px 死空档
            topMargin: visible ? 12 : 0
        }
        // 高度：滑杆列（展开时）+ 开关行；隐藏时归零避免占位
        height: visible ? moreContentCol.height : 0
        // 启用 DLog2（mac + D-LOG 2）即显示，基础态也保留：开关行可点击展开、三项参数置灰而非隐藏
        // （win 不上线：_dlog2Enabled 已含 osx 判断，Windows 恒 false 整段隐藏）
        visible: checkBox.checked && lutSetting._dlog2Enabled

        property bool expanded: false
        readonly property bool _paramsEnabled: dlog2VM.currentStyle !== "basic" && lutSetting.hasDLog2Metadata

        // 切回基础时收起展开状态，下次进算法方案默认从折叠开始
        onVisibleChanged: {
            if (!visible) expanded = false;
        }

        // 设计稿：展开时"收起更多设置"开关行位于滑杆下方 12px，收起时单独一行紧跟风格下拉
        Column {
            id: moreContentCol
            anchors { left: parent.left; right: parent.right; top: parent.top }
            spacing: 12

            // 3 项精细：亮度增益 / 高光保护 / 细节增强（展开时显示，位于开关行上方）
            // 走 FilterInfoSetting + DLog2Adjust 通用调节 model 通道，行为/视觉与 AdjustSettingPanel 完全一致：
            // label 双击复位、中心原点滑杆、可点击数值输入框；撤销栈由 nova UpdateDLog2Cmd + commit(true) 记录。
            FilterInfoSetting {
                id: dlog2ParamsSetting
                width: parent.width
                visible: moreSettingsSetting.expanded
                showHeader: false
                sliderLeft: 70
                itemVerticalSpacing: 12
                isDisable: !moreSettingsSetting._paramsEnabled
                // 亮度增益/高光保护/细节增强 三项输入框支持公式（四则+括号+中文全角+基于原值的 "+10"/"*2"/"/2"）
                supportFormula: true
                headerTextColor: Colors.color_666666      // header 已隐藏，此项不生效但保持一致
                subTitleTextColor: Colors.color_999999
                subTitleTextValueColor: Colors.color_999999
                adjustModel: dlog2VM
                onSliderReleased: {
                    eventTracker.trackEvent("pccut_panel_colorrecovery", {
                        "is_turnon": true,
                        "color_slug_string": _lutColorSlugString(),
                        "preset_name": _presetName(),
                        "preset_parameters": _presetParameters(),
                        "use_method": "slide",
                        "device_model": _lutDeviceModel(),
                        "device_category": _lutDeviceCategory(),
                        "is_scene_recommend": control.isSceneRecommended
                    })
                }
            }

            // 展开/收起开关行：只要 DLog2 面板可见就常亮可点，基础态也能展开查看置灰三项
            // 左缘与风格下拉框（styleTrigger）对齐
            Item {
                id: moreHeader
                width: parent.width
                height: 16
                Text {
                    id: moreLabel
                    // 让 label + spacing + 三角 整体在 moreHeader 中横向居中：
                    // label 自身中点相对父中点左移半个 (spacing + 三角宽) = -(4 + 8)/2 = -6
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.horizontalCenterOffset: -8
                    anchors.verticalCenter: parent.verticalCenter
                    text: moreSettingsSetting.expanded
                        ? qsTr("pccut_panel_colorrecovery_hide_settings_btn")
                        : qsTr("pccut_panel_colorrecovery_more_settings_btn")
                    color: Colors.color_999999
                    opacity: 1
                    font.pixelSize: 11
                }
                Image {
                    anchors { left: moreLabel.right; verticalCenter: parent.verticalCenter }
                    width: 16
                    height: 16
                    sourceSize { width: 20; height: 20 }
                    source: moreSettingsSetting.expanded ? "qrc:/icons/ic_open_triangle.svg" : "qrc:/icons/ic_close_triangle.svg"
                    opacity: checkBox.checked ? 1 : 0.2
                    fillMode: Image.Pad
                    horizontalAlignment: Image.AlignHCenter
                    verticalAlignment: Image.AlignVCenter
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        moreSettingsSetting.expanded = !moreSettingsSetting.expanded;
                    }
                }
            }
        }
    }

    // 说明浮框
    Component {
        id: popupComponent
        Popup {
            id:lutPopup
            x: 6 - checkBox.width
            y: parent.y + 20
            width: lutSetting.width
            height: colorrecoverColumn.height + 24
            modal: false
            focus: true
            closePolicy: Popup.CloseOnPressOutsideParent

            background: Rectangle{
                radius: 8
                border.width: 0.5
                border.color: Colors.color_444444
                color: Colors.color_141414
            }
            leftPadding: 17
            topPadding: 12
            Column {
                id: colorrecoverColumn
                spacing: 12
                Text {
                    id: title
                    anchors.left: parent.left
                    width: 193
                    height: 16
                    text: qsTr("pccut_panel_colorrecovery")
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    color: Colors.color_FFFFFF
                }

                Image {
                    id: image
                    width: 224
                    height: 136
                    source: "qrc:/icons/ic_lut_revert_show.png"
                }

                Column {
                    spacing: 12
                    Text {
                        id: detail
                        text: qsTr("pccut_panel_colorrecovery_description")
                        width: 224
                        font.pixelSize: 11
                        font.weight: Font.Normal
                        horizontalAlignment: Text.AlignLeft
                        font.letterSpacing: 0
                        color: Colors.color_EEEEEE
                        wrapMode: Text.WordWrap
                    }

                    Text {
                        id: tips
                        text: qsTr("pccut_panel_colorrecovery_automatic")
                        color: ColorsConfig.color_3392FF_4DFFC9
                        font.pixelSize: 10
                        font.weight: Font.Normal
                        width: 224
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }

}
