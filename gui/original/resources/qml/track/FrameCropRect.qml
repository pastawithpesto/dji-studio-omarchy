import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: root
    width: parent.width
    height: parent.height

    property bool isAction6Pro4K: false // 是否是Action6 Pro 拍摄的4k 1:1 素材
    property real blackRatio: 0  // ac206视频中黑边单边占比
    // 裁切框属性
    property string rectAspectRatio: "16:9" // 裁切画框的宽高比
    property bool orignalVideoIsCropped: false // 原视频有没有进行过画面裁切
    property real initAspect: 1.0
    property real initScale: 0 // 初始缩放比
    property real initTranselateX: 0 // 初始水平方向位移
    property real initTranselateY: 0 // 初始垂直方向位移

    property rect cropRect: Qt.rect(100, 100, 200, 240)
    property int originalCropWidth: parent.width // 裁切框原始宽度
    property int originalCropHeight: parent.height // 裁切框原始高度
    property int borderWidth: 2
    property int handleSize: 10
    property real aspectRatio: 1.0  // 宽高比 (width/height)
    property int minSize: 20

    property int defultHeight: parent.height // 设置为裁切播放器中画布的高度
    property int defultWidth: parent.width // 设置为裁切播放器中画布的宽度
    property int defultStartX: parent.x // 设置为裁切播放器中画布的左上角x
    property int defultStartY: parent.y // 设置为裁切播放器中画布的左上角y

    property real frameAspectRatio: defultWidth / defultHeight  // 播放器中视频画面真实的宽高比
    property bool isAspectChangedByOpen: false // 是否是刚打开裁切窗口导致裁切尺寸变化

    onVisibleChanged: {
        if(!root.visible){
            isAction6Pro4K = false;
            orignalVideoIsCropped = false;
        }else{
            isAspectChangedByOpen = true;
        }
    }

    onFrameAspectRatioChanged: {
        updateCropRect();
    }

    onRectAspectRatioChanged: {
        updateCropRect();
    }

    function updateCropRect(){
        if(root.rectAspectRatio === "16:9"){
            aspectRatio = 16 / 9;
        }else if(root.rectAspectRatio === "9:16"){
            aspectRatio = 9 / 16;
        }else if(root.rectAspectRatio === "1:1"){
            aspectRatio = 1.0;
        }else if(root.rectAspectRatio === "4:3"){
            aspectRatio = 4 / 3;
        }else if(root.rectAspectRatio === "3:4"){
            aspectRatio = 3 / 4;
        }

        if(!isAction6Pro4K){
            setCropRect(aspectRatio)
        }else{
            setBlackCropRect(aspectRatio)
        }
        maskCanvas.requestPaint();
    }

    function setCropRect(ratio){
        if(ratio > root.frameAspectRatio){
            root.cropRect.width = defultWidth;
            root.cropRect.height = defultWidth / ratio;
            root.cropRect.x = (root.width - defultWidth) / 2;
            root.cropRect.y = (root.height - root.cropRect.height) / 2;
        }else{
            root.cropRect.height = defultHeight;
            root.cropRect.width = defultHeight * ratio;
            root.cropRect.y = (root.height - defultHeight) / 2
            root.cropRect.x = (root.width - root.cropRect.width) / 2;
        }

        originalCropWidth = root.cropRect.width;
        originalCropHeight = root.cropRect.height;

        if(!isAspectChangedByOpen){
            return;
        }

        isAspectChangedByOpen = false;

        if(root.orignalVideoIsCropped){ // 如果原始视频已经被裁切过，初始裁切框设置为最近一次裁切时的位置
            root.cropRect.width = root.cropRect.width / root.initScale;
            root.cropRect.height = root.cropRect.height / root.initScale;

            root.cropRect.x = (root.width - root.cropRect.width) / 2 - (root.initTranselateX / root.initScale) * originalCropWidth
            root.cropRect.y = (root.height - root.cropRect.height) / 2 - (root.initTranselateY / root.initScale) * originalCropHeight
        }
    }

    // 黑边裁切时的裁切框设置
    function setBlackCropRect(ratio){

        var validMaxAspectRatio = 1 + 2 * blackRatio;
        var validMinAspectRatio = 1 - 2 * blackRatio;

        // 需要进行适配
        if(ratio > validMaxAspectRatio){
            root.cropRect.width = defultWidth;
            root.cropRect.height = defultWidth / ratio;
            root.cropRect.x = (root.width - root.cropRect.width) / 2;
            root.cropRect.y = (root.height - root.cropRect.height) / 2;

            originalCropWidth = root.cropRect.width;
            originalCropHeight = root.cropRect.height;
        }else if(ratio < validMinAspectRatio){
            root.cropRect.height = defultHeight;
            root.cropRect.width = defultHeight * ratio;
            root.cropRect.y = (root.height - root.cropRect.height) / 2
            root.cropRect.x = (root.width - root.cropRect.width) / 2;

            originalCropWidth = root.cropRect.width;
            originalCropHeight = root.cropRect.height;

        }else if(ratio > 1){
            root.cropRect.height = defultHeight * (1 - 2 * blackRatio);
            root.cropRect.width = root.cropRect.height * ratio;
            root.cropRect.y = (root.height - root.cropRect.height) / 2
            root.cropRect.x = (root.width - root.cropRect.width) / 2;

            originalCropWidth = root.cropRect.width;
            originalCropHeight = root.cropRect.height;
        }else if(ratio < 1){
            root.cropRect.width = defultWidth * (1 - 2 * blackRatio);
            root.cropRect.height = root.cropRect.width / ratio;
            root.cropRect.x = (root.width - root.cropRect.width) / 2;
            root.cropRect.y = (root.height - root.cropRect.height) / 2;
            originalCropWidth = root.cropRect.width;
            originalCropHeight = root.cropRect.height;

        }else if(ratio === 1){
            root.cropRect.width = defultWidth * (1 - 2 * blackRatio);
            root.cropRect.height = root.cropRect.width;
            root.cropRect.x = (root.width - root.cropRect.width) / 2;
            root.cropRect.y = (root.height - root.cropRect.height) / 2;

            originalCropWidth = defultWidth;
            originalCropHeight = defultHeight;
        }

        if(!isAspectChangedByOpen){
            return;
        }
        isAspectChangedByOpen = false;
        if(root.orignalVideoIsCropped){ // 如果原始视频已经被裁切过，初始裁切框设置为最近一次裁切时的位置
            root.cropRect.width = root.cropRect.width / root.initScale;
            root.cropRect.height = root.cropRect.height / root.initScale;

            root.cropRect.x = (root.width - root.cropRect.width) / 2 - (root.initTranselateX / root.initScale) * originalCropWidth
            root.cropRect.y = (root.height - root.cropRect.height) / 2 - (root.initTranselateY / root.initScale) * originalCropHeight
        }
    }

    // 裁切框
    Canvas {
        id: maskCanvas
        anchors.fill: parent

        property color borderColor: "#EEEEEE"
        property real borderWidth: 2  // 四条边中间部分的基准线宽
        property real cornerWidth: 5  // 四个圆角部分的线宽（4倍）
        property real cornerRadius: 4  // 圆角半径
        property real cornerLength: 40  // 圆角部分的单边长度

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            // 绘制半透明遮罩
            ctx.fillStyle = "#80000000"
            ctx.fillRect(0, 0, width, height)

            // 清除裁切区域
            ctx.globalCompositeOperation = "destination-out"
            drawRoundedRect(ctx, cropRect.x, cropRect.y, cropRect.width, cropRect.height, cornerRadius)
            ctx.fill()

            // 恢复绘制模式
            ctx.globalCompositeOperation = "source-over"

            // 计算裁切框各边1/4和3/4位置点（用于分割不同线宽区域）
            var left = cropRect.x
            var top = cropRect.y
            var right = cropRect.x + cropRect.width
            var bottom = cropRect.y + cropRect.height
            var r = cornerRadius

            var leftQuarter = left + cornerLength
            var rightQuarter = right - cornerLength
            var topQuarter = top + cornerLength
            var bottomQuarter = bottom - cornerLength

            ctx.strokeStyle = borderColor

            // 绘制四条边的中间部分（基准线宽）
            ctx.lineWidth = borderWidth
            ctx.beginPath()
            // 上边中间（从右圆角连接到左圆角）
            ctx.moveTo(rightQuarter, top)
            ctx.lineTo(leftQuarter, top)
            // 右边中间
            ctx.moveTo(right, topQuarter)
            ctx.lineTo(right, bottomQuarter)
            // 下边中间
            ctx.moveTo(leftQuarter, bottom)
            ctx.lineTo(rightQuarter, bottom)
            // 左边中间
            ctx.moveTo(left, bottomQuarter)
            ctx.lineTo(left, topQuarter)
            ctx.stroke()

            // 绘制四个圆角部分（4倍线宽）
            ctx.lineWidth = cornerWidth
            ctx.beginPath()

            // 左上圆角
            ctx.moveTo(left, top + r)
            ctx.arc(left + r, top + r, r, Math.PI, Math.PI * 1.5)
            // 从圆角终点连接到边线起点
            ctx.moveTo(left + r, top)
            ctx.lineTo(leftQuarter, top)
            ctx.moveTo(left, top + r)
            ctx.lineTo(left, topQuarter)

            // 右上圆角
            ctx.moveTo(right - r, top)
            ctx.arc(right - r, top + r, r, Math.PI * 1.5, 0)
            // 连接线
            ctx.moveTo(right - r, top)
            ctx.lineTo(rightQuarter, top)
            ctx.moveTo(right, top + r)
            ctx.lineTo(right, topQuarter)

            // 右下圆角
            ctx.moveTo(right, bottom - r)
            ctx.arc(right - r, bottom - r, r, 0, Math.PI * 0.5)
            // 连接线
            ctx.moveTo(right - r, bottom)
            ctx.lineTo(rightQuarter, bottom)
            ctx.moveTo(right, bottom - r)
            ctx.lineTo(right, bottomQuarter)

            // 左下圆角
            ctx.moveTo(left + r, bottom)
            ctx.arc(left + r, bottom - r, r, Math.PI * 0.5, Math.PI)
            // 连接线
            ctx.moveTo(left + r, bottom)
            ctx.lineTo(leftQuarter, bottom)
            ctx.moveTo(left, bottom - r)
            ctx.lineTo(left, bottomQuarter)

            ctx.stroke()

            if(cropMouseArea.isCropping){
                // 计算裁切框的边界
                let leftPos = cropRect.x
                let topPos = cropRect.y
                let rightPos = leftPos + cropRect.width
                let bottomPos = topPos + cropRect.height

                // 计算 1/3 和 2/3 的位置
                var thirdWidth = cropRect.width / 3
                var twoThirdWidth = 2 * thirdWidth

                var thirdHeight = cropRect.height / 3
                var twoThirdHeight = 2 * thirdHeight

                var left1 = leftPos + thirdWidth
                var left2 = leftPos + twoThirdWidth

                var top1 = topPos + thirdHeight
                var top2 = topPos + twoThirdHeight

                ctx.strokeStyle = borderColor

                ctx.lineWidth = 0.5

                // 绘制横向的两条线（将裁切框分为三等分）
                ctx.beginPath()
                ctx.moveTo(leftPos, top1)
                ctx.lineTo(rightPos, top1)

                ctx.moveTo(leftPos, top2)
                ctx.lineTo(rightPos, top2)

                // 绘制纵向的两条线
                ctx.moveTo(left1, topPos)
                ctx.lineTo(left1, bottomPos)

                ctx.moveTo(left2, topPos)
                ctx.lineTo(left2, bottomPos)

                ctx.stroke()
            }
        }

        // 圆角矩形路径
        function drawRoundedRect(ctx, x, y, w, h, r) {
            ctx.moveTo(x + r, y)
            ctx.lineTo(x + w - r, y)
            ctx.arcTo(x + w, y, x + w, y + r, r)
            ctx.lineTo(x + w, y + h - r)
            ctx.arcTo(x + w, y + h, x + w - r, y + h, r)
            ctx.lineTo(x + r, y + h)
            ctx.arcTo(x, y + h, x, y + h - r, r)
            ctx.lineTo(x, y + r)
            ctx.arcTo(x, y, x + r, y, r)
        }
    }


    // 覆盖裁切框MouseArea
    MouseArea {
            id: cropMouseArea
            anchors.fill: maskCanvas
            hoverEnabled: true
            z:1
            property bool isCropping: false // 是否在拖拽或者裁切中

            // 存储鼠标按下时的初始状态
            property point dragStart: Qt.point(0, 0)
            property rect startRect: Qt.rect(0, 0, 0, 0)
            property int edge: 0
            property int edgeUsedInMouseType: 0 // 用于更新鼠标样式， 必须单独一个变量，不能复用变量edge

            onPressed: (mouse) => {
                isCropping = true;
                dragStart = Qt.point(mouse.x, mouse.y)
                startRect = Qt.rect(cropRect.x, cropRect.y, cropRect.width, cropRect.height)

                // 确定用户点击的是哪个边缘或角落
                edge = getEdge(mouse.x, mouse.y)
                maskCanvas.requestPaint();

            }

            onReleased: (mouse) => {
                isCropping = false;
                maskCanvas.requestPaint();
            }

            onPositionChanged: (mouse) => {
                edgeUsedInMouseType = getEdge(mouse.x, mouse.y)  // 可以保证鼠标hover到可以缩放的区域时， 但是这里添加会导致绘制时发
                if (!pressed) return
                var dx = mouse.x - dragStart.x
                var dy = mouse.y - dragStart.y

                // 处理拖动逻辑
                if(edge === -1){
                    return;
                } else if (edge === 0) { // 拖动移动裁切框, 先处理这里，移动的时候进行处理
                    // 移动整个裁切框
                    var newX = Math.max(0, Math.min(maskCanvas.width - cropRect.width, startRect.x + dx))
                    var newY = Math.max(0, Math.min(maskCanvas.height - cropRect.height, startRect.y + dy))

                    newX = Math.max(newX, (root.width - defultWidth) / 2);
                    newX = Math.min(newX, (root.width - (root.width - defultWidth) / 2) - cropRect.width);

                    newY = Math.max(newY, (root.height - defultHeight) / 2);
                    newY = Math.min(newY, (root.height - (root.height - defultHeight) / 2) - cropRect.height);

                    if(isAction6Pro4K){
                       var result = snapToBlackEdge(newX, newY);
                       cropRect = Qt.rect(result.x, result.y, cropRect.width, cropRect.height);
                    }else{
                       cropRect = Qt.rect(newX, newY, cropRect.width, cropRect.height);
                    }
                    maskCanvas.requestPaint(); // 修改裁切框大小之后，必须手动调用cavans重新绘制
                } else { // 调整裁切框大小
                    adjustCropRect(dx, dy, edge) // todo: 新写一个黑块素材对应的方法
                    if(isAction6Pro4K){
                        adjustAc206BlackCropRect(edge)
                    }
                    maskCanvas.requestPaint(); // 修改裁切框大小之后，必须手动调用cavans重新绘制

                }
            }

            // 黑块裁切时实现自动吸附
            function snapToBlackEdge(newX, newY){
                var snapDistance = 10; // 吸附区域为边界的周边10像素
                var tempDefultHeight = defultHeight
                var snapLeft = defultStartX + defultWidth * blackRatio;
                var snapRight = defultStartX + defultWidth * (1 - blackRatio);
                var snapTop = defultStartY + defultHeight * blackRatio + 12;
                var snapBottom = defultStartY + defultHeight * (1 - blackRatio) + 12;

                var newLeftTopX = newX;
                var newLeftTopY = newY;
                var newRightTopX = newLeftTopX + cropRect.width;
                var newRightTopY = newLeftTopY;
                var newLeftBottomX = newLeftTopX;
                var newLeftBottomY = newLeftTopY + cropRect.height;
                var newRightBottomX = newRightTopX;
                var newRightBottomY = newLeftBottomY;

                if(Math.abs(newLeftTopX - snapLeft) < snapDistance){
                    return {
                        x: snapLeft,
                        y: newY,
                    };
                }else if(Math.abs(newLeftTopY - snapTop) < snapDistance){
                    return {
                        x: newX,
                        y: snapTop,
                    };
                }else if(Math.abs(newRightTopX - snapRight) < snapDistance){
                    return {
                        x: snapRight - cropRect.width,
                        y: newY,
                    };
                }else if(Math.abs(newRightTopY - snapTop) < snapDistance){
                    return {
                        x: newX,
                        y: snapTop,
                    };
                }else if(Math.abs(newRightBottomY - snapBottom) < snapDistance){
                    return {
                        x: newX,
                        y: snapBottom - cropRect.height,
                    };
                }else if(Math.abs(newRightBottomX - snapRight) < snapDistance){
                    return {
                        x: snapRight - cropRect.width,
                        y: newY,
                    };
                }else if(Math.abs(newLeftBottomX - snapLeft) < snapDistance){
                    return {
                        x: snapLeft,
                        y: newY,
                    };
                }else if(Math.abs(newLeftBottomY - snapBottom) < snapDistance){
                    return {
                        x: newX,
                        y: snapBottom - cropRect.height,
                    };
                }

                return {
                    x: newX,
                    y: newY,
                }
            }

            // 判断点击位置在裁切框的哪个边缘或角落
            function getEdge(x, y) {
                const margin = 10; // 边缘检测的容差范围
                const rect = cropRect;

                const inLeft = Math.abs(x - rect.x) <= margin && y >= rect.y && y <= rect.y + rect.height;
                const inRight = Math.abs(x - (rect.x + rect.width)) <= margin && y >= rect.y && y <= rect.y + rect.height;
                const inTop = Math.abs(y - rect.y) <= margin && x >= rect.x && x <= rect.x + rect.width;
                const inBottom = Math.abs(y - (rect.y + rect.height)) <= margin && x >= rect.x && x <= rect.x + rect.width;


                const inLeftTop = (Math.abs(x - rect.x) <= margin && y >= rect.y && y <= rect.y + rect.height * 1/4) || (Math.abs(y - rect.y) <= margin && x >= rect.x && x <= rect.x + rect.width * 1/4);
                const inRightTop = (Math.abs(x - (rect.x + rect.width)) <= margin && y >= rect.y && y <= rect.y + rect.height * 1/4) || (Math.abs(y - rect.y) <= margin && x >= rect.x + rect.width * 3/4 && x <= rect.x + rect.width);

                const inLeftBottom = (Math.abs(x - rect.x) <= margin && y >= rect.y + rect.height * 3/4 && y <= rect.y + rect.height) || (Math.abs(y - (rect.y + rect.height)) <= margin && x >= rect.x && x <= rect.x + rect.width * 1 /4);
                const inRightBottom = (Math.abs(x - (rect.x + rect.width)) <= margin && y >= rect.y + rect.height * 3/4 && y <= rect.y + rect.height) || (Math.abs(y - (rect.y + rect.height)) <= margin && x >= rect.x + rect.width * 3 /4  && x <= rect.x + rect.width)

                // 四个角落
                if (inLeftTop) return 5;
                if (inRightTop) return 6;
                if (inLeftBottom) return 8;
                if (inRightBottom) return 7;

                // 判断是否在框外部
                if(x < rect.x || x > rect.x + rect.width || y < rect.y || y > rect.y + rect.height){
                    return -1;
                }

                return 0;
            }

            // 调整裁切框大小
            function adjustCropRect(dx, dy, edge) {
                var rect = Qt.rect(startRect.x, startRect.y, startRect.width, startRect.height);
                var minSize = maskCanvas.cornerLength * 2; // 最小宽度和高度
                var canNotAdjust = false;

                // 检查当前是否已经到达边界
                switch (edge) {
                    case 5: // 左上角
                        canNotAdjust = (cropRect.x <= (root.width - defultWidth) / 2 || cropRect.y <= (root.height - defultHeight) / 2) && (dx < 0 || dy < 0);
                        break;
                    case 6: // 右上角
                        canNotAdjust = ((cropRect.x + cropRect.width) >= (root.width - (root.width - root.defultWidth) / 2) || (cropRect.y <= (root.height - root.defultHeight) / 2)) && (dx > 0 || dy < 0);
                        break;
                    case 7: // 右下角
                        canNotAdjust = ((cropRect.x + cropRect.width >= (root.width - (root.width - root.defultWidth) / 2)) || (cropRect.y + cropRect.height >= (root.height - (root.height - root.defultHeight) / 2))) && (dx > 0 || dy > 0)
                        break;
                    case 8: // 左下角
                        canNotAdjust = ((cropRect.x <= (root.width - defultWidth) / 2) || (cropRect.y + cropRect.height >= (root.height - (root.height - root.defultHeight) / 2))) && (dx < 0 || dy > 0)
                        break;
                }

                if(canNotAdjust){
                    return;
                }


                switch (edge) {
                    case 5: // 左上角
                        rect.x = Math.max((root.width - root.defultWidth) / 2, startRect.x + dx);
                        rect.width = startRect.width - (rect.x - startRect.x);
                        rect.height = rect.width / aspectRatio;
                        rect.y = startRect.y + (startRect.height - rect.height);
                        rect.y = Math.max((root.height - root.defultHeight) / 2, rect.y); // 确保不超出顶部边界
                        break;

                    case 6: // 右上角
                        rect.width = Math.min(maskCanvas.width - rect.x, startRect.width + dx);
                        rect.height = rect.width / aspectRatio;
                        rect.y = startRect.y + (startRect.height - rect.height);
                        rect.y = Math.max(0, rect.y); // 确保不超出顶部边界
                        break;

                    case 7: // 右下角
                        rect.width = Math.min(maskCanvas.width - rect.x, startRect.width + dx);
                        rect.height = rect.width / aspectRatio;
                        break;

                    case 8: // 左下角
                        rect.x = Math.max(0, startRect.x + dx);
                        rect.width = startRect.width - (rect.x - startRect.x);
                        rect.height = rect.width / aspectRatio;
                        break;
                }

                // 强制最小尺寸（优先保证宽度或高度不小于最小值）
                if (rect.width < minSize) {
                    rect.width = minSize;
                    rect.height = rect.width / aspectRatio;
                    // 修正位置（针对左上角、左下角、右上角的拖拽）
                    if (edge === 5 || edge === 8) rect.x = startRect.x + (startRect.width - rect.width);
                    if (edge === 5 || edge === 6) rect.y = startRect.y + (startRect.height - rect.height);
                }
                if (rect.height < minSize) {
                    rect.height = minSize;
                    rect.width = rect.height * aspectRatio;
                    // 修正位置（针对左上角、左下角、右上角的拖拽）
                    if (edge === 5 || edge === 8) rect.x = startRect.x + (startRect.width - rect.width);
                    if (edge === 5 || edge === 6) rect.y = startRect.y + (startRect.height - rect.height);
                }

                // 边界检查（保持宽高比）
                if (rect.x + rect.width > root.width - (root.width - root.defultWidth) / 2) {
                    rect.width = root.width - (root.width - root.defultWidth) / 2 - rect.x;
                    rect.height = rect.width / aspectRatio;
                }
                if (rect.y + rect.height > root.height - (root.height - root.defultHeight) / 2) {
                    rect.height = root.height - (root.height - root.defultHeight) / 2 - rect.y;
                    rect.width = rect.height * aspectRatio;
                }

                // 确保所有边界条件
                rect.x = Math.max((root.width - root.defultWidth) / 2, rect.x);
                rect.y = Math.max((root.height - root.defultHeight) / 2, rect.y);
                rect.width = Math.min(root.width - (root.width - root.defultWidth) / 2 - rect.x, rect.width);
                rect.height = Math.min(root.height - (root.height - root.defultHeight) / 2 - rect.y, rect.height);

                cropRect = rect;
            }

            // 裁切ac206素材时，缩放裁切框时进行吸附
            function adjustAc206BlackCropRect(edge){
                var rect = Qt.rect(cropRect.x, cropRect.y, cropRect.width, cropRect.height);
                var snapDistance = 10; // 吸附区域为边界的周边10像素

                var snapLeft = defultStartX + defultWidth * blackRatio;
                var snapRight = defultStartX + defultWidth * (1 - blackRatio);
                var snapTop = defultStartY + defultHeight * blackRatio + 12;
                var snapBottom = defultStartY + defultHeight * (1 - blackRatio) + 12;

                switch (edge) {
                case 5:{ // 左上角
                        let distanceX = Math.abs(cropRect.x - snapLeft);
                        let distanceY = Math.abs(cropRect.y - snapTop);

                        if(Math.min(distanceX, distanceY) > snapDistance){
                            break;
                        }

                        if(distanceX < distanceY){ // 向横轴上吸附

                            console.log("mathy ")
                            rect.x = snapLeft
                            var tempHeight = rect.height;
                            rect.width = rect.width + (cropRect.x - snapLeft);
                            rect.height = rect.width / aspectRatio;
                            rect.y = rect.y - (rect.height - tempHeight)

                        }else{ // 向纵轴上吸附
                            rect.y = snapTop
                            rect.height = rect.height + (cropRect.y - snapTop);
                            var tempWidth = rect.width;
                            rect.width = rect.height * aspectRatio;
                            rect.x = rect.x - (rect.width - tempWidth)
                        }

                        break;
                    }

                    case 6:{ // 右上角
                        let distanceX = Math.abs(cropRect.x + cropRect.width - snapRight);
                        let distanceY = Math.abs(cropRect.y - snapTop);

                        if(Math.min(distanceX, distanceY) > snapDistance){
                            break;
                        }

                        if(distanceX < distanceY){  // 在横轴上吸附
                            rect.width = rect.width + (snapRight - cropRect.width - cropRect.x);
                            var tempHeight = rect.height;
                            rect.height = rect.width / aspectRatio;
                            rect.y = rect.y - (rect.height - tempHeight)
                        }else{ // 在纵轴上吸附
                            rect.y = snapTop
                            rect.height = rect.height + (cropRect.y - snapTop);
                            rect.width = rect.height * aspectRatio;
                        }
                        break;
                    }

                    case 7:{ // 右下角
                        let distanceX = Math.abs(cropRect.x + cropRect.width - snapRight);
                        let distanceY = Math.abs(cropRect.y + cropRect.height - snapBottom);

                        if(Math.min(distanceX, distanceY) > snapDistance){
                            break;
                        }

                        if(distanceX < distanceY){  // 在横轴上吸附
                            rect.width = rect.width + (snapRight - (cropRect.x + rect.width));
                            rect.height = rect.width / aspectRatio;
                        }else{ // 在纵轴上吸附
                            rect.height = rect.height + (snapBottom - (cropRect.y + rect.height));
                            rect.width = rect.height * aspectRatio;
                        }

                        break;
                    }

                    case 8:{ // 左下角
                        let distanceX = Math.abs(cropRect.x- snapLeft);
                        let distanceY = Math.abs(cropRect.y + cropRect.height - snapBottom);

                        if(Math.min(distanceX, distanceY) > snapDistance){
                            break;
                        }

                        if(distanceX < distanceY){  // 在横轴上吸附
                            rect.x = snapLeft;
                            rect.width = rect.width + (cropRect.x - snapLeft);
                            rect.height = rect.width / aspectRatio;
                        }else{ // 在纵轴上吸附
                            rect.height = snapBottom - cropRect.y;
                            rect.width = rect.height * aspectRatio;
                            rect.x = rect.x - (rect.width - cropRect.width)
                        }
                        break;
                    }
                }

                cropRect = rect;
            }
        }
}
