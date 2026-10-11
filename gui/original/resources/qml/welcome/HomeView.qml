import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.3
import Controls 1.0
import Config 1.0
import Qt5Compat.GraphicalEffects
import DeviceFileInfoModel 1.0
import BannerManager 1.0
import CopiedFileListModel 1.0
import app_qrc 1.0
import "cloudalbum"

import UsedFunctionManager 1.0
import ShortcutAction 1.0
import CloudAlbumManager 1.0
import "../controller"

LightClipRectangle {
    id: homeView
    color: Colors.color_141414

    CShortcut {
        action: ShortcutAction.ESCAPE_FULL_SCREEN
        enabled: homeView.visible && homeView.showDraftSelectState
        priority: 1
        onActivated: {
            homeView.showDraftSelectState = false
            draftListViewModel.resetSelectedDrafts()
        }
    }
    radius: [0, 0, 9, 9]
    property bool showSelectState: true
    property bool showDraftSelectState: false
    onShowSelectStateChanged: {
        // ✓ multipleSelectBtn 由 DeviceView 中的数据绑定自动处理，无需在此手动赋值
        // 移除冗余的命令式赋值可避免与数据绑定的冲突和循环
    }
    property bool isSwitchIngDevicePage: false
    // 由于连接上的设备是由ListModel管理，因此List中Index = 0的位置代表第一个设备，为了统一管理，常驻的首页和设备连接按钮则置为-2和-1
    property int homeButtonIndex: 0
    property int deviceButtonIndex: 1
    property int deviceEmptyIndex: 2
    property int deviceDownloadIndex: 3
    property int recycleBinIndex: 4
    property bool recycleBinRedDot: false
    property var draftToastParent: null
    property int cloudAlbumIndex: 5
    // 云相册已登录视图是否正在显示
    property bool isCloudAlbumVisible: cloudAlbumFeatureFlags.enable
                                       && stackView.currentIndex === cloudAlbumIndex

    Connections {
        target: cloudAlbumFeatureFlags

        function onEnableChanged() {
            if (!cloudAlbumFeatureFlags.enable
                    && stackView.currentIndex === homeView.cloudAlbumIndex) {
                stackView.changeTab(homeView.homeButtonIndex)
            }
        }
    }

    // 灰度运行中被紧急停用/登出置 false 时，若正停留在云相册页则跳回首页，避免卡死在空页
    Connections {
        target: CloudAlbumManager

        function onGrayCloudAlbumAvailableChanged() {
            if (!CloudAlbumManager.grayCloudAlbumAvailable
                    && stackView.currentIndex === homeView.cloudAlbumIndex) {
                stackView.changeTab(homeView.homeButtonIndex)
            }
        }
    }

    // 跳转到云相册并滚动到指定文件
    function navigateToCloudAlbumAsset(fileName) {
        if (!cloudAlbumFeatureFlags.enable) {
            return;
        }
        console.log("[CloudAlbumNav] navigateToCloudAlbumAsset fileName=" + fileName
                    + " currentIndex=" + stackView.currentIndex
                    + " targetIndex=" + cloudAlbumIndex)
        stackView.changeTab(cloudAlbumIndex);
        console.log("[CloudAlbumNav] navigateToCloudAlbumAsset after changeTab currentIndex=" + stackView.currentIndex
                    + " loaderReady=" + !!cloudAlbumPageLoader.item)
        if (cloudAlbumPageLoader.item) {
            cloudAlbumPageLoader.item.scrollToFileName(fileName);
        }
    }

    function enterCloudAlbum() {
        cloudAlbumEventReport.trackEnterClick(0)  // 0 = EnterMethod::Home
        // 用户服务协议每个账号只弹一次：同意态存在 SDK 的账号库里，换账号或本地
        // 数据丢失会重新弹；读不到一律按未同意处理（宁可多弹，不可漏弹）。
        if (CloudAlbumManager.isCloudAlbumAgreementAccepted()) {
            stackView.changeTab(homeView.cloudAlbumIndex)
            return
        }
        // 只加载一次、之后复用（同 MenuBarPopupLayers 的 restartPopupLoader）。
        // 千万不要在按钮回调里 active = false：ConfirmPopup 的 close() 只是启动 100ms
        // 退出动画，closed 要等动画结束才发；提前销毁弹窗会让基类 LightPopup.onClosed
        // 里的 enableMenuBar(true) 永远不执行，菜单栏就一直置灰了。
        if (!cloudAlbumAgreementLoader.active) {
            cloudAlbumAgreementLoader.active = true
        }
        cloudAlbumAgreementLoader.item.open()
    }
    // 下载完成后的红色小点
    property bool copiedRed: false

    SplitView {
        id: topSplitView
        orientation: Qt.Horizontal
        anchors.fill: parent
        anchors.margins: 0
        SplitView.fillHeight: true
        handle: Rectangle {
            implicitWidth: 1
            color: Colors.color_141414
            containmentMask: Item {
                z: 1
                x: -4
                width: 9
                height: topSplitView.height
            }
        }



        //左侧导航栏
        Rectangle {
            id: navigation
            SplitView.minimumWidth: 216
            SplitView.maximumWidth: 256
            color: Colors.color_1F2021

            QtObject {
                id: navigationButtonSetting
                property int buttonWidth: 140
                property int buttonHeight: 44
                property color textColorNormal: Colors.color_EEEEEE
                property color textColorChecked: ColorsConfig.color_brand
                property color textColorHoverd: Colors.color_FFFFFF
                property color backgroundNormal: Colors.transparent
                property color backgroundChecked: Colors.color_check_button_background_checked
                property color backgroundHoverd: Colors.color_FFFFFF_10
            }

            ColumnLayout{
                anchors.fill: parent
                spacing: 12

                IconTextButton{
                    id :homeBtn
                    iconPathNormal: "qrc:/app_qrc/icons/icon_home_normal.svg"
                    iconPathChecked: "qrc:/app_qrc/icons/icon_home_pressed.svg"
                    iconSizeNormal: Qt.size(24, 24)
                    iconSizeChecked: Qt.size(24, 24)
                    title: qsTr("pccut_home")
                    Layout.topMargin: 48
                    Layout.leftMargin: 28
                    Layout.rightMargin: 28
                    Layout.fillWidth: true
                    Layout.preferredHeight: navigationButtonSetting.buttonHeight
                    //preferredWidth: navigationButtonSetting.buttonWidth
                    leftPadding: 18
                    rightPadding: 18
                    titleColorNormal: navigationButtonSetting.textColorNormal
                    titleColorChecked: navigationButtonSetting.textColorChecked
                    backgroundColorNormal: navigationButtonSetting.backgroundNormal
                    backgroundColorChecked: navigationButtonSetting.backgroundChecked
                    titleColorHover: navigationButtonSetting.textColorHoverd
                    Layout.alignment: Qt.AlignHCenter
                    manualChecked: stackView.currentIndex === homeButtonIndex
                    internalSpacing: 8
                    radius: RadiusConfig.radius_6_88
                    titleFontSize: 14
                    presseable: false

                    onCustomClicked: {
                        eventTracker.trackEvent("pccut_home_click");
                        stackView.changeTab(homeView.homeButtonIndex);
                    }
                }
                IconTextButton{
                    id: downloadBtn
                    iconPathNormal: "qrc:/app_qrc/icons/home_download_normal.svg"
                    iconPathChecked: "qrc:/app_qrc/icons/home_download_selected.svg"
                    iconSizeNormal: Qt.size(24, 24)
                    iconSizeChecked: Qt.size(24, 24)
                    title: qsTr("pccut_device_batch_my_download")
                    Layout.leftMargin: 28
                    Layout.rightMargin: 28
                    Layout.fillWidth: true
                    Layout.preferredHeight: navigationButtonSetting.buttonHeight
                    leftPadding: 18
                    rightPadding: 18
                    titleColorNormal: navigationButtonSetting.textColorNormal
                    titleColorChecked: navigationButtonSetting.textColorChecked
                    backgroundColorNormal: navigationButtonSetting.backgroundNormal
                    backgroundColorChecked: navigationButtonSetting.backgroundChecked
                    titleColorHover: navigationButtonSetting.textColorHoverd
                    Layout.alignment: Qt.AlignHCenter
                    manualChecked: stackView.currentIndex === deviceDownloadIndex
                    internalSpacing: 8
                    radius: RadiusConfig.radius_6_88
                    titleFontSize: 14
                    presseable: false
                    visible: copyFileManager.hasCopyFile
                    Rectangle {
                        visible: copiedRed
                        width: 5
                        height: 5
                        radius: 2.5
                        color: ColorsConfig.color_brand
                        x: {
                            // 计算文本起始位置
                            let textStartX = downloadBtn.leftPadding

                            // 如果有图标，加上图标宽度和间距
                            if (!downloadBtn.isTextOnly) {
                                textStartX += downloadBtn.imageRectWidth + downloadBtn.internalSpacing
                            }

                            // 文本结束位置 + 间距
                            return textStartX + downloadBtn.title1.implicitWidth + 6
                        }
                        y: 13
                    }
                    onCustomClicked: {
                        copiedRed = false;
                        stackView.changeTab(homeView.deviceDownloadIndex);
                    }
                }
                IconTextButton {
                    id :deviceBtn
                    iconPathNormal: "qrc:/app_qrc/icons/icon_device_normal.svg"
                    iconPathChecked: "qrc:/app_qrc/icons/icon_device_pressed.svg"
                    iconSizeNormal: Qt.size(24, 24)
                    iconSizeChecked: Qt.size(24, 24)
                    title: deviceCount > 0 ? qsTr("pccut_device_connected") : qsTr("pccut_device");
                    Layout.leftMargin: 28
                    Layout.rightMargin: 28
                    Layout.fillWidth: true
                    Layout.preferredHeight: navigationButtonSetting.buttonHeight
                    leftPadding: 18
                    rightPadding: 18
                    titleColorNormal: navigationButtonSetting.textColorNormal
                    titleColorChecked: navigationButtonSetting.textColorChecked
                    backgroundColorNormal: navigationButtonSetting.backgroundNormal
                    backgroundColorChecked: navigationButtonSetting.backgroundChecked
                    titleColorHover: navigationButtonSetting.textColorHoverd
                    Layout.alignment: Qt.AlignHCenter
                    manualChecked: stackView.currentIndex === deviceButtonIndex || stackView.currentIndex === deviceEmptyIndex
                    internalSpacing: 8
                    radius: RadiusConfig.radius_6_88
                    titleFontSize: 14
                    presseable: false

                    property int deviceCount: deviceListViewModel.deviceCount

                    onCustomClicked: {
                        eventTracker.trackEvent("pccut_device_connection_click");
                        if (deviceListViewModel.deviceCount === 0) {
                            stackView.changeTab(deviceEmptyIndex);
                        } else if (stackView.currentIndex !== deviceButtonIndex){
                            stackView.changeTab(deviceButtonIndex);
                            globalSignal.deviceSelected(deviceListViewModel.getDeviceNameByIndex(deviceListViewModel.currentIndex))
                        }
                    }
                }
                ListView {
                    id: deviceListView
                    Layout.preferredHeight: contentHeight
                    Layout.fillWidth: true
                    model: deviceListViewModel
                    spacing: 12
                    interactive: false
                    visible: deviceListViewModel.deviceCount > 0

                    delegate: IconTextButton {
                        title: Tools.getDeviceRealName(model.name)
                        iconPathNormal: "qrc:/app_qrc/icons/icon_real_device_normal.svg"
                        iconPathChecked: "qrc:/app_qrc/icons/icon_real_device_selected.svg"
                        iconSizeNormal: Qt.size(24, 24)
                        iconSizeChecked: Qt.size(24, 24)
                        anchors {
                            leftMargin: 28
                            rightMargin: 28
                            left: parent.left
                            right: parent.right
                        }
                        height: navigationButtonSetting.buttonHeight
                        titleColorNormal: navigationButtonSetting.textColorNormal
                        titleColorChecked: navigationButtonSetting.textColorChecked
                        backgroundColorNormal: Colors.transparent
                        leftPadding: 18
                        rightPadding: 18
                        internalSpacing: 8
                        manualChecked: deviceBtn.manualChecked && index === deviceListViewModel.currentIndex
                        radius: RadiusConfig.radius_6_88
                        titleFontSize: 14
                        presseable: false
                        titleColorHover:  navigationButtonSetting.textColorHoverd
                        onCustomClicked: {
                            stackView.changeTab(deviceButtonIndex);
                            globalSignal.deviceSelected(model.name)
                            if (deviceListViewModel.currentIndex !== index) {
                                showSelectState = false
                            }

                            deviceListViewModel.currentIndex = index
                        }
                    }
                }

                IconTextButton {
                    id: cloudAlbumBtn
                    objectName: "cloudAlbumNavBtn"
                    // 功能开关 + 灰度双重控制：未登录/未灰度时隐藏入口
                    visible: cloudAlbumFeatureFlags.enable
                             && CloudAlbumManager.grayCloudAlbumAvailable
                    iconPathNormal: "qrc:/app_qrc/icons/icon_cloud_album_normal.svg"
                    iconPathChecked: "qrc:/app_qrc/icons/icon_cloud_album_pressed.svg"
                    iconSizeNormal: Qt.size(24, 24)
                    iconSizeChecked: Qt.size(24, 24)
                    title: qsTr("pccut_cloud_album")
                    Layout.leftMargin: 28
                    Layout.rightMargin: 28
                    Layout.fillWidth: true
                    Layout.preferredHeight: navigationButtonSetting.buttonHeight
                    leftPadding: 18
                    rightPadding: 18
                    titleColorNormal: navigationButtonSetting.textColorNormal
                    titleColorChecked: navigationButtonSetting.textColorChecked
                    backgroundColorNormal: navigationButtonSetting.backgroundNormal
                    backgroundColorChecked: navigationButtonSetting.backgroundChecked
                    titleColorHover: navigationButtonSetting.textColorHoverd
                    Layout.alignment: Qt.AlignHCenter
                    manualChecked: stackView.currentIndex === cloudAlbumIndex
                    internalSpacing: 8
                    radius: RadiusConfig.radius_6_88
                    titleFontSize: 14
                    presseable: false

                    onCustomClicked: {
                        console.log("[CloudAlbumNav] cloudAlbumBtn.onCustomClicked currentIndex=" + stackView.currentIndex
                                    + " targetIndex=" + homeView.cloudAlbumIndex)
                        homeView.enterCloudAlbum()
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }

                BannerManager {
                    id: bannerManager
                }
                Loader {
                    id: bannerWidgetLoader
                    // 布局器会根据加载的内容自动调整该项占位大小
                    Layout.fillWidth: true
                    Layout.preferredHeight: width * 9 / 16
                    Layout.leftMargin: 28
                    Layout.rightMargin: 28
                    Layout.bottomMargin: 28
                    asynchronous: editorABConfig.asyncLoadComponent
                    onLoaded: {
                        bannerManager.loadData()
                    }
                    sourceComponent: bannerWidgetComponent
                }
                Component{
                   id: bannerWidgetComponent
                LightClipRectangle {
                    id: bannerWidget
                    anchors.fill: parent
                    //Layout.fillWidth: true
                    //Layout.preferredHeight: width * 9 / 16
                    //Layout.leftMargin: 28
                    //Layout.rightMargin: 28
                    //Layout.bottomMargin: 28
                    radius: [6, 6, 6, 6]
                    color: Colors.transparent
                    
                    visible: bannerManager.hasNetWork && bannerManager.modelCount > 0
                    readonly property int quickAnimationDuration: 100
                    readonly property int normalAnimationDuration: 300
                    Timer {
                        id: bannerLoopTimer
                        interval: 3000
                        repeat: true
                        running: lightWindow.active && bannerWidget.visible
                        onTriggered: {
                            if (bannerManager.modelCount > 1) {
                                bannerView.switchBanner(true)
                            }
                        }
                    }
                    
                    // 防连点计时器
                    Timer {
                        id: antiMisclickTimer
                        interval: bannerWidget.quickAnimationDuration
                        running: false
                    }

                    Rectangle {
                        id: bannerView
                        anchors.fill: parent
                        clip: true
                        property int currentIndex: 0
                        function switchBanner(isNext) {
                            if (antiMisclickTimer.running) {
                                return
                            }
                            numAnimation.isNext = isNext
                            let targetX = container.x
                            if (numAnimation.running) { // 加速动画
                                numAnimation.stop()
                                numAnimation.duration = bannerWidget.quickAnimationDuration
                                if (isNext) {
                                    targetX = Math.floor(1.0 * targetX / bannerView.width) * bannerView.width
                                } else {
                                    targetX = Math.ceil(1.0 * targetX / bannerView.width) * bannerView.width
                                }
                                numAnimation.from = container.x
                                numAnimation.to = targetX
                                numAnimation.start()
                                antiMisclickTimer.start()
                            } else { // 翻页
                                if (isNext) {
                                    targetX = targetX - bannerView.width
                                } else {
                                    targetX = targetX + bannerView.width                                    
                                }
                                numAnimation.from = container.x
                                numAnimation.to = targetX
                                numAnimation.duration = bannerWidget.normalAnimationDuration
                                numAnimation.start()
                                
                                // 再次判断是为了和上面代码功能上做区分，上面为动画更新逻辑，下面为currentIndex逻辑
                                // 此时虽然currentIndex已经更新了，但视觉上可能正处于切换状态，还未切换完成
                                if (isNext) {
                                    bannerView.currentIndex = (bannerView.currentIndex + 1) >= bannerManager.modelCount ? 0 : bannerView.currentIndex + 1
                                } else {
                                    bannerView.currentIndex = (bannerView.currentIndex - 1) < 0 ? bannerManager.modelCount - 1 : bannerView.currentIndex - 1
                                }
                            }
                        }

                        Item {
                            id: container
                            width: (bannerManager.modelCount + 2) * bannerView.width
                            height: bannerView.height
                            property double preWidth
                            onWidthChanged: {
                                // 校准x坐标
                                let targetX = (bannerView.currentIndex - 1) * bannerView.width
                                let percentage
                                // 重设动画参数
                                if (numAnimation.running) {
                                    numAnimation.stop()
                                    if (bannerView.width === 0 || preWidth === 0) {
                                        return
                                    }

                                    let currentX = container.x * (width * 1.0 / preWidth)
                                    if (numAnimation.isNext) {
                                        percentage = (currentX % bannerView.width) / bannerView.width
                                        targetX = Math.floor(1.0 * currentX / bannerView.width) * bannerView.width
                                    } else {
                                        percentage = 1 - (currentX % bannerView.width) / bannerView.width
                                        targetX = Math.ceil(1.0 * currentX / bannerView.width) * bannerView.width
                                    }
                                    numAnimation.from = currentX
                                    numAnimation.to = targetX
                                    numAnimation.duration = bannerWidget.quickAnimationDuration * (1 - percentage)
                                    numAnimation.start()
                                } else {
                                    x = targetX
                                }
                                preWidth = width
                            }
                            Component.onCompleted: {
                                preWidth = width
                            }

                            x: -bannerView.width
                            Repeater {
                                model: bannerManager.bannerModel
                                delegate: BannerItem {
                                    x: index * bannerView.width
                                    width: bannerView.width
                                    height: bannerView.height
                                    coverUrl: model.coverUrlLarge
                                    uri: model.uri
                                }
                            }
                            MouseArea {
                                id: bannerItemArea
                                anchors.fill: parent
                                hoverEnabled: true
                                propagateComposedEvents: true
                                onContainsMouseChanged: {
                                    if (containsMouse) {
                                        bannerLoopTimer.stop()
                                    } else {
                                        bannerLoopTimer.start()
                                    }
                                }                                
                            }
                            Rectangle {
                                anchors.fill: parent
                                visible: bannerItemArea.containsMouse || nextButtonArea.containsMouse || preButtonArea.containsMouse
                                color: Colors.color_FFFFFF
                                opacity: 0.03
                            }
                        }
                    }
                    NumberAnimation {
                        id: numAnimation
                        target: container
                        property: "x"
                        duration: bannerWidget.normalAnimationDuration
                        easing.type: Easing.InOutQuad
                        property bool isNext
                        onFinished: {
                            if (container.x <= -1 * (bannerManager.modelCount + 1) * bannerView.width) {
                                container.x = -bannerView.width
                            } else if (container.x >= 0) {
                                container.x = -1 * bannerManager.modelCount * bannerView.width
                            }
                        }
                    }
                    
                    // 前一个按钮
                    Rectangle {
                        anchors {
                            left: parent.left
                            leftMargin: 4
                            verticalCenter: parent.verticalCenter
                        }
                        width: 12
                        height: 16
                        radius: 2
                        visible: bannerManager.modelCount > 1 && (bannerItemArea.containsMouse || nextButtonArea.containsMouse || preButtonArea.containsMouse)
                        color: preButtonArea.containsMouse ? Colors.color_000000_30 : Colors.color_000000_20
                        Image {
                            anchors.centerIn: parent
                            source: "qrc:/icons/icon_banner_pre.svg"
                        }
                        MouseArea {
                            id: preButtonArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                bannerView.switchBanner(false)
                            }
                        }
                    }
                    
                    // 后一个按钮
                    Rectangle {
                        anchors {
                            right: parent.right
                            rightMargin: 4
                            verticalCenter: parent.verticalCenter
                        }
                        width: 12
                        height: 16
                        radius: 2
                        visible: bannerManager.modelCount > 1 && (bannerItemArea.containsMouse || nextButtonArea.containsMouse || preButtonArea.containsMouse)
                        color: nextButtonArea.containsMouse ? Colors.color_000000_30 : Colors.color_000000_20
                        Image {
                            anchors.centerIn: parent
                            source: "qrc:/icons/icon_banner_next.svg"
                        }
                        MouseArea {
                            id: nextButtonArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                bannerView.switchBanner(true)
                            }
                        }
                    }
                    
                    ListView {
                        id: pointListView
                        anchors {
                            horizontalCenter: parent.horizontalCenter
                            bottom: parent.bottom
                            bottomMargin: 10
                            
                        }
                        width: (count - 1) * (notCurrDelegateWidth + spacing) + currDelegateWidth
                        height: pointListView.notCurrDelegateWidth
                        spacing: 3
                        visible: bannerManager.modelCount > 1

                        readonly property int currDelegateWidth: 8
                        readonly property int notCurrDelegateWidth: 3
                        orientation: ListView.Horizontal
                        model: bannerManager.modelCount
                        
                        delegate: Rectangle {
                            width: index === bannerView.currentIndex ? pointListView.currDelegateWidth : pointListView.notCurrDelegateWidth
                            height: pointListView.notCurrDelegateWidth
                            radius: pointListView.notCurrDelegateWidth / 2.0
                            color: index === bannerView.currentIndex ? Colors.color_FFFFFF : Colors.color_FFFFFF_40
                            
                            Behavior on width {
                                NumberAnimation { duration: bannerWidget.normalAnimationDuration }
                            }
                        }
                    }
                }
                }
            }
        }

        StackLayout {
            id: stackView
            function changeTab(index) {
                console.log("[CloudAlbumNav] StackLayout.changeTab request currentIndex=" + currentIndex
                            + " targetIndex=" + index)
                if (currentIndex === index) {
                    console.log("[CloudAlbumNav] StackLayout.changeTab ignored same index=" + index)
                    return;
                }
                if (homeView.showDraftSelectState) {
                    homeView.showDraftSelectState = false
                    draftListViewModel.resetSelectedDrafts()
                }
                if (index === homeView.recycleBinIndex) {
                    draftManager.refreshRecycleBin()
                }
                currentIndex = index;
                console.log("[CloudAlbumNav] StackLayout.changeTab changed currentIndex=" + currentIndex)
                globalSignal.updateDiskAccessPermission()
                console.log("[CloudAlbumNav] StackLayout.changeTab updateDiskAccessPermission emitted currentIndex=" + currentIndex)
            }

            onCurrentIndexChanged: {
                console.log("[CloudAlbumNav] StackLayout.currentIndexChanged currentIndex=" + currentIndex
                            + " isCloudAlbumVisible=" + homeView.isCloudAlbumVisible)
            }

            Layout.fillHeight: true
            Layout.fillWidth: true
            
            Loader {
                sourceComponent: homePage
                // asynchronous: editorABConfig.asyncLoadComponent
            }
            Loader {
                id: devicePageLoader
                sourceComponent: devicePage
                // asynchronous: editorABConfig.asyncLoadComponent
            }
            Loader {
                sourceComponent: deviceEmptyPage
            }
            Loader {
                sourceComponent: copiedPage
                // asynchronous: editorABConfig.asyncLoadComponent
            }
            Loader {
                sourceComponent: recycleBinPage
                asynchronous: editorABConfig.asyncLoadComponent
            }
            Loader {
                id: cloudAlbumPageLoader
                sourceComponent: cloudAlbumPage
            }
        }

        Connections {
            target: USBDeviceDetector
            function onDeviceAttached(deviceName, holder) {
                deviceName = Tools.getDeviceRealName(deviceName);
                toast.showToast(deviceName + qsTr("pccut_device"));
            }

            function onDeviceDetached(deviceName, holder) {
                deviceName = Tools.getDeviceRealName(deviceName);
                toast.showToast(deviceName + qsTr("pccut_files_missing_device"));
            }
        }

        Connections {
            target: deviceListViewModel
            function onAddDevice() {
                // 第一个设备接入，无论如何都跳转页面
                if(deviceListViewModel.deviceCount === 1) {
                    stackView.changeTab(deviceButtonIndex);
                    deviceListViewModel.currentIndex = 0
                    globalSignal.deviceSelected(deviceListViewModel.getFirstDevice())
                }
            }

            function onRemoveDevice(index) {
                // 先判断是否是当前选中的设备
                if(index === deviceListViewModel.currentIndex) { // 当前选中设备被删除
                    if(deviceListViewModel.deviceCount === 0) { // 最后一个设备被删除
                        stackView.changeTab(deviceEmptyIndex);
                        deviceListViewModel.currentIndex = deviceButtonIndex
                    } else {
                        // 还有其他设备
                        deviceListViewModel.currentIndex = 0;
                        globalSignal.deviceSelected(deviceListViewModel.getFirstDevice())
                    }
                } else if(index < deviceListViewModel.currentIndex) { // 删除设备的index小于当前选择设备的
                    deviceListViewModel.currentIndex = deviceListViewModel.currentIndex - 1
                }
            }
        }


        Connections {
            target: globalSignal

            //查看下载页面
            function onCheckDownload() {
                stackView.changeTab(deviceDownloadIndex);
            }
        }

        //首页
        Component{
            id: homePage

            ColumnLayout{
                spacing: 24

                // 创建项目按钮
                Rectangle {
                    id :createProjectBtn
                    objectName: actionableItemName.createProjectForHomeView
                    Layout.leftMargin: 40
                    Layout.rightMargin: 39
                    Layout.topMargin: 48
                    Layout.preferredHeight: 102
                    Layout.fillWidth: true
                    Layout.bottomMargin: 16
                    layer.enabled: true
                    layer.effect: DropShadow {
                        horizontalOffset: 0
                        verticalOffset: 0
                        radius: 50
                        color: Colors.color_000000_30
                    }
                    color: createProjectArea.containsMouse ? Colors.color_button_background_hovered : Colors.color_button_background_normal
                    radius: RadiusConfig.radius_12_24
                    Item {
                        height: parent.height
                        width: childrenRect.width
                        anchors.centerIn: parent
                        Image {
                            id: createProjectIcon
                            anchors.verticalCenter: parent.verticalCenter
                            source: "qrc:/app_qrc/icons/icon_create_project.svg"
                            width: 24
                            height: 24
                            sourceSize: Qt.size(24, 24)
                        }
                        Text {
                            anchors.left: createProjectIcon.right
                            anchors.leftMargin: 12
                            anchors.verticalCenter: createProjectIcon.verticalCenter
                            
                            text: qsTr("pccut_create_project")
                            color: ColorsConfig.color_FFFFFF_4DFFC9
                            font.pixelSize: 20
                        }
                    }

                    MouseArea {
                        id: createProjectArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            eventTracker.trackEvent("pccut_create_project_click", {"use_method": "home"});
                            draftManager.addNewDraft()
                        }
                    }
                }

                // 最近项目标签
                Item {
                    Layout.leftMargin: 40
                    Layout.rightMargin: 40
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28

                    // 灰色背景按钮组件
                    component IconTextLocalGrayButton : IconTextButton {
                        height: 28
                        width: 96
                        radius: 6
                        imageRectWidth: 16
                        imageRectHeight: 16
                        internalSpacing: 4
                        backgroundColorNormal: Colors.color_button_background_normal
                        backgroundColorHover: Colors.color_button_background_hovered
                        titleColorNormal: enabled ? Colors.color_EEEEEE : Colors.color_444444
                    }

                    Text {
                        id: recentProjectTitle
                        text: qsTr("pccut_recent_project") + qsTr(" (" + draftManager.draftCount + ")")
                        color: Colors.color_FFFFFF
                        anchors.verticalCenter: parent.verticalCenter
                        font.pixelSize: 16
                    }

                    Text {
                        visible: homeView.showDraftSelectState
                        text: qsTr("pccut_draft_batch_selected_count_status").arg("<font color='" + Colors.color_EEEEEE + "'>" + draftListViewModel.selectCount + "</font>")
                        textFormat: Text.RichText
                        color: Colors.color_666666
                        font.pixelSize: 12
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: recentProjectTitle.right
                        anchors.leftMargin: 12
                    }

                    Row {
                        anchors {
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                        }
                        layoutDirection: Qt.RightToLeft
                        spacing: 8

                        Row {
                            spacing: 8
                            layoutDirection: Qt.RightToLeft

                            IconTextLocalGrayButton {
                                id: draftMultipleSelectBtn

                                enabled: draftManager.draftCount > 0
                                title: homeView.showDraftSelectState ? qsTr("pccut_draft_batch_select_cancel_btn") : qsTr("pccut_draft_batch_select_btn")
                                iconPathNormal: homeView.showDraftSelectState ? "" : "qrc:/app_qrc/icons/multiple_select.svg"
                                iconPathDisable: "qrc:/icons/recycle/icon_batch_selection_disabled.svg"
                                iconPathHover: "qrc:/icons/recycle/icon_batch_selection_hover.svg"
                                isTextOnly: homeView.showDraftSelectState
                                leftPadding: homeView.showDraftSelectState ? 22 : 12
                                rightPadding: homeView.showDraftSelectState ? 22 : 12
                                topPadding: 6
                                bottomPadding: 6

                                onCustomClicked: {
                                    homeView.showDraftSelectState = !homeView.showDraftSelectState
                                    if (!homeView.showDraftSelectState) {
                                        eventTracker.trackEvent("pccut_draft_batch_delete_click", {"button_type": "select_cancel", "use_method": "draft"})
                                        draftListViewModel.resetSelectedDrafts()
                                    } else {
                                        eventTracker.trackEvent("pccut_draft_batch_delete_click", {"button_type": "select", "use_method": "draft"})
                                    }
                                }
                            }

                            // 回收站入口
                            Rectangle {
                                width: 28
                                height: 28
                                radius: 6
                                color: recycleBinIconArea.containsMouse
                                    ? Colors.color_button_background_hovered
                                    : Colors.color_button_background_normal
                                visible: !homeView.showDraftSelectState

                                Image {
                                    id: recycleBinIcon
                                    anchors.centerIn: parent
                                    source: "qrc:/icons/recycle/icon_recycle_bin.svg"
                                    sourceSize: Qt.size(20, 20)
                                }

                                Rectangle {
                                    anchors.right: recycleBinIcon.right
                                    anchors.top: recycleBinIcon.top
                                    width: 5
                                    height: 5
                                    radius: 2.5
                                    color: Colors.color_F22443
                                    visible: homeView.recycleBinRedDot
                                }

                                MouseArea {
                                    id: recycleBinIconArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        homeView.recycleBinRedDot = false
                                        stackView.changeTab(homeView.recycleBinIndex)
                                    }
                                }
                            }
                        }

                        IconTextLocalGrayButton {
                            id: draftSelectAllBtn
                            usePreferredWidth: false
                            visible: homeView.showDraftSelectState

                            title: draftListViewModel.selectCount === draftManager.draftCount
                                ? qsTr("pccut_draft_batch_deselect_all_btn") : qsTr("pccut_draft_batch_select_all_btn")
                            isTextOnly: true

                            onCustomClicked: {
                                if (draftListViewModel.selectCount === draftManager.draftCount) {
                                    eventTracker.trackEvent("pccut_draft_batch_delete_click", {"button_type": "select_cancel", "use_method": "draft"})
                                    draftListViewModel.resetSelectedDrafts()
                                } else {
                                    eventTracker.trackEvent("pccut_draft_batch_delete_click", {"button_type": "select_all", "use_method": "draft"})
                                    draftListViewModel.selectAll()
                                }
                            }
                        }

                        IconTextButton {
                            id: draftRemoveBtn
                            height: 28
                            visible: homeView.showDraftSelectState
                            enabled: draftListViewModel.selectCount > 0

                            title: qsTr("pccut_draft_batch_delete_btn")
                            titleColorNormal: enabled ? hovered ? Colors.color_FFFFFF : Colors.color_EEEEEE : Colors.color_444444
                            iconPathNormal: "qrc:/icons/multiple_delete.svg"
                            iconPathDisable: "qrc:/icons/multiple_delete_disable.svg"
                            iconPathHover: "qrc:/icons/multiple_delete_highlight.svg"
                            imageRectWidth: 16
                            imageRectHeight: 16
                            rightPadding: 16

                            backgroundColorNormal: Colors.color_transparent
                            backgroundColorHover: Colors.color_transparent
                            internalSpacing: 4

                            onCustomClicked: {
                                eventTracker.trackEvent("pccut_draft_batch_delete_click", {"button_type": "delete", "use_method": "draft"})
                                currentDraftIndex = -1
                                deleteConfirmPopupLoader.active = true
                            }
                        }
                    }
                }

                //最近项目展示
                Rectangle {
                    id: recentDraftWindow
                    Layout.leftMargin: 40
                    Layout.rightMargin: 6
                    Layout.topMargin: 8
                    Layout.fillHeight: true
                    Layout.fillWidth: true
                    color: Colors.color_141414
                    Component.onCompleted: homeView.draftToastParent = recentDraftWindow

                    Connections {
                        target: recentDraftView
                        function onMessageTips(type){
                            switch(type) {
                                case MessageType.NAME_EXISTENT:{
                                    tipsModel.append({"message": qsTr("pccut_files_missing_samename")})
                                    tipsView.visible = true
                                    break;
                                }
                                case MessageType.NAME_ISEMPTY:{
                                    tipsModel.append({"message": qsTr("pccut_draft_name_empty")})
                                    tipsView.visible = true
                                    break;
                                }
                                case MessageType.NAME_TOLANG:{
                                    tipsModel.append({"message": qsTr("pccut_draft_name_limit")})
                                    tipsView.visible = true
                                    break;
                                }
                                case MessageType.NAME_INVALID:{
                                    tipsModel.append({"message": qsTr("pccut_draft_name_invalid")})
                                    tipsView.visible = true
                                    break;
                                }
                                case MessageType.COPY_SUCCESSED:{
                                    tipsModel.append({"message": qsTr("pccut_draft_copy_success")})
                                    tipsView.visible = true
                                    break;
                                }
                                case MessageType.COPY_FAILED_INSUFFICIENT_SPACE:{
                                    tipsModel.append({"message": qsTr("pccut_draft_copy_fail_space")})
                                    tipsView.visible = true
                                    break;
                                }
                                case MessageType.COPY_FAILED_DAMAGED_DRAFT:{
                                    tipsModel.append({"message": qsTr("pccut_draft_copy_fail_corrupted")})
                                    tipsView.visible = true
                                    break;
                                }
                                default:{

                                }
                            }
                            myTimer.running = true
                        }
                    }

                    Timer {
                        id: myTimer
                        interval: 1000
                        repeat: true
                        running: false
                        onTriggered: {
                            if(tipsModel.count > 0) {
                                tipsModel.remove(0, 1)
                                if (tipsModel.count === 0)
                                    running = false
                            }
                        }
                    }

                    RecentDraftView {
                        id: recentDraftView
                        showDraftSelectState: homeView.showDraftSelectState
                    }
                }


            }
        }

        // 设备连接空页面
        Component {
            id: deviceEmptyPage
            DeviceEmptyView{
                id: deviceEmptyView
            }
        }

        //设备连接
        Component{
            id: devicePage
            DeviceView {
                allFileInfoModel: DeviceFileInfoModel {}
            }
        }

        // 下载页面
        Component{
            id: copiedPage
            DeviceView {
                allFileInfoModel: CopiedFileListModel {}
                isDownloadPage: true
                Connections {
                    target: allFileInfoModel
                    function onAddCopyFinish() {
                        copiedRed = true;
                    }
                }
            }
        }

        Component {
            id: recycleBinPage
            RecycleBinView {
            }
        }

        // 云相册页面
        Component {
            id: cloudAlbumPage
            CloudAlbumView {
            }
        }
    }

    Loader {
        id: cloudAlbumAgreementLoader
        active: false
        sourceComponent: CloudAlbumAgreementPopup {}
    }

    Connections {
        target: cloudAlbumAgreementLoader.item

        function onAgreementAccepted() {
            // 先落盘同意态再进入：写失败只影响下次会再弹一次，不阻断本次进入。
            CloudAlbumManager.markCloudAlbumAgreementAccepted()
            stackView.changeTab(homeView.cloudAlbumIndex)
        }
    }

    ListModel {
        id: tipsModel
    }

    ListView {
        id: tipsView
        anchors.centerIn: parent
        width: contentItem.implicitWidth
        height: 41 * model.count + spacing * (model.count - 1)
        visible: false
        model: tipsModel
        spacing: 36
        delegate: Component {
            Rectangle {
                width: msg.width + 24
                height: 41
                color: Colors.color_EEEEEE
                radius: 4

                Text {
                    id: msg
                    anchors.centerIn: parent
                    text: qsTr(model.message)
                    font.pixelSize: 12
                    color: Colors.color_141414
                }
            }
        }
    }

    property int currentDraftIndex: -1
    function deleteDraft(index) {        
        if (draftManager.deleteDraft(index)) {
            homeView.recycleBinRedDot = true
        }
    }
    function checkDownload() {
        stackView.changeTab(deviceDownloadIndex);
    }

    Connections {
        target: globalSignal
        function onDraftDeleteConfirm(index) {
            currentDraftIndex = index
            deleteConfirmPopupLoader.active = true
        }
        // 点击批量选择按钮
        function onDeviceClickMultipleSelectBtn() {
            homeView.showSelectState = !homeView.showSelectState;
        }
    }

    Connections {
        target: draftManager
        function onDraftDamage() {
            draftDamagePopup.open();
        }
    }

    NoticePopup {
        id: draftDamagePopup
        width: 248
        height: 127
        text: qsTr("pccut_draft_copy_corrupted")
    }

    LightToastManager {
        id: draftToast
    }

    Loader {
        id: deleteConfirmPopupLoader
        active: false
        sourceComponent: Component {
            ConfirmPopup {
                id: deleteConfirmPopup
                property int deleteCount: currentDraftIndex < 0 ? draftListViewModel.selectCount : 1

                title: qsTr("pccut_draft_batch_delete_dialog_title")
                text: qsTr("pccut_draft_batch_delete_dialog_desc").arg("<font color='" + Colors.color_EEEEEE + "'>" + deleteCount + "</font>")
                leftButtonText: qsTr("pccut_draft_delete_popup_cancel")
                rightButtonText: qsTr("pccut_draft_delete_popup_yes")

                onRightButtonClicked: {
                    var indexes = currentDraftIndex < 0 ? draftListViewModel.selectedIndexes() : [currentDraftIndex]
                    for (var i = 0; i < indexes.length; i++) {
                        var draftId = draftManager.findOpenedDraftIdByIndex(indexes[i]);
                        var projectId = draftManager.projectEnvIdByDraftId(draftId);
                        UsedFunctionManager.removeProjectFuncData(projectId);
                    }
                    var totalCount = indexes.length
                    var successCount = draftManager.batchDeleteDrafts(indexes)
                    var failCount = totalCount - successCount
                    eventTracker.trackEvent("pccut_draft_batch_delete_result", {
                        "is_success": successCount === totalCount,
                        "success_count": successCount,
                        "fail_count": failCount
                    })
                    if (homeView.draftToastParent) {
                        draftToast.parent = homeView.draftToastParent
                        draftToast.anchors.centerIn = null
                        draftToast.x = Qt.binding(function() { return (draftToast.parent.width - draftToast.width) / 2 })
                        draftToast.y = Qt.binding(function() { return draftToast.parent.height - draftToast.height - 108 })
                    }
                    if (successCount > 0 && failCount === 0) {
                        draftToast.showToast(qsTr("pccut_draft_batch_delete_success_toast").arg(successCount))
                    } else if (successCount > 0 && failCount > 0) {
                        draftToast.showToast(qsTr("pccut_draft_batch_delete_partial_fail_toast").arg(successCount).arg(failCount))
                    } else {
                        draftToast.showToast(qsTr("pccut_draft_batch_delete_all_fail_toast"))
                    }

                    if (currentDraftIndex < 0) {
                        draftListViewModel.resetSelectedDrafts()
                        homeView.showDraftSelectState = false
                    }
                    if (successCount > 0) {
                        homeView.recycleBinRedDot = true
                    }
                }
                onClosed: {
                    deleteConfirmPopupLoader.active = false
                }
                Component.onCompleted: open()
            }
        }
    }

    ConfirmPopup {
        id: confirmReopenPopup
        objectName: actionableItemName.homeViewConfirmView
        title: qsTr("pccut_draft_exception_popup_title")
        leftButtonText: qsTr("pccut_draft_exception_popup_cancel")
        rightButtonText: qsTr("pccut_draft_exception_popup_yes")
        // 给 autotest（AutoTestClickHomeViewCancelBtn / AutoTestClickStorageExceed 等）显式钩子
        leftButtonObjectName: actionableItemName.confirmBtnForHomeViewConfirm
        rightButtonObjectName: actionableItemName.cancelBtnForHomeViewConfirm

        onLeftButtonClicked: {
            draftManager.reopen(false)
        }
        onRightButtonClicked: {
            deleteDraft(currentDraftIndex)
            draftManager.reopen(true)
        }
    }

    Component.onCompleted: {
        if(draftManager.getIsNormalClosed()) {
            // 上一次打开app时正常退出
            draftManager.initJsonFile()
        } else {
            // 上一次打开app时异常退出
            confirmReopenPopup.open()
        }
    }
}
