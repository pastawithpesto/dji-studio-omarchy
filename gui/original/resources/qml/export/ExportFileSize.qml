import QtQuick 2.15
import QtQuick.Controls
import Controls 1.0
import Config 1.0
import app_qrc 1.0

/**
 * @author: mark.zhu
 * @details 导出文件大小预估显示
 * @date: 2026-03-02
 */
Rectangle {
    id: root

    // 外部传入 MediaExportSettingsProtocol 实例 or 直接传入 estimatedFileSize
    property var viewModel: null
    property string estimatedFileSize: ""

    width: parent.width
    height: 33
    implicitHeight: 33
    color: Colors.color_transparent

    Text {
        id: fileSizeLabel
        anchors {
            left: parent.left
            top: parent.top
            right: parent.right
        }
        height: 13
        font.pixelSize: 9
        color: Colors.color_EEEEEE
        verticalAlignment: Text.AlignVCenter
        text: qsTr("pccut_export_size")
    }

    Text {
        id: estimateText
        anchors {
            left: parent.left
            top: fileSizeLabel.bottom
            topMargin: 2
        }
        height: 18
        font.pixelSize: 14
        color: Colors.color_EEEEEE
        verticalAlignment: Text.AlignVCenter
        text: viewModel ? viewModel.estimatedFileSize : estimatedFileSize
    }
}
