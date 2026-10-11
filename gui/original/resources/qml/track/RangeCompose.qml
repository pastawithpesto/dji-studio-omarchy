import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Shapes 1.15
import Qt5Compat.GraphicalEffects
import TrackDockViewModel 1.0
import TrackHeadViewModel 1.0
import TrackHeadListViewModel 1.0
import CursorHelper 1.0
import MultiTrackView 1.0
import MultiTrackDataProvider 1.0
import AddOrDeleteFragmentController 1.0
import MultiSelectController 1.0
import Config 1.0
import Controls 1.0
import ShortcutAction 1.0
import "../tracking"
import "../controller"
import QTractorType 1.0
import LightRectangle 1.0
import KeyframeBtnViewModel 1.0
import QPlayType 1.0
import SnappingTypeModel 1.0
import MediaTypeModel 1.0
import MediaListViewModel 1.0
import Qt.labs.platform 1.1
import Clipboard 1.0
import app_qrc 1.0

Item {
    property real scaleBase: 1
    property bool enableRangeCompose: false
    property bool isSelectFragment: false
    property real inRangeCompose: 0
    property real outRangeCompose: 0
    property real scrollX: 0
    property real contentWidth: 0
    property real paddingLeft: 0
    property real totalFrame: 0
    property real indicatorDragWidth: 3
    property real cancelButtonWidth: 116
    property real fps: 1
    property real indicatorX: 0

    property string inRangeComposeTimeText: ""
    property string outRangeComposeTimeText: ""

    property bool inRangeComposeStartDrag: false
    property bool outRangeComposeStartDrag: false

    property bool allowInRangeComposeDrag: true
    property bool allowOutRangeComposeDrag: true

    signal rangeComposeInUpdate(real newIndicatorIn)
    signal rangeComposeOutUpdate(real newIndicatorOut)

    signal rangeComposeInDrag(real newIndicatorIn)
    signal rangeComposeOutDrag(real newIndicatorOut)

    signal rangeComposeEnableChanged(bool rangeComposeEnable)

    id: root
    width: parent.width
    CursorHelper {
        id: cursorhelper
    }
    // clip: true
    // 范围导出左侧区域
    Rectangle {
        id: rangeComposeLeft
        width: scaleBase * inRangeCompose - scrollX
        height: parent.height
        x: 0
        visible: !isSelectFragment
        color: Colors.color_000000
        opacity: 0.5
    }
    // 范围导出-入指示器
    Rectangle {
        id: inIndicator
        width: 2
        height: parent.height
        x: scaleBase * inRangeCompose - scrollX
        visible: true
        color: Colors.transparent
        Shape{
            anchors.fill: parent
            height: parent.height
            ShapePath {
                strokeColor: Colors.color_EEEEEE_15
                strokeWidth: 1
                fillColor: Colors.transparent
                strokeStyle: ShapePath.DashLine
                dashPattern: [2, 2]
                startX: 0
                startY: 0
                PathLine { x: 0; y: root.height }
            }
            ShapePath {
                strokeColor: Colors.color_F22443
                strokeWidth: 1
                fillColor: Colors.transparent
                strokeStyle: ShapePath.SolidLine
                dashPattern: [2, 2]
                startX: 0
                startY: 0
                PathLine { x: 0; y: 8 }
            }
        }
        ToolTip {
            id: inRangeComposeTime
            x: -(inRangeComposeTimeTextBox.implicitWidth/2 +8)
            y: 20
            width: inRangeComposeTimeTextBox.implicitWidth + 16
            height: 27
            visible: false
            // 背景
            background: LightClipRectangle {
                anchors.fill: parent
                clip: true
                radius: [4,4,4,4]
                Rectangle {
                    anchors.fill: parent
                    border.color: Colors.color_454649
                    border.width: 1
                    color: Colors.color_19191A
                    radius: 4
                }
            }
            contentItem: Text {
                id: inRangeComposeTimeTextBox
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                anchors.topMargin: 6
                anchors.bottomMargin: 6
                font.pixelSize: 11
                text: inRangeComposeTimeText
                color: Colors.color_EEEEEE
            }
        }
    }
    // 范围导出-入指示器拖拽区域
    Rectangle {
        id: inIndicatorDrag
        width: indicatorDragWidth
        height: parent.height
        x: scaleBase * inRangeCompose - scrollX - indicatorDragWidth
        visible: true
        color: Colors.transparent
        MouseArea {
            id: inIndicatorDragArea
            anchors.fill: parent
            drag.target: inIndicatorDrag
            drag.axis: Drag.XAxis
            drag.threshold: 0
            drag.minimumX: - indicatorDragWidth
            drag.maximumX: scaleBase * outRangeCompose - scrollX - indicatorDragWidth
            propagateComposedEvents: true
            hoverEnabled: true
            // cursorShape: Qt.SizeHorCursor
            onEntered: {
                //拖动过程中，允许拖动，优先级更高，使用鼠标按键，drag.active可能在拖动过程中失效；重叠时，不允许拖动
                if(inIndicatorDragArea.pressed === false && Math.abs(indicatorX + 3.5 - (scaleBase * inRangeCompose)) <= 3) {
                    inIndicatorDrag.enabled = false;
                    return;
                }
                inIndicatorDrag.enabled = true;
                if(allowOutRangeComposeDrag === true && inRangeComposeStartDrag === false) {
                    cursorhelper.setCustomCursor(":/icons/ic_cutleft.svg", 24, 24);
                    inRangeComposeStartDrag = true;
                }
            }
            onExited: {
                //需要重置鼠标手势且未点击鼠标左键
                if(inRangeComposeStartDrag === true && inIndicatorDragArea.pressed === false) {
                    cursorhelper.restoreOverrideCursor();
                    inRangeComposeStartDrag = false;
                }
            }
            onPressed:  (mouse) => {
                inRangeComposeTimeText = DurationFormatter.format(inRangeCompose, fps, false, false);
                inRangeComposeTime.visible = true;
            }
            onPositionChanged: (mouse) => {
               if(inIndicatorDragArea.drag.active) {
                    //因为入点指示器和拖动区域的右侧对齐，所以需要加拖动区域的宽度，确保位置决定正确
                    updateRangeComposeInLocation(inIndicatorDrag.x + scrollX + indicatorDragWidth);
                }
            }
            onReleased: (mouse)=> {
                //鼠标释放再保存草稿
                if (scaleBase <= 0) {
                    rangeComposeInDrag(-1);
                }else{
                    let newRangeInFrame = Math.max(0, Math.round((inIndicatorDrag.x + scrollX + indicatorDragWidth) / scaleBase));
                    newRangeInFrame = Math.min(newRangeInFrame, totalFrame)
                    rangeComposeInDrag(newRangeInFrame);
                }
                inRangeComposeTime.visible = false;
                //恢复鼠标样式
                if(inRangeComposeStartDrag === true) {
                    cursorhelper.restoreOverrideCursor();
                    inRangeComposeStartDrag = false;
                }
            }
            Connections {
                target: inIndicatorDragArea.drag
                function onActiveChanged() {
                    if (!inIndicatorDragArea.drag.active && rangeComposeInScrollTimer) {
                        rangeComposeInScrollTimer.stop();
                    }
                }
            }
        }
        onXChanged: {

        }
    }
    Rectangle {
        id: rangeComposeRegion
        x: scaleBase * inRangeCompose - scrollX
        width: scaleBase * outRangeCompose - scaleBase * inRangeCompose
        height: 8
        color: Colors.color_EEEEEE
        opacity: 0.1
    }
    //范围导出-出指示器
    Rectangle {
        id: outIndicator
        width: 2
        height: parent.height
        x:  scaleBase * outRangeCompose - scrollX
        visible: true
        color: Colors.transparent
        Shape{
            anchors.fill: parent
            ShapePath {
                strokeColor: Colors.color_EEEEEE_15
                strokeWidth: 1
                fillColor: Colors.transparent
                strokeStyle: ShapePath.DashLine
                dashPattern: [2, 2]
                startX: 0
                startY: 0
                PathLine { x: 0; y: root.height }
            }
            ShapePath {
                strokeColor: Colors.color_F22443
                strokeWidth: 1
                fillColor: Colors.transparent
                strokeStyle: ShapePath.SolidLine
                startX: 0
                startY: 0
                PathLine { x: 0; y: 8 }
            }
        }
        ToolTip {
            id: outRangeComposeTime
            x: -(outRangeComposeTimeTextBox.implicitWidth/2 +8)
            y: 20
            width:outRangeComposeTimeTextBox.implicitWidth + 16
            height: 27
            visible: false
            // 背景
            background: LightClipRectangle {
                anchors.fill: parent
                clip: true
                radius: [4,4,4,4]
                Rectangle {
                    anchors.fill: parent
                    border.color: Colors.color_454649
                    border.width: 1
                    color: Colors.color_19191A
                    radius: 4
                }
            }
            contentItem: Text {
                id: outRangeComposeTimeTextBox
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                anchors.topMargin: 6
                anchors.bottomMargin: 6
                font.pixelSize: 11
                text: outRangeComposeTimeText
                color: Colors.color_EEEEEE
            }
        }
    }
    //范围导出-出指示器拖拽区域
    Rectangle {
        id: outIndicatorDrag
        width: indicatorDragWidth
        height: parent.height
        x:  scaleBase * outRangeCompose - scrollX
        visible: true
        color: Colors.transparent
        MouseArea {
            id: outIndicatorDragArea
            anchors.fill: parent
            drag.target: outIndicatorDrag
            drag.axis: Drag.XAxis
            drag.threshold: 0
            drag.minimumX: scaleBase * inRangeCompose - scrollX
            drag.maximumX: scaleBase * totalFrame
            propagateComposedEvents: true
            hoverEnabled: true
            // cursorShape: Qt.SizeHorCursor
            onEntered: {
                if(outIndicatorDragArea.pressed === false && Math.abs(indicatorX + 3.5 - (scaleBase * outRangeCompose)) <= 3) {
                    outIndicatorDrag.enabled = false;
                    return;
                }
                outIndicatorDrag.enabled = true;
                if(allowOutRangeComposeDrag === true && outRangeComposeStartDrag == false) {
                    cursorhelper.setCustomCursor(":/icons/ic_cutright.svg", 24, 24);
                    outRangeComposeStartDrag = true;
                }
            }
            onExited: {
                if(outRangeComposeStartDrag === true && outIndicatorDragArea.pressed === false) {
                    cursorhelper.restoreOverrideCursor();
                    outRangeComposeStartDrag = false;
                }
            }
            onPressed:  (mouse) => {
                outRangeComposeTimeText = DurationFormatter.format(outRangeCompose, fps, false, false);
                outRangeComposeTime.visible = true;
            }
            onPositionChanged: (mouse) => {
                if(outIndicatorDragArea.drag.active) {
                    updateRangeComposeOutLocation(outIndicatorDrag.x + scrollX);
                }
            }
            onReleased: (mouse)=> {
                //鼠标释放再保存草稿
                if (scaleBase <= 0) {
                    rangeComposeOutDrag(-1);
                }else{
                    let newRangeOutFrame = Math.max(0, Math.round((outIndicatorDrag.x + scrollX) / scaleBase));
                    newRangeOutFrame = Math.min(newRangeOutFrame, totalFrame)
                    rangeComposeOutDrag(newRangeOutFrame);
                }
                outRangeComposeTime.visible = false;
                if(outRangeComposeStartDrag === true) {
                    cursorhelper.restoreOverrideCursor();
                    outRangeComposeStartDrag = false;
                }
            }
        }
        onXChanged: {

        }
        Connections {
            target: outIndicatorDragArea.drag
            function onActiveChanged() {
                if (!outIndicatorDragArea.drag.active && rangeComposeOutScrollTimer) {
                    rangeComposeOutScrollTimer.stop();
                }
            }
        }
    }
    // 范围导出右侧区域
    Rectangle {
        id: rangeComposeRight
        x: scaleBase * outRangeCompose - scrollX
        width: contentWidth - scaleBase * outRangeCompose
        height: parent.height
        visible: !isSelectFragment
        color: Colors.color_000000
        opacity: 0.5
    }
    Button {
        id: inCancelButton
        x: scaleBase * inRangeCompose - scrollX - inCancelButton.width - 12
        y: 12
        width: {
            if(scaleBase * inRangeCompose - scrollX < 140) {
                return 40;
            } else {
                return cancelButtonWidth;
            }
        }
        height: 32
        visible: {
            if(isSelectFragment) {
                return false;
            }
            if(scaleBase * inRangeCompose - scrollX < 64) {
                return false;
            }
            return true;
        }
        text: {
            if(scaleBase * inRangeCompose - scrollX < 140) {
                return "";
            }
            return qsTr("pccut_track_scope_cancel");
        }
        palette {
            buttonText: Colors.color_EEEEEE
        }
        icon {
            width: 17
            height: 12
            source: "qrc:/icons/rangeCompose/cancel_range_btn.svg"
        }
        // 设置按钮的背景
        background: Rectangle {
            id: inCancelButtonBackgound
            color: parent.hovered?Colors.color_37383A:Colors.color_2F3032
            radius: 6
            opacity: 0.9
        }
        onClicked: {
            rangeComposeEnableChanged(false);
        }
        LightToolTip {
            visible: inCancelButton.hovered
            tip: qsTr("pccut_track_scope_tip_1")
            z: 200
        }
    }
    //取消按钮
    Button {
        id: outCancelButton
        x: scaleBase * outRangeCompose - scrollX + 12
        y: 12
        width: {
            if(parent.width - (scaleBase * outRangeCompose - scrollX) < 140) {
                return 40;
            } else {
                return cancelButtonWidth;
            }
        }
        height: 32
        visible: {
            if(isSelectFragment) {
                return false;
            }
            if(parent.width - (scaleBase * outRangeCompose - scrollX) < 64) {
                return false;
            }
            return true;
        }
        text: {
            if(parent.width - (scaleBase * outRangeCompose - scrollX) < 140) {
                return "";
            }
            return qsTr("pccut_track_scope_cancel");
        }
        palette {
            buttonText: Colors.color_EEEEEE
        }
        icon {
            width: 17
            height: 12
            source: "qrc:/icons/rangeCompose/cancel_range_btn.svg"
        }
        // 设置按钮的背景
        background: Rectangle {
            id: outCancelButtonBackground
            color: parent.hovered?Colors.color_37383A:Colors.color_2F3032
            radius: 6
            opacity: 0.9
        }
        onClicked: {
            rangeComposeEnableChanged(false);
        }
        LightToolTip {
            visible: outCancelButton.hovered
            tip: qsTr("pccut_track_scope_tip_1")
            z: 200
        }
    }

    function updateRangeComposeInLocation(newRangeIn) {
        if(enableRangeCompose) {
            if(newRangeIn <= outIndicator.x + scrollX && newRangeIn >= 0) {
                if (scaleBase <= 0) {
                    return;
                }
                let newRangeInFrame = Math.max(0, Math.round(newRangeIn / scaleBase));
                newRangeInFrame = Math.min(newRangeInFrame, totalFrame);
                inRangeComposeTimeText = DurationFormatter.format(newRangeInFrame, fps, false, false)
                rangeComposeInUpdate(newRangeInFrame);
            }
        }
    }

    function updateRangeComposeOutLocation(newRangeOut) {
        if(enableRangeCompose) {
            if(newRangeOut >= inIndicator.x + scrollX && newRangeOut <= scaleBase * totalFrame) {
                if (scaleBase <= 0) {
                    return;
                }
                let newRangeOutFrame = Math.max(0, Math.round(newRangeOut / scaleBase));
                outRangeComposeTimeText = DurationFormatter.format(newRangeOutFrame, fps, false, false)
                newRangeOutFrame = Math.min(newRangeOutFrame, totalFrame)
                rangeComposeOutUpdate(newRangeOutFrame);
            }
        }
    }
    //inIndicator和outIndicator变化时，联动其他控件变化
    function updateRangeComposeViewLocation() {
        //建议全部使用属性绑定的方式实现交互功能，以下代码都是绑定失效的情况
        inIndicatorDrag.x = scaleBase * inRangeCompose - indicatorDragWidth - scrollX;
        outIndicatorDrag.x = scaleBase * outRangeCompose - scrollX;
    }
}
