import QtQuick 2.15
import QtQuick.Dialogs
import QtCore
import QtQuick.Window 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.3
import Config 1.0
import Controls 1.0
import DeviceFileInfoModel 1.0
import DeviceMaterialAsyncLoader 1.0
import ProjectGenerator 1.0
import MediaTypeModel 1.0
import ShortcutAction 1.0
import CopiedFileListModel 1.0
import HighlightTaskStatus 1.0
import QmlConstants 1.0
import CloudAlbumTransferModel 1.0
import app_qrc 1.0
import Qt5Compat.GraphicalEffects

import DeviceMediaCategory 1.0
import DeviceMediaTypeCategory 1.0

import DeviceMediaCategoryViewModel 1.0
import DeviceMediaTypeCategoryViewModel 1.0
import HighLightThemeTabViewModel 1.0
import CloudAlbumTransferModel 1.0
import CloudAlbumManager 1.0

import "../controller"
import "../explorer"
import "../export"

Item {
    id: control
    
    // 🆕 暴露内部组件，供 DeviceView/CopiedView 的删除和下载按钮访问
    property alias deviceRemovePopup: deviceRemovePopup
    property alias highlightRemovePopupLoader: highlightRemovePopupLoader
    property alias fileFolderLoader: fileFolderLoader
    signal resetMultipleSelectStatus() 
    
    onVisibleChanged: {
        if (isDownloadPage) {
            hasDiskAccessPermission = true;
            if (visible) {
                homeView.copiedRed = false;
                allFileInfoModel.refreshCopiedList();
            }
            return;
        }
    }
    // 是否展示多选状态
    property bool showSelectState: homeView.showSelectState
    onShowSelectStateChanged: {
        if (!showSelectState) {
            allFileInfoModel.resetSelectedAssets();
        }
    }
    // 是否是下载页面
    property bool isDownloadPage: false
    
    // 🆕 接收从父组件传入的回调函数，用于切换回原片
    property var onSwitchToOriginal: null

    // 边距
    property int padding: 4
    // Item 间隔
    property int spacing: 24
    // Item 宽
    property int itemWidth: 177
    // Item 高
    property int itemHeight: 100
    // Delegate 宽
    property int delegateWidth: itemWidth + spacing
    // Delegate 高
    property int delegateHeight: itemHeight + spacing
    // 列数根据可视宽度和 Item 宽度计算
    property int columns: (list_view.width - list_view.leftMargin - list_view.rightMargin) / delegateWidth
                          < 1 ? 1 : (list_view.width - list_view.leftMargin - list_view.rightMargin) / delegateWidth

    property int sectionHeaderHeight: 64
    required property DeviceFileInfoModel allFileInfoModel

    // 是否是高光页面
    property bool isSelectHighlightTab: allFileInfoModel.deviceMediaCategory.selectedEnumValue === DeviceMediaCategory.Highlight

    property bool hasDiskAccessPermission: USBDeviceDetector.hasDiskAccessPermission || isDownloadPage

    onAllFileInfoModelChanged: {
        control.allFileInfoModel.setListview(list_view)
    }

    // 全选
    CShortcut {
        action: ShortcutAction.SELECT_ALL
        enabled: control.visible && showSelectState
        onActivated: {
           allFileInfoModel.selectAll();
        }
    }

    // 删除素材
    CShortcut {
        action: ShortcutAction.DELETE
        enabled: control.visible && showSelectState
        onActivated: {
            if (allFileInfoModel.selectCount < 1) {
                return;
            }
            if (isSelectHighlightTab) {
                // 高光tab下删除高光片段
                var highlightsMap = allFileInfoModel.getSelectedHighlightsMap();
                highlightRemovePopupLoader.active = true;
                highlightRemovePopupLoader.item.showPop(highlightsMap);
            } else {
                deviceRemovePopup.showPop(allFileInfoModel.selectedPathList());
            }
        }
    }
    // esc 退出选中
    CShortcut {
        action: ShortcutAction.ESCAPE_FULL_SCREEN
        enabled: control.visible && homeView.showSelectState
        onActivated: {
            homeView.showSelectState = false;
        }
    }

    Loader {
        id: fileFolderLoader
        property var fileList: []
        //*#*#*# 循环录影：整组下载时携带 groupId、虚拟路径和组MD5，用于下载页合并展示并还原 _fileMd5
        property string loopVideoGroupId: ""
        property string loopVirtualPath: ""
        property string loopGroupMd5: ""
        //*#*#*# 循环录影：批量下载参数列表，非空时优先使用 copyBatchFiles
        property var batchParams: []
        active: false
        anchors.fill:parent
        function showFolder(isShow) {
            if (isShow) {
                active = true;
                var defaultPath = lightSetting.getString("curCopyPath", StandardPaths.writableLocation(StandardPaths.DownloadLocation));
                defaultPath = fileOperator.isDirExists(defaultPath)?defaultPath:StandardPaths.writableLocation(StandardPaths.DownloadLocation);
                item.currentFolder = fileOperator.FileUrlWithPreFix(defaultPath);
                item.open();
            } else {
                item.close();
                active = false;
            }
        }

        sourceComponent: FolderDialog {
            id: fileDialog
            onAccepted: {
                var needCopyList = fileList
                var rawPath = fileDialog.currentFolder.toString()
                // 去掉 file:///
                var cleanedPath = rawPath.replace(/^file:\/\//, "")
                // Windows 下去掉开头的斜杠
                if (Qt.platform.os === "windows") {
                    cleanedPath = cleanedPath.replace(/^\//, "")
                }

                lightSetting.save("curCopyPath",cleanedPath)
                //*#*#*# 循环录影：batchParams 非空时调用批量下载接口（多选含循环录影）
                if (fileFolderLoader.batchParams && fileFolderLoader.batchParams.length > 0) {
                    // capture + clear，跟 loop 同理：dialog 异步回调时 fileFolderLoader 字段可能已被清空
                    var bp = fileFolderLoader.batchParams
                    fileFolderLoader.batchParams = [];
                    control.startBatchCopyWithStorageCheck(bp, cleanedPath);
                //*#*#*# 循环录影：有 groupId 时调用带组信息的下载接口，下载页可合并展示
                } else if (fileFolderLoader.loopVideoGroupId !== "") {
                    // 先 capture 到局部变量，再立即清空 fileFolderLoader 上的字段；
                    // 否则 storageWarn dialog 的异步回调里读到的会是空串，丢失合并组信息
                    var loopGid    = fileFolderLoader.loopVideoGroupId
                    var loopVPath  = fileFolderLoader.loopVirtualPath
                    var loopGMd5   = fileFolderLoader.loopGroupMd5
                    fileFolderLoader.loopVideoGroupId = "";
                    fileFolderLoader.loopVirtualPath  = "";
                    fileFolderLoader.loopGroupMd5     = "";
                    control.startCopyWithStorageCheck(needCopyList, cleanedPath,
                        loopGid, loopVPath, loopGMd5)
                } else {
                    // 普通文件路径：startCopyWithStorageCheck 内部按需 open copyFilePopup
                    control.startCopyWithStorageCheck(needCopyList, cleanedPath)
                }
                
                fileFolderLoader.active = false;
            }
            onRejected: {
                fileFolderLoader.batchParams = [];     //*#*#*# 循环录影
                fileFolderLoader.loopVideoGroupId = "";
                fileFolderLoader.loopVirtualPath  = "";
                fileFolderLoader.loopGroupMd5     = "";
                fileFolderLoader.active = false;
            }
        }
    }

    //*#*#*# 循环录影：损坏子文件降级提示（不适用下载页）
    Connections {
        target: allFileInfoModel
        enabled: !isDownloadPage
        //*#*#*# 循环录影：存在损坏子文件（片长为0），已降级为普通素材
        function onPartialLoopVideoImportFailed() {
            globalSignal.toast(qsTr("pccut_material_partial_import_failed"))
        }
    }

    //*#*#*# loopGroupId 非空时走 copyLoopRecordingFileList（单组循环录影），否则走 copyFileList（普通文件）
    function startCopyWithStorageCheck(needCopyList, cleanedPath,
                                       loopGroupId, loopVirtualPath, loopGroupMd5) {
        var totalSizeMB = copyFileManager.calculateTotalSizeMB(needCopyList)
        var doCopy = function() {
            if (loopGroupId && loopGroupId !== "") {
                copyFileManager.copyLoopRecordingFileList(needCopyList, cleanedPath,
                    loopGroupId, loopVirtualPath, loopGroupMd5)
            } else {
                copyFileManager.copyFileList(needCopyList, cleanedPath)
            }
        }
        if (fileOperator.checkStorageWarn(cleanedPath, totalSizeMB)) {
            var storageWarnDialog = Qt.createComponent("qrc:/Controls/ConfirmPopup.qml").createObject(control, {
                "title": qsTr("pccut_device_batch_download_low_storage"),
                "leftButtonText": qsTr("pccut_quick_delete_cancel"),
                "rightButtonText": qsTr("pccut_panel_image_directionlock_continue_yes")
            })

            if (!storageWarnDialog) {
                console.warn("Failed to create ConfirmPopup")
                copyFilePopup.open();
                doCopy()
                return
            }

            storageWarnDialog.onRightButtonClicked.connect(function() {
                copyFilePopup.open();
                doCopy()
            })
            storageWarnDialog.onClosed.connect(function() {
                storageWarnDialog.destroy()
                storageWarnDialog = null
            })
            storageWarnDialog.open()
        } else {
            copyFilePopup.open();
            doCopy()
        }
    }

    //*#*#*# 多选下载（含循环录影）专用预检：copyBatchFiles 内部按 isLoopVideo 分发
    function startBatchCopyWithStorageCheck(batchParams, cleanedPath) {
        // 多选含循环录影时 needCopyList 含 .osv 虚拟路径，QFileInfo 算成 0；必须用 batch 版
        var totalSizeMB = copyFileManager.calculateBatchTotalSizeMB(batchParams)
        if (fileOperator.checkStorageWarn(cleanedPath, totalSizeMB)) {
            var storageWarnDialog = Qt.createComponent("qrc:/Controls/ConfirmPopup.qml").createObject(control, {
                "title": qsTr("pccut_device_batch_download_low_storage"),
                "leftButtonText": qsTr("pccut_quick_delete_cancel"),
                "rightButtonText": qsTr("pccut_panel_image_directionlock_continue_yes")
            })
            storageWarnDialog.onRightButtonClicked.connect(function() {
                copyFilePopup.open();
                copyFileManager.copyBatchFiles(batchParams, cleanedPath)
            })
            storageWarnDialog.onClosed.connect(function() {
                storageWarnDialog.destroy()
                storageWarnDialog = null
            })
            storageWarnDialog.open()
        } else {
            copyFilePopup.open();
            copyFileManager.copyBatchFiles(batchParams, cleanedPath)
        }
    }

    // 设备素材导出弹窗
    Loader {
        id: deviceExportPopupLoader
        active: false
        property var pendingFileIdList: []
        property var pendingFileModel: null

        sourceComponent: DeviceExportSettingPopup {
            // 通过属性绑定直接传递数据（组件创建时即可用）
            selectedIdList: deviceExportPopupLoader.pendingFileIdList
            deviceFileInfoModel: deviceExportPopupLoader.pendingFileModel

            onClosed: {
                deviceExportPopupLoader.active = false;
            }
        }
        onLoaded: {
            // 数据已在 Component.onCompleted 中初始化，此处仅打开弹窗
            item.open();
        }
    }

    function showExportDialog(fileIdList, fileModel) {
        eventTracker.trackEvent("pccut_home_list_export_click");  // 数据埋点

        deviceExportPopupLoader.pendingFileIdList = fileIdList;
        deviceExportPopupLoader.pendingFileModel = fileModel;
        deviceExportPopupLoader.active = true;
    }

    WaitingPopup {
        id: waitingPopup
        property var removeFileList: []
        // 添加计时器
        Timer {
            id: timeoutTimer
            interval: 1000
            onTriggered: {
                waitingPopup.close();
                var resultList = [];
                var pathList = [];
                for (var i = 0; i < waitingPopup.removeFileList.length; i++) {
                    var path = waitingPopup.removeFileList[i];
                    var result = false;
                    var fileRealPath = "";
                    if (isDownloadPage) {
                        fileRealPath = copyFileManager.pathFromId(path);
                        result = (copyFileManager.removeCopiedFileId(path) >= 0);
                    } else {
                        fileRealPath = path;
                        result = USBDeviceDetector.removeFile(path);
                    }
                    if (result) {
                        resultList.push(path);
                        pathList.push(fileRealPath);
                    }
                }
                var errorCount = waitingPopup.removeFileList.length - resultList.length;
                if (errorCount > 0) {
                    var str = qsTr("pccut_device_batch_delete_fail").arg(errorCount);
                    globalSignal.toast(str);
                }
                globalSignal.deviceRemovedFileList(resultList, isDownloadPage, pathList);
            }
        }
        onOpened: timeoutTimer.start() // 弹窗打开时启动计时
        onClosed: timeoutTimer.stop()  // 弹窗关闭时停止计时
    }

    Connections {
        target: globalSignal

        function onMissingFileDetected() {
            if (isDownloadPage) {
                return;
            }
            // 检测到文件丢失，强制刷新一次列表
            globalSignal.deviceSelected(allFileInfoModel.getSelectedDevice())
        }

        // 响应windows上的素材删除，因为在播放器中使用的素材不能被删除, 目前的做法是关闭播放器窗口, 然后再走删除流程
        function onPlayerRemoveFileList(removeFileList, isDownloadRemove) {
            if (isDownloadPage !== isDownloadRemove) {
                return;
            }
            // console.log("======= playerRemoveFileList", removeFileList);
            globalSignal.closeWindow();
            waitingPopup.removeFileList = removeFileList;
            waitingPopup.open();
        }

        // 点击导出
        function onClickExportAction() {
            logger.i("[Device Panel] onClickExportAction");
            if (allFileInfoModel.selectCount < 1) {
                return;
            }
            control.showExportDialog(
                allFileInfoModel.selectedPathList(),
                allFileInfoModel
            );
        }
    }

    StackLayout {
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            bottom: parent.bottom
            leftMargin: 0
            rightMargin: 2
        }
        currentIndex: hasDiskAccessPermission ? 1 : 0

        Item {
            id: permissionGuidancePage
            ColumnLayout {
                id: contentLayout
                anchors.horizontalCenter: parent.horizontalCenter
                y: (parent.height - implicitHeight) / 2 * 0.8
                spacing: 0
                Image {
                    Layout.alignment: Qt.AlignHCenter
                    source: "qrc:/icons/icon_lock.svg"
                }
                RowLayout {
                    id: tipsLineLayout
                    Layout.topMargin: 24
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 8
                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        font {
                            pixelSize: 20
                        }
                        topPadding: -2
                        bottomPadding: -2
                        lineHeight: 24
                        lineHeightMode: Text.FixedHeight
                        
                        color: Colors.color_EEEEEE
                        text: qsTr("pccut_permission_movable_access_permission")
                    }
                    Image {
                        id: tipsIcon
                        Layout.preferredWidth: 16
                        Layout.preferredHeight: 16
                        Layout.alignment: Qt.AlignVCenter
                        source: tipsIconMouseArea.containsMouse ? "qrc:/icons/ic_explain.svg" : "qrc:/icons/ic_explain_hover.svg"
        
                        MouseArea {
                            id: tipsIconMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                        }
                    }
                }
                Text {
                    Layout.topMargin: 12
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 525
                    font.pixelSize: 14
                    lineHeight: 22
                    lineHeightMode: Text.FixedHeight
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignHCenter
                    color: Colors.color_999999
                    text: qsTr("pccut_permissions_fileaccess_home_text")
                }
                IconTextButton {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 40
                    Layout.preferredWidth: 140
                    Layout.preferredHeight: 40
                    titleFontSize: 14
                    isTextOnly: true
                    title: qsTr("pccut_quick_goto_enable")
                    alignment: Qt.AlignHCenter
                    titleColorNormal: ColorsConfig.color_FFFFFF_000000
                    backgroundColorNormal: ColorsConfig.color_F22443_4DFFC9
                    backgroundColorHover: ColorsConfig.color_F44C65_6DFFD3
                    onCustomClicked: {
                        if (!CommonUtils.isWindows()) {
                            eventTracker.trackEvent("pccut_home_authorize_click")
                            Tools.openSystemFilesAndFoldersPanel()
                        }
                    }
                }
            }
            LightPopup {
                id: tipsImagePopup
                parent: permissionGuidancePage
                x: contentLayout.x + tipsLineLayout.x + tipsIcon.x + tipsIcon.width + 2
                y: contentLayout.y + tipsLineLayout.y + tipsIcon.y - (implicitHeight - tipsIcon.height) / 2
                visible: tipsIconMouseArea.containsMouse
                modal: false
                background: Item{}
                RowLayout {
                    spacing: 0
                    Image {
                        source: "qrc:/icons/icon_fileandfloder_point.svg"
                    }
                    Image {
                        Layout.preferredWidth: 400
                        Layout.preferredHeight: 345
                        asynchronous: true
                        source: translationHandler.isChineseLang() ? "qrc:/app_qrc/FileAndFloderPage.png" : "qrc:/app_qrc/FileAndFloderPage_en.png"
                    }
                }
            }
        }

        // 套一层 Item clip 剪去 ListView 尾巴上多余的部分不显示出来
        Item {
            onVisibleChanged: {
                if (!visible) {
                    allFileInfoModel.resetSelectedAssets();
                }
                if (homeView.isSwitchIngDevicePage) {
                    return;
                }
                if (!visible) {
                    homeView.showSelectState = false;
                }
                // 已删除：批量选择按钮已从 AppBar 移到 DeviceView/CopiedView，不再需要控制可见性
                // appbar.multipleSelectDeviceBtn.visible = visible;
            }
            id: listSuperView
            clip: true
            MouseArea {
                anchors.fill: parent
                onClicked: (mouse) => {
                    if (dragSelectMouseArea.isShowRect) {
                        return;
                    }
                    var scrollBarPos = listScrollBar.mapToItem(listSuperView, 0, 0)
                    if (mouse.x >= scrollBarPos.x && mouse.x <= scrollBarPos.x + listScrollBar.width) {
                        return;
                    }
                    allFileInfoModel.resetSelectedAssets();
                }
            }
            
            ListView {
                id: list_view
                property var listColumsSize: control.columns
                width: parent.width
                // 高度多一个 delegate 放置 footer，防止末尾的一行滑倒底部后隐藏
                // 多出来的一部分会被外部 Item clip 掉
                // height: parent.height
                interactive: !bgSelectionRect.visible
                height: parent.height + control.delegateHeight * 1
                headerPositioning: ListView.OverlayHeader
                //topMargin: 24
                leftMargin: 40
                rightMargin: 16
                // 底部多一个 footer 撑高可显示范围，防止末尾的一行滑倒底部后隐藏
                footerPositioning: ListView.OverlayFooter
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {
                    id: listScrollBar
                    // padding 加上 ListView 多出来的一部分
                    bottomPadding: padding
                    rightPadding: 6
                    Component.onCompleted: {
                        contentItem.color = Colors.color_444444
                    }
                }
                footer: Item {
                    // 竖向的 ListView 宽度无所谓
                    width: 1
                    // 高度大于等于 delegate 高度才能保证显示
                    height: control.delegateHeight * 3
                }
                model: allFileInfoModel
                section {
                    property: "creationDate"
                    criteria: ViewSection.FullString
                    delegate: Item {
                        width: list_view.width - control.padding
                        height: sectionHeaderHeight
                        Text {
                            text: section
                            font.pixelSize: 16
                            anchors.bottom: parent.bottom
                            anchors.topMargin: 16
                            anchors.bottomMargin: 24
                            color: Colors.color_FFFFFF
                        }
                    }
                    labelPositioning: ViewSection.InlineLabels
                }

                delegate: Item {
                    id: list_item_root
                    property var indexValue: index
                    property var realY: (model.groupId % control.columns !== 0) ? -control.delegateHeight : 0
                    //*#*#*# 循环录影：子文件路径列表（定义在根 delegate 上，确保子组件均可访问）
                    property var allSubPaths: allFileInfoModel.getRealPathsForId(model.id)
                    //*#*#*# 循环录影：首个真实子文件路径（用于封面图和 AsyncLoader 加载时长/损坏状态）
                    property string thumbnailPath: allSubPaths.length > 0 ? allSubPaths[0] : model.path

                    width: control.delegateWidth
                    // 每行第一个 Item 有高度，后面的没高度，这样就能排列到一行
                    // 因为 0 高度 Item 在末尾，超出范围 visible 就置为 false 了，所以才需要 footer 撑高多显示一行的内容
                    // delegate 高度不一致会导致滚动条滚动时长度变化
                    height: (model.groupId % control.columns === 0) ? control.delegateHeight : 0
                    // 放置真正的内容
                    Item {
                        // 根据列号计算 x
                        x: (model.groupId % control.columns) * control.delegateWidth
                        // 负高度就能和每行第一个的 y 一样
                        y: (model.groupId % control.columns !== 0) ? -control.delegateHeight : 0
                        width: control.itemWidth
                        height: control.itemHeight

                        LightClipRectangle {
                            id: imageClip
                            radius: [6, 6, 6, 6]
                            width: control.itemWidth
                            height: control.itemHeight
                            color: Colors.color_444444
                            clip: true
                            Image {
                                source: "image://image_provider/" + (model.isHighlightItem ? model.highlightCover : thumbnailPath) + ";0;0;0;1;1"
                                sourceSize: Qt.size(control.itemWidth, control.itemHeight)
                                fillMode: Image.PreserveAspectCrop
                                anchors.fill: parent
                                visible: !agency16KTimelapseCover.visible && !damagedCover.visible
                            }

                            Rectangle {
                                id: agency16KTimelapseCover
                                width: parent.width
                                height: parent.height
                                color: Colors.color_19191A
                                visible: {
                                    if(!control.isDownloadPage) {
                                        return false;
                                    }
                                    return textLoader.is16KTimelapse && !model.agencyExists;
                                }
                                Image {
                                    anchors.centerIn: parent
                                    width: 134
                                    height: 60
                                    fillMode: Image.PreserveAspectFit
                                    source: control.isDownloadPage ? "qrc:/app_qrc/icons/icon_agency_missing.svg" : "qrc:/app_qrc/icons/icon_device_agency_missing.svg"
                                }
                            }

                            Rectangle {
                                id: damagedCover
                                width: parent.width
                                height: parent.height
                                color: Colors.color_1F2021
                                visible: textLoader.fileDamaged

                                Image {
                                    id: damagedIcon
                                    anchors.centerIn: parent
                                    width: 40
                                    height: 30
                                    sourceSize: Qt.size(40, 30)
                                    source: "qrc:icons/ic_resource_damaged.png"
                                }
                            }

                            DeviceMaterialAsyncLoader {
                                id: textLoader
                                //*#*#*# 循环录影：首个真实子文件路径，避免 fileDamaged=true 遮盖封面
                                filePath: thumbnailPath
                                deviceName: model.deviceName
                                //*#*#*# 循环录影：传虚拟路径+子文件总数，确保所有子文件下完才显示"已下载"图标
                                loopVirtualPath: allSubPaths.length > 1 ? model.id : ""
                                totalSubFileCount: allSubPaths.length
                                //*#*#*# 循环录影：传所有子文件路径，以便 onLoadText 累加总时长
                                subFilePaths: allSubPaths
                                onFileMd5Changed: {
                                    allFileInfoModel.updateFile(index, textLoader.fileMd5);
                                }
                            }

                            Image {
                                id: typeIcon
                                source: textLoader.typeIconName
                                visible: textLoader.typeIconName.length > 0
                                property bool trackedIcon: false  // 标记是否已上报

                                width: 16
                                height: 16
                                anchors.left: parent.left
                                anchors.leftMargin: 8
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 6
                                sourceSize: Qt.size(typeIcon.width * 2,
                                                    typeIcon.width * 2)
                                fillMode: Image.PreserveAspectFit // 保持纵横比

                                // 当图标可见时上报埋点
                                onVisibleChanged: {
                                    if (visible && !trackedIcon && textLoader.typeIconName.length > 0) {
                                        var quickshotType = getQuickshotTypeFromIcon(textLoader.typeIconName);
                                        if (quickshotType !== "none") {
                                            trackedIcon = true;
                                            eventTracker.trackEvent("pccut_quickshot_icon_show", {
                                                "quickshot_type": quickshotType,
                                                "show_location": "home_device"
                                            });
                                        }
                                    }
                                }

                                // 根据图标路径判断一键短片类型
                                function getQuickshotTypeFromIcon(iconPath) {
                                    if (iconPath.indexOf("quick_video_rocket") !== -1) return "rocket";
                                    if (iconPath.indexOf("quick_video_dronie") !== -1) return "dronie";
                                    if (iconPath.indexOf("quick_video_orbit") !== -1) return "orbit";
                                    if (iconPath.indexOf("quick_video_circle") !== -1) return "circle";
                                    if (iconPath.indexOf("quick_video_helix") !== -1) return "helix";
                                    if (iconPath.indexOf("quick_video_comet") !== -1) return "comet";
                                    return "none";
                                }
                            }

                            // Dlog-M标志
                            Rectangle {
                                id: logmRect
                                anchors {
                                    left: typeIcon.visible ? typeIcon.right : parent.left
                                    leftMargin: typeIcon.visible ? 4 : 8
                                    verticalCenter: typeIcon.verticalCenter
                                }
                                width: 24
                                height: 16
                                color: Colors.transparent
                                visible: textLoader.colorMode === QmlConstants.deviceLutLogmName
                                Image {
                                    source: "qrc:/icons/material_type_logm.svg"
                                    width: 24
                                    height: 16
                                    anchors.centerIn: parent
                                    sourceSize: Qt.size(24, 16)
                                }
                            }

                            Text {
                                id: durationText
                                anchors.left: logmRect.visible ? logmRect.right : (typeIcon.visible ? typeIcon.right : parent.left)
                                anchors.leftMargin: logmRect.visible ? 4 : (typeIcon.visible ? 4 : 8)
                                anchors.verticalCenter: typeIcon.verticalCenter
                                visible: model.isVideo
                                text: model.isHighlightItem ? model.highlightLengthText : textLoader.text
                                color: Colors.color_FFFFFF
                                font.pixelSize: 10
                            }

                            Image {
                                id: likeIcon
                                // 👆 封面顶部右侧：在 selectIcon 左侧 4px，如果没有 selectIcon 则占据最右侧
                                anchors.right: selectIcon.visible ? selectIcon.left : parent.right
                                anchors.rightMargin: selectIcon.visible ? 4 : 8
                                anchors.top: parent.top
                                anchors.topMargin: 8
                                source: "qrc:/app_qrc/icons/mediaimport_favorite_yes_icon.svg"
                                visible: isFavorite
                                width: 20
                                height: 20
                                sourceSize: Qt.size(20, 20)
                            }

                            Image {
                                id: selectIcon
                                // 👆 封面顶部右侧最右侧：占据右上角，多选时显示
                                anchors.right: parent.right
                                anchors.rightMargin: 8
                                anchors.top: parent.top
                                anchors.topMargin: 8
                                source: isSelected ? "qrc:/app_qrc/icons/media_selected.svg" : "qrc:/icons/media_normal.svg"
                                visible: showSelectState
                                width: 20
                                height: 20
                                sourceSize: Qt.size(20, 20)
                            }


                            Rectangle {
                                // 👆 封面顶部左侧最左侧：已下载素材显示
                                id: iconDownload
                                anchors.left: parent.left
                                anchors.leftMargin: 8
                                anchors.top: parent.top
                                anchors.topMargin: 8
                                width: 20
                                height: 20
                                color: Colors.color_000000_50
                                radius: 4
                                visible: !isDownloadPage && textLoader.copied
                                Image {
                                    source: "qrc:/icons/media_download.svg"
                                    width: 20
                                    height: 20
                                    anchors.centerIn: parent
                                    sourceSize: Qt.size(20, 20)
                                }
                            }

                            Rectangle {
                                // 封面顶部左侧：已上传云端标记
                                id: iconCloudUploaded
                                anchors.left: iconDownload.visible ? iconDownload.right : parent.left
                                anchors.leftMargin: iconDownload.visible ? 4 : 8
                                anchors.top: parent.top
                                anchors.topMargin: 8
                                width: 20
                                height: 20
                                color: Colors.color_000000_50
                                radius: 4
                                visible: {
                                    if (isDownloadPage) return false;
                                    var md5 = textLoader.fileMd5;
                                    if (!md5 || md5.length === 0) return false;
                                    // uploadedRevision 变化时触发重新求值
                                    var _rev = CloudAlbumTransferModel.uploadedRevision;
                                    var uploaded = CloudAlbumTransferModel.isFileUploaded(md5);
                                    console.log("[DevicePanel] iconCloudUploaded: path=" + model.path
                                                + " md5=" + md5 + " uploaded=" + uploaded);
                                    return uploaded;
                                }
                                Image {
                                    source: "qrc:/icons/media_type_cloud_uploaded.svg"
                                    width: 20
                                    height: 20
                                    anchors.centerIn: parent
                                    sourceSize: Qt.size(20, 20)
                                }
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: 6
                                color: Colors.transparent
                                border.color: Colors.color_FFFFFF_30
                                border.width: 2
                                visible: clickedBox.containsMouse || highlightButton.selfHovered
                            }

                            MouseArea {
                                id: clickedBox
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: (mouse) => {
                                    if (mouse.button === Qt.RightButton) {
                                        // 多选状态不响应右键
                                        if (showSelectState) {
                                            return;
                                        }
                                        var newPoint = clickedBox.mapToItem(control, mouseX, mouseY);
                                        if (control.height - newPoint.y < 150) {
                                            newPoint.y = control.height - 150;
                                        }
                                        fileOperatePopupLoader.openPop(newPoint, model.id, index, model.path, textLoader.isSupportHighlight, textLoader.fileMd5);
                                        return;
                                    }
                                    if (showSelectState) {
                                        if (dragSelectMouseArea.isShowRect) {
                                            return;
                                        }
                                        if (mouse.button === Qt.LeftButton && (mouse.modifiers & Qt.ShiftModifier)) {
                                            allFileInfoModel.continuousSelect(index);
                                            return;
                                        }
                                        if (allFileInfoModel.isSelectedForAssetId(model.id)) {
                                            allFileInfoModel.removeSelectedAssetId(model.id);
                                        } else {
                                            allFileInfoModel.appendSelectedAssetId([model.id]);
                                        }
                                        return;
                                    }
                                    // 循环录影：getRealPathsForId 返回所有真实子文件路径；普通文件返回 [model.path]
                                    var realSubPaths = allFileInfoModel.getRealPathsForId(model.id);
                                    //*#*#*# 循环录影：检查所有子文件，任意一个缺失均视为损坏，toast 显示虚拟路径名
                                    if (realSubPaths.length > 1) {
                                        var loopMissing = false;
                                        for (var si = 0; si < realSubPaths.length; si++) {
                                            if (!fileOperator.asyncIsExists(realSubPaths[si])) {
                                                loopMissing = true;
                                                break;
                                            }
                                        }
                                        if (loopMissing) {
                                            toast.showToast(model.path + " " + qsTr("pccut_player_lost"));
                                            return;
                                        }
                                    } else {
                                        var checkPath = realSubPaths.length > 0 ? realSubPaths[0] : model.path;
                                        if (!fileOperator.asyncIsExists(checkPath)) {
                                            toast.showToast(checkPath + " " + qsTr("pccut_player_lost"));
                                            return;
                                        }
                                    }
                                    if (textLoader.is16KTimelapse && !model.agencyExists) {
                                        toast.showToast(qsTr("pccut_timelapse_tip_3"));
                                        return;
                                    }

                                     // deviceOpenMedia 内部将虚拟路径展开为所有真实子文件，isDownloadPage 独立控制来源类型
                                     var loopMd5 = allFileInfoModel.getFileMd5ById(model.id);
                                     openOperator.deviceOpenMedia({
                                         "allPaths":            allFileInfoModel.getAllFilesPathSet(),
                                         "virtualTarget":       model.path,
                                         "realSubPaths":        realSubPaths,
                                         "isLoopRecording":     realSubPaths.length > 1,
                                         "loopVideoGroupId":    allFileInfoModel.getGroupIdById(model.id),
                                         "virtualPath":         model.id,
                                         "fileMd5":             loopMd5,
                                         "allLoopSubFilesMap":  allFileInfoModel.getAllLoopVideoSubFilesMap()
                                     }, isDownloadPage);

                                    // 移到C++侧处理预览弹窗
                                    // openOperator.deviceOpen(allFileInfoModel.getAllFilesPathSet(), model.path, isDownloadPage);
                                    allFileInfoModel.openPreviewWindow(model.id, isDownloadPage);
                                 }
                             }

                            // 👆 高光按钮：动态定位
                            //   - Ready 状态：右上角区域（在 likeIcon/selectIcon 左侧 4px），向下显示 Tooltip (y: 34, x: 68)
                            //   - 非 Ready 状态：左上角区域（在 iconDownload 右侧 4px 或占据最左侧），向下显示 Tooltip (y: 34, x: 68)
                            HighlightButton {
                                id: highlightButton

                                eventTrackingHighlightTag: "home"  // 高光分析埋点
                                videoId: textLoader.fileMd5
                                
                                // 判断是否为 INIT 状态（需要在 visible 之前定义）
                                property bool isReadyState: currentState === HighlightTaskStatus.INIT
                                property bool noHighlight: currentState === HighlightTaskStatus.SUCCESS && !hasHighlightItem
                                
                                // 可见性控制：
                                // - INIT 状态：鼠标 hover 封面或按钮本身时显示
                                // - 非 INIT 状态：常驻显示
                                visible: !(videoId.length === 0) && (!selectIcon.visible || !isReadyState) && !control.isSelectHighlightTab && !noHighlight &&
                                         (
                                             (isReadyState && (clickedBox.containsMouse || selfHovered)) ||  // INIT: hover 封面或按钮时显示
                                             (!isReadyState)  // 非 INIT: 常驻显示
                                         ) && textLoader.isSupportHighlight
                                         
                                width: isReadyState ? 24 : 20
                                height: isReadyState ? 24 : 20

                                // X 坐标动态计算
                                x: {
                                    if (isReadyState) {
                                        // Ready 状态：右上角区域
                                        if (likeIcon.visible) {
                                            // 在 likeIcon 左侧
                                            return likeIcon.x - width - 4
                                        } else if (selectIcon.visible) {
                                            // 在 selectIcon 左侧
                                            return selectIcon.x - width - 4
                                        } else {
                                            // 直接右上角
                                            return parent.width - width - 6
                                        }
                                    } else {
                                        // 非 Ready 状态：左上角区域
                                        if (iconDownload.visible) {
                                            // 在 iconDownload 右侧
                                            return iconDownload.x + iconDownload.width + 4
                                        } else {
                                            // 直接左上角
                                            return 8
                                        }
                                    }
                                }

                                // Y 坐标：统一在顶部
                                y: isReadyState ? 6 : 8

                                filePath: model.path
                                isHovered: clickedBox.containsMouse
                            }
                        }
                    }

                }

                Component.onCompleted: {
                    control.allFileInfoModel.setListview(list_view)
                }
            }

            // 素材加载提示
            Rectangle {
                id: loadingMask
                anchors.fill: parent
                color: Colors.color_content_area_background
                visible: !isDownloadPage && allFileInfoModel.isLoading
                ColumnLayout {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12
                    Image {
                        id: loadingIcon
                        width: 48
                        height: 48
                        source: "qrc:/icons/icon_loading.png"
                        sourceSize: Qt.size(48, 48)
                        Layout.alignment: Qt.AlignHCenter
                        RotationAnimation on rotation {
                            from: 0
                            to: 360
                            running: loadingMask.visible
                            duration: 2000
                            loops: Animation.Infinite
                        }
                    }
                    Text {
                        id: loadingText
                        text: qsTr("pccut_material_loading")
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        color: Colors.color_EEEEEE
                        Layout.alignment: Qt.AlignHCenter
                        Layout.maximumWidth: loadingMask.width - 80
                        elide: Text.ElideRight
                        maximumLineCount: 1

                        MouseArea {
                            id: loadingTextMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.NoButton
                        }

                        LightToolTip {
                            visible: loadingTextMouseArea.containsMouse && loadingText.truncated
                            tip: loadingText.text
                        }
                    }
                }
            }

            ProjectGenerator {
                id: projectGenerator
            }

            // 高光任务按钮
            FixedWidthIconTextButton {
                id: highlightTaskBtn
                anchors.right: createBtn.visible ? createBtn.left : parent.right
                anchors.rightMargin: createBtn.visible ? 8 : 40
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 40
                visible: homeView.showSelectState && !isSelectHighlightTab && !allFileInfoModel.aiRoughCutSupport && allFileInfoModel.selectedCanHighlightPathAndMd5.length > 0
                // 尺寸
                fixedWidth: 140
                fixedHeight: 44

                // 图标
                iconPathNormal: "qrc:/icons/highlight/ic_highlight.svg"
                iconSize: Qt.size(20, 20)

                // 文字
                title: qsTr("pccut_panel_adjust_highlights")  // 高光
                titleFontSize: 16
                titleFontWeight: Font.Medium
                titleColorNormal: Colors.color_FFFFFF

                // 布局
                internalSpacing: 4  // 图标与文字间距 4px

                // 背景：透明（使用自定义背景）
                backgroundColorNormal: "transparent"
                backgroundColorHover: "transparent"

                // 自定义 SVG 背景（渐变色）
                customBackground: Component {
                    Rectangle {
                        radius: 6
                        color: "transparent"
                        antialiasing: true

                        // SVG 背景图片
                        Image {
                            anchors.fill: parent
                            source: highlightTaskBtn.hovered
                                ? "qrc:/icons/highlight/ic_hl_bg_highlight.svg"
                                : "qrc:/icons/highlight/ic_hl_bg.svg"
                            sourceSize: Qt.size(parent.width, parent.height)
                        }
                    }
                }

                onCustomClicked: {
                    allFileInfoModel.batchStartHighlight();
                    control.resetMultipleSelectStatus()
                }
            }
            // 灵感粗剪按钮
            Item {
                id: roughCutTaskBtn
                anchors.right: createBtn.visible ? createBtn.left : parent.right
                anchors.rightMargin: createBtn.visible ? 8 : 40
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 40
                width: 140
                height: 44
                opacity: !allFileInfoModel.canAiRoughCut ? 0.2 : 1.0
                visible: allFileInfoModel.aiRoughCutSupport && homeView.showSelectState && allFileInfoModel.selectCount >= 1 && !highlightTaskBtn.visible

                onVisibleChanged: {
                    if (visible) {
                        eventTracker.trackEvent("pccut_auto_edit_entrance_show", {"page_source": "hardware"})
                    }
                }

                property bool taskDisabled: !allFileInfoModel.canAiRoughCut

                Image {
                    id: roughCutDeviceBg
                    anchors.fill: parent
                    source: (!roughCutTaskBtn.taskDisabled && roughCutDeviceMouse.containsMouse)
                        ? "qrc:/icons/roughcut/roughcut_device_hover_bg.svg"
                        : "qrc:/icons/roughcut/roughcut_device_default_bg.svg"
                    fillMode: Image.Stretch
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 6

                    Image {
                        width: 20
                        height: 20
                        anchors.verticalCenter: parent.verticalCenter
                        source: "qrc:/icons/roughcut/roughcut_sparkle.svg"
                        sourceSize: Qt.size(20, 20)
                    }

                    Text {
                        id: roughCutDeviceBtnText
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, roughCutTaskBtn.width - 20 - 6 - 24)
                        text: qsTr("pccut_roughcut_title")
                        color: "#FFFFFF"
                        font.pixelSize: 16
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    id: roughCutDeviceMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: roughCutTaskBtn.taskDisabled ? Qt.ArrowCursor : Qt.PointingHandCursor
                    onPressed: function(mouse) {
                        mouse.accepted = true;
                        if (roughCutTaskBtn.taskDisabled) return;
                        allFileInfoModel.openRoughCutLoadingPanel()
                        allFileInfoModel.checkLoginBeforeRoughCut();
                    }
                }

                LightToolTip {
                    visible: roughCutDeviceMouse.containsMouse && (roughCutTaskBtn.taskDisabled || roughCutDeviceBtnText.truncated)
                    tip: roughCutTaskBtn.taskDisabled ? allFileInfoModel.aiRoughCutDisableReason : qsTr("pccut_roughcut_title")
                }
            }
            // 创作按钮
            FixedWidthIconTextButton {
                id: createBtn
                anchors.right: parent.right
                anchors.rightMargin: 40
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 40
                visible: allFileInfoModel.displayMediaCount > 0

                // 尺寸
                fixedWidth: 140
                fixedHeight: 44

                // 图标
                iconPathNormal: "qrc:/icons/highlight/ic_create2.svg"
                iconSize: Qt.size(20, 20)

                // 文字
                title: qsTr("pccut_project_creation")  // 创作
                titleFontSize: 16
                titleFontWeight: Font.Medium
                titleColorNormal: Colors.color_141414

                // 布局
                internalSpacing: 4  // 图标与文字间距 4px

                // 背景配置（纯色）
                backgroundColorNormal: Colors.color_EEEEEE
                backgroundColorHover: Colors.color_FFFFFF
                radius: 6

                onCustomClicked: {
                    // 创作
                    var paramList = allFileInfoModel.getSelectedProcessParams(isDownloadPage);
                    projectGenerator.processDeviceFileList(paramList, allFileInfoModel.selectedHighlightIds(), allFileInfoModel.getSelectedDevice(), isDownloadPage);

                    eventTracker.trackEvent("pccut_create_project_click", {"use_method": "player"});
                }
            }

        }
    }

    Item {
        anchors {
            top: parent.top
            topMargin: -72
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }

        DeviceHighlightEmptyPanel {
            id: highlightEmptyPanel
            width: 654
            height: 476
            anchors.centerIn: parent

            z: 100
            visible: isSelectHighlightTab && allFileInfoModel.highlightLoadFinish && allFileInfoModel.isHighlightMediaListEmpty
            onBackOriginalPage: () => {
                allFileInfoModel.deviceMediaCategory.selectedIndex = 0
            }
        }

        LoadingPanelView {
            anchors.centerIn: parent
            z: 100

            visible: isSelectHighlightTab && !allFileInfoModel.highlightLoadFinish
            loadingTextTip: qsTr("pccut_media_loading")
            loadingTextColor: Colors.color_666666
            loadingTextFont.pixelSize: 14
            backgroudColor: Colors.color_content_area_background
        }
    }

    // 画框多选
    MouseArea {
        id: dragSelectMouseArea
        anchors.fill: parent
        anchors.rightMargin: 14 // 滚动条宽度(8) + rightPadding(6)
        parent: list_view
        acceptedButtons: Qt.LeftButton
        z: Number.MAX_SAFE_INTEGER
        propagateComposedEvents: true
        property real startX: 0
        property real startY: 0
        property real startContentY: 0
        property real currentX: 0
        property real currentY: 0
        property bool isShowRect: false
        onClicked: (mouse) => {
            mouse.accepted = false;
        }
        onPressedChanged: {
            if (pressed) {
                list_view.forceLayout();
                dragSelectMouseArea.isShowRect = false;
                ShortcutObserver.disableAllShortcut(true);
            } else {
                ShortcutObserver.disableAllShortcut(false);
                scrollTimer.stop();
            }
        }
        onPressed: (mouse) => {
            if (pressed) {
                let point = mapToItem(list_view, Qt.point(mouse.x, mouse.y));
                startX = point.x - list_view.leftMargin;
                startY = point.y;
                currentX = startX;
                currentY = startY;
                startContentY = list_view.contentY;
                scrollTimer.scrollDirectionY = 0;
                scrollTimer.maxContentY = 0;
                scrollTimer.start();
            }
        }

        onPositionChanged: (mouse) => {
            if (mouse.buttons === Qt.LeftButton) {
                // console.log("========onPositionChanged:");
                let point = mapToItem(listSuperView, Qt.point(mouse.x, mouse.y));
                currentX = point.x - list_view.leftMargin;
                currentY = point.y;
                // 检测边缘并设置滚动方向
                let edge = 30;
                // 滑动的速度
                let distance = 5;
                var speed = 0;
                if (point.y < edge) {
                    speed = (point.y - edge) / (edge * 2);
                } else if (listSuperView.height - edge < point.y) {
                    speed = (point.y + edge - listSuperView.height) / (edge * 2);
                }
                speed = speed * distance;
                scrollTimer.scrollDirectionY = speed;
            }
        }

        onCanceled: {
            scrollTimer.stop();
        }

        onReleased: {
            scrollTimer.stop();
        
        }

        Rectangle {
            id: bgSelectionRect
            parent: list_view.contentItem
            color: Colors.color_FFFFFF_10
            radius: 2
            border.width: 1
            border.color: Colors.color_FFFFFF_20
            z: Number.MAX_SAFE_INTEGER
            visible: dragSelectMouseArea.pressed
            x: Math.min(dragSelectMouseArea.startX, dragSelectMouseArea.currentX)
            width: Math.abs(dragSelectMouseArea.startX - dragSelectMouseArea.currentX)
            y: Math.min(dragSelectMouseArea.startY + dragSelectMouseArea.startContentY, dragSelectMouseArea.currentY + list_view.contentY)
            height: Math.abs(dragSelectMouseArea.startY + dragSelectMouseArea.startContentY - dragSelectMouseArea.currentY - list_view.contentY)
            onWidthChanged: {
                refreshDragSelect();
            }

            onHeightChanged: {
                refreshDragSelect();
            }

            function refreshDragSelect() {
                // 判定一定是鼠标拖拽画框的过程中
                if (!bgSelectionRect.visible || !dragSelectMouseArea.pressed) {
                    return;
                }
                if (bgSelectionRect.width < 2 || bgSelectionRect.height < 2) {
                    return;
                }
                if (!showSelectState) {
                    homeView.showSelectState = true;
                }
                dragSelectMouseArea.isShowRect = true;
                const selectRect = Qt.rect(bgSelectionRect.x, bgSelectionRect.y, bgSelectionRect.width, bgSelectionRect.height);
                const cellSize = Qt.size(control.delegateWidth, control.delegateHeight);
                const itemRect = Qt.rect(0, 0, control.itemWidth, control.itemHeight);

                var indicatePoint = Qt.point(0, 0);
                const allChildCount = list_view.contentItem.children.length;
                for (var i = allChildCount - 1; i >= 0; i--) {
                    var item = list_view.contentItem.children[i];
                    if (item.indexValue !== undefined) {
                        indicatePoint.x = item.indexValue;
                        indicatePoint.y = item.y + item.realY;
                        break;
                    }
                }
                // console.log("========>>>>>", selectRect, indicatePoint, control.sectionHeaderHeight, cellSize, itemRect);
                allFileInfoModel.dragSelect(selectRect, control.columns, control.sectionHeaderHeight, cellSize, itemRect, indicatePoint);
            }
        }

        Timer {
            id: scrollTimer
            interval: 20
            repeat: true
            running: false
            // 小于0 是向上移动, 大于0 是向下移动
            property int scrollDirectionY: 0
            property int maxContentY: 0
            onTriggered: {
                if (scrollDirectionY !== 0 && list_view.visible) {
                    var contentY = list_view.contentY + scrollDirectionY * 10;
                    const cellSize = Qt.size(control.delegateWidth, control.delegateHeight);
                    var realHeight = allFileInfoModel.getContentHeight(control.columns, control.sectionHeaderHeight, cellSize);
                    // 这里没有办法, 需要先给一个比较大的值后续再纠正
                    var currentMaxY = list_view.contentHeight * 1000;
                    if (scrollTimer.maxContentY != 0) {
                        currentMaxY = scrollTimer.maxContentY;
                    }
                    if (contentY < list_view.originY) {
                        contentY = list_view.originY;
                    }
                    contentY = Math.min(contentY, currentMaxY);
                    list_view.contentY = contentY;
                    // console.log("=======>", contentY, list_view.contentY, list_view.originY, scrollTimer.maxContentY, scrollDirectionY);
                    if (contentY !== list_view.contentY) {
                        if (scrollDirectionY > 0) {
                            scrollTimer.maxContentY = list_view.contentY;
                        }
                    }
                }
            }
        }
    }
    // 删除
    DeviceRemovePopup {
        id: deviceRemovePopup
        isDownloadRemove: isDownloadPage
        fileInfoModel: allFileInfoModel
        onShowToast: (toastStr) => {
            toast.showToast(toastStr);
        }
    }
    // 高光删除
    Loader {
        id: highlightRemovePopupLoader
        active: false
        sourceComponent: HighlightRemovePopup {
            onShowToast: (toastStr) => {
                toast.showToast(toastStr);
            }
        }
    }
    // copy 下载
    CopyFilePopup {
        id: copyFilePopup
        isFinshed: false
        Connections {
            target: copyFileManager
            function onAllFinished(errorList) {
                if (!copyFilePopup.visible) {
                    return;
                }

                if (errorList.length > 0) {
                    if (showSelectState) {
                        allFileInfoModel.resetSelectedAssets(errorList);
                    } else {
                        allFileInfoModel.resetSelectedAssets();
                    }
                    copyFilePopup.close()
                    globalSignal.toast(qsTr("pccut_device_batch_download_fail").arg(errorList.length));
                } else {
                    allFileInfoModel.resetSelectedAssets();
                    copyFilePopup.isFinshed = true;
                }
            }
        }

        onRightButtonClicked: {
            homeView.checkDownload();
        }
    }

    // 右键
    Loader {
        id: fileOperatePopupLoader
        active: false
        property var controlRef: control
        function openPop(showPoint, fileId, index, filePath, isSupportHighlight, fileMd5) {
            active = true;
            var fileOperatePopup = fileOperatePopupLoader.item;
            fileOperatePopup.x = showPoint.x;
            fileOperatePopup.y = showPoint.y;
            fileOperatePopup.fileId = fileId;
            fileOperatePopup.index = index;
            fileOperatePopup.filePath = filePath;
            fileOperatePopup.fileMd5 = fileMd5 || "";
            var operateModels = fileOperatePopup.listModel;
            operateModels.clear();
            operateModels.append({"title": qsTr("pccut_device_batch_edit"), "type": Instance.DEVICE_FILE_TYPE.DEVICE_FILE_CREATE});
            if (isDownloadPage) {
                operateModels.append({"title": qsTr("pccut_device_local_file_open"), "type": Instance.DEVICE_FILE_TYPE.DEVICE_FILE_OPEN});
            } else {
                var copiedPath = allFileInfoModel.getCopiedPath(index);
                operateModels.append({"title": qsTr("pccut_device_camera_file_open"), "type": Instance.DEVICE_FILE_TYPE.DEVICE_FILE_OPEN});
                if (copiedPath === "") {
                    operateModels.append({"title": qsTr("pccut_home_original_download"), "type": Instance.DEVICE_FILE_TYPE.DEVICE_FILE_DOWNLOAD});
                } else {
                    operateModels.append({"title": qsTr("pccut_device_local_file_open"), "type": Instance.DEVICE_FILE_TYPE.DEVICE_FILE_COPIED_OPEN});
                }
            }

            // 导出为视频文件（仅支持全景视频）
            if (Tools.isPanoramaFormat(filePath)) {
                operateModels.append({"title": qsTr("pccut_home_highlight_export_tab"), "type": Instance.DEVICE_FILE_TYPE.DEVICE_FILE_EXPORT_VIDEO});
            }

            // 灵感高光分析 / 取消灵感高光分析（仅在原片tab下显示）
            if (!isSelectHighlightTab && isSupportHighlight)
            {
                // 判断是否存在高光任务
                if (highlightManager.isTaskStartedFromPath(filePath)) {
                    // 任务进行中 → 显示"取消灵感高光分析"
                    operateModels.append({
                        "title": qsTr("pccut_home_highlight_cancel"),
                        "type": Instance.DEVICE_FILE_TYPE.DEVICE_FILE_CANCEL_HIGHLIGHT
                    });
                } else {
                    //已完成高光分析的情况下可以删除高光
                    if (highlightManager.hasMediaHighlightsFromPath(filePath)) {
                        operateModels.append({
                            "title": qsTr("pccut_home_highlight_cancel"),
                            "type": Instance.DEVICE_FILE_TYPE.DEVICE_FILE_DEL_HIGHLIGHT
                        });
                    } else {
                        //显示"灵感高光分析"
                        operateModels.append({
                            "title": qsTr("pccut_home_highlight_switch"),
                            "type": Instance.DEVICE_FILE_TYPE.DEVICE_FILE_INSPIRATION_HIGHLIGHT
                        });
                    }
                }
            }

            // 灵感粗剪菜单项（有后台任务或素材不合格则置灰）
            if (allFileInfoModel.aiRoughCutSupport) {
                var roughCutDisabled = allFileInfoModel.selectCount > 1
                    ? !allFileInfoModel.canAiRoughCut
                    : !allFileInfoModel.canAiRoughCutForFile(fileId);
                var roughCutTip = allFileInfoModel.selectCount > 1
                    ? allFileInfoModel.aiRoughCutDisableReason
                    : allFileInfoModel.aiRoughCutDisableReasonForFile(fileId);
                operateModels.append({
                    "title": qsTr("pccut_roughcut_title"),
                    "type": Instance.DEVICE_FILE_TYPE.DEVICE_FILE_ROUGH_CUT,
                    "disabled": roughCutDisabled,
                    "disabledTip": roughCutTip
                });
            }

            if (!isSelectHighlightTab) {
                // 功能开关 + 灰度 + 协议同意三重控制：未灰度或未同意协议时不显示上传入口
                if (cloudAlbumFeatureFlags.enable && CloudAlbumManager.grayCloudAlbumAvailable
                        && CloudAlbumManager.cloudAlbumAgreementAccepted) {
                    operateModels.append({"title": qsTr("pccut_cloud_album_upload_to"), "type": Instance.DEVICE_FILE_TYPE.DEVICE_FILE_UPLOAD_CLOUD_ALBUM});
                }
                operateModels.append({"title": qsTr("pccut_device_batch_delete"), "type": Instance.DEVICE_FILE_TYPE.DEVICE_FILE_REMOVE});
            } else {
                // 高光tab下显示删除选项
                operateModels.append({"title": qsTr("pccut_device_batch_delete"), "type": Instance.DEVICE_FILE_TYPE.DEVICE_FILE_DEL_HIGHLIGHT_ITEM});
            }

            fileOperatePopup.open();
        }
        sourceComponent: Component {
            OperatePopup {
                property string fileId: ""
                property string filePath: ""
                property string fileMd5: ""
                property int index: 0
                shaderSourceItem: control
                onClosed: {
                    fileOperatePopupLoader.active = false;
                }
                onClickType: (modeType) => {
                    // 防止 popup 有隐藏动效, 进而产生卡顿的感觉
                    background.visible = false;
                    contentItem.visible = false;
                    var fileList = [fileId];
                    // 下载后的文件路径
                    var copiedPath = allFileInfoModel.getCopiedPath(index);
                    if (modeType === Instance.DEVICE_FILE_TYPE.DEVICE_FILE_OPEN) {
                        // 循环录影（设备页和下载页均适用）：虚拟路径不存在于磁盘，取所有真实子文件路径；
                        // 普通文件 getRealPathsForId 返回 [path]，行为不变
                        var realPaths = allFileInfoModel.getRealPathsForId(fileId);
                        var pathsToOpen = realPaths.length > 0 ? realPaths : [filePath];
                        // Qt.callLater 推迟到信号处理器退出后执行，避免 SHOpenFolderAndSelectItems
                        // 抽取 Windows 消息队列导致 popup 被同步销毁引发崩溃
                        Qt.callLater(function() {
                            if (!fileOperator.openExplorerAtFiles(pathsToOpen)) {
                                toast.showToast(qsTr("pccut_media_file_noexists"));
                            }
                        });
                    } else if (modeType === Instance.DEVICE_FILE_TYPE.DEVICE_FILE_CREATE) {
                        // 循环录影（设备页和下载页均适用）：getProcessParamForId 返回包含循环素材信息的参数；
                        // processDeviceFileList 内部对设备路径自动检查本地已下载版本；

                        // yangxiao todo 循环录影合码遗留条件判断记录 需要review下
                        //if (isDownloadPage && !isSelectHighlightTab) {
                        //    fileList = [copyFileManager.pathFromId(fileId)];
                        //} else {
                        //    fileList = [allFileInfoModel.getEditorPath(fileId)];
                        //}

                        var param = allFileInfoModel.getProcessParamForId(fileId, isDownloadPage && !isSelectHighlightTab);
                        projectGenerator.processDeviceFileList([param],  allFileInfoModel.selectedHighlightIds(), "", isDownloadPage);
                    } else if(modeType === Instance.DEVICE_FILE_TYPE.DEVICE_FILE_DOWNLOAD) {
                            //*#*#*# 循环录影：getRealPathsForId 返回所有真实子文件路径；普通文件返回 [fileId]，行为不变
                            fileFolderLoader.fileList = allFileInfoModel.getRealPathsForId(fileId);
                            //*#*#*# 循环录影：传递 groupId 和虚拟路径（filePath 即 model.path，循环录影为虚拟路径）
                            var loopGid = allFileInfoModel.getGroupIdById(fileId);
                            if (loopGid !== "") {
                                fileFolderLoader.loopVideoGroupId = loopGid;
                                fileFolderLoader.loopVirtualPath  = filePath;
                                //*#*#*# 循环录影：MD5 从模型直接取，无需重新计算
                                fileFolderLoader.loopGroupMd5     = allFileInfoModel.getFileMd5ById(fileId);
                            }
                            fileFolderLoader.showFolder(true);
                    } else if(modeType === Instance.DEVICE_FILE_TYPE.DEVICE_FILE_REMOVE) {//删除文件
                        deviceRemovePopup.showPop(fileList);
                    } else if(modeType === Instance.DEVICE_FILE_TYPE.DEVICE_FILE_COPIED_OPEN) { //下载后在本地文件打开
                        //*#*#*# 循环录影：getAllCopiedSubPaths 返回所有已下载子文件路径；普通文件返回单路径列表
                        var copiedSubPaths = allFileInfoModel.getAllCopiedSubPaths(index);
                        Qt.callLater(function() {
                            if (copiedSubPaths.length === 0 || !fileOperator.openExplorerAtFiles(copiedSubPaths)) {
                                toast.showToast(qsTr("pccut_media_file_noexists"));
                            }
                        });
                    }
                    else if (modeType === Instance.DEVICE_FILE_TYPE.DEVICE_FILE_EXPORT_VIDEO) {
                        // 打开导出设置弹窗
                        fileOperatePopupLoader.controlRef.showExportDialog(
                            [allFileInfoModel.getFileId(index)],
                            allFileInfoModel
                        );
                    }
                    else if (modeType === Instance.DEVICE_FILE_TYPE.DEVICE_FILE_INSPIRATION_HIGHLIGHT) {
                        highlightManager.startTask(filePath);
                        highlightManager.eventTrackingStart("home");  // 高光分析埋点
                    }
                    else if (modeType === Instance.DEVICE_FILE_TYPE.DEVICE_FILE_CANCEL_HIGHLIGHT) {
                        highlightManager.cancelTaskFromPath(filePath);
                        highlightManager.eventTrackingCancel("home");  // 高光分析埋点
                    } else if (modeType === Instance.DEVICE_FILE_TYPE.DEVICE_FILE_DEL_HIGHLIGHT) {
                        highlightManager.removeMediaAllHighlightsFromPath(filePath);
                        highlightManager.eventTrackingCancel("home");  // 高光分析埋点
                    } else if (modeType === Instance.DEVICE_FILE_TYPE.DEVICE_FILE_DEL_HIGHLIGHT_ITEM) {
                        // 高光tab下删除高光片段（显示二次确认）
                        // 先重置选中，然后只选中当前文件
                        allFileInfoModel.resetSelectedAssets();
                        allFileInfoModel.appendSelectedAssetId([fileId]);
                        var highlightsMap = allFileInfoModel.getSelectedHighlightsMap();
                        highlightRemovePopupLoader.active = true;
                        highlightRemovePopupLoader.item.showPop(highlightsMap);
                    } else if (modeType === Instance.DEVICE_FILE_TYPE.DEVICE_FILE_UPLOAD_CLOUD_ALBUM) {
                        CloudAlbumTransferModel.addUpload([filePath], [fileMd5]);
                    }
                    else if (modeType === Instance.DEVICE_FILE_TYPE.DEVICE_FILE_ROUGH_CUT) {
                        allFileInfoModel.openRoughCutLoadingPanel()
                        allFileInfoModel.checkLoginBeforeRoughCutForFile(fileId);
                    }
                }

            }
        }
    }

}
