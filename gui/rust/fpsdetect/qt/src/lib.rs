//! Rust Qt adapter for the original FpsDetect 1.0 type.
mod native;
#[cfg(feature = "test-fixture")]
mod test_support;

/// Call after QGuiApplication construction and before QML loading.
pub fn register_types() {
    cxx_qt::init_crate!(fpsdetect_qt);
}

/// Native subscriber fixture, compiled only for the bounded runtime test.
/// # Safety
/// `object` must be the live GUI-thread FpsDetect created by the test.
#[cfg(feature = "test-fixture")]
pub unsafe fn arm_deferred_destroy(object: *mut cxx_qt::QObject) {
    unsafe { native::arm_deferred_destroy(object) };
}
