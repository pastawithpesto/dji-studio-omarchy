/**
 * @details 导出页缓存清理统一逻辑（应急 vs 常规），供三个导出弹窗共用，避免重复代码
 */

pragma Singleton
import QtQuick 2.15

QtObject {
    // 平台基数（参考 CommonUtils.base_file_number；单例内自包含，避免跨单例 import）
    function fileSizeBase() { return Qt.platform.os === "windows" ? 1024 : 1000; }

    // 常规清理：system + resource cleanAsync。tag 用于日志区分调用来源
    function autoCacheCleaner(tag) {
        logger.d(tag + " routine clean: system + resource cleanAsync");
        if (typeof systemCacheCleaner !== 'undefined')   systemCacheCleaner.cleanAsync();
        if (typeof resourceCacheCleaner !== 'undefined') resourceCacheCleaner.cleanAsync();
    }

    // 按保存路径判断是否需要应急清理（同盘 且 预测剩余 (可用-预估) < 应急阈值），命中则触发应急。
    // targets: [{path, estimatedMB}, ...]（单/双路径统一，内部按同盘过滤、聚合预留字节）。
    // 返回是否触发了应急，供调用方决定是否走常规清理兜底。tag/scene 仅用于日志区分。
    function tryEmergencyCleanForExport(targets, tag, scene) {
        if (typeof emergencyCacheCleaner === 'undefined') return false;
        var sameDrivePath = "";
        var reservedMB = 0;
        for (var i = 0; i < targets.length; ++i) {
            var p = targets[i].path;
            if (p && p.length > 0 && emergencyCacheCleaner.isOnBasePathDrive(p)) {
                if (sameDrivePath.length === 0) sameDrivePath = p;
                reservedMB += Math.max(0, targets[i].estimatedMB);
            }
        }
        if (sameDrivePath.length === 0) return false; // 无同盘导出，应急不适用
        var freeBytes = fileOperator.requestDriveFreeBytesSync(sameDrivePath, 100);
        var reservedBytes = reservedMB * Math.pow(fileSizeBase(), 2);
        var predictedRemainBytes = freeBytes - reservedBytes;
        var needEmergency = freeBytes >= 0
            && predictedRemainBytes < emergencyCacheCleaner.startThresholdBytes();
        logger.d(tag + " " + scene + " decide: path=" + sameDrivePath + " freeBytes=" + freeBytes
            + " reservedMB=" + reservedMB + " predictedRemainBytes=" + predictedRemainBytes
            + " threshold=" + emergencyCacheCleaner.startThresholdBytes()
            + " → " + (needEmergency ? "emergency" : "skip"));
        if (needEmergency) emergencyCacheCleaner.triggerForPath(sameDrivePath, reservedBytes);
        return needEmergency;
    }
}
