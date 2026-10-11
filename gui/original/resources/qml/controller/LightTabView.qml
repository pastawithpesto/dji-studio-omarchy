import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.15

Item {
    id: tabview
    // 当前使用的index
    property alias currentIndex: stackLayout.currentIndex
    onCurrentIndexChanged: {
        refreshTab();
    }
    clip: true
    // 当前的数量
    property int count: dataList.count

    readonly property ListModel tmpModels: ListModel {}
    property ListModel dataList: ListModel {}

    StackLayout {
        id: stackLayout
        objectName: actionableItemName.dasbBoardStackLayout
        anchors.fill: parent
        Repeater {
            model: dataList
            Loader {
                property bool isLoad: stackLayout.currentIndex === index
                objectName: actionableItemName.dashBoardTabLoader + index
                active: false
                // 懒加载：仅当页面是当前页时激活加载
                onIsLoadChanged: {
                    if (isLoad) {
                        active = true;
                    }
                }
                sourceComponent: model.component
            }
        }
    }

    function refreshTab() {
        stackLayout.currentIndex = currentIndex
    }

    function getTab(index) {
        if (index < 0 || index >= dataList.count) {
            return null;
        }
        return dataList.get(index).component;
    }

    function addTab(textValue, componentValue, trackEventNameValue) {
        tmpModels.append({
            text: textValue,
            component: componentValue,
            trackEventName: trackEventNameValue
        });
    }

    function syncTab() {
        dataList = tmpModels;
    }

    function clearTableView() {
        dataList.clear();
        tmpModels.clear();
        refreshTab();
    }
}
