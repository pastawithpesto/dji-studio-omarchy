import QtQuick 2.15
import QtQuick.Controls
import Config 1.0
import QtQuick.Window 2.15
import QtQuick.Layouts 1.15
import "qrc:/qml/controller"

Item{
    id:root
    property string titleText
    property string contentText
    property bool selectEnable:true
    property var selectedItem
    property alias valueTextCom: valueText  // 暴露整个Text组件
    property int itemSpacing:12
    signal changeSelect(var itemType)
    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: root.top
        anchors.bottom: root.bottom
        spacing: itemSpacing  // 控制子项间距
        HoverableText {
            id: title
            verticalAlignment: Text.AlignVCenter
            Layout.preferredWidth: 51
            maximumLineCount: 2
            cursorChanged: false
            wrapMode: Text.WrapAnywhere
            color: Colors.color_CCCCCC
            font.pixelSize: 12
            text: titleText
        }
        SelectableText {
            id: valueText
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            enabled:selectEnable
            height: root.height
            text: contentText
            DropMenu {
                id: itemMenu
                width: parent.width
                onItemChecked: (canvasType) => {
                    changeSelect(canvasType)
                }
            }
            onMenuShown: {
                itemMenu.updateData(selectedItem);
                itemMenu.height = itemMenu.dataCount * (28 + 4) + 4; // 28->item 高  4->间隙
            }
        }
    }

    function setMenus(models){
        itemMenu.setModel(models)
    }

}
