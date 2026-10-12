// This file is input to autocxx-build. Rust does not compile this module.
// The library generator creates exact aliases from installed Qt headers.
autocxx::include_cpp! {
    #include "QtGui/QGuiApplication"
    #include "QtGui/QScreen"
    concrete!("QList<QScreen*>", ScreenList)
    concrete!("QScreen*", ScreenPointer)
    exclude_impls!()
    exclude_utilities!()
}
