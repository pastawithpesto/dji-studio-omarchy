import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Config 1.0
import Controls 1.0
import "../user_guide"

Rectangle {
    id: panel
    color: "transparent"
    // 高度由外部 Loader（anchors.fill）提供；contentColumn 锚定 top+bottom 填满，
    // 使内部 StackLayout 获得确定高度，小屏时色轮内容区可滚动。
    implicitWidth: parent ? parent.width : 440
    implicitHeight: parent ? parent.height : 400

    // C++ 桥接对象
    property var colorWheelAdjust: null

    // 分组开关
    property bool isEnabled: colorWheelAdjust ? colorWheelAdjust.isEnable : true
    // 当前编辑 Tab（0=一级, 1=Log）
    property int currentTab: colorWheelAdjust ? colorWheelAdjust.activeTab : 0
    // 弹框纵向微调
    property real guidePopupYOffset: 1.5

    // 重置所有子 Tab 的所有色轮参数
    function resetAll() {
        if (colorWheelAdjust) colorWheelAdjust.resetAll();
    }

    readonly property bool isAllDefault: colorWheelAdjust ? colorWheelAdjust.isAllDefault : true

    readonly property var wheelTabs: [
        {
            name: qsTr("pccut_panel_adjust_colorwheel_primary_title"),
            id: "primary",
            items: [
                { title: qsTr("pccut_panel_adjust_colorwheel_primary_lift_title"),  id: "lift",     tooltip: qsTr("pccut_panel_adjust_colorwheel_primary_lift_tooltip") },
                { title: qsTr("pccut_panel_adjust_colorwheel_primary_gamma_title"), id: "gamma",    tooltip: qsTr("pccut_panel_adjust_colorwheel_primary_gamma_tooltip")},
                { title: qsTr("pccut_panel_adjust_colorwheel_primary_gain_title"),  id: "gain",     tooltip: qsTr("pccut_panel_adjust_colorwheel_primary_gain_tooltip") },
                { title: qsTr("pccut_panel_adjust_colorwheel_primary_offset_title"),id: "offset_primary", tooltip: qsTr("pccut_panel_adjust_colorwheel_primary_offset_tooltip") }
            ]
        },
        {
            name: qsTr("pccut_panel_adjust_colorwheel_log_title"),
            id: "log",
            items: [
                { title: qsTr("pccut_panel_adjust_colorwheel_log_shadow_title"),    id: "shadow",   tooltip: qsTr("pccut_panel_adjust_colorwheel_log_shadow_tooltip") },
                { title: qsTr("pccut_panel_adjust_colorwheel_log_midtone_title"),   id: "midtone",  tooltip: qsTr("pccut_panel_adjust_colorwheel_log_midtone_tooltip") },
                { title: qsTr("pccut_panel_adjust_colorwheel_log_highlight_title"), id: "highlight",  tooltip: qsTr("pccut_panel_adjust_colorwheel_log_highlight_tooltip") },
                { title: qsTr("pccut_panel_adjust_colorwheel_log_offset_title"),    id: "offset_log", tooltip: qsTr("pccut_panel_adjust_colorwheel_log_offset_tooltip") }
            ]
        }
    ]

    function getTabNames() {
        return wheelTabs.map(tab => tab.name);
    }

    // 第一个色轮（一级暗部）的引用，用于定位引导弹框
    property var firstColorWheel: null

    // 核心：根据“暗部标题”的真实坐标定位弹框
    function positionGuidePopup() {
        var wheel = panel.firstColorWheel;
        if (!wheel || !userGuidePopup.parent)
            return;

        // 直接用色轮顶部附近作为锚点（标题就在色轮顶部）
        var p = wheel.mapToItem(userGuidePopup.parent, wheel.width / 2, 20);

        userGuidePopup.x = Math.round(p.x - userGuidePopup.width / 2);
        userGuidePopup.y = Math.round(p.y
                                      + userGuidePopup.indicatorHeight
                                      + userGuidePopup.indicatorGap
                                      + 2
                                      + panel.guidePopupYOffset);
    }

    ColumnLayout {
        id: contentColumn
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.top: parent.top
        anchors.bottom: parent.bottom   // 锚定底部，使 StackLayout 的 fillHeight 生效（内容区获得确定高度）
        spacing: 14
        anchors.topMargin: 1

        // 顶部：分组开关 + 标题 + 重置
        Item {
            id: colorWheelControl
            property bool isDisable: !enableCheckBox.checked
            Layout.fillWidth: true
            height: 20

            LightCheckBox {
                id: enableCheckBox
                maxTextWidth: 200  // 设置一个合理的最大值，但不依赖父容器
                text: qsTr("pccut_panel_adjust_colorwheel_title")
                textColor: Colors.color_EEEEEE
                checked: panel.isEnabled
                anchors.verticalCenter: parent.verticalCenter
                Layout.preferredWidth: Math.min(implicitWidth, maxTextWidth + 16)
                Layout.fillWidth: false
                MouseArea {
                    anchors.fill: enableCheckBox
                    onClicked: {
                        if (panel.colorWheelAdjust)
                            panel.colorWheelAdjust.isEnable = !enableCheckBox.checked;
                    }
                }
            }

            Rectangle {
                id: cwResetBtn
                property bool isHovered: false
                anchors.right: useToAllBtn.left
                anchors.rightMargin: 12
                color: Colors.color_transparent
                width: 20
                height: 20
                anchors.verticalCenter: parent.verticalCenter
                Image {
                    anchors.fill: parent
                    source: cwResetBtn.isHovered ? "qrc:/icons/ic_reset_hover.svg" : "qrc:/icons/ic_reset.svg"
                    sourceSize: Qt.size(parent.width, parent.height)
                    opacity: (colorWheelControl.isDisable || panel.isAllDefault) ? 0.2 : 1.0
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !(panel.isAllDefault || colorWheelControl.isDisable)
                    onEntered: cwResetBtn.isHovered = true
                    onExited: cwResetBtn.isHovered = false
                    onClicked: {
                        if (!colorWheelControl.isDisable && !panel.isAllDefault) { panel.resetAll(); }
                    }
                }
            }

            Rectangle{
                id: useToAllBtn
                property bool isHovered: false
                color: colorWheelControl.isDisable ? Colors.color_353738 : useToAllBtn.isHovered ? Colors.color_414344 : Colors.color_353738
                radius: 4
                opacity: colorWheelControl.isDisable ? 0.3 : 1
                anchors{
                    right: parent.right
                }
                width: useToAllBtnText.width + 16
                height: 20
                anchors.verticalCenter: parent.verticalCenter
                Text{
                    id: useToAllBtnText
                    text: qsTr("pccut_panel_adjust_colorwheel_apply_all_btn")
                    anchors.centerIn: parent
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    color: Colors.color_EEEEEE
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !colorWheelControl.isDisable
                    onEntered: useToAllBtn.isHovered = true
                    onExited: useToAllBtn.isHovered = false
                    onClicked: {
                        panel.colorWheelAdjust.applyToAll();
                        toast.showToast(qsTr("pccut_adjust_applied_all"), "tracks");
                        panel.colorWheelAdjust.commitDraft();
                    }
                }
            }

        }

        // 子色轮选择器（下拉框）
        LightComboBox {
            id: tabComboBox
            Layout.fillWidth: true
            Layout.preferredHeight: 24
            indicatorRightMargin: 4
            model: panel.getTabNames()
            currentIndex: panel.currentTab
            enabled: enableCheckBox.checked
            opacity: enabled ? 1.0 : 0.2
            onCurrentIndexChanged: {
                if (panel.colorWheelAdjust && currentIndex !== panel.colorWheelAdjust.activeTab)
                    panel.colorWheelAdjust.activeTab = currentIndex;
            }
        }

        // Tab 内容区（StackLayout 切换）
        StackLayout {
            id: stack
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: panel.currentTab

            Loader {
                id: loader0
                sourceComponent: wheelGridComponent
                onLoaded: {
                    item.tabIndex = 0
                    // 绑定第一个色轮引用，布局好后会自动更新
                    panel.firstColorWheel = Qt.binding(function() {
                        return loader0.item ? loader0.item.firstWheel : null
                    })
                }
            }

            Loader {
                sourceComponent: wheelGridComponent
                onLoaded: { item.tabIndex = 1 }
            }
        }
    }

    Component {
        id: wheelGridComponent
        // 外层滚动区域，不显示滚动条（策略 AlwaysOff），仅保留滚轮/触控板竖直滚动能力。
        // 面板宽度由外层 SplitView 保证 ≥280（12+116+24+116+12），两列色轮恒可完整显示。
        ScrollView {
            id: wheelScroll
            property int tabIndex: 0
            // 稳定暴露第一个色轮（供引导弹框定位）
            property alias firstWheel: grid.firstWheel

            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical.policy: ScrollBar.AlwaysOff
            Component.onCompleted: contentItem.boundsBehavior = Flickable.StopAtBounds

            contentWidth: availableWidth   // 贴合可视区，不横向滚动
            contentHeight: grid.implicitHeight + 18 // 添加 8px 底部空间（2行色轮 × 4px），容纳 RGB 色条的溢出

            GridLayout {
                id: grid
                property var firstWheel: rep.count > 0 ? rep.itemAt(0) : null
                readonly property var currentTab: panel.wheelTabs[wheelScroll.tabIndex]
                readonly property var currentItems: currentTab.items
                // 固定内容宽（两列 116 + 间距 24 = 256），水平居中于可视区，
                // 面板拉宽时多出的宽度成为左右等宽留白，色轮间距恒为 24。
                width: 116 * 2 + 24
                anchors.horizontalCenter: parent.horizontalCenter
                columns: 2
                rowSpacing: 24
                columnSpacing: 24

                Repeater {
                    id: rep
                    model: grid.currentItems.length
                    ColorWheel {
                        title: grid.currentItems[index].title
                        tooltipText: grid.currentItems[index].tooltip
                        wheelEnabled: panel.isEnabled
                        viewModel: panel.colorWheelAdjust
                        tabIndex: wheelScroll.tabIndex
                        wheelIndex: index
                        tabName: grid.currentTab.id
                        wheelName: grid.currentItems[index].id
                        // 固定尺寸 116×148，不随列宽拉伸/压缩
                        Layout.preferredWidth: 116
                        Layout.preferredHeight: 148
                    }
                }
            }
        }
    }

    // 面板宽度变化时重新定位（横向居中会变）
    onWidthChanged: Qt.callLater(positionGuidePopup)

    Component.onCompleted: {
        Qt.callLater(function() {
            if (panel.colorWheelAdjust && !panel.colorWheelAdjust.isUserGuidePopupTriggered()) {
                // 确保停在“一级色轮”页，否则暗部不可见
                panel.currentTab = 0
                panel.colorWheelAdjust.activeTab = 0
                userGuidePopup.open()
            }
        })
    }

    AdaptablePopupforUserGuide {
        id: userGuidePopup
        parent: panel                   // 挂到根节点，坐标映射稳定
        anchors.centerIn: undefined     // 解除基类的居中锚定，让 x/y 生效
        descriptionText: qsTr("pccut_panel_adjust_colorwheel_hover_tip")
        descriptionfontSize: 11
        descriptionColor: Colors.color_141414
        width: 160
        radius: 4
        padding: 8
        topPadding: 6
        bottomPadding: 6
        indicatorEdge: "top"
        indicatorGap: -2
        indicatorWidth: 12
        indicatorHeight: 8

        // 每次显示前用真实坐标重算位置
        onAboutToShow: Qt.callLater(panel.positionGuidePopup)

        onClosed: {
            // 状态写入配置文件，之后不再弹出（done = true）
            if (panel.colorWheelAdjust)
                panel.colorWheelAdjust.setUserGuidePopupTriggered(true)
        }
    }
}
