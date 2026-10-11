import QtQuick 2.15
import CloudAlbumTransferModel 1.0

QtObject {
    id: root

    property var assetModel: null
    property bool active: true

    property Connections transferConnections: Connections {
        target: CloudAlbumTransferModel

        function onUploadAssetReady(asset) {
            if (root.active && root.assetModel) {
                root.assetModel.appendLocalUpload(asset)
            }
        }
    }
}
