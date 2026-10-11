import QtQuick.Window 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.3
import QtQuick 2.15
import Controls 1.0
import Config 1.0
import Qt5Compat.GraphicalEffects
import FpsDetect 1.0
import MousePositionTracker 1.0
import UserGuideMaskManager 1.0
import UserGuideTypeModel 1.0
import Nova 1.0
import Qt.labs.animation 1.0
import "../user_guide"

LightClipRectangle {
    id:mask
    property var userGuideType : UserGuideType.UNKOWN
    property var rectArray : userGuideMaskManager.rectArray
    property bool isMainWindowOutScreen: false  // 主窗口是否有部分在屏幕外
    objectName: "mask"
    width: parent.width
    height: parent.height
    anchors.centerIn: parent
    radius: [10,10,10,10]
    z: 1
    color: Colors.transparent
    clip:true

    signal maskAreaUpdate();

    onVisibleChanged: {
        if(!mask.visible){
            userGuideMaskManager.guideStep = 0;
            editorManager.isInUserGuideStatus = false;
            globalSignal.enableMenuBar(true);
            shaderEffect.clearRect();
        }
    }

    onUserGuideTypeChanged: {
        userGuideMaskManager.userGuideType = mask.userGuideType;
    }

    // 获取镂空区域位置
    UserGuideMaskManager{
        id:userGuideMaskManager
        userGuideType : mask.userGuideType
        guideStep : -1
    }

    // 实时捕获全局鼠标位置
    MousePositionTracker{
        id:mousePositionTracker

        onMousePositionChanged: {
            var globalX = mousePositionTracker.mouseX;
            var globalY = mousePositionTracker.mouseY;
            var localPos = mousePositionTracker.mapFromGlobal(lightWindow, globalX, globalY);

            var x = localPos.x / mask.width;
            var y = localPos.y / mask.height;

            var isInHollowArea = false;

            for (var i = 0; i < mask.rectArray.length; i++) {
                var rect = mask.rectArray[i];

                var rectX = rect.x;
                var rectY = rect.y;
                var rectWidth = rect.width;
                var rectHeight = rect.height;

                var lowerLeft = {x: rectX, y: rectY};
                var upperRight = {x: rectX + rectWidth, y: rectY + rectHeight};

                if (x > lowerLeft.x / mask.width && x < upperRight.x / mask.width &&
                    y > lowerLeft.y / mask.height && y < upperRight.y / mask.height) {
                    isInHollowArea = true;
                    break;
                }
            }

            if (!isInHollowArea) {
                maskMouseArea.hoverEnabled = true;
            } else {
                maskMouseArea.hoverEnabled = false;
            }
        }

    }
    Connections {
        target: mask
        function onMaskAreaUpdate() {
            if( keyFrameGuide.isEnterStep3Model && mask.userGuideType === UserGuideType.KEYFRAME){
                userGuideMaskManager.guideStep = 2;
            }else{
                userGuideMaskManager.guideStep = 0;
            }

            if( regionKeyFrameGuide.isEnterStep3Model && mask.userGuideType === UserGuideType.REGIONKEYFRAME){
                userGuideMaskManager.guideStep = 2;
            }else{
                userGuideMaskManager.guideStep = 0;
            }

            shaderEffect.updateMaskArea();
        }
    }

    // 绘制蒙层
    Canvas {
        id: shaderEffect
        anchors.fill: parent

        property var center1: Qt.point(0.3, 0.5) // 第一个镂空矩形的中心
        property var size1: Qt.size(0.3, 0.3) // 第一个镂空矩形的大小

        property var center2: Qt.point(0.75, 0.75) // 第二个镂空矩形的中心
        property var size2: Qt.size(0.2, 0.2) // 第二个镂空矩形的大小

        function updateMaskArea() {
                    requestPaint();
                }

        function isDrawBorder(index){
            return true;
        }

        // 清空绘制的镂空区域
        function clearRect(){
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            requestPaint();
        }

        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            // 绘制黑色蒙层
            ctx.fillStyle = "rgba(0, 0, 0, 0.5)";
            if(userGuideMaskManager.userGuideType === UserGuideType.KEYFRAME ||
               userGuideMaskManager.userGuideType === UserGuideType.TRANSITION_EFFECT ||
               userGuideMaskManager.userGuideType === UserGuideType.TRACKING ||
               userGuideMaskManager.userGuideType === UserGuideType.REGIONKEYFRAME ||
               userGuideMaskManager.userGuideType === UserGuideType.KEYFRAMESTART ||
               userGuideMaskManager.userGuideType === UserGuideType.SUPER_SLOW){
                ctx.fillStyle = Colors.transparent;
            }


            ctx.fillRect(0, 0, width, height);
            for (var i = 0; i < mask.rectArray.length; i++) {
                var rect = mask.rectArray[i];
            }

            // 遍历 rectArray 并抠出每个矩形区域
            for (var i = 0; i < mask.rectArray.length; i++) {
                var rect = mask.rectArray[i];
                var x = rect.x;
                var y = rect.y;
                var rectWidth = rect.width;
                var rectHeight = rect.height;
                var radius = 6; // 圆角半径
                let deltaBoard = 0;

                if(rectWidth === 0 || rectHeight === 0 || x < 0 || y < 0){  // 兜底逻辑: 出现获取目标元素位置错误时，直接退出新手引导，防止弹窗位置错乱导致蒙层无法关闭
                    mask.visible = false;
                    userGuideMaskManager.guideStep = 0;
                    editorManager.isInUserGuideStatus = false;
                    return;
                }

                if(rect.name === actionableItemName.mainPlayerControl || rect.name === actionableItemName.keyframeButton || rect.name === actionableItemName.addKf){
                    x = rect.x + rect.width / 2 - 20;
                    y = rect.y + rect.height / 2 - 20;
                    rectWidth = 40;
                    rectHeight = 40;
                    deltaBoard = -1;
                }

                if(rect.name === actionableItemName.playerContainer){
                    x = rect.x;
                    y = rect.y;
                    rectWidth = rect.width;
                    rectHeight = rect.height - 5;
                }

                let radius1 = 2;
                let adjust = 0;
                if(rect.name === actionableItemName.appBarExportRectangle || rect.name === actionableItemName.addMediaButton){
                    x = rect.x - 3;
                    y = rect.y - 3;
                    rectWidth = rect.width + 6;
                    rectHeight = rect.height + 6;
                    deltaBoard = 0;
                    radius1 = 2;
                    adjust = 2;
                }

                if(rect.name === actionableItemName.videoItemTrack0Clip0){
                    x = rect.x + 1;
                    y = rect.y;
                    rectWidth = rect.width;
                    rectHeight = rect.height;
                }

                // 抠出矩形区域
                ctx.clearRect(x - adjust, y - adjust, rectWidth + 2 * adjust, rectHeight + 2 * adjust);

                if(rect.name === actionableItemName.mainPlayerHeader || rect.name === actionableItemName.videoItemTrack0Clip0 || rect.name === "tkFragmentRect" || rect.name === "playerContainerRoot"){
                    continue;
                }
                if(rect.name === actionableItemName.playerContainer && userGuideMaskManager.userGuideType === UserGuideType.OVERALL){
                    continue;
                }

                if(rect.name === actionableItemName.tkFragmentRect){
                    y += 1;
                    rectHeight -= 2;
                }

                // 绘制外层描边
                ctx.strokeStyle = "rgba(255, 255, 255, 0.1)";
                ctx.lineWidth = 8; // 设置外层描边宽度

                if(rect.name === actionableItemName.playerContainer){
                    var rect1 = userGuideMaskManager.getItemRect(actionableItemName.playerContainerRoot)
                    x = rect1.x;
                    y = rect1.y;
                    ctx.lineWidth = 10
                    rectWidth = rect1.width;
                    rectHeight = rect1.height;
                }

                if(rect.name === actionableItemName.addMediaButton || rect.name === actionableItemName.appBarExportRectangle || rect.name === actionableItemName.keyframeButton){
                    ctx.lineWidth = 8
                }

                ctx.beginPath();
                let delX = 3 + deltaBoard;
                ctx.moveTo(x + radius1 + delX, y - delX);
                ctx.lineTo(x + rectWidth - radius1 - delX, y - delX);
                ctx.quadraticCurveTo(x + rectWidth + delX, y - delX, x + rectWidth + delX, y + radius1 + delX);
                ctx.lineTo(x + rectWidth + delX, y + rectHeight - radius1 - delX);
                ctx.quadraticCurveTo(x + rectWidth + delX, y + rectHeight + delX, x + rectWidth - radius1 - delX, y + rectHeight + delX);
                ctx.lineTo(x + radius1 + delX, y + rectHeight + delX);
                ctx.quadraticCurveTo(x - delX, y + rectHeight + delX, x - delX, y + rectHeight - radius1 - delX);
                ctx.lineTo(x - delX, y + radius1 + delX);
                ctx.quadraticCurveTo(x - delX, y - delX, x + radius1 + delX, y - delX);
                ctx.closePath();
                ctx.stroke();

                // 绘制内层白色框
                ctx.strokeStyle = "white";
                ctx.lineWidth = 2; // 设置内层边缘宽度
                if(!shaderEffect.isDrawBorder(i)){
                    ctx.lineWidth = 0; // 设置边缘宽度
                    ctx.strokeStyle = Colors.color_transparent;
                }



                // 绘制圆角矩形路径
                delX = deltaBoard;
                ctx.beginPath();
                ctx.moveTo(x + radius - delX, y - delX); // 内层路径向外偏移 delX 像素
                ctx.lineTo(x + rectWidth - radius + delX, y - delX);
                ctx.quadraticCurveTo(x + rectWidth + delX, y - delX, x + rectWidth + delX, y + radius - delX);
                ctx.lineTo(x + rectWidth + delX, y + rectHeight - radius + delX);
                ctx.quadraticCurveTo(x + rectWidth + delX, y + rectHeight + delX, x + rectWidth - radius + delX, y + rectHeight + delX);
                ctx.lineTo(x + radius - delX, y + rectHeight + delX);
                ctx.quadraticCurveTo(x - delX, y + rectHeight + delX, x - delX, y + rectHeight - radius + delX);
                ctx.lineTo(x - delX, y + radius - delX);
                ctx.quadraticCurveTo(x - delX, y - delX, x + radius - delX, y - delX);
                ctx.closePath();

                // 绘制路径
                ctx.stroke();
            }
        }
    }
    // 屏蔽鼠标事件
    MouseArea {
        id: maskMouseArea
        anchors.fill: parent
        hoverEnabled: true

        Connections{
            target: globalSignal
            function onEnterTkClipArea(){
                maskMouseArea.cursorShape = Qt.SizeHorCursor;
            }

            function onExitTkClipArea(){
                maskMouseArea.cursorShape = Qt.ArrowCursor;
            }
        }

        function isInSuperSlowGuideArea(mouse) {
            if (mask.userGuideType !== UserGuideType.SUPER_SLOW) {
                return false;
            }

            var rect = userGuideMaskManager.getItemRect(actionableItemName.superSlowButton);
            if (!rect || rect.width <= 0 || rect.height <= 0) {
                return false;
            }

            return mouse.x >= rect.x && mouse.x <= rect.x + rect.width &&
                   mouse.y >= rect.y && mouse.y <= rect.y + rect.height;
        }

        onClicked: (mouse) =>{
                var x = mouse.x / parent.width;
                var y = mouse.y / parent.height;

                var isInHollowArea = isInSuperSlowGuideArea(mouse);

                for (var i = 0; i < mask.rectArray.length; i++) {
                    var rect = mask.rectArray[i];

                    if(rect.disableClick === true){  // 如果当前的镂空区域设置了禁用点击事件
                        continue;
                    }

                    var rectX = rect.x;
                    var rectY = rect.y;
                    var rectWidth = rect.width;
                    var rectHeight = rect.height;

                    var lowerLeft = {x: rectX, y: rectY};
                    var upperRight = {x: rectX + rectWidth, y: rectY + rectHeight};

                    if (x > lowerLeft.x / parent.width && x < upperRight.x / parent.width &&
                        y > lowerLeft.y / parent.height && y < upperRight.y / parent.height) {
                        isInHollowArea = true;
                        break;
                    }
                }

                if (!isInHollowArea) {

                    for (var i = 0; i < mask.rectArray.length; i++) {
                        var rect = mask.rectArray[i];
                    }

                    mouse.accepted = true; // 阻止事件传播
                } else {
                    mouse.accepted = false; // 允许事件传播
                }
            }

        onPressed: (mouse) =>{
                var x = mouse.x / parent.width;
                var y = mouse.y / parent.height;

                var isInHollowArea = isInSuperSlowGuideArea(mouse);

                for (var i = 0; i < mask.rectArray.length; i++) {
                    var rect = mask.rectArray[i];

                    if(rect.disablePress === true){  // 如果当前的镂空区域设置了禁用点击事件
                        continue;
                    }

                    var rectX = rect.x;
                    var rectY = rect.y;
                    var rectWidth = rect.width;
                    var rectHeight = rect.height;

                    var lowerLeft = {x: rectX, y: rectY};
                    var upperRight = {x: rectX + rectWidth, y: rectY + rectHeight};

                    if (x > lowerLeft.x / parent.width && x < upperRight.x / parent.width &&
                        y > lowerLeft.y / parent.height && y < upperRight.y / parent.height) {
                        isInHollowArea = true;
                        break;
                    }
                }

                if (!isInHollowArea) {
                    mouse.accepted = true; // 阻止事件传播
                } else {
                    mouse.accepted = false; // 允许事件传播
                }
            }

        onPositionChanged: (mouse) => {
                var x = mouse.x / parent.width;
                var y = mouse.y / parent.height;

                var isInHollowArea = isInSuperSlowGuideArea(mouse);

                for (var i = 0; i < mask.rectArray.length; i++) {
                    var rect = mask.rectArray[i];
                    if(rect.disableHover === true){  // 如果当前的镂空区域设置了禁用点击事件
                        continue;
                    }
                    var rectX = rect.x;
                    var rectY = rect.y;
                    var rectWidth = rect.width;
                    var rectHeight = rect.height;

                    var lowerLeft = {x: rectX, y: rectY};
                    var upperRight = {x: rectX + rectWidth, y: rectY + rectHeight};

                    if (x > lowerLeft.x / parent.width && x < upperRight.x / parent.width &&
                        y > lowerLeft.y / parent.height && y < upperRight.y / parent.height) {
                        isInHollowArea = true;
                        break;
                    }
                }

                if (!isInHollowArea) {
                    mouse.accepted = true; // 阻止事件传播
                    hoverEnabled = true;
                    mousePositionTracker.stopTracking();
                } else { // 进入镂空区域
                    mouse.accepted = false; // 允许事件传播
                    hoverEnabled = false;
                    mousePositionTracker.startTracking();
                }
            }

        WheelHandler {
            onWheel: {
                wheel.accepted = true; // 阻止滚动事件传播
            }
        }
    }

    // 主流程指引
    OverallGuide{
        id: overallGuide
        objectName: actionableItemName.overallGuide
        visible: userGuideType === UserGuideType.OVERALL
        z:2
        curStep: 0
        x: 394
        y: 151

        onVisibleChanged: {
            if(overallGuide.visible){
                curStep = 0;
                console.log("[UserGuide] show guide mask")
            }else{
                console.log("[UserGuide] hide guide mask")
            }

            globalSignal.enablePlayerViewGesture(!overallGuide.visible);
        }

        onCurStepChanged: {
            if(curStep === 1){
                overallGuide.isClickNextBtn = false;
                console.log("[UserGuide] push step1 button")
            }else if(curStep === 2){
                globalSignal.changeToFilterTab();
                overallGuide.isClickNextBtn = false;
                console.log("[UserGuide] push step2 button")
            }else if(curStep == 3){
                globalSignal.addLocalFilter();
                overallGuide.isClickNextBtn = false;
                console.log("[UserGuide] push step3 button")
            }
        }

        Connections{
            target: mask
            function onRectArrayChanged(){
                if(!overallGuide.visible){
                    return;
                }

                // 设置第一步指引时提示弹窗位置
                if(overallGuide.curStep === 0){
                    overallGuide.updateGuidePos(actionableItemName.addMediaPanel, 24, -32);
                }else if(overallGuide.curStep === 1){
                    overallGuide.updateGuidePos(actionableItemName.mediaListFirstItem, 0, 176);
                    instructionAnimation.updatePos(actionableItemName.mediaListFirstItem);

                }else if(overallGuide.curStep === 2){

                    overallGuide.updateGuidePos(actionableItemName.filterListFirstItem, 20, 185);
                    instructionAnimation.updatePos(actionableItemName.filterListFirstItem);
                    instructionAnimation.startAnimation();
                } else if(overallGuide.curStep === 3){
                    overallGuide.updateGuidePos(actionableItemName.mainPlayerControl, 0, 44);
                } else if(overallGuide.curStep === 4){
                    for (var i = 0; i < mask.rectArray.length; i++) {
                        var rect = mask.rectArray[i];
                        if(rect.name === actionableItemName.appBarExportRectangle){
                            overallGuide.x = rect.x - overallGuide.width;
                            overallGuide.y = rect.y + 57;
                        }
                    }
                }
            }
        }

        Connections{
            target: globalSignal
            function onNextStepInAllGuide(){
                // 这里需要判断是否进行了实操
                if(mask.userGuideType !== UserGuideType.OVERALL){
                    return;
                }
                    overallGuide.curStep += 1;
                    userGuideMaskManager.guideStep += 1;
                    shaderEffect.updateMaskArea();
                // }
            }

            function onAllGuideFinish(){
                mask.visible = false;
                globalSignal.enableMenuBar(true);
                editorManager.isInUserGuideStatus = false;
                userGuideMaskManager.guideStep = 0;
                mask.userGuideType = UserGuideType.UNKOWN;
            }

            function onFirstClipLaidOut(){
                // step1→2 解耦：等主轨 0 号片段落轨后再推进 guideStep
                if(mask.userGuideType !== UserGuideType.OVERALL) return;
                if(overallGuide.curStep !== 2) return;            // 只在等 step2 推进时响应
                if(userGuideMaskManager.guideStep !== 1) return;   // 防重复推进
                userGuideMaskManager.guideStep = overallGuide.curStep;  // = 2，直接赋值不累加
                shaderEffect.updateMaskArea();
            }
        }

        function updateGuidePos(name, offsetX, offsetY){
            for (var i = 0; i < mask.rectArray.length; i++) {
                var rect = mask.rectArray[i];
                if(rect.name === name){
                    overallGuide.x = rect.x + rect.width + offsetX;
                    overallGuide.y = rect.y + offsetY;
                }
            }
        }
    }

    // 关键帧引导开始页
    KeyFrameGuideBegin{
        id: keyFrameGuideBegin
        objectName: actionableItemName.KEYFRAME_GUIDE_BEGIN
        property bool isPracticalOperation: false
        visible: userGuideType === UserGuideType.KEYFRAMESTART
        curStep: 0
        x: (parent.width - keyFrameGuideBegin.width) / 2
        y: (parent.height - keyFrameGuideBegin.height) / 2

        onCurStepChanged: {
            onNextStep();
        }


        onVisibleChanged:{
            if(visible){    
                updateTipsPos();
                userGuideMaskManager.userGuideType = UserGuideType.KEYFRAMESTART;
                userGuideMaskManager.guideStep = 0;
                globalSignal.enablePlayerViewGesture(false)  // 禁用全景手势
            }else{
                return;
            }
        }

        function onNextStep(){
            keyFrameGuideBegin.visible = false;
            mask.userGuideType = UserGuideType.KEYFRAME;
            userGuideMaskManager.userGuideType = UserGuideType.KEYFRAME;
            keyFrameGuide.visible = true;
            keyFrameGuide.curStep = 1;
        }

        function updateTipsPos(){
            keyFrameGuideBegin.updatePos(actionableItemName.keyframeButton, 4);
        }

        function updatePos(name, directions){
            var x = 0;
            var y = 0;
            var width = 0;
            var height = 0;

            var rect1 = userGuideMaskManager.getItemRect(actionableItemName.keyframeButton);
            x = rect1.x + rect1.width / 2 - 20;
            y = rect1.y - 20;
            width = 40;
            height = 40;

            keyFrameGuideBegin.x = x - (keyFrameGuideBegin.width - width) / 2;
            var trackToolsBarRect = userGuideMaskManager.getItemRect(actionableItemName.trackToolsBar);
            if (trackToolsBarRect && trackToolsBarRect.height > 0) {
                keyFrameGuideBegin.y = trackToolsBarRect.y - keyFrameGuideBegin.height + 4;
            } else {
                keyFrameGuideBegin.y = y - keyFrameGuideBegin.height + 2;
            }
        }
    }

    // 关键帧指引
    KeyFrameGuide{
        id: keyFrameGuide
        objectName: actionableItemName.keyframeGuide
        property bool isPracticalOperation: false // 是否是用户的实际操作触发进入下一步
        property bool isEnterStep3Model: false // 是否直接从第三步开始指引
        visible: userGuideType === UserGuideType.KEYFRAME
        isFinishStep: curStep >= 7
        curStep: 0
        property int firstPos: 0
        property int secondPos: 0
        property bool playStatus: false

        x: (parent.width - keyFrameGuide.width) / 2
        y: (parent.height - keyFrameGuide.height) / 2

        onCurStepChanged: {
            updateGuide(); // 修改指引UI
            onNextStep();
        }

        onVisibleChanged:{
            if(visible){
                updateGuide();
                globalSignal.enablePlayerViewGesture(false)  // 禁用全景手势
            }else{   // 关键帧指引弹窗不可见时，直接退出引导流程
                mask.visible = false;
                userGuideMaskManager.guideStep = 0;
                editorManager.isInUserGuideStatus = false;
                globalSignal.enablePlayerViewGesture(true);
                return;
            }
        }

        onHeightChanged: {
            updateTipsPos();
        }

        Timer {
            id: delayTimer
            interval: 100
            onTriggered: {
                keyFrameGuide.isEnterStep3Model = true;
                mask.userGuideType = UserGuideType.KEYFRAME;
                mask.visible = true;
                keyFrameGuide.curStep = 2;
                keyFrameGuide.visible = true;
                userGuideMaskManager.guideStep = 2;
            }
        }

        onFinishGuide:{
            keyFrameGuide.visible = false;
            curStep = 0;
            userGuideMaskManager.guideStep = 0;
            adjustView.stop();

            mask.visible = false;
            mask.userGuideType = UserGuideType.UNKOWN;
            editorManager.isInUserGuideStatus = false;
            userGuideMaskManager.guideStep = 0;
        }

        function startDelayTimer(){
            delayTimer.start();
        }
        function stopDelayTimer(){
            delayTimer.stop();
        }

        Timer {
            id: delayTimerPlay
            interval: 100
            onTriggered: {
                editorManager.pause();

                userGuideMaskManager.guideStep = keyFrameGuide.curStep
                keyFrameGuide.curStep += 1;
            }
        }
        function startDelayTimerPlay(){
            editorManager.play();
            keyFrameGuide.playStatus = true;
        }
        Connections {
            target: editorManager
            function onIndicatorFrameChanged() {
                if(mask.visible === true && userGuideMaskManager.userGuideType === UserGuideType.KEYFRAME
                  && keyFrameGuide.playStatus === true){
                    var indicatorFrame = editorManager.getIndicatorFrame();
                    if(indicatorFrame >= keyFrameGuide.secondPos){
                        editorManager.pause();
                        //播放结束，设置个标志，防止时间指示器在变动又收到消息会再次进入
                        keyFrameGuide.playStatus = false;
                        userGuideMaskManager.guideStep = keyFrameGuide.curStep
                        keyFrameGuide.curStep += 1;
                    }
                }
            }
        }

        Connections{
            target: mask
            function onRectArrayChanged(){
                if(!keyFrameGuide.visible){
                    return;
                }
                keyFrameGuide.updateTipsPos();
            }
        }

        function updateTipsPos(){
            // 指示线的方向: 0(没有指示线)，1(左)，2(右), 3(上), 4(下)
            //step1 下 step2 右 step3 上 step4 下 step5 上 step6 下
            if(keyFrameGuide.curStep === 0){
                keyFrameGuide.indicatorLineDirect = 0;
            }else if(keyFrameGuide.curStep === 1){
                keyFrameGuide.indicatorLineDirect = 4;
                keyFrameGuide.updatePos(actionableItemName.keyframeButton, 4);
            }else if(keyFrameGuide.curStep === 2){
                if(userGuideMaskManager.guideStep !== 2){
                    return;
                }
                keyFrameGuide.indicatorLineDirect = 2;
                keyFrameGuide.updatePos(actionableItemName.selectViewArea, 2);
            }else if(keyFrameGuide.curStep === 3){
                keyFrameGuide.indicatorLineDirect = 3;
                keyFrameGuide.updatePos(actionableItemName.playerContainerRoot, 3);
                adjustView.updatePos();
            }else if(keyFrameGuide.curStep === 4){
                keyFrameGuide.indicatorLineDirect = 4;
                keyFrameGuide.updatePos(actionableItemName.keyframeButton, 4);
            }else if(keyFrameGuide.curStep === 5){
                keyFrameGuide.indicatorLineDirect = 3;
                keyFrameGuide.updatePos(actionableItemName.playerContainerRoot, 3);
            }else if(keyFrameGuide.curStep === 6){
                keyFrameGuide.indicatorLineDirect = 3;
                keyFrameGuide.updatePos(actionableItemName.playerContainerRoot, 3);
            }else if(keyFrameGuide.curStep === 7){
                keyFrameGuide.indicatorLineDirect = 0;
                keyFrameGuide.y -= (keyFrameGuide.height + 50);
            }
        }

        // 更新位置, name: 指示的元素的名字， directions:弹窗指示方向(1(左)，2(右), 3(上), 4(下))
        function updatePos(name, directions){
            var x = 0;
            var y = 0;
            var width = 0;
            var height = 0;

            if(name === actionableItemName.playerContainerRoot){
                var rect1 = userGuideMaskManager.getItemRect(actionableItemName.playerContainerRoot);
                x = rect1.x;
                y = rect1.y;
                width = rect1.width;
                height = rect1.height;
            }else{
                for (var i = 0; i < mask.rectArray.length; i++) {
                    var rect = mask.rectArray[i];
                    if(rect.name === name){
                        x = rect.x;
                        y = rect.y;
                        width = rect.width;
                        height = rect.height;

                        if(rect.name === actionableItemName.mainPlayerControl || rect.name === actionableItemName.keyframeButton || rect.name === actionableItemName.addKf){
                            x = rect.x + rect.width / 2 - 20;
                            y = rect.y + rect.height / 2 - 20;
                            width = 40;
                            height = 40;
                        }
                    }
                }
            }
            if(directions === 2){
                keyFrameGuide.x = x - keyFrameGuide.width;
                keyFrameGuide.y = y + (width - keyFrameGuide.width) / 2;
            }else if(directions === 3){
                keyFrameGuide.x = x - (keyFrameGuide.width - width) / 2;
                keyFrameGuide.y = y + height;
            }else if(directions === 4){
                keyFrameGuide.x = x - (keyFrameGuide.width - width) / 2;
                keyFrameGuide.y = y - keyFrameGuide.height;
            }
        }

        function updateGuide(){
            if(keyFrameGuide.curStep === 0){
                keyFrameGuide.titleText = qsTr("pccut_guide_keyframe_1");
                keyFrameGuide.stepText = qsTr("pccut_guide_6_steps");
                keyFrameGuide.descriptionText = qsTr("pccut_guide_keyframe_2");
                keyFrameGuide.nextBtnText = qsTr("pccut_guide_start")
            }else if(keyFrameGuide.curStep === 1){
                keyFrameGuide.titleText = qsTr("pccut_guide_keyframe_3");
                keyFrameGuide.stepText = qsTr("1/6");
                keyFrameGuide.descriptionText = qsTr("pccut_guide_keyframe_4");
                keyFrameGuide.nextBtnText = qsTr("pccut_guide_next")
            }else if(keyFrameGuide.curStep === 2){
                keyFrameGuide.titleText = qsTr("pccut_guide_keyframe_5");
                keyFrameGuide.stepText = qsTr("2/6");
                keyFrameGuide.descriptionText = qsTr("pccut_guide_keyframe_6");
                keyFrameGuide.descriptionHeight = 52
            }else if(keyFrameGuide.curStep === 3){
                keyFrameGuide.titleText = qsTr("pccut_guide_keyframe_7");
                keyFrameGuide.stepText = qsTr("3/6");
                keyFrameGuide.descriptionText = qsTr("pccut_guide_keyframe_8");
                adjustView.visible = true;
            }else if(keyFrameGuide.curStep === 4){
                adjustView.stop();
                keyFrameGuide.titleText = qsTr("pccut_guide_start_keyframe_1"); //"添加另一个关键帧";
                keyFrameGuide.stepText = qsTr("4/6");
                keyFrameGuide.descriptionText = qsTr("pccut_guide_start_keyframe_2");
                //seek一下位置,
                var indicatorFrame = editorManager.getIndicatorFrame();
                var totalFrame = editorManager.getCurFragmentFrameCount();
                var fps = editorManager.getFps();
                //如果视频长度>90f 时，自动跳转90f，如果<90f ，>10f 跳转至前时长的1/2处
                if( (totalFrame - indicatorFrame) > 90 )
                    editorManager.seek(indicatorFrame + 90);
                else if( (totalFrame - indicatorFrame) <= 90 && (totalFrame - indicatorFrame) >10 )
                    editorManager.seek(indicatorFrame + (totalFrame - indicatorFrame)/2);
                else
                    editorManager.seekNextNFrame(totalFrame - indicatorFrame);
            }
            else if(keyFrameGuide.curStep === 5){
                adjustView.stop();
                keyFrameGuide.titleText = qsTr("pccut_guide_start_keyframe_3");
                keyFrameGuide.stepText = qsTr("5/6");
                keyFrameGuide.descriptionText = qsTr("pccut_guide_start_keyframe_4"); //"调整第二个关键帧到满意的视角";????????
            }
            else if(keyFrameGuide.curStep === 6){
                keyFrameGuide.titleText = qsTr("pccut_guide_start_keyframe_5");
                keyFrameGuide.stepText = qsTr("6/6");
                keyFrameGuide.descriptionText = qsTr("pccut_guide_start_keyframe_6");
            }else if(keyFrameGuide.curStep === 7){
                adjustView.stop();

                keyFrameGuide.titleText = qsTr("pccut_guide_start_keyframe_7");
                keyFrameGuide.stepText = qsTr("");
                keyFrameGuide.descriptionText = qsTr("pccut_guide_start_keyframe_8");
            }
        }

        function onNextStep(){
            if(keyFrameGuide.curStep === 1){

            }else if(keyFrameGuide.curStep === 2){
                // 添加关键帧
                if(!keyFrameGuide.isPracticalOperation && !keyFrameGuide.isEnterStep3Model){
                    globalSignal.addKfActionInGuide();
                }else{
                    keyFrameGuide.isPracticalOperation = false;
                }
                //获取第一个关键帧的起始位置
                firstPos = editorManager.getIndicatorFrame();
            }else if(keyFrameGuide.curStep === 3){
                // 添加小行星效果
                if(!keyFrameGuide.isPracticalOperation){
                    globalSignal.selectPerspectiveInGuide();
                }else{
                    keyFrameGuide.isPracticalOperation = false;
                }
                globalSignal.enablePlayerViewGesture(true)  // 启用全景手势
            }else if(keyFrameGuide.curStep === 4){
                globalSignal.enablePlayerViewGesture(false)  // 禁用全景手势
                keyFrameGuide.isPracticalOperation = false;
                //
            }else if(keyFrameGuide.curStep === 5){
                //添加另外一个关键帧
                if(!keyFrameGuide.isPracticalOperation){
                    globalSignal.addKfActionInGuide();
                }else{
                    keyFrameGuide.isPracticalOperation = false;
                }
                //获取第二个关键帧的起始位置
                secondPos = editorManager.getIndicatorFrame();
                adjustView.start();
                globalSignal.enablePlayerViewGesture(true)  // 启用全景手势

            }else if(keyFrameGuide.curStep === 6){
                globalSignal.enablePlayerViewGesture(false)  // 禁用全景手势
                editorManager.seek(firstPos);
                adjustView.stop();

            }else if(keyFrameGuide.curStep === 7){
            }


            userGuideMaskManager.guideStep += 1;
            shaderEffect.updateMaskArea();
        }


        Timer {
            id: nextStepDelayTime
            interval: 100
            onTriggered: {
                keyFrameGuide.isPracticalOperation = true;
                keyFrameGuide.curStep += 1;
            }
        }
        function nextStepDelayTimer(){
            nextStepDelayTime.start();
        }

        Connections{
            target: globalSignal
            function onNextStepInKfGuide(){
                if(UserGuideType.KEYFRAME === userGuideMaskManager.userGuideType)
                {
                    keyFrameGuide.nextStepDelayTimer();
                }
            }
            function onUserGuideNextStepPlay(){
                if(UserGuideType.KEYFRAME === userGuideMaskManager.userGuideType){
                    keyFrameGuide.startDelayTimerPlay();
                }
            }
        }
    }


    // 关键帧过渡效果指引
    KeyFrameGuide{
        id: kfEffectGuide
        isFinishStep: true
        indicatorLineDirect: 2
        visible: userGuideType === UserGuideType.TRANSITION_EFFECT
        titleText: qsTr("pccut_guide_animation_1")
        stepText: qsTr("")
        descriptionText: qsTr("pccut_guide_animation_2")
        curStep: 0
        x: 500
        y: 500

        onVisibleChanged: {
            if(visible){
                userGuideMaskManager.userGuideType = UserGuideType.TRANSITION_EFFECT;
                userGuideMaskManager.guideStep = 0;
                updatePos(actionableItemName.kfTransitionArea, 2);
            }
            globalSignal.enablePlayerViewGesture(!kfEffectGuide.visible);
        }

        onFinishGuide: {
            kfEffectGuide.visible = false;
            mask.visible = false;
            mask.userGuideType = UserGuideType.UNKOWN;
            editorManager.isInUserGuideStatus = false;
            userGuideMaskManager.guideStep = 0;
            globalSignal.kfEffectFinish();
        }

        Connections{
            target: mask
            function onRectArrayChanged(){
                if(!kfEffectGuide.visible){
                    return;
                }

                // 设置第一步指引时提示弹窗位置
                if(kfEffectGuide.curStep === 0){
                    kfEffectGuide.indicatorLineDirect = 2;
                    kfEffectGuide.updatePos(actionableItemName.kfTransitionArea, 2);
                }
            }
        }

        function updatePos(name, directions){
            var x = 0;
            var y = 0;
            var width = 0;
            var height = 0;

            for (var i = 0; i < mask.rectArray.length; i++) {
                var rect = mask.rectArray[i];
                if(rect.name === name){
                    x = rect.x;
                    y = rect.y;
                    width = rect.width;
                    height = rect.height;
                }
            }
            if(mask.rectArray.length <= 0){
                return;
            }

            if(directions === 1){
                kfEffectGuide.x = x - kfEffectGuide.width;
                kfEffectGuide.y = y - (height + 20 - kfEffectGuide.height);
            }else if(directions === 2){
                kfEffectGuide.x = x - kfEffectGuide.width;
                kfEffectGuide.y = y + (height + 20 - kfEffectGuide.height);
            }else if(directions === 3){
                kfEffectGuide.x = x - (kfEffectGuide.width - width) / 2;
                kfEffectGuide.y = y + height;
            }else if(directions === 4){
                kfEffectGuide.x = x - (kfEffectGuide.width - width) / 2;
                kfEffectGuide.y = y - kfEffectGuide.height;
            }
        }

        Connections{
            target: globalSignal
            function onKfEffectFinish(){
                if(UserGuideType.TRANSITION_EFFECT === userGuideMaskManager.userGuideType){
                    kfEffectGuide.visible = false;
                    mask.userGuideType = UserGuideType.UNKOWN;
                    mask.visible = false;
                    userGuideMaskManager.guideStep = 0;
                    globalSignal.enableMenuBar(true);
                    editorManager.isInUserGuideStatus = false;
                }
            }
        }
    }

    // 区域关键帧引导开始页
    RegionKeyFrameGuideBegin{
        id: regionKeyFrameGuideBegin
        objectName: actionableItemName.REGIONKEYFRAME_GUIDE_BEGIN
        property bool isPracticalOperation: false
        visible: userGuideType === UserGuideType.REGIONKEYFRAMESTART
        curStep: 0
        x: (parent.width - regionKeyFrameGuideBegin.width) / 2
        y: (parent.height - regionKeyFrameGuideBegin.height) / 2
        property int playStartFramePos: 0
        property int playFrameCount: 0

        onCurStepChanged: {
            onNextStep();
        }


        onVisibleChanged:{
            if(visible){
                userGuideMaskManager.userGuideType = UserGuideType.REGIONKEYFRAMESTART;
                userGuideMaskManager.guideStep = 0;
                updateTipsPos();
                globalSignal.enablePlayerViewGesture(false)  // 禁用全景手势
            }else{
                return;
            }
        }

        Timer {
            id: delayTimerRegionKeyStartPlay
            interval: 100
            onTriggered: {
                editorManager.pause();
                mask.userGuideType = UserGuideType.REGIONKEYFRAME;
                userGuideMaskManager.userGuideType = UserGuideType.REGIONKEYFRAME;
                regionKeyFrameGuide.visible = true;
                regionKeyFrameGuide.curStep = 1;
            }
        }

        function onNextStep(){
            regionKeyFrameGuideBegin.visible = false;   //隐藏当前窗口
            //20251121最新需求:
              //530素材添加到轨道上时，如果没有出现过区域关键帧引导的情况，
                  //如果视频长度>90f 时，自动播放90f，
                  //如果<90f ，>10f 播放至前时长的1/2处
            var length = editorManager.getCurFragmentFrameCount();
            var indicatorFrame = editorManager.getIndicatorFrame();
            if(length <= 1){
                exitGuide();
                return;
            }
            if(indicatorFrame >= (length-1)){
                //时间指示器在片段末尾时不进行播放，直接跳到下一步
                mask.userGuideType = UserGuideType.REGIONKEYFRAME;
                userGuideMaskManager.userGuideType = UserGuideType.REGIONKEYFRAME;
                regionKeyFrameGuide.visible = true;
                regionKeyFrameGuide.curStep = 1;
                return;
            }

            var seekcount = length - indicatorFrame;
            if(seekcount > 90)
                seekcount = 90;
            else if(seekcount > 1)
                seekcount = seekcount/2;
            else
                seekcount = 1;

            regionKeyFrameGuideBegin.playStartFramePos = indicatorFrame;
            regionKeyFrameGuideBegin.playFrameCount = seekcount;
            editorManager.play();
        }

        function updateTipsPos(){
            regionKeyFrameGuideBegin.indicatorLineDirect = 4;
            regionKeyFrameGuideBegin.updatePos(actionableItemName.keyframeButton, 4);

        }

        // 更新位置, name: 指示的元素的名字， directions:弹窗指示方向(1(左)，2(右), 3(上), 4(下))
        function updatePos(name, directions){
            var x = 0;
            var y = 0;
            var width = 0;
            var height = 0;


            var rect1 = userGuideMaskManager.getItemRect(actionableItemName.keyframeButton);
            x = rect1.x + rect1.width / 2 - 20;
            //y = rect1.y + rect1.height / 2 - 20;
            y = rect1.y;
            width = 40;
            height = 40;

            regionKeyFrameGuideBegin.x = x - (regionKeyFrameGuideBegin.width - width) / 2;
            var trackToolsBarRect = userGuideMaskManager.getItemRect(actionableItemName.trackToolsBar);
            if (trackToolsBarRect && trackToolsBarRect.height > 0) {
                regionKeyFrameGuideBegin.y = trackToolsBarRect.y - regionKeyFrameGuideBegin.height + 4;
            } else {
                regionKeyFrameGuideBegin.y = y - regionKeyFrameGuideBegin.height - 2;
            }
        }

        Connections {
            target: editorManager
            function onIndicatorFrameChanged() {
                if(mask.visible === true && userGuideMaskManager.userGuideType === UserGuideType.REGIONKEYFRAMESTART
                  && regionKeyFrameGuideBegin.curStep === 1){
                    var indicatorFrame = editorManager.getIndicatorFrame();
                    var start = regionKeyFrameGuideBegin.playStartFramePos;
                    var playFrameCount = regionKeyFrameGuideBegin.playFrameCount;
                    if( (indicatorFrame - start) >= playFrameCount){
                        editorManager.pause();
                        mask.userGuideType = UserGuideType.REGIONKEYFRAME;
                        userGuideMaskManager.userGuideType = UserGuideType.REGIONKEYFRAME;
                        regionKeyFrameGuide.visible = true;
                        regionKeyFrameGuide.curStep = 1;
                    }
                }
            }
        }

    }
    // 区域关键帧指引
    KeyFrameGuide{
        id: regionKeyFrameGuide
        objectName: actionableItemName.regionKeyframeGuide
        property bool isPracticalOperation: false // 是否是用户的实际操作触发进入下一步
        property bool isEnterStep3Model: false // 是否直接从第三步开始指引
        visible: userGuideType === UserGuideType.REGIONKEYFRAME
        isFinishStep: curStep === 5
        curStep: -1
        property int playStartFramePos: 0
        property int playFrameCount: 0
        property bool playStatus: false

        x: (parent.width - regionKeyFrameGuide.width) / 2
        y: (parent.height - regionKeyFrameGuide.height) / 2

        onCurStepChanged: {
            if(curStep === 1){
                var indicatorframe = editorManager.getIndicatorFrame();
                if(indicatorframe === 0){
                    var totalFrame = TimelinePlayerViewModel.videoTimelineFrameLength();
                    if(totalFrame>=30){
                        editorManager.seek(30);
                    }else{
                        editorManager.seek(1);
                    }
                }
            }

            if(curStep === 4){
                var start = editorManager.getCurKeyframeItemBegin();
                editorManager.seek(start);
            }
            if(curStep === 2){
                onNextStep();
                return;
            }

            updateGuide(); // 修改指引UI
            onNextStep();
        }

        onVisibleChanged:{
            if(visible){
                updateGuide();
                globalSignal.enablePlayerViewGesture(false)  // 禁用全景手势
            }else{
                mask.visible = false;
                userGuideMaskManager.guideStep = 0;
                editorManager.isInUserGuideStatus = false;
                globalSignal.enablePlayerViewGesture(true);
                return;
            }
        }

        onHeightChanged: {
            updateTipsPos();
        }

        Timer {
            id: delayTimerRegionKeyStep2
            interval: 100 //100
            onTriggered: {
                //在加完区域关键帧时启动定时器等待页面渲染完成
                regionKeyFrameGuide.updateGuide();
                userGuideMaskManager.guideStep = regionKeyFrameGuide.curStep; //c++侧会触发获取镂空区域
                shaderEffect.updateMaskArea();
            }
        }
        Timer {
            id: delayTimerRegionKeyPlay
            interval: 100
            onTriggered: {
                editorManager.pause();
                regionKeyFrameGuide.curStep += 1;
            }
        }
        onFinishGuide:{
            if(UserGuideType.REGIONKEYFRAME === userGuideMaskManager.userGuideType){
                regionKeyFrameGuide.visible = false;
                curStep = 0;
                userGuideMaskManager.guideStep = 0;
                adjustView.stop();

                mask.visible = false;
                mask.userGuideType = UserGuideType.UNKOWN;
                editorManager.isInUserGuideStatus = false;
                userGuideMaskManager.guideStep = 0;
            }
        }

        function startDelayTimer(){
            delayTimerRegionKey.start();
        }
        function stopDelayTimer(){
            delayTimerRegionKey.stop();
        }

        function startDelayTimerPlay(){
            var indicatorFrame = editorManager.getIndicatorFrame();
            var start = editorManager.getCurKeyframeItemBegin();
            var end = editorManager.getCurKeyframeItemEnd();
            regionKeyFrameGuide.playStartFramePos = indicatorFrame;
            regionKeyFrameGuide.playFrameCount = (end - indicatorFrame);
            editorManager.play();
            regionKeyFrameGuide.playStatus = true;
        }

        Connections {
            target: editorManager
            function onIndicatorFrameChanged() {
                if(mask.visible === true && userGuideMaskManager.userGuideType === UserGuideType.REGIONKEYFRAME
                   && regionKeyFrameGuide.playStatus === true){
                    var indicatorFrame = editorManager.getIndicatorFrame();
                    var start = regionKeyFrameGuide.playStartFramePos;
                    var playFrameCount = regionKeyFrameGuide.playFrameCount;
                    if( (indicatorFrame - start) >= playFrameCount){
                        editorManager.pause();
                        regionKeyFrameGuide.curStep += 1;
                        regionKeyFrameGuide.playStatus = false;
                    }
                }
            }
        }

        Connections{
            target: mask
            function onRectArrayChanged(){
                if(!regionKeyFrameGuide.visible){
                    return;
                }
                regionKeyFrameGuide.updateTipsPos();
            }
        }

        function updateTipsPos(){
            //指示线的方向: 0(没有指示线)，1(左)，2(右), 3(上), 4(下)
            //连接线在提示框的方向： step1:下  step2:右  step3:上   step4:上   step5:右
            if(regionKeyFrameGuide.curStep === 1){
                regionKeyFrameGuide.indicatorLineDirect = 4;
                regionKeyFrameGuide.updatePos(actionableItemName.keyframeButton, 4);
            }else if(regionKeyFrameGuide.curStep === 2){
                if(userGuideMaskManager.guideStep !== 2){
                    return;
                }
                regionKeyFrameGuide.indicatorLineDirect = 2;
                regionKeyFrameGuide.updatePos(actionableItemName.selectViewArea, 2);
            } else if(regionKeyFrameGuide.curStep === 3){
                regionKeyFrameGuide.indicatorLineDirect = 3;
                regionKeyFrameGuide.updatePos(actionableItemName.playerContainerRoot, 3);
                adjustView.updatePos();
            } else if(regionKeyFrameGuide.curStep === 4){
                //不需要改变
            } else if(regionKeyFrameGuide.curStep === 5){
                regionKeyFrameGuide.indicatorLineDirect = 2;
                regionKeyFrameGuide.updatePos(actionableItemName.selectViewArea, 2);
            }
        }

        // 更新位置, name: 指示的元素的名字， directions:弹窗指示方向(1(左)，2(右), 3(上), 4(下))
        function updatePos(name, directions){
            var x = 0;
            var y = 0;
            var width = 0;
            var height = 0;

            if(name === actionableItemName.playerContainerRoot){
                var rect1 = userGuideMaskManager.getItemRect(actionableItemName.playerContainerRoot);
                x = rect1.x;
                y = rect1.y;
                width = rect1.width;
                height = rect1.height;
            }else{
                for (var i = 0; i < mask.rectArray.length; i++) {
                    var rect = mask.rectArray[i];
                    if(rect.name === name){
                        x = rect.x;
                        y = rect.y;
                        width = rect.width;
                        height = rect.height;

                        if(rect.name === actionableItemName.mainPlayerControl || rect.name === actionableItemName.keyframeButton || rect.name === actionableItemName.addKf){
                            x = rect.x + rect.width / 2 - 20;
                            y = rect.y + rect.height / 2 - 20;
                            width = 40;
                            height = 40;
                        }
                    }
                }
            }
            if(directions === 2){
                regionKeyFrameGuide.x = x - regionKeyFrameGuide.width;
                if(curStep == 5){
                    regionKeyFrameGuide.y = y - 20; //y - height/2;
                    regionKeyFrameGuide.horizontalIndicatorTopMargin = 20 + height/2;
                }
                else{
                    regionKeyFrameGuide.y = y + (width - regionKeyFrameGuide.width) / 2;
                }
            }else if(directions === 3){
                regionKeyFrameGuide.x = x - (regionKeyFrameGuide.width - width) / 2;
                regionKeyFrameGuide.y = y + height;
            }else if(directions === 4){
                regionKeyFrameGuide.x = x - (regionKeyFrameGuide.width - width) / 2;
                regionKeyFrameGuide.y = y - keyFrameGuide.height;
            }
        }

        function updateGuide(){
            if(regionKeyFrameGuide.curStep === 1){
                regionKeyFrameGuide.titleText = qsTr("pccut_guide_start_keyframe_regional_4"); //"添加区域关键帧";
                regionKeyFrameGuide.stepText = qsTr("1/5");
                regionKeyFrameGuide.descriptionText = qsTr("pccut_guide_start_keyframe_regional_5");
                regionKeyFrameGuide.nextBtnText = qsTr("pccut_guide_next")
            }else if(regionKeyFrameGuide.curStep === 2){
                regionKeyFrameGuide.titleText = qsTr("pccut_guide_start_keyframe_regional_6");
                regionKeyFrameGuide.stepText = qsTr("2/5");
                regionKeyFrameGuide.descriptionText = qsTr("pccut_guide_start_keyframe_regional_7");
                regionKeyFrameGuide.descriptionHeight = 52
            }else if(regionKeyFrameGuide.curStep === 3){
                regionKeyFrameGuide.titleText = qsTr("pccut_guide_start_keyframe_regional_8");
                regionKeyFrameGuide.stepText = qsTr("3/5");
                regionKeyFrameGuide.descriptionText = qsTr("pccut_guide_start_keyframe_regional_9");
                adjustView.visible = true;
            }else if(regionKeyFrameGuide.curStep === 4){
                regionKeyFrameGuide.titleText = qsTr("pccut_guide_start_keyframe_regional_10");
                regionKeyFrameGuide.stepText = qsTr("4/5");
                regionKeyFrameGuide.descriptionText = qsTr("pccut_guide_start_keyframe_regional_11");
                adjustView.visible = false;
            }else if(regionKeyFrameGuide.curStep === 5){
                regionKeyFrameGuide.titleText = qsTr("pccut_guide_start_keyframe_regional_12");
                regionKeyFrameGuide.stepText = qsTr("5/5");
                regionKeyFrameGuide.descriptionText = qsTr("pccut_guide_start_keyframe_regional_13");
            }
        }

        function onNextStep(){
            if(regionKeyFrameGuide.curStep === 1){

            }else if(regionKeyFrameGuide.curStep === 2){
                // 添加区域关键帧
                if(!regionKeyFrameGuide.isPracticalOperation && !regionKeyFrameGuide.isEnterStep3Model){
                //if(!regionKeyFrameGuide.isPracticalOperation){
                    globalSignal.addKfActionInGuide();
                    //globalSignal.AddRegionKeyframeAction();
                }else{
                    regionKeyFrameGuide.isPracticalOperation = false;
                }
                delayTimerRegionKeyStep2.start();
                return;

            }else if(regionKeyFrameGuide.curStep === 3){
                // 添加小行星效果
                if(!regionKeyFrameGuide.isPracticalOperation){
                    globalSignal.selectPerspectiveInGuide();
                }else{
                    regionKeyFrameGuide.isPracticalOperation = false;
                }
                globalSignal.enablePlayerViewGesture(true)  // 启用全景手势
            }else if(regionKeyFrameGuide.curStep === 4){

                globalSignal.enablePlayerViewGesture(false)  // 禁用全景手势
            }
            else if(regionKeyFrameGuide.curStep === 5){
            }

            userGuideMaskManager.guideStep = regionKeyFrameGuide.curStep;
            shaderEffect.updateMaskArea();
        }


        Timer {
            id: nextStepRegionKeyDelayTime
            interval: 100
            onTriggered: {
                regionKeyFrameGuide.isPracticalOperation = true;
                regionKeyFrameGuide.curStep += 1;
            }
        }
        function nextStepDelayTimer(){
            nextStepRegionKeyDelayTime.start();
        }


        Connections{
            target: globalSignal
            function onNextStepInKfGuide(){
                if(UserGuideType.REGIONKEYFRAME === userGuideMaskManager.userGuideType)
                {
                    regionKeyFrameGuide.nextStepDelayTimer();
                }
            }
            function onUserGuideNextStepPlay(){
                if(UserGuideType.REGIONKEYFRAME === userGuideMaskManager.userGuideType){
                    if(regionKeyFrameGuide.playStatus){
                        return;
                    }
                    regionKeyFrameGuide.startDelayTimerPlay();
                }
            }

            function onExitRegionKfGuide(){
                if(UserGuideType.REGIONKEYFRAME === userGuideMaskManager.userGuideType && regionKeyFrameGuide.curStep > 4){
                    regionKeyFrameGuide.visible = false;
                    regionKeyFrameGuide.curStep = 0;

                    mask.visible = false;
                    mask.userGuideType = UserGuideType.UNKOWN;
                    editorManager.isInUserGuideStatus = false;
                    userGuideMaskManager.guideStep = 0;
                }
            }

        }

    }
    /////////////////////////////////////////////////
    // Tk指引
    // 前三步使用追踪自带的蒙层，只有最后一步使用这个蒙层
    KeyFrameGuide{
        id: trackingGuide
        property bool isPracticalOperation: false // 是否是用户的实际操作触发进入下一步
        property bool isFixPos: false
        visible: userGuideType === UserGuideType.TRACKING && curStep === 3
        isFinishStep: curStep === 3
        curStep: 0
        x: 500
        y: 500
        z:10
        titleText: qsTr("pccut_guide_TK_7")
        stepText: qsTr("4/4")
        descriptionText: qsTr("pccut_guide_TK_8")

        onCurStepChanged: {
            updateGuide(); // 修改指引UI
            onNextStep();
        }

        onVisibleChanged:{
            if(visible){
                updateGuide();
            }else{
                trackingGuide.isFixPos = false;
            }
            globalSignal.enablePlayerViewGesture(!trackingGuide.visible);
        }

        onFinishGuide: {
            trackingGuide.curStep = 0;
            mask.visible = false;
            userGuideMaskManager.guideStep = 0;
            globalSignal.enableMenuBar(true);
        }

        function updateGuide(){
            if(trackingGuide.curStep === 0){
                trackingGuide.titleText = qsTr("pccut_guide_TK_1");
                trackingGuide.stepText = qsTr("1/4");
                trackingGuide.descriptionText = qsTr("pccut_guide_TK_2");
            }else if(trackingGuide.curStep === 1){
                trackingGuide.titleText = qsTr("pccut_guide_TK_3");
                trackingGuide.stepText = qsTr("2/4");
                trackingGuide.descriptionText = qsTr("pccut_guide_TK_4");
            }else if(trackingGuide.curStep === 2){
                trackingGuide.titleText = qsTr("pccut_guide_TK_5");
                trackingGuide.stepText = qsTr("3/4");
                trackingGuide.descriptionText = qsTr("pccut_guide_TK_6");
            }else if(trackingGuide.curStep === 3){
                trackingGuide.titleText = qsTr("pccut_guide_TK_7");
                trackingGuide.stepText = qsTr("4/4");
                trackingGuide.descriptionText = qsTr("pccut_guide_TK_8");
            }
        }

        function onNextStep(){
            if(userGuideMaskManager.guideStep === 3){
                trackingGuide.curStep = 0;
            }else if(trackingGuide.curStep === 4){
                editorManager.isInUserGuideStatus = false;
            }

            userGuideMaskManager.guideStep += 1;
            shaderEffect.updateMaskArea();
        }

        function updateGuidePos(name, directions){
            var x = 0;
            var y = 0;
            var width = 0;
            var height = 0;

            for (var i = 0; i < mask.rectArray.length; i++) {
                var rect = mask.rectArray[i];
                if(rect.name === name){
                    x = rect.x;
                    y = rect.y;
                    width = rect.width;
                    height = rect.height;
                }
            }
            if(directions === 1){
                trackingGuide.x = x + width;
                trackingGuide.y = y - trackingGuide.height / 2 + height / 2;

            }else if(directions === 2){
                trackingGuide.x = x - trackingGuide.width;
                trackingGuide.y = y + (width - trackingGuide.width) / 2;
            }else if(directions === 3){
                trackingGuide.x = x - (trackingGuide.width - width) / 2;
                trackingGuide.y = y + height;
            }else if(directions === 4){
                trackingGuide.x = x - (trackingGuide.width - width) / 2;
                trackingGuide.y = y - trackingGuide.height;
            }

            if(trackingGuide.curStep === 3){
                if(trackingGuide.x  < -trackingGuide.horizontalIndicatorLength){
                    trackingGuide.x = 0;
                }
                else if(trackingGuide.x > mask.width + trackingGuide.horizontalIndicatorLength){
                    trackingGuide.x = mask.width - trackingGuide.width + trackingGuide.horizontalIndicatorLength - 20;
                }

                trackingGuide.y = y - trackingGuide.height;
                trackingGuide.horizontalIndicatorTopMargin = y - trackingGuide.y + height / 2
            }
        }

        Connections{
            target: mask
            function onRectArrayChanged(){
                if(trackingGuide.curStep === 0){
                    trackingGuide.updateGuidePos(actionableItemName.playerContainerRoot, 3);
                }
                if(!trackingGuide.visible){
                    return;
                }

                // 设置第一步指引时提示弹窗位置
                if(trackingGuide.curStep === 0){
                    trackingGuide.updateGuidePos(actionableItemName.playerContainerRoot, 3);
                }else if(trackingGuide.curStep === 1){
                    trackingGuide.updateGuidePos(actionableItemName.playerContainerRoot, 3);
                }else if(trackingGuide.curStep === 2){
                    trackingGuide.updateGuidePos(actionableItemName.playerContainerRoot, 3);
                } else if(trackingGuide.curStep === 3){
                    trackingGuide.indicatorLineDirect = 4;
                    if(!trackingGuide.isFixPos){
                        trackingGuide.updateGuidePos(actionableItemName.tkFragmentRect, 4);
                        trackingGuide.isFixPos = true;
                    }
                }
            }
        }

        Connections{
            target: globalSignal
            function onFinishTkGuideModel(){
                editorManager.isInUserGuideStatus = false;
                userGuideMaskManager.guideStep = 0;
                mask.visible = false;
                trackingGuide.visible = false;
            }
        }
    }

    // Action 拍摄的黑块素材裁切指引

    KeyFrameGuide{
        id: frameCropGuide
        rootWidth: 277
        tipsRectangleWidth: 277
        isShowStep: false
        finishBtnText: qsTr("pccut_frame_cropping_btn")
        visible: userGuideType === UserGuideType.FRAMECROP && curStep === 0
        indicatorLineDirect: 0
        curStep: 0
        isFinishStep: true
        x: (parent.width - frameCropGuide.width) / 2
        y: (parent.height - frameCropGuide.height) / 2
        z:100
        titleText: qsTr("pccut_frame_cropping_notice_edit")
        descriptionText: qsTr("pccut_frame_cropping_notice_publish")
        nextBtnText: qsTr("pccut_frame_cropping_btn")

        onFinishGuide: {
            frameCropGuide.curStep = 0;
            mask.visible = false;
            userGuideMaskManager.guideStep = 0;

            globalSignal.openFrameCropWindow();
        }
    }

    // 超级慢动作指引
    SuperSlowGuide {
        id: superSlowGuide
        visible: userGuideType === UserGuideType.SUPER_SLOW && curStep === 0
        property int positionRetryCount: 0

        Timer {
            id: positionRetryTimer
            interval: 100
            repeat: false
            onTriggered: {
                if (superSlowGuide.visible) {
                    superSlowGuide.updateTipsPos();
                }
            }
        }

        function closeGuide(enableSuperSlow) {
            positionRetryTimer.stop();
            positionRetryCount = 0;
            mask.userGuideType = UserGuideType.UNKOWN;
            curStep = 0;
            mask.visible = false;
            userGuideMaskManager.guideStep = 0;
            editorManager.isInUserGuideStatus = false;
            if (enableSuperSlow) {
                globalSignal.enableSuperSlowByGuide();
            }
        }

        function updateTipsPos() {
            var rect = userGuideMaskManager.getItemRect(actionableItemName.superSlowButton);
            if (!rect || rect.width <= 0 || rect.height <= 0) {
                if (positionRetryCount < 8) {
                    positionRetryCount += 1;
                    positionRetryTimer.start();
                } else {
                    closeGuide(false);
                }
                return;
            }

            positionRetryTimer.stop();
            positionRetryCount = 0;
            superSlowGuide.x = rect.x - (superSlowGuide.width - rect.width) / 2;
            superSlowGuide.y = rect.y - superSlowGuide.height - 8;
        }

        onVisibleChanged: {
            if (visible) {
                positionRetryCount = 0;
                updateTipsPos();
            } else {
                positionRetryTimer.stop();
                positionRetryCount = 0;
            }
        }

        onCurStepChanged: {
            if (curStep === 1) {
                closeGuide(true);
            }
        }

        onExitGuide: {
            closeGuide(false);
        }

        Connections {
            target: globalSignal
            function onEnterNextStepSuperSlowGuide() {
                if (mask.userGuideType !== UserGuideType.SUPER_SLOW) {
                    return;
                }
                superSlowGuide.closeGuide(false);
            }
        }
    }

    // 主流程指引箭头动画
    Rectangle {
        id: instructionAnimation
        visible: userGuideType === UserGuideType.OVERALL && (overallGuide.curStep === 1 || overallGuide.curStep === 2)
        width: 70
        height: 520
        property int curCount: 0
        z:2
        color: Colors.color_transparent

        onVisibleChanged: {
            if(instructionAnimation.visible){
                var rect = userGuideMaskManager.getItemRect(actionableItemName.mediaSelectedPage);
                if(rect.height > 0){
                    instructionAnimation.height = rect.height + 60;
                }

                startAnimation();
            }
        }

        function startAnimation(){
            canvas4.t = 0;
            instructionAnimation.curCount = 0;
            timer.start();
        }

        Image {
            id: roundImage
            width: 10
            height:10
            x:0
            y:0
            source: "qrc:/icons/icon_circle.svg"

            function updatePos(name){
                for (var i = 0; i < mask.rectArray.length; i++) {
                    var rect = mask.rectArray[i];
                    if(rect.name === name){
                        roundImage.x = rect.x + rect.width / 2 - roundImage.width;
                        roundImage.y = rect.y + rect.height / 2 - roundImage.height;
                    }
                }
            }
        }
        Canvas {
            id: canvas4
            anchors.fill: parent

            property real t: 0.0
            property var controlPoints: [
                Qt.point(roundImage.width / 1.5, roundImage.height),  // 起点
                Qt.point(50, instructionAnimation.height * 0.25), // 控制点1
                Qt.point(50, instructionAnimation.height * 0.75),  // 控制点2
                Qt.point(roundImage.width, instructionAnimation.height)  // 终点
            ]

            onPaint: {
                var ctx = getContext("2d")
                ctx.setLineDash([5, 5])

                ctx.clearRect(0, 0, width, height)
                ctx.strokeStyle = "white"
                ctx.lineWidth = 2

                ctx.beginPath()
                ctx.moveTo(controlPoints[0].x, controlPoints[0].y)

                // 计算贝塞尔曲线上的点
                for (var i = 0; i <= canvas4.t; i += 0.01) {
                    var x = Math.pow(1 - i, 3) * controlPoints[0].x +
                            3 * Math.pow(1 - i, 2) * i * controlPoints[1].x +
                            3 * (1 - i) * Math.pow(i, 2) * controlPoints[2].x +
                            Math.pow(i, 3) * controlPoints[3].x

                    var y = Math.pow(1 - i, 3) * controlPoints[0].y +
                            3 * Math.pow(1 - i, 2) * i * controlPoints[1].y +
                            3 * (1 - i) * Math.pow(i, 2) * controlPoints[2].y +
                            Math.pow(i, 3) * controlPoints[3].y

                    ctx.lineTo(x, y)
                }

                ctx.stroke()

                // 如果绘制完成，添加箭头
                if (t >= 1.0) {
                    // 计算曲线终点的切线方向
                    var tangentX = 3 * Math.pow(1 - t, 2) * (controlPoints[1].x - controlPoints[0].x) +
                                    6 * (1 - t) * t * (controlPoints[2].x - controlPoints[1].x) +
                                    3 * Math.pow(t, 2) * (controlPoints[3].x - controlPoints[2].x)

                    var tangentY = 3 * Math.pow(1 - t, 2) * (controlPoints[1].y - controlPoints[0].y) +
                                    6 * (1 - t) * t * (controlPoints[2].y - controlPoints[1].y) +
                                    3 * Math.pow(t, 2) * (controlPoints[3].y - controlPoints[2].y)

                    // 绘制箭头
                    drawDashedArrow(ctx, controlPoints[3].x, controlPoints[3].y, tangentX, tangentY)
                }
            }

            // 绘制虚线箭头的函数
            function drawDashedArrow(ctx, x, y, tangentX, tangentY) {
                var angle = Math.atan2(tangentY, tangentX) // 计算切线的角度
                var arrowLength = 20 // 箭头长度
                var arrowWidth = 12 // 箭头宽度

                ctx.setLineDash([]) // 恢复实线样式
                ctx.lineWidth = 2

                // 绘制箭头
                ctx.save()
                ctx.beginPath()
                ctx.moveTo(x, y)
                ctx.lineTo(
                    x - arrowLength * Math.cos(angle - Math.PI / 6),
                    y - arrowLength * Math.sin(angle - Math.PI / 6),
                )
                ctx.moveTo(x, y) // 移动到起点，避免连接线
                ctx.lineTo(
                    x - arrowLength * Math.cos(angle + Math.PI / 6),
                    y - arrowLength * Math.sin(angle + Math.PI / 6),
                )
                ctx.stroke()
                ctx.restore()
            }

            Timer {
                id: timer
                interval: 10
                running: false
                repeat: true
                onTriggered: {
                    if (canvas4.t < 1.0) {
                        canvas4.t += 0.02 // 每次增加 0.01，总共 100 步
                        canvas4.requestPaint()
                    } else {
                        instructionAnimation.curCount += 1;
                        if(instructionAnimation.curCount < 2){
                            timer2.start();
                            timer.stop()
                        }else{
                            stop();
                        }
                    }
                }
            }

            // 定时等待一段时间之后，进行第二次绘制
            Timer {
                id: timer2
                interval: 500
                running: false
                repeat: false
                onTriggered: {
                    timer.start();
                    canvas4.t = 0;
                    canvas4.requestPaint();
                    timer2.stop();
                }
            }

        }
        function updatePos(name){
            for (var i = 0; i < mask.rectArray.length; i++) {
                var rect = mask.rectArray[i];
                if(rect.name === name){
                    if(overallGuide.curStep === 1){ // 媒体
                        instructionAnimation.x = rect.x + rect.width / 2 - roundImage.width / 2;
                        instructionAnimation.y = rect.y + rect.height / 2 - roundImage.height / 2;
                    }else if(overallGuide.curStep === 2){ // 滤镜
                        instructionAnimation.x = rect.x + rect.width / 2 - roundImage.width / 2;
                        instructionAnimation.y = rect.y + rect.height / 2 - roundImage.height / 2;
                    }
                }
            }
        }
    }

    // 关键帧指引动画
    Rectangle {
        id: trackRectAnimation
        width: 175
        height: 200
        visible: userGuideType === UserGuideType.TRACKING && (trackingGuide.curStep === 0)
        color: Colors.color_transparent
        // 动画控制属性
        property int frameRate: 30     // 帧率 (fps)
        property int currentFrame: 0
        property int totalFrames: 75
        property int playCount: 0 // 播放次数

        onVisibleChanged: {
            if(trackRectAnimation.visible){
                var rect = userGuideMaskManager.getPlayerRect();
                trackRectAnimation.x = rect.x + rect.width / 2 - trackRectAnimation.width / 2;
                trackRectAnimation.y = rect.y + rect.height / 2 - trackRectAnimation.height / 2;
                trackRectAnimation.start();
            }else{
                fingerTimer.stop();
            }
        }

        function start(){
            selectionRect.visible = true
            fingerTimer.start();
        }
        function stop(){
            fingerTimer.stop();
            trackRectAnimation.visible = false;
        }

        // 显示当前帧
        Image {
            id: animImage
            anchors.fill: parent
            source: trackRectAnimation.getFramePath(trackRectAnimation.currentFrame)
        }

        function getFramePath(frameNumber) {
            const paddedNum = String(frameNumber).padStart(5, '0')
            return "qrc:/icons/TK_mac/TK_mac_" + paddedNum +".png"
        }

        // 帧控制器
        Timer {
            id: fingerTimer
            interval: 1000 / trackRectAnimation.frameRate  // 根据帧率计算间隔
            running: trackRectAnimation.visible
            repeat: true
            onTriggered: {
                if(trackRectAnimation.currentFrame < trackRectAnimation.totalFrames - 1) {
                    trackRectAnimation.currentFrame += 1;
                } else {
                    trackRectAnimation.playCount += 1;
                    if(trackRectAnimation.playCount <= 100){
                        trackRectAnimation.currentFrame = 0;
                    }else{
                        fingerTimer.stop();
                        trackRectAnimation.visible = false;
                        trackRectAnimation.currentFrame = 0;
                    }
                }
            }
        }
    }

    // Tk指引动画
    Rectangle {
        id: adjustView
        width: 410
        height: 200
        visible: false
        color: Colors.color_transparent
        // 动画控制属性
        property int frameRate: 30     // 帧率 (fps)
        property int currentFrame: 0
        property int totalFrames: 75
        property int playCount: 0 // 播放次数

        // 显示当前帧
        Image {
            id: animImage1
            anchors.fill: parent
            source: adjustView.getFramePath(adjustView.currentFrame)
        }

        function start(){
            adjustView.visible = true
            fingerTimer1.start();
        }
        function stop(){
            fingerTimer1.stop();
            adjustView.visible = false;
        }

        function getFramePath(frameNumber) {
            const paddedNum = String(frameNumber).padStart(5, '0')
            return "qrc:/icons/slide_mac/slide_mac_" + paddedNum +".png"
        }

        onVisibleChanged: {
            if(!adjustView.visible){
                fingerTimer1.stop();
            }
        }

        // 帧控制器
        Timer {
            id: fingerTimer1
            interval: 1000 / adjustView.frameRate  // 根据帧率计算间隔
            running: adjustView.visible
            repeat: true
            onTriggered: {
                if(adjustView.currentFrame < adjustView.totalFrames - 1) {
                    adjustView.currentFrame += 1;
                } else {
                    adjustView.playCount += 1;
                    if(adjustView.playCount <= 100){
                        adjustView.currentFrame = 0;
                    }else{
                        fingerTimer1.stop();
                        adjustView.visible = false;
                        adjustView.currentFrame = 0;
                    }
                }
            }
        }

        function updatePos(){
            for (var i = 0; i < mask.rectArray.length; i++) {
                var rect = mask.rectArray[i];
                if(rect.name === actionableItemName.playerContainer){
                    adjustView.x = rect.x + rect.width / 2 - adjustView.width / 2;
                    adjustView.y = rect.y + rect.height / 2 - adjustView.height / 2;
                }
            }
        }

        Connections{
            target: globalSignal
            function onStartAdjustView(){
                adjustView.visible = false;
            }
        }
    }

    Connections {
            target: overallGuide
            function onExitGuide(){
                mask.visible = false;
                globalSignal.enableMenuBar(true);
                editorManager.isInUserGuideStatus = false;
                userGuideMaskManager.guideStep = 0;
                mask.userGuideType = UserGuideType.UNKOWN;
            }

            function onNextStep(){
                userGuideMaskManager.guideStep += 1;
                if(userGuideMaskManager.userGuideType === UserGuideType.OVERALL){
                    if(userGuideMaskManager.guideStep === 1 && userGuideMaskManager.userGuideType === UserGuideType.OVERALL){
                        var pathStr = userGuideMaskManager.getLocalVideoPath();
                        globalSignal.addToMediaTab(pathStr, -1, -1);
                    }
                }

                shaderEffect.updateMaskArea();
            }
        }

    Connections {
            target: keyFrameGuide
            function onExitGuide(){
                keyFrameGuide.visible = false;
                adjustView.stop();
                keyFrameGuide.curStep = 0;
                mask.visible = false;
                editorManager.isInUserGuideStatus = false;
                mask.userGuideType = UserGuideType.UNKOWN;
                userGuideMaskManager.guideStep = 0;
                userGuideMaskManager.userGuideType = UserGuideType.UNKOWN;

                globalSignal.enableMenuBar(true);
                globalSignal.enablePlayerViewGesture(true)  // 启用全景手势
            }
        }
    Connections {
        target: keyFrameGuideBegin
        function onExitGuide(){
            keyFrameGuideBegin.visible = false;
            adjustView.stop();
            keyFrameGuideBegin.curStep = 0;
            mask.visible = false;
            editorManager.isInUserGuideStatus = false;
            mask.userGuideType = UserGuideType.UNKOWN;
            userGuideMaskManager.guideStep = 0;
            userGuideMaskManager.userGuideType = UserGuideType.UNKOWN;

            globalSignal.enableMenuBar(true);
            globalSignal.enablePlayerViewGesture(true)  // 启用全景手势
        }
    }
    Connections {
        target: regionKeyFrameGuideBegin
        function onExitGuide(){
            regionKeyFrameGuide.visible = false;
            adjustView.stop();
            regionKeyFrameGuide.curStep = 0;
            mask.visible = false;
            editorManager.isInUserGuideStatus = false;
            mask.userGuideType = UserGuideType.UNKOWN;
            userGuideMaskManager.guideStep = 0;
            userGuideMaskManager.userGuideType = UserGuideType.UNKOWN;

            globalSignal.enableMenuBar(true);
            globalSignal.enablePlayerViewGesture(true)  // 启用全景手势
        }
    }
    Connections {
        target: regionKeyFrameGuide
        function onExitGuide(){
            keyFrameGuide.visible = false;
            adjustView.stop();
            keyFrameGuide.curStep = 0;
            mask.visible = false;
            editorManager.isInUserGuideStatus = false;
            mask.userGuideType = UserGuideType.UNKOWN;
            userGuideMaskManager.guideStep = 0;
            userGuideMaskManager.userGuideType = UserGuideType.UNKOWN;

            globalSignal.enableMenuBar(true);
            globalSignal.enablePlayerViewGesture(true)  // 启用全景手势
        }
    }

    Connections {
            target: trackingGuide
            function onExitGuide(){
                trackingGuide.curStep = 0;
                mask.visible = false;
                mask.userGuideType = UserGuideType.UNKOWN;
                userGuideMaskManager.guideStep = 0;

                editorManager.isInUserGuideStatus = false;
                globalSignal.enableMenuBar(true);
            }
        }

    Connections{
        target: globalSignal
        function onEnterKfGuideModelStep3(){
            // 这里开始定时器,定时100ms
            keyFrameGuide.startDelayTimer();
        }

        function onExitTkGuideModel(finishTk){
            if(finishTk && userGuideMaskManager.hasTkFragment()){
                userGuideMaskManager.userGuideType = UserGuideType.TRACKING
                trackingGuide.curStep = 3;
                userGuideMaskManager.guideStep = 3;
            }else{
                mask.visible = false;
                mask.userGuideType = UserGuideType.UNKOWN;
                editorManager.isInUserGuideStatus = false;
                userGuideMaskManager.guideStep = 0;
                globalSignal.enableMenuBar(true);
            }
        }

        function onCloseAnimationInTkGuide(){
            trackRectAnimation.visible = false;
        }

    }
}
