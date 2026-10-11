import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Dialogs
import Controls 1.0
import Config 1.0
import Qt5Compat.GraphicalEffects
import QtQuick.Layouts 1.3
import QtQuick.Templates 2.12 as T

/**
 * @author fread.zhang
 * @desc 弹出的操作按钮
 * @create_date 2025-04-01
 */

LightPopup {
    id: popup
    signal clickType(int modeType)
    property alias listModel: listModel

    ListModel {
        id: listModel
    }

    width: maxItemTextWidth + 48
    height: 4 + 46 * listModel.count
    property real maxItemTextWidth: 0
    property real radiusValue: 8
    property var shaderSourceItem
    Overlay.modal: Rectangle {
        color: Colors.transparent
    }
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    parent: Window.contentItem

    onOpened: {
        globalSignal.enablePlayerViewGesture(false)  // 禁用全景手势
    }
    onClosed: {
        globalSignal.enablePlayerViewGesture(true)   // 启用全景手势
    }

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
            width: popup.width - 8
            height: parent.height
            spacing: 4
            x: 4
            model: listModel
            interactive: false
            anchors {
                top: parent.top
                topMargin: 4
            }
            delegate: Rectangle {
                width: parent.width
                height: 42
                color: itemMouseArea.containsMouse ? Colors.color_454649 : Colors.color_transparent
                radius: 4
                MouseArea {
                    id: itemMouseArea
                    hoverEnabled: true
                    anchors.fill: parent
                    onClicked: {
                        close();
                        clickType(model.type);
                    }
                }
                Image {
                    id: checkIcon
                    anchors {
                        left: parent.left
                        leftMargin: 8
                        verticalCenter: parent.verticalCenter
                    }
                    width: 16
                    height: 16
                    source: model.checked ? "qrc:/icons/adjustment/icon_compose_check.svg" : ""
                    sourceSize: Qt.size(16, 16)
                }
                Component.onCompleted: {
                    maxItemTextWidth = Math.max(maxItemTextWidth, subItemText.width);
                }
                Text {
                    id: itemText
                    text: model.title
                    font.pixelSize: 11
                    color: Colors.color_EEEEEE
                    x: 32
                    y: 6
                    verticalAlignment: Text.AlignVCenter
                    // 文字可能不清晰
                    antialiasing: true
                }
                Text {
                    id: subItemText
                    text: model.subTitle
                    font.pixelSize: 11
                    color: Colors.color_999999
                    x: 32
                    y: 21
                    verticalAlignment: Text.AlignVCenter
                    // 文字可能不清晰
                    antialiasing: true
                }
            }
        }
    }
}
