import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.3
import Config 1.0
import Controls 1.0

/**
 * @desc 高光片段删除确认弹窗（通用组件，不依赖业务ViewModel）
 * @create_date 2026-04-21
 */
ConfirmPopup {
    id: highlightRemovePopup

    leftButtonText: qsTr("pccut_device_batch_delete_all_cancel")
    rightButtonText: qsTr("pccut_device_batch_delete_all_yes")

    signal showToast(string toastStr)

    property var highlightsToDelete: ({})  // QMap<fileMd5, QStringList> 要删除的高光数据

    /**
     * @brief 显示删除确认弹窗
     * @param highlightsMap QMap<QString, QStringList> - Key: fileMd5, Value: 高光ID列表
     */
    function showPop(highlightsMap) {
        if (!highlightsMap || Object.keys(highlightsMap).length === 0) {
            logger.e("HighlightRemovePopup: highlightsMap is empty");
            return;
        }

        highlightsToDelete = highlightsMap;

        // 计算总共要删除的高光数量
        var totalCount = 0;
        for (var fileMd5 in highlightsMap) {
            totalCount += highlightsMap[fileMd5].length;
        }

        if (totalCount <= 0) {
            return;
        }

        title = qsTr("pccut_home_highlight_delete");
        open();
    }

    onLeftButtonClicked: {
        // 取消删除，无操作
    }

    onRightButtonClicked: {
        removeHighlightListFunc();
    }

    function removeHighlightListFunc() {
        if (!highlightsToDelete || Object.keys(highlightsToDelete).length === 0) {
            logger.e("delete failed：data is empty");
            return;
        }

        try {
            // 直接调用批量删除接口
            highlightManager.batchRemoveMediaHighlights(highlightsToDelete);
        } catch (e) {
            logger.e("delete highlight fragment failed: " + e);
        }
    }
}
