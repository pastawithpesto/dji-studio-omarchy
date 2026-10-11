import QtQuick 2.15
import QtQuick.Controls
import Config 1.0
import Controls 1.0
import Qt5Compat.GraphicalEffects
import app_qrc 1.0

TabButton {
    id: btn
    width: 30
    property alias imageSource: image.source
    property alias title: title.text
    y: 0
    height: parent.height
    background: Rectangle {
        color: Colors.transparent
    }
    anchors {
        top: parent.top
    }
    Item {
        id: contentItem
        anchors.fill: parent
        Image {
            id: image
            anchors {
                top: parent.top

                horizontalCenter: parent.horizontalCenter
            }
            sourceSize: Qt.size(20, 20)

            width: 20
            height: 20
            ColorOverlay {
                anchors.fill: image
                source: image
                color: btn.checked ? ColorsConfig.color_brand : Colors.color_FFFFFF
            }
        }


        Text {
            id: title
            font.pixelSize: 11
            anchors {
                top: image.bottom
                topMargin: 2
                horizontalCenter: parent.horizontalCenter
            }
            verticalAlignment: Text.AlignVCenter

            enabled: false
            color: btn.checked ? ColorsConfig.color_brand : Colors.color_999999

            //自定义了hoverabletext的属性
            maximumLineCount: 1
            wrapMode: Text.WordWrap
            property real maxTextWidth: 51
            width: Math.min(implicitWidth, maxTextWidth)
            elide: Text.ElideRight
            lineHeight: font.pixelSize * 1.17
            lineHeightMode: Text.FixedHeight
            MouseArea {
                id: titleArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    btn.clicked()
                }
                LightToolTip {
                    visible: titleArea.containsMouse && title.implicitWidth > title.width
                    tip: title.text
                    z: 200
                }
            }
        }
    }
}
