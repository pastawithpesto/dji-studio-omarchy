import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls
//import QtQuick.Controls.Styles 1.4
import QtQuick.Dialogs
import Controls 1.0
import Config 1.0
import AgencyManager 1.0
import Qt5Compat.GraphicalEffects
import QtQuick.Templates 2.12 as T
import MediaListViewModel 1.0

/**
 * @author robert.guo
 * @desc 素材列表右键点击弹框
 * @create_date 2024-04-18
 */
LightPopup {
    id: root
    /**
     * @desc 更新操作项
     *
     * @modeType 当前操作类型
     * @removeFileIndex 如果是移除/删除操作，则对应文件的索引，其他操作，暂无意义
     * @return 无
     */
    signal clickType(int modeType)

    // 媒体文件是否存在
    property bool mediaExist: true

    property var index: null
    property string filePath: ""

    property point showPoint: Qt.point(0, 0)
    
    width: Math.max(maxItemTextWidth + 34, 101)
    property real itemBgWidth: width - 8

    property real maxItemTextWidth: 0
    // 上下边距之和 + （item高度+ 上下padding之和）* 个数
    height: 4 + 32 * fileOperateModel.count

    property ListModel fileOperateModel: ListModel {}
    property real radiusValue: 8
    // 直接操作 fileOperateModel, 弹框的速度会变慢, 所先操作这个临时的 ListModel 会快一点
    readonly property ListModel tmpModels: ListModel {}

    T.Overlay.modal: Rectangle {
        color: Colors.transparent
    }

    function showPop() {
        tmpModels.clear();
        tmpModels.append({
            title: qsTr("pccut_media_transcoding_delete_yes"),
            type: Instance.FILE_OPERATE_TYPE.TYPE_OF_REMOVE_FILE_FROM_LIST
        });
        fileOperateModel = tmpModels;
        shaderSource.sourceRect = Qt.rect(showPoint.x, showPoint.y, width, height);
        open();
    }
    contentItem: LightClipRectangle {
        id: blurBg
        radius: [radiusValue, radiusValue, radiusValue, radiusValue]
        clip: true
        width: root.width
        height: root.height

        ShaderEffectSource {
            id: shaderSource
            sourceItem: mainPanel
            width: root.width
            height: root.height
            live: true
            smooth: true
        }

        // 高斯调节
        FastBlur {
            anchors.fill: parent
            source: shaderSource
            radius: 48
        }
 
        Rectangle {
            anchors.fill: parent
            border.color: Colors.color_444444
            border.width: 1
            color: Colors.color_141414_85
            radius: 8
        }

        ListView {
            width: parent.width - 8
            height: parent.height
            spacing: 4
            model: fileOperateModel
            anchors {
                top: parent.top
                topMargin: 4
            }

            delegate: MouseArea {
                id: itemMouseArea
                hoverEnabled: true
                onClicked: {
                    clickType(model.type);
                    close();
                }
                width: root.width
                height: 28
                Component.onCompleted: {
                    maxItemTextWidth = Math.max(maxItemTextWidth, itemText.width);
                }
                Rectangle {
                    width: parent.width - 8
                    height: parent.height
                    radius: 4
                    color: (itemMouseArea.containsMouse) ? Colors.color_FFFFFF_15 : Colors.color_transparent
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    id: itemText
                    text: model.title
                    height: parent.height
                    font.pixelSize: 11
                    color: Colors.color_EEEEEE
                    leftPadding: 12
                    verticalAlignment: Text.AlignVCenter
                    // 文字可能不清晰
                    antialiasing: true
                }
            }
        }
    }
}
