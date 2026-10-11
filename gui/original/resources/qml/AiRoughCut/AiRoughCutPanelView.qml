import QtQuick 2.15
import QtQuick.Controls
import Config 1.0
import AiRoughCut 1.0
import UIComponent

UIDialog {
    id: roughCutPanel
    title: qsTr("pccut_roughcut_title")
    width: 600
    height: 473
    closeOnMaskClick: false
    maskColor: "#80000000"

    property var context: viewModel.context
    property var viewModel: AiRoughCutPanelViewModel { }

    // 动态创建的 spinner 引用
    property Item _spinnerItem: null

    Component.onCompleted: {
        if (viewModel.logoutPending) {
            // 退出登录触发：隐藏面板内容（enter 动画会覆盖 opacity，所以用 visible 隐藏）
            background.visible = false
            contentItem.visible = false
            open()
            showLogoutDialog()
        } else if (context && context.step === AiRoughCutContext.StepPreparing) {
            // 准备中状态：面板打开提供遮罩，但隐藏面板卡片，显示独立 spinner
            open()
            roughCutPanel.opacity = 0
            _createSpinner()
        } else if (context && context.status === AiRoughCutContext.StatusFailed) {
            // 已有失败状态（如从后台恢复）：隐藏打开面板，直接弹错误
            roughCutPanel.opacity = 0
            open()
            showFailedPopup()
        } else {
            open()
        }
    }

    onOpened: {
        viewModel.notifyPanelOpened()
    }

    onSigClosed: {
        if (_closingForError || _closingForResult || _closingForCancel) return

        if (context && context.isInBackground) {
            // 收至后台触发的关闭，不拦截
            _destroySpinner()
            return
        }

        if (context && context.step === AiRoughCutContext.StepLoading) {
            if (!_cancelConfirmShowing) {
                // Esc/X 关闭面板时拦截：隐藏面板 + 弹取消确认
                // 延迟一帧 open 以确保无论 Esc（已 close）还是 X（sigClosed 后紧跟 close）
                // popup 最终都处于 open 状态，避免 msgBoxHost 失去宿主
                _closingForCancel = true
                roughCutPanel.opacity = 0
                Qt.callLater(function() {
                    roughCutPanel.open()
                    showClosedConfirm()
                })
            }
        } else {
            _destroySpinner()
            roughCutPanel.viewModel.closePanel()
        }
    }

    // ===== 准备中 spinner 动态创建/销毁 =====
    Component {
        id: preparingSpinnerComp
        Rectangle {
            width: 248
            height: 156
            anchors.centerIn: parent
            radius: 8
            clip: true
            color: Colors.color_2F3032
            border.width: 1
            border.color: Colors.color_454649

            Image {
                id: _spinIcon
                anchors {
                    top: parent.top
                    topMargin: 39
                    horizontalCenter: parent.horizontalCenter
                }
                width: 48
                height: 48
                source: "qrc:/icons/icon_loading.png"
                sourceSize: Qt.size(48, 48)

                RotationAnimation on rotation {
                    from: 0
                    to: 360
                    running: true
                    duration: 2000
                    loops: Animation.Infinite
                }
            }

            Text {
                anchors.top: _spinIcon.bottom
                anchors.topMargin: 12
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("pccut_loading_done_start")
                font.pixelSize: 14
                color: Colors.color_FFFFFF
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    function _createSpinner() {
        if (!_spinnerItem) {
            _spinnerItem = preparingSpinnerComp.createObject(Overlay.overlay)
        }
    }

    function _destroySpinner() {
        if (_spinnerItem) {
            _spinnerItem.destroy()
            _spinnerItem = null
        }
    }

    // 从 preparing 切到 input：销毁 spinner，显示面板
    function _onPreparingFinished() {
        _destroySpinner()
        roughCutPanel.opacity = 1
    }

    // 准备中状态超时兜底（10s）
    Timer {
        id: preparingTimeoutTimer
        interval: 10000
        running: context && context.step === AiRoughCutContext.StepPreparing
        onTriggered: {
            _destroySpinner()
            roughCutPanel.viewModel.closePanel()
        }
    }

    Loader {
        id: pageLoader
        anchors.fill: parent
        sourceComponent: {
            if (!context) return inputPageComponent
            switch (context.step) {
            case AiRoughCutContext.StepInput: return inputPageComponent;
            case AiRoughCutContext.StepLoading: return loadingPageComponent;
            default: return inputPageComponent;
            }
        }
    }

    Component {
        id: inputPageComponent
        AiRoughCutInputView {
            viewModel: roughCutPanel.viewModel.inputVM
            context: roughCutPanel.context
        }
    }

    Component {
        id: loadingPageComponent
        AiRoughCutLoadingView {
            viewModel: roughCutPanel.viewModel.loadingVM
            context: roughCutPanel.context
        }
    }

    // UIMessageBox 弹窗调度器
    UIMessageBoxHost { id: msgBoxHost }

    // 防止取消确认弹窗重复弹出
    property bool _cancelConfirmShowing: false
    // 弹窗期间跳过 onSigClosed 逻辑的标志
    property bool _closingForError: false
    property bool _closingForResult: false
    property bool _closingForCancel: false

    // 恢复面板可见状态
    function _restorePanel() {
        roughCutPanel.opacity = 1
        _closingForError = false
        _closingForResult = false
        _closingForCancel = false
    }

    // ===== 取消确认弹窗（执行中点 返回 时显示）=====
    function showCancelConfirm() {
        _cancelConfirmShowing = true
        msgBoxHost.show({
            title: qsTr("pccut_roughcut_cancel_dialog_title"),
            text: qsTr("pccut_end_analysis_back"),
            buttonMaxWidth: 88,
            buttons: [
                { text: qsTr("pccut_previous_step"), role: "return", type: UIButtonType.Light },
                { text: qsTr("pccut_roughcut_cancel_dialog_bg"), role: "background", type: UIButtonType.Brand }
            ],
            onClosed: function(role) {
                _cancelConfirmShowing = false
                if (role === "return") {
                    roughCutPanel.viewModel.loadingVM.cancel()
                    _closingForCancel = false
                    _restorePanel()
                } else if (role === "background") {
                    _closingForCancel = false
                    roughCutPanel.viewModel.minimizeToBackground()
                } else {
                    // Esc 等其他方式关闭：恢复面板
                    _restorePanel()
                }
            }
        })
    }

    // ===== 关闭确认弹窗（执行中点 X 时显示）=====
    function showClosedConfirm() {
        _cancelConfirmShowing = true
        msgBoxHost.show({
            title: qsTr("pccut_roughcut_cancel_dialog_title"),
            text: qsTr("pccut_exit_confirm_tip"),
            buttonMaxWidth: 88,
            buttons: [
                { text: qsTr("pccut_confirm_exit"), role: "exit", type: UIButtonType.Light },
                { text: context.status === AiRoughCutContext.StatusSuccess ? qsTr("pccut_process_later") : qsTr("pccut_roughcut_cancel_dialog_bg"),
                    role: "background", type: UIButtonType.Brand }
            ],
            onClosed: function(role) {
                _cancelConfirmShowing = false
                if (role === "exit") {
                    roughCutPanel.viewModel.loadingVM.cancel()
                    _closingForCancel = false
                    _restorePanel()
                } else if (role === "background") {
                    _closingForCancel = false
                    roughCutPanel.viewModel.minimizeToBackground()
                } else {
                    // Esc 等其他方式关闭：恢复面板
                    _restorePanel()
                }
            }
        })
    }

    Connections {
        target: roughCutPanel.viewModel.loadingVM
        function onCancelConfirmRequested() {
            // 从 loading 页触发，面板此时仍打开，隐藏后弹窗
            _closingForCancel = true
            roughCutPanel.opacity = 0
            showCancelConfirm()
        }
    }

    // ===== 一类错误弹窗：解析失败（可返回上一步重新分析）=====
    function showErrorRetryable() {
        var isTimeout = context && context.errorType === AiRoughCutContext.ErrorTypeTimeout
        msgBoxHost.show({
            title: isTimeout ? qsTr("pccut_roughcut_error1_timeout_title") : qsTr("pccut_roughcut_error1_fail_title"),
            text: isTimeout
                  ? qsTr("pccut_roughcut_error1_timeout_desc")
                  : qsTr("pccut_roughcut_error1_fail_desc"),
            buttonMaxWidth: 88,
            buttons: [
                { text: qsTr("pccut_roughcut_error1_abandon"), role: "abandon", type: UIButtonType.Light },
                { text: qsTr("pccut_roughcut_error1_back"), role: "goBack", type: UIButtonType.Brand }
            ],
            onClosed: function(role) {
                if (role === "abandon") {
                    _closingForError = false
                    roughCutPanel.viewModel.closePanel()
                } else {
                    // goBack / Esc：恢复面板回到输入页
                    if (context) {
                        context.status = AiRoughCutContext.StatusIdle
                        context.step = AiRoughCutContext.StepInput
                    }
                    _restorePanel()
                }
            }
        })
    }

    // ===== 二类错误弹窗：素材问题（需退出重选素材）=====
    function showErrorMaterial() {
        var isMaterialIssue = context && context.errorType === AiRoughCutContext.ErrorTypeMaterialContent
        msgBoxHost.show({
            title: isMaterialIssue ? qsTr("pccut_roughcut_error2_material_title") : qsTr("pccut_roughcut_error2_fail_title"),
            text: isMaterialIssue
                  ? qsTr("pccut_roughcut_error2_material_desc")
                  : qsTr("pccut_roughcut_error2_fail_desc"),
            buttonMaxWidth: 88,
            buttons: [
                { text: qsTr("pccut_roughcut_error2_confirm"), role: "acknowledge", type: UIButtonType.Brand }
            ],
            onClosed: function(role) {
                _closingForError = false
                roughCutPanel.viewModel.closePanel()
            }
        })
    }

    // ===== 失败弹窗入口 =====
    function showFailedPopup() {
        if (!context) return
        // 隐藏面板（保留窗口层级），再弹错误弹窗
        _closingForError = true
        roughCutPanel.opacity = 0
        if (context.errorCategory === AiRoughCutContext.ErrorRetryable) {
            showErrorRetryable()
        } else if (context.errorCategory === AiRoughCutContext.ErrorMaterialInvalid) {
            showErrorMaterial()
        }
    }

    // ===== 退出登录弹窗 =====
    function showLogoutDialog() {
        _closingForError = true
        roughCutPanel.opacity = 0
        msgBoxHost.show({
            title: qsTr("pccut_login_tip"),
            text: qsTr("pccut_task_stopped_logout"),
            buttonMaxWidth: 88,
            buttons: [
                { text: qsTr("pccut_roughcut_error2_confirm"), role: "acknowledge", type: UIButtonType.Light },
                { text: qsTr("pccut_login_now"), role: "login", type: UIButtonType.Brand }
            ],
            onClosed: function(role) {
                _closingForError = false
                roughCutPanel.viewModel.closePanel()
                if (role === "login") {
                    roughCutPanel.viewModel.requestLogin()
                }
            }
        })
    }

    // ===== 结果弹窗：AI 解析完成 =====
    function showResultPopup() {
        if (!context) return
        // 隐藏面板（保留窗口层级），再弹结果弹窗
        _closingForResult = true
        roughCutPanel.opacity = 0

        var btns = []
        if (draftManager.currentDraft !== -1) {
            btns.push({ text: qsTr("pccut_roughcut_result_append"), role: "insertTail", type: UIButtonType.Light })
        }
        btns.push({ text: qsTr("pccut_roughcut_result_new_draft"), role: "newDraft", type: UIButtonType.Brand })

        msgBoxHost.show({
            title: qsTr("pccut_roughcut_result_title"),
            text: qsTr("pccut_roughcut_result_desc"),
            buttons: btns,
            buttonMaxWidth: 88,
            onClosed: function(role) {
                if (role === "insertTail") {
                    roughCutPanel.viewModel.resultVM.insertToTail()
                } else if (role === "newDraft") {
                    roughCutPanel.viewModel.resultVM.createNewDraft()
                }
                _closingForResult = false
                roughCutPanel.viewModel.closePanel()
            }
        })
    }

    Connections {
        target: context
        function onStatusChanged() {
            if (context.status === AiRoughCutContext.StatusFailed && !context.isInBackground) {
                roughCutPanel.showFailedPopup()
            }
        }
        function onIsInBackgroundChanged() {
            if (!context.isInBackground && context.status === AiRoughCutContext.StatusFailed) {
                roughCutPanel.showFailedPopup()
            }
        }
        function onStepChanged() {
            if (context.step === AiRoughCutContext.StepInput && roughCutPanel._spinnerItem) {
                // 从 preparing(-1) 切到 input(0)：显示面板
                roughCutPanel._onPreparingFinished()
            }
            if (context.step === AiRoughCutContext.StepResult && context.status !== AiRoughCutContext.StatusFailed) {
                roughCutPanel.showResultPopup()
            }
        }
    }

    // ===== 退出登录信号（面板已打开时触发） =====
    Connections {
        target: roughCutPanel.viewModel
        function onLoggedOut() {
            showLogoutDialog()
        }
    }
}
