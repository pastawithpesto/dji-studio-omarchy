import QtQuick 2.15
import QtQuick.Controls
import Config 1.0
import app_qrc 1.0

/**
 * Description: 固定宽度的图标+文字按钮，icon 和 text 间距固定，左右 padding 自动均分（弹簧效果）
 * Use case: 适用于需要固定宽度、内容居中的按钮场景
 */
Button {
    id: btn

    // ========== 尺寸配置 ==========
    property int fixedWidth: 140
    property int fixedHeight: 44

    // ========== 图标配置 ==========
    property string iconPathNormal: ""
    property string iconPathHover: iconPathNormal

    property string iconPath: hovered ? iconPathHover : iconPathNormal

    property size iconSize: Qt.size(20, 20)

    // ========== 文字配置 ==========
    property string title: ""
    property int titleFontSize: 16
    property int titleFontWeight: Font.Medium

    property color titleColorNormal: Colors.color_FFFFFF
    property color titleColorHover: titleColorNormal

    property color titleColor: hovered ? titleColorHover : titleColorNormal

    // ========== 布局配置 ==========
    property int internalSpacing: 4  // icon 和 text 固定间距

    // ========== 背景配置 ==========
    property Component customBackground: null  // 自定义背景组件（优先级最高）

    property color backgroundColorNormal: Colors.color_262728
    property color backgroundColorHover: backgroundColorNormal

    property color backgroundColor: hovered ? backgroundColorHover : backgroundColorNormal

    property int radius: RadiusConfig.radius_4_88

    property real borderWidth: 0
    property color borderColor: Colors.color_transparent

    // ========== 交互配置 ==========
    property int hoveredCursor: Qt.ArrowCursor

    // ========== 自定义信号 ==========
    signal customClicked()

    // ========== 按钮设置 ==========
    width: fixedWidth
    height: fixedHeight
    hoverEnabled: true
    focusPolicy: Qt.NoFocus

    leftPadding: 0
    rightPadding: 0
    topPadding: 0
    bottomPadding: 0

    // ========== ToolTip ==========
    LightToolTip {
        visible: hovered && titleText.implicitWidth > titleText.width
        tip: title
        z: 200
    }

    // ========== 背景 ==========
    background: Loader {
        anchors.fill: parent
        sourceComponent: btn.customBackground !== null ? btn.customBackground : defaultBackground

        Component {
            id: defaultBackground
            Rectangle {
                radius: btn.radius
                color: backgroundColor
                border.width: borderWidth
                border.color: borderColor
                antialiasing: true

                MouseArea {
                    anchors.fill: parent
                    cursorShape: hoveredCursor
                }
            }
        }
    }

    // ========== 内容区域 ==========
    // Row 居中，实现左右 padding 自动均分的弹簧效果
    contentItem: Item {
        Row {
            anchors.centerIn: parent  // 关键：整个 Row 在按钮中居中，实现弹簧效果
            spacing: internalSpacing

            Image {
                id: icon
                visible: iconPath !== ""
                source: iconPath
                sourceSize: iconSize
                anchors.verticalCenter: parent.verticalCenter
                asynchronous: true
            }

            Text {
                id: titleText
                text: title
                font.pixelSize: titleFontSize
                font.weight: titleFontWeight
                color: titleColor
                anchors.verticalCenter: parent.verticalCenter
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignLeft
                clip: true

                // 限制文本最大宽度，避免超出按钮
                width: Math.min(implicitWidth, fixedWidth - (icon.visible ? icon.width + internalSpacing : 0) - 16)
                elide: Text.ElideRight
            }
        }
    }

    // ========== 事件处理 ==========
    onClicked: {
        customClicked()
    }
}
