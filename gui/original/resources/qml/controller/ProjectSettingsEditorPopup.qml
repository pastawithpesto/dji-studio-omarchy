import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls
import Config 1.0
import Controls 1.0
import VideoConfig 1.0
import ProjectSettingsInfo 1.0
import Qt5Compat.GraphicalEffects
import "../menubar"
import QmlConstants 1.0

LightPopup {
    id: pop
    width: lightWindow.width
    height: lightWindow.height
    dim: false
    // width: 360
    // height: 362 + proxyModeTipText.height

    //required property ProjectSettingsInfo initInfo

    // 信息源：name/useMaterialProxy 由 ProjectSettingsInfo 自权威读 nle/legacy；
    // nle 没有的属性 (composePath/canvasType/colorSpaceType/fps) 经 editorManager 喂给它
    ProjectSettingsInfo {
        id: editorInfo

        composePath: editorManager.draftDir
        canvasType: editorManager.canvasType
        colorSpaceType: editorManager.colorSpaceType
        fps: editorManager.fps
    }

    // 待确认编辑缓冲：从 editorInfo 取初值，确认前不写入任何后端，取消即丢弃
    property string editName: editorInfo.name
    property string editComposePath: editorInfo.composePath
    property int editCanvasType: editorInfo.canvasType
    property int editColorSpaceType: editorInfo.colorSpaceType
    property int editFps: editorInfo.fps
    property bool editUseMaterialProxy: editorInfo.useMaterialProxy

    readonly property string editCanvasTypeName: videoConfig.getNameByCanvasType(editCanvasType)
    readonly property string editColorSpaceName: videoConfig.getItemByColorSpaceType(editColorSpaceType)

    signal projectSettingsChanged(var updateInfo)

    // open后，屏蔽不让下面的窗口响应
    onOpened: {
        content.enabled = false;
    }

    onClosed: {
        content.enabled = true;
    }

    contentItem: Item{
        MouseArea {
            anchors.fill: parent
            onClicked: {
                //closeSignal();
                //close();
            }
        }
        Rectangle {
            id: popContent
            width: 360
            // height: 372 + proxyModeTipText.height
            height: 372
            anchors.verticalCenter: parent.verticalCenter
            anchors.horizontalCenter: parent.horizontalCenter
            radius: 8
            clip: true
            color: Colors.color_2F3032
            border.width:1
            border.color:Colors.color_454649
            MouseArea {
                anchors.fill: parent
                onClicked: {}
            }

            Item {
                id: popBackground
                anchors.fill: parent
                clip: true

                WindowTitleBar {
                    id: titleBar
                    height: 40
                    width: parent.width
                    title: qsTr("pccut_project_modify_settings")
                    onCloseClick: {
                        close();
                    }
                }

                Item {
                    id: actionButton
                    height: 72
                    width: 184

                    anchors {
                        right: parent.right
                        bottom: parent.bottom
                        rightMargin: 28
                        bottomMargin: 24
                    }
                    
                    BaseConfirmBtn {
                        id: confirmBtn
                        btnText:qsTr("pccut_project_modify_yes")
                        width: 88
                        height: 28
                        type: 0
                        anchors {
                            right: parent.right
                            bottom: parent.bottom
                        }
                        onCustomClick:() => {
                            confirm();
                        }
                    }

                    BaseConfirmBtn {
                        id: cancelBtn
                        btnText:qsTr("pccut_draft_delete_popup_cancel")
                        width: 88
                        height: 28
                        type: 1
                        anchors {
                            left: parent.left
                            bottom: parent.bottom
                        }
                        onCustomClick:() => {
                            cancel();
                        }
                    }
                }

                Rectangle {
                    anchors {
                        top: titleBar.bottom
                        bottom: actionButton.top
                        left: parent.left
                        right: parent.right
                        leftMargin: 28
                        rightMargin: 28
                    }
                    radius: 8
                    color: Colors.color_transparent

                    // 这里的UI设计非常随意，每一行的高度是不一致的，如果是输入框或者选择框就是28，如果是普通文本就是普通文本本身的高度
                    Item {
                        // 水平间隔
                        property real hItemMargin: 12
                        // 垂直间隔
                        property real vItemMargin: 16
                        // 标题对齐线
                        property real labelGuideline: Math.max(projectNameTitleText.width, savePathTitleText.width, canvasTitleText.width, proxyModeTitleText.width) + hItemMargin
                        anchors {
                            fill: parent
                            topMargin: 24
                        }

                        //项目名称
                        BaseTextField{
                            id:projectNameTitleText
                            titleText:qsTr("pccut_project_info_name")
                            maxLength: 50
                            height:28
                            anchors {
                                left: parent.left
                                leftMargin: 0
                                right: parent.right
                                rightMargin:0
                            }

                            // 显示源派生属性：editName 变化时自动重算
                            readonly property string _displayName: pop.editName
                            on_DisplayNameChanged: setText(_displayName)
                            Component.onCompleted: setText(_displayName)

                            onTextValueChanged:(value) => {
                                pop.editName = value;
                            }

                        }

                        // 保存位置
                        BaseText{
                            id:savePathTitleText
                            titleText:qsTr("pccut_project_info_path")
                            contentText:pop.editComposePath
                            height:28
                            anchors {
                                left: parent.left
                                leftMargin: 0
                                right: parent.right
                                rightMargin:0
                                top: projectNameTitleText.bottom
                                topMargin: parent.vItemMargin
                            }
                            MouseArea {
                                id: area
                                anchors.fill: parent
                                hoverEnabled: true

                                onEntered: {
                                    hoverTimer.start();
                                }
                                onExited: {
                                    hoverTimer.stop();
                                    composePathInfo.hide();
                                }
                            }
                            Timer {
                                id: hoverTimer
                                // hover之后保持N毫秒后展示完整路径
                                interval: 600
                                repeat: false
                                onTriggered: {
                                    if (!composePathInfo.isShow) {
                                        var mousePos = area.mapToItem(popContent,area.mouseX, area.mouseY);
                                        composePathInfo.show(mousePos, pop.editComposePath);
                                    }
                                }
                            }
                        }
                        // 画幅比例
                        BaseSelectionBox{
                            id:canvasValueBox
                            titleText:qsTr("pccut_project_info_ratio")
                            contentText:pop.editCanvasTypeName
                            selectedItem:pop.editCanvasType
                            height:28
                            anchors {
                                left: parent.left
                                leftMargin: 0
                                right: parent.right
                                rightMargin:0
                                top: savePathTitleText.bottom
                                topMargin: parent.vItemMargin
                            }
                            onChangeSelect:(itemType) => {
                                valueTextCom.hide();
                                editorManager.setCanvasManualChanged(true);
                                pop.editCanvasType = itemType;
                            }
                            ListModel {
                                id: canvasMenu
                                Component.onCompleted: {
                                    // 通过append动态添加数据项
                                    append({ 
                                        title: videoConfig.getQmlItemByCanvasType(VideoConfig.CANVASRATIOTYPE_16_9).name, 
                                        type: VideoConfig.CANVASRATIOTYPE_16_9, 
                                        checked: false 
                                    });
                                    append({ 
                                        title: videoConfig.getQmlItemByCanvasType(VideoConfig.CANVASRATIOTYPE_9_16).name, 
                                        type: VideoConfig.CANVASRATIOTYPE_9_16, 
                                        checked: false 
                                    });
                                    append({ 
                                        title: videoConfig.getQmlItemByCanvasType(VideoConfig.CANVASRATIOTYPE_1_1).name, 
                                        type: VideoConfig.CANVASRATIOTYPE_1_1, 
                                        checked: false 
                                    });
                                    append({ 
                                        title: videoConfig.getQmlItemByCanvasType(VideoConfig.CANVASRATIOTYPE_4_3).name, 
                                        type: VideoConfig.CANVASRATIOTYPE_4_3, 
                                        checked: false 
                                    });
                                    append({ 
                                        title: videoConfig.getQmlItemByCanvasType(VideoConfig.CANVASRATIOTYPE_3_4).name, 
                                        type: VideoConfig.CANVASRATIOTYPE_3_4, 
                                        checked: false 
                                    });
                                    canvasValueBox.setMenus(canvasMenu);
                                }
                            }
                        }

                        //色彩空间
                        BaseSelectionBox{
                            id: colorSpaceBox
                            titleText:qsTr("pccut_hdr_project_setting_colorspace_label")
                            contentText:pop.editColorSpaceName
                            selectedItem:pop.editColorSpaceType
                            visible: !CommonUtils.isWindows()
                            height:28
                            anchors {
                                left: parent.left
                                leftMargin: 0
                                right: parent.right
                                rightMargin:0
                                top: canvasValueBox.bottom
                                topMargin: parent.vItemMargin
                            }
                            onChangeSelect:(itemType) => {
                                valueTextCom.hide();
                                pop.editColorSpaceType = itemType;
                            }
                            ListModel {
                                id: colorSpaceMenu
                                Component.onCompleted: {
                                    // 通过append动态添加数据项
                                    append({
                                        title: videoConfig.getItemByColorSpaceType(VideoConfig.SDR_Rec709),
                                        type: VideoConfig.SDR_Rec709,
                                        checked: false
                                    });
                                    append({
                                        title: videoConfig.getItemByColorSpaceType(VideoConfig.HDR_BT2020_HLG),
                                        type: VideoConfig.HDR_BT2020_HLG,
                                        checked: false
                                    });
                                    colorSpaceBox.setMenus(colorSpaceMenu);
                                }
                            }
                        }

                    }
                }
            }

            // 鼠标悬浮一段时间后弹出完整路径，目前单行显示
            Rectangle {
                id: composePathInfo
                property real anchorX: 0
                property real anchorY: 0
                property bool isShow: false
                property string showPath: ""

                visible: false
                opacity: 0
                // 12是左右的padding * 2
                width: text.width + 12
                // 16是上下的padding * 2
                height: text.height + 16
                x: anchorX - width / 2
                y: anchorY
                color: Colors.color_444444
                radius: 4
                border {
                    color: Colors.color_666666
                    width: 0.5
                }
                Text {
                    id: text
                    anchors.centerIn: parent
                    font.pixelSize: 11
                    color: Colors.color_EEEEEE
                    text: savePathValueText.text
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
                    composePathInfo.visible = true;
                    composePathInfo.opacity = 1.0;
                    composePathInfo.showPath = path;
                    isShow = true;
                }
                function hide() {
                    composePathInfo.opacity = 0.0;
                    isShow = false;
                }
            }
        }
    }


    function cancel() {
        close();
    }

    function confirm() {
        // 特殊逻辑处理，用户点击设置页面的确定按钮之后，就认为用户人为设置了画幅，如果当前是默认的16:9，则修改为用户设置的16:9类型，便于在特殊逻辑处进行区分
        if(editCanvasType == 5){ // 5:默认的16:9
            editCanvasType = 8 // 8: 用户设置的16:9
        }

        projectSettingsChanged({
            name: editName,
            composePath: editComposePath,
            canvasType: editCanvasType,
            fps: editFps,
            useMaterialProxy: editUseMaterialProxy,
            colorSpaceType: editColorSpaceType
        });
    }
}
