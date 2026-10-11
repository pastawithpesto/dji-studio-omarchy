import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import Controls 1.0
import Config 1.0
import FeedBackManager 1.0
import app_qrc 1.0

LightPopup {
    id: popup
    closePolicy: Popup.CloseOnEscape
    width: 360
    height: 594
    anchors.centerIn: Overlay.overlay
    Overlay.modal: Rectangle{
        radius: 10
        color: Colors.color_000000_50
    }
    enter: Transition {
    }
    exit:Transition {
    }
    property FeedBackManager feedBackManager

    property bool isClosedOrDestruction: false
    property bool isInEURegion: locationManager.isInEURegion
    property int feedBackShowFlag: 1

    function showUserFeedBackLoading(type,description,contact,device){
        userFeedbackUploadLoading.type=type
        userFeedbackUploadLoading.description=description
        userFeedbackUploadLoading.contact=contact
        userFeedbackUploadLoading.device=device
        if(!locationManager.isInEURegion){
            feedBackShowFlag = 2
        }
        feedBackManager.sendResource()
    }

    onOpened: {
        feedBackShowFlag = 1
        sceneModel.clear()
        for (let i = 0 ;i < scene.length; ++i) {
            sceneModel.append({"code": i, "title": qsTr(scene[i])})
        }
        feedBackManager.init()
        descriptionInput.text = ""
        contactInput.text = ""
        deviceModelComboBox.currentIndex = -1
        isClosedOrDestruction = true
        logUploadReflush.visible = false
        ShortcutObserver.disableAllShortcut(true)
        globalSignal.addPopupQuantity()
        if(!isInEURegion) {
            feedBackManager.packResource()
        }
        feedBackContent.contentY = 0
        forceActiveFocus()
    }
    onClosed: {
        if (isClosedOrDestruction) {
            ShortcutObserver.disableAllShortcut(false)
            globalSignal.reducePopupQuantity()
            isClosedOrDestruction = false
        }
    }

    property bool inChina: locationManager.isInChina
    property var scene: [
    qsTr("pccut_feedback_scene_network"),
    qsTr("pccut_feedback_scene_effect"),
    qsTr("pccut_feedback_scene_play"),
    qsTr("pccut_feedback_scene_export"),
    qsTr("pccut_feedback_scene_crash"),
    qsTr("pccut_feedback_scene_lag"),
    qsTr("pccut_feedback_scene_audio"),
    qsTr("pccut_feedback_scene_video"),
    qsTr("pccut_feedback_scene_quality"),
    qsTr("pccut_feedback_scene_timeline"),
    qsTr("pccut_feedback_scene_import"),
    qsTr("pccut_feedback_scene_draft"),
    qsTr("pccut_feedback_scene_asset"),
    qsTr("pccut_feedback_scene_hardware"),
    qsTr("pccut_feedback_scene_update"),
    qsTr("pccut_feedback_scene_feature_suggestion"),
    qsTr("pccut_feedback_scene_login"),
    qsTr("pccut_feedback_scene_other")
    ]

    property var deviceModels: feedBackManager.userFeedbackDeviceModels()
                                            .concat([qsTr("pccut_feedback_log_device_other")])

    background: Rectangle {
        radius: 8
        border.color: Colors.color_454649
        border.width: 1
        color: Colors.color_2F3032
        Rectangle {
            width: parent.width
            height: 1
            anchors.top: parent.top
            anchors.topMargin: 40
            anchors.horizontalCenter: parent.horizontalCenter
            color: Colors.color_454649
        }
    }

    contentItem: Item {
        MouseArea {
            anchors.fill: parent
            preventStealing: true
            onClicked: {
                forceActiveFocus()
            }
        }

        ListModel {
            id: sceneModel
        }
        ButtonGroup {
            id: sceneButtonGroup
        }

        ConfirmPopup {
            id: quitConfirmPopup

            title: qsTr("pccut_feedback_exit")
            text: qsTr("pccut_feedback_exit_save")
            leftButtonText: qsTr("pccut_feedback_exit_cancel")
            rightButtonText: qsTr("pccut_feedback_exit_yes")
            onRightButtonClicked: {
                eventTracker.trackEvent("pccut_feedback_close")
                feedBackManager.clearZip()
                popup.close()
            }
        }

        IconButton {
            id: btn_close
            anchors {
                top: parent.top
                left: parent.left
                topMargin: 14
                leftMargin: 16
            }
            width: 12
            height: 12
            iconMargins: 0
            visible: !CommonUtils.isWindows()

            iconSource: "qrc:/icons/appbar/btn_close_normal.svg"
            hoverIconSource: "qrc:/icons/appbar/btn_close_hovered.svg"
            pressedIconSource: "qrc:/icons/appbar/btn_close_pushed.svg"
            disabledIconSource: "qrc:/icons/appbar/btn_appbar_disable.svg"
            onClicked: {
                if (!descriptionInput.isDefaultText && !descriptionInput.text.length !== 0
                  && feedBackShowFlag === 1) {
                    quitConfirmPopup.open()
                } else {
                    eventTracker.trackEvent("pccut_feedback_close")
                    feedBackManager.clearZip()
                    popup.close()
                }
            }
        }

        IconButton {
            id: windows_btn_close
            anchors {
                right: parent.right
                rightMargin: 16
                verticalCenter: userFeedBackTitle.verticalCenter
            }
            width: 20
            height: 20
            iconMargins: 0
            visible: CommonUtils.isWindows()

            iconSource: "qrc:/icons/WindowsIcon/icon_close_modal.svg"
            hoverIconSource: "qrc:/icons/WindowsIcon/icon_close_modal_hover.svg"
            pressedIconSource: "qrc:/icons/WindowsIcon/icon_close_modal_hover.svg"
            disabledIconSource: "qrc:/icons/WindowsIcon/icon_close_modal.svg"
            onClicked: {
                if (!descriptionInput.isDefaultText && !descriptionInput.text.length !== 0
                && feedBackShowFlag === 1) {
                    quitConfirmPopup.open()
                } else {
                    eventTracker.trackEvent("pccut_feedback_close")
                    feedBackManager.clearZip()
                    popup.close()
                }
            }
        }

        Text {
            id: userFeedBackTitle
            text: qsTr("pccut_feedback")
            font.pixelSize: 12
            anchors {
                horizontalCenter: parent.horizontalCenter
                top: parent.top
                topMargin: 12
            }
            color: Colors.color_EEEEEE
        }


        Rectangle{
            id:feedBackSubmitLoading
            visible: feedBackShowFlag === 2
            // 布局可能需要修改
            anchors {
                fill:parent
                topMargin: 64
                leftMargin: 28
                rightMargin: 28
                bottomMargin: 28
            }

            color: Colors.color_transparent

            Timer {
                id: disableEventTrackerDelay
                interval: 10000  // 10秒
                repeat: false
                onTriggered: {
                    eventTracker.enable(false)
                }
            }

            Rectangle {
                id: userFeedbackUploadLoading
                visible:feedBackSubmitLoading.visible
                width: 360
                height: 140
                anchors.centerIn: parent
                property string type: ""
                property string description: ""
                property string contact: ""
                property string device: ""
                property int progress: feedBackManager.resourceUploadProgress
                property bool isClosedOrDestruction: false

                color: Colors.color_transparent
                onVisibleChanged: {
                    if(visible){
                        isClosedOrDestruction = true
                        feedbackUpLoadingText.text = qsTr("pccut_feedback_log_upload_pack_loading")
                        ShortcutObserver.disableAllShortcut(true)
                        globalSignal.addPopupQuantity()
                        forceActiveFocus()
                    }else{
                    if (isClosedOrDestruction) {
                        ShortcutObserver.disableAllShortcut(false)
                        globalSignal.reducePopupQuantity()
                        isClosedOrDestruction = false
                    }
                    }

                }
                Connections {
                    target: feedBackManager
                    function onPostFeedBackSucess(feedBackid) {
                        // 有两个问题
                        // 1. 取消点击以后，上传日志已经完成，到触发结果反馈ID接口的时候，有延迟，会导致明明已经取消但是还是显示成功了
                        // 2. 网络不好的时候，已经显示失败了，到界面1，也就是默认界面了，但是后面网络接口成功了，又闪了一下成功界面
                        if(feedBackShowFlag !== 1){
                            feedBackIdText.text = feedBackid
                            feedBackShowFlag = 3
                            feedBackManager.clearZip()
                        }
                    }

                    function onDetectedNoNetwork() {
                        feedBackShowFlag = 1
                    }

                    function onRequestTooFrequent() {
                        feedBackShowFlag = 1
                    }
                    function onDetectedNoNetworkSingle() {
                        feedBackShowFlag = 1
                    }

                    function onRequestTooFrequentSingle() {
                        feedBackShowFlag = 1
                    }

                    function onUploadFailed() {
                        feedBackShowFlag = 1
                        feedBackManager.clearZip();
                        if(!isInEURegion) {
                            feedBackManager.packResource()
                        }
                    }
                }
                onProgressChanged: {
                    if (progress === 100) {
                        // 欧盟地区在发送事件前开启埋点开关
                        if(locationManager.isInEURegion) {
                            // 停止之前的计时器（如果存在）
                            if(disableEventTrackerDelay.running) {
                                disableEventTrackerDelay.stop();
                            }
                            eventTracker.enable(true)
                        }
                        feedbackUpLoadingText.text = qsTr("pccut_feedback_log_upload_loading")
                        feedBackManager.postFeedBackID(userFeedbackUploadLoading.contact,
                        userFeedbackUploadLoading.description,
                        userFeedbackUploadLoading.type,
                        userFeedbackUploadLoading.device)

                        // 欧盟地区在发送事件后延迟10秒关闭埋点开关
                        if (locationManager.isInEURegion) {
                            disableEventTrackerDelay.start()
                        }
                    }
                }



                ColumnLayout {
                    id: column
                    x: 28
                    y: 24
                    width: parent.width - 28 * 2
                    spacing: 22
                    Text {
                        id:feedbackUpLoadingText
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignHCenter
                        text: qsTr("pccut_feedback_log_automatic_uploading")
                        font.pixelSize: 14
                        wrapMode: Text.Wrap
                        color: Colors.color_EEEEEE
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        radius: 2
                        height: 4
                        color: Colors.color_454649
                        Rectangle {
                            radius: 2
                            height: 4
                            width: parent.width * (1.0 * userFeedbackUploadLoading.progress / 100)
                            color: ColorsConfig.color_brand
                        }
                    }
                    IconTextButton {
                        usePreferredWidth: true
                        Layout.preferredWidth: 88
                        Layout.preferredHeight: 28
                        Layout.alignment: Qt.AlignHCenter
                        title: qsTr("pccut_feedback_log_automatic_uploading_cancel")
                        titleColorNormal: Colors.color_FFFFFF
                        backgroundColorNormal: Colors.color_68696D
                        backgroundColorHover: Colors.color_7A7B80
                        isTextOnly: true
                        leftPadding: 6
                        rightPadding: 6
                        onCustomClicked: {
                            feedBackManager.cancelSendResource()
                            feedBackShowFlag=1
                        }
                    }
                }

            }

        }

        // 反馈结果展示
        Rectangle{
            id:feedBackShowRec
            // 提交界面关闭以后展示这个界面
            visible: feedBackShowFlag === 3

            anchors {
                fill:parent
                topMargin: 64
                leftMargin: 28
                rightMargin: 28
                bottomMargin: 28
            }
            color: Colors.color_transparent


            // 此控件一共三个部分，分别是状态展示图界面、信息提示部分、交互按钮部分

            // 展示图有两个状态分别是成功和失败，组合都是图标和文字的组合
            Item{
                id: feedBackStatusItem
                height: 86
                width: 96

                anchors{
                    top:parent.top
                    topMargin: 56
                    horizontalCenter: parent.horizontalCenter
                }

                Rectangle{
                    width: 96
                    height: parent.height
                    anchors.centerIn: parent
                    color: Colors.color_transparent
                    Rectangle{
                        width: 56
                        height: 56
                        color: Colors.color_transparent
                        anchors{
                            top:parent.top
                            horizontalCenter: parent.horizontalCenter
                        }
                        Image{
                            anchors.fill: parent
                            source: "qrc:/icons/icon_feedback_sucess.svg"
                            fillMode: Image.PreserveAspectCrop
                        }
                    }

                    Text {
                        anchors{
                            bottom: parent.bottom
                            horizontalCenter: parent.horizontalCenter
                        }
                        font.pixelSize: 16
                        color: Colors.color_32E494
                        text: qsTr("pccut_feedback_log_upload_id_success")
                    }
                }
            }

            // 提示信息部分
            Item{
                id:feedBackMsgItem
                width: 304
                height: 68
                anchors{
                    top:parent.top
                    topMargin: 208
                    horizontalCenter: parent.horizontalCenter
                }

                Rectangle{
                    // 背景颜色、样式等
                    anchors{
                        fill:parent
                        bottomMargin: 28
                    }

                    radius: 8
                    color: Colors.color_1f2021
                    // 做一个水平布局，然后展示反馈ID、FEEDID、 复制按钮
                    RowLayout{
                        // title
                        Text{

                            Layout.fillHeight: true
                            Layout.topMargin: 12
                            Layout.leftMargin: 8
                            text: qsTr("pccut_feedback_log_upload_id")+":"
                            font.pixelSize: 12
                            color: Colors.color_666666
                        }

                        Text{
                            id:feedBackIdText
                            Layout.fillHeight: true
                            Layout.topMargin: 12
                            text:""
                            font.pixelSize: 12
                            color: Colors.color_EEEEEE
                        }
                    }

                    // copyBtn
                    Rectangle{
                        width: 16
                        height: 16

                        anchors{
                            top:parent.top
                            topMargin: 12
                            right:parent.right
                            rightMargin: 16
                        }
                        color: Colors.color_transparent
                        Image{
                            anchors.fill: parent
                            source: feedBackCopyBtnMouseArea.containsMouse?"qrc:/icons/icon_copy_hover.svg":"qrc:/icons/icon_copy.svg"
                            fillMode: Image.PreserveAspectCrop
                        }
                        MouseArea{
                            id:feedBackCopyBtnMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                feedBackManager.copyFeedBackId(feedBackIdText.text)
                                toast.showToast(qsTr("pccut_feedback_log_upload_id_copy"))
                            }
                        }
                    }

                    Text {
                        anchors.top: parent.bottom
                        anchors.topMargin: 12
                        font.pixelSize: 12
                        color: Colors.color_EEEEEE
                        text: qsTr("pccut_feedback_log_upload_id_tip")
                    }
                }
            }

            // 交互按钮部分
            Rectangle{
                // 布局效果
                width: parent.width
                height: 28
                anchors{
                    top:parent.top
                    topMargin: 356
                }
                color: Colors.color_transparent
                Item {
                    id:sucessBtn
                    anchors.fill: parent

                    IconTextButton {
                        title: qsTr("pccut_feedback_log_upload_pack_back")
                        isTextOnly: true
                        height: 28
                        width:88
                        anchors{
                            verticalCenter: parent.verticalCenter
                            right:parent.right
                            rightMargin: 160
                        }
                        titleColorNormal: Colors.color_EEEEEE
                        titleColorHover: Colors.color_FFFFFF
                        backgroundColorNormal: Colors.color_68696D
                        backgroundColorHover: Colors.color_7A7B80
                        checkable: true
                        leftPadding: 12
                        rightPadding: 12
                        topPadding: 3
                        bottomPadding: 3
                        enabled: true
                        hoverEnabled: true
                        onClicked: {
                            popup.close()
                        }
                    }

                    // addNewFeedBackBtn 反馈成功展示
                    IconTextButton {
                        title: qsTr("pccut_feedback_log_upload_resubmit")
                        width:88
                        isTextOnly: true
                        height: 28
                        anchors{
                            verticalCenter: parent.verticalCenter
                            left:parent.left
                            leftMargin: 160
                        }
                        titleColorNormal: Colors.color_EEEEEE
                        titleColorHover: Colors.color_FFFFFF
                        backgroundColorNormal: Colors.color_F22443
                        backgroundColorHover: Colors.color_F44C65

                        checkable: true
                        leftPadding: 12
                        rightPadding: 12
                        topPadding: 3
                        bottomPadding: 3
                        enabled: true
                        hoverEnabled: true
                        onClicked: {
                            forceActiveFocus()
                            globalSignal.reducePopupQuantity()
                            isClosedOrDestruction = false

                            feedBackShowFlag = 1
                            sceneModel.clear()
                            for (let i = 0 ;i < scene.length; ++i) {
                                sceneModel.append({"code": i, "title": qsTr(scene[i])})
                            }
                            feedBackManager.init()
                            descriptionInput.text = ""
                            contactInput.text = ""
                            deviceModelComboBox.currentIndex = 0
                            isClosedOrDestruction = true
                            logUploadReflush.visible = false
                            ShortcutObserver.disableAllShortcut(true)
                            globalSignal.addPopupQuantity()
                            if(!isInEURegion) {
                                feedBackManager.packResource()
                            }
                            // 回到最上
                            feedBackContent.contentY = 0
                        }
                    }
                }
            }
        }

        Flickable {
            id:feedBackContent
            visible: feedBackShowFlag === 1
            anchors {
                fill: parent
                topMargin: 64
                leftMargin: 4
                rightMargin: 4
            }
            contentHeight: content.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    forceActiveFocus()
                }
            }
            ScrollBar.vertical: ScrollBar{
                id:feedbackVerScrollBar
                policy: ScrollBar.AsNeeded
                height: feedBackContent.height-4
                bottomPadding:4
                rightPadding:0
                contentItem: Rectangle {
                    id:contentRectangle
                    implicitWidth: 6
                    radius: height/2
                    color: feedbackVerScrollBar.active ? Colors.color_575A5B_100 : Colors.color_414344_100
                }
            }
            ColumnLayout {
                id: content
                width: parent.width - 48
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 0
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 16
                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("*")
                        font.pixelSize: 12
                        Layout.alignment: Qt.AlignVCenter
                        color: ColorsConfig.color_brand
                    }
                    HoverableText {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 10
                        anchors.right: parent.right
                        text: qsTr("pccut_feedback_scene")
                        font.pixelSize: 12
                        Layout.alignment: Qt.AlignVCenter
                        color: Colors.color_EEEEEE
                        elide: Text.ElideRight
                        maxTextWidth: parent.width
                        cursorChanged: false
                        noWarp: true
                        lineCount: 1
                    }
                }

                Flow {
                    id: sceneSelect
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    spacing: 8
                    Repeater {
                        model: sceneModel
                        IconTextButton {
                            id: sceneButton
                            title: model.title
                            isTextOnly: true
                            titleColorNormal: Colors.color_EEEEEE
                            titleColorHover: Colors.color_EEEEEE
                            titleColorPressed: Colors.color_141414
                            titleColorChecked: Colors.color_141414
                            backgroundColorNormal: Colors.color_454649
                            backgroundColorHover: Colors.color_56575B
                            backgroundColorPressed: ColorsConfig.color_EEEEEE_4DFFC9
                            backgroundColorChecked: ColorsConfig.color_EEEEEE_4DFFC9
                            checkable: true
                            leftPadding: 8
                            rightPadding: 8
                            topPadding: 6
                            bottomPadding: 6
                            onClicked: {
                                forceActiveFocus()
                            }

                            Component.onCompleted: {
                                sceneButtonGroup.addButton(this)
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 16
                    Layout.topMargin: 28
                    spacing: 6
                    Text {
                        text: "*"
                        font.pixelSize: 12
                        Layout.alignment: Qt.AlignVCenter
                        color: ColorsConfig.color_brand
                    }
                    Text {
                        text: qsTr("pccut_feedback_log_device_list") + ":"
                        font.pixelSize: 12
                        Layout.alignment: Qt.AlignVCenter
                        color: Colors.color_EEEEEE
                    }
                }
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    Layout.topMargin: 12
                    Rectangle {
                        anchors.fill: parent
                        radius: 8
                        color: deviceModelComboBox.hovered ? Colors.color_56575B : Colors.color_454649
                        height: 40
                    }
                    ComboBox {
                        id: deviceModelComboBox
                        anchors.fill: parent
                        model: popup.deviceModels

                        indicator: Image {
                            anchors {
                                right: parent.right
                                rightMargin: 8
                                verticalCenter: parent.verticalCenter
                            }
                            width: 20
                            height: 20
                            source: deviceModelComboBox.popup.visible
                                    ? "qrc:/icons/ic_open_triangle.svg"
                                    : "qrc:/icons/ic_close_triangle.svg"
                            sourceSize: Qt.size(width, height)
                        }

                        contentItem: Text {
                            leftPadding: 8
                            rightPadding: 28
                            text: deviceModelComboBox.currentIndex === -1
                                  ? qsTr("pccut_feedback_log_device_list_default")
                                  : deviceModelComboBox.displayText
                            font.pixelSize: 12
                            color: deviceModelComboBox.currentIndex === -1 ? Colors.color_999999 : Colors.color_EEEEEE
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }

                        background: Item {}

                        delegate: Rectangle {
                            id: deviceDelegate
                            property bool isHovered: false
                            x: 4
                            width: deviceModelListView.width - 4 - (deviceListScrollBar.visible ? deviceListScrollBar.width + 2 : 4)
                            radius: 4
                            height: 28
                            color: isHovered ? Colors.color_56575B : Colors.transparent

                            Row {
                                anchors.fill: parent
                                spacing: 0
                                Item {
                                    width: 28
                                    height: 28
                                    Image {
                                        anchors.centerIn: parent
                                        visible: index === deviceModelComboBox.currentIndex
                                        width: 16
                                        height: 16
                                        source: "qrc:/app_qrc/icons/icon_checkbox_check.svg"
                                        sourceSize: Qt.size(16, 16)
                                    }
                                }
                                Text {
                                    width: deviceDelegate.width - 28
                                    height: 28
                                    text: modelData
                                    font.pixelSize: 11
                                    color: Colors.color_EEEEEE
                                    verticalAlignment: Text.AlignVCenter
                                    elide: Text.ElideRight
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onEntered: deviceDelegate.isHovered = true
                                onExited: deviceDelegate.isHovered = false
                                onClicked: {
                                    deviceModelComboBox.currentIndex = index
                                    deviceModelComboBox.popup.close()
                                }
                            }
                        }

                        popup: Popup {
                            y: deviceModelComboBox.height + 4
                            width: deviceModelComboBox.width
                            height: Math.min(deviceModelListView.contentHeight, 170) + topPadding + bottomPadding
                            topPadding: 4
                            bottomPadding: 4
                            leftPadding: 0
                            rightPadding: deviceListScrollBar.visible ? 2 : 0

                            contentItem: ListView {
                                id: deviceModelListView
                                clip: true
                                model: deviceModelComboBox.delegateModel
                                currentIndex: deviceModelComboBox.currentIndex

                                ScrollBar.vertical: ScrollBar {
                                    id: deviceListScrollBar
                                    visible: deviceModelListView.contentHeight > deviceModelListView.height
                                    anchors.rightMargin: 4
                                    contentItem: Rectangle {
                                        implicitWidth: 6
                                        radius: height / 2
                                        color: deviceListScrollBar.active ? Colors.color_68696D : Colors.color_56575B
                                    }
                                }
                            }

                            background: Rectangle {
                                color: Colors.color_454649
                                radius: 8
                            }
                        }

                        Keys.onPressed: (event) => { event.accepted = true }
                        Keys.onReleased: (event) => { event.accepted = true }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 16
                    Layout.topMargin: 28
                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("*")
                        font.pixelSize: 12
                        Layout.alignment: Qt.AlignVCenter
                        color: ColorsConfig.color_brand
                    }
                    HoverableText {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 10
                        anchors.right: parent.right
                        text: qsTr("pccut_feedback_problem")
                        font.pixelSize: 12
                        Layout.alignment: Qt.AlignVCenter
                        color: Colors.color_EEEEEE
                        elide: Text.ElideRight
                        maxTextWidth: parent.width
                        cursorChanged: false
                        noWarp: true
                        lineCount: 1
                    }
                }
                Rectangle {
                    radius: 8
                    color: Colors.color_1F2021
                    Layout.topMargin: 12
                    Layout.fillWidth: true
                    Layout.preferredHeight: 108
                    Flickable {
                        id: descriptionFilckable
                        interactive: contentHeight > height
                        anchors {
                            fill: parent
                            topMargin: 8
                            leftMargin: 6
                            rightMargin: 8
                            bottomMargin: 26
                        }
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        TextArea.flickable: TextArea {
                            id: descriptionInput
                            // 设置文本的对齐方式
                            horizontalAlignment: TextInput.AlignLeft
                            verticalAlignment: TextInput.AlignTop
                            // 选择文本的字体和颜色
                            font.pixelSize: 12
                            // 按住鼠标左键选择文本
                            selectByMouse: true
                            selectionColor: Colors.color_EEEEEE // 选中文本的背景色
                            selectedTextColor: Colors.color_000000_70   // 选中文本的颜色
                            color: Colors.color_EEEEEE
                            wrapMode: Text.WrapAnywhere
                            padding: 0

                            property bool isDefaultText: text === ""
                            onTextChanged: {
                                if (descriptionInput.text.length > 200) {
                                    var cursorPos = cursorPosition
                                    descriptionInput.text = descriptionInput.text.substring(0, 200)
                                    cursorPosition = Math.min(cursorPos, 200)
                                }
                            }
                        }
                    }
                    Text {
                        anchors {
                            right: parent.right
                            bottom: parent.bottom
                            rightMargin: 8
                            bottomMargin: 6
                        }
                        font.pixelSize: 12
                        color: Colors.color_666666
                        text: descriptionInput.length + "/" + "200"
                    }

                    Text {
                        anchors.fill: descriptionFilckable
                        anchors.leftMargin: 4
                        text: qsTr("pccut_feedback_problem_description")
                        color: Colors.color_666666
                        wrapMode: Text.Wrap
                        visible: descriptionInput.text === "" && !descriptionInput.focus
                        font.pixelSize: 12
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 16
                    Layout.topMargin: 28
                    spacing: 6
                    Text {
                        text: qsTr("pccut_feedback_problem_upload")
                        font.pixelSize: 12
                        Layout.alignment: Qt.AlignVCenter
                        color: Colors.color_EEEEEE
                    }
                }
                Rectangle {
                    radius: 8
                    color: Colors.color_1F2021
                    Layout.topMargin: 12
                    Layout.fillWidth: true
                    Layout.preferredHeight: 72
                    FileDialog {
                        id: fileDialog
                        nameFilters: ["(*.mp4 *.mov *.jpg *.png)"]
                        onAccepted: {
                            let size = Tools.getFileSize(selectedFile) / (1024 * 1024)
                            if (size > 200) {
                                toast.showToast(qsTr("pccut_feedback_log_limit"))
                            } else {
                                feedBackManager.sendMedia(selectedFile)
                            }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: feedBackManager.mediaUploadProgress < 0
                        onClicked: {
                            fileDialog.open()
                        }
                    }
                    RowLayout {
                        anchors{
                            verticalCenter: parent.verticalCenter
                            left: parent.left
                            right: parent.right
                            leftMargin: 8
                            rightMargin: 16
                        }
                        spacing: 0
                        LightClipRectangle {
                            id: coverItem
                            Layout.preferredWidth: 56
                            Layout.preferredHeight: 56
                            property bool hasCover: false
                            property bool isUploading: false
                            radius: [4, 4, 4, 4]
                            color: Colors.transparent
                            Connections {
                                target: popup.feedBackManager

                                function onMediaUploadProgressChanged() {
                                    if (feedBackManager.mediaUploadProgress < 0) {
                                        mediaUploadProgressTimer.stop()
                                        coverItem.isUploading = false
                                    } else if (feedBackManager.mediaUploadProgress < 100) {
                                        mediaUploadProgressTimer.stop()
                                        coverItem.isUploading = true
                                    } else {
                                        mediaUploadProgressTimer.start()
                                    }
                                }
                            }
                            Timer {
                                id: mediaUploadProgressTimer
                                interval: 500
                                running: false
                                onTriggered: {
                                    coverItem.isUploading = false
                                }
                            }
                            Image {
                                id: coverImage
                                anchors.centerIn: parent
                                source: coverItem.isUploading || feedBackManager.mediaUploadProgress >= 100
                                        ? "image://image_provider/" + feedBackManager.mediaUploadPath + ";0;0;0;1;1"
                                        : "qrc:/icons/icon_feedback_video.svg"
                                width: coverItem.isUploading || feedBackManager.mediaUploadProgress >= 100 ? parent.width : 24
                                height: coverItem.isUploading || feedBackManager.mediaUploadProgress >= 100 ? parent.height : 24
                                fillMode: Image.PreserveAspectCrop
                            }
                            Canvas {
                                id: canvas
                                anchors.fill: parent
                                visible: feedBackManager.mediaUploadProgress < 0
                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.reset()

                                    // 矩形参数
                                    var x = 1
                                    var y = 1
                                    var width = parent.width - 2 * x
                                    var height = parent.height - 2 * y
                                    var radius = 4

                                    // 虚线样式
                                    ctx.setLineDash([2, 1.5]) // 5像素实线，3像素空白
                                    ctx.lineWidth = 2
                                    ctx.strokeStyle = Colors.color_454649

                                    // 绘制圆角矩形
                                    ctx.beginPath()
                                    ctx.moveTo(x + radius, y)
                                    ctx.lineTo(x + width - radius, y)
                                    ctx.arcTo(x + width, y, x + width, y + radius, radius)
                                    ctx.lineTo(x + width, y + height - radius)
                                    ctx.arcTo(x + width, y + height, x + width - radius, y + height, radius)
                                    ctx.lineTo(x + radius, y + height)
                                    ctx.arcTo(x, y + height, x, y + height - radius, radius)
                                    ctx.lineTo(x, y + radius)
                                    ctx.arcTo(x, y, x + radius, y, radius)
                                    ctx.closePath()

                                    ctx.stroke()
                                }
                            }
                        }

                        ColumnLayout {
                            visible: !coverItem.isUploading
                            Layout.alignment: Qt.AlignVCenter
                            Layout.fillWidth: true
                            Layout.leftMargin: 12
                            Text {
                                Layout.fillWidth: true
                                color: Colors.color_EEEEEE
                                font.pixelSize: 12
                                text: feedBackManager.mediaUploadProgress < 0 ? qsTr("pccut_feedback_problem_upload_description") : Tools.getFileNameFromPath(feedBackManager.mediaUploadPath)
                                elide: Text.ElideRight
                            }
                            Text {
                                id: fileDescriptionText
                                Layout.fillWidth: true
                                color: Colors.color_454649
                                font.pixelSize: 12
                                text: feedBackManager.mediaUploadProgress < 0 ? qsTr("pccut_feedback_problem_limit") : Math.max((Math.round(feedBackManager.mediaFileSize * 10) / 10), 0.1) + "MB"
                            }
                        }

                        ColumnLayout {
                            visible: coverItem.isUploading
                            Layout.alignment: Qt.AlignVCenter
                            Layout.preferredWidth: 180
                            Layout.preferredHeight: 56
                            Layout.leftMargin: 12
                            Text {
                                Layout.fillWidth: true
                                id: uploadFileName
                                text: Tools.getFileNameFromPath(feedBackManager.mediaUploadPath)
                                color: Colors.color_EEEEEE
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }
                            ProgressBar {
                                id: videoUploadProgress
                                Layout.fillWidth: true
                                Layout.preferredHeight: 2

                                value: feedBackManager.mediaUploadProgress / 100.0
                                from: 0
                                to: 1
                                // 设置背景矩形的颜色
                                background: Rectangle {
                                    implicitWidth: parent.width
                                    implicitHeight: parent.height
                                    color: Colors.color_454649
                                    radius: parent.height / 2
                                }

                                // 设置进度矩形的颜色
                                contentItem: Item {
                                    Rectangle {
                                        width: videoUploadProgress.value * parent.width
                                        height: parent.height
                                        color: ColorsConfig.color_brand
                                        radius: parent.height / 2
                                    }
                                }
                            }
                            Text {
                                id: mediaUploadProgress
                                Layout.preferredWidth: 170
                                text: feedBackManager.mediaUploadProgress < 100
                                      ? qsTr("pccut_feedback_log_uploading") + " " + Math.min(100, feedBackManager.mediaUploadProgress) + "%"
                                      : qsTr("pccut_feedback_log_automatic_finish") + " 100%"
                                color: Colors.color_EEEEEE
                                font.pixelSize: 12
                            }
                        }
                        Image {
                            visible: coverItem.isUploading || feedBackManager.mediaUploadProgress >= 100
                            Layout.alignment: Qt.AlignVCenter
                            Layout.leftMargin: 16
                            Layout.preferredWidth: 16
                            Layout.preferredHeight: 16
                            source: cancelUploadArea.containsMouse ? "qrc:/icons/icon_export_task_delete_hover.svg" : "qrc:/icons/icon_export_task_delete.svg"
                            sourceSize: Qt.size(16, 16)
                            MouseArea {
                                id: cancelUploadArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    feedBackManager.cancelSendMedia()
                                }
                            }
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 16
                    Layout.topMargin: 28
                    spacing: 6
                    visible: !popup.isInEURegion
                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        text: qsTr("pccut_feedback_log")
                        font.pixelSize: 12
                        color: Colors.color_EEEEEE
                    }
                }
                RowLayout {
                    Layout.topMargin: 12
                    Layout.fillWidth: true
                    visible: !popup.isInEURegion
                        Text {
                            id: reportUploadProgress
                        Layout.alignment: Qt.AlignVCenter
                        Layout.fillWidth: true
                            text: qsTr("pccut_feedback_log_upload_pack")
                            Connections {
                                target: popup.feedBackManager

                                function onReportFileSizeChanged() {
                                    if (!feedBackManager.packFinished) {
                                        reportUploadProgress.text = qsTr("pccut_feedback_log_upload_pack")
                                    } else {
                                        reportUploadProgress.text = Tools.getFileNameFromPath(feedBackManager.reportUploadPath) + " | " + Math.max((Math.round(feedBackManager.reportFileSize * 10) / 10), 0.1) + "MB"
                                    }
                                }
                            }

                            color: Colors.color_999999
                        }
                    Item {
                        id: logUploadReflush
                        Layout.preferredWidth: childrenRect.width
                        Layout.preferredHeight: childrenRect.height
                        visible: false
                        Image {
                            anchors.right: logUploadReflushText.left
                            anchors.rightMargin: 4
                            y: logUploadReflushText.y + 1.0 * (logUploadReflushText.height - height) / 2
                            source: logUploadReflushArea.containsMouse ? "qrc:/icons/icon_resert_hover.svg" : "qrc:/icons/icon_resert.svg"
                        }
                        Text {
                            id: logUploadReflushText
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            color: logUploadReflushArea.containsMouse ? Colors.color_FFFFFF : Colors.color_EEEEEE
                            text: qsTr("pccut_feedback_retry")
                        }
                        MouseArea {
                            id: logUploadReflushArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                logUploadReflush.visible = false
                                feedBackManager.packResource()
                            }
                        }
                        Connections {
                            target: popup.feedBackManager

                            function onLogPackFailed() {
                                logUploadReflush.visible = true
                            }
                        }
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.fillWidth: true
                    text: qsTr("pccut_permissions_product_text_6")
                    maximumLineCount: 3
                    wrapMode: Text.WordWrap
                    color: Colors.color_666666
                    font.pixelSize: 11
                    Layout.topMargin: 8
                    visible: !popup.isInEURegion
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 16
                    Layout.topMargin: 28
                    spacing: 6
                    Text {
                        text: qsTr("pccut_feedback_contact")
                        font.pixelSize: 12
                        Layout.alignment: Qt.AlignVCenter
                        color: Colors.color_EEEEEE
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    Layout.topMargin: 12
                    TextField {
                        id: contactInput
                        anchors.fill: parent
                        // 设置文本的对齐方式
                        horizontalAlignment: TextInput.AlignLeft
                        verticalAlignment: TextInput.AlignVCenter
                        // 选择文本的字体和颜色
                        font.pixelSize: 12
                        // 按住鼠标左键选择文本
                        selectByMouse: true
                        selectionColor: Colors.color_EEEEEE // 选中文本的背景色
                        selectedTextColor: Colors.color_000000_70   // 选中文本的颜色
                        color: Colors.color_EEEEEE
                        maximumLength: inChina ? 11 : 200
                        property bool isDefaultText: text === ""
                        validator: RegularExpressionValidator {
                                regularExpression: popup.inChina ? /^[0-9]*$/ : /^[a-zA-Z0-9@._-]*$/
                            }
                        background: Rectangle {
                            radius: 8
                            color: Colors.color_1F2021
                        }
                        leftPadding: 8
                        rightPadding: 8
                        onActiveFocusChanged: {
                            if (!focus && inChina && text.length !== 11 && text.length !== 0) {
                                toast.showToast(qsTr("pccut_feedback_number_right"))
                            }
                        }
                    }

                    Text {
                        anchors.left: contactInput.left
                        anchors.verticalCenter: contactInput.verticalCenter
                        anchors.leftMargin: 6
                        text: inChina ? qsTr("pccut_feedback_number") : qsTr("pccut_feedback_email")
                        color: Colors.color_666666
                        visible: contactInput.text === "" && !contactInput.focus
                        font.pixelSize: 12
                    }
                }

                Loader {
                    id: improveSchemeConfirmLoader
                    onLoaded: {
                        // 弹出的模态窗口关闭时触发,卸载掉loader的source
                        if (improveSchemeConfirmLoader.item) {
                            improveSchemeConfirmLoader.item.onClosed.connect(function() {
                                improveSchemeConfirmLoader.sourceComponent = null
                            });
                        }
                    }
                }

                Component {
                    id: improveSchemeConfirm
                    ConfirmPopup {
                        title: qsTr("pccut_feedback_submit_settings_product_tex")
                        leftButtonText: qsTr("pccut_feedback_submit_settings_product_cancel")
                        rightButtonText: qsTr("pccut_feedback_submit_settings_product_agree_submit")
                        onRightButtonClicked: {
                            lightSetting.save("needReport", true);
                            eventTracker.enable(true)
                            eventTracker.trackEvent("pccut_feedback_submit_settings_product_agree_submit")
                            crashTrackHelper.enableUploadEvent(true);
                            showUserFeedBackLoading(sceneButtonGroup.checkedButton.title,
                                                    descriptionInput.isDefaultText ? "" : descriptionInput.text,
                                                    contactInput.isDefaultText ? "" : contactInput.text,
                                                    deviceModelComboBox.currentText)
                        }
                    }
                }

                IconTextButton {
                    isTextOnly: true
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    Layout.topMargin: 28
                    Layout.bottomMargin: 28
                    alignment: Qt.AlignHCenter
                    title: qsTr("pccut_feedback_submit")
                    titleColorNormal: Colors.color_141414
                    backgroundColorNormal: ColorsConfig.color_EEEEEE_4DFFC9
                    backgroundColorHover: ColorsConfig.color_FFFFFF_6DFFD3
                    backgroundColorPressed: ColorsConfig.color_EEEEEE20_4DFFC920
                    backgroundColorDisable: Colors.color_454649
                    enabled: !descriptionInput.isDefaultText
                             && descriptionInput.text !== ""
                             && sceneButtonGroup.checkedButton !== null
                             && deviceModelComboBox.currentIndex !== -1
                             && (!inChina || contactInput.isDefaultText || contactInput.text.length === 0 || contactInput.text.length === 11)
                             && (feedBackManager.mediaUploadProgress < 0 || feedBackManager.mediaUploadProgress >= 100)
                             && (feedBackManager.resourceUploadProgress < 0 || feedBackManager.resourceUploadProgress >= 100)
                             && feedBackManager.packFinished
                    hoverEnabled: true
                    onClicked: {
                        if (Tools.checkNetworkAccessible() === false) {
                            toast.showToast(qsTr("pccut_feedback_no_network"))
                            return
                        }
                        if (lightSetting.getBool("needReport", false)) {
                             showUserFeedBackLoading(sceneButtonGroup.checkedButton.title,
                                                     descriptionInput.isDefaultText ? "" : descriptionInput.text,
                                                     contactInput.isDefaultText ? "" : contactInput.text,
                                                     deviceModelComboBox.currentText)
                        } else {
                            // 如果是欧盟地区，不去提示打开用户改进计划，直接上传
                            if(popup.isInEURegion) {
                                showUserFeedBackLoading(sceneButtonGroup.checkedButton.title,
                                                        descriptionInput.isDefaultText ? "" : descriptionInput.text,
                                                        contactInput.isDefaultText ? "" : contactInput.text,
                                                        deviceModelComboBox.currentText)
                            }
                            else {
                                improveSchemeConfirmLoader.sourceComponent = improveSchemeConfirm
                                improveSchemeConfirmLoader.item.open()
                            }
                        }
                    }
                }
            }
        }
    }
}
