import QtQuick 2.15
import QtQuick.Shapes 1.15
import Config 1.0
import app_qrc 1.0

/**
 *  @File        : DownloadAnimation.qml
 *  @Brief       : 通用下载加载指示组件。
 *                 先显示转圈 Loading（不定进度），到点后切换为圆环进度（按 progress 绘制扇环 + 中心百分比）。
 *                 用作 LUT / 水印等云端资源下载的统一加载态。
 *  @Author      : jack.sheng
 *  @Date        : 2026-07-28
 *
 *  用法：
 *      DownloadAnimation {
 *          anchors.fill: parent
 *          active: isDownloading        // 下载态显隐
 *          progress: 0.42               // 0.0–1.0；切换为圆环后驱动扇环与百分比
 *      }
 *
 *  行为：
 *      - active 置 true 起 spinnerDuration（默认 2 秒）内显示转圈 Loading；
 *      - 到点后切换为圆环进度，按 progress 绘制扇环 + 中心百分比；
 *      - active 置 false 立即停止并隐藏，重置回转圈态，下次激活重新计时。
 *
 *  自定义：
 *      ringColor / trackColor / textColor  —— 进度环 / 轨道 / 文字颜色
 *      ringWidth                           —— 圆环线宽
 *      skeletonColor / skeletonRadius      —— 占位底块颜色 / 圆角（遮盖底层内容）
 *      spinnerDuration                     —— 转圈阶段时长（毫秒）
 *      showPercentText                     —— 是否显示中心百分比
 */
