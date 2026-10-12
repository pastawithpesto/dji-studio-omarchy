use cxx_qt_lib::{QByteArray, QGuiApplication, QQmlApplicationEngine, QString, QUrl};
use std::sync::{
    Arc,
    atomic::{AtomicBool, Ordering},
};

fn main() {
    // The main thread owns the application and all Qt objects.
    let mut app = QGuiApplication::new();
    assert!(!app.is_null());
    original_qml_host::initialize_resources();
    let mut engine = QQmlApplicationEngine::new();
    engine.pin_mut().add_import_path(&QString::from("qrc:/"));
    let created = Arc::new(AtomicBool::new(false));
    let seen = Arc::clone(&created);
    let _connection = engine.pin_mut().on_object_created(move |_, object, _| {
        seen.store(!object.is_null(), Ordering::Release);
    });
    // Config/qmldir registers this original file as a 1.0 singleton.
    // Its property literals and function body supply the test expectations.
    engine.pin_mut().load_data(
        &QByteArray::from(
            &br#"
import QtQuick
import Config 1.0
Item {
    id: root
    property bool preservedValues:
        TransitionConstants.zIndexTransition === 10 &&
        TransitionConstants.zIndexClipArea === 30 &&
        TransitionConstants.clipAreaWidth === 5 &&
        TransitionConstants.itemGap === 1.0 &&
        TransitionConstants.minTransitionWidth === 5.0 &&
        TransitionConstants.defaultFps === 30 &&
        TransitionConstants.timebase === 30000 &&
        TransitionConstants.cursorCutLeft === ":/icons/ic_cutleft.svg" &&
        TransitionConstants.cursorCutRight === ":/icons/ic_cutright.svg" &&
        TransitionConstants.cursorSize === 24 &&
        TransitionConstants.transitionIconPath === "qrc:/icons/transition/icon_transition.svg" &&
        TransitionConstants.transitionIconSize === 16 &&
        TransitionConstants.oneFrameDuration(60) === 500 &&
        TransitionConstants.oneFrameDuration(0) === 1000
    Timer {
        interval: 1
        running: true
        onTriggered: Qt.exit(root.preservedValues ? 0 : 1)
    }
}
"#[..],
        ),
        &QUrl::from("qrc:/host-singleton-test.qml"),
    );
    assert!(
        created.load(Ordering::Acquire),
        "original Config singleton import did not resolve"
    );
    assert_eq!(app.pin_mut().exec(), 0, "original singleton values changed");
    created.store(false, Ordering::Release);
    engine.pin_mut().load_data(
        &QByteArray::from(&b"import QtQuick\nimport Config 1.0\nQtObject { property color originalColor: Colors.transparent }"[..]),
        &QUrl::from("qrc:/host-import-test.qml"),
    );
    assert!(
        created.load(Ordering::Acquire),
        "original Config import did not resolve"
    );
    engine
        .pin_mut()
        .load(&QUrl::from("qrc:/missing-host-test.qml"));
    assert!(
        !created.load(Ordering::Acquire),
        "missing resource did not report failure"
    );
    engine.pin_mut().load_data(
        &QByteArray::from(&b"import QtQuick\nItem { Timer { interval: 1; running: true; onTriggered: Qt.quit() } }"[..]),
        &QUrl::from("qrc:/host-lifecycle-test.qml"),
    );
    assert!(created.load(Ordering::Acquire));
    assert_eq!(app.pin_mut().exec(), 0);
    println!(
        "PASS: original Config singleton values, Config import, load failure, Qt event loop exit"
    );
}
