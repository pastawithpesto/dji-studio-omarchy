import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls
import Controls 1.0
import Config 1.0
import CursorHelper 1.0
import app_qrc 1.0

Item {
    id: timeView
    anchors.fill: parent
    // 是否是拖拽操作
    property bool longPressDrag: false
    //当前偏移时间,默认单位ms
    property int currentOffsetTime: dashboardManager.offsetTime
    //当前时间单位
    property int currentTimeType: dashboardManager.timeType
    property double minOffsetTime: dashboardManager.minOffsetTime
    property double maxOffsetTIme: dashboardManager.maxOffsetTime

    Connections {
        target: dashboardManager
        function onOffsetTimeChanged() {
            currentOffsetTime = dashboardManager.offsetTime
        }
    }
    //将当前偏移时间转换成字符串
    function formatTime(){
        if(currentOffsetTime == 0){
            return "0";
        }

        var isPositive = currentOffsetTime > 0;
        var time = isPositive ? currentOffsetTime : -currentOffsetTime;
        var returnValue = isPositive ? "+" : "-";

        var minutes = Math.floor(time / 60000);
        if(minutes > 0){
            returnValue += minutes + "m";
        }
        var seconds = Math.floor((time % 60000) / 1000);
        if(seconds > 0){
            returnValue += seconds + "s";
        }
        var milliseconds = time % 1000;
        if(milliseconds > 0){
            returnValue += milliseconds + "ms";
        }

        return returnValue;
    }

    //改变当前偏移时间
    function changeOffsetTime(isPositive) {
        var offset = 0;
        switch(currentTimeType){
        case 0:
            offset = 100;
            break;
        case 1:
            offset = 1000;
            break;
        case 2:
            offset = 10000;
            break;
        case 3:
            offset = 60000;
            break;
        case 4:
            offset = 600000;
            break;
        case 5:
            offset = 3600000;
            break;
        default:
            offset = 0;
            break;
        }
        offset = isPositive ? offset : -offset;
        currentOffsetTime += offset;
        if(currentOffsetTime < minOffsetTime) {
            currentOffsetTime = minOffsetTime;
        }
        if(currentOffsetTime > maxOffsetTIme) {
            currentOffsetTime = maxOffsetTIme;
        }

        formatTime();
    }

    CursorHelper {
        id: cursorhelper
    }

    Rectangle {
        id: reduceBtn
        anchors.left: parent.left
        anchors.leftMargin: 12
        width: 32
        height: 32
        color: Colors.color_FFFFFF_15
        radius: RadiusConfig.radius_4_88
        Accessible.role: Accessible.Button
        property bool isClicked: false
        Image {
            width: 20
            height: 20
            anchors.verticalCenter: parent.verticalCenter
            anchors.horizontalCenter: parent.horizontalCenter
            source: reduceBtn.isClicked ? "qrc:/app_qrc/icons/icon_reducetime_clicked.svg" : "qrc:/icons/dashboard/icon_reducetime.svg"
            sourceSize: Qt.size(20, 20)
        }
        MouseArea {
            anchors.fill: parent
            onPressed: {
                reduceBtn.isClicked = true;
            }
            onReleased: {
                reduceBtn.isClicked = false;
            }
            onClicked: {
                changeOffsetTime(false);
                dashboardManager.setOffsetTime(currentOffsetTime)
            }
        }
    }

    Rectangle {
        id: textRect
        anchors.left: reduceBtn.right
        anchors.leftMargin: 8
        anchors.right: addBtn.left
        anchors.rightMargin: 8
        height: 32
        color: Colors.color_FFFFFF_15
        radius: RadiusConfig.radius_4_88

        Text {
            anchors.fill: parent
            anchors.leftMargin: 4
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            anchors.horizontalCenter: parent.horizontalCenter
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            font.pixelSize: 12
            color: Colors.color_FFFFFF
            text: formatTime();
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.SizeHorCursor
                // 防止Mouse事件被父控件拦截
                preventStealing: true
                acceptedButtons: Qt.LeftButton
                property real startMoveX: -1
                property real startMoveY: -1
                property real accumulatedDeltaX: 0 // 累积的水平移动距离
                onPositionChanged: (mouse) =>{
                    if (startMoveX !== -1 && startMoveY !== -1 && (mouse.x - startMoveX) * (mouse.x - startMoveX) + (mouse.y - startMoveY) * (mouse.y - startMoveY)  < 9) {
                        return;
                    }

                    longPressDrag = true;
                    // 根据鼠标位置的变化来判断是左滑还是右滑
                    var deltaX = mouse.x - startMoveX;
                    accumulatedDeltaX += deltaX;

                    if (Math.abs(accumulatedDeltaX) >= 10) {
                        changeOffsetTime(accumulatedDeltaX > 0);
                        accumulatedDeltaX = 0; // 重置累积的水平移动距离
                    }
                    startMoveX = mouse.x; // 更新startMoveX，以避免重复计算
                }
                onPressed: (mouse) =>{
                    startMoveX = mouse.x;
                    startMoveY = mouse.y
                    longPressDrag = false;
                }
                onReleased: {
                    if (longPressDrag) {
                        dashboardManager.setOffsetTime(currentOffsetTime)
                    }
                    longPressDrag = false;
                    startMoveX = -1;
                    startMoveY = -1;
                    accumulatedDeltaX = 0;
                }
                onDoubleClicked: {
                    currentOffsetTime = 0;
                    dashboardManager.setOffsetTime(currentOffsetTime)
                }
            }
        }
    }

    Rectangle {
        id: addBtn
        anchors.right: parent.right
        anchors.rightMargin: 12
        width: 32
        height: 32
        color: Colors.color_FFFFFF_15
        radius: RadiusConfig.radius_4_88
        Accessible.role: Accessible.Button
        property bool isClicked: false
        Image {
            width: 20
            height: 20
            anchors.verticalCenter: parent.verticalCenter
            anchors.horizontalCenter: parent.horizontalCenter
            source: addBtn.isClicked ? "qrc:/app_qrc/icons/icon_addtime_clicked.svg" : "qrc:/icons/dashboard/icon_addtime.svg"
            sourceSize: Qt.size(20, 20)
        }
        MouseArea {
            anchors.fill: parent
            onPressed: {
                addBtn.isClicked = true;
            }
            onReleased: {
                addBtn.isClicked = false;
            }
            onClicked: {
                changeOffsetTime(true);
                dashboardManager.setOffsetTime(currentOffsetTime)
            }
        }
    }

    Component.onCompleted: {
        currentOffsetTime = dashboardManager.getOffsetTime();
        formatTime();
    }
}
