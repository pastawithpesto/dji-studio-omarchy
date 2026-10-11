import Config 1.0
import Controls 1.0
import QtQuick 2.15
import QtQuick.Controls
import VideoFragmentViewModel 1.0
import app_qrc 1.0
import UsedFunctionManager 1.0
import ProjectSettingsInfo 1.0

/**
 * @author tengsen.zhang
 * @desc 仪表盘功能调节界面
 * @create_date 2024-10-11
 */
Rectangle {
    id: root

    property VideoFragmentViewModel viewModel
    property bool controlsEnabled: dashboardManager.filterEnabled
    property Popup importPopup: null
    anchors.fill: parent
    color: Colors.color_141414

    Component.onCompleted: {
        if (PopupManager) {
            importPopup = PopupManager.getPopup("qrc:/qml/controller/SportsDataImportPopup.qml");
            importPopup.objectName = actionableItemName.sportsDataImportPopup

        } else {
            console.error("PopupManager is null, cannot call getPopup");
        }
    }
    Connections {
        target: dashboardManager
        function onFilterEnabledChanged() {
            controlsEnabled = dashboardManager.filterEnabled
            checkBox.checked = dashboardManager.filterEnabled
        }
    }
    function showImportPopup() {
        importPopup.isFirstTime = true;
        importPopup.parent = lightWindow.contentItem;
        importPopup.anchors.centerIn = undefined;
        importPopup.closePolicy = Popup.CloseOnPressOutside | Popup.CloseOnEscape;
        var position = UiUtils.getGlobalPosition(dataSelectRect);
        importPopup.width = Math.max(dataSelectRect.width, 360);
        importPopup.x = position.x + dataSelectRect.width - importPopup.width;
        importPopup.y = position.y + dataSelectRect.height + 5;
        importPopup.open();
    }

    function showAligmentPopup() {
        var position = UiUtils.getGlobalPosition(aligmentRect);
        aligmentPopup.x = position.x + aligmentRect.width - aligmentPopup.width;
        aligmentPopup.y = position.y + aligmentRect.height + 4;
        aligmentPopup.open();
    }
    //时间对齐弹窗
    TimeAlignmentPopup {
        id: aligmentPopup
        currentTime: importPopup.currentTime
    }

    // 窗口失去焦点时关闭弹窗
    Connections {
        target: appStateDetector
        function onAppActiveChanged() {
            if (!appStateDetector.appActive) {
                if(aligmentPopup.opened) {
                    aligmentPopup.close()
                }
                if(importPopup.opened) {
                    importPopup.close()
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 1
        color: Colors.color_content_area_background

        ScrollView {
            id: scrollView

            bottomPadding: 20
            ScrollBar.vertical.policy: ScrollBar.AlwaysOff
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            clip: true
            contentHeight: column.implicitHeight
            anchors {
                left: parent.left
                leftMargin: 12
                top: parent.top
                right: parent.right
                bottom: parent.bottom
            }

            Component.onCompleted: {
                contentItem.boundsBehavior = Flickable.StopAtBounds
            }

            Column {
                id: column
                spacing: 0

                Rectangle{
                    anchors.left: parent.left
                    width: scrollView.width
                    color: Colors.color_transparent
                    height: 46
                    clip: true

                    CheckBox {
                        id:checkBox
                        text: qsTr("pccut_dashboard")
                        anchors.top: parent.top
                        anchors.topMargin: 10
                        checked: dashboardManager.filterEnabled
                        indicator: Rectangle {
                            implicitWidth: 14
                            implicitHeight: 14
                            anchors.left: checkBox.left
                            anchors.verticalCenter: parent.verticalCenter
                            color:  checkBox.checked ? ColorsConfig.color_brand : Colors.color_444444
                            radius: 4
                            Image {
                                id: icon
                                visible: checkBox.checked
                                anchors.fill: parent
                                source: "qrc:/app_qrc/icons/icon_checkbox_check.svg"
                                sourceSize: Qt.size(parent.width, parent.height)
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                var isChecked = checkBox.checked;
                                var projectId = draftManager.activeProjectEnvId();
                                if(isChecked){
                                    toast.showToast(qsTr("pccut_dashboard_close"), "playerPanel");
                                    UsedFunctionManager.removeFunction(projectId,UsedFunctionManager.EditorFunctionType.DASHBOARD);
                                }else{
                                    toast.showToast(qsTr("pccut_dashboard_open"), "playerPanel");
                                    UsedFunctionManager.addFunction(projectId,UsedFunctionManager.EditorFunctionType.DASHBOARD);
                                }
                                dashboardManager.setFilterEnabled(!isChecked)
                            }
                        }
                        contentItem: Text {
                            text: checkBox.text
                            font.pixelSize: 12
                            color: Colors.color_EEEEEE
                            verticalAlignment: Text.AlignVCenter
                            leftPadding: checkBox.indicator.width + 2
                        }
                    }
                }

                //仪表名称
                Rectangle {
                    anchors.left: parent.left
                    width: scrollView.width
                    color: Colors.color_transparent
                    height: 34
                    clip: true

                    Rectangle {
                        color: Colors.color_transparent
                        height: 20
                        Text {
                            id: dashboardName
                            anchors {
                                left: parent.left
                                top: parent.top
                                bottom: parent.bottom
                            }
                            horizontalAlignment: Text.AlignLeft
                            verticalAlignment: Text.AlignVCenter
                            font.pixelSize: 11
                            color: Colors.color_EEEEEE
                            text: qsTr("pccut_dashboard_name")
                            opacity: root.controlsEnabled ? 1 : 0.2
                        }

                        Text {
                            anchors {
                                top: parent.top
                                left: dashboardName.right
                                leftMargin: 24
                                bottom: parent.bottom
                            }
                            verticalAlignment: Text.AlignVCenter
                            font.pixelSize: 11
                            color: Colors.color_EEEEEE
                            opacity: root.controlsEnabled ? 1 : 0.2
                            text: dashboardManager.getDashboardCategoryName();
                        }
                    }
                }

                //数据导入
                Rectangle {
                    anchors.left: parent.left
                    width: scrollView.width
                    height: 15
                    color: Colors.color_transparent
                    clip: true

                    Text {
                        id: importText
                        anchors {
                            left: parent.left
                            top: parent.top
                            bottom: parent.bottom
                        }
                        enabled: root.controlsEnabled
                        horizontalAlignment: Text.AlignLeft
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: 11
                        opacity: root.controlsEnabled ? 1 : 0.2
                        color: Colors.color_EEEEEE
                        text: qsTr("pccut_dashboard_import_data")
                    }
                }
                // 数据源选择
                Rectangle {
                    anchors.left: parent.left
                    width: scrollView.width
                    height: 50
                    color: Colors.color_transparent
                    clip: true

                    Rectangle {
                        id: dataSelectRect
                        property bool isHovered: false
                        anchors {
                            left:  parent.left
                            right: aligmentRect.left
                            rightMargin: 8
                            top: parent.top
                            topMargin: 12
                        }
                        height: 24
                        radius: RadiusConfig.radius_4_8
                        color: dataSelectRect.isHovered ? Colors.color_414344 : Colors.color_353738
                        Accessible.role: Accessible.Button
                        opacity: enabled ? 1 : 0.2
                        enabled: root.controlsEnabled

                        Text {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            verticalAlignment: Text.AlignVCenter
                            horizontalAlignment: Text.AlignLeft
                            font.pixelSize: 11
                            color: Colors.color_EEEEEE
                            text: qsTr("pccut_dashboard_data_source")
                        }

                        Image {
                            id: canvas_icon
                            anchors {
                                right: parent.right
                                rightMargin: 4
                                verticalCenter: parent.verticalCenter
                            }
                            width: 20
                            height: 20
                            source: importPopup.visible ? "qrc:/icons/player/ic_canvas_up.svg" : "qrc:/icons/player/ic_canvas_down.svg"
                            sourceSize: Qt.size(20, 20)
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: dataSelectRect.isHovered = true;
                            onExited: dataSelectRect.isHovered = false;
                            onClicked: {
                                if(importPopup.visible){
                                    importPopup.close();
                                }
                                else{
                                    showImportPopup();
                                }
                            }
                        }
                    }

                    Rectangle {
                        id: aligmentRect
                        property bool isHovered: false
                        anchors {
                            right: parent.right
                            rightMargin: 12
                            top: parent.top
                            topMargin: 12
                        }
                        width: timeAlignmentTitle.width + 16
                        height: 24
                        radius: RadiusConfig.radius_4_8
                        color: aligmentRect.isHovered ? Colors.color_414344 : Colors.color_353738
                        Accessible.role: Accessible.Button
                        enabled: root.controlsEnabled && dashboardManager.offsetTimeEnabled
                        opacity: enabled ? 1 : 0.2

                        Text {
                            id: timeAlignmentTitle
                            anchors.centerIn: parent
                            verticalAlignment: Text.AlignVCenter
                            horizontalAlignment: Text.AlignHCenter
                            font.pixelSize: 11
                            color: Colors.color_EEEEEE
                            text: qsTr("pccut_dashboard_time_alignment")
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: aligmentRect.isHovered = true;
                            onExited: aligmentRect.isHovered = false;
                            onClicked: {
                                showAligmentPopup();
                            }
                        }
                    }
                }
                // 仪表选择
                Rectangle {
                    anchors.left: parent.left
                    width: scrollView.width
                    height: 20
                    color: Colors.color_transparent
                    clip: true
                    enabled: root.controlsEnabled

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignLeft
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: 11
                        opacity: root.controlsEnabled ? 1 : 0.2
                        color: Colors.color_EEEEEE
                        text: qsTr("pccut_dashboard_choice")
                    }

                    IconButton {
                        width: 20
                        height: 20
                        radius: 4
                        Accessible.role: Accessible.Button
                        externalOpacity: true
                        anchors.verticalCenter: parent.verticalCenter
                        anchors {
                            right: parent.right
                            rightMargin: 12
                        }
                        enabled: root.controlsEnabled
                        opacity: root.controlsEnabled ? 1 : 0.2
                        iconSource: hovered ? "qrc:/icons/ic_reset_hover.svg" : "qrc:/icons/ic_reset.svg"
                        hoverColor: Colors.color_transparent
                        pressedColor: Colors.color_transparent
                        tipLinesFunc: function() {
                            return [
                            {
                                text: qsTr("pccut_dashboard_reset"),
                                color: Colors.color_EEEEEE,
                                size: 11
                            },
                            {
                                text: qsTr("pccut_dashboard_reset_description"),
                                color: Colors.color_999999,
                                size: 11
                            },
                        ];
                        }
                        onClicked: {
                            selectingPanel.stickerDataListModel.reset();
                            editorDraftManager.saveDraft();
                            toast.showToast(qsTr("pccut_dashboard_restore"), "playerPanel");
                            eventTracker.trackEvent("pccut_dashboard_reset_click")
                        }
                    }
                }
                // 仪表
                DashboardSelectingPanel{
                    enabled: root.controlsEnabled
                    id: selectingPanel
                    objectName: actionableItemName.dashboardSelectingPanel
                    width: scrollView.width
                }

                // 地理位置信息
                DashboardLocationSelector {
                    id: locationSelector
                    isActive: root.controlsEnabled && locationSelector.viewModel.isGpsStickerActive && !locationSelector.viewModel.isLoading
                    width: scrollView.width
                }
            }
        }
    }
}
