use std::{env, path::PathBuf, process::Command};
fn main() {
    let qmake = env::var("QMAKE").unwrap_or_else(|_| "qmake6".into());
    let query = |key: &str| {
        let r = Command::new(&qmake).args(["-query", key]).output().unwrap();
        assert!(r.status.success());
        String::from_utf8(r.stdout).unwrap().trim().to_owned()
    };
    let h = PathBuf::from(query("QT_INSTALL_HEADERS"));
    let v = query("QT_VERSION");
    let includes = vec![
        h.clone(),
        h.join("QtCore"),
        h.join("QtCore").join(&v),
        h.join("QtCore").join(&v).join("QtCore"),
        h.join("QtQml"),
    ];
    let mut build = autocxx_build::Builder::new("src/bindings.rs", &includes)
        .extra_clang_args(&["-std=c++17"])
        .build()
        .expect("generate BusinessLog Qt declarations");
    cxx_build::bridge("src/qt.rs")
        .includes(&includes)
        .flag_if_supported("-std=c++17")
        .compile("business_log_qt_api");
    println!("cargo:rerun-if-changed=src/qt.rs");
    build
        .flag_if_supported("-std=c++17")
        .compile("business_log_qt");
}
