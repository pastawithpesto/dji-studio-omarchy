import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.3
import Config 1.0
import Controls 1.0

ConfirmPopup {
    title: qsTr("pccut_device_batch_delete_material").arg(removeFileList.length)
    leftButtonText: qsTr("pccut_device_batch_delete_all_cancel")
    rightButtonText: qsTr("pccut_device_batch_delete_all_yes")
    signal showToast(string toastStr)
    signal beforeRemove()
    property var removeFileList: []
    // 是否是播放器点击删除
    property bool isPlayerRemove: false
    // 是否是下载页面的删除
    property bool isDownloadRemove: false
    // DeviceFileInfoModel 实例，用于展开循环录影虚拟路径到真实子文件路径
    property var fileInfoModel: null

    WaitingPopup {
        id: waitingPopup
        loadingText: ""
        // 添加计时器
        Timer {
            id: timeoutTimer
            interval: 1000
            onTriggered: {
                waitingPopup.close();
                removeFileListFunc();
            }
        }
        onOpened: timeoutTimer.start() // 弹窗打开时启动计时
        onClosed: timeoutTimer.stop()  // 弹窗关闭时停止计时
    }

    // 将 id 列表展开为真实文件路径列表
    // 设备页：循环录影展开为设备真实子文件路径，普通文件 realPaths[0] 等于 model._path
    // 下载页：循环录影展开为本地真实子文件路径，普通文件 realPaths[0] 等于 finderPath
    //        两种情况均可替代 copyFileManager.pathListFromIdList，且对循环录影有效
    function expandToRealPaths(idList) {
        var result = [];
        for (var i = 0; i < idList.length; i++) {
            var id = idList[i];
            var realPaths = fileInfoModel ? fileInfoModel.getRealPathsForId(id) : null;
            //*#*#*# 循环录影：播放器弹窗无 fileInfoModel，用 copyFileManager 补全虚拟路径对应的本地子文件路径
            if (isDownloadRemove && (!realPaths || realPaths.length === 0)) {
                var fallbackPaths = copyFileManager.copiedPathsForLoopVideo(id);
                if (fallbackPaths && fallbackPaths.length > 0) {
                    realPaths = fallbackPaths;
                }
            }
            if (realPaths && realPaths.length > 0) {
                for (var j = 0; j < realPaths.length; j++) {
                    result.push(realPaths[j]);
                }
            } else {
                var copiedPaths = copyFileManager.copiedPathsForLoopVideo(id);
                if (copiedPaths.length > 0) {
                    for (var k = 0; k < copiedPaths.length; k++) {
                        result.push(copiedPaths[k]);
                    }
                } else {
                    // 通过 copyFileManager 获取真实路径而非直接使用 UUID
                    var copiedPath = copyFileManager.copiedPathForDevicePath(id);
                    result.push(copiedPath !== "" ? copiedPath : id);
                }
            }
        }
        return result;
    }

    function showPop(fileList) {
        removeFileList = fileList;
        var pathList = fileList;
        var titleKey = "";
        if (isDownloadRemove) {
            // 循环录影：pathListFromIdList 对虚拟路径无效；expandToRealPaths 对普通文件和循环录影均适用
            pathList = expandToRealPaths(fileList);
            var isUsed = editorManager.isInEditorForFileList(pathList);
            if (isUsed) {
                titleKey = "pccut_device_batch_delete_all_local";
            } else {
                title = qsTr("pccut_home_highlight_delate_tip").arg(fileList.length);
                titleKey = ""; // 清空 titleKey，避免后续被覆盖
            }
        } else {
            // 循环录影：展开虚拟路径为真实子文件路径，确保编辑器检测能覆盖所有子文件
            pathList = expandToRealPaths(fileList);
            var isUsed = editorManager.isInEditorForFileList(pathList);
            if (isUsed) {
                titleKey = "pccut_device_batch_delete_all_material";
            } else {
                titleKey = "pccut_device_batch_delete_material";
            }
        }
        if (titleKey !== "") {
            title = qsTr(titleKey).arg(fileList.length);
        }
        open();
    }

    onLeftButtonClicked: {
    }

    function removeFileListFunc() {
        var resultList = [];
        var pathList = [];
        //*#*#*# 循环录影：部分子文件删除失败时的计数，避免与 errorCount（整组失败）重复计数
        var failedSubFileCount = 0;
        for (var i = 0; i < removeFileList.length; i++) {
            var id = removeFileList[i];
            var result = false;
            var realPaths = fileInfoModel ? fileInfoModel.getRealPathsForId(id) : null;
            //*#*#*# 循环录影：播放器弹窗无 fileInfoModel（未注入），此时 id 为虚拟路径，
            //*#*#*# 通过 copyFileManager 补全已下载子文件本地路径，保证 isLoopVideo 和 pathList 正确。
            if (isDownloadRemove && (!realPaths || realPaths.length === 0)) {
                var fallbackPaths = copyFileManager.copiedPathsForLoopVideo(id);
                if (fallbackPaths && fallbackPaths.length > 0) {
                    realPaths = fallbackPaths;
                }
            }
            var isLoopVideo = realPaths && realPaths.length > 1;
            if (isDownloadRemove) {
                if (isLoopVideo) {
                    // 下载页循环录影：通过 groupId 整组删除，返回值为删除失败的子文件数
                    var deleteFailedCount = copyFileManager.removeCopiedFileId(id);
                    if (deleteFailedCount >= 0) {
                        resultList.push(id);
                        for (var n = 0; n < realPaths.length; n++) {
                            pathList.push(realPaths[n]);
                        }
                        failedSubFileCount += deleteFailedCount;
                    }
                } else {
                    // 下载页普通文件
                    var fileRealPath = copyFileManager.pathFromId(id);
                    result = (copyFileManager.removeCopiedFileId(id) >= 0);
                    if (result) {
                        resultList.push(id);
                        pathList.push(fileRealPath);
                    }
                }
            } else {
                if (isLoopVideo) {
                    //*#*#*# 设备页循环录影：逐一追踪每个子文件删除结果
                    var successPaths = [];
                    var failedCount = 0;
                    for (var j = 0; j < realPaths.length; j++) {
                        if (USBDeviceDetector.removeFile(realPaths[j])) {
                            successPaths.push(realPaths[j]);
                        } else {
                            failedCount++;
                        }
                    }
                    if (successPaths.length > 0) {
                        // 有子文件被删除（全部或部分成功）：从模型移除该分组
                        // 分组已不完整，继续显示无意义；已删除子文件无法回滚
                        resultList.push(id);
                        for (var k = 0; k < successPaths.length; k++) {
                            pathList.push(successPaths[k]);
                        }
                        // 部分失败时记录子文件级失败数
                        // successPaths.length === 0 时整组失败，由 errorCount 计数，不在此重复计
                        failedSubFileCount += failedCount;
                    }
                } else {
                    // 设备页普通文件
                    result = USBDeviceDetector.removeFile(id);
                    if (result) {
                        resultList.push(id);
                        pathList.push(id);
                    }
                }
            }
        }
        
        var errorCount = removeFileList.length - resultList.length + failedSubFileCount;

        if (errorCount > 0) {
            var str = qsTr("pccut_device_batch_delete_fail").arg(errorCount)
            showToast(str);
        }
        globalSignal.deviceRemovedFileList(resultList, isDownloadRemove, pathList);
    }

    onRightButtonClicked: {
        beforeRemove();
        var pathList;
        // 先获取真实路径，通知编辑器释放文件句柄（Windows 上文件被占用无法删除）
        // expandToRealPaths 对设备页和下载页的普通文件及循环录影均适用
        pathList = expandToRealPaths(removeFileList);
        globalSignal.devicePrepareRemovedFileList(pathList);
        if (isPlayerRemove && CommonUtils.isWindows()) {
            globalSignal.playerRemoveFileList(removeFileList, isDownloadRemove);
            return;
        }
        if (CommonUtils.isWindows()) {
            waitingPopup.open();
        } else {
            removeFileListFunc();
        }
    }
}
