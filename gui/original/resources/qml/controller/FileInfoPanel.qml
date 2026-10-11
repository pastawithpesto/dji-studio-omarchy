import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.3
import Config 1.0
import Controls 1.0

/**
 *  @File        : FileInfoPanel.qml
 *  @Brief       : 文件信息UI
 *  @Details     : 详细说明
 *  @Author      : pansy.guo
 *  @Date        : 2024-03-08 14:11:31
 */
Rectangle {
    id: root
    color: Colors.color_content_area_background

    signal requestDeselectAll()

    property bool isHasAudio: true // 是否存在音频
    property string filePath: ""

    ListModel {
        id: fileInfoModel
    }

    /**
     * @desc 更新文件路径
     *
     * @path 文件路径
     * @return 无
     */
    function updatePath() {
        if (CommonUtils.isEmptyStr(filePath)) {
            return;
        }
        fileInfoModel.clear();
        fileInfoModel.append({
            title: qsTr("pccut_media_info_path"),
            value: fileOperator.getFileInfoDisplayPath(filePath)
        });
        fileInfoModel.append({
            title: qsTr("pccut_media_info_date"),
            value: fileOperator.getCreationTimeByFormatted(filePath, qsTr("pccut_media_info_year_month_day"))
        });
        fileInfoModel.append({
            title: qsTr("pccut_media_info_size"),
            value: CommonUtils.getFileSizeInfo(fileOperator.getFileSize(filePath))
        });
        fileInfoModel.append({
            title: qsTr("pccut_media_info_resolution"),
            value: fileOperator.getFileWidth(filePath) + "x" + fileOperator.getFileHeight(filePath)
        });
        if (fileOperator.isVideo(filePath)) {
            fileInfoModel.append({
                title: qsTr("pccut_media_info_rate"),
                value: fileOperator.getFileFrameRate(filePath) + "fps"
            });
            fileInfoModel.append({
                title: qsTr("pccut_media_info_time"),
                value: fileOperator.getFileDurationByTimeFormat(filePath)
            });
            fileInfoModel.append({
                title: qsTr("pccut_media_info_encoding"),
                value: fileOperator.getVideoFileCodec(filePath)
            });
            let colorMode = fileOperator.getVideoColorMode(filePath)
            if (colorMode !== "") {
                fileInfoModel.append({
                    title: qsTr("pccut_media_info_color_mode"),
                    value: colorMode
                });
            }
            let colorDepth = fileOperator.getVideoColorDepth(filePath)
            if (colorDepth !== "") {
                fileInfoModel.append({
                    title: qsTr("pccut_media_info_bit_mode_depth"),
                    value: colorDepth + "bit"
                });
            }
        }
    }

    Component.onCompleted: {
        updatePath();
    }

    anchors.fill: parent

    MouseArea {
        anchors.fill: parent
        propagateComposedEvents: true
        onClicked: {
            var localPos = mapToItem(root, mouse.x, mouse.y)
            if (root.contains(localPos)) {
                root.requestDeselectAll()
            }
        }
    }

    // 顶部分割线
    Rectangle {
        color: Colors.color_141414
        width: parent.width
        height: 1
    }

    ScrollView {
        id: scrollView
        anchors {
            left: parent.left
            top: parent.top
            right: parent.right
            bottom: parent.bottom
            topMargin: 16
            leftMargin: 12
            rightMargin: 12
        }
        bottomPadding: 20
        contentHeight: infoLayout.implicitHeight
        ScrollBar.vertical.policy: ScrollBar.AlwaysOff
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        clip: true

        ColumnLayout {
            id: infoLayout
            anchors.fill: parent
            spacing: 16
            property int maxLeftMargin: 0
            Repeater {
                model: fileInfoModel
                Item {
                    id: itemRect
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.max(titleLabel.implicitHeight, valueLabel.implicitHeight)
                    clip: true

                    HoverableText {
                        id: titleLabel
                        anchors.left: parent.left
                        anchors.top: parent.top
                        horizontalAlignment: Text.AlignLeft
                        color: Colors.color_999999
                        font.pixelSize: 12
                        text: model.title

                        Component.onCompleted: {
                            infoLayout.maxLeftMargin = Math.max(infoLayout.maxLeftMargin, width + 16)
                        }
                    }

                    TextEdit {
                        id: valueLabel
                        anchors.left: parent.left
                        anchors.leftMargin: infoLayout.maxLeftMargin
                        anchors.top: titleLabel.top
                        readOnly: true
                        selectByMouse: true
                        selectionColor: Colors.color_FFFFFF_20
                        horizontalAlignment: Text.AlignLeft
                        color: Colors.color_EEEEEE
                        wrapMode: Text.WrapAnywhere
                        font.pixelSize: 12
                        width: parent.width - infoLayout.maxLeftMargin
                        text: model.value

                        Connections {
                            target: root // 指向定义信号的父元素
                            function onRequestDeselectAll() {
                                valueLabel.deselect()
                            }
                        }
                    }
                }
            }
        }
    }
}
