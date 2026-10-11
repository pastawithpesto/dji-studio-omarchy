import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.3
import Controls 1.0
import Config 1.0
import app_qrc 1.0
import "../transition"
import "../effect"

//包含一个tab切换整体结构
Rectangle {
    id: root
    anchors.fill: parent
    color: Colors.color_141414

    property var managedPopups: ({})

    LightClipRectangle {
        id: topBarBG
        height: 45
        width: parent.width
        color: Colors.color_title_area_background

        TabBar {
            // 记录之前的索引
            property int previousIndex: 0
            // 仪表盘索引 - 需要根据平台动态调整
            property int dashboardIndex: 7
            id: topbar
            height: topBarBG.height
            spacing: 24  // 设置间距
            anchors {
                fill: parent
                topMargin: 4
                leftMargin: 12
                rightMargin: 8
            }
            background: Rectangle {
                color: Colors.transparent
            }
            onCurrentIndexChanged: {
                draftUIManager.materiaIndex = currentIndex;
                if(currentIndex === dashboardIndex){
                    var importPopup = PopupManager.getPopup("qrc:/qml/controller/SportsDataImportPopup.qml");
                    var currentDashboardTab = stackLayout.itemAt(dashboardIndex);
                    if(currentDashboardTab && !currentDashboardTab.dashboardListModel.isFirstClickDashboard()) {
                        importPopup.parent = lightWindow.contentItem;
                        importPopup.closePolicy = Popup.CloseOnEscape | Popup.NoAutoClose;
                        importPopup.anchors.centerIn = importPopup.parent;
                        importPopup.isFirstTime = false;
                        importPopup.width = 360;
                        importPopup.objectName = actionableItemName.sportsDataImportPopup
                        importPopup.open();
                        managedPopups[importPopup.objectName] = importPopup;

                        if (!importPopup.signalsConnected) {
                            importPopup.confirmSignal.connect(function() {
                                importPopup.isFirstTime = true;
                                currentDashboardTab.dashboardListModel.setFirstClickDashboard();
                                currentDashboardTab.dashboardListModel.addDashboardFromIndex(0, true);
                            });
                            importPopup.cancelSignal.connect(function() {
                                importPopup.isFirstTime = true;
                                currentDashboardTab.dashboardListModel.setFirstClickDashboard();
                            });
                            importPopup.signalsConnected = true;
                        }
                    }
                    else {
                        importPopup.isFirstTime = true;
                    }
                }
            }
            Component.onCompleted: {
                transitionTabButtonComponent.createObject(topbar);
                if(!CommonUtils.isWindows()){
                    // 动态添加OverlayTextMaterialTabView              
                }
                textTabButtonComponent.createObject(topbar);
                // 动态添加DashBoardMaterialTabView
                dashboardTabButtonComponent.createObject(topbar);
            }
            MaterialTabButton {
                y: 0
                title: qsTr("pccut_menu_file")
                objectName: actionableItemName.titleBarForFileTypeIcon
                imageSource: "qrc:/app_qrc/icons/tab_flie.svg"
            }
            MaterialTabButton {
                title: qsTr("pccut_music")
                objectName: actionableItemName.titleBarForMusicTypeIcon
                imageSource: "qrc:/app_qrc/icons/tab_music.svg"
                onClicked: {
                    eventTracker.trackEvent("pccut_music_click")
                }
            }
            MaterialTabButton {
                title: qsTr("pccut_filter")
                objectName: actionableItemName.titleBarForFilterTypeIcon
                imageSource: "qrc:/app_qrc/icons/tab_filter.svg"
                onClicked: {
                    eventTracker.trackEvent("pccut_filter_click")
                }
            }
            // 特效
            MaterialTabButton {
                title: qsTr("pccut_tab_effects")
                objectName: actionableItemName.titleBarForFilterTypeIcon
                imageSource: "qrc:/app_qrc/icons/tab_special_effect.svg"
                onClicked: {
                    eventTracker.trackEvent("pccut_effect_tab_click")
                }
            }
            // 运镜模版
            MaterialTabButton {
                title: qsTr("pccut_resource_movement_ title")
                objectName: actionableItemName.titleBarForDashBoardTypeIcon
                imageSource: "qrc:/icons/ic_camera_move.svg"
                onClicked: {
                    eventTracker.trackEvent("pccut_movement_click")
                }
            }
            Component {
                id: transitionTabButtonComponent
                MaterialTabButton {
                    title: qsTr("pccut_resource_transition_title")
                    objectName: actionableItemName.titleBarForDashBoardTypeIcon
                    imageSource: "qrc:/app_qrc/icons/tab_transition.svg"
                    onClicked: {
                    }
                }
            }

            // 文字素材标签 - 动态创建
            Component {
                id: textTabButtonComponent
                MaterialTabButton {
                    title: qsTr("pccut_word_title")
                    objectName: actionableItemName.titleBarForTextTypeIcon
                    imageSource: "qrc:/app_qrc/icons/tab_text.svg"
                    onClicked: {
                        eventTracker.trackEvent("pccut_text_click")
                    }
                }
            }
            // 移动位置的时候注意修改 dashboardIndex数值！
            Component {
                id: dashboardTabButtonComponent
                MaterialTabButton {
                    title: qsTr("pccut_dashboard")
                    objectName: actionableItemName.titleBarForDashBoardTypeIcon
                    imageSource: "qrc:/app_qrc/icons/tab_dashboard.svg"
                    onClicked: {
                        eventTracker.trackEvent("pccut_dashboard_click")
                    }
                }
            }
        }

        Connections{
            target: globalSignal
            function onChangeToFilterTab(){
                var filterIndex = 0;
                for (var i = 0; i < topbar.count; i++) {
                    if (topbar.itemAt(i).title === qsTr("pccut_filter")) {
                        filterIndex = i;
                        break;
                    }
                }
                topbar.currentIndex = filterIndex;
            }

            function onShowInMediaLibrary(paths) {
                // 切换到本地素材tab，具体定位由 VideoMaterialTabView 处理
                topbar.currentIndex = 0
            }
        }
    }
    Component {
        id: transitionTabComponent
        TransitionMaterialTabView{
            id: transtionTab
            initSplitPosition: stackLayout.sharedSplitPosition
            onVisibleChanged: {
                if(!visible){
                    stackLayout.sharedSplitPosition = transtionTab.lastAxisPos;
                }
            }
        }
    }

    Component {
        id: textTabComponent
        OverlayTextMaterialTabView {
            id: textTab
            initSplitPosition: stackLayout.sharedSplitPosition
            onVisibleChanged: {
                if(!visible){
                    stackLayout.sharedSplitPosition = textTab.lastAxisPos;
                }
            }
        }
    }
    Component {
        id: dashboardTabComponent
        DashBoardMaterialTabView {
            id: dashboardTab
            initSplitPosition: stackLayout.sharedSplitPosition
            onVisibleChanged: {
                if(!visible){
                    stackLayout.sharedSplitPosition = dashboardTab.lastAxisPos;
                }
            }
        }
    }

    // 资源列表Tab
    Item{
        id: materialTabs
        anchors {
            left: parent.left
            right: parent.right
            top: topBarBG.bottom
            topMargin: 1
            bottom: parent.bottom
        }
        Component.onCompleted: {
            transitionTabComponent.createObject(stackLayout);
            if(!CommonUtils.isWindows()){
                // 动态添加
            }
            textTabComponent.createObject(stackLayout);
            // 动态添加DashBoardMaterialTabView
            dashboardTabComponent.createObject(stackLayout);
        }
        StackLayout {
            id: stackLayout
            property real sharedSplitPosition: 120 // 所有tab的共用左右分割线位置(主要用来处理在TabA中调整了分割线位置之后，切换到TabB时仍然需要保持TabA中分割线的位置)
            // SplitView.minimumWidth: 292
            anchors.fill: parent
            clip: true
            currentIndex: topbar.currentIndex
            onCurrentIndexChanged: {
                let currentItem = stackLayout.children[stackLayout.currentIndex]
                currentItem.leftViewLoader.active = true
                currentItem.rightViewLoader.active = true
            }
            // 视频素材列表Tab
            VideoMaterialTabView{
                id: mediaTab
                initSplitPosition: stackLayout.sharedSplitPosition
                // 当前页面被切换时更新分割线的位置，新tab中的初始位置需要使用这个位置，保证切换tab时分割线的位置保持不变
                onVisibleChanged: {
                    if(!visible){
                        stackLayout.sharedSplitPosition = mediaTab.lastAxisPos;
                    }
                }

            }

            // 音频素材列表Tab
            AudioMaterialTabView{
                id: audioTab
                initSplitPosition: stackLayout.sharedSplitPosition
                onVisibleChanged: {
                    if(!visible){
                        stackLayout.sharedSplitPosition = audioTab.lastAxisPos;

                    }
                }
            }

            // 滤镜资源列表Tab
            FilterMaterialTabView{
                id: filterTab
                initSplitPosition: stackLayout.sharedSplitPosition
                onVisibleChanged: {
                    if(!visible){
                        stackLayout.sharedSplitPosition = filterTab.lastAxisPos;

                    }
                }
            }

            // 特效资源列表Tab
            SpecialEffectTabView {
                id: effectTab
                initSplitPosition: stackLayout.sharedSplitPosition
                onVisibleChanged: {
                    if(!visible){
                        stackLayout.sharedSplitPosition = effectTab.lastAxisPos;
                    }
                }
            }

            // 运镜模版资源列表Tab
            CameraMoveAssetTab {
                id: cameraMoveAssetTab
                initSplitPosition: stackLayout.sharedSplitPosition
                onVisibleChanged: {
                    if(!visible){
                        stackLayout.sharedSplitPosition = cameraMoveAssetTab.lastAxisPos;

                    }
                }
            }

            // // 转场资源列表Tab 暂不暴露接口
            // TransitionMaterialTabView{
            //     id: transtionTab
            //     visible: !CommonUtils.isWindows()
            //     initSplitPosition: stackLayout.sharedSplitPosition
            //     onVisibleChanged: {
            //         if(!visible){
            //             stackLayout.sharedSplitPosition = transtionTab.lastAxisPos;
            //         }
            //     }
            // }

            // // 文字素材tab
            // OverlayTextMaterialTabView {
            //     id: textTab
            //     visible: !CommonUtils.isWindows()
            //     initSplitPosition: stackLayout.sharedSplitPosition
            //     onVisibleChanged: {
            //         if(!visible){
            //             stackLayout.sharedSplitPosition = textTab.lastAxisPos;
            //         }
            //     }
            // }

            // // 仪表盘资源列表Tab
            // DashBoardMaterialTabView {
            //     id: dashboardTab
            //     initSplitPosition: stackLayout.sharedSplitPosition
            //     onVisibleChanged: {
            //         if(!visible){
            //             stackLayout.sharedSplitPosition = dashboardTab.lastAxisPos;

            //         }
            //     }
            // }
        }
    }

    Connections {
        target: globalSignal
        function onImportMedia(urls, operationType, needSwitchTab) {
            if(needSwitchTab) {
                topbar.currentIndex = 0
                mediaTab.switchTab(0,urls, operationType)
            }
            else {
                mediaTab.importMedia(urls, operationType)
            }
        }

        //草稿切换时，素材库tab切换回草稿保存的tab
        function onActivedProjectChanged(id) {
            if(draftUIManager.isActiveProjectExist()) {
                var index = draftUIManager.materiaIndex >= topbar.count ? 0 : draftUIManager.materiaIndex;
                topbar.currentIndex = index;
            }
        }
    }

    // 获取当前素材面板区所选设备的设备名，如无设备连接则为空
    function getMediaTabSelectedDeviceName() {
        return mediaTab.getMediaTabSelectedDeviceName();
    }

    Component.onCompleted: {
        mediaTab.leftViewLoader.active = true
        mediaTab.rightViewLoader.active = true
    }
}
