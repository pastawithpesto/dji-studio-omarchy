import Config 1.0
import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.15
import QmlConstants 1.0
import app_qrc 1.0

/**
  * @author: pansy.guo
  * @last modified: eisen.chang
  * @details 自定义Switch
  * @date: 2024-04-11 20:38:15
  */

Switch {
    id: control
    width: QmlConstants.isWhiteXtra() ? 28 : 24
    height: QmlConstants.isWhiteXtra() ? 16 : 14

    signal pressedSignal
    signal toggledSignal
    signal openSignal(bool needNotify)
    signal closeSignal(bool needNotify)
    property real pillSize: QmlConstants.isWhiteXtra() ? 16 : 12
    property bool handlePressed: false
    property bool advanceControl: false
    property bool needConfirm:false //开关是否需要弹窗
    property string confirmText
    property bool animationIsRunning: switchAnimation.running
    property double disabledOpacity: 0.2
    property bool isEnabled: enabled

    ConfirmPopup {
        id: confirmPop
        title: qsTr(confirmText)
        leftButtonText: qsTr("pccut_draft_delete_popup_cancel")
        rightButtonText: qsTr("pccut_player_screenshot_yes")
        onLeftButtonClicked: {
            return;
        }
        onRightButtonClicked: {
            switchManual(true);
        }
    }
    function switchManual(open,needNotify = true){
        if(open){
            if(!control.checked){
                control.checked = true;
                control.openSignal(needNotify);
            }
        }else{
            if(control.checked){
                control.checked = false;
                control.closeSignal(needNotify);
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            if(advanceControl){
                if(!needConfirm) {
                    if(control.checked){
                        control.switchManual(false);
                    }else{
                        control.switchManual(true);
                    }
                }else{
                    if(control.checked){
                        control.switchManual(false);
                    }else{
                         // confirmPop.open()
                        switchManual(true);
                    }
                }
            }else{
                if(handlePressed) {
                    control.pressedSignal();
                }
                else {
                    control.checked = !control.checked;
                    control.toggledSignal();
                }
            }
        }
    }

    indicator: Rectangle {
        id: indRect
        width: QmlConstants.isWhiteXtra() ? 28 : 24
        height: QmlConstants.isWhiteXtra() ? 16 : 14
        color: Colors.transparent

        Rectangle {
            id: baseRect
            implicitWidth: 24
            implicitHeight: 14
            radius: 7
            color: control.checked ? ColorsConfig.color_brand : Colors.color_666666
            opacity: isEnabled ? 1 : disabledOpacity

            anchors.centerIn: parent
            Behavior on color {
                ColorAnimation {
                    duration: 200
                }
            }
        }

        Rectangle {
            id: dotRect
            property int offset: (parent.height - height) / 2
            x: control.checked ? parent.width - width - offset : offset
            anchors.verticalCenter: parent.verticalCenter
            width: pillSize
            height: pillSize
            radius: width / 2
            color: isEnabled ? Colors.color_FFFFFF : Colors.color_575859
            Behavior on x {
                NumberAnimation {
                    id: switchAnimation
                    duration: 200
                }
            }
        }

    }
}
