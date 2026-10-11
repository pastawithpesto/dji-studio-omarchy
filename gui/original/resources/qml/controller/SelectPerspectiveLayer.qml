import QtQuick 2.15
import QtQuick.Controls
import Controls 1.0
import Config 1.0
import TrackingManager 1.0
import PanoramaController 1.0
import QtQuick.Layouts 1.3
import app_qrc 1.0
import Nova 1.0

/**
 * @author robert.guo
 * @desc 选择视角-模型选择布局
 * @create_date 2024-06-14
 */
Item {
    id: root
    property bool isTabVisible: panoKfVm.tabMaskVisible
    property alias currentPreset: gridView.currentIndex

    width: parent.width
    height: 58 * gridView.rowCount

    // 视角预设已接入 nova：应用/高亮走 panoKfVm。
    property PanoramaKeyframeViewModel panoKfVm

    Connections {
        target: panoKfVm
        function onPresetIndexChanged() {
            gridView.currentIndex = panoKfVm.presetIndex;
        }
    }

    Connections {
        target: globalSignal
        function onTrackingStateChanged(status) {
            if (status === TrackingManager.TK_EDIT) {
                panoramaPanelViewModel.isEnteringTkEdit = true;
            } else {
                panoramaPanelViewModel.isEnteringTkEdit = false;
            }
        }

        function onSelectPerspectiveInGuide(){
            panoKfVm.applyPreset(0);
            editorDraftManager.saveDraft();
        }
    }

    Component.onCompleted: {
        gridView.currentIndex = panoKfVm.presetIndex;
    }

    Rectangle {
        anchors.fill: parent
        color: Colors.color_transparent
        GridView {
            id: gridView
            anchors.fill: parent
            flow: GridView.FlowLeftToRight
            // cellWidth: 58 + 8
            cellWidth: 58 + 8 + (parent.width - 66 * 4) / 4
            cellHeight: 58
            model: panoramaPanelViewModel.selectPerspectiveListModel
            delegate: selectPerspectiveDelegate
            ScrollBar.vertical: ScrollBar {}
            // 禁止GridView滚动
            interactive: false

            // 计算行数的属性
            property int rowCount: Math.ceil(model.count / columns)

            // 根据列数和模型大小动态计算列数
            property int columns: Math.floor(width / cellWidth)
        }
    }

    Component {
        id: selectPerspectiveDelegate
        Rectangle {
            width: gridView.cellWidth
            height: gridView.cellHeight
            color: Colors.color_transparent
        Item {
            width: 58 + 8
            height: 58
            enabled: true

            Rectangle {
                radius: RadiusConfig.radius_4_12
                width: 58
                height: 58
                color: root.isTabVisible ? Colors.color_2F3032_40 : mouseArea.containsMouse ? Colors.color_button_background_hovered : Colors.color_button_background_normal

                Image {
                    width: 24
                    height: 24
                    y: 8
                    anchors.horizontalCenter: parent.horizontalCenter
                    source: root.isTabVisible ? panoramaPanelViewModel.selectPerspectiveListModel.get(index).disableSource : panoramaPanelViewModel.getSelectePerspectiveSource(gridView.currentIndex == index, index)
                    sourceSize: Qt.size(24, 24)
                }

                Text {
                    id: textLabel
                    text: panoramaPanelViewModel.selectPerspectiveListModel.get(index).text
                    color: root.isTabVisible ? Colors.color_444444 : (gridView.currentIndex === index ? ColorsConfig.color_666666_4DFFC9 : Colors.color_666666)
                    font.pixelSize: 11
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                    anchors {
                        left: parent.left
                        right: parent.right
                        bottom: parent.bottom
                        leftMargin: 8
                        rightMargin: 8
                        bottomMargin: 6
                    }
                }
                LightToolTip {
                    visible: mouseArea.containsMouse && textLabel.implicitWidth > textLabel.width
                    tip: textLabel.text
                }
            }
            MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    panoKfVm.applyPreset(index);
                    globalSignal.panoramaPlayerPramaAdjust(PanoramaController.PresetParameters)
                    if(editorManager.isInUserGuideStatus){
                        globalSignal.nextStepInKfGuide();
                    }
                    editorDraftManager.saveDraft();
                }
                }
            }
        }
    }
}
