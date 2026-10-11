import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls
import QtQuick.Dialogs
import Controls 1.0
import Config 1.0

Item {

    property bool allowSelectFolder: false
    property alias title: linkFileDialog.title

    FileDialog {
        id: linkFileDialog
        // windows上这个白扯
        nameFilters: [ "Media Files (" + fileOperator.linkFileSuffixes() + ")" ]
        onAccepted: {
            if (!lAFViewModel.tryLinkMediaWithUrl(linkFileDialog.currentFile)) {
                toast.showToast(qsTr("pccut_files_missing_fail"));
            }
        }
    }

    function show() {
        linkFileDialog.open();
    }

    function close() {
        linkFileDialog.close();
    }
}