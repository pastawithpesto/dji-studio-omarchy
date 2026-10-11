import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts 1.3

/**
 * @author robert.guo
 * @desc 智能推荐目标控件
 * @create_date 2025-09-13
 */
Item {
    id: root
    property string imageSource: ""
    property int imageWidth: 50
    property int imageHeight: 50

    property int parentWidth: 0
    property int parentHeight: 0

    property bool showAnimation: true

    signal trackRectChanged(real x, real y, real width, real height)

    ListModel {
        id: recommanedRectModel
    }

    function trackingRecommandListChanged(rectList) {
        clearData()
        for (var i = 0; i < rectList.length; i++) {
            if (rectList[i] === null || rectList[i] === undefined) {
                continue
            }
            recommanedRectModel.append({"x": rectList[i].x, "y": rectList[i].y - rectList[i].height / 10, "width": rectList[i].width, "height": rectList[i].height})
        }
    }

    function clearData() {
        recommanedRectModel.clear()
    }

    Repeater {
        id: recommandRepeater
        model: recommanedRectModel

        delegate:  AnimatedImage {
            id: currentImage
            source: root.imageSource
            width: showAnimation ? root.imageWidth : 0
            height: showAnimation ? root.imageHeight : 0
            fillMode: Image.PreserveAspectFit

            Component.onCompleted: {
                if (root.parentWidth > 0 && root.parentHeight > 0) {
                    x = recommanedRectModel.get(index).x * root.parentWidth - width/2
                    y = recommanedRectModel.get(index).y * root.parentHeight - height/2
                }
            }

            MouseArea {
                anchors.fill: parent
                property point dragOffset: Qt.point(0, 0)

                onClicked: {
                    trackRectChanged(recommanedRectModel.get(index).x, recommanedRectModel.get(index).y, recommanedRectModel.get(index).width, recommanedRectModel.get(index).height)
                    clearData()
                }
            }
        }
    }
}
