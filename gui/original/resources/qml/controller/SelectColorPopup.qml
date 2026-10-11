import QtQuick 2.15
import QtQuick.Layouts 1.3
import Controls 1.0
import Config 1.0
import LightRectangle 1.0
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import ColorListModel 1.0

/**
 * @author hongbin.shi
 * @desc 颜色选择器
 * @create_date 2025-12-12
 */
Popup {
    id: colorPopup
    width: 256
    height: 345
    padding: 0

    // 公共属性
    property color currentColor
    property int colorR: 255
    property int colorG: 255
    property int colorB: 255
    property string colorHex: "#FF0000"
    property real hue: 0.0        // 色相 0-1
    property real saturation: 1.0 // 饱和度 0-1
    property real brightness: 1.0 // 亮度 0-1
    property bool bShowRGB: true  //
    property int presetColorMaxCount: 300 + 84    //自定义预设颜色最大数量 300， 软件自带 84个
    property bool bOpenColorTypePopUp: false

    property bool bDragSvSelect: false
    // undo
    property color oldColor: Colors.color_FFFFFF

    // 信号
    signal colorSelected(color finalColor)
    signal addUndoColor(color oldcolor, color newcolor)

    onClosed: {
        if(bOpenColorTypePopUp){
            colorTypePopup.close();
            bOpenColorTypePopUp = false;
        }

        if(bShowRGB){
            //颜色分量编辑框内容为空时恢复原来的值
            if (colorREdit.text.length <= 0) {
                var t = colorR;
                colorR = 0;
                colorR = t;
                return;
            }
            if (colorGEdit.text.length <= 0) {
                var t = colorG;
                colorG = 0;
                colorG = t;
                return;
            }
            if (colorBEdit.text.length <= 0) {
                var t = colorB;
                colorB = 0;
                colorB = t;
                return;
            }
           var r = parseInt(colorREdit.text);
           var g = parseInt(colorGEdit.text);
           var b = parseInt(colorBEdit.text);
           oldColor = currentColor;
           currentColor = Qt.rgba(r/255.0, g/255.0, b/255.0, 1)
           if(currentColor !== oldColor){
               //发送颜色改变信号
               colorPopup.colorSelected(currentColor);
               colorPopup.addUndoColor(oldColor, currentColor);
           }
       }
       else{
           if (colorHexEdit.text.length <= 0) {
               var t = colorHex;
               colorHex = "";
               colorHex = t;
               return;
           }

           var tempColorHex = colorHexEdit.text.toUpperCase()
           oldColor = currentColor;
           currentColor = parseHex(tempColorHex);
           if(oldColor !== currentColor)
               colorPopup.addUndoColor(oldColor, currentColor);

       }
    }

    onCurrentColorChanged: {
        var r = Qt.color(currentColor).r * 255
        var g = Qt.color(currentColor).g * 255
        var b = Qt.color(currentColor).b * 255
        var a = 255
        //console.log("----shihb onCurrentColorChanged R:", r, "G:", g, "B:", b, "A:", a)
        colorR = r;
        colorG = g;
        colorB = b;
        colorHex = colorToHex(currentColor)
        if(!bDragSvSelect){
            updateHSV(currentColor);
        }
        //发送颜色改变信号
        colorPopup.colorSelected(currentColor);
    }

    // 设置颜色
    function updateHSV() {
        var color = Qt.color(currentColor);
        var red = color.r;
        var green = color.g;
        var blue = color.b;

        // RGB转HSV
        var max = Math.max(red, green, blue);
        var min = Math.min(red, green, blue);
        var h, s, v = max;

        var d = max - min;
        s = max === 0 ? 0 : d / max;

        if (max === min) {
            h = 0;
        } else {
            switch(max) {
                case red: h = (green - blue) / d + (green < blue ? 6 : 0); break;
                case green: h = (blue - red) / d + 2; break;
                case blue: h = (red - green) / d + 4; break;
            }
            h /= 6;
        }

        colorPopup.hue = h;         //色相
        colorPopup.saturation = s;  //饱和度
        colorPopup.brightness = v;  //亮度
    }

    function intToColor(colorInt) {
        // ARGB 格式：0xAARRGGBB
        var a = 255 //(colorInt >> 24) & 0xFF
        var r = (colorInt >> 16) & 0xFF
        var g = (colorInt >> 8) & 0xFF
        var b = colorInt & 0xFF

        // 转换为 Qt.rgba()
        return Qt.rgba(r / 255, g / 255, b / 255, a / 255)
    }
    function colorToARGB(color) {
        var c = Qt.color(color)
        var a = Math.round(c.a * 255)
        var r = Math.round(c.r * 255)
        var g = Math.round(c.g * 255)
        var b = Math.round(c.b * 255)

        // ARGB 格式：0xAARRGGBB
        return (a << 24) | (r << 16) | (g << 8) | b
    }
    function colorToHex(color) {
        var c = Qt.color(color)
        var r = Math.round(c.r * 255).toString(16).padStart(2, '0').toUpperCase()
        var g = Math.round(c.g * 255).toString(16).padStart(2, '0').toUpperCase()
        var b = Math.round(c.b * 255).toString(16).padStart(2, '0').toUpperCase()
        //return '#' + r + g + b
        return '' + r + g + b
    }
    // 将单个十六进制字符扩展为两个字符，然后转换为十进制
    // 例如: expandHex('F') -> 255, expandHex('0') -> 0, expandHex('8') -> 136
    function expandHex(hexChar) {
        var expanded = hexChar + hexChar
        return parseInt(expanded, 16)
    }

    // 解析十六进制字符串，返回包含分量的对象
    function parseHex(hexString) {
        if (!hexString) return null

        var hex = hexString.trim().toUpperCase()

        // 移除 # 前缀
        if (hex.startsWith('#')) {
            hex = hex.substring(1)
        }

        // 验证有效性
        if (!/^[0-9A-F]+$/.test(hex)) {
            return null
        }

        var length = hex.length
        if(length < 6 && length !== 3){
            // 补上缺失的字符
            hex = hex.padEnd(6, '0')
            length = 6
        }
        var r, g, b, a = 1.0

        switch (length) {
        case 3: // #RGB
            r = expandHex(hex[0]) / 255
            g = expandHex(hex[1]) / 255
            b = expandHex(hex[2]) / 255
            break

        case 6: // #RRGGBB
            r = parseInt(hex.substr(0, 2), 16) / 255
            g = parseInt(hex.substr(2, 2), 16) / 255
            b = parseInt(hex.substr(4, 2), 16) / 255
            break

        default:
            return null
        }

        return { r: r, g: g, b: b, a: a }
    }

    function getColorAt(position) {
        if (position < 0.2) {
            return Qt.hsva(position * 5, 1, 1, 1) // 红到黄
        } else if (position < 0.4) {
            return Qt.hsva(0.2 + (position-0.2)*5, 1, 1, 1) // 黄到绿
        } else if (position < 0.6) {
            return Qt.hsva(0.4 + (position-0.4)*5, 1, 1, 1) // 绿到青
        } else if (position < 0.8) {
            return Qt.hsva(0.6 + (position-0.6)*5, 1, 1, 1) // 青到蓝
        } else {
            return Qt.hsva(0.8 + (position-0.8)*5, 1, 1, 1) // 蓝到品红
        }
    }

    // HSV转RGB函数
    function hsvToRgb(h, s, v) {
        var r, g, b, i, f, p, q, t;
        i = Math.floor(h * 6);
        f = h * 6 - i;
        p = v * (1 - s);
        q = v * (1 - f * s);
        t = v * (1 - (1 - f) * s);

        switch(i % 6) {
            case 0: r = v; g = t; b = p; break;
            case 1: r = q; g = v; b = p; break;
            case 2: r = p; g = v; b = t; break;
            case 3: r = p; g = q; b = v; break;
            case 4: r = t; g = p; b = v; break;
            case 5: r = v; g = p; b = q; break;
        }
        return Qt.rgba(r, g, b, 1.0);
    }
    // 更新颜色（从HSV）
    function updateColorFromHSV() {
        var newColor = hsvToRgb(colorPopup.hue, colorPopup.saturation, colorPopup.brightness);
        if (colorPopup.currentColor.toString() !== newColor.toString()) {
            colorPopup.currentColor = newColor;
            colorPopup.colorSelected(newColor);
        }
    }

    background: Rectangle {
        color: Colors.color_2F3032
        radius: 4
        // 阴影效果
        layer.enabled: true
        layer.effect: DropShadow {
            transparentBorder: true
            horizontalOffset: 0
            verticalOffset: 0
            radius: 10
            samples: 17
            color: Colors.color_000000_50
        }
    }

    ColorListModel {
       id: colorModel
    }

    MouseArea {
        anchors.fill: parent
        onClicked: (mouse)=> {
            forceActiveFocus()
        }
    }

    // 1. 饱和度和亮度面板
    Rectangle {
        id: svPanel
        //width: 232
        height: 130
        radius: 4
        anchors {
            top: parent.top; topMargin: 16
            left: parent.left; leftMargin: 12
            right: parent.right; rightMargin: 12
        }

        // 基础色
        Rectangle {
            anchors.fill: parent
            color: hsvToRgb(colorPopup.hue, 1.0, 1.0)
            radius: 4
        }

        // 亮度渐变（从左到右）
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.rgba(21,21,21,1) }
                GradientStop { position: 1.0; color: Qt.rgba(230,3,3,0) }
            }
            radius: 2
        }
        // 饱和度渐变（从上到下）
        Rectangle {
            anchors.fill: parent

            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: Qt.rgba(1,1,1,0) }
                //GradientStop { position: 1.0; color: Qt.rgba(1,1,1,0.5) }
                GradientStop { position: 1.0; color: Qt.rgba(0,0,0,1) }
            }
            radius: 2
        }

        // 选择点
        Rectangle {
            id: svSelector
            x: colorPopup.saturation * (parent.width - width)
            y: (1 - colorPopup.brightness) * (parent.height - height)
            width: 12
            height: 12
            radius: 6
            color: Colors.color_transparent
            border.width: 2
            border.color: Colors.color_FFFFFF

            // 外层阴影
            layer.enabled: true
            layer.effect: DropShadow {
                transparentBorder: true
                horizontalOffset: 0
                verticalOffset: 1
                radius: 2
                samples: 6
                color: Colors.color_000000_30
            }

            Rectangle {
                anchors.centerIn: parent
                width: 8
                height: 8
                radius: 4
                color: Colors.color_transparent
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: (mouse)=> {
                oldColor = currentColor;
                colorPopup.saturation = mouse.x / parent.width;
                colorPopup.brightness = 1 - (mouse.y / parent.height);
                updateColorFromHSV();
                bDragSvSelect = false;
            }
            onPositionChanged: (mouse)=> {
                if (pressed) {
                    bDragSvSelect = true;
                    colorPopup.saturation = Math.max(0, Math.min(1, mouse.x / parent.width));
                    colorPopup.brightness = 1 - Math.max(0, Math.min(1, mouse.y / parent.height));
                    updateColorFromHSV();
                }
            }
            onPressedChanged: {
                if (pressed) {
                    oldColor = currentColor;
                }
            }
            onReleased: {
                bDragSvSelect = false;
                colorPopup.addUndoColor(oldColor, currentColor);
            }
        }
    }

    // 2. 色相条选择器
    Rectangle {
        id: huePanel
        //width: 232
        height: 12
        radius: 5
        anchors{
            top: svPanel.bottom; topMargin: 12
            left: svPanel.left
            right: svPanel.right
        }

        // 色相渐变
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.00; color: "#FF0000" }  // 红
            GradientStop { position: 0.16; color: "#FFFF00" }  // 黄
            GradientStop { position: 0.33; color: "#00FF00" }  // 绿
            GradientStop { position: 0.50; color: "#00FFFF" }  // 青
            GradientStop { position: 0.66; color: "#0000FF" }  // 蓝
            GradientStop { position: 0.83; color: "#FF00FF" }  // 品红
            GradientStop { position: 1.00; color: "#FF0000" }  // 红
        }

        // 色相滑块
        Rectangle {
            id: hueSlider
            x: colorPopup.hue * (parent.width - width)
            y: -2
            width: 16
            height: 16
            radius: 8
            color: Colors.color_transparent
            border.width: 2
            border.color: Colors.color_FFFFFF

            Rectangle {
                anchors.centerIn: parent
                width: 10
                height: 10
                radius: 5
                color: Colors.color_transparent
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: (mouse)=> {
                colorPopup.hue = mouse.x / parent.width;
                updateColorFromHSV();
            }
            onPositionChanged: (mouse)=> {
                if (pressed) {
                    colorPopup.hue = Math.max(0, Math.min(1, mouse.x / parent.width));
                    updateColorFromHSV();
                }
            }
            onPressedChanged: {
                if (pressed) {
                    oldColor = currentColor;
                }
            }
            onReleased: {
                colorPopup.addUndoColor(oldColor, currentColor);
            }
        }
    }

    // 3. 颜色值设置
    Rectangle {
        id: inputRectangle
        height: 24
        radius: 4
        anchors{
            left: huePanel.left
            top: huePanel.bottom;topMargin: 14
            right: huePanel.right
        }
        color: Colors.color_transparent

        // RGB和16进制切换
        Rectangle {
            id: rgbOrHex
            width: 70; height: 24;
            color: Colors.color_454649
            anchors.top: parent.top
            anchors.left: parent.left
            radius: 4

            Text {
                id: colorStyle
                width: 48; height: 16
                text: bShowRGB ? "RGB" : "HEX"
                font.pixelSize: 12
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.topMargin: 4
                anchors.leftMargin: 8
                horizontalAlignment: Text.AlignLeft
                color: Colors.color_EEEEEE
            }


            Rectangle {
                id: colorStyleSelect
                width: 20; height: 20
                anchors{
                    right: parent.right; rightMargin: 4
                    top: parent.top; topMargin: 2
                }
                color: Colors.color_transparent
                Image{
                    id: colorBtn
                    anchors{
                        top: parent.top
                        left: parent.left
                    }
                    source:  colorTypePopup.visible ? "qrc:/icons/adjustment/icon_drop_down_menu_collapse.svg" : "qrc:/icons/adjustment/icon_drop_down_menu_expand.svg"
                    sourceSize: Qt.size(20, 20)
                    opacity: 1
                }
            }

            MouseArea {
                id: colorMouseArea
                anchors.fill: parent
                hoverEnabled: true
                onEntered: {
                    parent.color = Colors.color_56575B
                    bOpenColorTypePopUp = colorTypePopup.visible;
                }
                onExited: {
                    parent.color = Colors.color_454649
                }
                onClicked: {
                    var x = rgbOrHex.mapToItem(colorPopup.contentItem, 0, 0).x
                    var y = rgbOrHex.mapToItem(colorPopup.contentItem, 0, 0).y + rgbOrHex.height + 4
                    colorTypePopup.x = x
                    colorTypePopup.y = y
                    //colorTypePopup.open();
                    if(bOpenColorTypePopUp){
                        colorTypePopup.close();
                        bOpenColorTypePopUp = false;
                    }
                    else{
                        colorTypePopup.open();
                        bOpenColorTypePopUp = true;
                    }
                }
            }

            Connections {
                target: colorTypePopup
                function onSelectColorType(type) {
                    bShowRGB = type;
                }
            }
        }

        //RGB颜色值表示
        TextField {
            id: colorREdit
            width: (parent.width-rgbOrHex.width-12)/3
            height: 24
            anchors.left: rgbOrHex.right;
            anchors.top: rgbOrHex.top
            anchors.leftMargin: 4
            // 背景黑色
            background: Rectangle {
                color: Colors.color_1F2021
                radius: 4
            }
            color: Colors.color_EEEEEE
            selectionColor: Colors.color_EEEEEE
            selectedTextColor: Colors.color_1F2021
            font.pixelSize: 12
            horizontalAlignment: TextInput.AlignHCenter
            visible: bShowRGB
            text: colorR
            // 输入限制：只能输入数字
            validator: IntValidator {
                bottom: 0
                top: 255
            }
            Keys.onReturnPressed: {
                focus = false
            }
            Keys.onEscapePressed: {
                focus = false
            }
            onFocusChanged: {
                if (!focus) {
                    if (text.length <= 0) {
                        var t = colorR;
                        colorR = 0;
                        colorR = t;
                        return;
                    }
                    var r = parseInt(text);
                    if(r !== colorR){
                        oldColor = currentColor;
                        currentColor = Qt.rgba(r/255.0, colorG/255.0, colorB/255.0, 1)
                        colorPopup.addUndoColor(oldColor, currentColor);
                    }
                }
            }
        }
        TextField {
            id: colorGEdit
            width: (parent.width-rgbOrHex.width-12)/3
            height: 24
            anchors.left: colorREdit.right;
            anchors.top: colorREdit.top
            anchors.leftMargin: 4
            background: Rectangle {
                color: Colors.color_1F2021
                radius: 4
            }
            color: Colors.color_EEEEEE
            selectionColor: Colors.color_EEEEEE
            selectedTextColor: Colors.color_1F2021
            font.pixelSize: 12
            horizontalAlignment: TextInput.AlignHCenter
            visible: bShowRGB
            text: colorG
            validator: IntValidator {
                bottom: 0
                top: 255
            }
            Keys.onReturnPressed: {
                focus = false
            }
            Keys.onEscapePressed: {
                focus = false
            }
            onFocusChanged: {
                if (!focus) {
                    if (text.length <= 0) {
                        var t = colorG;
                        colorG = 0;
                        colorG = t;
                        return;
                    }
                    var g = parseInt(text);
                    if(g !== colorG){
                        oldColor = currentColor;
                        currentColor = Qt.rgba(colorR/255.0, g/255.0, colorB/255.0, 1)
                        colorPopup.addUndoColor(oldColor, currentColor);
                    }
                }
            }
        }
        TextField {
            id: colorBEdit
            width: (parent.width-rgbOrHex.width-12)/3
            height: 24
            anchors.top: rgbOrHex.top
            anchors.right: parent.right
            background: Rectangle {
                color: Colors.color_1F2021
                radius: 4
            }
            color: Colors.color_EEEEEE
            selectionColor: Colors.color_EEEEEE
            selectedTextColor: Colors.color_1F2021
            font.pixelSize: 12
            horizontalAlignment: TextInput.AlignHCenter
            visible: bShowRGB
            text: colorB
            validator: IntValidator {
                bottom: 0
                top: 255
            }
            Keys.onReturnPressed: {
                focus = false
            }
            Keys.onEscapePressed: {
                focus = false
            }
            Keys.onShortcutOverride: function(event) {
                if (event.key === Qt.Key_Enter) {
                    event.accepted = true // 阻止其他组件处理
                }
            }
            onFocusChanged: {
                if (!focus) {
                    if (text.length <= 0) {
                        var t = colorB;
                        colorB = 0;
                        colorB = t;
                        return;
                    }
                    var b = parseInt(text);
                    if(b !== colorB){
                        oldColor = currentColor;
                        currentColor = Qt.rgba(colorR/255.0, colorG/255.0, b/255.0, 1);
                        colorPopup.addUndoColor(oldColor, currentColor);
                    }
                }
            }
        }

        //HEX值表示
        TextField {
            id: colorHexEdit
            width: 158;height: 24
            anchors.left: rgbOrHex.right;
            anchors.top: rgbOrHex.top
            anchors.leftMargin: 4
            background: Rectangle {
                color: Colors.color_1F2021
                radius: 4
            }
            color: Colors.color_EEEEEE
            font.pixelSize: 12
            horizontalAlignment: TextInput.AlignLeft //TextInput.AlignHCenter
            leftPadding: 8
            topPadding: 4
            bottomPadding: 4
            visible: !bShowRGB
            text: colorHex
            selectionColor: Colors.color_EEEEEE
            selectedTextColor: Colors.color_1F2021
            onActiveFocusChanged: {
                if (activeFocus && text === "") {
                }
            }
            validator: RegularExpressionValidator {
                regularExpression: /^([A-Fa-f0-9]{6})$/
            }
            maximumLength: 6  // 6个字符
            // 监听焦点变化
            onFocusChanged: {
                if (!focus) {
                    if (text.length <= 0) {
                        var t = colorHex;
                        colorHex = "";
                        colorHex = t;
                        return;
                    }

                    colorHex = text.toUpperCase()
                    oldColor = currentColor;
                    currentColor = parseHex(colorHex);
                    // 可能会将不满6位的拓展，需要实时更新
                    colorHex = colorToHex(currentColor)
                    if(oldColor !== currentColor)
                        colorPopup.addUndoColor(oldColor, currentColor);
                }
            }
            // 按键事件
            Keys.onReturnPressed: {
                focus = false
            }
            Keys.onEscapePressed: {
                focus = false
            }
            Keys.onShortcutOverride: function(event) {
                if (event.key === Qt.Key_Enter) {
                    event.accepted = true // 阻止其他组件处理
                }
            }
        }
    }

    // 4. 分割线
    Rectangle {
        id: separatorLine
        width: 232
        height: 1
        color: Colors.color_454649
        border.color: Colors.color_454649
        border.width: 1
        anchors{
            left: inputRectangle.left
            top: inputRectangle.bottom; topMargin: 16
            right: inputRectangle.right
        }
    }

    // 5. 预设颜色
    ScrollView {
        id: colorScrollView
        //width: 232
        height: 88
        anchors{
            left: separatorLine.left
            top: separatorLine.bottom;topMargin: 16
            right: separatorLine.right
        }
        ScrollBar.vertical.policy: ScrollBar.AlwaysOff
        ScrollBar.horizontal.policy:ScrollBar.AlwaysOff

        contentItem: Flickable {
            boundsBehavior: Flickable.StopAtBounds  // 禁用回弹
            contentWidth: grid.width
            contentHeight: grid.height
            clip: true

            Grid {
                id: grid
                columns: (colorScrollView.width+6.5) / (20 + 6.5) //9
                width: parent.width
                columnSpacing: 6.5  // 列间距
                rowSpacing: 6     // 行间距

                property int itemWidth: 20 //(width - (columns - 1) * spacing) / columns
                property int itemHeight: 20

                Repeater {
                    model: colorModel
                    Rectangle {
                        width: grid.itemWidth
                        height: grid.itemHeight
                        // 判断是否为第一行第一列
                        property bool isFirstRowFirstColumn: {
                            var row = Math.floor(index / grid.columns)
                            var col = index % grid.columns
                            return row === 0 && col === 0
                        }
                        // 根据位置设置不同样式
                        color: {
                            if (isFirstRowFirstColumn) {
                                return Colors.color_454649
                            } else  {
                                return intToColor(colorvalue);
                            }
                        }
                        property int row: Math.floor(index / grid.columns)
                        property int col: index % grid.columns
                        radius: 2

                        // 特殊交互效果
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onEntered: {
                            }
                            onExited: {}
                            onClicked: (mouse)=> {
                                var curRow = parent.row;
                                var curCol = parent.col;
                                if (mouse.button === Qt.RightButton) {
                                    if(presetting){
                                        toast.showToastAtItem(qsTr("pccut_word_edit_font_toast_2"), colorPopup.contentItem)
                                    }else{
                                        colorContextMenuLoader.active = true
                                        colorContextMenuLoader.item.colorIndex = curRow * 9 + curCol;
                                        colorContextMenuLoader.item.popup()
                                    }
                                } else if (mouse.button === Qt.LeftButton){
                                    if (parent.isFirstRowFirstColumn) {
                                        if(colorModel.rowCount()> presetColorMaxCount){
                                            toast.showToast(qsTr("pccut_word_edit_font_toast_3"))
                                        }else{
                                            if(colorTypePopup.bRGB){
                                                var textR = colorREdit.text;
                                                var textG = colorGEdit.text;
                                                var textB = colorBEdit.text;
                                                var r, g, b;
                                                if (textR.length > 0) {
                                                    r = parseInt(textR);
                                                } else {
                                                    r = 0
                                                }
                                                if (textG.length > 0) {
                                                   g = parseInt(textG);
                                                } else {
                                                   g = 0
                                                }
                                                if (textB.length > 0) {
                                                   b = parseInt(textB);
                                                } else {
                                                   b = 0
                                                }
                                                currentColor = Qt.rgba(r / 255, g / 255, b / 255, 1.0)
                                            }else{
                                                var t = parseHex(colorHexEdit.text);
                                                if(t === null){
                                                    return;
                                                }
                                                currentColor = t;
                                            }

                                            if(!colorModel.hasColor(colorToARGB(currentColor))){
                                                colorModel.addColor(colorToARGB(currentColor), false);
                                            }else{
                                                toast.showToast(qsTr("pccut_word_edit_font_toast_4"))
                                            }
                                        }
                                    }else{
                                        oldColor = currentColor;
                                        currentColor = intToColor(colorvalue);
                                        colorPopup.addUndoColor(oldColor, currentColor);
                                    }
                                }

                            }
                        }

                        Loader {
                            id: colorContextMenuLoader
                            active: false
                            sourceComponent: LightMenu {
                                property int colorIndex: -1
                                menuWidth: 80
                                contentTextLeftMargin: 12
                                itemHighlighted: Colors.color_353738
                                itemFontSize: 11

                                Action {
                                    text: qsTr("pccut_shortcut_delete")
                                    onTriggered: {
                                        if (colorIndex >= 0) {
                                            colorModel.removeColor(colorIndex)
                                        }
                                    }
                                }
                            }
                        }

                        // 特殊单元格添加图标
                        Image {
                            visible: isFirstRowFirstColumn
                            source: "qrc:/icons/ic_addcolor.svg"
                            width: 9.5
                            height: 9.5
                            anchors {
                                top: parent.top
                                right: parent.right
                                margins: 5
                            }
                        }
                    }
                }
            }

        }

    }


    Popup {
        id: colorTypePopup
        x: 10
        y: 10
        width: 70
        height: 67
        padding: 0
        background: Rectangle {
            radius: 4
            color: Colors.color_454649
        }
        property bool bRGB: true

        signal selectColorType(bool bRgb)

        Rectangle {
            id: rgbRectangle
            anchors {
                left: parent.left; top: parent.top
                leftMargin: 4; topMargin: 4
            }
            color:  Colors.color_454649
            width: 62; height: 28 //15
            radius: 4

            Rectangle {
                width: 16; height: 16;
                anchors.top: parent.top; anchors.left: parent.left
                anchors.leftMargin: 8; anchors.topMargin: 6
                color: Colors.color_transparent;
                radius: 4
                visible: colorTypePopup.bRGB
                Image{
                    id: rgbImage
                    anchors{
                        left: parent.left; top: parent.top;
                    }
                    source: "qrc:/icons/adjustment/icon_compose_check.svg"
                    sourceSize: Qt.size(16, 16)
                }
            }
            Text {
                width: 24; height: 15
                text: "RGB"
                font.pixelSize: 11
                anchors.right: parent.right; anchors.top: parent.top
                anchors.rightMargin: 6; anchors.topMargin: 6.5
                horizontalAlignment: Text.AlignRight
                color: Colors.color_EEEEEE
            }

            MouseArea {
                id: rgbmouseArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: (mouse)=> {
                    colorTypePopup.bRGB = true;
                    colorTypePopup.selectColorType(true);
                    colorTypePopup.close();
                }
                // 鼠标进入
                onEntered: {
                    parent.color = Colors.color_68696D
                }
                // 鼠标离开
                onExited: {
                    parent.color = Colors.color_454649
                    // if(colorTypePopup.bRGB)
                    //     parent.color = Colors.color_56575B
                    // else
                    //     parent.color = Colors.color_454649;
                }
            }
        }

        Rectangle {
            id: hexRectangle
            color:  {
                if(!colorTypePopup.bRGB)
                    return Colors.color_56575B
                else
                    return Colors.color_454649;
            }
            anchors {
                left: parent.left; bottom: parent.bottom
                leftMargin: 4; bottomMargin: 4
            }
            width: 62; height: 28
            radius: 4

            Rectangle {
                width: 16; height: 16;
                anchors.top: parent.top; anchors.left: parent.left
                anchors.leftMargin: 8; anchors.topMargin: 6
                color: Colors.color_transparent;
                radius: 4
                visible: !colorTypePopup.bRGB
                Image{
                    id: hexImage
                    anchors{
                        left: parent.left; top: parent.top;
                    }
                    source: "qrc:/icons/adjustment/icon_compose_check.svg"
                    sourceSize: Qt.size(16, 16)
                }
            }
            Text {
                width: 23; height: 15
                text: "HEX"
                font.pixelSize: 11
                anchors.right: parent.right; anchors.top: parent.top
                anchors.rightMargin: 7; anchors.topMargin: 6.5
                horizontalAlignment: Text.AlignRight
                color: Colors.color_EEEEEE
            }

            MouseArea {
                id: hexmouseArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: (mouse)=> {
                    colorTypePopup.bRGB = false;
                    colorTypePopup.selectColorType(false);
                    colorTypePopup.close();
                }
                // 鼠标进入
                onEntered: parent.color = Colors.color_68696D
                // 鼠标离开
                onExited: {
                    parent.color = Colors.color_454649
                }
            }
        }

    }

}

