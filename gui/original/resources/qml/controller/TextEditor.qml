import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.3
import LightRectangle 1.0
import Config 1.0
import Controls 1.0
import QmlConstants 1.0
import Qt5Compat.GraphicalEffects

/**
 * @author hongbin.shi
 * @desc 文本片段内容编辑控件
 * @create_date 2025-12-10
 */

Rectangle {
    id: container
    height: 82
    color: Colors.color_19191A
    radius: 4
    // 使用Qt的双向绑定机制，避免内部循环更新
    property alias textContent: contentArea.text

    Rectangle {
        id: textContentRectangle
        width: parent.width
        height: 61
        color: Colors.color_transparent
        radius: 4
        anchors{
            left: container.left
            top: container.top
        }

        ScrollView {
            anchors.fill: parent
            TextArea {
                id: contentArea
                text: ""
                wrapMode: TextEdit.WrapAtWordBoundaryOrAnywhere //TextArea.Wrap
                selectByMouse: true
                topPadding: 4
                leftPadding: 8
                rightPadding: 8
                bottomPadding: 1
                // 选中文本样式
                color: Colors.color_EEEEEE
                selectionColor: Colors.color_EEEEEE
                selectedTextColor: Colors.color_1F2021
                font.pixelSize: 12
           }

        }
    }

    Rectangle {
        id: textContentClear
        width: parent.width;
        height: 20
        color: Colors.color_19191A
        radius: 4
        anchors{
            right: container.right; rightMargin: 8
            top: textContentRectangle.bottom; topMargin: 0
        }

        Text {
            id: defaultTextLabel
            text: qsTr("pccut_word_edit_clear")
            font.pixelSize: 12
            anchors.right: parent.right
            anchors.top: parent.top
            color: Colors.color_666666
        }

        MouseArea {
            anchors.fill: defaultTextLabel
            onClicked: {
                contentArea.clear()
            }
        }
    }

}

