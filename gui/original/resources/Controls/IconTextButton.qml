import QtQuick 2.15
import QtQuick.Controls
import Config 1.0
import Qt5Compat.GraphicalEffects
import QtQuick.Layouts 1.15
import app_qrc 1.0

/**
 * Description :实现一个图片+文字的按钮
 * Note: 可通过padding属性控制内边距，并且会自适应调整大小。当设置了固定尺寸时，才能触发文本省略
 */

Button {
    id: btn
    property string title
    property int imageRectWidth: 20
    property int imageRectHeight: 20
    property bool isTextOnly: false
    property int omitPolicy: Text.ElideRight
    property int preferredWidth: 200
    property int textMinimumWidth: 0    // 设置最小宽度为200像素
    property int textMaximumWidth: 0
    property bool usePreferredWidth: false  //处于layout控件中的Text如果不指定Layout.preferredWidth属性会导致elide失效，考虑到用到这个组件的地方很多，所以加上这个属性避免影响现有代码
    property int hoveredCursor: Qt.ArrowCursor

    // 设置此属性是为了屏蔽button的默认行为，该行为导致连续点击button时checked会在true和false值之间切换
    property bool manualChecked: false

    // 是否对按下敏感，有时按钮不需要处理按下状态
    property bool presseable: true
    property int horPadding: 10

    leftPadding: 0 
    rightPadding: 0
    topPadding: 0
    bottomPadding: 0
    hoverEnabled: true
    property int internalSpacing: 10
    property int titleFontSize: 12
    property int titleFontWeight: Font.Medium
    property real title1Width: title1.width

    property real textImplicitWidth: title1.visible ? title1.implicitWidth : title2.implicitWidth
    property real buttonContentImplicitWidth: textImplicitWidth + imageRectWidth + internalSpacing

    property color titleColorNormal: Colors.color_FFFFFF
    property color titleColorPressed: titleColorNormal
    property color titleColorChecked: titleColorPressed
    property color titleColorHover: titleColorPressed
    property color titleColorDisable: titleColorNormal
    property color titleColorFocus: titleColorPressed
    property alias title1: title1
    property color titleColor: {
        if(!enabled){
            return titleColorDisable
        }
        if(presseable && pressed){
            return titleColorPressed
        }
        if(checked || manualChecked){
            return titleColorChecked
        }
        if (focus) {
            return titleColorFocus
        }
        if(hovered){
            return titleColorHover
        }
        return titleColorNormal
    }

    property color backgroundColorNormal: Colors.color_262728
    property color backgroundColorPressed: backgroundColorNormal
    property color backgroundColorChecked: backgroundColorPressed
    property color backgroundColorHover: backgroundColorPressed
    property color backgroundColorDisable: backgroundColorNormal
    property color backgroundColorFocus: backgroundColorPressed

    property color backgroundColor: {
        if(!enabled){
            return backgroundColorDisable
        }
        if(presseable && pressed){
            return backgroundColorPressed
        }
        if(checked || manualChecked){
            return backgroundColorChecked
        }
        if (focus) {
            return backgroundColorFocus
        }
        if(hovered){
            return backgroundColorHover
        }
        return backgroundColorNormal
    }

    property string iconPathNormal: ""
    property string iconPathPressed: iconPathNormal
    property string iconPathChecked: iconPathNormal
    property string iconPathHover: iconPathNormal
    property string iconPathDisable: iconPathNormal
    property string iconPathFocus: iconPathNormal

    property string iconPath: {
        if(!enabled){
            return iconPathDisable
        }
        if(presseable && pressed){
            return iconPathPressed
        }
        if(checked || manualChecked){
            return iconPathChecked
        }
        if (focus) {
            return iconPathFocus
        }
        if(hovered){
            return iconPathHover
        }
        return iconPathNormal
    }

    property size iconSizeNormal: Qt.size(imageRectWidth,imageRectHeight)
    property size iconSizePressed: iconSizeNormal
    property size iconSizeChecked: iconSizeNormal
    property size iconSizeHover: iconSizeNormal
    property size iconSizeDisable: iconSizeNormal
    property size iconSizeFocus: iconSizeNormal

    property size iconSize: {
        if(!enabled){
            return iconSizeDisable
        }
        if(pressed){
            return iconSizePressed
        }
        if(checked || manualChecked){
            return iconSizeChecked
        }
        if (focus) {
            return iconSizeFocus
        }
        if(hovered){
            return iconSizeHover
        }
        return iconSizeNormal
    }

    property int alignment: Qt.AlignLeft

    property int radius: RadiusConfig.radius_4_88

    property real borderWidth: 0
    property color borderColor: Colors.color_transparent

    signal customClicked()
    signal customCompleted()
    signal customDestruction()
    signal customEntered()
    signal customExited()

    focusPolicy: Qt.NoFocus

    LightToolTip {
        visible: hovered && ((title1.visible && title1.implicitWidth > title1.width) || title2.visible && title2.implicitWidth > title2.width)
        tip: title
        z: 200
    }

    background: Rectangle {
        radius: btn.radius
        color: backgroundColor
        border.width: borderWidth
        border.color: borderColor
        MouseArea {
            anchors.fill: parent
            cursorShape: hoveredCursor
        }
    }

    contentItem: RowLayout{
        id: layout
        spacing: 0
        Rectangle {
            visible: Qt.AlignHCenter === alignment
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Colors.transparent
        }
        RowLayout {
            Layout.alignment: Qt.AlignCenter
            Layout.maximumWidth: preferredWidth - horPadding*2
            spacing:0
            Rectangle {
                id: imageRectangle
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: imageRectWidth
                height: imageRectHeight
                color: Colors.transparent
                visible: !isTextOnly
                Image {
                    anchors.centerIn: parent
                    id: image
                    source: iconPath
                    sourceSize: iconSize
                    visible: !isTextOnly
                }
            }
            Rectangle {
                id: spacingRect
                visible: !isTextOnly
                Layout.preferredWidth: internalSpacing
                Layout.fillHeight: true
                color: Colors.transparent
            }

            Text{
                id: title1
                text: title
                color: titleColor
                verticalAlignment: Qt.AlignVCenter
                font.pixelSize: titleFontSize
                font.weight: titleFontWeight
                visible: Qt.AlignLeft === alignment
                clip: true
                Layout.fillHeight: true
                Layout.fillWidth: true
                elide: omitPolicy
                horizontalAlignment: isTextOnly?Text.AlignHCenter:Text.AlignLeft
            }

            Text{
                id: title2
                text: title
                color: titleColor
                verticalAlignment: Qt.AlignVCenter
                font.pixelSize: titleFontSize
                font.weight: titleFontWeight
                visible: Qt.AlignHCenter === alignment
                clip: true
                Layout.fillHeight: true
                Layout.fillWidth: true
                horizontalAlignment: isTextOnly?Text.AlignHCenter:Text.AlignLeft
                elide: omitPolicy
            }
        }

        Rectangle {
            visible: Qt.AlignHCenter === alignment
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Colors.transparent
        }
    }
    onClicked: {
        customClicked()
    }

    Component.onCompleted: {
        customCompleted()
    }

    Component.onDestruction: {
        customDestruction()
    }
}
