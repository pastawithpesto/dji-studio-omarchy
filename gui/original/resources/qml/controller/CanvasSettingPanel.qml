import QtQuick 2.15
import Controls 1.0
import Config 1.0
import VideoConfig 1.0
import app_qrc 1.0

/**
  * @author: pansy.guo
  * @details 画幅选择界面
  * @date: 2024-05-21 21:08:53
  */
LightPopup {

    // 点击item信号
    signal clickCanvasItemSignal(int new_canvas_type)
    // 点击空白位置，关闭界面的信号
    signal closeSignal

    property real canvasRectangleWidth: 101
    property real canvasRectangleHeight: 0
    needTransparent:true
    width: parent.width
    height: parent.height
    z: Infinity
    dim: false

    contentItem: Item {

        MouseArea {
            anchors.fill: parent
            onClicked: {
                closeSignal();
                close();
            }
        }
        ListModel {
            id: canvasMenu
            Component.onCompleted: {
                // 通过append动态添加数据项
                append({ 
                    title: videoConfig.getQmlItemByCanvasType(VideoConfig.CANVASRATIOTYPE_16_9).name, 
                    type: VideoConfig.CANVASRATIOTYPE_16_9, 
                    checked: false 
                });
                append({ 
                    title: videoConfig.getQmlItemByCanvasType(VideoConfig.CANVASRATIOTYPE_9_16).name, 
                    type: VideoConfig.CANVASRATIOTYPE_9_16, 
                    checked: false 
                });
                append({ 
                    title: videoConfig.getQmlItemByCanvasType(VideoConfig.CANVASRATIOTYPE_1_1).name, 
                    type: VideoConfig.CANVASRATIOTYPE_1_1, 
                    checked: false 
                });
                append({ 
                    title: videoConfig.getQmlItemByCanvasType(VideoConfig.CANVASRATIOTYPE_4_3).name, 
                    type: VideoConfig.CANVASRATIOTYPE_4_3, 
                    checked: false 
                });
                append({ 
                    title: videoConfig.getQmlItemByCanvasType(VideoConfig.CANVASRATIOTYPE_3_4).name, 
                    type: VideoConfig.CANVASRATIOTYPE_3_4, 
                    checked: false 
                });
                menu.setModel(canvasMenu);
            }
        }
        
        DropMenuNoShader {
            id: menu
            width: canvasRectangleWidth
            height: canvasRectangleHeight
            bkColor:Colors.color_141414_85
            hoverColor:ColorsConfig.color_FFFFFF15_4DFFC920
            onItemChecked: (canvasType) => {
                clickCanvasItemSignal(canvasType);
                close();
            }
        }
    }
    // widget：画幅按钮  selectedCanvas：选中的画幅type
    function show(widget, selectedCanvas) {
        menu.updateData(selectedCanvas);
        canvasRectangleHeight = menu.dataCount * 32 + 4;
        menu.x = UiUtils.getGlobalPosition(widget).x - (canvasRectangleWidth - widget.width) / 2;
        menu.y = UiUtils.getGlobalPosition(widget).y - canvasRectangleHeight - 4;
        open();
    }
}
