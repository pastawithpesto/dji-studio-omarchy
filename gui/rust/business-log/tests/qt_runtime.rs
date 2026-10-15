//! A separate executable keeps Qt operations on the process main thread.
use business_log_qt::{Events, Stream};
use cxx_qt_lib::{QByteArray, QCoreApplication, QQmlApplicationEngine, QUrl};
use std::sync::{
    Arc,
    atomic::{AtomicBool, Ordering},
};

fn main() {
    assert_eq!(std::mem::size_of::<Stream>(), 4);
    assert_eq!(std::mem::align_of::<Stream>(), 4);
    assert_eq!(std::mem::size_of::<Events>(), 4);
    assert_eq!(std::mem::align_of::<Events>(), 4);
    let mut app = QCoreApplication::new();
    business_log_qt::register_types().expect("register BusinessLog 1.0");
    business_log_qt::register_types().expect("repeat registration is stable");
    let mut engine = QQmlApplicationEngine::new();
    let created = Arc::new(AtomicBool::new(false));
    let seen = Arc::clone(&created);
    let _connection = engine.pin_mut().on_object_created(move |_, object, _| {
        seen.store(!object.is_null(), Ordering::Release);
    });
    let qml = QByteArray::from(include_str!("enum-contract.qml"));
    engine
        .pin_mut()
        .load_data(&qml, &QUrl::from("qrc:/business-log-test.qml"));
    assert!(
        created.load(Ordering::Acquire),
        "BusinessLog 1.0 import or QML creation failed"
    );
    assert_eq!(
        app.pin_mut().exec(),
        0,
        "original enum or registration contract failed"
    );
    println!("BusinessLog 1.0: all30 byte-derived enum values and creation rejection passed");
}
