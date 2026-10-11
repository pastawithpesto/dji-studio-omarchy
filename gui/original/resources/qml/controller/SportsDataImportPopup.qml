import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.3
import Qt5Compat.GraphicalEffects
import Qt.labs.platform 1.1
import Config 1.0
import Controls 1.0
import FitDataListModel 1.0
import app_qrc 1.0

/**
 * @author tengsen.zhang
 * @desc 运动数据导入弹窗
 * @create_date 2024-10-15
 */
LightPopup{
    id: lightPopup
    property bool isFirstTime: false
    property bool signalsConnected: false
    property string currentTime: fitDataListModel.currentTime

    parent: Overlay.overlay
    width: 360
    // height: !isFirstTime ? 398 : 346
    height: 398

    modal: true
    Overlay.modal: Rectangle {
        color: !isFirstTime ? Colors.color_80000000 : Colors.color_transparent
    }
    // 点击【取消】的信号
    signal cancelSignal
    // 点击【确定】的信号
    signal confirmSignal


    // 选中态由 C++ 单向回灌（内核 fitDataPath 的投影），此处不再手动赋值 listView.currentIndex，
    // 避免破坏绑定。弹窗为 PopupManager 单例常驻，每次打开按内核校准，覆盖 undo/redo/切草稿等被动变更。
    onAboutToShow: fitDataListModel.onFitDataChanged()

    FitTipPopUp {
        id: fitTipPopUp
        x: lightPopup.x + (lightPopup.width - width) / 2
        y: lightPopup.y + 36
    }

    FileDialog {
        id: importFileDialog
        fileMode: FileDialog.OpenFile
        // 支持的格式
        nameFilters: ["files (*.fit)"]
        onAccepted: {
            var isAddDashboard = false;
            if(!isFirstTime){
                confirmSignal();
                isAddDashboard = true;
            }

            editorManager.pause();
            var file = files[0];
            fitDataListModel.importFitFile(file, isAddDashboard);
            lightPopup.close();
        }
    }

    FitDataListModel {
        id: fitDataListModel
    }

    contentItem: Item{
        Rectangle {
            id: contentRectangle
            width: parent.width
            height: parent.height
            radius: 8
            color: Colors.color_2F3032
            border {
                color: Colors.color_454649
                width: 0.5
            }

            Column {
                spacing: 0

                //运动数据导入
                Rectangle {
                    width: contentRectangle.width
                    height: 40
                    color: Colors.color_transparent
                    clip: true

                    // 按钮固定在左侧垂直居中
                    ImageButton {
                        visible: !CommonUtils.isWindows()
                        anchors.left: parent.left
                        anchors.leftMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        width: 12
                        height: 12
                        normalImage: "qrc:/icons/appbar/btn_close_normal.svg"
                        hoveredImage: "qrc:/icons/appbar/btn_close_hovered.svg"
                        pushedImage: "qrc:/icons/appbar/btn_close_pushed.svg"
                        onClicked: (mouse) =>{
                            cancelSignal()
                            close()
                        }
                    }

                    ImageButton {
                        visible: CommonUtils.isWindows()
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16
                        height: 16
                        normalImage: "qrc:/icons/WindowsIcon/icon_close_modal.svg"
                        hoveredImage: "qrc:/icons/WindowsIcon/icon_close_modal_hover.svg"

                        onClicked: (mouse) =>{
                            cancelSignal()
                            close()
                        }
                    }

                    // 中间内容整体居中
                    Row {
                        anchors.centerIn: parent
                        spacing: 4

                        Text {
                            id: importText
                            verticalAlignment: Text.AlignVCenter
                            font.pixelSize: 12
                            color: Colors.color_EEEEEE
                            text: qsTr("pccut_dashboard_import_sportsdata")
                        }

                        Image {
                            id: explainIcon
                            width: 14
                            height: 14
                            source: explainIconMouseArea.containsMouse ? "qrc:/icons/ic_explain.svg" : "qrc:/icons/ic_explain_hover.svg"
                            sourceSize: Qt.size(14, 14)
                            anchors.verticalCenter: parent.verticalCenter
                            MouseArea {
                                id: explainIconMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                preventStealing: true
                                onEntered: fitTipPopUp.visible = true
                                onExited: fitTipPopUp.visible = false
                            }
                        }
                    }
                }
                BaseSpliter {
                    width: contentRectangle.width
                }
                Item {
                    width: contentRectangle.width
                    height: 24
                }
                //Fit文件导入
                Rectangle {
                    width: contentRectangle.width
                    height: 63
                    color: Colors.color_transparent
                    clip: true

                    Rectangle {
                        anchors {
                            left: parent.left
                            leftMargin: 28
                            right: parent.right
                            rightMargin: 28
                            verticalCenter: parent.verticalCenter
                        }
                        width: 278
                        height: Math.max(importRect.height + description.height + 12, 65)
                        radius: 8
                        color: importRectMouseArea.containsMouse ? Colors.color_56575B : Colors.color_454649
                        Accessible.role: Accessible.Button

                        Rectangle{
                            id: importRect
                            color: Colors.color_transparent
                            anchors {
                                horizontalCenter: parent.horizontalCenter
                            }
                            Image {
                                id: fitIcon
                                anchors {
                                    top: parent.top
                                    topMargin: 12
                                }
                                width: 16
                                height: 16
                                source: "qrc:/icons/dashboard/icon_fit_import.svg"
                                sourceSize: Qt.size(16, 16)
                            }
                            Text {
                                id: fitDescription
                                anchors {
                                    left: fitIcon.right
                                    leftMargin: 4
                                    top: parent.top
                                    topMargin: 12
                                }
                                verticalAlignment: Text.AlignVCenter
                                horizontalAlignment: Text.AlignHCenter
                                font.pixelSize: 12
                                color: Colors.color_EEEEEE
                                text: qsTr("pccut_dashboard_import_fitdata")
                            }

                            width:fitIcon.width + fitDescription.width + 4
                            height: 33
                        }

                        Text {
                            id:description
                            anchors {
                                top: importRect.bottom
                                left: parent.left
                                leftMargin: 12
                                right: parent.right
                                rightMargin: 12
                            }
                            verticalAlignment: Text.AlignVCenter
                            horizontalAlignment: Text.AlignHCenter
                            font.pixelSize: 11
                            color: Colors.color_999999
                            text: qsTr("pccut_dashboard_import_fitdata_description")
                            wrapMode: Text.WordWrap
                        }

                        MouseArea {
                            id: importRectMouseArea
                            anchors.fill: parent
                            preventStealing: true
                            hoverEnabled: true
                            onClicked: {
                                importFileDialog.open();
                                eventTracker.trackEvent("pccut_dashboard_fit_click")
                            }
                        }
                    }
                }
                Item {
                    width: contentRectangle.width
                    height: 16
                }
                // 数据源选择
                Rectangle {
                    width: contentRectangle.width
                    height: 29
                    color: Colors.color_transparent
                    clip: true

                    Text {
                        anchors {
                            left: parent.left
                            leftMargin: 28
                            verticalCenter: parent.verticalCenter
                        }
                        horizontalAlignment: Text.AlignLeft
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: 12
                        color: Colors.color_EEEEEE
                        text: qsTr("pccut_dashboard_select_data")
                    }
                }
                Item {
                    width: contentRectangle.width
                    height: 5
                }
                Rectangle{
                    width: contentRectangle.width
                    height: 194
                    color: Colors.color_transparent
                    clip: true
                    ListView {
                        id: listView
                        model: fitDataListModel.dataList
                        // 单向绑定：选中态唯一真相源在内核，QML 只读投影
                        currentIndex: fitDataListModel.currentIndex
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            bottom: !isFirstTime ? okBtn.top : parent.bottom
                            leftMargin: 28
                            rightMargin: 4
                            bottomMargin: !isFirstTime ? 12 : 0
                        }
                        clip: true
                        boundsBehavior: GridView.StopAtBounds
                        ScrollBar.vertical: ScrollBar{
                            rightPadding: 0
                            Component.onCompleted: {
                                contentItem.color = Colors.color_444444;
                            }
                        }
                        onCurrentIndexChanged: {
                            dashboardManager.setOffsetTimeEnabled(currentIndex === 0 ? false : true);
                        }
                        delegate: Column {
                            width: listView.width
                            FitDataItem {
                                itemModel: model.modelData
                                currentIndex: listView.currentIndex
                                width: listView.width-24
                                height: 57
                                Connections {
                                    function onFileDelete(path) {
                                        editorManager.pause();
                                        fitDataListModel.deleteByPath(path);
                                    }
                                    function onItemClick(path, date) {
                                        if(listView.currentIndex === index) {
                                            return;
                                        }

                                        editorManager.pause();
                                        var isAddDashboard = false;
                                        if(!isFirstTime){
                                            confirmSignal();
                                            isAddDashboard = true;
                                        }

                                        // 不再抢先自赋值 currentIndex：落盘后由内核回灌驱动选中态
                                        fitDataListModel.currentTime = date;

                                        close();
                                        fitDataListModel.analyzeFitFile(path, isAddDashboard);
                                    }
                                }
                            }
                            // 添加间隔，但不在最后一个元素后添加
                            Rectangle {
                                width: 278
                                height: 8
                                color: Colors.color_transparent
                            }
                        }
                        Component.onCompleted: {
                            fitDataListModel.fetchFitData();
                        }
                    }                  
                    Rectangle {  // 用 Rectangle 替代 Button，配合 MouseArea 实现自定义按钮
                        id: okBtn
                        width: 88
                        height: 28
                        visible: !isFirstTime
                        objectName: actionableItemName.dashBoardConfirmBtn
                        anchors {
                            bottom: parent.bottom
                            bottomMargin: 0
                            right: parent.right
                            rightMargin: 28
                        }
                        radius: RadiusConfig.radius_4_88
                        color: ColorsConfig.color_brand

                        Text {
                            anchors.centerIn: parent
                            text: qsTr("pccut_project_modify_yes")
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font.pixelSize: 12
                            color: ColorsConfig.color_FFFFFF_000000
                        }

                        MouseArea {
                            anchors.fill: parent
                            preventStealing: true  // 核心：阻止事件冒泡到其他区域

                            onPressed: {
                                // 可添加按钮按下效果（如颜色变化）
                                okBtn.color = Qt.darker(ColorsConfig.color_brand, 1.2)
                            }

                            onReleased: {
                                okBtn.color = ColorsConfig.color_brand
                            }

                            onClicked: {
                                editorManager.pause()
                                confirmSignal()
                                close()
                                fitDataListModel.analyzeFitFile("videoSource", true)
                            }
                        }
                    }
                    //取消按钮
                    Rectangle {
                        id: customBtn
                        objectName: actionableItemName.sportDataImportCancel
                        width: 88
                        height: 28
                        visible: !isFirstTime
                        anchors {
                            bottom: parent.bottom
                            bottomMargin: 0
                            right: okBtn.left
                            rightMargin: 12
                        }
                        radius: RadiusConfig.radius_4_88
                        color: Colors.color_666666

                        Text {
                            text: qsTr("pccut_draft_delete_popup_cancel")
                            anchors.fill: parent
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font.pixelSize: 12
                            color: Colors.color_FFFFFF
                        }

                        MouseArea {
                            anchors.fill: parent
                            preventStealing: true  // 核心：阻止事件冒泡到其他区域
                            onClicked: (mouse) =>{
                                cancelSignal()
                                close()
                                mouse.accepted = true // 阻止事件冒泡[3][7]
                            }
                        }
                    }
                }
            }
        }
    }
}
