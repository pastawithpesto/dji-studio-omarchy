import QtQuick 2.15
import QtQuick.Shapes 1.15
import Controls 1.0
import Config 1.0

Item {
    id: root

    property string buttonText: ""
    property string loadingText: ""
    property bool isLoading: false
    property color loadingColor: "#EEEEEE"

    signal clicked()

    implicitWidth: isLoading ? loadingRow.width : btnRow.width
    implicitHeight: 16

    // --- 正常按钮 ---
    Row {
        id: btnRow
        spacing: 2
        visible: !root.isLoading
        anchors.centerIn: parent

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.buttonText
            font.pixelSize: 12
            font.weight: Font.Medium
            lineHeight: 16
            lineHeightMode: Text.FixedHeight
            color: Colors.color_FF7B00
        }

        Item {
            width: 16
            height: 16
            anchors.verticalCenter: parent.verticalCenter

            Shape {
                anchors.centerIn: parent
                width: 4
                height: 8

                ShapePath {
                    strokeColor: Colors.color_FF7B00
                    strokeWidth: 1
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin
                    startX: 0; startY: 0
                    PathLine { x: 4; y: 4 }
                    PathLine { x: 0; y: 8 }
                }
            }
        }
    }

    // --- 加载状态行 ---
    Row {
        id: loadingRow
        spacing: 8
        visible: root.isLoading
        anchors.centerIn: parent

        Item {
            width: 16
            height: 16
            anchors.verticalCenter: parent.verticalCenter

            Canvas {
                id: spinnerCanvas
                anchors.fill: parent
                property real spinAngle: 0

                onPaint: {
                    var ctx = getContext("2d");
                    var cx = width / 2, cy = height / 2;
                    var r = Math.min(width, height) / 2 - 1.5;
                    ctx.clearRect(0, 0, width, height);
                    ctx.lineCap = "round";
                    ctx.lineWidth = 1.5;
                    for (var i = 0; i < 360; i += 3) {
                        var opacity = (i / 360) * 0.9;
                        ctx.strokeStyle = Qt.rgba(root.loadingColor.r, root.loadingColor.g, root.loadingColor.b, opacity);
                        var a1 = (spinAngle + i) * Math.PI / 180;
                        var a2 = (spinAngle + i + 3) * Math.PI / 180;
                        ctx.beginPath();
                        ctx.arc(cx, cy, r, a1, a2);
                        ctx.stroke();
                    }
                }

                NumberAnimation on spinAngle {
                    from: 0; to: 360
                    duration: 1000
                    running: loadingRow.visible
                    loops: Animation.Infinite
                }

                onSpinAngleChanged: requestPaint()
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.loadingText
            font.pixelSize: 12
            font.weight: Font.Medium
            lineHeight: 16
            lineHeightMode: Text.FixedHeight
            color: root.loadingColor
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: !root.isLoading
        hoverEnabled: true
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }
}
