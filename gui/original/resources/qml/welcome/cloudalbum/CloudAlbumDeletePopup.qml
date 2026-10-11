import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.3
import Config 1.0
import Controls 1.0

ConfirmPopup {
    id: cloudDeletePopup

    title: qsTr("pccut_cloud_album_recycle_move_confirm_title")
    text: qsTr("pccut_cloud_album_recycle_move_confirm").arg(deleteFileIds.length)
    leftButtonText: qsTr("pccut_device_batch_delete_all_cancel")
    rightButtonText: qsTr("pccut_device_batch_delete_all_yes")
    leftButtonObjectName: "cloudAlbumDeleteCancelBtn"
    rightButtonObjectName: "cloudAlbumDeleteConfirmBtn"

    signal confirmDelete(var fileIds)

    property var deleteFileIds: []
    property var deleteMetadata: ({
        size: 0,
        materials: {photo: 0, video: 0, panoPhoto: 0, panoVideo: 0, livePhoto: 0}
    })

    function showPop(fileIds, metadata) {
        deleteFileIds = fileIds;
        deleteMetadata = metadata || deleteMetadata;
        open();
    }

    onLeftButtonClicked: {
        cloudAlbumEventReport.trackDeleteConfirm(
            false, deleteFileIds, deleteMetadata.size, deleteMetadata.materials)
    }

    onRightButtonClicked: {
        confirmDelete(deleteFileIds);
    }
}
