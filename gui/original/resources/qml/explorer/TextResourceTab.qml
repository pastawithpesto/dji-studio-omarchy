import QtQuick 2.15
import Config 1.0
import Controls 1.0
import Qt5Compat.GraphicalEffects
import app_qrc 1.0
import QtQuick.Controls
import QtQuick.Layouts
import OverlayTextListModel 1.0
import Qt.labs.qmlmodels 1.0

Item {
    id: textResourceTab
    height: 200
    width: parent.width
    property int categoryIndex: selectCategoryIndex    //当前选中的左侧目录列表类型索引
    // 当前文字列表展示数据
    property OverlayTextListModel textListModel

    property var currentSelectedItem: null
    property bool hasClearSelectItem: false

    //监听点击背景 (为了做取消选中)
    Item {
        id: bgView
        visible: true
        parent: UiUtils.getTopParent(textResourceTab)
        anchors {
            fill: parent
            leftMargin: 5
            rightMargin: 5
            topMargin: 34
            bottomMargin: 5
        }
        PointHandler {
             onGrabChanged: (transition, point) => {
                point.accepted = false;
                if (point.timeHeld !== 0) {
                    return;
                }
                hasClearSelectItem = false;
            }
        }
    }

    ListModel {
        id: listDataModel
        ListElement {
            category: qsTr("pccut_word_base")
        }
    }
    ListView {
        id: resourceListView
        anchors.fill: parent
        model: listDataModel
        spacing: 26
        delegate: resourceListDelegate
    }

    Component {  // 某一个分类的TableView
        id: resourceListDelegate
        Item{
            id: containerItem
            height: categoryTitle.height + resourceTableView.contentHeight // 绑定高度到内容高度
            anchors {
                left: parent.left
                right: parent.right
            }

            Text {
                id: categoryTitle
                width: containerItem.width //100
                font.pixelSize: 12
                text: category
                color: ColorsConfig.color_FFFFFF_6DFFD3
                anchors{
                    left: parent.left
                    leftMargin: 12
                }
            }

            // 其中展示某一个分类下的所有资源
            GridView {
                id: resourceTableView
                implicitHeight: contentHeight
                anchors {
                    top: categoryTitle.bottom
                    topMargin: 12
                    left: parent.left
                    leftMargin: 12
                    right: parent.right
                }
                cellWidth: 80
                cellHeight: 80
                model: textListModel
                delegate: TextMoveItemView {
                    id: gridItem
                    visible: true
                    textListModel: textResourceTab.textListModel
                    selected: false
                }
            }
        }
    }
}
