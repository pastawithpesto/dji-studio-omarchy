//! Check signal type lookup when a class and namespace share an identifier.
use cxx_qt_gen::{self_inlining, write_cpp, CppFragment, GeneratedCppBlocks, GeneratedOpt, Parser};

fn generated(namespace: &str, mutable: bool) -> (String, String) {
    let receiver = if mutable {
        "Pin<&mut Object>"
    } else {
        "&Object"
    };
    let input = format!(
        r#"#[cxx_qt::bridge(namespace = "{namespace}")]
        mod ffi {{
            unsafe extern "C++Qt" {{
                include!("QtCore/QObject");
                #[qobject]
                #[cxx_name = "Repeat"]
                type Object;
                #[qsignal]
                fn changed(self: {receiver}, value: i32);
            }}
        }}"#
    );
    let mut parser = Parser::from(syn::parse_str(&input).unwrap()).unwrap();
    self_inlining::qualify_self_types(&mut parser).unwrap();
    let cpp = GeneratedCppBlocks::from(&parser, &GeneratedOpt::default()).unwrap();
    let CppFragment::Pair { header, source } = write_cpp(&cpp, "test/signals") else {
        panic!("expected a header and source");
    };
    let compact = |text: String| text.chars().filter(|c| !c.is_whitespace()).collect();
    (compact(header), compact(source))
}

#[test]
fn collision_qualifies_declaration_definition_callback_and_member_pointer() {
    for namespace in ["Repeat", "Repeat::inner"] {
        for mutable in [true, false] {
            let (header, source) = generated(namespace, mutable);
            let class = format!("::{namespace}::Repeat");
            let reference = if mutable { "&" } else { "const&" };
            let helper = format!("Connect({class}{reference}self,");
            assert!(header.contains(&helper), "helper declaration: {header}");
            assert!(source.contains(&helper), "helper definition: {source}");
            assert!(source.contains(&format!("&{class}::changed,")));
            assert!(source.contains(&format!("operator()<{class}{reference},::std::int32_t>")));
        }
    }
}

#[test]
fn unrelated_signal_type_spelling_stays_unchanged() {
    for namespace in ["regular", "outer::Repeat"] {
        let (header, source) = generated(namespace, true);
        let class = format!("{namespace}::Repeat");
        assert!(header.contains(&format!("Connect({class}&self,")));
        assert!(source.contains(&format!("Connect({class}&self,")));
        assert!(source.contains(&format!("&{class}::changed,")));
        assert!(source.contains(&format!("operator()<{class}&,::std::int32_t>")));
        assert!(!header.contains(&format!("Connect(::{class}&self,")));
    }
}
