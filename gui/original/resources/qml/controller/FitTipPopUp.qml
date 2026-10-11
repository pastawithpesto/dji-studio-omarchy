import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.3
import Qt5Compat.GraphicalEffects
import Config 1.0
import Controls 1.0

/**
 * @author tengsen.zhang
 * @desc 运动数据导入弹窗
 * @create_date 2024-10-16
 */
LightPopup{
    width: 303
    height: column.height
    modal: false
    contentItem: Item{
        Rectangle {
            id: contentRectangle
            width: parent.width
            height: parent.height
            radius: 8
            color: Colors.color_161616
            layer.enabled: true
            layer.effect: DropShadow {
                horizontalOffset: 0
                verticalOffset: 0
                radius: 10
                color: Colors.color_000000_50
            }
            border {
                color: Colors.color_454649
                width: 0.5
            }

            Column {
                id: column
                spacing: 0
                anchors {
                    left: parent.left
                    leftMargin: 16
                    right: parent.right
                    rightMargin: 16
                }
                Item {
                    height: 16
                    width: parent.width
                }
                Text {
                    horizontalAlignment: Text.AlignLeft
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: 12
                    color: Colors.color_FFFFFF
                    text: qsTr("pccut_dashboard_import")
                }
                Item {
                    height: 10
                    width: parent.width
                }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignLeft
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: 11
                    elide: Text.ElideRight
                    wrapMode: Text.Wrap
                    color: Colors.color_999999
                    text: qsTr("pccut_dashboard_import_description")
                }
                Item {
                    height: 8
                    width: parent.width
                }
                Image {
                    width: 24
                    height: 27
                    source: "qrc:/icons/dashboard/icon_fit_file.svg"
                    sourceSize: Qt.size(24, 27)
                }
                Item {
                    height: 24
                    width: parent.width
                }
                Text {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignLeft
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: 12
                        color: Colors.color_FFFFFF
                        text: qsTr("pccut_dashboard_import_how")
                }
                Item {
                    height: 12
                    width: parent.width
                }
                Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignLeft
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: 11
                        color: Colors.color_FFFFFF
                        text: qsTr("pccut_dashboard_import_methodone")
                }
                Item {
                    height: 8
                    width: parent.width
                }
                Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignLeft
                        verticalAlignment: Text.AlignVCenter
                        wrapMode: Text.WordWrap
                        font.pixelSize: 11
                        color: Colors.color_999999
                        text: qsTr("pccut_dashboard_import_methodone_description")
                }
                Item {
                    height: 12
                    width: parent.width
                }
                Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignLeft
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: 11
                        color: Colors.color_FFFFFF
                        text: qsTr("pccut_dashboard_import_methodtwo")
                }
                Item {
                    height: 8
                    width: parent.width
                }
                Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignLeft
                        verticalAlignment: Text.AlignVCenter
                        wrapMode: Text.WordWrap
                        font.pixelSize: 11
                        color: Colors.color_999999
                        text: qsTr("pccut_dashboard_import_methodtwo_description")
                    }
                Item {
                    height: 16
                    width: parent.width
                }
            }
        }
    }
}
