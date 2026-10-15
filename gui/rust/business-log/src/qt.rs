//! Bind the global Qt type directly. Autocxx confuses it with a Qt namespace declaration.
// Native reflection queries are used only by unit tests.
#[allow(dead_code)]
#[cxx::bridge]
pub(crate) mod ffi {
    unsafe extern "C++" {
        include!("QtCore/private/qmetaobjectbuilder_p.h");
        include!("QtQml/qqml.h");
        type QMetaObject;
        type QMetaObjectBuilder = crate::bindings::QMetaObjectBuilder;
        type QMetaEnumBuilder = crate::bindings::QMetaEnumBuilder;
        type QByteArray = cxx_qt_lib::QByteArray;
        type QString = cxx_qt_lib::QString;

        #[rust_name = "method_count"]
        fn methodCount(self: &QMetaObject) -> i32;
        #[rust_name = "property_count"]
        fn propertyCount(self: &QMetaObject) -> i32;
        #[rust_name = "constructor_count"]
        fn constructorCount(self: &QMetaObject) -> i32;
        #[rust_name = "enum_count"]
        fn enumeratorCount(self: &QMetaObject) -> i32;
        #[rust_name = "super_class"]
        fn superClass(self: &QMetaObject) -> *const QMetaObject;

        #[rust_name = "set_scoped"]
        fn setIsScoped(self: Pin<&mut QMetaEnumBuilder>, value: bool);
        #[rust_name = "set_flag"]
        fn setIsFlag(self: Pin<&mut QMetaEnumBuilder>, value: bool);
        #[rust_name = "set_64_bit"]
        fn setIs64Bit(self: Pin<&mut QMetaEnumBuilder>, value: bool);
        #[rust_name = "add_key"]
        fn addKey(self: Pin<&mut QMetaEnumBuilder>, name: &QByteArray, value: i32) -> i32;

        #[rust_name = "set_super_class"]
        unsafe fn setSuperClass(self: Pin<&mut QMetaObjectBuilder>, superclass: *const QMetaObject);
        #[rust_name = "to_meta_object"]
        fn toMetaObject(self: &QMetaObjectBuilder) -> *mut QMetaObject;
        #[rust_name = "register_uncreatable_metaobject"]
        unsafe fn qmlRegisterUncreatableMetaObject(
            metaobject: &QMetaObject,
            uri: *const c_char,
            major: i32,
            minor: i32,
            name: *const c_char,
            reason: &QString,
        ) -> i32;
    }
}
