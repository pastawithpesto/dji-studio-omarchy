import QtQuick 2.15
import Config
import DraftRecoverTool 1.0
import Qt.labs.platform 1.1
Item {
    id: root
    property var draftRecoverWindow: null
    property alias dialogVisible: selectDraftDialog.visible

    DraftRecoverTool {
        id: draftRecoverTool
    }

    FileDialog {
        id: selectDraftDialog
        fileMode: FileDialog.OpenFile
        title: qsTr("选择草稿文件")

        onAccepted: {
            var filePath
            if(CommonUtils.isWindows()){
                filePath = files[0].toString().replace("file:///", "");
            }else{
                filePath = files[0].toString().replace("file://", "");
            }

            const folderPath = filePath.substring(0, filePath.lastIndexOf('/'));
            validateAndOpenDraft(folderPath);
        }
    }

    Connections {
        target: globalSignal
        function onSelectDraftFile() {
            selectDraftDialog.open();
        }
    }

    function validateAndOpenDraft(folderPath) {
        if (!draftRecoverTool.containsProjFile(folderPath)) {
            globalSignal.toast(qsTr("该目录下缺少草稿相关文件 (.proj, .db)"))
            return;
        }
        createOrShowWindow(folderPath);
    }

    // 创建/显示恢复窗口
    function createOrShowWindow(folderPath) {
        if (!draftRecoverWindow) {
            const component = Qt.createComponent("qrc:/qml/debug/DraftRecoverWindow.qml");
            if (component.status === Component.Ready) {
                draftRecoverWindow = component.createObject(root);
            } else {
                return;
            }
        }

        draftRecoverWindow.projectFolder = folderPath;
        draftRecoverWindow.show();
    }
}
