/**
 * @author: dendi.zheng
 * @details: QML的UI工具类，大家有UI的工具方法可以往这里扔
 * @date: 2024-04-17 21:50:08
 */

pragma Singleton
import QtQuick 2.15

QtObject {

    /**
     * @desc 获取组件的根布局
     * @param 目标组件
     * @return 目标组件的根布局
     */
    function getTopParent(target) {
        var component = target;
        while (component.parent !== null && component.parent !== undefined && component.parent !== component) {
            component = component.parent;
        }
        return component;
    }

    /**
     * @desc 时间格式化
     *
     * @millisecond 毫秒
     * @return 时间串 分钟：秒
     */
    function formatSeconds(millisecond) {
        var seconds = millisecond / 1000;
        var minutes = Math.floor(seconds / 60);
        var remainingSeconds = Math.round(seconds % 60);
        //秒数有可能余数为60，此时需要进位
        if(remainingSeconds == 60){
            minutes += 1;
            remainingSeconds = 0;
        }
        // 如果分钟或秒数小于 10，前面补零
        minutes = minutes < 10 ? "0" + minutes : minutes;
        remainingSeconds = remainingSeconds < 10 ? "0" + remainingSeconds : remainingSeconds;
        return minutes + ":" + remainingSeconds;
    }

    /* 获取相对于根窗口的全局的坐标，输入参数为需要获取全局坐标的对象 */
    function getGlobalPosition(targetObject) {
        var positionX = 0;
        var positionY = 0;
        var obj = targetObject;

        /* 遍历所有的父窗口 */
        while (obj !== null) {
            /* 累加计算坐标 */
            positionX += obj.x;
            positionY += obj.y;
            obj = obj.parent;
        }
        return {
            "x": positionX,
            "y": positionY
        };
    }
}
