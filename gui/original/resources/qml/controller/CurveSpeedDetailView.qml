import QtQuick 2.15
import QtQuick.Controls
import Config 1.0
import Controls 1.0
import "../track"

/**
  * @author: zhongshan.wang
  * @details 【变速曲线】界面
  * @date 2025-11-01 15:50
  */
Rectangle {
    id: root
    anchors.fill: parent
    color: Colors.color_19191A
    radius: 4

    // 输出的帧率
    property int outputFps: 30
    property int canvasPadding: 8
    // 控制点半径
    property int pointRadius: 5

    // 时间轴缩放属性
    property real scaleFactor: 1.0      // 当前缩放因子
    property real scaleMin: 1.0         // 最小缩放
    property real scaleMax: 10.0       // 最大缩放
    property real scrollOffset: 0.0     // 缩放后的平移偏移量（屏幕像素）
    readonly property real maxScrollOffset: canvas.width * (scaleFactor - 1) // scrollOffset 的最大值

    // 存储控制点数据
    property var points: []

    // 当前选中的点索引，-1表示没有选中
    property int selectedPointIndex: -1

    // 竖线的x坐标
    property real lineX: -1.0
    // 竖线与曲线的交叉点
    property point intersectionPoint: Qt.point(0, 0)

    // 拖拽中点的更新信号（用于强制Canvas重绘）
    signal pointsDragUpdated()

    // 视频总时长属性(1倍速下视频原长)
    property real totalDuration: 0
    // 当前视频时长（变速前）
    property real originalDuration: 0
    // 当前视频时长（变速后）
    property real targetDuration: 0

    // 添加裁剪范围属性
    property real clipStart: 0  // 片段起始位置
    property real clipEnd: 0    // 片段结束位置
    property real cutStart: 0  // 裁剪起始位置（0-1比例）
    property real cutEnd: 1    // 裁剪结束位置（0-1比例）

    // 当前播放位置（0-1的世界坐标）
    property real currentPlayPosition: -1.0

    // 标记鼠标是否被按住在 Canvas 上
    property bool mousePressed: false

    // 定义按钮最小间距
    property real pointMinDistance: totalDuration > 0 ? 1000 / totalDuration : 0.01
    // 标志位：是否禁止onCurrentPlayPositionChanged更新竖线
    property bool isUpdatingLineX: false
    // 记录指示器可见时是否在关键点上（用于指示器隐藏时保持添加/删除按钮显隐状态）
    property bool isOnControlPoint: false
    // 添加按钮是否满足距离条件（交叉点距离左右控制点超过最小间距）
    property bool isAddPointAllowed: false

    onCurrentPlayPositionChanged: {
        if (!isUpdatingLineX) {
            syncLineXFromPlayPosition();
        }
    }

    onScrollOffsetChanged: {
        if (!isUpdatingLineX) {
            syncLineXFromScroll();
        }
    }

    // 滚动时根据当前指示器的世界坐标重新映射屏幕位置
    function syncLineXFromScroll() {
        if (currentPlayPosition < 0 || canvas.width <= 0) return;

        // 如果指示器在关键点上，使用关键点的精确世界坐标
        var worldX;
        if (selectedPointIndex >= 0 && selectedPointIndex < points.length) {
            worldX = points[selectedPointIndex].x;
        } else {
            worldX = cutStart + currentPlayPosition * (cutEnd - cutStart);
        }

        var screenX = root.worldToScreenXZoomed(worldX);
        if (screenX < 0 || screenX > canvas.width) {
            root.lineX = -1;
            canvas.requestPaint();
        } else {
            root.lineX = screenX;
            updateIntersectionPoint();
            canvas.requestPaint();
        }
    }

    // 根据播放位置同步指示器，超出可视范围时隐藏
    function syncLineXFromPlayPosition() {
        if (currentPlayPosition < 0 || canvas.width <= 0) return;

        var worldX = cutStart + currentPlayPosition * (cutEnd - cutStart);
        var screenX = root.worldToScreenXZoomed(worldX);
        if (screenX < 0 || screenX > canvas.width) {
            root.lineX = -1;
            root.selectedPointIndex = -1;
            root.intersectionPoint = Qt.point(0, 0);
            canvas.requestPaint();
        } else {
            updateLineX(screenX);
        }
    }

    onClipStartChanged: {
        updateCutRange();
        // 刷新界面
        canvas.requestPaint();
    }
    onClipEndChanged: {
        updateCutRange();
        // 刷新界面
        canvas.requestPaint();
    }
    // 更新裁剪范围（将时间片位置转换为0-1比例）
    function updateCutRange() {
        if (totalDuration <= 0) {
            cutStart = 0;
            cutEnd = 1;
            return;
        }

        // 根据公式计算：clipEnd - clipStart + 1 = videoTotalDuration
        // 所以时间片范围 [clipStart, clipEnd] 对应比例范围 [0, 1]
        cutStart = clipStart / totalDuration;
        cutEnd = (clipEnd + 1) / totalDuration;
    }

    // 滑杆值(0~100)转换为缩放因子(1~10)
    function sliderToScale(sliderValue) {
        return scaleMin + (sliderValue / 100.0) * (scaleMax - scaleMin);
    }

    // 缩放因子(1~10)转换为滑杆值(0~100)
    function scaleToSlider(scale) {
        return (scale - scaleMin) / (scaleMax - scaleMin) * 100.0;
    }

    // 获取缩放步长
    function getZoomStep() {
        return 1;
    }

    // 应用缩放，以当前lineX为缩放中心
    function applyZoom(newScale) {
        newScale = Math.max(scaleMin, Math.min(scaleMax, newScale));
        if (Math.abs(newScale - scaleFactor) < 0.001) return;

        // 阻止缩放过程中scrollOffset变化触发syncLineXFromPlayPosition
        isUpdatingLineX = true;

        // 缩放中心：当前竖线在canvas中的屏幕位置
        var zoomCenterX = root.lineX >= 0 ? root.lineX : canvas.width / 2;

        // 缩放中心对应的世界坐标（在旧缩放下）
        var worldAtCenter = screenToWorldXZoomed(zoomCenterX);

        // 如果lineX在关键点上，使用关键点的精确世界坐标，避免浮点漂移
        var snapIndex = getLineXExistControlPointIndex();
        if (snapIndex >= 0) {
            worldAtCenter = root.points[snapIndex].x;
        }

        // 更新缩放因子
        scaleFactor = newScale;

        // 计算新的scrollOffset，使缩放中心不变
        // screenX = worldScreenX * scaleFactor - scrollOffset
        var worldScreenX = worldToScreenX(worldAtCenter);
        scrollOffset = worldScreenX * scaleFactor - zoomCenterX;

        // 缩放回最小值时精确重置，避免浮点误差导致滚动条残留
        if (Math.abs(scaleFactor - scaleMin) < 0.01) {
            scaleFactor = scaleMin;
            scrollOffset = 0;
        } else {
            // 限制scrollOffset范围
            clampScrollOffset();
        }

        // 将lineX精确对齐到关键点的新屏幕位置
        if (snapIndex >= 0) {
            root.lineX = worldToScreenXZoomed(root.points[snapIndex].x);
        }

        canvas.requestPaint();

        // 缩放完成后更新指示器位置
        if (snapIndex >= 0) {
            // 关键点对齐后更新指示器位置，不同步播放位置以避免中断播放
            updateLineX(root.lineX, false);
        } else {
            // 非关键点：用播放位置重新同步（处理指示器不可见后恢复的情况）
            syncLineXFromPlayPosition();
        }

        // 恢复标记
        isUpdatingLineX = false;

        // 写回ViewModel，用于记忆和持久化
        if (root.viewModel) {
            root.viewModel.curveSpeedZoomScale = scaleFactor;
        }
    }

    // 限制scrollOffset，确保内容不会超出可视范围太多
    function clampScrollOffset() {
        scrollOffset = Math.max(0, Math.min(maxScrollOffset, scrollOffset));
    }
    // 刷新面板
    // 输入，是否需要更新属性值
    function refreshPanel(needUpdateLine) {
        if(needUpdateLine){
            // 从ViewModel恢复缩放比例
            var savedScale = (root.viewModel && root.viewModel.curveSpeedZoomScale > 0)
                             ? root.viewModel.curveSpeedZoomScale : scaleMin;
            scaleFactor = Math.max(scaleMin, Math.min(scaleMax, savedScale));
            // scrollOffset = 0;
            selectedPointIndex = -1;
            intersectionPoint = Qt.point(0, 0);

            // 根据当前播放位置计算scrollOffset，使指示器居中显示
            if (currentPlayPosition >= 0 && canvas.width > 0) {
                var worldX = cutStart + currentPlayPosition * (cutEnd - cutStart);
                var baseScreenX = worldToScreenX(worldX);
                scrollOffset = baseScreenX * scaleFactor - canvas.width / 2;
                clampScrollOffset();
            } else {
                scrollOffset = 0;
            }

            syncLineXFromPlayPosition();
            // 刷新画布
            canvas.requestPaint();
        }
        else{
            updateLineX(root.lineX)
        }
    }

    // 在修改控制点前后保持指示器在同一时间点，并同步轨道指示器
    function withPreservedLineX(action) {
        // 如果指示器在关键点上，使用关键点的精确世界坐标，避免浮点漂移
        var savedWorldX;
        var snapIndex = getLineXExistControlPointIndex();
        if (snapIndex >= 0) {
            savedWorldX = root.points[snapIndex].x;
        } else {
            savedWorldX = root.screenToWorldXZoomed(root.lineX);
        }
        isUpdatingLineX = true;
        action();
        Qt.callLater(function() {
            // 先updateLineX同步轨道指示器，再恢复标记，防止中间被syncLineXFromPlayPosition覆盖
            var newScreenX = root.worldToScreenXZoomed(savedWorldX);
            updateLineX(newScreenX, true);
            canvas.requestPaint();
            isUpdatingLineX = false;
        });
    }

    // 添加控制点
    function addControlPoint() {
        if (root.lineX >= 0 && canvas.width > 0) {
            withPreservedLineX(function() {

            // 将屏幕lineX坐标转换为相对比例（考虑缩放）
            var lineXRatio = root.screenToWorldXZoomed(root.lineX);
            // 查找应该插入新点的位置
            var insertIndex = root.points.length - 1; // 默认插入到最后一个点之前

            // 查找应该插入新点的正确位置
            for (var i = 0; i < root.points.length - 1; i++) {
                if (lineXRatio >= root.points[i].x && lineXRatio <= root.points[i+1].x) {
                    insertIndex = i + 1;
                    break;
                }
            }

            // 如果插入位置是最后一个位置，不允许
            if (insertIndex >= root.points.length) {
                return
            }

            // 创建新点数组，避免直接修改原数组
            var newPoints = [];
            for (var j = 0; j < root.points.length; j++) {
                if (j === insertIndex) {
                    // 保留两位小数
                    var y = Math.round(root.intersectionPoint.y * 100) / 100;
                    newPoints.push({x: root.intersectionPoint.x, y: y});
                }
                newPoints.push(root.points[j]);
            }
            if (root.viewModel && typeof root.viewModel.updateChangedPoints === 'function') {
                // 在C++端直接修改点坐标，这样会触发pointsChanged信号并更新视图
                root.viewModel.updateChangedPoints(newPoints);
            }
            }); // withPreservedLineX
        }
    }

    // 删除控制点
    function removeControlPoint(index) {
        if (index >= 0 && index < root.points.length) {
            withPreservedLineX(function() {

            // 创建新点数组，避免直接修改原数组
            var newPoints = [];
            for (var j = 0; j < root.points.length; j++) {
                if (j !== index) {
                    newPoints.push(root.points[j]);
                }
            }
            if (root.viewModel && typeof root.viewModel.updateChangedPoints === 'function') {
                // 在C++端直接修改点坐标，这样会触发pointsChanged信号并更新视图
                root.viewModel.updateChangedPoints(newPoints);
            }
            }); // withPreservedLineX
        }
    }

    // 重置控制点到初始状态
    function resetControlPoints() {
        root.viewModel.resetControlPoints();
    }

    // 重置拖拽状态
    function resetDragState() {
        canvas.draggedPointIndex = -1;
    }

    // 更新竖线位置
    // syncPlay: 是否同步更新轨道指示器播放位置（仅在用户拖动竖线时为true，避免死循环）
    function updateLineX(x, syncPlay = false) {
        // 确保x值在有效范围内
        root.lineX = Math.max(0, Math.min(x, canvas.width));
        // 将屏幕坐标转换为世界坐标，检查是否在裁剪范围内（考虑缩放）
        var worldX = root.screenToWorldXZoomed(root.lineX);
        // 如果竖线超出了裁剪范围，将其移动到最近的边界
        if (worldX < cutStart) {
            root.lineX = root.worldToScreenXZoomed(cutStart);
            worldX = cutStart;
        } else if (worldX > cutEnd) {
            root.lineX = root.worldToScreenXZoomed(cutEnd);
            worldX = cutEnd;
        }
        canvas.requestPaint();

        // 如果需要同步播放位置，调用ViewModel更新轨道指示器
        if (syncPlay && root.viewModel && typeof root.viewModel.updatePlayPositionFromView === 'function') {
            var relativePosition = (worldX - cutStart) / (cutEnd - cutStart);
            root.viewModel.updatePlayPositionFromView(relativePosition);
        }

        // 计算并更新交叉点
        updateIntersectionPoint();
        // 记录指示器是否在关键点上（用于指示器隐藏时保持按钮显隐状态）
        isOnControlPoint = getLineXExistControlPointIndex() !== -1;
    }

    // 判断当前竖线是否存在控制点，范围竖线左右6px（考虑缩放比例）
    function getLineXExistControlPointIndex() {
        if( root.lineX < 0 || root.lineX > canvas.width ){
            return -1;
        }
        // 遍历所有控制点，判断当前竖线是否穿过
        for(var i = 0; i < root.points.length; i++){
            var point = root.points[i];
            // 只检查裁剪范围内的点
            if (point.x < cutStart || point.x > cutEnd) {
                continue;
            }

            // 计算控制点在屏幕上的位置，与Canvas绘制时使用相同的计算方式
            var pointScreenX = root.worldToScreenXZoomed(point.x);

            if( Math.abs(pointScreenX - root.lineX) <= root.pointRadius){
                return i;
            }
        }
        return -1;
    }

    // 将缩放后的屏幕坐标转换为世界坐标
    function screenToWorldXZoomed(screenX) {
        // 先反向应用缩放：screenX = baseScreenX * scaleFactor - scrollOffset
        // 所以 baseScreenX = (screenX + scrollOffset) / scaleFactor
        var baseScreenX = (screenX + scrollOffset) / scaleFactor;
        return screenToWorldX(baseScreenX);
    }

    // 将屏幕坐标转换为世界坐标（不考虑缩放）
    function screenToWorldX(screenX) {
        if (canvas.width <= 0) {
            return 0;
        }

        // 将局部坐标转换为原始比例（0-1）
        var rawRatio = screenX / canvas.width;

        // 将原始比例映射到裁剪范围内的比例
        return cutStart + rawRatio * (cutEnd - cutStart);
    }

    // 将世界坐标转换为缩放后的屏幕坐标
    function worldToScreenXZoomed(worldX) {
        var baseScreenX = worldToScreenX(worldX);
        return baseScreenX * scaleFactor - scrollOffset;
    }

    // 将世界坐标转换为屏幕坐标（不考虑缩放）
    // 以currentScreenX为缩放中心点
    function worldToScreenX(worldX) {
        if (canvas.width <= 0) {
            return 0;
        }
        // 将世界坐标（裁剪范围内的比例）转换为原始比例
        var rawRatio = (worldX - cutStart) / (cutEnd - cutStart);

        // 将局部坐标转换为屏幕坐标
        return rawRatio * canvas.width;
    }

    // 将屏幕坐标转换为世界坐标（Y轴，分上下两部分）
    // 返回值是canvas的高度比例值
    function screenToWorldY(screenY) {
        if(canvas.height <= 0){
            return 0;
        }
        screenY -= canvasPadding;
        var realHeight = canvas.height - 2 * canvasPadding;
        if(screenY < 0 || screenY > realHeight){
            return 0;
        }
        if (screenY >= realHeight/2) {
            return 1 - (1.8 / realHeight) * (screenY - realHeight / 2);
        }
        else{
            return 10 - (18 / realHeight) * screenY;
        }
    }

    // 将世界坐标转换为屏幕坐标（Y轴，分上下两部分）
    // 返回值是相对于canvas的y坐标
    function worldToScreenY(worldY) {
        if(worldY < 0 || worldY > 10){
            return 0;
        }
        var realHeight = canvas.height - 2 * canvasPadding;
        var screenY = 0;
        if (worldY <= 1) {
            screenY = realHeight * (0.5 + (1 - worldY) / 1.8);
        }
        else{
            screenY =  (10 - worldY) * realHeight / 18;
        }
        return screenY + canvasPadding;
    }

    // 计算竖线与曲线的交叉点
    function updateIntersectionPoint() {
        // 第一步 判断是否正在拖拽控制点
        if(canvas.draggedPointIndex !== -1){
            root.selectedPointIndex = canvas.draggedPointIndex;
            root.intersectionPoint = Qt.point(root.points[canvas.draggedPointIndex].x, root.points[canvas.draggedPointIndex].y);
            return;
        }
        // 第二步：如果当前竖线与控制点，取控制点的坐标
        var existIndex = getLineXExistControlPointIndex();
        if(existIndex >= 0){
            // 竖线所在的点，不计算交叉点
            root.selectedPointIndex = existIndex;
            root.intersectionPoint = Qt.point(root.points[existIndex].x, root.points[existIndex].y);
            return;
        }
        // 第三步：只有在不拖拽、不在控制点上时，才清理选中点索引
        root.selectedPointIndex = -1;
        // 第四步：否则，根据当前竖线位置，计算交叉点
        if (root.lineX < 0 || root.points.length < 2) {
            root.intersectionPoint = Qt.point(0, 0);
            return;
        }

        // 将屏幕lineX坐标转换为世界坐标（考虑裁剪和缩放）
        var lineXWorld = 0;
        if(canvas.width > 0){
            lineXWorld = root.screenToWorldXZoomed(root.lineX);
        }
        // 首先检查是否在裁剪范围内
        if (lineXWorld < cutStart || lineXWorld > cutEnd) {
            root.intersectionPoint = Qt.point(0, 0);
            return;
        }
        // 找到竖线所在的线段区间
        for (var i = 0; i < root.points.length - 1; i++) {
            var p1 = root.points[i];
            var p2 = root.points[i + 1];

            // 如果竖线在当前线段范围内
            if (lineXWorld >= p1.x && lineXWorld <= p2.x) {
                // 计算新点的y坐标（先转换为屏幕坐标进行插值，再转换回世界坐标）
                var ratio = 0;
                if(p2.x - p1.x > 0){
                    ratio = (lineXWorld - p1.x) / (p2.x - p1.x);
                }
                // 将世界坐标转换为屏幕坐标
                var p1ScreenY = worldToScreenY(p1.y);
                var p2ScreenY = worldToScreenY(p2.y);
                // 在屏幕坐标系中进行线性插值
                var newScreenY = p1ScreenY + ratio * (p2ScreenY - p1ScreenY);
                // 将计算出的屏幕坐标转换回世界坐标
                var newY = screenToWorldY(newScreenY);
                newY = Math.round(newY * 100) / 100;

                // 存储相对比例的x值和y值
                root.intersectionPoint = Qt.point(lineXWorld, newY);

                // 判断交叉点的x是否离左右控制点的距离超过pointMinDistance
                var isAddBtnEnable = Math.abs(lineXWorld - p1.x) > root.pointMinDistance && Math.abs(lineXWorld - p2.x) > root.pointMinDistance;
                root.isAddPointAllowed = isAddBtnEnable;
                return;
            }
        }

        // 如果没有找到交叉点，重置为默认值
        root.intersectionPoint = Qt.point(0, 0);
    }

    // 自动吸附功能 - 使用屏幕像素距离计算吸附阈值
    function applyAutoSnapping(currentY, draggedIndex) {
        if (root.points.length <= 0 || draggedIndex < 0 || draggedIndex >= root.points.length) {
            return null;
        }

        // 将Y坐标转换为屏幕坐标
        var currentScreenY = root.worldToScreenY(currentY);

        // 吸附阈值：屏幕上的像素距离
        var snapPixelDistance = 5;

        var closestY = null;
        var minPixelDiff = snapPixelDistance;

        // 检查左边相邻的点
        if (draggedIndex > 0) {
            var leftPoint = root.points[draggedIndex - 1];
            // 检查左边点是否在裁剪范围内
            if (leftPoint.x >= cutStart && leftPoint.x <= cutEnd) {
                var leftScreenY = root.worldToScreenY(leftPoint.y);
                var leftPixelDiff = Math.abs(currentScreenY - leftScreenY);

                if (leftPixelDiff < minPixelDiff) {
                    closestY = leftPoint.y;
                    minPixelDiff = leftPixelDiff;
                }
            }
        }

        // 检查右边相邻的点
        if (draggedIndex < root.points.length - 1) {
            var rightPoint = root.points[draggedIndex + 1];
            // 检查右边点是否在裁剪范围内
            if (rightPoint.x >= cutStart && rightPoint.x <= cutEnd) {
                var rightScreenY = root.worldToScreenY(rightPoint.y);
                var rightPixelDiff = Math.abs(currentScreenY - rightScreenY);

                if (rightPixelDiff < minPixelDiff) {
                    closestY = rightPoint.y;
                }
            }
        }

        return closestY;
    }

    // 拖拽优化Timer：拖动过程中定期把锚点同步到后端，片段实时变化
    Timer {
        id: updateTimer
        interval: 300
        repeat: true
        running: false

        onTriggered: {
            if (canvas.draggedPointIndex >= 0) {
                if (root.viewModel && typeof root.viewModel.updatePointAt === 'function') {
                    var point = root.points[canvas.draggedPointIndex];
                    root.viewModel.updatePointAt(canvas.draggedPointIndex, point.x, point.y);
                }
            }
        }
    }

    // 上部分容器 - 高度36（时长、添加、删除、重置按钮）
    Item {
        id: topContainer
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 36

        // 文本：原视频时长
        Text {
            id: originalTimeText
            anchors{
                top: parent.top
                left: parent.left
                leftMargin: 8
                topMargin: 11
                rightMargin: 8
            }
            text: DurationFormatter.format(root.originalDuration * root.outputFps / 1000000, root.outputFps);
            font.pixelSize: 10
            color: Colors.color_666666
        }
        Image {
            id: arrow
            anchors.topMargin: 10
            anchors.top: parent.top
            anchors.left: originalTimeText.right
            source: "qrc:/icons/panorama/next_key_frame_disable.svg"
            sourceSize: Qt.size(16, 16)
        }
        // 文本：目标视频时长
        Text {
            id: targetTimeText
            anchors{
                top: parent.top
                left: arrow.right
                topMargin: 11
                rightMargin: 8
            }
            text: DurationFormatter.format(root.targetDuration * root.outputFps / 1000000, root.outputFps);
            font.pixelSize: 10
            color: Colors.color_666666
        }

        // 重置按钮 - 最右侧
        ImageButton {
            id: resetButton
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: 12
            width: 20
            height: 20
            hoverEnabled: true
            normalImage: "qrc:/icons/curveSpeed/btn_reset_normal.svg"
            hoveredImage: "qrc:/icons/curveSpeed/btn_reset_clicked.svg"
            pushedImage: "qrc:/icons/curveSpeed/btn_reset_clicked.svg"
            disabledImage: "qrc:/icons/curveSpeed/btn_reset_disabled.svg"
            onClicked: resetControlPoints()
        }

        // 删除按钮 - 在重置按钮左边
        ImageButton {
            id: removeButton
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: resetButton.left
            anchors.rightMargin: 12
            width: 20
            height: 20
            visible: !addButton.visible
            enabled: root.selectedPointIndex !== -1 && root.selectedPointIndex !== 0 && root.selectedPointIndex !== root.points.length-1
            hoverEnabled: true
            normalImage: "qrc:/icons/curveSpeed/btn_remove_normal.svg"
            hoveredImage: "qrc:/icons/curveSpeed/btn_remove_clicked.svg"
            pushedImage: "qrc:/icons/curveSpeed/btn_remove_clicked.svg"
            disabledImage: "qrc:/icons/curveSpeed/btn_remove_disabled.svg"
            onClicked: removeControlPoint(root.selectedPointIndex)
        }

        // 添加控制点按钮 - 在删除/重置按钮左边
        ImageButton {
            id: addButton
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: removeButton.visible ? removeButton.left : resetButton.left
            anchors.rightMargin: 12
            width: 20
            height: 20
            enabled: root.isAddPointAllowed
            visible: root.lineX >= 0 ? getLineXExistControlPointIndex() === -1 : !isOnControlPoint
            hoverEnabled: true
            normalImage: "qrc:/icons/curveSpeed/btn_add_normal.svg"
            hoveredImage: "qrc:/icons/curveSpeed/btn_add_clicked.svg"
            pushedImage: "qrc:/icons/curveSpeed/btn_add_clicked.svg"
            disabledImage: "qrc:/icons/curveSpeed/btn_add_diabled.svg"
            onClicked: addControlPoint()
        }
    }

    Rectangle {
        id: dividerLine
        anchors.top: topContainer.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: Colors.color_content_area_background
    }

    Rectangle {
        id: dividerLine2
        anchors.bottom: scrollBarContainer.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: Colors.color_content_area_background
    }

    // 横向滚动条（缩放后可滑动查看整个面板）
    Item {
        id: scrollBarContainer
        anchors.top: bottomZoomContainer.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.scaleFactor > root.scaleMin ? 8 : 0
        visible: root.scaleFactor > root.scaleMin
        clip: true

        Rectangle {
            id: scrollBarTrack
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 4
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            height: 4
            radius: 2
            color: Colors.transparent

            Rectangle {
                id: scrollBarHandle
                // 滑块宽度 = 轨道宽度 / scaleFactor（表示可视区域占总内容的比例）
                width: Math.max(20, scrollBarTrack.width / root.scaleFactor)
                height: parent.height
                radius: 2
                color: scrollBarMouseArea.containsMouse ? Colors.color_37383A : Colors.color_2F3032
                // 滑块位置 = scrollOffset / maxOffset * (轨道可用宽度)
                x: {
                    if (root.maxScrollOffset <= 0) return 0;
                    var availableWidth = scrollBarTrack.width - width;
                    return (root.scrollOffset / root.maxScrollOffset) * availableWidth;
                }

                MouseArea {
                    id: scrollBarMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    // 扩大上下点击区域
                    anchors.topMargin: -4
                    anchors.bottomMargin: -4
                    preventStealing: true
                    property real dragStartX: 0
                    property real dragStartOffset: 0

                    onPressed: {
                        dragStartX = mapToItem(scrollBarTrack, mouseX, 0).x;
                        dragStartOffset = root.scrollOffset;
                    }
                    onPositionChanged: {
                        if (!pressed) return;
                        var trackX = mapToItem(scrollBarTrack, mouseX, 0).x;
                        var availableWidth = scrollBarTrack.width - scrollBarHandle.width;
                        if (availableWidth <= 0) return;
                        var deltaX = trackX - dragStartX;
                        var newOffset = dragStartOffset + (deltaX / availableWidth) * root.maxScrollOffset;
                        root.scrollOffset = Math.max(0, Math.min(root.maxScrollOffset, newOffset));
                        canvas.requestPaint();
                    }
                }
            }

            // 点击轨道空白处跳转
            MouseArea {
                anchors.fill: parent
                // 扩大上下点击区域
                anchors.topMargin: -4
                anchors.bottomMargin: -4
                z: -1
                onClicked: {
                    var availableWidth = scrollBarTrack.width - scrollBarHandle.width;
                    if (availableWidth <= 0) return;
                    // 将点击位置映射为scrollOffset（以滑块中心对齐点击位置）
                    var targetX = mouseX - scrollBarHandle.width / 2;
                    targetX = Math.max(0, Math.min(availableWidth, targetX));
                    root.scrollOffset = (targetX / availableWidth) * root.maxScrollOffset;
                    canvas.requestPaint();
                }
            }
        }
    }

    // 下部分容器 - 高度36（缩放控件，右对齐）
    Item {
        id: bottomZoomContainer
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.rightMargin: 12
        height: 36

        // 放大按钮（最右侧）
        ImageButton {
            id: zoomInButton
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            width: 20
            height: 20
            padding: 0
            enabled: root.scaleFactor < root.scaleMax
            hoverEnabled: true
            normalImage: "qrc:/icons/curveSpeed/btn_zoom_in_normal.svg"
            hoveredImage: "qrc:/icons/curveSpeed/btn_zoom_in_hover.svg"
            pushedImage: "qrc:/icons/curveSpeed/btn_zoom_in_hover.svg"
            disabledImage: "qrc:/icons/curveSpeed/btn_zoom_in_disabled.svg"
            onClicked: {
                var newScale = Math.min(root.scaleMax, root.scaleFactor + root.getZoomStep());
                root.applyZoom(newScale);
            }
        }

        // 缩放滑杆
        LightSlider {
            id: zoomSlider
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: zoomInButton.left
            anchors.rightMargin: 4
            width: 64
            height: 10
            padding: 0
            from: 0
            to: 100
            stepSize: 1
            lineWitdh: 2
            selectedColor: Colors.color_EEEEEE
            unSelectedColor: Colors.color_444444
            handleBorderColor: Colors.color_19191A
            Component.onCompleted: value = root.scaleToSlider(root.scaleFactor)
            onMoved: {
                var newScale = root.sliderToScale(value);
                root.applyZoom(newScale);
            }
            Connections {
                target: root
                function onScaleFactorChanged() {
                    zoomSlider.value = root.scaleToSlider(root.scaleFactor);
                }
            }
        }

        // 缩小按钮
        ImageButton {
            id: zoomOutButton
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: zoomSlider.left
            anchors.rightMargin: 4
            width: 20
            height: 20
            padding: 0
            enabled: root.scaleFactor > root.scaleMin
            hoverEnabled: true
            normalImage: "qrc:/icons/curveSpeed/btn_zoom_out_normal.svg"
            hoveredImage: "qrc:/icons/curveSpeed/btn_zoom_out_hover.svg"
            pushedImage: "qrc:/icons/curveSpeed/btn_zoom_out_hover.svg"
            disabledImage: "qrc:/icons/curveSpeed/btn_zoom_out_disabled.svg"
            onClicked: {
                var newScale = Math.max(root.scaleMin, root.scaleFactor - root.getZoomStep());
                root.applyZoom(newScale);
            }
        }
    }

    Canvas {
        id: canvas
        anchors.top: dividerLine.bottom
        anchors.bottom: dividerLine2.top
        anchors.left : parent.left
        anchors.right: parent.right
        property int draggedPointIndex: -1

        onWidthChanged: {
            root.clampScrollOffset();
            root.syncLineXFromPlayPosition();
        }

        onPaint: {
            var ctx = getContext("2d");
            ctx.resetTransform();
            ctx.clearRect(0, 0, width, height);

            // 绘制横线
            ctx.strokeStyle = Colors.color_37383A;
            ctx.lineWidth = 1;

            // 设置文本样式
            ctx.fillStyle = Colors.color_666666;
            // 使用跨平台兼容的字体列表，系统会选择第一个可用的字体
            ctx.font = "8px 'Arial Unicode MS', 'Helvetica Neue', 'PingFang SC', sans-serif";
            ctx.textBaseline = "middle";

            // 定义y值刻度
            var yValues = [10, 1, 0.1];

            // 绘制横线和数值
            for (var i = 0; i < yValues.length; i++) {
                var yValue = yValues[i];
                var y = root.worldToScreenY(yValue);

                var speed = yValue.toString() + "x";

                // 在右侧绘制速度数值（左对齐）
                var textX = width - 23; // 右侧区域的起始x坐标
                ctx.fillText(speed, textX, y);
            }

            // 检查是否有选中的点
            if (root.selectedPointIndex !== -1) {
                // 获取选中点的世界坐标
                var selectedPoint = root.points[root.selectedPointIndex];

                // 将世界坐标转换为屏幕坐标
                y = root.worldToScreenY(selectedPoint.y);

                // 绘制横向虚线
                ctx.strokeStyle = Colors.color_454649;
                ctx.lineWidth = 1;
                ctx.setLineDash([3,1]); // 设置虚线样式 (4像素实线, 4像素空白)

                ctx.beginPath();
                ctx.moveTo(0, y);
                ctx.lineTo(width, y);
                ctx.stroke();

                // 5. 绘制右侧的速度数值
                ctx.setLineDash([]); // 恢复实线状态，防止影响后续绘制
                ctx.fillStyle = Colors.color_EEEEEE; // 文字颜色

                // 计算文字位置：靠右
                textX = width - 23;

                // 格式化速度值
                var speedValue = selectedPoint.y;
                var speedText = "";
                if (Math.abs(speedValue - Math.round(speedValue)) < 0.001) {  // 判断是否是整数
                    speedText = speedValue.toFixed(0) + "x";  // 整数，不显示小数位
                } else {
                    // 先用两位小数
                    var twoDecimals = speedValue.toFixed(2);
                    // 检查最后一位是否为'0'
                    if (twoDecimals.charAt(twoDecimals.length - 1) === '0') {
                        // 最后一位是0，只显示一位小数
                        speedText = speedValue.toFixed(1) + "x";
                    } else {
                        speedText = twoDecimals + "x";
                    }
                }

                ctx.fillText(speedText, textX, y);
            }

            // 绘制平滑曲线（考虑缩放位置，但线宽固定）
            if (root.points.length > 1) {
                ctx.strokeStyle = Colors.color_F22443;
                ctx.lineWidth = 2;
                ctx.beginPath();

                // 找到裁剪范围内的第一个有效点和最后一个有效点
                var validPoints = [];

                // 首先收集所有在裁剪范围内的点
                for (var j = 0; j < root.points.length; j++) {
                    var point = root.points[j];
                    if (point.x >= cutStart && point.x <= cutEnd) {
                        validPoints.push(point);
                    }
                }

                // 如果裁剪边界处没有点，需要计算边界交点
                var startIntersection = null;
                var endIntersection = null;

                // 查找裁剪起始位置的交点
                if (cutStart > 0) {
                    for (var k = 0; k < root.points.length - 1; k++) {
                        var p1 = root.points[k];
                        var p2 = root.points[k + 1];

                        if (p1.x <= cutStart && p2.x >= cutStart) {
                            // 计算交点
                            var ratio = (cutStart - p1.x) / (p2.x - p1.x);
                            y = p1.y + ratio * (p2.y - p1.y);
                            startIntersection = {x: cutStart, y: y};
                            break;
                        }
                    }
                }
                // 查找裁剪结束位置的交点
                if (cutEnd < 1.0) {
                    for (var l = 0; l < root.points.length - 1; l++) {
                        p1 = root.points[l];
                        p2 = root.points[l + 1];

                        if (p1.x <= cutEnd && p2.x >= cutEnd) {
                            // 计算交点
                            ratio = (cutEnd - p1.x) / (p2.x - p1.x);
                            y = p1.y + ratio * (p2.y - p1.y);
                            endIntersection = {x: cutEnd, y: y};
                            break;
                        }
                    }
                }

                // 构建要绘制的点序列
                var drawPoints = [];
                // 如果有起始交点，添加起始交点
                if (startIntersection) {
                    drawPoints.push(startIntersection);
                }

                // 添加所有在裁剪范围内的点
                for (var m = 0; m < validPoints.length; m++) {
                    drawPoints.push(validPoints[m]);
                }

                // 如果有结束交点，添加结束交点
                if (endIntersection) {
                    drawPoints.push(endIntersection);
                }

                // 如果没有需要绘制的点，跳过
                if (drawPoints.length < 2) {
                    return;
                }
                // 对绘制点按x坐标排序
                drawPoints.sort(function(a, b) {
                    return a.x - b.x;
                });

                // 绘制贝塞尔曲线
                for (var n = 0; n < drawPoints.length - 1; n++) {
                    p1 = drawPoints[n];
                    p2 = drawPoints[n + 1];

                    // 将世界坐标转换为裁剪范围内的显示坐标（考虑缩放）
                    var screenX1 = root.worldToScreenXZoomed(p1.x);
                    var screenX2 = root.worldToScreenXZoomed(p2.x);
                    var screenY1 = root.worldToScreenY(p1.y);
                    var screenY2 = root.worldToScreenY(p2.y);

                    var cpOffset = Math.abs(screenX2 - screenX1) * 0.5;

                    if (n === 0) {
                        ctx.moveTo(screenX1, screenY1);
                    }

                    // 如果两个点之间的距离小于最小间距，用直线连接
                    if (Math.abs(p2.x - p1.x) < root.pointMinDistance) {
                        ctx.lineTo(screenX2, screenY2);
                    } else {
                        ctx.bezierCurveTo(
                                    screenX1 + cpOffset, screenY1,
                                    screenX2 - cpOffset, screenY2,
                                    screenX2, screenY2
                                    );
                    }
                }

                ctx.stroke();
            }

            // 绘制控制点（只显示裁剪范围内的点）
            for (var o = 0; o < root.points.length; o++) {
                point = root.points[o];

                // 只绘制裁剪范围内的点
                if (point.x >= cutStart && point.x <= cutEnd) {
                    // 将世界坐标转换为裁剪范围内的显示坐标（考虑缩放）
                    var screenX = root.worldToScreenXZoomed(point.x);
                    var screenY = root.worldToScreenY(point.y);

                    ctx.beginPath();
                    ctx.arc(screenX, screenY, root.pointRadius, 0, 2 * Math.PI);
                    ctx.fillStyle = (root.selectedPointIndex === o) ? Colors.color_F22443 : Colors.color_EEEEEE;
                    ctx.fill();
                    ctx.strokeStyle = Colors.color_19191A;
                    ctx.lineWidth = 2;
                    ctx.stroke();
                }
            }


            // 绘制选中点的竖线（限制在裁剪范围内，并尊重圆角）
            if (root.lineX >= 0) {
                // 将屏幕坐标转换为世界坐标，检查是否在裁剪范围内
                var lineWorldX = root.screenToWorldXZoomed(root.lineX);

                // 如果竖线在裁剪范围内，则绘制
                if (lineWorldX >= cutStart && lineWorldX <= cutEnd) {
                    var lineScreenX = root.lineX;
                    ctx.strokeStyle = Colors.color_EEEEEE;
                    ctx.lineWidth = 1;

                    var radius = 4; // 根据root的radius值
                    var canvasWidth = width;
                    var canvasHeight = height;

                    // 计算竖线应该绘制的起点和终点（考虑圆角）
                    var startY = 0;

                    // 检查左侧圆角范围
                    if (lineScreenX < radius) {
                        var dx = radius - lineScreenX;
                        if (dx <= radius) {  // 确保在圆角范围内
                            var dy = Math.sqrt(radius * radius - dx * dx);
                            startY = radius - dy;  // 顶部圆角的下边界
                        }
                    }
                    // 检查右侧圆角范围
                    else if (lineScreenX > canvasWidth - radius) {
                        dx = lineScreenX - (canvasWidth - radius);
                        if (dx <= radius) {  // 确保在圆角范围内
                            dy = Math.sqrt(radius * radius - dx * dx);
                            startY = radius - dy;  // 顶部圆角的下边界
                        }
                    }

                    ctx.beginPath();
                    ctx.moveTo(lineScreenX, startY);
                    ctx.lineTo(lineScreenX, height);
                    ctx.stroke();
                }
            }
        }

        // 响应触摸板双指缩放手势（macOS）
        PinchArea {
            id: pinchHandler
            anchors.fill: parent
            property real initScale: 1.0

            onPinchStarted: {
                initScale = root.scaleFactor;
            }
            onPinchUpdated: (pinch) => {
                var targetScale = pinch.scale * initScale;
                root.applyZoom(targetScale);
            }

            // 响应触摸板双指滑动手势（macOS）
            MouseArea {
                anchors.fill: parent
                scrollGestureEnabled: true

                onWheel: (wheel) => {
                    // 仅在缩放状态下响应水平滑动
                    if (root.scaleFactor <= root.scaleMin) {
                        wheel.accepted = false;
                        return;
                    }
                    var deltaX = wheel.pixelDelta.x;
                    if (Math.abs(deltaX) > 0) {
                        root.scrollOffset = Math.max(0, Math.min(root.maxScrollOffset, root.scrollOffset - deltaX));
                        canvas.requestPaint();
                    }
                }
            }

        // 响应鼠标事件
        MouseArea {
            id: mouseArea
            anchors.fill: parent
            scrollGestureEnabled: false
            property real pointStartX: 0
            property real pointStartY: 0
            property real mouseStartX: 0
            property real mouseStartY: 0
            // 关键修改：允许鼠标事件传播，这样即使鼠标移出，也能继续接收事件
            propagateComposedEvents: true
            // 启用悬停跟踪
            hoverEnabled: true
            property bool draggingLine: false
            property var draggedPointsBeforeDrag: null

            onPressed: {
                root.mousePressed = true;
                // 设置标志，防止拖动过程中onCurrentPlayPositionChanged干扰竖线位置
                root.isUpdatingLineX = true;
                updateTimer.start();
                // 将屏幕坐标转换为世界坐标（考虑缩放）
                var worldX = root.screenToWorldXZoomed(mouseX);
                canvas.draggedPointIndex = -1;

                // 检查是否点击在控制点上
                for (var i = 0; i < root.points.length; i++) {
                    var point = root.points[i];
                    // 只检查裁剪范围内的点
                    if (point.x < cutStart || point.x > cutEnd) {
                        continue;
                    }
                    // 计算控制点在屏幕上的位置（考虑缩放）
                    var pointScreenX = root.worldToScreenXZoomed(point.x);
                    var pointScreenY = root.worldToScreenY(point.y);

                    // 计算距离（使用相同的屏幕坐标系）
                    var distanceX = Math.abs(mouseX - pointScreenX);
                    var distanceY = Math.abs(mouseY - pointScreenY);

                    // 判断是否点击在控制点上
                    if (distanceX <= root.pointRadius) {
                        pointStartX = point.x;
                        pointStartY = point.y;
                        mouseStartX = mouseX;
                        mouseStartY = mouseY;
                        root.selectedPointIndex = i;

                        canvas.requestPaint();
                        if(distanceY <= root.pointRadius){
                            // 点击在控制点上
                            root.selectedPointIndex = i;
                            canvas.draggedPointIndex = i;
                        }
                        continue;
                    }
                }
                // 没有点击在控制点上，重置拖动状态
                // 直接使用鼠标的屏幕坐标更新竖线位置
                // 将updateLineX放到下个循环来执行
                updateLineX(mouseX, true);
                // 如果没有点击到控制点，则开始拖动竖线
                if (canvas.draggedPointIndex === -1) {
                    draggingLine = true;
                }
                else {
                    draggedPointsBeforeDrag = JSON.parse(JSON.stringify(root.points));
                    // 锚点拖拽期间后端逐 tick commit(false) 刷新代价高，发拖拽态信号让 VM 抑制刷新，松手统一对账
                    globalSignal.speedDragStart();
                }
            }

            onPositionChanged: {
                if (canvas.draggedPointIndex >= 0) {
                    var newX = root.screenToWorldXZoomed(mouseX);

                    // 限制控制点不能拖出裁剪范围
                    if (canvas.draggedPointIndex === 0) {
                        // 首点保持原来的x坐标不变
                        newX = root.points[canvas.draggedPointIndex].x;
                    } else if (canvas.draggedPointIndex === root.points.length - 1) {
                        // 尾点保持原来的x坐标不变
                        newX = root.points[canvas.draggedPointIndex].x;
                    } else {
                        // 中间点限制在裁剪范围内
                        newX = Math.max(cutStart, Math.min(cutEnd, newX));

                        // 同时受相邻点限制
                        if (canvas.draggedPointIndex > 0) {
                            newX = Math.max(newX, root.points[canvas.draggedPointIndex - 1].x + root.pointMinDistance);
                        }
                        if (canvas.draggedPointIndex < root.points.length - 1) {
                            newX = Math.min(newX, root.points[canvas.draggedPointIndex + 1].x - root.pointMinDistance);
                        }
                    }

                    var screenY = mouseY;
                    if(screenY < 0) screenY = 0;
                    // 限制在上下各8px的范围内
                    screenY = Math.max(canvasPadding, Math.min(canvas.height - canvasPadding, screenY));
                    var newY = root.screenToWorldY(screenY);

                    // 如果开启了自动吸附功能
                    var autoSnapping = lightSetting.getBool("key_auto_snapping", false);
                    if (autoSnapping) {
                        // 计算拖动方向
                        var dragDirection = mouseY - mouseStartY;  // 负数=向上，正数=向下
                        var pointScreenY = root.worldToScreenY(root.points[canvas.draggedPointIndex].y);
                        // 检查鼠标是否拖过了锚点位置
                        var hasCrossedPoint = (dragDirection < 0 && mouseY < pointScreenY) ||
                                                 (dragDirection > 0 && mouseY > pointScreenY);
                        // 计算向上、向下能拖动的像素
                        var upPixels = pointScreenY - canvasPadding;
                        var downPixels = (canvas.height - canvasPadding) - pointScreenY;

                        // 根据拖动方向，获取可用像素
                        var availablePixels = dragDirection < 0 ? upPixels : downPixels;
                        // 只有空间充足且拖动距离小于5px，才吸附
                        if (hasCrossedPoint && availablePixels < 5) {
                            // 禁用吸附，使用自由拖动值 newY
                        } else {
                            // 正常吸附
                            var snappedY = applyAutoSnapping(newY, canvas.draggedPointIndex);
                            if (snappedY !== null) {
                                newY = snappedY;
                            }
                        }
                    }
                    newY = Math.round(newY * 100) / 100;
                    newY = Math.max(0.1, Math.min(10, newY));

                    // 确保x值在裁剪范围内
                    newX = Math.max(cutStart, Math.min(cutEnd, newX));

                    // 通过对象重新赋值来让QML识别到变化
                    var point = root.points[canvas.draggedPointIndex];
                    point.x = newX;
                    point.y = newY;
                    root.points[canvas.draggedPointIndex] = point;

                    // 立即重绘Canvas显示位置
                    canvas.requestPaint();

                    // 更新竖线位置
                    var newScreenX = root.worldToScreenXZoomed(newX);
                    updateLineX(newScreenX, true);
                } else if (draggingLine) {
                    // 如果正在拖动竖线，即使鼠标移出控件，也要继续更新

                    // 计算鼠标的有效位置（限制在裁剪范围内）
                    var effectiveMouseX = mouseX;

                    // 如果鼠标移出左侧，将竖线移动到裁剪范围的起始位置
                    if (mouseX < 0) {
                        effectiveMouseX = 0;
                        // 将竖线移动到裁剪起始位置的屏幕坐标
                        var startScreenX = root.worldToScreenXZoomed(cutStart);
                        updateLineX(startScreenX, true);
                        return;
                    }

                    // 如果鼠标移出右侧，将竖线移动到裁剪范围的结束位置
                    if (mouseX > canvas.width) {
                        effectiveMouseX = canvas.width;
                        // 将竖线移动到裁剪结束位置的屏幕坐标
                        var endScreenX = root.worldToScreenXZoomed(cutEnd);
                        updateLineX(endScreenX, true);
                        return;
                    }

                    // 正常情况下，根据鼠标位置更新竖线
                    var worldX = root.screenToWorldXZoomed(effectiveMouseX);

                    if (worldX >= cutStart && worldX <= cutEnd) {
                        Qt.callLater(updateLineX, effectiveMouseX, true);
                    }
                }
            }

            onReleased: {
                root.mousePressed = false
                // 重置标志，允许onCurrentPlayPositionChanged更新竖线
                root.isUpdatingLineX = false;
                updateTimer.stop();
                // 拖拽前锚点快照；清拖拽态发收尾信号，随后最终落库 commit 触发的刷新不再被抑制
                var pointsBeforeDrag = draggedPointsBeforeDrag;
                if (pointsBeforeDrag !== null) {
                    draggedPointsBeforeDrag = null;
                    globalSignal.speedDragEnd();
                }

                // 拖动结束时，最后同步一次数据到后端
                if (canvas.draggedPointIndex >= 0) {
                    if (root.viewModel && typeof root.viewModel.updatePointAt === 'function') {
                        var point = root.points[canvas.draggedPointIndex];
                        root.viewModel.updatePointAt(canvas.draggedPointIndex, point.x, point.y);
                        // 最终提交换了曲线映射，而拖动期用旧映射发出的 seek 异步回调可能在提交后才回灌
                        // currentPlayPosition，导致指示线跳到滞后的播放位置。提交后按新曲线把播放头重新
                        // 对齐到最终锚点、并重钉指示线，让最后一次回灌收敛回锚点。
                        if (cutEnd > cutStart && typeof root.viewModel.updatePlayPositionFromView === 'function') {
                            root.viewModel.updatePlayPositionFromView((point.x - cutStart) / (cutEnd - cutStart));
                        }
                        updateLineX(root.worldToScreenXZoomed(point.x), false);
                    }
                }

                // 拖动结束时，如果有拖动过锚点，记录一次撤销
                if (canvas.draggedPointIndex >= 0 && pointsBeforeDrag !== null) {
                    var currentPoints = JSON.parse(JSON.stringify(root.points));
                    // 只有当点的坐标确实改变时，才记录撤销
                    if (JSON.stringify(pointsBeforeDrag) !== JSON.stringify(currentPoints)) {
                        root.viewModel.commitPointChange(pointsBeforeDrag, currentPoints);
                    }
                }
                // 释放鼠标时重置拖动状态
                canvas.draggedPointIndex = -1;
                draggingLine = false;
            }
            onWheel: (wheel) => {
                // Ctrl+滚轮 或 触控板双指缩放（macOS触控板pinch会发送带Ctrl的wheel事件）
                if (wheel.modifiers & Qt.ControlModifier) {
                    wheel.accepted = true;
                    // macOS触控板pinch使用pixelDelta实现平滑缩放
                    if (wheel.pixelDelta.y !== 0) {
                        var pixelStep = wheel.pixelDelta.y / 50.0;
                        var newScale = Math.max(root.scaleMin, Math.min(root.scaleMax, root.scaleFactor + pixelStep));
                        root.applyZoom(newScale);
                    } else {
                        var delta = wheel.angleDelta.y > 0 ? root.getZoomStep() : -root.getZoomStep();
                        var newScale2 = Math.max(root.scaleMin, Math.min(root.scaleMax, root.scaleFactor + delta));
                        root.applyZoom(newScale2);
                    }
                } else if (root.mousePressed) {
                    wheel.accepted = true
                } else {
                    wheel.accepted = false
                }
            }
        }
        } // PinchArea
    }


}
