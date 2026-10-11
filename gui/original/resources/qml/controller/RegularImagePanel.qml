import QtQuick 2.15
import QtQuick.Controls
import Config 1.0
import Controls 1.0
import Nova 1.0

/**
 * @author: mathy.shi
 * @details 普通（非全景）视频素材的【画面】设置面板：目前只承载 ND 滤镜入口
 */
Rectangle {
    id: panel
    property var projectId: draftManager.activeProjectEnvId()

    color: Colors.color_content_area_background

    NdFilterViewModel {
        id: ndController
    }

    // 顶部分割线
    Rectangle {
        id: topDivider
        color: Colors.color_141414
        width: parent.width
        height: 1
    }

    ScrollView {
        id: scrollView
        anchors {
            left: parent.left
            right: parent.right
            top: topDivider.bottom
            bottom: parent.bottom
            leftMargin: 12
            rightMargin: 12
            topMargin: 16
        }
        ScrollBar.vertical.policy: ScrollBar.AlwaysOff
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        clip: true
        contentHeight: ndSetting.height

        NdFilterSetting {
            id: ndSetting
            width: scrollView.width
            anchors.left: parent.left
            controller: ndController
            projectId: panel.projectId
            // 标题行高度对齐到音频面板"音量"标签行（20px），让 ND 标题文字与之等齐
            headerHeight: 20
            // 不在本层做可见性判定 —— SettingPanel.refreshUI() 中已用
            // canUseNdFilterInCurClipForRegularVideo() 决定是否 addTab(regularImageTab)。
            // 再加 visible 绑定会踩 QML binding 拓扑顺序坑：ndController.videoSourceModel
            // 与 ndSetting.visible 互不依赖，evaluate 顺序未定义，实测 visible 先求值时
            // ndController._videoSourceModel 还是 null，导致 visible 永远 false。
        }
    }

    // 顶层 MouseArea：拦截整个画面 Tab 内的所有 press，强制清除 ND 数值 TextField 的焦点。
    // 必须放在 ScrollView 之后（源码顺序在后 → z 在上）才能先于子元素接到 press。
    // propagateComposedEvents + mouse.accepted=false 保证点击继续穿透到底层的
    // 滑杆 / 开关 / 按钮 / TextField，不会破坏原有交互。
    // hoverEnabled=false 让 hover 事件直通，否则会遮挡 reset/useInAll 等图标的 hover 效果。
    MouseArea {
        anchors.fill: parent
        z: 999
        hoverEnabled: false
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        propagateComposedEvents: true
        onPressed: function(mouse) {
            panel.forceActiveFocus()
            mouse.accepted = false
        }
    }
}
