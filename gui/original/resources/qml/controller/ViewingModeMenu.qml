// 视角数据量小且一般不变动，直接写死，不写成列表和model的方式
import QtQuick 2.15
import Controls 1.0
import Config 1.0
import PanoramaConfig 1.0
import Qt5Compat.GraphicalEffects

Rectangle {

    id: viewingModeMenuRoot

    property var modeNames: ({
        [PanoramaConfig.SHOT_VIEW]: qsTr("pccut_image_preview_switch"),
        [PanoramaConfig.FREEDOM_VIEW]: qsTr("pccut_image_liberty_switch"),
        [PanoramaConfig.DIRECTION_LOCK]: qsTr("pccut_panel_image_directionlock"),
        [PanoramaConfig.SELFIE_VIEW]: qsTr("pccut_editing_assistant"),
        [PanoramaConfig.FORWARD_VIEW]: qsTr("pccut_editing_perspective_forward"),
        [PanoramaConfig.FRONTSHOT_VIEW]: qsTr("pccut_editing_perspective_towards")
    })

    property var modeDescs: ({
        [PanoramaConfig.SHOT_VIEW]: qsTr("pccut_image_preview_desc"),
        [PanoramaConfig.FREEDOM_VIEW]: qsTr("pccut_image_liberty_desc"),
        [PanoramaConfig.DIRECTION_LOCK]: qsTr("pccut_image_directionlock_desc"),
        [PanoramaConfig.SELFIE_VIEW]: qsTr("pccut_image_backward_desc"),
        [PanoramaConfig.FORWARD_VIEW]: qsTr("pccut_editing_perspective_forward_explain"),
        [PanoramaConfig.FRONTSHOT_VIEW]: qsTr("pccut_editing_perspective_towards_explain")
    })

    // 支持选择的模式列表
    property var supportModes: ({
        [PanoramaConfig.SHOT_VIEW]: true,
        [PanoramaConfig.FREEDOM_VIEW]: true,
        [PanoramaConfig.DIRECTION_LOCK]: true,
        [PanoramaConfig.SELFIE_VIEW]: true,
        [PanoramaConfig.FORWARD_VIEW]: true,
        [PanoramaConfig.FRONTSHOT_VIEW]: true
    })
    
    property int selectedMode: PanoramaConfig.FREEDOM_VIEW
    // property string selectedModeName: modeNames[selectedMode]
    signal select(int mode, string name)

    // 每个item
    component ViewingModeItem: Item {

        property string iconSource: ""
        property int mode: -1
        property string itemTitle: modeNames[mode]
        property string itemDesc: modeDescs[mode]
        visible: supportModes[mode]

        signal select()

        // height: 50
        // width: parent.width
        // color: Colors.color_454649

        Rectangle {
            visible: mouse.containsMouse
            color: Colors.color_68696D
            radius: 4
            anchors {
                fill: parent
                leftMargin: 4
                rightMargin: 4
                topMargin: 4
                bottomMargin: 0
            }
        }

        Image {
            id: viewingModeIcon
            width: 16
            height: 16
            source: iconSource
            sourceSize: Qt.size(16, 16)
            anchors {
                left: parent.left
                top: parent.top
                leftMargin: 12
                topMargin: 11
            }
        }

        Text {
            id: viewingModeTitle
            anchors {
                left: viewingModeIcon.right
                leftMargin: 4
                top: viewingModeIcon.top
            }
            text: itemTitle
            color: Colors.color_EEEEEE
            font.pixelSize: 12
        }

        Text {
            id: viewingModeDesc
            anchors {
                left: parent.left
                bottom: parent.bottom
                leftMargin: 12
                bottomMargin: 8
            }
            text: itemDesc
            color: Colors.color_999999
            font.pixelSize: 11
        }

        Image {
            id: checkIcon
            anchors {
                right: parent.right
                rightMargin: 16
                verticalCenter: parent.verticalCenter
            }
            width: 16
            height: 16
            sourceSize: Qt.size(16, 16)
            visible: selectedMode == mode
            source: "qrc:/icons/adjustment/icon_compose_check.svg"
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true

            onClicked: { 
                viewingModeMenuRoot.select(mode, itemTitle)
            }
        }
    }

    property int itemHeight: 55
    property int verticalSpacing: 0
    // 不同情况数量不同
    property int itemCount: Object.values(supportModes).filter(v => v).length

    width: parent.width
    height: itemHeight * itemCount + verticalSpacing * (itemCount + 1) + itemColumn.anchors.bottomMargin
    radius: 4
    color: Colors.color_454649

    // 添加阴影效果
    layer.enabled: true
    layer.effect: DropShadow {
        horizontalOffset: 0
        verticalOffset: 0
        radius: 10
        color: Colors.color_000000_40
    }

    Column {
        id: itemColumn
        width: parent.width
        height: parent.height - verticalSpacing
        spacing: verticalSpacing
        anchors {
            top: parent.top
            bottom: parent.bottom
            bottomMargin: 4
        }

        // 拍摄视角，解释起来就是镜头视角
        ViewingModeItem {
            id: shotView
            width: parent.width
            height: itemHeight
            mode: PanoramaConfig.SHOT_VIEW
            iconSource: "qrc:/icons/panorama/panorama_shot_view.svg"
        }
        
        // 自由视角
        ViewingModeItem {
            id: freedomView
            width: parent.width
            height: itemHeight
            mode: PanoramaConfig.FREEDOM_VIEW
            iconSource: "qrc:/icons/panorama/panorama_freedom_view.svg"
        }

        // 方向锁定
        ViewingModeItem {
            id: fixView
            width: parent.width
            height: itemHeight
            mode: PanoramaConfig.DIRECTION_LOCK
            iconSource: "qrc:/icons/panorama/panorama_direction_lock.svg"
        }

        // 自拍视角
        ViewingModeItem {
            id: selfieView
            width: parent.width
            height: itemHeight
            mode: PanoramaConfig.SELFIE_VIEW
            iconSource: "qrc:/icons/panorama/panorama_selfie_view.svg"
        }

        // 前进视角
        ViewingModeItem {
            id: forwardView
            width: parent.width
            height: itemHeight
            mode: PanoramaConfig.FORWARD_VIEW
            iconSource: "qrc:/icons/panorama/panorama_forward_view.svg"
        }

        // 前拍视角
        ViewingModeItem {
            id: frontShotView
            width: parent.width
            height: itemHeight
            mode: PanoramaConfig.FRONTSHOT_VIEW
            iconSource: "qrc:/icons/panorama/panorama_front_shot_view.svg"
        }
    }
}
