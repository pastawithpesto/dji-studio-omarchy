use cxx_qt_build::{CxxQtBuilder, QmlModule};
fn main() {
    let mut builder = CxxQtBuilder::new_qml_module(QmlModule::new("FpsDetect").version(1, 0))
        .file("src/native.rs")
        .qt_module("Quick");
    if std::env::var_os("CARGO_FEATURE_TEST_FIXTURE").is_some() {
        builder = builder.file("src/test_probe.rs");
        builder = builder.file("src/test_objects.rs");
        builder = builder.file("src/test_support.rs");
    }
    builder.build();
}
