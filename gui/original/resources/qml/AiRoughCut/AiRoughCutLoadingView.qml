import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.15
import Config 1.0
import Controls 1.0
import UIComponent
import AiRoughCut 1.0

/**
 * 执行中页：可滚动内容区（步骤逐步展示）+ 固定底部按钮
 * 每个步骤完成后打勾显示内容，正在执行的显示"...正在xxx xx%"，未开始的不显示
 */
Item {
    id: root

    property var context: null
    property var viewModel: null

    // 自动滚动到底部
    function scrollToBottom() {
        if (contentFlickable.contentHeight > contentFlickable.height) {
            contentFlickable.contentY = contentFlickable.contentHeight - contentFlickable.height;
        }
    }

    // 监听步骤列表变化自动滚动
    Connections {
        target: contentFlickable
        function onContentHeightChanged() {
            Qt.callLater(root.scrollToBottom);
        }
    }

    // ===== 可滚动内容区 =====
    Flickable {
        id: contentFlickable
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.leftMargin: 28
        anchors.right: parent.right
        anchors.rightMargin: 2
        anchors.bottom: bottomBar.top
        anchors.bottomMargin: 32
        contentHeight: contentColumn.height + 24  // 24 = contentColumn.anchors.topMargin
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        // 点击空白区域让 TextArea 失焦
        MouseArea {
            anchors.fill: parent
            z: -1
            onClicked: contentFlickable.forceActiveFocus()
        }

        ScrollBar.vertical: UIScrollBar {
            policy: ScrollBar.AlwaysOn
        }

        ColumnLayout {
            id: contentColumn
            anchors.top: parent.top
            anchors.topMargin: 24
            width: contentFlickable.width - 26
            spacing: 24

            // ===== 跳过素材弱提示 =====
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 12
                visible: context && (context.unsupportedTypeCount > 0 || context.durationTooShortCount > 0)

                Row {
                    spacing: 8
                    width: Math.min(implicitWidth, contentColumn.width)

                    UIIcon {
                        source: "qrc:/icons/roughcut/roughcut_loading_finish.svg";
                        iconSize: 12
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    UIText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, contentColumn.width - 20)
                        text: qsTr("pccut_aicut_analyze_filter")
                        type: UITextType.Primary
                        size: UIControlSize.M
                        elide: Text.ElideRight
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    color: Colors.color_262728
                    radius: 8
                    implicitHeight: filterMsgText.height + 24

                    UIText {
                        id: filterMsgText
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 12
                        type: UITextType.Secondary
                        size: UIControlSize.M
                        wrapMode: Text.WordWrap
                        text: {
                            var parts = []
                            if (context && context.unsupportedTypeCount > 0)
                                parts.push(qsTr("pccut_roughcut_duration_limit_toast_1").arg(context.unsupportedTypeCount))
                            if (context && context.durationTooShortCount > 0)
                                parts.push(qsTr("pccut_roughcut_duration_skip_short_toast").arg(context.durationTooShortCount))
                            return parts.join(qsTr("，"))
                        }
                    }
                }
            }

            // 动态渲染步骤列表
            Repeater {
                model: context.executeTipInfoList

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    // === 已完成步骤：✓ + 文字 ===
                    Row {
                        spacing: 8
                        visible: modelData && modelData.status === AiRoughCutExecuteTipInfo.TipCompleted

                        UIIcon {
                            source: "qrc:/icons/roughcut/roughcut_loading_finish.svg";
                            iconSize: 12
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        UIText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData ? modelData.stepName : ""
                            type: UITextType.Primary
                            size: UIControlSize.M
                        }
                    }

                    // === 已完成步骤内容卡片（content 非空时显示） ===
                    Rectangle {
                        id: stepCard
                        Layout.fillWidth: true
                        // Layout.leftMargin: 20
                        visible: modelData && modelData.status === AiRoughCutExecuteTipInfo.TipCompleted && modelData.stepDesc.length > 0
                        color: Colors.color_262728
                        radius: 8
                        // 用 contentColumn.width 直接算文本宽度，打断布局循环
                        property real _textAvailableWidth: contentColumn.width - 24
                        implicitHeight: Math.min(descText.implicitHeight + 24, 160)

                        Flickable {
                            id: contentScroll
                            anchors.fill: parent
                            anchors.margins: 12
                            clip: true
                            contentHeight: descText.implicitHeight
                            boundsBehavior: Flickable.StopAtBounds
                            interactive: contentHeight > height

                            ScrollBar.vertical: UIScrollBar {
                                policy: contentScroll.interactive ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                            }

                            UIText {
                                id: descText
                                width: stepCard._textAvailableWidth
                                text: modelData ? modelData.stepDesc : ""
                                type: UITextType.Secondary
                                size: UIControlSize.M
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    // === 正在执行步骤：流光效果（圆点 + 文字） ===
                    Item {
                        visible: modelData && modelData.status === AiRoughCutExecuteTipInfo.TipInProgress
                        width: shimmerRow.width
                        height: 20

                        Row {
                            id: shimmerRow
                            spacing: 8

                            // 三个圆点
                            Row {
                                spacing: 4
                                anchors.verticalCenter: parent.verticalCenter

                                Repeater {
                                    model: 3
                                    delegate: Rectangle {
                                        width: 3
                                        height: 3
                                        radius: 1.5
                                        color: Colors.color_FFFFFF
                                    }
                                }
                            }

                            UIText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData ? modelData.stepName : ""
                                type: UITextType.Primary
                                size: UIControlSize.M
                            }
                        }

                        // 流光 ShaderEffect
                        layer.enabled: true
                        layer.effect: ShaderEffect {
                            property real shimmerPos: 0.0
                            fragmentShader: "qrc:/qml/AiRoughCut/shaders/shimmer.frag.qsb"

                            NumberAnimation on shimmerPos {
                                from: -0.3
                                to: 1.3
                                duration: 1200
                                loops: Animation.Infinite
                            }
                        }
                    }
                }
            }

            // ===== 等待下一步的三点动画 =====
            // 最后一个 tip 已完成且没有 running 状态的 tip 时显示
            Item {
                visible: {
                    if (!context || context.executeTipInfoList.length === 0) return false;
                    var list = context.executeTipInfoList;
                    var lastTip = list[list.length - 1];
                    if (lastTip.status !== AiRoughCutExecuteTipInfo.TipCompleted) return false;
                    // 确认没有 running 的
                    for (var i = 0; i < list.length; i++) {
                        if (list[i].status === AiRoughCutExecuteTipInfo.TipInProgress) return false;
                    }
                    // 任务还在执行中（非成功/失败终态）
                    return context.status === AiRoughCutContext.StatusIdle;
                }
                width: waitingRow.implicitWidth
                height: 20

                Row {
                    id: waitingRow
                    spacing: 8
                    anchors.verticalCenter: parent.verticalCenter

                    Row {
                        id: waitingDots
                        spacing: 4
                        anchors.verticalCenter: parent.verticalCenter

                        Repeater {
                            model: 3
                            delegate: Rectangle {
                                width: 3
                                height: 3
                                radius: 1.5
                                color: Colors.color_FFFFFF
                            }
                        }
                    }

                    UIText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("pccut_analyzing_background")
                        type: UITextType.Primary
                        size: UIControlSize.M
                    }
                }

                // 流光 ShaderEffect
                layer.enabled: true
                layer.effect: ShaderEffect {
                    property real shimmerPos: 0.0
                    fragmentShader: "qrc:/qml/AiRoughCut/shaders/shimmer.frag.qsb"

                    NumberAnimation on shimmerPos {
                        from: -0.3
                        to: 1.3
                        duration: 1200
                        loops: Animation.Infinite
                    }
                }
            }

            // ===== AI Agent 消息流（深色卡片包裹） =====
            Rectangle {
                Layout.fillWidth: true
                visible: context.agentMessages.length > 0
                color: Colors.color_262728
                radius: 8
                implicitHeight: agentMsgColumn.height + 24

                ColumnLayout {
                    id: agentMsgColumn
                    anchors.left: parent.left
                    anchors.right: parent.right 
                    anchors.top: parent.top
                    anchors.margins: 16

                    Repeater {
                        model: context.agentMessages

                        UIText {
                            Layout.fillWidth: true
                            text: modelData || ""
                            type: UITextType.Secondary
                            size: UIControlSize.M
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }
        }
    }

    // ===== 固定底部按钮栏 =====
    RowLayout {
        id: bottomBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 28
        anchors.rightMargin: 28
        anchors.bottomMargin: 20
        height: 36
        spacing: 8

        // 取消按钮
        UIButton {
            Layout.alignment: Qt.AlignVCenter
            type: UIButtonType.Light
            size: UIControlSize.L
            text: qsTr("pccut_previous_step")
            onClicked: viewModel.requestCancelConfirm()
        }

        Item { Layout.fillWidth: true }

        // 分析中：收至后台分析 / 分析完成且有草稿：插入到队尾
        UIButton {
            Layout.alignment: Qt.AlignVCenter
            type: UIButtonType.Light
            size: UIControlSize.L
            visible: context.status !== AiRoughCutContext.StatusSuccess || draftManager.currentDraft !== -1
            text: context.status === AiRoughCutContext.StatusSuccess ? qsTr("pccut_roughcut_result_append") : qsTr("pccut_roughcut_minimize")
            onClicked: {
                if (context.status === AiRoughCutContext.StatusSuccess) {
                    viewModel.insertToTail();
                } else {
                    viewModel.minimizeToBackground();
                }
            }
        }

        // 分析中：查看效果（禁用） / 分析完成：新建草稿
        UIButton {
            Layout.alignment: Qt.AlignVCenter
            type: UIButtonType.Brand
            size: UIControlSize.L
            text: context.status === AiRoughCutContext.StatusSuccess ? qsTr("pccut_roughcut_result_new_draft") : qsTr("pccut_roughcut_view_result")
            enabled: context.status === AiRoughCutContext.StatusSuccess
            onClicked: viewModel.createNewDraft()
        }
    }
}
