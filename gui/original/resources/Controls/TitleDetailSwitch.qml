
/**
 *  @File        : TitleDetailSwitch.qml
 *  @Brief       : 自定义开关组件
 *  @Details     : 左上标题Text,左下描述Text,右侧switc
 *  @Author      : heikki.xia
 *  @Date        : 2025年01月09日16
 */

import Config 1.0
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QmlConstants 1.0

Item {
    id: titleDetailSwitch
    property alias text: titleText.text
    property alias description: descriptionText.text
    property alias switchChecked: switchControl.checked
    signal toggled(bool checked)

    width: parent.width - 56
    height: 54

    ColumnLayout {
        anchors.fill: parent
        spacing: 4

        Text {
            id: titleText
            Layout.fillWidth: true
            height: 16
            horizontalAlignment: Text.AlignLeft
            verticalAlignment: Text.AlignVCenter
            font.pixelSize: 12
            color: Colors.color_CCCCCC
        }

        Text {
            id: descriptionText
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignLeft
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.WordWrap
            font.pixelSize: 11
            color: Colors.color_666666
        }
    }

    LightBaseSwitch {
        id: switchControl
        anchors {
            right: parent.right
            verticalCenter: parent.verticalCenter
        }
        onToggled: titleDetailSwitch.toggled(checked)
    }
}
