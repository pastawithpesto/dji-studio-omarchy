import QtQuick 2.15
import QtQuick.Controls
import Controls 1.0
import Config 1.0
import TrackingManager 1.0
import app_qrc 1.0
import Nova 1.0

/**
 * @author robert.guo
 * @desc 过渡效果区域选择布局
 * @create_date 2024-06-14
 */
Item {
    id: root
    property bool maskVisible: panoKfVm.tabMaskVisible
    // 过渡可编辑/可用 已接入 nova：指针处于两关键帧之间(panoKfVm.transitionEditEnable)
    property bool transitionEditEnable: panoKfVm.transitionEditEnable
    property bool transitionEffectEnable: panoKfVm.transitionEditEnable
    property int  transitionEffectType: -1
    width: parent.width
    height: gridView.cellHeight * gridView.rowCount
    enabled: !(root.isTabVisible || !transitionEffectEnable)

    PanoramaPanelViewModel {
        id: panoramaPanelViewModel
        // 过渡图标取色走 getTransitonEffectSource → 读本实例 transitionEffectEnable(=keyframeEnable||tk)。
        // 普通关键帧的 keyframeEnable 与 transitionEditEnable 同义(指针在两帧间)，接 nova 真值；tk 保留老态。
        keyframeEnable: panoKfVm.transitionEditEnable
    }

    // 过渡效果已接入 nova：设置/读取走 panoKfVm。
    property PanoramaKeyframeViewModel panoKfVm

    function updateTransitionHighlight() {
        root.transitionEffectType = panoKfVm.transitionType;
        panoramaPanelViewModel.transitionEffectIndex = panoramaPanelViewModel.getIndexByType(panoKfVm.transitionType);
    }

    Connections {
        target: panoKfVm
        function onTransitionTypeChanged() { updateTransitionHighlight(); }
    }

    Component.onCompleted: updateTransitionHighlight()

    Rectangle {
        anchors.fill: parent
        color: Colors.color_transparent

        GridView {
            id: gridView
            anchors.fill: parent
            flow: GridView.FlowLeftToRight
            // cellWidth: 55 + 12
            cellWidth: 55 + 12 + (parent.width - 67 * 4) / 4
            cellHeight: 55 + 12
            model: panoramaPanelViewModel.transitionEffectListModel
            delegate: transitionEffectDelegate
            ScrollBar.vertical: ScrollBar {}
            // 禁止GridView滚动
            interactive: false
            currentIndex: panoramaPanelViewModel.transitionEffectIndex

            // 计算行数的属性
            property int rowCount: Math.ceil(model.count / columns)

            // 根据列数和模型大小动态计算列数
            property int columns: Math.floor(width / cellWidth)
        }
    }

    Component {
        id: transitionEffectDelegate
        Rectangle {
            width: gridView.cellWidth
            height: gridView.cellHeight
            color: Colors.color_transparent
        Item {
            width: gridView.cellWidth
            height: gridView.cellHeight

            Rectangle {
                id: imageBg
                radius: RadiusConfig.radius_4_88
                width: 36
                height: 36
                y: 0
                anchors.horizontalCenter: parent.horizontalCenter
                color: (root.maskVisible || !root.transitionEditEnable) ? Colors.color_2F3032_40 : mouseArea.containsMouse ? Colors.color_button_background_hovered : Colors.color_button_background_normal

                Image {
                    width: 24
                    height: 24
                    anchors.centerIn: parent
                    source: (root.maskVisible || !root.transitionEditEnable)  ? panoramaPanelViewModel.transitionEffectListModel.get(index).unenableSource : panoramaPanelViewModel.getTransitonEffectSource(index)
                    sourceSize: Qt.size(24, 24)
                }
            }

            Text {
                id: textLabel
                text: panoramaPanelViewModel.transitionEffectListModel.get(index).text
                color: Colors.color_666666
                font.pixelSize: 11
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
                anchors {
                    left: parent.left
                    leftMargin: 6
                    right: parent.right
                    rightMargin: 6
                    top: imageBg.bottom
                    topMargin: 4
                }
            }
            LightToolTip {
                visible: mouseArea.containsMouse && textLabel.implicitWidth > textLabel.width
                tip: textLabel.text
                z: 200
                y: parent.height - 10
            }
            MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    panoKfVm.setTransition(panoramaPanelViewModel.transitionEffectListModel.get(index).type);
                    if(editorManager.isInUserGuideStatus){
                        globalSignal.kfEffectFinish();
                    }
                    editorDraftManager.saveDraft();
                    eventTracker.trackEvent("pccut_keyframe_animation", {"use_effect": panoramaPanelViewModel.transitionEffectListModel.get(index).trackEventName})
                }
                }
            }
        }
    }

    // 禁用点击事件
    Item {
        id: disableCovering
        anchors.fill: parent
        visible: root.maskVisible || !root.transitionEditEnable
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
                console.log("TransitionEffectLayer, click event was intercepted.");
            }
        }
    }

    Connections {
        target: globalSignal
        function onTrackingStateChanged(status) {
            if (status === TrackingManager.TK_EDIT) {
                panoramaPanelViewModel.isEnteringTkEdit = true
            } else {
                panoramaPanelViewModel.isEnteringTkEdit = false
            }
        }
    }
}
