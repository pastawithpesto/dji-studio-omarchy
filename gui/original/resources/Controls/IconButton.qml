import QtQuick 2.15
import Config 1.0
import Controls 1.0
import QtQuick.Controls

Item {
    id: root
    height: 24
    width: 24
    radius: 4
    iconMargins: 2
    property real disableOpacity:0.5
    // 鼠标悬停的提示文案
    property var hoverTextFunc: function() { return "" }
    property int cursorShape: Qt.ArrowCursor // 鼠标光标的形状
    property bool useNormalBgColor: false // 是否使用单一背景色
    // 状态属性
    property bool disabled: false // 是否禁用
    property bool hovered: mouseArea.containsMouse // 是否悬停
    property bool isHoverEnabled: true
    property bool pressed: mouseArea.pressed // 是否按下

    // 颜色属性
    property color normalColor: Colors.color_transparent // 正常状态下的颜色
    property color hoverColor: Colors.color_333333 // 悬停状态下的颜色
    property color pressedColor: Colors.color_141414 // 按下状态下的颜色
    property color disableColor: Colors.color_transparent // 禁用状态下的颜色
    property color focusColor: Colors.color_transparent // foucs 状态下的颜色

    // 图标源属性
    property string iconSource: "" // 正常状态下的图标源
    property string hoverIconSource: iconSource // 悬停状态下的图标源
    property string pressedIconSource: iconSource // 按下状态下的图标源
    property string disabledIconSource: iconSource // 禁用状态下的图标源

    // 布局和外观属性
    property alias radius: background.radius // 背景圆角半径
    property alias iconMargins: icon.anchors.margins // 图标边距
    property real iconHeight: -1 // 图标的高度
    property real iconWidth: -1 // 图标的宽度
    property bool iconAsynchronous: true // 图标是否异步加载
    // 多行tips文本
    property var tipLinesFunc: function() { return [] }

    // 用于外部控制 currentOpacity
    property bool externalOpacity: false
    // 自定义信号
    signal clicked
    property bool showToolTip: mouseArea.containsMouse && enabled
    onShowToolTipChanged: {
        refreshTips();
    }
    function refreshTips() {
        toolTipLoader.refreshTips();
        multiToolTipLoader.refreshTips();
    }
    // 动态属性，根据状态确定当前颜色
    property color currentColor: {
        if (disabled) {
            return disableColor
        }
        if (mouseArea.pressed) {
            return pressedColor
        }
        if (hovered) {
            return hoverColor
        }
        if (focus) {
            return focusColor;
        }

        return normalColor
    }

    // 动态属性，根据状态确定当前图标源
    property string currentIconSource: {
        if (disabled) {
            return disabledIconSource
        }
        if (mouseArea.pressed) {
            return pressedIconSource
        }
        if (hovered) {
            return hoverIconSource
        }
        return iconSource
    }

    property double currentOpacity: {
        if(externalOpacity) {
            return 1
        }

        if (disabled) {
            return disableOpacity
        }
        if (hovered) {
            return 1
        }
        return 0.9
    }
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: root.isHoverEnabled
        cursorShape: root.cursorShape
        preventStealing: true
        onClicked: {
            if (!disabled) {
                root.clicked()
            }
        }
        // 单行的 Tips
        Loader {
            id: toolTipLoader
            active: false
            anchors.fill:parent
            function refreshTips() {
                if (showToolTip) {
                    var txt = hoverTextFunc();
                    if (txt.length < 1) {
                        active = false;
                        return;
                    }
                    active = true;
                    item.tip = txt;
                    item.visible = true
                } else {
                    active = false;
                }
            }
            sourceComponent: LightToolTip {}
        }
        // 多文本展示的ToolTip
        Loader {
            id: multiToolTipLoader
            active: false
            anchors.fill:parent
            function refreshTips() {
                if (showToolTip) {
                    var lines = tipLinesFunc();
                    if (lines.length < 1) {
                        active = false;
                        return;
                    }
                    active = true;
                    item.lines = lines;
                    item.visible = true
                } else {
                    active = false;
                }
            }
            sourceComponent: MultilineToolTip {
                x: parent.x
                y: parent.y + parent.height + 2
            }
        }
    }

    // 背景矩形，颜色根据状态变化
    Rectangle {
        id: background
        anchors.fill: parent
        radius: root.radius
        color: useNormalBgColor ? normalColor : (currentColor !== undefined ? currentColor : normalColor)
    }

    // 图标，根据状态变化
    Image {
        id: icon
        opacity: currentOpacity
        anchors.centerIn: parent
        width: root.iconWidth > 0 ? root.iconWidth : (parent.width - root.iconMargins * 2)
        height: root.iconHeight > 0 ? root.iconHeight : (parent.height - root.iconMargins * 2)
        sourceSize: Qt.size(icon.width * 2, icon.height * 2)
        fillMode: Image.PreserveAspectFit // 保持纵横比
        source: currentIconSource !== "" ? currentIconSource : iconSource
        asynchronous: root.iconAsynchronous
    }
}
