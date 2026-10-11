import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.3
import Qt.labs.platform 1.1
import Config 1.0
import Controls 1.0
import FilterListModel 1.0
import Qt5Compat.GraphicalEffects
import MediaListViewModel 1.0
import DeviceMediaListModel 1.0
import CopiedMediaListModel 1.0
import AppBarViewModel 1.0
import app_qrc 1.0
import CloudAlbumAssetListModel 1.0
import CloudAlbumManager 1.0
import "../welcome/cloudalbum"

MaterialTabBaseView{
    // // 当前需要被替换的素材路径
    property string curReplaceMediaPath: ""
    property real targetTrack : -1
    property real targetClip: -1
    property bool ignoreResetTab: false      //在播放器选择使用App打开时，忽略项目tab重置

    property MediaListViewModel mediaListViewModel
    property DeviceMediaListModel deviceMediaListModel
    property CopiedMediaListModel copiedMediaListModel

    mediaListViewModel: MediaListViewModel {}
    deviceMediaListModel: DeviceMediaListModel {}
    copiedMediaListModel: CopiedMediaListModel {}

    AppBarViewModel {
        id: _appBarViewModel
    }

    // 当前本地素材页面的tab在第一个，index对应0
    property int localTabIndex: 0

    property int downloadTabIndex: 1

    // 当前设备素材页面的tab在第二个，index对应1
    property int deviceTabIndex: 2

    // 云相册标签，index = 3
    property int cloudAlbumTabIndex: 3

    property int selectedDeviceTabIndex: 0
    // 硬件的菜单列表
    property var deviceMenuModel
    // 本地的菜单列表
    property var localMenuModel
    // 是否下载过
    property bool hasCopyFile: copyFileManager.hasCopyFile
    onHasCopyFileChanged: {
        // 目前只有 下载和本地导入, 所以写的条件比较简陋
        if (localMenuModel  !== undefined && hasCopyFile && localMenuModel.count === 1) {
            localMenuModel.append({"subName": qsTr("pccut_device_batch_my_download")});
        }
    }

    id: tabView
    property int leftLocalSubIdx: 0
    property bool leftLocalIsExpanded: true
    property bool leftDeviceIsExpanded: true
    property int selectIndex: 0
    // 菜单选中的下标
    // property int leftLocalSubIdx: 0
    onLeftLocalSubIdxChanged: {
        if (leftLocalSubIdx < 0) {
            return;
        }
        leftDeviceSubIdx = -1;
        leftCloudAlbumSubIdx = -1;
        if (leftLocalSubIdx == 0) {
            selectIndex = localTabIndex;
        } else if (leftLocalSubIdx === 1) {
            selectIndex = downloadTabIndex;
        }
    }
    property int leftDeviceSubIdx: -1
    onLeftDeviceSubIdxChanged: {
        if (leftDeviceSubIdx < 0) {
            return;
        }
        leftLocalSubIdx = -1;
        leftCloudAlbumSubIdx = -1;
        selectIndex = deviceTabIndex;
        var subName = deviceMenuModel.get(leftDeviceSubIdx).subName
        globalSignal.deviceSelected(subName)
    }

    property int leftCloudAlbumSubIdx: -1
    onLeftCloudAlbumSubIdxChanged: {
        if (leftCloudAlbumSubIdx < 0) {
            return;
        }
        if (!cloudAlbumFeatureFlags.enable) {
            leftCloudAlbumSubIdx = -1;
            return;
        }
        leftLocalSubIdx = -1;
        leftDeviceSubIdx = -1;
        selectIndex = cloudAlbumTabIndex;
    }

    Connections {
        target: cloudAlbumFeatureFlags

        function onEnableChanged() {
            if (!cloudAlbumFeatureFlags.enable
                    && selectIndex === cloudAlbumTabIndex) {
                leftCloudAlbumSubIdx = -1;
                leftLocalIsExpanded = true;
                leftLocalSubIdx = 0;
            }
        }
    }

    function getMediaTabSelectedDeviceName() {
        if (leftDeviceSubIdx >= 0 && leftDeviceSubIdx < deviceListViewModel.deviceCount) {
            return deviceListViewModel.getDeviceList()[leftDeviceSubIdx];
        }
        return "";
    }

    function switchTab(index,urls, operationType){
        if (index === 0) {
            leftLocalIsExpanded = true;
            leftLocalSubIdx = 0;
        }
        importMedia(urls, operationType)
    }

    function enterCloudAlbum() {
        cloudAlbumEventReport.trackEnterClick(1)
        // 用户服务协议每个账号只弹一次：同意态存在 SDK 的账号库里，换账号或本地
        // 数据丢失会重新弹；读不到一律按未同意处理（宁可多弹，不可漏弹）。
        if (CloudAlbumManager.isCloudAlbumAgreementAccepted()) {
            leftCloudAlbumSubIdx = 0
            return
        }
        // 只加载一次、之后复用。不要在按钮回调里 active = false：ConfirmPopup 的
        // close() 只是启动 100ms 退出动画，closed 要等动画结束才发；提前销毁弹窗会让
        // 基类 LightPopup.onClosed 里的 enableMenuBar(true) 永远不执行，菜单栏会一直置灰。
        if (!cloudAlbumAgreementLoader.active) {
            cloudAlbumAgreementLoader.active = true
        }
        cloudAlbumAgreementLoader.item.open()
    }

    // 基类 MaterialTabBaseView 是 SplitView，任何可见的 Item 直接子项都会变成一块分栏，
    // 所以这里必须 visible: false，否则会在右侧多挤出一条空白栏，并把 rightContainer
    // 压到 minimumWidth。弹窗本身不受影响：LightPopup 固定 parent: Overlay.overlay，
    // 显示位置与这个 Loader 的几何无关。
    Loader {
        id: cloudAlbumAgreementLoader
        active: false
        visible: false
        sourceComponent: CloudAlbumAgreementPopup {}
    }

    Connections {
        target: cloudAlbumAgreementLoader.item

        function onAgreementAccepted() {
            // 先落盘同意态再进入：写失败只影响下次会再弹一次，不阻断本次进入。
            CloudAlbumManager.markCloudAlbumAgreementAccepted()
            leftCloudAlbumSubIdx = 0
        }
    }

    function importMedia(urls, operationType){
        rightViewLoader.item.localTabView.importMedia(urls, operationType)
    }

    function checkMediaDownload() {
        leftLocalIsExpanded = true;
        leftLocalSubIdx = downloadTabIndex;
        ignoreResetTab = true
    }

    // 灵感粗剪：导入完成后将素材铺到轨道
    property var _pendingAddToTrackIds: []

    Timer {
        id: roughCutAddToTrackTimer
        interval: 200
        repeat: true
        onTriggered: {
            if (_pendingAddToTrackIds.length === 0) {
                stop();
                return;
            }
            var localModel = rightViewLoader.item ? rightViewLoader.item.localTabView.dataModel : null;
            if (!localModel) return;

            // 检查是否全部 prepared
            var allPrepared = true;
            for (var i = 0; i < _pendingAddToTrackIds.length; i++) {
                var id = _pendingAddToTrackIds[i];
                if (!localModel.mediaPrepared(id) && !localModel.mediaPreparedTimeout(id)) {
                    allPrepared = false;
                    break;
                }
            }
            if (allPrepared) {
                var firstId = _pendingAddToTrackIds[0];
                _pendingAddToTrackIds = [];
                stop();
                // 先将时间指示器移到轨道末尾，确保素材插入到尾部
                editorManager.setIndicatorFrame(editorManager.totalFrames());
                // mediaClickAdd 会把所有 selected 的素材一次性加到轨道（在指示器位置）
                localModel.mediaClickAdd(firstId);
            }
        }
    }

    Connections {
        target: mediaListViewModel
        function onExternalAddToTrackRequested(paths) {
            var localModel = rightViewLoader.item ? rightViewLoader.item.localTabView.dataModel : null;
            if (!localModel) return;
            var ids = [];
            for (var i = 0; i < paths.length; i++) {
                var found = localModel.idForPath(paths[i]);
                if (found.length > 0) {
                    ids.push(found[0]);
                }
            }
            if (ids.length > 0) {
                _pendingAddToTrackIds = ids;
                roughCutAddToTrackTimer.start();
            }
        }
    }

    onLeftPaneClicked: {
        globalSignal.multiSelectStateChanged(false);
    }

    leftView: Component {
        Item {
            id: leftTab
            anchors.fill: parent
            // 本地
            FoldListTab {
                id: leftLocalTab
                width: parent.width - 32

                anchors.top: parent.top
                anchors.topMargin: 16
                anchors.horizontalCenter: parent.horizontalCenter
                title: qsTr("pccut_menu_import")
                selectSubIdx: leftLocalSubIdx
                // selectSubIdx: 0
                showRedIndex: homeView.copiedRed ? 1 : -1
                onClickIndex: (index) => {
                    leftLocalSubIdx = index;
                }
                // 已选中的"本地素材"子项再次点击不触发 clickIndex，埋点改挂 subItemClicked
                onSubItemClicked: (index) => {
                    if (index === 0) {
                        eventTracker.trackEvent("pccut_local_file_click");
                    }
                }
            }
            // 硬件
            FoldListTab {
                id: leftDeviceTab
                width: parent.width - 32
                anchors.top: leftLocalTab.bottom
                anchors.topMargin: 16
                anchors.horizontalCenter: parent.horizontalCenter
                title: qsTr("pccut_device")
                selectSubIdx: leftDeviceSubIdx
                onClickIndex: (index) => {
                    leftDeviceSubIdx = index;
                    eventTracker.trackEvent("pccut_connected_devices_click");
                }
            }
            // 云相册（无下拉，直接点击切换）
            Rectangle {
                id: leftCloudAlbumTab
                width: parent.width - 32
                height: 28
                // 功能开关 + 灰度双重控制：未登录/未灰度时隐藏入口
                visible: cloudAlbumFeatureFlags.enable
                         && CloudAlbumManager.grayCloudAlbumAvailable
                anchors.top: leftDeviceTab.bottom
                anchors.topMargin: 16
                anchors.horizontalCenter: parent.horizontalCenter
                color: ColorsConfig.color_2F3032_transparent
                radius: 4

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        tabView.enterCloudAlbum()
                    }
                }

                Text {
                    font.pixelSize: 12
                    color: leftCloudAlbumSubIdx >= 0 ? ColorsConfig.color_brand : Colors.color_FFFFFF
                    text: qsTr("pccut_cloud_album")
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            Component.onCompleted: {
                deviceMenuModel = leftDeviceTab.menuModel;
                localMenuModel = leftLocalTab.menuModel;
                localMenuModel.append({"subName": qsTr("pccut_media")});
                if (copyFileManager.hasCopyFile) {
                    localMenuModel.append({"subName": qsTr("pccut_device_batch_my_download")});
                }
            }
        }
     }
    rightView: Component {
         //媒体MediaTab
         Item {
             id: root
             property alias localTabView: localTabView

             CloudAlbumAssetListModel { id: cloudAlbumAssetModel }
             Connections {
                 target: deviceListViewModel

                 function onDeviceCountChanged() {
                     deviceMenuModel.clear()
                     for (var i = 0; i < deviceListViewModel.deviceCount; i++) {
                         var deviceName = deviceListViewModel.getDeviceList()[i]
                         var stum = { subName: deviceName }
                         deviceMenuModel.append(stum)
                     }
                 }
             }

             Connections {
                 target: globalSignal

                 function onGeneralItemImported(target, sourceList, highlightIds) {
                     leftLocalIsExpanded = true;
                     leftLocalSubIdx = 0;
                     if (draftManager.isInWelcomePage()) {
                         draftManager.addNewDraftOnOpenFinder();
                         localTabView.createImport = true;
                     }

                     localTabView.sourceArray = sourceList
                     localTabView.highlightIds = highlightIds
                     if (mediaListViewModel.count < 1) {
                         localTabView.importToLocal(sourceList, highlightIds)
                     } else {
                         localTabView.draftPopup.open()
                     }
                 }

                 function onDeviceItemImported(deviceName, target) {
                     leftDeviceIsExpanded = true;
                     var index = deviceListViewModel.getDeviceList().indexOf(deviceName)
                     if (index !== -1) {
                         leftDeviceSubIdx = index;
                     }
                     ignoreResetTab = true
                 }

                 function onGeneralFromDevicePanel(deviceName) {
                     if (deviceName === "CopiedFileList") {
                         leftLocalIsExpanded = true;
                         leftLocalSubIdx = 1;
                         ignoreResetTab = true
                         return;
                     }
                     leftDeviceIsExpanded = true;
                     var index = deviceListViewModel.getDeviceList().indexOf(deviceName)
                     if (index !== -1) {
                         leftDeviceSubIdx = index;
                         globalSignal.deviceSelected(deviceName)
                     }
                     ignoreResetTab = true
                 }

                 function onActivedProjectChanged(id) {
                     if(draftUIManager.isActiveProjectExist()) {
                         leftLocalIsExpanded = true;
                         if(!ignoreResetTab) {
                             leftLocalSubIdx = 0;
                         }
                         else {
                             ignoreResetTab = false;
                         }
                     }
                 }
                 function onAddToMediaTab(path, targetTrack, targetClip){
                     curReplaceMediaPath = path;
                     mediaListViewModel.importOneMedia(path, MediaListViewModel.Replace, false, true);
                     tabView.targetTrack = targetTrack;
                     tabView.targetClip = targetClip;
                 }
                 // 添加新手引导中的素材到轨道上
                 function onAddFirstMediaToTrack(){
                     var firstId = mediaListViewModel.firstAssetId();
                     mediaListViewModel.mediaClickAdd(firstId);
                 }

                 function onImportLocalFavoriteSource(source, isFavorite) {
                     leftLocalIsExpanded = true;
                     leftLocalSubIdx = 0;
                     if (draftManager.isInWelcomePage()) {
                         draftManager.addNewDraftOnOpenFinder();
                         localTabView.createImport = true;
                     }
                     localTabView.source = source
                     localTabView.isFavorate = isFavorite
                     if (mediaListViewModel.count < 1) {
                         localTabView.importToLocalWithFav(source, isFavorite)
                     } else {
                         localTabView.draftPopup.open()
                     }
                 }
             }

             function importMedia(urls, operationType){
                  localTabView.importMedia(urls, operationType)
              }


             StackLayout {
                 anchors.fill: parent
                 clip: true
                 currentIndex: selectIndex
                 onCurrentIndexChanged: {
                     if (currentIndex === downloadTabIndex) {
                         homeView.copiedRed = false;
                     }
                     globalSignal.updateDiskAccessPermission()
                 }
                 LocalTabView {
                     id: localTabView
                     dataModel: mediaListViewModel

                     // 放在这里的原因主要是LocalTabView中的dataModel其实不一定是哪个
                     Connections {
                         target: localTabView.dataModel

                         function onImportProgress(totalCount, processCount, notSupportCount, brokenCount, finished) {
                             // *#*#*# 取消导入后忽略信号队列中残留的 importProgress 信号，防止弹窗被重新拉起
                             if (localTabView.dataModel.isCancelImport) return
                             // *#*#*# 设备页/下载页导入不弹加载弹窗
                             if (localTabView.dataModel.currentImportMethod === MediaListViewModel.Device) return
                             if (!importLoader.active){
                                importLoader.active = true;
                             }
                             var importLoading = importLoader.item
                             importLoading.processCount = processCount;
                             importLoading.totalCount = totalCount;
                             if (!finished && !importLoading.opened) {
                                 importLoading.open();
                             }
                             if (finished) {
                                 console.log("[MediaListViewModel] Loading dialog close");
                                 importLoading.close();
                                 importLoader.active = false
                             }
                         }

                         //*#*#*# 循环录影：存在损坏子文件（片长为0），已降级为普通素材
                         function onLoopVideoPartialImportFailed() {
                             mediaTabToaster.showToastText(qsTr("pccut_material_partial_import_failed"))
                         }

                         //*#*#*# 循环录影：需要弹窗询问合并策略
                         function onShowLoopVideoMergePop() {
                             // *#*#*# 循环录影：信号为异步队列投递，QML 侧再次校验取消标志
                             if (localTabView.dataModel.isCancelImport) return
                             if (!loopMergeLoader.active) {
                                 loopMergeLoader.active = true
                             }
                             var mergePop = loopMergeLoader.item
                             if (mergePop && !mergePop.opened) {
                                 mergePop.open()
                             }
                         }

                         //*#*#*# 循环录影：合并处理中弹窗（"素材导入中..."，无文件数量）
                         function onLoopVideoImportProgress(finished, current, total) {
                             //*#*#*# 设备页/下载页导入不弹合并弹窗
                             if (localTabView.dataModel.currentImportMethod === MediaListViewModel.Device) return
                             if (finished) {
                                 //*#*#*# 循环录影：延迟关闭，确保进度条 100% 先渲染一帧再关闭
                                 loopVideoImportCloseTimer.restart()
                             } else {
                                 if (!loopVideoImportLoader.active) {
                                     loopVideoImportLoader.active = true
                                 }
                                 if (loopVideoImportLoader.item) {
                                     loopVideoImportLoader.item.processCount = current
                                     loopVideoImportLoader.item.totalCount = total
                                     if (!loopVideoImportLoader.item.opened) {
                                         loopVideoImportLoader.item.open()
                                     }
                                 }
                             }
                         }

                         function onImportSuccess(ids, paths, notSupportCount, brokenCount, repeatCount, missingRefCount, isReplaceMedia, importMethod) {
                             const successCount = paths.length;
                             const failedCount = notSupportCount + brokenCount;
                             let toastMsg;
                             if (missingRefCount > 0) {
                                 toastMsg = qsTr("pccut_import_edit_fail").arg(missingRefCount);
                             } else if (successCount <= 0 && failedCount <= 0) {
                                 toastMsg = qsTr("pccut_material_repeated_import");
                             } else if (failedCount > 0) {
                                 if (successCount <= 0) {
                                     toastMsg = qsTr("pccut_import_raw_fail_2");
                                 } else {
                                     toastMsg = qsTr("pccut_import_clip_part_fail");
                                 }
                             } else if (repeatCount > 0) {
                                 toastMsg = repeatCount + qsTr("pccut_media_import_duplicate_files");
                             } else {
                                 toastMsg = "";
                             }
                             if (toastMsg.length > 0) {
                                 mediaTabToaster.showToastText(toastMsg);
                             }
                             // 设备页点击"+"触发的导入不自动选中预览，与 rc/20260416 行为一致
                             // 替换导入不自动选中：selectMaterial 会进素材预览态(playType=Preview)，替换场景不应改变 playType
                             if (paths.length === 1 && importMethod !== MediaListViewModel.Device && !isReplaceMedia) {
                                 localTabView.selectMaterial(ids[0], false, 0);
                             }

                             if(isReplaceMedia){
                                 mediaListViewModel.pause();
                                 let index = mediaListViewModel.mediaIndexFor(curReplaceMediaPath);
                                 if (index === -1) {
                                     mediaTabToaster.showToastText(qsTr("pccut_import_edit_fail").arg(1));
                                 } else {
                                     let fragment = mediaListViewModel.createFragmentPtrAt(index);
                                     globalSignal.replaceMedia(fragment, tabView.targetTrack, tabView.targetClip);
                                 }
                                 curReplaceMediaPath = "";
                             }

                             if(!lightSetting.getBool("first_add_draft")){
                                 draftManager.addNewDraft();
                             }
                         }
                     }

                     Connections {
                         target: globalSignal
                         function onManualLinkMedia(tfInfoList) {
                             const linkMedias = tfInfoList.length <= 0 ? mediaListViewModel.getLostTrackingFiles(false) : tfInfoList;
                             localTabView.showLinkMediaPop(linkMedias);
                         }

                        function onShowInMediaLibrary(paths) {
                            leftLocalIsExpanded = true;
                            leftLocalSubIdx = 0;
                            
                            var allIds = []
                            for (var i = 0; i < paths.length; i++) {
                                const ids = mediaListViewModel.idForPath(paths[i])
                                if (ids.length > 0) {
                                    allIds.push(ids[0])
                                }
                            }

                            if (allIds.length > 0) {
                                mediaListViewModel.resetSelectedAssets(allIds)
                                localTabView.scrollToFirstSelected()
                            }
                        }
                     }

                     property MediaLostAndFoundPop linkMediaPop: null
                     function showLinkMediaPop(tfInfos) {
                         if (CommonUtils.isNull(linkMediaPop)) {
                             linkMediaPop = Qt.createComponent("MediaLostAndFoundPop.qml").createObject(lightWindow);
                             linkMediaPop.onClosed.connect(function() {
                                 linkMediaPop.destroy();
                                 linkMediaPop = null;
                             });
                             linkMediaPop.setNeedLinkedData(tfInfos);
                             linkMediaPop.open();
                         }
                     }
                 }
                 LocalTabView {
                     localMediaViewModel: localTabView.dataModel
                     dataModel: copiedMediaListModel
                 }
                  LocalTabView {
                      id: deviceTabView
                      localMediaViewModel: localTabView.dataModel
                      dataModel: deviceMediaListModel
                      Connections {
                          target: deviceMediaListModel
                          //*#*#*# 循环录影：存在损坏子文件（片长为0），已降级为普通素材
                          function onLoopVideoPartialImportFailed() {
                              mediaTabToaster.showToastText(qsTr("pccut_material_partial_import_failed"))
                          }
                      }
                  }
                 CloudAlbumTabView {
                     id: cloudAlbumTabView
                     cloudAlbumModel: cloudAlbumAssetModel
                     mediaListViewModel: tabView.mediaListViewModel
                 }
             }

             LightToaster {
                 id: mediaTabToaster
                 parent: root
             }

             Connections {
                 target: importLoader.item
                 function onCancelClick(){
                     localTabView.dataModel.setIsCancelImport(true)
                     importLoader.active = false
                 }
             }

             //*#*#*# 循环录影：合并处理中取消
             Connections {
                 target: loopVideoImportLoader.item
                 function onCancelClick() {
                     localTabView.dataModel.setIsCancelImport(true)
                     loopVideoImportCloseTimer.stop()
                     loopVideoImportLoader.active = false
                 }
             }

             //*#*#*# 循环录影：延迟关闭弹窗，确保进度条 100% 状态至少渲染一帧后再关闭
             Timer {
                 id: loopVideoImportCloseTimer
                 interval: 100
                 repeat: false
                 onTriggered: {
                     if (loopVideoImportLoader.active && loopVideoImportLoader.item) {
                         loopVideoImportLoader.item.close()
                         loopVideoImportLoader.active = false
                     }
                 }
             }

             Loader {
                 id: importLoader
                 // 默认不加载
                 active: false
                 // 排序弹框
                 sourceComponent: LightLoadPopup {
                     id: importLoading
                     text: qsTr("pccut_image_preview_tip") + "..." + "(" + processCount + "/" + totalCount + ")"
                 }
             }

             //*#*#*# 循环录影：合并处理中加载弹窗（仅文字，无文件数量）
             Loader {
                 id: loopVideoImportLoader
                 active: false
                 sourceComponent: LightLoadPopup {
                     text: qsTr("pccut_material_importing")
                 }
             }

             Loader {
                 id: loopMergeLoader
                 active: false
                 sourceComponent: LoopVideoMergePop {
                     onLeftButtonClicked: {
                         mediaListViewModel.onLoopVideoMergeDecision(false)
                     }
                     onRightButtonClicked: {
                         mediaListViewModel.onLoopVideoMergeDecision(true)
                     }
                     onClosed: {
                         loopMergeLoader.active = false
                     }
                 }
             }

             // function checkMediaDownload() {
             //     leftLocalIsExpanded = true;
             //     leftLocalSubIdx = downloadTabIndex;
             //     ignoreResetTab = true
             // }

         }
     }

}
