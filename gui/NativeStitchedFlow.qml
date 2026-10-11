// Independent subset composition under13dc8440/review695. No vendor Main/services.
import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtMultimedia
import NativeStitchedFlow 1.0
import RecoveredFlowControls 1.0
import RecoveredFlowPalette 1.0

ApplicationWindow {
    id: window
    objectName: "nativeWindow"
    visible: true
    width: 1100; height: 820
    minimumWidth: 780; minimumHeight: 640
    title: "Native stitched view · experimental"
    color: Colors.base_color_main_background
    onClosing: function(close) { close.accepted = Flow.requestClose() }
    property var presenter: null

    Component {
        id: presenterFactory
        Item {
            id: presentation
            required property string jobToken
            anchors.fill: parent
            VideoOutput { id: video; objectName: "outputVideo"; anchors.fill: parent; fillMode: VideoOutput.PreserveAspectFit }
            AudioOutput { id: audio; muted: true }
            MediaPlayer { id: player; videoOutput: video; audioOutput: audio }
            Component.onCompleted: Flow.attachPresenter(player, video.videoSink, audio, jobToken)
            Component.onDestruction: { player.stop(); player.source = "" }
        }
    }
    Connections {
        target: Flow
        function onClearPresenter() { if (window.presenter) { window.presenter.destroy(); window.presenter = null } }
        function onVerifyOutput(source, token) {
            if (window.presenter) window.presenter.destroy()
            window.presenter = presenterFactory.createObject(videoContainer, { "jobToken": token })
        }
    }
    FileDialog {
        id: inputDialog; title: "Choose an already stitched input"
        fileMode: FileDialog.OpenFile
        onAccepted: Flow.selectInput(selectedFile)
    }
    FileDialog {
        id: outputDialog; title: "Choose a new MP4 output"; fileMode: FileDialog.SaveFile
        nameFilters: ["MP4 video (*.mp4)"]; defaultSuffix: "mp4"
        onAccepted: Flow.chooseOutput(selectedFile)
    }
    component ActionButton: LightTextButton {
        Layout.preferredHeight: 36
        normalColor: ColorsConfig.color_FFFFFF_000000
        hoverColor: ColorsConfig.color_FFFFFF_000000
        pressedColor: ColorsConfig.color_FFFFFF_000000
        disableColor: "#777777"
        backgroundNormalColor: ColorsConfig.color_F22443_4DFFC9
        backgroundHoverColor: ColorsConfig.color_F44C65_6DFFD3
        backgroundPressedColor: ColorsConfig.color_F44C65_4DFFC9
        backgroundDisableColor: "#37383A"
    }
    ColumnLayout {
        anchors.fill: parent; anchors.margins: 20; spacing: 12
        Label { text: "Already stitched input → default flat view"; font.pixelSize: 23; color: "white" }
        Label { text: "Experimental native composition. Declare stitched geometry yourself; metadata is diagnostic only."; color: "#cccccc"; wrapMode: Text.Wrap; Layout.fillWidth: true }
        RowLayout {
            ImageButton {
                objectName: "selectIcon"; Layout.preferredWidth: 28; Layout.preferredHeight: 28
                enabled: !Flow.busy
                normalImage: "qrc:/app_qrc/icons/icon_create_project.svg"
                hoveredImage: normalImage; pushedImage: normalImage; disabledImage: normalImage
                onClicked: inputDialog.open()
            }
            ActionButton { objectName: "selectInputButton"; text: "Select input"; disabled: Flow.busy; onClicked: inputDialog.open() }
            Label { text: Flow.inputUrl.toString(); color: "white"; elide: Text.ElideMiddle; Layout.fillWidth: true }
        }
        RowLayout {
            CheckBox {
                objectName: "stitchedDeclaration"; text: "I declare this input is already stitched equirectangular media"
                enabled: Flow.inputReady && !Flow.busy; checked: Flow.stitchedDeclared
                onClicked: Flow.stitchedDeclared = checked
            }
            ActionButton { objectName: "metadataButton"; text: "Inspect metadata"; disabled: !Flow.inputReady || Flow.busy; onClicked: Flow.inspectDirectMetadata() }
        }
        RowLayout {
            ActionButton { objectName: "outputButton"; text: "Choose new output"; disabled: !Flow.inputReady || Flow.busy; onClicked: outputDialog.open() }
            Label { text: Flow.outputUrl.toString(); color: "white"; elide: Text.ElideMiddle; Layout.fillWidth: true }
            ActionButton { objectName: "renderButton"; text: "Reframe 1920×1080"; disabled: !Flow.stitchedDeclared || Flow.outputUrl.toString() === "" || Flow.busy; onClicked: Flow.exportDefaultView() }
        }
        Rectangle {
            id: videoContainer; objectName: "videoContainer"
            Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumHeight: 200
            color: "#151515"; radius: RadiusConfig.radius_6_88
            Label { anchors.centerIn: parent; visible: !Flow.previewReady; text: Flow.phase === "checking" ? "Decoding the actual output…" : "Output-only preview"; color: "#aaaaaa" }
        }
        RowLayout {
            Image { source: "qrc:/icons/icon_loading.png"; visible: Flow.busy; sourceSize: Qt.size(20,20); Layout.preferredWidth: 20; Layout.preferredHeight: 20 }
            Label { text: Flow.phase + " · " + Flow.previewState; color: "white"; Layout.fillWidth: true }
            ActionButton { objectName: "playButton"; text: Flow.previewState === "playing" ? "Pause" : "Play"; disabled: !Flow.outputReady || !Flow.previewReady; onClicked: Flow.playPause() }
            ActionButton { objectName: "folderButton"; text: "Open output folder"; disabled: !Flow.outputCreated; onClicked: Flow.openOutputFolder() }
        }
        Label { text: Flow.failureText; color: "#ff8a8a"; visible: text.length > 0; Layout.fillWidth: true; wrapMode: Text.Wrap }
        Label { text: Flow.metadataOutcome + (Flow.jobId ? " · job " + Flow.jobId : ""); color: "#bbbbbb"; Layout.fillWidth: true; elide: Text.ElideMiddle }
        RowLayout {
            ScrollView { Layout.fillWidth: true; Layout.preferredHeight: 120; TextArea { objectName: "stdoutArea"; readOnly: true; text: Flow.metadataText; font.family: "monospace"; wrapMode: TextEdit.Wrap } }
            ScrollView { Layout.fillWidth: true; Layout.preferredHeight: 120; TextArea { objectName: "stderrArea"; readOnly: true; text: Flow.diagnosticText; font.family: "monospace"; wrapMode: TextEdit.Wrap } }
        }
    }
}
