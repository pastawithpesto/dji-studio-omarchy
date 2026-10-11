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
    // 根据哪个字段排序
    property int currentOrderType: 0
    // 是否是升序
    property bool currentIsASC: false
    property bool isLocal: false
    // 点击是否是升序
    signal clickASC(var isASC)
    // 点击根据哪个字段排序
    signal clickOrderType(var orderType)
    width: Math.max(sortGroup.maxItemTextWidth + 34, 101)
    property real itemBgWidth: width - 8

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
            id: sortmModel
            ListElement {
                orderType: MediaListViewModel.ORDER_TYPE_IMPORT
                title: qsTr("pccut_media_dateimported")
            }
            ListElement {
                orderType: MediaListViewModel.ORDER_TYPE_CREATE
                title: qsTr("pccut_media_datecreated")
            }
            ListElement {
                orderType: MediaListViewModel.ORDER_TYPE_EDIT
                title: qsTr("pccut_media_modification")
            }
            ListElement {
                orderType: MediaListViewModel.ORDER_TYPE_TYPE
                title: qsTr("pccut_media_flletype")
            }
            ListElement {
                orderType: MediaListViewModel.ORDER_TYPE_SIZE
                title: qsTr("pccut_media_info_size")
            }
            ListElement {
                orderType: MediaListViewModel.ORDER_TYPE_NAME
                title: qsTr("pccut_task_queue_col_filename")
            }
        }

        ListModel {
            id: deviceSortmModel
            ListElement {
                orderType: MediaListViewModel.ORDER_TYPE_CREATE
                title: qsTr("pccut_media_datecreated")
            }
            ListElement {
                orderType: MediaListViewModel.ORDER_TYPE_EDIT
                title: qsTr("pccut_media_modification")
            }
            ListElement {
                orderType: MediaListViewModel.ORDER_TYPE_TYPE
                title: qsTr("pccut_media_flletype")
            }
            ListElement {
                orderType: MediaListViewModel.ORDER_TYPE_SIZE
                title: qsTr("pccut_media_info_size")
            }
            ListElement {
                orderType: MediaListViewModel.ORDER_TYPE_NAME
                title: qsTr("pccut_task_queue_col_filename")
            }
        }

        Item {
            id: topItem
            height: 4
        }

        Column {
            id: sortGroup
            property real maxItemTextWidth: 0
            width: parent.width
            spacing: 4
            anchors {
                top: topItem.bottom
            }

            Repeater {
                id: sortRepeater
                model: isLocal ? sortmModel : deviceSortmModel
                anchors.fill: parent

                delegate: Rectangle {
                    id: sort
                    property bool isHovered: false
                    radius: 4
                    width: itemBgWidth
                    height: 28
                    color: sort.isHovered ? ColorsConfig.color_FFFFFF15_4DFFC920 : Colors.color_transparent
                    anchors.horizontalCenter: parent.horizontalCenter

                    Image {
                        width: 16
                        height: 16
                        source: "qrc:/app_qrc/icons/icon_compose_check.svg"
                        anchors.verticalCenter: parent.verticalCenter
                        x: 8
                        visible: orderType === currentOrderType
                    }

                    Text {
                        id: textLabel
                        text: model.title
                        height: parent.height
                        font.pixelSize: 11
                        color: (orderType === currentOrderType || sort.isHovered) ? ColorsConfig.color_EEEEEE_4DFFC9 : Colors.color_EEEEEE
                        leftPadding: 30
                        verticalAlignment: Text.AlignVCenter
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: sort.isHovered = true
                        onExited: sort.isHovered = false
                        onClicked: {
                            close();
                            clickOrderType(orderType);
                        }
                    }
                    Component.onCompleted: {
                        sortGroup.maxItemTextWidth = Math.max(sortGroup.maxItemTextWidth, textLabel.width);
                    }
                }
            }
        }

        Rectangle {
            id: sperateItem
            height: 0.5
            width: itemBgWidth
            color: Colors.color_444444_50
            anchors {
                top: sortGroup.bottom
                topMargin: 4
            }
            x: 4
        }

        ListModel {
            id: ascendmModel
            ListElement {
                isASC: true
                title: qsTr("pccut_media_ascending")
            }
            ListElement {
                isASC: false
                title: qsTr("pccut_media_descending")
            }
        }

        Column {
            width: parent.width
            height: 60
            spacing: 4
            anchors {
                top: sperateItem.bottom
                topMargin: 4
            }

            Repeater {
                id: ascendRepeater
                model: ascendmModel
                anchors.fill: parent

                delegate: Rectangle {
                    id: ascend
                    property bool isHovered: false
                    radius: 4
                    width: itemBgWidth
                    height: 28
                    color: ascend.isHovered ? ColorsConfig.color_FFFFFF15_4DFFC920 : Colors.color_transparent
                    anchors.horizontalCenter: parent.horizontalCenter
                    Component.onCompleted: {
                        sortGroup.maxItemTextWidth = Math.max(sortGroup.maxItemTextWidth, textLabel2.width);
                    }
                    Image {
                        width: 16
                        height: 16
                        source: "qrc:/app_qrc/icons/icon_compose_check.svg"
                        anchors.verticalCenter: parent.verticalCenter
                        x: 8
                        visible: currentIsASC == isASC
                    }

                    Text {
                        id: textLabel2
                        text: model.title
                        height: parent.height
                        font.pixelSize: 11
                        color: (currentIsASC == isASC || ascend.isHovered) ? ColorsConfig.color_EEEEEE_4DFFC9 : Colors.color_EEEEEE
                        leftPadding: 30
                        verticalAlignment: Text.AlignVCenter
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: ascend.isHovered = true
                        onExited: ascend.isHovered = false
                        onClicked: {
                            close();
                            clickASC(isASC);
                        }
                    }
                }
            }
        }
    }
}
