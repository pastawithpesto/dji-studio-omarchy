import QtQuick 2.15
import QtQuick.Controls 2.15
import Config 1.0
import Controls 1.0
import Qt5Compat.GraphicalEffects
import app_qrc 1.0

Popup {
    id: root

    // 公共接口
    property alias leftModel: leftListView.model
    property alias rightModel: rightListView.model
    property alias leftCurrentIndex: leftListView.currentIndex
    property alias rightCurrentIndex: rightListView.currentIndex
    property Component leftDelegate: defaultLeftDelegate
    property Component rightDelegate: defaultRightDelegate
    property string leftHeader: ""
    property string rightHeader: ""
    property real leftWidth: 122
    property real popupHeight: 288
    property bool isAnotherStyle: false
    property color dividerColor: isAnotherStyle ? Colors.color_56575B : Colors.color_37383A
    property color backgroundColor: isAnotherStyle ? Colors.color_454649 : Colors.color_141414
    property color headerColor: isAnotherStyle ? Colors.color_454649 : Colors.color_141414
    property color itemTextColor: ColorsConfig.color_EEEEEE_4DFFC9
    property color itemHoverColor: isAnotherStyle ? ColorsConfig.color_68696D_4DFFC920 : ColorsConfig.color_353738_4DFFC920
    property color headerTextColor: isAnotherStyle ? Colors.color_999999 : Colors.color_666666
    property real itemHeight: 28
    property real headerHeight: 30
    property real leftHeaderHeight: headerHeight
    property real rightHeaderHeight: headerHeight
    property real leftListSpacing: 2
    property real rightListSpacing: 2
    property real leftListTopMargin: leftListSpacing
    property real leftListBottomMargin: 4
    property real rightListTopMargin: 0
    property real rightListBottomMargin: 0
    property int fontSize: 11
    property int ownerRadius: isExport ? RadiusConfig.radius_4_8 : 8

    // 信号
    signal leftItemHovered(int index)
    signal rightItemClicked(int index)
    signal openedPopup()
    signal closedPopup()
    signal leftViewInit()
    signal rightViewInit()

    modal: false
    closePolicy: Popup.CloseOnEscape
    implicitHeight: popupHeight
    padding: 1

    onOpened: openedPopup()
    onClosed: closedPopup()

    function positionLeftAt(index, mode) { leftListView.positionViewAtIndex(index, mode) }
    function positionRightAt(index, mode) { rightListView.positionViewAtIndex(index, mode) }
    readonly property alias rightPanelItem: rightContainer

    // 公共垂直滚动条（左右列表共用，仅顶部留白不同）
    component VerticalScrollBar: ScrollBar {
        required property real headerTopPadding
        policy: ScrollBar.AsNeeded
        width: 10
        topPadding: headerTopPadding
        anchors {
            right: parent.right
            rightMargin: 2
        }
        contentItem: Rectangle {
            // contentItem 的 parent 即 ScrollBar 自身
            color: parent.hovered ? Colors.color_56575B : Colors.color_454649
            radius: 4
            implicitWidth: 5
            anchors.right: parent.right
            // 内容超出才显示（自定义 contentItem 需自行处理 AsNeeded 的隐藏）
            visible: parent.size < 1.0
        }
    }

    contentItem: Item {
        clip: true
        implicitHeight: popupHeight

        // 左侧列表
        Item {
            id: leftContainer
            height: parent.height
            width: leftWidth
            anchors {
                top: parent.top
                left: parent.left
            }

            ListView {
                id: leftListView
                clip: true
                anchors.fill: parent
                implicitHeight: contentHeight
                topMargin: root.leftListTopMargin
                bottomMargin: root.leftListBottomMargin
                spacing: root.leftListSpacing
                focus: true
                boundsBehavior: Flickable.StopAtBounds
                headerPositioning: ListView.OverlayHeader
                header: defaultLeftHeader
                delegate: root.leftDelegate
                ScrollBar.vertical: VerticalScrollBar {
                    headerTopPadding: root.leftHeaderHeight
                }
                Component.onCompleted: leftViewInit()
            }
        }

        // 分割线
        Rectangle {
            id: divider
            anchors {
                top: parent.top
                bottom: parent.bottom
                left: leftContainer.right
            }
            width: 1
            color: dividerColor
        }

        // 右侧列表
        Item {
            id: rightContainer
            height: parent.height
            width: parent.width - leftWidth - divider.width
            anchors {
                top: parent.top
                left: divider.right
            }

            ListView {
                id: rightListView
                clip: true
                anchors.fill: parent
                implicitHeight: contentHeight
                topMargin: root.rightListTopMargin
                bottomMargin: root.rightListBottomMargin
                spacing: root.rightListSpacing
                boundsBehavior: Flickable.StopAtBounds
                headerPositioning: ListView.OverlayHeader
                header: defaultRightHeader
                delegate: root.rightDelegate
                ScrollBar.vertical: VerticalScrollBar {
                    headerTopPadding: root.rightHeaderHeight
                }
                Component.onCompleted: rightViewInit()
            }
        }
    }

    background: Rectangle {
        color:  backgroundColor
        border.color: dividerColor
        border.width: isAnotherStyle ? 0 : 1
        radius: ownerRadius
        // 阴影
        layer.enabled: isExport ? true : false
        layer.effect: DropShadow {
            horizontalOffset: 0
            verticalOffset: 0
            radius: 10
            color: Colors.color_000000_40
        }
    }

    // 默认左侧列表项代理
    Component {
        id: defaultLeftDelegate
        Rectangle {
            width: leftListView.width
            height: itemHeight
            color: mouseArea.containsMouse ? itemHoverColor : Colors.color_transparent
            anchors.left: CommonUtils.isNull(parent) ? undefined : parent.left
            anchors.right: CommonUtils.isNull(parent) ? undefined : parent.right
            anchors.leftMargin: 4
            anchors.rightMargin: 4
            radius: 4
            opacity: 1

            Text {
                anchors {
                    left: parent.left
                    leftMargin: 8
                    verticalCenter: parent.verticalCenter
                }
                text: modelData
                color: leftListView.currentIndex === index ? itemTextColor : Colors.color_EEEEEE
                font.pixelSize: fontSize
                font.weight: Font.Medium
            }

            MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true
                onEntered: {
                    leftListView.currentIndex = index
                    root.leftItemHovered(index)
                }
            }

        }
    }

    // 默认右侧列表项代理
    Component {
        id: defaultRightDelegate
        Rectangle {
            id: delegateRoot
            height: itemHeight
            color: rightDelegateMouseArea.containsMouse ? itemHoverColor : Colors.color_transparent
            anchors.left: CommonUtils.isNull(parent) ? undefined : parent.left
            anchors.right: CommonUtils.isNull(parent) ? undefined : parent.right
            anchors.leftMargin: 4
            anchors.rightMargin: 4
            radius: 4
            opacity: 1

            Rectangle{
                id: selectedFlag
                width: 16
                height: 16
                anchors.verticalCenter: parent.verticalCenter
                anchors{
                    left: parent.left
                    leftMargin: 8
                }

                Image {
                    id: icon
                    visible: rightListView.currentIndex === index ? true : false
                    anchors.fill: parent
                    source: "qrc:/app_qrc/icons/icon_compose_check.svg"
                    sourceSize: Qt.size(parent.width, parent.height)
                }
                color: Colors.color_transparent
            }

            // 文本或图片内容
            Loader {
                anchors {
                    left: selectedFlag.right
                    right: delegateRoot.right
                    top: delegateRoot.top
                    bottom: delegateRoot.bottom
                }
                sourceComponent: {
                    if (typeof modelData === 'string') {
                        return textContent; // 纯文本
                    } else {
                        return imageContent;
                    }
                }
            }

            Component {
                id: textContent
                Text {
                    anchors {
                        left: parent.left
                        verticalCenter: parent.verticalCenter
                    }
                    verticalAlignment: Text.AlignVCenter
                    leftPadding: 8
                    text: modelData
                    color: rightListView.currentIndex === index ? itemTextColor : Colors.color_EEEEEE
                    font.pixelSize: fontSize
                    font.weight: Font.Medium
                    font.letterSpacing: 0.33
                }
            }

            Component {
                id: imageContent
                Item {
                    anchors {
                        verticalCenter: parent.verticalCenter
                        left: parent.left
                        leftMargin: 8
                    }
                    Image {
                        anchors {
                            verticalCenter: parent.verticalCenter
                        }
                        clip: true
                        source: model.path
                        asynchronous: true
                        width: implicitWidth / 2
                        height: implicitHeight / 2
                        fillMode: Image.PreserveAspectFit
                    }
                }
            }

            MouseArea {
                id: rightDelegateMouseArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    rightListView.currentIndex = index;
                    root.rightItemClicked(index);
                }
            }
        }
    }

    // 默认左侧列表头
    Component {
        id: defaultLeftHeader
        Rectangle {
            width: parent.width
            height: root.leftHeaderHeight
            color: headerColor
            opacity: 1
            radius: 8
            z: 2

            Text {
                anchors {
                    left: parent.left
                    leftMargin: 12
                    verticalCenter: parent.verticalCenter
                }
                font.pixelSize: fontSize
                font.weight: Font.Medium
                font.letterSpacing: 0
                color: headerTextColor
                text: leftHeader
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
            }

            Rectangle {
                anchors {
                    left: parent.left
                    bottom: parent.bottom
                }
                width: 8
                height: 8
                color: headerColor
            }

            Rectangle {
                anchors {
                    right: parent.right
                    bottom: parent.bottom
                }
                width: 8
                height: 8
                color: headerColor
            }
        }
    }

    // 默认右侧列表头
    Component {
        id: defaultRightHeader
        Rectangle {
            width: parent.width
            height: root.rightHeaderHeight
            color: headerColor
            opacity: 1
            radius: 8
            z: 2

            Text {
                anchors {
                    left: parent.left
                    leftMargin: 12
                    verticalCenter: parent.verticalCenter
                }
                font.pixelSize: fontSize
                font.weight: Font.Medium
                font.letterSpacing: 0
                color: headerTextColor
                text: rightHeader
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
            }

            Rectangle {
                anchors {
                    left: parent.left
                    bottom: parent.bottom
                }
                width: 8
                height: 8
                color: headerColor
            }

            Rectangle {
                anchors {
                    right: parent.right
                    bottom: parent.bottom
                }
                width: 8
                height: 8
                color: headerColor
            }
        }
    }
}
