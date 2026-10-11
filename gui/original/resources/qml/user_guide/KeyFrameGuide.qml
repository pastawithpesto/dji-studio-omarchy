import QtQuick 2.15
import QtQuick.Layouts 1.15
import Controls 1.0
import Config 1.0
import Qt5Compat.GraphicalEffects
import UserGuideTypeModel 1.0
import app_qrc 1.0

Rectangle{
    id: root
    property int verticalIndicatorLength: 40
    property int horizontalIndicatorLength: 40
    property int rootWidth: 248
    property int tipsRectangleWidth: 248
    property bool isShowStep: true  // 弹窗顶部是否展示当前执行到第几步
    width: rootWidth + verticalIndicatorLength
    height: tipsRectangle.height + horizontalIndicatorLength
    color: Colors.transparent
    property bool isFinishStep: false // 是否是最后的一步
    property int indicatorLineDirect: 3  // 指示线的方向: 0(没有指示线)，1(左)，2(右), 3(上), 4(下)
    property int curStep: 0
    property int descriptionHeight: 32
    property int horizontalIndicatorTopMargin: (root.height - horizontalIndicator.height) / 2
    property int verticalIndicatorLeftMargin: (root.width - verticalIndicator.width) / 2

    property string titleText: ""
    property string stepText: ""
    property string descriptionText: ""
    property string nextBtnText: qsTr("pccut_guide_next")
    property string finishBtnText: qsTr("pccut_guide_done")

    signal exitGuide();
    signal finishGuide();
Rectangle{
    id: tipsRectangle
    property int margin: 40 // content在此Rectangle中顶部底部间距各20px
    width: tipsRectangleWidth
    height: content.height + margin
    property int topMargin : calTopMargin()
    property int leftMargin : calLeftMargin()
    color: "white"
    radius: 12
    layer.enabled: true
    layer.effect: DropShadow {
        horizontalOffset: 0
        verticalOffset: 0
        radius: 20
        samples: 41
        transparentBorder: true
        color: Colors.color_000000_40
    }

    anchors{
        top: parent.top
        topMargin: tipsRectangle.topMargin
        left: parent.left
        leftMargin: tipsRectangle.leftMargin
    }

    function calTopMargin(){
        if(indicatorLineDirect === 3){
            return root.horizontalIndicatorLength;
        }else if(indicatorLineDirect === 4){
            return 0;
        }else{
            return root.horizontalIndicatorLength / 2;
        }
    }

    function calLeftMargin(){
        if(indicatorLineDirect === 1){
            return root.verticalIndicatorLength;
        }else if(indicatorLineDirect === 2){
            return 0;
        }else{
            return root.verticalIndicatorLength / 2;
        }
    }

    Item {
        id: content
        anchors.centerIn: parent
        width: parent.width - root.verticalIndicatorLength
        height: contentColumn.height

        Column {
            id: contentColumn
            anchors.top: parent.top
            width: parent.width
            spacing: 12 // 调整间距

            Item {
                id: titleItem
                width: parent.width
                height: title.height
                anchors{
                    left: parent.left
                }


                Text {
                    id: title
                    width: isShowStep ? 176 : titleItem.width
                    height: implicitHeight

                    anchors{
                        top: parent.top
                        left: parent.left
                    }

                    text: root.titleText
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0
                    color: Colors.color_141414
                    wrapMode: Text.WordWrap  // 设置自动换行
                }

                Text {
                    id: stepInfo
                    visible: isShowStep
                    width: 29
                    height: implicitHeight

                    anchors{
                        top: title.top
                        topMargin: 2
                        left: parent.left
                        leftMargin: titleItem.width - stepInfo.width
                    }

                    text: root.stepText
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    font.letterSpacing: 0
                    horizontalAlignment: Text.AlignRight
                    color: Colors.color_999999
                }

            }

            Text {
                id: description

                anchors{
                    left: parent.left
                }

                width: parent.width
                height: implicitHeight
                text: root.descriptionText
                font.pixelSize: 12
                font.weight: Font.Medium
                font.letterSpacing: 0
                color: Colors.color_666666

                wrapMode: Text.WordWrap  // 设置自动换行
            }

            Item {
            id: btnList
            anchors{
                horizontalCenter: parent.horizontalCenter
            }

            width:168
            height: 28

            Rectangle {
                id: nextBtn
                visible: !root.isFinishStep
                Layout.alignment: Qt.AlignVCenter
                width: 80
                height: 28

                anchors{
                    left: exitedBtn.right
                    leftMargin: 8
                    top: parent.top
                }

                color: nextArea.containsMouse ? ColorsConfig.color_F44C65_6DFFD3 : ColorsConfig.color_F22443_4DFFC9
                radius: RadiusConfig.radius_6_88

                Text {
                    anchors.centerIn: parent
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                    color: ColorsConfig.color_FFFFFF_000000
                    text: nextBtnText
                }

                MouseArea {
                    id: nextArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        if(curStep === 4 && mask.userGuideType === UserGuideType.REGIONKEYFRAME){
                            //先播放区域关键帧视频内容
                            regionKeyFrameGuide.startDelayTimerPlay();
                            return;
                        }
                        if(curStep === 6 && mask.userGuideType === UserGuideType.KEYFRAME){
                            //先播放区域关键帧视频内容
                            keyFrameGuide.startDelayTimerPlay();
                            return;
                        }

                        curStep += 1;
                    }
                }
            }

            Rectangle {
                id: exitedBtn
                objectName: actionableItemName.cancel
                visible: !root.isFinishStep
                width: 80
                height: 28

                anchors{
                    left: parent.left
                    top:parent.top
                }

                color: exitedArea.containsMouse ? Colors.color_F2F2F2 : Colors.color_EEEEEE
                radius: RadiusConfig.radius_6_88

                Text {
                    anchors.centerIn: parent
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                    color: Colors.color_666666
                    text: qsTr("pccut_guide_exit")
                }

                MouseArea {
                    id: exitedArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        exitGuide();
                    }
                }
            }

            Rectangle {
                id: finishBtn
                visible: root.isFinishStep
                Layout.alignment: Qt.AlignVCenter
                width: 80
                height: 28

                anchors{
                    horizontalCenter: parent.horizontalCenter
                    top:parent.top
                }

                color: finishBtnMouseArea.containsMouse ? ColorsConfig.color_F44C65_6DFFD3 : ColorsConfig.color_F22443_4DFFC9
                radius: 6

                Text {
                    anchors.centerIn: parent
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                    color: ColorsConfig.color_FFFFFF_000000
                    text: finishBtnText
                }

                MouseArea {
                    id:finishBtnMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        finishGuide();
                    }
                }

            }
        }
        }
    }
}
Rectangle{
    id:verticalIndicator
    visible: indicatorLineDirect === 3 || indicatorLineDirect === 4
    height: root.verticalIndicatorLength + 2
    width: 2
    anchors{
        top: indicatorLineDirect === 3 ? parent.top : tipsRectangle.bottom
        topMargin: indicatorLineDirect === 3 ? 1 : -1
        left: parent.left
        leftMargin: verticalIndicatorLeftMargin
    }
    color: "white";
}

Rectangle{
    id: horizontalIndicator
    visible: indicatorLineDirect === 1 || indicatorLineDirect === 2
    height: 2
    width: root.horizontalIndicatorLength
    anchors{
        top: parent.top
        topMargin: horizontalIndicatorTopMargin
        left: parent.left
        leftMargin: indicatorLineDirect === 1 ? 0 : tipsRectangle.width - 1
    }
    color: "white";
}
}



