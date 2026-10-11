import QtQuick 2.15
import QtQuick.Layouts 1.3
import Controls 1.0
import Config 1.0
import LightRectangle 1.0
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import FontModel 1.0
import FontItem 1.0
import FontCategory 1.0

/**
 * @author hongbin.shi
 * @desc 字体选择器
 * @create_date 2025-12-12
 */
Popup {
    id: fontPopup
    width: 256
    height: 424 //416
    padding: 0
    background: Rectangle {
        color: Colors.color_2F3032
        radius: 4

        // 阴影效果
        layer.enabled: true
        layer.effect: DropShadow {
            transparentBorder: true
            horizontalOffset: 0
            verticalOffset: 0
            radius: 10
            samples: 17
            color: Colors.color_000000_50
        }
    }


    FontModel {
       id: fontModel
    }
    property string curFontName: ""
    property string finishFontName: ""
    property bool curAllFontTab: true

    // 信号
    signal selectFontChange(string fontName, string realFamily, string filePath)

    Timer {
        id: initTimer
        interval: 200  // 短延时确保 UI 渲染完成
        onTriggered: {
            Qt.callLater(function() {
                var map = fontModel.getFontIndex(curFontName);
                if(map.listIndex >=0 && map.repeaterIndex >= 0){
                    scrollTo(map.listIndex, map.repeaterIndex);
                }
                else{
                    scrollTo(0, 0);
                }
            });
        }
    }

    // 打开时自动定位到已选择的字体
    onOpened: {
        initTimer.start();
    }
    onAboutToHide:{        
        // 重置所有分类为显示状态
        for (var i = 0; i < outerListView.count; i++) {
            var delegateItem = outerListView.itemAtIndex(i);
            if (delegateItem) {
                // 查找innerColumn（在delegate Column中）
                var innerCol = delegateItem.children[delegateItem.children.length - 1];
                if (innerCol && innerCol.objectName === "innerColumn") {
                    innerCol.visible = true;
                }
            }
        }
    }
    function scrollTo(listIndex, repeaterIndex) {

        Qt.callLater(function () {
            // 1 确保 delegate 已创建
            outerListView.positionViewAtIndex(listIndex, ListView.Beginning)

            const row = outerListView.itemAtIndex(listIndex)
            if (!row) {
                return
            }

            const child = row.repeater.itemAt(repeaterIndex)
            if (!child) {
                return
            }
            let bottomPos = outerListView.contentItem.height;
            // bottomPos上述方式计算有时不准，使用最后一个元素的位置作为参考点
            {
                const lastMap = fontModel.getLastIndex();
                const lastRow = outerListView.itemAtIndex(lastMap.listIndex);
                if(lastRow){
                    const lastItem = lastRow.repeater.itemAt(lastMap.repeaterIndex);
                    if(lastItem){
                        bottomPos = lastItem.mapToItem(outerListView.contentItem, 0, 0).y + lastItem.height;
                    }
                }
            }

            // 2 计算子元素在 ListView 中的 Y
            const pos = child.mapToItem(outerListView.contentItem, 0, 0)

            // 3 滚动 - 确保不会在下方留空白
            const targetY = pos.y
            const maxContentY = Math.max(0, bottomPos - outerListView.height)
            outerListView.contentY = Math.min(targetY, maxContentY)
        })
    }

    Connections {
        target: fontModel
        function onFontDownloadComplete(downloadFontName, realFamily, fontFilePath, bClose){
            if(downloadFontName === curFontName){
                fontPopup.selectFontChange(curFontName, realFamily, fontFilePath);  //发送信号给主界面
                fontModel.addRecentUse(downloadFontName);
                finishFontName = curFontName;
            }
        }
    }

    function getFontNameByRealFamily(realFamily) {
        var fontName = fontModel.getFontNameByRealFamily(realFamily);
        return fontName;
    }


    // 主布局
    ColumnLayout {
        anchors.fill: parent
        spacing: 16 //20
        // 全部和可商用 tbn
        RowLayout {
            width: parent.width; height: 24
            Layout.leftMargin: 12   // 设置左侧边距
            Layout.topMargin: 16    // 设置顶部边距
            spacing: 8
            visible: false
            //全部
            Rectangle {
                id: allBtn
                width: 48; height: 24;
                color: (curAllFontTab ? Colors.color_454649 : Colors.color_37383A)
                radius: 4
                Text {
                    text: qsTr("pccut_word_edit_font_all")
                    color: curAllFontTab ? Colors.color_EEEEEE : Colors.color_999999
                    font.pixelSize: 12
                    anchors.centerIn: parent
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked:{ curAllFontTab = true;}
                }
            }

            // Rectangle {
            //     id: commercialBtn
            //     width: 60; height: 24
            //     color: !curAllFontTab ? Colors.color_454649 : Colors.color_37383A
            //     radius: 4
            //     visible: false
            //     Text {
            //         text: "可商用"
            //         color: !curAllFontTab ? Colors.color_EEEEEE : Colors.color_999999
            //         font.pixelSize: 12
            //         anchors.centerIn: parent
            //     }
            //     MouseArea {
            //         anchors.fill: parent
            //         onClicked:{ curAllFontTab = false;}
            //     }
            // }
        }

        // 外层 ListView - 显示分类
        ListView {
            id: outerListView
            Layout.fillWidth: true;
            Layout.fillHeight: true;
            Layout.topMargin: 16    // 设置顶部边距
            model: fontModel
            clip: true
            cacheBuffer: 10000
            spacing: 20

            // 外层列表项委托
            delegate: Column {
                id: categoryDelegate
                width: outerListView.width //- 20
                spacing: 10
                property alias repeater : innerColumnRepeater
                //visible: (fontCount > 0 ? true : false)
                // 分类标题
                Rectangle {
                    width:  outerListView.width
                    height: 16; radius: 4;
                    anchors {
                        left: parent.left; leftMargin: 12
                    }

                    color: Colors.color_2F3032
                    Text {
                        id: categoryText
                        text: categoryName
                        width: Math.max(44, categoryText.contentWidth); //44;
                        height: 15;
                        font.pixelSize: 11;
                        color: Colors.color_666666
                        anchors {
                            left: parent.left;
                            top: parent.top; topMargin: 0.5
                        }
                    }
                    Image{
                        anchors{
                            top: parent.top;
                            left: categoryText.right; leftMargin: 4;
                        }
                        //expand and collapse
                        source:  innerColumn.visible ? "qrc:/icons/ic_fontselectcollapse.svg" : "qrc:/icons/ic_fontselectexpand.svg"
                        sourceSize: Qt.size(16, 16)
                    }
                    // 点击切换内层列表的显示/隐藏
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            innerColumn.visible = !innerColumn.visible
                        }
                    }
                }

                //内层用repeater
                Column {
                    id: innerColumn
                    objectName: "innerColumn"
                    width: parent.width //- 20
                    Repeater {
                        id: innerColumnRepeater
                        model: fontCategory.fonts
                        delegate: Rectangle {
                            width: outerListView.width -10 //248
                            height: 28
                            radius: 4
                            color: Colors.color_2F3032
                            // 下载进度
                            property real currentProgress: progress
                            // 内层项点击效果
                            MouseArea {
                                anchors.fill: parent; hoverEnabled: true
                                onClicked: {
                                    if(!systemFont && currentProgress <= 0){
                                        curFontName = fontName;
                                        //开始下载
                                        fontModel.download(fontName, true, true);
                                    }else{
                                        curFontName = fontName;
                                        finishFontName = fontName;
                                        fontPopup.selectFontChange(fontName, realFamily,  filePath);  //发送信号给主界面
                                        if(fontName.length > 0 && fontName !== qsTr("pccut_word_edit_font_typ_system")){
                                            fontModel.addRecentUse(fontName);   //持久化数据
                                        }

                                        fontPopup.close();
                                    }
                                }
                                //onEntered: parent.color = Colors.color_454649
                                //onExited: parent.color = Colors.color_2F3032
                                onEntered: {
                                    fontContent.color = Colors.color_454649
                                }
                                onExited: {
                                    fontContent.color = Colors.color_2F3032
                                }
                            }
                            Rectangle {
                                id: fontContent
                                width: parent.width - 8
                                height: 28
                                anchors{
                                    left: parent.left; leftMargin: 4
                                    top: parent.top;
                                }
                                color: Colors.color_2F3032
                                radius: 4
                            }


                            Image {
                                source: "qrc:/icons/ic_fontselect.svg"
                                width: 16; height: 16;
                                anchors{
                                    left: parent.left; leftMargin: 12;
                                    top: parent.top; topMargin: 6;
                                }
                                visible: fontName === finishFontName
                            }
                            // 字体名称
                            Text {
                                height: 15
                                anchors {
                                    left: parent.left; top: parent.top
                                    leftMargin: 40; topMargin: 6.5;
                                    right: parent.right; rightMargin: 64
                                }
                                anchors.verticalCenter: parent.verticalCenter
                                text: fontName.length === 0 ? qsTr("pccut_word_edit_font_typ_system") : fontName
                                font.pixelSize: fontName === "Zapfino" ? 6 : 11
                                font.family: fontName
                                color: Colors.color_EEEEEE
                                elide: Text.ElideRight
                                visible: systemFont
                            }
                            //预设字体image
                            ShaderEffectSource {
                                width: 64
                                height: 16
                                sourceItem: src
                                sourceRect: Qt.rect(0, src.width*3/8, src.width, src.width/4)
                                live: true
                                anchors.verticalCenter: parent.verticalCenter
                                anchors {
                                    left: parent.left; top: parent.top
                                    leftMargin: 32; topMargin: 6 //6.5;
                                }
                                Image {
                                    id: src
                                    source: iconUrl
                                    visible: false
                                }
                                visible: !systemFont
                            }

                            //下载
                            Image{
                                id: downloadIcon
                                width: 16; height: 16;
                                anchors{
                                    top: parent.top; right: parent.right
                                    topMargin: 6; rightMargin: 44 //48;
                                }
                                source:  "qrc:/icons/ic_fontdownload.svg"
                                sourceSize: Qt.size(16, 16)
                                visible: (!systemFont  && currentProgress < 0) ? true : false
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        //开始下载
                                        curFontName = fontName;
                                        fontModel.download(fontName, true, false);
                                    }
                                }
                            }

                            Image {
                                id: rotatingImage
                                width: 16; height: 16
                                source: "qrc:/icons/ic_download_loading.png"
                                anchors.centerIn: downloadIcon
                                visible: {

                                    return (!systemFont && currentProgress >= 0 && currentProgress < 1)
                                }
                                smooth: true
                                RotationAnimation on rotation {
                                    loops: Animation.Infinite
                                    running: rotatingImage.visible
                                    from: 0
                                    to: 360
                                    duration: 1000 // 持续时间为1秒
                                }
                            }

                            //收藏
                            Image{
                                width: 16; height: 16;
                                anchors{
                                    top: parent.top; right: parent.right
                                    topMargin: 6; rightMargin: 16 //20
                                }
                                source:  collected ? "qrc:/icons/icon_collect_red.svg" : "qrc:/icons/icon_collect.svg"
                                sourceSize: Qt.size(16, 16)
                                visible: true

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if(!collected){
                                            fontModel.addCollect(fontName);
                                        }else{
                                            fontModel.removeCollect(fontName);
                                        }


                                    }
                                }
                            }
                        }
                    }
                }

            }

            // 滚动条
            ScrollBar.vertical: ScrollBar {
                id: verticalBar
                // 基本属性
                policy: ScrollBar.AsNeeded
                width: 10
                anchors {
                    right: parent.right
                    rightMargin: 4
                }
                contentItem: Rectangle {
                    id: handleItem
                    color: Colors.color_56575B_50
                    radius: 4
                    width: 6
                    anchors.right: parent.right
                }
            }
        }

        Item{
            height: 1
        }
    }

}

