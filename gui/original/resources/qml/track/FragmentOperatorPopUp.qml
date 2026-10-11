import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls
// import QtQuick.Controls.Styles
import QtQuick.Dialogs
import Qt5Compat.GraphicalEffects
import Controls 1.0
import Config 1.0
import MediaListViewModel 1.0

LightPopup {
    id: customLightPopup
    // 根据哪个字段筛选
    property int curTrackIndex: 0
    property int curClipIndex: 0
    property bool isMediaLost: false
    property bool isSelectFile: false
    property bool isAudioFragment: false
    // 导出所选分段
    property bool isComposeFragmentValid: false

    property ListModel fragmentOperateModel: ListModel {}
    property int maxItemTextWidth: 0
    width: customLightPopup.maxItemTextWidth + 4 * 2 + 8 * 2
    height: contentColumn.height + contentColumn.spacing * 2

    signal repalceMedia();
    signal deleteAllSelectFragment();
    signal linkMediaClicked();
    signal copyKeyframe();
    signal pasteKeyframe();
    signal composeFragment();
    signal showInMediaLibrary();

    function getEstimatedHeight() {
        var count = fragmentOperateModel.count;
        var itemHeight = contentColumn.itemHeight;  // 28
        var spacing = contentColumn.spacing; 
        //不能遮挡滑杆,滑杆加底部边距时14px
        return count * itemHeight + (count - 1) * spacing + spacing * 2 + 14;
    }

    function showPop_Video(windowPointX, windowPointY, isMediaLost, isSelectFile, topasteKeyframe, composeFragmentValid) {
        repeater.model = {};
        fragmentOperateModel.clear();
        fragmentOperateModel.append({
            title: qsTr("pccut_replace_clip"),
            type: Instance.FRAGMENT_OPERATE_TYPE.FRAGMENT_REPALCE,
            enabled: true
        });
        if(isMediaLost){
            fragmentOperateModel.append({
                title: qsTr("pccut_files_missing_linkmedia"),
                type: Instance.FRAGMENT_OPERATE_TYPE.FRAGMENT_MEIDA_LOSS,
                enabled: true
            });
        }
        if (isSelectFile) {
            fragmentOperateModel.append({
                title: qsTr("pccut_cropleft_click_right_delete"),
                type: Instance.FRAGMENT_OPERATE_TYPE.FRAGMENT_DELETE,
                enabled: true
            });
        }
        if(topasteKeyframe) {
            fragmentOperateModel.append({
                title: qsTr("pccut_keyframe_paste"),
                type: Instance.FRAGMENT_OPERATE_TYPE.KEYFRAME_PASTE,
                enabled: true
            });
        }
        if(composeFragmentValid){
            fragmentOperateModel.append({
                title: qsTr("pccut_editor_result_type_btn"),
                type: Instance.FRAGMENT_OPERATE_TYPE.FRAGMENT_COMPOSE,
                enabled: true
            });
        }
        if(!isMediaLost && isSelectFile){
            fragmentOperateModel.append({
                title: qsTr("pccut_track_right_display"),
                type: Instance.FRAGMENT_OPERATE_TYPE.FRAGMENT_SHOW_IN_LIBRARY,
                enabled: true
            });
        }

        customLightPopup.maxItemTextWidth = 0;
        repeater.model = fragmentOperateModel;
        customLightPopup.x = windowPointX;
        var estimatedH = getEstimatedHeight();
        var bottomEdge = windowPointY + estimatedH;
        customLightPopup.y = bottomEdge > lightWindow.height
            ? lightWindow.height - estimatedH - 4
            : windowPointY;
        customLightPopup.open();
    }

    function showPop_Audio(windowPointX, windowPointY, isMediaLost, isSelectFile, composeFragmentValid) {
        repeater.model = {};
        fragmentOperateModel.clear();
        if(isMediaLost){
            fragmentOperateModel.append({
                title: qsTr("pccut_files_missing_linkmedia"),
                type: Instance.FRAGMENT_OPERATE_TYPE.FRAGMENT_MEIDA_LOSS,
                enabled: true
            });
        }
        if (isSelectFile) {
            fragmentOperateModel.append({
                title: qsTr("pccut_cropleft_click_right_delete"),
                type: Instance.FRAGMENT_OPERATE_TYPE.FRAGMENT_DELETE,
                enabled: true
            });
        }
        customLightPopup.maxItemTextWidth = 0;
        repeater.model = fragmentOperateModel;
        customLightPopup.x = windowPointX;
        customLightPopup.y = windowPointY;
        customLightPopup.open();
    }

    function showPop_Keyframe(windowPointX, windowPointY, tocopy, topaste) {
        repeater.model = {};
        fragmentOperateModel.clear();
        fragmentOperateModel.append({
            title: qsTr("pccut_keyframe_copy"),
            type: Instance.FRAGMENT_OPERATE_TYPE.KEYFRAME_COPY,
            enabled: (tocopy === true)
        });
        fragmentOperateModel.append({
            title: qsTr("pccut_keyframe_paste"),
            type: Instance.FRAGMENT_OPERATE_TYPE.KEYFRAME_PASTE,
            enabled: (topaste === true)
        });
        customLightPopup.maxItemTextWidth = 0;
        repeater.model = fragmentOperateModel;
        customLightPopup.x = windowPointX;
        customLightPopup.y = windowPointY;
        customLightPopup.open();
    }

    function showPop_Overlay(windowPointX, windowPointY, isMediaLost, isSelectFile)
    {
        repeater.model = {};
        fragmentOperateModel.clear();
        
        if(isMediaLost){
            fragmentOperateModel.append({
                title: qsTr("pccut_files_missing_linkmedia"),
                type: Instance.FRAGMENT_OPERATE_TYPE.FRAGMENT_MEIDA_LOSS,
                enabled: true
            });
        }
        if (isSelectFile) {
            fragmentOperateModel.append({
                title: qsTr("pccut_shortcut_delete"),
                type: Instance.FRAGMENT_OPERATE_TYPE.FRAGMENT_DELETE,
                enabled: true
            });
        }
        customLightPopup.maxItemTextWidth = 0;
        repeater.model = fragmentOperateModel;
        customLightPopup.x = windowPointX;
        customLightPopup.y = windowPointY;
        customLightPopup.open();
    }

    LightClipRectangle {
        anchors.fill: parent
        clip: true
        radius: [8,8,8,8]

        ShaderEffectSource {
            id: shaderSource
            // 仅当菜单与 mainPanel 处于同一窗口时才捕获其内容做毛玻璃背景，
            // 跨窗口捕获在部分 GPU/驱动上会死锁渲染线程；此时置 null 退化为下方纯色圆角背景。
            sourceItem: (typeof mainPanel !== "undefined" && mainPanel
                         && shaderSource.Window.window
                         && shaderSource.Window.window === mainPanel.Window.window) ? mainPanel : null
            sourceRect: Qt.rect(customLightPopup.x, customLightPopup.y, customLightPopup.width, customLightPopup.height)
            width: parent.width
            height: parent.height
            // 菜单模态且打开后位置固定，live:false 只在打开时捕获一次背景，
            // 省掉每帧重抓 + FastBlur 重算。showPop_* 里先定好 x/y 与宽高再 open，首帧捕获即为定位后的背景。
            live: false
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
            border.width: 0.5
            color: Colors.color_141414_85
            radius: 8
        }

        Column {
            id: contentColumn
            property int itemHeight: 28
            width: parent.width
            spacing: 4
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter

            Repeater {
                id: repeater
                model: {}

                delegate: Rectangle {
                    id: filter
                    property bool isHovered: false
                    radius: 4
                    width: customLightPopup.width - 4 * 2
                    height: contentColumn.itemHeight
                    color: (model.enabled && filter.isHovered) ? Colors.color_FFFFFF_15 : Colors.color_transparent
                    anchors.horizontalCenter: parent.horizontalCenter
                    Component.onCompleted: {
                        customLightPopup.maxItemTextWidth = Math.max(customLightPopup.maxItemTextWidth, filterText.width);
                    }
                    Text {
                        id: filterText
                        text: model.title
                        font.pixelSize: 11
                        color: model.enabled ? Colors.color_EEEEEE : Colors.color_444444
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: filter.isHovered = true;
                        onExited: filter.isHovered = false;
                        enabled: model.enabled
                        onClicked: {
                            close();
                            if(model.type === Instance.FRAGMENT_OPERATE_TYPE.FRAGMENT_REPALCE) {
                                customLightPopup.repalceMedia();
                            } else if(model.type === Instance.FRAGMENT_OPERATE_TYPE.FRAGMENT_MEIDA_LOSS) {
                                customLightPopup.linkMediaClicked();
                            } else if(model.type === Instance.FRAGMENT_OPERATE_TYPE.FRAGMENT_DELETE) {
                                customLightPopup.deleteAllSelectFragment();
                            } else if(model.type === Instance.FRAGMENT_OPERATE_TYPE.KEYFRAME_COPY) {
                                customLightPopup.copyKeyframe();
                            } else if(model.type === Instance.FRAGMENT_OPERATE_TYPE.KEYFRAME_PASTE) {
                                customLightPopup.pasteKeyframe();
                            } else if(model.type === Instance.FRAGMENT_OPERATE_TYPE.FRAGMENT_COMPOSE){
                                customLightPopup.composeFragment();
                            } else if(model.type === Instance.FRAGMENT_OPERATE_TYPE.FRAGMENT_SHOW_IN_LIBRARY){
                                customLightPopup.showInMediaLibrary();
                            } 
                        }
                    }
                }
            }
        }
    }
}
