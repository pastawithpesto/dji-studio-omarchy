import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls
//import QtQuick.Controls.Styles 1.4
import QtQuick.Dialogs
import Controls 1.0
import Config 1.0
import AgencyManager 1.0
import Qt5Compat.GraphicalEffects
import QtQuick.Templates 2.12 as T
import MediaListViewModel 1.0
import app_qrc 1.0

import DeviceMediaCategory 1.0
import AlgBizHighLightModel 1.0
import HighLightThemeTabViewModel 1.0
import CloudAlbumManager 1.0

/**
 * @author robert.guo
 * @desc 素材列表右键点击弹框
 * @create_date 2024-04-18
 */
LightPopup {
    id: root
    /**
     * @desc 更新操作项
     *
     * @modeType 当前操作类型
     * @removeFileIndex 如果是移除/删除操作，则对应文件的索引，其他操作，暂无意义
     * @return 无
     */
    signal clickType(int modeType)
    // 是否是本地的素材列表(区分硬件)
    property var pageType

    property var mediaListViewModel: null
    property bool isSelectHighlightTab: root.mediaListViewModel ? root.mediaListViewModel.mediaCategoryType == DeviceMediaCategory.Highlight : false

    // 是否已下载
    property bool isDownload: false
    // 是否是收藏
    property bool isFavourite: false
    // 代理文件状态
    property int agencyFileState: -1
    // 媒体文件是否存在
    property bool mediaExist: true
    // 16K静止延时代理文件是否存在
    property bool agency16KTimelapseLost: false
    // 是否支持高光分析
    property bool isSupportHighlight: false

    property point showPoint: Qt.point(0, 0)
    
    width: Math.max(maxItemTextWidth + 34, 101)
    property real itemBgWidth: width - 8

    property real maxItemTextWidth: 0
    // 上下边距之和 + （item高度+ 上下padding之和）* 个数
    height: 4 + 32 * fileOperateModel.count

    property ListModel fileOperateModel: ListModel {}
    property real radiusValue: 8
    // 直接操作 fileOperateModel, 弹框的速度会变慢, 所先操作这个临时的 ListModel 会快一点
    readonly property ListModel tmpModels: ListModel {}

    T.Overlay.modal: Rectangle {
        color: Colors.transparent
    }

    function showPop() {
        tmpModels.clear();
        if (mediaExist) {
            let cancelValues = [AgencyManager.AGENCY_RESULT_AGENCY_EXISTS];
            // if (cancelValues.indexOf(agencyFileState) != -1) {
            //     tmpModels.append({
            //         title: qsTr("pccut_media_proxy_cancel"),
            //         type: Instance.FILE_OPERATE_TYPE.TYPE_OF_AGENCY_CLOSE
            //     });
            // }
            let useValues = [AgencyManager.AGENCY_RESULT_CAN_OPEN];
            if (useValues.indexOf(agencyFileState) != -1) {
                tmpModels.append({
                    title: qsTr("pccut_media_proxy_open"),
                    type: Instance.FILE_OPERATE_TYPE.TYPE_OF_AGENCY_OPEN,
                    disabled: false,
                    disabledTip: ""
                });
            }
            tmpModels.append({
                title: qsTr("pccut_records_folder"),
                type: Instance.FILE_OPERATE_TYPE.TYPE_OF_OPEN_FILE,
                disabled: false,
                disabledTip: ""
            });
            if(!agency16KTimelapseLost) {
                tmpModels.append({
                    title: isFavourite ? qsTr("pccut_media_unfavorite") : qsTr("pccut_media_filter_favorite"),
                    type: Instance.FILE_OPERATE_TYPE.TYPE_OF_FAVORITE
                });
            }
        } else {
            tmpModels.append({
                title: qsTr("pccut_files_missing_linkmedia"),
                type: Instance.FILE_OPERATE_TYPE.TYPE_OF_MEDIA_LINK,
                disabled: false,
                disabledTip: ""
            });
        }
        // lex，非高光页面显示灵感高光相关菜单（动态判断）
        if (!root.isSelectHighlightTab && root.isSupportHighlight && root.openPath) {
            // 判断是否存在高光任务
            if (highlightManager.isTaskStartedFromPath(root.openPath)) {
                // 任务进行中 → 显示"取消灵感高光"
                tmpModels.append({
                    title: qsTr("pccut_home_highlight_cancel"),
                    type: Instance.FILE_OPERATE_TYPE.TYPE_OF_MEDIA_CANCEL_HIGHLIGHT
                });
            } else {
                //已完成高光分析的情况下可以删除高光
                if (highlightManager.hasMediaHighlightsFromPath(root.openPath)) {
                    tmpModels.append({
                        title: qsTr("pccut_home_highlight_cancel"),
                        type: Instance.FILE_OPERATE_TYPE.TYPE_OF_MEDIA_DEL_HIGHLIGHT
                    });
                } else {
                    //显示"灵感高光"
                    tmpModels.append({
                        title: qsTr("pccut_home_highlight_name"),
                        type: Instance.FILE_OPERATE_TYPE.TYPE_OF_MEDIA_HIGHLIGHT
                    });
                }
            }
        }

        // 灵感粗剪菜单项（高光页/普通页均支持，素材不合格或有后台任务则置灰）
        if (root.mediaListViewModel && root.mediaListViewModel.aiRoughCutSupport && root.openPath) {
            tmpModels.append({
                title: qsTr("pccut_roughcut_title"),
                type: Instance.FILE_OPERATE_TYPE.TYPE_OF_MEDIA_ROUGH_CUT,
                disabled: !root.mediaListViewModel.canAiRoughCut,
                disabledTip: root.mediaListViewModel.aiRoughCutDisableReason
            });
            eventTracker.trackEvent("pccut_auto_edit_entrance_show", {"page_source": "timeline_right_click"})
        }

        //高光不支持移除
        if (!root.isSelectHighlightTab) {
            // 功能开关 + 灰度 + 协议同意三重控制：未灰度或未同意协议时不显示上传入口
            if (cloudAlbumFeatureFlags.enable && CloudAlbumManager.grayCloudAlbumAvailable
                    && CloudAlbumManager.cloudAlbumAgreementAccepted) {
                tmpModels.append({
                    title: qsTr("pccut_cloud_album_upload_to"),
                    objectName: "localMediaMenuUploadCloudAlbumItem",
                    type: Instance.FILE_OPERATE_TYPE.TYPE_OF_UPLOAD_CLOUD_ALBUM
                });
            }
            tmpModels.append({
                title: qsTr("pccut_media_remove"),
                type: Instance.FILE_OPERATE_TYPE.TYPE_OF_REMOVE_FILE_FROM_LIST
            });
        } else {
            // 高光tab下显示删除选项
            tmpModels.append({
                title: qsTr("pccut_device_batch_delete"),
                type: Instance.FILE_OPERATE_TYPE.TYPE_OF_DEL_HIGHLIGHT_ITEM
            });
        }

        if (pageType !== MediaListViewModel.PAGE_LOCAL) {
            tmpModels.clear();
            if (pageType === MediaListViewModel.PAGE_DEVICE) {
                tmpModels.append({
                    title: qsTr("pccut_device_camera_file_open"),
                    type: Instance.FILE_OPERATE_TYPE.TYPE_OF_OPEN_FILE,
                    disabled: false,
                    disabledTip: ""
                });
            } else {
                tmpModels.append({
                    title: qsTr("pccut_records_folder"),
                    type: Instance.FILE_OPERATE_TYPE.TYPE_OF_OPEN_FILE,
                    disabled: false,
                    disabledTip: ""
                });
            }

            if (!root.isSelectHighlightTab && root.isSupportHighlight && root.openPath) {
                // 判断是否存在高光任务
                if (highlightManager.isTaskStartedFromPath(root.openPath)) {
                    // 任务进行中 → 显示"取消灵感高光"
                    tmpModels.append({
                        title: qsTr("pccut_home_highlight_cancel"),
                        type: Instance.FILE_OPERATE_TYPE.TYPE_OF_MEDIA_CANCEL_HIGHLIGHT
                    });
                } else {
                    //已完成高光分析的情况下可以删除高光
                    if (highlightManager.hasMediaHighlightsFromPath(root.openPath)) {
                        tmpModels.append({
                            title: qsTr("pccut_home_highlight_cancel"),
                            type: Instance.FILE_OPERATE_TYPE.TYPE_OF_MEDIA_DEL_HIGHLIGHT
                        });
                    } else {
                        //显示"灵感高光"
                        tmpModels.append({
                            title: qsTr("pccut_home_highlight_name"),
                            type: Instance.FILE_OPERATE_TYPE.TYPE_OF_MEDIA_HIGHLIGHT
                        });
                    }
                }
            }

            // 灵感粗剪菜单项（设备页，素材不合格或有后台任务则置灰）
            if (root.mediaListViewModel && root.mediaListViewModel.aiRoughCutSupport && !root.isSelectHighlightTab && root.openPath
                && root.mediaListViewModel.selectPathSize >= 1) {
                tmpModels.append({
                    title: qsTr("pccut_roughcut_title"),
                    type: Instance.FILE_OPERATE_TYPE.TYPE_OF_MEDIA_ROUGH_CUT,
                    disabled: !root.mediaListViewModel.canAiRoughCut,
                    disabledTip: root.mediaListViewModel.aiRoughCutDisableReason
                });
                eventTracker.trackEvent("pccut_auto_edit_entrance_show", {"page_source": "timeline_right_click"})
            }

            // 功能开关 + 灰度 + 协议同意三重控制：未灰度或未同意协议时不显示上传入口
            if (cloudAlbumFeatureFlags.enable && CloudAlbumManager.grayCloudAlbumAvailable
                    && CloudAlbumManager.cloudAlbumAgreementAccepted) {
                tmpModels.append({
                    title: qsTr("pccut_cloud_album_upload_to"),
                    objectName: "localMediaMenuUploadCloudAlbumItem",
                    type: Instance.FILE_OPERATE_TYPE.TYPE_OF_UPLOAD_CLOUD_ALBUM
                });
            }
            tmpModels.append({
                title: qsTr("pccut_device_batch_delete"),
                type: Instance.FILE_OPERATE_TYPE.TYPE_OF_MEDIA_DEVICE_REMOVE
            });
            if (pageType === MediaListViewModel.PAGE_DEVICE) {
                if (isDownload) {
                    tmpModels.append({
                        title: qsTr("pccut_device_local_file_open"),
                        type: Instance.FILE_OPERATE_TYPE.TYPE_OF_MEDIA_DEVICE_COPIED_OPEN
                    });
                }
                if ((root.mediaListViewModel?.getNeedCopyFileList()?.length ?? 0) > 0) {
                    tmpModels.append({
                        title: qsTr("pccut_device_batch_download_local"),
                        type: Instance.FILE_OPERATE_TYPE.TYPE_OF_MEDIA_DEVICE_DOWNLOAD
                    });
                }
            }
        }
/*
        // DEBUG高光菜单
        tmpModels.append({
            title: "DEBUG：发起高光",
            type: Instance.FILE_OPERATE_TYPE.TYPE_OF_MEDIA_HIGHLIGHT
        });
        tmpModels.append({
            title: "DEBUG：取消高光",
            type: Instance.FILE_OPERATE_TYPE.TYPE_OF_MEDIA_DEL_HIGHLIGHT
        });
*/
        fileOperateModel = tmpModels;
        shaderSource.sourceRect = Qt.rect(showPoint.x, showPoint.y, width, height);
        open();
    }
    contentItem: LightClipRectangle {
        id: blurBg
        radius: [radiusValue, radiusValue, radiusValue, radiusValue]
        clip: true
        width: root.width
        height: root.height

        ShaderEffectSource {
            id: shaderSource
            sourceItem: mainPanel
            width: root.width
            height: root.height
            live: true
            smooth: true
        }

        // 高斯调节
        FastBlur {
            anchors.fill: parent
            source: shaderSource
            radius: 48
        }

        Rectangle {
            anchors.fill: parent
            border.color: Colors.color_444444
            border.width: 1
            color: Colors.color_141414_85
            radius: 8
        }

        ListView {
            width: parent.width - 8
            height: parent.height
            spacing: 4
            model: fileOperateModel
            anchors {
                top: parent.top
                topMargin: 4
            }

            delegate: MouseArea {
                id: itemMouseArea
                objectName: model.objectName || ""
                hoverEnabled: true
                property bool itemDisabled: model.disabled !== undefined ? model.disabled : false
                onClicked: {
                    if (itemDisabled) return;
                    clickType(model.type);
                    close();
                }
                width: root.width
                height: 28
                Component.onCompleted: {
                    maxItemTextWidth = Math.max(maxItemTextWidth, itemText.width);
                }
                Rectangle {
                    width: parent.width - 8
                    height: parent.height
                    radius: 4
                    color: itemMouseArea.itemDisabled ? Colors.color_transparent
                         : (itemMouseArea.containsMouse) ? ColorsConfig.color_FFFFFF15_4DFFC920 : Colors.color_transparent
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    id: itemText
                    text: model.title
                    height: parent.height
                    font.pixelSize: 11
                    color: itemMouseArea.itemDisabled ? Colors.color_68696D
                         : (itemMouseArea.containsMouse) ? ColorsConfig.color_EEEEEE_4DFFC9 : Colors.color_EEEEEE
                    leftPadding: 12
                    verticalAlignment: Text.AlignVCenter
                    // 文字可能不清晰
                    antialiasing: true
                }

                LightToolTip {
                    visible: itemMouseArea.itemDisabled && itemMouseArea.containsMouse
                    tip: (model.disabledTip !== undefined) ? model.disabledTip : ""
                }
            }
        }
    }
}
