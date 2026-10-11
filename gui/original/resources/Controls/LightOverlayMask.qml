import QtQuick 2.15

/**
 * @author robert.guo
 * @desc 蒙层控件
 * @create_date 2024-07-18
 */
Item {
    property var rectList: []
    property int maskRadius: 10
    anchors.fill: parent
    enabled: true

    /**
     * @desc 设置抠图方框列表数据，并绘制ui
     *
     * @param data 列表数据
     */
    function addData(data) {
        rectList.unshift(data);
        refreshUi();
    }

    /**
     * @desc 清空数据，并执行是否重绘ui的逻辑
     *
     * @param needRefrsh 是否重回ui
     */
    function clearData(needRefrsh) {
        rectList.splice(0, rectList.length)
        if (needRefrsh) {
            refreshUi();
        }
    }

    /**
     * @desc 绘制ui
     */
    function refreshUi() {
        canvas.requestPaint();
    }

    Component.onCompleted: {
        canvas.requestPaint()
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            if (rectList.length <= 0) {
                return;
            }

            // 绘制黑色蒙层
            ctx.fillStyle = "rgba(0, 0, 0, 0.4)";
            ctx.beginPath();
            ctx.moveTo(maskRadius, 0);
            ctx.lineTo(width - maskRadius, 0);
            ctx.arcTo(width, 0, width, maskRadius, maskRadius);
            ctx.lineTo(width, height - maskRadius);
            ctx.arcTo(width, height, width - maskRadius, height, maskRadius);
            ctx.lineTo(maskRadius, height);
            ctx.arcTo(0, height, 0, height - maskRadius, maskRadius);
            ctx.lineTo(0, maskRadius);
            ctx.arcTo(0, 0, maskRadius, 0, maskRadius);
            ctx.closePath();
            ctx.fill();


            // 抠图矩形区域，让其透明
            for (var i = 0; i < rectList.length; i++) {
                ctx.clearRect(rectList[i].x, rectList[i].y, rectList[i].width, rectList[i].height);
            }
        }
    }
}
