import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.3

import Config 1.0
import Controls 1.0

LightPopup {
    anchors.centerIn: Overlay.overlay
    background: Rectangle {
        border.color: Colors.color_FFFFFF_20
        border.width: 0.5
        radius: 12
        color: Colors.color_333333_80
    }

    contentItem: ColumnLayout {
        id: contentItemLayout
        spacing: 16

        ColumnLayout {
            id: layout
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 16
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            spacing: 4
            Text {
                id: title
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: 184
                font.pixelSize: 14
                font.weight: Font.DemiBold
                color: Colors.color_FFFFFF
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }
            Text {
                id: body
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: 184
                font.pixelSize: 11
                font.weight: Font.Medium
                visible: text !== ""
                color: Colors.color_CCCCCC
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }
        }

        IconTextButton {
            Layout.alignment: Qt.AlignHCenter
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            Layout.bottomMargin: 16
            isTextOnly: true
            title: qsTr("pccut_project_modify_yes")
            titleFontWeight: Font.DemiBold
            titleFontSize: 12
            titleColorNormal: Colors.color_FFFFFF
            backgroundColorNormal: Colors.color_D8D8D8_20
            topPadding: 4
            bottomPadding: 4
            leftPadding: 30
            rightPadding: 30
            onCustomClicked: {
                closePopup()
            }
        }
    }

    function setMessage(msg, bodyText) {
        title.text = msg
        body.text = bodyText

        // 这里声明了一个用不上的局部变量，是因为访问一次implicitHeight属性可以让popup的尺寸计算正常，原因未知
        let hei = contentItemLayout.implicitHeight
    }

    function closePopup() {
        close()
    }
}
