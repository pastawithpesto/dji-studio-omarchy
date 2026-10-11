import QtQuick 2.15
import QtQuick.Layouts
import Controls 1.0
import Config 1.0


Item {
    property string coverUrl
    property string uri
    LightClipRectangle {
        id: bannerImageRect
        anchors.fill: parent
        visible: coverUrl !== "" && bannerImage.status === Image.Ready

        Image {
            id: bannerImage
            anchors.centerIn: parent
            property double widthScale: bannerImageRect.width !== 0 ? implicitWidth / bannerImageRect.width : 1
            property double heightScale: bannerImageRect.height !== 0 ? implicitHeight / bannerImageRect.height: 1
            width: {
                if (heightScale <= 0) {
                    return 0
                }
                widthScale > heightScale ? implicitWidth / heightScale : bannerImageRect.width
            }
            height: {
                if (widthScale <= 0) {
                    return 0
                }
                widthScale > heightScale ? bannerImageRect.height : implicitHeight / widthScale
            }
            source: coverUrl
            sourceSize: Qt.size(implicitWidth, implicitHeight)
        }
    }

    // 图片未加载完成时展示的loading
    Rectangle {
        anchors.fill: parent
        color: Colors.color_2F3032
        visible: coverUrl === "" || bannerImage.status !== Image.Ready
        ColumnLayout {
            anchors.centerIn: parent
            Image {
                Layout.alignment: Qt.AlignHCenter
                source: "qrc:/icons/icon_banner_loading.svg"
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                color: Colors.color_666666
                text: qsTr("pccut_banner_loading")
                font.pixelSize: 8
                font.weight: Font.Medium
            }
        }
    }


    MouseArea {
        id: bannerCoverMouseArea
        anchors.fill: parent
        onClicked: {
            if (model.uri !== "" ) {
                Qt.openUrlExternally(uri)
            }
        }
    }
}
