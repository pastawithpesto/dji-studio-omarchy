import QtQuick 2.15
import QtQuick.Controls
import Config 1.0
import Controls 1.0
import QtQuick.Layouts 1.3
import Nova 1.0
import VideoFragmentViewModel 1.0
import MediaTypeModel 1.0
import QmlConstants 1.0
import app_qrc 1.0
import PanoramaConfig 1.0
import "../player/."
import UsedFunctionManager 1.0
import ProjectSettingsInfo 1.0
/**
  * @author: pansy.guo
  * @details 【画面设置】界面
  * @date: 2024-04-11 17:45:57
  */
Rectangle {
    id:panel
    property VideoFragmentViewModel viewModel
    property bool isPanoramaImage: panoramaVM.isPanoramaImage
    property bool isSupportLensProtective: !panoramaVM.isPanoramaImage && panoramaVM.supportLensProtective
    property bool flyModeSupport: panoramaVM.flyModeSupport
    property var  projectId: draftManager.activeProjectEnvId()
    color: Colors.color_content_area_background


    // 全景(mika.panorama)统一 VM：防水/增稳/拼接/色差/视角/标定，跟随 nova 选中片段
    PanoramaFilterViewModel {
        id: panoramaVM
    }

    // 视角模式手动切换：切换并上报埋点(旧/新模式)
    function manualChangeFlyMode() {
        const oldMode = panoramaVM.flyMode;
        panoramaVM.toggleMode();
        const newMode = panoramaVM.flyMode;
        if (!CommonUtils.isNull(panel.viewModel)) {
            panel.viewModel.changeFlyMode(oldMode, newMode);
        }
    }

    Connections{
        target: panoramaVM
        function onStitcherTypeChanged(){
            mesh_1_Switch.checked = panoramaVM.stitcherType === PanoramaFilterViewModel.MESH
            mesh_2_Switch.checked = panoramaVM.stitcherType === PanoramaFilterViewModel.MESH_EQUAL
            mesh_ai_Switch.checked = panoramaVM.stitcherType === PanoramaFilterViewModel.AI_OPTIMIZATION
            mesh_line_Switch.checked = panoramaVM.stitcherType === PanoramaFilterViewModel.MESH_LINE
            mesh_test_Switch.checked = panoramaVM.stitcherType === PanoramaFilterViewModel.STITCHER_TEST
            if(panoramaVM.stitcherType === PanoramaFilterViewModel.FLOW){
                stitcherSwitch.switchManual(true,false);
                preciseStitchSwtich.switchManual(false,false);
                return;
            }
            if(panoramaVM.stitcherType === PanoramaFilterViewModel.PRECISE){
                preciseStitchSwtich.switchManual(true,false);
                stitcherSwitch.switchManual(false,false);
                return;
            }
            stitcherSwitch.switchManual(false,false);
            preciseStitchSwtich.switchManual(false,false);
        }
    }
    // 顶部分割线
    Rectangle {
        color: Colors.color_141414
        width: parent.width
        height: 1
    }

    ScrollView {
        id: scrollView
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        bottomPadding: 20
        ScrollBar.vertical.policy: ScrollBar.AlwaysOff
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        clip: true
        contentHeight: column.implicitHeight

        Component.onCompleted: {
            contentItem.boundsBehavior = Flickable.StopAtBounds
        }

        contentItem: Flickable {
            // 覆盖整个 Flickable 的 MouseArea，用于清除焦点
            MouseArea {
                anchors.fill: parent
                z: -1
                onClicked: {
                    forceActiveFocus()
                }
            }

        Column {
            id: column
            spacing: 0
            Rectangle {
                width: scrollView.width
                height: 16
                color: Colors.color_transparent
            }

            Rectangle {
                anchors {
                    left: parent.left
                    right: parent.right
                }
                height: 4
                visible: true
                color: Colors.color_transparent
            }

            Connections {
                target: panoramaVM
                function onFlyModeChanged() {
                    // LightBaseSwitch 的 checked 在点击时会被重新赋值导致绑定失效，这里重新赋一下值
                    fpvModeSwitch.checked = panoramaVM.flyMode === PanoramaConfig.FPV;
                    followModeSwitch.checked = panoramaVM.flyMode === PanoramaConfig.FOLLOW;
                }
            }

            Rectangle {
                id: flyModeRectangle
                width: scrollView.width
                height: 20
                anchors.left: parent.left
                // SEMI/BULLET_TIME 不支持飞行模式(且 flyModeSupport 已排除)；声明式随选中刷新
                visible: flyModeSupport && !panoramaVM.isSemiOrBullet
                color: Colors.color_transparent
                Text {
                    id: flyModeTitle
                    anchors.left: parent.left
                    anchors.topMargin: 0;
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignLeft
                    font {
                        pixelSize: 12
                    }
                    color: Colors.color_EEEEEE
                    text: qsTr("pccut_image_flight_switch")
                }
            }

            Rectangle {
                anchors {
                    left: parent.left
                    right: parent.right
                }
                height: 13
                color: Colors.color_transparent
                visible: flyModeSupport
            }

            // FPV模式
            Rectangle {
                width: scrollView.width
                height: 20
                anchors.left: parent.left
                color: Colors.color_transparent
                clip: true
                visible: flyModeSupport

                HoverableText {
                    width: scrollView.width - 36
                    cursorChanged: false
                    wrapMode: Text.NoWrap
                    elide: Text.ElideRight
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignLeft
                    font {
                        pixelSize: 11
                    }
                    color: Colors.color_999999
                    text: qsTr("pccut_image_fpv_switch")
                }
                LightBaseSwitch {
                    id: fpvModeSwitch
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    advanceControl:true
                    checked: panoramaVM.flyMode === PanoramaConfig.FPV
                    onCloseSignal:(needNotify) => {
                                      panel.manualChangeFlyMode();
                                  }
                    onOpenSignal:(needNotify) =>{
                                     panel.manualChangeFlyMode();
                                 }
                }
            }

            Rectangle {
                anchors {
                    left: parent.left
                    right: parent.right
                }
                height: 13
                color: Colors.color_transparent
                visible: flyModeSupport
            }

            // 跟随模式
            Rectangle {
                width: scrollView.width
                height: 20
                anchors.left: parent.left
                color: Colors.color_transparent
                clip: true
                visible: flyModeSupport
                HoverableText {
                    width: scrollView.width - 36
                    cursorChanged: false
                    wrapMode: Text.NoWrap
                    elide: Text.ElideRight
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignLeft
                    font {
                        pixelSize: 11
                    }
                    color: Colors.color_999999
                    text: qsTr("pccut_image_follow_switch")
                }

                LightBaseSwitch {
                    id: followModeSwitch
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    advanceControl:true
                    checked: panoramaVM.flyMode === PanoramaConfig.FOLLOW
                    onCloseSignal:(needNotify) => {
                                      panel.manualChangeFlyMode();
                                  }
                    onOpenSignal:(needNotify) =>{
                                     panel.manualChangeFlyMode();
                                 }
                }
            }

            Rectangle {
                anchors {
                    left: parent.left
                    right: parent.right
                }
                height: 13
                visible: flyModeSupport
                color: Colors.color_transparent
            }

            Rectangle {
                anchors {
                    left: parent.left
                    right: parent.right
                }
                height: 1
                visible: flyModeSupport
                color: Colors.color_444444_50
            }

            Rectangle {
                anchors {
                    left: parent.left
                    right: parent.right
                }
                height: 13
                visible: flyModeSupport && isSupportLensProtective
                color: Colors.color_transparent
            }

            // 镜头拼接title
            Rectangle {
                id: pannoWateProffTitleRectangle
                width: scrollView.width
                height: 20
                anchors.left: parent.left
                color: Colors.color_transparent
                visible: isSupportLensProtective
                clip: true
                Text {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignLeft
                    font {
                        pixelSize: 12
                    }
                    color: Colors.color_EEEEEE
                    text: qsTr("pccut_pr_import_source_lensstitching")
                }
            }
            Rectangle {
                anchors {
                    left: parent.left
                    right: parent.right
                }
                height: 13
                color: Colors.color_transparent
                visible: isSupportLensProtective
            }



            // 镜头保护壳
            Rectangle {
                width: scrollView.width
                height: 20
                anchors.left: parent.left
                color: Colors.color_transparent
                clip: true
                visible: isSupportLensProtective
                HoverableText {
                    id: waterproof_stitching_text
                    width: scrollView.width - 36
                    cursorChanged: false
                    wrapMode: Text.NoWrap
                    elide: Text.ElideRight
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignLeft
                    font {
                        pixelSize: 11
                    }
                    color: Colors.color_999999
                    text: qsTr("pccut_panel_image_lens_protective")
                }
                LightBaseSwitch {
                    id: waterproof_stitching
                    anchors.right: parent.right
                    y: waterproof_stitching_text.y + (waterproof_stitching_text.height - height) / 2
                    checked: panoramaVM.waterProff === Instance.waterproof_stitching;

                    onToggledSignal: {
                        if(checked) {
                            UsedFunctionManager.addFunction(projectId,UsedFunctionManager.EditorFunctionType.ACCESSORY);
                            panoramaVM.waterProff = Instance.waterproof_stitching
                            waterproof_under.checked = false
                            waterproof_above.checked = false
                        } else {
                            UsedFunctionManager.removeFunction(projectId,UsedFunctionManager.EditorFunctionType.ACCESSORY);
                            panoramaVM.waterProff = 0
                        }
                    }
                }
            }

            Rectangle {
                anchors {
                    left: parent.left
                    right: parent.right
                }
                height: 13
                color: Colors.color_transparent
                visible: isSupportLensProtective
            }

            // 隐形防水壳（水上）
            Rectangle {
                width: scrollView.width
                height: 20
                anchors.left: parent.left
                color: Colors.color_transparent
                clip: true
                visible: isSupportLensProtective
                HoverableText {
                    width: scrollView.width - 36
                    cursorChanged: false
                    wrapMode: Text.NoWrap
                    elide: Text.ElideRight
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignLeft
                    font {
                        pixelSize: 11
                    }
                    color: Colors.color_999999
                    text: qsTr("pccut_panel_image_waterproof_above")
                }
                LightBaseSwitch {
                    id: waterproof_above
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    checked: panoramaVM.waterProff === Instance.waterproof_above

                    onToggledSignal: {
                        if(checked) {
                            UsedFunctionManager.addFunction(projectId,UsedFunctionManager.EditorFunctionType.ACCESSORY);
                            panoramaVM.waterProff = Instance.waterproof_above
                            waterproof_under.checked = false
                            waterproof_stitching.checked = false
                        } else {
                            UsedFunctionManager.removeFunction(projectId,UsedFunctionManager.EditorFunctionType.ACCESSORY);
                            panoramaVM.waterProff = 0
                        }
                    }
                }
            }

            Rectangle {
                anchors {
                    left: parent.left
                    right: parent.right
                }
                height: 13
                color: Colors.color_transparent
                visible: isSupportLensProtective
            }

            // 隐形防水壳（水下）
            Rectangle {
                width: scrollView.width
                height: 20
                anchors.left: parent.left
                color: Colors.color_transparent
                clip: true
                visible: isSupportLensProtective
                HoverableText {
                    width: scrollView.width - 36
                    cursorChanged: false
                    wrapMode: Text.NoWrap
                    elide: Text.ElideRight
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignLeft
                    font {
                        pixelSize: 11
                    }
                    color: Colors.color_999999
                    text: qsTr("pccut_panel_image_waterproof_under")
                }
                LightBaseSwitch {
                    id: waterproof_under
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    checked: panoramaVM.waterProff === Instance.waterproof_under

                    Connections{
                        target:panoramaVM
                        function onWaterProffChanged(){
                            var tmpWaterProff = panoramaVM.waterProff
                            switch(tmpWaterProff) {
                            case Instance.waterproof_stitching:
                                UsedFunctionManager.removeFunction(projectId,UsedFunctionManager.EditorFunctionType.ACCESSORY);
                                UsedFunctionManager.addFunction(projectId,UsedFunctionManager.EditorFunctionType.ACCESSORY);
                                waterproof_stitching.checked = true
                                waterproof_above.checked = false
                                waterproof_under.checked = false
                                break
                            case Instance.waterproof_above:
                                UsedFunctionManager.removeFunction(projectId,UsedFunctionManager.EditorFunctionType.ACCESSORY);
                                UsedFunctionManager.addFunction(projectId,UsedFunctionManager.EditorFunctionType.ACCESSORY);
                                waterproof_stitching.checked = false
                                waterproof_above.checked = true
                                waterproof_under.checked = false
                                break
                            case Instance.waterproof_under:
                                UsedFunctionManager.removeFunction(projectId,UsedFunctionManager.EditorFunctionType.ACCESSORY);
                                UsedFunctionManager.addFunction(projectId,UsedFunctionManager.EditorFunctionType.ACCESSORY);
                                waterproof_stitching.checked = false
                                waterproof_above.checked = false
                                waterproof_under.checked = true
                                break
                            case 0:
                                UsedFunctionManager.removeFunction(projectId,UsedFunctionManager.EditorFunctionType.ACCESSORY);
                                waterproof_stitching.checked = false
                                waterproof_above.checked = false
                                waterproof_under.checked = false
                            }
                        }
                    }

                    onToggledSignal: {
                        if(checked) {
                            UsedFunctionManager.addFunction(projectId,UsedFunctionManager.EditorFunctionType.ACCESSORY);
                            panoramaVM.waterProff = Instance.waterproof_under
                            waterproof_above.checked = false
                            waterproof_stitching.checked = false
                        } else {
                            UsedFunctionManager.removeFunction(projectId,UsedFunctionManager.EditorFunctionType.ACCESSORY);
                            panoramaVM.waterProff = 0
                        }
                    }
                }
            }

            Rectangle {
                anchors {
                    left: parent.left
                    right: parent.right
                }
                height: 13
                color: Colors.color_transparent
                visible: isSupportLensProtective
            }

            Rectangle {
                id: line2
                anchors {
                    left: parent.left
                    right: parent.right
                }
                height: 1
                color: Colors.color_444444_50
                visible: isSupportLensProtective /* isPanoramaImage ? false : true */
            }

            Rectangle {
                anchors {
                    left: parent.left
                    right: parent.right
                }
                height: 7
                color: Colors.color_transparent
                visible: false /* !isPanoramaImage */
            }

            Rectangle {
                anchors {
                    left: parent.left
                    right: parent.right
                }
                height: 13
                visible: isPanoramaImage ? false : true
                color: Colors.color_transparent
            }

            Rectangle {
                id: colordiffTitleRectangle
                z:1
                width: scrollView.width
                height: 20
                anchors.left: parent.left
                visible: true
                color: Colors.color_transparent
                Text {
                    id: colordifftitle
                    anchors.left: parent.left
                    anchors.topMargin: 0;
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignLeft
                    font {
                        pixelSize: 12
                    }
                    color: Colors.color_EEEEEE
                    text: qsTr("pccut_panel_image_color_control")
                }

                Image {
                    id: colordiffNotificationButton
                    visible: true
                    anchors {
                        left: colordifftitle.right
                        leftMargin: 4
                    }
                    y: colordifftitle.y + 1.0 * (colordifftitle.height - height) / 2 // 为了避免0.5px的偏差
                    source: colordiffNotificationButtonMouseArea.containsMouse ? "qrc:/icons/ic_explain.svg" : "qrc:/icons/ic_explain_hover.svg"
                    sourceSize: Qt.size(14, 14)
                    MouseArea {
                        id: colordiffNotificationButtonMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                    }
                }

                ColorDiffClearTips {
                    id: colordiffcleartips
                    // 根据hover按钮在x轴位置设置偏移值，大于60%就将气泡箭头和位置进行一个偏移
                    property real offset: (colordiffNotificationButton.x + colordiffNotificationButton.width / 2) / width > 0.6 ? 50 : 0

                    arrowLeftMargin: Math.min(colordifftitle.width + 4,  (colordiffcleartips.width - colordiffNotificationButton.width) / 2 + offset) + colordiffNotificationButton.width / 2
                    width: 138
                    height: 28
                    anchors {
                        left: colordiffNotificationButton.left
                        //与左边标题平齐，或将中心与hover按钮放在同一x轴位置，后续为解决多语言被裁切问题，增加了offset偏移
                        leftMargin: Math.max(-colordifftitle.width - 4,  -(colordiffcleartips.width - colordiffNotificationButton.width) / 2 - offset)
                        bottom: colordiffNotificationButton.top
                    }
                    visible: colordiffNotificationButtonMouseArea.containsMouse
                }
            }


            Rectangle {
                anchors {
                    left: parent.left
                    right: parent.right
                }
                height: 4
                visible: true
                color: Colors.color_transparent
            }

            //消除拼接色差
            Rectangle {
                id:rtDiffColor
                width: scrollView.width
                height: 20
                anchors.left: parent.left
                visible: true
                color: Colors.color_transparent
                clip: true
                Text {
                    id: colordiffText
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignLeft
                    font {
                        pixelSize: 11
                    }
                    color: Colors.color_999999
                    text: qsTr("pccut_panel_image_color_eliminate")
                }
                LightBaseSwitch {
                    id:colordiffSwitch
                    anchors.right: parent.right
                    y: colordiffText.y + (colordiffText.height - height) / 2
                    checked: panoramaVM.isAchromatization //checked: deflickerSettingViewModel.isPanoDrone ? true : panoramaVM.isAchromatization
                    //isEnabled: !deflickerSettingViewModel.isPanoDrone
                    //enabled:!deflickerSettingViewModel.isPanoDrone

                    Component.onCompleted:
                    {
                        var isFuncExist = UsedFunctionManager.hasFunction(projectId,UsedFunctionManager.EditorFunctionType.COLOR_DIFF);
                        // 校准UI与业务层状态，阻塞信号避免触发onClicked
                        if (!isFuncExist && checked)
                        {
                            UsedFunctionManager.addFunction(projectId,UsedFunctionManager.EditorFunctionType.COLOR_DIFF);
                        }
                    }

                    Connections{
                        target:panoramaVM
                        function onAchromatizationChanged(){
                            colordiffSwitch.checked = panoramaVM.isAchromatization
                        }
                    }

                    onPressedSignal: {
                        colordiffSwitch.checked = !colordiffSwitch.checked;
                        colordiffSwitch.toggledSignal();
                    }

                    onToggledSignal: {
                        if(checked){
                            UsedFunctionManager.removeFunction(projectId,UsedFunctionManager.EditorFunctionType.COLOR_DIFF);
                            UsedFunctionManager.addFunction(projectId,UsedFunctionManager.EditorFunctionType.COLOR_DIFF);
                            panoramaVM.isAchromatization = true
                        }else{
                            UsedFunctionManager.removeFunction(projectId,UsedFunctionManager.EditorFunctionType.COLOR_DIFF);
                            panoramaVM.isAchromatization = false
                        }
                    }
                }
            }


            Rectangle {
                anchors {
                    left: parent.left
                    right: parent.right
                }
                height: 13
                visible: true
                color: Colors.color_transparent
            }

            // 强度(抑制色彩跳变)
           Rectangle {
                    id: colordiffIntensity
                    width: scrollView.width
                    height: 24
                    anchors.left: parent.left
                    visible: deflickerSettingViewModel.isPanoDrone
                    color: Colors.color_transparent
                    clip: false
                    opacity: 1

                    //text
                    Text {
                        id: colordiffIntensityText
                        height: 15
                        width: 46
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignLeft
                        font {
                            pixelSize: 11
                        }
                        color: Colors.color_999999
                        text: qsTr("pccut_reduce_color_jump") //强度（抑制跳变）
                        elide: Text.ElideRight
                        maximumLineCount: 1


                        MouseArea{
                            id: colordiffIntensityTextMouseArea
                               anchors.fill: parent
                               hoverEnabled: true
                               acceptedButtons: Qt.NoButton
                        }
                        // 是否被截断
                        //readonly property bool textElided:  contentWidth > width 失效了，但是失效原因待查，已经改用truncated

                        LightToolTip{
                            visible: colordiffIntensityTextMouseArea.containsMouse && colordiffIntensityText.truncated
                            tip: colordiffIntensityText.text
                        }

                    }
                    //tooltip
                    Image {
                        id:intensityIcon
                        height: 14
                        width: 14
                        anchors{
                            left: colordiffIntensityText.right
                            leftMargin: 2
                            verticalCenter: parent.verticalCenter
                        }

                        source: intensityIconMouseArea.containsMouse ? "qrc:/icons/ic_explain.svg" : "qrc:/icons/ic_explain_hover.svg"
                        sourceSize: Qt.size(14, 14)

                        MouseArea {
                            id: intensityIconMouseArea
                               anchors.fill: parent
                               hoverEnabled: true
                               acceptedButtons: Qt.NoButton

                               onEntered: {
                                   intensityTipsPopup.x =
                                       colordiffIntensityText.mapToItem(null, 0, colordiffIntensityText.height + 4).x
                                   intensityTipsPopup.y =
                                       colordiffIntensityText.mapToItem(null, 0, colordiffIntensityText.height + 4).y
                                   intensityTipsPopup.arrowX =
                                       intensityIcon.mapToItem(intensityTipsPopup.background,intensityIcon.width / 2, 0).x
                                   intensityTipsPopup.open()
                                   arrow.x = intensityIcon.x + arrow.width / 2

                               }

                               onExited: {
                                   intensityTipsPopup.close()
                               }
                        }
                    }
                    /*
                    ColorDiffClearTips {
                        id: intensityTipsPopup
                        tipText: qsTr("pccut_reduce_color_jump_tooltip")
                        // 根据hover按钮在x轴位置设置偏移值，大于60%就将气泡箭头和位置进行一个偏移
                        property real offset: (intensityIcon.x + intensityIcon.width / 2) / width > 0.6 ? 50 : 0

                        arrowLeftMargin: Math.min(colordiffIntensityText.width + 4,  (intensityTipsPopup.width - intensityIcon.width) / 2 + offset) + intensityIcon.width / 2
                        width: 256
                        height: 28
                        z:5
                        anchors {
                            left: intensityIcon.left
                            //与左边标题平齐，或将中心与hover按钮放在同一x轴位置，后续为解决多语言被裁切问题，增加了offset偏移
                            leftMargin: Math.max(-colordiffIntensityText.width - 4,  -(intensityTipsPopup.width - intensityIcon.width) / 2 - offset)
                            bottom: intensityIcon.top
                        }
                        visible: intensityIconMouseArea.containsMouse
                    }*/


                    Popup {
                         id: intensityTipsPopup
                         property bool showArrow: true
                         property int arrowX: width / 2
                         property int arrowSize: 8
                         property int arrowOffsetY: -4

                         implicitWidth: width
                         implicitHeight: height + (showArrow ? arrowSize / 2 : 0)
                         modal: false
                         focus: false
                         closePolicy: Popup.NoAutoClose
                         parent: Overlay.overlay
                         width: 256
                         height: textItem.contentHeight + 8 + (showArrow ? arrowSize : 0)

                         topPadding: (showArrow ? arrowSize / 2 : 0)
                         leftPadding: 8
                         rightPadding: 8
                         bottomPadding: 0

                         background: Item {
                             id:bgTip
                             width: intensityTipsPopup.implicitWidth
                             height: textItem.contentHeight+16
                             clip: false

                             Rectangle {
                                 id: bgRect
                                 width: parent.width
                                 height: parent.height
                                 anchors.top: parent.top
                                 anchors.topMargin: intensityTipsPopup.showArrow
                                                               ? intensityTipsPopup.arrowSize / 2
                                                               : 0
                                 radius: 4
                                 color: Colors.color_141414
                                 border.width: 1
                                 border.color: Colors.color_454649
                             }

                             Image {
                                 id: arrow
                                 rotation: 180
                                 visible: intensityTipsPopup.showArrow
                                 source: "qrc:/icons/panorama/transition_effect_arrow.svg"
                                 width: intensityTipsPopup.arrowSize
                                 height: intensityTipsPopup.arrowSize
                                 sourceSize: Qt.size(intensityTipsPopup.arrowSize, intensityTipsPopup.arrowSize)
                                 anchors {
                                     bottom: bgRect.top
                                     bottomMargin: intensityTipsPopup.arrowOffsetY
                                 }
                             }

                         }

                         contentItem: Text {
                             id: textItem
                             verticalAlignment: Text.AlignVCenter
                             horizontalAlignment: Text.AlignLeft
                             leftPadding: 0
                             wrapMode: Text.WordWrap
                             font.pixelSize: 11
                             color: Colors.color_EEEEEE
                             text: qsTr("pccut_reduce_color_jump_tooltip")
                         }
                     }

                    // listBox
                    ComboBox {
                        id: colordiffIntensityComboBox
                        currentIndex: {
                            if (deflickerSettingViewModel.currentIntensity === "close")
                                return 0
                            if (deflickerSettingViewModel.currentIntensity === "default")
                                return 1
                            if (deflickerSettingViewModel.currentIntensity === "high")
                                return 2
                            return 0
                        }
                        font.pixelSize: 11

                        enabled: true
                        anchors {
                            top: parent.top
                            left: intensityIcon.right
                            leftMargin: 10
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                        }
                        width: 184
                        height: 24
                        opacity: 1
                        textRole: "text"
                        model: ListModel {
                            ListElement {
                                text: qsTr("pccut_reduce_color_jump_level_close")//关闭
                                value:"close"
                            }
                            ListElement {
                                text: qsTr("pccut_reduce_color_jump_level_default")//默认
                                value:"default"
                            }
                            ListElement {
                                text: qsTr("pccut_reduce_color_jump_level_high")//更强
                                value:"high"
                            }
                        }
                        //指示器，箭头
                        indicator: Rectangle {
                            id: openRect
                            z: 1
                            anchors{
                                right: parent.right
                                rightMargin: 4
                                verticalCenter: parent.verticalCenter
                            }
                            width: 20
                            height: 20
                            color: Colors.color_transparent
                            property string iconPath : "qrc:/icons/ic_close_triangle.svg";

                            Image {
                                anchors.fill: parent
                                source: openRect.iconPath
                                sourceSize: Qt.size(parent.width, parent.height)
                                opacity: colordiffIntensityComboBox.enabled ? 1 : 0.2
                            }

                            Connections {
                                target: colordiffIntensityComboBox
                                function onDownChanged(){
                                    if(colordiffIntensityComboBox.popup.visible){
                                        openRect.iconPath = "qrc:/icons/ic_open_triangle.svg"
                                    }else{
                                        openRect.iconPath = "qrc:/icons/ic_close_triangle.svg"
                                    }
                                }
                            }
                        }
                        //cbo文字
                        contentItem: Rectangle {
                            id: bg
                            anchors.fill: parent
                            radius: 4
                            color: hovered ? Colors.color_37383A: Colors.color_2F3032

                            opacity: colordiffIntensityComboBox.enabled ? 1 : 0.2

                            property bool hovered: false

                            HoverHandler {
                                onHoveredChanged: bg.hovered = hovered
                            }

                            Text {
                                anchors.fill: parent
                                leftPadding: 8
                                rightPadding: 28
                                text: colordiffIntensityComboBox.displayText
                                font.pixelSize: 11
                                color: Colors.color_EEEEEE
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                            }
                        }

                        background: Item { }

                        Keys.onPressed: (event)=> {
                            event.accepted = true; // 阻止按键事件的默认行为
                        }

                        Keys.onReleased: (event)=> {
                            event.accepted = true; // 阻止按键事件的默认行为
                        }

                        // 下拉列表，暂时借用水印设置
                        popup: DiffColorIntensityPopup {
                            id: intensityPopup
                            y: colordiffIntensityComboBox.height + 4
                            x: -intensityPopup.width + parent.width+0.5
                            parent: parent
                            intensityModel: colordiffIntensityComboBox.model
                            selectedIndex: colordiffIntensityComboBox.currentIndex
                            onItemClicked: (index,value) => {
                           if(value === "high"){
                                toast.showToast(qsTr("pccut_reduce_color_jump_high_warning"));
                            }
                            deflickerSettingViewModel.currentIntensity = value
                            console.log("选择是否启用intensityLevel=",value);
                            }
                        }

                    }


                    Connections {
                        target: deflickerSettingViewModel
                        function onCurrentIntensityChanged() {
                            var intensity = deflickerSettingViewModel.currentIntensity;
                            if (intensity === "close") {
                                colordiffIntensityComboBox.currentIndex = 0;
                            } else if (intensity === "default") {
                                colordiffIntensityComboBox.currentIndex = 1;
                            } else if (intensity === "high") {
                                colordiffIntensityComboBox.currentIndex = 2;
                            } else {
                                colordiffIntensityComboBox.currentIndex = 0; // 兜底保护
                            }
                        }
                    }

                }

           //下边距
           Rectangle {
               anchors {
                   left: parent.left
                   right: parent.right
               }
               height: 16
               visible: colordiffIntensity.visible
               color: Colors.color_transparent
           }

            Rectangle {
                id: line1
                visible: true
                anchors {
                    left: parent.left
                    right: parent.right
                }
                height: 1
                color: Colors.color_444444_50
            }
            Rectangle {
                anchors {
                    left: parent.left
                    right: parent.right
                }
                height: 13
                color: Colors.color_transparent
            }

            //拼接优化
            Rectangle {
                id: pannoTitleRectangle
                width: scrollView.width
                height: 20
                anchors.left: parent.left
                color: Colors.color_transparent
                clip: true
                visible: panoramaVM.aiEnable || stitchingCorrectionRec.visible
                Text {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignLeft
                    font {
                        pixelSize: 12
                    }
                    color: Colors.color_EEEEEE
                    text: qsTr("pccut_panel_image_splicing_optimization")
                }
            }
            Rectangle {
                anchors {
                    left: parent.left
                    right: parent.right
                }
                visible: panoramaVM.aiEnable
                height: 13
                color: Colors.color_transparent
            }
            // 光流拼接
            Rectangle {
                width: scrollView.width
                height: 20
                anchors.left: parent.left
                color: Colors.color_transparent
                clip: true
                visible: panoramaVM.aiEnable
                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignLeft
                    font {
                        pixelSize: 11
                    }
                    color: Colors.color_999999
                    text: qsTr("pccut_panel_image_optical_flow")
                }
                LightBaseSwitch {
                    id: stitcherSwitch
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    advanceControl:true
                    // 防水壳(水上/水下)锁定时光流置灰不可点，且必然为开启态
                    enabled: !panoramaVM.isWaterProofLocked
                    checked: panoramaVM.stitcherType === PanoramaFilterViewModel.FLOW
                    Component.onCompleted:
                    {
                        var isFuncExist = UsedFunctionManager.hasFunction(projectId,UsedFunctionManager.EditorFunctionType.OPTICAL_FLOW_STITCHING);
                        if(!isFuncExist && checked)
                        {
                            UsedFunctionManager.removeFunction(projectId,UsedFunctionManager.EditorFunctionType.HIGH_PRECISION_STITCHING);
                            UsedFunctionManager.addFunction(projectId,UsedFunctionManager.EditorFunctionType.OPTICAL_FLOW_STITCHING);
                        }
                    }
                    onCloseSignal:(needNotify) => {
                                      if(!preciseStitchSwtich.checked){
                                          if(needNotify){
                                              UsedFunctionManager.removeFunction(projectId,UsedFunctionManager.EditorFunctionType.OPTICAL_FLOW_STITCHING);
                                              UsedFunctionManager.addFunction(projectId,UsedFunctionManager.EditorFunctionType.HIGH_PRECISION_STITCHING);
                                              panoramaVM.stitcherType = PanoramaFilterViewModel.PRECISE//精细拼接
                                              eventTracker.trackEvent("pccut_image_opticalflow_switch", {"is_turnon": checked})

                                          }
                                      }
                                  }
                    onOpenSignal:(needNotify) =>{
                                     if(needNotify){
                                         UsedFunctionManager.removeFunction(projectId,UsedFunctionManager.EditorFunctionType.HIGH_PRECISION_STITCHING);
                                         UsedFunctionManager.addFunction(projectId,UsedFunctionManager.EditorFunctionType.OPTICAL_FLOW_STITCHING);
                                         panoramaVM.stitcherType = PanoramaFilterViewModel.FLOW//光流拼接
                                         preciseStitchSwtich.switchManual(false)
                                         eventTracker.trackEvent("pccut_image_opticalflow_switch", {"is_turnon": checked})
                                     }
                                 }
                }
            }
            Rectangle {
                anchors {
                    left: parent.left
                    right: parent.right
                }
                visible: panoramaVM.aiEnable && hightPrecisionItem.visible
                height: 13
                color: Colors.color_transparent
            }
            Item {
                id: hightPrecisionItem
                width: scrollView.width
                height: 20
                anchors.left: parent.left
                clip: true
                // 防水壳(水上/水下)锁定时高精度拼接入口隐藏(与光流置灰配套)
                visible: panoramaVM.aiEnable && !panoramaVM.isWaterProofLocked

                Text {
                    id: highPrecisionText
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignLeft
                    font {
                        pixelSize: 11
                    }
                    color: Colors.color_999999
                    text: qsTr("pccut_panel_image_high_precision")
                }

                Image {
                    id: hightStitcherIcon
                    anchors{
                        left: highPrecisionText.right
                        leftMargin: 4
                        verticalCenter: parent.verticalCenter
                    }

                    source: hightStitcherIconMouseArea.containsMouse ? "qrc:/icons/ic_explain.svg" : "qrc:/icons/ic_explain_hover.svg"
                    sourceSize: Qt.size(14, 14)

                    MouseArea {
                        id: hightStitcherIconMouseArea
                        anchors.fill: parent
                        hoverEnabled: true

                        onContainsMouseChanged: {
                            if (containsMouse) {
                                // 悬浮时按当前位置定位，气泡贴在标题行上方
                                var pos = hightPrecisionItem.mapToItem(null, 0, 0)
                                stitcherTooltip.x = pos.x
                                stitcherTooltip.anchorY = pos.y
                                stitcherTooltip.open()
                            } else {
                                stitcherTooltip.close()
                            }
                        }
                    }
                }
                LightBaseSwitch {
                    id:preciseStitchSwtich
                    anchors.right: parent.right
                    y: highPrecisionText.y + (highPrecisionText.height - height) / 2
                    advanceControl:true
                    handlePressed:true
                    needConfirm:true
                    confirmText:"pccut_panel_image_high_precision_describe"
                    checked: panoramaVM.stitcherType === PanoramaFilterViewModel.PRECISE
                    Component.onCompleted:
                    {
                        var isFuncExist = UsedFunctionManager.hasFunction(projectId,UsedFunctionManager.EditorFunctionType.HIGH_PRECISION_STITCHING);
                        if(!isFuncExist && checked)
                        {
                            UsedFunctionManager.removeFunction(projectId,UsedFunctionManager.EditorFunctionType.OPTICAL_FLOW_STITCHING);
                            UsedFunctionManager.addFunction(projectId,UsedFunctionManager.EditorFunctionType.HIGH_PRECISION_STITCHING);
                        }
                    }
                    onCloseSignal:(needNotify) =>{
                                      if(!stitcherSwitch.checked){
                                          if(needNotify){
                                              panoramaVM.stitcherType = PanoramaFilterViewModel.FLOW
                                          }
                                      }
                                  }
                    onOpenSignal:(needNotify) =>{
                                     if(needNotify){
                                         panoramaVM.stitcherType = PanoramaFilterViewModel.PRECISE
                                         stitcherSwitch.switchManual(false);
                                     }
                                 }
                }
            }

            Popup {
                id: stitcherTooltip
                // 标题行在场景坐标系中的顶部，气泡以此为基准上移
                property real anchorY: 0

                parent: Overlay.overlay
                modal: false
                focus: false
                closePolicy: Popup.NoAutoClose
                y: anchorY - height - 13
                width: Math.min(stitcherTooltipText.implicitWidth + 16, 256)
                height: stitcherTooltipText.contentHeight + 10
                padding: 0

                background: Rectangle {
                    radius: 4
                    color: Colors.color_19191A
                    border.width: 1
                    border.color: Colors.color_454649
                }

                contentItem: Text {
                    id: stitcherTooltipText
                    text: qsTr("pccut_optimize_seam_ai")
                    wrapMode: Text.WordWrap
                    font.pixelSize: 11
                    color: Colors.color_EEEEEE
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        leftMargin: 8
                        rightMargin: 8
                        topMargin: 5
                    }
                }
            }

            Rectangle {
                anchors {
                    left: parent.left
                    right: parent.right
                }
                visible: panoramaVM.aiEnable && stitchingCorrectionRec.visible
                height: 13
                color: Colors.color_transparent
            }

            // 拼接校正：加载/设置经全景统一 VM(panoramaVM)，跟随 nova 选中片段
            Connections {
                target: panoramaVM
                function onStitcherCorrectionEnabledChanged() {
                    stitchingMaskPopup.close()
                    stitcherCorrectionSwitch.enabled = true
                }
                function onSwitchPanel(open) {
                    stitcherCorrectionSwitch.switchManual(open, false)
                }
            }

            // // 拼接校正
            Rectangle {
                id: stitchingCorrectionRec
                z:2
                width: parent.width
                height: 20
                visible: panoramaVM.canShowStitcherCorrection
                anchors.left: parent.left
                color: Colors.color_transparent
                property bool hasUserClicked: lightSetting.getBool("stitchingCorrectionClicked")

                Text {
                    id: stitchingCorrectionTitle
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignLeft
                    font {
                        pixelSize: 11
                    }
                    color: Colors.color_999999
                    text: qsTr("pccut_scene_stitching_correction_click")
                }
                ColorDiffClearTips {
                    id: stitchingCorrectionTooltip
                    tipText: qsTr("pccut_scene_stitching_correction_click_hover")
                    arrowLeftMargin: stitchingCorrectionIcon.x + stitchingCorrectionIcon.width / 2
                    width: stitchingCorrectionRec.width - stitchingCorrectionTitle.x
                    height: 28
                    // width: 160
                    anchors {
                        left: stitchingCorrectionIcon.left
                        leftMargin: Math.max(-stitchingCorrectionTitle.x - stitchingCorrectionIcon.x, -(stitchingCorrectionTooltip.width - stitchingCorrectionIcon.width) / 2)
                        bottom: stitchingCorrectionIcon.top
                    }
                    visible: stitchingCorrectionIconMouseArea.containsMouse
                }

                Image {
                    id: stitchingCorrectionIcon
                    anchors{
                        left: stitchingCorrectionTitle.right
                        leftMargin: 4
                        verticalCenter: parent.verticalCenter
                    }
                    source: stitchingCorrectionIconMouseArea.containsMouse ? "qrc:/icons/ic_explain.svg" : "qrc:/icons/ic_explain_hover.svg"
                    sourceSize: Qt.size(14, 14)
                    MouseArea {
                        id: stitchingCorrectionIconMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                    }
                }
                // 新功能红点指示器
                Rectangle {
                    id: newFeatureDot
                    visible: !parent.hasUserClicked
                    width: 5
                    height: 5
                    radius: 2.5
                    color: Colors.color_FF0000
                    opacity: 1
                    anchors.left: stitchingCorrectionIcon.right
                    anchors.leftMargin: 4
                    anchors.top: stitchingCorrectionTitle.top
                    anchors.topMargin: 2
                }

                // 加载界面loading时镂空播放器效果
                VideoStitcherCorrectionLoadingMask {
                    id: stitchingMaskPopup
                    onClosed: {
                        stitcherCorrectionSwitch.enabled = true
                    }
                }

                // 镂空加载界面打开
                function openPopup() {
                    stitchingMaskPopup.playerRect = playerPanel.getPlayerPosition()
                    stitchingMaskPopup.playerControllerRect = playerPanel.getPlayerControllerPosition()
                    stitchingMaskPopup.playerPanelRect = Qt.rect(UiUtils.getGlobalPosition(playerPanel).x,
                                                    UiUtils.getGlobalPosition(playerPanel).y,
                                                    playerPanel.width,
                                                    playerPanel.height)
                    stitchingMaskPopup.open()
                }

                // 拼接校正开关
                LightBaseSwitch {
                    id:stitcherCorrectionSwitch
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    advanceControl:true
                    handlePressed:true
                    checked: panoramaVM.stitcherCorrectionEnabled
                    onCheckedChanged: {
                        logger.d("real change stitcher switch to:"+stitcherCorrectionSwitch.checked+panoramaVM.stitcherCorrectionEnabled)
                    }
                    onCloseSignal:(needNotify) =>{
                        if(!needNotify) return;
                        // 关闭只清空自标定参数，不做分析，无需弹分析蒙层
                        stitcherCorrectionSwitch.enabled = false
                        lightSetting.save("stitchingCorrectionClicked", true)
                        stitchingCorrectionRec.hasUserClicked = true
                        eventTracker.trackEvent("pccut_scene_stitching_correction_click", {"is_open": false})
                        panoramaVM.enableStitcherCorrection(false)
                    }
                    onOpenSignal:(needNotify) =>{
                        if(!needNotify) return;
                        stitcherCorrectionSwitch.enabled = false
                        // 有自标定缓存时内核秒回缓存结果，无需分析蒙层；无缓存才弹蒙层走全片分析
                        if(!panoramaVM.hasStitcherCorrectionCache()) {
                            stitchingCorrectionRec.openPopup()
                        }
                        lightSetting.save("stitchingCorrectionClicked", true)
                        stitchingCorrectionRec.hasUserClicked = true
                        eventTracker.trackEvent("pccut_scene_stitching_correction_click", {"is_open": true})
                        panoramaVM.enableStitcherCorrection(true)

                    }

                    LightToolTip {
                        id: correctionSwitchTip
                        visible: stitcherCorrectionSwitch.visible && stitcherCorrectionSwitch.hovered/*&& correctionSwitchArea.containsMouse*/
                        tip: qsTr("pccut_scene_stitching_correction_click_hover")
                    }
                }
            }


            Rectangle {
                anchors {
                    left: parent.left
                    right: parent.right
                }
                visible: panoramaVM.aiEnable || stitchingCorrectionRec.visible
                height: 13
                color: Colors.color_transparent
            }

            Rectangle {
                id: line3
                visible: panoramaVM.aiEnable
                anchors {
                    left: parent.left
                    right: parent.right
                }
                height: 1
                color: Colors.color_444444_50
            }

            // 运动模糊
            NdFilterSetting {
                id: motionBlurItem
                width: scrollView.width
                anchors.left: parent.left
                controller: videoMotionBlurController
                projectId: panel.projectId
                visible: panoramaVM.canUseNdFilterInCurClip
            }


            Rectangle {
                visible: motionBlurItem.visible
                anchors {
                    left: parent.left
                    right: parent.right
                }
                height: 16
                color: Colors.color_transparent
            }

            Rectangle {
                visible: motionBlurItem.visible
                anchors {
                    left: parent.left
                    right: parent.right
                }
                height: 1
                color: Colors.color_444444_50
            }

            Rectangle {
                visible: true
                anchors {
                    left: parent.left
                    right: parent.right
                }
                height: 16
                color: Colors.color_transparent
            }

            //畸变优化
            Rectangle {
                id: distortionOptimization
                z:1
                width: scrollView.width
                height: 16
                anchors.left: parent.left
                color: Colors.color_transparent
                clip: false
                visible: true
                Text {
                    id: distortionText
                    anchors.left: parent.left
                    anchors.topMargin: 0;
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignLeft
                    font {
                        pixelSize: 12
                    }
                    color: Colors.color_EEEEEE
                    text: qsTr("pccut_image_lens_tab")
                }

                Image {
                    id: distortionNotificationButton
                    visible: true
                    anchors {
                        left: distortionText.right
                        leftMargin: 4
                    }
                    y: distortionText.y + 1.0 * (distortionText.height - height) / 2 // 为了避免0.5px的偏差
                    source: distortionButtonMouseArea.containsMouse ? "qrc:/icons/ic_explain.svg" : "qrc:/icons/ic_explain_hover.svg"
                    sourceSize: Qt.size(14, 14)
                    MouseArea {
                        id: distortionButtonMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                    }
                }

                ColorDiffClearTips {
                    id: deDistortionTips
                    tipText: qsTr("pccut_image_lens_tip")
                    // 根据hover按钮在x轴位置设置偏移值，大于60%就将气泡箭头和位置进行一个偏移
                    property real offset: (distortionNotificationButton.x + distortionNotificationButton.width / 2) / width > 0.6 ? 50 : 0

                    arrowLeftMargin: Math.min(distortionText.width + 4,  (deDistortionTips.width - distortionNotificationButton.width) / 2 + offset) + distortionNotificationButton.width / 2
                    width: 160
                    height: 28
                    anchors {
                        left: distortionNotificationButton.left
                        //与左边标题平齐，或将中心与hover按钮放在同一x轴位置，后续为解决多语言被裁切问题，增加了offset偏移
                        leftMargin: Math.max(-distortionText.width - 4,  -(deDistortionTips.width - distortionNotificationButton.width) / 2 - offset)
                        bottom: distortionNotificationButton.top
                    }
                    visible: distortionButtonMouseArea.containsMouse
                }
            }

            Rectangle {
                anchors {
                    left: parent.left
                    right: parent.right
                }
                height: 13
                color: Colors.color_transparent
            }

            Rectangle {
                width: scrollView.width
                height: 20
                visible: true
                anchors.left: parent.left
                color: Colors.color_transparent
                clip: true
                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignLeft
                    font {
                        pixelSize: 11
                    }
                    color: Colors.color_999999
                    text: qsTr("pccut_image_lens_switch")
                }
                LightBaseSwitch {
                    id: lightBaseSwitch
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    checked: panoramaVM.deDistortionEnabled
                    Component.onCompleted:
                    {
                        var projectId = draftManager.activeProjectEnvId();
                        var isFuncExist = UsedFunctionManager.hasFunction(projectId,UsedFunctionManager.EditorFunctionType.DISTORTION_CALIBRATION);
                        if(!isFuncExist && checked)
                        {
                            UsedFunctionManager.addFunction(projectId,UsedFunctionManager.EditorFunctionType.DISTORTION_CALIBRATION);
                        }
                    }
                    onToggledSignal: {
                        panoramaVM.enableDedistortion(checked)
                        if(checked) {
                            UsedFunctionManager.addFunction(projectId,UsedFunctionManager.EditorFunctionType.DISTORTION_CALIBRATION);
                            toast.showToast(qsTr("pccut_image_lens_on"));
                        }else{
                            UsedFunctionManager.removeFunction(projectId,UsedFunctionManager.EditorFunctionType.DISTORTION_CALIBRATION);
                            toast.showToast(qsTr("pccut_image_lens_off"));
                        }
                    }

                    Connections{
                        target: panoramaVM
                        function onDeDistortionEnabledChanged(){
                            lightBaseSwitch.checked = panoramaVM.deDistortionEnabled;
                        }
                    }
                }
            }

            Item {
                anchors {
                    left: parent.left
                    right: parent.right
                }
                height: 13
            }
            Item {
                width: scrollView.width
                height: 20
                anchors.left: parent.left
                clip: true
                visible: !fileOperator.isRelease() && editorManager.debugStatus
                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignLeft
                    font {
                        pixelSize: 11
                    }
                    color: Colors.color_CCCCCC
                    text: "ai拼接(调试)"
                }
                LightBaseSwitch {
                    id: mesh_ai_Switch
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    checked: panoramaVM.stitcherType === PanoramaFilterViewModel.AI_OPTIMIZATION
                    onToggledSignal: {
                        if(checked) {
                            panoramaVM.stitcherType = PanoramaFilterViewModel.AI_OPTIMIZATION
                        } else {
                            panoramaVM.stitcherType = PanoramaFilterViewModel.MESH_LINE
                        }
                    }
                }
            }
            Item {
                width: scrollView.width
                height: 20
                anchors.left: parent.left
                clip: true
                visible: !fileOperator.isRelease() && editorManager.debugStatus
                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignLeft
                    font {
                        pixelSize: 11
                    }
                    color: Colors.color_CCCCCC
                    text: "mesh线权(调试)"
                }
                LightBaseSwitch {
                    id: mesh_line_Switch
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    checked: panoramaVM.stitcherType === PanoramaFilterViewModel.MESH_LINE
                    onToggledSignal: {
                        if(checked) {
                            panoramaVM.stitcherType = PanoramaFilterViewModel.MESH_LINE
                        } else {
                            panoramaVM.stitcherType = PanoramaFilterViewModel.MESH
                        }
                    }
                }
            }

            Item {
                width: scrollView.width
                height: 20
                anchors.left: parent.left
                clip: true
                visible: !fileOperator.isRelease() && editorManager.debugStatus
                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignLeft
                    font {
                        pixelSize: 11
                    }
                    color: Colors.color_CCCCCC
                    text: "mesh硬拼(调试)"
                }
                LightBaseSwitch {
                    id: mesh_1_Switch
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    checked: panoramaVM.stitcherType === PanoramaFilterViewModel.MESH
                    onToggledSignal: {
                        if(checked) {
                            panoramaVM.stitcherType = PanoramaFilterViewModel.MESH
                        } else {
                            panoramaVM.stitcherType = PanoramaFilterViewModel.MESH_LINE
                        }
                    }
                }
            }

            Item {
                width: scrollView.width
                height: 20
                anchors.left: parent.left
                clip: true
                visible: !fileOperator.isRelease() && editorManager.debugStatus
                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignLeft
                    font {
                        pixelSize: 11
                    }
                    color: Colors.color_CCCCCC
                    text: "mesh等权(调试)"
                }
                LightBaseSwitch {
                    id: mesh_2_Switch
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    checked: panoramaVM.stitcherType === PanoramaFilterViewModel.MESH_EQUAL
                    onToggledSignal: {
                        if(checked) {
                            panoramaVM.stitcherType = PanoramaFilterViewModel.MESH_EQUAL
                        } else {
                            panoramaVM.stitcherType = PanoramaFilterViewModel.MESH_LINE
                        }
                    }
                }
            }

            Item {
                width: scrollView.width
                height: 20
                anchors.left: parent.left
                clip: true
                visible: !fileOperator.isRelease() && editorManager.debugStatus
                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignLeft
                    font {
                        pixelSize: 11
                    }
                    color: Colors.color_CCCCCC
                    text: "mesh算法测试(调试)"
                }
                LightBaseSwitch {
                    id: mesh_test_Switch
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 24
                    height: 14
                    checked: panoramaVM.stitcherType === PanoramaFilterViewModel.STITCHER_TEST
                    onToggledSignal: {
                        if(checked) {
                            panoramaVM.stitcherType = PanoramaFilterViewModel.STITCHER_TEST
                        } else {
                            panoramaVM.stitcherType = PanoramaFilterViewModel.MESH_LINE
                        }
                    }
                }
            }
            Rectangle {
                width: scrollView.width
                height: 20
                anchors.left: parent.left
                visible:  editorManager.debugStatus && !fileOperator.isRelease()
                color: Colors.color_transparent
                clip: true

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter // 垂直居中
                    horizontalAlignment: Text.AlignLeft // 水平对齐方式为靠左
                    font {
                        pixelSize: 11
                    }
                    color: Colors.color_999999
                    text: "多框（TK调试）"
                }
                LightBaseSwitch {
                    id: multiRectSwitch
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    checked: lightSetting.getBool("multiRectShow")
                    onToggledSignal: {
                        var multiRectShow = lightSetting.getBool("multiRectShow")
                        lightSetting.save("multiRectShow", !multiRectShow)
                    }
                }
            }
            Rectangle {
                width: scrollView.width
                height: 20
                anchors.left: parent.left
                visible: !fileOperator.isRelease() && editorManager.debugStatus
                color: Colors.color_transparent
                clip: true

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter // 垂直居中
                    horizontalAlignment: Text.AlignLeft // 水平对齐方式为靠左
                    font {
                        pixelSize: 11
                    }
                    color: Colors.color_999999
                    text: "开启日志（TK调试）"
                }
                LightBaseSwitch {
                    id: tkLogSwitch
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    checked: lightSetting.getBool("tkLogSwitch")
                    onToggledSignal: {
                        var tkLogSwitch = lightSetting.getBool("tkLogSwitch")
                        lightSetting.save("tkLogSwitch", !tkLogSwitch)
                    }
                }
            }
            Rectangle {
                width: scrollView.width
                height: 20
                anchors.left: parent.left
                visible: !fileOperator.isRelease() && editorManager.debugStatus
                color: Colors.color_transparent
                clip: true

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter // 垂直居中
                    horizontalAlignment: Text.AlignLeft // 水平对齐方式为靠左
                    font {
                        pixelSize: 11
                    }
                    color: Colors.color_999999
                    text: "初始目标测试（TK调试）"
                }
                LightBaseSwitch {
                    id: targetSw
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    checked: lightSetting.getBool("targetSw")
                    onToggledSignal: {
                        var targetSw = lightSetting.getBool("targetSw")
                        lightSetting.save("targetSw", !targetSw)
                    }
                }
            }

            Rectangle {
                width: scrollView.width
                height: 20
                anchors.left: parent.left
                visible: !fileOperator.isRelease() && editorManager.debugStatus
                color: Colors.color_transparent
                clip: true

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter // 垂直居中
                    horizontalAlignment: Text.AlignLeft // 水平对齐方式为靠左
                    font {
                        pixelSize: 11
                    }
                    color: Colors.color_999999
                    text: "死区测试（TK调试）"
                }
                LightBaseSwitch {
                    id: deathZoneSw
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    checked: lightSetting.getBool("deathZoneSw")
                    onToggledSignal: {
                        var deathZoneSw = lightSetting.getBool("deathZoneSw")
                        lightSetting.save("deathZoneSw", !deathZoneSw)
                    }
                }
            }

            Rectangle {
                width: scrollView.width
                height: 20
                anchors.left: parent.left
                visible: !fileOperator.isRelease() && editorManager.debugStatus
                color: Colors.color_transparent
                clip: true

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter // 垂直居中
                    horizontalAlignment: Text.AlignLeft // 水平对齐方式为靠左
                    font {
                        pixelSize: 11
                    }
                    color: Colors.color_999999
                    text: "是否要播放"
                }
                LightBaseSwitch {
                    id: ifPause
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    checked: lightSetting.getBool("ifPause")
                    onToggledSignal: {
                        var ifPause = lightSetting.getBool("ifPause")
                        lightSetting.save("ifPause", !ifPause)
                    }
                }
            }

            Rectangle {
                anchors {
                    left: parent.left
                    right: parent.right
                }
                height: 10
                color: Colors.color_transparent
            }
            Rectangle {
                width: scrollView.width
                height: 24
                anchors.left: parent.left
                color: Colors.color_transparent
                visible: !fileOperator.isRelease() && editorManager.debugStatus
                clip: true
                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignLeft
                    font {
                        pixelSize: 11
                    }
                    color: Colors.color_999999
                    text: qsTr("底部拼接优化")
                }

                ComboBox {
                    id: maskComboBox
                    opacity: 1
                    anchors {
                        top: parent.top
                        left: parent.left
                        leftMargin: 70
                        verticalCenter: parent.verticalCenter
                    }
                    width: parent.width - 70
                    height: 24

                    Keys.onPressed: (event)=> {
                                        event.accepted = true; // 阻止按键事件的默认行为
                                    }

                    Keys.onReleased: (event)=> {
                                         event.accepted = true; // 阻止按键事件的默认行为
                                     }

                    contentItem: Text {
                        anchors.left: parent.left
                        leftPadding: 8
                        text: maskComboBox.currentText
                        font.pixelSize: 12
                        color: Colors.color_EEEEEE
                        opacity: 1
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }

                    background: Rectangle {
                        color: Colors.color_353738
                        radius: 4
                        border.color: "black"
                        border.width: 1
                    }

                    model:editorManager.getMaskKeys()
                    currentIndex: 0 // 默认选中首个
                }
            }

            Rectangle {
                anchors {
                    left: parent.left
                    right: parent.right
                }
                height: 10
                color: Colors.color_transparent
                visible: !fileOperator.isRelease()
            }
            Rectangle {
                width: scrollView.width
                height: 24
                anchors.left: parent.left
                color: Colors.color_transparent
                visible: !fileOperator.isRelease() && editorManager.debugStatus
                clip: true
                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignLeft
                    font {
                        pixelSize: 11
                    }
                    color: Colors.color_999999
                    text: qsTr("Calib_para")
                }

                ComboBox {
                    id: snComboBox
                    opacity: 1
                    anchors {
                        top: parent.top
                        left: parent.left
                        leftMargin: 70
                        verticalCenter: parent.verticalCenter
                    }
                    width: parent.width - 70
                    height: 24

                    Keys.onPressed: (event)=> {
                                        event.accepted = true; // 阻止按键事件的默认行为
                                    }

                    Keys.onReleased: (event)=> {
                                         event.accepted = true; // 阻止按键事件的默认行为
                                     }

                    contentItem: Text {
                        anchors.left: parent.left
                        leftPadding: 8
                        text: panoramaVM.currentSn
                        font.pixelSize: 12
                        color: Colors.color_EEEEEE
                        opacity: 1
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }

                    background: Rectangle {
                        color: Colors.color_353738
                        radius: 4
                        border.color: "black"
                        border.width: 1
                    }

                    model: panoramaVM.snNameList()
                    onActivated: {
                        panoramaVM.currentSn = model[currentIndex]
                    }
                }
            }

            Item {
                anchors {
                    left: parent.left
                    right: parent.right
                }
                height: 10
            }
            Item {
                width: scrollView.width
                height: 24
                anchors.left: parent.left
                clip: true
                visible: !fileOperator.isRelease() && editorManager.debugStatus
                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignLeft
                    font {
                        pixelSize: 11
                    }
                    color: Colors.color_CCCCCC
                    text: "intrinsic"
                }

                ComboBox {
                    id: intrinsicComboBox
                    opacity: 1
                    anchors {
                        top: parent.top
                        left: parent.left
                        leftMargin: 70
                        verticalCenter: parent.verticalCenter
                    }
                    width: parent.width - 70
                    height: 24

                    Keys.onPressed: (event)=> {
                                        event.accepted = true; // 阻止按键事件的默认行为
                                    }

                    Keys.onReleased: (event)=> {
                                         event.accepted = true; // 阻止按键事件的默认行为
                                     }

                    contentItem: Text {
                        anchors.left: parent.left
                        leftPadding: 8
                        text: panoramaVM.currentMeshIntrinsic
                        font.pixelSize: 12
                        color: Colors.color_EEEEEE
                        opacity: 1
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }

                    background: Rectangle {
                        color: Colors.color_353738
                        radius: 4
                        border.color: "black"
                        border.width: 1
                    }

                    model: panoramaVM.meshIntrinsicNameList()
                    onActivated: {
                        panoramaVM.currentMeshIntrinsic = model[currentIndex]
                    }
                }
            }
            Item {
                anchors {
                    left: parent.left
                    right: parent.right
                }
                height: 10
            }
            Item {
                anchors {
                    left: parent.left
                    right: parent.right
                }
                height: 28
                visible: !fileOperator.isRelease() && editorManager.debugStatus
                TextInput {
                    height: 28
                    anchors {
                        left: parent.left
                        right: parent.right
                    }

                    // 设置 TextField 的初始文本内容
                    // 设置文本的对齐方式
                    horizontalAlignment: TextInput.AlignLeft
                    // 选择文本的字体和颜色
                    font.pixelSize: 12
                    // 按住鼠标左键选择文本
                    selectByMouse: true
                    selectionColor: Colors.color_EEEEEE // 选中文本的背景色
                    selectedTextColor: Colors.color_000000_70   // 选中文本的颜色4
                    color: Colors.color_EEEEEE
                    leftPadding: 8
                    validator: DoubleValidator {}
                    text: panoramaVM.meshValue
                    onAccepted: {
                        panoramaVM.meshValue = Number(text);
                        focus = false // 处理小键盘Enter键
                    }
                }
            }


        }
        }
    }
}
