import QtQuick 2.15
import QtQuick.Layouts 1.3
import Config 1.0
import Controls 1.0


Rectangle {
    id: root

    property bool isDisabled: false
    property string disableReason: ""
    signal buttonClicked()

    height: 32
    z: 100
    color: Colors.color_252627

    onVisibleChanged: {
        if (visible) {
            eventTracker.trackEvent("pccut_auto_edit_entrance_show", {"page_source": "material_lib"})
        }
    }

    RowLayout {
        anchors {
            fill: parent
            leftMargin: 12
            rightMargin: 12
        }
        spacing: 8
        z: 100

        TooltipText {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            text: qsTr("pccut_roughcut_bar_tips")
            color: Colors.color_999999
            font.pixelSize: 12
            elide: Text.ElideRight
        }

        Item {
            id: roughCutButton
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: 56
            height: 20
            opacity: root.isDisabled ? 0.2 : 1.0

            Image {
                anchors.fill: parent
                source: (!root.isDisabled && roughCutBtnMouse.containsMouse)
                    ? "qrc:/icons/roughcut/roughcut_material_hover_bg.svg"
                    : "qrc:/icons/roughcut/roughcut_material_default_bg.svg"
                sourceSize: Qt.size(56, 20)
            }

            Row {
                id: roughCutBtnContent
                anchors.centerIn: parent
                spacing: 4
                width: Math.min(implicitWidth, roughCutButton.width - 8)
                clip: true

                Text {
                    id: roughCutBtnText
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, roughCutButton.width - 8)
                    text: qsTr("pccut_roughcut_title")
                    color: "#EEEEEE"
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }
            }

            MouseArea {
                id: roughCutBtnMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: root.isDisabled ? Qt.ArrowCursor : Qt.PointingHandCursor
                onPressed: function(mouse) {
                    mouse.accepted = true;
                    if (root.isDisabled) return;
                    root.buttonClicked();
                }
            }

            LightToolTip {
                visible: roughCutBtnMouse.containsMouse && (root.isDisabled || roughCutBtnText.truncated)
                tip: root.isDisabled ? root.disableReason : qsTr("pccut_roughcut_title")
            }
        }
    }
}
