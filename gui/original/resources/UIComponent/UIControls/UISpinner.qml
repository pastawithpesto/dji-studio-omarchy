import QtQuick
import UIComponent

// UISpinner
//   - 不传 progress  → 无限旋转 spinner
//   - 传 progress   → 圆环进度(0.0 ~ 1.0)
//   - 可选 text     → 副文案
//
// 复用 QtQuick 原生属性,无新增信号。
//
// 用例:
//   UISpinner { size: UIControlSize.L }
//   UISpinner { size: UIControlSize.XL; progress: 0.42; text: "正在分析" }
//   UISpinner { size: UIControlSize.M; progress: -1 }
Item {
    id: root

    property int size: UIControlSize.M
    property real   progress: -1          // -1 = indeterminate;0~1 = ring progress
    property string text: ""
    property url    imageSource: ""
    property int    imageSize: diameter
    property bool   showCenterProgress: false
    property color  backgroundColor: _style.bgColor
    property int    borderRadius: _style.borderRadius

    readonly property var _style: UITheme.spinner.of(size)

    property color  trackColor: _style.trackColor
    property color  textColor:  _style.textColor
    property int    textSpacing: _style.textSpacing
    property int    lineHeight: _style.lineHeight

    property int  diameter: _style.diameter
    property real strokeWidth: _style.strokeWidth
    property real padding: _style.padding
    readonly property bool indeterminate: progress < 0
    readonly property int  spinDuration: _style.spinDuration
    readonly property int  _effectiveSize: _useImage ? imageSize : diameter

    implicitWidth:  Math.max(_effectiveSize, label.implicitWidth)
    implicitHeight: _effectiveSize + (text.length > 0 ? textSpacing + label.implicitHeight : 0)

    readonly property bool _useImage: imageSource.toString().length > 0

    Rectangle {
        anchors.fill: parent
        color: root.backgroundColor
        radius: root.borderRadius
    }

    Item {
        id: ringWrap
        width: root._effectiveSize
        height: root._effectiveSize
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top

        Canvas {
            id: ring
            anchors.fill: parent
            visible: !root._useImage
            antialiasing: true

            // indeterminate：GPU 旋转贴图，Canvas 内容静止，零 CPU 重绘
            RotationAnimator on rotation {
                running:  root.indeterminate && root.visible && !root._useImage
                from:     0
                to:       360
                duration: root.spinDuration
                loops:    Animation.Infinite
            }

            Connections {
                target: root
                function onTrackColorChanged()    { ring.requestPaint() }
                function onProgressChanged()      { ring.requestPaint() }
                function onIndeterminateChanged() {
                    if (!root.indeterminate) ring.rotation = 0
                    ring.requestPaint()
                }
            }

            onWidthChanged:        requestPaint()
            onHeightChanged:       requestPaint()
            Component.onCompleted: requestPaint()

            onPaint: {
                const ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)

                const cx = width  / 2
                const cy = height / 2
                const r  = cx - root.strokeWidth / 2 - root.padding
                const lw = root.strokeWidth
                const c  = root.trackColor

                if (root.indeterminate) {
                    // createConicalGradient 是 Qt Quick Canvas 专有 API（非 CSS 草案的 createConicGradient）
                    // 一次 draw call 替代 360 段循环；头端不透明在 360°，尾端透明在 0°
                    const grad = ctx.createConicalGradient(cx, cy, 0)
                    grad.addColorStop(0.0, c)
                    grad.addColorStop(1.0, Qt.rgba(c.r, c.g, c.b, 0.0))
                    ctx.beginPath()
                    ctx.arc(cx, cy, r, 0, Math.PI * 2)
                    ctx.strokeStyle = grad
                    ctx.lineWidth   = lw
                    ctx.lineCap     = "round"
                    ctx.stroke()
                } else {
                    // 背景轨道环
                    ctx.beginPath()
                    ctx.arc(cx, cy, r, 0, Math.PI * 2)
                    ctx.strokeStyle = Qt.rgba(c.r, c.g, c.b, 0.2)
                    ctx.lineWidth   = lw
                    ctx.lineCap     = "butt"
                    ctx.stroke()
                    // 进度弧（从 12 点顺时针）
                    if (root.progress > 0) {
                        ctx.beginPath()
                        ctx.arc(cx, cy, r,
                                -Math.PI / 2,
                                -Math.PI / 2 + root.progress * Math.PI * 2)
                        ctx.strokeStyle = c
                        ctx.lineWidth   = lw
                        ctx.lineCap     = "round"
                        ctx.stroke()
                    }
                }
            }
        }

        Loader {
            active: root._useImage
            anchors.fill: parent
            sourceComponent: Image {
                source: root.imageSource
                sourceSize: Qt.size(root.imageSize, root.imageSize)
                smooth: true

                RotationAnimation on rotation {
                    running: root.indeterminate && root.visible
                    from: 0; to: 360
                    duration: root.spinDuration
                    loops: Animation.Infinite
                }
            }
        }

        Text {
            visible: root.showCenterProgress && !root.indeterminate
            anchors.centerIn: parent
            text: Math.round(root.progress * 100).toString()
            color: root.textColor
            font.pixelSize: root._style.centerFontSize
        }
    }

    Text {
        id: label
        visible: root.text.length > 0
        text: root.text
        color: root.textColor
        font.pixelSize: root._style.fontSize
        //height: root.lineHeight
        anchors.top: ringWrap.bottom
        anchors.topMargin: root.textSpacing
        anchors.horizontalCenter: parent.horizontalCenter
        verticalAlignment: Qt.AlignVCenter
    }
}
