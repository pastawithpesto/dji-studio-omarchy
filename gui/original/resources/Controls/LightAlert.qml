import QtQuick 2.15
import QtQuick.Controls
import Config 1.0
import Controls 1.0
import Qt5Compat.GraphicalEffects
import app_qrc 1.0

Popup {
    // 点击【取消】的信号
    signal cancelSignal
    // 点击【确定】的信号
    signal confirmBtnSignal

    // 主标题
    property string title: ""
    // 副标题
    property string subTitle: ""

    // 取消按钮
    property string cancelText: qsTr("pccut_draft_delete_popup_cancel")
    // 确定按钮
    property string confirmText: qsTr("pccut_project_modify_yes")

    // 确定按钮的背景色
    property color confirmBackgroundColor: Colors.color_D8D8D8_20
    // 确定按钮的字体颜色
    property color confirmTextColor: ColorsConfig.color_brand

    parent: Overlay.overlay
    width: parent.width
    height: parent.height
    closePolicy: Popup.CloseOnEscape
    dim: false
    modal: true
    z: Infinity

    background: Rectangle {
        color: Colors.color_141414
        opacity: 0.5
    }

    contentItem: Item {
        anchors.fill: parent
        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        Rectangle {
            anchors {
                centerIn: parent
            }

            width: 270
            height: sureBtn.y + sureBtn.height + 16
            radius: 12
            color: Colors.color_333333
            border {
                width: 0.5
                color: Colors.color_FFFFFF_20
            }

            // 阴影
            layer.enabled: true
            layer.effect: DropShadow {
                horizontalOffset: 0
                verticalOffset: 0
                radius: 10
                color: Colors.color_000000_30
            }

            // 主标题
            Text {
                id: titleView
                anchors {
                    left: parent.left
                    leftMargin: 20
                    top: parent.top
                    topMargin: CommonUtils.isEmptyStr(subTitle) ? 24 : 20
                    right: parent.right
                    rightMargin: 20
                }
                text: title
                font {
                    pixelSize: 14
                    weight: Font.DemiBold
                }
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                color: Colors.color_EEEEEE
            }

            // 副标题
            Text {
                id: subTitleView
                anchors {
                    left: parent.left
                    leftMargin: 16
                    top: titleView.bottom
                    topMargin: 16
                    right: parent.right
                    rightMargin: 16
                }

                text: subTitle
                font {
                    pixelSize: 11
                    weight: Font.Medium
                }
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                color: Colors.color_999999
            }

            // 取消按钮
            Button {
                id: cancelBtn
                anchors {
                    right: parent.horizontalCenter
                    rightMargin: 16
                    top: CommonUtils.isEmptyStr(subTitle) ? titleView.bottom : subTitleView.bottom
                    topMargin: CommonUtils.isEmptyStr(subTitle) ? 24 : 16
                }
                height: 26
                width: 84
                background: Rectangle {
                    radius: 6
                    color: Colors.color_D8D8D8_20
                }

                contentItem: Text {
                    anchors.centerIn: parent
                    height: 17
                    text: cancelText
                    font {
                        pixelSize: 12
                        weight: Font.DemiBold
                    }
                    color: Colors.color_FFFFFF
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: {
                    cancelSignal();
                    close();
                }
            }

            // 确定按钮
            Button {
                id: sureBtn
                objectName: actionableItemName.confirm
                anchors {
                    left: parent.horizontalCenter
                    leftMargin: 16
                    top: CommonUtils.isEmptyStr(subTitle) ? titleView.bottom : subTitleView.bottom
                    topMargin: CommonUtils.isEmptyStr(subTitle) ? 24 : 16
                }
                height: 26
                width: 84
                background: Rectangle {
                    radius: 6
                    color: confirmBackgroundColor
                }

                contentItem: Text {
                    anchors.centerIn: parent
                    height: 17
                    text: confirmText
                    font {
                        pixelSize: 12
                        weight: Font.DemiBold
                    }
                    color: confirmTextColor
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: {
                    confirmBtnSignal();
                    close();
                }
            }
        }
    }

    // open后，屏蔽不让下面的窗口响应
    onOpened: {
        content.enabled = false;
    }

    onClosed: {
        content.enabled = true;
    }

    Component.onDestruction: {
        if (opened) {
            close();
        }
    }
}
