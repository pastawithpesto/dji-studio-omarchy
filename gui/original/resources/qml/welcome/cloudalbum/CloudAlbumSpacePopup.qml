import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.3
import Config 1.0
import Controls 1.0

ConfirmPopup {
    id: spacePopup
    objectName: "cloudAlbumSpacePopup"
    leftButtonObjectName: "cloudAlbumSpaceCancelBtn"
    rightButtonObjectName: "cloudAlbumSpaceUpgradeBtn"

    signal expandStorageClicked()

    // 模式 1：空间已满
    function showFull() {
        title = qsTr("pccut_cloud_album_space_insufficient_title")
        text = qsTr("pccut_cloud_album_upload_disabled_hint")
        leftButtonText = qsTr("pccut_cloud_album_space_cancel")
        rightButtonText = qsTr("pccut_draft_delete_popup_yes")
        open()
    }

    // 模式 2：部分文件跳过
    function showInsufficient(skippedCount) {
        title = qsTr("pccut_cloud_album_space_insufficient_title")
        text = qsTr("pccut_cloud_album_space_insufficient_content").arg(skippedCount)
        leftButtonText = qsTr("pccut_cloud_album_space_acknowledged")
        rightButtonText = qsTr("pccut_draft_delete_popup_yes")
        open()
    }

    onLeftButtonClicked: {
    }

    onRightButtonClicked: {
        expandStorageClicked()
    }
}
