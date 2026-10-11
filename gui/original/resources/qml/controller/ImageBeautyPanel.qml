import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls
//import QtQuick.Controls.Styles 1.4
import QtQuick.Controls.Material 2.15
import Config 1.0
import Controls 1.0
import LutListModel 1.0
import QtQuick.Layouts 1.3
import app_qrc 1.0
import UsedFunctionManager 1.0
import ProjectSettingsInfo 1.0
import Nova 1.0

/**
 *  @File        : ImageBeautyPanel.qml
 *  @Brief       : 美颜调节面板
 *  @Details     : 包含美颜预设、皮肤、五官、妆容、美体分组调节
 *  @Author      : xuan.geng
 *  @Date        : 2026-03-12
 */

Rectangle {
    id: root
    anchors.fill: parent
    color: Colors.color_content_area_background

    property bool isShowStylePanel : false
    property bool isDefaultStatus : beautyVM.isDefaultStatus


    property real maxItemTextWidth: Math.max(skinSetting.maxItemTextWidth, facialSetting.maxItemTextWidth, bodySetting.maxItemTextWidth, bodySetting.maxItemTextWidth)

    property real textLeftPadding: Math.max(70, maxItemTextWidth + 12)

    // 滑块左侧标签区宽度（对齐最宽标签"黑眼圈"）
    readonly property real sliderLeft: 56
    // 滑块两侧总占用宽度（左侧标签 + 右侧数值）
    readonly property int bothSidePadding: sliderLeft + 30

    // 美颜协调器（nova byted_effects）：开关/预设/重置/应用到全部，内核驱动按选中自动回灌。
    ImageBeautyFilterViewModel {
        id: beautyVM
    }
    Connections {
        target: beautyVM
        function onPresetIndexChanged() {
            presetRow.currentIndex = beautyVM.presetIndex;
        }
    }

    // ----------------------------------------------------------------
    // 预设数据：从 JSON 加载
    // ----------------------------------------------------------------
    ListModel { id: presetModel }

    Component.onCompleted: loadPresets()

    function loadPresets() {

        var arr = beautyVM.loadCardsfromJson();
        presetModel.clear();
        for (var i = 0; i < arr.length; ++i) {
                    presetModel.append(arr[i])
                }
        presetRow.currentIndex = beautyVM.presetIndex;

    }

    // 顶部分割线
    Rectangle {
        color: Colors.color_141414
        width: parent.width
        height: 1
    }

    ScrollView {
        id: scrollView
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            bottom: bottomFixedArea.top  // 底部连接到固定区域
            leftMargin:12
            rightMargin:12
        }
        // 隐藏滚动条
        ScrollBar.vertical.policy: ScrollBar.AlwaysOff
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        clip: true
        Component.onCompleted: {
            contentItem.boundsBehavior = Flickable.StopAtBounds
        }
        contentItem: Flickable {
            id: flickable
            contentHeight: columnLayout.implicitHeight
            ColumnLayout {
                id: columnLayout
                spacing: 0
                anchors {
                    left: parent.left
                    top: parent.top
                }
                width: scrollView.width
                Loader {
                    active: !isShowStylePanel
                    visible: active
                    sourceComponent: Rectangle {
                        width: scrollView.width
                        height: 0.5
                        color: Colors.color_transparent
                    }
                }
                // LutSetting {
                //     id: lutSetting
                //     Layout.preferredWidth: width
                //     Layout.preferredHeight: height
                //     videoFragment: root.videoFragment
                // }


                // Rectangle {
                //     visible: beautyControl.visible
                //     height: 1
                //     Layout.fillWidth: true
                //     color: Colors.color_333333
                // }

                // ---- 头部：开关 + 重置按钮 ----

                Item{
                    id: beautyAdControl
                    property bool isDisable: !beautyVM.isEnable
                    Layout.fillWidth: true
                    Layout.topMargin: 18
                    height: 16

                    LightCheckBox {
                        id:checkBox2
                        maxTextWidth: root.width - 180
                        text: qsTr("pccut_panel_beauty_tab_title")
                        checked: beautyVM.isEnable
                        anchors.verticalCenter: parent.verticalCenter
                        Component.onCompleted:
                        {
                            // 从业务层登记功能已使用（埋点/已用功能），开关态由内核回灌。
                            var projectId = draftManager.activeProjectEnvId();
                            var isFuncExist = UsedFunctionManager.hasFunction(projectId,UsedFunctionManager.EditorFunctionType.BEAUTY);

                            if(!isFuncExist && beautyVM.isEnable)
                            {
                                UsedFunctionManager.addFunction(projectId,UsedFunctionManager.EditorFunctionType.BEAUTY);
                            }
                        }
                        MouseArea {
                            anchors.fill: checkBox2
                            onClicked: {
                                var newChecked = !checkBox2.checked;
                                eventTracker.trackEvent("pccut_panel_beauty_switch", {"is_turnon": newChecked})
                                if (newChecked) {
                                    var projectId = draftManager.activeProjectEnvId();
                                    if (!UsedFunctionManager.hasFunction(projectId, UsedFunctionManager.EditorFunctionType.BEAUTY))
                                        UsedFunctionManager.addFunction(projectId, UsedFunctionManager.EditorFunctionType.BEAUTY);
                                }
                                beautyVM.isEnable = newChecked;
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
                            source: (beautyAdControl.isDisable || root.isDefaultStatus) ? "qrc:/icons/ic_reset.svg" :  resetBtn.isHovered ? "qrc:/icons/ic_reset_hover.svg" : "qrc:/icons/ic_reset.svg"
                            sourceSize: Qt.size(parent.width, parent.height)
                            opacity: (beautyAdControl.isDisable || root.isDefaultStatus) ? 0.2 : 1
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: resetBtn.isHovered = true
                            onExited: resetBtn.isHovered = false
                            onClicked: {
                                if(!beautyAdControl.isDisable && !root.isDefaultStatus) {
                                    beautyVM.resetValue();
                                    eventTracker.trackEvent("pccut_panel_beauty_reset")
                                }
                            }
                        }
                    }

                    // ColorDiffClearTips {
                    //     id: beautyTips
                    //     tipText: qsTr("pccut_tone_enhancement_tooltip")
                    //     property real offset: {

                    //         return (checkBox2.x + checkBox2.width / 2) / width > 0.6 ? 50 : 0
                    //     }

                    //     arrowLeftMargin: Math.min(checkBoxBeauty.width - 6,  (beautyTips.width - checkBox2.width) / 2 + offset) + checkBox2.width / 2
                    //     width: parent.width
                    //     height: 28
                    //     anchors {
                    //         left: checkBox2.left
                    //         leftMargin: Math.max(-checkBoxBeauty.width + 6,  -(beautyTips.width - checkBox2.width) / 2 - offset)
                    //         bottom: checkBox2.top
                    //     }
                    //     visible: false//BeautyDescIconMouseArea.containsMouse
                    // }
                }
                // ---- 美颜预设 ----
                Text {
                    Layout.fillWidth: true
                    text: qsTr("pccut_panel_beauty_preset_title")
                    Layout.topMargin: 16
                    font.pixelSize: 11
                    color: "#999999";
                    font.family: "PingFang SC";
                }
                // 预设卡片行
                Row {
                    id: presetRow
                    property int currentIndex: -1
                    Layout.fillWidth: true
                    Layout.topMargin: 13

                    // 卡片间固定间距，宽度自适应 Row 宽度
                    readonly property real cardSpacing: 12
                    spacing: cardSpacing
                    readonly property real cardSize: 55

                    Repeater {
                        model: presetModel

                        delegate: Column {
                            spacing: 8
                            opacity:  1.0

                            // 预设缩略图（虚线边框）
                            Item {
                                width: presetRow.cardSize
                                height: presetRow.cardSize


                                Rectangle {
                                    anchors.fill: parent
                                    radius: 6
                                    opacity: beautyAdControl.isDisable ? 0.2 : 1
                                    // color: {
                                    //     if (index === presetRow.currentIndex) {
                                    //         // 选中项：保持你原来的高亮色
                                    //         return Colors.color_353738;
                                    //     }
                                    //     // 启用但未选中：hover 时略亮，不 hover 时底色
                                    //     return Colors.color_2F3032;
                                    // }
                                    color: mouseArea.containsMouse ? Colors.color_button_background_hovered : Colors.color_button_background_normal
                                }
                                Image {
                                    anchors.centerIn: parent
                                    source: {
                                        if(beautyAdControl.isDisable)
                                        {
                                            return model.disableSource;
                                        }
                                        else
                                        {
                                            if (index === presetRow.currentIndex) {
                                                return model.selectSource;
                                            }
                                            else
                                                return model.unselectSource;
                                        }
                                    }
                                    sourceSize: Qt.size(40, 40)

                                }

                                // TODO: 替换为实际预设缩略图
                                // Image { anchors.fill: parent; source: model.iconSource; fillMode: Image.PreserveAspectCrop }

                                MouseArea {
                                    id: mouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: !beautyAdControl.isDisable
                                    onClicked: {

                                        beautyVM.presetValues(index)
                                        presetRow.currentIndex = index
                                        eventTracker.trackEvent("pccut_panel_beauty_preset", {"preset_name": model.trackName})

                                    }
                                }
                            }

                            // 预设名称
                            Text {
                                opacity: beautyAdControl.isDisable ? 0.2 : 1
                                width: presetRow.cardSize
                                text: model.name
                                font.pixelSize: 11
                                color: Colors.color_666666
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }
                }

                // ---- 分割线（预设 → 皮肤）----
                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: 16
                    height: 1
                    color:  Colors.color_2F3032
                }

                // ---- 皮肤 ----
                FilterInfoSetting {
                    id: skinSetting
                    minValue: -100
                    maxValue: 100
                    sliderLeft: textLeftPadding
                    isDisable: beautyAdControl.isDisable
                    Layout.preferredWidth: width
                    Layout.preferredHeight: height
                    Layout.topMargin: 15
                    itemVerticalSpacing: 12
                    headerTextColor: Colors.color_EEEEEE
                    subTitleTextColor: Colors.color_999999
                    subTitleTextValueColor: Colors.color_999999
                    adjustModel: SkinFilterAdjust {
                        id: skinModel
                    }


                }


                // ---- 五官 ----
                FilterInfoSetting {
                    id: facialSetting
                    minValue: -100
                    maxValue: 100
                    sliderLeft: textLeftPadding
                    isDisable: beautyAdControl.isDisable
                    Layout.preferredWidth: width
                    Layout.preferredHeight: height
                    itemVerticalSpacing: 12
                    Layout.topMargin: 24
                    headerTextColor: Colors.color_EEEEEE
                    subTitleTextColor: Colors.color_999999
                    subTitleTextValueColor: Colors.color_999999
                    adjustModel: FacialFilterAdjust {
                        id: facialModel
                    }


                }


                // ---- 妆容 ----
                FilterInfoSetting {
                    id: makeupSetting
                    minValue: -100
                    maxValue: 100
                    sliderLeft: textLeftPadding
                    isDisable: beautyAdControl.isDisable
                    Layout.preferredWidth: width
                    Layout.preferredHeight: height
                    itemVerticalSpacing: 12
                    Layout.topMargin: 24
                    headerTextColor: Colors.color_EEEEEE
                    subTitleTextColor: Colors.color_999999
                    subTitleTextValueColor: Colors.color_999999
                    adjustModel: MakeupFilterAdjust {
                        id: makeupModel
                    }


                }
                // ---- 美体 ----
                FilterInfoSetting {
                    id: bodySetting
                    minValue: -100
                    maxValue: 100
                    sliderLeft: textLeftPadding
                    isDisable: beautyAdControl.isDisable
                    Layout.preferredWidth: width
                    Layout.preferredHeight: height
                    itemVerticalSpacing: 12
                    Layout.topMargin: 24
                    Layout.bottomMargin: 16
                    headerTextColor: Colors.color_EEEEEE
                    subTitleTextColor: Colors.color_999999
                    subTitleTextValueColor: Colors.color_999999
                    adjustModel: BodyFilterAdjust {
                        id: bodyModel
                    }

                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 0
                }
            }
        }

    }

    Rectangle {
        id: bottomFixedArea
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        height: 32
        color: Colors.color_252627

        // 底部固定的应用到全局按钮
        Rectangle{
            id: bottomAllUseBtn
            property bool isHovered: false
            //color: bottomAllUseBtn.isHovered ? Colors.color_414344 : Colors.color_353738
            radius: 4
            //opacity: 1
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin:12
            width: 71
            height: 20
            enabled: !beautyAdControl.isDisable
            color: (bottomAllUseBtn.enabled === false) ? Colors.color_353738 : mousearea_applyToAll.containsMouse ? Colors.color_414344 : Colors.color_353738
            opacity: (bottomAllUseBtn.enabled === true) ? 1 : 0.2
            
            Text{
                id: bottomAllUseBtnText
                text: qsTr("pccut_panel_colorrecovery_applyglobally")
                anchors.centerIn: parent
                font.pixelSize: 11
                font.weight: Font.Medium
                color: Colors.color_EEEEEE
            }

            MouseArea {
                id: mousearea_applyToAll
                anchors.fill: parent
                hoverEnabled: true
                enabled: true
                onEntered: bottomAllUseBtn.isHovered = true
                onExited: bottomAllUseBtn.isHovered = false
                onClicked: {
                    var clipCount = beautyVM.getTrackClipCount()
                    var presetName = presetRow.currentIndex >= 0 ? presetModel.get(presetRow.currentIndex).trackName : "none"
                    beautyVM.applyToAll();
                    eventTracker.trackEvent("pccut_panel_beauty_all", {"clip_count": clipCount, "preset_name": presetName})
                }
            }
        }
    }

    // isDefaultStatus 由 beautyVM.isDefaultStatus 提供（内核态聚合）。

}
