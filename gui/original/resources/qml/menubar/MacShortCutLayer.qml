import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.15
import Qt5Compat.GraphicalEffects
import Controls 1.0
import Config 1.0
import app_qrc 1.0
import "../controller"

LightPopup {
    id: layer
    // 充满主窗口 overlay；真正可见的对话框是内部居中的 windowBackground 卡片
    width: parent ? parent.width : 0
    height: parent ? parent.height : 0
    focus: true
    needNoBorder: true            // 遮罩铺满 overlay，无需整屏描边
    closePolicy: Popup.NoAutoClose // Esc 由下方 Shortcut 守卫(有未保存改动先弹确认)
    // 模态窗口宽度
    property real windowWidth: 600

    // ====== 动态窗口高度 ======
    // 高度随当前 tab(左右两列较多一侧)的行数变化，使内容区恰好容纳、正常不出现滚动条。
    // 用绑定计算而非在 onCompleted 里赋值：首次打开即以正确高度创建窗口，避免 mac 上
    // "先按默认高度弹出、再跳到内容高度"的突变；下方 Behavior 仅在切 tab(高度变化)时做动画。
    readonly property int rowHeight: 32
    // content 顶部固定偏移 100(标题栏 40 + tab 区 24+24 + content topMargin 12) 加底部留白 88
    readonly property int contentVMargin: 188
    // 最大高度取主窗口(overlay)可用高度的 90%，超出时由滚动条兜底
    readonly property int maxWindowHeight: Math.round((layer.parent ? layer.parent.height : 900) * 0.9)
    // 当前 tab 左右两列中较多一侧的行数；getLeftModel/getRightModel 内部读取 currentShortcutType，
    // 切 tab 时该依赖变化会自动触发本绑定重算
    readonly property int currentTabRows: {
        if (!macshortCutViewModel) return 0
        const lm = macshortCutViewModel.getLeftModel()
        const rm = macshortCutViewModel.getRightModel()
        return Math.max(lm ? lm.count : 0, rm ? rm.count : 0)
    }
    // 当前 tab 自然高度是否超过最大高度(决定是否显示滚动条)
    readonly property bool contentOverflow: (currentTabRows * rowHeight + contentVMargin) > maxWindowHeight
    // 模态窗口高度：自然高度与最大高度取小
    property real windowHeight: Math.min(currentTabRows * rowHeight + contentVMargin, maxWindowHeight)

    // 高度动画移至 windowBackground.height(纯 QML 层动画，无原生窗口 resize → 无居中/抖动)
    // 首帧创建期间不动画，避免初始/启动期几何重算触发动画
    property bool heightAnimReady: false
    // 面板动画统一时长(高度过渡 + tab 指示块滑动共用，避免被各自改成不同值)
    readonly property int panelAnimDuration: 150
    Component.onCompleted: { heightAnimReady = true; open() }

    // 草稿打开时编辑器面板的 PlayerViewGesture 有个 dragThreshold:0 的全屏 DragHandler，
    // 走 scene 级 pointer grab，绕过 modal popup：点击 tab 时鼠标微移会被它抢走 grab，
    // 导致 TabButton.clicked 不触发(mac/win 同源)。仿其他弹窗惯例，弹窗期间禁用播放器手势。
    // 覆盖基类 onOpened，故需补回基类的 enableMenuBar(false)；手势恢复并入下方既有 onClosed。
    onOpened: {
        globalSignal.enableMenuBar(false)
        globalSignal.enablePlayerViewGesture(false)
    }

    // 快捷键面板数据 model：声明在 Window 之前，保证 currentTabRows/windowHeight 绑定首次求值时
    // 它已构造完成(Window 几何绑定依赖 windowHeight，需要 viewmodel 已就绪)，从而首开即得到正确高度
    MacShortCutViewmodel {
        id: macshortCutViewModel
        onTypeChanged: (type) => {
            page1.model = null
            page1.model = getLeftModel()
            page2.model = null
            page2.model = getRightModel()
        }
    }

    property int selectShortCutType: ShortcutConfig.currentShortcutType()

    property var activeDynamicContent: null
            
    property bool isRecording: false

    property var pendingChanges: ({}) 
    property bool hasUnsavedChanges: false

    property int conflictActionId: -1
    property string conflictActionTitle: ""

    property string currentCombo: ""
    property bool isCompletingRecording: false  

    property int pendingTemplateType: -1

    function isProtectedAction(actionId) {
        return ShortcutConfig.isProtectedAction ? ShortcutConfig.isProtectedAction(actionId) : false
    }

    function setActiveDynamicContent(item) {
        if (activeDynamicContent === item) {
            cancelActivation()
            return
        }
        
        if (activeDynamicContent) {
            activeDynamicContent.active = false
        }
        
        activeDynamicContent = item
        if (activeDynamicContent) {
            activeDynamicContent.active = true
            startRecording()
        }
    }

    signal destorySource()
    // 关闭弹窗(走 Popup 关闭动画)
    function closeWinowd() {
        close()
    }
    // 关闭后通知 Loader 卸载(MenuBarPopupLayers 连接 destorySource → sourceComponent=null + 恢复菜单栏)
    // 一并恢复播放器手势(开弹窗时 onOpened 禁用)
    onClosed: {
        destorySource()
        globalSignal.enablePlayerViewGesture(true)
    }

    function clearShortcut(actionId, contentItem) {
        var originalShortcut = ShortcutConfig.actionString(actionId)
        var hasPending = pendingChanges.hasOwnProperty(actionId) && pendingChanges[actionId] !== ""

        // 已保存与待保存都为空，无需处理
        if (originalShortcut === "" && !hasPending) {
            return
        }

        pendingChanges[actionId] = ""
        hasUnsavedChanges = true
        confirmBtn.canUse = true

        // 优先清空指定行的显示；否则回退到当前激活项
        var target = contentItem
            || (activeDynamicContent && activeDynamicContent.actionId === actionId ? activeDynamicContent : null)
        if (target) {
            updateShortcutDisplayRealtime("", target)
        }
    }

    function buildActionContextFromRecording(comboString, actionId) {
        return {
            actionId: actionId,
            keySequence: comboString,
            appType: getCurrentAppType()
        }
    }

    function getCurrentAppType() {
        return selectShortCutType
    }

    function getAppTypeName(enumValue) {
        return ShortcutConfig.getTypeTitle(enumValue)
    }

    function buildCurrentCombo(event) {
        var combo = ""
        var parts = []
        
        if (event.modifiers & Qt.ControlModifier) parts.push("Ctrl")
        if (event.modifiers & Qt.ShiftModifier) parts.push("Shift")
        if (event.modifiers & Qt.AltModifier) parts.push("Alt")
        if (event.modifiers & Qt.MetaModifier) parts.push("Meta")
        

        var keyName = getKeyName(event.key)
        if (keyName !== "Unknown" && !isModifierKey(event.key)) {
            parts.push(keyName)
        }
        
        if (parts.length > 3) {
            parts = parts.slice(0, 3)
        }
        return parts.join("+")
    }

    function isModifierKey(keyCode) {
        return keyCode === Qt.Key_Control || 
            keyCode === Qt.Key_Shift || 
            keyCode === Qt.Key_Alt || 
            keyCode === Qt.Key_Meta
    }

    function startRecording() {
        currentCombo = ""
        isRecording = true
        content.forceActiveFocus()
    }

    function cancelActivation() {
        currentCombo = ""
        isRecording = false
        if (activeDynamicContent) {
            activeDynamicContent.active = false
            activeDynamicContent = null
        }
    }

    // 把图标项列表填充到指定 DynamicContent（先清空再逐项追加）
    // shortcutText 为完整快捷键串，供内容溢出渐隐时的 tooltip 使用
    function fillContentWithIcons(content, items, shortcutText) {
        if (!content) return
        content.shortcutText = shortcutText || ""
        content.clearContent()
        if (!items) return
        for (let i = 0; i < items.length; i++) {
            const item = items[i]
            if (item === null) continue
            if (item.type === "image") {
                content.addImage(item.source)
            } else {
                content.addText(item.text)
            }
        }
    }

    function updateShortcutDisplayRealtime(displayText, targetContent) {
        var content = targetContent || activeDynamicContent
        if (!content) return
        var items = (displayText && displayText.length > 0)
            ? ShortcutConfig.parseShortcutStringToIcons(displayText)
            : []
        fillContentWithIcons(content, items, displayText)
    }
    // 统一处理一次快捷键冲突：受保护→toast 拦截；普通冲突→弹覆盖确认框。
    // 返回 true 表示已处理（调用方应 return），false 表示无冲突可继续。
    function handleShortcutConflict(conflict) {
        if (!conflict || !conflict.hasConflict) return false
        if (conflict.isProtected) {
            toast.showToast(qsTr("pccut_shortcut_space_customize_warn_8").arg(ShortcutConfig.actionTitle(conflict.conflictActionId)))
            updateShortcutDisplayRealtime("")
            currentCombo = ""
            return true
        }
        conflictActionId = conflict.conflictActionId
        conflictActionTitle = conflict.conflictActionTitle
        conflictPopup.text = qsTr("pccut_shortcut_space_customize_warn_3").arg(conflict.conflictActionTitle)
        conflictPopup.open()
        return true
    }

    function completeRecording() {
        if (currentCombo && activeDynamicContent && activeDynamicContent.actionId >= 0) {
            var parts = currentCombo.split("+")
            var hasUnknownKey = false
            var hasValidMainKey = false
            for (var i = 0; i < parts.length; i++) {
                var part = parts[i]
                if (part === "Unknown") {
                    hasUnknownKey = true
                    break
                }
                if (part !== "Ctrl" && part !== "Shift" && part !== "Alt" && part !== "Cmd") {
                    hasValidMainKey = true
                }
            }
            
            if (hasUnknownKey) {
                toast.showToast(qsTr("pccut_shortcut_space_customize_warn_1"))
                updateShortcutDisplayRealtime("")
                currentCombo = ""
                return
            }
            
            if (!hasValidMainKey) {
                toast.showToast(qsTr("pccut_shortcut_space_customize_warn_2"))
                updateShortcutDisplayRealtime("")
                currentCombo = ""
                return
            }
            var originalShortcut = ShortcutConfig.actionString(activeDynamicContent.actionId)
            
            var currentEffectiveShortcut = getEffectiveShortcut(activeDynamicContent.actionId)
            
            if (currentCombo !== currentEffectiveShortcut) {
                // 先查待保存改动里的冲突
                if (handleShortcutConflict(checkPendingConflicts(currentCombo, activeDynamicContent.actionId))) return

                var conflictInfo = ShortcutConfig.getConflictInfo(currentCombo, activeDynamicContent.actionId)
                if (conflictInfo.hasConflict) {
                    // 受保护：直接拦截；普通冲突：仅当其当前生效快捷键确实等于该组合时才提示覆盖
                    if (conflictInfo.isProtected
                        || getEffectiveShortcut(conflictInfo.conflictActionId) === currentCombo) {
                        if (handleShortcutConflict(conflictInfo)) return
                    }
                }

                // 保持 pendingChanges 干净：等于原始值不写入待保存条目，避免保存时把原值回写
                if (currentCombo === originalShortcut) {
                    delete pendingChanges[activeDynamicContent.actionId]
                } else {
                    pendingChanges[activeDynamicContent.actionId] = currentCombo
                }
                // 与当前生效快捷键不同，视为有改动，保存按钮置红
                hasUnsavedChanges = true
                confirmBtn.canUse = true
            }
            // 与当前生效快捷键相同：保持保存按钮原有状态，不做任何改变
            
            updateShortcutDisplayRealtime(currentCombo)
        }else{
            toast.showToast(qsTr("pccut_shortcut_space_customize_warn_1"))
            updateShortcutDisplayRealtime("")
        }
        currentCombo = ""
    }


    function getActionIdForContent(dynamicContent) {
        return dynamicContent.actionId || 0
    }

    function saveAllChanges() {
        var appTypeEnum = getCurrentAppType()
        // var successCount = 0
        var failCount = 0
        
        for (var actionId in pendingChanges) {
            var keySequence = pendingChanges[actionId]
            var success = ShortcutConfig.updateShortcutFromEnum(
                parseInt(actionId), 
                keySequence, 
                appTypeEnum
            )
            
            if (success) {
                // successCount++
            } else {
                failCount++
            }
        }
        
        if (failCount === 0) {
            pendingChanges = {}
            hasUnsavedChanges = false
            confirmBtn.canUse = false
            macshortCutViewModel.setShortCutType(topbar.currentIndex)
            // toast.showToast(qsTr("pccut_shortcut_save_success"))
        } else {
            // toast.showToast(qsTr("pccut_shortcut_save_failed_count").arg(failCount))
        }
    }


    function cancelAllChanges() {
        pendingChanges = {}
        hasUnsavedChanges = false
        
        confirmBtn.canUse = false
        
        cancelActivation()
        
        var currentIndex = topbar.currentIndex
        macshortCutViewModel.setShortCutType(currentIndex)
    }

    function restoreDefaults() {
        cancelAllChanges()
        
        var currentType = getCurrentAppType()
        ShortcutConfig.restoreToDefaults(currentType)
        
        var currentIndex = topbar.currentIndex
        macshortCutViewModel.setShortCutType(currentIndex)
        
    }

    function checkPendingConflicts(keySequence, currentActionId) {
        if (!keySequence || keySequence === "") {
            return { hasConflict: false }
        }
        
        
        for (var actionId in pendingChanges) {
            var actionIdInt = parseInt(actionId)
            var pendingKeySequence = pendingChanges[actionId]
            
            
            if (actionIdInt !== currentActionId && 
                pendingKeySequence === keySequence && 
                pendingKeySequence !== "" && 
                keySequence !== "") {
                
                return {
                    hasConflict: true,
                    conflictActionId: actionIdInt,
                    conflictActionTitle: ShortcutConfig.actionTitle(actionIdInt),
                    isProtected: isProtectedAction(actionIdInt) 
                }
            }
        }
        
        return { hasConflict: false }
    }

    function getEffectiveShortcut(actionId) {
        if (pendingChanges.hasOwnProperty(actionId.toString())) {
            return pendingChanges[actionId.toString()]
        }
        return ShortcutConfig.actionString(actionId)
    }

    function getKeyName(key) {
        // 修饰键
        if (key === Qt.Key_Control) return "Ctrl"
        if (key === Qt.Key_Shift) return "Shift" 
        if (key === Qt.Key_Alt) return "Alt"
        if (key === Qt.Key_Meta) return "Meta"
        
        var keyMap = {
            16777216: "Esc", 16777220: "Enter", 32: "Space",
            16777232: "Home", 16777233: "End",
            16777234: "Left", 16777235: "Up", 16777236: "Right", 16777237: "Down",
            16777222: "Insert", 16777223: "Delete",
            16777238: "PageUp", 16777239: "PageDown",
            16777219: "Backspace",

            // 这里需要注意对各种不同的键码进行转换
            //这里我列举了产品给的那些 以后如果需要同一按键的不同键码 就在这里进行补充
            47: "/", 63: "/",   // / 和 ?
            92: "\\", 124: "\\", 12289: "\\",65372: "\\",   // \ 和 |
            45: "-", 95: "-",   // - 和 _
            61: "=", 43: "=",   // = 和 +
            91: "[", 123: "[",12304: "[", 12300: "[", // [  { 【 「
            93: "]", 125: "]",12305: "]", 12301: "]", // ]  } 】 」
            59: ";", 58: ";",65306: ";",65307: ";",   // ; : ； ：
            39: "'", 34: "'",8216: "'", 8217: "'",    // ' " ‘ “
            96: "`", 126: "`",183: "`",  // ` 和 ~
            44: ",", 60: ",",65292: ",",12298: ",", // , < ，《 
            46: ".", 62: ".",12290: ".",12299: ".", //. > 。 》
        }
        
        if (keyMap[key]) return keyMap[key]
        
        // 字母全转为大写
        if ((key >= 65 && key <= 90) || (key >= 97 && key <= 122)) {
            if (key >= 97) {
                return String.fromCharCode(key - 32) 
            } else {
                return String.fromCharCode(key)
            }
        }
        
        // 数字0 到9
        if (key >= 48 && key <= 57) return String.fromCharCode(key)
        
        // F1到F24
        if (key >= 16777264 && key <= 16777287) return "F" + (key - 16777263)
        
        return "Unknown"
    }

    function debugKeyCode(event) {
        console.log("=== 按键调试信息 ===")
        console.log("键码 (key):", event.key)
        console.log("字符:", String.fromCharCode(event.key))
        console.log("修饰键 (modifiers):", event.modifiers)
        console.log("扫描码 (nativeScanCode):", event.nativeScanCode)
        console.log("文本 (text):", event.text)
        console.log("==================")
    }

    function hasNonModifierKey(comboString) {
        if (!comboString) return false
        
        var parts = comboString.split("+")
        for (var i = 0; i < parts.length; i++) {
            var part = parts[i].trim()
            if (part !== "Ctrl" && part !== "Shift" && part !== "Alt" && part !== "Cmd" && part !== "") {
                return true
            }
        }
        return false
    }

    function isArrowKey(keyCode) {
        return keyCode === Qt.Key_Left || 
            keyCode === Qt.Key_Right || 
            keyCode === Qt.Key_Up || 
            keyCode === Qt.Key_Down
    }

    function isSpecialFunctionKey(keyCode) {
        return keyCode === Qt.Key_Home || 
            keyCode === Qt.Key_End || 
            keyCode === Qt.Key_PageUp || 
            keyCode === Qt.Key_PageDown || 
            keyCode === Qt.Key_Insert || 
            keyCode === Qt.Key_Delete || 
            keyCode === Qt.Key_Backspace ||
            keyCode === Qt.Key_Space ||
            keyCode === Qt.Key_Escape ||
            (keyCode >= Qt.Key_F1 && keyCode <= Qt.Key_F24)  // F1-F24
    }


    contentItem: Item {

        // 可见对话框卡片：在 overlay 内居中，高度随 tab 内容平滑变化(纯 QML 动画)
        Rectangle {
            id: windowBackground
            width: windowWidth
            height: windowHeight
            anchors.centerIn: parent
            color: Colors.color_2F3032
	    radius: CommonUtils.isWindows() ? 8 : 12
            border.width: 1
            border.color: Colors.color_454649
            // 切 tab 时高度平滑过渡
            Behavior on height {
                enabled: layer.heightAnimReady
                NumberAnimation { duration: layer.panelAnimDuration; easing.type: Easing.Linear }
            }

        // 窗口级兜底点击区：置于最底层(声明最早即 z 序最低)，承接所有未被
        // 上层交互控件(tab/下拉/快捷键格/按钮等)消费的空白点击，统一取消快捷键录制激活态
        MouseArea {
            anchors.fill: parent
            hoverEnabled: false
            acceptedButtons: Qt.LeftButton
            onClicked: cancelActivation()
        }

        Shortcut {
            sequence: "Escape"
            context: Qt.WindowShortcut
            enabled: !isRecording
            onActivated: {
                if (hasUnsavedChanges) {
                    cancelPopup.open()
                } else {
                    closeWinowd()
                }
            }
        }

        WindowTitleBar{
            id: titleBar
            title: qsTr("pccut_shortcut")

            onCloseClick: {
                if (hasUnsavedChanges) {
                    cancelPopup.open()
                } else {
                    closeWinowd()
                }
            }
        }

        Rectangle {
            id: topbarRoot
            width: 216
            height: 24
            anchors {
                left: parent.left
                leftMargin: 28
                top: titleBar.bottom
                topMargin: 24
            }
            color:  Colors.transparent

            // 整条 tab 背景容器（pill），所有 tab 共用
            Rectangle {
                anchors.fill: parent
                radius: CommonUtils.isWindows() ? 4 : RadiusConfig.radius_4_12
                color: Colors.color_1F2021
            }

            // 切换时横向滑动的高亮块，宽度=单个 tab
            Rectangle {
                id: tabIndicator
                width: 72
                height: parent.height
                radius: CommonUtils.isWindows() ? 4 : RadiusConfig.radius_4_12
                color: Colors.color_454649
                x: topbar.currentIndex * width
                Behavior on x { NumberAnimation { duration: layer.panelAnimDuration; easing.type: Easing.Linear } }
            }

            TabBar {
                id: topbar
                width: parent.weight
                height: parent.height

                spacing: 0
                anchors.left:parent.left
                Component.onCompleted: contentItem.interactive = false
                onCurrentIndexChanged: {
                    macshortCutViewModel.setShortCutType(currentIndex)
                }

                background: Rectangle {
                    color: Colors.transparent
                }

                // 三个 tab 结构一致，仅文案/首尾圆角不同，用 Repeater 统一生成
                Repeater {
                    model: [
                        { text: qsTr("pccut_player"),   pos: "left" },
                        { text: qsTr("pccut_clipping"), pos: "mid" },
                        { text: qsTr("pccut_others"),   pos: "right" }
                    ]

                    TabButton {
                        width: 72
                        height: 24
                        anchors.top: parent.top
                        // 点击任意 tab(含再次点击当前 tab)都取消快捷键录制激活态
                        onClicked: cancelActivation()

                        background: Rectangle {
                            color: Colors.transparent
                        }

                        // 仅用于承载 hover 态(供文字变色)，背景视觉由上层 tabIndicator 提供。
                        // 不用 LightClipRectangle：它的 layer+OpacityMask shader 在 Windows 下拖慢点击响应，且此处全透明无视觉用途。
                        Item {
                            id: tabBackground
                            anchors.fill: parent
                            property bool hovered: false

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.NoButton
                                onEntered: parent.hovered = true
                                onExited: parent.hovered = false
                            }
                        }

                        Text {
                            id: tabText
                            font.pixelSize: 12
                            anchors.fill: parent
                            leftPadding: 8
                            rightPadding: 8
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                            horizontalAlignment: Text.AlignHCenter
                            color: (topbar.currentIndex === index || tabBackground.hovered) ? Colors.color_EEEEEE : Colors.color_999999
                            text: modelData.text
                        }

                        // 文案被省略时悬停显示完整文案
                        LightToolTip {
                            visible: tabBackground.hovered && tabText.truncated
                            tip: modelData.text
                            z: 200
                        }
                    }
                }
            }
        }
        // 切换模板（快捷键方案）下拉
        ComboBox {
            id: shortCutTypeChoose
            height: 24
            width: 128
            anchors {
                right: parent.right
                rightMargin: 28
                top: titleBar.bottom
                topMargin: 24
            }
            model: ListModel {
                ListElement { type: 0 }
                ListElement { type: 1 }
                ListElement { type: 2 }
                ListElement { type: 3 }
            }
            Component.onCompleted: currentIndex = selectShortCutType

            // 点击 combo 时：press 阶段 popup 尚未 toggle，此刻 popup.visible 反映点击前状态——
            // 未展开(即将展开)则取消快捷键录制激活态；已展开(即将收起)则不取消。
            onPressedChanged: {
                if (shortCutTypeChoose.pressed && !shortCutTypeChoose.popup.visible) {
                    cancelActivation()
                }
            }

            background: Rectangle {
                color: (shortCutTypeChoose.hovered || shortCutTypeChoose.popup.visible) ? Colors.color_68696D : Colors.color_454649
                radius: CommonUtils.isWindows() ? 4 : RadiusConfig.radius_4_88
            }

            contentItem: Text {
                leftPadding: 8
                rightPadding: shortCutTypeChoose.indicator.width + 8
                text: ShortcutConfig.getTypeTitle(selectShortCutType)
                color: Colors.color_EEEEEE
                font.pixelSize: 12
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignLeft
                verticalAlignment: Text.AlignVCenter
            }

            indicator: Image {
                x: shortCutTypeChoose.width - width - 8
                y: (shortCutTypeChoose.height - height) / 2
                width: 20
                height: 20
                sourceSize: Qt.size(20, 20)
                source: shortCutTypeChoose.popup.visible
                        ? "qrc:/icons/adjustment/icon_drop_down_menu_collapse.svg"
                        : "qrc:/icons/adjustment/icon_drop_down_menu_expand.svg"
            }

            delegate: ItemDelegate {
                width: shortCutTypeChoose.width - 8
                height: 28
                padding: 0
                contentItem: Item {
                    Image {
                        id: checkIcon
                        anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                        width: 16
                        height: 16
                        sourceSize: Qt.size(16, 16)
                        source: model.type === selectShortCutType
                                ? (CommonUtils.isWindows() ? "qrc:/icons/adjustment/icon_compose_check.svg" : "qrc:/app_qrc/icons/icon_compose_check.svg")
                                : ""
                    }
                    Text {
                        anchors {
                            left: checkIcon.right; leftMargin: 5
                            right: parent.right; rightMargin: 8
                            verticalCenter: parent.verticalCenter
                        }
                        text: ShortcutConfig.getTypeTitle(model.type)
                        color: CommonUtils.isWindows() ? Colors.color_EEEEEE : ((model.type === selectShortCutType || hovered) ? ColorsConfig.color_EEEEEE_4DFFC9 : Colors.color_EEEEEE)
                        font.pixelSize: 11
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                }
                background: Rectangle {
                    radius: CommonUtils.isWindows() ? 4 : RadiusConfig.radius_4_8
                    color: hovered ? ColorsConfig.color_68696D_4DFFC920 : Colors.transparent
                }
            }

            popup: Popup {
                y: shortCutTypeChoose.height + 4
                // 点击 combo 自身(popup 的 parent)不被此策略关闭，交给 ComboBox 内置 toggle 正常
                // 展开/收起；这样 onPressedChanged 在 press 时读到的 popup.visible 是 toggle 前的真实
                // 状态，可据此区分展开/收起。点击 combo 以外区域仍会关闭 popup。
                closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
                width: shortCutTypeChoose.width
                padding: 4
                enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 100 } }
                exit:  Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 100 } }
                contentItem: ListView {
                    clip: true
                    implicitHeight: contentHeight
                    spacing: 4
                    model: shortCutTypeChoose.popup.visible ? shortCutTypeChoose.delegateModel : null
                    currentIndex: shortCutTypeChoose.highlightedIndex
                }
                background: Rectangle {
                    radius: CommonUtils.isWindows() ? 4 : RadiusConfig.radius_4_8
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

            // 有未保存改动时不直接切换：弹确认框，由弹框决定保存后再切；显示文案由 selectShortCutType 驱动，无需回退 currentIndex
            onActivated: {
                var newType = model.get(currentIndex).type
                if (newType === selectShortCutType) return
                if (hasUnsavedChanges) {
                    pendingTemplateType = newType
                    templateSwitchPopup.open()
                } else {
                    ShortcutConfig.updateShortcutType(newType)
                    selectShortCutType = ShortcutConfig.currentShortcutType()
                    macshortCutViewModel.setShortCutType(topbar.currentIndex)
                }
            }
        }

        Rectangle { // 界面显示部分的容器
            id: content
            anchors.top: topbarRoot.bottom
            anchors.topMargin: 12
            width: parent.width
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 88
            color: Colors.transparent

            focus: true
            MouseArea {
                id: globalClickArea
                anchors.fill: parent
                z: -1
                hoverEnabled: false
                onClicked: {
                    cancelActivation()
                }
            }

            // 左右两列共用的行 delegate（结构完全一致，避免重复定义）
            Component {
                id: shortcutRowDelegate
                Rectangle {
                    width: parent ? parent.width : 0
                    height: 32
                    color: Colors.transparent

                    HoverableText {
                        anchors.left: parent.left
                        anchors.leftMargin: 28
                        anchors.verticalCenter: parent.verticalCenter
                        color: Colors.color_999999
                        // 名字占快捷键区左侧剩余空间，与快捷键区留 24px 间隔
                        maxTextWidth: Math.max(0, dynamicContent.x - 28 - 24)
                        noWarp: true
                        font.pixelSize: 12
                        text: ShortcutConfig.actionTitle(action)
                        cursorChanged: false
                    }

                    DynamicContent {
                        id: dynamicContent
                        height: 16
                        anchors.right: parent.right
                        anchors.rightMargin: 32
                        anchors.verticalCenter: parent.verticalCenter
                        actionId: action
                        opacity: isProtectedAction(action) ? 0.5 : 1.0
                        // 悬停到快捷键或清除按钮区域时，保持边框显示
                        externalHovered: comboHover.containsMouse || clearHover.containsMouse
                        onClicked: (item) => {
                            if (isProtectedAction(action)) {
                                toast.showToast(qsTr("pccut_shortcut_space_customize_warn_9"))
                                return
                            }
                            setActiveDynamicContent(item)
                        }
                        Component.onCompleted: {
                            if (pendingChanges.hasOwnProperty(action)) {
                                updateShortcutDisplayRealtime(pendingChanges[action], dynamicContent)
                            } else {
                                fillContentWithIcons(dynamicContent, ShortcutConfig.actionIcons(action), getEffectiveShortcut(action))
                            }
                        }
                    }

                    Loader {
                        width: 16
                        height: 16
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        active: true
                        // 内容极轻量(一张16x16 svg)，逐行异步孵化无收益，反而在关闭面板/切tab时
                        // 引发"孵化中context被销毁"的info提示，这里固定同步孵化
                        asynchronous: false
                        sourceComponent: btnClearComponent
                        Component {
                            id: btnClearComponent
                            Item {
                                anchors.fill: parent
                                // 显示/消失淡入淡出；完全透明时不可见也不可点击
                                opacity: (!isProtectedAction(model.action) && (dynamicContent.active || comboHover.containsMouse || clearHover.containsMouse)) ? 1 : 0
                                visible: opacity > 0
                                Behavior on opacity { NumberAnimation { duration: 100 } }
                                Image {
                                    anchors.fill: parent
                                    source: "qrc:/icons/shortcut_clean.svg"
                                    // 显示 16x16，按 32x32 栅格化以适配 win 高 DPI 缩放
                                    sourceSize: Qt.size(32, 32)
                                    fillMode: Image.PreserveAspectFit
                                    // 仅 hover（未按下）时降到 80%，按下时恢复，直接切换无动画
                                    opacity: (clearHover.containsMouse && !clearHover.pressed) ? 0.8 : 1.0
                                }
                            }
                        }
                    }

                    // 统一悬停区域：覆盖快捷键 + 间隙，避免移动时边框/大叉闪烁；
                    // NoButton 让点击穿透到下层的快捷键编辑区
                    MouseArea {
                        id: comboHover
                        anchors.left: dynamicContent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                    }

                    // 大叉专属悬停/点击区（置于最上层，可靠检测大叉自身 hover 用于变暗）
                    MouseArea {
                        id: clearHover
                        width: 16
                        height: 16
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        hoverEnabled: true
                        // 点清除大叉先取消当前录制激活态(无论激活的是本行还是其它行)，再清空本行
                        onClicked: {
                            cancelActivation()
                            clearShortcut(model.action, dynamicContent)
                        }
                    }
                }
            }
            Keys.onPressed: (event) => {
                if (!activeDynamicContent || !activeDynamicContent.active) return
                
                if (event.isAutoRepeat) {
                    event.accepted = true
                    return
                }
                
                currentCombo = buildCurrentCombo(event)
                updateShortcutDisplayRealtime(currentCombo)
                
                event.accepted = true
            }

            
            Keys.onReleased: (event) => {
                if (!activeDynamicContent || !activeDynamicContent.active) return
                if (event.isAutoRepeat) {
                    event.accepted = true
                    return
                }
                var isModifierReleased = isModifierKey(event.key)
                if (isModifierReleased) {
                    if (event.modifiers === Qt.NoModifier && currentCombo !== "") {
                        completeRecording()
                    }
                } else {
                    if (currentCombo !== "") {
                        completeRecording()
                    }
                }
                
                event.accepted = true
            }

            // 整个 tab 作为一个整体滚动（左右两列共用一个滚动条）
            Flickable {
                id: tabFlick
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.rightMargin: 4
                height: Math.min(parent.height, contentHeight)
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                contentWidth: width
                contentHeight: Math.max(page1.count, page2.count) * 32

                ScrollBar.vertical: ScrollBar {
                    id: tabScrollBar
                    policy: ScrollBar.AlwaysOn
                    // 仅当自然高度超过最大窗口高度时才显示，避免切 tab 高度动画过程中闪现
                    visible: layer.contentOverflow
                    anchors.right: parent.right
                    height: parent.height
                    contentItem: Rectangle {
                        implicitWidth: 6
                        radius: 3
                        color: tabScrollBarArea.containsMouse ? Colors.color_56575B : Colors.color_454649
                        Behavior on color {
                            ColorAnimation { duration: 200 }
                        }
                    }
                    MouseArea {
                        id: tabScrollBarArea
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                    }
                }

                // 空白区域点击取消：位于 SplitView 之下，点到快捷键/清除按钮由它们自身消费，
                // 点到列表空白处则落到此处，取消当前激活（红框）状态
                MouseArea {
                    width: tabFlick.width
                    height: tabFlick.contentHeight
                    onClicked: cancelActivation()
                }

                SplitView { // 用来做tabView效果的组件
                    width: tabFlick.width
                    height: tabFlick.contentHeight
                    orientation: Qt.Horizontal
                handle: Rectangle {
                    implicitWidth: 1
                    color: Colors.color_FFFFFF_10
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    enabled: false
                }
                Rectangle { // tab 导航栏
                    id: tabSelector
                    width: parent.width/2
                    height: parent.height
                    color: Colors.transparent
                    
                    implicitWidth: parent.width/2
                    ListView {
                        id: page1
                        anchors.fill: parent
                        interactive: false
                        clip: false
                        model: macshortCutViewModel.getLeftModel()
                        delegate: shortcutRowDelegate
                    }
                }
                Rectangle { // tab 导航页根据 preferencesLayerIndex 的值加载对应的页面
                    id: tabPage
                    width: parent.width/2
                    height: parent.height
                    color: Colors.transparent
                    ListView {
                        id: page2
                        interactive: false
                        clip: false
                        anchors.fill: parent
                        model: macshortCutViewModel.getRightModel()
                        delegate: shortcutRowDelegate
                    }
                }
            }
            }
        }

        ConfirmPopup {
            id: conflictPopup
            parent: windowBackground   // 定位到快捷键卡片而非主界面 overlay
            title: qsTr("pccut_shortcut_space_customize_warn_4")
            text:""
            leftButtonText: qsTr("pccut_draft_delete_popup_cancel")
            width:windowWidth
            height:windowHeight
            rightButtonText: qsTr("pccut_shortcut_space_customize_warn_cover")

            onLeftButtonClicked: {
                // 还原到上一次未保存的设置：有 pending 取 pending，否则取配置值；
                // 与 pendingChanges 天然对齐，避免出现显示与待保存值不一致
                var effectiveShortcut = getEffectiveShortcut(activeDynamicContent.actionId)
                updateShortcutDisplayRealtime(effectiveShortcut)
            }

            onRightButtonClicked: {
                 pendingChanges[conflictActionId] = ""
    
                pendingChanges[activeDynamicContent.actionId] = currentCombo
                
                hasUnsavedChanges = true
                confirmBtn.canUse = true
                
                var currentIndex = topbar.currentIndex
                macshortCutViewModel.setShortCutType(currentIndex)
                
            }
        }

        ConfirmPopup {
            id: cancelPopup
            parent: windowBackground   // 定位到快捷键卡片而非主界面 overlay
            title: qsTr("pccut_shortcut_space_customize_save_warn_5")
            text:qsTr("pccut_shortcut_space_customize_save_warn_6")
            leftButtonText: qsTr("pccut_draft_delete_popup_cancel")
            width:windowWidth
            height:windowHeight
            rightButtonText: qsTr("pccut_shortcut_space_customize_cancel")

            onLeftButtonClicked: {
            }

            // 右键为"放弃修改"：丢弃未保存改动后关闭，不做保存
            onRightButtonClicked: {
                cancelAllChanges()
                closeWinowd()
            }
        }

       ConfirmPopup {
            id: templateSwitchPopup
            parent: windowBackground   // 定位到快捷键卡片而非主界面 overlay
            title: qsTr("pccut_shortcut_space_customize_save_warn_5")
            text: qsTr("pccut_shortcut_space_customize_save_warn_7")
            leftButtonText: qsTr("pccut_draft_delete_popup_cancel")
            width:windowWidth
            height:windowHeight
            rightButtonText: qsTr("pccut_shortcut_space_customize_cancel")

            onLeftButtonClicked: {
                pendingTemplateType = -1
            }

            // 右键为"放弃修改"：丢弃未保存改动后再切换配置，不做保存
            onRightButtonClicked: {
                cancelAllChanges()

                ShortcutConfig.updateShortcutType(pendingTemplateType)
                selectShortCutType = ShortcutConfig.currentShortcutType()
                macshortCutViewModel.setShortCutType(topbar.currentIndex)
                pendingTemplateType = -1
            }
        }

        LightToastManager {
            id: toast
            Connections {
                target: globalSignal
                function onToast(msg, panelName) {
                    toast.showToast(msg, panelName)
                }
            }
        }
        BaseConfirmBtn {
            id: restoreDefaultBtn
            btnText:qsTr("pccut_shortcut_space_customize_recover")
            width: 88
            height: 28
            type: 1
            anchors {
                left: parent.left
                leftMargin: 28
                bottom: parent.bottom
                bottomMargin: 24
            }
            onCustomClick: () => {
                restoreDefaults()
            }
        }
        BaseConfirmBtn {
            id: cancelBtn
            btnText:qsTr("pccut_draft_delete_popup_cancel")
            width: 88
            height: 28
            type: 1
            anchors {
                right: parent.right
                rightMargin: 28
                bottom: parent.bottom
                bottomMargin: 24
            }
            onCustomClick:() => {
                if (hasUnsavedChanges) {
                    cancelPopup.open()
                } else {
                    closeWinowd()
                }
            }
        }
        BaseConfirmBtn {
            id: confirmBtn
            btnText:qsTr("pccut_shortcut_space__customize_save")
            canUse: hasUnsavedChanges
            width: 88
            height: 28
            type: 0
            anchors {
                right: cancelBtn.left
                rightMargin: 16
                bottom: parent.bottom
                bottomMargin: 24
            }
            onCustomClick: () => {
                if (hasUnsavedChanges) {
                    saveAllChanges()
                    closeWinowd()
                }
            }
        }
        }
    }
}
