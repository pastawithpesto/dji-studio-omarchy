import QtQuick 2.15
import LightRectangle 1.0
import Config 1.0
import Controls 1.0
import TransitionMaterialViewModel 1.0
import TransitionCategorysModel 1.0
import QmlConstants 1.0
import app_qrc 1.0

/**
 * @author hugo.li
 * @desc 转场左侧列表
 * @create_date 2025-11-13
 */
Item {
    property TransitionCategorysModel transitionCategorysModel
    property int selectIndex: transitionCategorysModel.selectIndex
    onSelectIndexChanged: {
        listView.positionViewAtIndex(selectIndex, ListView.Contain);
    }

    property bool isSelectedCollectTab: transitionCategorysModel.selectIndex < 0

    StateGroup {
        id: stateGroup
        states: [
            State {
                name: "collectState"
                when:isSelectedCollectTab
                PropertyChanges { target: collectBtn; isSelect: true }
                PropertyChanges { target: cloudTransitionBtn; isSelect: false }
                PropertyChanges { target: collectBtn; isExpanded: true }
                PropertyChanges { target: cloudTransitionBtn; isExpanded: false }
            },
            State {
                name: "davinciState"
                when: !isSelectedCollectTab
                PropertyChanges { target: collectBtn; isSelect: false }
                PropertyChanges { target: cloudTransitionBtn; isSelect: true }
                PropertyChanges { target: collectBtn; isExpanded: false }
                PropertyChanges { target: cloudTransitionBtn; isExpanded: true }
            }
        ]
    }

    TransitionFoldListButton {
        id: collectBtn
        x: 16
        y: 16
        height: 28
        width: listView.width - 32
        title: qsTr("pccut_resource_transition_like_title")
        isShowImg: false
        onCusClicked: {
            if (transitionCategorysModel.selectIndex >= 0) {
                transitionCategorysModel.selectIndex = -1;
            }
        }
    }

    TransitionFoldListButton {
        id: cloudTransitionBtn
        x: 16
        anchors.top: collectBtn.bottom
        anchors.topMargin: 16
        height: 28
        width: listView.width - 32
        title: qsTr("pccut_resource_transition_tab_1")
        onCusClicked: {
            if (transitionCategorysModel.selectIndex < 0) {
                transitionCategorysModel.selectIndex = 0;
            }
        }
    }


    ListView {
        id: listView
        visible:cloudTransitionBtn.isExpanded
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: cloudTransitionBtn.bottom
        anchors.topMargin: 0
        anchors.bottom: parent.bottom

        clip: true
        header: Item { height: 8 }
        model: transitionCategorysModel

        footer: Item {
            height: 16
        }
        spacing: 8


        delegate: Rectangle {
            height: 28
            width: parent.width - 32
            // color: selectIndex === index ? Colors.color_2F3032 : Colors.transparent
            color: Colors.transparent
            radius: 4
            anchors.horizontalCenter: parent.horizontalCenter

            MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true
                LightToolTip {
                    visible: mouseArea.containsMouse && menuText.implicitWidth > menuText.width
                    tip: name
                }
                onClicked: {
                    transitionCategorysModel.selectIndex = index;
                }
            }

            Text {
                id: menuText
                text: name
                font.pixelSize: 12
                color: selectIndex === index ? ColorsConfig.color_brand : Colors.color_check_button_text_normal
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.rightMargin: QmlConstants.isWhiteXtra() ? 12 : 8
                anchors.leftMargin: QmlConstants.isWhiteXtra() ? 18 : 12
                anchors.verticalCenter: parent.verticalCenter
                // horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
