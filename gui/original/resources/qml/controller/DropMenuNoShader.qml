import QtQuick 2.15
import Controls 1.0
import Config 1.0
import VideoConfig 1.0
import Qt5Compat.GraphicalEffects
import app_qrc 1.0

// move from CanvasSettingPanel.qml
LightClipRectangle {
    property int customRadius: 8  // 固定为 8，与 SubTitlePopup 一致
    clip: true
    radius: [8, 8, 8, 8]  // 固定为 8
    id: canvasRectangle
    property int dataCount: itemModels.count
    property string textColor:ColorsConfig.color_EEEEEE_4DFFC9
    property string bkColor:Colors.color_454649
    property string hoverColor:ColorsConfig.color_68696D_4DFFC920
    signal itemChecked(int itemType);
    ShaderEffectSource {
        id: shaderSource
        sourceItem: mainPanel
        sourceRect: Qt.rect(canvasRectangle.x, canvasRectangle.y, canvasRectangle.width, canvasRectangle.height)
        width: parent.width
        height: parent.height
        live: true
        smooth: true
    }
    //高斯调节
    FastBlur {
        anchors.fill: parent
        source: shaderSource
        radius: 48
    }
    ListModel {
        id: itemModels
    }
    Rectangle {
        anchors.fill: parent
        border.color: Colors.color_444444
        border.width: 0.5
        radius: 8
        color:bkColor  // 动态背景切换
    }
    Column {
        topPadding: 4
        spacing: 4
        anchors.fill: parent
        Repeater {
            model: itemModels
            anchors.fill: parent
            Rectangle {
                height: 28
                width: canvasRectangle.width - 8
                radius: RadiusConfig.radius_4_8
                color: mouse.containsMouse ? hoverColor : Colors.color_transparent
                anchors.horizontalCenter: parent.horizontalCenter

                Image {
                    id: checkIcon
                    anchors {
                        left: parent.left
                        leftMargin: 8
                        verticalCenter: parent.verticalCenter
                    }
                    width: 16
                    height: 16
                    source: model.checked ? "qrc:/app_qrc/icons/icon_compose_check.svg" : ""
                    sourceSize: Qt.size(16, 16)
                }
                Text {
                    anchors {
                        left: checkIcon.right
                        leftMargin: 8
                        top: parent.top
                        bottom: parent.bottom
                        right: parent.right
                    }
                    color: (model.checked || mouse.containsMouse) ? textColor : Colors.color_EEEEEE
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: 11
                    text: model.title
                }
                MouseArea {
                    id: mouse
                    hoverEnabled: true
                    anchors.fill: parent
                    preventStealing: true
                    onClicked: {
                        for (var i = 0; i < itemModels.count; i++) {
                            let item = itemModels.get(i);
                            item.checked = false;
                            if (i === index) {
                                item.checked = true;
                                itemChecked(item.type);
                                return;
                            }
                        }
                    }
                }
            }
        }
    }
    function setModel(model){
        itemModels.clear();  // 清空原有数据
        for (var i = 0; i < model.count; i++) {
            itemModels.append(model.get(i)); // 逐条添加新数据
        }
    }
    function updateData(selectedItem) {
        for (var i = 0; i < itemModels.count; i++) {
            let item = itemModels.get(i);
            if(item.type === selectedItem){
                itemModels.setProperty(i, "checked", true); 
            }else{
                itemModels.setProperty(i, "checked", false); 
            }
        }
    }
}
