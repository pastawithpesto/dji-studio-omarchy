import QtQuick 2.15
import QtQuick.Controls 2.15
import Config 1.0

ComboBox {
    id: lightComboBox

    // ── 样式属性 ──
    property color backgroundColor: Colors.color_2F3032
    property color textColor: Colors.color_EEEEEE
    property color placeholderTextColor: Colors.color_999999
    property color hoverColor: Colors.color_37383A
    property color listItemHoverColor: Colors.color_2F3032
    property color popupBackgroundColor: Colors.color_141414
    property color popupBorderColor: Colors.color_444444
    property color scrollBarColor: Colors.color_56575B
    property color scrollBarActiveColor: Colors.color_68696D
    property int popupBorderWidth: 1
    property real popupRadius: 6
    property int fontSize: 11
    property real radius: 4
    property int itemHeight: 28
    property int maxPopupHeight: 170
    property real contentLeftPadding: 8
    property real contentRightPadding: 28
    property int indicatorWidth: 20
    property int indicatorHeight: 20
    property int indicatorRightMargin: 8
    property int checkboxWidth: 16
    property int checkboxHeight: 16
    property int scrollBarWidth: 6
    property int scrollBarRightMargin: 4
    property string placeholderText: ""

    // 背景容器
    background: Rectangle {
        radius: lightComboBox.radius
        color: lightComboBox.enabled && lightComboBox.hovered && !lightComboBox.popup.visible
               ? lightComboBox.hoverColor : lightComboBox.backgroundColor
    }

    contentItem: Text {
        leftPadding: lightComboBox.contentLeftPadding
        rightPadding: lightComboBox.contentRightPadding
        text: lightComboBox.currentIndex === -1 ? lightComboBox.placeholderText : lightComboBox.displayText
        font.pixelSize: lightComboBox.fontSize
        color: lightComboBox.currentIndex === -1 ? lightComboBox.placeholderTextColor : lightComboBox.textColor
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    indicator: Image {
        anchors {
            right: parent.right
            rightMargin: lightComboBox.indicatorRightMargin
            verticalCenter: parent.verticalCenter
        }
        width: lightComboBox.indicatorWidth
        height: lightComboBox.indicatorHeight
        source: lightComboBox.popup.visible ? "qrc:/icons/ic_open_triangle.svg" : "qrc:/icons/ic_close_triangle.svg"
        sourceSize: Qt.size(width, height)
    }

    delegate: Rectangle {
        id: listDelegate
        property bool isHovered: false
        x: 4
        width: delegateListView.width - 4 - (popupScrollBar.visible ? popupScrollBar.width + 2 : 4)
        radius: 4
        height: lightComboBox.itemHeight
        color: isHovered ? lightComboBox.listItemHoverColor : Colors.transparent

        Row {
            anchors.fill: parent
            spacing: 0
            Item {
                width: lightComboBox.itemHeight
                height: lightComboBox.itemHeight
                Image {
                    anchors.centerIn: parent
                    visible: index === lightComboBox.currentIndex
                    width: lightComboBox.checkboxWidth
                    height: lightComboBox.checkboxHeight
                    source: "qrc:/app_qrc/icons/icon_checkbox_check.svg"
                    sourceSize: Qt.size(width, height)
                }
            }
            Text {
                width: listDelegate.width - lightComboBox.itemHeight
                height: lightComboBox.itemHeight
                text: modelData
                font.pixelSize: lightComboBox.fontSize
                color: lightComboBox.textColor
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: listDelegate.isHovered = true
            onExited: listDelegate.isHovered = false
            onClicked: {
                lightComboBox.currentIndex = index
                lightComboBox.popup.close()
            }
        }
    }

    popup: Popup {
        y: lightComboBox.height + 4
        width: lightComboBox.width
        height: Math.min(delegateListView.contentHeight, lightComboBox.maxPopupHeight) + topPadding + bottomPadding
        topPadding: 4
        bottomPadding: 4
        leftPadding: 0
        rightPadding: popupScrollBar.visible ? 2 : 0

        contentItem: ListView {
            id: delegateListView
            clip: true
            model: lightComboBox.delegateModel
            currentIndex: lightComboBox.currentIndex

            ScrollBar.vertical: ScrollBar {
                id: popupScrollBar
                visible: delegateListView.contentHeight > delegateListView.height
                anchors.rightMargin: lightComboBox.scrollBarRightMargin
                contentItem: Rectangle {
                    implicitWidth: lightComboBox.scrollBarWidth
                    radius: height / 2
                    color: parent.active ? lightComboBox.scrollBarActiveColor : lightComboBox.scrollBarColor
                }
            }
        }

        background: Rectangle {
            color: lightComboBox.popupBackgroundColor
            border.color: lightComboBox.popupBorderColor
            border.width: lightComboBox.popupBorderWidth
            radius: lightComboBox.popupRadius
        }
    }

    Keys.onPressed: (event) => { event.accepted = true }
    Keys.onReleased: (event) => { event.accepted = true }
}



