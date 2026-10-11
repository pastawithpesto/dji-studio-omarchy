import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.3
import Config 1.0
import Controls 1.0
import Qt5Compat.GraphicalEffects
import QmlConstants 1.0
import app_qrc 1.0

Column {
    property bool isSelect: selectSubIdx >= 0
    property int selectSubIdx: -1
    property bool isExpanded: true
    property alias title: menuText.text
    property alias menuModel: menuModel
    property int showRedIndex: -1

    ListModel {
        id: menuModel
    }

    signal clickIndex(int index)
    // 子项每次点击均发出；clickIndex 仅在选中项变化时发出
    signal subItemClicked(int index)
    Rectangle {
        height: 28
        width: parent.width
        color: ColorsConfig.color_2F3032_transparent
        radius: 4
        // 鼠标点击事件处理
        MouseArea {
            id: mouseArea
            hoverEnabled: true
            anchors.fill: parent
            Loader {
                id: deviceBtnToolTipLoader
                active: mouseArea.containsMouse && menuText.implicitWidth > menuText.width
                sourceComponent: LightToolTip {
                    tip: title
                }
            }

            onClicked: {
                isExpanded = !isExpanded;
            }
        }

        Text {
            id: menuText
            font.pixelSize: 12
            color: isSelect ? ColorsConfig.color_brand : Colors.color_FFFFFF
            elide: Text.ElideRight
            wrapMode: Text.NoWrap
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.rightMargin: QmlConstants.isWhiteXtra() ? 12 : 28
            anchors.leftMargin: QmlConstants.isWhiteXtra() ? 18 : 12
            anchors.verticalCenter: parent.verticalCenter
        }
        Image {
            id: foldImage
            anchors {
                left: QmlConstants.isWhiteXtra() ? parent.left : undefined
                leftMargin: QmlConstants.isWhiteXtra() ? 0 : undefined
                right: QmlConstants.isWhiteXtra() ? undefined : parent.right
                rightMargin: QmlConstants.isWhiteXtra() ? undefined : 8
                verticalCenter: parent.verticalCenter
            }
            sourceSize: QmlConstants.isWhiteXtra() ? Qt.size(12, 12) : Qt.size(20, 20)
            source: "qrc:/app_qrc/icons/media_flod.svg"
            width: QmlConstants.isWhiteXtra() ? 12 : 20
            height: QmlConstants.isWhiteXtra() ? 12 : 20
            // 应用旋转变换
            transform: Rotation {
                // 设置旋转中心为图像的中心
                origin.x: foldImage.width / 2
                origin.y: foldImage.height / 2
                // 旋转角度（例如，90度）
                angle: isExpanded ? 0 : 180
            }
            ColorOverlay {
                anchors.fill: foldImage
                source: foldImage
                color: isSelect ? ColorsConfig.color_brand : Colors.color_FFFFFF
            }
        }
    }
      // 根据expanded属性决定是否显示子菜单
    Repeater {
        model: isExpanded ? menuModel : null
        delegate: Item {
            width: parent.width
            property bool isSubSelected: selectSubIdx === index
            height: 36
            Text {
                id: subMenuText
                text: Tools.getDeviceRealName(subName)
                font.pixelSize: 12
                color: isSubSelected ? ColorsConfig.color_brand : Colors.color_999999
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.leftMargin: QmlConstants.isWhiteXtra() ? 18 : 12
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 4
            }
            Rectangle {
                visible: showRedIndex === index
                width: 5
                height: 5
                radius: 2.5
                color: ColorsConfig.color_brand
                anchors.top: subMenuText.top
                anchors.topMargin: 3
                anchors.left: parent.left
                anchors.leftMargin: Math.min(subMenuText.width, subMenuText.implicitWidth) + 20
            }
            MouseArea {
                id: subMouseArea
                hoverEnabled: true
                anchors.fill: parent
                LightToolTip {
                    visible: subMouseArea.containsMouse && subMenuText.implicitWidth > subMenuText.width
                    tip: subName
                }
                onClicked: {
                    subItemClicked(index);
                    if (selectSubIdx === index) {
                        return;
                    }
                    clickIndex(index);
                }
            }
        }
    }
}
