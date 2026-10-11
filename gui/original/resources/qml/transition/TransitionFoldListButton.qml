import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.3
import Config 1.0
import Controls 1.0
import Qt5Compat.GraphicalEffects
import QmlConstants 1.0
import app_qrc 1.0

/**
 * @author hugo.li
 * @desc 转场素材列表按钮点击效果实现
 * @create_date 2025-12-25
 */
Rectangle {

    property bool isSelect: false
    property bool isExpanded:false
    property bool isShowImg:true
    property string title: ""

    signal cusClicked()

    height: 28
    width: parent.width
    color: ColorsConfig.color_2F3032_transparent
    radius: 4
    // 鼠标点击事件处理
    MouseArea {
        id: mouseArea
        hoverEnabled: true
        anchors.fill: parent

        LightToolTip {
            visible: mouseArea.containsMouse && menuText.implicitWidth > menuText.width
            tip: title
        }

        onClicked: {
            isExpanded = !isExpanded
            cusClicked()
        }
    }

    Text {
        id: menuText
        text: title
        font.pixelSize: 12
        color: isSelect ? ColorsConfig.color_brand : Colors.color_FFFFFF
        elide: Text.ElideRight
        wrapMode: Text.NoWrap
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.rightMargin: QmlConstants.isWhiteXtra() ? 12 : 28
        anchors.leftMargin: QmlConstants.isWhiteXtra() ? 18 : 12
        anchors.verticalCenter: parent.verticalCenter
    }

    // coverLay输入输出要为两个元素所以做一个缓存
    Image {
        id: foldImageCache
        visible: false
        anchors {
            left: QmlConstants.isWhiteXtra() ? parent.left : undefined
            leftMargin: QmlConstants.isWhiteXtra() ? 0 : undefined
            right: QmlConstants.isWhiteXtra() ? undefined : parent.right
            rightMargin: QmlConstants.isWhiteXtra() ? undefined : 8
            verticalCenter: parent.verticalCenter
        }
        sourceSize: QmlConstants.isWhiteXtra() ? Qt.size(12, 12) : Qt.size(20, 20)
        source: "qrc:/app_qrc/icons/media_flod.svg"
        width: QmlConstants.isWhiteXtra() ? 12 : 20
        height: QmlConstants.isWhiteXtra() ? 12 : 20
    }


    Image {
        id: foldImage
        visible: isShowImg
        anchors {
            left: QmlConstants.isWhiteXtra() ? parent.left : undefined
            leftMargin: QmlConstants.isWhiteXtra() ? 0 : undefined
            right: QmlConstants.isWhiteXtra() ? undefined : parent.right
            rightMargin: QmlConstants.isWhiteXtra() ? undefined : 8
            verticalCenter: parent.verticalCenter
        }
        sourceSize: QmlConstants.isWhiteXtra() ? Qt.size(12, 12) : Qt.size(20, 20)
        source: "qrc:/app_qrc/icons/media_flod.svg"
        width: QmlConstants.isWhiteXtra() ? 12 : 20
        height: QmlConstants.isWhiteXtra() ? 12 : 20
        // 应用旋转变换
        transform: Rotation {
            // 设置旋转中心为图像的中心
            origin.x: foldImage.width / 2
            origin.y: foldImage.height / 2
            // 旋转角度（例如，90度）
            angle: isExpanded ? 0 : 180
        }
        ColorOverlay {
            id:colorOverlay
            anchors.fill: foldImage
            source: foldImageCache
            color: isSelect ? ColorsConfig.color_brand : Colors.color_FFFFFF
        }
    }
}

