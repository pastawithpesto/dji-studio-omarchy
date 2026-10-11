import QtQuick 2.15
import Qt5Compat.GraphicalEffects
import Config 1.0
import Controls 1.0

Rectangle {
    id: root
    
    
    property int hoverPadding: 4
    width: 88
    height: childrenRect.height
    color: Colors.color_transparent
    
    // 当前 DynamicContent 是否被激活
    property bool active: false
    property bool hovered: false
    // 外部驱动的悬停（例如悬停到清除按钮时，也保持快捷键边框显示）
    property bool externalHovered: false
    property int actionId: -1
    // 完整快捷键文本（如 "Ctrl+Shift+Home"），内容溢出渐隐时用作 tooltip 提示
    property string shortcutText: ""
    // 左侧溢出渐隐的像素宽度（内容超宽时从透明过渡到不透明的距离）
    readonly property int fadeWidth: 16
    
    signal clicked(var item)

    ListModel {
        id: contentModel
    }

    // 裁切+渐隐容器：固定可见宽度(=root.width)，内容靠右对齐；
    // 当快捷键过长、内容总宽超出可用宽度时，左侧淡出以提示溢出（非纯文本无法用 Text.elide）
    Item {
        id: clipContainer
        width: root.width
        height: row.height
        anchors.right: parent.right
        clip: true

        // 内容总宽超出容器可见宽度(=组件宽度)时，左侧裁切并渐隐；
        // 内容 <= 容器宽度即可完整显示(clip 边界就是容器宽)，不应渐隐
        readonly property bool overflow: row.width > width
        layer.enabled: overflow
        layer.effect: OpacityMask {
            maskSource: LinearGradient {
                width: clipContainer.width
                height: clipContainer.height
                start: Qt.point(0, 0)
                end: Qt.point(clipContainer.width, 0)
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Colors.color_transparent }
                    GradientStop { position: root.fadeWidth / clipContainer.width; color: Colors.color_000000 }
                    GradientStop { position: 1.0; color: Colors.color_000000 }
                }
            }
        }

        Row {
            id: row
            spacing: 4
            anchors.right: parent.right  // 让Row靠右对齐
            layoutDirection: Qt.LeftToRight  // 改回左到右，保持快捷键内部顺序正确
            Repeater {
                model: contentModel

                delegate: Item {
                    id: delegateItem
                    width: childrenRect.width
                    height: 16

                    // 图标显示：贴边布局，按键间距统一由 Row.spacing(4) 控制，
                    // 不再额外加左边距/透明内边距，避免与文本白底键之间出现大于 4px 的间隙
                    Rectangle {
                        height: childrenRect.height
                        width: (model.type === "image") ? childrenRect.width : 0
                        color: Colors.transparent

                        Image {
                            source: (model.type === "image") ? model.source : ""
                            anchors.left: parent.left
                        }
                    }

                    // 文本显示
                    Rectangle {
                        height: CommonUtils.isWindows() ? 16 : 12
                        width: (model.type === "text") ? (childrenRect.width + 8) : 0
                        color: CommonUtils.isWindows() ? ((model.type === "text") ? Colors.color_FFFFFF : Colors.transparent) : Colors.color_FFFFFF
                        radius: 2
                        anchors.verticalCenter: parent.verticalCenter

                        Loader {
                            active: true
                            sourceComponent: CommonUtils.isWindows() ? winTextComponent : macTextComponent
                            Component {
                                id: macTextComponent
                                Text {
                                    height: (model.type === "text") ? 30 : parent.height
                                    text: (model.type === "text") ? model.text : ""
                                    color: Colors.color_141414
                                    font.pixelSize: 8
                                    anchors {
                                        left: parent.left
                                        leftMargin: 4
                                        top: parent.top
                                        topMargin: 0
                                    }
                                }
                            }
                            Component {
                                id: winTextComponent
                                Text {
                                    height: (model.type === "text") ? 30 : parent.height
                                    text: (model.type === "text") ? model.text : ""
                                    color: (model.type === "text") ? Colors.color_141414 : Colors.color_EEEEEE
                                    font.pixelSize: (model.type === "text") ? 8 : 10
                                    font.weight: (model.type === "text") ? Font.Normal : Font.Bold
                                    anchors {
                                        left: parent.left
                                        leftMargin: (model.type === "text") ? 4 : 8
                                        top: parent.top
                                        topMargin: 3// 垂直居中，居中对齐效果会偏上，所以使用偏移量的方式
                                    }
                                }
                            }
                        }

                    }
                }
            }
        }
    }

    // 激活状态边框
    Rectangle {
        id: selectedBorder
        anchors.fill: parent
        anchors.margins: -hoverPadding
        color: "transparent"
        border.width: 1
        border.color: Colors.color_F22443
        radius: 4
        enabled: false
        z: 3
        // 显示/消失用透明度淡入淡出（与悬停边框交叉淡变即“变色”）
        opacity: active ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 100 } }
    }

    // 悬停状态边框
    Rectangle {
        id: hoverBorder
        anchors.fill: parent
        anchors.margins: -hoverPadding
        color: "transparent"
        border.width: 1
        border.color: Colors.color_454649
        radius: 4
        enabled: false
        z: 1
        // 悬停边框由外部统一悬停区域(externalHovered)驱动；
        // 不用内部 rootMouseArea.containsMouse，避免被上层 overlay 截走 hover 后卡在 true
        opacity: (!active && root.externalHovered) ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 100 } }
    }

    // 内容溢出渐隐时，悬停在快捷键区域展示完整快捷键，避免被截断后无法辨认
    LightToolTip {
        visible: clipContainer.overflow && root.externalHovered && root.shortcutText.length > 0
        tip: root.shortcutText
    }

    // 鼠标交互区域（仅处理点击；hover 由外部统一悬停区域负责，避免被上层 overlay 截走后卡住）
    MouseArea {
        id: rootMouseArea
        anchors.fill: parent
        hoverEnabled: false
        acceptedButtons: Qt.LeftButton

        onClicked: {
            root.clicked(root)
        }

        onDoubleClicked: {
            root.clicked(root)  // 双击也通知父控件，由父控件决定是否编辑
        }
    }

    // 清除选择状态
    function clearSelection() {
        root.active = false
    }

    // 添加图片
    function addImage(source) {
        contentModel.append({"type": "image", "source": source, "text": ""})
    }

    // 添加文本
    function addText(text) {
        contentModel.append({"type": "text", "source": "", "text": text})
    }
    
    // 清除所有内容
    function clearContent() {
        contentModel.clear()
    }
}
