use cxx_qt_lib::{QByteArray, QGuiApplication, QQmlApplicationEngine, QUrl};
use std::sync::{
    Arc,
    atomic::{AtomicBool, Ordering},
};
#[path = "../src/test_probe.rs"]
mod probe;
fn main() {
    let mut app = QGuiApplication::new();
    fpsdetect_qt::register_types();
    let mut engine = QQmlApplicationEngine::new();
    let created = Arc::new(AtomicBool::new(false));
    let seen = Arc::clone(&created);
    let _created = engine
        .pin_mut()
        .on_object_created(move |engine, object, _| {
            seen.store(!object.is_null(), Ordering::Release);
            if !object.is_null() {
                // SAFETY: the engine has just constructed this live test root.
                unsafe { probe::expose_timer(engine, object) };
            }
        });
    engine.pin_mut().load_data(
        &QByteArray::from(
            &br#"
import QtQuick
import QtQuick.Window
import FpsDetect 1.0
Window {
    id: root
    visible: false
    property int phase: 0
    property string events: ""
    property bool passed: true
    property real mean: 0
    property bool nested: false
    property int destroyedEvents: 0
    property int activeEvents: 0
    property int activeFps: 0
    property bool activeDestroyed: false
    function checkSample() {
        let expectedFps = phase === 0 ? 7 : 0;
        let threshold = expectedFps === 0 ? 0 : Math.trunc(1000 / expectedFps) * 0.8;
        passed = passed && events === (mean > threshold ? "RFR" : "RF");
        passed = passed && detector.fps === expectedFps;
        if (phase === 0) {
            phase = 1;
            events = "";
        } else {
            passed = passed && mean === 0;
            phase = 2;
            events = "";
            for (let i = 0; i < 3; ++i) {
                root.beforeRendering();
                root.afterRendering();
            }
            // This reaches the real child timer's callback again from its
            // first renderTime handler. The nested empty sample publishes 0.
            sampleTimer.timeout();
            passed = passed && nested && events === "RRFF" && detector.fps === 0;
            phase = 3;
            let temporary = temporaryDetector.createObject(root);
            temporary.destroy();
            let active = temporaryDetector.createObject(root, { "destroyActive": true });
            pump.armDeferred(active);
            lifecycleCheck.start();
        }
    }
    FpsDetect {
        id: detector
        objectName: "testDetector"
        onRenderTime: function(time) {
            if (root.phase === 2) {
                root.events += "R";
                root.passed = root.passed && Number.isFinite(time) && time >= 0;
                if (!root.nested) {
                    root.nested = true;
                    sampleTimer.timeout();
                }
                return;
            }
            if (root.phase === 3) return;
            if (root.events === "") root.mean = time;
            root.passed = root.passed && Number.isFinite(time) && time >= 0 && time === root.mean;
            root.events += "R";
        }
        onFpsChanged: function(fps) {
            if (root.phase === 2) {
                root.events += "F";
                root.passed = root.passed && fps === 0 && detector.fps === 0;
                return;
            }
            if (root.phase === 3) return;
            root.events += "F";
            root.passed = root.passed && root.events === "RF" && detector.fps === fps;
            Qt.callLater(root.checkSample);
        }
    }
    Component.onCompleted: {
        passed = detector.fps === 0 && detector.width === 0 &&
                 String(detector).indexOf("FpsDetect::FpsDetect") === 0;
        try { detector.fps = 123; passed = false; } catch (error) {}
        // Test-only native window signals exercise the real registered callbacks.
        for (let i = 0; i < 7; ++i) {
            root.beforeRendering();
            root.afterRendering();
        }
    }
    Component {
        id: temporaryDetector
        FpsDetect {
            property bool destroyActive: false
            onRenderTime: {
                if (destroyActive) {
                    root.activeEvents += 1;
                    destroy();
                } else {
                    root.destroyedEvents += 1;
                }
            }
            onFpsChanged: if (destroyActive) root.activeFps += 1
            Component.onDestruction: if (destroyActive) root.activeDestroyed = true
        }
    }
    TestPump { id: pump }
    Timer {
        id: lifecycleCheck
        interval: 1400
        onTriggered: Qt.exit(root.passed && root.destroyedEvents === 0 &&
                             root.activeEvents === 1 && root.activeFps === 0 &&
                             root.activeDestroyed ? 0 : 1)
    }
    Timer { interval: 6000; running: true; onTriggered: Qt.exit(2) }
}
"#[..],
        ),
        &QUrl::from("qrc:/fpsdetect-contract-test.qml"),
    );
    assert!(
        created.load(Ordering::Acquire),
        "FpsDetect import or construction failed"
    );
    assert_eq!(
        app.pin_mut().exec(),
        0,
        "original FpsDetect contract failed"
    );
    println!(
        "PASS: FpsDetect1.0 creatable QQuickItem, read-only fps, native frame hooks, timer sampling/reset, reentrant field reloads, deferred and active teardown, signal names/arguments/order"
    );
}
