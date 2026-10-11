import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.3
import LightRectangle 1.0
import Config 1.0
import Controls 1.0
import QmlConstants 1.0
import Qt5Compat.GraphicalEffects
//import SettingPanelViewModel 1.0
import Nova 1.0
import app_qrc 1.0

/**
 * @author hongbin.shi
 * @desc 文本片段参数设置界面
 * @create_date 2025-12-10
 */

Rectangle {
    id: root
    //anchors.fill: parent

    color: Colors.color_content_area_background
    property TextViewModel textViewModel

    property int kBaseHeight: 1080
    property int kBaseWidth: 1920
    property int kMaxFontSize: 300
    property int kMinFontSize: 5
    property int kMaxScale: 1000
    property int kMinScale: 1
    property int kMaxTranslateX: 7680
    property int kMinTranslateX: -7680
    property int kMaxTranslateY: 4320
    property int kMinTranslateY: -4320

    // 子标题字体大小
    readonly property int kSubTitleSize: 11

    readonly property int baseMaxLength: 4320
    property bool bOpenFontPopUp: false
    property bool bOpenColorPopUp: false

    readonly property var kTextTitle: "text.title";
    readonly property var kTextColor: "text.color";
    readonly property var kTextAlpha: "text.alpha";
    readonly property var kTextFont: "text.font";
    readonly property var kTextFontPath: "text.font_path";
    readonly property var kTextFontSize: "text.font_size";
    readonly property var kTextAlign: "text.align";
    readonly property var kTextBold: "text.bold";
    readonly property var kTextUnderline: "text.underline";
    readonly property var kTextItalic: "text.italic";
    readonly property var kSelected: "selected";
    readonly property var kRotate: "rotate";
    readonly property var kScale: "scale";
    readonly property var kTranslate: "translate";


    function intToColor(colorInt) {
        //var a = (colorInt >> 24) & 0xFF
        var r = (colorInt >> 16) & 0xFF
        var g = (colorInt >> 8) & 0xFF
        var b = colorInt & 0xFF
        return Qt.rgba(r / 255, g / 255, b / 255, 1.0)
    }
    function colorToARGB(color) {
        var c = Qt.color(color)
        var a = 255 //Math.round(c.a * 255)
        var r = Math.round(c.r * 255)
        var g = Math.round(c.g * 255)
        var b = Math.round(c.b * 255)

        // ARGB 格式：0xAARRGGBB
        return (a << 24) | (r << 16) | (g << 8) | b
    }

    Connections {
        target: textViewModel

        function onTextColorChanged(textColor){
            if (root.selectColorPopup) {
                root.selectColorPopup.currentColor = intToColor(root.textViewModel.textColor)
            }
        }
    }
    onVisibleChanged: {
        if(!visible){
            forceActiveFocus()
        }
    }

    // 顶部分割线
    Rectangle {
        color: Colors.color_141414
        width: parent.width
        height: 1
    }

    ScrollView {
        id: scrollView
        anchors.fill: parent
        anchors {
            leftMargin: 12
            topMargin: 1
            rightMargin: 12
        }
        //bottomPadding: 16

        ScrollBar.vertical.policy: ScrollBar.AlwaysOff
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        clip: true

        contentItem: Flickable {
            id: flickable
            boundsBehavior: Flickable.StopAtBounds
            contentWidth: width
            contentHeight: contentRoot.height
            Column {
                id: contentRoot
                width: parent.width

                Item {
                    id: topSpace
                    width: scrollView.width
                    height: 16
                }

                Rectangle {
                    id: contentRect
                    width: parent.width
                    height: textEditor.height + textSettingRectangle.height + posRectangle.height +  16*4
                    color: Colors.color_content_area_background

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            // 强制清除所有焦点
                            forceActiveFocus()
                        }
                    }

                    //内容编辑区
                    TextEditor {
                        id: textEditor
                        anchors {
                            top: parent.top;
                            left: parent.left
                        }
                        width: parent.width
                        textContent: textViewModel.textTitle

                        onTextContentChanged: {
                            if(textContent !== textViewModel.textTitle){
                                if(textContent.length>240){
                                    textViewModel.textTitle = textContent.substring(0, 240);
                                }
                                else{
                                    textViewModel.textTitle = textContent;
                                }
                            }
                        }
                    }

                    //文字设置
                    Rectangle {
                        id: textSettingRectangle
                        width: parent.width
                        height: 240
                        color: Colors.color_1F2021
                        anchors.top: textEditor.bottom
                        anchors.topMargin: 20


                        Rectangle{
                            id: textLabelRectangle
                            width: parent.width
                            height: 28
                            anchors.left: parent.left
                            anchors.top: parent.top
                            color: Colors.color_transparent

                            Text {
                                id: textLabel
                                text: qsTr("pccut_word_edit_set")
                                font.pixelSize: 12
                                anchors.left: parent.left
                                anchors.top: parent.top
                                horizontalAlignment: Text.AlignLeft
                                color: Colors.color_EEEEEE

                                elide: Text.ElideRight
                                LightToolTip {
                                    visible: mouseAreaTextLabel.containsMouse && (textLabel.truncated)
                                    tip: textLabel.text
                                    z: 200
                                    y: parent.height + 10
                                }
                                MouseArea {
                                    id: mouseAreaTextLabel
                                    anchors.fill: parent
                                    hoverEnabled: true
                                }
                            }
                        }

                        //字体
                        Rectangle {
                            id: fontRectangle
                            width: parent.width
                            height: 28
                            anchors.left: parent.left
                            anchors.top: textLabelRectangle.bottom
                            color: Colors.color_transparent

                            Text {
                                id: fontLabel
                                text: qsTr("pccut_word_edit_font_name")
                                font.pixelSize: kSubTitleSize
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.topMargin: 6
                                horizontalAlignment: Text.AlignLeft
                                color: Colors.color_999999

                                elide: Text.ElideRight
                                LightToolTip {
                                    visible: mouseAreaFontLabel.containsMouse && (fontLabel.truncated)
                                    tip: fontLabel.text
                                    z: 200
                                    y: parent.height + 10
                                }
                                MouseArea {
                                    id: mouseAreaFontLabel
                                    anchors.fill: parent
                                    hoverEnabled: true
                                }
                            }

                            Rectangle {
                                id: fontnameRectangle
                                height: 28;
                                color: Colors.color_2F3032
                                anchors {
                                    left: parent.left
                                    top: parent.top
                                    leftMargin: 60
                                    right: parent.right
                                }
                                radius: 4
                                //具体字体: 如 "宋体"
                                Text {
                                    id: fontnameText
                                    width: 48; height: 16
                                    text: {
                                        // textFont 即面板显示用 family（VM 已按路径查表得到）；为空显示系统默认。
                                        if(textViewModel.textFont.length === 0){
                                            return qsTr("pccut_word_edit_font_typ_system");
                                        }
                                        return textViewModel.textFont;
                                    }
                                    font.pixelSize: kSubTitleSize
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.topMargin: 6
                                    anchors.leftMargin: 8
                                    horizontalAlignment: Text.AlignLeft
                                    color: Colors.color_EEEEEE
                                }
                                Image{
                                    id: fontBtn
                                    anchors{
                                        top: parent.top; right: parent.right
                                        topMargin: 4; rightMargin: 8
                                    }
                                    source:  (root.fontPopup && root.fontPopup.visible) ? "qrc:/icons/adjustment/icon_drop_down_menu_collapse.svg" : "qrc:/icons/adjustment/icon_drop_down_menu_expand.svg"
                                    sourceSize: Qt.size(20, 20)
                                }

                                MouseArea {
                                    id: fontMouseArea
                                    anchors.fill: parent

                                    hoverEnabled: true
                                    onEntered: {
                                        parent.color = Colors.color_37383A
                                        if (root.fontPopup) root.bOpenFontPopUp = root.fontPopup.visible;
                                    }
                                    onExited: {
                                        parent.color = Colors.color_2F3032
                                    }

                                    onClicked: {
                                        forceActiveFocus()
                                        var x = fontRectangle.mapToItem(root, 0, 0).x
                                        var y = fontRectangle.mapToItem(root, 0, 0).y + fontRectangle.height + 4
                                        // textFont 即显示用 family，直接作为 popup 当前选中项。
                                        var textFont = root.textViewModel.textFont

                                        if(root.bOpenFontPopUp){
                                            root.closeFontPopup();
                                        }
                                        else{
                                            root.openFontPopupAt(x, y, textFont);
                                        }
                                    }
                                }

                                Connections {
                                    target: root.fontPopup
                                    function onSelectFontChange(fontName, realFamily, fontPath) {
                                        // 有文件路径走路径；Mac 系统字体 fontPath 为空，回退 realFamily/fontName
                                        // 写入 resource，否则内核收不到字体、预览不变（Win 系统字有路径所以正常）。
                                        var pathOrFamily = (fontPath && fontPath.length > 0)
                                                ? fontPath
                                                : (realFamily && realFamily.length > 0 ? realFamily : fontName);
                                        root.textViewModel.textFontPath = pathOrFamily;
                                        root.textViewModel.textFont = fontName;
                                    }
                                }
                            }
                        }
                        //字号
                        Rectangle {
                            id: fontSizeRectangle
                            width: parent.width
                            height: 24
                            color: Colors.color_transparent
                            anchors.left: parent.left
                            anchors.top: fontRectangle.bottom
                            anchors.topMargin: 12

                            Text {
                                id: fontSizeLabel
                                width: 48; height: 16
                                text: qsTr("pccut_word_edit_font_size")
                                font.pixelSize: kSubTitleSize
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.topMargin: 4
                                horizontalAlignment: Text.AlignLeft
                                color: Colors.color_999999

                                elide: Text.ElideRight
                                LightToolTip {
                                    visible: mouseAreaFontSizeLabel.containsMouse && (fontSizeLabel.truncated)
                                    tip: fontSizeLabel.text
                                    z: 200
                                    y: parent.height + 10
                                }
                                MouseArea {
                                    id: mouseAreaFontSizeLabel
                                    anchors.fill: parent
                                    hoverEnabled: true
                                }
                            }

                            LightBaseSlider {
                                id: baseSlider
                                property int lastValue : 15
                                leftPadding: 0
                                anchors{
                                    top: parent.top
                                    left: fontSizeLabel.right; leftMargin: 12
                                    right: fontSizeTextField.left; rightMargin: 12
                                    verticalCenter: parent.verticalCenter
                                }

                                enabled: true
                                visible: true
                                width: 116
                                height: 12
                                from: 5
                                to: 300
                                value: textViewModel.textFontSize
                                stepSize: 1
                                snapMode: Slider.SnapAlways
                                Accessible.role: Accessible.Slider
                                property int oldValue: 0
                                onMoved: {
                                    if (pressed){
                                        textViewModel.textFontSize = value;
                                    }
                                }

                                onPressedChanged: {
                                    if (!pressed) {
                                        lastValue = value;
                                        textViewModel.addUndoAction(kTextFontSize, oldValue, value);
                                    }else{
                                        forceActiveFocus()
                                        oldValue = value;
                                    }
                                }

                                onValueChanged:{
                                    if(!pressed){
                                        lastValue = value;
                                    }
                                }
                            }

                            TextField {
                                id: fontSizeTextField
                                width: 56
                                height: 24
                                anchors.top: parent.top
                                anchors.right: fontSizeAdjustContainer.left
                                anchors.rightMargin: 2

                                // 背景黑色
                                background: Rectangle {
                                    color: Colors.color_19191A
                                    radius: 4
                                }
                                // 文本样式
                                color: Colors.color_EEEEEE
                                selectionColor: Colors.color_EEEEEE
                                selectedTextColor: Colors.color_1F2021
                                font.pixelSize: kSubTitleSize
                                horizontalAlignment: TextInput.AlignHCenter
                                text: textViewModel.textFontSize

                                // 输入验证属性
                                property int minValue: kMinFontSize
                                property int maxValue: kMaxFontSize
                                // 输入限制：只能输入数字
                                validator: IntValidator {
                                    bottom: fontSizeTextField.minValue
                                    top: fontSizeTextField.maxValue
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
                                            textViewModel.textFontSize = textViewModel.textFontSize;
                                        }else{
                                            var value = parseInt(text);
                                            if (!isNaN(value)) {
                                                if (value < minValue) {
                                                    value = minValue;
                                                } else if(value > maxValue){
                                                    value = maxValue;
                                                }

                                                // 如果值被调整，更新文本
                                                if (textViewModel.textFontSize !== value) {
                                                    var oldValue = textViewModel.textFontSize;
                                                    textViewModel.textFontSize = value;
                                                    textViewModel.addUndoAction(kTextFontSize, oldValue, value);
                                                }else{
                                                    textViewModel.textFontSize = value;
                                                }
                                            }
                                        }
                                    }
                                }
                                // 焦点变化时的处理
                                onActiveFocusChanged: {
                                    if (!activeFocus && text === "") {
                                        textViewModel.textFontSize = textViewModel.textFontSize;
                                    }
                                }

                                Keys.onShortcutOverride: function(event) {
                                    if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                                        focus = false;
                                        event.accepted = true
                                    }
                                }
                                // 键盘输入处理
                                Keys.onPressed: function(event) {
                                    // 只允许数字键
                                    if (event.text < '0' || event.text > '9') {
                                        event.accepted = false;
                                    }
                                }
                            }

                            Item{
                                id: fontSizeAdjustContainer
                                height: parent.height
                                width: 10
                                anchors{
                                    right: parent.right
                                }

                                Image{
                                    id: upBtn
                                    anchors{
                                        top: parent.top
                                        topMargin: 1
                                    }
                                    source: "qrc:/icons/ic_next_up.svg"
                                    sourceSize: Qt.size(10, 10)
                                    opacity: 1 //1 : 0.2

                                    MouseArea {
                                        id: mouseArea
                                        anchors.fill: parent
                                        onClicked: {
                                            forceActiveFocus()
                                            var oldValue = textViewModel.textFontSize;
                                            textViewModel.textFontSize = Math.min(textViewModel.textFontSize + 1, 300);
                                            textViewModel.addUndoAction(kTextFontSize, oldValue, textViewModel.textFontSize);
                                        }
                                    }
                                }

                                Image{
                                    id: downBtn
                                    anchors{
                                        bottom: parent.bottom
                                        bottomMargin: 1
                                    }
                                    source: "qrc:/icons/ic_next_down.svg"
                                    sourceSize: Qt.size(10, 10)
                                    opacity: 1
                                    MouseArea {
                                        id: mouseArea1
                                        anchors.fill: parent
                                        onClicked: {
                                            forceActiveFocus()
                                            var oldValue = textViewModel.textFontSize;
                                            textViewModel.textFontSize = Math.max(textViewModel.textFontSize - 1, 5);
                                            textViewModel.addUndoAction(kTextFontSize, oldValue, textViewModel.textFontSize);
                                        }
                                    }
                                }
                            }
                        }
                        //样式
                        Rectangle {
                            id: styleRectangle
                            width: parent.width
                            height: 24
                            color: Colors.color_transparent
                            anchors.left: parent.left
                            anchors.top: fontSizeRectangle.bottom
                            anchors.topMargin: 12

                            Text {
                                id: styleLabel
                                width: 48; height: 16
                                text: qsTr("pccut_word_edit_font_typ")
                                font.pixelSize: kSubTitleSize
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.topMargin: 4
                                horizontalAlignment: Text.AlignLeft
                                color: Colors.color_999999

                                elide: Text.ElideRight
                                LightToolTip {
                                    visible: mouseAreaStyleLabel.containsMouse && (styleLabel.truncated)
                                    tip: styleLabel.text
                                    z: 200
                                    y: parent.height + 10
                                }
                                MouseArea {
                                    id: mouseAreaStyleLabel
                                    anchors.fill: parent
                                    hoverEnabled: true
                                }
                            }

                            Rectangle {
                                id: boldRectangle
                                width: 24; height: 24;
                                color: Colors.color_2F3032
                                anchors.top: parent.top
                                anchors.left: styleLabel.right
                                anchors.leftMargin: 12
                                radius: 4

                                MouseArea {
                                    id: boldmouseArea
                                    anchors.fill: parent
                                    onClicked: {
                                        textViewModel.textBold = !textViewModel.textBold;
                                    }
                                    hoverEnabled: true
                                    onEntered: parent.color = Colors.color_37383A
                                    onExited: parent.color = Colors.color_2F3032
                                }

                                Image{
                                    id: boldBtn
                                    anchors{
                                        top: parent.top
                                        left: parent.left
                                        topMargin: 5
                                        leftMargin: 7
                                    }
                                    source: "qrc:/icons/ic_bold.svg"
                                    sourceSize: Qt.size(10, 14)
                                    opacity: 1

                                    ColorOverlay {
                                        anchors.fill: boldBtn
                                        source: boldBtn
                                        color: {
                                            forceActiveFocus()
                                            if(textViewModel.textBold)
                                                return Colors.color_F22443
                                            return Colors.color_EEEEEE
                                            // if(textViewModel.textBold){
                                            //     return ColorsConfig.color_brand
                                            // }
                                            // return Colors.color_FFFFFF
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                id: underRectangle
                                width: 24; height: 24;
                                color: Colors.color_2F3032
                                anchors.top: parent.top
                                anchors.left: boldRectangle.right
                                anchors.leftMargin: 12
                                radius: 4
                                visible: false
                                MouseArea {
                                    id: undermouseArea
                                    anchors.fill: parent
                                    onClicked: {
                                        forceActiveFocus()
                                        textViewModel.textUnderline = !textViewModel.textUnderline
                                        text
                                    }
                                    hoverEnabled: true
                                    onEntered: parent.color = Colors.color_37383A
                                    onExited: parent.color = Colors.color_2F3032
                                }

                                Image{
                                    id: underBtn
                                    anchors{
                                        top: parent.top
                                        left: parent.left
                                        topMargin: 6
                                        leftMargin: 7
                                    }
                                    source: "qrc:/icons/ic_underline.svg"
                                    sourceSize: Qt.size(9, 10)
                                    opacity: 1

                                    ColorOverlay {
                                        anchors.fill: underBtn
                                        source: underBtn
                                        color: {
                                            if(textViewModel.textUnderline)
                                                return Colors.color_F22443
                                            return Colors.color_EEEEEE
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                id: italicRectangle
                                width: 24; height: 24;
                                color: Colors.color_2F3032
                                anchors.top: parent.top
                                anchors.left: boldRectangle.right
                                anchors.leftMargin: 12
                                radius: 4
                                MouseArea {
                                    id: italicmouseArea
                                    anchors.fill: parent
                                    onClicked: {
                                        textViewModel.textItalic = !textViewModel.textItalic
                                    }
                                    hoverEnabled: true
                                    onEntered: parent.color = Colors.color_37383A
                                    onExited: parent.color = Colors.color_2F3032
                                }

                                Image{
                                    id: italicBtn
                                    anchors{
                                        top: parent.top
                                        left: parent.left
                                        topMargin: 7
                                        leftMargin: 8
                                    }
                                    source: "qrc:/icons/ic_italic.svg"
                                    sourceSize: Qt.size(8, 11)
                                    opacity: 1

                                    ColorOverlay {
                                        anchors.fill: italicBtn
                                        source: italicBtn
                                        color: {
                                            forceActiveFocus()
                                            if(textViewModel.textItalic)
                                                return Colors.color_F22443
                                            return Colors.color_EEEEEE

                                            // if(textViewModel.textItalic)
                                            //     return ColorsConfig.color_brand
                                            // return Colors.color_FFFFFF
                                        }
                                    }
                                }
                            }
                        }

                        //颜色
                        Rectangle {
                            id: colorRectangle
                            width: parent.width
                            height: 28
                            color: Colors.color_transparent
                            anchors.left: parent.left
                            anchors.top: styleRectangle.bottom
                            anchors.topMargin: 12

                            Text {
                                id: colorLabel
                                width: 48; height: 16
                                text: qsTr("pccut_word_edit_font_color")
                                font.pixelSize: kSubTitleSize
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.topMargin: 6
                                horizontalAlignment: Text.AlignLeft
                                color: Colors.color_999999

                                elide: Text.ElideRight
                                LightToolTip {
                                    visible: mouseAreaColorLabel.containsMouse && (colorLabel.truncated)
                                    tip: colorLabel.text
                                    z: 200
                                    y: parent.height + 10
                                }
                                MouseArea {
                                    id: mouseAreaColorLabel
                                    anchors.fill: parent
                                    hoverEnabled: true
                                }
                            }

                            //颜色和箭头组合框
                            Rectangle {
                                id: color1Rectangle
                                width: 96; height: 28;
                                color: Colors.color_2F3032
                                anchors.top: parent.top
                                anchors.left: colorLabel.right
                                anchors.leftMargin: 12
                                radius: 4
                                //颜色框
                                Rectangle {
                                    id: colorVRectangle
                                    width: 64; height: 20;
                                    anchors{
                                        left: parent.left; top: parent.top
                                        leftMargin: 4; topMargin: 4
                                    }
                                    color: intToColor(textViewModel.textColor)
                                    radius: 2
                                }
                                Image{
                                    id: colorBtn
                                    anchors{
                                        top: parent.top; topMargin: 4;
                                        //right: parent.right; rightMargin: 8
                                        left: colorVRectangle.right; leftMargin: 4
                                    }
                                    source:  (root.selectColorPopup && root.selectColorPopup.visible) ? "qrc:/icons/adjustment/icon_drop_down_menu_collapse.svg" : "qrc:/icons/adjustment/icon_drop_down_menu_expand.svg"
                                    sourceSize: Qt.size(20, 20)
                                }


                                MouseArea {
                                    id: colorMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: {
                                        parent.color = Colors.color_37383A
                                        if (root.selectColorPopup) root.bOpenColorPopUp = root.selectColorPopup.visible;
                                    }
                                    onExited: {
                                        parent.color = Colors.color_2F3032
                                    }

                                    onClicked: {
                                        forceActiveFocus()
                                        var x = colorRectangle.mapToItem(root, 0, 0).x
                                        var y = colorRectangle.mapToItem(root, 0, 0).y + colorRectangle.height + 4
                                        //设置当前颜色
                                        var currentColor = intToColor(root.textViewModel.textColor)

                                        if(root.bOpenColorPopUp){
                                            root.closeColorPopup();
                                        }
                                        else{
                                            root.openColorPopupAt(x, y, currentColor);
                                        }
                                    }

                                }

                                Connections {
                                    target: root.selectColorPopup
                                    function onColorSelected(c) {
                                        var r = Qt.color(c).r * 255
                                        var g = Qt.color(c).g * 255
                                        var b = Qt.color(c).b * 255
                                        var a = Qt.color(c).a
                                        //界面上选择颜色后更新model
                                        root.textViewModel.textColor = colorToARGB(c);
                                    }

                                    function onAddUndoColor(oldcolor, newcolor){
                                        textViewModel.addUndoAction(kTextColor, colorToARGB(oldcolor), colorToARGB(newcolor));
                                    }
                                }
                            }
                        }

                        //对齐
                        Rectangle {
                            id: alignmentRectangle
                            width: parent.width
                            height: 24
                            color: Colors.color_transparent
                            anchors.left: parent.left
                            anchors.top: colorRectangle.bottom
                            anchors.topMargin: 12

                            Text {
                                id: alignmentLabel
                                width: 48; height: 16
                                text: qsTr("pccut_word_alignment_title")
                                font.pixelSize: kSubTitleSize
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.topMargin: 4
                                horizontalAlignment: Text.AlignLeft
                                color: Colors.color_999999

                                elide: Text.ElideRight
                                LightToolTip {
                                    visible: mouseAreaAlignmentLabel.containsMouse && (alignmentLabel.truncated)
                                    tip: alignmentLabel.text
                                    z: 200
                                    y: parent.height + 10
                                }
                                MouseArea {
                                    id: mouseAreaAlignmentLabel
                                    anchors.fill: parent
                                    hoverEnabled: true
                                }
                            }
                            //对齐方式
                            Rectangle {
                                id: alignmentTypeRectangle
                                width: 96; height: 24;
                                color: Colors.color_2F3032
                                anchors.top: parent.top
                                anchors.left: alignmentLabel.right
                                anchors.leftMargin: 12
                                radius: 4

                                Rectangle {
                                    id: leftAlignmentRectangle
                                    width: 32; height: 24;
                                    color: Colors.color_transparent
                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    radius: 4
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            forceActiveFocus()
                                            var oldValue = textViewModel.textAlign
                                            textViewModel.textAlign = 0;
                                        }
                                        hoverEnabled: true
                                        onEntered: parent.color = Colors.color_37383A
                                        onExited: parent.color = Colors.color_transparent
                                    }
                                }
                                Rectangle {
                                    id: centerAlignmentRectangle
                                    width: 32; height: 24;
                                    color: Colors.color_transparent
                                    anchors.top: parent.top
                                    anchors.left: leftAlignmentRectangle.right
                                    radius: 4
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            forceActiveFocus()
                                            var oldValue = textViewModel.textAlign
                                            textViewModel.textAlign = 1;
                                        }
                                        hoverEnabled: true
                                        onEntered: parent.color = Colors.color_37383A
                                        onExited: parent.color = Colors.color_transparent
                                    }
                                }
                                Rectangle {
                                    id: rightAlignmentRectangle
                                    width: 32; height: 24;
                                    color: Colors.color_transparent
                                    anchors.top: parent.top
                                    anchors.left: centerAlignmentRectangle.right
                                    radius: 4
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            forceActiveFocus()
                                            var oldValue = textViewModel.textAlign
                                            textViewModel.textAlign = 2;
                                        }
                                        hoverEnabled: true
                                        onEntered: parent.color = Colors.color_37383A
                                        onExited: parent.color = Colors.color_transparent
                                    }
                                }

                                Image{
                                    id: leftBtn
                                    anchors{
                                        top: parent.top; left: parent.left; topMargin: 4; leftMargin: 8
                                    }
                                    source: "qrc:/icons/ic_alignment_left.svg"
                                    sourceSize: Qt.size(16, 16)
                                    opacity: 1
                                    ColorOverlay {
                                        anchors.fill: leftBtn
                                        source: leftBtn
                                        color: {
                                            if(textViewModel.textAlign === 0)
                                                return Colors.color_F22443
                                            return Colors.color_EEEEEE
                                        }
                                    }
                                }
                                Image{
                                    id: centerBtn
                                    anchors{
                                        top: parent.top; left: leftBtn.right; topMargin: 4; leftMargin: 16
                                    }
                                    source: "qrc:/icons/ic_alignment_center.svg"
                                    sourceSize: Qt.size(16, 16)
                                    opacity: 1
                                    ColorOverlay {
                                        anchors.fill: centerBtn
                                        source: centerBtn
                                        color: {
                                            if(textViewModel.textAlign === 1)
                                                return Colors.color_F22443
                                            return Colors.color_EEEEEE
                                        }
                                    }
                                }
                                Image{
                                    id: rightBtn
                                    anchors{
                                        top: parent.top; left: centerBtn.right; topMargin: 4; leftMargin: 16
                                    }
                                    source: "qrc:/icons/ic_alignment_right.svg"
                                    sourceSize: Qt.size(16, 16)
                                    opacity: 1
                                    ColorOverlay {
                                        anchors.fill: rightBtn
                                        source: rightBtn
                                        color: {
                                            if(textViewModel.textAlign === 2)
                                                return Colors.color_F22443
                                            return Colors.color_EEEEEE
                                        }
                                    }
                                }
                            }

                        }

                        //不透明度
                        Rectangle {
                            id: alphaRectangle
                            width: parent.width
                            height: 24
                            color: Colors.color_transparent
                            anchors.left: parent.left
                            anchors.top: alignmentRectangle.bottom
                            anchors.topMargin: 12

                            Text {
                                id: alphaLabel
                                width: 48; height: 16
                                text: qsTr("pccut_word_edit_font_transparent")
                                font.pixelSize: kSubTitleSize
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.topMargin: 4
                                horizontalAlignment: Text.AlignLeft
                                color: Colors.color_999999

                                elide: Text.ElideRight
                                LightToolTip {
                                    visible: mouseAreaAlphaLabel.containsMouse && (alphaLabel.truncated)
                                    tip: alphaLabel.text
                                    z: 200
                                    y: parent.height + 10
                                }
                                MouseArea {
                                    id: mouseAreaAlphaLabel
                                    anchors.fill: parent
                                    hoverEnabled: true
                                }
                            }

                            LightBaseSlider {
                                id: alphaSlider
                                property int lastValue : 100
                                leftPadding: 0
                                anchors{
                                    top: parent.top
                                    left: alphaLabel.right; leftMargin: 12
                                    right: alphaRect.left; rightMargin: 12
                                    verticalCenter: parent.verticalCenter
                                }

                                enabled: true
                                visible: true
                                width: 116
                                height: 12
                                from: 0
                                to: 100
                                value: {
                                    return parseInt(textViewModel.textAlpha * 100)
                                }
                                stepSize: 1
                                snapMode: Slider.SnapAlways
                                Accessible.role: Accessible.Slider
                                property real oldValue: 0
                                onMoved: {
                                    if (pressed){
                                        var newValue = value / 100.0;
                                        if(textViewModel.textAlpha !== newValue)
                                            textViewModel.textAlpha = newValue
                                    }
                                }
                                onPressedChanged: {
                                    if (!pressed) {
                                        lastValue = value;
                                        textViewModel.addUndoAction(kTextAlpha, oldValue, textViewModel.textAlpha);
                                    }else{
                                        forceActiveFocus()
                                        oldValue = textViewModel.textAlpha;
                                    }
                                }
                            }

                            Rectangle {
                                id: alphaRect
                                anchors.top: parent.top
                                anchors.right: alphaAdjustContainer.left; anchors.rightMargin: 2
                                height: 24
                                width: 56
                                color: Colors.color_19191A
                                radius: 4

                                Rectangle {
                                    id: alphaComponent
                                    anchors.top: parent.top
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    height: 24
                                    width: {
                                        var t = alphaTextField.width + textDescText.width
                                        if(t < 56){
                                            return t
                                        }else{
                                            return 56
                                        }
                                    }
                                    color: Colors.color_19191A

                                    TextField {
                                        id: alphaTextField
                                        height: 24
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                        text: {
                                            var t = parseInt(textViewModel.textAlpha * 100)
                                            return t.toString();
                                        }
                                        width: {
                                                var contentWidth = alphaTextField.contentWidth
                                                return Math.min(50, Math.max(10, contentWidth))
                                            }
                                        // 背景黑色
                                        background: Rectangle {
                                            color: Colors.color_19191A
                                            radius: 4
                                        }
                                        anchors.verticalCenter: parent.verticalCenter
                                        verticalAlignment: Text.AlignVCenter
                                        // 文本样式
                                        color: Colors.color_EEEEEE
                                        selectionColor: Colors.color_EEEEEE
                                        selectedTextColor: Colors.color_1F2021
                                        font.pixelSize: kSubTitleSize
                                        horizontalAlignment: TextInput.AlignRight
                                        rightPadding: 0
                                        leftPadding: 0

                                        // 输入限制：只能输入数字
                                        property int minValue: 0
                                        property int maxValue: 100
                                        validator: IntValidator {
                                            bottom: alphaTextField.minValue
                                            top: alphaTextField.maxValue
                                        }
                                        // 当焦点失去时
                                        onFocusChanged: {
                                            if (!focus) {
                                                if (text.length <= 0) {
                                                    textViewModel.textAlpha = textViewModel.textAlpha;
                                                }else{
                                                    var alpha = parseInt(text);
                                                    if (!isNaN(alpha)) {
                                                        if (alpha < minValue) {
                                                            alpha = minValue;
                                                        } else if (alpha > maxValue) {
                                                            alpha = maxValue;
                                                        }
                                                        var newValue = alpha / 100.0;
                                                        if(textViewModel.textAlpha !== newValue){
                                                            var oldValue = textViewModel.textAlpha
                                                            textViewModel.textAlpha = newValue
                                                            textViewModel.addUndoAction(kTextAlpha, oldValue, newValue);
                                                        }else{
                                                            textViewModel.textAlpha = textViewModel.textAlpha;
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                        Keys.onReturnPressed: {
                                            focus = false
                                        }
                                        Keys.onEscapePressed: {
                                            focus = false
                                        }
                                        Keys.onShortcutOverride: function(event) {
                                            if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                                                focus = false;
                                                event.accepted = true
                                            }
                                        }
                                        // 键盘输入处理
                                        Keys.onPressed: function(event) {
                                            // 允许退格、删除、方向键等控制键
                                            if (event.key === Qt.Key_Backspace ||
                                                event.key === Qt.Key_Delete ||
                                                event.key === Qt.Key_Left ||
                                                event.key === Qt.Key_Right ||
                                                event.key === Qt.Key_Home ||
                                                event.key === Qt.Key_End ||
                                                event.key === Qt.Key_Tab ||
                                                event.key === Qt.Key_Enter ||
                                                event.key === Qt.Key_Return ||
                                                event.key === Qt.Key_Escape) {
                                                return;
                                            }

                                            if (event.text < '0' || event.text > '9') {
                                                event.accepted = false;
                                            }
                                        }
                                    }
                                    Text {
                                        id: textDescText
                                        height: 24
                                        width: contentWidth
                                        anchors.left: alphaTextField.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "%"
                                        horizontalAlignment: Text.AlignLeft
                                        verticalAlignment: Text.AlignVCenter
                                        color: Colors.color_EEEEEE
                                        font.pixelSize: kSubTitleSize
                                        rightPadding: 0
                                        leftPadding: 0
                                    }
                                }
                            }


                            Item{
                                id: alphaAdjustContainer
                                height: parent.height
                                width: 10
                                anchors{
                                    right: parent.right
                                }

                                Image{
                                    id: alphaUpBtn
                                    anchors{
                                        top: parent.top
                                        topMargin: 1
                                    }
                                    source: "qrc:/icons/ic_next_up.svg"
                                    sourceSize: Qt.size(10, 10)
                                    opacity: 1

                                    MouseArea {
                                        id: alphaUpMouseArea
                                        anchors.fill: parent
                                        onClicked: {
                                            forceActiveFocus()
                                            var oldValue = textViewModel.textAlpha
                                            textViewModel.textAlpha = Math.min(textViewModel.textAlpha + 0.01, 1);
                                            textViewModel.addUndoAction(kTextAlpha, oldValue, textViewModel.textAlpha);
                                        }
                                    }
                                }

                                Image{
                                    id: alphaDownBtn
                                    anchors{
                                        bottom: parent.bottom
                                        bottomMargin: 1
                                    }
                                    source: "qrc:/icons/ic_next_down.svg"
                                    sourceSize: Qt.size(10, 10)
                                    opacity: 1 // 1 : 0.2
                                    MouseArea {
                                        id: alphaDownMouseArea1
                                        anchors.fill: parent
                                        onClicked: {
                                            forceActiveFocus()
                                            var oldValue = textViewModel.textAlpha
                                            textViewModel.textAlpha = Math.max(textViewModel.textAlpha - 0.01, 0);
                                            textViewModel.addUndoAction(kTextAlpha, oldValue, textViewModel.textAlpha);
                                        }
                                    }
                                }
                            }
                        }
                    }

                    //分割线
                    Rectangle {
                        id: separatorRectangle
                        height: 1
                        width: parent.width
                        color: Colors.color_2F3032
                        anchors {
                            left: parent.left
                            top: textSettingRectangle.bottom
                            right: parent.right
                            topMargin: 16
                        }
                        visible: true
                    }

                    //位置大小
                    Rectangle {
                        id: posRectangle
                        width: parent.width
                        height: 160
                        color: Colors.color_1F2021
                        anchors.top: separatorRectangle.bottom
                        anchors.topMargin: 16

                        Rectangle{
                            id: posSizeRectangle
                            width: parent.width
                            height: 28
                            anchors.left: parent.left
                            anchors.top: parent.top
                            color: Colors.color_transparent

                            Text {
                                id: postSizeLabel
                                text: qsTr("pccut_word_edit_font_location")
                                font.pixelSize: 12
                                anchors.left: parent.left
                                anchors.top: parent.top
                                horizontalAlignment: Text.AlignLeft
                                color: Colors.color_EEEEEE

                                elide: Text.ElideRight
                                LightToolTip {
                                    visible: mouseAreaPostSizeLabel.containsMouse && (postSizeLabel.truncated)
                                    tip: postSizeLabel.text
                                    z: 200
                                    y: parent.height + 10
                                }
                                MouseArea {
                                    id: mouseAreaPostSizeLabel
                                    anchors.fill: parent
                                    hoverEnabled: true
                                }
                            }

                            Rectangle {
                                id: posResetRectangle
                                width: 24; height: 24;
                                color: Colors.color_transparent
                                anchors{
                                    right: parent.right; top: parent.top;
                                }

                                Image{
                                    id: posResetBtn
                                    width: 20
                                    height: 20
                                    anchors{
                                        right: parent.right; rightMargin: 2
                                        top: parent.top; topMargin: 2
                                    }
                                    source: "qrc:/icons/ic_pos_reset.svg"
                                    sourceSize: Qt.size(20, 20)
                                    //opacity: textViewModel.needReset ? 1 : 0.2

                                    property color disableColor: Colors.color_444444
                                    property color enableColor: Colors.color_FFFFFF_20


                                    MouseArea {
                                        id: posResetMouseArea
                                        anchors.fill: parent
                                        onClicked: {
                                            forceActiveFocus()
                                            textViewModel.resetLocation();
                                        }
                                        hoverEnabled: true
                                        onEntered: {
                                            posResetBtn.enableColor = Colors.color_FFFFFF
                                        }
                                        onExited: {
                                            posResetBtn.enableColor = Colors.color_FFFFFF_20
                                        }
                                    }
                                    ColorOverlay {
                                        id: resetOverlay
                                        anchors.fill: posResetBtn
                                        source: posResetBtn
                                        color: {
                                            return textViewModel.needReset?posResetBtn.enableColor:posResetBtn.disableColor
                                        }
                                    }

                                }
                            }

                        }

                        //缩放
                        Rectangle {
                            id: scaleRectangle
                            width: parent.width
                            height: 24
                            color: Colors.color_transparent
                            anchors.left: parent.left
                            anchors.top: posSizeRectangle.bottom
                            anchors.topMargin: 12

                            Text {
                                id: scaleLabel
                                width: 48; height: 16
                                text: qsTr("pccut_word_edit_font_zoom")
                                font.pixelSize: kSubTitleSize
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.topMargin: 4
                                horizontalAlignment: Text.AlignLeft
                                color: Colors.color_999999

                                elide: Text.ElideRight
                                LightToolTip {
                                    visible: mouseAreaScaleLabel.containsMouse && (scaleLabel.truncated)
                                    tip: scaleLabel.text
                                    z: 200
                                    y: parent.height + 10
                                }
                                MouseArea {
                                    id: mouseAreaScaleLabel
                                    anchors.fill: parent
                                    hoverEnabled: true
                                }
                            }

                            LightBaseSlider {
                                id: scaleSlider
                                property int lastValue : 100
                                property real sliderLeft: 70
                                leftPadding: 0
                                anchors{
                                    top: parent.top
                                    left: scaleLabel.right; leftMargin: 12
                                    right: scaleRect.left; rightMargin: 12
                                    verticalCenter: parent.verticalCenter
                                }

                                enabled: true
                                visible: true
                                width: 116
                                height: 12
                                from: 1
                                to: 1000
                                value: {
                                    parseInt(textViewModel.scale * 100)
                                }
                                stepSize: 1
                                snapMode: Slider.SnapAlways
                                Accessible.role: Accessible.Slider
                                property real oldValue: 0
                                onMoved: {
                                    if (pressed){
                                        var newValue = value / 100.0;
                                        if(textViewModel.scale !== newValue)
                                            textViewModel.scale = newValue
                                    }
                                }

                                onPressedChanged: {
                                    if (!pressed) {
                                        lastValue = value;
                                        textViewModel.addUndoAction(kScale, oldValue, textViewModel.scale);
                                    }else{
                                        forceActiveFocus()
                                        oldValue = textViewModel.scale;
                                    }
                                }

                                onValueChanged:{
                                    if(!pressed){
                                        lastValue = value;
                                    }
                                }
                            }

                            Rectangle {
                                id: scaleRect
                                anchors.top: parent.top
                                //anchors.left: scaleSlider.right; anchors.leftMargin: 12
                                anchors.right: scaleAdjustContainer.left; anchors.rightMargin: 2
                                height: 24
                                width: 56
                                color: Colors.color_19191A
                                radius: 4

                                Rectangle {
                                    id: scaleComponent
                                    anchors.top: parent.top
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    height: 24
                                    width: {
                                        var t = scaleTextField.width + scaleDescText.width
                                        if(t < 56){
                                            return t
                                        }else{
                                            return 56
                                        }
                                    }
                                    color: Colors.color_19191A

                                    TextField {
                                        id: scaleTextField
                                        height: 24
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                        text:{
                                            var t = parseInt(textViewModel.scale * 100)
                                            return t.toString();
                                        }
                                        width: {
                                                var contentWidth = scaleTextField.contentWidth
                                                return Math.min(50, Math.max(10, contentWidth))
                                            }
                                        // 背景黑色
                                        background: Rectangle {
                                            color: Colors.color_19191A
                                            radius: 4
                                        }
                                        anchors.verticalCenter: parent.verticalCenter
                                        verticalAlignment: Text.AlignVCenter
                                        // 文本样式
                                        color: Colors.color_EEEEEE
                                        selectionColor: Colors.color_EEEEEE
                                        selectedTextColor: Colors.color_1F2021
                                        font.pixelSize: kSubTitleSize
                                        horizontalAlignment: TextInput.AlignRight
                                        rightPadding: 0
                                        leftPadding: 0

                                        // 输入限制：只能输入数字
                                        validator: IntValidator {
                                            bottom: kMinScale
                                            top: kMaxScale
                                        }
                                        // 当焦点失去时
                                        onFocusChanged: {
                                            if (!focus) {
                                                if (text.length <= 0) {
                                                    if(textViewModel.scale !== 0.01)
                                                        textViewModel.scale = 0.01
                                                }else{
                                                    var newscale = parseInt(text);
                                                    if (!isNaN(newscale)) {
                                                        if (newscale < kMinScale) {
                                                            newscale = kMinScale;
                                                        } else if (newscale > kMaxScale) {
                                                            newscale = kMaxScale;
                                                        }
                                                        var newValue = newscale / 100.0;
                                                        if(textViewModel.scale !== newValue){
                                                            var oldValue = textViewModel.scale
                                                            textViewModel.scale = newValue
                                                            textViewModel.addUndoAction(kScale, oldValue, newValue);
                                                        }else{
                                                            textViewModel.scale = textViewModel.scale;
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                        Keys.onShortcutOverride: function(event) {
                                            if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                                                focus = false;
                                                event.accepted = true // 阻止其他组件处理
                                            }
                                        }
                                        Keys.onReturnPressed: {
                                            focus = false
                                        }
                                        Keys.onEscapePressed: {
                                            focus = false
                                        }
                                        // 键盘输入处理
                                        Keys.onPressed: function(event) {
                                            // 允许退格、删除、方向键等控制键
                                            if (event.key === Qt.Key_Backspace ||
                                                event.key === Qt.Key_Delete ||
                                                event.key === Qt.Key_Left ||
                                                event.key === Qt.Key_Right ||
                                                event.key === Qt.Key_Home ||
                                                event.key === Qt.Key_End ||
                                                event.key === Qt.Key_Tab ||
                                                event.key === Qt.Key_Enter ||
                                                event.key === Qt.Key_Return ||
                                                event.key === Qt.Key_Escape) {
                                                return;
                                            }

                                            if (event.text < '0' || event.text > '9') {
                                                event.accepted = false;
                                            }
                                        }
                                    }
                                    Text {
                                        id: scaleDescText
                                        height: 24
                                        width: contentWidth
                                        anchors.left: scaleTextField.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "%"
                                        horizontalAlignment: Text.AlignLeft
                                        verticalAlignment: Text.AlignVCenter
                                        color: Colors.color_EEEEEE
                                        font.pixelSize: kSubTitleSize
                                        rightPadding: 0
                                        leftPadding: 0
                                    }
                                }
                            }

                            Item{
                                id: scaleAdjustContainer
                                height: parent.height
                                width: 10
                                anchors{
                                    right: parent.right
                                }

                                Image{
                                    id: scaleUpBtn
                                    anchors{
                                        top: parent.top
                                        topMargin: 1
                                    }
                                    source: "qrc:/icons/ic_next_up.svg"
                                    sourceSize: Qt.size(10, 10)
                                    opacity: 1

                                    MouseArea {
                                        id: scaleUpMouseArea
                                        anchors.fill: parent
                                        onClicked: {
                                            forceActiveFocus()
                                            var oldValue = textViewModel.scale;
                                            textViewModel.scale = Math.min(textViewModel.scale + 0.01, 10);
                                            textViewModel.addUndoAction(kScale, oldValue, textViewModel.scale);
                                        }
                                    }
                                }

                                Image{
                                    id: scaleDownBtn
                                    anchors{
                                        bottom: parent.bottom
                                        bottomMargin: 1
                                    }
                                    source: "qrc:/icons/ic_next_down.svg"
                                    sourceSize: Qt.size(10, 10)
                                    opacity: 1
                                    MouseArea {
                                        id: scaleDownMouseArea1
                                        anchors.fill: parent
                                        onClicked: {
                                            forceActiveFocus()
                                            var oldValue = textViewModel.scale;
                                            textViewModel.scale = Math.max(textViewModel.scale - 0.01, 0.01);
                                            textViewModel.addUndoAction(kScale, oldValue, textViewModel.scale);
                                        }
                                    }
                                }
                            }
                        }


                        //位置
                        Rectangle {
                            id: posXYRectangle
                            width: parent.width
                            height: 24
                            color: Colors.color_transparent
                            anchors.left: parent.left
                            anchors.top: scaleRectangle.bottom
                            anchors.topMargin: 12

                            Text {
                                id: posXYLabel
                                width: 48; height: 16
                                text: qsTr("pccut_word_edit_font_loction_1")
                                font.pixelSize: kSubTitleSize
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.topMargin: 4
                                horizontalAlignment: Text.AlignLeft
                                color: Colors.color_999999

                                elide: Text.ElideRight
                                LightToolTip {
                                    visible: mouseAreaPosXYLabel.containsMouse && (posXYLabel.truncated)
                                    tip: posXYLabel.text
                                    z: 200
                                    y: parent.height + 10
                                }
                                MouseArea {
                                    id: mouseAreaPosXYLabel
                                    anchors.fill: parent
                                    hoverEnabled: true
                                }
                            }

                            Text {
                                id: xLabel
                                width: 8; height: 16
                                text: "X"
                                font.pixelSize: 12
                                anchors{
                                    left: posXYLabel.right; leftMargin: kSubTitleSize;
                                    top: parent.top; topMargin: 4
                                    //verticalCenter: parent.verticalCenter
                                }
                                horizontalAlignment: Text.AlignLeft
                                color: Colors.color_999999
                            }
                            AutoAdjustTextEdit {
                                id: xRectange
                                width: 56
                                height: 24
                                dragCoeff: 5
                                minValue: root.kMinTranslateX
                                maxValue: root.kMaxTranslateX
                                accurate: 0
                                fontSize: kSubTitleSize
                                bInt: true    //编辑时显示整数
                                value: {
                                    var num = textViewModel.translate.x * kBaseWidth
                                    return Math.round(num);
                                }
                                anchors {
                                    //verticalCenter: parent.verticalCenter
                                    top: parent.top; topMargin: 1
                                    left: xLabel.right; leftMargin: 8
                                }

                                onRelease: {
                                    var tempOldValue = 1.0 * oldValue / kBaseWidth;
                                    textViewModel.addUndoAction(kTranslate, Qt.point(tempOldValue, textViewModel.translate.y),
                                                                            textViewModel.translate)
                                }
                                Connections {
                                    target: xRectange
                                    function onArgumentChanged(value, itemIndex, isEditing) {
                                        var tempOldValue = textViewModel.translate.x;
                                        textViewModel.translate.x = 1.0*value/kBaseWidth;
                                        if(isEditing){
                                            textViewModel.addUndoAction(kTranslate, Qt.point(tempOldValue, textViewModel.translate.y),
                                                                                    textViewModel.translate)
                                        }

                                    }
                                }
                            }


                            Text {
                                id: yLabel
                                width: 8; height: 16
                                text: "Y"
                                font.pixelSize: kSubTitleSize
                                anchors{
                                    left: xRectange.right; leftMargin: 4 //20
                                    top: parent.top; topMargin: 4
                                    //verticalCenter: parent.verticalCenter
                                }
                                horizontalAlignment: Text.AlignLeft
                                color: Colors.color_999999
                            }

                            AutoAdjustTextEdit {
                                id: yRectange
                                width: 56
                                height: 24
                                dragCoeff: 5
                                accurate: 0
                                fontSize: kSubTitleSize
                                bInt: true    //编辑时显示整数
                                minValue: root.kMinTranslateY
                                maxValue: root.kMaxTranslateY
                                value: {
                                    var num = textViewModel.translate.y * kBaseHeight
                                    //return num.toFixed(1);
                                    return Math.round(num);
                                }
                                property bool isStart: false
                                property real beforeMouseDeltaX: 0

                                anchors {
                                    left: yLabel.right; leftMargin: 8
                                    top: parent.top; topMargin: 1
                                }

                                onRelease: {
                                    var tempOldValue = 1.0 * oldValue / kBaseHeight;
                                    textViewModel.addUndoAction(kTranslate, Qt.point(textViewModel.translate.x, tempOldValue),
                                                                            textViewModel.translate)
                                }

                                Connections {
                                    target: yRectange
                                    function onArgumentChanged(value, itemIndex, isEditing) {
                                        var tempOldValue = textViewModel.translate.y;
                                        textViewModel.translate.y = 1.0*value/kBaseHeight;
                                        if(isEditing){
                                            textViewModel.addUndoAction(kTranslate, Qt.point(textViewModel.translate.x, tempOldValue),
                                                                                    textViewModel.translate)
                                        }
                                    }
                                }
                            }
                        }

                        //旋转
                        Rectangle {
                            id: rotateRectangle
                            width: parent.width
                            height: 24
                            color: Colors.color_transparent
                            anchors.left: parent.left
                            anchors.top: posXYRectangle.bottom
                            anchors.topMargin: 12

                            Text {
                                id: rotateLabel
                                width: 48; height: 16
                                text: qsTr("pccut_word_edit_font_roll")
                                font.pixelSize: kSubTitleSize
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.topMargin: 4
                                horizontalAlignment: Text.AlignLeft
                                color: Colors.color_999999

                                elide: Text.ElideRight
                                LightToolTip {
                                    visible: mouseAreaRotateLabel.containsMouse && (rotateLabel.truncated)
                                    tip: rotateLabel.text
                                    z: 200
                                    y: parent.height + 10
                                }
                                MouseArea {
                                    id: mouseAreaRotateLabel
                                    anchors.fill: parent
                                    hoverEnabled: true
                                }
                            }

                            Rectangle {
                                id: rotate1Rectange
                                width: 90
                                height: 24
                                anchors {
                                    left: rotateLabel.right; leftMargin: 8
                                    top: parent.top; topMargin: 0
                                }
                                color: Colors.transparent
                                radius: 4

                                AutoAdjustTextEdit {
                                    id: rotateAdjustTextEdit
                                    width: 37
                                    height: 24
                                    dragCoeff: 1
                                    fontSize: kSubTitleSize
                                    enableMulpleText: true
                                    showDegree: true
                                    value: textViewModel.rotate
                                    anchors {
                                        left: rotate1Rectange.left
                                        leftMargin: 4
                                        top: parent.top
                                    }


                                    onRelease: {
                                        textViewModel.addUndoAction(kRotate, oldValue, textViewModel.rotate)
                                    }
                                    Connections {
                                        target: rotateAdjustTextEdit
                                        function onArgumentChanged(value, itemIndex, isEditing) {
                                            var tempOldValue = textViewModel.rotate;
                                            textViewModel.rotate = value;
                                            if(isEditing){
                                                textViewModel.addUndoAction(kRotate, tempOldValue, textViewModel.rotate)
                                            }
                                        }
                                    }
                                }
                            }
                        }


                        // 布局
                        Row{
                            id: alignmentTypeRow
                            width: 256
                            height: 24
                            anchors.left: parent.left
                            anchors.top: rotateRectangle.bottom
                            anchors.topMargin: 12
                            spacing: 12

                            Text{
                                id: alignmentTypeLabel
                                text: qsTr("pccut_word_alignment_image_title")
                                width: 48; height: 16
                                font.pixelSize: kSubTitleSize
                                horizontalAlignment: Text.AlignLeft
                                anchors.verticalCenter: parent.verticalCenter
                                color: Colors.color_999999

                                elide: Text.ElideRight
                                LightToolTip {
                                    visible: mouseAreaAlignmentTypeLabel.containsMouse && (alignmentTypeLabel.truncated)
                                    tip: alignmentTypeLabel.text
                                    z: 200
                                    y: parent.height + 10
                                }
                                MouseArea {
                                    id: mouseAreaAlignmentTypeLabel
                                    anchors.fill: parent
                                    hoverEnabled: true
                                }
                            }

                            Rectangle{
                                width: 197; height: 24;
                                color: Colors.color_2F3032
                                radius: 4
                                clip: true

                                Row{
                                    spacing: 1
                                    anchors.left: parent.left
                                    anchors.leftMargin: 0
                                    anchors.rightMargin: 0
                                    anchors.verticalCenter: parent.verticalCenter

                                    Repeater{
                                        id: alignmentTypeRepeater
                                        model: [
                                            {
                                                name: qsTr("pccut_word_alignment_left"),
                                                imagePath: "qrc:/icons/textSetting/ic_text_align_left.svg",
                                                alignment: TextViewModel.TEXT_ALIGNMENT_LEFT
                                            },
                                            {
                                                name: qsTr("pccut_word_alignment_center"),
                                                imagePath: "qrc:/icons/textSetting/ic_text_align_hcenter.svg",
                                                alignment: TextViewModel.TEXT_ALIGNMENT_HCENTER
                                            },
                                            {
                                                name: qsTr("pccut_word_alignment_right"),
                                                imagePath: "qrc:/icons/textSetting/ic_text_align_right.svg",
                                                alignment: TextViewModel.TEXT_ALIGNMENT_RIGHT
                                            },
                                            {
                                                name: qsTr("pccut_word_alignment_top"),
                                                imagePath: "qrc:/icons/textSetting/ic_text_align_top.svg",
                                                alignment: TextViewModel.TEXT_ALIGNMENT_TOP
                                            },
                                            {
                                                name: qsTr("pccut_word_alignment_vertical"),
                                                imagePath: "qrc:/icons/textSetting/ic_text_align_vcenter.svg",
                                                alignment: TextViewModel.TEXT_ALIGNMENT_VCENTER
                                            },
                                            {
                                                name: qsTr("pccut_word_alignment_bottom"),
                                                imagePath: "qrc:/icons/textSetting/ic_text_align_bottom.svg",
                                                alignment: TextViewModel.TEXT_ALIGNMENT_BOTTOM
                                            },
                                        ]
                                        Rectangle{
                                            width: 32; height: 24
                                            color: mouseAreaAlignmentTypeImage.containsMouse ? Colors.color_37383A : Colors.color_2F3032
                                            radius: 4
                                            Image{
                                                id: alignmentTypeImage
                                                width: 16
                                                height: 16
                                                source: modelData.imagePath
                                                anchors.centerIn: parent
                                                LightToolTip {
                                                    visible: mouseAreaAlignmentTypeImage.containsMouse
                                                    tip: modelData.name
                                                    z: 200
                                                    y: parent.height + 10
                                                }
                                                ColorOverlay {
                                                    anchors.fill: parent
                                                    source: parent
                                                    color: {
                                                        // 根据mouseAreaAlignmentTypeImage，如果鼠标按下，返回enableColor，否则返回disableColor
                                                        return mouseAreaAlignmentTypeImage.pressed ? Colors.color_FFFFFF : Colors.color_EEEEEE
                                                    }
                                                }
                                            }
                                            MouseArea {
                                                id: mouseAreaAlignmentTypeImage
                                                anchors.fill: parent
                                                hoverEnabled: true

                                                onClicked: {
                                                    // 通知播放器调整文字位置
                                                    textViewModel.adjustTextPosition(modelData.alignment)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Item {
                    id: bottomSpace
                    width: scrollView.width
                    height: 16
                }
            }
        }

        ScrollBar.vertical.onPositionChanged: {
            if(bOpenColorPopUp){
                closeColorPopup();
            }
            if(bOpenFontPopUp){
                closeFontPopup();
            }
        }
    }
    // Loader 方式加载 popup，延迟初始化以加快启动速度
    Loader {
        id: fontPopupLoader
        active: false
        asynchronous: false
        source: "SelectFontPopup.qml"
    }

    Loader {
        id: colorPopupLoader
        active: false
        asynchronous: false
        source: "SelectColorPopup.qml"
    }

    // 代理属性，保持原有接口兼容性
    readonly property var fontPopup: fontPopupLoader.item
    readonly property var selectColorPopup: colorPopupLoader.item

    // 便利函数：确保 popup 已加载
    function ensureFontPopupLoaded() {
        if (!fontPopupLoader.active) {
            fontPopupLoader.active = true;
        }
    }

    function ensureColorPopupLoaded() {
        if (!colorPopupLoader.active) {
            colorPopupLoader.active = true;
        }
    }

    // 便利函数：打开字体 popup
    function openFontPopupAt(x, y, fontName) {
        ensureFontPopupLoaded();
        if (root.fontPopup) {
            root.fontPopup.x = x;
            root.fontPopup.y = y;
            root.fontPopup.curFontName = fontName;
            root.fontPopup.finishFontName = fontName;
            root.fontPopup.width = root.width - 24;
            root.fontPopup.open();
            root.bOpenFontPopUp = true;
        }
    }

    // 便利函数：关闭字体 popup
    function closeFontPopup() {
        if (root.fontPopup) {
            root.fontPopup.close();
            root.bOpenFontPopUp = false;
        }
    }

    // 便利函数：打开颜色 popup
    function openColorPopupAt(x, y, color) {
        ensureColorPopupLoaded();
        if (root.selectColorPopup) {
            root.selectColorPopup.x = x;
            root.selectColorPopup.y = y;
            root.selectColorPopup.currentColor = color;
            root.selectColorPopup.width = root.width - 24;
            root.selectColorPopup.open();
            root.bOpenColorPopUp = true;
        }
    }

    // 便利函数：关闭颜色 popup
    function closeColorPopup() {
        if (root.selectColorPopup) {
            root.selectColorPopup.close();
            root.bOpenColorPopUp = false;
        }
    }

}
