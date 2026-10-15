//! Feature-only native fixture bindings, added explicitly by build.rs.
#[cxx::bridge]
pub(crate) mod ffi {
    unsafe extern "C++" {
        include!("fpsdetect-qt/src/native.cxxqt.h");
        #[namespace = "FpsDetect"]
        type FpsDetect = crate::native::ffi::FpsDetect;
        include!("QtCore/QObject");
        type QObject = cxx_qt::QObject;
        #[rust_name = "cast_test_detector"]
        unsafe fn qobject_cast(object: *mut QObject) -> *mut FpsDetect;
        include!("QtCore/QCoreApplication");
        type QCoreApplication;
        #[Self = "QCoreApplication"]
        #[rust_name = "fps_test_flush"]
        unsafe fn sendPostedEvents(receiver: *mut QObject, event_type: i32);
    }
}
