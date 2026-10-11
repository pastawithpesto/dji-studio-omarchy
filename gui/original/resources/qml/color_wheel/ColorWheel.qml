import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Window 2.15
import Config 1.0
import CursorHelper 1.0

Item {
    id: wheelRoot

    CursorHelper {
        id: cursorHelper
    }

    property bool _isDestroying: false

    // 组件销毁时（如切换轨道片段）兜底还原光标，避免残留的自定义 override 光标（竖直箭头等）永久卡住。
    Component.onDestruction: {
        _isDestroying = true;
        cursorHelper.restoreAllOverrideCursors();
    }

    // 全局兜底：鼠标离开整个色轮时还原光标。
    // 仅在无进行中交互（拖拽 / warp / tooltip实际hover或编辑）时还原，避免误清合法光标。
    HoverHandler {
        id: rootHover
        onHoveredChanged: {
            if (hovered) return;
            if (wheelMouseArea.isDragMode || arcMouseArea.activeArc !== arcTypeNone
                    || arcMouseArea.isWarpingCursor || wheelMouseArea.isWarpingCursor
                    || rgbMouseArea.dragBox || rgbMouseArea.isWarpingCursor
                    || satTooltip.editing || expTooltip.editing
                    || satTooltip.tooltipContainsMouse || satTooltip.bridgeContainsMouse
                    || expTooltip.tooltipContainsMouse || expTooltip.bridgeContainsMouse)
                return;
            arcMouseArea.isHoveringArcHandle = false;
            arcMouseArea.hoveredArcHandle = null;
            cursorHelper.restoreAllOverrideCursors();
        }
    }

    // ── 弧形滑针类型常量 ──
    readonly property string arcTypeSaturation: "sat"
    readonly property string arcTypeExposure: "exp"
    readonly property string arcTypeNone: ""

    // ── 弧形滑针绘制参数 ──
    readonly property real arcPointerLength: 6.0       // 滑针三角形箭头长度（滑针图标宽为7，此值为减去透明部分后的实际宽度）
    readonly property real arcPointerWidth: 7.6        // 滑针三角形底部宽度（滑针图标高为8，此值为减去透明部分后的实际高度）
    readonly property real arcPointerHitLength: arcPointerLength + 1    // 滑针hover检测三角形箭头长度（绘制+1px）
    readonly property real arcPointerHitWidth: arcPointerWidth + 1      // 滑针hover检测三角形底部宽度（绘制+1px）

    // ── 色轮控制点参数 ──
    readonly property real hueHandleGrabDist: 3      // 色轮控制点捕获距离（px）
    readonly property real rgbEpsilon: 0.005         // RGB 精度阈值（2位小数的一半）
    readonly property real dragSensitivity: 18       // 拖拽灵敏度降低系数（鼠标移动量 / 系数 = 实际移动量）

    readonly property real angleToRadians: Math.PI / 180.0          // π / 180
    readonly property real radiansToAngle: 180.0 / Math.PI          // 180 / π
    readonly property real rotateAngle: 120                         // 色环默认旋转角度，逆时针方向
    readonly property real rotateRadian: rotateAngle * angleToRadians
    readonly property real basePhase:  Math.PI * 2 / 3              // 色相矢量 RGB 轴相隔（120°）
    readonly property real redPhase:   rotateRadian                 // Red 相位
    readonly property real greenPhase: rotateRadian + basePhase * 1 // Green 相位
    readonly property real bluePhase:  rotateRadian + basePhase * 2 // Blue 相位

    // ── UI 参数 ──
    readonly property int cursorIconSize: 16
    property string title: ""
    property string tooltipText: ""
    property bool wheelEnabled: true

    // C++ 桥接：由 ColorWheelPanel 注入
    property var viewModel: null
    property int tabIndex: 0
    property int wheelIndex: 0

    // 色轮分类名称，用于埋点
    property string tabName: ""
    property string wheelName: ""

    // 偏移色轮（wheelIndex=3）无色调范围可视化，禁用标题 hover 效果
    readonly property bool hasTitleHover: wheelIndex !== 3

    // 自动监听 ViewModel 信号，确保初始化和片段切换时加载数据
    Connections {
        target: viewModel
        function onParamsChanged() { Qt.callLater(wheelRoot.loadFromViewModel) }
    }
    onViewModelChanged: Qt.callLater(loadFromViewModel)

    property real hueAngle: 0
    property real hueStrength: 0

    property real redOffset: 0.00
    property real greenOffset: 0.00
    property real blueOffset: 0.00

    property real exposure: 0
    property real saturationValue: 0

    // 只要有任一通道在显示精度（2位小数）上不为零，色轮即为激活态
    readonly property bool isActivated: Math.abs(redOffset) >= rgbEpsilon
                                      || Math.abs(greenOffset) >= rgbEpsilon
                                      || Math.abs(blueOffset) >= rgbEpsilon
    readonly property bool isDefault: !isActivated
                                      && exposure === 0
                                      && saturationValue === 0

    signal resetClicked()
    signal titleHovered(bool hovered)

    readonly property var rgbInputs: [rInput, gInput, bInput]
    // 对外暴露 RGB 拖拽/编辑状态
    readonly property bool isRgbDragging: rgbInputs.some(i => i.isDragging)

    readonly property real wheelSize: 84
    readonly property real outerRadius: wheelSize / 2
    readonly property real ringWidth: 4
    readonly property real innerRadius: outerRadius - ringWidth
    readonly property real dragRadius: outerRadius - ctrlHandleRadius
    readonly property real ctrlHandleRadius: 3  // 色盘控制点半径
    readonly property real ringCanvasMargin: 8  // 色环外缘到 ringCanvas 画布边缘的余量，避免控制点贴边变形
    readonly property real ringCanvasSize: wheelSize + ringCanvasMargin * 2  // 画布尺寸 100

    implicitWidth: 116
    implicitHeight: 148

    // 数据是否已从 ViewModel 加载：控制点位置依赖 hueStrength/hueAngle，
    // 加载完成前先隐藏控制点，避免它先出现在圆心、加载后再跳到色相位置。
    property bool _dataLoaded: false

    property bool isDragging: false
    property bool isSyncing: false

    onHueAngleChanged: if (!isDragging && !isSyncing) syncRgbFromHue()
    onHueStrengthChanged: if (!isDragging && !isSyncing) syncRgbFromHue()

    function syncRgbFromHue() {
        if (hueStrength < rgbEpsilon) {
            redOffset = 0; greenOffset = 0; blueOffset = 0;
            return;
        }

        var rad = hueAngle * angleToRadians;

        // L∞ 归一化，再乘 0.5：
        //   色轮边缘（hueStrength=1.0）→ 通道最大值 ±0.5
        //   拖出边缘（hueStrength=2.0）→ 通道最大值 ±1.0
        var rRaw = Math.cos(rad - redPhase);
        var gRaw = Math.cos(rad - greenPhase);
        var bRaw = Math.cos(rad - bluePhase);
        var normalizer = Math.max(Math.abs(rRaw), Math.abs(gRaw), Math.abs(bRaw));
        var scaled = hueStrength * 0.5;

        redOffset   = Math.max(-1.0, Math.min(1.0, Math.round(scaled * rRaw / normalizer * 100) / 100));
        greenOffset = Math.max(-1.0, Math.min(1.0, Math.round(scaled * gRaw / normalizer * 100) / 100));
        blueOffset  = Math.max(-1.0, Math.min(1.0, Math.round(scaled * bRaw / normalizer * 100) / 100));
    }

    function syncHueFromRgb() {
        // 色相矢量合成：每个通道沿其相位方向投影
        //   x = ΣRGB·cos(相位)，y = ΣRGB·sin(相位)
        // 公共模（R=G=B）在三轴合成中自动相消 → 矢量为零 → 无色相。
        // L∞ 逆映射（×2）：正向 RGB = hueStrength * 0.5 * direction
        //   ∴ hueStrength = max(|R|,|G|,|B|) * 2，上界 2.0（RGB ±1.0 对应 hueStrength 2.0）
        var x = redOffset * Math.cos(redPhase) + greenOffset * Math.cos(greenPhase) + blueOffset * Math.cos(bluePhase);
        var y = redOffset * Math.sin(redPhase) + greenOffset * Math.sin(greenPhase) + blueOffset * Math.sin(bluePhase);

        var vecLen = Math.sqrt(x * x + y * y);
        if (vecLen < 0.001) {
            hueStrength = 0;   // 无色相 → 圆心，角度保持不变
            return;
        }
        hueStrength = Math.min(Math.max(Math.abs(redOffset), Math.abs(greenOffset), Math.abs(blueOffset)) * 2.0, 2.0);

        var angle = Math.atan2(y, x) * radiansToAngle;
        if (angle < 0) angle += 360;
        hueAngle = angle;
    }

    function reset() {
        hueAngle = 0; hueStrength = 0;
        redOffset = 0; greenOffset = 0; blueOffset = 0;
        exposure = 0; saturationValue = 0;
        syncToViewModel(2);
    }

    function resetHueOnly() {
        // 色相已是默认（控制点在圆心）则无需重置，避免产生空撤销项
        if (Math.abs(hueStrength) < 0.001
                && redOffset === 0 && greenOffset === 0 && blueOffset === 0)
            return;
        hueAngle = 0; hueStrength = 0;
        redOffset = 0; greenOffset = 0; blueOffset = 0;
        syncToViewModel(2);
    }

    // 关闭所有编辑中的输入框
    function dismissAllEditing() {
        rgbInputs.forEach(i => { if (i.editing) i.applyInput(); });
    }

    // 将当前所有参数同步到 C++ ViewModel
    function syncToViewModel(step) {
        if (!viewModel) return;
        viewModel.updateWheelParams(tabIndex, wheelIndex,
            hueAngle, hueStrength, redOffset, greenOffset, blueOffset,
            exposure, saturationValue, step);
        if (step === 2) {
            viewModel.commitDraft();
            // 埋点：仅在参数提交（FilterAdjustEnd）时上报一次，
            // 避免拖动过程中 FilterAdjustChanging 每帧触发导致事件风暴
            wheelRoot.wheelUsageState();
        }
    }

    // 从 C++ ViewModel 加载参数
    function loadFromViewModel() {
        if (_isDestroying) return;  // Qt.callLater 延迟触发时组件可能已在销毁，防止函数表失效导致崩溃
        if (!viewModel) { _dataLoaded = true; return; }  // 无 viewModel 也算就绪（显示默认值）
        isSyncing = true;
        var p = viewModel.getWheelParams(tabIndex, wheelIndex);
        hueAngle    = p.hueAngle || 0;
        redOffset   = p.r || 0;
        greenOffset = p.g || 0;
        blueOffset  = p.b || 0;
        exposure        = p.exposure || 0;
        saturationValue = p.saturation || 0;
        // hueStrength 由 RGB 反算：先检查色相矢量是否为零（R=G=B 时三轴合成互消 → 圆心）
        syncHueFromRgb();
        isSyncing = false;
        _dataLoaded = true;
    }

    // 色轮埋点
    function wheelUsageState() {
        eventTracker.trackEvent("pccut_color_wheel_use", {
                                    "the_first_level_classification": tabName,
                                    "the_second_level_classification": wheelName
                                });
    }

    Component {
        id: arcHandleComponent
        Canvas {
            width: 24; height: 24
            property real halfArc: 0
            property real arcRadius: 0
            property real normalizedValue: 0
            property real baseAngle: 0
            property real centerX: 0
            property real centerY: 0

            readonly property real handleAngle: baseAngle - halfArc + 2 * halfArc * (1 - normalizedValue)
            readonly property real adjustedRadius: arcRadius - wheelRoot.arcPointerLength + 2 // 滑针所在位置与色轮圆心的距离
            x: centerX + adjustedRadius * Math.cos(handleAngle) - width / 2
            y: centerY + adjustedRadius * Math.sin(handleAngle) - height / 2
            onHandleAngleChanged: requestPaint()
            onPaint: wheelRoot.paintPointer(getContext("2d"), width / 2, height / 2, handleAngle)
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: 2
        anchors.bottomMargin: 2
        spacing: 13

        // ── 标题行 ──
        Item {
            id: titleRow
            Layout.fillWidth: true
            height: 16
            z: 2          // 高于色轮主体区域(z:1)，防止hover区域被色轮主体盖住

            Text {
                id: titleText
                text: wheelRoot.title
                color: wheelRoot.wheelEnabled ? Colors.color_EEEEEE : Colors.color_444444
                font.pixelSize: 11
                font.bold: true
                anchors.centerIn: parent
                HoverHandler {
                    id: titleHover
                    enabled: wheelRoot.wheelEnabled && !cursorHelper.hoverSuppressed && wheelRoot.hasTitleHover
                    onHoveredChanged: {
                        wheelRoot.titleHovered(hovered);
                        // 显示/隐藏色轮作用范围的可视化
                        if (hovered && viewModel) {
                            viewModel.showWheelRangeVisualization(tabIndex, wheelIndex);
                            eventTracker.trackEvent("pccut_color_wheel_preview", {
                                                        "the_first_level_classification" : tabName,
                                                        "the_second_level_classification" : wheelName
                                                    })
                        } else if (viewModel) {
                            viewModel.hideWheelRangeVisualization();
                        }
                    }
                }
            }

            // 标题下白线
            Rectangle {
                anchors.top: titleText.bottom
                anchors.topMargin: 0
                anchors.horizontalCenter: titleText.horizontalCenter
                width: titleText.width
                height: 1.5
                color: Colors.color_EEEEEE
                opacity: titleHover.hovered && wheelRoot.wheelEnabled && wheelRoot.hasTitleHover ? 1.0 : 0
                Behavior on opacity { NumberAnimation { duration: 100 } }
            }

            // info图标
            Image {
                id: helpIcon
                width: parent.height
                height: width
                anchors.left: titleText.right
                anchors.leftMargin: 2
                anchors.verticalCenter: parent.verticalCenter
                source: helpHover.hovered && wheelRoot.wheelEnabled
                        ? "qrc:/icons/colorWheel/color_wheel_explain_hover.svg" : "qrc:/icons/colorWheel/color_wheel_explain.svg"
                sourceSize: Qt.size(width, height)
                opacity: wheelRoot.wheelEnabled ? 1.0 : 0.25
                HoverHandler {
                    id: helpHover
                    enabled: wheelRoot.wheelEnabled && !cursorHelper.hoverSuppressed
                }

                ToolTip {
                    id: infoIconTooltip
                    parent: helpIcon
                    visible: helpHover.hovered && wheelRoot.tooltipText.length > 0
                    text: wheelRoot.tooltipText; delay: 300;
                    leftPadding: 8; rightPadding: 8
                    topPadding: 6; bottomPadding: 6

                    background: Rectangle {
                        color: Colors.color_19191A
                        border.color: Colors.color_454649
                        border.width: 1
                        radius: 4
                    }
                    contentItem: Column {
                        spacing: 4

                        Text {
                            text: infoIconTooltip.text
                            color: Colors.color_EEEEEE
                            font.pixelSize: 11
                            font.bold: true
                        }

                        Text {
                            visible: wheelRoot.hasTitleHover
                            text: qsTr("pccut_panel_adjust_colorwheel_onboarding_tooltip")
                            color: Colors.color_999999
                            font.pixelSize: 11
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }

            // 重置按钮
            Rectangle {
                id: resetBtn
                property bool isHovered: false
                color: Colors.color_transparent
                width: parent.height
                height: width
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                Image {
                    anchors.fill: parent
                    source: (!wheelRoot.isDefault && wheelRoot.wheelEnabled && resetBtn.isHovered)
                            ? "qrc:/icons/ic_reset_hover.svg" : "qrc:/icons/ic_reset.svg"
                    sourceSize: Qt.size(parent.width, parent.height)
                    opacity: (wheelRoot.isDefault || !wheelRoot.wheelEnabled) ? 0.2 : 1.0
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !wheelRoot.isDefault && wheelRoot.wheelEnabled
                    onEntered: resetBtn.isHovered = true
                    onExited: resetBtn.isHovered = false
                    onClicked: {
                        wheelRoot.reset();
                        wheelRoot.resetClicked();
                    }
                }
            }
        }

        // ── 色轮主体区域 ──
        Item {
            id: wheelBody
            Layout.fillWidth: true
            Layout.fillHeight: true
            z: 1
            // 色盘/色环/滑轨均为 C++ 预绘制纹理，随场景图第 1 帧即时出现。
            opacity: wheelRoot.wheelEnabled ? 1.0 : 0.2

            // ── 色盘 + 色环（C++ ImageProvider 预绘制，瞬间加载）──
            // 画布 100px（色环外径 84 + 每边 8px 余量），余量避免控制点贴边变形。
            // 色盘逐像素平滑渐变；色环用 QPainter 抗锯齿绘制（与 QML Canvas 同一光栅引擎，平滑度一致）。
            // 十字线由 crosshair 绘制。
            // 按设备像素（× devicePixelRatio）渲染纹理，HiDPI 缩放下保持 1:1 清晰（与 Canvas 一致）；
            // source 传入设备像素的画布尺寸、色环内径、外径，几何以 QML 为单一来源。
            Image {
                id: ringCanvas
                anchors.centerIn: parent
                width: wheelRoot.ringCanvasSize
                height: wheelRoot.ringCanvasSize
                sourceSize.width: Math.round(width * Screen.devicePixelRatio)
                sourceSize.height: Math.round(height * Screen.devicePixelRatio)
                source: "image://colorwheel/" + Math.round(width * Screen.devicePixelRatio)
                        + "_" + Math.round(wheelRoot.innerRadius * Screen.devicePixelRatio)
                        + "_" + Math.round(wheelRoot.outerRadius * Screen.devicePixelRatio)
                cache: true
                smooth: true
            }

            // ── 十字参考线（仅激活状态显示）──
            // 用 Rectangle 绘制（场景图渲染，随 isActivated 即时显隐，无 Canvas 异步延迟）。
            Item {
                id: crosshair
                visible: wheelRoot.isActivated
                z: 2
                x: ringCanvas.x; y: ringCanvas.y
                width: ringCanvas.width; height: ringCanvas.height

                Rectangle {  // 水平线
                    anchors.centerIn: parent
                    width: (wheelRoot.innerRadius + 1) * 2
                    height: 1
                    color: Colors.color_FFFFFF_10
                }
                Rectangle {  // 垂直线
                    anchors.centerIn: parent
                    width: 1
                    height: (wheelRoot.innerRadius + 1) * 2
                    color: Colors.color_FFFFFF_10
                }
            }

            // ── 弧形轨道（C++ QPainter 预绘制：圆头端点 + 竖直渐变，随色盘/色环同帧出现）──
            // 容器 Item 保留 id 与几何属性（供滑针/交互层引用）；内部左右弧分开：
            //   右弧为静态黑白，cache:true 只生成一次并全色轮共享；左弧随 RGB/曝光动态，cache:false。
            Item {
                id: arcTracksCanvas

                // ====== 几何参数 ======
                readonly property real arcRadius: wheelRoot.outerRadius + (diffFromRingCanvas - lineWidth) / 2
                readonly property real halfArc: Math.PI * 0.5 * 0.56  // 滑轨弧形圆心夹角（90°）的一半
                readonly property int diffFromRingCanvas: 18 // 弧形轨道直径与内部色环直径长度差
                readonly property int lineWidth: 4

                width: ringCanvas.width + diffFromRingCanvas
                height: ringCanvas.height + diffFromRingCanvas
                x: ringCanvas.x - diffFromRingCanvas / 2
                y: ringCanvas.y - diffFromRingCanvas / 2

                // 公共几何参数（设备像素），供左右弧 URL 复用
                readonly property string _arcGeom: Math.round(width * Screen.devicePixelRatio)
                        + "_" + (arcRadius * Screen.devicePixelRatio).toFixed(3)
                        + "_" + (lineWidth * Screen.devicePixelRatio).toFixed(3)
                        + "_" + halfArc.toFixed(5)

                // 右弧：静态黑白，几何不变 → URL 稳定，cache:true 只生成一次
                Image {
                    anchors.fill: parent
                    cache: true
                    smooth: true
                    sourceSize.width: Math.round(width * Screen.devicePixelRatio)
                    sourceSize.height: Math.round(height * Screen.devicePixelRatio)
                    source: "image://colorwheelarc/right/" + arcTracksCanvas._arcGeom
                }

                // 左弧：随 RGB/曝光动态变化，cache:false 避免拖拽时缓存膨胀
                Image {
                    anchors.fill: parent
                    cache: false
                    smooth: true
                    sourceSize.width: Math.round(width * Screen.devicePixelRatio)
                    sourceSize.height: Math.round(height * Screen.devicePixelRatio)
                    source: "image://colorwheelarc/left/" + arcTracksCanvas._arcGeom
                            + "_" + wheelRoot.redOffset.toFixed(4)
                            + "_" + wheelRoot.greenOffset.toFixed(4)
                            + "_" + wheelRoot.blueOffset.toFixed(4)
                            + "_" + wheelRoot.exposure.toFixed(4)
                }
            }

            // ── 饱和度滑针 ──
            Loader {
                id: satHandleLoader
                sourceComponent: arcHandleComponent
                onLoaded: wheelRoot.initArcHandle(
                              item,
                              function() { return Math.max(0, Math.min(1, 1 - (wheelRoot.saturationValue + 100) / 200)); },
                              Math.PI)
            }

            // ── 曝光滑针 ──
            Loader {
                id: expHandleLoader
                sourceComponent: arcHandleComponent
                onLoaded: wheelRoot.initArcHandle(
                              item,
                              function() { return Math.max(0, Math.min(1, (wheelRoot.exposure + 100) / 200)); },
                              0)
            }

            // ── 饱和度 Tooltip ──
            ColorWheelEditableTooltip {
                id: satTooltip
                z: 2
                label: qsTr("pccut_panel_adjust_saturation")
                value: wheelRoot.saturationValue
                minValue: -100
                maxValue: 100
                precision: 0
                arrowOnTop: true
                hovered: (arcMouseArea.isHoveringArcHandle && arcMouseArea.hoveredArcHandle === satHandleLoader.item)
                         || arcMouseArea.activeArc === wheelRoot.arcTypeSaturation
                property var targetHandle: satHandleLoader.item
                x: targetHandle ? targetHandle.x + targetHandle.width / 2 - width / 2 : 0
                y: targetHandle ? targetHandle.y + targetHandle.height : 0
                onValueModified: function(newVal) {
                    // 值未变（未改动或输入相同值）不计入撤销栈
                    if (newVal === wheelRoot.saturationValue) return;
                    wheelRoot.saturationValue = newVal;
                    wheelRoot.syncToViewModel(2);
                }
                onTooltipContainsMouseChanged: wheelRoot.updateTooltipCursor(satTooltip)
                onBridgeContainsMouseChanged: wheelRoot.updateTooltipCursor(satTooltip)
                onEditingChanged: if (!editing) wheelRoot.updateTooltipCursor(satTooltip)
            }

            // ── 曝光 Tooltip ──
            ColorWheelEditableTooltip {
                id: expTooltip
                z: 2
                label: qsTr("pccut_panel_adjust_exposure")
                value: wheelRoot.exposure
                minValue: -100
                maxValue: 100
                precision: 0
                arrowOnTop: true
                hovered: (arcMouseArea.isHoveringArcHandle && arcMouseArea.hoveredArcHandle === expHandleLoader.item)
                         || arcMouseArea.activeArc === wheelRoot.arcTypeExposure
                property var targetHandle: expHandleLoader.item
                x: targetHandle ? targetHandle.x + targetHandle.width / 2 - width / 2 : 0
                y: targetHandle ? targetHandle.y + targetHandle.height : 0
                onValueModified: function(newVal) {
                    // 值未变（未改动或输入相同值）不计入撤销栈
                    if (newVal === wheelRoot.exposure) return;
                    wheelRoot.exposure = newVal;
                    wheelRoot.syncToViewModel(2);
                }
                onTooltipContainsMouseChanged: wheelRoot.updateTooltipCursor(expTooltip)
                onBridgeContainsMouseChanged: wheelRoot.updateTooltipCursor(expTooltip)
                onEditingChanged: if (!editing) wheelRoot.updateTooltipCursor(expTooltip)
            }

            // ── 弧形交互层 ──
            MouseArea {
                id: arcMouseArea
                x: ringCanvas.x - 18; y: ringCanvas.y - 18
                width: ringCanvas.width + 36; height: ringCanvas.height + 36
                enabled: wheelRoot.wheelEnabled; z: 1
                preventStealing: true
                hoverEnabled: true
                cursorShape: Qt.ArrowCursor
                property string activeArc: ""
                property bool isHoveringArcHandle: false
                property var hoveredArcHandle: null
                property bool isWarpingCursor: false    // 弧形滑针 CGWarp 期间抑制异步事件干扰
                property real dragStartValue: 0
                property real dragStartMouseX: 0
                property real dragStartMouseY: 0
                // 双击检测状态：滑轨双击归零用（onReleased 会 warp 光标，无法用 Qt 原生 onDoubleClicked，故自行判定）。
                property double lastPressTime: 0
                property string lastPressArc: ""

                onMouseXChanged: if (activeArc === wheelRoot.arcTypeNone && !isWarpingCursor && !wheelMouseArea.isWarpingCursor) updateArcHoverState()
                onMouseYChanged: if (activeArc === wheelRoot.arcTypeNone && !isWarpingCursor && !wheelMouseArea.isWarpingCursor) updateArcHoverState()
                onEntered:       if (activeArc === wheelRoot.arcTypeNone && !isWarpingCursor && !wheelMouseArea.isWarpingCursor) updateArcHoverState()
                onExited: {
                    if (activeArc !== wheelRoot.arcTypeNone || isWarpingCursor) return;
                    // 鼠标离开弧形交互区：若鼠标曾在滑针上方，清除 hover 态并还原光标。
                    // 不再附加 !wheelMouseArea.containsMouse 条件——直接移出色轮时该条件虽为真，
                    // 但若鼠标是移进色盘区，wheelMouseArea 的 hover 逻辑会自行重设光标，无副作用。
                    if (isHoveringArcHandle) {
                        isHoveringArcHandle = false;
                        hoveredArcHandle = null;
                        cursorHelper.restoreAllOverrideCursors();
                    }
                }

                function applyArcHover(arcMx, arcMy) {
                    var hit = detectArcHandleAtPoint(arcMx, arcMy);
                    var wasHovering = isHoveringArcHandle;
                    isHoveringArcHandle = (hit !== wheelRoot.arcTypeNone);
                    hoveredArcHandle = hit === wheelRoot.arcTypeSaturation ? satHandleLoader.item
                                     : hit === wheelRoot.arcTypeExposure  ? expHandleLoader.item
                                     : null;
                    if (isHoveringArcHandle && !wasHovering)      wheelRoot.setVerticalCursor();
                    else if (!isHoveringArcHandle && wasHovering && !wheelMouseArea.isHoveringHandle) cursorHelper.restoreAllOverrideCursors();
                }

                function updateArcHoverState() { applyArcHover(mouseX, mouseY); }

                onPositionChanged: function(mouse) {
                    if (activeArc !== "") {
                        updateArcValue(mouse.x, mouse.y);
                    }
                }
                onPressed: function(mouse) {
                    wheelRoot.dismissAllEditing();
                    var hit = detectArcHandleAtPoint(mouse.x, mouse.y);
                    if (hit === wheelRoot.arcTypeNone) {
                        // 未命中滑针：检测是否双击了弧形轨道 → 归零。
                        var track = detectArcTrackAtPoint(mouse.x, mouse.y);
                        if (track !== wheelRoot.arcTypeNone) {
                            var t = new Date().getTime();
                            if (track === lastPressArc && (t - lastPressTime) < 400) {
                                lastPressTime = 0; lastPressArc = "";   // 消费双击
                                arcResetToZero(track);
                                mouse.accepted = true;   // 接受，避免下传到色盘
                                return;
                            }
                            lastPressTime = t; lastPressArc = track;
                        }
                        mouse.accepted = false;   // 单击轨道/空白：不拦截，交由下层处理
                        return;
                    }

                    activeArc = hit;
                    dragStartValue = (hit === wheelRoot.arcTypeSaturation) ? wheelRoot.saturationValue : wheelRoot.exposure;
                    dragStartMouseX = mouse.x;
                    dragStartMouseY = mouse.y;
                    cursorHelper.setOverrideCursor(Qt.BlankCursor);
                }
                // 重置对应滑轨值（饱和度/曝光 → 0），并激活色轮。
                function arcResetToZero(hit) {
                    if (hit === wheelRoot.arcTypeSaturation) {
                        if (wheelRoot.saturationValue !== 0) {
                            wheelRoot.saturationValue = 0;
                            wheelRoot.syncToViewModel(2);
                        }
                    } else {
                        if (wheelRoot.exposure !== 0) {
                            wheelRoot.exposure = 0;
                            wheelRoot.syncToViewModel(2);
                        }
                    }
                }
                onReleased: {
                    var wasArc = activeArc;
                    // 仅当滑针值相对按下时发生变化才提交撤销栈：
                    // 纯点击（未拖拽，值未变）不计入撤销恢复操作。
                    if (wasArc !== wheelRoot.arcTypeNone) {
                        var curVal = (wasArc === wheelRoot.arcTypeSaturation) ? wheelRoot.saturationValue
                                                                              : wheelRoot.exposure;
                        if (curVal !== dragStartValue) wheelRoot.syncToViewModel(2); // FilterAdjustEnd
                    }
                    activeArc = wheelRoot.arcTypeNone;
                    // wasArc 为 None 时（双击轨道归零那次 press 被接受并触发本回调）不选中滑针，避免误 warp 到曝光滑针。
                    var handle = (wasArc === wheelRoot.arcTypeSaturation) ? satHandleLoader.item
                               : (wasArc === wheelRoot.arcTypeExposure)   ? expHandleLoader.item
                                                                          : null;
                    if (handle) {
                        isHoveringArcHandle = true;
                        hoveredArcHandle = handle;
                        isWarpingCursor = true;
                        var centroidOffX = (wheelRoot.arcPointerLength / 3) * Math.cos(handle.handleAngle);
                        var centroidOffY = (wheelRoot.arcPointerLength / 3) * Math.sin(handle.handleAngle);
                        var handleGlobalPos = handle.mapToGlobal(handle.width / 2 + centroidOffX,
                                                                 handle.height / 2 + centroidOffY);
                        cursorHelper.setCursorPosWithHoverUpdate(handleGlobalPos.x, handleGlobalPos.y);
                        // 原子替换 BlankCursor → 拖拽图标（不经过 count=0，无闪烁）
                        setVerticalCursor();
                        Qt.callLater(function() { arcMouseArea.isWarpingCursor = false; });
                    } else {
                        cursorHelper.restoreAllOverrideCursors();
                    }
                }

                function detectArcHandleAtPoint(mx, my) {
                    var entries = [
                        { item: satHandleLoader.item, tip: satTooltip, type: wheelRoot.arcTypeSaturation },
                        { item: expHandleLoader.item, tip: expTooltip, type: wheelRoot.arcTypeExposure }
                    ];
                    for (var k = 0; k < entries.length; k++) {
                        var e = entries[k];
                        if (!e.item || !e.item.visible) continue;
                        if (pointInHandleTriangle(mx, my, e.item)) return e.type;
                        if (e.tip.tipVisible && pointInBridgeZone(mx, my, e.item)) return e.type;
                        if (e.tip.tipVisible && pointInTooltipRect(mx, my, e.tip)) return e.type;
                    }
                    return wheelRoot.arcTypeNone;
                }

                // 检测点是否落在左右弧形轨道上（供双击归零）：距圆心接近 arcRadius 且角度在弧扇区内。
                // 左弧（饱和度）在 π±halfArc，右弧（曝光）在 0±halfArc。返回命中的弧类型。
                function detectArcTrackAtPoint(mx, my) {
                    var cx = width / 2, cy = height / 2;
                    var ha = arcTracksCanvas.halfArc;
                    var R = arcTracksCanvas.arcRadius;
                    var dx = mx - cx, dy = my - cy;
                    var dist = Math.sqrt(dx * dx + dy * dy);
                    // 距离容差：半线宽 + 4px 余量（圆头端点+便于命中）
                    var tol = arcTracksCanvas.lineWidth / 2 + 4;
                    if (Math.abs(dist - R) > tol) return wheelRoot.arcTypeNone;

                    var a = Math.atan2(dy, dx);   // -π~π
                    // 右弧：角度在 [-ha, ha]
                    if (a >= -ha && a <= ha) return wheelRoot.arcTypeExposure;
                    // 左弧：角度接近 π（π-ha ~ π 或 -π ~ -(π-ha)）
                    if (a >= Math.PI - ha || a <= -(Math.PI - ha)) return wheelRoot.arcTypeSaturation;
                    return wheelRoot.arcTypeNone;
                }

                // 检测鼠标是否在tooltip矩形区域内
                function pointInTooltipRect(mx, my, tip) {
                    var tx = tip.x + tip.tooltipLocalX - arcMouseArea.x;
                    var ty = tip.y + tip.tooltipLocalY - arcMouseArea.y;
                    var tw = tip.tooltipRealWidth;
                    var th = tip.tooltipRealHeight;
                    return mx >= tx && mx <= tx + tw && my >= ty && my <= ty + th;
                }

                // 桥接区：滑针中心 + tooltip左上角 + tooltip右上角 组成的三角形
                function pointInBridgeZone(mx, my, handleItem) {
                    var tip = (handleItem === satHandleLoader.item) ? satTooltip : expTooltip;
                    // 滑针中心（arcMouseArea局部坐标）
                    var ax = handleItem.x + handleItem.width / 2 - arcMouseArea.x;
                    var ay = handleItem.y + handleItem.height / 2 - arcMouseArea.y;
                    // tooltip左上角（父坐标系 → arcMouseArea局部坐标）
                    var tipAbsX = tip.x + tip.tooltipLocalX;
                    var tipAbsY = tip.y + tip.tooltipLocalY;
                    var bx = tipAbsX - arcMouseArea.x;
                    var by = tipAbsY - arcMouseArea.y;
                    // tooltip右上角
                    var cx = bx + tip.tooltipRealWidth;
                    var cy = by;
                    return pointInTriangle(mx, my, ax, ay, bx, by, cx, cy);
                }

                function pointInHandleTriangle(mx, my, handleItem) {
                    var cx = handleItem.x + handleItem.width / 2 - arcMouseArea.x;
                    var cy = handleItem.y + handleItem.height / 2 - arcMouseArea.y;
                    var angle = handleItem.handleAngle;
                    var tipX = cx + wheelRoot.arcPointerHitLength * Math.cos(angle);
                    var tipY = cy + wheelRoot.arcPointerHitLength * Math.sin(angle);
                    var b1x = cx + wheelRoot.arcPointerHitWidth * Math.cos(angle + Math.PI / 2);
                    var b1y = cy + wheelRoot.arcPointerHitWidth * Math.sin(angle + Math.PI / 2);
                    var b2x = cx + wheelRoot.arcPointerHitWidth * Math.cos(angle - Math.PI / 2);
                    var b2y = cy + wheelRoot.arcPointerHitWidth * Math.sin(angle - Math.PI / 2);
                    return pointInTriangle(mx, my, tipX, tipY, b1x, b1y, b2x, b2y);
                }

                function pointInTriangle(px, py, ax, ay, bx, by, cx, cy) {
                    var d1 = (px - ax) * (by - ay) - (bx - ax) * (py - ay);
                    var d2 = (px - bx) * (cy - by) - (cx - bx) * (py - by);
                    var d3 = (px - cx) * (ay - cy) - (ax - cx) * (py - cy);
                    return (d1 > 0 && d2 > 0 && d3 > 0) || (d1 < 0 && d2 < 0 && d3 < 0);
                }

                function updateArcValue(mx, my) {
                    var cx = width/2, cy = height/2, ha = arcTracksCanvas.halfArc;
                    // 虚拟鼠标位置：起始位置 + 实际偏移量 / 灵敏度系数
                    var vmx = dragStartMouseX + (mx - dragStartMouseX) / wheelRoot.dragSensitivity;
                    var vmy = dragStartMouseY + (my - dragStartMouseY) / wheelRoot.dragSensitivity;
                    var a = Math.atan2(vmy-cy, vmx-cx);
                    if (activeArc === wheelRoot.arcTypeSaturation) {
                        var d = a - Math.PI;
                        if (d > Math.PI) d -= 2*Math.PI; if (d < -Math.PI) d += 2*Math.PI;
                        wheelRoot.saturationValue = Math.round(Math.max(0, Math.min(1, (d+ha)/(2*ha))) * 200 - 100);
                    } else {
                        wheelRoot.exposure = Math.round(100 - Math.max(0, Math.min(1, (a+ha)/(2*ha))) * 200);
                    }
                    wheelRoot.syncToViewModel(1); // FilterAdjustChanging
                }
            }

            // ── 色相控制点 ──
            // 兄弟节点（与 ringCanvas 平级），坐标按 ringCanvas 位置偏移。
            // z 高于色盘/色环（都在 ringCanvas 纹理里），确保控制点显示在色环之上。
            Item {
                id: dragHandle
                width: wheelRoot.ctrlHandleRadius * 2; height: width
                z: 10
                // 数据加载后再显示，避免先出现在圆心、加载后跳到色相位置
                visible: wheelRoot._dataLoaded
                x: ringCanvas.x + ringCanvas.width / 2 - width / 2 + Math.min(wheelRoot.hueStrength, 1.0) * wheelRoot.dragRadius * Math.cos(wheelRoot.hueAngle * angleToRadians)
                y: ringCanvas.y + ringCanvas.height / 2 - height / 2 - Math.min(wheelRoot.hueStrength, 1.0) * wheelRoot.dragRadius * Math.sin(wheelRoot.hueAngle * angleToRadians)
                Rectangle {
                    anchors.fill: parent
                    radius: wheelRoot.ctrlHandleRadius
                    color: wheelRoot.isActivated ? Colors.color_EEEEEE : Colors.color_999999
                }
            }

            // ── 色轮拖拽交互 ──
            MouseArea {
                id: wheelMouseArea
                anchors.fill: ringCanvas
                z: 2
                cursorShape: Qt.ArrowCursor
                enabled: wheelRoot.wheelEnabled
                hoverEnabled: true
                preventStealing: true
                property bool isDragMode: false
                property bool isHoveringHandle: false
                property bool isWarpingCursor: false   // macOS CGWarp 期间抑制 onExited
                property bool _dragOccurred: false     // 本次按下是否发生过拖拽（用于区分点击/拖拽）
                property real grabStartHandleX: 0      // 按下时控制点 X 偏移（精细区原点）
                property real grabStartHandleY: 0      // 按下时控制点 Y 偏移（精细区原点）
                property real dragPrecision: 1.0       // 当前拖拽精细系数（1.0=正常，0.2=按住Ctrl/Cmd精细拖拽）
                property real _prevMouseX: 0           // 上一帧鼠标 X（逐帧增量拖拽）
                property real _prevMouseY: 0           // 上一帧鼠标 Y（逐帧增量拖拽）
                property real _accHandleX: 0           // 当前控制点 X 累积偏移（逐帧积分）
                property real _accHandleY: 0           // 当前控制点 Y 累积偏移（逐帧积分）

                // 视觉位置：hueStrength 超过 1.0（拖出色轮边缘）时控制点停在边缘
                readonly property real handleOffX: Math.min(wheelRoot.hueStrength, 1.0) * wheelRoot.dragRadius * Math.cos(wheelRoot.hueAngle * angleToRadians)
                readonly property real handleOffY: -Math.min(wheelRoot.hueStrength, 1.0) * wheelRoot.dragRadius * Math.sin(wheelRoot.hueAngle * angleToRadians)

                onPressed: function(mouse) {
                    wheelRoot.dismissAllEditing();
                    _dragOccurred = false;
                    var cx = ringCanvas.width / 2;
                    var cy = ringCanvas.height / 2;
                    var dx = mouse.x - cx;
                    var dy = mouse.y - cy;
                    var dist = Math.sqrt(dx * dx + dy * dy);
                    if (dist > wheelRoot.outerRadius) {
                        mouse.accepted = false;
                        return;
                    }

                    var handleDist = Math.sqrt(
                        Math.pow(mouse.x - (cx + handleOffX), 2) +
                        Math.pow(mouse.y - (cy + handleOffY), 2));

                    if (handleDist >= wheelRoot.hueHandleGrabDist) {
                        // 点击在控制点外，接受事件以支持双击重置，但不启动拖拽
                        return;
                    }

                    // 在控制点上，进入拖拽模式
                    wheelRoot.isDragging = true;
                    isDragMode = true;
                    _dragOccurred = true;   // 控制点交互（拖拽或纯点击）均视为非主体单击，不触发激活切换
                    cursorHelper.setOverrideCursor(Qt.BlankCursor);
                    // grabStart 与 acc 均用逻辑位置（hueStrength 可 >1.0 表示 RGB 超出 ±0.5），
                    // 保证 distFromGrab 初始为 0，灵敏度区计算从"本次拖拽起点"开始。
                    var logX = wheelRoot.hueStrength * wheelRoot.dragRadius * Math.cos(wheelRoot.hueAngle * angleToRadians);
                    var logY = -wheelRoot.hueStrength * wheelRoot.dragRadius * Math.sin(wheelRoot.hueAngle * angleToRadians);
                    grabStartHandleX = logX;
                    grabStartHandleY = logY;
                    _accHandleX = logX;
                    _accHandleY = logY;
                    _prevMouseX = mouse.x;
                    _prevMouseY = mouse.y;
                    dragPrecision = 1.0;   // 复位精细系数，首次移动时按当前修饰键重新判定
                }
                onPositionChanged: function(mouse) {
                    if (!isDragMode) return;

                    // 按住 Ctrl(Windows)/Cmd(macOS) 切换精细拖拽（0.2×速）：
                    // 切换时将精细区原点和逐帧基准同步到当前位置，确保无跳变且新精细系数
                    // 从此处以最高灵敏度（20:1）生效。
                    var precision = (mouse.modifiers & Qt.ControlModifier) ? 0.2 : 1.0;
                    if (precision !== dragPrecision) {
                        grabStartHandleX = _accHandleX;
                        grabStartHandleY = _accHandleY;
                        _prevMouseX = mouse.x;
                        _prevMouseY = mouse.y;
                        dragPrecision = precision;
                    }

                    // 逐帧鼠标增量（相比 grab-from-start，消除了屏幕边界对可达范围的硬性限制）
                    var dmx = mouse.x - _prevMouseX;
                    var dmy = mouse.y - _prevMouseY;
                    _prevMouseX = mouse.x;
                    _prevMouseY = mouse.y;

                    // 自适应灵敏度：
                    //   精细区（控制点离精细原点 ≤ FINE_DIST）：保持原始 dragSensitivity。
                    //   超出精细区后：灵敏度系数线性过渡到 COARSE_SENS（12:1）。
                    var FINE_DIST = 10;
                    var COARSE_SENS = 12;
                    var distFromGrab = Math.sqrt(
                        (_accHandleX - grabStartHandleX) * (_accHandleX - grabStartHandleX) +
                        (_accHandleY - grabStartHandleY) * (_accHandleY - grabStartHandleY)
                    );
                    var sensitivity;
                    if (distFromGrab <= FINE_DIST) {
                        sensitivity = wheelRoot.dragSensitivity;
                    } else {
                        var t = Math.min(1.0, (distFromGrab - FINE_DIST) / (wheelRoot.dragRadius - FINE_DIST));
                        sensitivity = wheelRoot.dragSensitivity * (1.0 - t) + COARSE_SENS * t;
                    }

                    _accHandleX += dmx / sensitivity * precision;
                    _accHandleY += dmy / sensitivity * precision;
                    applyPosition(_accHandleX, _accHandleY);

                    // 将累积器截断到扩展边界（2×dragRadius），防止超调后出现死区
                    var maxExt = 2.0 * wheelRoot.dragRadius;
                    var accDist = Math.sqrt(_accHandleX * _accHandleX + _accHandleY * _accHandleY);
                    if (accDist > maxExt) {
                        _accHandleX = _accHandleX / accDist * maxExt;
                        _accHandleY = _accHandleY / accDist * maxExt;
                    }
                }
                onMouseXChanged: if (!isDragMode && !isWarpingCursor && !arcMouseArea.isWarpingCursor) { updateHandleHoverState(); if (!isHoveringHandle) updateArcHoverFromWheel(); }
                onMouseYChanged: if (!isDragMode && !isWarpingCursor && !arcMouseArea.isWarpingCursor) { updateHandleHoverState(); if (!isHoveringHandle) updateArcHoverFromWheel(); }
                onEntered:       if (!isDragMode && !isWarpingCursor && !arcMouseArea.isWarpingCursor) { updateHandleHoverState(); if (!isHoveringHandle) updateArcHoverFromWheel(); }
                onExited: {
                    if (isDragMode || isWarpingCursor) return;
                    if (isHoveringHandle) {
                        isHoveringHandle = false;
                        cursorHelper.restoreAllOverrideCursors();
                    }
                }

                onReleased: {
                    if (isDragMode) {
                        isDragMode = false;
                        wheelRoot.isDragging = false;
                        wheelRoot.syncRgbFromHue();
                        wheelRoot.syncToViewModel(2); // FilterAdjustEnd
                        arcMouseArea.isHoveringArcHandle = false;
                        arcMouseArea.hoveredArcHandle = null;
                        isHoveringHandle = true;
                        isWarpingCursor = true;
                        var handleGlobalPos = dragHandle.mapToGlobal(dragHandle.width / 2, dragHandle.height / 2);
                        cursorHelper.setCursorPosWithHoverUpdate(handleGlobalPos.x, handleGlobalPos.y);
                        wheelRoot.setFourHeadedCursor();
                        Qt.callLater(function() {
                            updateHandleHoverState();
                            isWarpingCursor = false;
                        });
                    } else {
                        updateHandleHoverState();
                        updateArcHoverFromWheel();
                    }
                }
                // 双击重置色相
                onDoubleClicked: { wheelRoot.resetHueOnly(); }

                function updateArcHoverFromWheel() {
                    arcMouseArea.applyArcHover(mouseX + (ringCanvas.x - arcMouseArea.x),
                                                   mouseY + (ringCanvas.y - arcMouseArea.y));
                }

                function updateHandleHoverState() {
                    var cx = ringCanvas.width / 2;
                    var cy = ringCanvas.height / 2;
                    var handleDist = Math.sqrt(
                        Math.pow(mouseX - (cx + handleOffX), 2) +
                        Math.pow(mouseY - (cy + handleOffY), 2));
                    var wasHovering = isHoveringHandle;
                    isHoveringHandle = (handleDist < wheelRoot.hueHandleGrabDist);

                    if (isHoveringHandle && !wasHovering) { wheelRoot.setFourHeadedCursor(); }
                    else if (!isHoveringHandle && wasHovering) {  cursorHelper.restoreAllOverrideCursors(); }
                }

                function applyPosition(dx, dy) {
                    var dist = Math.sqrt(dx * dx + dy * dy);
                    var maxR = wheelRoot.dragRadius;
                    // 允许 hueStrength 超过 1.0（拖出色轮边缘），但截止到 2.0（RGB ±1.0）
                    var maxExtended = 2.0 * maxR;
                    if (dist > maxExtended) {
                        dx = dx / dist * maxExtended; dy = dy / dist * maxExtended; dist = maxExtended;
                    }
                    wheelRoot.hueStrength = dist / maxR;
                    var angle = Math.atan2(-dy, dx) * radiansToAngle;
                    if (angle < 0) angle += 360;
                    wheelRoot.hueAngle = angle;
                    wheelRoot.syncRgbFromHue();
                    wheelRoot.syncToViewModel(1); // FilterAdjustChanging
                }
            }

        }

        // ── RGB 数值行 ──
        // 结构照搬色轮弧针 arcMouseArea：用“一个覆盖整行(+边距)的大 MouseArea”统一承载
        // 三个数值框的 hover / 按下 / 拖拽 / 松手 warp / 光标几何对账；三个 36×20 框退化为
        // 纯几何命中目标（如同滑针之于 arcMouseArea）。这样 warp 之后光标落回“大 MouseArea”
        // 内部，真实鼠标一动就持续收到 onPositionChanged，几何重测决定光标，绝不依赖会被
        // macOS warp 冻结吞掉的小框 HoverLeave —— 这正是色轮手柄不卡、而旧小框实现卡死的根因。
        // 容器 z:2 高于色轮主体区域(z:1)，避免 arcMouseArea 外扩 18px 压住本行。
        Item {
            id: rgbRowContainer
            z: 2
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: rgbRow.width
            implicitHeight: rgbRow.height

            Row {
                id: rgbRow
                anchors.centerIn: parent
                spacing: 4
                opacity: wheelRoot.wheelEnabled ? 1.0 : 0.2

                ColorWheelValueInput {
                    id: rInput
                    value: wheelRoot.redOffset
                    channelColor: Colors.color_FF0000;
                    enabled: wheelRoot.wheelEnabled
                    onValueModified: (v) => wheelRoot.onChannelModified(0, v)
                    onIsDraggingChanged: wheelRoot.syncToViewModel(isDragging ? 0 : 2)
                    onTabPressed: Qt.callLater(function() { gInput.enterEditing() })
                }

                ColorWheelValueInput {
                    id: gInput
                    value: wheelRoot.greenOffset
                    channelColor: Colors.color_26FF31;
                    enabled: wheelRoot.wheelEnabled
                    onValueModified: (v) => wheelRoot.onChannelModified(1, v)
                    onIsDraggingChanged: wheelRoot.syncToViewModel(isDragging ? 0 : 2)
                    onTabPressed: Qt.callLater(function() { bInput.enterEditing() })
                }

                ColorWheelValueInput {
                    id: bInput
                    value: wheelRoot.blueOffset
                    channelColor: Colors.color_0000FF;
                    enabled: wheelRoot.wheelEnabled
                    onValueModified: (v) => wheelRoot.onChannelModified(2, v)
                    onIsDraggingChanged: wheelRoot.syncToViewModel(isDragging ? 0 : 2)
                    onTabPressed: Qt.callLater(function() { rInput.enterEditing() })
                }
            }

            // 行级大 MouseArea：覆盖整行并向左右下外扩，承载全部指针交互与光标对账。
            // 顶部不外扩(topMargin:0)，避免压住上方色轮弧针交互区。
            // 编辑中禁用本层 → 事件下传给编辑态 TextInput（点击定位光标/选区正常）。
            MouseArea {
                id: rgbMouseArea
                anchors.fill: rgbRow
                // 严格贴合整行，不外扩：避免吞掉相邻色条/隔壁框的 hover。
                // 恢复光标不依赖外扩带——warp 落点在框中心(离边≥10px)本就在区内，
                // 靠 onPositionChanged 几何对账恢复；彻底移出则由 onExited 兜底。
                z: 3                                   // 高于 rgbRow，接管指针事件
                enabled: wheelRoot.wheelEnabled && !wheelRoot.rgbInputs.some(i => i.editing)
                hoverEnabled: true
                cursorShape: Qt.ArrowCursor
                preventStealing: true

                property var boxes: wheelRoot.rgbInputs   // [rInput, gInput, bInput]
                property var dragBox: null                // 正在拖拽的框（null=未拖拽）
                property var hoverBox: null               // 当前 hover 命中的框
                property real dragStartX: 0
                property real dragStartValue: 0
                property bool isWarpingCursor: false      // warp 期间抑制异步事件干扰（同色轮）

                // 几何命中：返回鼠标(本区坐标)落在的框，未命中返回 null。
                function boxAt(mx, my) {
                    for (var i = 0; i < boxes.length; i++) {
                        var b = boxes[i];
                        if (!b.enabled) continue;
                        var p = b.mapFromItem(rgbMouseArea, mx, my);
                        if (p.x >= 0 && p.y >= 0 && p.x < b.width && p.y < b.height) return b;
                    }
                    return null;
                }
                function channelOf(box) {
                    return box === rInput ? 0 : box === gInput ? 1 : 2;
                }

                // 持续几何对账：命中框→水平箭头；未命中→恢复系统光标。不依赖 HoverLeave。
                function applyHover(mx, my) {
                    var hit = boxAt(mx, my);
                    if (hit && hit !== hoverBox) {
                        hoverBox = hit;
                        wheelRoot.setHorizontalCursor();
                    } else if (!hit && hoverBox) {
                        hoverBox = null;
                        cursorHelper.restoreAllOverrideCursors();
                    }
                }

                onPressed: function(mouse) {
                    wheelRoot.dismissAllEditing();
                    var hit = boxAt(mouse.x, mouse.y);
                    if (!hit) { mouse.accepted = false; return; }   // 空白区不拦截
                    dragBox = hit;
                    dragStartX = mouse.x;
                    dragStartValue = hit.value;
                }

                onEntered: { if (!isWarpingCursor && !dragBox) applyHover(mouseX, mouseY) }

                onPositionChanged: function(mouse) {
                    if (isWarpingCursor) return;
                    if (dragBox) {
                        var dx = mouse.x - dragStartX;
                        if (!dragBox.isDragging && Math.abs(dx) > 3) {
                            dragBox.isDragging = true;                 // 触发 FilterAdjust 起点同步
                            cursorHelper.restoreAllOverrideCursors();
                            cursorHelper.setOverrideCursor(Qt.BlankCursor);
                            hoverBox = null;
                        }
                        if (dragBox.isDragging) {
                            var nv = dragBox.clampValue(dragStartValue + Math.round(dx / 3) * dragBox.stepSize);
                            wheelRoot.onChannelModified(channelOf(dragBox), nv);
                        }
                        return;
                    }
                    applyHover(mouse.x, mouse.y);   // 未按下：持续几何对账（含 warp 落点后的移动）
                }

                onReleased: function(mouse) {
                    if (dragBox && dragBox.isDragging) {
                        var box = dragBox;
                        // warp 光标回框中心：保留“拖拽手感”。落点在本大 MouseArea 内。
                        var gp = box.mapToGlobal(box.width / 2, box.height / 2);
                        isWarpingCursor = true;
                        cursorHelper.setCursorPosWithHoverUpdate(gp.x, gp.y);
                        // 原子替换 BlankCursor → 水平箭头（不经过 count=0，无闪烁）
                        wheelRoot.setHorizontalCursor();
                        hoverBox = box;
                        box.isDragging = false;                        // 触发 FilterAdjust 终点同步
                        Qt.callLater(function() { rgbMouseArea.isWarpingCursor = false; });
                    } else if (dragBox) {
                        // 未拖拽（纯点击）→ 进入编辑；本层随后被 enabled 绑定禁用，事件转交 TextInput。
                        cursorHelper.restoreAllOverrideCursors();
                        hoverBox = null;
                        dragBox.enterEditing();
                    }
                    dragBox = null;
                }

                onExited: {
                    // 移出整行外扩区：仅在非拖拽/非 warp 时恢复。warp 落点在区内不会触发本回调。
                    if (dragBox || isWarpingCursor) return;
                    if (hoverBox) {
                        hoverBox = null;
                        cursorHelper.restoreAllOverrideCursors();
                    }
                }
            }
        }
    }

    // 弧形滑轨滑针绘制
    function paintPointer(ctx, cx, cy, toCenter) {
        ctx.clearRect(0, 0, 24, 24);
        var pLen = wheelRoot.arcPointerLength, pW = wheelRoot.arcPointerWidth / 2;
        var tipX = cx + pLen * Math.cos(toCenter);
        var tipY = cy + pLen * Math.sin(toCenter);
        var b1x = cx + pW * Math.cos(toCenter + Math.PI/2);
        var b1y = cy + pW * Math.sin(toCenter + Math.PI/2);
        var b2x = cx + pW * Math.cos(toCenter - Math.PI/2);
        var b2y = cy + pW * Math.sin(toCenter - Math.PI/2);
        ctx.beginPath(); ctx.moveTo(tipX,tipY); ctx.lineTo(b1x,b1y); ctx.lineTo(b2x,b2y); ctx.closePath(); // 绘制三角形
        ctx.fillStyle = Colors.color_EEEEEE; ctx.fill();  // 填充
    }

    // 单个通道值被修改时的统一处理
    function onChannelModified(channel, v) {
        // 值未变（编辑后未改动 / 输入相同值）不计入撤销栈
        var cur = channel === 0 ? redOffset : channel === 1 ? greenOffset : blueOffset;
        if (v === cur) return;

        if (channel === 0) redOffset = v;
        else if (channel === 1) greenOffset = v;
        else blueOffset = v;

        isSyncing = true;
        syncHueFromRgb();
        isSyncing = false;

        if (isRgbDragging) {
            syncToViewModel(1);
        } else {
            syncToViewModel(0);
            syncToViewModel(2);  // syncToViewModel(2) 内部已在提交时埋点
        }
    }

    // 设置光标
    function setVerticalCursor() {
        cursorHelper.setCustomCursor(":/icons/colorWheel/cursor_up_down_arrow.svg",
                                     cursorIconSize, cursorIconSize);
    }
    function setHorizontalCursor() {
        // 原子替换栈顶 override（拖拽时的 BlankCursor → 水平箭头），count>0 时不新增计数，
        // 避免闪烁；count==0 时（普通 hover 进入）内部会 setOverrideCursor 使 count=1。
        cursorHelper.changeToCustomCursor(":/icons/colorWheel/cursor_left_right_arrow.svg", 16, 16);
    }
    function setFourHeadedCursor() {
        cursorHelper.setCustomCursor(":/icons/colorWheel/cursor_move.svg",
                                     cursorIconSize, cursorIconSize);
    }
    // 统一管理花针提示框相关光标：
    //   tooltip 文本区 / 桥接条 / 编辑态 → 编辑太光标；
    //   离开这些区域 → 清除残留的滑针 hover 态并还原光标（Popup 在顶层，arcMouseArea 收不到
    //   exit，其 isHoveringArcHandle 会残留旧值；若鼠标实为移回滑针，arcMouseArea 会重新检测并恢复）。
    function updateTooltipCursor(tip) {
        cursorHelper.restoreAllOverrideCursors();
        if (tip.tooltipContainsMouse || tip.bridgeContainsMouse || tip.editing) {
            cursorHelper.setCustomCursor(":/icons/colorWheel/cursor_edit_state.svg",
                                         cursorIconSize, cursorIconSize);
        } else {
            arcMouseArea.isHoveringArcHandle = false;
            arcMouseArea.hoveredArcHandle = null;
        }
    }

    // 弧形滑针公共绑定初始化（normalizedValue / baseAngle 由调用方传入）
    function initArcHandle(item, normalizedBindingFn, baseAngle) {
        item.halfArc   = Qt.binding(function() { return arcTracksCanvas.halfArc; });
        item.arcRadius = Qt.binding(function() { return arcTracksCanvas.arcRadius; });
        item.centerX   = Qt.binding(function() { return arcTracksCanvas.x + arcTracksCanvas.width / 2; });
        item.centerY   = Qt.binding(function() { return arcTracksCanvas.y + arcTracksCanvas.height / 2; });
        item.normalizedValue = Qt.binding(normalizedBindingFn);
        item.baseAngle = baseAngle;
    }
}
