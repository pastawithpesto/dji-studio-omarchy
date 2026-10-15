import QtQml
import BusinessLog 1.0
QtObject {
    id: root
    property Timer deadline: Timer { interval: 5000; running: true; onTriggered: Qt.exit(19) }
    Component.onCompleted: Qt.callLater(function() {
        if (BusinessLog.Stream.UNKNOWN !== -1) { console.error("Stream.UNKNOWN"); Qt.exit(11); return; }
        if (BusinessLog.Stream.APP_LAUNCH !== 1) { console.error("Stream.APP_LAUNCH"); Qt.exit(11); return; }
        if (BusinessLog.Stream.DEVICE_CONNECTION !== 2) { console.error("Stream.DEVICE_CONNECTION"); Qt.exit(11); return; }
        if (BusinessLog.Stream.PLAYER_PREVIEW !== 3) { console.error("Stream.PLAYER_PREVIEW"); Qt.exit(11); return; }
        if (BusinessLog.Stream.DRAFT_SAVE !== 4) { console.error("Stream.DRAFT_SAVE"); Qt.exit(11); return; }
        if (BusinessLog.Stream.PROJECT_OPEN !== 5) { console.error("Stream.PROJECT_OPEN"); Qt.exit(11); return; }
        if (BusinessLog.Stream.DRAFT_COVER_UPDATE !== 6) { console.error("Stream.DRAFT_COVER_UPDATE"); Qt.exit(11); return; }
        if (BusinessLog.Events.UNKNOWN !== -1) { console.error("Events.UNKNOWN"); Qt.exit(11); return; }
        if (BusinessLog.Events.STREAM_START !== 1) { console.error("Events.STREAM_START"); Qt.exit(11); return; }
        if (BusinessLog.Events.MAIN_START !== 2) { console.error("Events.MAIN_START"); Qt.exit(11); return; }
        if (BusinessLog.Events.PRE_CONFIGURE !== 3) { console.error("Events.PRE_CONFIGURE"); Qt.exit(11); return; }
        if (BusinessLog.Events.INIT_APP !== 4) { console.error("Events.INIT_APP"); Qt.exit(11); return; }
        if (BusinessLog.Events.INIT_ENGINE !== 5) { console.error("Events.INIT_ENGINE"); Qt.exit(11); return; }
        if (BusinessLog.Events.INIT_SENTRY !== 6) { console.error("Events.INIT_SENTRY"); Qt.exit(11); return; }
        if (BusinessLog.Events.CONFIGURE_MLT !== 7) { console.error("Events.CONFIGURE_MLT"); Qt.exit(11); return; }
        if (BusinessLog.Events.INIT_EVENT_TRACKER !== 8) { console.error("Events.INIT_EVENT_TRACKER"); Qt.exit(11); return; }
        if (BusinessLog.Events.CONFIGURE_PROJECT !== 9) { console.error("Events.CONFIGURE_PROJECT"); Qt.exit(11); return; }
        if (BusinessLog.Events.REGISTER_META_TYPE !== 10) { console.error("Events.REGISTER_META_TYPE"); Qt.exit(11); return; }
        if (BusinessLog.Events.LOAD_EDITOR_QML !== 11) { console.error("Events.LOAD_EDITOR_QML"); Qt.exit(11); return; }
        if (BusinessLog.Events.EDITOR_QML_LOAD_COMPLETED !== 12) { console.error("Events.EDITOR_QML_LOAD_COMPLETED"); Qt.exit(11); return; }
        if (BusinessLog.Events.APP_WINDOW_SHOWED !== 13) { console.error("Events.APP_WINDOW_SHOWED"); Qt.exit(11); return; }
        if (BusinessLog.Events.PROJECT_FILE_PREPARED !== 14) { console.error("Events.PROJECT_FILE_PREPARED"); Qt.exit(11); return; }
        if (BusinessLog.Events.PROJECT_DRAMA_PREPARED !== 15) { console.error("Events.PROJECT_DRAMA_PREPARED"); Qt.exit(11); return; }
        if (BusinessLog.Events.PROJECT_VERIFIED !== 16) { console.error("Events.PROJECT_VERIFIED"); Qt.exit(11); return; }
        if (BusinessLog.Events.PROJECT_DRAMA_READ !== 17) { console.error("Events.PROJECT_DRAMA_READ"); Qt.exit(11); return; }
        if (BusinessLog.Events.PROJECT_RESOURCE_READY !== 18) { console.error("Events.PROJECT_RESOURCE_READY"); Qt.exit(11); return; }
        if (BusinessLog.Events.PROJECT_ACTIVATED !== 19) { console.error("Events.PROJECT_ACTIVATED"); Qt.exit(11); return; }
        if (BusinessLog.Events.STREAM_END !== 20) { console.error("Events.STREAM_END"); Qt.exit(11); return; }
        if (BusinessLog.Events.STREAM_TIMEOUT !== 21) { console.error("Events.STREAM_TIMEOUT"); Qt.exit(11); return; }
        if (BusinessLog.Events.STREAM_CANCEL !== 22) { console.error("Events.STREAM_CANCEL"); Qt.exit(11); return; }
        if (typeof BusinessLog.Stream["0"] !== "undefined" ||
            typeof BusinessLog.Events["0"] !== "undefined") { Qt.exit(12); return; }
        try {
            Qt.createQmlObject("import BusinessLog 1.0\nBusinessLog {}", root, "uncreatable.qml");
            Qt.exit(13); return;
        } catch (error) {
            if (!error.qmlErrors || error.qmlErrors.length !== 1 ||
                error.qmlErrors[0].message !== "enums only") { console.error(error); Qt.exit(14); return; }
        }
        try {
            Qt.createQmlObject("import QtQml\nimport BusinessLog 2.0\nQtObject {}", root, "wrong-version.qml");
            Qt.exit(15); return;
        } catch (error) {
            if (String(error).indexOf("version 2.0 is not installed") < 0) { console.error(error); Qt.exit(16); return; }
        }
        Qt.exit(0);
    })
}
