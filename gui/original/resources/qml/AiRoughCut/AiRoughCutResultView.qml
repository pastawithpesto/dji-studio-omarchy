import QtQuick 2.15
import QtQuick.Controls
import Config 1.0
import Controls 1.0
import UIComponent

/**
 * 结果页：AI 素材解析完成确认（插入至尾部 / 新建草稿）
 */
Item {
    id: root

    property var context: null
    property var viewModel: null

    // 居中显示确认内容
    Item {
        anchors.centerIn: parent
        width: 192
        height: 112

        // 标题
        UIText {
            id: titleText
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            type: UITextType.Primary
            size: UIControlSize.L
            font.weight: Font.Medium
            text: qsTr("pccut_roughcut_result_title")
        }

        // 描述
        UIText {
            id: descText
            anchors.top: titleText.bottom
            anchors.topMargin: 8
            anchors.left: parent.left
            anchors.right: parent.right
            horizontalAlignment: Text.AlignHCenter
            type: UITextType.Secondary
            size: UIControlSize.M
            text: qsTr("pccut_roughcut_result_desc")
            wrapMode: Text.WordWrap
        }

        // 按钮行
        Row {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 16

            // 插入至尾部
            UIButton {
                type: UIButtonType.Light
                size: UIControlSize.L
                text: qsTr("pccut_roughcut_result_append")
                onClicked: viewModel.insertToTail()
            }

            // 新建草稿
            UIButton {
                type: UIButtonType.Brand
                size: UIControlSize.L
                text: qsTr("pccut_roughcut_result_new_draft")
                onClicked: viewModel.createNewDraft()
            }
        }
    }
}
