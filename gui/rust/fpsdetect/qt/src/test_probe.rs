//! Test-only access to native QObject children. No FpsDetect API is added.
use cxx_qt_lib::{QQmlApplicationEngine, QString};
use std::pin::Pin;
#[path = "test_objects.rs"]
mod objects;

#[cxx_qt::bridge]
mod probe_ffi {
    unsafe extern "RustQt" {
        #[qobject]
        #[qml_element]
        #[namespace = "FpsDetectTest"]
        type TestPump = super::TestPumpRust;
        #[qinvokable]
        #[cxx_name = "armDeferred"]
        unsafe fn arm_deferred(self: Pin<&mut TestPump>, object: *mut QObject);
    }
}
#[derive(Default)]
pub struct TestPumpRust;
impl probe_ffi::TestPump {
    unsafe fn arm_deferred(self: Pin<&mut Self>, object: *mut cxx_qt::QObject) {
        // SAFETY: the QML fixture passes its newly created dynamic detector.
        unsafe { fpsdetect_qt::arm_deferred_destroy(object) };
    }
}

fn same_cpp_type<T, U>()
where
    T: cxx::ExternType<Id = U::Id>,
    U: cxx::ExternType,
{
}

// The local opaque view and library QObject denote exactly the same C++ class.
unsafe fn object_view<'a>(object: *const cxx_qt::QObject) -> Option<&'a objects::ffi::QObject> {
    same_cpp_type::<objects::ffi::QObject, cxx_qt::QObject>();
    unsafe { object.cast::<objects::ffi::QObject>().as_ref() }
}

/// Called immediately after construction, before the event loop or deletion.
pub unsafe fn expose_timer(engine: Pin<&mut QQmlApplicationEngine>, root: *mut cxx_qt::QObject) {
    // SAFETY: objectCreated supplies a live tree owned by this test engine.
    let root = unsafe { object_view(root) }.expect("test root");
    let detector = find_detector(root).expect("test detector child");
    let meta = unsafe { detector.meta_object().as_ref() }.expect("test metaobject");
    assert_eq!(meta.method_count() - meta.method_offset(), 2);
    assert_eq!(meta.property_count() - meta.property_offset(), 1);
    // Original local class-info count is zero. Qt6 registration adds one
    // QML.Element scaffold entry; this is a declared metadata difference.
    assert_eq!(meta.class_info_count() - meta.class_info_offset(), 1);
    // SAFETY: static C strings and the live detector's native metaobject.
    unsafe {
        assert_eq!(
            meta.index_of_class_info(c"QML.Element".as_ptr()),
            meta.class_info_offset()
        );
        assert_eq!(
            meta.index_of_signal(c"fpsChanged(int)".as_ptr()),
            meta.method_offset()
        );
        assert_eq!(
            meta.index_of_signal(c"renderTime(double)".as_ptr()),
            meta.method_offset() + 1
        );
    }
    let timer = detector
        .children()
        .iter()
        .find_map(|child| {
            let object = unsafe { object_view(child.as_ptr()) }?;
            let meta = unsafe { object.meta_object().as_ref() }?;
            // SAFETY: the live QObject's metaobject owns its static class name.
            let name = unsafe { std::ffi::CStr::from_ptr(meta.class_name()) };
            (name == c"QTimer").then_some(child.as_mut_ptr())
        })
        .expect("native child QTimer");
    same_cpp_type::<objects::ffi::QQmlApplicationEngine, QQmlApplicationEngine>();
    let engine = engine.as_ref().get_ref() as *const QQmlApplicationEngine;
    // SAFETY: equal ExternType IDs denote the same native class, not a guessed
    // layout. Both Rust representations are opaque and non-owning.
    let engine = unsafe { &*engine.cast::<objects::ffi::QQmlApplicationEngine>() };
    let context = engine.root_context();
    // SAFETY: the context and normal detector/timer outlive this fixture.
    unsafe {
        Pin::new_unchecked(context.as_mut().expect("root context"))
            .set_context_property(&QString::from("sampleTimer"), timer.cast());
    }
}
fn find_detector(object: &objects::ffi::QObject) -> Option<&objects::ffi::QObject> {
    if object.fps_probe_object_name() == QString::from("testDetector") {
        return Some(object);
    }
    object.children().iter().find_map(|child| {
        // SAFETY: synchronous tree traversal, no user callbacks or deletion.
        let child = unsafe { object_view(child.as_ptr()) }?;
        find_detector(child)
    })
}
