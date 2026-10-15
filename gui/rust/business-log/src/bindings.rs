//! Generate Qt declarations from the installed headers.
autocxx::include_cpp! {
    #include "QtCore/private/qmetaobjectbuilder_p.h"
    #include "QtQml/qqml.h"
    safety!(unsafe)
    extern_cpp_type!("QByteArray", cxx_qt_lib::QByteArray)
    extern_cpp_type!("QString", cxx_qt_lib::QString)
    generate!("QMetaObjectBuilder")
    generate!("QMetaEnumBuilder")
    block!("Qt::QMetaObject")
}

pub(crate) use ffi::{QMetaEnumBuilder, QMetaObjectBuilder};
