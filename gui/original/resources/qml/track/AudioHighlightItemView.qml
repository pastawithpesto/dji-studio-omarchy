/**
* @author: albert.lbrayim
* @details:  视频语音高光标记
* @date: 2026-01-08 11:05:52
*/

import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.15
import Qt5Compat.GraphicalEffects
import QtQuick.Window 2.15
import Config 1.0
import Controls 1.0

Item {
    id: root

    required property double xPos
    required property double nWidth
    required property double type

    signal highlightItemClicked()

    // 获取语音高光图标
    function highlightIcon(type)
    {
        if (type === 1)
            return "qrc:/app_qrc/icons/audio_highlight_speaking.svg"
        if (type === 2)
            return "qrc:/app_qrc/icons/audio_highlight_shouting.svg"
        if (type === 3)
            return "qrc:/app_qrc/icons/audio_highlight_laughing.svg"
        return "qrc:/app_qrc/icons/audio_highlight_noise.svg"
    }

    // 获取语音高光提示
    function highlightTips(type)
    {
        if (type === 1)
            return qsTr("pccut_voice_tag_speech")
        if (type === 2)
            return qsTr("pccut_voice_tag_shout")
        if (type === 3)
            return qsTr("pccut_voice_tag_laughter")
        return qsTr("pccut_voice_tag_noise") // 噪声类型为 0
    }

    Rectangle {

        x : xPos
        visible: true
        width: nWidth
        height: 16
        color: mouseArea.containsMouse ? Colors.color_9EC0F2_60 : Colors.color_9EC0F2_50

        property string imagePath : highlightIcon(type)
        property string tipText: highlightTips(type)

        // 底部边框
        Rectangle {
            width: parent.width
            height: 1                           // 边框粗细
            color: Colors.color_FFFFFF          // 边框颜色
            anchors.bottom: parent.bottom
        }

        Image {
            visible: parent.width > 10
            width: 12
            height: 12
            source: parent.imagePath
        }

        Loader {
            id: toolTipLoader
            active: mouseArea.containsMouse
            anchors.top: parent.bottom
            visible: mouseArea.containsMouse

            // 加载后x坐标跟着鼠标移动而变
            x: mouseArea.mouseX

            sourceComponent: LightToolTip {}

            onVisibleChanged : {

                // this.x = mouseHover.point.position.x // 加载后x坐标不变
                if (visible) {

                    item.tip = parent.tipText
                    item.visible = true
                }
            }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onPressed: (mouse) => {
                root.highlightItemClicked()
                // 将非点击的按下事件传递给父层级，避免阻断拖拽
                mouse.accepted = false
            }
        }

    }
}
