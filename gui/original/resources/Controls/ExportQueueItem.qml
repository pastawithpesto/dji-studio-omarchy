import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.3
import Qt.labs.platform 1.1
import Config 1.0
import Controls 1.0
import ExportQueueItemModel 1.0
import Qt5Compat.GraphicalEffects
import ExportEventReport 1.0
import VideoConfig 1.0
import ExportDataManager 1.0

/**
 * @author robert.guo
 * @desc 导出通用列表项
 * @create_date 2024-04-23
 */
Rectangle {

    // 当前列表对应的文件信息
    property ExportQueueItemModel itemModel

    // item 点击事件 signal
    signal itemDidClickSignal(var draftPath, var outPath)

    // 文件删除signal
    signal fileDelete(var draftPath, bool isDelFile)

    signal hasOperation

    function getExportImageCover() {
        if(!CommonUtils.isNull(itemModel) && draftManager.isFileExist(itemModel.imagePath)) {
            if(itemModel.isMultiFragment()){
                return "qrc:/icons/export_multifragment_folder.png"
            }else{
                return "file:///" + itemModel.imagePath
            }
        }
        else {
            if (itemModel.coverLoadFailed) {
                // 来源封面缓存不可用时明确展示视频默认图，不能使用 editor_default_cover_art：
                // 后者是绿色音频封面，会误导为缓存复用了错误的素材类型。
                return "qrc:/app_qrc/metaType/welcome_device_item_video.svg"
            }
            // 分段导出，右键菜单入口，itemModel.imagePath不存在，这里获取用户选择的第一个视频片段封面
            if(itemModel.entrance() === 1){
                return "file:///" + draftManager.getSelectDraftCoverPath();
            }else{
                return translationHandler.isChineseLang() ? "qrc:/icons/export_item_cover_loading_cn.svg" : "qrc:/icons/export_item_cover_loading_en.svg"
            }
        }
    }
    color: !CommonUtils.isNull(itemModel) && itemModel.state === 1 ? Colors.color_1F2021 : Colors.transparent
    radius: 8

    Rectangle {
        anchors.fill: parent
        anchors.margins: 12
        color: Colors.transparent
        // 封面, 图片圆角
        LightClipRectangle {
            id: coverRoot
            radius: [8, 8, 8, 8]
            // 动态设置背景色：图标尺寸40时用黑色，否则用原始颜色
            //color: !CommonUtils.isNull(itemModel) && itemModel.state === 1 ? Colors.color_262728 : Colors.color_353738
            color: Colors.transparent

            anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
            }
            width: 56
            height: 56

            Image {
                id: listeItemMediaCover
                // 添加属性存储当前尺寸
                property int currentSize: coverRoot.width

                width: coverRoot.width
                height: coverRoot.height
                anchors.centerIn: parent
                source: getExportImageCover();
                fillMode: Image.PreserveAspectCrop
                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: listeItemMediaCover.width
                        height: listeItemMediaCover.height
                        radius: 4
                    }
                }

                Connections {
                    target: globalSignal
                    function onExportCoverUpdated() {
                        listeItemMediaCover.source = ""
                        listeItemMediaCover.source = getExportImageCover();
                        // 更新尺寸状态
                        listeItemMediaCover.currentSize = listeItemMediaCover.width
                    }
                }
            }
        }

        // 文件名
        Text {
            id: filename
            anchors {
                left: coverRoot.right
                leftMargin: 12
                right: parent.right
            }

            function getDisplayText() {
                var fullName = itemModel.outPath.split('/').pop().split('\\').pop();
                if (itemModel.isMultiFragment()) {
                    // 多片段导出时 outPath 是文件夹路径，无需去扩展名，直接拼接片段数
                    fullName = fullName + "(" + itemModel.getVecFragmentSize() + "clips)"
                }
                return fullName;
            }

            text: getDisplayText()

            //text: CommonUtils.isNull(itemModel) ? "" : itemModel.outPath.split('/').pop().split('\\').pop()
            color: isWaitting ? Colors.color_999999 : Colors.color_EEEEEE
            // maximumLineCount和elide同时设置后，elide将失效
            maximumLineCount: 2
            elide: isExporting ? Text.ElideMiddle : Text.ElideNone
            wrapMode: isExporting ? Text.NoWrap : Text.Wrap
            font.pixelSize: 12
            font.bold: true
            property bool isExporting: CommonUtils.isNull(itemModel) ? false : itemModel.state !== 2
            property bool isWaitting: CommonUtils.isNull(itemModel) ? false : (itemModel.state === -1 || itemModel.state === 0)
        }

        //点击取消提示弹窗
        ConfirmPopup {
            id: removePopup
            anchors.centerIn: Overlay.overlay
            title: qsTr("pccut_records_confirm_delete")
            leftButtonText: qsTr("pccut_draft_delete_popup_cancel")

            rightButtonText: qsTr("pccut_project_modify_yes")

            onRightButtonClicked: {
                if(itemModel.state != 3)
                {
                    reportExportCancalEvent();
                    //ExportEventReport.reportComposeFailed(ExportEventReport.ERROR_CODE_4001);//弃用
                }
                fileDelete(itemModel.draftPath, true);
            }
        }

        //导出进度条
        ExportProgressBar {
            height: 26
            visible: CommonUtils.isNull(itemModel) ? false : (itemModel.state === 0 || itemModel.state === 1 || itemModel.state === 3)
            isFail: itemModel.state === 3 ? true : false
            anchors.left: filename.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            progress: CommonUtils.isNull(itemModel) ? 0 : itemModel.progress
            error: itemModel.errorInfo
            z: 1
            isWaitting: CommonUtils.isNull(itemModel) ? false : itemModel.state === 0
            onCancelClicked: {
                hasOperation()
                // 在这里处理取消操作
                if (isWaitting) {
                    reportExportCancalEvent();
                    fileDelete(itemModel.draftPath, true);
                } else {
                    removePopup.open();
                }
            }
            onRetryClicked: {
                hasOperation()
                // 在这里处理重试操作
                if (isFail) {
                    itemDidClickSignal(itemModel.draftPath, itemModel.outPath);
                    isFail = false
                }
            }
        }

        // item的点击事件
        MouseArea {
            anchors.fill: parent
            z: 0
            onClicked: {
                hasOperation()
                itemDidClickSignal(itemModel.draftPath, itemModel.outPath);
            }
        }

        RowLayout {
            id: layout
            spacing: 0
            anchors {
                left: filename.left
                bottom: coverRoot.bottom
                right: parent.right
            }
            Image {
                Layout.alignment: Qt.AlignVCenter
                source: "qrc:/icons/icon_export_success.svg"
                sourceSize: Qt.size(12, 12)
                visible: CommonUtils.isNull(itemModel) ? false : itemModel.state === 2
            }

            Text {
                Layout.alignment: Qt.AlignVCenter
                text: CommonUtils.isNull(itemModel) ? "" : Tools.formatExportTime(itemModel.createTime)
                Layout.fillWidth: true
                color: Colors.color_999999
                font.pixelSize: 11
                visible: CommonUtils.isNull(itemModel) ? false : itemModel.state === 2
                Layout.leftMargin: 8
            }

            Image {
                Layout.alignment: Qt.AlignVCenter
                visible: CommonUtils.isNull(itemModel) ? false : itemModel.state === 2
                source: deleteArea.containsMouse ? "qrc:/icons/icon_export_task_delete_hover.svg" : "qrc:/icons/icon_export_task_delete.svg"
                sourceSize: Qt.size(16, 16)
                MouseArea {
                    id: deleteArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        hasOperation()
                        eventTracker.trackEvent("pccut_export_task_history_clear")
                        fileDelete(itemModel.draftPath, false);
                    }
                }
            }
            Image {
                Layout.alignment: Qt.AlignVCenter
                visible: CommonUtils.isNull(itemModel) ? false : itemModel.state === 2
                source: folderArea.containsMouse ? "qrc:/icons/export_medium_folder_hover.svg" : "qrc:/icons/export_medium_folder.svg"
                sourceSize: Qt.size(16, 16)
                Layout.leftMargin: 16
                MouseArea {
                    id: folderArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        hasOperation()
                        openExportFileFolder();
                        eventTracker.trackEvent("pccut_export_task_history_open")
                    }
                }
            }

            Image {
                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                visible: CommonUtils.isNull(itemModel) ? false : itemModel.state === -1
                source: deleteFailedArea.containsMouse ? "qrc:/icons/icon_export_task_delete_hover.svg" : "qrc:/icons/icon_export_task_delete.svg"
                sourceSize: Qt.size(16, 16)
                MouseArea {
                    id: deleteFailedArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        hasOperation()
                        fileDelete(itemModel.draftPath, true)
                    }
                }
            }
        }
    }

    /**
     * @desc 打开导出文件弹框
     * @return 无
     */
    function openExportFileFolder() {
        if(itemModel.isMultiFragment()){
            let isOpenSuccess = fileOperator.openExplorerAtFolder(itemModel.outPath);
            if (!isOpenSuccess) {
                toast.showToast(qsTr("pccut_media_file_noexists"));
            }
        }else{
            let isOpenSuccess = fileOperator.openExplorerAtFile(itemModel.outPath);
            if (!isOpenSuccess) {
                toast.showToast(qsTr("pccut_media_file_noexists"));
            }
        }
    }


    function reportExportCancalEvent()
    {
        let videoInfo = ExportDataManager.getDataContentByExportId(itemModel.exportId);
        if (!videoInfo || Object.keys(videoInfo).length === 0) {
            // 兼容旧数据：exportId 为空时，降级按输出路径查询
            videoInfo = ExportDataManager.getDataContentByOutputPath(itemModel.outPath);
        }
        let extend = "";
        if (!videoInfo || Object.keys(videoInfo).length === 0) {
            extend = "No Data Found";
            logger.w("[ExportEventReport]未获取到信息，导出取消");
        }
        const exportId = itemModel.exportId;
        const colorDepth = videoInfo.colorDepth;
        const denoise = videoInfo.denoise;
        const dolbyVision = videoInfo.dolbyVision;
        const videoType = videoInfo.export_media_type;
        const denoiseType = videoInfo.denoiseType;
        const exportType = videoInfo.exportType;
        const exportCnt = videoInfo.exportCnt;
        const dataMap = videoInfo.dataMap;
        const materialDataMap = videoInfo.materialDataMap;
        const resolutionMap = videoInfo.resolutionMap;
        const frameRateMap = videoInfo.frameRateMap;
        const bitrateMap = videoInfo.bitrateMap;
        let functionUsedList = videoInfo.function_used;
        let isRetry = videoInfo.is_retry;
        let isThumbSuccess =  videoInfo.is_thumb_success;
        const scopeType = videoInfo.scopeType;
        const outputPath = videoInfo.outputPath || "";
        const freeStorageSizeGB = outputPath ? fileOperator.tempBytesAvailableWithTimeout(outputPath) : -1.0;
        const superSlowModeCount = videoInfo.super_slow_mode_count;
        const superSlowModeSpeedValue = videoInfo.super_slow_mode_speed_value_list;
        // getTaskElapsedMs()/hasBlocked() 是 ComposeDraftManager 单例的全局状态，反映"当前正在导出的那一项"。
        // 只有被取消的就是当前正在导出项(state===1 Synthesizing)时，这些值才属于它；
        // 取消的是等待中的项时它从未运行过，耗时记 0、未卡顿，避免把别的导出/上次残留的数据张冠李戴。
        const isRunningItem = !CommonUtils.isNull(itemModel) && itemModel.state === 1;
        // duration 记录任务级 felt-time(用户真实感受到的耗时)：同一任务的多个分段串行导出期间，分段推进的
        // 间隙、以及卡顿等待都计入；重试时归零。取自 ComposeDraftManager.getTaskElapsedMs()。
        // 这里不上报合成速度(synthesis_spend)：当前导出埋点代码较混乱、各字段口径/意义不清晰，且神策侧无法
        // 新增属性、只能复用已有字段；任务级速度的分子(耗时)与分母(实际已渲染内容)在多片段/范围导出/重试下
        // 难以同时取准、又与片段级口径不一致。速度统一由底层片段级事件 pccut_export_fragment_cancel 准确上报。
        const taskElapsedMs = isRunningItem ? composeDraftManager.getTaskElapsedMs() : 0;
        const isBlocked = isRunningItem ? composeDraftManager.hasBlocked() : false;
        //删除数据；旧数据无 exportId 时跳过，不能安全地按路径删除
        if (exportId) {
            ExportDataManager.deleteDataByExportId(exportId);
        }

        if (!materialDataMap) {
            // 导出原片和高光时没有赋值
            // TODO
            return;
        }

        eventTracker.trackEvent("pccut_export_task_exporting_cancel",
                                { "task_id": exportId || "",
                                    "number_of_materials": materialDataMap["number_of_material"] || 0,       //视频片段总数 number
                                    "clip_duration": materialDataMap["duration"]|| 0,                    //原始素材时长
                                    "devices_name":materialDataMap["devices_name"] ||[],            //素材包含的硬件类型
                                    "media_type": materialDataMap["media_type"]|| [],   //媒体类型 list
                                    "is_pano": materialDataMap["is_pano"] || false,                             //是否包含全景素材
                                    "size":materialDataMap["size"]|| 0,                              //原视频大小
                                    "fps":materialDataMap["fps"]|| 0,                                //素材帧率
                                    "bitrate":materialDataMap["bitrate"]|| "",                        //素材码率
                                    "resolution":materialDataMap["resolution"]|| "",                  //素材分辨率
                                    "media_format":materialDataMap["media_format"]|| [],                //文件格式
                                    "file_format_list":materialDataMap["media_format"]|| [],            //文件格式 list
                                    "file_encode_format_list":materialDataMap["file_encode_format_list"]|| [],  //编码格式
                                    "file_color_mode_list":materialDataMap["file_color_mode_list"]|| [],        //色彩模式
                                    "is_device_material":(materialDataMap["is_device_material"] || false) ? 1 : 0,          //是否包含硬件素材
                                    "types_of_material":materialDataMap["types_of_material"] || "",       //素材类型
                                    "export_resolution": resolutionMap["name"] || "",                        //导出分辨率 string
                                    "export_frame_rate": frameRateMap["name"] || "",                         //导出帧率 string
                                    "export_frame_bitrate": bitrateMap["frameRate"] || 0,                    //导出码率 number
                                    "export_media_type": videoType || "",                               //导出作品方式
                                    "export_type": exportType || "",                                 //导出方式
                                    "export_cnt":exportCnt|| 0,                                         //导出段数
                                    "work_duration":dataMap["work_duration"] || 0,                   //输出作品时长
                                    "is_retry":isRetry || false,                                    //是否重试
                                    "function_used":functionUsedList || [],                          //已使用功能列表
                                    "playback_speed_list": dataMap["playback_speed"] || [],           //视频倍速 list
                                    "filter_list": dataMap["filter_slug_list"] || [],                 //滤镜slug list
                                    "movement_slug_list": dataMap["movement_slug_list"] || [],                 //运镜slug list
                                    "music_code_list": dataMap["music_code_list"] || [],              //音乐slug list
                                    "denoise_type": denoiseType || "",                                //降噪类型
                                    "is_open_proxy": dataMap["is_proxy"] || false,                       //是否代理模式 bool
                                    "is_open_10bit": colorDepth === 10,                                //是否开启10bit bool
                                    "is_open_hdr": dolbyVision || false,                                 //是否杜比导出
                                    "is_thumb_success": isThumbSuccess || false,                           //预览图是否加载成功
                                    "is_open_dashboard": dataMap["is_dashboard"] || false,               //是否开启仪表盘 bool
                                    "dashboard_source_list": dataMap["dashboard_source_list"] || [], //仪表盘素材源
                                    "sticker_slug": dataMap["sticker_slug"] || "",                    //仪表盘贴纸
                                    "dashboard_tab_list": dataMap["dashboard_tab_list"] || [],        //仪表盘场景
                                    "stitching_list": dataMap["stitching_list"] || [],                // 拼接类型
                                    "tracking_cnt": dataMap["tracking_cnt"] || 0,                     //视频所含追踪段数
                                    "tracking_duration": dataMap["tracking_duration"] || 0,           //视频所含追踪总时长
                                    "is_open_tone_enhancement": dataMap["is_tonalenhance"] || false,   //影调增强
                                    "reduce_color_jump_level": dataMap["reduce_color_jump_level"] || [],//去频闪强度
                                    "font_slug": dataMap["font_slug_list"] || [],                     // 字体slug list
                                    "scope_type": scopeType || "",                                       //导出范围
                                    "super_slow_mode_count": superSlowModeCount,
                                    "super_slow_mode_speed_value_list": superSlowModeSpeedValue,
                                    "free_storage_size": freeStorageSizeGB, //剩余磁盘空间（GB）
                                    "compose_file_size": videoInfo.compose_file_size !== undefined ? videoInfo.compose_file_size : -1, //预估导出文件大小（GB，-1=算不出）
                                    "duration": taskElapsedMs > 0 ? Math.round(taskElapsedMs / 1000) : 0,  //导出耗时(秒,任务级 felt-time)
                                    "laged_information": isBlocked ? "true" : "false", //复用字段:实际为是否卡住过(原 is_blocked,laged_information 是 STRING,用 "true"/"false" 承载)
                                    "extend":extend                                         //数据库获取数据，成功""，失败：No Data Found
                                });
    }


}
