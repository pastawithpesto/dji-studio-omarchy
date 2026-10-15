//! Check the explicit shared callback option and the unchanged default callback.
use cxx_qt_gen::{
    self_inlining, write_cpp, write_rust, CppFragment, GeneratedCppBlocks, GeneratedOpt,
    GeneratedRustBlocks, Parser,
};

fn input(option: &str) -> String {
    format!(
        r#"#[cxx_qt::bridge(namespace = "external")]
        mod ffi {{
            unsafe extern "C++Qt" {{
                include!("QtCore/QObject");
                #[qobject]
                type Object;
                #[qsignal]
                {option}
                pub(self) fn changed(self: Pin<&mut Object>, value: i32);
            }}
        }}"#
    )
}

fn generated(option: &str) -> (String, String, String) {
    let mut parser = Parser::from(syn::parse_str(&input(option)).unwrap()).unwrap();
    self_inlining::qualify_self_types(&mut parser).unwrap();
    let cpp = GeneratedCppBlocks::from(&parser, &GeneratedOpt::default()).unwrap();
    let CppFragment::Pair { header, source } = write_cpp(&cpp, "test/shared") else {
        panic!("expected a header and source");
    };
    let rust = write_rust(
        &GeneratedRustBlocks::from(&parser).unwrap(),
        Some("test/shared"),
    )
    .to_string();
    let compact: String = rust.chars().filter(|c| !c.is_whitespace()).collect();
    (header, source, compact)
}

#[test]
fn shared_callback_has_no_mutable_handler_reference() {
    let (header, source, rust) = generated("#[qsignal_shared]");
    let (default_header, default_source, _) = generated("");
    assert_eq!(header, default_header);
    assert_eq!(source, default_source);
    assert!(rust.contains("F:Fn("));
    assert!(rust.contains("+'static+Send+Sync>"));
    assert!(rust.contains("#[repr(transparent)]"));
    assert!(rust.contains("closure:Box<dynFn("));
    assert!(rust.contains("+Send+Sync>"));
    assert!(rust.contains("handler:&ObjectCxxQtSignalHandlerchanged"));
    assert!(!rust.contains("handler:&mut"));
    assert!(!rust.contains("FnMut"));
    assert!(rust.contains("handler.closure.as_ref()"));
    assert!(rust.contains("unsafeimplcxx::ExternType"));
    assert!(rust.contains("cxx::kind::Trivial"));
    assert!(rust.contains("assert_eq_align!"));
    assert!(rust.contains("assert_eq_size!"));
    assert!(!rust.contains("qsignal_shared"));
}

#[test]
fn default_callback_keeps_upstream_storage_and_mutable_dispatch() {
    let (_, _, rust) = generated("");
    assert!(rust.contains("F:FnMut("));
    assert!(rust.contains("typeFnType=dynFnMut("));
    assert!(rust.contains("handler:&mutObjectCxxQtSignalHandlerchanged"));
    assert!(rust.contains("handler.closure()"));
    assert!(rust.contains("CxxQtSignalHandlerClosurefor"));
    assert!(!rust.contains("closure:Box<dynFn("));
    assert!(!rust.contains("+'static+Send+Sync>"));
}

#[test]
fn shared_option_rejects_arguments() {
    for option in ["#[qsignal_shared(true)]", "#[qsignal_shared = true]"] {
        assert!(Parser::from(syn::parse_str(&input(option)).unwrap()).is_err());
    }
}
