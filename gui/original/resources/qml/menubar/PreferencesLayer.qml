import QtQuick 2.15
import QtQml 2.15
import QtQuick.Window 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.15
import Controls 1.0
import Config 1.0
import Qt5Compat.GraphicalEffects
import Qt.labs.platform 1.1
import CacheResourceManage 1.0
import CacheCleaner 1.0
import LightRectangle 1.0
import QuickLookSetting 1.0
import app_qrc 1.0
import "../controller"


/**
 * @author xu.lv
 * @desc 偏好设置页面
 * @create_date 2024-07-03
 */
Item {
    id: prefRoot
    // 模态窗口关闭时触发的信号，用于通知上层界面卸载loader资源
    signal destorySource()
    // 模态窗口关闭
    function closeWinowd() {
        mainWindow.visible = false
        destorySource()
    }

    // 打开偏好就尝试扫两个 cleaner，切到「缓存设置」tab 时大小已就位。但要避开正在进行的清理/扫描：
    // - 应急(EmergencyCacheCleaner)在执行 → 不扫，等其结束(onCompleted)再补扫，避免被应急的 cancel-and-forceClean 抢断；
    // - 该 cleaner 自身在扫/在清 → 不扫，已绑定的结束信号会把 currentSize 刷成正确值；
    // - 都空闲 → 扫。
    function scanCacheSizeIfIdle(cleaner) {
        if (!cleaner) return
        if (emergencyCacheCleaner.isRunning()) return          // 等应急结束后由下面 Connections.onCompleted 补扫
        if (cleaner.state !== CacheCleaner.State.Idle) return  // 在扫/在清，绑定的结束信号会刷新，不重复扫
        cleaner.scanSizeAsync()
    }
    // 应急清理是否正在「真清理」中（willClean=true 期间）：用于让删除按钮在应急编排期间统一禁用，
    // 避免用户对暂时 Idle 的 cleaner 点「立即清除」被应急 cancel-and-forceClean 抢断。
    property bool emergencyCleaning: false
    Component.onCompleted: {
        emergencyCleaning = emergencyCacheCleaner.isRunning()  // 兜底：开页时应急已在跑（漏掉 started）
        scanCacheSizeIfIdle(resourceCacheCleaner)
        scanCacheSizeIfIdle(systemCacheCleaner)
        fileOperator.requestAppBaseDriveFreeBytes()
    }
    // 应急清理结束后补扫（开页时应急在跑则两个 cleaner 都跳过了扫描；此处常驻监听，无 check-then-wait 漏信号）
    Connections {
        target: emergencyCacheCleaner
        function onStarted(willClean) {
            prefRoot.emergencyCleaning = willClean  // 都 Off（willClean=false）不禁用，本就不冲突
        }
        function onCompleted(finalFreeBytes, reachedTarget, didExecute) {
            prefRoot.emergencyCleaning = false
            prefRoot.scanCacheSizeIfIdle(resourceCacheCleaner)
            prefRoot.scanCacheSizeIfIdle(systemCacheCleaner)
        }
    }
    // 关闭偏好设置：进行中的 scan/clean 协作取消，不阻塞用户
    Component.onDestruction: {
        prefRoot.isClosing = true
        if (resourceCacheCleaner.state !== CacheCleaner.State.Idle) resourceCacheCleaner.cancel()
        if (systemCacheCleaner.state   !== CacheCleaner.State.Idle) systemCacheCleaner.cancel()
    }
    // 关窗触发的取消清理不应再刷新磁盘警告（区别于页面打开时用户主动清理）
    property bool isClosing: false

    // 点过删除后强制显示 0（部分缓存被占用删不掉，currentSize 会残留）。
    // 提到设置页层级，使其跨 tab 切换不丢失（section 随 Loader 切换销毁重建）。
    property bool resourceCleanedOnce: false
    property bool systemCleanedOnce: false

    // -1 = 未查询/无效；
    property var lowDiskFreeBytes: -1
    readonly property var kLowDiskWarnBytes: 5 * Math.pow(CommonUtils.base_file_number, 3) // 5GB（平台基数）

    Connections {
        target: fileOperator
        function onAppBaseDriveFreeBytesReady(freeBytes) {
            prefRoot.lowDiskFreeBytes = freeBytes
        }
    }

    property int preferencesLayerIndex: 0
    property CacheResourceManage cacheResourceManage: CacheResourceManage {}
    property double cacheSize: cacheResourceManage.cacheSize()

    // 模态窗口的宽高
    property real windowWidth: 468
    property real windowHeight: 444

    property int pathIndex:0
    property string agencyPath:""
    property string projectPath:""
    property string customPath: ""

    function updateCbState(checked) {
        lightSetting.save("needReport", checked);
        var needReport = checked
        logger.d("[PreferencesLayer]: updateCbState() needReport = " + needReport)

        if (needReport) {
            // 打开时： 需要先打开神策数据等，然后在上报
            eventTracker.enable(true)
            eventTracker.trackEvent("pccut_menu_preference_settings_product", {"is_turnon": true})
        } else {
            // 关闭时， 需要先上报关闭埋点，然后再关闭神策
            // eventTracker.trackEvent("pccut_menu_preference_settings_product", {"is_turnon": false})
            eventTracker.enable(false)
        }

        crashTrackHelper.enableUploadEvent(needReport);
    }

    function updateDecodeSetting(checked) {
        lightSetting.save("hardware_decode_on", checked);
        // 同步注入 nle：首次编辑后被拒绝（返回 false），需重开草稿生效；legacy MKSourceBase 下次建源即读新值。
        applicationEnv.setHardwareDecodeEnabled(checked)
    }

    function updateEncodeSetting(checked) {
        lightSetting.save("hardware_encode_on", checked);
    }

    QuickLookSetting {
        id: quicklookSetting
    }

    CustomWindow {
        id: mainWindow
        width: windowWidth
        height: windowHeight
        Shortcut {
            sequence: "Escape"
            context: Qt.WindowShortcut
            onActivated: {
                closeWinowd()
            }
        }

        WindowTitleBar {  // 自定义的标题栏
            id: titleBar
            height: 40
            width: windowWidth
            title: qsTr("pccut_navigation_preference_global_setting_title")
            onCloseClick: {
                closeWinowd();
            }
        }

        Rectangle { // 界面显示部分的容器
            id: content
            anchors {
                top: titleBar.bottom
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                margins: 1
            }
            color: Colors.transparent

            SplitView { // 用来做tabView效果的组件
                anchors.fill: parent
                orientation: Qt.Horizontal

                // 设定SplitView的间距以及背景
                handle: Item {
                    implicitWidth: 0
                }

                LightRectangle { // tab 导航栏
                    id: tabSelector
                    height: parent.height
                    color: Colors.color_1F2021
                    SplitView.preferredWidth: 108
                    radius: [0, 0, 0, 8]

                    ListView {
                        id: tabSelectorList
                        anchors.fill: parent
                        spacing: 12
                        header: Item {
                            height: 18
                        }
                        currentIndex: 0
                        interactive: false
                        model: ListModel {
                            ListElement {txt: qsTr("pccut_menu_advanced_setup"); checked:true}
                            ListElement {txt: qsTr("pccut_menu_path_settings"); checked:false}
                            ListElement {txt: qsTr("pccut_setting_storage_title"); checked:false}
                            ListElement {txt: qsTr("pccut_settings_import_preferences"); checked:false} //导入偏好
                        }
                        Component.onCompleted: {
                            if(CommonUtils.isWindows()){
                                model.append( {txt: qsTr("pccut_navigation_codec_settings"), checked:false})
                                model.append({txt: qsTr("pccut_performance_title"), checked:false})
                            }
                        }
                        onCurrentIndexChanged: {
                            for (var i = 0; i < model.count; i++) {
                                var item = model.get(i);
                                if(i == tabSelectorList.currentIndex){
                                    item.checked = true;
                                }else{
                                    item.checked = false;
                                }
                            }
                            if(tabSelectorList.currentIndex === 0){
                                settingLayer.sourceComponent = cacheComponent
                            }else if(tabSelectorList.currentIndex === 1){
                                settingLayer.sourceComponent = pathSettingComponent
                            }else if(tabSelectorList.currentIndex === 2){
                                settingLayer.sourceComponent = cacheSettingComponent
                            }else if(tabSelectorList.currentIndex === 3){
                                settingLayer.sourceComponent = importPrefComponent
                            }else if(tabSelectorList.currentIndex === 4){
                                settingLayer.sourceComponent = encodeSettingComponent
                            }else if(tabSelectorList.currentIndex === 5){
                                settingLayer.sourceComponent = detectSettingComponent
                            }else{
                                settingLayer.sourceComponent = null
                            }
                        }
                        delegate: Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 92
                            height: 28
                            radius: RadiusConfig.radius_4_88
                            color:{
                                if (checked) {
                                    return Colors.color_2F3032;
                                } else {
                                    return Colors.color_transparent;
                                }
                            }
                            MouseArea {
                                id: tabSelectorListArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    tabSelectorList.currentIndex = index
                                }
                            }
                            HoverableText {
                                cursorChanged: false
                                width: 92 - 24//左右留12
                                noWarp: true
                                lineCount:1
                                anchors.centerIn: parent
                                color: {
                                    if (checked) {
                                        return Colors.color_FFFFFF;
                                    } else {
                                        return Colors.color_999999;
                                    }
                                }
                                onClicked: {
                                    tabSelectorList.currentIndex = index
                                }
                                font.pixelSize: 12
                                text: txt
                            }
                        }
                    }

                }

                Rectangle { // tab 导航页根据 preferencesLayerIndex 的值加载对应的页面
                    id: tabPage
                    SplitView.fillWidth: true
                    height: parent.height
                    color: Colors.transparent
                    Loader {
                        id: settingLayer
                        anchors.fill: parent
                        asynchronous: editorABConfig.asyncLoadComponent
                        sourceComponent: cacheComponent
                    }
                }
            }
        }

        Component { // 缓存清楚页
            id: cacheComponent

            Item {
                //是否为欧盟地区
                property bool isInEURegion: locationManager.isInEURegion

                width: tabPage.width
                height: tabPage.height
                Item{
                    width: parent.width
                    anchors.top: parent.top
                    anchors.left: parent.left
                    Text{
                        id:gaojiTxt
                        anchors.top: parent.top
                        anchors.topMargin: 24
                        anchors.left: parent.left
                        anchors.leftMargin: 28
                        text: qsTr("pccut_menu_advanced")
                        color:Colors.color_EEEEEE
                        font.pixelSize: 12
                    }

                    CheckBox {
                        id: needReportCheckBox
                        checked: lightSetting.getBool("needReport", false) && !isInEURegion
                        anchors.top: gaojiTxt.bottom
                        anchors.topMargin: 4
                        anchors.left: parent.left
                        anchors.leftMargin: 28
                        enabled: isInEURegion ? false : true
                        opacity: isInEURegion ? 0.2 : 1

                        indicator: Rectangle {
                            width: 14
                            height: 14
                            radius: 4
                            anchors.verticalCenter: parent.verticalCenter
                            color: needReportCheckBox.checked ? ColorsConfig.color_brand : Colors.color_444444
                            Image {
                                anchors.fill: parent
                                source: "qrc:/app_qrc/icons/icon_checkbox_check.svg"
                                sourceSize: Qt.size(parent.width, parent.height)
                                visible: needReportCheckBox.checked
                            }
                        }

                        onClicked: {
                            needReportCheckBox.checked = checked
                            updateCbState(checked)
                        }
                    }

                    HoverableText {
                        id:gaojiDSescTxt
                        anchors.top: gaojiTxt.bottom
                        anchors.topMargin: 12
                        anchors.left: parent.left
                        anchors.leftMargin: 48
                        anchors.right: parent.right
                        anchors.rightMargin: 30
                        text: qsTr("pccut_menu_datarecycling")
                        color:Colors.color_EEEEEE
                        font.pixelSize: 11
                        maxTextWidth: parent.width
                        cursorChanged: false
                        noWarp: true
                        lineCount: 1
                        opacity: isInEURegion ? 0.2 : 1
                    }

                    Text{
                        id: permissions
                        anchors.top: gaojiDSescTxt.bottom
                        anchors.topMargin: 8
                        anchors.left: gaojiTxt.left
                        anchors.right: parent.right
                        anchors.rightMargin: 30
                        text: qsTr("pccut_permissions_product_text_7")
                        color:Colors.color_666666
                        font.pixelSize: 11
                        maximumLineCount: 10
                        wrapMode: Text.WordWrap
                    }

                    Text{
                        id:cacheTxt
                        anchors.top: gaojiDSescTxt.bottom
                        anchors.topMargin: 24
                        anchors.left: parent.left
                        anchors.leftMargin: 28
                        text: qsTr("pccut_menu_clearcache_size")
                        color:Colors.color_EEEEEE
                        font.pixelSize: 12
                        visible: false
                    }
                    Text{
                        id: cacheSizeTxt
                        anchors.top: cacheTxt.bottom
                        anchors.topMargin: 16
                        anchors.left: parent.left
                        anchors.leftMargin: 28
                        text: qsTr(cacheSize.toFixed(2)+"MB")
                        color: Colors.color_EEEEEE
                        font.pixelSize: 12
                        visible: false
                    }

                    IconTextButton {
                        id: clearButton
                        alignment: Qt.AlignHCenter
                        isTextOnly: true
                        title: qsTr("pccut_menu_clearcache_clear")
                        width: 72
                        height: 28
                        // enabled: draftManager.currentDraft === -1
                        anchors.top: parent.top
                        anchors.topMargin: 122
                        anchors.right: parent.right
                        anchors.rightMargin: 28
                        backgroundColorNormal: Colors.color_454649
                        backgroundColorHover: Colors.color_56575B
                        backgroundColorDisable: Colors.color_454649
                        visible: false
                        onCustomClicked: {
                            cacheResourceManage.clearCache()
                            cacheSize = cacheResourceManage.cacheSize()
                            globalSignal.refreshMaterialView()
                        }
                    }

                    CheckBox {
                        id: quicklookCheckBox
                        visible: quicklookSetting.installed
                        checked: quicklookSetting.enable
                        enabled: true
                        opacity: 1
                        anchors {
                            top: permissions.bottom
                            topMargin: 4
                            left: parent.left
                            leftMargin: 28
                        }

                        indicator: Rectangle {
                            width: 14
                            height: 14
                            radius: 4
                            anchors.verticalCenter: parent.verticalCenter
                            color: quicklookCheckBox.checked ? ColorsConfig.color_brand : Colors.color_444444
                            Image {
                                anchors.fill: parent
                                source: "qrc:/app_qrc/icons/icon_checkbox_check.svg"
                                sourceSize: Qt.size(parent.width, parent.height)
                                visible: quicklookCheckBox.checked
                            }
                        }

                        onClicked: {
                            quicklookSetting.enable = checked
                        }
                    }

                    HoverableText {
                        id: enableQuicklookTxt
                        visible: quicklookSetting.installed
                        text: qsTr("pccut_quicklook_open_btn")
                        color:Colors.color_EEEEEE
                        font.pixelSize: 11
                        maxTextWidth: parent.width
                        cursorChanged: false
                        noWarp: true
                        lineCount: 1
                        opacity: 1
                        anchors {
                            top: permissions.bottom
                            topMargin: 12
                            left: parent.left
                            leftMargin: 48
                        }
                    }
                }
            }
        }

        // 缓存设置：资源缓存 / 系统缓存 两段；顶部磁盘不足警告
        Component { // 缓存设置
            id: cacheSettingComponent

            Item {
                width: tabPage.width
                height: tabPage.height

                Flickable {
                    id: cacheFlick
                    anchors.fill: parent
                    clip: true
                    contentWidth: width
                    contentHeight: cacheColumn.height + warnBanner.height + 48   // 上下各留 24
                    boundsBehavior: Flickable.StopAtBounds
                    // 内容超出可视区域时显示竖向滚动条（需要时常驻）；样式对齐 MacComposePanel
                    ScrollBar.vertical: ScrollBar {
                        id: cacheScrollBar
                        anchors.right: cacheFlick.right
                        height: cacheFlick.height
                        policy: cacheFlick.contentHeight > cacheFlick.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                        contentItem: Rectangle {
                            implicitWidth: 6
                            radius: 3
                            color: cacheScrollBarArea.containsMouse ? Colors.color_56575B : Colors.color_454649
                            Behavior on color { ColorAnimation { duration: 200 } }
                            MouseArea {
                                id: cacheScrollBarArea
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.NoButton
                            }
                        }
                    }

                    // 磁盘不足警告：显隐时高度平滑上下收缩。
                    Item {
                        id: warnBanner
                        x: 28
                        y: 24
                        width: cacheFlick.width - 56
                        clip: true
                        property bool shown: prefRoot.lowDiskFreeBytes >= 0 && prefRoot.lowDiskFreeBytes < prefRoot.kLowDiskWarnBytes
                        // 展开高度 = 内容 16 + 与下方分段的完整间距 24
                        readonly property int contentHeight: 16 + 24
                        height: shown ? contentHeight : 0
                        visible: height > 0
                        opacity: shown ? 1 : 0
                        Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        Row {
                            width: parent.width
                            spacing: 2
                            Item {
                                width: 14
                                height: 16
                                Image {
                                    x: -2
                                    width: 16
                                    height: 16
                                    fillMode: Image.PreserveAspectFit
                                    sourceSize: Qt.size(32, 32)
                                    smooth: true
                                    source: "qrc:/icons/icon_space_warning_with_margin.svg"
                                }
                            }
                            Text {
                                id: warnText
                                width: parent.width - 14 - 2
                                height: 16
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                                color: Colors.color_3392FF
                                font.pixelSize: 12
                                text: qsTr("pccut_setting_storage_disk_low_notice")
                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.NoButton
                                    LightToolTip { visible: parent.containsMouse && warnText.truncated; tip: warnText.text; z: 200 }
                                }
                            }
                        }
                    }

                    Column {
                        id: cacheColumn
                        x: 28
                        y: 24 + warnBanner.height
                        width: cacheFlick.width - 56
                        spacing: 18

                        Loader {
                            width: parent.width
                            sourceComponent: cacheSectionComponent
                            property var sectionCleaner: resourceCacheCleaner
                            property string sectionTitle: qsTr("pccut_setting_storage_asset_cache_title")
                            property string sectionTip: qsTr("pccut_setting_storage_asset_cache_tooltip")
                            property string sectionDialogTitle: qsTr("pccut_setting_storage_asset_cache_clean_dialog_title")
                            property string sectionDialogDesc: qsTr("pccut_setting_storage_asset_cache_clean_dialog_desc")
                        }
                        // 分割线（上 18 / 下 24）
                        Item {
                            width: parent.width
                            height: 7
                            BaseSpliter {
                                width: parent.width
                                anchors.top: parent.top
                            }
                        }
                        Loader {
                            width: parent.width
                            sourceComponent: cacheSectionComponent
                            property var sectionCleaner: systemCacheCleaner
                            property string sectionTitle: qsTr("pccut_setting_storage_system_cache_title")
                            property string sectionTip: qsTr("pccut_setting_storage_system_cache_tooltip")
                            property string sectionDialogTitle: qsTr("pccut_setting_storage_system_cache_clean_dialog_title")
                            property string sectionDialogDesc: qsTr("pccut_setting_storage_system_cache_clean_dialog_desc")
                        }
                    }
                }
            }
        }

        // 单个缓存设置区（实例化两份）
        Component {
            id: cacheSectionComponent

            Item {
                id: section
                width: parent ? parent.width : 0
                height: childrenRect.height

                property var cleaner: parent && parent.sectionCleaner ? parent.sectionCleaner : null
                property string title: parent && parent.sectionTitle ? parent.sectionTitle : ""
                property string tip: parent && parent.sectionTip ? parent.sectionTip : ""
                property string dialogTitle: parent && parent.sectionDialogTitle ? parent.sectionDialogTitle : ""
                property string dialogDesc: parent && parent.sectionDialogDesc ? parent.sectionDialogDesc : ""
                readonly property int rowGap: 12
                // 标签最大宽度：预留下拉框(224)位置，过长语言在此换行不撑破布局
                readonly property int maxLabelWidth: Math.max(48, width - 224 - rowGap)
                readonly property int contentMaxWidth: Math.max(0, width - mgmtLabel.width - rowGap)
                property int currentMode: cleaner ? cleaner.mode() : CacheCleaner.CleanMode.Off
                // 点过删除后强制显示 0（提到 prefRoot，跨 tab 切换不丢；本地仅做读取代理）
                readonly property bool cleanedOnce: cleaner === resourceCacheCleaner ? prefRoot.resourceCleanedOnce
                                                                                     : prefRoot.systemCleanedOnce
                // 实时进度字节：统计中递增 / 删除中递减；-1 = 无实时值（用 currentSize）
                property double liveBytes: -1

                Connections {
                    target: section.cleaner
                    function onCleanCompleted(freedBytes, err) {
                        if (prefRoot.isClosing) return
                        fileOperator.requestAppBaseDriveFreeBytes()
                    }
                    function onProgress(currentBytes) {
                        section.liveBytes = currentBytes
                    }
                    function onStateChanged() {
                        if (!section.cleaner) return
                        if (section.cleaner.state === CacheCleaner.State.Scanning) section.liveBytes = 0
                        else if (section.cleaner.state === CacheCleaner.State.Cleaning) section.liveBytes = section.cleaner.currentSize
                        else section.liveBytes = -1
                    }
                }

                function formatBytes(bytes) {
                    return CommonUtils.getFileSizeInfo(bytes >= 0 ? bytes : 0, " ")
                }

                // 清理前二次确认弹窗
                ConfirmPopup {
                    id: confirmCleanPopup
                    title: section.dialogTitle
                    text: section.dialogDesc
                    leftButtonText: qsTr("pccut_common_text_cancel")
                    rightButtonText: qsTr("pccut_setting_storage_cache_clean_confirm_btn")
                    onRightButtonClicked: {
                        if (section.cleaner) {
                            if (section.cleaner === resourceCacheCleaner) prefRoot.resourceCleanedOnce = true
                            else prefRoot.systemCleanedOnce = true
                            section.cleaner.forceCleanAsync()
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: 0

                    // xx缓存 标题 + 说明图标
                    Row {
                        width: parent.width
                        spacing: 4
                        Text {
                            id: sectionTitleText
                            width: Math.min(implicitWidth, parent.width - 18)
                            height: 16
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                            text: section.title
                            color: Colors.color_EEEEEE
                            font.pixelSize: 12
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.NoButton
                                LightToolTip { visible: parent.containsMouse && sectionTitleText.truncated; tip: sectionTitleText.text; z: 200 }
                            }
                        }
                        Rectangle {
                            width: 16
                            height: 16
                            color: Colors.color_transparent
                            Image {
                                anchors.fill: parent
                                sourceSize: Qt.size(32, 32)
                                smooth: true
                                source: explainArea.containsMouse ? "qrc:/icons/ic_setting_explain.svg" : "qrc:/icons/ic_setting_explain_hover.svg"
                                MouseArea {
                                    id: explainArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                }
                                LightToolTip {
                                    tip: section.tip
                                    visible: explainArea.containsMouse
                                }
                            }
                        }
                    }

                    // 缓存管理
                    Row {
                        topPadding: 12
                        spacing: section.rowGap
                        Text {
                            id: mgmtLabel
                            width: Math.min(implicitWidth, section.maxLabelWidth)
                            height: 28
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                            text: qsTr("pccut_setting_storage_cache_management_title")
                            color: Colors.color_999999
                            font.pixelSize: 11
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.NoButton
                                LightToolTip { visible: parent.containsMouse && mgmtLabel.truncated; tip: mgmtLabel.text; z: 200 }
                            }
                        }
                        ComboBox {
                            id: modeCombo
                            width: section.contentMaxWidth
                            height: 28
                            textRole: "label"
                            valueRole: "value"
                            model: ListModel {
                                ListElement {label: qsTr("pccut_setting_storage_auto_clean_off_option");     value: 0}   // Off
                                ListElement {label: qsTr("pccut_setting_storage_auto_clean_by_size_option"); value: 3}   // BySize
                                ListElement {label: qsTr("pccut_setting_storage_auto_clean_by_time_option"); value: 1}   // ByAge
                            }
                            background: Rectangle {
                                radius: RadiusConfig.radius_4_8
                                color: modeCombo.hovered ? Colors.color_68696D : Colors.color_454649
                            }
                            contentItem: Text {
                                id: comboDisplay
                                leftPadding: 8
                                rightPadding: modeCombo.indicator.width + 8
                                text: modeCombo.displayText
                                color: Colors.color_FFFFFF
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                horizontalAlignment: Text.AlignLeft
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                                LightToolTip { visible: modeCombo.hovered && comboDisplay.truncated; tip: comboDisplay.text; z: 200 }
                            }
                            indicator: Image {
                                x: modeCombo.width - width - 8
                                y: (modeCombo.height - height) / 2
                                width: 20
                                height: 20
                                sourceSize: Qt.size(40, 40)
                                smooth: true
                                source: modeCombo.popup.visible
                                        ? "qrc:/icons/adjustment/icon_drop_down_menu_collapse.svg"
                                        : "qrc:/icons/adjustment/icon_drop_down_menu_expand.svg"
                            }
                            delegate: ItemDelegate {
                                id: optDelegate
                                width: modeCombo.width - 8
                                height: 28
                                padding: 0
                                contentItem: Item {
                                    Image {
                                        id: checkIcon
                                        anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                                        width: 16
                                        height: 16
                                        sourceSize: Qt.size(32, 32)
                                        smooth: true
                                        source: index === modeCombo.currentIndex ? "qrc:/app_qrc/icons/icon_compose_check.svg" : ""
                                    }
                                    Text {
                                        id: optText
                                        anchors {
                                            left: checkIcon.right; leftMargin: 5
                                            right: parent.right; rightMargin: 8
                                            verticalCenter: parent.verticalCenter
                                        }
                                        text: model.label
                                        color: Colors.color_EEEEEE
                                        font.pixelSize: 11
                                        verticalAlignment: Text.AlignVCenter
                                        elide: Text.ElideRight
                                    }
                                    LightToolTip { visible: optDelegate.hovered && optText.truncated; tip: optText.text; z: 200 }
                                }
                                background: Rectangle {
                                    radius: RadiusConfig.radius_4_8
                                    color: hovered ? Colors.color_FFFFFF_15 : Colors.color_transparent
                                }
                            }
                            popup: Popup {
                                y: modeCombo.height + 4
                                width: modeCombo.width
                                padding: 4
                                enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 100 } }
                                exit:  Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 100 } }
                                contentItem: ListView {
                                    clip: true
                                    implicitHeight: contentHeight
                                    spacing: 4
                                    model: modeCombo.popup.visible ? modeCombo.delegateModel : null
                                    currentIndex: modeCombo.highlightedIndex
                                }
                                background: Rectangle {
                                    radius: RadiusConfig.radius_4_8
                                    color: Colors.color_454649
                                    layer.enabled: true
                                    layer.effect: DropShadow {
                                        horizontalOffset: 0
                                        verticalOffset: 0
                                        radius: 10
                                        color: Colors.color_000000_40
                                        transparentBorder: true
                                    }
                                }
                            }
                            Component.onCompleted: {
                                if (!section.cleaner) return
                                const m = section.cleaner.mode()
                                for (let i = 0; i < model.count; ++i) {
                                    if (model.get(i).value === m) { currentIndex = i; break }
                                }
                                section.currentMode = m
                            }
                            onActivated: {
                                if (!section.cleaner) return
                                const v = model.get(currentIndex).value
                                section.cleaner.setMode(v)
                                section.currentMode = v
                            }
                        }
                    }

                    // 条件输入
                    Item {
                        width: parent.width
                        clip: true
                        property bool shown: section.currentMode === CacheCleaner.CleanMode.BySize
                                             || section.currentMode === CacheCleaner.CleanMode.ByAge
                        height: shown ? (section.currentMode === CacheCleaner.CleanMode.ByAge ? byAgeRow.height : bySizeRow.height) : 0
                        visible: height > 0
                        opacity: shown ? 1 : 0
                        Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        // 按大小：阈值输入
                        Row {
                            id: bySizeRow
                            width: parent.width
                            visible: section.currentMode === CacheCleaner.CleanMode.BySize
                            // 与下拉的间距并入行内（容器收起时一并归零，动画不跳）
                            topPadding: 8
                            leftPadding: mgmtLabel.width + section.rowGap
                            spacing: 8
                            // 带 %s 占位，按 %s 拆分为「前缀 + 输入框 + 后缀」；前缀只去尾、后缀只去头，剥掉译文紧挨 %s 那侧可能多加的空格（间隔已由 spacing 预留）
                            property var descParts: qsTr("pccut_setting_storage_auto_clean_by_size_desc").split("%s").map(function (s, i) { return i === 0 ? s.replace(/\s+$/, "") : s.replace(/^\s+/, "") })
                            Text {
                                id: bySizePrefix
                                height: 24
                                width: Math.min(implicitWidth, section.contentMaxWidth - 64 - bySizeSuffix.width)
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                                visible: text.length > 0
                                text: parent.descParts.length > 0 ? parent.descParts[0] : ""
                                color: Colors.color_EEEEEE
                                font.pixelSize: 12
                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.NoButton
                                    LightToolTip { visible: parent.containsMouse && bySizePrefix.truncated; tip: bySizePrefix.text; z: 200 }
                                }
                            }
                            TextField {
                                id: maxGbInput
                                width: 48
                                height: 24
                                color: Colors.color_EEEEEE
                                font.pixelSize: 12
                                leftPadding: 8
                                rightPadding: 8
                                verticalAlignment: TextInput.AlignVCenter
                                selectByMouse: true
                                maximumLength: 5
                                placeholderTextColor: Colors.color_666666
                                selectedTextColor: Colors.color_2E2E2E
                                selectionColor: Colors.color_EEEEEE
                                background: Rectangle {
                                    color: Colors.color_454649
                                    radius: RadiusConfig.radius_4_8
                                }
                                validator: RegularExpressionValidator { regularExpression: /[0-9]+/ }
                                onTextEdited: {
                                    if (text.length === 0) return
                                    const n = parseInt(text)
                                    if (isNaN(n)) return
                                    if (n > 9999) text = "9999"   // 实时只修正最大，最小留到失焦
                                }
                                function commit() {
                                    if (!section.cleaner) return
                                    const g = Math.pow(CommonUtils.base_file_number, 3)  // 平台基数 GB→字节
                                    if (text.length === 0) {
                                        const cur = section.cleaner.maxBytes()
                                        text = cur > 0 ? Math.round(cur / g).toString() : ""
                                        return
                                    }
                                    let gb = parseInt(text)
                                    if (isNaN(gb)) return
                                    gb = Math.max(1, Math.min(9999, gb))   // clamp 1~9999，超限回写
                                    text = gb.toString()
                                    section.cleaner.setMaxBytes(gb * g)
                                }
                                Component.onCompleted: {
                                    if (!section.cleaner) return
                                    const b = section.cleaner.maxBytes()
                                    text = b > 0 ? Math.round(b / Math.pow(CommonUtils.base_file_number, 3)).toString() : ""
                                }
                                Component.onDestruction: commit()
                                onEditingFinished: commit()
                                // 空文本失焦时 acceptableInput=false 不发 editingFinished，靠失焦兜底
                                onActiveFocusChanged: if (!activeFocus) commit()
                            }
                            Text {
                                id: bySizeSuffix
                                height: 24
                                width: Math.min(implicitWidth, section.contentMaxWidth - 64)
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                                visible: text.length > 0
                                text: parent.descParts.length > 1 ? parent.descParts[1] : ""
                                color: Colors.color_EEEEEE
                                font.pixelSize: 12
                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.NoButton
                                    LightToolTip { visible: parent.containsMouse && bySizeSuffix.truncated; tip: bySizeSuffix.text; z: 200 }
                                }
                            }
                        }
                        // 按时间：天数输入
                        Row {
                            id: byAgeRow
                            width: parent.width
                            visible: section.currentMode === CacheCleaner.CleanMode.ByAge
                            // 与下拉的间距并入行内（容器收起时一并归零，动画不跳）
                            topPadding: 8
                            leftPadding: mgmtLabel.width + section.rowGap
                            spacing: 8
                            // 带 %s 占位，按 %s 拆分为「前缀 + 输入框 + 后缀」；前缀只去尾、后缀只去头，剥掉译文紧挨 %s 那侧可能多加的空格（间隔已由 spacing 预留）
                            property var descParts: qsTr("pccut_setting_storage_auto_clean_by_time_desc").split("%s").map(function (s, i) { return i === 0 ? s.replace(/\s+$/, "") : s.replace(/^\s+/, "") })
                            Text {
                                id: byAgePrefix
                                height: 24
                                width: Math.min(implicitWidth, section.contentMaxWidth - 64 - byAgeSuffix.width)
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                                visible: text.length > 0
                                text: parent.descParts.length > 0 ? parent.descParts[0] : ""
                                color: Colors.color_EEEEEE
                                font.pixelSize: 12
                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.NoButton
                                    LightToolTip { visible: parent.containsMouse && byAgePrefix.truncated; tip: byAgePrefix.text; z: 200 }
                                }
                            }
                            TextField {
                                id: ageDaysInput
                                width: 48
                                height: 24
                                color: Colors.color_EEEEEE
                                font.pixelSize: 12
                                leftPadding: 8
                                rightPadding: 8
                                verticalAlignment: TextInput.AlignVCenter
                                selectByMouse: true
                                maximumLength: 5
                                placeholderTextColor: Colors.color_666666
                                selectedTextColor: Colors.color_2E2E2E
                                selectionColor: Colors.color_EEEEEE
                                background: Rectangle {
                                    color: Colors.color_454649
                                    radius: RadiusConfig.radius_4_8
                                }
                                validator: RegularExpressionValidator { regularExpression: /[0-9]+/ }
                                onTextEdited: {
                                    if (text.length === 0) return
                                    const n = parseInt(text)
                                    if (isNaN(n)) return
                                    if (n > 3650) text = "3650"   // 实时只修正最大，最小留到失焦
                                }
                                function commit() {
                                    if (!section.cleaner) return
                                    if (text.length === 0) {
                                        text = section.cleaner.ageDays().toString()
                                        return
                                    }
                                    let d = parseInt(text)
                                    if (isNaN(d)) return
                                    d = Math.max(1, Math.min(3650, d))   // clamp 1~3650，超限回写
                                    text = d.toString()
                                    section.cleaner.setAgeDays(d)
                                }
                                Component.onCompleted: {
                                    if (section.cleaner) text = section.cleaner.ageDays().toString()
                                }
                                Component.onDestruction: commit()
                                onEditingFinished: commit()
                                // 空文本失焦时 acceptableInput=false 不发 editingFinished，靠失焦兜底
                                onActiveFocusChanged: if (!activeFocus) commit()
                            }
                            Text {
                                id: byAgeSuffix
                                height: 24
                                width: Math.min(implicitWidth, section.contentMaxWidth - 64)
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                                visible: text.length > 0
                                text: parent.descParts.length > 1 ? parent.descParts[1] : ""
                                color: Colors.color_EEEEEE
                                font.pixelSize: 12
                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.NoButton
                                    LightToolTip { visible: parent.containsMouse && byAgeSuffix.truncated; tip: byAgeSuffix.text; z: 200 }
                                }
                            }
                        }
                    }

                    // 缓存大小
                    Row {
                        topPadding: 12
                        spacing: section.rowGap
                        Text {
                            id: sizeLabel
                            width: Math.min(implicitWidth, section.maxLabelWidth)
                            height: 32
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                            text: qsTr("pccut_setting_storage_cache_size_title")
                            color: Colors.color_999999
                            font.pixelSize: 11
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.NoButton
                                LightToolTip { visible: parent.containsMouse && sizeLabel.truncated; tip: sizeLabel.text; z: 200 }
                            }
                        }
                        // 大小值 + 删除按钮（间距 8）
                        Row {
                            spacing: 8
                            Text {
                                id: sizeValue
                                height: 32
                                width: Math.min(implicitWidth, section.contentMaxWidth - 24)
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                                color: Colors.color_999999
                                font.pixelSize: 11
                                text: {
                                    if (!section.cleaner) return ""
                                    var live = section.liveBytes
                                    // 统计中：实时累加（从 0 递增）
                                    if (section.cleaner.state === CacheCleaner.State.Scanning)
                                        return section.formatBytes(live >= 0 ? live : 0)
                                    // 删除中：实时剩余（递减）
                                    if (section.cleaner.state === CacheCleaner.State.Cleaning)
                                        return section.formatBytes(live >= 0 ? live : section.cleaner.currentSize)
                                    // 空闲：点过删除则显 0，否则显示实际容量
                                    return section.cleanedOnce ? section.formatBytes(0) : section.formatBytes(section.cleaner.currentSize)
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.NoButton
                                    LightToolTip { visible: parent.containsMouse && sizeValue.truncated; tip: sizeValue.text; z: 200 }
                                }
                            }
                            Item {
                                width: 16
                                height: 16
                                anchors.verticalCenter: parent.verticalCenter
                                // 统计/删除中、或应急清理编排进行中：禁用并显示加载图标；空闲：可点删除按钮
                                property bool busy: (section.cleaner && section.cleaner.state !== CacheCleaner.State.Idle)
                                                    || prefRoot.emergencyCleaning
                                Image {
                                    id: deleteIcon
                                    anchors.centerIn: parent
                                    width: 16
                                    height: 16
                                    sourceSize: Qt.size(16 * Screen.devicePixelRatio, 16 * Screen.devicePixelRatio)
                                    smooth: true
                                    visible: !parent.busy
                                    opacity: delMouse.containsMouse ? 1.0 : 0.9
                                    source: "qrc:/icons/multiple_delete.svg"
                                }
                                MouseArea {
                                    id: delMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: !parent.busy ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    enabled: !parent.busy
                                    onClicked: {
                                        // 先抢焦让输入框失焦提交，再弹确认框
                                        delMouse.forceActiveFocus()
                                        if (section.cleaner) {
                                            confirmCleanPopup.open()
                                        }
                                    }
                                }
                                // 加载图标：展示时自转，隐藏时停止动画
                                Image {
                                    id: loadingIcon
                                    anchors.centerIn: parent
                                    width: 16
                                    height: 16
                                    sourceSize: Qt.size(32, 32)
                                    smooth: true
                                    visible: parent.busy
                                    source: "qrc:/icons/ic_download_loading@2x.png"
                                    RotationAnimator on rotation {
                                        from: 0
                                        to: 360
                                        duration: 1000
                                        loops: Animation.Infinite
                                        running: loadingIcon.visible
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Component { // 导入偏好
            id: importPrefComponent

            Item {
                width: tabPage.width
                height: tabPage.height
                Item {
                    width: parent.width
                    anchors.top: parent.top
                    anchors.left: parent.left

                    Text {
                        id: importPrefTxt
                        anchors.top: parent.top
                        anchors.topMargin: 24
                        anchors.left: parent.left
                        anchors.leftMargin: 28
                        text: qsTr("pccut_material_import")
                        color: Colors.color_EEEEEE
                        font.pixelSize: 12
                    }

                    CheckBox {
                        id: loopVideoNoRemindCheckBox
                        // 仅当 no_remind=true 且 action="merge" 时才显示选中
                        // 与弹窗"不再提醒"耦合：弹窗点取消会保存 action="unmerge"，此时偏好不应显示为勾选
                        checked: lightSetting.getBool("loop_video_merge_no_remind", false)
                                 && lightSetting.getString("loop_video_merge_action", "") === "merge"
                        anchors.top: importPrefTxt.bottom
                        anchors.topMargin: 4
                        anchors.left: parent.left
                        anchors.leftMargin: 28

                        indicator: Rectangle {
                            width: 14
                            height: 14
                            radius: 4
                            anchors.verticalCenter: parent.verticalCenter
                            color: loopVideoNoRemindCheckBox.checked ? ColorsConfig.color_brand : Colors.color_444444
                            Image {
                                anchors.fill: parent
                                source: "qrc:/app_qrc/icons/icon_checkbox_check.svg"
                                sourceSize: Qt.size(parent.width, parent.height)
                                visible: loopVideoNoRemindCheckBox.checked
                            }
                        }

                        onClicked: {
                            lightSetting.save("loop_video_merge_no_remind", checked)
                            // 勾选 → 直接合并（同时写入 action，避免 preference.isEmpty() 仍弹窗）
                            // 取消勾选 → 清空 action，下次导入重新弹窗询问
                            lightSetting.save("loop_video_merge_action", checked ? "merge" : "")
                        }
                    }

                    HoverableText {
                        anchors.top: importPrefTxt.bottom
                        anchors.topMargin: 12
                        anchors.left: parent.left
                        anchors.leftMargin: 48
                        anchors.right: parent.right
                        anchors.rightMargin: 30
                        text: qsTr("pccut_material_merge_display")//循环录影视频导入时不再提醒弹窗
                        color: Colors.color_EEEEEE
                        font.pixelSize: 11
                        maxTextWidth: parent.width
                        cursorChanged: false
                        noWarp: true
                        lineCount: 1
                    }
                }
            }
        }

        Component { // 硬件加速页面
            id: pathSettingComponent
            Item {
                width: tabPage.width
                height: tabPage.height
                Item{
                    id: moviePathItem
                    height: 56
                    anchors.top: parent.top
                    anchors.topMargin: 24
                    anchors.left: parent.left
                    anchors.leftMargin: 28
                    anchors.right: parent.right
                    anchors.rightMargin: 28
                    visible: false
                    Text {
                        id: moviesPathTxt
                        text: qsTr("pccut_menu_path_media")
                        anchors.top: parent.top
                        anchors.left: parent.left
                        font.pixelSize: 12
                        color:Colors.color_EEEEEE

                    }
                    Rectangle {
                        anchors {
                            left: parent.left
                            top: moviesPathTxt.bottom
                            topMargin: 12
                        }
                        width: 224
                        height: 28
                        color: Colors.color_454649
                        radius: 4
                        Text {
                            id: moviesPath
                            anchors {
                                left: parent.left
                                leftMargin: 8
                                top: parent.top
                                right: parent.right
                                rightMargin: 8
                                bottom: parent.bottom
                            }
                            // 省略号
                            elide: Text.ElideMiddle
                            horizontalAlignment: Text.AlignLeft
                            verticalAlignment: Text.AlignVCenter
                            color: Colors.color_EEEEEE
                            font.pixelSize: 12
                            text: ""
                        }
                    }
                    IconTextButton {
                        id: openMediaPathButton
                        alignment: Qt.AlignHCenter
                        isTextOnly: true
                        title: qsTr("pccut_menu_path_media_open")
                        width: 72
                        height: 28
                        anchors.top: moviesPathTxt.bottom
                        anchors.topMargin: 12
                        anchors.right: parent.right
                        leftPadding: 8
                        rightPadding: 8
                        backgroundColorNormal: Colors.color_454649
                        backgroundColorHover: Colors.color_56575B
                        onCustomClicked: {
                            // pathIndex = 0
                            // pathDialog.open()
                        }
                    }
                }
                Item{
                    id: projectPathItem
                    height: 56
                    anchors.top: parent.top
                    anchors.topMargin: 24
                    anchors.left: parent.left
                    anchors.leftMargin: 28
                    anchors.right: parent.right
                    anchors.rightMargin: 28
                    Text {
                        id: projectPathTxt
                        text: qsTr("pccut_menu_path_project")
                        anchors.top: parent.top
                        anchors.left: parent.left
                        font.pixelSize: 12
                        color:Colors.color_EEEEEE

                    }
                    Rectangle {
                        anchors {
                            left: parent.left
                            top: projectPathTxt.bottom
                            topMargin: 12
                        }
                        width: 224
                        height: 28
                        color: mouseArea.containsMouse ? Colors.color_56575B : Colors.color_454649
                        radius: RadiusConfig.radius_4_8
                        MouseArea {
                            id: mouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                fileOperator.openExplorerAtFile(cacheResourceManage.projectPath())
                            }
                        }
                        Text {
                            id: projectPath
                            anchors {
                                left: parent.left
                                leftMargin: 8
                                top: parent.top
                                right: parent.right
                                rightMargin: 8
                                bottom: parent.bottom
                            }
                            // 省略号
                            elide: Text.ElideMiddle
                            horizontalAlignment: Text.AlignLeft
                            verticalAlignment: Text.AlignVCenter
                            color: Colors.color_EEEEEE
                            font.pixelSize: 11
                            text: qsTr(cacheResourceManage.projectPath())
                        }
                    }

                    IconTextButton {
                        id: openProjectPathButton
                        titleFontSize: 11
                        alignment: Qt.AlignHCenter
                        isTextOnly: true
                        title: qsTr("pccut_project_modify")
                        width: 72
                        height: 28
                        anchors.top: projectPathTxt.bottom
                        anchors.topMargin: 12
                        anchors.right: parent.right
                        backgroundColorNormal: Colors.color_454649
                        backgroundColorHover: Colors.color_56575B
                        leftPadding: 8
                        rightPadding: 8
                        radius: RadiusConfig.radius_4_8
                        onCustomClicked: {
                            // pathIndex = 1
                            // pathDialog.open()
                            pathDialog.open()
                        }
                    }

                    Connections{
                        target: pathDialog
                        function onChangeProjectPath(path){
                                projectPath.text = path
                        }
                    }
                }
                Item{
                    id: downloadPathItem
                    height: 56
                    anchors.top: projectPathItem.bottom
                    anchors.topMargin: 28
                    anchors.left: parent.left
                    anchors.leftMargin: 28
                    anchors.right: parent.right
                    anchors.rightMargin: 28
                    Text {
                        id: downloadPathTxt
                        text: qsTr("pccut_menu_path_download")
                        anchors.top: parent.top
                        anchors.left: parent.left
                        font.pixelSize: 12
                        color: Colors.color_EEEEEE
                    }
                    Rectangle {
                        anchors {
                            left: parent.left
                            top: downloadPathTxt.bottom
                            topMargin: 12
                        }
                        width: 224
                        height: 28
                        color: downloadPathMouseArea.containsMouse ? Colors.color_56575B : Colors.color_454649
                        radius: RadiusConfig.radius_4_8
                        MouseArea {
                            id: downloadPathMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                fileOperator.openExplorerAtFile(cacheResourceManage.downloadPath())
                            }
                        }
                        Text {
                            id: downloadPath
                            anchors {
                                left: parent.left
                                leftMargin: 8
                                top: parent.top
                                right: parent.right
                                rightMargin: 8
                                bottom: parent.bottom
                            }
                            elide: Text.ElideMiddle
                            horizontalAlignment: Text.AlignLeft
                            verticalAlignment: Text.AlignVCenter
                            color: Colors.color_EEEEEE
                            font.pixelSize: 12
                            text: qsTr(cacheResourceManage.downloadPath())
                        }
                    }

                    IconTextButton {
                        id: openDownloadPathButton
                        alignment: Qt.AlignHCenter
                        isTextOnly: true
                        title: qsTr("pccut_project_modify")
                        width: 72
                        height: 28
                        anchors.top: downloadPathTxt.bottom
                        anchors.topMargin: 12
                        anchors.right: parent.right
                        backgroundColorNormal: Colors.color_454649
                        backgroundColorHover: Colors.color_56575B
                        leftPadding: 8
                        rightPadding: 8
                        radius: RadiusConfig.radius_4_8
                        onCustomClicked: {
                            downloadPathDialog.open()
                        }
                    }

                    Connections {
                        target: downloadPathDialog
                        function onChangeDownloadPath(path) {
                            downloadPath.text = path
                        }
                    }
                }
                Item{
                    id: screenshotItem
                    height: 112
                    anchors.top: projectPathItem.bottom
                    anchors.topMargin: 28
                    anchors.left: parent.left
                    anchors.leftMargin: 28
                    anchors.right: parent.right
                    anchors.rightMargin: 28
                    visible: false
                    Text {
                        id: screenshotPathTxt
                        text: qsTr("pccut_menu_path_snapshot")
                        anchors.top: parent.top
                        anchors.left: parent.left
                        font.pixelSize: 12
                        color:Colors.color_EEEEEE
                    }
                    CheckBox {
                        id: currentPathCheckBox
                        text: qsTr("pccut_menu_path_snapshot_current")
                        height: 18
                        anchors.top: screenshotPathTxt.bottom
                        anchors.topMargin: 12
                        checked: true
                        indicator: Rectangle {
                            implicitWidth: 16
                            implicitHeight: 16
                            anchors.left: currentPathCheckBox.left
                            anchors.verticalCenter: parent.verticalCenter
                            color:  Colors.color_transparent
                            radius: 8
                            Image {
                                visible: true
                                anchors.fill: parent
                                source: currentPathCheckBox.checked?"qrc:/icons/icon_radio_button.svg":"qrc:/icons/icon_radio_button_no.svg"
                                sourceSize: Qt.size(parent.width, parent.height)
                            }
                        }
                        MouseArea {
                            anchors.fill: currentPathCheckBox
                            onClicked: {
                                if(currentPathCheckBox.checked){
                                    return;
                                }else{
                                    currentPathCheckBox.checked = true;
                                    cutstomPathCheckBox.checked = false;
                                }
                            }
                        }
                        contentItem: Text {
                            text: currentPathCheckBox.text
                            font.pixelSize: 12
                            color: Colors.color_999999
                            verticalAlignment: Text.AlignVCenter
                            leftPadding: currentPathCheckBox.indicator.width
                        }
                    }

                    CheckBox {
                        id:cutstomPathCheckBox
                        text: qsTr("pccut_menu_path_snapshot_custom")
                        anchors.top: currentPathCheckBox.bottom
                        anchors.topMargin: 12
                        height: 18
                        checked: false
                        indicator: Rectangle {
                            implicitWidth: 16
                            implicitHeight: 16
                            anchors.left: cutstomPathCheckBox.left
                            anchors.verticalCenter: parent.verticalCenter
                            color:  Colors.color_transparent
                            radius: 8
                            Image {
                                visible: true
                                anchors.fill: parent
                                source:cutstomPathCheckBox.checked?"qrc:/icons/icon_radio_button.svg":"qrc:/icons/icon_radio_button_no.svg"
                                sourceSize: Qt.size(parent.width, parent.height)
                            }
                        }
                        MouseArea {
                            anchors.fill: cutstomPathCheckBox
                            onClicked: {
                                if(cutstomPathCheckBox.checked){
                                    return;
                                }else{
                                    currentPathCheckBox.checked = false;
                                    cutstomPathCheckBox.checked = true;
                                }
                            }
                        }
                        contentItem: Text {
                            text: cutstomPathCheckBox.text
                            font.pixelSize: 12
                            color: Colors.color_999999
                            verticalAlignment: Text.AlignVCenter
                            leftPadding: cutstomPathCheckBox.indicator.width
                        }
                    }

                    Rectangle {
                        anchors {
                            left: parent.left
                            top: cutstomPathCheckBox.bottom
                            topMargin: 12
                        }
                        width: 224
                        height: 28
                        color: Colors.color_454649
                        radius: 4
                        Text {
                            id: screenshotPath
                            anchors {
                                left: parent.left
                                leftMargin: 8
                                top: parent.top
                                right: parent.right
                                rightMargin: 8
                                bottom: parent.bottom
                            }
                            // 省略号
                            elide: Text.ElideMiddle
                            horizontalAlignment: Text.AlignLeft
                            verticalAlignment: Text.AlignVCenter
                            color: Colors.color_EEEEEE
                            font.pixelSize: 12
                            text: qsTr(cacheResourceManage.projectPath())
                        }

                        // Connections{
                        //     target: radioGroup
                        //     function onItemSelect(index){
                        //         if(index === 0){
                        //             screenshotPath.title = screenShot.getAvailablePath(lightSetting.get(Instance.key_screen_shot_save_path))
                        //         }else{
                        //             screenshotPath.title = customPath
                        //         }
                        //     }
                        // }
                        Connections{
                            target: pathDialog
                            function onChangeCustomPath(path){
                                screenshotPath.title = path
                            }
                        }
                    }

                    IconTextButton {
                        id: openscreenshotButton
                        alignment: Qt.AlignHCenter
                        isTextOnly: true
                        title: qsTr("pccut_menu_path_media_open")
                        width: 72
                        height: 28
                        anchors.top: cutstomPathCheckBox.bottom
                        anchors.topMargin: 12
                        anchors.right: parent.right
                        backgroundColorNormal: Colors.color_454649
                        backgroundColorHover: Colors.color_56575B
                        backgroundColorDisable: Colors.color_454649
                        leftPadding: 8
                        rightPadding: 8
                        onCustomClicked: {
                            // pathIndex = 2
                            // pathDialog.open()
                        }
                    }
                }
            }
        }

        Component { // 硬件编解码设置
            id: encodeSettingComponent

            Item {
                width: tabPage.width
                height: tabPage.height
                Item{
                    width: parent.width
                    anchors.top: parent.top
                    anchors.left: parent.left
                    Text{
                        id: descTxt
                        anchors.top: parent.top
                        anchors.topMargin: 24
                        anchors.left: parent.left
                        anchors.leftMargin: 28
                        text: qsTr("pccut_navigation_codec_settings") + ": "
                        color:Colors.color_EEEEEE
                        font.pixelSize: 12
                    }

                    CheckBox {
                        id: decodeSettingCheck
                        checked: lightSetting.getBool("hardware_decode_on", true) // 默认选中
                        anchors.top: descTxt.bottom
                        anchors.topMargin: 4
                        anchors.left: parent.left
                        anchors.leftMargin: 28

                        indicator: Rectangle {
                            width: 14
                            height: 14
                            radius: 4
                            anchors.verticalCenter: parent.verticalCenter
                            color: decodeSettingCheck.checked ? ColorsConfig.color_brand : Colors.color_444444
                            Image {
                                anchors.fill: parent
                                source: "qrc:/app_qrc/icons/icon_checkbox_check.svg"
                                sourceSize: Qt.size(parent.width, parent.height)
                                visible: decodeSettingCheck.checked
                            }
                        }

                        onClicked: {
                            decodeSettingCheck.checked = checked
                            updateDecodeSetting(checked)
                        }
                    }

                    Text{
                        id:decodeSettingDescTxt
                        anchors.top: descTxt.bottom
                        anchors.topMargin: 10
                        anchors.left: parent.left
                        anchors.leftMargin: 48
                        text: qsTr("pccut_navigation_codec_decoding")
                        color:Colors.color_EEEEEE
                        font.pixelSize: 11
                    }

                    Rectangle {
                        width: 16
                        height: 16

                        anchors {
                            left: decodeSettingDescTxt.right
                            leftMargin: 4
                            top: decodeSettingDescTxt.top
                            //topMargin: 1
                        }

                        color: Colors.color_transparent

                        Image {
                            id: icon1
                            anchors.fill: parent
                            sourceSize: Qt.size(32, 32)
                            source: mouseArea1.containsMouse ? "qrc:/icons/ic_setting_explain.svg" : "qrc:/icons/ic_setting_explain_hover.svg"

                            MouseArea {
                                id: mouseArea1
                                anchors.fill: parent
                                hoverEnabled: true
                            }

                            LightToolTip {
                                id: tip1
                                tip: qsTr("pccut_navigation_codec_decoding_toast")
                                visible: mouseArea1.containsMouse
                            }
                        }
                    }

                    CheckBox {
                        id: encodeSettingCheck
                        checked: lightSetting.getBool("hardware_encode_on", true) // 默认选中
                        anchors.top: decodeSettingDescTxt.bottom
                        anchors.topMargin: 4
                        anchors.left: parent.left
                        anchors.leftMargin: 28

                        indicator: Rectangle {
                            width: 14
                            height: 14
                            radius: 4
                            anchors.verticalCenter: parent.verticalCenter
                            color: encodeSettingCheck.checked ? ColorsConfig.color_brand : Colors.color_444444
                            Image {
                                anchors.fill: parent
                                source: "qrc:/app_qrc/icons/icon_checkbox_check.svg"
                                sourceSize: Qt.size(parent.width, parent.height)
                                visible: encodeSettingCheck.checked
                            }
                        }

                        onClicked: {
                            encodeSettingCheck.checked = checked
                            updateEncodeSetting(checked)
                        }
                    }

                    Text{
                        id:encodeSettingDescTxt
                        anchors.top: decodeSettingDescTxt.bottom
                        anchors.topMargin: 10
                        anchors.left: parent.left
                        anchors.leftMargin: 48
                        text: qsTr("pccut_navigation_codec_encoding")
                        color:Colors.color_EEEEEE
                        font.pixelSize: 11
                    }

                    Rectangle {
                        width: 16
                        height: 16

                        anchors {
                            left: encodeSettingDescTxt.right
                            leftMargin: 4
                            top: encodeSettingDescTxt.top
                            //topMargin: 1
                        }

                        color: Colors.color_transparent

                        Image {
                            id: icon2
                            anchors.fill: parent
                            sourceSize: Qt.size(32, 32)
                            source: mouseArea2.containsMouse ? "qrc:/icons/ic_setting_explain.svg" : "qrc:/icons/ic_setting_explain_hover.svg"

                            MouseArea {
                                id: mouseArea2
                                anchors.fill: parent
                                hoverEnabled: true
                            }

                            LightToolTip {
                                id: tip2
                                tip: qsTr("pccut_navigation_codec_encoding_toast")
                                visible: mouseArea2.containsMouse
                            }
                        }
                    }
                }
            }
        }

        Component {//环境检测
            id: detectSettingComponent
            Item {
                Text {
                    id: detectTxt
                    anchors.top: parent.top
                    anchors.topMargin: 24
                    anchors.left: parent.left
                    anchors.leftMargin: 28
                    font.pixelSize: 12
                    text: qsTr("pccut_performance_title")+":"
                    color: Colors.color_EEEEEE
                }
                Text {
                    id: detectDescTxt
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    text: qsTr("pccut_menu_advanced_performance_tip")
                    width: 304
                    anchors {
                        top: detectTxt.bottom
                        topMargin: 12
                        left: parent.left
                        leftMargin: 28
                    }
                    wrapMode: Text.WordWrap
                    color: Colors.color_EEEEEE
                }
                IconTextButton {
                    id: startDetectButton
                    alignment: Qt.AlignHCenter
                    isTextOnly: true
                    title: qsTr("pccut_menu_advanced_performance_again")
                    width: 72
                    height: 28
                    anchors {
                        top: detectDescTxt.bottom
                        topMargin: 12
                        right: parent.right
                        rightMargin: 28
                    }
                    backgroundColorNormal: Colors.color_454649
                    backgroundColorHover: Colors.color_56575B
                    onCustomClicked: {
                        detectPopup.open()
                    }
                }
            }
        }

        FolderDialog {
            signal changeCustomPath(var customPath)
            signal changeProjectPath(var projectPath)
            id: pathDialog
            currentFolder: cacheResourceManage.pathToQmlUrl(cacheResourceManage.projectPath())
            options: FolderDialog.ShowDirsOnly
            onAccepted: {
                var folderPath = cacheResourceManage.normalizePath(folder.toString())     
                cacheResourceManage.setProjectPath(folderPath)
                changeProjectPath(folderPath)
            }
        }
        //重新检测
        ConfirmPopup {
            id: detectPopup
            parent: mainWindow.contentItem  // 明确挂到 CustomWindow 内
            // width/height 也要改成相对 mainWindow 的值
            width: mainWindow.width
            height: mainWindow.height
            customTitleHeight: 36
            title: qsTr("pccut_menu_advanced_performance_again_tip")
            leftButtonText: qsTr("pccut_draft_delete_popup_cancel")
            rightButtonText: qsTr("pccut_menu_reboot_yes")
            onRightButtonClicked: {
                lightSetting.save("detect_retry_count", 0)
                lightSetting.save("startDetect", true)
                globalSignal.restart()
            }
        }        
        FolderDialog {
            signal changeDownloadPath(var downloadPath)
            id: downloadPathDialog
            currentFolder: cacheResourceManage.pathToQmlUrl(cacheResourceManage.downloadPath())
            options: FolderDialog.ShowDirsOnly
            onAccepted: {
                var folderPath = cacheResourceManage.normalizePath(folder.toString())
                cacheResourceManage.setDownloadPath(folderPath)
                changeDownloadPath(folderPath)
            }
        }
    }
}
