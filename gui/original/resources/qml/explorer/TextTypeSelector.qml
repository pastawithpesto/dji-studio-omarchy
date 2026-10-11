import QtQuick 2.15
import LightRectangle 1.0
import Config 1.0
import Controls 1.0
import QtQuick.Controls
import app_qrc 1.0
import OverlayTextListModel 1.0

Item {
    width: 120
    // 当前文字列表展示数据
    property OverlayTextListModel textListModel

    // 创建子分类数据模型
    property var subCategoryModel: [
        // {"subName": "热门", "id": "hot"},
        // {"subName": "Vlog", "id": "vlog"},
        // {"subName": "旅行", "id": "travel"},
        // {"subName": "假期", "id": "holiday"},
        // {"subName": "时间", "id": "time"},
        // {"subName": "地点", "id": "location"}
    ]
    
    // 当前选中的主分类索引
    property int selectedCategoryIndex: 0
    // 当前选中的文字模板子分类索引
    property int templateSubCategoryIndex: -1
    // 保存文字模板的menuModel
    property ListModel templateMenuModel: null
    
    // 处理主分类选择
    function handleCategorySelection(index, categoryId) {
        selectedCategoryIndex = index;
        templateSubCategoryIndex = -1;
        //globalSignal.textCategorySelected(categoryId);
    }
    
    // 处理模板子分类选择
    function handleTemplateSubCategorySelection(index) {
        templateSubCategoryIndex = index;
        selectedCategoryIndex = -1;
        if (templateMenuModel) {
            globalSignal.textSubCategorySelected(templateMenuModel.get(index).id);
        }
    }
    
    // 初始化模板子分类数据
    function populateTemplateMenuModel(menuModel) {
        menuModel.clear();
        templateMenuModel = menuModel;
        for (var i = 0; i < subCategoryModel.length; i++) {
            menuModel.append({
                "subName": subCategoryModel[i].subName,
                "id": subCategoryModel[i].id
            });
        }
    }
    ListModel {
        id: categoryModel
        ListElement {
            name: qsTr("pccut_word_base")
            other: "basic"
        }
        // ListElement{
        //     name: "花字"
        //     other: "fancy"
        // }
    }
    
    ListView {
        id: listView
        anchors.fill: parent
        boundsBehavior: GridView.StopAtBounds
        topMargin: 16
        spacing: 8
        model:categoryModel
        ScrollBar.vertical: ScrollBar {}

        delegate: Rectangle {
            property bool isSelected: selectedCategoryIndex === index
            height: 28
            color: isSelected ? Colors.color_2F3032 : Colors.transparent
            radius: 4
            anchors.horizontalCenter: parent.horizontalCenter
            width: listView.width - 32

            Accessible.role: Accessible.Button
            Accessible.description: "text_categorytab_" + name

            MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true
                LightToolTip {
                    visible: mouseArea.containsMouse && menuText.implicitWidth > menuText.width
                    tip: name
                }

                onClicked: {
                    handleCategorySelection(index, other);
                }
            }

            Text {
                id: menuText
                text: name
                font.pixelSize: 12
                color: (isSelected ? ColorsConfig.color_brand : Colors.color_EEEEEE)
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                leftPadding: 12
                verticalAlignment: Text.AlignVCenter
            }
        }
        
        // 文字模板使用FoldListTab
         // Component {
         //     id: templateFoldListTabComponent
         //     FoldListTab {
         //         id: templateFoldListTab
         //         width: listView.width - 32
         //         title: qsTr("文字模版")
         //         selectSubIdx: templateSubCategoryIndex
         //         onClickIndex: (index) => {
         //             handleTemplateSubCategorySelection(index);
         //         }
         //     }
         // }

         // 自定义脚注，放置文字模板的FoldListTab
         // footer: Loader {
         //     sourceComponent: templateFoldListTabComponent
         //     height: 28 + (item && item.isExpanded ? item.menuModel.count * 36 : 0)
         //     anchors.horizontalCenter: parent.horizontalCenter

         //     // 当Loader加载完成后，初始化menuModel
         //     onLoaded: {
         //         populateTemplateMenuModel(item.menuModel);
         //     }
         // }
        
    }
}
