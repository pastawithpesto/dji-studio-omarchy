/**
 * @details: 标记点右键菜单（按需创建）。菜单项定义与动作分发由内嵌的
 *           MarkPointContextMenuViewModel 承担；数据改动委托 RibbonViewModel。
 */
import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Window 2.15
import Qt5Compat.GraphicalEffects
import Controls 1.0
import Config 1.0
import MarkPointContextMenuViewModel 1.0

LightPopup {
    id: markMenu

    property var ribbonVm
    property string targetId: ""
    property bool isTimeline: false

    property int maxItemTextWidth: 0

    // 行相对菜单边的左右内缩
    readonly property int rowInset: 4
    // 文字左右内边距（与下方 Text.leftMargin 同一来源）
    readonly property int itemTextPadding: 8

    width: markMenu.maxItemTextWidth + itemTextPadding * 2 + rowInset * 2
    height: contentColumn.height + contentColumn.spacing * 2
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    Overlay.modal: Rectangle {
        color: "transparent"
    }

    MarkPointContextMenuViewModel {
        id: menuVm
        ribbonVm: markMenu.ribbonVm
        targetId: markMenu.targetId
        isTimeline: markMenu.isTimeline
    }

    LightClipRectangle {
        anchors.fill: parent
        clip: true
        radius: [8, 8, 8, 8]

        ShaderEffectSource {
            id: shaderSource
            sourceItem: (typeof mainPanel !== "undefined" && mainPanel
                         && shaderSource.Window.window
                         && shaderSource.Window.window === mainPanel.Window.window) ? mainPanel : null
            sourceRect: Qt.rect(markMenu.x, markMenu.y, markMenu.width, markMenu.height)
            width: parent.width
            height: parent.height
            // 菜单背景静态模糊：菜单模态且打开后位置固定，mainPanel 背景不随菜单变化，
            // live:false 仅在打开时捕获一次，省掉每帧重抓 + FastBlur 重算（与 LightToolTip liveBackground 同源优化）。
            // 打开前已在 openMenu 定好 x/y、Component.onCompleted 定好宽度，首帧捕获即为定位后的正确背景。
            live: false
            smooth: true
        }

        FastBlur {
            anchors.fill: parent
            source: shaderSource
            radius: 48
        }

        Rectangle {
            anchors.fill: parent
            border.color: Colors.color_444444
            border.width: 0.5
            color: Colors.color_141414_85
            radius: 8
        }
    }

    Column {
        id: contentColumn
        property int itemHeight: 28
        width: parent.width
        spacing: 4
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter

        Repeater {
            id: repeater
            model: menuVm.menuItems

            delegate: Rectangle {
                id: filter
                property bool isHovered: false
                radius: 4
                width: markMenu.width - markMenu.rowInset * 2
                height: contentColumn.itemHeight
                color: filter.isHovered ? Colors.color_FFFFFF_15 : Colors.color_transparent
                anchors.horizontalCenter: parent.horizontalCenter
                Component.onCompleted: {
                    markMenu.maxItemTextWidth = Math.max(markMenu.maxItemTextWidth, filterText.width);
                }
                Text {
                    id: filterText
                    text: modelData.title
                    font.pixelSize: 11
                    color: Colors.color_EEEEEE
                    anchors.left: parent.left
                    anchors.leftMargin: markMenu.itemTextPadding
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: filter.isHovered = true;
                    onExited: filter.isHovered = false;
                    onClicked: {
                        close();
                        menuVm.trigger(modelData.action);
                    }
                }
            }
        }
    }
}
