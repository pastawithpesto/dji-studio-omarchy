import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.3
import DeviceFileInfoModel 1.0
import CloudAlbumTransferModel 1.0
import Controls 1.0
import UIComponent
import Config 1.0
import app_qrc 1.0
import DeviceMediaCategory 1.0
import DeviceMediaTypeCategory 1.0

import DeviceMediaCategoryViewModel 1.0
import DeviceMediaTypeCategoryViewModel 1.0
import HighLightThemeTabViewModel 1.0

import QtQuick.Dialogs
import Qt.labs.platform
import VideoConfig 1.0
import MediaTypeModel 1.0
import CloudAlbumManager 1.0

Item {
    id: deviceView

    property alias allFileInfoModel: devicePanel.allFileInfoModel
    property alias isDownloadPage: devicePanel.isDownloadPage

    // 🆕 暴露批量选择按钮，供 HomeView 访问
    property alias multipleSelectBtn: multipleSelectBtn
    
    // 🆕 暴露 devicePanel 引用，供删除/下载按钮访问数据
    property alias devicePanel: devicePanel
    property var isSelectedHighlightTab: allFileInfoModel.deviceMediaCategory.selectedEnumValue == DeviceMediaCategory.Highlight

    
    //设备页一级Tab(原片/高光/...)
    Item {
        id: mediaSourceTab
        anchors {
            top: parent.top
            topMargin: 40
            left: parent.left
            leftMargin: 40
        }
        
        width: deviceMediaCategory.implicitWidth
        height: deviceMediaCategory.implicitHeight

        // 高光功能开关
        visible: allFileInfoModel.isTabsViewVisible

        EnumTabsView {
            id: deviceMediaCategory
            anchors.fill: parent
            spacing: 24
            clip: false  // 注意不要裁掉高光红点
            tabHorizontalPadding: 0
            tabVerticalPadding: 0
            viewModel: allFileInfoModel ? allFileInfoModel.deviceMediaCategory : null
        }
    }

    //设备页二级Tab(原片：图片/视频，高光：高光主题)
    Item {
        id: mediaTypeTab
        anchors {
            top: mediaSourceTab.bottom
            topMargin: 24
            left: parent.left
            leftMargin: 40
        }

        height: 28
        implicitHeight: 28
        implicitWidth: deviceMediaCategory.implicitWidth

        // 控制整个二级Tab的可见性：
        // 1. 原片页面时显示（图片/视频切换）
        // 2. 高光页面且有高光素材时显示（高光主题切换）
        // 3. 高光页面且无高光素材时隐藏
        // 4. 高光功能开关
        visible: allFileInfoModel.isTabsViewVisible &&
                 (!deviceView.isSelectedHighlightTab || !allFileInfoModel.isHighlightMediaListEmpty)

        StackLayout {
            id: stackLayout
            currentIndex: deviceView.isSelectedHighlightTab ? 1 : 0

            EnumTabsView {
                id: originMediaType
                spacing: 12
                tabHorizontalPadding: 16
                tabVerticalPadding: 6
                minHeight: 28
                viewModel: allFileInfoModel ? allFileInfoModel.deviceMediaTypeCategory : null
            }

            EnumTabsView {
                id: highlightTheme
                spacing: 12
                tabHorizontalPadding: 16
                tabVerticalPadding: 6
                minHeight: 28
                viewModel: allFileInfoModel ? allFileInfoModel.highLightThemeTabViewModel : null
            }
        }
    }

    //设备素材
    Item {
        anchors {
            top: allFileInfoModel.isTabsViewVisible ? mediaTypeTab.bottom : parent.top
            topMargin: 20
            left: parent.left
            bottom: parent.bottom
            right: parent.right
        }

        DevicePanel {
            id: devicePanel
            anchors.fill: parent

            onResetMultipleSelectStatus: {
                deviceView.resetMultipleSelectBtn()
            }
        }
    }

    //右侧浮动按钮
    Item {
        anchors {
            top: parent.top
            topMargin: 36
            right: parent.right
            rightMargin: 40
        }

        height: 28
        RowLayout { 
            anchors {
                top: parent.top
                right: parent.right
            }

            height: parent.height
            layoutDirection: Qt.RightToLeft
            spacing: 24  // 调整间距以适应新按钮尺寸 (66x28)

            //批量选择
            IconTextButton {
                id: multipleSelectBtn
                height: 28
                implicitWidth: (isTextOnly ? 0 : imageRectWidth + internalSpacing) + textImplicitWidth + leftPadding + rightPadding
                usePreferredWidth: false
                visible: devicePanel.allFileInfoModel.displayMediaCount > 0
                // 根据状态切换文字和图标
                title: homeView.showSelectState
                    ? qsTr("pccut_device_batch_cancel")      // 取消选择
                    : qsTr("pccut_device_batch_selection")   // 批量选择
                titleColorNormal: Colors.color_EEEEEE
                imageRectWidth: 16
                imageRectHeight: 16

                // 仅在未选择状态显示图标，选择状态只显示文字
                iconPathNormal: homeView.showSelectState
                    ? ""  // 选中状态不显示图标
                    : "qrc:/app_qrc/icons/multiple_select.svg"
                isTextOnly: homeView.showSelectState  // 选中状态为纯文字模式
                backgroundColorNormal: Colors.color_button_background_normal
                backgroundColorHover: Colors.color_button_background_hovered  // 半透明白色 hover 效果
                internalSpacing: 4
                leftPadding: homeView.showSelectState ? 22 : 12
                rightPadding: homeView.showSelectState ? 22 : 12
                topPadding: 6
                bottomPadding: 6

                onCustomClicked: {
                    globalSignal.deviceClickMultipleSelectBtn()
                }
            }

            //上传云相册
            IconTextButton {
                id: uploadCloudBtn
                height: 28
                // 功能开关 + 灰度 + 协议同意三重控制：未灰度或未同意协议时不显示上传入口
                visible: cloudAlbumFeatureFlags.enable
                         && CloudAlbumManager.grayCloudAlbumAvailable
                         && CloudAlbumManager.cloudAlbumAgreementAccepted
                         && homeView.showSelectState

                enabled: devicePanel.allFileInfoModel.selectCount > 0

                title: qsTr("pccut_cloud_album_upload_to")
                titleColorNormal: enabled ? hovered ? Colors.color_FFFFFF : Colors.color_EEEEEE : Colors.color_444444
                iconPathNormal: "qrc:/icons/media_cloud_uploaded.svg"
                iconPathDisable: "qrc:/icons/media_cloud_uploaded_disabled.svg"
                iconPathHover: "qrc:/icons/media_cloud_uploaded_hover.svg"
                imageRectWidth: 16
                imageRectHeight: 16

                backgroundColorNormal: Colors.color_transparent
                backgroundColorHover: Colors.color_transparent
                internalSpacing: 4

                onCustomClicked: {
                    if (!enabled) return;
                    var paths = devicePanel.allFileInfoModel.selectedUploadPaths();
                    var md5s = devicePanel.allFileInfoModel.selectedUploadMd5s();
                    if (paths.length === 0) return;
                    CloudAlbumTransferModel.addUpload(paths, md5s);
                    globalSignal.deviceClickMultipleSelectBtn();
                }
            }

            //删除
            IconTextButton {
                id: removeBtn
                height: 28
                visible: homeView.showSelectState  // 仅批量选择模式显示

                // 状态控制（原片和高光都支持删除）
                enabled: devicePanel.allFileInfoModel.selectCount > 0

                title: qsTr("pccut_device_batch_delete")
                titleColorNormal: enabled ? hovered ? Colors.color_FFFFFF : Colors.color_EEEEEE : Colors.color_444444
                iconPathNormal: "qrc:/icons/multiple_delete.svg"
                iconPathDisable: "qrc:/icons/multiple_delete_disable.svg"
                iconPathHover: "qrc:/icons/multiple_delete_highlight.svg"
                imageRectWidth: 16
                imageRectHeight: 16

                backgroundColorNormal: Colors.color_transparent
                backgroundColorHover: Colors.color_transparent
                internalSpacing: 4

                // 根据tab类型调用不同的删除弹窗
                onCustomClicked: {
                    if (devicePanel.allFileInfoModel.selectCount < 1 || !enabled) {
                        return;
                    }
                    if (deviceView.isSelectedHighlightTab) {
                        // 高光tab：调用高光删除弹窗
                        var highlightsMap = devicePanel.allFileInfoModel.getSelectedHighlightsMap();
                        devicePanel.highlightRemovePopupLoader.active = true;
                        devicePanel.highlightRemovePopupLoader.item.showPop(highlightsMap);
                    } else {
                        // 原片tab：调用原片删除弹窗
                        devicePanel.deviceRemovePopup.showPop(devicePanel.allFileInfoModel.selectedPathList());
                    }
                }
            }

            //下载
            IconTextButton {
                id: downloadBtn
                height: 28
                visible: homeView.showSelectState  // 仅批量选择模式显示

                // 状态控制
                enabled: devicePanel.allFileInfoModel.needCopyCountInSelected > 0
                title: qsTr("pccut_device_batch_download")
                titleColorNormal: enabled ? hovered ? Colors.color_FFFFFF : Colors.color_EEEEEE : Colors.color_444444
                iconPathNormal: "qrc:/icons/multiple_need_download.svg"
                iconPathDisable: "qrc:/icons/multiple_need_download_disable.svg"
                iconPathHover: "qrc:/icons/multiple_need_download_highlight.svg"

                imageRectWidth: 16
                imageRectHeight: 16

                backgroundColorNormal: Colors.color_transparent
                backgroundColorHover: Colors.color_transparent
                internalSpacing: 4

                // 保持原有逻辑
                onCustomClicked: {
                    if (enabled === false) {
                        return;
                    }
                    if (devicePanel.allFileInfoModel.selectCount < 1) {
                        return;
                    }
                    var needCopyList = devicePanel.allFileInfoModel.getNeedCopyFileList();
                    if (needCopyList.length === 0) {
                        devicePanel.allFileInfoModel.resetSelectedAssets();
                        toast.showToast(qsTr("pccut_device_batch_download_save"));
                        return;
                    }
                    devicePanel.fileFolderLoader.fileList = needCopyList;
                    //*#*#*# 循环录影：批量下载必须设置 batchParams，否则循环录影虚拟路径走 copyFileList 导致下载失败
                    devicePanel.fileFolderLoader.batchParams = devicePanel.allFileInfoModel.getSelectedBatchDownloadParams();
                    devicePanel.fileFolderLoader.showFolder(true);
                }
            }
        }
    }

    function resetMultipleSelectBtn() {
        if (homeView.showSelectState) {
            globalSignal.deviceClickMultipleSelectBtn()
        }
    }

    Connections {
        target: allFileInfoModel.deviceMediaTypeCategory
        function onSelectedEnumValueChanged() {
            resetMultipleSelectBtn()
        }
    }

    Connections {
        target: allFileInfoModel.deviceMediaCategory
        function onSelectedEnumValueChanged() {
            resetMultipleSelectBtn()
            if (allFileInfoModel.isShowRedDot && allFileInfoModel.deviceMediaCategory.selectedEnumValue == DeviceMediaCategory.Highlight) {
                allFileInfoModel.isShowRedDot = false
            }
        }
    }

    Connections {
        target: allFileInfoModel.highLightThemeTabViewModel
        function onSelectedEnumValueChanged() {
            resetMultipleSelectBtn()
        }
    }
}
