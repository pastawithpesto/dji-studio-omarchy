import QtQuick 2.15
import QtQuick.Controls
import Config 1.0
import Controls 1.0
import Qt5Compat.GraphicalEffects
import HighlightTaskStatus 1.0

Rectangle {
    id: root
    width: 20  // 注意size会变
    height: 20
    color: Colors.transparent
    
    // ========== 状态说明 ==========
    // 注：使用 HighlightTaskStatus 枚举，不再定义本地常量
    // HighlightTaskStatus.UNKNOW (0)   - 未知状态
    // HighlightTaskStatus.INIT (1)     - 准备就绪，未开始分析
    // HighlightTaskStatus.PENDING (2)  - 等待中（多任务排队时）
    // HighlightTaskStatus.RUNNING (3)  - 正在运行
    // HighlightTaskStatus.PAUSED (4)   - 已暂停
    // HighlightTaskStatus.CANCELED (5) - 已取消
    // HighlightTaskStatus.SUCCESS (6)  - 成功
    // HighlightTaskStatus.FAILED (7)   - 失败
    
    // ========== 对外接口 ==========
    property string filePath: ""     // 素材路径
    property string videoId: "" //视频唯一标识：md5
    property bool isHovered: false   // 是否鼠标悬浮（由父组件传入）
    readonly property int currentState: internal.currentState  // 暴露当前状态
    readonly property bool selfHovered: mouseArea.containsMouse  // 暴露按钮自身的 hover 状态

    property string eventTrackingHighlightTag: ""  // 高光分析埋点

    // ========== 内部状态 ==========
    QtObject {
        id: internal
        
        // 当前状态（默认为 INIT）
        property int currentState: HighlightTaskStatus.INIT
        
        // 当前进度 (0-100)
        property real currentProgress: 0
    }

    onVideoIdChanged: {
        updateInternalState()
    }

    function updateInternalState() {
        if (root.videoId === "") {
            return;
        }
        // 1. 检查是否已有高光数据
        if (highlightManager.hasMediaHighlights(root.videoId)) {
            internal.currentState = HighlightTaskStatus.SUCCESS;
            return;
        }
        
        var status = highlightManager.taskStatus(root.videoId);

        // 2. 检查是否有正在进行的任务
        if (highlightManager.isTaskStarted(root.videoId)) {
            var progress = highlightManager.taskProgress(root.videoId);
            // 直接使用任务状态
            internal.currentState = status;
            // 如果是 RUNNING 或 PAUSED，恢复进度
            if (status === HighlightTaskStatus.RUNNING || status === HighlightTaskStatus.PAUSED) {
                internal.currentProgress = progress * 100;
            }
            return;
        }

        // 3. 任务失败，展示为重试icon
        if (status === HighlightTaskStatus.FAILED) {
            // 直接使用任务状态
            internal.currentState = status;
            return
        }

        // 默认为 INIT 状态
        internal.currentState = HighlightTaskStatus.INIT;
    }
    
    // ========== 可见性控制 ==========
    visible: {
        var state = internal.currentState;
        
        // Success/Running/Paused/Pending/INIT 状态常驻显示
        if (state === HighlightTaskStatus.SUCCESS || 
            state === HighlightTaskStatus.RUNNING || 
            state === HighlightTaskStatus.PAUSED ||
            state === HighlightTaskStatus.PENDING ||
            state === HighlightTaskStatus.INIT) {
            return true;
        }
        
        // Failed 状态：外部 hover 或内部 hover 时显示
        return !(root.videoId.length === 0) && (isHovered || mouseArea.containsMouse);
    }
    
    // ========== UI 层 ==========
    
    // 圆形进度条 (Running/Pending 状态)
    Item {
        id: progressCircle
        anchors.fill: parent
        visible: {
            var state = internal.currentState;
            var isHovered = mouseArea.containsMouse;
            
            // RUNNING 状态：非 hover 时显示进度环，hover 时显示暂停图标
            if (state === HighlightTaskStatus.RUNNING) {
                return !isHovered;
            }

            return false;
        }

        Rectangle {
            anchors.fill: parent
            radius: 4
            color: Colors.color_000000_50
        }
        
        Canvas {
            id: canvas
            anchors.fill: parent
            anchors.margins: 3
            onPaint: {
                var ctx = getContext("2d");
                var centerX = width / 2;
                var centerY = height / 2;
                var radius = width / 2 - 1;
                var lineWidth = 1.5;
                
                ctx.clearRect(0, 0, width, height);
                
                // 进度圆弧
                var startAngle = -Math.PI / 2;
                // PENDING 状态显示 0% 进度
                var progress = (internal.currentProgress);
                var endAngle = startAngle + (2 * Math.PI * progress / 100);
                
                ctx.beginPath();
                ctx.arc(centerX, centerY, radius, startAngle, endAngle);
                ctx.strokeStyle = Colors.color_EEEEEE;
                ctx.lineWidth = lineWidth;
                ctx.lineCap = "butt";
                ctx.stroke();
            }
        }

        Text {
            anchors.fill: parent
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: {
                var finalProgress = Math.round(internal.currentProgress)
                return finalProgress < 100 ? (finalProgress >= 0 ? finalProgress : 0) : 99
            }
            font.pixelSize: 6
            font.weight: Font.DemiBold
            color: Colors.color_EEEEEE
        }
        
        Connections {
            target: internal
            function onCurrentProgressChanged() {
                canvas.requestPaint();
            }
            // 状态变化时也重绘（PENDING → RUNNING 切换）
            function onCurrentStateChanged() {
                canvas.requestPaint();
            }
        }
    }
    
    // 图标层
    Image {
        id: iconImage
        anchors.fill: parent
        visible: !progressCircle.visible
        
        source: {
            var state = internal.currentState;
            var buttonHovered = mouseArea.containsMouse;  // 使用按钮内部的 hover
            
            if (state === HighlightTaskStatus.INIT) {
                return "qrc:/icons/highlight/icon_hl_ready.svg";
            } else if (state === HighlightTaskStatus.RUNNING && buttonHovered) {
                // Running 状态 hover 按钮时显示暂停图标（替换进度条）
                return "qrc:/icons/highlight/icon_hl_pause.svg";
            } else if (state === HighlightTaskStatus.PAUSED) {
                // Paused 状态 hover 按钮时显示恢复图标
                return buttonHovered ? "qrc:/icons/highlight/icon_hl_resume.svg" 
                                     : "qrc:/icons/highlight/icon_hl_pause.svg";
            } else if (state === HighlightTaskStatus.SUCCESS) {
                return "qrc:/icons/highlight/icon_hl_success.svg";
            } else if (state === HighlightTaskStatus.FAILED) {
                return "qrc:/icons/highlight/icon_hl_fail.svg";
            } else if (state === HighlightTaskStatus.PENDING) {
                return "qrc:/icons/highlight/icon_hl_pending.svg"
            }
            return "";
        }
    }
    
    // ========== 交互层 ==========
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.ArrowCursor
        
        // PENDING 状态时禁用点击
        enabled: internal.currentState !== HighlightTaskStatus.PENDING

        // 防止重复点击
        property bool isProcessing: false

        onContainsMouseChanged: {
            //console.log("[HighlightButton] containsMouse:", containsMouse, "state:", internal.currentState)
        }

        onClicked: {
            if (isProcessing) return;

            var state = internal.currentState;

            if (state === HighlightTaskStatus.INIT) {
                // INIT → RUNNING: 启动高光任务
                //console.log("[HighlightButton] Starting task for:", filePath);
                var success = highlightManager.startTask(root.videoId, filePath);
                highlightManager.eventTrackingStart(eventTrackingHighlightTag);  // 高光分析埋点
            } else if (state === HighlightTaskStatus.RUNNING) {
                // RUNNING → PAUSED: 暂停任务
                //console.log("[HighlightButton] Pausing task");
                // TODO: 等 highlightManager.pauseTask() 功能实现后启用
                var success = highlightManager.pauseTask(root.videoId);
                internal.currentState = HighlightTaskStatus.PAUSED;
            } else if (state === HighlightTaskStatus.PAUSED) {
                // PAUSED → RUNNING: 恢复任务
                //console.log("[HighlightButton] Resuming task");
                // TODO: 等 highlightManager.resumeTask() 功能实现后启用
                var success = highlightManager.resumeTask(root.videoId);
                internal.currentState = HighlightTaskStatus.RUNNING;
            } else if (state === HighlightTaskStatus.FAILED) {
                // FAILED → RUNNING: 重试
                //console.log("[HighlightButton] Retrying task");
                // TODO: 等 highlightManager 重试功能实现后启用
                highlightManager.startTask(root.videoId, filePath);
                internal.currentProgress = 0
                internal.currentState = HighlightTaskStatus.RUNNING;
            } else if (state === HighlightTaskStatus.PENDING) {
                // lex-TODO: 等待状态点击行为待产品确认
                //console.log("[HighlightButton] PENDING state clicked - no action defined");
            } else if (state === HighlightTaskStatus.CANCELED) {
                // lex-TODO: 取消状态点击行为待产品确认
                //console.log("[HighlightButton] CANCELED state clicked - no action defined");
            }
            // SUCCESS 状态：不允许重新分析，无操作

            // 防抖处理
            isProcessing = true;
            debounceTimer.start();
        }
    }

    // INIT 状态的 Tooltip
    LightToolTip {
        visible: mouseArea.containsMouse && internal.currentState === HighlightTaskStatus.INIT
        x: (root.width / 2) - (width / 2)
        width: 185
        tip: qsTr("pccut_home_highlight_tip")
        textWrapMode: Text.WordWrap

        onVisibleChanged: {
            //console.log("[HighlightButton] Tooltip visible:", visible)
        }
    }
    
    // SUCCESS 状态的 Tooltip
    LightToolTip {
        visible: mouseArea.containsMouse && internal.currentState === HighlightTaskStatus.SUCCESS
        x: (root.width / 2) - (width / 2)
        y: 26
        tip: qsTr("pccut_home_highlight_success")
        textWrapMode: Text.WordWrap
    }
    
    Timer {
        id: debounceTimer
        interval: 500
        onTriggered: mouseArea.isProcessing = false
    }
    
    // ========== 监听任务状态变化 ==========
    Connections {
        target: highlightManager
        
        function onTaskStatusChanged(md5, status) {
            if (md5 !== root.videoId) return;
            
            //console.log("[HighlightButton] Task status changed:", status);
            
            // 任务被取消后，自动重置为 INIT 状态（允许重新启动）
            if (status === HighlightTaskStatus.CANCELED) {
                internal.currentState = HighlightTaskStatus.INIT;
                internal.currentProgress = 0;  // 重置进度
                //console.log("[HighlightButton] Task canceled, reset to INIT state");
            } else {
                // 直接赋值，状态值完全对应
                internal.currentState = status;
            }
        }
        
        function onTaskProgressChanged(md5, progress) {
            // 详细日志：不过滤，全部打印
            //console.log("[进度信号接收] md5=" + md5 + 
            //            ", progress=" + (progress * 100).toFixed(2) + "%" +
             //           ", root.videoId=" + root.videoId +
            //            ", match=" + (md5 === root.videoId));
            
            if (md5 !== root.videoId) {
             //   console.warn("[进度信号] MD5 不匹配，忽略此进度更新");
                return;
            }
            
            // 更新进度（0-1.0 转换为 0-100）
            internal.currentProgress = (progress < 1 ? progress : 0.99) * 100;
            //console.log("[HighlightButton] Progress updated:", internal.currentProgress);
        }
        
        function onMediaHighlightChanged(md5List) {
            // 检查列表中是否包含当前文件的md5
            // QML中QStringList会被暴露为JS数组，可以使用indexOf()
            if (md5List.indexOf(root.videoId) === -1) {
                return;
            }

            //console.log("[HighlightButton] Highlight data changed for:", root.videoId);
            internal.currentState = HighlightTaskStatus.SUCCESS;
        }
    }
    
    // ========== 初始化检查 ==========
    Component.onCompleted: {
        updateInternalState()
    }
}
