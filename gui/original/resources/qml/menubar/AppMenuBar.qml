import QtQuick 2.15
import Qt.labs.platform 1.1
import TrackingManager 1.0
import ShortcutAction 1.0
import QtQuick.Dialogs
import LogManager 1.0
import MediaListViewModel 1.0
import QmlConstants 1.0
import UsedFunctionManager 1.0
import ProjectSettingsInfo 1.0
import Nova 1.0
import Config 1.0
import AppBarViewModel 1.0
import CloudAlbumManager 1.0
/**
 * @author xu.lv
 * @desc mac系统菜单栏
 * @create_date 2024-07-03
 */
MenuBar {
    id: menubar
    // 菜单栏点击信号，page为哪个菜单，item为哪一项

    AppBarViewModel {
        id: appBarViewModel
    }

    signal itemClicked(int page, int item)
    property bool isAvailable: true

    function popupAndProhibit(page,item){
        itemClicked(page,item);
        isAvailable = false;
    }

    Connections {
        target: globalSignal
        function onEnableMenuBar(enable) {
            if(editorManager.isInUserGuideStatus && enable){ // 用户指引过程中，禁止enable
                return;
            }
            isAvailable = enable;
            systemMenu.enabled = isAvailable
            file.enabled = isAvailable
            edit.enabled = isAvailable
            menuPreferences.enabled = isAvailable
            help.enabled = isAvailable
        }

        function onTrackingStateChanged(status){
            if (status === TrackingManager.TK_ENTER) {
                systemMenu.enabled = false
                isAvailable = false
            } else if(status === TrackingManager.TK_EXIT){
                systemMenu.enabled = true
                isAvailable = true
            }
        }

        function onUpdateLanguageCode(code) {
            macMenuBarLayers.showLanguagePop(code);
        }
    }

    // Qt.labs.platform 1.1 提供的跨平台菜单功能，Menu类的子项MenuItem声明
    // 顺序跟mac系统菜单栏展示是反的，如下“关于”会排在“偏好设置”上面
    Menu { // 系统栏 page 0

        id: systemMenu
        onAboutToShow: {
            // 在菜单即将显示时进行动态判断
            systemMenu.enabled = isAvailable
        }
        // 退出
        MenuItem {
            role: MenuItem.ApplicationSpecificRole
            text: qsTr("pccut_menu_exit")
            shortcut: "Ctrl+Q"
            onTriggered: {
                globalSignal.quitApp();
            }
        }
        MenuItem {// 检测更新 item 2
            id: menuUpdate
            role: MenuItem.ApplicationSpecificRole
            text: qsTr("pccut_menu_updates")
            onTriggered: {
                itemClicked(0, 2)
            }
        }

        MenuItem { // 关于 item 0
            id: menuAbout
            role: MenuItem.ApplicationSpecificRole
            text: qsTr("pccut_menu_about")
            onTriggered: {
                popupAndProhibit(0,0)
            }
        }
        // 主要是系统会有多语言, 和我们的会有区别, 所以隐藏系统的
        MenuItem {
            id: menuQuit
            role: MenuItem.QuitRole
            visible: false
            onTriggered: {
                // TODO: yahui.li 这里应该跟系统的退出区分开，如果快捷键和系统的一致，就不注册监听，如果不一致
                // 就加个自定义的监听，而不是监听MenuItem.QuitRole
                globalSignal.quitApp();
            }
        }
    }

    // 不实用MenuItem的role属性的菜单条目会按照正常的声明顺序，如“仅供展示 1” 会在 “仅供展示 2”上面
    Menu { // 文件栏 page 1
        id: file
        title: qsTr("pccut_menu_file");
        MenuItem {
            text: qsTr("pccut_menu_create")
            shortcut: "Ctrl+N"
            enabled: isAvailable
            onTriggered: {
                    //draftManager.addNewDraft()
                    // 传 windowScoped=false：mac 系统菜单栏在独立子窗口（偏好设置/关于等）
                    // 聚焦时仍可点击，若走默认窗口隔离会因 focusWindow=子窗口而被静默拦截。
                    ShortcutObserver.shortcutActivated(ShortcutAction.NEW_PROJECT,"newProject", false)
            }
        }

        MenuItem {
            text: qsTr("pccut_menu_import")
            shortcut: "Ctrl+I"
            enabled: isAvailable && (draftManager.currentDraft !== -1)
            onTriggered: {
                globalSignal.setImportOperationType(MediaListViewModel.Menubar)
                ShortcutObserver.shortcutActivated(ShortcutAction.IMPORT,"import", false)
            }
        }

        MenuItem {
            id: exportMenuItem
            text: qsTr("pccut_menu_export")
            shortcut: ShortcutConfig.actionString(ShortcutAction.EXPORT)
            enabled: isAvailable && (draftManager.currentDraft !== -1)
            onTriggered: {
                ShortcutObserver.shortcutActivated(ShortcutAction.EXPORT,"export", false)
            }
        }
        Connections {
            target: ShortcutConfig
            function onShortcutsChanged() {
                exportMenuItem.shortcut = ""
                exportMenuItem.shortcut = ShortcutConfig.actionString(ShortcutAction.EXPORT)
            }
        }
    }
    Menu { // 编辑栏 page 2
        id: edit
        title: qsTr("pccut_menu_edit")
        onAboutToShow: {
            // 在菜单即将显示时进行动态判断
            undo.enabled = UndoController.canUndo && (draftManager.currentDraft !== -1)
            redo.enabled = UndoController.canRedo && (draftManager.currentDraft !== -1)
        }
        enabled: isAvailable
        MenuItem {
            id:undo
            text: qsTr("pccut_menu_undo")
            shortcut: "Ctrl+Z"
            onTriggered: {
                ShortcutObserver.shortcutActivated(ShortcutAction.UN_DO,"Undo", false)
                eventTracker.trackEvent("pccut_undo_click", {"use_method": "shortcut"})
                var projectId = draftManager.activeProjectEnvId();
                UsedFunctionManager.undo(projectId)
            }
        }
        MenuItem {
            id:redo
            text: qsTr("pccut_menu_redo")
            shortcut: "Ctrl+Shift+Z"
            onTriggered: {
                ShortcutObserver.shortcutActivated(ShortcutAction.RE_DO,"Redo", false)
                eventTracker.trackEvent("pccut_redo_click", {"use_method": "shortcut"})
                var projectId = draftManager.activeProjectEnvId();
                UsedFunctionManager.redo(projectId)
            }
        }
        // 添加一个空的MenuItem来避免填充
    }
    Menu { // 偏好设置栏 page 3
        // 说明：偏好设置作为顶级菜单，含 4 个子项：全局设置 / 项目设置 / 快捷键 / 语言。
        // 原本尝试嵌套在 systemMenu(mac 应用菜单) 内，但无 role 的嵌套 Menu 不会被 Qt.labs.platform
        // 分派到原生应用菜单槽位（应用菜单只识别带 role 的 MenuItem），会导致整块偏好设置菜单不显示。
        // 提升为顶级 Menu 后正常显示；仍复用 page=3 保持与 MenuBarPopupLayers 的路由约定。
        id: menuPreferences
        title: qsTr("pccut_menu_preference_settings")
        onAboutToShow:{
            menuPreferences.enabled = isAvailable
            // 语言子菜单沿用原生 Cocoa 实现（QML 展开式子菜单在 mac 原生菜单栏反复点击会“卡死”），
            // 挂载目标随之从原"设置"菜单迁移到本"偏好设置"菜单，实际的挂载查找在
            // src_MacOS/open_material/MaterialOpenOperatorMacOS.mm 中按 pccut_menu_preference_settings 定位。
            globalSignal.setupLanguageMenu(isAvailable);
        }
        MenuItem { // 全局设置（打开原偏好设置窗口）
            text: qsTr("pccut_navigation_preference_global_setting_title")
            onTriggered: {
                popupAndProhibit(0, 1)
            }
        }
        MenuItem { // 项目设置（打开项目设置弹窗）
            text: qsTr("pccut_project_modify_settings")
            // 依赖 SettingPanel（仅编辑器页存在）+ 已打开草稿，无草稿时置灰。
            // 不手动置 isAvailable：弹窗生命周期（LightPopup.onClosed→enableMenuBar(true)）负责恢复，
            // 与 Windows(AppBar) 范式一致。
            enabled: isAvailable && (draftManager.currentDraft !== -1)
            onTriggered: {
                editorManager.pause();
                globalSignal.clickProxySuggestPopup();
            }
        }
        MenuItem { // 快捷键（迁移自设置）
            text: qsTr("pccut_shortcut")
            onTriggered: {
                popupAndProhibit(3, 2)
            }
        }
        // 第 4 项"语言"在下拉打开时由原生代码追加到菜单末尾，见 onAboutToShow。
    }

    Menu { // 帮助栏 page 4
        id: help
        title: qsTr("pccut_menu_help");
        onAboutToShow: {
            // 在菜单即将显示时进行动态判断
            enabled = isAvailable
        }
        MenuItem {
            text: qsTr("pccut_menu_help")
            onTriggered: {
                Qt.openUrlExternally(QmlConstants.officicalWebHelp())
            }
        }
        MenuItem {
            text: qsTr("pccut_menu_feedback")
            onTriggered: {
                globalSignal.showUserFeedback()
            }
        }
        MenuItem {
            text: qsTr("pccut_menu_download_pr")
            visible: !QmlConstants.isWhiteXtra()
            onTriggered: {
                Qt.openUrlExternally(QmlConstants.prPluginWebsite())
            }
        }
        MenuItem {
            text: qsTr("pccut_guide_quick")
            onTriggered: {
                draftManager.addNewDraft();
                globalSignal.openUserGuide();
                // globalSignal.enableMenuBar(false);
                // editorManager.isInUserGuideStatus = true;
            }
        }
        MenuItem {
            text: qsTr("pccut_guide_tutorial")
            onTriggered: {
                    Qt.openUrlExternally(QmlConstants.officialWebTutorial())
            }
        }
        MenuItem {
            text: qsTr("pccut_account_delete_title")
            // visible: userLoginViewModel.isLoggedIn
            enabled: userLoginViewModel.isLoggedIn
            onTriggered: {
                userLoginViewModel.deleteAccount();
                userLoginViewModel.reportAccountDelete("top_menu");
            }
        }
    }

    Menu { // debug
        id: debug
        visible: !fileOperator.isRelease()
        title: "DEBUG"

        LogManager {
            id: logManager
        }

        MenuItem {
            text: "[DEBUG] 打开数据存储文件夹"
            enabled: true
            onTriggered: {
                fileOperator.openAppDataFile();
            }
        }

        MenuItem {
            text: "[DEBUG] 打开此次执行log"
            enabled: true
            onTriggered: {
                fileOperator.openLogPath();
            }
        }
        MenuItem {
            text: "[DEBUG] 打开此次底层执行log"
            onTriggered: {
                fileOperator.openMKLogPath();
            }
        }
        MenuItem {
            text: "[DEBUG] 打开日志入口"
            enabled: true
            onTriggered: {
                logManager.collect();
                fileOperator.openExportLogPath();
            }
        }

        Menu {
            title: "[DEBUG] 模拟崩溃"
            enabled: true

            MenuItem {
                text: "[Bugly] 空指针崩溃"
                enabled: true
                onTriggered: {
                    fileOperator.testCrashNullPointer();
                }
            }
            MenuItem {
                text: "[Bugly] 栈溢出崩溃"
                enabled: true
                onTriggered: {
                    fileOperator.testCrashStackOverflow();
                }
            }
            MenuItem {
                text: "[Bugly] FastFail崩溃"
                enabled: true
                onTriggered: {
                    fileOperator.testCrashFastFail();
                }
            }
            MenuItem {
                text: "[Bugly] abort崩溃"
                enabled: true
                onTriggered: {
                    fileOperator.testCrashAbort();
                }
            }
            MenuItem {
                text: "[Bugly] 非法参数/内存崩溃"
                enabled: true
                onTriggered: {                
                    fileOperator.testCrashInvalidParam();
                }
            }
            MenuItem {
                text: "[Bugly] Purecall崩溃"
                enabled: true
                onTriggered: {
                    fileOperator.testCrashPurecall();
                }
            }
            MenuItem {
                text: "[Bugly] C++未捕获异常崩溃"
                enabled: true
                onTriggered: {
                    fileOperator.testCrashCppException();
                }
            }
            MenuItem {
                text: "[Bugly] 非崩溃Dump上报"
                enabled: true
                onTriggered: {
                    fileOperator.testNonCrashDump();
                }
            }
            MenuItem {
                text: "[Bugly] 触发自定义错误上报"
                enabled: true
                onTriggered: {                
                    fileOperator.testCustomErrorReport();
                }
            }
            MenuItem {
                text: "[Bugly] 触发错误文件上报"
                enabled: true
                onTriggered: {
                    fileOperator.testCustomErrorFileReport();
                }
            }
            MenuItem {
                text: "[Bugly-Mac] ObjC异常崩溃"
                enabled: true
                onTriggered: {                
                    fileOperator.testBuglyObjCException();
                }
            }
            MenuItem {
                text: "[Bugly-Mac] Cocoa异常上报(非崩溃)"
                enabled: true
                onTriggered: {
                    fileOperator.testBuglyExceptionCategory();
                }
            }
            MenuItem {
                text: "[Bugly-Mac] 启动监控测试"
                enabled: true
                onTriggered: {                
                    fileOperator.testBuglyLaunchMonitor();
                }
            }
            MenuItem {
                text: "[Bugly-Mac] 网络监控测试"
                enabled: true
                onTriggered: {
                    fileOperator.testBuglyNetworkTracer();
                }
            }
            MenuItem {
                text: "[Bugly-Mac] 自定义标签测试"
                enabled: true
                onTriggered: {
                    fileOperator.testBuglyCustomTags();
                }
            }
            MenuItem {
                text: "[Bugly] 主动日志上传测试"
                enabled: true
                onTriggered: {
                    fileOperator.testDiagnoseUploadLogs();
                }
            }
        }

        Menu {
            title: "[DEBUG] 卡顿/ANR 模拟上报(Bugly)"
            enabled: isAvailable
            MenuItem {
                text: "[Bugly] 模拟主线程卡顿上报（3s）"
                enabled: true
                onTriggered: {
                    console.log("[DEBUG] simulate bugly lag 3s triggered")
                    fileOperator.testBuglyLagBlock()
                }
            }

            MenuItem {
                text: "[Bugly] 模拟主线程 ANR 上报（6s）"
                enabled: true
                onTriggered: {
                    console.log("[DEBUG] simulate bugly ANR 6s triggered")
                    fileOperator.testBuglyANRBlock()
                }
            }
        }

        MenuItem {
            text: "[DEBUG] 网络错误模拟上报(Bugly)"
            enabled: isAvailable
            onTriggered: {
                console.log("[DEBUG] simulate bugly network error triggered")
                fileOperator.testBuglyNetworkError();
            }
        }

        MenuItem {
            text: "[DEBUG] json转二进制"
            enabled: true
            onTriggered: {
                fileOperator.metaJsonTobinary();
            }
        }

        MenuItem {
            property bool discardFrame: lightSetting.getBool("debug_key_preview_discard_frame", true)
            property bool hasTriggered: false
            property string menuText: discardFrame ? "[DEBUG] 预览丢帧:是" : "[DEBUG] 预览丢帧:否"
            text: hasTriggered ? menuText + "(重启生效)" : menuText;
            enabled: true
            onTriggered: {
                lightSetting.save("debug_key_preview_discard_frame", !discardFrame);
                discardFrame = !discardFrame;
                hasTriggered = true;
            }
        }

        MenuItem {
            property bool showdebuginfo: editorManager.debugStatus
            property string menuText: editorManager.debugStatus ? "[DEBUG] 关闭调试" : "[DEBUG] 开启调试"
            text: menuText;
            enabled: true
            onTriggered: {
                showdebuginfo = !showdebuginfo;
                editorManager.setDebugStatus(showdebuginfo);
            }
        }

        MenuItem {
            property bool updateTestEnv: lightSetting.getBool("updateTestEnv", false)
            property string menuText: updateTestEnv ? "[DEBUG] 当前测试环境" : "[DEBUG] 当前正式环境"
            text: menuText;
            enabled: true
            onTriggered: {
                updateTestEnv = !updateTestEnv;
                lightSetting.save("updateTestEnv", updateTestEnv);
                globalSignal.restart();
            }
        }

        MenuItem {
            property bool isEU: locationManager.isInEURegion
            text: isEU ? "[DEBUG] 当前 EU(切换为 CN)" : "[DEBUG] 当前非 EU(切换为 AT)"
            enabled: true
            onTriggered: {
                locationManager.setCountryCodeForDebug(isEU ? "CN" : "AT");
            }
        }

        MenuItem {
            id: denoiseAlgoMenuItem
            property bool forceTraditional: lightSetting.getBool("debug_key_denoise_force_traditional", false)
            text: forceTraditional ? "[DEBUG] 降噪算法: 传统算法(强制)" : "[DEBUG] 降噪算法: NN算法(跟随白名单)"
            enabled: true
            onTriggered: {
                forceTraditional = !forceTraditional;
                lightSetting.save("debug_key_denoise_force_traditional", forceTraditional);
                globalSignal.denoiseForceTraditionalChanged(forceTraditional);
            }
        }

        Connections {
            target: globalSignal
            function onDenoiseForceTraditionalChanged(value) {
                denoiseAlgoMenuItem.forceTraditional = value;
            }
        }

        MenuItem {
            property bool showdebuginfo: lightSetting.getBool("tkHeadToggle", false)
            property string menuText: lightSetting.getBool("tkHeadToggle") ? "[DEBUG] 关闭追头" : "[DEBUG] 开启追头"
            text: menuText
            enabled: true
            onTriggered: {
                showdebuginfo = !showdebuginfo;
                lightSetting.save("tkHeadToggle", showdebuginfo);
            }
        }

        MenuItem {
            property bool useMachineSelfieMetaData: lightSetting.getBool("useMachineSelfieMetaData", true)
            property string menuText: useMachineSelfieMetaData ? "[DEBUG] 自拍视角不用机内高光数据" : "[DEBUG] 自拍视角用机内高光数据"
            text: menuText
            enabled: true
            onTriggered: {
                useMachineSelfieMetaData = !useMachineSelfieMetaData;
                lightSetting.save("useMachineSelfieMetaData", useMachineSelfieMetaData);
            }
        }

        MenuItem {
            property bool showEventFilter: globalEventFilter.isOpen()
            property string menuText: showEventFilter ? "[DEBUG] 关闭EventFilter" : "[DEBUG] 开启EventFilter"
            text: menuText
            enabled: true
            onTriggered: {
                showEventFilter = !showEventFilter;
                if (showEventFilter) {
                    globalEventFilter.open();
                } else {
                    globalEventFilter.close();
                }
            }
        }

        MenuItem {
            text: appBarViewModel.active ? "[DEBUG] 关闭qml路径调试" : "[DEBUG] 开启qml路径调试"
            enabled: true
            onTriggered: {
                appBarViewModel.toggleInspector();
            }
        }
        
        Menu {
            title: "[DEBUG] 高光分析调试"
            enabled: true

            MenuItem {
                text: "高光开关（AB测试 && GPU支持）（当前：" + (highlightManager.highlightSupport ? "开" : "关") + "）"
                enabled: true
                onTriggered: {
                    highlightManager.highlightSupport = !highlightManager.highlightSupport;
                }
            }

            Menu {
                title: "构图方案"
                enabled: true

                MenuItem {
                    text: (highlightManager.analyzeSolution == 0 ? "[✓]" : "[ ]") + "不处理"
                    enabled: true
                    onTriggered: {
                        highlightManager.analyzeSolution = 0;
                    }
                }
                MenuItem {
                    text: (highlightManager.analyzeSolution == 1 ? "[✓]" : "[ ]") + "方案1：仅16:9参数(100, 0.6) 畸变更小，横向构图更好，主体突出"
                    enabled: true
                    onTriggered: {
                        highlightManager.analyzeSolution = 1;
                    }
                }
                MenuItem {
                    text: (highlightManager.analyzeSolution == 2 ? "[✓]" : "[ ]") + "方案2：根据画幅比例选择 16:9(100, 0.6)、9:16(100, 1)、1:1(110, 0.7) 三套参数"
                    enabled: true
                    onTriggered: {
                        highlightManager.analyzeSolution = 2;
                    }
                }
                MenuItem {
                    text: (highlightManager.analyzeSolution == 3 ? "[✓]" : "[ ]") + "方案3：仅1:1参数(110, 0.7) 畸变更小，兼顾横竖构图，主体略小"
                    enabled: true
                    onTriggered: {
                        highlightManager.analyzeSolution = 3;
                    }
                }
            }

            Menu {
                title: "视角调整方案"
                enabled: true

                MenuItem {
                    text: (highlightManager.offsetAngleSolution == 0 ? "[✓]" : "[ ]") + "方案A：全量平移（所有关键帧统一偏移）"
                    enabled: true
                    onTriggered: {
                        highlightManager.offsetAngleSolution = 0;
                    }
                }
                MenuItem {
                    text: (highlightManager.offsetAngleSolution == 1 ? "[✓]" : "[ ]") + "方案B：局部调整（仅调整当前位置相邻关键帧）"
                    enabled: true
                    onTriggered: {
                        highlightManager.offsetAngleSolution = 1;
                    }
                }
                MenuItem {
                    text: (highlightManager.offsetAngleSolution == 2 ? "[✓]" : "[ ]") + "方案C：绝对值反算（从filter读取反算offsetParams）"
                    enabled: true
                    onTriggered: {
                        highlightManager.offsetAngleSolution = 2;
                    }
                }
                MenuItem {
                    text: (highlightManager.offsetAngleSolution == 3 ? "[✓]" : "[ ]") + "方案D：按帧位置精确差值（保存每帧快照）"
                    enabled: true
                    onTriggered: {
                        highlightManager.offsetAngleSolution = 3;
                    }
                }
            }

            MenuItem {
                text: "高光任务使用前一次的缓存加速分析（当前：" + (highlightManager.enableTaskCache ? "开" : "关") + "）"
                enabled: true
                onTriggered: {
                    highlightManager.enableTaskCache = !highlightManager.enableTaskCache;
                }
            }
            
            MenuItem {
                text: "高光数量copy翻倍（测试UI布局、主题）"
                enabled: true
                onTriggered: {
                    highlightManager.debugDuplicateHighlight();
                }
            }
            
            MenuItem {
                text: "删除所有高光（包括缓存）"
                enabled: true
                onTriggered: {
                    highlightManager.debugDeleteAllHighlight();
                }
            }
            
            MenuItem {
                text: "模拟任务失败（所有任务都返回失败，持续10秒）"
                enabled: true
                onTriggered: {
                    highlightManager.debugMockTaskFailed();
                }
            }
        }

        MenuItem {
            text: "[DEBUG] 灵感粗剪开关（AB测试）（当前：" + (appBarViewModel.roughCutSupport ? "开" : "关") + "）"
            enabled: true
            onTriggered: {
                appBarViewModel.toggleRoughCutSupport();
            }
        }

        MenuItem {
            property bool showRemaining: lightSetting.getBool("debug_ai_roughcut_show_remaining", false)
            text: "[DEBUG] 灵感粗剪剩余次数显示（当前：" + (showRemaining ? "开" : "关") + "）"
            enabled: true
            onTriggered: {
                showRemaining = !showRemaining;
                lightSetting.save("debug_ai_roughcut_show_remaining", showRemaining);
            }
        }

        Menu {
            title: "[DEBUG] 灵感粗剪每日限制次数（当前：" + aiRoughCutManager.config.dailyLimit + "）"
            enabled: true

            MenuItem {
                text: "不限频(-1)"
                onTriggered: aiRoughCutManager.config.setDebugDailyLimit(-1)
            }
            MenuItem {
                text: "2次"
                onTriggered: aiRoughCutManager.config.setDebugDailyLimit(2)
            }
            MenuItem {
                text: "6次(默认)"
                onTriggered: aiRoughCutManager.config.setDebugDailyLimit(6)
            }
            MenuItem {
                text: "10次"
                onTriggered: aiRoughCutManager.config.setDebugDailyLimit(10)
            }
        }

        Menu {
            title: "[DEBUG] 灵感粗剪错误模拟"
            enabled: true

            MenuItem {
                text: "模拟：分析超时（可重试）"
                onTriggered: appBarViewModel.debugSimulateRoughCutError(AppBarViewModel.SimError_JobTimeout)
            }
            MenuItem {
                text: "模拟：解析失败（可重试）"
                onTriggered: appBarViewModel.debugSimulateRoughCutError(AppBarViewModel.SimError_Unknown)
            }
            MenuItem {
                text: "模拟：素材内容问题（退出）"
                onTriggered: appBarViewModel.debugSimulateRoughCutError(AppBarViewModel.SimError_ParamInvalid)
            }
            MenuItem {
                text: "模拟：远端执行失败（退出）"
                onTriggered: appBarViewModel.debugSimulateRoughCutError(AppBarViewModel.SimError_JobExecuteFailed)
            }
        }

        Menu {
            title: "[DEBUG] VideoTranscodeHelper 测试"
            enabled: true

            FileDialog {
                id: vthMacTestDialog
                nameFilters: ["视频文件 (*.mp4 *.mov *.avi *.mkv *.hevc *.h264 *.m4v *.osv *.lrf *.OSV *.LRF)"]
                property int testMode: 0   // 0=VideoExport 1=FrameExtract 2=AudioExport
                onAccepted: {
                    var path = selectedFile.toString().replace("file://", "")
                    if (testMode === 0) {
                        videoTranscodeHelperTest.testVideoExport(path)
                    } else if (testMode === 1) {
                        videoTranscodeHelperTest.testFrameExtract(path)
                    } else if (testMode === 2) {
                        videoTranscodeHelperTest.testAudioExport(path)
                    } else if (testMode === 3) {
                        videoTranscodeHelperTest.testPanoVideoExport(path)
                    } else if (testMode === 4) {
                        videoTranscodeHelperTest.testPanoFrameExtract(path)
                    } else if (testMode === 5) {
                        videoTranscodeHelperTest.testPanoAudioExport(path)
                    } else if (testMode === 6) {
                        videoTranscodeHelperTest.testCompareExport(path)
                    }
                }
            }

            MenuItem {
                text: "[DEBUG] 测试 VideoExport（选文件→转 480P 3fps MP4）"
                enabled: true
                onTriggered: {
                    vthMacTestDialog.testMode = 0
                    vthMacTestDialog.open()
                }
            }
            MenuItem {
                text: "[DEBUG] 测试 FrameExtract（选文件→抽 3fps JPEG 序列）"
                enabled: true
                onTriggered: {
                    vthMacTestDialog.testMode = 1
                    vthMacTestDialog.open()
                }
            }
            MenuItem {
                text: "[DEBUG] 测试 AudioExport（选文件→提取音频）"
                enabled: true
                onTriggered: {
                    vthMacTestDialog.testMode = 2
                    vthMacTestDialog.open()
                }
            }

            MenuSeparator {}

            MenuItem {
                text: "[DEBUG] 测试 PanoVideoExport（选全景文件→转 480P 3fps MP4，fov=100 eyez=1）"
                enabled: true
                onTriggered: {
                    vthMacTestDialog.testMode = 3
                    vthMacTestDialog.open()
                }
            }
            MenuItem {
                text: "[DEBUG] 测试 PanoFrameExtract（选全景文件→抽 3fps JPEG 序列，fov=100 eyez=1）"
                enabled: true
                onTriggered: {
                    vthMacTestDialog.testMode = 4
                    vthMacTestDialog.open()
                }
            }
            MenuItem {
                text: "[DEBUG] 测试 PanoAudioExport（选全景文件→提取音频，fov=100 eyez=1）"
                enabled: true
                onTriggered: {
                    vthMacTestDialog.testMode = 5
                    vthMacTestDialog.open()
                }
            }

            MenuSeparator {}

            MenuItem {
                text: "[DEBUG] 对比导出清晰度（方案A:3fps 1Mbps vs 方案B:30fps 10Mbps 10x快进）"
                enabled: true
                onTriggered: {
                    vthMacTestDialog.testMode = 6
                    vthMacTestDialog.open()
                }
            }
        }

        Menu {
            title: "[DEBUG] 云相册功能开关"
            enabled: true
            id: cloudAlbumDebugMenu

            property string networkHost: lightSetting.getString("debug_cloud_album_network_host", QmlConstants.cloudAlbumHostUlanProd())
            property bool forceBetaView: lightSetting.getBool("debug_force_cloud_album_beta_view", false)
            property bool forceGuideStepsView: lightSetting.getBool("debug_force_cloud_album_guide_steps_view", false)

            onAboutToShow: {
                forceBetaView = lightSetting.getBool("debug_force_cloud_album_beta_view", false)
                forceGuideStepsView = lightSetting.getBool("debug_force_cloud_album_guide_steps_view", false)
            }

            function currentNetworkLabel() {
                switch (networkHost) {
                case QmlConstants.cloudAlbumHostHangzhouDev():
                    return "杭州-开发"
                case QmlConstants.cloudAlbumHostHangzhouTest():
                    return "杭州-测试"
                case QmlConstants.cloudAlbumHostHangzhouPreProd():
                    return "杭州-PRE-PROD"
                case QmlConstants.cloudAlbumHostUlanDev():
                    return "乌兰-开发"
                case QmlConstants.cloudAlbumHostUlanTest():
                    return "乌兰-测试"
                case QmlConstants.cloudAlbumHostUlanPreProd():
                    return "乌兰-预发"
                case QmlConstants.cloudAlbumHostUlanPayPreProd():
                    return "乌兰支付-pre-prod"
                case QmlConstants.cloudAlbumHostUlanProd():
                    return "乌兰-生产"
                default:
                    return networkHost
                }
            }

            function networkActionText(label, host) {
                return (networkHost === host ? "[✓] " : "[ ] ") + label + "    " + host
            }

            function setNetworkHost(host) {
                networkHost = host
                lightSetting.save("debug_cloud_album_network_host", host)
                globalSignal.restart()
            }

            function setForceBetaView(enabled) {
                forceBetaView = enabled
                if (enabled) {
                    forceGuideStepsView = false
                    lightSetting.save("debug_force_cloud_album_guide_steps_view", false)
                }
                lightSetting.save("debug_force_cloud_album_beta_view", enabled)
                globalSignal.cloudAlbumDebugRefreshBenefit()
            }

            function setForceGuideStepsView(enabled) {
                forceGuideStepsView = enabled
                if (enabled) {
                    forceBetaView = false
                    lightSetting.save("debug_force_cloud_album_beta_view", false)
                }
                lightSetting.save("debug_force_cloud_album_guide_steps_view", enabled)
                globalSignal.cloudAlbumDebugRefreshBenefit()
            }

            MenuItem {
                text: "总开关（当前：" + (cloudAlbumFeatureFlags.enable ? "开" : "关") + "）"
                enabled: true
                onTriggered: {
                    cloudAlbumFeatureFlags.enable = !cloudAlbumFeatureFlags.enable
                }
            }
            MenuItem {
                text: "高光标签（当前：" + (cloudAlbumFeatureFlags.highlightEnable ? "开" : "关") + "）"
                enabled: true
                onTriggered: {
                    cloudAlbumFeatureFlags.highlightEnable = !cloudAlbumFeatureFlags.highlightEnable
                }
            }
            MenuItem {
                text: "新建相册（当前：" + (cloudAlbumFeatureFlags.createAlbumEnable ? "开" : "关") + "）"
                enabled: true
                onTriggered: {
                    cloudAlbumFeatureFlags.createAlbumEnable = !cloudAlbumFeatureFlags.createAlbumEnable
                }
            }
            MenuItem {
                text: "去订阅（当前：" + (cloudAlbumFeatureFlags.subscribeEnable ? "开" : "关") + "）"
                enabled: true
                onTriggered: {
                    cloudAlbumFeatureFlags.subscribeEnable = !cloudAlbumFeatureFlags.subscribeEnable
                }
            }
            MenuItem {
                text: "强制显示内测资格申请页（当前：" + (cloudAlbumDebugMenu.forceBetaView ? "开" : "关") + "）"
                enabled: true
                onTriggered: {
                    cloudAlbumDebugMenu.setForceBetaView(!cloudAlbumDebugMenu.forceBetaView)
                }
            }
            MenuItem {
                text: "强制显示权益领取页（当前：" + (cloudAlbumDebugMenu.forceGuideStepsView ? "开" : "关") + "）"
                enabled: true
                onTriggered: {
                    cloudAlbumDebugMenu.setForceGuideStepsView(!cloudAlbumDebugMenu.forceGuideStepsView)
                }
            }

            Menu {
                title: "切换网络环境（当前：" + cloudAlbumDebugMenu.currentNetworkLabel() + "，需重启生效）"
                enabled: true

                MenuItem {
                    text: cloudAlbumDebugMenu.networkActionText("杭州-开发", QmlConstants.cloudAlbumHostHangzhouDev())
                    enabled: true
                    onTriggered: {
                        cloudAlbumDebugMenu.setNetworkHost(QmlConstants.cloudAlbumHostHangzhouDev())
                    }
                }
                MenuItem {
                    text: cloudAlbumDebugMenu.networkActionText("杭州-测试", QmlConstants.cloudAlbumHostHangzhouTest())
                    enabled: true
                    onTriggered: {
                        cloudAlbumDebugMenu.setNetworkHost(QmlConstants.cloudAlbumHostHangzhouTest())
                    }
                }
                MenuItem {
                    text: cloudAlbumDebugMenu.networkActionText("杭州-PRE-PROD", QmlConstants.cloudAlbumHostHangzhouPreProd())
                    enabled: true
                    onTriggered: {
                        cloudAlbumDebugMenu.setNetworkHost(QmlConstants.cloudAlbumHostHangzhouPreProd())
                    }
                }
                MenuItem {
                    text: cloudAlbumDebugMenu.networkActionText("乌兰-开发", QmlConstants.cloudAlbumHostUlanDev())
                    enabled: true
                    onTriggered: {
                        cloudAlbumDebugMenu.setNetworkHost(QmlConstants.cloudAlbumHostUlanDev())
                    }
                }
                MenuItem {
                    text: cloudAlbumDebugMenu.networkActionText("乌兰-测试", QmlConstants.cloudAlbumHostUlanTest())
                    enabled: true
                    onTriggered: {
                        cloudAlbumDebugMenu.setNetworkHost(QmlConstants.cloudAlbumHostUlanTest())
                    }
                }
                MenuItem {
                    text: cloudAlbumDebugMenu.networkActionText("乌兰-预发", QmlConstants.cloudAlbumHostUlanPreProd())
                    enabled: true
                    onTriggered: {
                        cloudAlbumDebugMenu.setNetworkHost(QmlConstants.cloudAlbumHostUlanPreProd())
                    }
                }
                MenuItem {
                    text: cloudAlbumDebugMenu.networkActionText("乌兰支付-pre-prod", QmlConstants.cloudAlbumHostUlanPayPreProd())
                    enabled: true
                    onTriggered: {
                        cloudAlbumDebugMenu.setNetworkHost(QmlConstants.cloudAlbumHostUlanPayPreProd())
                    }
                }
                MenuItem {
                    text: cloudAlbumDebugMenu.networkActionText("乌兰-生产", QmlConstants.cloudAlbumHostUlanProd())
                    enabled: true
                    onTriggered: {
                        cloudAlbumDebugMenu.setNetworkHost(QmlConstants.cloudAlbumHostUlanProd())
                    }
                }
            }

            MenuItem {
                property bool active: lightSetting.getBool("debug_mock_storage_1gb", false)
                text: "模拟剩余空间1G（当前：" + (active ? "开" : "关") + "）"
                enabled: true
                onTriggered: {
                    active = !active
                    lightSetting.save("debug_mock_storage_1gb", active)
                    globalSignal.cloudAlbumDebugRefreshBenefit()
                }
            }
            MenuItem {
                property bool active: lightSetting.getBool("debug_mock_membership_expiring_20d", false)
                text: "模拟会员还有20天到期（当前：" + (active ? "开" : "关") + "）"
                enabled: true
                onTriggered: {
                    active = !active
                    lightSetting.save("debug_mock_membership_expiring_20d", active)
                    if (active) lightSetting.save("debug_mock_membership_expired_20d", false)
                    globalSignal.cloudAlbumDebugRefreshBenefit()
                }
            }
            MenuItem {
                property bool active: lightSetting.getBool("debug_mock_membership_expired_20d", false)
                text: "模拟会员已过期20天（当前：" + (active ? "开" : "关") + "）"
                enabled: true
                onTriggered: {
                    active = !active
                    lightSetting.save("debug_mock_membership_expired_20d", active)
                    if (active) lightSetting.save("debug_mock_membership_expiring_20d", false)
                    globalSignal.cloudAlbumDebugRefreshBenefit()
                }
            }
            MenuItem {
                text: "[灰度Mock] 开启云相册（重启生效）"
                enabled: true
                onTriggered: {
                    if (CloudAlbumManager.debugSetCloudAlbumGrayMock(true)) {
                        globalSignal.toast("灰度 mock 已写入：开启，重启后生效", "cloudAlbum")
                    } else {
                        globalSignal.toast("写入失败：请先登录并进入过云相册", "cloudAlbum")
                    }
                }
            }
            MenuItem {
                text: "[灰度Mock] 关闭云相册（重启生效）"
                enabled: true
                onTriggered: {
                    if (CloudAlbumManager.debugSetCloudAlbumGrayMock(false)) {
                        globalSignal.toast("灰度 mock 已写入：关闭，重启后生效", "cloudAlbum")
                    } else {
                        globalSignal.toast("写入失败：请先登录并进入过云相册", "cloudAlbum")
                    }
                }
            }
        }

        //
        MenuItem {
            text: "[DEBUG] 乱码信息"
            enabled: true
            onTriggered: {
                logger.d(qsTr("pccut_draft_delete_popup_cancel"))
                fileOperator.logGarbled();
            }
        }

        MenuItem {
            text: "[DEBUG] 恢复草稿"
            enabled: true
            onTriggered: {
                globalSignal.selectDraftFile();
            }
        }

        MenuItem {
            property bool isProEnv: lightSetting.getBool("useProdEventTrackHost", false)
            text: "[DEBUG] 当前" + (isProEnv ? "正式" : "测试") + "环境埋点(需重启)"
            enabled: true
            onTriggered: {
                lightSetting.save("useProdEventTrackHost", !isProEnv);
                globalSignal.restart();
            }
        }

        MenuItem {
            property bool mockExportFail: lightSetting.getBool("mockExportFail", false)
            property string menuText: mockExportFail ? "[DEBUG] 当前开启模拟导出失败" : "[DEBUG] 当前关闭模拟导出失败"
            text: menuText
            enabled: true
            onTriggered: {
                lightSetting.save("mockExportFail", !mockExportFail);
                globalSignal.restart();
            }
        }

        MenuItem {
            property bool useTrackingPreview: editorManager.tkPreviewStatus
            property string menuText: useTrackingPreview ? "[DEBUG] 关闭实时追踪预览" : "[DEBUG] 开启实时追踪预览"
            text: menuText
            enabled: true
            onTriggered: {
                editorManager.tkPreviewStatus = !useTrackingPreview;
                globalSignal.switchTrackingPreview();
            }
        }

        MenuItem {
            id: lagButton
            text: "[DEBUG] 模拟卡顿(Sleep 2s)"
            enabled: true
            onTriggered: {
                //globalSignal.freezeByWaitLock();
                keepAliveEventFilter.SetSimulateLag();
            }
        }

        MenuItem {
            text: "[DEBUG] 模拟转场替换失败"
            onTriggered: {
                globalSignal.toast(qsTr("pccut_resource_transition_replace_fail"), "tracks")
            }
        }


        MenuItem {
            id: freezedButton
            text: "[DEBUG] 模拟卡死(Sleep 20s)"
            enabled: true
            onTriggered: {
                //globalSignal.freezeBySlowFunction();
                keepAliveEventFilter.SetSimulateFreezed();
            }
        }

        MenuItem {
            id: unresponsiveButton
            text: "[DEBUG] 模拟窗口无响应 8s"
            enabled: true
            onTriggered: {
                keepAliveEventFilter.SetSimulateUnresponsive();
            }
        }

        MenuItem {
            property bool isSimulating: false
            text: isSimulating ? "[DEBUG] 停止模拟渲染线程卡死" : "[DEBUG] 模拟渲染线程卡死"
            enabled: true
            onTriggered: {
                isSimulating = !isSimulating;
                if (isSimulating) {
                    keepAliveEventFilter.setSimulateRenderFreezed();
                } else {
                    keepAliveEventFilter.stopSimulateRenderFreezed();
                }
            }
        }

        Menu {
            title: "[DEBUG] 性能追踪与调试"
            enabled: isAvailable

            MenuItem {
                property bool trackingStatsEnabled: lightSetting.getBool("trackingStatsEnabled", false)
                property string menuText: trackingStatsEnabled ? "关闭追踪统计" : "开启追踪统计"
                text: menuText
                enabled: true
                onTriggered: {
                    trackingStatsEnabled = !trackingStatsEnabled;
                    lightSetting.save("trackingStatsEnabled", trackingStatsEnabled);
                }
            }

            MenuItem {
                text: "导出追踪数据"
                enabled: true
                onTriggered: {
                    globalSignal.exportTrackingStats();
                }
            }

            MenuItem {
                property bool showTkSpeedUpFeature: lightSetting.getBool("showTkSpeedUpFeature", false)
                property string menuText: showTkSpeedUpFeature ? "隐藏倍速TK功能" : "显示倍速TK功能"
                text: menuText
                enabled: true
                onTriggered: {
                    showTkSpeedUpFeature = !showTkSpeedUpFeature;
                    lightSetting.save("showTkSpeedUpFeature", showTkSpeedUpFeature);
                }
            }
        }

        Menu {
            title: "[DEBUG] ASAN 内存错误测试"
            enabled: isAvailable

            MenuItem {
                text: "堆缓冲区溢出 (heap-buffer-overflow)"
                enabled: true
                onTriggered: {
                    console.log("测试: 堆缓冲区溢出")
                    globalSignal.testAsanHeapBufferOverflow();
                }
            }

            MenuItem {
                text: "栈缓冲区溢出 (stack-buffer-overflow)"
                enabled: true
                onTriggered: {
                    console.log("测试: 栈缓冲区溢出")
                    globalSignal.testAsanStackBufferOverflow();
                }
            }

            MenuItem {
                text: "释放后使用 (use-after-free)"
                enabled: true
                onTriggered: {
                    console.log("测试: 堆释放后使用")
                    globalSignal.testAsanUseAfterFree();
                }
            }

            MenuItem {
                text: "重复释放 (double-free)"
                enabled: true
                onTriggered: {
                    console.log("测试: 重复释放")
                    globalSignal.testAsanDoubleFree();
                }
            }

            MenuItem {
                text: "全局缓冲区溢出 (global-buffer-overflow)"
                enabled: true
                onTriggered: {
                    console.log("测试: 全局缓冲区溢出")
                    globalSignal.testAsanGlobalBufferOverflow();
                }
            }

            MenuItem {
                text: "作用域后使用 (use-after-scope)"
                enabled: true
                onTriggered: {
                    console.log("测试: 作用域后使用")
                    globalSignal.testAsanUseAfterScope();
                }
            }
        }

        Menu {
            id: exportDebugMenu
            title: "[DEBUG] 导出"

            property double currentMock: lightSetting.getDouble("debug_disk_mock_available_mb", -1)

            function setMock(val) {
                lightSetting.save("debug_disk_mock_available_mb", val);
                currentMock = val;
            }

            Menu {
                title: "模拟导出剩余空间 (" + (exportDebugMenu.currentMock < 0 ? "真实值" : exportDebugMenu.currentMock + " MB") + ")"

                MenuItem {
                    text: (exportDebugMenu.currentMock < 0 ? "✓ " : "   ") + "真实值"
                    onTriggered: exportDebugMenu.setMock(-1)
                }
                MenuItem {
                    text: (exportDebugMenu.currentMock === 100 ? "✓ " : "   ") + "100 MB"
                    onTriggered: exportDebugMenu.setMock(100)
                }
                MenuItem {
                    text: (exportDebugMenu.currentMock === 512 ? "✓ " : "   ") + "512 MB"
                    onTriggered: exportDebugMenu.setMock(512)
                }
                MenuItem {
                    text: (exportDebugMenu.currentMock === 1024 ? "✓ " : "   ") + "1024 MB (1GB)"
                    onTriggered: exportDebugMenu.setMock(1024)
                }
                MenuItem {
                    text: (exportDebugMenu.currentMock === 3072 ? "✓ " : "   ") + "3072 MB (3GB)"
                    onTriggered: exportDebugMenu.setMock(3072)
                }
                MenuItem {
                    text: (exportDebugMenu.currentMock === 5120 ? "✓ " : "   ") + "5120 MB (5GB)"
                    onTriggered: exportDebugMenu.setMock(5120)
                }
                MenuItem {
                    text: (exportDebugMenu.currentMock === 10240 ? "✓ " : "   ") + "10240 MB (10GB)"
                    onTriggered: exportDebugMenu.setMock(10240)
                }
                MenuItem {
                    text: (exportDebugMenu.currentMock === 51200 ? "✓ " : "   ") + "51200 MB (50GB)"
                    onTriggered: exportDebugMenu.setMock(51200)
                }
            }
        }
        MenuItem {
            text: Instance.debugMarkPointUseAltIcon ? "[DEBUG] 标记标签: 调试图标" : "[DEBUG] 标记标签: 正式图标"
            onTriggered: {
                Instance.debugMarkPointUseAltIcon = !Instance.debugMarkPointUseAltIcon;
            }
        }
        Menu {
            title: "[DEBUG] 设置底层LOGLevel"
            enabled: true
            MenuItem {
                text: "默认(error)"
                enabled: true
                onTriggered: {
                    crashTrackHelper.setMltLogLevel(16);
                }
            }
            MenuItem {
                text: "warning"
                enabled: true
                onTriggered: {
                    crashTrackHelper.setMltLogLevel(24);
                }
            }
            MenuItem {
                text: "info"
                enabled: true
                onTriggered: {
                    crashTrackHelper.setMltLogLevel(32);
                }
            }
            MenuItem {
                text: "debug"
                enabled: true
                onTriggered: {
                    crashTrackHelper.setMltLogLevel(48);
                }
            }
        }

        Menu {
            id: panoDebugOsdMenu
            title: "[DEBUG] 开关画面OSD"
            enabled: true
            property bool osdEnabled: false
            onAboutToShow: {
                osdEnabled = lightSetting.getBool("panoDebugOsd", false)
            }
            MenuItem {
                text: panoDebugOsdMenu.osdEnabled ? "[DEBUG] 关闭画面OSD" : "[DEBUG] 开启画面OSD"
                enabled: true
                onTriggered: {
                    panoDebugOsdMenu.osdEnabled = !panoDebugOsdMenu.osdEnabled
                    lightSetting.save("panoDebugOsd", panoDebugOsdMenu.osdEnabled)
                }
            }
        }
    }
}
