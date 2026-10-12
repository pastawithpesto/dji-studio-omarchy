//! A separate executable keeps all Qt calls on one process main thread.
use cxx_qt_lib::{QByteArray, QGuiApplication, QQmlApplicationEngine, QUrl};
use std::sync::{
    Arc,
    atomic::{AtomicBool, Ordering},
};

fn main() {
    let mut app = QGuiApplication::new();
    window_position_detector_qt::register_types();
    let mut engine = QQmlApplicationEngine::new();
    let created = Arc::new(AtomicBool::new(false));
    let seen = Arc::clone(&created);
    let _connection = engine.pin_mut().on_object_created(move |_, object, _| {
        seen.store(!object.is_null(), Ordering::Release);
    });
    let qml = QByteArray::from(
        r#"import QtQuick
import QtQuick.Window
import WindowPositionDetector 1.0
Window {
    id: window
    visible: false
    width: 40
    height: 20
    x: 10
    y: 20
    WindowPositionDetector { id: detector }
    Timer { interval: 5000; running: true; onTriggered: Qt.exit(17) }
    Component.onCompleted: Qt.callLater(function() {
        if (typeof detector.isWindowCompletelyOnScreen !== "function" ||
            typeof detector.resetWindowToBestScreen !== "function") { Qt.exit(11); return; }
        if (detector.isWindowCompletelyOnScreen(null) !== false) { Qt.exit(12); return; }
        detector.resetWindowToBestScreen(null);
        if (detector.isWindowCompletelyOnScreen(window) !== true) { Qt.exit(13); return; }
        window.x = 100000;
        window.y = 100000;
        if (detector.isWindowCompletelyOnScreen(window) !== false) { Qt.exit(14); return; }
        detector.resetWindowToBestScreen(window);
        if (detector.isWindowCompletelyOnScreen(window) !== true) { Qt.exit(15); return; }
        if (window.width !== 40 || window.height !== 20) { Qt.exit(16); return; }
        Qt.exit(0);
    })
}"#,
    );
    engine
        .pin_mut()
        .load_data(&qml, &QUrl::from("qrc:/window-position-test.qml"));
    assert!(
        created.load(Ordering::Acquire),
        "original type import or QML creation failed"
    );
    let code = app.pin_mut().exec();
    assert_eq!(code, 0, "QML registration/native method check failed");
    println!("WindowPositionDetector 1.0 registration and QWindow calls passed");
}
