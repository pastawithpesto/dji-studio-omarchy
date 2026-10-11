import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15
import Qt.labs.platform 1.1
import MaterialListViewModel 1.0

Window {
    id: draftRecoverWindow
    property string projectFolder
    width: 650
    height: 350
    visible: true

    ToolTip {
        id: toast
        visible: false
        x: (parent.width - toast.width) / 2
        y: (parent.height - toast.height) / 2
        delay: 500
        text: ""

        // 定时器：3秒后自动隐藏
        Timer {
            id: autoCloseTimer
            interval: 3000
            onTriggered: toast.visible = false
        }

        onVisibleChanged: {
            if(visible){
                autoCloseTimer.start();
            }
        }
    }

    // 主布局（垂直排列）
    Column {
        anchors.fill: parent
        spacing: 0

        // 表头
        Rectangle {
            id: header
            width: parent.width
            height: 40
            color: "#f0f0f0"
            border.color: "#d0d0d0"

            Row {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 10

                Text {
                    width: 180
                    text: "素材名称"
                    font.bold: true
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: 14
                    color: "#333"
                }

                Text {
                    width: 100
                    text: "类型"
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: 14
                    color: "#333"
                }

                Text {
                    width: 100
                    text: "时长(s)"
                    font.bold: true
                    horizontalAlignment: Text.AlignRight
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: 14
                    color: "#333"
                }

                Text {
                    width: 100
                    text: "使用状态(轨道)"
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: 14
                    color: "#333"
                }

                Text {
                    width: 100
                    text: "操作"
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: 14
                    color: "#333"
                }
            }
        }

        ListView {
            id: listView
            width: parent.width
            height: parent.height - header.height - footer.height
            model: materialModel
            spacing: 5
            clip: true

            property int itemWidth: {
                const pathWidth = 180;
                const typeWidth = 100;
                const durationWidth = 100;
                const isUsed = 100;
                const buttonWidth = 100;
                return pathWidth + typeWidth + durationWidth + isUsed + buttonWidth + 30 + 20;
            }

            delegate: Rectangle {
                id:delegateItem
                width: listView.width
                height: 60
                color: index % 2 === 0 ? "#f5f5f5" : "#ffffff"
                border.color: "#e0e0e0"

                Row {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10

                    Text {
                        id: videoName
                        width: 180
                        text: model.path
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: 14
                        color: "#333"

                        ToolTip {
                            id: toolTip
                            visible: mouseArea.containsMouse && (videoName.truncated)
                            delay: 500
                            text: model.path
                        }

                        MouseArea {
                            id: mouseArea
                            anchors.fill: videoName
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                        }
                    }

                    Text {
                        width: 100
                        text: model.type
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: 14
                        color: "#555"
                    }

                    Text {
                        width: 100
                        text: covertDurationToTime(model.duration)
                        horizontalAlignment: Text.AlignRight
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: 14
                        color: "#555"

                        function covertDurationToTime(duration) {
                            var length_s = duration / 1000 / 30;

                            var hours = Math.floor(length_s / 3600);
                            var remainingSeconds = length_s % 3600;
                            var minutes = Math.floor(remainingSeconds / 60);
                            var seconds = Math.floor(remainingSeconds % 60);

                            // 格式化为两位数显示
                            var hoursStr = hours.toString().padStart(2, '0');
                            var minutesStr = minutes.toString().padStart(2, '0');
                            var secondsStr = seconds.toString().padStart(2, '0');

                            return hoursStr + ":" + minutesStr + ":" + secondsStr;
                        }
                    }

                    Text {
                        width: 100
                        text: model.isUsed ? "✓" : "✗"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: 14
                        color: model.isUsed ? "green" : "red"
                        font.bold: true
                    }

                    FileDialog {
                        id: selectReplaceVideo
                        fileMode: FileDialog.OpenFile
                        onAccepted: {
                            // 获取选中的文件路径
                            var filePath = files[0].toString();
                            // 移除 "file://" 前缀（如果存在）
                            filePath = filePath.replace("file://", "");
                            // 提取所在文件夹路径
                            var res = materialModel.replaceVideo(model.md5, filePath);
                            if(!res){
                                toast.visible = true;
                                toast.text = "替换失败";
                            }else{
                                replaceBtn.text = "已替换"
                            }
                        }
                    }

                    Button {
                        id: replaceBtn
                        width: 100
                        height: 30
                        text: "替换素材"
                        onClicked: {
                            selectReplaceVideo.open();
                        }
                    }
                }
            }

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
            }
        }

        // 底部按钮区域
        Rectangle {
            id: footer
            width: parent.width
            height: 60
            color: "#f5f5f5"
            border.color: "#e0e0e0"

            Button {
                anchors.centerIn: parent
                width: 120
                height: 40
                text: "打开工程"
                font.pixelSize: 14
                onClicked: {
                    materialModel.openProject();
                    draftRecoverWindow.close();

                }
            }
        }
    }

    MaterialListViewModel {
        id: materialModel
        draftPath: draftRecoverWindow.projectFolder
    }
}
