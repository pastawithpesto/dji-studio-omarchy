import QtQuick 2.15
import Config 1.0
import QmlConstants 1.0
import app_qrc 1.0

/**
 * @author robert.guo
 * @desc tk拖画框的控件
 * @create_date 2024-07-15
 */
Rectangle {
    id: root
    color: Colors.transparent
    property bool startTk: false
    property bool trackingLoss: false
    property int destRectIndex: 0
    property bool isUseDefalutRect: false

    property rect selectedTarget: Qt.rect(0, 0, 0, 0)
    property int showCount: 0
    property int originalTargetIndex: 9999
    property int deathZoneIndex: 9998
    property int maxShowCount: 30

    property bool hasMoved: false

    // 定义一个阈值，只有touch滑动距离超过阈值才会触发tk
    property int delta: 3

    property double deathZoneFactor: 0.01
    property double deathZoneVOffset: 0

    /**
     * @desc 返回当前用户拖拽框的位置和长宽信息
     */
    function getRectPositionInfo() {
        // 数据格式按照机器学习的要求封装，方框中心点x， y， 方框的宽， 方框的高， 取值范围都是百分比，0-1
        if(root.isUseDefalutRect){
            canvas.drawing = true;
            defalutRect.visible = false;
            var startX = defalutRect.x;
            var startY = defalutRect.y;
            var endX = defalutRect.x + defalutRect.width;
            var endY = defalutRect.y + defalutRect.height;

            var realStartX = startX;
            var realStartY = startY;
            var realEndX = endX;
            var realEndY = endY;
            if (startX > endX) {
                realStartX = realEndX;
                realEndX = startX;
            }
            if (startY > endY) {
                realStartY = endY;
                realEndY = startY;
            }

            // 处理拖动手势拖到区域之外的情况
            if (realStartX < 0) {
                realStartX = 0;
            }
            if (realStartX > width) {
                realStartX = width;
            }
            if (realStartY < 0) {
                realStartY = 0;
            }
            if (realStartY > height) {
                realStartY = height;
            }
            if (realEndX < 0) {
                realEndX = 0;
            }
            if (realEndX > width) {
                realEndX = width;
            }
            if (realEndY < 0) {
                realEndY = 0;
            }
            if (realEndY > height) {
                realEndY = height;
            }


            var x1 = (realStartX + (realEndX - realStartX)/2) / (width);
            var y1 = (realStartY + (realEndY - realStartY)/2) / (height);
            var width1 = (realEndX - realStartX) / width;
            var height1 = (realEndY - realStartY) / height;
            var rect1 = Qt.rect(x1, y1, width1, height1);
            return rect1;
        }else{
            var _x = (canvas.tempStart.x + (canvas.tempEnd.x - canvas.tempStart.x)/2) / (width);
            var _y = (canvas.tempStart.y + (canvas.tempEnd.y - canvas.tempStart.y)/2) / (height);
            var _width = (canvas.tempEnd.x - canvas.tempStart.x) / width;
            var _height = (canvas.tempEnd.y - canvas.tempStart.y) / height;
            var rect = Qt.rect(_x, _y, _width, _height);
            return rect;
        }
    }

    /**
     * @desc 根据用户拖拽框信息，转换成居中框信息
     * @return
     */
    function getRectCenterPositionInfo() {
        var rect = getRectPositionInfo();
        rect.x = 0.5
        rect.y = 0.5
        return rect;
    }

    function getVideoSize() {
        return Qt.size(width, height)
    }

    /**
     * @desc 清空数据和画布
     */
    function clearData() {
        canvas.start.x = -1;
        canvas.start.y = -1;
        canvas.end.x = -1;
        canvas.end.y = -1;
        canvas.requestPaint();
        canvas.drawing = false;
    }

    /**
     * @desc 清空数据和画布
     */
    function clearCanvasOnly() {
        canvas.start.x = -1;
        canvas.start.y = -1;
        canvas.end.x = -1;
        canvas.end.y = -1;
        canvas.requestPaint();
    }

    /**
     * @desc 接收机器学习返回的识别框信息，并重新绘制ui
     *
     * @param centerX 中心点x位置百分比
     * @param centerY 中心点y位置百分比
     * @param widthRatio 框的宽度百分比
     * @param heightRatio 框的高度百分比
     * @param trackingIsLoss tracking是否丢失
     */
    function trackingRectChanged(centerX, centerY, widthRatio, heightRatio, trackingIsLoss) {
        trackingLoss = trackingIsLoss
        var rectWidth = widthRatio * width
        var rectHeigt = heightRatio * height
        var rectCenterX = centerX * width
        var rectCenterY = centerY * height

        canvas.start.x = rectCenterX - rectWidth / 2;
        canvas.start.y = rectCenterY - rectHeigt / 2;
        canvas.end.x = rectCenterX + rectWidth / 2;
        canvas.end.y = rectCenterY + rectHeigt / 2;

        rectModel.clear();
        rectModel.append(Qt.rect(centerX, centerY, widthRatio, heightRatio));

        canvas.requestPaint();
    }

    function updateSelectedTarget(target) {
        selectedTarget = target
        showCount = 0
    }

    function updateDeathZoneFactor(factor, vOffset) {
        deathZoneFactor = factor
        deathZoneVOffset = vOffset
    }

    ListModel {
        id: rectModel
    }

    function trackingRecommandListChanged(rectList) {
        if (hasMoved || editorManager.isInUserGuideStatus) {
            return;
        }
        smartRecommandRectView.trackingRecommandListChanged(rectList)
    }


    function trackingRectListChanged(rectList, mainRectIndex, trackingIsLoss, bodyRectIndex) {
        trackingLoss = trackingIsLoss
        destRectIndex = bodyRectIndex !== -1 ? bodyRectIndex :mainRectIndex
        rectModel.clear();
        for (var i = 0; i < rectList.length; ++i) {
            if (rectList[i] === null || rectList[i] === undefined) {
                continue
            }

            rectModel.append({"x": rectList[i].x, "y": rectList[i].y, "width": rectList[i].width, "height": rectList[i].height})
        }

        canvas.dataReturn = true;
        canvas.requestPaint()
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        // 用户拖拽时，实际的起始点
        property point start
        // 用户拖拽时，实际的结束点
        property point end

        // 拖拽方框真实的左上角
        property point tempStart
        // 拖拽方框真实的右下角
        property point tempEnd

        property bool dataReturn: false

        // 是否要进行绘制
        property bool drawing: false
        // 默认圆角半径的两倍
        property int defaultCornerRadius: 20
        // 绘制真实的圆角半径
        property int cornerRadius: 2
        // 虚线框的宽度
        property int lineWidth: 2

        Component.onCompleted: {
            canvas.start.x = 285;
            canvas.start.y = 117;
            canvas.end.x = 485;
            canvas.end.y = 317;
        }

        function drawSingleRect(ctx, index) {

            // 根据当前的start和end，重新算出真正的左上和右下两个点
            tempStart.x = start.x;
            tempStart.y = start.y;
            tempEnd.x = end.x;
            tempEnd.y = end.y;
            if (start.x > end.x) {
                tempStart.x = end.x;
                tempEnd.x = start.x;
            }
            if (start.y > end.y) {
                tempStart.y = end.y;
                tempEnd.y = start.y;
            }

            // 处理拖动手势拖到区域之外的情况
            if (tempStart.x < 0) {
                tempStart.x = 0;
            }
            if (tempStart.x > width) {
                tempStart.x = width;
            }
            if (tempStart.y < 0) {
                tempStart.y = 0;
            }
            if (tempStart.y > height) {
                tempStart.y = height;
            }
            if (tempEnd.x < 0) {
                tempEnd.x = 0;
            }
            if (tempEnd.x > width) {
                tempEnd.x = width;
            }
            if (tempEnd.y < 0) {
                tempEnd.y = 0;
            }
            if (tempEnd.y > height) {
                tempEnd.y = height;
            }

            // 区域过小不绘制
            if (tempEnd.x - tempStart.x < 1 || tempEnd.y - tempStart.y < 1) {
                return;
            }
            // 下面是移动端的方案
            if (drawing) {
                if (startTk) {
                    var x = tempStart.x;
                    var y = tempStart.y;
                    var w = Math.abs(tempEnd.x - tempStart.x);
                    var h = Math.abs(tempEnd.y - tempStart.y);

                    //缩放过程中，最短边限制为长度12
                    var center = tempStart;
                    center.x = (tempStart.x + tempEnd.x) / 2;
                    center.y = (tempStart.y + tempEnd.y) / 2;

                    if(w < 12)
                    {
                        w = 12;
                    }

                    if(h < 12)
                    {
                        h = 12;
                    }

                    x = center.x - w / 2;
                    y = center.y - h / 2;

                    // Draw the green lines
                    if (trackingLoss) {
                        ctx.strokeStyle = ColorsConfig.color_brand;
                        ctx.fillStyle = Colors.color_transparent;
                        ctx.fillRect(x, y, w, h)
                    } else {
                        if (destRectIndex === index) {
                            ctx.strokeStyle = Colors.color_32E494
                        } else if (originalTargetIndex === index) {
                            ctx.strokeStyle = ColorsConfig.color_brand;
                        } else if (deathZoneFactor === index) {
                            ctx.strokeStyle = Colors.color_EEEEEE;
                        } else{
                            ctx.strokeStyle = Colors.color_FFFFFF;
                        }
                    }

                    ctx.lineWidth = 2;

                    var horizontalSegmentWidth = Math.min(w,h) / 4;
                    //限制tk四角边框一面的长度
                    if(horizontalSegmentWidth > 18) {
                        horizontalSegmentWidth = 18;
                    }

                    var verticalSegmentWidth = Math.min(w,h) / 4;
                    //限制tk四角边框一面的长度
                    if(verticalSegmentWidth > 18) {
                        verticalSegmentWidth = 18;
                    }

                    var SegmentWidth = Math.min(horizontalSegmentWidth,verticalSegmentWidth)

                    var radius = 4
                    if(SegmentWidth < radius) {
                        radius = SegmentWidth
                    }

                    //左上角
                    ctx.beginPath();
                    ctx.moveTo(x, y + SegmentWidth);
                    ctx.lineTo(x, y + radius);
                    ctx.arc(x + radius, y + radius, radius, Math.PI, Math.PI*3/2);
                    ctx.lineTo(x + radius, y);
                    ctx.lineTo(x + SegmentWidth, y);
                    ctx.stroke();

                    //右上角
                    ctx.beginPath();
                    ctx.moveTo(x + w - SegmentWidth, y);
                    ctx.lineTo(x + w - radius, y);
                    ctx.arc(x + w - radius, y + radius, radius, Math.PI*3/2, Math.PI*2);
                    ctx.lineTo(x + w, y + radius);
                    ctx.lineTo(x + w, y + SegmentWidth);
                    ctx.stroke();

                    //右下角
                    ctx.beginPath();
                    ctx.moveTo(x + w, y + h - SegmentWidth);
                    ctx.lineTo(x + w, y + h - radius);
                    ctx.arc(x + w - radius, y + h - radius, radius, 0, Math.PI/2);
                    ctx.lineTo(x + w - radius, y + h);
                    ctx.lineTo(x + w - SegmentWidth, y + h);
                    ctx.stroke();

                    //左下角
                    ctx.beginPath();
                    ctx.moveTo(x + SegmentWidth, y + h);
                    ctx.lineTo(x + radius, y + h);
                    ctx.arc(x + radius, y + h - radius, radius, Math.PI/2, Math.PI);
                    ctx.lineTo(x, y + h - radius);
                    ctx.lineTo(x, y + h - SegmentWidth);
                    ctx.stroke();

                } else {
                    ctx.clearRect(0, 0, width, height)
                    var x = tempStart.x;
                    var y = tempStart.y;
                    var w = tempEnd.x - tempStart.x;
                    var h = tempEnd.y - tempStart.y;
                    var radius = 4
                    if(w < radius * 2) {
                        radius = w / 2
                    }
                    if(h < radius * 2) {
                        radius = h / 2
                    }

                    ctx.strokeStyle = Colors.color_32E494;
                    ctx.fillStyle = Colors.color_32E494_20
                    ctx.lineWidth = 2;
                    ctx.beginPath();

                    if(w < radius * 2) {
                        radius = w / 2
                    }
                    if(h < radius * 2) {
                        radius = h / 2
                    }
                    
                    // 从左上角开始，顺时针绘制
                    ctx.moveTo(x + radius, y);
                    // 上边线
                    ctx.lineTo(x + w - radius, y);
                    // 右上角圆角
                    ctx.arc(x + w - radius, y + radius, radius, -Math.PI/2, 0);
                    // 右边线
                    ctx.lineTo(x + w, y + h - radius);
                    // 右下角圆角
                    ctx.arc(x + w - radius, y + h - radius, radius, 0, Math.PI/2);
                    // 下边线
                    ctx.lineTo(x + radius, y + h);
                    // 左下角圆角
                    ctx.arc(x + radius, y + h - radius, radius, Math.PI/2, Math.PI);
                    // 左边线
                    ctx.lineTo(x, y + radius);
                    // 左上角圆角
                    ctx.arc(x + radius, y + radius, radius, Math.PI, -Math.PI/2);
                    
                    ctx.closePath();
                    ctx.stroke();
                    ctx.fill()
                }
            }
        }

        onPaint: {
            var ctx = getContext("2d");
            // 先清空画布内容
            ctx.clearRect(0, 0, width, height);
            var trackingCenterX = 0.0
            var trackingCenterY = 0.0

            if (dataReturn) {
                var multiRectShow = lightSetting.getBool("multiRectShow")
                for (var i = 0; i < rectModel.count; i++) {
                    if (!multiRectShow && i !== destRectIndex) {
                        continue;
                    }

                    var rectWidth = rectModel.get(i).width * width
                    var rectHeigt = rectModel.get(i).height * height
                    var rectCenterX = rectModel.get(i).x * width
                    var rectCenterY = rectModel.get(i).y * height

                    trackingCenterX = rectCenterX
                    trackingCenterY = rectCenterY

                    start.x = rectCenterX - rectWidth / 2;
                    start.y = rectCenterY - rectHeigt / 2;
                    end.x = rectCenterX + rectWidth / 2;
                    end.y = rectCenterY + rectHeigt / 2;
                    drawSingleRect(ctx, i)
                }

                var targetSw = lightSetting.getBool("targetSw")
                if (targetSw && showCount < maxShowCount) {
                    showCount = showCount + 1
                    var selectedTargetWidth = selectedTarget.width * width
                    var selectedTargetHeigt = selectedTarget.height * height
                    var selectedTargetCenterX = selectedTarget.x * width
                    var selectedTargetCenterY = selectedTarget.y * height

                    start.x = selectedTargetCenterX - selectedTargetWidth / 2;
                    start.y = selectedTargetCenterY - selectedTargetHeigt / 2;
                    end.x = selectedTargetCenterX + selectedTargetWidth / 2;
                    end.y = selectedTargetCenterY + selectedTargetHeigt / 2;
                    drawSingleRect(ctx, originalTargetIndex)
                }

                var deathZoneSw = lightSetting.getBool("deathZoneSw")
                if (deathZoneSw) {
                    var deathZoneTargetWidth = deathZoneFactor * width * 2.0;
                    var deathZoneTargetHeight = deathZoneFactor * height * 2.0;

                    var deathZoneCenterX = 0.5 * width;
                    var deathZoneCenterY = (0.5 + deathZoneVOffset) * height;

                    start.x = deathZoneCenterX - deathZoneTargetWidth / 2;
                    start.y = deathZoneCenterY - deathZoneTargetHeight / 2;
                    end.x = deathZoneCenterX + deathZoneTargetWidth / 2;
                    end.y = deathZoneCenterY + deathZoneTargetHeight / 2;
                    drawSingleRect(ctx, originalTargetIndex)

                    ctx.fillStyle = Colors.color_FFCC00      // 点的颜色
                    ctx.strokeStyle = Colors.color_FFCC00   // 边框颜色（如果绘制矩形）

                    ctx.fillRect(trackingCenterX, trackingCenterY, 3, 3)
                }

                return;
            }

            drawSingleRect(ctx, 0)



            // 下面的insta 360的画框方案
            /**
            // 重新计算圆角半径
            if (tempEnd.y - tempStart.y < defaultCornerRadius && tempEnd.x - tempStart.x < defaultCornerRadius) {
                cornerRadius = Math.min(tempEnd.y - tempStart.y, tempEnd.x - tempStart.x) / 2;
            } else if (tempEnd.y - tempStart.y < defaultCornerRadius) {
                cornerRadius = (tempEnd.y - tempStart.y) / 2;
            } else if (tempEnd.x - tempStart.x < defaultCornerRadius) {
                cornerRadius = (tempEnd.x - tempStart.x) / 2;
            } else {
                cornerRadius = defaultCornerRadius / 2;
            }

            // 开始绘制
            if (drawing) {
                var dashedLinePattern = [5, 2];  // 前面的5表示每个虚线长度，2是虚线之间的间隔长度
                ctx.setLineDash(dashedLinePattern);
                ctx.lineCap = "round";
                ctx.strokeStyle = Colors.color_tk_rect_border;
                ctx.fillStyle = Colors.color_tk_rect_fill;
                ctx.lineWidth = lineWidth;
                ctx.beginPath();
                ctx.moveTo(tempStart.x, tempStart.y + cornerRadius);
                ctx.arcTo(tempStart.x, tempStart.y, tempStart.x + cornerRadius, tempStart.y, cornerRadius);
                ctx.lineTo(tempEnd.x - cornerRadius, tempStart.y);
                ctx.arcTo(tempEnd.x, tempStart.y, tempEnd.x, tempStart.y + cornerRadius, cornerRadius);
                ctx.lineTo(tempEnd.x, tempEnd.y - cornerRadius);
                ctx.arcTo(tempEnd.x, tempEnd.y, tempEnd.x - cornerRadius, tempEnd.y, cornerRadius);
                ctx.lineTo(tempStart.x + cornerRadius, tempEnd.y);
                ctx.arcTo(tempStart.x, tempEnd.y, tempStart.x, tempEnd.y - cornerRadius, cornerRadius);
                ctx.closePath();

                // fill打开后，方框将被实心填充
                ctx.fill();

                ctx.stroke();
            }**/
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton

            onPressed: (mouse) => {
                if (startTk) {
                    return;
                }

                hasMoved = false;
                if (mouse.button === Qt.LeftButton) {
                    canvas.start.x = mouse.x;
                    canvas.start.y = mouse.y;
                    canvas.end.x = mouse.x;
                    canvas.end.y = mouse.y;
                    canvas.drawing = true;
                    canvas.dataReturn = false;
                    globalSignal.closeAnimationInTkGuide();
                }
            }

            onPositionChanged: (mouse) => {
                if (startTk) {
                    return;
                }

                var moveX = Math.abs(mouse.x - canvas.start.x);
                var moveY = Math.abs(mouse.y - canvas.start.y);
                if (moveX > delta || moveY > delta) {
                    hasMoved = true;
                    smartRecommandRectView.clearData()
                } else {
                    return;
                }

                if (mouse.buttons === Qt.LeftButton && canvas.drawing) {
                    canvas.end.x = mouse.x;
                    canvas.end.y = mouse.y;
                    canvas.requestPaint();
                }
            }

            onReleased: (mouse) => {
                if (startTk) {
                    smartRecommandRectView.clearData()
                    return;
                }

                if (!hasMoved) {
                    logger.d("TrackRectLayer no movement happens")
                    canvas.end.x = mouse.x;
                    canvas.end.y = mouse.y;
                    canvas.requestPaint();
                    // globalSignal.trackingEnterAction();
                    return;
                }
                smartRecommandRectView.clearData()

                if (mouse.button === Qt.LeftButton && canvas.drawing) {
                    canvas.end.x = mouse.x;
                    canvas.end.y = mouse.y;
                    canvas.requestPaint();
                    globalSignal.trackingReadyAction();
                    let width = Math.abs(canvas.end.x - canvas.start.x)
                    let height = Math.abs(canvas.end.y - canvas.start.y)
                    let sizeStr = width.toString() + "*" + height.toString()
                    eventTracker.trackEvent("pccut_tk_frame", {"frame": sizeStr, "tk_sdk": QmlConstants.trackingSDKVersion})
                    if(editorManager.isInUserGuideStatus){
                        globalSignal.nextStepInTkGuide();
                        root.enabled = false;
                    }
                }
            }
        }
    }

    // 追踪指引时点下一步时自动生成的追踪框位置
    Rectangle {
        id: defalutRect
        visible: isUseDefalutRect && editorManager.isInUserGuideStatus
        width: 97
        height: 135
        color: "transparent"  // 背景透明
        border.color: Colors.color_tk_rect_border
        border.width: 2
        anchors.centerIn: parent
    }


    function clearSmartRecommaneData() {
        smartRecommandRectView.clearData()
        rectModel.clear()
    }

    SmartRecommandRectView {
        id: smartRecommandRectView
        imageSource: "qrc:/app_qrc/icons/recommand_rect_tk.gif"
        imageWidth: 30
        imageHeight: 30
        parentWidth: root.width
        parentHeight: root.height

        Connections {
            target: smartRecommandRectView
            function onTrackRectChanged(x, y, width, height) {
                root.hasMoved = true
                canvas.drawing = true

                canvas.tempStart.x = (x - width/2)* root.width
                canvas.tempStart.y = (y - height/2)*root.height
                canvas.tempEnd.x = (x + width/2)*root.width
                canvas.tempEnd.y = (y + height/2)*root.height

                rectModel.clear()
                canvas.requestPaint()

                globalSignal.trackingReadyAction();
                globalSignal.trackingStartAction();
            }
        }

        Connections {
            target: globalSignal
            function onTrackingExitAction() {
                clearSmartRecommaneData()
            }
        }
    }
}
