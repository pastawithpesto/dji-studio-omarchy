import QtQuick 2.15
import QtQuick.Layouts 1.15
import Controls 1.0
import Config 1.0

Item {
    id: root
    objectName: "cloudAlbumNotLoginView"

    property real panelWidth: Math.min(420, Math.max(0, width - 48))
    property real panelHeight: 0
    property bool centerPanel: false
    property real topRatio: 0.18
    property real topOffset: 8
    property real imageWidth: panelWidth
    property real imageHeight: imageWidth * 220 / 420
    property real titleTopMargin: 54
    property real descTopMargin: 12
    property real buttonTopMargin: 24
    property real titleFontSize: 20
    property real titleLineHeight: 24
    property real descFontSize: 14
    property real descLineHeight: 18
    property real buttonWidth: 140
    property real buttonHeight: 44
    property real buttonFontSize: 16

    signal loginClicked()

    Item {
        id: layoutPanel
        width: root.panelWidth
        height: root.panelHeight > 0 ? root.panelHeight : contentColumn.implicitHeight
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.centerPanel ? (parent.height - height) / 2 : parent.height * root.topRatio + root.topOffset

        ColumnLayout {
            id: contentColumn
            anchors.centerIn: parent
            width: parent.width
            spacing: 0

            // 顶部插画图片区域
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: root.imageWidth
                Layout.preferredHeight: root.imageHeight
                radius: 12
                color: "transparent"
                clip: true

                Image {
                    id: placeholderImage
                    anchors.fill: parent
                    source: "qrc:/app_qrc/icons/cloud_album_placeholder.png"
                    fillMode: Image.PreserveAspectCrop
                }
            }

            // 标题文字
            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: root.titleTopMargin
                Layout.maximumWidth: parent.width
                text: qsTr("pccut_cloud_album_slogan")
                font.pixelSize: root.titleFontSize
                font.weight: Font.Medium
                lineHeight: root.titleLineHeight
                lineHeightMode: Text.FixedHeight
                color: Colors.color_EEEEEE
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            // 副标题文字
            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: root.descTopMargin
                Layout.maximumWidth: parent.width
                text: qsTr("pccut_cloud_album_login_desc")
                font.pixelSize: root.descFontSize
                font.weight: Font.Medium
                lineHeight: root.descLineHeight
                lineHeightMode: Text.FixedHeight
                color: Colors.color_999999
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            // 立即登录按钮 - 复用 FixedWidthIconTextButton，注入纯色背景
            FixedWidthIconTextButton {
                id: loginBtn
                objectName: "cloudAlbumLoginBtn"
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: root.buttonTopMargin
                fixedWidth: root.buttonWidth
                fixedHeight: root.buttonHeight
                title: qsTr("pccut_cloud_album_login_now")
                titleFontSize: root.buttonFontSize
                titleColorNormal: Colors.color_141414
                titleColorHover: Colors.color_141414
                backgroundColorNormal: "#EEEEEE"
                backgroundColorHover: "#FFFFFF"
                radius: 6

                onCustomClicked: {
                    root.loginClicked()
                }
            }
        }
    }
}
