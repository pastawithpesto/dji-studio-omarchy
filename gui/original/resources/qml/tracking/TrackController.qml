import QtQuick 2.15
import Config 1.0
import Controls 1.0
import AudioWavePaint 1.0
import Qt5Compat.GraphicalEffects
import app_qrc 1.0

/**
 * @author robert.guo
 * @desc 启动tk后，播放器控制ui的控件
 * @create_date 2024-07-15
 */
Rectangle {
    id: root
    height: 44
    width: parent.width
    color: Colors.color_content_area_background

    property bool tkReady: false
    property bool startTk: false
    property bool trackingInited: false
    property bool enableSpeedTracking: false
    // 使用这个loader 主要是防止文字乱码(目前文字乱码都出现在初始化的时候就加载的popuo页面中),
    // 修改popup为懒加载的形式已见效, 但是由于由于TK这个popup 太复杂, 所以只对部分UI进行了懒加载
    Loader {
        active: visible && !tkReady
        anchors.fill: parent
        sourceComponent: Item {
        // 进入tk模式后的ui展示
        anchors.fill: parent
        visible: !tkReady
        anchors.verticalCenter: parent.verticalCenter
        Text {
            text: qsTr("pccut_navigation_track_select")
            anchors {
                verticalCenter: parent.verticalCenter
                left: parent.left
                leftMargin: 13
            }

            font.pixelSize: 12
            color: Colors.color_FFFFFF
        }

        Rectangle {
            enabled: !editorManager.isInUserGuideStatus
            width: 88
            height: 28
            radius: RadiusConfig.radius_4_88
            property bool hovered: false
            color: hovered ? Colors.color_7A7B80: ColorsConfig.color_68696D_4DFFC920
            anchors {
                right: parent.right
                rightMargin:13
                verticalCenter: parent.verticalCenter
            }

            Text {
                id: cancel
                anchors {
                    fill: parent
                    leftMargin: 12
                    rightMargin: 12
                    topMargin: 4
                    bottomMargin: 4
                }
                font.pixelSize: 12
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: qsTr("pccut_navigation_track_cancel")
                color: Colors.color_FFFFFF
            }
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: parent.hovered = true
                onExited: parent.hovered = false
                onClicked: {
                    globalSignal.trackingStopAction(true)
                    globalSignal.trackingExitAction()

                }
            }
        }
    }
    }

    Loader {
        active: visible && tkReady
        // 启动tk后ui的ui展示
        anchors.fill: parent
        sourceComponent: Item {
        anchors.fill: parent

        // 每次加载时恢复上次的倍速TK状态
        Component.onCompleted: {
            enableSpeedTracking = lightSetting.getBool("tkSpeedUpEnabled", false)
        }

        LightCheckBox {
            id: speedTrackingCheckbox
            text: qsTr("pccut_tk_accelerate_btn")
            checked: enableSpeedTracking
            //visible: !CommonUtils.isWindows() && lightSetting.getBool("showTkSpeedUpFeature", false)
            visible: true
            maxTextWidth: 120  // 设置更大的文本宽度以完整显示中文
            anchors {
                left: parent.left
                leftMargin: 13
                verticalCenter: parent.verticalCenter
            }
            onCheckedChanged: {
                enableSpeedTracking = checked
                // 保存到设置
                lightSetting.save("tkSpeedUpEnabled", checked)
                // 如果TK已经在运行，触发requestSync信号更新Consumer的fps_strategy
                if (startTk) {
                    globalSignal.requestSync(true)
                }
            }
        }

        Rectangle {
            color: Colors.transparent
            anchors.centerIn: parent
            width: childrenRect.width
            height: childrenRect.height

        Rectangle {
            id: cancelTk
            objectName: actionableItemName.trackCancelButton
            width: 88
            enabled: !editorManager.isInUserGuideStatus
            height: 28
            radius: RadiusConfig.radius_4_88
            property bool hovered: false
            color: hovered ?  Colors.color_7A7B80 : Colors.color_68696D
            Text {
                id: cancelTkText
                text: qsTr("pccut_navigation_track_cancel")
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                color: Colors.color_FFFFFF
                font.pixelSize: 12
                font.weight: Font.DemiBold
                anchors {
                    fill: parent
                    leftMargin: 12
                    rightMargin: 12
                    topMargin: 4
                    bottomMargin: 4
                }
            }
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: parent.hovered = true
                onExited: parent.hovered = false
                onClicked: {
                    logger.d("[TK] TrackController::click() cancelTracking")
                    editorManager.pause()
                    globalSignal.trackingStopAction(true)
                    globalSignal.trackingExitAction()
                    // 取消追踪时，也需要删除对应的tk片段
                    globalSignal.trackingSegmentRemoveAction(true)
                }
            }
        }

        Rectangle {
            id: exitTk
            width: 88
            height: 28
            radius: RadiusConfig.radius_4_88
            property bool hovered: false
            color: {
                if (!trackingInited) {
                    // 未初始化状态：灰色
                    return hovered ?  Colors.color_7A7B80 : Colors.color_666666
                } else if (startTk) {
                    // 已开始状态：白色
                    return hovered ? Colors.color_FFFFFF : Colors.color_EEEEEE
                } else {
                    // 准备开始状态：品牌色（红色）
                    return hovered ? Colors.color_F44C65 : ColorsConfig.color_brand
                }
            }
            objectName: actionableItemName.trackStartButton
            anchors {
                left: cancelTk.right
                leftMargin: 16
            }

            HoverableText {
                id: tkControl
                objectName:"tkControlButton"
                text: startTk ? qsTr("pccut_navigation_track_finish") : qsTr("pccut_navigation_track_start")
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                color: !startTk ? ColorsConfig.color_FFFFFF_000000 : Colors.color_444444
                cursorChanged: false
                wrapMode: Text.NoWrap
                font.pixelSize: 12
                font.weight: Font.DemiBold
                anchors {
                    fill: parent
                    leftMargin: 12
                    rightMargin: 12
                    topMargin: 4
                    bottomMargin: 4
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: parent.hovered = true
                onExited: parent.hovered = false
                onClicked: {
                    if (!trackingInited) {
                        return;
                    }
                    if (!startTk) {
                        globalSignal.readyTrackingEvent() // 必须先于trackingStartAction信号发送
                        globalSignal.trackingStartAction()
                    } else {
                        logger.d("Cancel clicked")
                        globalSignal.trackingStopAction(false)
                        globalSignal.trackingExitAction()
                    }

                    if(editorManager.isInUserGuideStatus){
                        globalSignal.nextStepInTkGuide();
                    }
                }
            }
        }
        }
    }
    }
}
