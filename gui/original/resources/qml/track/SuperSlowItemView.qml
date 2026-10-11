import QtQuick 2.15
import QtQuick.Controls 2.15
import Controls 1.0
import Config 1.0
import Nova 1.0

Item {
    id: root

    property real pxPerFrameTemp: pxPerFrame
    property int clipIndex: -1
    property int trackIndex: -1
    property real visibleLeft: 0
    property real visibleRight: 0
    property TimelineVideoClipViewModel viewModel
    property var speedViewModel: (typeof settingPanel !== "undefined" && settingPanel)
                                 ? settingPanel.speedViewModel : null
    readonly property bool enableSuperSlow: viewModel && viewModel.isSuperSlow
    readonly property int speedLevel: viewModel ? viewModel.superSlowSpeedLevel : 1
    readonly property string tagString: speedOptions[speedLevel]
    readonly property var speedOptions: ["0.5x", "0.25x", "0.125x"]

    width: viewModel && viewModel.superSlowEffectRange.endUs !== undefined
           ? Math.max(0, (viewModel.superSlowEffectRange.endUs -
                         viewModel.superSlowEffectRange.startUs) /
                        oneFrameToTimes * pxPerFrame)
           : 0
    x: viewModel && viewModel.superSlowEffectRange.startUs !== undefined
       ? (viewModel.superSlowEffectRange.startUs - viewModel.trackFrameIn) /
         oneFrameToTimes * pxPerFrame
       : 0
    height: 16

    function changeClipRange() {
        // The range is projected from the current Nova snapshot.
    }

    ComboBox {
        id: speedCombo
        anchors.fill: parent
        currentIndex: root.speedLevel
        enabled: root.enableSuperSlow

        background: Rectangle {
            radius: 2
            color: Colors.color_009DFF
        }

        contentItem: Text {
            text: root.tagString
            color: Colors.color_143668
            font.pixelSize: 10
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }

        model: root.speedOptions

        onActivated: {
            if (root.speedViewModel) {
                root.speedViewModel.superSlowSpeedLevel = currentIndex
            }
        }
    }
}
