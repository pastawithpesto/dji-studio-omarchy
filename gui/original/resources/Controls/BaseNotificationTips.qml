import QtQuick 2.15
import QtQuick.Controls
import Controls 1.0
import Config 1.0
import Qt5Compat.GraphicalEffects

/**
 * @desc 通用提示气泡控件
 * 支持自定义文本、颜色、箭头位置等
 */
Item {
    id: root
    width: parent.width

    property string text: ""
    property string textColor: Colors.color_EEEEEE
    property int fontSize: 11
    property int fontWeight: Font.Normal
    property int lineHeight: 15
    property real letterSpacing: 1
    property int textWrapMode: Text.WordWrap
    
    property int arrowLeftMargin: 90
    property string arrowSource: "qrc:/icons/panorama/transition_effect_arrow.svg"
    property bool showArrow: true
    property int arrowWidth: 8
    property int arrowHeight: 8
    property int arrowPosition: 0
    
    property string backgroundColor: Colors.color_141414_85
    property string borderColor: Colors.color_444444
    property real borderWidth: 0.5
    property int radius: 4
    property bool enableBlur: true  // 是否启用背景模糊
    property int blurRadius: 48
    
    property int contentLeftMargin: 8
    property int contentRightMargin: 8
    property int contentTopMargin: 6
    property int contentBottomMargin: 8
    
    property string iconSource: ""
    property int iconSize: 16
    property int iconSpacing: 6
    property bool showIcon: iconSource !== ""

    Rectangle {
        id: parentRectangle
        width: parent.width
        //箭头向上时,要向下偏移，否则箭头被盖住了
        y: (root.arrowPosition === 1 && root.showArrow) ? root.arrowHeight : 0
        color: root.backgroundColor
        border.width: root.borderWidth
        border.color: root.borderColor
        radius: root.radius
        
        LightClipRectangle {
            anchors.fill: parent
            clip: true
            radius: [root.radius, root.radius, root.radius, root.radius]
            visible: root.enableBlur

            ShaderEffectSource {
                id: shaderSource
                sourceItem: mainPanel
                sourceRect: Qt.rect(root.x, root.y, root.width, root.height)
                width: parent.width
                height: parent.height
                live: true
                smooth: true
            }

            FastBlur {
                anchors.fill: parent
                source: shaderSource
                radius: root.blurRadius
            }

            Rectangle {
                anchors.fill: parent
                border.color: root.borderColor
                border.width: root.borderWidth
                color: root.backgroundColor
                radius: root.radius
            }
        }
        
        Row {
            id: contentRow
            spacing: root.iconSpacing
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                leftMargin: root.contentLeftMargin
                rightMargin: root.contentRightMargin
                topMargin: root.contentTopMargin
            }
            
            Image {
                source: root.iconSource
                width: root.iconSize
                height: root.iconSize
                sourceSize: Qt.size(root.iconSize, root.iconSize)
                visible: root.showIcon
                anchors.verticalCenter: dynamicText.verticalCenter
            }
            
            Text {
                id: dynamicText
                text: root.text
                color: root.textColor
                font.pixelSize: root.fontSize
                font.weight: root.fontWeight
                wrapMode: root.textWrapMode
                lineHeight: root.lineHeight
                font.letterSpacing: root.letterSpacing
                lineHeightMode: Text.FixedHeight
                width: contentRow.width - (root.showIcon ? (root.iconSize + root.iconSpacing) : 0)

                Component.onCompleted: {
                    updateParentHeight();
                }

                onHeightChanged: {
                    updateParentHeight();
                }
                
                function updateParentHeight() {
                    parentRectangle.height = dynamicText.height + root.contentTopMargin + root.contentBottomMargin;
                    root.height = parentRectangle.height + (root.showArrow ? 8 : 0);
                }
            }
        }
    }

    Image {
        id: arrow
        source: root.arrowSource
        width: root.arrowWidth
        height: root.arrowHeight
        sourceSize: Qt.size(root.arrowWidth, root.arrowHeight)
        visible: root.showArrow

        // 使用states来控制箭头位置
        states: [
            State {
                name: "bottom"
                when: root.arrowPosition === 0
                AnchorChanges {
                    target: arrow
                    anchors.top: undefined
                    anchors.bottom: parent.bottom
                }
                PropertyChanges {
                    target: arrow
                    anchors.bottomMargin: 4
                    anchors.topMargin: 0
                    rotation: 0  // 箭头向下
                }
            },
            State {
                name: "top"
                when: root.arrowPosition === 1
                AnchorChanges {
                    target: arrow
                    anchors.bottom: undefined
                    anchors.top: parent.top
                }
                PropertyChanges {
                    target: arrow
                    anchors.topMargin: 4
                    anchors.bottomMargin: 0
                    rotation: 180  // 箭头向上（如果需要旋转图标）
                }
            }
        ]
        
        anchors {
            left: parent.left
            leftMargin: root.arrowLeftMargin - root.contentLeftMargin
        }
    }

    
    function setSimpleText(textContent) {
        root.text = textContent;
        root.showIcon = false;
        root.enableBlur = false;
    }
    
    function setTextWithIcon(textContent, iconPath) {
        root.text = textContent;
        root.iconSource = iconPath;
        root.showIcon = true;
    }
}