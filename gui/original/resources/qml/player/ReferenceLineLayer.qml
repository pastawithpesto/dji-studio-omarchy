import QtQuick 2.15
import QtQuick.Controls

import Config 1.0
import Controls 1.0

Item {
    id: referenceLineRoot
    // anchors.fill: parent
    enabled: false
 
    property bool showRef:         false
    property bool showGrid:        false
    property bool showCenterPoint: false
    property bool showCrossLine:   false
    property bool showDiagonal:    false
    property bool showGoldenRatio: false
 
    readonly property color lineColor: Qt.rgba(1, 1, 1, 0.3) 
    readonly property real  lineWidth: 1
 
    Canvas {
        id: canvas
        anchors.fill: parent
        // 任意一项开启时重绘
        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            ctx.strokeStyle = referenceLineRoot.lineColor
            ctx.lineWidth   = referenceLineRoot.lineWidth
            
            if (!showRef) 
                return

            // 网格线：1/3、2/3 处横竖各两条
            if (referenceLineRoot.showGrid) {
                ;[1/3, 2/3].forEach(function(r) {
                    ctx.beginPath(); ctx.moveTo(width * r, 0); ctx.lineTo(width * r, height); ctx.stroke()
                    ctx.beginPath(); ctx.moveTo(0, height * r); ctx.lineTo(width, height * r); ctx.stroke()
                })
            }

            if (referenceLineRoot.showCenterPoint) {
                var cx = width / 2
                var cy = height / 2
                ctx.beginPath(); ctx.moveTo(cx, cy - 10); ctx.lineTo(cx, cy + 10); ctx.stroke()
                ctx.beginPath(); ctx.moveTo(cx - 10, cy); ctx.lineTo(cx + 10, cy); ctx.stroke()
            }

 
            // 十字线：水平 + 垂直中心线
            if (referenceLineRoot.showCrossLine) {
                ctx.beginPath(); ctx.moveTo(width / 2, 0);  ctx.lineTo(width / 2, height); ctx.stroke()
                ctx.beginPath(); ctx.moveTo(0, height / 2); ctx.lineTo(width, height / 2);  ctx.stroke()
            }
 
            // 对角线
            if (referenceLineRoot.showDiagonal) {
                ctx.beginPath(); ctx.moveTo(0, 0);     ctx.lineTo(width, height); ctx.stroke()
                ctx.beginPath(); ctx.moveTo(width, 0); ctx.lineTo(0, height);     ctx.stroke()
            }
 
            // 黄金分割线：0.382 / 0.618 处横竖各两条
            if (referenceLineRoot.showGoldenRatio) {
                ;[0.382, 0.618].forEach(function(r) {
                    ctx.beginPath(); ctx.moveTo(width * r, 0); ctx.lineTo(width * r, height); ctx.stroke()
                    ctx.beginPath(); ctx.moveTo(0, height * r); ctx.lineTo(width, height * r); ctx.stroke()
                })
            }
        }
 
        // 属性变化时触发重绘
        onWidthChanged:              Qt.callLater(requestPaint)
        onHeightChanged:             Qt.callLater(requestPaint)
 
        Connections {
            target: referenceLineRoot
            function onShowRefChanged()         { Qt.callLater(canvas.requestPaint) }
            function onShowGridChanged()        { if (showRef) Qt.callLater(canvas.requestPaint) }
            function onShowCenterPointChanged() { if (showRef) Qt.callLater(canvas.requestPaint) }
            function onShowCrossLineChanged()   { if (showRef) Qt.callLater(canvas.requestPaint) }
            function onShowDiagonalChanged()    { if (showRef) Qt.callLater(canvas.requestPaint) }
            function onShowGoldenRatioChanged() { if (showRef) Qt.callLater(canvas.requestPaint) }
        }
    }
}
