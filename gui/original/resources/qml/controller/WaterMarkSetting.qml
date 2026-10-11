import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls
import QtQuick.Controls.Material 2.15
import Config 1.0
import Controls 1.0
import VideoFragmentViewModel 1.0
import WaterMarkListModel 1.0
import Nova 1.0
import app_qrc 1.0
import QmlConstants 1.0
import UsedFunctionManager 1.0
import ProjectSettingsInfo 1.0

/**
 *  @File        : WaterMarkSetting.qml
 *  @Brief       : 水印设置（系列 → 产品 → 样式三级列表，与色彩还原一致使用 DoubleListPopup）
 *  @Author      : jack.sheng
 *  @Date        : 2026-07-13
 */
Item {
    id: waterMarkSetting
    property double defaultOpacity: checkBox.checked ? 1 : 0.2
    property bool isExport: false
    visible: !QmlConstants.isWhiteXtra()

    // 编辑/导出各自一个实例，模式由 isExportMode 构造时一次性固定，VM 内部按标志路由读写
    WatermarkFilterViewModel {
        id: vm
        isExportMode: waterMarkSetting.isExport
    }

    property bool isWaterMarkOpen: vm.isEnable
    property int positionType: vm.positionType
    // 草稿中已应用的水印 slug（未应用水印时为空）
    property string appliedSlug: vm.waterMarkSlug

    // 以 slug 为 key 的下载进度表（0.0–1.0）；根级 Connections 写入，delegate 读取
    property var wmDownloadProgress: ({})

    // 等待下载完成后应用的 slug
    property string pendingApplySlug: ""
    // 下载中不关闭列表；下载完成应用后若仍相等则关闭弹窗，失败或已变化则清空保持打开
    property string pendingCloseAfterApply: ""
    // 已提示过下载失败的 slug 集合，避免批量下载多个失败时重复弹 toast；配置重载后清空
    property var _failedSlugs: []

    // 刷新截图
    signal refreshCoverImage()

    onAppliedSlugChanged: {
        if (appliedSlug.length > 0) restoreFromSlug(appliedSlug);
    }

    // 勾选框被点击后 Controls 会直接写 checked、打断绑定；草稿开关态变化时重新接上
    onIsWaterMarkOpenChanged: syncCheckBoxToDraft()

    // 把 checkBox.checked 恢复为对草稿开关态的绑定
    function syncCheckBoxToDraft() {
        checkBox.checked = Qt.binding(function() { return waterMarkSetting.isWaterMarkOpen; });
    }

    onPositionTypeChanged: {
        if (positionComboBox.currentIndex !== positionType) {
            positionComboBox.currentIndex = positionType;
            positionPopup.currentPositionType = positionType;
        }
    }

    // ── C++ 数据源 ──────────────────────────────────────────────────────────────
    WaterMarkListModel { id: waterMarkListModel }

    // ── 左列（系列）展示模型 ────────────────────────────────────────────────────
    ListModel { id: displaySeriesModel }

    // ── 右列（产品分组 + 水印条目）展示模型 ─────────────────────────────────────
    ListModel { id: groupedWaterMarkModel }

    // ── 列表选中状态持有（无视觉） ──────────────────────────────────────────────
    Item {
        id: control
        property int fixSeriesIndex: 0        // 当前高亮的系列索引
        property int fixProductIndex: -1
        property string fixWaterMarkSlug: ""  // 当前选中水印的 slug（未应用时为推荐值）
        property string curWaterMarkName: " "
    }

    function applyToExportDraft() {
        vm.applyExportOverrideToDraft();
    }

    function closeAllPopup() {
        if (waterMarkListPopup.visible) waterMarkListPopup.close();
        if (positionComboBox.popup.visible) positionComboBox.popup.close();
    }

    // ── 构建左列：系列列表 ──────────────────────────────────────────────────────
    function buildSeriesDisplayModel() {
        displaySeriesModel.clear();
        var count = waterMarkListModel.getSeriesCount();
        for (var i = 0; i < count; i++) {
            displaySeriesModel.append({
                type: "series",
                seriesName: waterMarkListModel.getSeriesName(i),
                seriesIdx: i
            });
        }
    }

    // ── 构建右列：每行 = 一个产品（含所有水印缩略图） ────────────────────────────
    function buildGroupedWaterMarkModel(seriesIdx) {
        groupedWaterMarkModel.clear();
        if (seriesIdx < 0) return;
        var products = waterMarkListModel.getProductList(seriesIdx);
        // 系列内即使只有一个产品也显示产品名
        var showHeader = products.length >= 1;
        for (var pi = 0; pi < products.length; pi++) {
            var wms = waterMarkListModel.getWaterMarkList(seriesIdx, pi);
            // QVariantList 直接 stringify 会丢字段，手动转成纯 JS 对象数组
            var wmArr = [];
            for (var wi = 0; wi < wms.length; wi++) {
                var w = wms[wi];
                wmArr.push({
                    slug:          w.slug          || "",
                    name:          w.name          || "",
                    icon:          w.icon          || "",
                    drawImage:     w.drawImage     || "",
                    isLimitedTime: w.isLimitedTime || false,
                    limitedEnd:    w.limitedEnd    || "",
                    isLocal:       !!w.isLocal,
                    url:           w.url           || ""
                });
            }
            groupedWaterMarkModel.append({
                productName:    products[pi].productName || "",
                productIdx:     pi,
                showHeader:     showHeader,
                watermarksJson: JSON.stringify(wmArr)
            });
        }
    }

    // ── 从 slug 恢复选中状态 ────────────────────────────────────────────────────
    function restoreFromSlug(slug) {
        if (slug.length > 0) {
            var found = waterMarkListModel.findBySlug(slug);
            if (found.seriesIdx >= 0) {
                control.fixSeriesIndex   = found.seriesIdx;
                control.fixProductIndex  = found.productIdx;
                control.fixWaterMarkSlug = slug;
                buildGroupedWaterMarkModel(found.seriesIdx);
                for (var i = 0; i < groupedWaterMarkModel.count; i++) {
                    var it = groupedWaterMarkModel.get(i);
                    var wms = JSON.parse(it.watermarksJson || "[]");
                    for (var wi = 0; wi < wms.length; wi++) {
                        if (wms[wi].slug === slug) {
                            control.curWaterMarkName = it.productName;
                            break;
                        }
                    }
                }
                return;
            }
        }

        // 兜底：默认第一个系列
        if (displaySeriesModel.count > 0) {
            control.fixSeriesIndex = 0;
            buildGroupedWaterMarkModel(0);
        }
    }

    // ── 推荐并恢复选中状态（Component.onCompleted 与 popup onOpened 共用） ───────
    // 全局水印：推荐依据始终是时间轴第一个视频，切换选中片段不影响。
    // 草稿未应用水印（slug 为空）时按设备推荐，只更新列表选中态，不写草稿
    function recommendAndRestore() {
        buildSeriesDisplayModel();
        if (waterMarkSetting.appliedSlug.length > 0) {
            restoreFromSlug(waterMarkSetting.appliedSlug);
            return;
        }
        var firstPath  = waterMarkListModel.firstVideoPath();
        var recProduct = waterMarkListModel.recommendWaterMarkProduct(firstPath);
        var recSlug    = recProduct.length > 0 ? waterMarkListModel.firstSlugOfProduct(recProduct) : "";
        restoreFromSlug(recSlug);
    }

    // ── 应用水印（大图已在本地时调用） ──────────────────────────────────────────
    function applyWaterMark(slug) {
        if (slug.length === 0 || waterMarkListModel.getDrawPathBySlug(slug).length === 0) {
            // 大图缺失（配置错误或文件被删）时提示，不用空路径建水印 clip
            globalSignal.toast(qsTr("pccut_cloud_watermark_load_fail_toast"));
            syncCheckBoxToDraft();
            return;
        }
        if (vm.isEnable) vm.updateWaterMarkSource(slug);
        else             vm.setWaterMarkToTrack(slug);

        if (isExport) refreshCoverImage();
        else          editorDraftManager.saveDraft();
    }

    // ── 应用当前选中水印：本地已下载直接应用，未下载挂 pending 等下载完成自动应用 ──
    function applyOrDownloadCurrent() {
        var slug = control.fixWaterMarkSlug;
        if (slug.length === 0) {
            globalSignal.toast(qsTr("pccut_cloud_watermark_load_fail_toast"));
            syncCheckBoxToDraft();
            return;
        }
        if (waterMarkListModel.isLocalWatermark(slug)) {
            applyWaterMark(slug);
            return;
        }
        if (waterMarkListModel.getUrlBySlug(slug).length > 0) {
            waterMarkSetting.pendingApplySlug = slug;
            waterMarkSetting.pendingCloseAfterApply = slug;
            waterMarkListModel.requestDownload(slug);
        } else {
            globalSignal.toast(qsTr("pccut_cloud_watermark_load_fail_toast"));
            syncCheckBoxToDraft();
        }
    }

    // ── 水印下载信号响应（从 WaterMarkListModel 转发） ────────────────────────────
    Connections {
        target: waterMarkListModel

        // 水印产品 zip 下载解压完成
        function onWatermarkProductReady(slug) {
            var m = waterMarkSetting.wmDownloadProgress;
            if (m[slug] !== undefined) {
                delete m[slug];
                waterMarkSetting.wmDownloadProgress = m;
            }
            // 重建右列让缩略图 Image 重新加载
            buildGroupedWaterMarkModel(control.fixSeriesIndex);
            if (slug !== waterMarkSetting.pendingApplySlug) return;
            waterMarkSetting.pendingApplySlug = "";
            waterMarkSetting.applyWaterMark(slug);
            if (waterMarkSetting.pendingCloseAfterApply === slug) {
                waterMarkSetting.pendingCloseAfterApply = "";
                if (waterMarkListPopup.visible) waterMarkListPopup.close();
            }
        }

        // 水印产品 zip 下载失败
        function onWatermarkProductFailed(slug) {
            var m = waterMarkSetting.wmDownloadProgress;
            if (m[slug] !== undefined) {
                delete m[slug];
                waterMarkSetting.wmDownloadProgress = m;
            }
            // 自动下载失败也提示；用 _failedSlugs 去重，避免批量下载多个失败时重复弹
            if (waterMarkSetting._failedSlugs.indexOf(slug) < 0) {
                waterMarkSetting._failedSlugs.push(slug);
                globalSignal.toast(qsTr("pccut_cloud_watermark_load_fail_toast"));
            }
            if (slug !== waterMarkSetting.pendingApplySlug) return;
            waterMarkSetting.pendingApplySlug = "";
            // 勾选框在点击时已被写成勾上，下载失败没落到草稿，恢复为草稿开关态
            waterMarkSetting.syncCheckBoxToDraft();
            // 列表保持打开，让用户重试或选择其他水印
            if (waterMarkSetting.pendingCloseAfterApply === slug)
                waterMarkSetting.pendingCloseAfterApply = "";
        }

        // 下载进度更新（0.0–1.0），写入进度表驱动进度环
        function onDownloadProgressChanged(slug, progress) {
            var m = waterMarkSetting.wmDownloadProgress;
            if (m[slug] === progress) return;
            m[slug] = progress;
            waterMarkSetting.wmDownloadProgress = m;   // 重新赋值触发绑定刷新
        }

        function onModelReloaded() {
            buildSeriesDisplayModel();
            buildGroupedWaterMarkModel(control.fixSeriesIndex);
            // 配置就绪后清空上一轮失败记录，新一轮下载的失败可再次提示
            waterMarkSetting._failedSlugs = [];
        }
    }

    Component.onCompleted: {
        // 加载时即执行推荐+恢复，确保打勾/名称在打开下拉前就正确
        recommendAndRestore();
    }

    width: parent.width
    height: childrenRect.height

    // ── 水印开关 ─────────────────────────────────────────────────────────────────
    Rectangle {
        id: waterMarkRect
        width: parent.width
        height: checkBox.implicitHeight
        color: Colors.color_transparent
        anchors { left: parent.left; right: parent.right; top: parent.top }

        LightCheckBox {
            id: checkBox
            text: qsTr("pccut_watermark_switch")
            anchors.verticalCenter: parent.verticalCenter
            checked: waterMarkSetting.isWaterMarkOpen
            verticalPadding: 1.5
            onClicked: {
                var projectId = draftManager.activeProjectEnvId();
                if (!checkBox.checked) {
                    UsedFunctionManager.removeFunction(projectId, UsedFunctionManager.EditorFunctionType.WATER_LOGO);
                    vm.removeWaterMark();
                    if (isExport) refreshCoverImage();
                    else          editorDraftManager.saveDraft();
                } else {
                    UsedFunctionManager.addFunction(projectId, UsedFunctionManager.EditorFunctionType.WATER_LOGO);
                    waterMarkSetting.applyOrDownloadCurrent();
                }
            }
        }
    }

    // ── 水印名称 ───────────────────────────────────────────────────────────────
    Item {
        id: nameSetting
        width: parent.width
        height: waterMarkSetting.isExport ? 28 : 24
        anchors { left: parent.left; right: parent.right; top: waterMarkRect.bottom; topMargin: 12 }

        Text {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            height: 15
            color: Colors.color_CCCCCC
            opacity: waterMarkSetting.defaultOpacity
            font.pixelSize: waterMarkSetting.isExport ? 12 : 11
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: qsTr("pccut_watermark_name")
        }

        // 触发按钮（与 LutSetting 的 lutSelectTrigger 一致） ─────────────────────
        Rectangle {
            id: waterMarkComboTrigger
            property bool isHovered: false

            anchors {
                left: parent.left
                leftMargin: waterMarkSetting.isExport ? 63 : 70
                right: parent.right
                verticalCenter: parent.verticalCenter
            }
            height: waterMarkSetting.isExport ? 28 : 24
            radius: RadiusConfig.radius_4_8
            color: isHovered && checkBox.checked
                       ? (waterMarkSetting.isExport ? Colors.color_68696D : Colors.color_37383A)
                       : (waterMarkSetting.isExport ? Colors.color_454649 : Colors.color_2F3032)
            opacity: checkBox.checked ? 1 : 0.2

            Text {
                anchors {
                    left: parent.left; leftMargin: 8
                    right: listOpenBtn.left; rightMargin: 4
                    verticalCenter: parent.verticalCenter
                }
                text: control.curWaterMarkName
                font.pixelSize: 12
                color: waterMarkSetting.isExport ? Colors.color_EEEEEE : ColorsConfig.color_EEEEEE_4DFFC9
                opacity: waterMarkSetting.defaultOpacity
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }

            Rectangle {
                id: listOpenBtn
                anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                width: 20; height: 20
                color: Colors.color_transparent
                Image {
                    anchors.fill: parent
                    source: waterMarkListPopup.visible ? "qrc:/icons/ic_open_triangle.svg" : "qrc:/icons/ic_close_triangle.svg"
                    sourceSize: Qt.size(parent.width, parent.height)
                    opacity: checkBox.checked ? 1 : 0.2
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                enabled: checkBox.checked
                onEntered: waterMarkComboTrigger.isHovered = true
                onExited:  waterMarkComboTrigger.isHovered = false
                onClicked: waterMarkListPopup.visible ? waterMarkListPopup.close() : waterMarkListPopup.open()
            }
        }

        // ── DoubleListPopup（与 LutSetting 保持一致） ─────────────────────────────
        DoubleListPopup {
            id: waterMarkListPopup

            parent: waterMarkComboTrigger
            y: waterMarkComboTrigger.height + 4
            x: -(waterMarkSetting.isExport ? 63 : 70)
            z: waterMarkSetting.isExport ? 9999 : 0
            width: 268
            popupHeight: 276
            closePolicy: Popup.CloseOnPressOutsideParent
            leftWidth: Math.round(waterMarkListPopup.width * 56 / 127)
            leftListSpacing: 4
            rightListSpacing: 0
            leftListTopMargin: 0
            leftListBottomMargin: 4
            rightListTopMargin: 0
            rightListBottomMargin: 4
            isAnotherStyle: waterMarkSetting.isExport
            leftHeader: qsTr("pccut_panel_colorrecovery_device")
            leftHeaderHeight: 35
            rightHeader: qsTr("pccut_watermark_type_style")
            rightHeaderHeight: 35
            leftModel: displaySeriesModel
            rightModel: groupedWaterMarkModel

            // 定位右列到当前选中项
            function positionRightToSelected() {
                for (var j = 0; j < groupedWaterMarkModel.count; j++) {
                    if (groupedWaterMarkModel.get(j).productIdx === control.fixProductIndex) {
                        waterMarkListPopup.positionRightAt(j, ListView.Center);
                        return;
                    }
                }
            }

            onOpened: {
                recommendAndRestore();
                buildGroupedWaterMarkModel(control.fixSeriesIndex);
                for (var i = 0; i < displaySeriesModel.count; i++) {
                    if (displaySeriesModel.get(i).seriesIdx === control.fixSeriesIndex) {
                        waterMarkListPopup.leftCurrentIndex = i;
                        waterMarkListPopup.positionLeftAt(i, ListView.Center);
                        break;
                    }
                }
                Qt.callLater(positionRightToSelected);

                // 对未本地化且未在下载中的水印重新触发下载
                waterMarkListModel.requestDownloadAll();
            }

            // ── 左列 delegate ────────────────────────────────────────────────────
            leftDelegate: Component {
                Item {
                    width: ListView.view ? ListView.view.width : 0
                    height: model.type === "divider" ? 1 : 28

                    Rectangle {
                        visible: model.type === "divider"
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left; anchors.right: parent.right
                        anchors.leftMargin: 4; anchors.rightMargin: 4
                        height: 1
                        color: waterMarkSetting.isExport ? Colors.color_56575B : Colors.color_37383A
                    }

                    Rectangle {
                        id: seriesItemBg
                        visible: model.type === "series"
                        width: parent.width - 8
                        height: parent.height
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: model.seriesIdx === control.fixSeriesIndex
                                   ? ColorsConfig.color_353738_4DFFC920 : Colors.color_transparent
                        radius: RadiusConfig.radius_4_8

                        Text {
                            id: seriesItemText
                            anchors {
                                left: parent.left; leftMargin: 8
                                right: parent.right; rightMargin: 8
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
                                waterMarkListPopup.leftCurrentIndex = index;
                                control.fixSeriesIndex = model.seriesIdx;
                                buildGroupedWaterMarkModel(model.seriesIdx);
                            }
                        }
                    }
                }
            }

            // ── 右列 delegate（产品分组 + 28px 水印行） ───────────────────────────
            rightDelegate: Component {
                Item {
                    id: rightDelegateRoot
                    width: ListView.view ? ListView.view.width : 0

                    // 所有行统一 28px、间距统一 4px（与 LUT rightDelegate 一致）
                    readonly property int rowHeight:         28
                    readonly property int intraGroupSpacing: 4
                    readonly property int groupSpacing:      4
                    // logo 图高度固定 16，宽度沿用 90，PreserveAspectFit
                    readonly property int imgH:  16
                    readonly property int imgW:  90

                    readonly property int delegateProductIdx: model.productIdx || 0
                    readonly property string delegateProductName: model.productName || ""

                    property var wms: JSON.parse(model.watermarksJson || "[]")

                    // 首项无顶部间距、后续项 +groupSpacing，使标题↔行、行↔行、产品↔产品间距统一 4px
                    height: (index > 0 ? groupSpacing : 0)
                        + (model.showHeader ? rowHeight : 0)
                        + wms.length * (rowHeight + intraGroupSpacing)

                    // 产品分组标题
                    Item {
                        visible: model.showHeader
                        height:  rightDelegateRoot.rowHeight
                        anchors {
                            top:        parent.top
                            topMargin:  index > 0 ? rightDelegateRoot.groupSpacing : 0
                            left:       parent.left
                            right:      parent.right
                            // 12 = 右列标题（DoubleListPopup rightHeader）的 leftMargin，标题/产品名/对勾三者左对齐
                            leftMargin: 12
                            rightMargin: 4
                        }
                        Text {
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                            text: (model.productName || "").toUpperCase()
                            // 导出面板背景为浅色(#454649)，#444444 会与背景融为一体，需用浅色
                            color: waterMarkSetting.isExport ? Colors.color_999999 : Colors.color_444444
                            font.pixelSize: 10
                            font.weight:    Font.Medium
                        }
                    }

                    // 水印行列表
                    Column {
                        anchors {
                            top: parent.top
                            topMargin: (index > 0 ? rightDelegateRoot.groupSpacing : 0)
                                + (model.showHeader ? rightDelegateRoot.rowHeight : 0)
                            left: parent.left
                            right: parent.right
                        }
                        spacing: rightDelegateRoot.intraGroupSpacing

                        Repeater {
                            model: rightDelegateRoot.wms.length

                            Rectangle {
                                id: wmRowBg
                                property var wm: rightDelegateRoot.wms[index]
                                property bool isSelected: !!(wm && wm.slug === control.fixWaterMarkSlug)
                                property bool isLocal: !!(wm && wm.isLocal)
                                property bool isDownloading: !!(wm && waterMarkListModel.isDownloading(wm.slug))
                                // 下载进度（0.0–1.0），从根进度表读取，重建后不丢
                                property real downloadProgress: (wm && wm.slug) ? (waterMarkSetting.wmDownloadProgress[wm.slug] || 0) : 0

                                width: rightDelegateRoot.width - 8
                                height: rightDelegateRoot.rowHeight
                                // 行背景左右边距均为 4（与左列行一致），右侧不为滚动条留白
                                x: 4
                                radius: RadiusConfig.radius_4_8
                                // 选中态用 hover 底色，靠对勾区分
                                color: (wmRowBg.isSelected || wmRowHover.hovered || wmRowBg.isDownloading)
                                       ? ColorsConfig.color_353738_4DFFC920
                                       : Colors.color_transparent

                                Connections {
                                    target: waterMarkListModel
                                    function onDownloadProgressChanged(slug, progress) {
                                        // 只在下载中置 true；置 false 交给 Ready/Failed，避免极速下载时动画一闪
                                        if (wmRowBg.wm && slug === wmRowBg.wm.slug && progress >= 0 && progress < 1)
                                            wmRowBg.isDownloading = true;
                                    }
                                    function onWatermarkProductReady(slug) {
                                        if (wmRowBg.wm && slug === wmRowBg.wm.slug)
                                            wmRowBg.isDownloading = false;
                                    }
                                    function onWatermarkProductFailed(slug) {
                                        if (wmRowBg.wm && slug === wmRowBg.wm.slug)
                                            wmRowBg.isDownloading = false;
                                    }
                                }

                                // 选中勾（始终保留用于 anchor，未选中时不可见）。
                                // leftMargin 4：行背景左缘 4 + 4 + 勾 SVG 自带约 3.7px 左留白 ≈ 12，
                                // 与右列标题、产品名的 12px 左缘对齐
                                Rectangle {
                                    id: wmRowCheckIcon
                                    width: 20
                                    height: 20
                                    anchors {
                                        left: parent.left
                                        leftMargin: 4
                                        verticalCenter: parent.verticalCenter
                                    }
                                    color: Colors.color_transparent
                                    Image {
                                        visible: wmRowBg.isSelected
                                        anchors.fill: parent
                                        source: "qrc:/app_qrc/icons/icon_compose_check.svg"
                                        sourceSize: Qt.size(parent.width, parent.height)
                                    }
                                }

                                // 本地：16px 高 logo
                                Image {
                                    id: thumb
                                    visible: wmRowBg.isLocal
                                    anchors {
                                        left: wmRowCheckIcon.right
                                        leftMargin: 4
                                        verticalCenter: parent.verticalCenter
                                    }
                                    width:  rightDelegateRoot.imgW
                                    height: rightDelegateRoot.imgH
                                    fillMode: Image.PreserveAspectFit
                                    horizontalAlignment: Image.AlignLeft
                                    asynchronous: true
                                    // 用 C++ 提供的合法 file URL（QUrl::fromLocalFile）
                                    source: wmRowBg.isLocal && wmRowBg.wm && wmRowBg.wm.slug.length > 0
                                            ? waterMarkListModel.getIconUrlBySlug(wmRowBg.wm.slug)
                                            : ""
                                }

                                // 未下载：显示名称文字
                                Text {
                                    id: wmName
                                    visible: !wmRowBg.isLocal
                                             && !wmRowBg.isDownloading
                                             && !!(wmRowBg.wm && wmRowBg.wm.url && wmRowBg.wm.url.length > 0)
                                    anchors {
                                        left: wmRowCheckIcon.right
                                        leftMargin: 4
                                        right: parent.right
                                        rightMargin: 8
                                        verticalCenter: parent.verticalCenter
                                    }
                                    text: wmRowBg.wm ? wmRowBg.wm.name : ""
                                    color: ColorsConfig.color_EEEEEE_4DFFC9
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                    horizontalAlignment: Text.AlignLeft
                                    elide: Text.ElideRight
                                }

                                LightToolTip {
                                    visible: wmRowHover.hovered && wmName.visible
                                             && wmName.implicitWidth > wmName.width
                                    tip: wmName.text
                                    z: 200
                                }

                                // 下载中动画（转圈 Loading → 圆环进度 + 百分比），靠行右缘 4px
                                DownloadAnimation {
                                    width: rightDelegateRoot.imgH
                                    height: rightDelegateRoot.imgH
                                    anchors {
                                        right: parent.right
                                        rightMargin: 4
                                        verticalCenter: parent.verticalCenter
                                    }
                                    active: wmRowBg.isDownloading
                                    progress: wmRowBg.downloadProgress
                                    visible: wmRowBg.isDownloading
                                    z: 2
                                }

                                HoverHandler { id: wmRowHover }

                                MouseArea {
                                    id: cellHover
                                    anchors.fill: parent
                                    onClicked: {
                                        var wm = wmRowBg.wm;
                                        if (!wm || !wm.slug || wm.slug.length === 0) return;
                                        if (wm.slug === waterMarkSetting.appliedSlug) {
                                            waterMarkListPopup.close();
                                            return;
                                        }

                                        control.fixWaterMarkSlug = wm.slug;
                                        control.fixProductIndex  = rightDelegateRoot.delegateProductIdx;
                                        control.curWaterMarkName = rightDelegateRoot.delegateProductName;

                                        if (wmRowBg.isLocal) {
                                            waterMarkSetting.applyWaterMark(wm.slug);
                                            waterMarkListPopup.close();
                                        } else if (wm.url && wm.url.length > 0) {
                                            // 未本地化的云端水印：挂 pending，列表保持打开，
                                            // 下载完成由 onWatermarkProductReady 自动应用并关闭
                                            waterMarkSetting.pendingApplySlug = wm.slug;
                                            waterMarkSetting.pendingCloseAfterApply = wm.slug;
                                            waterMarkListModel.requestDownload(wm.slug);
                                        } else {
                                            globalSignal.toast(qsTr("pccut_cloud_watermark_load_fail_toast"));
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── 位置设置 ────────────────────────────────────────────────────────────────
    Item {
        id: positionSetting
        width: parent.width
        height: waterMarkSetting.isExport ? 28 : 24
        anchors {
            left: parent.left; right: parent.right
            top: nameSetting.bottom; topMargin: waterMarkSetting.isExport ? 16 : 12
        }

        Text {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            height: 15
            color: Colors.color_CCCCCC
            opacity: waterMarkSetting.defaultOpacity
            font.pixelSize: waterMarkSetting.isExport ? 12 : 11
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: qsTr("pccut_watermark_location")
        }

        Rectangle {
            anchors { left: positionComboBox.left; right: positionComboBox.right; verticalCenter: positionComboBox.verticalCenter }
            height: waterMarkSetting.isExport ? 28 : 24
            color: {
                if (positionComboBox.enabled && positionComboBox.hovered && !positionComboBox.down)
                    return waterMarkSetting.isExport ? Colors.color_68696D : Colors.color_37383A;
                return waterMarkSetting.isExport ? Colors.color_454649 : Colors.color_2F3032;
            }
            radius: RadiusConfig.radius_4_8
            opacity: positionComboBox.enabled ? 1 : 0.2
        }

        ComboBox {
            id: positionComboBox
            enabled: checkBox.checked
            anchors {
                top: parent.top; left: parent.left
                leftMargin: waterMarkSetting.isExport ? 63 : 70
                right: parent.right
                verticalCenter: parent.verticalCenter
            }
            height: waterMarkSetting.isExport ? 28 : 24
            textRole: "name"
            model: ListModel {
                ListElement { name: qsTr("pccut_watermark_location_lower_right"); positionType: WaterMarkListModel.RIGHT_DOWN }
                ListElement { name: qsTr("pccut_watermark_upper_right");           positionType: WaterMarkListModel.RIGHT_UP   }
                ListElement { name: qsTr("pccut_watermark_lower_left");            positionType: WaterMarkListModel.LEFT_DOWN  }
                ListElement { name: qsTr("pccut_watermark_upper_left");            positionType: WaterMarkListModel.LEFT_UP    }
                ListElement { name: qsTr("pccut_watermark_bottom");                positionType: WaterMarkListModel.BOTTOM     }
                ListElement { name: qsTr("pccut_watermark_top");                   positionType: WaterMarkListModel.TOP        }
            }

            indicator: Rectangle {
                id: openRect
                anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                width: 20; height: 20
                color: Colors.color_transparent
                property string iconPath: "qrc:/icons/ic_close_triangle.svg"
                Image {
                    anchors.fill: parent
                    source: openRect.iconPath
                    sourceSize: Qt.size(parent.width, parent.height)
                    opacity: positionComboBox.enabled ? 1 : 0.2
                }
                Connections {
                    target: positionComboBox
                    function onDownChanged() {
                        openRect.iconPath = positionComboBox.popup.visible
                            ? "qrc:/icons/ic_open_triangle.svg"
                            : "qrc:/icons/ic_close_triangle.svg";
                    }
                }
            }

            contentItem: Text {
                anchors.left: parent.left
                leftPadding: 8; rightPadding: 28
                text: positionComboBox.displayText
                font.pixelSize: 12
                color: Colors.color_EEEEEE
                opacity: waterMarkSetting.defaultOpacity
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }

            background: Item {}

            Keys.onPressed:  (event) => { event.accepted = true; }
            Keys.onReleased: (event) => { event.accepted = true; }

            popup: WaterMarkPositionSettingPopup {
                id: positionPopup
                y: positionComboBox.height + 4
                x: -positionPopup.width + parent.width
                isExport: waterMarkSetting.isExport
                z: waterMarkSetting.isExport ? 9999 : 0
                parent: parent
                positionModel: positionComboBox.model
                onClickPositionType: (posType) => {
                    currentPositionType = posType;
                    vm.updateWaterMark(posType);
                    if (isExport) refreshCoverImage();
                    else          editorDraftManager.saveDraft();
                }
            }
        }
    }

}