Item {
    id: root

    // ── 输入属性 ────────────────────────────────────────────────
    /// 0.0–1.0；<0 视为未开始，圆环留空
    property real progress: 0
    /// 是否处于下载态（整体显隐）
    property bool active: false

    // ── 样式属性 ────────────────────────────────────────────────
    /// 占位底块颜色（遮盖底层内容，使圆环更清晰）
    property color skeletonColor: Colors.color_37383A
    /// 进度圆环颜色（与 ic_lut_download.svg 箭头一致 #EEEEEE）
    property color ringColor: "#EEEEEE"
    /// 圆环背景轨道颜色（整圈底色，用同色低透明度保持色相一致）
    property color trackColor: "#33EEEEEE"
    /// 百分比文字颜色
    property color textColor: "#EEEEEE"
    /// 占位块圆角
    property int skeletonRadius: 2
    /// 圆环线宽（覆盖 _ringW 的自动比例；默认 0 表示用 _size 比例）
    property real ringWidth: 1
    /// 转圈 Loading 持续时长（毫秒），到期切换为圆环进度
    property int spinnerDuration: 2000
    /// 是否显示中心百分比文字
    property bool showPercentText: true
    /// 圆环水平对齐：Qt.AlignLeft / Qt.AlignHCenter / Qt.AlignRight（默认靠右）
    property int alignment: Qt.AlignRight
    /// 对齐边距（右对齐时离右边缘的距离，避免被滚动条遮挡）
    property int alignmentMargin: 10

    opacity: active ? 1 : 0
    visible: active

    /// 内部状态：active 起 spinnerDuration 内为 false（显示转圈），之后 true（显示圆环）
    property bool _showProgress: false

    onActiveChanged: {
        if (active) {
            _showProgress = false
            spinnerTimer.start()
        } else {
            spinnerTimer.stop()
            _showProgress = false
        }
    }

    Timer {
        id: spinnerTimer
        interval: root.spinnerDuration
        repeat: false
        onTriggered: root._showProgress = true
    }

    // ── 圆环尺寸：与 ic_lut_download.svg 视觉对齐 ───────────────────
    // ic_lut_download.svg 画布 12×12，箭头竖杆/横杆线宽约 1.2（占尺寸 10%），
    // 圆环线宽按同比例取 10%，中心线半径 = size/2 - ringW/2
    readonly property real _size: Math.max(0, Math.min(root.width, root.height))
    readonly property real _ringW: root.ringWidth > 0 ? root.ringWidth : root._size * 0.10
    readonly property real _radius: root._size / 2 - root._ringW / 2
    readonly property real _center: root._size / 2
    // 圆环内径可用宽度（用于约束百分比文字，保证不超出圆环）
    readonly property real _innerDiameter: Math.max(0, root._radius * 2 - root._ringW)

    // ── 抗锯齿：离屏渲染 4x，再 smooth 缩回目标尺寸 ─────────────────
    // Shape 在小尺寸（12px）下曲线路径走样明显，4x SSAA 可显著消除锯齿。
    // _renderSize 为离屏 buffer 边长，最终 Image 以 smooth 采样缩回 _size。
    readonly property real _ssaaScale: 4
    readonly property real _renderSize: Math.max(1, Math.round(root._size * root._ssaaScale))
    readonly property real _renderRingW: root._ringW * root._ssaaScale
    readonly property real _renderRadius: root._radius * root._ssaaScale
    readonly property real _renderCenter: root._renderSize / 2

    // ── 占位底块（遮盖底层内容）──────────────────────────────────
    Rectangle {
        id: skeletonBlock
        anchors.fill: parent
        color: root.skeletonColor
        radius: root.skeletonRadius
        opacity: 0.5
    }

    // ── 圆环容器（按 alignment 水平对齐，垂直居中）────────────────
    Item {
        id: ringContainer
        anchors.verticalCenter: parent.verticalCenter
        // 水平位置由 alignment 驱动：左对齐贴左、右对齐贴右（留 alignmentMargin 避开滚动条）、居中取中
        x: root.alignment === Qt.AlignLeft
           ? root.alignmentMargin
           : root.alignment === Qt.AlignRight
             ? Math.max(root.alignmentMargin, root.width - root._size - root.alignmentMargin)
             : (root.width - root._size) / 2
        width: root._size
        height: root._size
        visible: root.active

        // 进度态离屏 buffer：4x 尺寸渲染背景轨道 + 进度扇环
        // 不直接显示（hideSource），由下方 ShaderEffectSource 抓取纹理后缩回目标尺寸
        Item {
            id: progressBuffer
            width: root._renderSize
            height: root._renderSize

            // 背景轨道（整圈）—— 与进度环同色低透明度，色相一致
            Shape {
                id: trackShape
                anchors.fill: parent
                ShapePath {
                    strokeColor: root.trackColor
                    strokeWidth: root._renderRingW
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    PathAngleArc {
                        centerX: root._renderCenter
                        centerY: root._renderCenter
                        radiusX: root._renderRadius
                        radiusY: root._renderRadius
                        startAngle: 0
                        sweepAngle: 360
                    }
                }
            }

            // 进度扇环（从顶部开始，顺时针）—— 与 ic_lut_download.svg 同色 #EEEEEE
            Shape {
                id: progressShape
                anchors.fill: parent
                ShapePath {
                    strokeColor: root.ringColor
                    strokeWidth: root._renderRingW
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    PathAngleArc {
                        centerX: root._renderCenter
                        centerY: root._renderCenter
                        radiusX: root._renderRadius
                        radiusY: root._renderRadius
                        startAngle: -90
                        sweepAngle: 360 * Math.max(0, Math.min(1, root.progress))

                        Behavior on sweepAngle {
                            NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
                        }
                    }
                }
            }
        }

        // 进度态显示：抓取 4x buffer 纹理，线性+mipmap 缩回目标尺寸（消除锯齿）
        // live: true 让进度扇环随 progress 动画实时重绘
        ShaderEffectSource {
            anchors.fill: parent
            visible: root._showProgress
            sourceItem: progressBuffer
            hideSource: true
            live: true
            mipmap: true
        }

        // 转圈态离屏 buffer：4x 尺寸渲染 3/4 圆弧缺口
        Item {
            id: spinnerBuffer
            width: root._renderSize
            height: root._renderSize

            Shape {
                id: spinnerShape
                anchors.fill: parent
                ShapePath {
                    strokeColor: root.ringColor
                    strokeWidth: root._renderRingW
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    PathAngleArc {
                        centerX: root._renderCenter
                        centerY: root._renderCenter
                        radiusX: root._renderRadius
                        radiusY: root._renderRadius
                        startAngle: 0
                        sweepAngle: 270
                    }
                }
            }
        }

        // 转圈态显示：旋转作用在缩回后的纹理上，线性采样（消除锯齿）
        ShaderEffectSource {
            anchors.fill: parent
            visible: root.active && !root._showProgress
            sourceItem: spinnerBuffer
            hideSource: true
            live: true
            mipmap: true

            RotationAnimator on rotation {
                from: 0
                to: 360
                duration: 800
                loops: Animation.Infinite
                running: parent.visible
            }
        }
    }

    // ── 中心百分比文字（仅进度态，跟随圆环位置）──────────────────
    // 字号按圆环内径缩放（最坏为 "100%" 四字符），保证文字不超出圆环
    Text {
        visible: root.showPercentText && root._showProgress && root.progress >= 0
        anchors.centerIn: ringContainer
        text: Math.floor(Math.max(0, Math.min(1, root.progress)) * 100) + "%"
        color: root.textColor
        font.pixelSize: Math.max(5, Math.min(8, root._innerDiameter / 2.6))
        font.weight: Font.Medium
    }
}
