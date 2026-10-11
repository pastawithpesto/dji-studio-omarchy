import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.3
import Config 1.0
import Controls 1.0

ConfirmPopup {
    id: taskDeletePopup
    objectName: "taskQueueDeleteConfirmPopup"

    // deleteMode: 0=single(download), 1=clearAll(download), 2=batchRemove(download)
    //             3=activeExport,     4=clearAllExports,     5=batchExports
    //             6=clearActive（清空进行中的上传/下载任务，无 checkbox）
    property int deleteMode: 0

    title: deleteMode === 6
           ? qsTr("pccut_task_queue_clear_active_confirm")
           : qsTr("pccut_task_queue_delete_confirm_title")
    leftButtonText: qsTr("pccut_device_batch_delete_all_cancel")
    rightButtonText: qsTr("pccut_device_batch_delete_all_yes")
    leftButtonObjectName: "taskQueueDeleteConfirmCancelBtn"
    rightButtonObjectName: "taskQueueDeleteConfirmConfirmBtn"
    checkBoxObjectName: "taskQueueDeleteConfirmDeleteLocalFileCheckbox"

    // 下载队列信号
    signal confirmDeleteTask(string taskId, bool deleteFile)
    signal confirmClearAll(int transferType, bool deleteFiles)
    signal confirmBatchRemove(var taskIds, bool deleteFiles)

    // 导出队列信号
    signal confirmDeleteExport(string draftPath, bool deleteFile)
    signal confirmClearAllExports(bool deleteFiles)
    signal confirmBatchDeleteExports(var draftPaths, bool deleteFiles)

    // 清空活跃任务信号
    signal confirmClearActive()

    property string deleteTaskId: ""
    property int deleteTransferType: -1
    property var batchTaskIds: []
    property string deleteExportDraftPath: ""
    property var batchExportDraftPaths: []

    // 活跃任务取消时必须清理本地任务文件，不显示可选 checkbox。
    isCheckBoxVisible: deleteMode !== 3 && deleteMode !== 6
    isChecked: false

    checkBox.text: qsTr("pccut_task_queue_delete_local_file")

    // ===== 下载队列 =====
    function showForTask(taskId) {
        deleteTaskId = taskId;
        deleteMode = 0;
        isChecked = false;
        open();
    }

    function showForClearAll(transferType) {
        deleteTransferType = transferType;
        deleteMode = 1;
        isChecked = false;
        open();
    }

    function showForBatchRemove(taskIds) {
        batchTaskIds = taskIds;
        deleteMode = 2;
        isChecked = false;
        open();
    }

    // ===== 导出队列 =====
    function showForClearAllExports() {
        batchExportDraftPaths = [];
        deleteMode = 4;
        isChecked = false;
        open();
    }

    function showForBatchExports(draftPaths) {
        batchExportDraftPaths = draftPaths;
        deleteMode = 5;
        isChecked = false;
        open();
    }

    // ===== 活跃任务（上传/下载进行中）=====
    function showForClearActive() {
        deleteMode = 6;
        isChecked = false;
        open();
    }

    // 正在导出的任务必须真正取消，确认后固定删除未完成的本地文件。
    function showForActiveExportTask(draftPath) {
        deleteExportDraftPath = draftPath;
        deleteMode = 3;
        isChecked = false;
        open();
    }

    onLeftButtonClicked: {
    }

    onRightButtonClicked: {
        switch (deleteMode) {
        case 1:
            confirmClearAll(deleteTransferType, isChecked);
            break;
        case 2:
            confirmBatchRemove(batchTaskIds, isChecked);
            break;
        case 3:
            confirmDeleteExport(deleteExportDraftPath, true);
            break;
        case 4:
            confirmClearAllExports(isChecked);
            break;
        case 5:
            confirmBatchDeleteExports(batchExportDraftPaths, isChecked);
            break;
        case 6:
            confirmClearActive();
            break;
        default:
            confirmDeleteTask(deleteTaskId, isChecked);
            break;
        }
    }
}
