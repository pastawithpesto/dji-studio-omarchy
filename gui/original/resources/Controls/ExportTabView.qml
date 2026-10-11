import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.3
import Qt5Compat.GraphicalEffects
import Config 1.0
import ExportTabViewModel 1.0
import ExportDataManager 1.0
import app_qrc 1.0

/**
 * @author robert.guo
 * @desc 导出面板
 * @create_date 2024-04-23
 */
LightPopup{
    id: exportTabView
    width: 345
    height: 422
    scale: 0.5
    opacity: 0.5
    needTransparent:true
    property real xOffset: 0.0
    property real yOffset: 0.0
    property int transformAnimationDuration: 150

    signal customClosed
    signal hasOperation

    Overlay.modal: Rectangle {
        color: Colors.transparent
    }
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    property real exportCount: 0
    property bool showFinishImage: false
    // 暴露 ViewModel 供 TaskQueuePopup 共享
    property alias exportVM: exportTabViewModel
    // 导出类型索引，0对应导出队列， 1对应导出记录
    property int exportTypeIndex: 0
    property bool isOpen:false
    function changeTabIndex(){
        exportTabView.exportTypeIndex = 0;
    }

    function isEmptyTextVisible()
    {
        if(exportTabView.exportTypeIndex == 0)
        {
            return exportTabViewModel.exportListCount < 1;
        }
        else
        {
            return exportTabViewModel.exportSuccessListCount < 1;
        }
    }

    ExportTabViewModel {
        id: exportTabViewModel
    }

    // Connections {
    //     target: composeDraftManager
    //     // 保存 导出草稿 成功的信号（整段导出）
    //     function onSaveComposeDraftFileSuccessSignal(compose_draft_path, compose_first_source_path, compose_out_path, exportId, videoInfo, resolutionType, hasDeviceMaterial, draftId, composeSize, useCylinder, entrance, isMultiFragment, vecDraftPath, composeRange) {
    //         // 草稿保存成功后才将导出配置落库，避免验证失败或取消时产生孤儿记录。因为这个时候才会把导出记录添加到数据库中
    //         ExportDataManager.insertExportData(videoInfo, compose_out_path);
    //         // 添加到数据库
    //         exportTabViewModel.insertDataToDB(compose_draft_path, exportId, compose_out_path, compose_first_source_path, resolutionType, hasDeviceMaterial, draftId, composeSize, useCylinder, entrance, isMultiFragment, vecDraftPath, composeRange);
    //         // 开始导出
    //         exportTabViewModel.autoCompose(useCylinder);
    //     }
    // }

    Connections {
        target: projectExportEnvManager
        // 开始导出的信号
        // context 参数由 ProjectExportEnvManager 透传业务上下文（exportId/fragmentIndex 等），
        // 此处仅需刷新导出列表计数，故不使用该参数。
        function onExportStarted(compose_draft_path, taskId, exportPath, context) {
            exportCount = exportTabViewModel.exportListCountReal;
        }
        // 导出失败的信号
        function onExportError(compose_draft_path, taskId, exportPath, error_code, error_str, context) {
            let errorMsg = error_code != 0 ? error_code.toString() : error_str;
            // videoInfo 由 ProjectExportEnvManager 查询后写入 context["videoInfo"]，直接读取，无需查询 DB。
            // 若为空，说明 context 传递链异常或该路径本身无埋点数据，以 "No Data Found" 降级处理。
            let videoInfo = context["videoInfo"] || {};
            let extend = "";
            if (!videoInfo || Object.keys(videoInfo).length === 0) {
                extend = "No Data Found";
                logger.w("[ExportEventReport]未获取到信息，导出失败");
            }
            const exportId = context["exportId"];
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

            // 2.整合视频数据的埋点上报
            eventTracker.trackEvent("pccut_synthesis_result",
                                    {   "task_id": exportId || "",
                                        "session_id": context["session_id"] || 0,              //Vince QoS enrich 路由 key
                                        "number_of_materials": materialDataMap["number_of_material"] || 0,       //视频片段总数 number
                                        "clip_duration": materialDataMap["duration"]|| 0,                    //原始素材时长
                                        "devices_name":materialDataMap["devices_name"] || [],            //素材包含的硬件类型
                                        "media_type": materialDataMap["media_type"]|| [],                //媒体类型 list
                                        "is_pano": materialDataMap["is_pano"] || false,                             //是否包含全景素材
                                        "size":materialDataMap["size"]|| 0,                              //原视频大小
                                        "fps":materialDataMap["fps"]|| 0,                                //素材帧率
                                        "bitrate":materialDataMap["bitrate"]|| "",                        //素材码率
                                        "resolution":materialDataMap["resolution"]|| "",                  //素材分辨率
                                        "media_format":materialDataMap["media_format"]|| [],                //文件格式
                                        "file_format_list":materialDataMap["media_format"]|| [],              //文件格式 list
                                        "file_encode_format_list":materialDataMap["file_encode_format_list"]|| [],  //编码格式
                                        "file_color_mode_list":materialDataMap["file_color_mode_list"]|| [],        //色彩模式
                                        "is_device_material":(materialDataMap["is_device_material"] || false) ? 1 : 0,          //是否包含硬件素材
                                        "types_of_material":materialDataMap["types_of_material"] || "",       //素材类型
                                        "export_resolution": resolutionMap["name"] || "",                        //导出分辨率 string
                                        "export_frame_rate": frameRateMap["name"] || "",                         //导出帧率 string
                                        "export_frame_bitrate": bitrateMap["frameRate"] || 0,                   //导出码率 frameRate
                                        "export_media_type": videoType || "",                               //导出作品方式
                                        "export_type": exportType || "",                                 //导出方式
                                        "export_cnt":exportCnt|| 0,                                          //导出段数
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
                                        "is_open_tone_enhancement": dataMap["is_tonalenhance"] || false,  //影调增强
                                        "font_slug": dataMap["font_slug_list"] || [],                     // 字体slug list
                                        "reduce_color_jump_level": dataMap["reduce_color_jump_level"] || [],//去频闪强度
                                        "scope_type": scopeType || "",                                  //导出范围
                                        "super_slow_mode_count": superSlowModeCount,
                                        "super_slow_mode_speed_value_list": superSlowModeSpeedValue,
                                        "extend":extend,                                          //数据库获取数据，成功“”，失败：No Data Found
                                        "duration": 0,                                            //导出耗时
                                        "fail_reason": errorMsg,                                  //合成失败原因
                                        "is_success": false,                                       //是否合成成功
                                        "pixel": resolutionMap["name"] || "",                         //导出素材像素
                                        "synthesis_spend": 0.0,                                    //合成速度
                                        "is_save_success": false,                                 //是否保存成功
                                        "laged_information": composeDraftManager.hasBlocked() ? "true" : "false",           //复用字段:实际为是否卡住过(原 is_blocked,laged_information 是 STRING,用 "true"/"false" 承载)
                                        "free_storage_size": freeStorageSizeGB,               //剩余磁盘空间（GB）
                                        "compose_file_size": videoInfo.compose_file_size !== undefined ? videoInfo.compose_file_size : -1, //预估导出文件大小（GB，-1=算不出）
                                        "project_colorspace": materialDataMap["project_colorspace"]|| "", // 色彩空间
                                        "has_hdr_display": materialDataMap["has_hdr_display"]|| false, // 是否有hdr显示器
                                        "ai_roughcut_job_ids": videoInfo.ai_roughcut_job_ids || [],
                                        "is_localcube": dataMap["is_localcube"] || 0,                      //是否使用自定义LUT
                                    });;

            toast.showToast(qsTr("pccut_export_task_exporting_text_fail"));
            globalSignal.clickExportButton()
            exportTabView.hasOperation()
            // 修改该条记录的状态
            exportTabViewModel.updateSynthesizingToFail(compose_draft_path,error_str);
            // 开始下一个导出
            exportTabViewModel.autoCompose();
            exportCount = exportTabViewModel.exportListCountReal;
        }
        // 正在导出的信号
        function onExportProgress(compose_draft_path, taskId, exportPath, progress) {
            exportTabViewModel.updateProgress(compose_draft_path, progress * 360);
            exportCount = exportTabViewModel.exportListCountReal;
        }
        // 导出成功的信号
        function onExportFinished(compose_draft_path, taskId, exportPath, success, context) {
            if (!success) {
                // 失败/取消时也要更新 UI + DB 状态，否则 item 会卡在 Synthesizing。
                // ProjectExportEnvManager 失败时同时发 exportFinished(success=false) 和 exportError，
                // 但 exportError 的 C++ 回调只清 timer，不动状态机，所以收尾必须在这里做。
                exportTabViewModel.updateSynthesizingToFail(compose_draft_path, "");
                exportTabViewModel.autoCompose();
                exportCount = exportTabViewModel.exportListCountReal;
                return;
            }
            if (!success) {
                exportCount = exportTabViewModel.exportListCountReal;
                return;
            }
            let successCount = exportTabViewModel.exportSuccessListCount;
            // 将该条记录的状态由：正在合成-》合成成功
            exportTabViewModel.updateSynthesizingToSuccess(compose_draft_path, exportPath);
            // 开始下一个导出
            exportTabViewModel.autoCompose();
            exportCount = exportTabViewModel.exportListCountReal;

            logger.d("exportTabView exportCount=" + exportCount + ",successCount="+successCount+",exportTabViewModel.exportSuccessListCount="+exportTabViewModel.exportSuccessListCount);
            if (successCount < exportTabViewModel.exportSuccessListCount){
                showFinishImage = true;
                // 持久化导出红点标志（与 TaskQueueViewModel.checkExportHistory 保持一致）
                lightSetting.save("task_queue_new_export_history", true);
            }
        }
    }

    onOpened: {
        logger.d("exportTabView opened")
        if(!isOpen){
            isOpen = true
            loader.active = true
            globalSignal.addPopupQuantity()
        }
    }
    onClosed: {
        if(isOpen){
            globalSignal.reducePopupQuantity()
            isOpen = false
            customClosed()
        }
        if(exportTypeIndex === 1){
            showFinishImage = false;
        }
    }
    Component.onCompleted: {
        logger.d("exportTabView load completed")
    }

    enter: Transition {
        NumberAnimation { property: "scale"; from: 0.5; to: 1; duration: transformAnimationDuration }
        NumberAnimation { property: "opacity"; from: 0.5; to: 1; duration: transformAnimationDuration }
        NumberAnimation { property: "xOffset"; from: -15; to: 0; duration: transformAnimationDuration }
        NumberAnimation { property: "yOffset"; from: -18; to: 0; duration: transformAnimationDuration }
    }
    exit: Transition {
        NumberAnimation { property: "scale"; from: 1; to: 0.5; duration: transformAnimationDuration }
        NumberAnimation { property: "opacity"; from: 1; to: 0.5; duration: transformAnimationDuration }
        NumberAnimation { property: "xOffset"; from: 0; to: -15; duration: transformAnimationDuration }
        NumberAnimation { property: "yOffset"; from: 0; to: -18; duration: transformAnimationDuration }
    }

    transformOrigin: Item.TopRight

    contentItem: Loader {
        id: loader
        active: editorABConfig.asyncLoadComponent===false?true:false
        sourceComponent: Item {
        Component.onCompleted: {
            logger.d("exportTabView item load completed")
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                exportTabView.hasOperation()
            }
        }

        Rectangle {
            id: canvasRectangle
            width: parent.width
            height: parent.height - 10
            anchors.top: parent.top
            anchors.topMargin: 10
            clip: true
            radius: 8
            color: Colors.color_2F3032
            border {
                color: Colors.color_454649
                width: 1
            }
            layer.enabled: true
            layer.effect: DropShadow {
                horizontalOffset: 0
                verticalOffset: 0
                radius: 10
                spread: 0.3
                transparentBorder: true
                color: Colors.color_000000_30
            }

            // Tab Bar
            TabBar {
                id : tabBar
                width: parent.width - 24
                height: 20
                spacing: 32  // 设置间距
                anchors {
                    top: parent.top
                    topMargin: 24
                    left: parent.left
                    leftMargin: 24
                }
                background: Rectangle {
                    color: Colors.transparent
                }
                TabButton {
                    width: Math.min(title.implicitWidth, 132)
                    height: 20
                    checked: exportTabView.exportTypeIndex === 0
                    background: Rectangle {
                        color: Colors.transparent
                    }
                    HoverableText {
                        id: title
                        // 这是一个很奇怪的写法, 主要是因为发现,所有的乱码都出现在popup上, 所以在展示的时候再刷新一下
                        text: visible ? qsTr("pccut_exporting") : ""
                        font.pixelSize: 14
                        width: parent.width
                        verticalAlignment: Text.AlignVCenter
                        wrapMode: Text.NoWrap
                        maximumLineCount: 1
                        cursorChanged: false
                        color: parent.checked ? Colors.color_EEEEEE : Colors.color_999999
                        onClicked: {
                            hasOperation()
                            if(exportTypeIndex === 1){
                                showFinishImage = false
                            }

                            exportTabView.exportTypeIndex = 0
                            eventTracker.trackEvent("pccut_export_task_exporting_click")
                        }
                    }
                    onClicked: {
                        hasOperation()
                        if(exportTypeIndex === 1){
                            showFinishImage = false
                        }

                        exportTabView.exportTypeIndex = 0
                        eventTracker.trackEvent("pccut_export_task_exporting_click")
                    }
                }
                TabButton {
                    objectName: actionableItemName.exportButtonEntracne
                    width: Math.min(title2.implicitWidth, 132)
                    height: 20
                    checked: exportTabView.exportTypeIndex === 1
                    background: Rectangle {
                        color: Colors.transparent
                    }
                    HoverableText {
                        id: title2
                        text: visible ? qsTr("pccut_records") : ""
                        font.pixelSize: 14
                        width: parent.width
                        verticalAlignment: Text.AlignVCenter
                        wrapMode: Text.NoWrap
                        maximumLineCount: 1
                        cursorChanged: false
                        color: parent.checked ? Colors.color_EEEEEE : Colors.color_999999
                        onClicked: {
                            hasOperation()
                            exportTabView.exportTypeIndex = 1
                            showFinishImage = false
                            eventTracker.trackEvent("pccut_export_task_history_click")
                        }
                    }
                    Rectangle {
                        anchors{
                            left: title2.right
                        }
                        y: -1
                        width: 7
                        height: 7
                        radius: 5
                        color: ColorsConfig.color_brand
                        border.width: 0.5
                        border.color: Colors.color_353738
                        visible: showFinishImage
                    }
                    onClicked: {
                        hasOperation()
                        exportTabView.exportTypeIndex = 1
                        showFinishImage = false
                        eventTracker.trackEvent("pccut_export_task_history_click")
                    }
                }
            }


            Item {
                anchors.top: tabBar.bottom
                anchors.topMargin: 11
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                ListView {
                    id: list_view
                    clip: true
                    anchors.fill: parent
                    anchors.rightMargin: 4
                    anchors.leftMargin: 12
                    anchors.bottomMargin: 12
                    visible: exportTabView.exportTypeIndex == 0
                    spacing: 4
                    boundsBehavior: GridView.StopAtBounds
                    model: exportTabViewModel.exportList
                    ScrollBar.vertical: ScrollBar{
                        Component.onCompleted: {
                            contentItem.color = Colors.color_454649
                        }
                    }
                    delegate:ExportQueueItem {
                        itemModel: model.modelData
                        width: 317
                        height: 80
                        onHasOperation: {
                            exportTabView.hasOperation()
                        }

                        Connections {
                            function onItemDidClickSignal(draftPath, outPath) {
                                if (itemModel.state === 1) {
                                    return;
                                }
                                exportTabViewModel.handCompose(draftPath, outPath);
                            }
                            function onFileDelete(draftPath, isDelFile) {
                                exportTabViewModel.deleteByDraftPath(draftPath, isDelFile);
                            }
                        }
                    }
                    onContentYChanged: {
                        exportTabView.hasOperation()
                    }
                }

                ListView {
                    id: exportRecordTab
                    model: exportTabViewModel.exportSuccessList
                    anchors.fill: parent
                    anchors.rightMargin: 4
                    anchors.leftMargin: 12
                    anchors.bottomMargin: 52
                    visible: exportTabView.exportTypeIndex == 1
                    clip: true
                    spacing: 4
                    boundsBehavior: GridView.StopAtBounds
                    ScrollBar.vertical: ScrollBar{
                        Component.onCompleted: {
                            contentItem.color = Colors.color_454649;
                        }
                    }
                    delegate: ExportQueueItem {
                        itemModel: model.modelData
                        width: 317
                        height: 80
                        onHasOperation: {
                            exportTabView.hasOperation()
                        }
                        Connections {
                            function onFileDelete(draftPath, isDelFile) {
                                exportTabViewModel.deleteByDraftPath(draftPath, isDelFile);
                            }
                        }
                    }
                    onContentYChanged: {
                        exportTabView.hasOperation()
                    }
                }

                IconTextButton {
                    isTextOnly: true
                    width: 88 > title.width + 28 ? 88 : title.width + 28
                    height: 28
                    anchors {
                        bottom: parent.bottom
                        bottomMargin: 12
                        right: parent.right
                        rightMargin: 28
                    }
                    visible: exportTabView.exportTypeIndex == 1 && exportTabViewModel.exportSuccessListCount > 0
                    backgroundColorNormal: Colors.color_454649
                    backgroundColorPressed: Colors.color_56575B
                    usePreferredWidth: true

                    titleColorNormal: Colors.color_FFFFFF

                    title: visible ? qsTr("pccut_records_empty") : ""
                    onCustomClicked: {
                        exportTabView.hasOperation()
                        exportTabViewModel.clearExportSuccessList();
                        eventTracker.trackEvent("pccut_export_task_history_delete")
                    }
                }
            }

            Image {
                anchors {
                    bottom: tiptext.top
                    bottomMargin: 12
                    horizontalCenter: tiptext.horizontalCenter
                    horizontalCenterOffset: 4
                }

                visible: isEmptyTextVisible()
                source: "qrc:/icons/export_empty_image.svg"
            }
            Text {
                id: tiptext
                text: exportTabView.exportTypeIndex == 0 ? qsTr("pccut_exporting_none") : qsTr("pccut_records_none")
                width: 265
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                visible: isEmptyTextVisible()
                anchors.centerIn: parent
                anchors.verticalCenterOffset: 5
                height: 17
                color: Colors.color_454649
            }
        }
        Canvas {
            id: canvas
            width: parent.width
            height: 24
            anchors.top: parent.top
            onPaint: {
                var ctx = getContext("2d");
                // 设置颜色
                ctx.fillStyle = Colors.color_2F3032;
                ctx.strokeStyle = Colors.color_454649;
                // 开始绘制路径
                ctx.beginPath();
                ctx.moveTo(315, 0); // 顶点
                ctx.lineTo(297, 24); // 左下角
                ctx.lineTo(333, 24); // 右下角
                ctx.closePath();
                ctx.fill();

                // 绘制三角形的两条边
                ctx.beginPath();
                ctx.moveTo(315, 0); // 顶点
                ctx.lineTo(307, 10); // 左下角
                ctx.moveTo(315, 0); // 顶点
                ctx.lineTo(323, 10); // 右下角
                ctx.stroke();
            }
        }
    }
    }
}
