//! Original UserGuideTypeModel 1.0 registration and enum types.

// Generated enum constants are consumed by QML.
#[allow(dead_code)]
mod mouese_event_type;
mod registration;
#[allow(dead_code)]
mod user_guide_type;

/// Register both original creatable QObject types.
/// Call after application construction and before engine construction.
pub fn register_types() {
    cxx_qt::init_crate!(userguide_type_model);
    static REGISTER: std::sync::Once = std::sync::Once::new();
    REGISTER.call_once(|| {
        // Execute the generated registrar directly; it publishes both named enums.
        // The pinned Qt implementation invokes the callback without an engine.
        assert!(
            registration::ffi::QQmlMetaType::register_module_types(&cxx_qt_lib::QString::from(
                "UserGuideTypeModel"
            )),
            "UserGuideTypeModel generated registration callback is unavailable"
        );
        // Skip plugin resolution for the module whose complete types are now registered.
        // SAFETY: The static URI string is NUL-terminated and remains live for the call.
        assert!(
            unsafe { registration::ffi::protect_module(c"UserGuideTypeModel".as_ptr(), 1) },
            "UserGuideTypeModel registered module could not be protected"
        );
    });
}
