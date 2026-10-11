import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import UIComponent
import DebugModule

ApplicationWindow {
    width: 1400
    height: 800
    title: qsTr("UIComponent Gallery")
    visible: false

    background: Rectangle {
        anchors.fill: parent
        color: UIColors.colorBgFrame
        z: -1
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Variant Toggle: Gallery 实时切 Internal/Abroad；生产构建 _variant 由 #ifdef PRODUCT_ABROAD 锁定
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 48
            color: UIColors.colorBgBar
            border.width: 0

            Row {
                anchors.left: parent.left
                anchors.leftMargin: UISize.sizeMD
                anchors.verticalCenter: parent.verticalCenter
                spacing: UISize.sizeSM

                Text {
                    text: qsTr("gallery_toolbar_variant")
                    color: UIColors.colorTextPrimary
                    font.pixelSize: UIFonts.fontSizeM
                    anchors.verticalCenter: parent.verticalCenter
                }
                UIButton {
                    text: qsTr("gallery_toolbar_internal")
                    size: UIControlSize.M
                    type: UITheme.variant === UIThemeVariant.Internal ? UIButtonType.Brand : UIButtonType.White
                    onClicked: UITheme.setVariant(UIThemeVariant.Internal)
                }
                UIButton {
                    text: qsTr("gallery_toolbar_abroad")
                    size: UIControlSize.M
                    type: UITheme.variant === UIThemeVariant.Abroad ? UIButtonType.Brand : UIButtonType.White
                    onClicked: UITheme.setVariant(UIThemeVariant.Abroad)
                }

                // Lang toggle (独立 Gallery 专属 — Studio host 走自身语言切换流程, 不进此分支)
                Text {
                    text: qsTr("gallery_toolbar_lang")
                    color: UIColors.colorTextPrimary
                    font.pixelSize: UIFonts.fontSizeM
                    leftPadding: UISize.sizeLG
                    anchors.verticalCenter: parent.verticalCenter
                }
                UIButton {
                    text: "中文"
                    size: UIControlSize.M
                    type: GalleryTranslator.currentCode === "zh" ? UIButtonType.Brand : UIButtonType.White
                    onClicked: GalleryTranslator.setLanguage("zh")
                }
                UIButton {
                    text: "English"
                    size: UIControlSize.M
                    type: GalleryTranslator.currentCode === "en" ? UIButtonType.Brand : UIButtonType.White
                    onClicked: GalleryTranslator.setLanguage("en")
                }

                Text {
                    text: "系统："
                    color: UIColors.colorTextPrimary
                    font.pixelSize: UIFonts.fontSizeM
                    leftPadding: UISize.sizeLG
                    anchors.verticalCenter: parent.verticalCenter
                }
                UIButton {
                    text: "Mac"
                    size: UIControlSize.M
                    type: UITheme.platform === UIThemePlatform.Mac ? UIButtonType.Brand : UIButtonType.White
                    onClicked: UITheme.setPlatform(UIThemePlatform.Mac)
                }
                UIButton {
                    text: "Windows"
                    size: UIControlSize.M
                    type: UITheme.platform === UIThemePlatform.Windows ? UIButtonType.Brand : UIButtonType.White
                    onClicked: UITheme.setPlatform(UIThemePlatform.Windows)
                }

                // 开发者模式
                Text {
                    text: qsTr("gallery_toolbar_dev_mode")
                    color: UIColors.colorTextPrimary
                    font.pixelSize: UIFonts.fontSizeM
                    leftPadding: UISize.sizeLG
                    anchors.verticalCenter: parent.verticalCenter
                }
                UISwitch {
                    size: UIControlSize.M
                    anchors.verticalCenter: parent.verticalCenter
                    checked: galleryView.isDevMode
                    onToggled: galleryView.isDevMode = checked
                }
            }
        }

        GalleryView {
            id: galleryView
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }
}
