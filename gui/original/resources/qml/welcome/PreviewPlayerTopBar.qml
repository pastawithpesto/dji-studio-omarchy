import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Window 2.15
import QtQuick.Layouts 1.15
import Controls 1.0
import Config 1.0
import LightTabRectangle 1.0
import LightRectangle 1.0
import "../controller"
import PreviewSourceHandler 1.0
import DeviceMediaCategory 1.0
import app_qrc 1.0

Item {
    id: control
    property url icon
    property int iconSize: 20

    // ✨ 新增：hover 状态属性
    property bool isHovered: false

    property string sourceFileName: ""
    property var fromType

    // 云相册预览的图片：与边下边播一致隐藏「创作」按钮。仅云相册来源生效，其余来源不受影响。
    property bool isCloudAlbumImagePreview: false

    property var isPreviewHighlight
    property var isPreviewOriginal
    
    property var maxClickListener: function () {
        if (CommonUtils.isNull(previewResizableTarget.win)) {
            return
        }
        if (previewResizableTarget.win.visibility === Window.Maximized) {
            previewResizableTarget.win.showNormal()
        } else {
            previewResizableTarget.win.showMaximized()
        }
    }
    property var fullScreenClickListener: function () {
        fullScreenClicked()
    }
    property var minClickListener: function () {
        previewResizableTarget.win.showMinimized();
    }
    property var closeClickListener: function () {
        customClosedClicked();
    }
    property var systemMenuListener: function () {
        previewResizableTarget.win.showSystemMenu();
    }

    function closeWindow() {
        globalSignal.closeWindow()
        sourceHandler.clearSource()
    }

    signal fullScreenClicked
    signal customClosedClicked
    signal draftCreationClicked
    signal removeClicked
    signal downloadClicked
    signal exportClicked

    height: visible ? 40 : 0
    opacity: visible
    z: 65535

    Item {
        id: previewResizableTarget

        property var win: Window.window
        property bool resizable: win && !(win.height === win.maximumHeight && win.height === win.minimumHeight && win.width === win.maximumWidth && win.width === win.minimumWidth)
    }

    WindowMovable {
        id: mouse_app_bar

        anchors.fill: parent

        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                systemMenuListener();
            }
        }

        window: previewPlayerRoot
        sizeHandler: previewWindowSizeManager
        resizableBar: previewResizableTarget
    }
    RowLayout {
        id: windowsButtonsRow
        anchors {
            top: parent.top
            bottom: parent.bottom
            topMargin: 0.5
            right: parent.right
            rightMargin: 0.5
        }
        spacing: 0

        visible: CommonUtils.isWindows()

        IconButton {
            id: minButton
            width: 48
            height: 32
            radius: 0

            normalColor: Colors.transparent
            hoverColor: Colors.color_2F3032
            pressedColor: Colors.color_252627
            disableColor: Colors.transparent

            iconSource: "qrc:/icons/WindowsIcon/icon_minimize.svg"

            onClicked: {
                minClickListener()
            }
        }

        IconButton {
            id: maxButton
            width: 48
            height: 32
            radius: 0

            normalColor: Colors.transparent
            hoverColor: Colors.color_2F3032
            pressedColor: Colors.color_252627
            disableColor: Colors.transparent

            iconSource: !CommonUtils.isNull(previewResizableTarget.win)
                        && previewResizableTarget.win.visibility !== Window.Maximized
                        ? "qrc:/icons/WindowsIcon/icon_maximizing.svg"
                        : "qrc:/icons/WindowsIcon/icon_maxminimizing.svg"
            onClicked: {
                maxClickListener()
            }
        }

        LightRectangle {
            id: closeButton
            width: 48
            height: 32
            radius: [0, 0, 0, 0]
            color: {
                if (mouseArea.pressed) return Colors.color_C61E37;
                if (mouseArea.containsMouse) return Colors.color_F22443;
                return Colors.color_transparent;
            }

            Image {
                anchors.centerIn: parent
                width: parent.width
                height: parent.height
                source: "qrc:/icons/WindowsIcon/icon_close.svg"
                sourceSize: Qt.size(width, height)
            }

            MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    closeClickListener()
                }
            }
        }
    }

    RowLayout {
        id: row
        visible: !windowsButtonsRow.visible
        anchors {
            verticalCenter: parent.verticalCenter
            left: parent.left
            leftMargin: 10
        }

        ImageButton {
            id: btn_close

            Layout.preferredHeight: 12
            Layout.preferredWidth: 12
            normalImage: "qrc:/icons/appbar/btn_close_normal.svg"
            hoveredImage: "qrc:/icons/appbar/btn_close_hovered.svg"
            pushedImage: "qrc:/icons/appbar/btn_close_pushed.svg"
            onClicked: closeClickListener()
        }

        // 最小化按钮关闭，仅作占位用
        ImageButton {
            id: btn_min
            Layout.preferredHeight: 12
            Layout.preferredWidth: 12
            Rectangle {
                anchors.fill: parent
                radius: 6
                color: "#525251"
            }
        }

        ImageButton {
            id: btn_max

            Layout.preferredHeight: 12
            Layout.preferredWidth: 12
            normalImage: "qrc:/icons/appbar/btn_max_normal.svg"
            hoveredImage: !CommonUtils.isNull(Window.window) ? Window.window.visibility === Window.FullScreen ? "qrc:/icons/appbar/btn_normal_hovered.svg" : "qrc:/icons/appbar/btn_max_hovered.svg" : ""
            pushedImage: !CommonUtils.isNull(Window.window) ? Window.window.visibility === Window.FullScreen ? "qrc:/icons/appbar/btn_normal_pushed.svg" : "qrc:/icons/appbar/btn_max_pushed.svg" : ""
            disabledImage: "qrc:/icons/appbar/btn_appbar_disable.svg"
            onClicked: fullScreenClickListener()
            visible: previewResizableTarget.resizable
        }
    }

    Row {
        id: rightRow
        anchors.rightMargin: 12
        anchors.right: windowsButtonsRow.visible ? windowsButtonsRow.left : parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: 24
        spacing: 8
        
        IconButton {
            id: deleteBtn
            width: 24
            height: 24
            iconWidth: 16
            iconHeight: 16
            visible: fromType !== PreviewSourceHandler.PREVIEW_FROM_FINDER
            hoverTextFunc: function() { return qsTr("pccut_device_batch_delete") }
            iconSource: "qrc:/icons/mediaAsset/ic_Delete.svg"
            pressedIconSource: "qrc:/icons/mediaAsset/ic_Delete_pressed.svg"
            normalColor: Colors.color_transparent
            hoverColor: Colors.color_2F3032
            pressedColor: Colors.color_37383A
            onClicked: {
                removeClicked();
            }
        }

        IconButton {
            id: downloadBtn
            width: 24
            height: 24
            iconWidth: 16
            iconHeight: 16
            visible: fromType === PreviewSourceHandler.PREVIEW_FROM_DEVICE
            hoverTextFunc: function() {
                return sourceHandler.isCopied ? qsTr("pccut_device_batch_downloaded") : qsTr("pccut_device_batch_download")
            }
            iconSource: sourceHandler.isCopied ? "qrc:/icons/mediaAsset/ic_downloaded.svg" : "qrc:/icons/mediaAsset/ic_download.svg"
            pressedIconSource: "qrc:/icons/mediaAsset/ic_download_pressed.svg"
            disabled: sourceHandler.isCopied
            normalColor: Colors.color_transparent
            hoverColor: Colors.color_2F3032
            pressedColor: Colors.color_37383A
            onClicked: {
                downloadClicked();
            }
        }

        IconButton {
            id: exportBtn
            width: 24
            height: 24
            iconWidth: 16
            iconHeight: 16
            visible: fromType !== PreviewSourceHandler.PREVIEW_FROM_FINDER && highlightManager.highlightSupport
            hoverTextFunc: function() { return qsTr("pccut_menu_export") }
            iconSource: "qrc:/icons/mediaAsset/icon_export.svg"
            pressedIconSource: "qrc:/icons/mediaAsset/icon_export_pressed.svg"
            disabled: !sourceHandler.isEnableExport
            normalColor: Colors.color_transparent
            hoverColor: Colors.color_2F3032
            pressedColor: Colors.color_37383A
            onClicked: {
                exportClicked();
            }
        }

        LeftIconButton {
            id: importBtn
            height: 24
            width: 66
            textSpace: 4
            // 云相册边下边播预览、以及云相册图片预览下隐藏「创作」按钮，其他来源（设备/下载/Finder）保持不变。
            visible: !sourceHandler.isStreaming && !isCloudAlbumImagePreview
            text: qsTr("pccut_project_creation")
            textColor: ColorsConfig.color_FFFFFF_000000
            source: "qrc:/icons/ic_create.svg"
            normalColor: ColorsConfig.color_F22443_4DFFC9
            hoverColor: ColorsConfig.color_F44C65_6DFFD3
            onClickBtn: {
                draftCreationClicked()
            }
        }
    }

    Text {
        id: sourceFileText
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.rightMargin: rightRow.width + 30
        anchors.leftMargin: rightRow.width + 30
        anchors.verticalCenter: parent.verticalCenter
        horizontalAlignment: Text.AlignHCenter
        font.pixelSize: 12
        color: Colors.color_FFFFFF
        font.weight: Font.Medium
        font.letterSpacing: 0.26
        text: sourceFileName
    }

    MouseArea {
        property var buttons: [btn_close, btn_min, btn_max]

        anchors.fill: row
        hoverEnabled: true
        onEntered: {
            for (var i in buttons) {
                buttons[i].customHovered = true;
            }
        }
        onExited: {
            for (var i in buttons) {
                buttons[i].customHovered = false;
            }
        }
        acceptedButtons: Qt.NoButton
    }
}
