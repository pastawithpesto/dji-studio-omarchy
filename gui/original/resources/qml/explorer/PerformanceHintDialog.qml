import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.15
import Controls 1.0
import Config 1.0
import Qt5Compat.GraphicalEffects
import app_qrc 1.0

LightPopup {
    id: performanceHintDialog
    parent: Overlay.overlay
    width: parent.width
    height: parent.height
    dim: false
    needTransparent: true
    contentItem: Rectangle {
        id: popContent
        color: Colors.color_80000000

        // 窗口背景色
        Rectangle {
            id: popBackground
            anchors.centerIn: parent
            width: 248
            // 不知道怎么写自适应，需求紧急，这个地方先写死
            height: title.height + content.height + close.height + 24 + 12 + 20 + 20
            radius: 8
            clip: true
            color: Colors.color_2F3032
            border.color: Colors.color_454649
            border.width: 1
            Text {
                id: title
                text: qsTr("pccut_performance_save_local_tips")
                color: Colors.color_EEEEEE
                font.pixelSize: 14
                anchors {
                    top: parent.top
                    topMargin: 24
                    horizontalCenter: parent.horizontalCenter
                }
            }

            Text {
                id: content
                text: qsTr("pccut_performance_save_local_tips_description")
                color: Colors.color_999999
                font.pixelSize: 11
                wrapMode: Text.WordWrap
                anchors {
                    top: title.bottom
                    left: parent.left
                    right: parent.right
                    topMargin: 12
                    leftMargin: 28
                    rightMargin: 28
                }
                horizontalAlignment: Text.AlignHCenter
            }

            IconTextButton {
                id: close
                anchors {
                    top: content.bottom
                    topMargin: 20
                    horizontalCenter: parent.horizontalCenter
                }
                alignment: Qt.AlignHCenter
                width: 88
                height: 28
                isTextOnly: true
                title: qsTr("pccut_performance_save_local_tips_ok")

                titleColorNormal: ColorsConfig.color_EEEEEE_000000
                backgroundColorNormal: ColorsConfig.color_brand
                backgroundColorPressed: ColorsConfig.color_F44C65_6DFFD3

                onCustomClicked: {
                    performanceHintDialog.close()
                }
            }
        }
    }
}
