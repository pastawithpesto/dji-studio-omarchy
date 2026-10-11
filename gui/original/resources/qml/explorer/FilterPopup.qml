import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls
import QtQuick.Dialogs
import Qt5Compat.GraphicalEffects
import Controls 1.0
import Config 1.0
import MediaListViewModel 1.0
import app_qrc 1.0

LightPopup {
    id: customLightPopup
    // 根据哪个字段筛选
    property int currentFilterType: 0
    // 点击根据哪个字段筛选
    signal clickFilterType(var filterType)
    width: Math.max(maxItemTextWidth + 34, 101)
    property real itemBgWidth: width - 8
    property alias filterModel: filterModel

    property real maxItemTextWidth: 0
    contentItem: LightClipRectangle {
        anchors.fill: parent
        clip: true
        radius: [8,8,8,8]

        ShaderEffectSource {
            id: shaderSource
            sourceItem: mainPanel
            sourceRect: Qt.rect(customLightPopup.x, customLightPopup.y, customLightPopup.width, customLightPopup.height)
            width: parent.width
            height: parent.height
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
            border.color: Colors.color_444444
            border.width: 0.5
            color: Colors.color_141414_85
            radius: 8
        }

        ListModel {
            id: filterModel
        }

        Item {
            id: topItem
            height: 4
        }

        Column {
            width: parent.width
            height: 128
            spacing: 4
            anchors {
                top: topItem.bottom
            }

            Repeater {
                model: filterModel
                anchors.fill: parent

                delegate: Rectangle {
                    id: filter
                    property bool isHovered: false
                    radius: 4
                    width: itemBgWidth
                    height: 28
                    color: filter.isHovered ? ColorsConfig.color_FFFFFF15_4DFFC920 : Colors.color_transparent
                    anchors.horizontalCenter: parent.horizontalCenter
                    Component.onCompleted: {
                        maxItemTextWidth = Math.max(maxItemTextWidth, filterText.width);
                    }
                    Image {
                        width: 16
                        height: 16
                        source: "qrc:/app_qrc/icons/icon_compose_check.svg"
                        anchors.verticalCenter: parent.verticalCenter
                        x: 8
                        visible: filterType === currentFilterType
                    }

                    Text {
                        id: filterText
                        text: model.title
                        height: parent.height
                        font.pixelSize: 11
                        color: (filter.isHovered ||filterType === currentFilterType) ? ColorsConfig.color_EEEEEE_4DFFC9 : Colors.color_EEEEEE
                        leftPadding: 30
                        verticalAlignment: Text.AlignVCenter
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: filter.isHovered = true;
                        onExited: filter.isHovered = false;
                        onClicked: {
                            close();
                            clickFilterType(filterType);
                        }
                    }
                }
            }
        }
    }
}
