import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Config 1.0
import Controls 1.0

ToolTip {
    id: toolTip
    y: parent.height + 4
    opacity: 0
    delay: 500
    // 像素对齐开关：默认 false 保持老代码不变；true 时宽高向上取整到整数像素
    // 避免圆角遮罩(LightClipRectangle)在亚像素下吃掉右/下边框
    property bool pixelAligned: false
    width: pixelAligned ? Math.ceil(implicitWidth) : implicitWidth
    height: pixelAligned ? Math.ceil(implicitHeight) : implicitHeight
    // 背景毛玻璃是否实时刷新：默认 true 保持老代码不变；false 时只在显示时捕获一次
    // 省掉 ShaderEffectSource 每帧重抓 + FastBlur 重算（大量标记 hover/拖动场景减负）
    property bool liveBackground: true
    property string tip: '' // 鼠标悬停的提示文案
    property int textWrapMode: Text.WrapAnywhere
    // 渐隐渐现动画时长，可配置；默认 300 保持老代码不变
    property int animationDuration: 300

    // 渐隐渐现的动画
    Behavior on opacity {
        NumberAnimation {
            duration: toolTip.animationDuration
        }
    }
    // 监听 visible 属性的变化，控制 opacity
    onVisibleChanged: {
        if (visible) {
            opacity = 1.0
        } else {
            opacity = 0.0
        }
    }
    // 背景
    background: LightClipRectangle {
        anchors.fill: parent
        clip: true
        radius: [4,4,4,4]

        ShaderEffectSource {
            id: shaderSource
            // 仅当 tooltip 与 mainPanel 处于同一窗口时才捕获其内容做毛玻璃背景。
            // 偏好设置等独立 Window 里弹出的 tooltip，跨窗口捕获 mainPanel 的 ShaderEffectSource
            // 在部分 GPU/驱动上会死锁渲染线程导致软件卡死；此时 sourceItem 置 null，
            // 退化为下方纯色圆角背景（不再做模糊）。
            sourceItem: (typeof mainPanel !== "undefined" && mainPanel
                         && shaderSource.Window.window
                         && shaderSource.Window.window === mainPanel.Window.window) ? mainPanel : null
            sourceRect: Qt.rect(toolTip.x, toolTip.y, toolTip.width, toolTip.height)
            width: parent.width
            height: parent.height
            live: toolTip.liveBackground
            smooth: true
        }

        // 高斯调节
        FastBlur {
            anchors.fill: parent
            source: shaderSource
            radius: 48
        }

        Rectangle {
            anchors.fill: parent
            border.color: Colors.color_444444
            border.width: 0.5
            color: Colors.color_141414_85
            radius: 4
        }
    }
    leftPadding: 8
    rightPadding: 8
    topPadding: 6
    bottomPadding: 6
    contentItem: Text {
        font.pixelSize: 11
        text: tip
        wrapMode: textWrapMode
        color: Colors.color_EEEEEE
    }
}
