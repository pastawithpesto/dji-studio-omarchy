import QtQuick 2.15
import Controls 1.0
import Config 1.0
import Qt5Compat.GraphicalEffects
import app_qrc 1.0

Item {
    id: root

    // --- 尺寸配置 ---
    property int popupWidth: 248
    property int internalMargin: 20
    width: popupWidth
    height: bg.height + 12

    // --- 顶部图片（可选）---
    property bool hasTopImage: false
    property string imageSource: ""
    property bool imageRounded: false
    property bool isAnimatedImage: true

    // --- 文字内容 ---
    property bool isShowStep: true
    property string titleText: ""
    property string stepText: ""
    property string descriptionText: ""
    property string nextBtnText: qsTr("pccut_guide_start")
    property string finishBtnText: qsTr("pccut_guide_done")

    // --- 按钮布局 ---
    property int nextBtnRightMargin: 0

    // --- 外部定位属性（由 UserGuideMask 管理）---
    property int indicatorLineDirect: 4
    property bool isMainWindowOutScreen: false
    property int verticalIndicatorLength: 40
    property int horizontalIndicatorLength: 40

    // --- 状态 ---
    property int curStep: 0

    signal exitGuide()
    signal finishGuide()

    Rectangle {
        id: bg
        width: root.popupWidth
        height: root.internalMargin * 2 + mainColumn.implicitHeight
        color: Colors.color_FFFFFF
        radius: 12
        layer.enabled: true
        layer.effect: DropShadow {
            horizontalOffset: 0
            verticalOffset: 0
            radius: 20
            samples: 41
            transparentBorder: true
            color: Colors.color_000000_40
        }
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right

        Column {
            id: mainColumn
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: root.internalMargin
            anchors.leftMargin: root.internalMargin
            anchors.rightMargin: root.internalMargin

            // 顶部动图（hasTopImage=true 时显示）
            Item {
                id: topImageItem
                visible: root.hasTopImage
                width: parent.width
                height: 140
                Loader {
                    id: topImage
                    active: root.hasTopImage
                    width: parent.width
                    height: parent.height
                    layer.enabled: root.imageRounded
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: topImage.width
                            height: topImage.height
                            radius: 8
                        }
                    }
                    sourceComponent: root.isAnimatedImage ? animatedImageComp : staticImageComp
                }
                Component {
                    id: staticImageComp
                    Image {
                        width: topImage.width
                        height: topImage.height
                        source: root.imageSource
                        fillMode: Image.PreserveAspectCrop
                    }
                }
                Component {
                    id: animatedImageComp
                    AnimatedImage {
                        width: topImage.width
                        height: topImage.height
                        source: root.imageSource
                        playing: root.visible
                        fillMode: Image.PreserveAspectCrop
                    }
                }
            }

            // 图片下方间距（hasTopImage=true 时显示）
            Item {
                id: imageBottomMargin
                visible: root.hasTopImage
                width: parent.width
                height: 10
            }

            // 标题行
            Item {
                id: titleItem
                width: parent.width
                height: title.implicitHeight

                Text {
                    id: title
                    width: 185
                    anchors {
                        top: parent.top
                        left: parent.left
                    }
                    text: root.titleText
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0
                    color: Colors.color_141414
                    wrapMode: Text.WordWrap
                }

                Text {
                    id: stepInfo
                    visible: root.isShowStep
                    width: 29
                    height: implicitHeight
                    anchors {
                        top: title.top
                        topMargin: 2
                        right: parent.right
                    }
                    text: root.stepText
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    font.letterSpacing: 0
                    horizontalAlignment: Text.AlignRight
                    color: Colors.color_999999
                }
            }

            // 标题与描述间距
            Item { width: parent.width; height: 12 }

            // 描述文字
            Text {
                id: description
                width: parent.width
                height: implicitHeight
                text: root.descriptionText
                font.pixelSize: 12
                font.weight: Font.Medium
                font.letterSpacing: 0
                color: Colors.color_666666
                wrapMode: Text.WordWrap
            }

            // 描述与按钮间距
            Item { width: parent.width; height: 12 }

            // 按钮区
            Item {
                id: btnList
                width: parent.width
                height: 28

                Rectangle {
                    id: nextBtn
                    width: 80
                    height: 28
                    anchors {
                        top: parent.top
                        right: parent.right
                        rightMargin: root.nextBtnRightMargin
                    }
                    color: nextArea.containsMouse ? ColorsConfig.color_F44C65_6DFFD3 : ColorsConfig.color_F22443_4DFFC9
                    radius: RadiusConfig.radius_6_88

                    Text {
                        anchors.centerIn: parent
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                        color: ColorsConfig.color_FFFFFF_000000
                        text: root.nextBtnText
                    }

                    MouseArea {
                        id: nextArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            root.curStep += 1
                        }
                    }
                }

                Rectangle {
                    id: exitedBtn
                    objectName: actionableItemName.cancel
                    width: 80
                    height: 28
                    anchors {
                        right: nextBtn.left
                        top: parent.top
                        rightMargin: 8
                    }
                    color: exitedArea.containsMouse ? Colors.color_F2F2F2 : Colors.color_EEEEEE
                    radius: RadiusConfig.radius_6_88

                    Text {
                        anchors.centerIn: parent
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                        color: Colors.color_666666
                        text: qsTr("pccut_guide_exit")
                    }

                    MouseArea {
                        id: exitedArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            root.exitGuide()
                        }
                    }
                }
            }
        }
    }

    // 底部指示箭头
    Image {
        visible: true
        height: 14
        width: 20
        source: "qrc:/icons/region_guide_begin_bottom.svg"
        anchors {
            top: bg.bottom
            topMargin: -6
        }
        x: bg.width / 2 - 10
    }
}
