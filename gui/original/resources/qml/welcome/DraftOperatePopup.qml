import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls
import QtQuick.Dialogs
import Controls 1.0
import Config 1.0
import Qt5Compat.GraphicalEffects
import QtQuick.Layouts 1.3
import app_qrc 1.0

/**
 * @author robert.guo
 * @desc 素材列表右键点击弹框
 * @create_date 2024-04-18
 */
LightPopup {
    id: root
    // 当前选择的模式索引
    property int modeType: Instance.DRAFT_OPERATE_TYPE.TYPE_OF_NONE
    signal clickType(int modeType)
    Overlay.modal: Rectangle {
        color: Colors.transparent
    }
    width: Math.max(maxItemTextWidth + 16, 93)
    property real itemBgWidth: width - 8
    height: content.implicitHeight + 8

    property real maxItemTextWidth: 0
    // 高斯模糊背景
    background: Rectangle {
        color: Colors.transparent
        layer.enabled: true
        layer.effect: DropShadow {
            horizontalOffset: 0
            verticalOffset: 0
            radius: 50
            color: Colors.color_000000_40
        }

        LightClipRectangle {
            anchors.fill: parent
            radius: [8, 8, 8, 8]
            clip: true

            ShaderEffectSource {
                id: shaderSource
                sourceItem: stackLayout
                width: root.width
                height: root.height
                sourceRect: Qt.rect(root.x, root.y - 30,
                                    root.width, root.height)
                live: true
                smooth: true
            }

            // 高斯调节
            FastBlur {
                anchors.fill: parent
                source: shaderSource
                radius: 48
            }

            Rectangle {
                anchors.fill: parent
                color: Colors.color_141414_85
                radius: 8
                border.width: 1
                border.color: Colors.color_454649
            }
        }
    }

    contentItem: Item {
        ListModel {
            id: draftOperateModel
            ListElement {
                title: function () {
                    return qsTr("pccut_draft_rename");
                }
                type: Instance.DRAFT_OPERATE_TYPE.TYPE_OF_RENAME
            }
            ListElement {
                title: function () {
                    return qsTr("pccut_draft_copy");
                }
                type: Instance.DRAFT_OPERATE_TYPE.TYPE_OF_COPY
            }
            ListElement {
                title: function () {
                    return qsTr("pccut_draft_delete");
                }
                type: Instance.DRAFT_OPERATE_TYPE.TYPE_OF_DELETE
            }
            ListElement {
                title: function () {
                    return qsTr("pccut_draft_contents");
                }
                type: Instance.DRAFT_OPERATE_TYPE.TYPE_OF_PATH
            }
        }

        ColumnLayout {
            id: content
            anchors {
                top: parent.top
                left: parent.left
                topMargin: 4
                bottomMargin: 4
            }
            spacing: 4

            Repeater {
                model: draftOperateModel

                delegate: Rectangle {
                    Layout.preferredWidth: root.width - 8
                    Component.onCompleted: {
                        maxItemTextWidth = Math.max(maxItemTextWidth, filterText.width);
                    }
                    Layout.preferredHeight: 28
                    Layout.leftMargin: 4
                    Layout.rightMargin: 4
                    radius: 4
                    color: itemMouseArea.containsMouse ? ColorsConfig.color_37383A_4DFFC920 : Colors.color_transparent
                    Text {
                        id: filterText
                        text: model.title()
                        height: parent.height
                        font.pixelSize: 11
                        color: itemMouseArea.containsMouse ? ColorsConfig.color_EEEEEE_4DFFC9 : Colors.color_EEEEEE
                        leftPadding: 12
                        verticalAlignment: Text.AlignVCenter
                    }
                    MouseArea {
                        id: itemMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            modeType = model.type;
                            root.close();
                            clickType(modeType);
                        }
                    }
                }
            }
        }
    }
}
