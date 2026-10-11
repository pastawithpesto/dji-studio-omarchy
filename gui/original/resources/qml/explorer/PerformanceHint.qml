import QtQuick 2.15
import Config 1.0

Item {
    property int lastShowTime: lightSetting.getReal("performance_hint_pop_time_in_seconds", 0)

    Connections {
        target: globalSignal

        function onMayShowPerformanceHint(filePath) {
            // 对windows和mac区分处理，因为windows暂时还没实现速度检测的功能，等windows实现后，两端逻辑再统一
            if (CommonUtils.isWindows()) {
                if (expired()) {
                    showDialog();
                }
            } else {
                if (expired() && USBDeviceDetector.mediaTransferIsSlow(filePath)) {
                    showDialog();
                }
            }
        }

        /*
        时机有改动，旧代码先不删除，后面完善需求后再说
        // 检测手动导入素材的场景
        function onImportSuccess(paths) {
            if (!expired()) {
                return;
            }
            // 检测是否有硬件素材
            for (const path of paths) {
                if (fileOperator.isExists(path) && fileOperator.isUsbDevicePath(path)) {
                    showDialog();
                    break;
                }
            }
        }

        // 检测从finder中右键打开硬件素材的场景
        function onDeviceItemImported(deviceName, target) {
            if (!expired()) {
                return;
            }
            showDialog();
        }
        */
    }

    /*
    时机有改动，旧代码先不删除，后面完善需求后再说
    Connections {
        target: USBDeviceDetector

        // 检测硬件连接的场景
        function onDeviceAttached(deviceName, holder) {
            if (!expired()) {
                return;
            }
            
            const projectName = editorManager.projectName;
            if (projectName !== null && projectName !== "") {
                showDialog();                
            }
        }
    }
    */

    property PerformanceHintDialog dialog: null
    function showDialog() {
        if (CommonUtils.isNull(dialog)) {
            dialog = Qt.createComponent("PerformanceHintDialog.qml").createObject(lightWindow)
        }
        if (!CommonUtils.isNull(dialog)) {
            dialog.open();
            lastShowTime = Date.now() / 1000;
            lightSetting.save("performance_hint_pop_time_in_seconds", lastShowTime);
        }
    }

    function expired() {
        const now = Date.now() / 1000;
        // 一天之内只更新一次
        if (now - lastShowTime < 1 * 24 * 60 * 60) {
            return false;
        }
        return true;
    }
}
