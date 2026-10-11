import QtQuick 2.15
import QtQuick.Controls
import Controls 1.0
import Config 1.0
import app_qrc 1.0

/**
 * @author: mark.zhu
 * @details 统一的文件名组件（自动适配单个/批量模式）
 *          传入 viewModel（MediaExportSettingsProtocol 实例或兼容的 QtObject）驱动
 * @date: 2026-03-03
 */
Item {
    id: root

    // 外部传入 viewModel（需具备 isSingleMode/isBatchMode/fileNameList/showSuffix/fileNameSuffix/savePath 等属性）
    required property var viewModel

    // 可选属性：标题文本
    property string titleText: qsTr("pccut_export_name")

    // 可选属性：样式定制
    property int titleLeftMargin: 63

    // 上次用户确认的有效文件名（用于空名恢复）
    property string lastCommittedName: ""

    // 显示源派生属性：复用原绑定表达式，由 QML 自动追踪 viewModel 上的所有依赖
    // （isSingleMode、fileNameList 等任一变化都会重新评估）
    readonly property string _displayName:
        root.viewModel.isSingleMode
        && root.viewModel.fileNameList.length > 0
        ? root.viewModel.fileNameList[0]
        : ""

    width: parent.width
    height: 28
    implicitHeight: 28
    clip: false

    // 显示源变化 → 主动 setText 同步到 BaseTextField
    on_DisplayNameChanged: singleFileInput.setText(_displayName)

    // ===== 单个文件模式：可编辑输入框 =====
    BaseTextField {
        id: singleFileInput
        visible: root.viewModel.isSingleMode
        anchors.fill: parent

        titleText: root.titleText
        showSuffix: root.viewModel.showSuffix
        suffixText: root.viewModel.fileNameSuffix
        placeholderText: qsTr("pccut_export_entername_empty")
        showWarning: duplicateWarning.showWarning
        height: 28
        spacing: 12

        Component.onCompleted: {
            // 初次同步显示，并记录 lastCommittedName
            singleFileInput.setText(root._displayName)
            if (contentText.trim().length > 0) {
                root.lastCommittedName = contentText
            }
        }

        // 用户输入 → 同步回 viewModel
        onTextValueChanged: function(value) {
            if (root.viewModel.isSingleMode && root.viewModel.fileNameList.length > 0) {
                var is_change = root.viewModel.fileNameList[0] !== value;
                if (is_change) {
                    root.viewModel.updateSingleFileName(value);
                }

                if (root.viewModel.enableEventTracking) {
                    // 键盘输入频率不可控，暂不埋点
                }
            }
            // 记录外部（非用户输入）更新的有效文件名
            if (!singleFileInput.valueTextCom.activeFocus && value.trim().length > 0) {
                root.lastCommittedName = value
            }
        }
    }

    // 显式提交编辑：若文件名为空则恢复为上次有效名称
    function commitEdit() {
        var name = singleFileInput.contentText.trim()
        if (name.length === 0) {
            // 通过 viewModel 回流，由 _displayName 派生属性触发 setText 刷新显示，链路统一
            root.viewModel.updateSingleFileName(root.lastCommittedName)
        } else {
            root.lastCommittedName = name
        }
    }

    // 失焦或回车时自动提交
    Connections {
        target: singleFileInput.valueTextCom
        function onEditingFinished() {
            root.commitEdit()
        }
    }

    DuplicateFileWarning {
        id: duplicateWarning
        checkEnabled: root.viewModel.isSingleMode
        visible: checkEnabled
        y: root.height
        x: root.titleLeftMargin
        width: root.width - root.titleLeftMargin
        savePath: root.viewModel.savePath
        fileName: root.viewModel.isSingleMode && root.viewModel.fileNameList.length > 0
            ? root.viewModel.fileNameList[0] : ""
        fileNameSuffix: root.viewModel.showSuffix ? root.viewModel.fileNameSuffix : ""
    }

    // ===== 批量文件模式：只读列表显示 =====
    Rectangle {
        id: batchFileDisplay
        visible: root.viewModel.isBatchMode
        anchors.fill: parent
        color: Colors.color_transparent

        HoverableText {
            id: titleLabel
            anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
            }
            horizontalAlignment: Text.AlignLeft
            verticalAlignment: Text.AlignVCenter
            font.pixelSize: 12
            color: Colors.color_CCCCCC
            text: root.titleText
        }

        Rectangle {
            id: fileListBox
            anchors {
                left: parent.left
                leftMargin: root.titleLeftMargin
                top: parent.top
                bottom: parent.bottom
                right: parent.right
            }

            color: Colors.color_transparent
            radius: RadiusConfig.radius_4_8

            Text {
                id: fileListDisplay
                anchors {
                    left: parent.left
                    top: parent.top
                    bottom: parent.bottom
                    right: parent.right
                }
                text: root.viewModel.displayFileNames
                font.pixelSize: 12
                font.weight: Font.DemiBold
                color: Colors.color_EEEEEE
                wrapMode: Text.WrapAnywhere
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignLeft
                verticalAlignment: Text.AlignVCenter

                // 鼠标悬浮区域
                MouseArea {
                    id: hoverArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.ArrowCursor
                    onClicked: {} // 阻止点击事件传递

                    // 使用项目统一的 LightToolTip
                    LightToolTip {
                        visible: hoverArea.containsMouse && fileListDisplay.truncated
                        tip: root.viewModel.displayFileNamesTips
                        z: 200
                    }
                }
            }
        }
    }
}
