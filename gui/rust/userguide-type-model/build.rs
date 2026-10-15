use cxx_qt_build::{CxxQtBuilder, QmlModule};
use std::{env, path::PathBuf, process::Command};

fn main() {
    let query = Command::new(env::var("QMAKE").unwrap_or_else(|_| "qmake6".into()))
        .args(["-query", "QT_INSTALL_HEADERS"])
        .output()
        .expect("query Qt headers");
    assert!(query.status.success(), "Qt header query failed");
    let headers = PathBuf::from(String::from_utf8(query.stdout).unwrap().trim());
    let version_query = Command::new(env::var("QMAKE").unwrap_or_else(|_| "qmake6".into()))
        .args(["-query", "QT_VERSION"])
        .output()
        .expect("query Qt version");
    assert!(version_query.status.success());
    let version = String::from_utf8(version_query.stdout).unwrap();
    let version = version.trim();
    assert_eq!(
        version, "6.11.2",
        "metadata probe is pinned to audited Qt6.11.2"
    );
    assert_eq!(env::var("CARGO_CFG_TARGET_POINTER_WIDTH").unwrap(), "64");
    let out = PathBuf::from(env::var("OUT_DIR").unwrap());
    let dump = out.join("qt-native-layout.dump");
    let compiler = env::var("CXX").unwrap_or_else(|_| "c++".into());
    let layout_check = Command::new(compiler)
        .args(["-x", "c++", "-std=c++17", "-fPIC"])
        .arg("-I")
        .arg(&headers)
        .arg("-I")
        .arg(headers.join("QtCore"))
        .arg(format!("-fdump-lang-class={}", dump.display()))
        .arg("-c")
        .arg(headers.join("QtCore/QMetaEnum"))
        .arg("-o")
        .arg(out.join("qt-native-layout.o"))
        .output()
        .expect("compile actual Qt header layout probe");
    assert!(
        layout_check.status.success(),
        "native header layout check failed: {}",
        String::from_utf8_lossy(&layout_check.stderr)
    );
    let layout = std::fs::read_to_string(dump).unwrap();
    let mut constants = String::new();
    for (native, name) in [
        ("QMetaEnum", "ENUM"),
        ("QMetaType", "TYPE"),
        ("QFlags<QMetaType::TypeFlag>", "FLAGS"),
    ] {
        let marker = format!("Class {native}\n");
        let row = layout
            .split_once(&marker)
            .expect("Qt native class in dump")
            .1
            .lines()
            .next()
            .unwrap();
        let value = |prefix: &str| -> usize {
            row.split_whitespace()
                .find_map(|s| s.strip_prefix(prefix))
                .unwrap()
                .parse()
                .unwrap()
        };
        constants.push_str(&format!(
            "pub const NATIVE_{name}_SIZE: usize = {};\n",
            value("size=")
        ));
        constants.push_str(&format!(
            "pub const NATIVE_{name}_ALIGN: usize = {};\n",
            value("align=")
        ));
    }
    std::fs::write(out.join("native-layout.rs"), constants).unwrap();
    println!(
        "cargo:rerun-if-changed={}",
        headers.join("QtCore/qmetaobject.h").display()
    );
    println!(
        "cargo:rerun-if-changed={}",
        headers.join("QtCore/qmetatype.h").display()
    );

    CxxQtBuilder::new_qml_module(QmlModule::new("UserGuideTypeModel").version(1, 0))
        .file("src/user_guide_type.rs")
        .file("src/mouese_event_type.rs")
        .file("src/reflection.rs")
        .file("src/registration.rs")
        .include_dir(headers.join("QtCore").join(version))
        .include_dir(headers.join("QtCore").join(version).join("QtCore"))
        .include_dir(headers.join("QtQml").join(version))
        .include_dir(headers.join("QtQml").join(version).join("QtQml"))
        .qt_module("Gui")
        .build();
}
