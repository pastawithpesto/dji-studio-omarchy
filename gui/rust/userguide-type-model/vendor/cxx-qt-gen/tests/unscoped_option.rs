//! Check unchanged upstream output and the explicit member-enum option.
use cxx_qt_gen::{
    self_inlining, write_cpp, write_rust, CppFragment, GeneratedCppBlocks, GeneratedOpt,
    GeneratedRustBlocks, Parser,
};
use std::{
    io::Write,
    process::{Command, Stdio},
};

fn generated(input: &str) -> (String, String, String) {
    let mut parser = Parser::from(syn::parse_str(input).unwrap()).unwrap();
    self_inlining::qualify_self_types(&mut parser).unwrap();
    let cpp = GeneratedCppBlocks::from(&parser, &GeneratedOpt::default()).unwrap();
    let CppFragment::Pair { header, source } = write_cpp(&cpp, "directory/file_ident") else {
        panic!("expected generated pair");
    };
    let rust = write_rust(
        &GeneratedRustBlocks::from(&parser).unwrap(),
        Some("directory/file_ident"),
    )
    .to_string();
    (header, source, rust)
}

#[test]
fn default_qenum_output_matches_all_three_upstream_snapshots() {
    let (header, source, rust) = generated(include_str!("test_inputs-qenum.rs.txt"));
    let format = |s: &str| {
        clang_format::clang_format_with_style(s, &clang_format::ClangFormatStyle::File).unwrap()
    };
    assert_eq!(header, format(include_str!("test_outputs-qenum.h.txt")));
    assert_eq!(source, format(include_str!("test_outputs-qenum.cpp.txt")));
    assert_eq!(rust, include_str!("stock-default-qenum.rs.txt"));
    let format_rust = |source: &str| {
        let mut child = Command::new(std::env::var("RUSTFMT").unwrap_or_else(|_| "rustfmt".into()))
            .args(["--emit", "stdout", "--edition", "2021"])
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .spawn()
            .unwrap();
        child
            .stdin
            .take()
            .unwrap()
            .write_all(source.as_bytes())
            .unwrap();
        let output = child.wait_with_output().unwrap();
        assert!(output.status.success(), "format Rust snapshot");
        String::from_utf8(output.stdout).unwrap()
    };
    assert_eq!(
        format_rust(&rust),
        format_rust(include_str!("test_outputs-qenum.rs.txt"))
    );
}

#[test]
fn explicit_unscoped_member_changes_only_enum_scope() {
    let input = r#"#[cxx_qt::bridge]
mod ffi {
    #[qenum(Object)]
    enum EnumType { A, B }
    extern "RustQt" { #[qobject] type Object = super::ObjectRust; }
}"#;
    let (header, source, rust) = generated(input);
    let (unscoped_header, unscoped_source, unscoped_rust) =
        generated(&input.replace("enum EnumType", "#[qenum_unscoped] enum EnumType"));
    assert_eq!(
        unscoped_header,
        header.replace("enum class EnumType", "enum EnumType")
    );
    assert_eq!(unscoped_source, source);
    assert_eq!(unscoped_rust, rust);
}

#[test]
fn rejects_unscoped_standalone_and_option_arguments() {
    for input in [
        r#"#[cxx_qt::bridge(namespace="example")] mod ffi {
            #[qenum] #[qenum_unscoped] enum EnumType { A }
        }"#,
        r#"#[cxx_qt::bridge] mod ffi {
            #[qenum(Object)] #[qenum_unscoped(true)] enum EnumType { A }
            extern "RustQt" { #[qobject] type Object = super::ObjectRust; }
        }"#,
    ] {
        assert!(Parser::from(syn::parse_str(input).unwrap()).is_err());
    }
}

#[test]
fn unscoped_namespaced_member_id_matches_cxx_alias() {
    let input = r#"#[cxx_qt::bridge] mod ffi {
        #[qenum(Object)] #[namespace = "internal::binding"] #[qenum_unscoped]
        enum EnumType { A, B }
        extern "RustQt" { #[qobject] type Object = super::ObjectRust; }
    }"#;
    let (_, _, rust) = generated(input);
    assert!(rust.contains("type_id ! (\"internal::binding::EnumType\")"));
    assert!(rust.contains("namespace = \"internal::binding\""));
    let (_, _, default_rust) = generated(&input.replace("#[qenum_unscoped]", ""));
    assert!(default_rust.contains("type_id ! (\"EnumType\")"));
}
