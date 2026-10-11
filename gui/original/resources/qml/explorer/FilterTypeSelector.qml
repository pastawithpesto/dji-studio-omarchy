import QtQuick 2.15
import LightRectangle 1.0
import Config 1.0
import Controls 1.0
import FilterCategorysModel 1.0
import FilterListModel 1.0
import QmlConstants 1.0
import app_qrc 1.0


Item {
    property FilterCategorysModel allFilterCategoryModels
    property int selectIndex: allFilterCategoryModels.selectIndex
    onSelectIndexChanged: {
        listView.positionViewAtIndex(selectIndex, ListView.Contain);
    }
    property bool isSelectedImportTab: allFilterCategoryModels.selectIndex < 0

    // 状态管理：导入Tab 和 分类Tab 的切换
    StateGroup {
        states: [
            State {
                name: "importState"
                when: isSelectedImportTab
                PropertyChanges { target: cloudLutBtn; isExpanded: false }
            },
            State {
                name: "categoryState"
                when: !isSelectedImportTab
                PropertyChanges { target: cloudLutBtn; isExpanded: true }
            }
        ]
    }

    // 监听数据加载完成，自动选中第一个分类
    Connections {
        target: allFilterCategoryModels
        function onCountChanged(count) {
            // 当数据加载完成且不在导入Tab时，自动选中第一个
            if (!isSelectedImportTab &&
                allFilterCategoryModels.selectIndex < 0 &&
                count > 0) {
                allFilterCategoryModels.selectIndex = 0
                allFilterCategoryModels.clickSection(0)
            }
        }
    }

    FoldListButton{
        id: importLutBtn
        x: 16
        y: 16
        height: 28
        width: parent.width - 32
        anchors{
            horizontalCenter: parent.horizontalCenter
        }
        title: qsTr("pccut_filter_cube_add_lut_tab")
        isSelect: isSelectedImportTab
        isShowImg: false
        onCusClicked: {
            if (allFilterCategoryModels.selectIndex >= 0) {
                allFilterCategoryModels.selectIndex = -1
                allFilterCategoryModels.clickSection(-1)
            }
        }
    }

    FoldListButton {
        id: cloudLutBtn
        x: 16
        anchors.top: importLutBtn.bottom
        anchors.topMargin: 16
        height: 28
        width: listView.width - 32
        title: qsTr("pccut_filter_add_fail_tab")
        isShowImg: true
        isSelect: !isSelectedImportTab
        onCusClicked: {
            if (allFilterCategoryModels.selectIndex < 0) {
                allFilterCategoryModels.selectIndex = 0
                allFilterCategoryModels.clickSection(0)
            }
        }
    }

    ListView {
        id: listView
        visible: cloudLutBtn.isExpanded
        clip: true
        height: visible ? Math.min(contentHeight, parent.height - importLutBtn.height - cloudLutBtn.height - 56) : 0
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: cloudLutBtn.bottom
        anchors.topMargin: 0
        anchors.bottom: parent.bottom
        model: allFilterCategoryModels
        header: Item { height: 8 }
        footer: Item {
            height: 16
        }
        spacing: 8
        delegate: Item {
            height: 28
            width: listView.width - 32
            x: 16

            MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true
                LightToolTip {
                    visible: mouseArea.containsMouse && menuText.implicitWidth > menuText.width
                    tip: name
                }

                onClicked: {
                    allFilterCategoryModels.selectIndex = index;
                    allFilterCategoryModels.clickSection(index);
                }
            }

            Text {
                id: menuText
                text: name
                font.pixelSize: 12
                color: allFilterCategoryModels.selectIndex === index ? ColorsConfig.color_brand : Colors.color_check_button_text_normal
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
                anchors.left: parent.left
                anchors.rightMargin: QmlConstants.isWhiteXtra() ? 12 : 8
                anchors.leftMargin: QmlConstants.isWhiteXtra() ? 18 : 12
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
