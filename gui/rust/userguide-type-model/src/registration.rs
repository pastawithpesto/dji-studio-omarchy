//! Execute the generated QML registration without constructing an engine.
#[cxx::bridge]
pub(crate) mod ffi {
    unsafe extern "C++" {
        include!("QtQml/private/qqmlmetatype_p.h");
        include!("QtQml/qqml.h");
        #[rust_name = "protect_module"]
        unsafe fn qmlProtectModule(uri: *const c_char, major: i32) -> bool;
        type QString = cxx_qt_lib::QString;
        type QQmlMetaType;
        #[Self = "QQmlMetaType"]
        #[rust_name = "register_module_types"]
        fn qmlRegisterModuleTypes(uri: &QString) -> bool;
    }
}
