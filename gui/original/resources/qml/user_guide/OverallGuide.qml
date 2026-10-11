import QtQuick 2.15
import QtQuick.Layouts 1.15
import Controls 1.0
import Config 1.0
import app_qrc 1.0

Rectangle{
    id: root
    width: 420
    height: 98
    color: Colors.transparent
    property int curStep: 0
    property bool isClickNextBtn: false // 通过点击下一步按钮进入下一步
    property int descriptionItemWidth: 400
    property bool imageIsVisible: true
    property bool imageIsInLeft: true
    property int imageLeftMargin: 0
    property int imageTopMargin: 30
    property int descriptionTopMargin: 0
    property string descriptionText: qsTr("pccut_guide_overall_function_1")
    property bool isFinishStep: curStep === 4

    signal exitGuide();
    signal nextStep();
    Image {
        id: image
        visible: imageIsVisible
        width: 84
        height: 55
        anchors{
            left: parent.left
            leftMargin: imageLeftMargin
            top: parent.top
            topMargin: imageTopMargin
        }
        source: "qrc:/icons/icon_guide_arrow1.svg"
    }

    Item{
        id: descriptionItem
        anchors{
            left: parent.left
            leftMargin: (imageIsVisible && imageIsInLeft) ? 108 : 0
            top: parent.top
            topMargin: descriptionTopMargin
        }

        height: parent.height
        width: descriptionItemWidth
    Image{
        id: stepText
        width: 40
        height: 18
        anchors{
            left: parent.left
            top: parent.top
        }
        source: "qrc:/icons/icon_guide_step" + root.curStep.toString() +".svg"
        sourceSize: Qt.size(40, 18)
    }

    Text {
        id: tips
        anchors{
            left: stepText.left
            top: stepText.bottom
        }
        width: 312
        height: 28

        font.pixelSize: 24
        font.weight: Font.DemiBold
        lineHeight: 28 / 24
        lineHeightMode: Text.FixedHeight
        color: "#FFFFFF"
        text: root.descriptionText
    }


    Rectangle {
        id: nextBtn
        Layout.alignment: Qt.AlignVCenter
        width: 88
        height: 28

        anchors{
            left: exitedBtn.right
            leftMargin: 8
            top:tips.bottom
            topMargin: 20
        }

        color: nextArea.containsMouse ? ColorsConfig.color_F44C65_6DFFD3 : ColorsConfig.color_brand
        radius: RadiusConfig.radius_6_88

        Text {
            anchors.centerIn: parent
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            color: ColorsConfig.color_FFFFFF_000000
            text: root.isFinishStep ? qsTr("pccut_guide_done") : qsTr("pccut_guide_next")
        }

        MouseArea {
            id: nextArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
                if(curStep === 4){ // 已经执行到最后一步
                    curStep = 0;
                    exitGuide();
                    return;
                }

                // 连点守卫：step2 等待片段落轨期间（curStep 已到 2 但 guideStep 还在 1）忽略后续点击
                if(curStep === 2 && userGuideMaskManager.guideStep === 1) return;

                root.isClickNextBtn = true;
                curStep += 1;
                if(curStep == 2){
                    // step2 解耦：只下发添加素材命令；changeToFilterTab 由 onCurStepChanged 统一发；
                    // guideStep 推进改由 UserGuideMask 监听 firstClipLaidOut 后执行，不在此 emit nextStep()
                    globalSignal.addFirstMediaToTrack();
                    root.isClickNextBtn = false;
                    return;
                }else if(curStep == 3){
                    // addLocalFilter 由 onCurStepChanged 统一发，此处不重复 emit
                }

                nextStep();
            }
        }
    }

    Rectangle {
        id: exitedBtn
        objectName: actionableItemName.exit
        visible: !root.isFinishStep
        Layout.alignment: Qt.AlignVCenter
        width: 88
        height: 28

        anchors{
            left: stepText.left
            top:tips.bottom
            topMargin: 20
        }

        color: exitedArea.containsMouse ? Colors.color_7A7B80 : Colors.color_68696D
        radius: 6

        Text {
            anchors.centerIn: parent
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            color: Colors.color_FFFFFF
            text: qsTr("pccut_guide_quit")
        }

        MouseArea {
            id: exitedArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
                curStep = 0;
                exitGuide();
            }
        }
    }
    }

    Connections {
        target: root
        function onCurStepChanged() {
            updateRoot();
        }
    }

    function updateRoot(){
        if(root.curStep === 0){
            root.descriptionItemWidth = 400
            root.imageIsVisible = true
            root.imageIsInLeft = true
            root.imageLeftMargin = 0
            root.imageTopMargin = 30
            root.descriptionTopMargin = 0
            root.width = 420
            root.height = 98
            image.source = "qrc:/icons/icon_guide_arrow1.svg"
            root.descriptionText = qsTr("pccut_guide_overall_function_1")
        }

        if(root.curStep === 1){
            root.x = 250;
            root.y = 343;
            root.width = 456;
            root.height = 98;
            root.imageIsVisible = false;
            root.descriptionText = qsTr("pccut_guide_overall_function_2")
        }else if(root.curStep === 2){
            root.x = 227;
            root.y = 311;
            root.width = 480;
            root.height = 98;
            root.imageIsVisible = false;
            root.descriptionText = qsTr("pccut_guide_overall_function_3")
        }else if(root.curStep === 3){
            image.source = "qrc:/icons/icon_guide_arrow2.svg";
            root.imageIsVisible = true;
            root.imageIsInLeft = true;

            root.x = 720;
            root.y = 482;
            root.width = 325;
            root.height = 110;
            root.imageTopMargin = 0;
            root.descriptionText = qsTr("pccut_guide_overall_function_4")
        }else if(root.curStep === 4){
            image.source = "qrc:/icons/icon_guide_arrow3.svg";
            root.imageIsVisible = true;
            root.imageIsInLeft = false;
            root.imageLeftMargin = 288;
            image.width = 84;
            image.height = 55;
            root.imageTopMargin = 0;
            root.descriptionTopMargin = 30;

            root.x = 848;
            root.y = 57;
            root.width = 372;
            root.height = 128;
            root.descriptionText = qsTr("pccut_guide_overall_function_5")
        }
    }
}


