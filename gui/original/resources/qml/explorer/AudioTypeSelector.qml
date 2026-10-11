import QtQuick 2.15
import LightRectangle 1.0
import Config 1.0
import Controls 1.0
import QtQuick.Controls
import AudioCategoryListModel 1.0
import QmlConstants 1.0
import app_qrc 1.0

Item {
    property AudioCategoryListModel categoryModel
    property int selectIndex: categoryModel.selectIndex
    onSelectIndexChanged: {
        listView.positionViewAtIndex(selectIndex, ListView.Contain);
    }
    property bool isSelectedImportTab: categoryModel.selectIndex < 0

    Component.onCompleted: {
        if (listView.count < 1) {
            categoryModel.fetchData();
        }
    }

    // 状态管理：导入Tab 和 分类Tab 的切换
    StateGroup {
        states: [
            State {
                name: "importState"
                when: isSelectedImportTab
                PropertyChanges { target: categoryAudioBtn; isExpanded: false }
            },
            State {
                name: "categoryState"
                when: !isSelectedImportTab
                PropertyChanges { target: categoryAudioBtn; isExpanded: true }
            }
        ]
    }

    // 监听数据加载完成，自动选中第一个分类
    Connections {
        target: categoryModel
        function onCountChanged(count) {
            // 当数据加载完成且不在导入Tab时，自动选中第一个
            if (!isSelectedImportTab &&
                categoryModel.selectIndex < 0 &&
                count > 0) {
                categoryModel.selectIndex = 0
            }
        }
    }

    Connections {
        target: globalSignal

        //草稿切换时，音乐二级tab切换回第一个
        function onActivedProjectChanged(id) {
            if(draftUIManager.isActiveProjectExist()) {
                categoryModel.selectIndex = 0;
            }
        }
    }

    FoldListButton{
        id: importAudioBtn
        x: 16
        y: 16
        height: 28
        width: parent.width - 32
        anchors{
            horizontalCenter: parent.horizontalCenter
        }
        title: qsTr("pccut_music_import")
        isSelect: isSelectedImportTab
        isShowImg: false
        onCusClicked: {
            if (categoryModel.selectIndex >= 0) {
                categoryModel.selectIndex = -1
            }
        }
    }

    FoldListButton {
        id: categoryAudioBtn
        x: 16
        anchors.top: importAudioBtn.bottom
        anchors.topMargin: 16
        height: 28
        width: listView.width - 32
        title: qsTr("pccut_audio_category")
        isShowImg: true
        isSelect: !isSelectedImportTab
        onCusClicked: {
            if (categoryModel.selectIndex < 0) {
                categoryModel.selectIndex = 0
            }
        }
    }

    ListView {
        id: listView
        visible: categoryAudioBtn.isExpanded
        clip: true
        height: visible ? Math.min(contentHeight, parent.height - importAudioBtn.height - categoryAudioBtn.height - 56) : 0
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: categoryAudioBtn.bottom
        anchors.topMargin: 0
        anchors.bottom: parent.bottom
        model: categoryModel
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
                    categoryModel.selectIndex = index;
                }
            }

            Text {
                id: menuText
                text: name
                font.pixelSize: 12
                color: categoryModel.selectIndex === index ? ColorsConfig.color_brand : Colors.color_check_button_text_normal
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
                anchors.left: parent.left
                anchors.rightMargin: QmlConstants.isWhiteXtra() ? 12 : 8
                anchors.leftMargin: QmlConstants.isWhiteXtra() ? 18 : 12
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
