import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.3
import Config 1.0
import Controls 1.0
import Qt5Compat.GraphicalEffects
import app_qrc 1.0

/**
 * @author tengsen.zhang
 * @desc 导出队列重试按钮
 * @create_date 2024-10-08
 */
Button {
    id: iconTextButton
    width: 62
    height: 16
    background: Rectangle {
        color: Colors.color_transparent
    }

    contentItem: RowLayout {
        anchors.centerIn: parent
        anchors.fill: parent
        spacing: 2

        Image {
            source: "qrc:/app_qrc/icons/export_reset.svg"
            width: 16
            height: 16
            ColorOverlay {
                anchors.fill: parent
                source: parent
                color: iconTextButton.hovered ? ColorsConfig.color_F44C65_6DFFD3 : ColorsConfig.color_brand
            }
        }

        Text {
            text: qsTr("pccut_exporting_retry")
            font.pixelSize: 11
            color: iconTextButton.hovered ? ColorsConfig.color_F44C65_6DFFD3 : ColorsConfig.color_brand
        }
    }
}
