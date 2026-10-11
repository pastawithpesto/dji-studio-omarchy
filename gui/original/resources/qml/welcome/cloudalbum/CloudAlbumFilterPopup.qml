import QtQuick 2.15
import QtQuick.Controls
import Controls 1.0
import Config 1.0
import Qt5Compat.GraphicalEffects
import app_qrc 1.0

/**
 * 云相册筛选弹框
 * 带勾选标记的筛选菜单，选项：全部 / 视频 / 图片 / 收藏
 */
LightPopup {
    id: popup
    objectName: "cloudAlbumFilterPopup"

    // 当前选中的筛选类型
    property int currentFilterType: 0
    // 点击筛选项的信号
    signal clickFilterType(int filterType)

    // 筛选类型枚举
    enum FilterType {
        All,
        Video,
        Image,
        Favorite
    }

    property alias filterModel: filterModel

    width: 101
    height: 4 + 28 * filterModel.count + 4

    Overlay.modal: Rectangle {
        color: Colors.color_transparent
    }
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    contentItem: LightClipRectangle {
        anchors.fill: parent
        clip: true
        radius: [8, 8, 8, 8]

        Rectangle {
            anchors.fill: parent
            border.color: Colors.color_444444
            border.width: 0.5
            color: Colors.color_141414_85
            radius: 8
        }

        ListModel {
            id: filterModel
        }

        ListView {
            width: parent.width - 8
            height: parent.height
            spacing: 0
            model: filterModel
            interactive: false
            anchors {
                top: parent.top
                topMargin: 4
                horizontalCenter: parent.horizontalCenter
            }

            delegate: MouseArea {
                id: itemMouseArea
                objectName: model.objectName || ""
                hoverEnabled: true
                width: popup.width - 8
                height: 28

                onClicked: {
                    close();
                    popup.clickFilterType(model.filterType);
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 4
                    color: itemMouseArea.containsMouse ? ColorsConfig.color_FFFFFF15_4DFFC920 : Colors.color_transparent
                }

                // 勾号图标（固定位置，未选中时隐藏但占位）
                Image {
                    id: checkIcon
                    width: 16
                    height: 16
                    source: "qrc:/app_qrc/icons/icon_compose_check.svg"
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    visible: model.filterType === popup.currentFilterType
                }

                // 筛选项文字（居中对齐）
                Text {
                    id: filterText
                    text: model.title
                    height: parent.height
                    font.pixelSize: 11
                    color: (itemMouseArea.containsMouse || model.filterType === popup.currentFilterType)
                           ? ColorsConfig.color_EEEEEE_4DFFC9 : Colors.color_EEEEEE
                    anchors.horizontalCenter: parent.horizontalCenter
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    antialiasing: true
                }
            }
        }
    }
}
