import QtQuick 2.15
import QtQuick.Controls
import Config 1.0
import Controls 1.0
import app_qrc 1.0

CheckBox {
    id:checkBox
    hoverEnabled: true
    property real maxTextWidth: 80
    property bool isDisabled: false  // 禁用状态，但可以点击
    property bool disableChecked: false  // 处理默认选中，但是位置灰逻辑
    property color textColor: Colors.color_EEEEEE
    // 设为 true 时，文案区域的点击会被吞掉，只有点击复选框 indicator 才会切换勾选
    property bool indicatorOnlyClickable: false
    width: Math.min(checkText.implicitWidth, maxTextWidth) + 16
    indicator: Rectangle {
        implicitWidth: 14
        implicitHeight: 14
        anchors.left: checkBox.left
        anchors.verticalCenter: parent.verticalCenter
        color:  checkBox.isDisabled ? Colors.color_454649 : (checkBox.checked ? ColorsConfig.color_brand : Colors.color_444444)
        opacity: disableChecked || checkBox.isDisabled || !checkBox.enabled ? 0.2 : 1
        radius: 4
        Image {
            id: icon
            visible: checkBox.checked
            anchors.fill: parent
            source: "qrc:/app_qrc/icons/icon_checkbox_check.svg"
            sourceSize: Qt.size(parent.width, parent.height)
        }
    }
    LightToolTip {
        visible: checkBox.hovered && checkText.implicitWidth > checkText.width
        tip: checkText.text
    }
    contentItem: Text {
        id: checkText
        text: checkBox.text
        font.pixelSize: 12
        color: checkBox.textColor
        elide: Text.ElideRight
        verticalAlignment: Text.AlignVCenter
        anchors.verticalCenter: parent.verticalCenter
        leftPadding: checkBox.indicator.width + 2
    }
    // 拦截文字区域的点击，避免点文字时也触发勾选
    MouseArea {
        visible: checkBox.indicatorOnlyClickable
        z: 1
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.left: checkBox.indicator.right
        // 空 onClicked 即可消费事件，阻止其冒泡至 CheckBox 自身的点击逻辑
        onClicked: {}
    }
}
