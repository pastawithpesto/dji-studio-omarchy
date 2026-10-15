//! Test-only opaque views of Qt classes, with methods local to this test crate.
#[cxx::bridge]
pub mod ffi {
    unsafe extern "C++" {
        include!("QtCore/QObject");
        type QObject;
        include!("cxx-qt-lib/core/qlist/qlist_QObjectMutPtr.h");
        type QList_QObjectMutPtr = cxx_qt_lib::QList<cxx_qt_lib::QObjectMutPtr>;
        fn children(self: &QObject) -> &QList_QObjectMutPtr;
        include!("cxx-qt-lib/qstring.h");
        type QString = cxx_qt_lib::QString;
        #[rust_name = "fps_probe_object_name"]
        fn objectName(self: &QObject) -> QString;
        include!("QtCore/QMetaObject");
        type QMetaObject;
        #[rust_name = "class_name"]
        fn className(self: &QMetaObject) -> *const c_char;
        #[rust_name = "meta_object"]
        fn metaObject(self: &QObject) -> *const QMetaObject;
        #[rust_name = "index_of_signal"]
        unsafe fn indexOfSignal(self: &QMetaObject, signature: *const c_char) -> i32;
        #[rust_name = "method_offset"]
        fn methodOffset(self: &QMetaObject) -> i32;
        #[rust_name = "method_count"]
        fn methodCount(self: &QMetaObject) -> i32;
        #[rust_name = "property_offset"]
        fn propertyOffset(self: &QMetaObject) -> i32;
        #[rust_name = "property_count"]
        fn propertyCount(self: &QMetaObject) -> i32;
        #[rust_name = "class_info_offset"]
        fn classInfoOffset(self: &QMetaObject) -> i32;
        #[rust_name = "class_info_count"]
        fn classInfoCount(self: &QMetaObject) -> i32;
        #[rust_name = "index_of_class_info"]
        unsafe fn indexOfClassInfo(self: &QMetaObject, name: *const c_char) -> i32;
        include!("QtQml/QQmlContext");
        type QQmlContext;
        #[rust_name = "set_context_property"]
        unsafe fn setContextProperty(
            self: Pin<&mut QQmlContext>,
            name: &QString,
            object: *mut QObject,
        );
        include!("cxx-qt-lib/qqmlapplicationengine.h");
        type QQmlApplicationEngine;
        #[rust_name = "root_context"]
        fn rootContext(self: &QQmlApplicationEngine) -> *mut QQmlContext;
    }
}
