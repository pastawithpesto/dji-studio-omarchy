import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Config 1.0
import Controls 1.0

/**
 * @author robert.guo
 * @desc 自定义ToolTip，来展示多行文本
 * @create_date 2024-08-20
 */
ToolTip {
    id: customToolTip
    // 用于存储每行文本的属性和样式
    property var lines: []

    opacity: 0.0
    delay: 500

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
            sourceRect: Qt.rect(customToolTip.x, customToolTip.y, customToolTip.width, customToolTip.height)
            width: parent.width
            height: parent.height
            live: true
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

    // 暂时注释掉了，因为目前看来没有给FontMetrics设置text，那么计算的结果就是NaN，理论上没有生效
    /*
    FontMetrics {
        id: fontMetrics
        font: fontText.font
    }

    Text {
        id: fontText
        visible: false
    }
    */

    // 渐隐渐现的动画
    Behavior on opacity {
        NumberAnimation {
            duration: 300
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

    // ToolTip 的内容是一个 Column，其中包含多个 Text 元素
    contentItem: Column {
        width: parent.width
        spacing: 2 // 行间距

        // 根据 lines 属性动态创建 Text 元素
        Repeater {
            model: customToolTip.lines
            delegate: Text {
                text: modelData.text
                color: modelData.color
                font.pixelSize: modelData.size
            }
        }
    }

    // 根据内容调整 ToolTip 的宽度
    /*
    Component.onCompleted: {
        var maxWidth = 0;
        for (var i = 0; i < lines.length; ++i) {
            var line = lines[i];
            fontText.text = line.text;
            fontText.font.pixelSize = line.size;
            var textWidth = fontMetrics.width;
            maxWidth = Math.max(maxWidth, textWidth);
        }
        width = maxWidth + 10; // 加上一些边距
    }
    */
}
