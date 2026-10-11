import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.3
import Qt.labs.platform 1.1
import Config 1.0
import Controls 1.0
import Qt5Compat.GraphicalEffects
import MultiTrackView 1.0
import OverlayTextListModel 1.0
import MaterialDragController 1.0
import OverlayTextDragBussiness 1.0
import TrackDockViewModel 1.0
import app_qrc 1.0
import Qt.labs.qmlmodels


Item {
    id: root
    width: 80
    height: 80
    property OverlayTextListModel textListModel
    property var selected

    property bool clearSelect: hasClearSelectItem
    property bool clickSelect: false  // 临时状态
    property bool isSelect: clearSelect && clickSelect // 处理选中态
    onClearSelectChanged : {
        if(hasClearSelectItem == false){
            clickSelect = false;
        }
    }

    // 默认文字UI
    Rectangle {
         id: defaultTextUI
         width: 80
         height: 80
         color: Colors.color_2F3032
         anchors.left: parent.left
         anchors.top: parent.top
         radius: 6
         border {
             width: root.isSelect ? 2 : 0
             color: root.isSelect ? ColorsConfig.color_brand : Colors.color_transparent
         }

         Text {
             id: defaultTextLabel
             text: title
             font.pixelSize: 12
             anchors.centerIn: parent
             horizontalAlignment: Text.AlignHCenter
             width: 60
             color: Colors.color_EEEEEE
             wrapMode: Text.Wrap
         }

         MouseArea{
             id: mouseArea
             anchors.fill: parent
             hoverEnabled: true

             drag.target: materialDragController.dragCoverItem  // 必须设置
             onClicked: {
                 clickSelect = true;
                 hasClearSelectItem = true;
             }
             onPressed: (mouseEvent) =>{
                mouseEvent.accepted = true;
             }

             onPositionChanged: {
                 if(pressed){
                     if(!materialDragController.visible){
                         materialDragController.visible = true;
                         var pos = mapToItem(lightWindow.contentItem, mouseX, mouseY);
                         materialDragController.mousePoint = pos;
                     }

                     var posInWindow = mapToItem(lightWindow.contentItem, mouseX, mouseY);
                     materialDragController.mousePoint = posInWindow;
                 }

                var point = Qt.point(mouseArea.mouseX, mouseArea.mouseY);
                var mousePos = mapToItem(textdAdd, mouseArea.mouseX, mouseArea.mouseY);
                textdAdd.containsMouse = textdAdd.contains(mousePos);
             }

             onReleased: {
                 if(materialDragController.visible){
                     materialDragController.visible = false;
                 }
             }

             onCanceled: {
                 if(materialDragController.visible){
                     materialDragController.visible = false;
                 }
             }
         }
   }
    Image {
       id: textdAdd
       anchors.right: defaultTextUI.right
       anchors.bottom: defaultTextUI.bottom
       anchors.rightMargin: 4
       anchors.bottomMargin: 4

       property bool containsMouse: false
       source: "qrc:/app_qrc/icons/filter_add.svg"
       visible: mouseArea.containsMouse
       sourceSize: Qt.size(20, 20)
       MouseArea {
           anchors.fill: parent
           onClicked: {
               globalSignal.videoSelected(null);
               editorManager.pause();
               //textListModel.selectedTextIndex = -1;
               textListModel.addDefaultTextClick();
           }
           LightToolTip {
               id: filterAddTip
               visible: textdAdd.visible && textdAdd.containsMouse
               tip: qsTr("pccut_word_title_add_toast")
           }
       }
    }

    //处理封面拖拽的组件
    MaterialDragController{
        id: materialDragController
        visible: false;
        parentItem: lightWindow.contentItem // 必须设置: 确保可以在整个窗口中进行拖拽
        dragBusinessManager: OverlayTextDragBussiness{
            view: tracks.multiTrackView
            textListModel: root.textListModel
            currentIndex: index
        }
        dragCoverItem: Rectangle{
            width: 80
            height: 80
            color: Colors.color_2F3032
            radius: 6
            border {
                width: 2      // 边框宽度
                color: ColorsConfig.color_FD5050_4DFFC9 // 边框颜色
            }

            Text {
                id: dragTextLabel
                text: title
                font.pixelSize: 12
                anchors.centerIn: parent
                color: Colors.color_EEEEEE
            }
        }
        dragItemInTrack: Rectangle{
            property real frameLength: 0
            property real pxPerFrame: 0
            width: 90 //frameLength * pxPerFrame 在c++中进行动态调整
            height: 20
            color: ColorsConfig.color_0A9B83_transparent
            radius: 4
            clip: true

            Text {
                id: coverTextLabel
                text: title
                font.pixelSize: 10
                color: ColorsConfig.color_95FCEB_95FCEB
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 4
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignLeft
            }
        }
    }
}
