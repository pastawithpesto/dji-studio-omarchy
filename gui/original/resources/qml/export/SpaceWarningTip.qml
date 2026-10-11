import QtQuick 2.15
import Controls 1.0
import Config 1.0
import app_qrc 1.0

/**
 * @brief 磁盘空间不足警告提示（图标 + 文字）
 * @details 外部通过 spaceInsufficient / spaceLow 控制显隐
 */
Item {
    id: root

    property bool spaceInsufficient: false
    property bool spaceLow: false

    visible: root.spaceInsufficient || root.spaceLow
    implicitWidth: warningIcon.width + 4 + warningText.implicitWidth
    implicitHeight: 18

    Image {
        id: warningIcon
        anchors {
            left: parent.left
            verticalCenter: warningText.verticalCenter
        }
        source: "qrc:/icons/icon_space_warning.svg"
        sourceSize: Qt.size(12, 12)
        width: 12
        height: 12
    }

    Text {
        id: warningText
        anchors {
            left: warningIcon.right
            leftMargin: 4
            top: parent.top
        }
        height: 18
        font.pixelSize: 12
        font.weight: Font.Medium
        lineHeight: 16
        lineHeightMode: Text.FixedHeight
        color: Colors.color_3392FF
        verticalAlignment: Text.AlignVCenter
        text: qsTr("pccut_export_still_export_low_tip1")
    }
}
