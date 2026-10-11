import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.15
import Config 1.0
import Controls 1.0
import app_qrc 1.0
import CloudAlbumTransferModel 1.0
import Qt5Compat.GraphicalEffects
import QtQuick.Shapes 1.15
import TaskQueueViewModel 1.0

/**
 * @author kaoru.yu
 * @desc 任务队列弹窗 - 支持导出/上传/下载队列管理
 * @create_date 2026-05-09
 */
LightPopup {
    id: taskQueuePopup
    objectName: "taskQueuePopup"

    signal closeClicked
    signal navigateToCloudAlbumAsset(string fileName)

    parent: Overlay.overlay
    anchors.centerIn: parent
    closePolicy: Popup.CloseOnEscape
    focus: true
    width: 920
    height: 520

    Overlay.modal: Rectangle {
        color: Colors.color_000000_50
    }

    property bool isClosedOrDestruction: false

    // 与 AppBar 共用同一个 ViewModel，确保任务角标和弹窗内已读状态实时同步
    property TaskQueueViewModel vm: null

    // 右侧内容区起始 x
    readonly property int contentLeftX: 224
    // 右侧内容区右边距
    readonly property int contentRightMargin: 40

    // ==================== 布局分区 ====================
    // 左侧栏宽度（同时也是右侧内容区分隔线的起始 x）
    readonly property int sidebarWidth: 184
    // 标题栏底部分隔线 / 左侧栏起始 y
    readonly property int headerSeparatorY: 41
    // 列头区起始 y
    readonly property int tableHeaderY: 118
    // 列表区起始 y
    readonly property int listViewStartY: 159

    // ==================== 行/列通用尺寸 ====================
    readonly property int delegateHeight: 64       // 列表行高
    readonly property int delegateHoverPadding: 12 // delegate hover 背景左右扩展宽度
    readonly property int tableHeaderHeight: 36    // 列头高度
    readonly property int checkboxColWidth: 22     // 复选框列宽
    readonly property int thumbnailSize: 40        // 缩略图尺寸
    readonly property int colInnerOffset: 26       // 各列内容左偏移（进度列/大小列/操作列）
    readonly property int progressBarW: 160        // 进度条宽度
    readonly property int scrollBarRightOffset: 16 // 滚动条相对内容区域的右移距离

    // ==================== 历史记录列偏移 ====================
    // 列头 leftPadding 与列内 x 保持一致，确保表头与内容对齐
    readonly property int histFileSizeColX: 52
    readonly property int histDurationColX: 66
    readonly property int histStatusColX: 60
    readonly property int histActionColX: 43

    // ==================== 空状态布局 ====================
    // 图标 + 文字整体尺寸（图标80×56 + 间距12 + 文字行高≈16）
    readonly property int emptyStateWidth: 80
    readonly property int emptyStateHeight: 84
    // 距内容区顶部分隔线(headerSeparatorY=41)230px → 距ListView顶部(listViewStartY=160)的偏移 = 230−(160−41) = 111
    readonly property int emptyStateTopMargin: 111

    // 活跃队列 - 文件名称列宽（表头、delegate、文件名 Text 共用同一基准）
    readonly property real activeFileNameColRatio: 0.42
    readonly property int  activeFileNameColOffset: 22
    // 历史记录队列 - 文件名称列宽
    readonly property real histFileNameColRatio: 0.38
    readonly property int  histFileNameColOffset: 20
    readonly property bool currentTabHasItems: (vm.currentTabIndex === 0 ? vm.tabCounts[0] : vm.tabCounts[1]) > 0
    readonly property bool hasPartialSelection: vm.checkedCount > 0 && !vm.isAllChecked

    function closeByUserAction() {
        taskQueuePopup.close()
        closeClicked()
    }

    Shortcut {
        sequence: "Escape"
        context: Qt.WindowShortcut
        enabled: taskQueuePopup.visible
        onActivated: taskQueuePopup.closeByUserAction()
    }

    contentItem: Item {
        id: rootContent
        focus: true
        Keys.priority: Keys.BeforeItem
        Keys.onEscapePressed: function(event) {
            event.accepted = true
            taskQueuePopup.closeByUserAction()
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            preventStealing: true
            onPressed: function(mouse) {
                mouse.accepted = true
            }
            onReleased: function(mouse) {
                mouse.accepted = true
            }
            onClicked: function(mouse) {
                mouse.accepted = true
            }
            onDoubleClicked: function(mouse) {
                mouse.accepted = true
            }
            onPressAndHold: function(mouse) {
                mouse.accepted = true
            }
            onWheel: function(wheel) {
                wheel.accepted = true
            }
        }

        // 主容器
        Rectangle {
            id: mainContainer
            anchors.fill: parent
            color: Colors.color_2F3032
            radius: 8
            clip: true
            border.width: 1
            border.color: Colors.color_454649

            // ==================== 标题栏区域 ====================

            // macOS 风格关闭按钮
            IconButton {
                id: closeBtn
                anchors {
                    top: parent.top
                    left: parent.left
                    topMargin: 14
                    leftMargin: 16
                }
                width: 12
                height: 12
                iconMargins: 0
                visible: !CommonUtils.isWindows()
                iconSource: "qrc:/icons/appbar/btn_close_normal.svg"
                hoverIconSource: "qrc:/icons/appbar/btn_close_hovered.svg"
                pressedIconSource: "qrc:/icons/appbar/btn_close_pushed.svg"
                disabledIconSource: "qrc:/icons/appbar/btn_appbar_disable.svg"
                onClicked: {
                    taskQueuePopup.closeByUserAction()
                }
            }

            // Windows 风格关闭按钮
            IconButton {
                id: windowsCloseBtn
                anchors {
                    right: parent.right
                    rightMargin: 16
                    verticalCenter: titleText.verticalCenter
                }
                width: 20
                height: 20
                iconMargins: 0
                visible: CommonUtils.isWindows()
                iconSource: "qrc:/icons/WindowsIcon/icon_close_modal.svg"
                hoverIconSource: "qrc:/icons/WindowsIcon/icon_close_modal_hover.svg"
                pressedIconSource: "qrc:/icons/WindowsIcon/icon_close_modal_hover.svg"
                disabledIconSource: "qrc:/icons/WindowsIcon/icon_close_modal.svg"
                onClicked: {
                    taskQueuePopup.closeByUserAction()
                }
            }

            // 标题
            Text {
                id: titleText
                anchors.top: parent.top
                anchors.topMargin: 11
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("pccut_task_queue_title")
                font.pixelSize: 13
                font.weight: Font.Medium
                color: Colors.color_EEEEEE
            }

            // 标题栏底部分隔线（右侧内容区上方）
            Rectangle {
                x: taskQueuePopup.sidebarWidth
                y: taskQueuePopup.headerSeparatorY
                width: parent.width - taskQueuePopup.sidebarWidth
                height: 1
                color: Colors.color_454649
                opacity: 0.6
            }

            // ==================== 左侧栏 ====================

            // 左侧栏背景
            Rectangle {
                id: sidebarBg
                x: 0
                y: taskQueuePopup.headerSeparatorY
                width: taskQueuePopup.sidebarWidth
                height: parent.height - taskQueuePopup.headerSeparatorY
                color: Colors.color_1F2021
                // 只需左下圆角
                radius: 8
                // 补上角：顶部平直
                Rectangle {
                    width: parent.width
                    height: parent.radius
                    color: parent.color
                    anchors.top: parent.top
                }
                // 补右侧：右边平直
                Rectangle {
                    width: parent.radius
                    height: parent.height
                    color: parent.color
                    anchors.right: parent.right
                }
                // 三边描边（上、左、下含左下圆角）用 Shape 绘制连续路径
                Shape {
                    id: sidebarBorderShape
                    anchors.fill: parent
                    ShapePath {
                        strokeColor: Colors.color_454649
                        strokeWidth: 1
                        fillColor: "transparent"
                        // 从右上角出发，沿上边往左到左上角
                        startX: sidebarBorderShape.width; startY: 0.5
                        PathLine { x: 0.5;                          y: 0.5 }
                        // 左边往下到圆角切点
                        PathLine { x: 0.5;                          y: sidebarBorderShape.height - sidebarBg.radius }
                        // 左下圆角弧（顺时针：左边切点 → 底边切点）
                        PathArc  {
                            x: sidebarBg.radius;                    y: sidebarBorderShape.height - 0.5
                            radiusX: sidebarBg.radius;              radiusY: sidebarBg.radius
                            direction: PathArc.Counterclockwise
                        }
                        // 底边往右
                        PathLine { x: sidebarBorderShape.width;     y: sidebarBorderShape.height - 0.5 }
                    }
                }
            }

            // 左侧导航列表
            Column {
                id: navColumn
                x: 12
                y: 64
                width: 160
                spacing: 12

                Repeater {
                    model: vm.navItems

                    Rectangle {
                        objectName: "taskQueueNavItem_" + index
                        width: navColumn.width
                        height: 40
                        radius: 6
                        property int activeTaskCount: vm.navActiveCounts[index] || 0
                        property int pausedFailedTaskCount: vm.navPausedFailedCounts[index] || 0
                        property bool hasHistoryDot: vm.navHistoryDots[index] || false
                        color: vm.currentNavIndex === index
                              ? Colors.color_2F3032
                              : (navItemArea.containsMouse ? Colors.color_2F3032 : Colors.color_transparent)

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 16
                            text: modelData
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            color: vm.currentNavIndex === index
                                  ? Colors.color_EEEEEE
                                  : Colors.color_999999
                        }

                        CountBadge {
                            id: navCountBadge
                            count: parent.activeTaskCount
                            badgeColor: Colors.color_F22443
                            textColor: Colors.color_FFFFFF
                            anchors.right: parent.right
                            anchors.rightMargin: 16
                            anchors.verticalCenter: parent.verticalCenter
                            visible: parent.activeTaskCount > 0
                        }

                        CountBadge {
                            count: parent.pausedFailedTaskCount
                            badgeColor: Colors.color_EEEEEE
                            textColor: Colors.color_141414
                            anchors.right: parent.right
                            anchors.rightMargin: 16
                            anchors.verticalCenter: parent.verticalCenter
                            visible: parent.activeTaskCount <= 0 && parent.pausedFailedTaskCount > 0
                        }

                        Rectangle {
                            width: 5
                            height: 5
                            radius: 2.5
                            color: Colors.color_F22443
                            anchors.right: parent.right
                            anchors.rightMargin: 20
                            anchors.verticalCenter: parent.verticalCenter
                            visible: parent.activeTaskCount <= 0 && parent.pausedFailedTaskCount <= 0 && parent.hasHistoryDot
                        }

                        MouseArea {
                            id: navItemArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                vm.currentNavIndex = index
                                vm.currentTabIndex = 0
                            }
                        }
                    }
                }
            }

            // ==================== 右侧内容区 ====================

            // 内容标签页 + 操作按钮 行
            Item {
                id: tabActionRow
                x: contentLeftX
                y: 56
                width: mainContainer.width - contentLeftX - contentRightMargin
                height: 32

                // 标签页
                Row {
                    id: tabRow
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 24

                    Repeater {
                        model: vm.tabLabels

                        Item {
                            width: tabText.implicitWidth + 6
                            height: tabText.implicitHeight

                            Text {
                                id: tabText
                                text: vm.tabCounts[index] > 0
                                      ? modelData + " " + vm.tabCounts[index]
                                      : modelData
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                                color: vm.currentTabIndex === index
                                      ? Colors.color_EEEEEE
                                      : Colors.color_666666
                            }

                            // 红点：仅在"xx记录"标签（index===1）且有新记录时显示
                            Rectangle {
                                visible: index === 1 && vm.showCurrentHistoryDot
                                width: 5
                                height: 5
                                radius: 2.5
                                color: Colors.color_F22443
                                anchors.left: tabText.right
                                anchors.leftMargin: 5
                                anchors.top: tabText.top
                                anchors.topMargin: 5
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    vm.currentTabIndex = index
                                }
                            }
                        }
                    }
                }

                // 操作按钮区：全部暂停 / 全部清除
                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    // 全部暂停/恢复按钮（仅在"正在xx"标签页 + 上传/下载队列时显示）
                    IconTextButton {
                        id: pauseResumeAllButton
                        objectName: "taskQueuePauseResumeAllBtn"
                        property bool allPaused: vm.currentNavIndex === 1
                                                 ? CloudAlbumTransferModel.uploadRunningCount === 0
                                                 : CloudAlbumTransferModel.downloadRunningCount === 0
                        height: 28
                        visible: vm.currentTabIndex === 0 && vm.isTransferModel
                        enabled: vm.tabCounts[0] > 0
                        opacity: enabled ? 1.0 : 0.2
                        iconPathNormal: allPaused ? "qrc:/icons/icon_resume.svg" : "qrc:/icons/icon_pause.svg"
                        iconPathHover: allPaused ? "qrc:/icons/icon_resume_hover.svg" : "qrc:/icons/icon_pause_hover.svg"
                        iconSizeNormal: Qt.size(16, 16)
                        title: allPaused
                               ? (taskQueuePopup.hasPartialSelection
                                  ? qsTr("pccut_task_queue_batch_resume")
                                  : qsTr("pccut_task_queue_resume_all"))
                               : (taskQueuePopup.hasPartialSelection
                                  ? qsTr("pccut_task_queue_batch_pause")
                                  : qsTr("pccut_task_queue_pause_all"))
                        titleFontWeight: Font.Medium
                        titleColorNormal: Colors.color_EEEEEE
                        backgroundColorNormal: Colors.color_454649
                        backgroundColorHover: Colors.color_56575B
                        alignment: Qt.AlignHCenter
                        hoveredCursor: Qt.PointingHandCursor
                        internalSpacing: 4
                        imageRectWidth: 16
                        imageRectHeight: 16
                        leftPadding: 10
                        rightPadding: 10
                        radius: 6
                        onCustomClicked: vm.pauseResumeAll(allPaused)
                    }

                    // 全部清除按钮
                    IconTextButton {
                        id: clearAllButton
                        objectName: "taskQueueClearAllBtn"
                        height: 28
                        iconPathNormal: "qrc:/icons/icon_export_task_delete_hover.svg"
                        iconPathHover: "qrc:/icons/icon_export_task_delete_hover.svg"
                        title: taskQueuePopup.hasPartialSelection
                               ? qsTr("pccut_task_queue_batch_clear")
                               : qsTr("pccut_task_queue_clear_all")
                        iconSizeNormal: Qt.size(16, 16)
                        titleFontWeight: Font.Medium
                        titleColorNormal: Colors.color_EEEEEE
                        backgroundColorNormal: Colors.color_454649
                        backgroundColorHover: Colors.color_56575B
                        alignment: Qt.AlignHCenter
                        hoveredCursor: Qt.PointingHandCursor
                        internalSpacing: 4
                        imageRectWidth: 16
                        imageRectHeight: 16
                        leftPadding: 10
                        rightPadding: 10
                        radius: 6
                        hoverEnabled: !taskDeleteConfirmPopup.opened
                        enabled: vm.currentTabIndex === 0 ? vm.tabCounts[0] > 0 : vm.tabCounts[1] > 0
                        opacity: enabled ? 1.0 : 0.2
                        onCustomClicked: {
                            rootContent.forceActiveFocus()
                            Qt.callLater(function() {
                                if (!clearAllButton.enabled) return

                                if (vm.isExportModel && vm.currentTabIndex === 0) {
                                    vm.exportTabViewModel.clearExportList()
                                    vm.clearChecked()
                                } else if (vm.currentTabIndex === 0 && vm.isTransferModel) {
                                    // 上传/下载活跃队列：可能存在进行中或传输到一半的任务，需二次确认
                                    taskDeleteConfirmPopup.showForClearActive()
                                } else if (vm.currentTabIndex === 0) {
                                    vm.cancelActiveAll()
                                } else {
                                    vm.clearHistory()
                                }
                            })
                        }
                    }
                }
            }

            // 标签页下方分隔线
            Rectangle {
                x: contentLeftX
                y: 106
                width: mainContainer.width - contentLeftX - contentRightMargin
                height: 1
                color: Colors.color_454649
                opacity: 0.6
            }

            // ==================== 正在xx 界面 (currentTabIndex === 0) ====================
            // 表格列头
            Item {
                id: tableHeader
                x: contentLeftX
                y: taskQueuePopup.tableHeaderY
                width: mainContainer.width - contentLeftX - contentRightMargin
                height: taskQueuePopup.tableHeaderHeight
                visible: vm.currentTabIndex === 0

                Row {
                    anchors.fill: parent

                    // 全选复选框
                    Item {
                        width: taskQueuePopup.checkboxColWidth
                        height: parent.height

                        Rectangle {
                            width: 14
                            height: 14
                            radius: 4
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            color: vm.isAllChecked ? ColorsConfig.color_brand : Colors.color_444444
                            opacity: taskQueuePopup.currentTabHasItems ? 1.0 : 0.2

                            Image {
                                anchors.fill: parent
                                source: "qrc:/app_qrc/icons/icon_checkbox_check.svg"
                                sourceSize: Qt.size(parent.width, parent.height)
                                visible: vm.isAllChecked
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: taskQueuePopup.currentTabHasItems
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: vm.toggleAllChecked()
                            }
                        }
                    }

                    // 文件名称
                    Text {
                        width: parent.width * taskQueuePopup.activeFileNameColRatio - taskQueuePopup.activeFileNameColOffset
                        leftPadding: 8
                        height: parent.height
                        text: qsTr("pccut_task_queue_col_filename")
                        font.pixelSize: 12
                        color: Colors.color_666666
                        verticalAlignment: Text.AlignVCenter
                    }
                    // 导出进度/上传进度/下载进度
                    Text {
                        width: parent.width * 0.30
                        height: parent.height
                        leftPadding: taskQueuePopup.colInnerOffset
                        text: vm.currentNavIndex === 0
                              ? qsTr("pccut_task_queue_col_export_progress")
                              : vm.currentNavIndex === 1
                                ? qsTr("pccut_task_queue_col_upload_progress")
                                : qsTr("pccut_task_queue_col_download_progress")
                        font.pixelSize: 12
                        color: Colors.color_666666
                        verticalAlignment: Text.AlignVCenter
                    }
                    // 文件大小
                    Text {
                        width: parent.width * 0.15
                        height: parent.height
                        leftPadding: taskQueuePopup.colInnerOffset
                        text: qsTr("pccut_task_queue_col_filesize")
                        font.pixelSize: 12
                        color: Colors.color_666666
                        verticalAlignment: Text.AlignVCenter
                    }
                    // 操作
                    Text {
                        width: parent.width * 0.13
                        height: parent.height
                        leftPadding: taskQueuePopup.colInnerOffset
                        text: qsTr("pccut_task_queue_col_action")
                        font.pixelSize: 12
                        color: Colors.color_666666
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            // 文件列表区域
            ListView {
                id: fileListView
                objectName: "taskQueueActiveListView"
                x: contentLeftX - taskQueuePopup.delegateHoverPadding
                y: taskQueuePopup.listViewStartY
                width: mainContainer.width - contentLeftX - contentRightMargin + 24
                       + taskQueuePopup.delegateHoverPadding + taskQueuePopup.scrollBarRightOffset
                height: mainContainer.height - y - 12
                clip: true
                spacing: 4
                rightMargin: 24 + taskQueuePopup.scrollBarRightOffset
                boundsBehavior: Flickable.StopAtBounds
                visible: vm.currentTabIndex === 0

                ScrollBar.vertical: ScrollBar {
                    rightPadding: 4

                    function updateThumbColor() {
                        contentItem.color = hovered || pressed ? "#56575b" : "#454649"
                    }

                    Component.onCompleted: updateThumbColor()
                    onHoveredChanged: updateThumbColor()
                    onPressedChanged: updateThumbColor()
                }

                model: vm.activeModel

                delegate: Item {
                    objectName: "taskQueueActiveItem_" + index
                    width: fileListView.width - fileListView.rightMargin + taskQueuePopup.delegateHoverPadding
                    height: taskQueuePopup.delegateHeight

                    // 标准化字段：统一不同 model 类型的属性访问
                    readonly property string itemFileName:   model.fileName      || ""
                    readonly property real   itemProgress:   model.progress      || 0
                    readonly property int    itemFileStatus: model.fileStatus    || 0
                    readonly property real   itemFileSizeBytes: model.fileSize || 0
                    readonly property string itemFileSize: itemFileSizeBytes > 0
                        ? CommonUtils.getFileSizeInfo(itemFileSizeBytes)
                        : ""
                    readonly property string itemSpeed:      model.speedDisplay  || ""
                    readonly property string itemError:      model.errorMessage  || ""
                    readonly property string itemThumbnail:  model.thumbnail     || ""
                    readonly property string itemLocalPath:   model.localPath     || ""
                    // Reuse the device image provider when an upload thumbnail is not ready.
                    readonly property bool useImageProviderThumbnail:
                        taskQueuePopup.vm.currentNavIndex === 1 &&
                        itemThumbnail.length === 0 && itemLocalPath.length > 0
                    readonly property string itemThumbnailSource:
                        useImageProviderThumbnail
                            ? "image://image_provider/" + itemLocalPath + ";0;0;0;1;1"
                            : itemThumbnail
                    // 唯一标识符：TransferModel 用 taskId，ExportModel 用 draftPath
                    readonly property string itemUniqueId:   model.uniqueId      || ""
                    // isItemChecked 是 Q_INVOKABLE，显式读取 checkedCount 让单行状态随变更刷新
                    readonly property bool   itemChecked:    vm.checkedCount >= 0 && vm.isItemChecked(itemUniqueId)

                    HoverHandler {
                        id: delegateHoverHandler
                    }

                    // 扩展 hover 背景（左右各 +12px，不影响内容布局）
                    Rectangle {
                        x: 0
                        width: parent.width
                        height: parent.height
                        color: delegateHoverHandler.hovered ? "#37383A" : Colors.color_transparent
                        radius: 6

                        MouseArea {
                            id: delegateMouseArea
                            anchors.fill: parent
                            propagateComposedEvents: true
                            onClicked: function(mouse) {
                                vm.toggleItemChecked(itemUniqueId)
                                mouse.accepted = false
                            }
                        }
                    }

                    Row {
                        anchors.fill: parent
                        anchors.topMargin: 0
                        anchors.leftMargin: taskQueuePopup.delegateHoverPadding
                        anchors.rightMargin: taskQueuePopup.delegateHoverPadding
                        spacing: 0

                            // ===== 复选框列 =====
                            Item {
                                width: taskQueuePopup.checkboxColWidth
                                height: parent.height

                                Rectangle {
                                    width: 14
                                    height: 14
                                    radius: 4
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    color: itemChecked ? ColorsConfig.color_brand : Colors.color_444444

                                    Image {
                                        anchors.fill: parent
                                        source: "qrc:/app_qrc/icons/icon_checkbox_check.svg"
                                        sourceSize: Qt.size(parent.width, parent.height)
                                        visible: itemChecked
                                    }

                                    MouseArea {
                                        objectName: "taskQueueActiveCheckbox_" + index
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: vm.toggleItemChecked(itemUniqueId)
                                    }
                                }
                            }

                            // ===== 文件名称列：缩略图 + 文件名 =====
                            Item {
                                width: parent.width * taskQueuePopup.activeFileNameColRatio - taskQueuePopup.activeFileNameColOffset
                                height: parent.height

                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8
                                    spacing: 12

                                    // 缩略图
                                    Rectangle {
                                        id: thumbMask1
                                        objectName: "taskQueueActiveThumbnail_" + index
                                        width: taskQueuePopup.thumbnailSize
                                        height: taskQueuePopup.thumbnailSize
                                        radius: 6
                                        color: Colors.color_454649

                                        Loader {
                                            anchors.fill: parent
                                            active: itemThumbnailSource.length > 0
                                            sourceComponent: Image {
                                                anchors.fill: parent
                                                source: itemThumbnailSource
                                                sourceSize: Qt.size(taskQueuePopup.thumbnailSize,
                                                                    taskQueuePopup.thumbnailSize)
                                                fillMode: Image.PreserveAspectCrop
                                                asynchronous: true
                                                layer.enabled: true
                                                layer.effect: OpacityMask {
                                                    maskSource: Rectangle {
                                                        width: thumbMask1.width
                                                        height: thumbMask1.height
                                                        radius: thumbMask1.radius
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // 文件名
                                    Text {
                                        id: activeFileNameText
                                        objectName: "taskQueueActiveFileName_" + index
                                        width: parent.parent.parent.width * taskQueuePopup.activeFileNameColRatio - taskQueuePopup.activeFileNameColOffset - 56 - 16 - 16
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: itemFileName
                                        font.pixelSize: 12
                                        color: Colors.color_999999
                                        elide: Text.ElideMiddle
                                        maximumLineCount: 1

                                        MouseArea {
                                            id: activeFileNameHover
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            acceptedButtons: Qt.NoButton
                                            propagateComposedEvents: true
                                        }

                                        LightToolTip {
                                            visible: activeFileNameHover.containsMouse && activeFileNameText.implicitWidth > activeFileNameText.width
                                            tip: itemFileName
                                        }
                                    }
                                }
                            }

                            // ===== 下载进度列 =====
                            Item {
                                id: progressColumn
                                width: parent.width * 0.30
                                height: parent.height

                                // 使用标准化的状态和进度
                                property int fileStatus: itemFileStatus
                                property real fileProgress: itemProgress
                                property real smoothProgress: 0
                                Behavior on smoothProgress {
                                    NumberAnimation { duration: 500; easing.type: Easing.OutCubic }
                                }
                                onFileProgressChanged: smoothProgress = fileProgress
                                Component.onCompleted: smoothProgress = fileProgress

                                // 正常进行中状态
                                Item {
                                    anchors.fill: parent
                                    visible: parent.fileStatus === 1

                                    // 进度条 - 与行垂直居中
                                    Rectangle {
                                        id: progressBarActive
                                        objectName: "taskQueueActiveProgressBar_" + index
                                        x: taskQueuePopup.colInnerOffset
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: taskQueuePopup.progressBarW
                                        height: 2
                                        radius: 1
                                        color: Colors.color_454649

                                        Rectangle {
                                            width: parent.width * progressColumn.smoothProgress
                                            height: parent.height
                                            radius: 1
                                            color: ColorsConfig.color_brand
                                        }
                                    }

                                    // 进行中状态文字: 导出中/上传中/下载中 88% – 120.9 MB/S
                                    Text {
                                        objectName: "taskQueueActiveProgressText_" + index
                                        x: progressBarActive.x
                                        anchors.top: progressBarActive.bottom
                                        anchors.topMargin: 2
                                        text: {
                                            var statusText;
                                            switch (vm.currentNavIndex) {
                                            case 0: statusText = qsTr("pccut_task_queue_exporting_status"); break;
                                            case 1: statusText = qsTr("pccut_task_queue_uploading_status"); break;
                                            case 2: statusText = qsTr("pccut_task_queue_downloading_status"); break;
                                            default: statusText = ""; break;
                                            }
                                            var prog = Math.round(progressColumn.smoothProgress * 100);
                                            var speedStr = (prog >= 100) ? "" : itemSpeed;
                                            return statusText + " " + prog + "%"
                                                   + (speedStr !== "" ? " – " + speedStr : "");
                                        }
                                        font.pixelSize: 10
                                        color: Colors.color_999999
                                    }
                                }

                                // 失败状态
                                Item {
                                    anchors.fill: parent
                                    visible: parent.fileStatus === 3

                                    // 空进度条 - 与行垂直居中
                                    Rectangle {
                                        id: progressBarFailed
                                        x: taskQueuePopup.colInnerOffset
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: taskQueuePopup.progressBarW
                                        height: 2
                                        radius: 1
                                        color: Colors.color_454649
                                    }

                                    Text {
                                        objectName: "taskQueueActiveErrorText_" + index
                                        x: progressBarFailed.x
                                        width: progressBarFailed.width
                                        anchors.top: progressBarFailed.bottom
                                        anchors.topMargin: 2
                                        text: itemError
                                        font.pixelSize: 10
                                        color: Colors.color_F22443
                                        horizontalAlignment: Text.AlignLeft
                                        wrapMode: Text.Wrap
                                        maximumLineCount: 2
                                    }
                                }

                                // 排队状态
                                Text {
                                    objectName: "taskQueueActiveStatusText_" + index
                                    x: taskQueuePopup.colInnerOffset
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: parent.fileStatus === 0
                                    text: qsTr("pccut_task_queue_queuing")
                                    font.pixelSize: 11
                                    color: Colors.color_666666
                                }

                                // 已暂停状态
                                Item {
                                    anchors.fill: parent
                                    visible: parent.fileStatus === 2

                                    Rectangle {
                                        id: progressBarPaused
                                        x: taskQueuePopup.colInnerOffset
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: taskQueuePopup.progressBarW
                                        height: 2
                                        radius: 1
                                        color: Colors.color_454649

                                        Rectangle {
                                            width: parent.width * progressColumn.smoothProgress
                                            height: parent.height
                                            radius: 1
                                            color: Colors.color_EEEEEE
                                        }
                                    }

                                    Text {
                                        objectName: "taskQueueActivePausedText_" + index
                                        x: progressBarPaused.x
                                        anchors.top: progressBarPaused.bottom
                                        anchors.topMargin: 2
                                        text: qsTr("pccut_task_queue_paused") + " " + Math.round(progressColumn.smoothProgress * 100) + "%"
                                        font.pixelSize: 10
                                        color: Colors.color_999999
                                    }
                                }
                            }

                            // ===== 文件大小列 =====
                            Item {
                                width: parent.width * 0.15
                                height: parent.height

                                Text {
                                    objectName: "taskQueueActiveFileSize_" + index
                                    x: taskQueuePopup.colInnerOffset
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: itemFileSize
                                    font.pixelSize: 12
                                    color: Colors.color_999999
                                }
                            }

                            // ===== 操作列 =====
                            Item {
                                width: parent.width * 0.13
                                height: parent.height

                                property int fileStatus: itemFileStatus

                                Row {
                                    x: taskQueuePopup.colInnerOffset
                                    anchors.verticalCenter: parent.verticalCenter
                                    height: parent.height
                                    spacing: 20
                                    enabled: parent.fileStatus === 3 || itemProgress < 1.0
                                    opacity: parent.fileStatus !== 3 && itemProgress >= 1.0 ? 0.2 : 1.0

                                    // 暂停/恢复/重试 按钮
                                    Image {
                                        anchors.verticalCenter: parent.verticalCenter
                                        // 失败: 重试图标, 排队/暂停: 恢复图标, 进行中: 暂停图标
                                        source: parent.parent.fileStatus === 3
                                                ? (retryItemArea.containsMouse
                                                    ? "qrc:/icons/icon_export_retry_hover.svg"
                                                    : "qrc:/icons/icon_export_retry.svg")
                                                : (parent.parent.fileStatus === 2 || parent.parent.fileStatus === 0)
                                                ? ((resumeItemArea.containsMouse || forceStartItemArea.containsMouse)
                                                    ? "qrc:/icons/icon_resume_hover.svg"
                                                    : "qrc:/icons/icon_resume.svg")
                                                : (pauseItemArea.containsMouse
                                                    ? "qrc:/icons/icon_pause_hover.svg"
                                                    : "qrc:/icons/icon_pause.svg")
                                        sourceSize: Qt.size(20, 20)
                                        visible: {
                                            var st = parent.parent.fileStatus;
                                            if (vm.isExportModel)
                                                return st === 3;  // 导出仅支持失败重试
                                            return st === 0 || st === 1 || st === 2 || st === 3;
                                        }

                                        MouseArea {
                                            id: pauseItemArea
                                            objectName: "taskQueueActivePauseBtn_" + index
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            visible: !vm.isExportModel && parent.parent.parent.fileStatus === 1
                                            onClicked: {
                                                if (vm.isTransferModel) {
                                                    CloudAlbumTransferModel.pauseTask(model.taskId);
                                                }
                                            }
                                        }
                                        MouseArea {
                                            id: resumeItemArea
                                            objectName: "taskQueueActiveResumeBtn_" + index
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            visible: !vm.isExportModel && parent.parent.parent.fileStatus === 2
                                            onClicked: {
                                                if (vm.isTransferModel) {
                                                    CloudAlbumTransferModel.resumeTask(model.taskId)
                                                }
                                            }
                                        }
                                        MouseArea {
                                            id: forceStartItemArea
                                            objectName: "taskQueueActiveForceStartBtn_" + index
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            visible: !vm.isExportModel && parent.parent.parent.fileStatus === 0
                                            onClicked: {
                                                if (vm.isTransferModel) {
                                                    CloudAlbumTransferModel.forceStartTask(model.taskId)
                                                }
                                            }
                                        }
                                        MouseArea {
                                            id: retryItemArea
                                            objectName: "taskQueueActiveRetryBtn_" + index
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            visible: parent.parent.parent.fileStatus === 3
                                            onClicked: {
                                                if (vm.isExportModel) {
                                                    vm.exportTabViewModel.handCompose(model.draftPath, model.outPath);
                                                } else if (vm.isTransferModel) {
                                                    CloudAlbumTransferModel.retryTask(model.taskId);
                                                }
                                            }
                                        }

                                        LightToolTip {
                                            visible: pauseItemArea.containsMouse
                                                     || resumeItemArea.containsMouse
                                                     || forceStartItemArea.containsMouse
                                                     || retryItemArea.containsMouse
                                            tip: {
                                                if (retryItemArea.containsMouse) return qsTr("pccut_task_queue_action_retry")
                                                if (resumeItemArea.containsMouse) {
                                                    return vm.currentNavIndex === 1
                                                        ? qsTr("pccut_task_queue_tooltip_resume_upload")
                                                        : qsTr("pccut_task_queue_tooltip_resume_download")
                                                }
                                                if (forceStartItemArea.containsMouse) {
                                                    return vm.currentNavIndex === 1
                                                        ? qsTr("pccut_task_queue_tooltip_start_upload")
                                                        : qsTr("pccut_task_queue_tooltip_start_download")
                                                }
                                                return qsTr("pccut_task_queue_action_pause")
                                            }
                                        }
                                    }

                                    // 删除按钮
                                    Image {
                                        anchors.verticalCenter: parent.verticalCenter
                                        source: cancelItemArea.containsMouse
                                                ? "qrc:/icons/icon_export_task_delete_hover.svg"
                                                : "qrc:/icons/icon_export_task_delete.svg"
                                        sourceSize: Qt.size(20, 20)

                                        MouseArea {
                                            id: cancelItemArea
                                            objectName: "taskQueueActiveCancelBtn_" + index
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (vm.isExportModel) {
                                                    if (itemFileStatus === 1) {
                                                        taskDeleteConfirmPopup.showForActiveExportTask(model.draftPath)
                                                    } else {
                                                        vm.exportTabViewModel.deleteByDraftPath(model.draftPath, false);
                                                    }
                                                } else if (vm.isTransferModel) {
                                                    if (itemFileStatus === 3) {
                                                        CloudAlbumTransferModel.removeTask(model.taskId);
                                                    } else {
                                                        CloudAlbumTransferModel.cancelTask(model.taskId);
                                                    }
                                                }
                                            }
                                        }

                                        LightToolTip {
                                            visible: cancelItemArea.containsMouse
                                            tip: vm.isTransferModel
                                                ? qsTr("pccut_task_queue_tooltip_delete_task")
                                                : qsTr("pccut_task_queue_action_cancel")
                                        }
                                    }
                                }
                            }
                        }
                    }

                // 空状态
                Item {
                    visible: fileListView.count === 0
                    width: taskQueuePopup.emptyStateWidth
                    height: taskQueuePopup.emptyStateHeight
                    x: (parent.width - parent.rightMargin - width) / 2
                    anchors.top: parent.top
                    anchors.topMargin: taskQueuePopup.emptyStateTopMargin

                    Column {
                        anchors.centerIn: parent
                        spacing: 12

                        Image {
                            anchors.horizontalCenter: parent.horizontalCenter
                            source: "qrc:/icons/icon_empty_state.svg"
                            sourceSize: Qt.size(80, 56)
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: vm.emptyText
                            font.pixelSize: 12
                            color: Colors.color_444444
                        }
                    }
                }
            }

            // ==================== xx记录 界面 (currentTabIndex === 1) ====================
            // 记录表头
            Item {
                id: historyTableHeader
                x: contentLeftX
                y: taskQueuePopup.tableHeaderY
                width: mainContainer.width - contentLeftX - contentRightMargin
                height: taskQueuePopup.tableHeaderHeight
                visible: vm.currentTabIndex === 1

                Row {
                    anchors.fill: parent

                    // 全选复选框
                    Item {
                        width: taskQueuePopup.checkboxColWidth
                        height: parent.height

                        Rectangle {
                            width: 14
                            height: 14
                            radius: 4
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            color: vm.isAllChecked ? ColorsConfig.color_brand : Colors.color_444444
                            opacity: taskQueuePopup.currentTabHasItems ? 1.0 : 0.2

                            Image {
                                anchors.fill: parent
                                source: "qrc:/app_qrc/icons/icon_checkbox_check.svg"
                                sourceSize: Qt.size(parent.width, parent.height)
                                visible: vm.isAllChecked
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: taskQueuePopup.currentTabHasItems
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: vm.toggleAllChecked()
                            }
                        }
                    }

                    // 文件名称
                    Text {
                        width: parent.width * taskQueuePopup.histFileNameColRatio - taskQueuePopup.histFileNameColOffset
                        leftPadding: 8
                        height: parent.height
                        text: qsTr("pccut_task_queue_col_filename")
                        font.pixelSize: 12
                        color: Colors.color_666666
                        verticalAlignment: Text.AlignVCenter
                    }
                    // 导出显示分辨率，上传/下载显示文件大小
                    Text {
                        width: parent.width * 0.13
                        height: parent.height
                        leftPadding: taskQueuePopup.histFileSizeColX
                        text: vm.currentNavIndex === 0
                              ? qsTr("pccut_media_info_resolution")
                              : qsTr("pccut_task_queue_col_filesize")
                        font.pixelSize: 12
                        color: Colors.color_666666
                        verticalAlignment: Text.AlignVCenter
                    }
                    // 文件时长
                    Text {
                        width: parent.width * 0.15
                        height: parent.height
                        leftPadding: taskQueuePopup.histDurationColX
                        text: qsTr("pccut_task_queue_col_duration")
                        font.pixelSize: 12
                        color: Colors.color_666666
                        verticalAlignment: Text.AlignVCenter
                    }
                    // 状态
                    Text {
                        width: parent.width * 0.18
                        height: parent.height
                        leftPadding: taskQueuePopup.histStatusColX
                        text: qsTr("pccut_task_queue_col_status")
                        font.pixelSize: 12
                        color: Colors.color_666666
                        verticalAlignment: Text.AlignVCenter
                    }
                    // 操作
                    Text {
                        width: parent.width * 0.16
                        height: parent.height
                        leftPadding: taskQueuePopup.histActionColX
                        text: qsTr("pccut_task_queue_col_action")
                        font.pixelSize: 12
                        color: Colors.color_666666
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            // 记录列表
            ListView {
                id: historyListView
                objectName: "taskQueueHistoryListView"
                x: contentLeftX - taskQueuePopup.delegateHoverPadding
                y: taskQueuePopup.listViewStartY
                width: mainContainer.width - contentLeftX - contentRightMargin + 24
                       + taskQueuePopup.delegateHoverPadding + taskQueuePopup.scrollBarRightOffset
                height: mainContainer.height - y - 12
                clip: true
                spacing: 4
                rightMargin: 24 + taskQueuePopup.scrollBarRightOffset
                boundsBehavior: Flickable.StopAtBounds
                visible: vm.currentTabIndex === 1

                ScrollBar.vertical: ScrollBar {
                    rightPadding: 4

                    function updateThumbColor() {
                        contentItem.color = hovered || pressed ? "#56575b" : "#454649"
                    }

                    Component.onCompleted: updateThumbColor()
                    onHoveredChanged: updateThumbColor()
                    onPressedChanged: updateThumbColor()
                }

                model: vm.historyModel

                delegate: Item {
                    objectName: "taskQueueHistoryItem_" + index
                    width: historyListView.width - historyListView.rightMargin + taskQueuePopup.delegateHoverPadding
                    readonly property string histItemLocalPath:   model.localPath || ""
                    // Reuse the device image provider for upload history when needed.
                    readonly property bool useImageProviderThumbnail:
                        taskQueuePopup.vm.currentNavIndex === 1 &&
                        histItemThumbnail.length === 0 && histItemLocalPath.length > 0
                    readonly property string histItemThumbnailSource:
                        useImageProviderThumbnail
                            ? "image://image_provider/" + histItemLocalPath + ";0;0;0;1;1"
                            : histItemThumbnail
                    height: taskQueuePopup.delegateHeight

                    // 标准化字段
                    readonly property string histItemFileName:   model.fileName     || ""
                    // 导出/下载已完成但本地文件已丢失
                    property bool isLocalFileLost: model.isLocalFileLost || false
                    readonly property int    histItemFileStatus: model.fileStatus || 0
                    readonly property string histItemError:      model.errorMessage || ""
                    readonly property string histItemThumbnail:  model.thumbnail    || ""
                    // 唯一标识符：TransferModel 用 taskId，ExportModel 用 draftPath
                    readonly property string itemUniqueId:       model.uniqueId     || ""
                    // isItemChecked 是 Q_INVOKABLE，显式读取 checkedCount 让单行状态随变更刷新
                    readonly property bool   itemChecked:        vm.checkedCount >= 0 && vm.isItemChecked(itemUniqueId)

                    HoverHandler {
                        id: historyDelegateHoverHandler
                    }

                    // 分辨率 / 文件大小 / 时长缓存（避免 delegate 绑定中同步读文件系统）
                    property string _cachedResolution: ""
                    property real _cachedFileSizeBytes: 0
                    property string _cachedFileDuration: ""

                    Component.onCompleted: {
                        // 异步计算文件信息，避免主线程阻塞
                        vm.computeFileStatsAsync(itemUniqueId, model.outPath || "", model.localPath || "")
                    }

                    Connections {
                        target: vm
                        function onFileStatsReady(uniqueId, resolution, fileSizeBytes, duration) {
                            if (uniqueId === itemUniqueId) {
                                _cachedResolution = resolution
                                _cachedFileSizeBytes = fileSizeBytes
                                _cachedFileDuration = duration
                            }
                        }
                        // 导出完成事件可能早于文件落盘，首轮探测为空时由 VM 触发补探测
                        function onFileStatsRefreshNeeded() {
                            if (_cachedResolution === "" && _cachedFileDuration === "") {
                                vm.computeFileStatsAsync(itemUniqueId, model.outPath || "", model.localPath || "")
                            }
                        }
                    }

                    Rectangle {
                        x: 0
                        width: parent.width
                        height: parent.height
                        color: historyDelegateHoverHandler.hovered ? "#37383A" : Colors.color_transparent
                        radius: 6

                        MouseArea {
                            id: historyDelegateMouseArea
                            anchors.fill: parent
                            propagateComposedEvents: true
                            onClicked: function(mouse) {
                                vm.toggleItemChecked(itemUniqueId)
                                mouse.accepted = false
                            }
                        }

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: taskQueuePopup.delegateHoverPadding
                            anchors.rightMargin: taskQueuePopup.delegateHoverPadding
                            spacing: 0

                            // ===== 复选框列 =====
                            Item {
                                width: taskQueuePopup.checkboxColWidth
                                height: parent.height

                                Rectangle {
                                    width: 14
                                    height: 14
                                    radius: 4
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    color: itemChecked ? ColorsConfig.color_brand : Colors.color_444444

                                    Image {
                                        anchors.fill: parent
                                        source: "qrc:/app_qrc/icons/icon_checkbox_check.svg"
                                        sourceSize: Qt.size(parent.width, parent.height)
                                        visible: itemChecked
                                    }

                                    MouseArea {
                                        objectName: "taskQueueHistoryCheckbox_" + index
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: vm.toggleItemChecked(itemUniqueId)
                                    }
                                }
                            }

                            // ===== 文件名称列 =====
                            Item {
                                width: parent.width * taskQueuePopup.histFileNameColRatio - taskQueuePopup.histFileNameColOffset
                                height: parent.height

                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8
                                    spacing: 12

                                    // 缩略图
                                    Rectangle {
                                        id: thumbMask2
                                        objectName: "taskQueueHistoryThumbnail_" + index
                                        width: taskQueuePopup.thumbnailSize
                                        height: taskQueuePopup.thumbnailSize
                                        radius: 6
                                        color: Colors.color_454649

                                        Loader {
                                            anchors.fill: parent
                                            active: histItemThumbnailSource.length > 0
                                            sourceComponent: Image {
                                                anchors.fill: parent
                                                source: histItemThumbnailSource
                                                sourceSize: Qt.size(taskQueuePopup.thumbnailSize,
                                                                    taskQueuePopup.thumbnailSize)
                                                fillMode: Image.PreserveAspectCrop
                                                asynchronous: true
                                                layer.enabled: true
                                                layer.effect: OpacityMask {
                                                    maskSource: Rectangle {
                                                        width: thumbMask2.width
                                                        height: thumbMask2.height
                                                        radius: thumbMask2.radius
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // 文件名
                                    Text {
                                        id: histFileNameText
                                        objectName: "taskQueueHistoryFileName_" + index
                                        width: parent.parent.parent.width * taskQueuePopup.histFileNameColRatio - taskQueuePopup.histFileNameColOffset - 56 - 16 - 16
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: histItemFileName
                                        font.pixelSize: 12
                                        color: Colors.color_999999
                                        elide: Text.ElideMiddle
                                        maximumLineCount: 1

                                        MouseArea {
                                            id: histFileNameHover
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            acceptedButtons: Qt.NoButton
                                            propagateComposedEvents: true
                                        }

                                        LightToolTip {
                                            visible: histFileNameHover.containsMouse && histFileNameText.implicitWidth > histFileNameText.width
                                            tip: histItemFileName
                                        }
                                    }
                                }
                            }

                            // ===== 导出显示分辨率，上传/下载显示文件大小 =====
                            Item {
                                width: parent.width * 0.13
                                height: parent.height

                                Text {
                                    objectName: "taskQueueHistoryFileSize_" + index
                                    x: taskQueuePopup.histFileSizeColX
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: vm.currentNavIndex === 0
                                        ? _cachedResolution
                                        : (_cachedFileSizeBytes > 0
                                            ? CommonUtils.getFileSizeInfo(_cachedFileSizeBytes)
                                            : "")
                                    font.pixelSize: 12
                                    color: Colors.color_999999
                                }
                            }

                            // ===== 文件时长列 =====
                            Item {
                                width: parent.width * 0.15
                                height: parent.height

                                Text {
                                    objectName: "taskQueueHistoryDuration_" + index
                                    x: taskQueuePopup.histDurationColX
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: _cachedFileDuration
                                    font.pixelSize: 12
                                    color: Colors.color_999999
                                }
                            }

                            // ===== 状态列 =====
                            Item {
                                width: parent.width * 0.18
                                height: parent.height

                                property int fileStatus: histItemFileStatus

                                Row {
                                    x: taskQueuePopup.histStatusColX
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 4

                                    Image {
                                        anchors.verticalCenter: parent.verticalCenter
                                        source: "qrc:/icons/icon_export_success.svg"
                                        sourceSize: Qt.size(12, 12)
                                        visible: parent.parent.fileStatus === 4
                                    }

                                    Text {
                                        objectName: "taskQueueHistoryStatus_" + index
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: {
                                            var st = parent.parent.fileStatus;
                                            if (st === 4) {
                                                switch (vm.currentNavIndex) {
                                                case 0: return qsTr("pccut_task_queue_export_success");
                                                case 1: return qsTr("pccut_task_queue_upload_success");
                                                case 2: return qsTr("pccut_task_queue_download_success");
                                                default: return "";
                                                }
                                            } else if (st === 3) {
                                                return histItemError || qsTr("pccut_task_queue_failed");
                                            }
                                            return "";
                                        }
                                        font.pixelSize: 12
                                        maximumLineCount: 1
                                        elide: Text.ElideRight
                                        width: Math.min(implicitWidth, 90)
                                        color: parent.parent.fileStatus === 3
                                               ? Colors.color_F22443
                                               : Colors.color_999999
                                    }
                                }
                            }

                            // ===== 操作列 =====
                            Item {
                                width: parent.width * 0.16
                                height: parent.height

                                Row {
                                    x: taskQueuePopup.histActionColX
                                    anchors.verticalCenter: parent.verticalCenter
                                    height: parent.height
                                    spacing: 20

                                    // 导出/下载：打开文件夹按钮（仅成功时显示）
                                    Image {
                                        anchors.verticalCenter: parent.verticalCenter
                                        readonly property bool canOpenFolder: !isLocalFileLost

                                        source: canOpenFolder && historyOpenFolderArea.containsMouse
                                                ? "qrc:/icons/export_medium_folder_hover.svg"
                                                : "qrc:/icons/export_medium_folder.svg"
                                        sourceSize: Qt.size(20, 20)
                                        opacity: canOpenFolder ? 1.0 : 0.3
                                        visible: {
                                            if (vm.currentNavIndex === 1)
                                                return false  // 上传队列不显示
                                            if (vm.isExportModel)
                                                return histItemFileStatus === 4  // 导出成功时显示
                                            if (vm.isTransferModel)
                                                return model.fileStatus === 4  // 下载成功时显示，本地文件丢失则置灰禁用
                                            return false
                                        }

                                        MouseArea {
                                            id: historyOpenFolderArea
                                            objectName: "taskQueueHistoryOpenFolderBtn_" + index
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: parent.canOpenFolder ? Qt.PointingHandCursor : Qt.ArrowCursor
                                            onClicked: {
                                                if (!parent.canOpenFolder)
                                                    return
                                                var p = model.outPath || model.localPath
                                                if (p) fileOperator.openExplorerAtFileAsync(p)
                                            }
                                        }

                                        LightToolTip {
                                            visible: historyOpenFolderArea.containsMouse
                                            tip: parent.canOpenFolder
                                                 ? qsTr("pccut_task_queue_action_open_folder")
                                                 : qsTr("pccut_task_queue_local_file_lost")
                                        }
                                    }

                                    // 上传记录暂不支持打开云文件
                                    Image {
                                        anchors.verticalCenter: parent.verticalCenter
                                        source: historyOpenCloudArea.containsMouse
                                                ? "qrc:/icons/icon_open_cloud_file_hover.svg"
                                                : "qrc:/icons/icon_open_cloud_file.svg"
                                        sourceSize: Qt.size(20, 20)
                                        visible: false

                                        MouseArea {
                                            id: historyOpenCloudArea
                                            objectName: "taskQueueHistoryLocateBtn_" + index
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                taskQueuePopup.navigateToCloudAlbumAsset(model.fileName);
                                                taskQueuePopup.close();
                                            }
                                        }

                                        LightToolTip {
                                            visible: historyOpenCloudArea.containsMouse
                                            tip: qsTr("pccut_task_queue_action_open_cloud")
                                        }
                                    }

                                    // 上传/下载失败：重试按钮
                                    Image {
                                        anchors.verticalCenter: parent.verticalCenter
                                        source: historyRetryArea.containsMouse
                                                ? "qrc:/icons/icon_export_retry_hover.svg"
                                                : "qrc:/icons/icon_export_retry.svg"
                                        sourceSize: Qt.size(20, 20)
                                        visible: vm.isTransferModel
                                                 && model.fileStatus === 3

                                        MouseArea {
                                            id: historyRetryArea
                                            objectName: "taskQueueHistoryRetryBtn_" + index
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                CloudAlbumTransferModel.retryTask(model.taskId)
                                            }
                                        }

                                        LightToolTip {
                                            visible: historyRetryArea.containsMouse
                                            tip: qsTr("pccut_task_queue_action_retry")
                                        }
                                    }

                                    // 删除按钮（所有队列通用）
                                    Image {
                                        anchors.verticalCenter: parent.verticalCenter
                                        source: historyCancelArea.containsMouse
                                                ? "qrc:/icons/icon_export_task_delete_hover.svg"
                                                : "qrc:/icons/icon_export_task_delete.svg"
                                        sourceSize: Qt.size(20, 20)

                                        MouseArea {
                                            id: historyCancelArea
                                            objectName: "taskQueueHistoryDeleteBtn_" + index
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (vm.isExportModel) {
                                                    vm.exportTabViewModel.deleteByDraftPath(model.draftPath, false)
                                                } else if (vm.isTransferModel) {
                                                    // 已完成的下载任务：本地文件已丢失直接删除，否则弹窗确认
                                                    if (vm.currentNavIndex === 2 && model.fileStatus === 4 && !isLocalFileLost) {
                                                        taskDeleteConfirmPopup.showForTask(model.taskId);
                                                    } else {
                                                        CloudAlbumTransferModel.removeTask(model.taskId);
                                                    }
                                                }
                                            }
                                        }

                                        LightToolTip {
                                            visible: historyCancelArea.containsMouse
                                            tip: qsTr("pccut_task_queue_action_delete")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // 空状态
                Item {
                    visible: historyListView.count === 0
                    width: taskQueuePopup.emptyStateWidth
                    height: taskQueuePopup.emptyStateHeight
                    x: (parent.width - parent.rightMargin - width) / 2
                    anchors.top: parent.top
                    anchors.topMargin: taskQueuePopup.emptyStateTopMargin

                    Column {
                        anchors.centerIn: parent
                        spacing: 12

                        Image {
                            anchors.horizontalCenter: parent.horizontalCenter
                            source: "qrc:/icons/icon_empty_state.svg"
                            sourceSize: Qt.size(80, 56)
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: vm.emptyText
                            font.pixelSize: 12
                            color: Colors.color_444444
                        }
                    }
                }
            }
        }
    }

    Connections {
        target: CloudAlbumTransferModel
        function onDownloadDiskSpaceInsufficient() {
            if (taskQueuePopup.visible && !downloadDiskSpacePopup.opened) {
                downloadDiskSpacePopup.open()
            }
        }
    }

    ConfirmPopup {
        id: downloadDiskSpacePopup
        objectName: 'taskQueueDownloadDiskSpacePopup'
        parent: Overlay.overlay
        onlyOneBtn: true
        title: qsTr('pccut_cloud_album_err_disk_full')
        text: qsTr('pccut_device_batch_download_low_storage')
        leftButtonText: qsTr('pccut_common_text_got_it')
    }

    // 上传/下载和导出记录删除确认弹窗；活跃导出取消也复用该弹窗。
    TaskDeleteConfirmPopup {
        id: taskDeleteConfirmPopup
        parent: Overlay.overlay

        onConfirmDeleteTask: function(taskId, deleteFile) {
            CloudAlbumTransferModel.removeTask(taskId, deleteFile);
        }

        onConfirmClearAll: function(transferType, deleteFiles) {
            CloudAlbumTransferModel.clearCompleted(transferType, deleteFiles);
            vm.clearChecked()
        }

        onConfirmBatchRemove: function(taskIds, deleteFiles) {
            CloudAlbumTransferModel.removeTaskBatch(taskIds, deleteFiles)
            vm.clearChecked()
        }

        onConfirmDeleteExport: function(draftPath, deleteFile) {
            vm.exportTabViewModel.deleteByDraftPath(draftPath, deleteFile)
        }

        onConfirmClearAllExports: function(deleteFiles) {
            if (!vm.exportTabViewModel) return
            if (deleteFiles) {
                // clearExportSuccessList 不删文件，需逐条调用 deleteByDraftPath(path, true)
                var count = vm.exportTabViewModel.exportSuccessListCount
                var paths = []
                for (var i = 0; i < count; i++) {
                    var item = vm.exportTabViewModel.exportSuccessList[i]
                    if (item && item.draftPath) paths.push(item.draftPath)
                }
                for (var j = 0; j < paths.length; j++) {
                    vm.exportTabViewModel.deleteByDraftPath(paths[j], true)
                }
            } else {
                vm.exportTabViewModel.clearExportSuccessList()
            }
            vm.clearChecked()
        }

        onConfirmBatchDeleteExports: function(draftPaths, deleteFiles) {
            for (var i = 0; i < draftPaths.length; i++) {
                vm.exportTabViewModel.deleteByDraftPath(draftPaths[i], deleteFiles)
            }
            vm.clearChecked()
        }
    }

    // ViewModel 信号转发 → QML 层
    Connections {
        target: vm
        function onNavigateToCloudAlbumAsset(fileName) {
            taskQueuePopup.navigateToCloudAlbumAsset(fileName)
        }
        function onConfirmClearDownloadHistory(ids) {
            taskDeleteConfirmPopup.showForBatchRemove(ids)
        }
        function onConfirmClearAllDownloads(type) {
            taskDeleteConfirmPopup.showForClearAll(type)
        }
        function onConfirmBatchDeleteExports(paths) {
            taskDeleteConfirmPopup.showForBatchExports(paths)
        }
        function onConfirmClearAllExports() {
            taskDeleteConfirmPopup.showForClearAllExports()
        }
    }

    Connections {
        target: taskDeleteConfirmPopup
        function onConfirmClearActive() {
            vm.cancelActiveAll()
        }
    }

    onAboutToShow: {
        vm.onPopupOpened()
    }

    onOpened: {
        isClosedOrDestruction = true
        ShortcutObserver.disableAllShortcut(true)
        globalSignal.addPopupQuantity()
        Qt.callLater(function() {
            rootContent.forceActiveFocus()
        })
    }

    onClosed: {
        if (isClosedOrDestruction) {
            ShortcutObserver.disableAllShortcut(false)
            globalSignal.reducePopupQuantity()
            isClosedOrDestruction = false
        }
        vm.onPopupClosed()
    }

    Component.onDestruction: {
        if (isClosedOrDestruction) {
            ShortcutObserver.disableAllShortcut(false)
            globalSignal.reducePopupQuantity()
            isClosedOrDestruction = false
        }
    }
}
