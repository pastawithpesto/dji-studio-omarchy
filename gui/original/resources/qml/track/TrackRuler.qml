import QtQuick 2.12
import QtQuick.Window 2.12
import Config 1.0

/**
为了维护标尺的逻辑简单，策略相关的逻辑不在本控件实现，本控件只根据外部指定的比例尺和开始的位置，一直画满整个视图
*/
Rectangle {
    id: trackRulerRoot
    color: Colors.color_1F2021
    clip: true

    property int fps: 30
    property int groupSlots: 5
    property int slotFrames: 5
    // px per frame
    property real scaleBase: 5
    property real scrollX: 0
    // 小刻度的尺寸
    property size slotMarkSize: Qt.size(1, 4)
    // 小刻度的颜色
    property color slotMarkColor: Colors.color_56575B
    // 大刻度的尺寸
    property size groupMarkSize: Qt.size(1, 14)
    // 大刻度的颜色
    property color groupMarkColor: Colors.color_68696D
    // 时间戳的x,y
    property int timestampMarginLeft: 5
    property int timestampMarginTop: 2
    // 展示时间的size
    property int timestampSize: 10
    // 展示时间的颜色
    property color timestampColor: Colors.color_68696D
    // 刻度尺距离左侧的宽度，之所以会定义这个属性原因是因为刻度尺可能左侧有一段空白区域，但是滑动之后仍然需要展示，类似RecyclerView的paddingLeft
    property real paddingLeft: 0
    // 拖拽的时候只透过刻度文字, 样式不太好看, 为了不做结构的变动, 所以这里加了背景色
    // 本控件自己的private属性
    QtObject {
        id: attr

        property int slotCount: 0
        property int groupCount: 0
        property real slotWidth: 0
        property real groupWidth: 0
        property int groupFrames: 0
        property int firstGroupMarkFrameIndex: 0
        // 当前视口首根可见 slot 的绝对序号(自 paddingLeft 起算)：slot delegate 的 index 是视口相对序号，
        // 滚动后首根未必是大刻度，须用绝对序号 (firstSlotMarkIndex+index)%groupSlots 才能稳定判定大刻度位置。
        property int firstSlotMarkIndex: 0

        Component.onCompleted: {
            trackRulerRoot.refreshData();
        }
    }

    onWidthChanged: {
        refreshData();
    }

    onScrollXChanged: {
        // @author zhongshan.wang
        // 首个大刻度序号必须从逻辑滚动量直接计算并取整，不能用被视觉修正过(减半线宽/dpr吸附/未扣paddingLeft)的
        // groupRow.x 像素位置反推，否则截断取整会在跨大刻度边界时偏移一格。写法与下方 firstSlotMarkIndex 对齐。
        attr.firstGroupMarkFrameIndex = scrollX < paddingLeft ? 0 : Math.floor((scrollX - paddingLeft) / attr.groupWidth);
        attr.firstSlotMarkIndex = scrollX < paddingLeft ? 0 : Math.floor((scrollX - paddingLeft) / attr.slotWidth);
    }

    function refreshData() {
        attr.slotCount = Math.ceil((width / scaleBase / slotFrames + 10) / 100) * 100;
        attr.groupCount = Math.ceil(attr.slotCount / groupSlots);
        attr.slotWidth = slotFrames * scaleBase;
        attr.groupWidth = groupSlots * attr.slotWidth;
        attr.groupFrames = groupSlots * slotFrames;
        attr.firstGroupMarkFrameIndex = scrollX < paddingLeft ? 0 : Math.floor((scrollX - paddingLeft) / attr.groupWidth);
        attr.firstSlotMarkIndex = scrollX < paddingLeft ? 0 : Math.floor((scrollX - paddingLeft) / attr.slotWidth);
    }

    // slot component
    Component {
        id: slotMarkItem

        Rectangle {
            id: markLine

            width: slotMarkSize.width
            height: slotMarkSize.height
            radius: slotMarkSize.width
            color: slotMarkColor
            // 大刻度位置(每 groupSlots 个 slot)由 group 长线绘制，此处短线不画：dpr 对齐后两线精确重合，
            // 圆角/抗锯齿边缘会露出短线。用绝对序号(firstSlotMarkIndex+index)判定——index 是视口相对序号，
            // 滚动后首根未必是大刻度，只用 index%groupSlots 会时对时偏。用 opacity 而非 visible——Row 定位器
            // 跳过 visible:false 项会塌缩间距致后续刻度错位。
            opacity: (attr.firstSlotMarkIndex + index) % groupSlots === 0 ? 0 : 1
        }

    }

    // group component
    Component {
        id: groupMarkItem

        Rectangle {
            id: markLine

            width: groupMarkSize.width
            height: groupMarkSize.height
            radius: groupMarkSize.width
            color: groupMarkColor
        }

    }

    // timestamp component
    Component {
        id: textItem

        Item {
            width: attr.groupWidth
            height: text.height

            Text {
                id: text
                function _calculateTimestamp(groupIndex) {
                    const frameIndex = attr.groupFrames * groupIndex;
                    const restFrames = frameIndex % fps;
                    // 不到整数秒，展示当前group(1s)内的帧数
                    return restFrames == 0 ? DurationFormatter.format(frameIndex, fps, false, false) : restFrames + "f";
                }

                text: _calculateTimestamp(attr.firstGroupMarkFrameIndex + index)
                color: timestampColor

                font {
                    pixelSize: timestampSize
                }

            }

        }

    }

    // draw slot
    Row {
        // 刻度线左对齐会使其视觉中心比帧线右偏半个线宽；减半宽让线中心对齐帧栅格，再按 dpr 吸附物理像素网格(同 snappingLine/预览轴)，跨平台清晰不发虚
        x: {
            let raw = (scrollX < paddingLeft ? paddingLeft - scrollX : -((scrollX - paddingLeft) % attr.slotWidth)) - slotMarkSize.width / 2;
            let dpr = Screen.devicePixelRatio;
            return Math.round(raw * dpr) / dpr;
        }
        visible: attr.slotCount < 1000
        width: parent.width
        height: parent.height
        spacing: attr.slotWidth - slotMarkSize.width

        Repeater {
            model: attr.slotCount
            delegate: slotMarkItem
        }
    }

    // draw group
    Row {
        id: groupRow
        // 同 slot：减半个线宽让大刻度线中心对齐帧栅格，再按 dpr 吸附物理像素网格
        x: {
            let raw = (scrollX < paddingLeft ? paddingLeft - scrollX : -((scrollX - paddingLeft) % attr.groupWidth)) - groupMarkSize.width / 2;
            let dpr = Screen.devicePixelRatio;
            return Math.round(raw * dpr) / dpr;
        }
        visible: attr.slotCount < 1000
        width: parent.width
        height: parent.height
        spacing: attr.groupWidth - groupMarkSize.width

        Repeater {
            model: attr.groupCount
            delegate: groupMarkItem
        }

    }

    // draw timestamp
    Row {
        x: groupRow.x + timestampMarginLeft
        y: timestampMarginTop
        visible: attr.slotCount < 1000
        width: parent.width
        height: parent.height

        Repeater {
            model: attr.groupCount
            delegate: textItem
        }

    }

}
