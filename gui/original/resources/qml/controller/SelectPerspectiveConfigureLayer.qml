import QtQuick 2.15
import QtQuick.Controls
import Controls 1.0
import Config 1.0
import TrackingManager 1.0
import PanoramaController 1.0
import QtQuick.Layouts 1.15
import Nova 1.0

/**
 * @author robert.guo
 * @desc 选择视角-参数设置布局
 * @create_date 2024-06-14
 */
Item {
    id: root
    width: parent.width
    // height: itemHeight * 3
    height: (isSelfieMode ? itemHeight : itemHeight * 3) + zoomRect.height
    property bool isTabVisible: panoKfVm.tabMaskVisible

    property real itemHeight: 39 + 16
    property real horizontalPadding: 12
    property real columnSpacing: 3
    property real itemWidth: (width - horizontalPadding * 2 - horizontalPadding) / 2
    property bool isSelfieMode: false // 素材是否是自拍模式或者时光凝固

    property PanoramaKeyframeViewModel panoKfVm

    Connections {
        target: panoKfVm
        function onParamsChanged() { updateUi(); }
    }

    Connections {
        target: globalSignal
        function onKeyFrameValueChanged(_hasKeyFrame, _hasNextKeyFrame, _hasPreviousKeyFrame) {
            panoramaPanelViewModel.hasKeyFrame = _hasKeyFrame;
        }

        function onTrackingStateChanged(status) {
            if (status === TrackingManager.TK_EDIT) {
                panoramaPanelViewModel.isEnteringTkEdit = true
            } else {
                panoramaPanelViewModel.isEnteringTkEdit = false
            }
        }
    }

    function updateUi() {
        // index: 0=fov 1=distortion 2=yaw(水平) 3=pitch(俯仰) 4=roll(旋转)，与 panoKfVm.setParam 对齐
        var arr = [panoKfVm.fov, panoKfVm.distortion, panoKfVm.yaw, panoKfVm.pitch, panoKfVm.roll];
        for (var i = 0; i < arr.length; i++) {
            let item = repeater.itemAt(i);
            if (item !== null) {
                item.updateOriginValue(arr[i]);
                item.updateUi(arr[i]);
            }
        }
    }

    Item {
        id: zoomRect
        height: 48
        anchors {
            left: parent.left
            leftMargin: horizontalPadding
            top: parent.top
            right: parent.right
            rightMargin: horizontalPadding
        }
        Text {
            text: qsTr("pccut_panel_screen_zoom")
            color: Colors.color_EEEEEE
            font.pixelSize: 12
            anchors {
                verticalCenter: parent.verticalCenter
                left: parent.left
            }
        }
        Rectangle {
            width: 90
            height: 24
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            color: Colors.color_19191A
            radius: 4
            Timer {
                id: repeatZoomTimer
                interval: 30
                repeat: true
                property bool isZoomIn: false
                property int triggerCount: 0

                function resetState() {
                    stop();
                    isZoomIn = false;
                    triggerCount = 0;
                }
                onTriggered: {
                    triggerCount += 1;
                    // 长按的连续缩放
                    if (triggerCount > 17) {
                        var zoomValue = 0.01;
                        if (isZoomIn) {
                            zoomValue = -zoomValue;
                        }
                        panoKfVm.zoom(zoomValue, false);
                    }
                }
            }
            // 缩小
            IconButton {
                id: zoomIn
                iconSource: "qrc:/icons/trackToolBar/toolbar_zoom_in.svg"
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 4
                hoverColor: Colors.color_2F3032
                pressedColor: Colors.color_19191A
                height: 16
                width: 16
                radius: 3
                disabled: panoKfVm.disableZoomIn || isTabVisible
                iconMargins: 0
                opacity: disabled ? 0.2 : 1
                property bool isPressIng: false
                onPressedChanged: {
                    if (pressed) {
                        if (disabled) {
                            return;
                        }
                        isPressIng = true;
                        repeatZoomTimer.isZoomIn = true
                        repeatZoomTimer.start();
                        panoKfVm.zoom(-0.05, false);
                    }  else if (isPressIng) {
                        isPressIng = false;
                        repeatZoomTimer.resetState();
                        panoKfVm.zoom(0, true);
                        editorDraftManager.saveDraft();
                    }
                }
            }

            AutoAdjustTextView {
                id: zoomText
                width: valueText.width
                height: 24
                isTabVisible: root.isTabVisible
                isPlaying: false
                isDisableMode: false
                dragCoeff: 0.1
                enableMulpleText: false
                minValue: 0
                maxValue: 1000
                value: panoKfVm.centerHFov
                disableClick: true
                property bool isStart: false
                property real beforeMouseDeltaX: 0

                anchors {
                    verticalCenter: parent.verticalCenter
                    horizontalCenter: parent.horizontalCenter
                }

                onArgumentChanged: (value, itemIndex, isEditing) => {
                    if (!isStart) {
                        isStart = true;
                        beforeMouseDeltaX = 0;
                        return;
                    }
                    // 这里需要自己计算变化的值
                    // 这里是一个手感的值
                    var value = (mouseDeltaX - beforeMouseDeltaX) / 20;
                    beforeMouseDeltaX = mouseDeltaX;
                    panoKfVm.zoom(value, false);
                }

                onRelease: (value, itemIndex) => {
                    isStart = false;
                    panoKfVm.zoom(0, true);
                    editorDraftManager.saveDraft();
                }
            }

            // 放大
            IconButton {
                id: zoomOut
                iconSource: "qrc:/icons/trackToolBar/toolbar_zoom_out.svg"
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: 4
                hoverColor: Colors.color_2F3032
                pressedColor: Colors.color_19191A
                height: 16
                width: 16
                radius: 3
                iconMargins: 0
                opacity: disabled ? 0.2 : 1
                disabled: panoKfVm.disableZoomOut || isTabVisible
                property bool isPressIng: false

                onPressedChanged: {
                    if (pressed) {
                        if (disabled) {
                            return;
                        }
                        isPressIng = true;
                        repeatZoomTimer.isZoomIn = false;
                        repeatZoomTimer.start();
                        panoKfVm.zoom(0.05, false);
                    } else if (isPressIng) {
                        isPressIng = false;
                        repeatZoomTimer.resetState();
                        panoKfVm.zoom(0, true);
                        editorDraftManager.saveDraft();
                    }
                }
            }
        }
    }

    Item {
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            top: zoomRect.bottom
        }
        // 选择视角，参数设置区域
        GridLayout {
            id: gridView
            anchors {
                fill: parent
                leftMargin: horizontalPadding
                rightMargin: horizontalPadding
            }
            columns: 2
            rowSpacing: 0
            columnSpacing: root.columnSpacing
            // spacing: 0  // 设置子项之间的间距
            property real cellWidth: itemWidth
            Repeater {
                id: repeater
                model: panoramaPanelViewModel.selectPerspectiveSetArgumentListModel
                delegate: selectPerspectiveSetArgumentDelegate
            }
            Component.onCompleted: {
                delayedUpdateTimer.start();
            }
        }
        Timer {
            id: delayedUpdateTimer
            interval: 100 // 延迟 100 毫秒
            repeat: false
            onTriggered: {
                root.updateUi();
            }
        }
    }

    Component {
        id: selectPerspectiveSetArgumentDelegate
        Item {
            // Qt6.5 之后对代码要求更严格, GridLayout 需要设置Layout
            Layout.preferredWidth: gridView.cellWidth
            Layout.preferredHeight: itemHeight
            visible: index < 2 || (!root.isSelfieMode) // 自拍模式或者时光凝固素材时，只有前两个参数可调
            function updateUi(_value) {
                autoAdjustTextView.value = _value;
            }

            function updateOriginValue(_value) {
                autoAdjustTextView.originValue = _value;
            }
            enabled: panoramaPanelViewModel.getSelectPerspectiveConfigEnable(index)

                Image {
                    x: 2
                    id: setArgumentIcon
                    width: 20
                    height: 20
                    source: panoramaPanelViewModel.selectPerspectiveSetArgumentListModel.get(index).selectSource
                    sourceSize: Qt.size(32, 32)
                    opacity: root.isTabVisible ? 0.2 : 1
                    anchors {
                        top: parent.top
                        topMargin: 2
                    }
                }

                HoverableText {
                    id: nameForSetAugument
                    elide: Text.ElideRight
                    wrapMode: Text.Wrap
                    width: parent.width
                    text: panoramaPanelViewModel.selectPerspectiveSetArgumentListModel.get(index).text
                    color: root.isTabVisible || !panoramaPanelViewModel.getSelectPerspectiveConfigEnable(index) ? Colors.color_444444 : Colors.color_666666
                    font.pixelSize: 11
                    maximumLineCount: 2
                    anchors {
                        left: setArgumentIcon.left
                        top: setArgumentIcon.bottom
                        topMargin: 4
                    }
                }


                AutoAdjustTextView {
                    id: autoAdjustTextView
                    width: 37
                    height: 24
                    itemIndex: index
                    isTabVisible: root.isTabVisible
                    hasKeyFrame: panoKfVm.hasKeyFrame
                    isPlaying: panoKfVm.isPlaying
                    isDisableMode: !panoramaPanelViewModel.getSelectPerspectiveConfigEnable(index)
                    dragCoeff: panoramaPanelViewModel.selectPerspectiveSetArgumentListModel.get(index).dragCoeff
                    enableMulpleText: panoramaPanelViewModel.selectPerspectiveSetArgumentListModel.get(index).enableMulpleText
                    minValue: panoramaPanelViewModel.selectPerspectiveSetArgumentListModel.get(index).minValue
                    maxValue: panoramaPanelViewModel.selectPerspectiveSetArgumentListModel.get(index).maxValue
                    value: 0
                    anchors {
                        left: setArgumentIcon.right
                        leftMargin: 4
                        top: parent.top
                    }

                    onValueChanged: {
                        panoramaPanelViewModel.setPerspectiveArgumentValue(value, index)
                    }

                    onRelease: {
                        globalSignal.panoramaPlayerPramaAdjust(PanoramaController.VideoManual)
                    }

                    Connections {
                        target: autoAdjustTextView
                        function onArgumentChanged(value, itemIndex, isEditing) {
                          panoKfVm.setParam(itemIndex, value, isEditing);  // isEditing 即 isChangeEnd(沿用老语义)
                          if(isEditing && editorManager.isInUserGuideStatus){
                              globalSignal.nextStepInKfGuide();
                          }
                        }

                        function onRelease(value, itemIndex) {
                            panoKfVm.setParam(itemIndex, value, true);
                            editorDraftManager.saveDraft();
                        }
                    }
                }

            Component.onCompleted: {
                root.updateUi()
            }
        }
    }
}
