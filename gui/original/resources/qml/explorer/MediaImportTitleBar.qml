import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.3
import Qt.labs.platform 1.1
import Config 1.0
import Controls 1.0
import MediaListViewModel 1.0
import Qt5Compat.GraphicalEffects
import app_qrc 1.0

import DeviceMediaCategory 1.0
import AlgBizHighLightModel 1.0
import HighLightThemeTabViewModel 1.0

/**
 * @author robert.guo
 * @desc 素材导入title栏
 * @create_date 2024-04-11
 */
Item {
    id: root
    signal clickAddFile
    signal filterChange
    property var mediaListViewModel
    property bool isLocal: true
    //property alias addBtn: addBtn
    property alias filterBtn: filterBtn
    property alias gridBtn: gridBtn
    property alias sortBtn: sortBtn
    property alias btnContainer: btnContainer
    property alias btnOri: btnOri
    
    property bool isSelectHighlightTab: mediaListViewModel.mediaCategoryType == DeviceMediaCategory.Highlight

    visible: true      //!(root.isSelectHighlightTab && mediaListViewModel.count < 1)  - lex-TODO：内部按钮可见性调整.
    
    // 原片、高光按钮
    Rectangle {
        id: btnContainer
        width: 160
        height: 24
        radius: 4
        
        color: Colors.color_19191A            // 如果没有这句,露出背景白点

        // 高光功能开关
        visible: mediaListViewModel.isTabsViewVisible

        property bool selectHighlight: mediaListViewModel.mediaCategoryType == DeviceMediaCategory.Highlight
        Row {
            anchors {
                left: parent.left
                top: parent.top
            }
            clip: true
            // 原片
            IconTextButton {
                id: btnOri
                height: 24
                anchors.verticalCenter: parent.verticalCenter
            
                title: qsTr("pccut_home_original")
                titleFontSize: 12
                isTextOnly: true
            
                // 根据你提供的样式设置
                radius: 4  // border-radius: 4px
            
                // 背景色 #2F3032
                backgroundColorNormal: !btnContainer.selectHighlight ? Colors.color_check_button_background_checked : Colors.color_transparent
                        //backgroundColorHover: "#3F4042"  // 悬停时稍微亮一点
                //backgroundColorHover: "#2F3032"  // 悬停时稍微亮一点
            
                // 文字颜色（根据你的项目可能是白色）
                //titleColorNormal: "#EEEEEE"
                titleColorNormal: !btnContainer.selectHighlight ? Colors.color_check_button_text_checked: Colors.color_check_button_text_normal
                titleColorHover: Colors.color_EEEEEE
                // 移除边框
                // borderWidthNormal: 0
            
                // 内边距（根据 padding: 3px 50px）
                
                leftPadding: (80 - textImplicitWidth) / 2
                rightPadding: (80 - textImplicitWidth) / 2
                topPadding: 3.5
                bottomPadding: 3.5
                
            
                onClicked:{
                    mediaListViewModel.mediaCategoryType = DeviceMediaCategory.Original
                    //root.highlightTypeChanged(0)
                    //titleColorNormal = "#EEEEEE"
                }
            }

            // 高光
            IconTextButton {
                id: btnHighlight
                height: 24
                anchors.verticalCenter: parent.verticalCenter
            
                title: qsTr("pccut_home_highlight")
                titleFontSize: 12
                isTextOnly: true
            
                // 根据你提供的样式设置
                radius: 4  // border-radius: 4px
            
                // 背景色 #2F3032
                backgroundColorNormal: btnContainer.selectHighlight ? Colors.color_check_button_background_checked : Colors.color_transparent
                //backgroundColorHover: "#3F4042"  // 悬停时稍微亮一点
                // 文字颜色（根据你的项目可能是白色）
                //titleColorNormal: "#EEEEEE"
                titleColorNormal: btnContainer.selectHighlight ? Colors.color_check_button_text_checked: Colors.color_check_button_text_normal
                titleColorHover: Colors.color_EEEEEE
            
                // 移除边框
                //borderWidthNormal: 0
            
                // 内边距（根据 padding: 3px 50px）
                
                leftPadding: (80 - textImplicitWidth) / 2
                rightPadding: (80 - textImplicitWidth) / 2
                topPadding: 3.5
                bottomPadding: 3.5
                
            
                onClicked:{
                    mediaListViewModel.mediaCategoryType = DeviceMediaCategory.Highlight
                    //root.highlightTypeChanged(1)
                    mediaListViewModel.isShowRedDot = false  // 点击时隐藏红点
                    //titleColorNormal = "#EEEEEE"
                }

                Rectangle {
                    id:redBot
                    width: 5
                    height: 5
                    radius: 2.5
                    x: btnHighlight.width / 2 + btnHighlight.textImplicitWidth / 2 + 4
                    y: btnHighlight.topPadding + 2
                    color: Colors.color_F22443
                    visible: mediaListViewModel.isShowRedDot  // 绑定到状态变量
                }
            }
        }

    }
    // 添加按钮
    Rectangle {
        id: addBtn
        height: 24
        width: 16 + 8 * 2 + importText.width + 2
    
        // 高光功能关闭时显示
        visible: !mediaListViewModel.isTabsViewVisible && isLocal

        // 高光功能关闭时作为新手引导目标
        objectName: !mediaListViewModel.isTabsViewVisible ? actionableItemName.addMediaButton : ""

        color: mouseArea.containsMouse ? ColorsConfig.color_brand_20 : ColorsConfig.color_brand_10
        anchors {
            left: parent.left
            //leftMargin: 12
            verticalCenter: parent.verticalCenter
        }
        radius: RadiusConfig.radius_4_88
        LightToolTip {
            visible: addBtn.visible && mouseArea.containsMouse
            tip: qsTr("pccut_media_import")
        }
        Image {
            id: addImage
            width: 16
            height: 16
            anchors {
                left: parent.left
                leftMargin: 8
                verticalCenter: parent.verticalCenter
            }
            source: "qrc:/app_qrc/icons/editor_material_add.svg"
            sourceSize: Qt.size(16, 16)
        }

        Text {
            id: importText
            anchors {
                left: addImage.right
                leftMargin: 2
                verticalCenter: parent.verticalCenter
            }
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            color: ColorsConfig.color_brand
            text: qsTr("pccut_menu_import")
        }
        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
                clickAddFile();
            }
        }
    }
    // 筛选
    IconButton {
        id: filterBtn
        radius: 4
        anchors.verticalCenter: addBtn.verticalCenter
        anchors.right: gridBtn.left
        anchors.rightMargin: 10
        iconMargins: 2
        width: 24
        height: 24
        hoverTextFunc: function() {
            return qsTr("pccut_media_filter");
        }
        hoverColor: Colors.color_track_tool_button_background_hovered
        iconSource: (filterPopup.visible || mediaListViewModel.filterType !== 0) ? "qrc:/app_qrc/icons/editor_material_filter_selected.svg" : "qrc:/icons/editor_material_filter.svg"
        visible: mediaListViewModel.count > 0 && (!isSelectHighlightTab || !mediaListViewModel.isHighlightMediaListEmpty)
        onClicked: {
            var newPoint = filterBtn.mapToItem(null, width, height);
            filterPopup.x = newPoint.x - filterPopup.width;
            filterPopup.y = newPoint.y + 4;
            var operateModels = filterPopup.filterModel;
            operateModels.clear();
            // 这是一个很奇怪的写法, 主要是因为发现,所有的乱码都出现在popup上, 所以在展示的时候再刷新一下
            operateModels.append({"title": qsTr("pccut_media_filter_all"), "filterType": MediaListViewModel.FILTER_TYPE_ALL});
            operateModels.append({"title": qsTr("pccut_media_filter_video"), "filterType": MediaListViewModel.FILTER_TYPE_VIDEO});
            operateModels.append({"title": qsTr("pccut_media_filter_image"), "filterType": MediaListViewModel.FILTER_TYPE_IMAGE});
            operateModels.append({"title": qsTr("pccut_media_filter_favorite"), "filterType": MediaListViewModel.FILTER_TYPE_FAVORITE});
            filterPopup.open();
        }
    }

    // 筛选弹框
    FilterPopup {
        id: filterPopup
        x: 0
        y: 0
        parent: Overlay.overlay
        currentFilterType: mediaListViewModel.filterType
        height: 132
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        Overlay.modal: Rectangle {
            color: Colors.transparent
        }
        onClickFilterType: (filterType) => {
            mediaListViewModel.filterType = filterType;
            filterChange();
            let functionInterface = isLocal ? "local_file" : "connected_devices"

            switch(filterType) {
            case MediaListViewModel.FILTER_TYPE_ALL: {
                eventTracker.trackEvent("pccut_filter_materials_click", {"use_method": "all", "function": functionInterface})
                break
            }
            case MediaListViewModel.FILTER_TYPE_VIDEO: {
                eventTracker.trackEvent("pccut_filter_materials_click", {"use_method": "videos", "function": functionInterface})
                break
            }
            case MediaListViewModel.FILTER_TYPE_IMAGE: {
                eventTracker.trackEvent("pccut_filter_materials_click", {"use_method": "images", "function": functionInterface})
                break
            }
            case MediaListViewModel.FILTER_TYPE_FAVORITE: {
                eventTracker.trackEvent("pccut_filter_materials_click", {"use_method": "favorites", "function": functionInterface})
                break
            }
            }
        }
    }
    // 切换列表展示方式
    IconButton {
        id: gridBtn
        radius: 4
        anchors.verticalCenter: addBtn.verticalCenter
        anchors.right: sortBtn.left
        anchors.rightMargin: 10
        width: 24
        height: 24
        iconMargins: 2
        hoverTextFunc: function() {
            return qsTr("pccut_media_mode");
        }
        hoverColor: Colors.color_track_tool_button_background_hovered
        iconSource: mediaListViewModel.isGridMode ? "qrc:/icons/editor_material_change_mode.svg" : "qrc:/icons/editor_material_change_list_mode.svg"
        visible: mediaListViewModel.count > 0 && (!isSelectHighlightTab || !mediaListViewModel.isHighlightMediaListEmpty)
        onClicked: {
            mediaListViewModel.isGridMode = !mediaListViewModel.isGridMode;

            let functionInterface = isLocal ? "local_file" : "connected_devices"

            if (mediaListViewModel.isGridMode) {
                eventTracker.trackEvent("pccut_view_options_click", {"use_method": "grid", "function": functionInterface})
            } else {
                eventTracker.trackEvent("pccut_view_options_click", {"use_method": "list", "function": functionInterface})
            }
        }
    }
    // 排序
    IconButton {
        id: sortBtn
        radius: 4
        anchors.verticalCenter: addBtn.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: 10
        width: 24
        height: 24
        iconMargins: 2
        hoverColor: Colors.color_track_tool_button_background_hovered
        iconSource: sortPopupLoader.active ? "qrc:/app_qrc/icons/editor_material_sort_selected.svg" : "qrc:/icons/editor_material_sort.svg"
        hoverTextFunc: function() {
            return qsTr("pccut_media_sort");
        }
        visible: mediaListViewModel.count > 0 && (!isSelectHighlightTab || !mediaListViewModel.isHighlightMediaListEmpty)
        onClicked: {
            var newPoint = sortBtn.mapToItem(null, width, height);
            sortPopupLoader.active = true;
            var sortPopup = sortPopupLoader.item;
            sortPopup.x = newPoint.x - sortPopup.width;
            sortPopup.y = newPoint.y + 4;
            sortPopup.isLocal = root.isLocal;
            sortPopup.height = 264 - (!root.isLocal ?  32 : 0);
            sortPopup.currentOrderType = mediaListViewModel.orderType
            sortPopup.currentIsASC = mediaListViewModel.isASC
            sortPopup.open();
        }
    }
    Loader {
        id: sortPopupLoader
        // 默认不加载
        active: false
        // 排序弹框
        sourceComponent: SortPopup {
            parent: Overlay.overlay
            closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

            Overlay.modal: Rectangle {
                color: Colors.transparent
            }
            onClickASC: (isASC) => {
                mediaListViewModel.isASC = isASC;
            }
            onClosed: {
                sortPopupLoader.active = false;
            }
            onClickOrderType: (orderType) => {
                mediaListViewModel.orderType = orderType;
                let functionInterface = isLocal ? "local_file" : "connected_devices"
                switch(orderType) {
                case MediaListViewModel.ORDER_TYPE_IMPORT: {
                    eventTracker.trackEvent("pccut_sort_click", {"use_method": "import_time", "function": functionInterface})
                    break
                }
                case MediaListViewModel.ORDER_TYPE_CREATE: {
                    eventTracker.trackEvent("pccut_sort_click", {"use_method": "creation_time", "function": functionInterface})
                    break
                }
                case MediaListViewModel.ORDER_TYPE_EDIT: {
                    eventTracker.trackEvent("pccut_sort_click", {"use_method": "edit_time", "function": functionInterface})
                    break
                }
                case MediaListViewModel.ORDER_TYPE_TYPE: {
                    eventTracker.trackEvent("pccut_sort_click", {"use_method": "file_type", "function": functionInterface})
                    break
                }
                case MediaListViewModel.ORDER_TYPE_SIZE: {
                    eventTracker.trackEvent("pccut_sort_click", {"use_method": "file_size", "function": functionInterface})
                    break
                }
                case MediaListViewModel.ORDER_TYPE_NAME: {
                    eventTracker.trackEvent("pccut_sort_click", {"use_method": "file_name", "function": functionInterface})
                    break
                }
                }
            }
        }
    }
}
