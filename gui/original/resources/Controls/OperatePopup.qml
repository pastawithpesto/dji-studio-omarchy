import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Dialogs
import Controls 1.0
import Config 1.0
import Qt5Compat.GraphicalEffects
import QtQuick.Layouts 1.3
import QtQuick.Templates 2.12 as T
import app_qrc 1.0

/**
 * @author fread.zhang
 * @desc 弹出的操作按钮
 * @create_date 2025-04-01
 */

LightPopup {
    id: popup
    signal clickType(int modeType)
    property alias listModel: listModel
    property string itemObjectNamePrefix: ""

    ListModel {
        id: listModel
    }

    width: maxItemTextWidth + 16
    height: 4 + 32 * listModel.count
    property real maxItemTextWidth: 0
    property real radiusValue: 8
    property var shaderSourceItem
    Overlay.modal: Rectangle {
        color: Colors.transparent
    }
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    parent: Window.contentItem

    T.Overlay.modal: Rectangle {
        color: Colors.transparent
    }
    contentItem: LightClipRectangle {
        id: blurBg
        radius: [radiusValue, radiusValue, radiusValue, radiusValue]
        clip: true
        width: popup.width
        height: popup.height

        ShaderEffectSource {
            id: shaderSource
            width: popup.width
            height: popup.height
            sourceRect: Qt.rect(popup.x, popup.y, popup.width, popup.height);
            smooth: true
            live: true
            sourceItem: shaderSourceItem
        }

        // 高斯调节
        FastBlur {
            anchors.fill: parent
            source: shaderSource
            radius: 48
        }

        Rectangle {
            anchors.fill: parent
            border.color: Colors.color_444444
            border.width: 1
            color: Colors.color_141414_85
            radius: 8
        }

        ListView {
            width: parent.width - 8
            height: parent.height
            spacing: 4
            model: listModel
            interactive: false
            anchors {
                top: parent.top
                topMargin: 4
            }
            delegate: MouseArea {
                id: itemMouseArea
                objectName: model.objectName || (popup.itemObjectNamePrefix + model.type)
                hoverEnabled: true
                property bool itemDisabled: model.disabled !== undefined ? model.disabled : false
                onClicked: {
                    if (itemDisabled) return;
                    close();
                    clickType(model.type);
                }
                width: popup.width
                height: 28
                Component.onCompleted: {
                    maxItemTextWidth = Math.max(maxItemTextWidth, itemText.width);
                }
                Rectangle {
                    width: parent.width - 8
                    height: parent.height
                    radius: 4
                    color: itemMouseArea.itemDisabled ? Colors.color_transparent
                         : (itemMouseArea.containsMouse) ? ColorsConfig.color_FFFFFF15_4DFFC920 : Colors.color_transparent
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    id: itemText
                    text: model.title
                    height: parent.height
                    font.pixelSize: 11
                    color: itemMouseArea.itemDisabled ? Colors.color_68696D
                         : (itemMouseArea.containsMouse) ? ColorsConfig.color_EEEEEE_4DFFC9 : Colors.color_EEEEEE
                    leftPadding: 12
                    verticalAlignment: Text.AlignVCenter
                    // 文字可能不清晰
                    antialiasing: true
                }

                LightToolTip {
                    visible: itemMouseArea.itemDisabled && itemMouseArea.containsMouse
                    tip: (model.disabledTip !== undefined) ? model.disabledTip : ""
                }
            }
        }
    }
}
