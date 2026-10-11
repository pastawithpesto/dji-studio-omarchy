import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T
import Qt5Compat.GraphicalEffects
import UIComponent

// UISlider
//   基础滑块 + 可选数值显示 / 重置按钮。
//   centerOrigin: true 时填充从中点开始（适用于 -100~100 类对称调节）。
//   gradientColors: 非空时轨道显示线性渐变。
Item {
    id: root

    property alias from:     slider.from
    property alias to:       slider.to
    property alias value:    slider.value
    property alias stepSize: slider.stepSize
    property alias snapMode: slider.snapMode
    property alias pressed:  slider.pressed

    property int size: UIControlSize.M

    property bool   showValue: false
    property string valueSuffix: ""
    property bool   showResetButton: false
    property real   resetValue: 0
    property bool   centerOrigin: false
    property var    gradientColors: []
    property url    handleSource: ""

    // todo  后期统一修改从_style中取值
    property bool  showTicks: false
    property color tickColor: UIColors.gray1
    property int   tickCount: 6
    readonly property int tickHeight: 8
    readonly property real tickWidth: 1.5
    readonly property int tickMargin: 3

    readonly property var _style: UITheme.slider.of(size)

    property color trackColor:          _style.trackColor
    property color fillColor:           _style.fill.base
    property color fillColorDisabled:   _style.fill.disabled
    property color handleColor:         _style.handle.base
    property color handleColorDisabled: _style.handle.disabled

    readonly property color resolvedFillColor:
        enabled ? fillColor : fillColorDisabled
    readonly property color resolvedHandleColor:
        enabled ? handleColor : handleColorDisabled

    property real  disabledOpacity: _style.opacity.disable
    readonly property int   trackRadius: 3
    readonly property int   resetIconSize: UISize.sizeMD
    readonly property int   valueLabelMinWidth: UISize.controlHeight

    readonly property bool _useHandleImage: handleSource.toString().length > 0
    readonly property bool _canShowTicks: showTicks && tickCount > 1

    signal sigMoved()
    signal sigResetRequested()

    implicitHeight: row.implicitHeight
    implicitWidth:  size === UIControlSize.M ? 117
                                             : size === UIControlSize.XL ? 240 : 180
    
    RowLayout {
        id: row
        anchors.fill: parent
        spacing: UISize.sizeXS

        T.Slider {
            id: slider
            Layout.fillWidth: true
            from: 0
            to: 100
            value: 0
            implicitHeight: root._style.height + (root._canShowTicks ? root.tickHeight + root.tickMargin : 0)
            implicitWidth: root.width

            onMoved: root.sigMoved()

            background: Item {
                x: slider.leftPadding
                y: slider.topPadding + (slider.availableHeight - root._style.trackHeight) / 2
                width: slider.availableWidth
                height: root._style.trackHeight

                Rectangle {
                    id: trackBg
                    anchors.fill: parent
                    radius: root.trackRadius
                    color: root.gradientColors.length > 0 ? "transparent" : root.trackColor
                    visible: root.gradientColors.length === 0
                }

                Loader {
                    active: root.gradientColors.length >= 2
                    anchors.fill: parent
                    opacity: root.enabled ? 1.0 : root.disabledOpacity
                    sourceComponent: Rectangle {
                        radius: root.trackRadius
                        color: "transparent"
                        layer.enabled: true
                        layer.effect: OpacityMask {
                            maskSource: Rectangle {
                                width: trackBg.width
                                height: trackBg.height
                                radius: root.trackRadius
                            }
                        }
                        LinearGradient {
                            anchors.fill: parent
                            start: Qt.point(0, 0)
                            end: Qt.point(parent.width, 0)
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: root.gradientColors.length >= 2 ? root.gradientColors[0] : "transparent" }
                                GradientStop { position: 1.0; color: root.gradientColors.length >= 2 ? root.gradientColors[1] : "transparent" }
                            }
                        }
                    }
                }

                Rectangle {
                    visible: !root.centerOrigin && root.gradientColors.length === 0
                    width: slider.visualPosition * parent.width
                    height: parent.height
                    color: root.resolvedFillColor
                    radius: root.trackRadius
                }

                Rectangle {
                    visible: root.centerOrigin && root.gradientColors.length === 0
                    x: slider.visualPosition < 0.5 ? slider.visualPosition * parent.width : 0.5 * parent.width
                    width: Math.abs(0.5 - slider.visualPosition) * parent.width
                    height: parent.height
                    color: root.resolvedFillColor
                    radius: root.trackRadius
                }

                Repeater {
                    width: parent.width
                    model: root.showTicks && root.tickCount > 1 ? root.tickCount : 0
                    Rectangle {
                        property real frac: index / (root.tickCount - 1)
                        x: frac * (parent.width )
                        anchors.verticalCenter: parent.verticalCenter
                        width:  root.tickWidth
                        height: root.tickHeight
                        color:  root.tickColor
                    }
                }
            }

            handle: Item {
                x: root._canShowTicks ? slider.leftPadding + slider.visualPosition * slider.availableWidth - width / 2
                                      : slider.leftPadding + slider.visualPosition * (slider.availableWidth - width) 
                y: slider.topPadding + slider.availableHeight / 2 - height / 2
                implicitWidth: root._style.handleSize
                implicitHeight: root._style.handleSize

                Rectangle {
                    anchors.fill: parent
                    visible: !root._useHandleImage
                    radius: width / 2
                    color: root.resolvedHandleColor
                }

                Loader {
                    active: root._useHandleImage
                    anchors.fill: parent
                    sourceComponent: Image {
                        source: root.handleSource
                        sourceSize: Qt.size(width, height)
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                    }
                }
            }
        }

        UIText {
            visible: root.showValue
            text: Math.round(slider.value) + root.valueSuffix
            type: UITextType.Primary
            size: UIControlSize.M
            Layout.minimumWidth: root.valueLabelMinWidth
            horizontalAlignment: Text.AlignRight
        }

        Item {
            visible: root.showResetButton
            implicitWidth: root.resetIconSize
            implicitHeight: root.resetIconSize
            Loader {
                anchors.fill: parent
                active: root.showResetButton
                sourceComponent: Component {
                    Image {
                        anchors.fill: parent
                        sourceSize: Qt.size(width, height)
                        smooth: true
                        source: resetHover.hovered
                              ? UITheme.isolationIcon("reset_hover.svg")
                              : UITheme.isolationIcon("reset.svg")
                        opacity: root.enabled ? 1.0 : root.disabledOpacity
                        HoverHandler { id: resetHover }
                        TapHandler {
                            onTapped: {
                                slider.value = root.resetValue
                                root.sigResetRequested()
                            }
                        }
                    }
                }
            }
        }
    }
}
