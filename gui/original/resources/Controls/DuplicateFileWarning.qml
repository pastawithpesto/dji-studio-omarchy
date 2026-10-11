import QtQuick 2.15
import Config 1.0
import app_qrc 1.0

/**
 * @brief 文件名重复警告文字
 * @details 监听 fileName / savePath / fileNameSuffix 变化，防抖 300ms 后检查目标路径是否已存在，
 *          若存在则在输入框下方显示警告文字。
 *          height 为 0，不占用布局空间，文字溢出显示在父容器间距区域。
 */
Item {
    id: root

    property string savePath: ""
    property string fileName: ""
    property string fileNameSuffix: ""
    property bool checkEnabled: true

    height: 0
    clip: false

    property bool showWarning: false

    // 统一的重新检测入口：重置警告并启动防抖
    function recheckDuplicate() {
        root.showWarning = false
        if (!root.checkEnabled) {
            debounceTimer.stop()
            return
        }
        if (root.fileName.length > 0 && root.savePath.length > 0) {
            debounceTimer.restart()
        } else {
            debounceTimer.stop()
        }
    }

    onFileNameChanged: recheckDuplicate()
    onSavePathChanged: recheckDuplicate()
    onFileNameSuffixChanged: recheckDuplicate()
    onCheckEnabledChanged: recheckDuplicate()

    Timer {
        id: debounceTimer
        interval: 300
        repeat: false
        onTriggered: {
            if (root.fileName.length === 0 || root.savePath.length === 0) {
                root.showWarning = false
                return
            }
            var fullPath = root.savePath + "/" + root.fileName + root.fileNameSuffix
            root.showWarning = fileOperator.isExists(fullPath)
        }
    }

    Text {
        visible: root.showWarning
        x: 0
        y: 0
        height: 16
        font.pixelSize: 11
        font.weight: Font.Medium
        color: Colors.color_3392FF
        text: qsTr("pccut_export_still_export_name_tip")
        verticalAlignment: Text.AlignVCenter
    }
}
