import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.3
import Qt.labs.platform 1.1
import Config 1.0
import Controls 1.0
import Qt5Compat.GraphicalEffects
import FitDataItemModel 1.0
import app_qrc 1.0

/**
 * @author tengsen.zhang
 * @desc Fit数据列表项
 * @create_date 2024-10-15
 */
Item {
    id: control
    // 当前列表对应的文件信息
    property FitDataItemModel itemModel
    // listview当前选中的index
    property int currentIndex

    // 文件删除
    signal fileDelete(var path)

    // 选中fit
    signal itemClick(var path, var date)

    Rectangle {
        anchors.fill: parent
        color: itemMouseArea.containsMouse ? Colors.color_56575B : Colors.color_454649
        radius: 8
        clip: true
        RowLayout {
            anchors.fill: parent
            Rectangle {
                width: 40
                height: control.height
                color: Colors.color_transparent
                clip: true
                Image {
                    id: image
                    x: 16
                    y: 20.5
                    width: 16
                    height: 16
                    source: currentIndex == index ? "qrc:/app_qrc/icons/icon_radio_selected.svg" : "qrc:/icons/dashboard/icon_radio_unselected.svg"
                    sourceSize: Qt.size(16, 16)
                }
            }

            Rectangle {
                id: datacontrol
                Layout.fillWidth: true
                height: control.height
                color: Colors.color_transparent
                // 文件日期
                Text {
                    id: fileDate
                    y: 13.5
                    text: !CommonUtils.isNull(itemModel) ? itemModel.date : ""
                    color: Colors.color_EEEEEE
                    elide: Text.ElideMiddle
                    font.pixelSize: 12
                }
                // 文件名
                Text {
                    id: fileName
                    y: fileDate.y + fileDate.height + 2
                    width: datacontrol.width
                    text: !CommonUtils.isNull(itemModel) ? itemModel.fileName : ""
                    color: Colors.color_999999
                    elide: Text.ElideRight
                    font.pixelSize: 10
                }
            }

            Rectangle {
                width: 52
                height: control.height
                color: Colors.color_transparent
                clip: true
                Image {
                    id: deleteButton
                    x: 16
                    y: 20.5
                    width: 16
                    height: 16
                    visible: index != 0
                    source: "qrc:/icons/dashboard/icon_fit_delete.svg"
                    sourceSize: Qt.size(16, 16)
                    Accessible.role: Accessible.Button
                }
            }
        }
        // item的点击事件
        MouseArea {
            id: itemMouseArea
            width: parent.width
            height: parent.height
            hoverEnabled: true
            z: 0
            onClicked: {
                itemClick(itemModel.path, itemModel.date);
            }
        }
        // 删除按钮的点击事件
        MouseArea {
            id: deleteMouseArea
            width: deleteButton.width
            height: deleteButton.height
            x: deleteButton.x + deleteButton.parent.x
            y: deleteButton.y + deleteButton.parent.y
            z: 1
            onClicked: {
                fileDelete(itemModel.path);
            }
        }
    }
}
