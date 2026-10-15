// Native Qt qtypes.h defines qsizetype as the signed integer for sizeof(size_t).
// This 64-bit host binding retains that native typedef in the CXX signature.
#[repr(transparent)]
pub struct QtSize(pub std::os::raw::c_longlong);
// SAFETY: The pinned host Qt typedef is signed64; CXX uses qsizetype itself.
unsafe impl cxx::ExternType for QtSize {
    type Id = cxx::type_id!("qsizetype");
    type Kind = cxx::kind::Trivial;
}
#[repr(transparent)]
pub struct MetaTypeFlag(u32);
// SAFETY: Qt's native TypeFlags is QFlags<TypeFlag>, a 32-bit flag enum.
// No flag values are constructed; this binding reads the native bitset.
unsafe impl cxx_qt_lib::QFlag for MetaTypeFlag {
    type TypeId = cxx::type_id!("QMetaType::TypeFlags");
    type Repr = u32;
    fn to_repr(self) -> u32 {
        self.0
    }
}
#[cxx::bridge]
pub mod object {
    unsafe extern "C++" {
        include!("QtCore/QObject");
        include!("QtCore/QMetaObject");
        include!("QtCore/QMetaEnum");
        include!("QtCore/QMetaType");
        type QObject;
        type QMetaObject;
        type QMetaEnum = crate::bindings::QMetaEnum;
        type QMetaType = crate::bindings::QMetaType;
        type qsizetype = super::QtSize;
        #[namespace = "QMetaType"]
        type TypeFlags = cxx_qt_lib::QFlags<super::MetaTypeFlag>;
        fn sizeOf(self: &QMetaType) -> qsizetype;
        fn alignOf(self: &QMetaType) -> qsizetype;
        fn flags(self: &QMetaType) -> TypeFlags;
        fn id(self: &QMetaType, zero: i32) -> i32;
        fn metaType(self: &QMetaEnum) -> QMetaType;
        fn isScoped(self: &QMetaEnum) -> bool;
        fn isFlag(self: &QMetaEnum) -> bool;
        fn name(self: &QMetaEnum) -> *const c_char;
        fn keyCount(self: &QMetaEnum) -> i32;
        fn key(self: &QMetaEnum, index: i32) -> *const c_char;
        fn value(self: &QMetaEnum, index: i32) -> i32;
        type QByteArray = cxx_qt_lib::QByteArray;
        include!("cxx-qt-lib/qbytearray.h");
        #[Self = "QMetaType"]
        #[rust_name = "type_from_name"]
        #[cxx_name = "type"]
        fn type_(name: &QByteArray) -> i32;
        #[Self = "QMetaType"]
        fn metaObjectForType(id: i32) -> *const QMetaObject;
        fn classInfoCount(self: &QMetaObject) -> i32;
        fn classInfoOffset(self: &QMetaObject) -> i32;
        unsafe fn indexOfClassInfo(self: &QMetaObject, name: *const c_char) -> i32;
        fn metaObject(self: &QObject) -> *const QMetaObject;
        fn className(self: &QMetaObject) -> *const c_char;
        fn propertyCount(self: &QMetaObject) -> i32;
        fn propertyOffset(self: &QMetaObject) -> i32;
        fn methodCount(self: &QMetaObject) -> i32;
        fn methodOffset(self: &QMetaObject) -> i32;
        fn constructorCount(self: &QMetaObject) -> i32;
        fn enumeratorCount(self: &QMetaObject) -> i32;
        fn enumeratorOffset(self: &QMetaObject) -> i32;
        fn enumerator(self: &QMetaObject, index: i32) -> QMetaEnum;
    }
}
