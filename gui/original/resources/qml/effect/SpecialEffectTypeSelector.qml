import QtQuick 2.15
import Config 1.0
import Controls 1.0
import SpecialEffectCategoriesModel 1.0
import QmlConstants 1.0
import app_qrc 1.0
import "../explorer"

Item {
    property SpecialEffectCategoriesModel allEffectCategoryModels
    property int curTabIndex: allEffectCategoryModels.selectIndex

    onCurTabIndexChanged: {
        listView.positionViewAtIndex(curTabIndex, ListView.Contain);
    }

    property bool isSelectedImportTab: allEffectCategoryModels.selectIndex < 0

    // 状态管理：收藏Tab 和 分类Tab 的切换
    StateGroup {
        states: [
            State {
                name: "collectState"
                when: isSelectedImportTab
                PropertyChanges { target: resourceItemsBtn; isExpanded: false }
            },
            State {
                name: "categoryState"
                when: !isSelectedImportTab
                PropertyChanges { target: resourceItemsBtn; isExpanded: true }
            }
        ]
    }

    FoldListButton {
        id: collectedItemsBtn
        x: 16
        y: 16
        height: 28
        width: parent.width - 32
        anchors {
            horizontalCenter: parent.horizontalCenter
        }
        title: qsTr("pccut_media_favorites")
        isSelect: isSelectedImportTab
        isShowImg: false
        onCusClicked: {
            if (allEffectCategoryModels.selectIndex >= 0) {
                allEffectCategoryModels.selectIndex = -1;
                allEffectCategoryModels.clickSection(-1);
            }
        }
    }

    FoldListButton {
        id: resourceItemsBtn
        x: 16
        anchors.top: collectedItemsBtn.bottom
        anchors.topMargin: 16
        height: 28
        width: listView.width - 32
        title: qsTr("pccut_tab_general_effects")
        isShowImg: true
        isSelect: !isSelectedImportTab
        onCusClicked: {
            if (allEffectCategoryModels.selectIndex < 0) {
                allEffectCategoryModels.selectIndex = 0;
                allEffectCategoryModels.clickSection(0);
            }
        }
    }

    ListView {
        id: listView
        visible: resourceItemsBtn.isExpanded
        height: visible ? Math.min(contentHeight, parent.height - collectedItemsBtn.height - resourceItemsBtn.height - 56) : 0
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: resourceItemsBtn.bottom
        anchors.topMargin: 8
        anchors.bottom: parent.bottom
        model: allEffectCategoryModels
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
                Loader {
                    active: mouseArea.containsMouse && menuText.implicitWidth > menuText.width
                    sourceComponent: Component {
                        LightToolTip { tip: name }
                    }
                }

                onClicked: {
                    allEffectCategoryModels.selectIndex = index;
                    allEffectCategoryModels.clickSection(index);
                }
            }

            Text {
                id: menuText
                text: name
                font.pixelSize: 12
                color: allEffectCategoryModels.selectIndex === index ? ColorsConfig.color_brand : Colors.color_check_button_text_normal
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.rightMargin: QmlConstants.isWhiteXtra() ? 12 : 8
                anchors.leftMargin: QmlConstants.isWhiteXtra() ? 18 : 12
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignLeft
            }
        }
    }
}
