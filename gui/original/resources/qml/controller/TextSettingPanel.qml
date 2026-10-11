import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.3
import LightRectangle 1.0
import Config 1.0
import Controls 1.0
import Qt5Compat.GraphicalEffects
import Nova 1.0

/**
 * @author hongbin.shi
 * @desc 文本片段参数设置panel（nova TextViewModel 驱动）
 * @create_date 2025-12-10
 */


Rectangle {
    id: root
    anchors.fill: parent
    color: Colors.color_title_area_background
    visible: true

    TextViewModel {
        id: textViewModel

        onHasClipChanged: {
            root.visible = textViewModel.hasClip
            if (textViewModel.hasClip) {
                forceActiveFocus()
            }
        }
    }

    ListModel {
        id: textHeaderListModel
        ListElement { text: qsTr("pccut_word_set_title") }
    }

    ListView {
        id: textHederList
        objectName: qsTr("textHeaderListView")
        x: 12
        y: 0
        width: parent.width - 24
        height: 45
        spacing: 20
        orientation: ListView.Horizontal
        clip: true
        model: textHeaderListModel
        boundsBehavior: Flickable.StopAtBounds

        property bool needScroll: contentWidth > parent.width - 24
        delegate: MouseArea {
            objectName: qsTr("textHeaderListViewItem") + index
            width: textLabel.width
            onClicked: {}
            height: textHederList.height
            Text {
                id: textLabel
                anchors.centerIn: parent
                text: model.text
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                color: Theme.settingTabSelectedTitleColor
            }
        }
    }

    Item {
        id: textTabview
        property alias currentIndex: textStackLayout.currentIndex
        clip: true
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            top: textHederList.bottom
        }
        property int count: dataList.count

        readonly property ListModel tmpModels: ListModel {}
        property ListModel dataList: ListModel {}

        StackLayout {
            id: textStackLayout
            objectName: qsTr("textStackLayout")
            anchors.fill: parent
            currentIndex: 0

            TextSettingTab {
                id: textSettingTab
                textViewModel: textViewModel
            }
        }
    }
}
