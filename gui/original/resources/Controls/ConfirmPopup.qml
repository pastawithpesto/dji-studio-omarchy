import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.3
import QtQuick.Window 2.15
import Controls 1.0
import Config 1.0
import Qt5Compat.GraphicalEffects
import app_qrc 1.0

LightPopup {
    id: confirmPopup

    property int customTopMargin: 26
    property int customBottomMargin: 22
    property int customLeftMargin: 28
    property int customRightMargin: 28
    property int customTitleHeight : 56

    topPadding: customTopMargin
    bottomPadding: customBottomMargin
    leftPadding: customLeftMargin
    rightPadding: customRightMargin

    property alias title: titleLabel.text
    property alias text: textLabel.text

    // 以下 title 排版 alias 的默认值与原有写死样式完全一致，仅供长文案弹窗按需覆盖，
    // 不传就是老样子，既有调用方零影响。
    property alias titleFontSize: titleLabel.font.pixelSize
    property alias titleFontWeight: titleLabel.font.weight
    property alias titleLineHeight: titleLabel.lineHeight
    property alias titleHorizontalAlignment: titleLabel.horizontalAlignment
    // 供调用方按实际行数决定对齐（单行居中、多行左对齐）；长文案弹窗需要。
    // 注意用 implicitWidth 而不是 lineCount：lineCount 会随 horizontalAlignment
    // 引发的重排而更新，拿它反推对齐会形成绑定循环；implicitWidth 是「不折行时的
    // 自然宽度」，与对齐方式无关，超过实际宽度即说明文案需要折行。
    readonly property bool titleWrapped: titleLabel.implicitWidth > titleLabel.width
    property alias titleLineCount: titleLabel.lineCount
    // 非空时：hover 正文弹出完整文案，用于 title 被截断展示的场景。
    // 默认空 = 不启用，既有调用方不会凭空多出一个浮层。
    property string titleTooltip: ""

    property string leftButtonText: ""
    property alias leftButtonTextColor: leftButton.titleColorNormal
    property alias leftButtonBackgroundColor: leftButton.backgroundColorNormal
    property alias leftButtonBackgroundPressed: leftButton.backgroundColorPressed
    // 按钮 objectName 默认为空；需要 autotest 钩子的调用方显式传入（如 HomeView 的草稿重打开弹窗），
    // 避免在 ConfirmPopup 内硬依赖 actionableItemName 这个仅主 engine 才有的 context property
    property string leftButtonObjectName: ""

    property alias checkBox: checkBox
    property string checkBoxObjectName: ""

    property alias rightButtonText: rightButton.title
    property alias rightButtonTextColor: rightButton.titleColorNormal
    property alias rightButtonBackgroundColor: rightButton.backgroundColorNormal
    property string rightButtonObjectName: ""
    property alias loader: loader
    property bool isCheckBoxVisible: false
    property bool isChecked: false
    // 只展示一个按钮
    property bool onlyOneBtn: false
    property var popWidth: 248
    signal checkBoxClicked(bool checked)
    signal leftButtonClicked
    signal rightButtonClicked
    // 通过 parent 找当前所在 Window，避免硬依赖 Main.qml 专属的 lightWindow id，
    // 让 ConfirmPopup 在 PreviewPlayerWindow 等独立 QQmlEngine 下也能正常显示。
    readonly property var hostWindow: parent ? parent.Window.window : null
    width: hostWindow ? hostWindow.width : 0
    height: hostWindow ? hostWindow.height : 0
    needNoBorder: true
    dim: false
    // 之前写的是 Infinity 但是上面可能有 tips 所以他不能是最大的, 暂定是 100
    z: 100
    // 因为有些情况下popup没有close而直接被销毁了，可能导致onClosed方法未执行
    // 这个属性是为了防止在同时设置onClosed和onDestruction时方法重复执行
    property bool isClosedOrDestruction: false

    contentItem: Item{
        id:content
        MouseArea {
            anchors.fill: parent
            onClicked: {
                //closeSignal();
                //close();
            }
        }
        Rectangle {
            anchors.fill: contentLayout
            color: Colors.color_2F3032
            radius: 8
            clip: true
            border.width:1
            border.color:Colors.color_454649
        }
        Column {
            id: contentLayout
            spacing: 0
            //Layout.fillWidth: true
            anchors.centerIn: parent  // 直接居中
            width: popWidth
            Rectangle{
                width:parent.width
                height:24
                color: Colors.color_transparent
            }
            ColumnLayout {
                width: parent.width - 56  // 左右各减去 28
                anchors.horizontalCenter: parent.horizontalCenter
                Layout.minimumHeight: customTitleHeight
                spacing: 12              
                Text {
                    id: titleLabel
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    color: Colors.color_EEEEEE
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter

                    // 文案被截断时（titleTooltip 非空）hover 正文展示全文，
                    // 浮层本体见下方 titleTooltipBox。
                    HoverHandler {
                        id: titleHoverHandler
                        enabled: confirmPopup.titleTooltip !== ""
                        cursorShape: Qt.ArrowCursor
                    }
                }

                Text {
                    id: textLabel
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    wrapMode: Text.Wrap
                    lineHeight: 1 // 行高设为1.5倍
                    lineHeightMode: Text.ProportionalHeight // 使用比例模式
                    color: Colors.color_999999
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    visible: text !== ""
                }

            }
            Item {
                width: parent.width
                height: 20
                visible: onlyOneBtn
            }
            IconTextButton {
                // 单按钮模式复用 leftButtonObjectName，与下方双按钮分支保持一致，
                // 否则 onlyOneBtn 的弹窗无法被 autotest 通过 objectName 找到按钮
                objectName: confirmPopup.leftButtonObjectName
                Layout.alignment: Qt.AlignHCenter  // 水平居中
                height: 28
                leftPadding: 28
                rightPadding: 28
                alignment: Qt.AlignHCenter
                isTextOnly: true
                title: leftButtonText                
                titleColorNormal: ColorsConfig.color_FFFFFF_000000
                backgroundColorNormal: ColorsConfig.color_F22443_4DFFC9
                backgroundColorPressed: ColorsConfig.color_F44C65_4DFFC9
                anchors.horizontalCenter: parent.horizontalCenter

                onCustomClicked: {
                    close()
                    leftButtonClicked()
                }
                visible: rightButton.title.length === 0
            }

            Rectangle{
                width:parent.width
                height:12
                visible: isCheckBoxVisible
                color:Colors.color_transparent
            }
            CheckBox {
                id:checkBox
                objectName: confirmPopup.checkBoxObjectName
                text: qsTr("pccut_editing_assistant_remind_again")
                anchors.horizontalCenter: parent.horizontalCenter
                Layout.topMargin: 0
                visible: isCheckBoxVisible
                checked: isChecked
                verticalPadding: 1.5
                indicator: Rectangle {
                    implicitWidth: 14
                    implicitHeight: 14
                    anchors.left: checkBox.left
                    anchors.verticalCenter: parent.verticalCenter
                    color:  checkBox.checked ? ColorsConfig.color_brand : Colors.color_444444
                    radius: 4
                    Image {
                        id: icon
                        visible: checkBox.checked
                        anchors.fill: parent
                        source: "qrc:/app_qrc/icons/icon_checkbox_check.svg"
                        sourceSize: Qt.size(parent.width, parent.height)
                    }
                }
                onClicked:{
                    isChecked = checked
                    checkBoxClicked(checked)
                }
                contentItem: Text {
                    text: checkBox.text
                    font.pixelSize: 12
                    color: Colors.color_EEEEEE
                    verticalAlignment: Text.AlignVCenter
                    leftPadding: checkBox.indicator.width + 2
                }
            }
            Loader {
                id: loader
                width: parent.width - 56  // 左右各减去 28
                x: 28
                sourceComponent: null
            }
            Rectangle{
                width:parent.width
                height:20
                color:Colors.color_transparent
                visible: !onlyOneBtn
            }
            RowLayout {
                spacing: 16
                width: 88 * 2 + 16
                anchors.horizontalCenter: parent.horizontalCenter
                visible: rightButton.title.length !== 0
                Layout.topMargin: checkBox.visible ? 4 : 0
                Layout.alignment: Qt.AlignHCenter
                IconTextButton {
                    id: leftButton
                    objectName: confirmPopup.leftButtonObjectName
                    Layout.preferredHeight: 28
                    Layout.preferredWidth: 88
                    alignment: Qt.AlignHCenter
                    isTextOnly: true
                    title: leftButtonText
                    titleColorNormal: Colors.color_FFFFFF
                    backgroundColorNormal: Colors.color_68696D
                    backgroundColorHover: Colors.color_7A7B80
                    onCustomClicked: {
                        close()
                        leftButtonClicked()
                    }
                }
                IconTextButton {
                    id: rightButton
                    objectName: confirmPopup.rightButtonObjectName
                    Layout.preferredHeight: 28
                    Layout.preferredWidth: 88
                    alignment: Qt.AlignHCenter
                    isTextOnly: true
                    titleColorNormal: ColorsConfig.color_FFFFFF_000000
                    backgroundColorNormal: ColorsConfig.color_F22443_4DFFC9
                    backgroundColorPressed: ColorsConfig.color_F44C65_6DFFD3

                    onCustomClicked: {
                        close()
                        rightButtonClicked()
                    }
                }
            }
            Rectangle{
                width:parent.width
                height:20
                color:Colors.color_transparent
            }
        }

        // 正文被截断时（titleTooltip 非空）hover 弹出的全文浮层。
        // 不用 LightToolTip：它是 Popup，嵌套在本弹窗（同样是 Popup）内部时坐标会
        // 脱离弹窗、跑到窗口角落去。这里的浮层和弹窗主体处于同一坐标系，位置完全可控。
        // 挂在弹窗正下方而不是压在正文上，是为了不遮住鼠标下的文字——一旦遮住，
        // HoverHandler 会立刻失去 hover，浮层随即消失，形成显示/隐藏的抖动。
        Rectangle {
            id: titleTooltipBox
            objectName: 'confirmPopupTitleTooltip'
            visible: confirmPopup.titleTooltip !== "" && titleHoverHandler.hovered
            z: 200
            anchors.top: contentLayout.bottom
            anchors.topMargin: 8
            anchors.horizontalCenter: contentLayout.horizontalCenter
            width: contentLayout.width
            // 内容高度优先，但绝不越过弹窗下方的可用空间，否则会顶出窗口
            height: Math.min(titleTooltipLabel.implicitHeight + 16,
                             Math.max(0, (content.height - contentLayout.height) / 2 - 16))
            clip: true
            radius: 4
            color: Colors.color_141414_85
            border.width: 0.5
            border.color: Colors.color_444444

            Text {
                id: titleTooltipLabel
                anchors.fill: parent
                anchors.margins: 8
                wrapMode: Text.Wrap
                lineHeight: 1.4
                font.pixelSize: 11
                color: Colors.color_EEEEEE
                text: confirmPopup.titleTooltip
            }
        }
    }
    

    onOpened: {
        if (!hostWindow) {
            close()
            return
        }
        isClosedOrDestruction = true
        ShortcutObserver.disableAllShortcut(true)
        globalSignal.addPopupQuantity()
    }
    onClosed: {
        if (isClosedOrDestruction) {
            ShortcutObserver.disableAllShortcut(false)
            globalSignal.reducePopupQuantity()
            isClosedOrDestruction = false
        }
    }


    Component.onDestruction: {
        if (isClosedOrDestruction) {
            ShortcutObserver.disableAllShortcut(false)
            globalSignal.reducePopupQuantity()
            isClosedOrDestruction = false
        }
    }

    function closePopup() {
        destroy()
    }
}
