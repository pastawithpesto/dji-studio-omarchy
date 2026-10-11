import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls
import QtQuick.Dialogs
import QtQml 2.15
import Controls 1.0
import Config 1.0
import Qt5Compat.GraphicalEffects
import MediaLostAndFoundViewModel 1.0
import "../menubar"
import app_qrc 1.0

// 媒体链接
LightPopup {
    id: pop
    width: lightWindow.width
    height: lightWindow.height
    dim: false

    // open后，屏蔽不让下面的窗口响应
    onOpened: {
        content.enabled = false;
    }

    onClosed: {
        content.enabled = true;
        const linkedCount = lAFViewModel.linkedCount
        if (linkedCount > 0) {
            toast.showToast(qsTr("pccut_files_missing_success") + linkedCount + qsTr("pccut_count"));
        }
        const dialog = fileDialogLoader.item;
        dialog.close();
    }

    MediaLostAndFoundViewModel {
        id: lAFViewModel
        autoLinkWithDir: autoLinkWithDir.checked

        onAllMediaFound: {
            close();
        }
    }

    contentItem: Item {
        id: popContent

        // 窗口背景色
        Rectangle {
            id: popBackground
            anchors.centerIn: parent
            width: 600
            height: 482
            color: Colors.color_2F3032
            radius: 8
            clip: true
            border.width:1
            border.color:Colors.color_454649
            WindowTitleBar {
                id: titleBar
                height: 40
                width: parent.width
                title: qsTr("pccut_files_missing_linkmedia")
                onCloseClick: {
                    close();
                }
            }
            // 直接把border写在popBackground中和放在另外一个Rectangle中，效果并不一致，也许直接设置border并不会叠加显示
            Item {
                id: actionButton
                height: 26
                width: parent.width

                anchors {
                    right: parent.right
                    bottom: parent.bottom
                    rightMargin: 28
                    bottomMargin: 19
                }

                Rectangle {
                    id: confirmBtn
                    color: confirmMouseArea.containsMouse ? ColorsConfig.color_F44C65_6DFFD3 : ColorsConfig.color_brand
                    radius: RadiusConfig.radius_4_88
                    width: Math.max(confirmBtn.defaultWidth, cancelBtn.defaultWidth)
                    height: 26
                    property real defaultWidth: confirmText.width + 26
                    anchors.right: parent.right
                    Text {
                        id: confirmText
                        text: qsTr("pccut_files_missing_linkmedia")
                        color: ColorsConfig.color_FFFFFF_000000
                        anchors.centerIn: parent
                        font.pixelSize: 12
                    }

                    MouseArea {
                        id: confirmMouseArea
                        hoverEnabled: true
                        anchors.fill: parent
                        onClicked: {
                            confirm();
                        }
                    }
                }

                Rectangle {
                    id: cancelBtn
                    color: cancelMouseArea.containsMouse ? Colors.color_777777 : Colors.color_666666
                    radius: RadiusConfig.radius_4_88
                    width: Math.max(confirmBtn.defaultWidth, cancelBtn.defaultWidth)
                    height: 26
                    property real defaultWidth: cancelText.width + 26
                    anchors.right: confirmBtn.left
                    anchors.rightMargin: 12
                    Text {
                        id: cancelText
                        text: qsTr("pccut_draft_delete_popup_cancel")
                        color: Colors.color_FFFFFF
                        anchors.centerIn: parent
                        font.pixelSize: 12
                    }

                    MouseArea {
                        id: cancelMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            cancel();
                        }
                    }
                }
            }

            CheckBox {
                id:autoLinkWithDir

                text: qsTr("pccut_files_missing_auto")
                // 默认为true，不记录用户选择
                checked: true
                width: cancelBtn.x - 12 - 28 - 8
                anchors {
                    top: actionButton.top
                    bottom: actionButton.bottom
                    left: parent.left
                    leftMargin: 28
                }

                indicator: Rectangle {
                    implicitWidth: 14
                    implicitHeight: 14
                    anchors.left: autoLinkWithDir.left
                    anchors.verticalCenter: parent.verticalCenter
                    color:  autoLinkWithDir.checked ? ColorsConfig.color_brand : Colors.color_444444
                    radius: 4
                    Image {
                        id: icon
                        visible: autoLinkWithDir.checked
                        anchors.fill: parent
                        source: "qrc:/app_qrc/icons/icon_checkbox_check.svg"
                        sourceSize: Qt.size(parent.width, parent.height)
                    }

                }

                contentItem: HoverableText {
                    text: autoLinkWithDir.text
                    font.pixelSize: 12
                    color: Colors.color_EEEEEE
                    verticalAlignment: Text.AlignVCenter
                    cursorChanged: false
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap

                    anchors.left: autoLinkWithDir.indicator.right
                    anchors.leftMargin: 4
                    anchors.right: parent.right
                    anchors.rightMargin: 12

                    onClicked:{
                        autoLinkWithDir.checked = !autoLinkWithDir.checked
                    }
                }
            }

            Text {
                id: secondaryTitle
                text: qsTr("pccut_files_missing_linkmedia_description")
                color: Colors.color_CCCCCC
                anchors {
                    left: parent.left
                    top: titleBar.bottom
                    leftMargin: 28
                    topMargin: 12
                }
                font.pixelSize: 11
            }

            Rectangle {
                anchors {
                    top: secondaryTitle.bottom
                    left: parent.left
                    right: parent.right
                    topMargin: 12
                    leftMargin: 28
                    rightMargin: 28
                }
                radius: 8
                color: Colors.color_1F2021
                height: 331

                Rectangle {
                    anchors.fill: parent
                    radius: 8
                    border.color: Colors.color_FFFFFF_10
                    border.width: 0.5
                    color: Colors.transparent
                }

                Item {
                    id: tableTitle
                    width: parent.width
                    height: 15
                    anchors {
                        left: parent.left
                        leftMargin: 16
                        right: parent.right
                        rightMargin: 16
                        top:parent.top
                        topMargin:12
                    }
                    Text {
                        id: mediaNameColumnTitle
                        text: qsTr("pccut_files_missing_name")
                        color: Colors.color_999999
                        width: 149
                        height: parent.height
                        anchors {
                            left: parent.left
                            leftMargin: 20
                        }
                        font.pixelSize: 11
                        verticalAlignment: Text.AlignVCenter
                    }

                    Text {
                        id: durationColumnTitle
                        text: qsTr("pccut_media_info_time")
                        color: Colors.color_999999
                        width: 54
                        height: parent.height
                        anchors {
                            right: parent.right
                            rightMargin: 0
                        }
                        font.pixelSize: 11
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Text.AlignRight     // 水平靠右
                    }

                    Text {
                        id: pathColumnTitle
                        text: qsTr("pccut_files_missing_source")
                        color: Colors.color_999999
                        height: parent.height
                        anchors {
                            left: mediaNameColumnTitle.right
                            right: durationColumnTitle.left
                            leftMargin: 24
                            rightMargin: 24
                        }
                        font.pixelSize: 11
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Rectangle {
                    id: tableTitleDivider
                    width: parent.width
                    height: 1
                    color: Colors.color_2F3032
                    anchors.top: tableTitle.bottom
                    anchors.topMargin:12
                    anchors.left:parent.left
                    anchors.leftMargin:16
                    anchors.right:parent.right
                    anchors.rightMargin:16
                }

                Item {
                    id: tableFoot
                    width: parent.width
                    anchors {
                        left: parent.left
                        right: parent.right
                        bottom: parent.bottom
                        bottomMargin:12
                    }
                    height: 15

                    Text {
                        id: mediaLinkedLabelText
                        text: qsTr("pccut_files_missing_count")
                        color: Colors.color_CCCCCC
                        height: parent.height
                        anchors {
                            right: parent.right
                            rightMargin: 16
                        }
                        font.pixelSize: 11
                        verticalAlignment: Text.AlignVCenter
                    }

                    Text {
                        id: mediaLinkedCountText
                        color: ColorsConfig.color_brand
                        height: parent.height
                        anchors.right: mediaLinkedLabelText.left
                        font.pixelSize: 11
                        verticalAlignment: Text.AlignVCenter
                        text: qsTr("pccut_files_missing_count_number").arg(lAFViewModel.linkedCount + "/" + lAFViewModel.totalCount)
                    }
                }

                Rectangle {
                    id: tableFootDivider
                    width: parent.width
                    height: 1
                    color: Colors.color_2F3032
                    anchors.bottom: tableFoot.top
                    anchors.bottomMargin: 12
                    anchors.left:parent.left
                    anchors.leftMargin:0
                    anchors.right:parent.right
                    anchors.rightMargin:0
                }

                ScrollView {
                    anchors {
                        top: tableTitleDivider.bottom
                        left: parent.left
                        right: parent.right
                        bottom: tableFootDivider.top
                    }
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                    clip: true

                    ListView {
                        id: lostMedias
                        anchors {
                            left: parent.left
                            right: parent.right
                        }
                        model:lAFViewModel
                        delegate: Item {
                            anchors {
                                left: parent.left
                                right: parent.right
                            }
                            height: 39

                            Text {
                                id: mediaNameText
                                color: selected ? ColorsConfig.color_brand : Colors.color_EEEEEE
                                width: 149
                                height: parent.height
                                elide: Text.ElideMiddle
                                anchors {
                                    left: parent.left
                                    leftMargin: 36
                                }
                                font.pixelSize: 11
                                verticalAlignment: Text.AlignVCenter
                                text: srcName
                            }

                            Text {
                                id: mediaDurationText
                                color: selected ? ColorsConfig.color_brand : Colors.color_EEEEEE
                                width: 70
                                height: parent.height
                                elide: Text.ElideMiddle
                                anchors.right: parent.right
                                anchors.rightMargin:16
                                font.pixelSize: 11
                                verticalAlignment: Text.AlignVCenter
                                horizontalAlignment: Text.AlignRight 
                                text: duration
                            }

                            Text {
                                id: mediaPathText
                                color: selected ? ColorsConfig.color_brand : Colors.color_EEEEEE
                                height: parent.height
                                elide: Text.ElideMiddle
                                anchors {
                                    left: mediaNameText.right
                                    right: mediaDurationText.left
                                    leftMargin: 24
                                    rightMargin: 24
                                }
                                font.pixelSize: 11
                                verticalAlignment: Text.AlignVCenter
                                text: srcPath
                                property bool isElided: implicitWidth > width

                                MouseArea {
                                    id: mediaPathMouse
                                    anchors.fill: parent
                                    hoverEnabled: true

                                    onEntered: {
                                        if (mediaPathText.isElided) {  // 仅在省略时启动计时器
                                            hoverTimer.start();
                                        }
                                    }
                                    onExited: {
                                        hoverTimer.stop();
                                        mediaPathInfo.hide();
                                    }
                                }

                                Timer {
                                    id: hoverTimer
                                    // hover之后保持N毫秒后展示完整路径
                                    interval: 600
                                    repeat: false
                                    onTriggered: {
                                        if (!mediaPathInfo.isShow) {
                                            var mousePos = mediaPathMouse.mapToItem(popContent, mediaPathMouse.mouseX, mediaPathMouse.mouseY);
                                            mediaPathInfo.show(mousePos, srcPath);
                                        }
                                    }
                                }
                            }

                            Image {
                                id: linkedImage
                                visible: linked
                                width: 16
                                height: 16
                                anchors {
                                    right: mediaNameText.left
                                    rightMargin: 2
                                    verticalCenter: parent.verticalCenter
                                }
                                source: "qrc:/icons/ic_lost_media_linked.svg"
                                sourceSize: Qt.size(16, 16)
                            }

                            Rectangle {
                                id: mediaItemDivider
                                height: 1
                                color: Colors.color_2F3032
                                anchors {
                                    top: parent.bottom
                                    left: parent.left
                                    right: parent.right
                                    leftMargin: 16
                                    rightMargin: 16
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    if (!selected) {
                                        lAFViewModel.select(index)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            id: mediaPathInfo
            property real anchorX: 0
            property real anchorY: 0
            property bool isShow: false
            property string showPath: ""

            visible: false
            opacity: 0
            // 12是左右的padding * 2
            width: text.width + 16
            // 16是上下的padding * 2
            height: text.height + 16
            x: anchorX - width / 2
            y: anchorY
            color: Colors.color_19191A
            radius: 4
            border {
                color: Colors.color_454649
                width: 1
            }
            Text {
                id: text
                anchors.centerIn: parent
                font.pixelSize: 11
                color: Colors.color_EEEEEE
                text: mediaPathInfo.showPath
            }

            // 使用Behavior实现渐显和渐隐
            Behavior on opacity {
                OpacityAnimator {
                    duration: 200
                }
            }

            // 监听opacity变化，当opacity为0时设置visible为false
            onOpacityChanged: {
                if (opacity === 0) {
                    visible = false;
                }
            }

            function show(mousePoint, path) {
                anchorX = mousePoint.x;
                // 这里的20其实是不太重要的值，主要作用是让展示的位置展示在鼠标位置向下一些
                anchorY = mousePoint.y + 20;
                mediaPathInfo.visible = true;
                mediaPathInfo.opacity = 1.0;
                mediaPathInfo.showPath = path;
                isShow = true;
            }
            function hide() {
                mediaPathInfo.opacity = 0.0;
                isShow = false;
            }
        }
    }

    Loader {
        id: fileDialogLoader
        source: Qt.platform.os === "osx" ? "LinkFileDialogMac.qml" : "LinkFileDialogWindows.qml";
    }

    function cancel() {
        close();
    }

    function confirm() {
        const dialog = fileDialogLoader.item;
        dialog.allowSelectFolder = lAFViewModel.autoLinkWithDir
        dialog.title = qsTr("pccut_files_missing_search") + lAFViewModel.selectedFileName();
        dialog.show();
    }

    function setNeedLinkedData(tfInfos) {
        lAFViewModel.setFilterInfos(tfInfos);
    }
}
