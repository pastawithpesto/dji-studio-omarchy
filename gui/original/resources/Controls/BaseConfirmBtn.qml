import QtQuick 2.15
import QtQuick.Controls
import Config 1.0
import QtQuick.Window 2.15
import app_qrc 1.0
import Controls 1.0

Rectangle {
    id: btn
    property string btnText:qsTr("pccut_player_screenshot_yes")
    property int type:0
    property bool canUse: true
    property bool clickEnabled: true
    signal customClick
    color: {
        if(type == 0){//0是确定按钮
            if(canUse){
                return confirmMouseArea.containsMouse ? ColorsConfig.color_F44C65_6DFFD3 : ColorsConfig.color_F22443_4DFFC9
            }else{
                return ColorsConfig.color_F22443_4DFFC9;
            }
        }else{
            if(canUse){
                return confirmMouseArea.containsMouse ? Colors.color_7A7B80: ColorsConfig.color_68696D_4DFFC920
            }else{
                return ColorsConfig.color_68696D_4DFFC920;
            }
        }
    }
    opacity: canUse?1:0.2
    radius: RadiusConfig.radius_4_88
    Text {
        id: textItem
        text: btn.btnText
        color: type == 0 ? ColorsConfig.color_FFFFFF_000000 : Colors.color_FFFFFF
        anchors.centerIn: parent
        font.pixelSize: 12
        
        width: parent.width - 16
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
        clip: true
    }

    MouseArea {
        id: confirmMouseArea
        hoverEnabled: true
        anchors.fill: parent
        enabled: btn.clickEnabled
        onClicked: {
            customClick()
        }
    }

    // 文案被省略时悬停显示完整文案
    LightToolTip {
        visible: confirmMouseArea.containsMouse && textItem.truncated
        tip: btn.btnText
        z: 200
    }
}
