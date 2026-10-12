use cxx_qt_build::{CxxQtBuilder, QmlModule};
use std::{env, path::PathBuf, process::Command};
fn main() {
    let qmake = env::var("QMAKE").unwrap_or_else(|_| "qmake6".into());
    let output = Command::new(qmake)
        .args(["-query", "QT_INSTALL_HEADERS"])
        .output()
        .expect("query Qt headers");
    assert!(output.status.success(), "Qt header query failed");
    let headers = PathBuf::from(
        String::from_utf8(output.stdout)
            .expect("Qt path is UTF-8")
            .trim(),
    );
    let generated = PathBuf::from(env::var_os("OUT_DIR").unwrap()).join("screen-aliases");
    autocxx_build::Builder::new(
        "src/aliases.rs",
        [&headers, &headers.join("QtCore"), &headers.join("QtGui")],
    )
    .extra_clang_args(&["-std=c++17"])
    .custom_gendir(generated.clone())
    .build()
    .expect("generate Qt screen aliases");
    // SAFETY: Only the generator include path is added. ABI flags stay under CXX-Qt control.
    unsafe {
        CxxQtBuilder::new_qml_module(QmlModule::new("WindowPositionDetector").version(1, 0))
            .file("src/native.rs")
            .qt_module("Gui")
            .cc_builder(|builder| {
                builder.include(generated.join("include"));
            })
            .build();
    }
    println!("cargo:rerun-if-changed=src/aliases.rs");
}
