import QtQuick 2.15
import QtQuick.Layouts 1.15
import Controls 1.0
import Config 1.0

Item {
    id: root
    objectName: "cloudAlbumGuideView"

    property var benefitViewModel: null   // 由父级（CloudAlbumLoggedInView）传入
    property bool forceShowBetaView: false
    property bool forceShowGuideStepsView: false

    StackLayout {
        objectName: "cloudAlbumGuideStack"
        anchors.fill: parent
        // showBetaView=true -> BetaView(0); false -> GuideStepsView(1)
        currentIndex: root.forceShowBetaView ? 0
                      : root.forceShowGuideStepsView ? 1
                      : root.benefitViewModel && root.benefitViewModel.showBetaView ? 0 : 1

        // index 0: Beta 状态（权益暂不可领）
        CloudAlbumBetaView {
            objectName: "cloudAlbumBetaView"
            benefitViewModel: root.benefitViewModel
        }

        // index 1: 步骤引导（权益可领）
        CloudAlbumGuideStepsView {
            objectName: "cloudAlbumGuideStepsView"
            benefitViewModel: root.benefitViewModel
        }
    }
}
