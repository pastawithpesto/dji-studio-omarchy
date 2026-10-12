//! Source policy check. External libraries and untracked build outputs are separate.
#![forbid(unsafe_code)]

use std::{fs, path::Path, process::Command};

// Frozen research records, not application implementations. Exact Git blob IDs
// preserve two decompiler outputs and one historical DLL reference harness.
const REFERENCE_FILES: [(&str, &str); 3] = [
    (
        "docs/evidence/atomic-wait-timeouts/__std_atomic_wait_get_deadline.pseudo.c",
        "7ff8a8242973232a13f124898e34e61620ac61fd",
    ),
    (
        "docs/evidence/atomic-wait-timeouts/__std_atomic_wait_get_remaining_timeout.pseudo.c",
        "94f2b8d05e7f02edc6e11164830a1c82bc9b536b",
    ),
    (
        "tests/fixtures/oss-crc64/original_exports.c",
        "21f2787296f971dd6fcd4133f5ea8520bf82de2b",
    ),
];

fn forbidden_path(path: &str) -> bool {
    let extension = Path::new(path)
        .extension()
        .and_then(|value| value.to_str())
        .unwrap_or_default()
        .to_ascii_lowercase();
    if matches!(
        extension.as_str(),
        "c" | "cc"
            | "cp"
            | "cpp"
            | "cxx"
            | "c++"
            | "h"
            | "hh"
            | "hpp"
            | "hxx"
            | "h++"
            | "ipp"
            | "inl"
            | "tcc"
            | "m"
            | "mm"
            | "cu"
            | "cuh"
    ) {
        return true;
    }
    (path.starts_with("src/") || path.starts_with("gui/"))
        && matches!(
            extension.as_str(),
            "py" | "js"
                | "jsx"
                | "ts"
                | "tsx"
                | "go"
                | "java"
                | "kt"
                | "kts"
                | "cs"
                | "swift"
                | "rb"
                | "php"
                | "lua"
                | "sh"
                | "bash"
                | "zsh"
                | "html"
                | "css"
        )
}

// Ignore Rust comments and literals. FFI declarations and generated bindings are
// permitted; the rust-cpp macros carry handwritten C++ and are prohibited.
fn skip_trivia(source: &str, mut index: usize) -> usize {
    let bytes = source.as_bytes();
    while index < bytes.len() {
        if bytes[index..].starts_with(b"//") {
            while index < bytes.len() && bytes[index] != b'\n' {
                index += 1;
            }
            continue;
        }
        if bytes[index..].starts_with(b"/*") {
            index += 2;
            let mut depth = 1;
            while index < bytes.len() && depth > 0 {
                if bytes[index..].starts_with(b"/*") {
                    depth += 1;
                    index += 2;
                } else if bytes[index..].starts_with(b"*/") {
                    depth -= 1;
                    index += 2;
                } else {
                    index += 1;
                }
            }
            continue;
        }
        let character = source[index..].chars().next().unwrap();
        if character.is_whitespace() || matches!(character, '\u{200e}' | '\u{200f}') {
            index += character.len_utf8();
            continue;
        }
        break;
    }
    index
}

fn inline_cpp(source: &str) -> bool {
    let bytes = source.as_bytes();
    let mut index = 0;
    let mut previous = "";
    while index < bytes.len() {
        index = skip_trivia(source, index);
        if index == bytes.len() {
            break;
        }
        let raw_start = if bytes[index] == b'r' {
            Some(index)
        } else if matches!(bytes[index], b'b' | b'c') && bytes.get(index + 1) == Some(&b'r') {
            Some(index + 1)
        } else {
            None
        };
        if let Some(start) = raw_start {
            let mut quote = start + 1;
            while quote < bytes.len() && bytes[quote] == b'#' {
                quote += 1;
            }
            if bytes.get(quote) == Some(&b'"') {
                let hashes = quote - start - 1;
                index = quote + 1;
                while index < bytes.len() {
                    if bytes[index] == b'"'
                        && bytes.get(index + 1..index + 1 + hashes)
                            == Some(&bytes[quote - hashes..quote])
                    {
                        index += 1 + hashes;
                        break;
                    }
                    index += 1;
                }
                previous = "";
                continue;
            }
        }
        if bytes[index] == b'\'' {
            let mut end = index + 1;
            if bytes.get(end) == Some(&b'\\') {
                end += 1;
                match bytes.get(end) {
                    Some(b'u') if bytes.get(end + 1) == Some(&b'{') => {
                        end += 2;
                        while end < bytes.len() && bytes[end] != b'}' {
                            end += 1;
                        }
                        end += 1;
                    }
                    Some(b'x') => end += 3,
                    Some(_) => end += 1,
                    None => {}
                }
            } else if let Some(character) = source[end..].chars().next() {
                end += character.len_utf8();
            }
            if bytes.get(end) == Some(&b'\'') {
                index = end + 1;
                previous = "";
                continue;
            }
        }
        if bytes[index] == b'"' {
            index += 1;
            while index < bytes.len() {
                match bytes[index] {
                    b'\\' => index += 2,
                    b'"' => {
                        index += 1;
                        break;
                    }
                    _ => index += 1,
                }
            }
            previous = "";
            continue;
        }
        if bytes[index].is_ascii_alphabetic() || bytes[index] == b'_' {
            let start = index;
            index += 1;
            while index < bytes.len()
                && (bytes[index].is_ascii_alphanumeric() || bytes[index] == b'_')
            {
                index += 1;
            }
            previous = &source[start..index];
            continue;
        }
        if bytes[index] == b'!'
            && matches!(previous, "cpp" | "cpp_class")
            && matches!(
                bytes.get(skip_trivia(source, index + 1)),
                Some(b'(' | b'[' | b'{')
            )
        {
            return true;
        }
        if !bytes[index].is_ascii() {
            let character = source[index..].chars().next().unwrap();
            if !character.is_whitespace() && !matches!(character, '\u{200e}' | '\u{200f}') {
                previous = "";
            }
            index += character.len_utf8();
            continue;
        }
        if !bytes[index].is_ascii_whitespace() {
            previous = "";
        }
        index += 1;
    }
    false
}

fn check() -> Result<(), String> {
    let root_output = Command::new("git")
        .args(["rev-parse", "--show-toplevel"])
        .output()
        .map_err(|error| format!("Cannot find repository root: {error}"))?;
    if !root_output.status.success() {
        return Err("Cannot find repository root".into());
    }
    let root_text = std::str::from_utf8(&root_output.stdout)
        .map_err(|error| format!("Invalid repository path encoding: {error}"))?;
    let root = Path::new(root_text.strip_suffix('\n').unwrap_or(root_text));
    let output = Command::new("git")
        .current_dir(root)
        .args(["ls-files", "--cached", "-z"])
        .output()
        .map_err(|error| format!("Cannot read tracked source: {error}"))?;
    if !output.status.success() {
        return Err("Cannot read tracked source with git ls-files".into());
    }
    let paths = std::str::from_utf8(&output.stdout)
        .map_err(|error| format!("Invalid source path encoding: {error}"))?;
    let mut failures = Vec::new();
    for path in paths.split('\0').filter(|path| !path.is_empty()) {
        if let Some((_, expected)) = REFERENCE_FILES.iter().find(|(name, _)| *name == path) {
            let blob = Command::new("git")
                .current_dir(root)
                .args(["hash-object", "--no-filters", "--", path])
                .output()
                .map_err(|error| format!("Cannot hash reference {path}: {error}"))?;
            if !blob.status.success() || String::from_utf8_lossy(&blob.stdout).trim() != *expected {
                failures.push(format!("Frozen reference bytes changed: {path}"));
            }
        } else if forbidden_path(path) {
            failures.push(format!("Prohibited source language: {path}"));
        } else if Path::new(path)
            .extension()
            .is_some_and(|extension| extension.eq_ignore_ascii_case("rs"))
        {
            let source = fs::read_to_string(root.join(path))
                .map_err(|error| format!("Cannot read {path}: {error}"))?;
            if inline_cpp(&source) {
                failures.push(format!("Prohibited inline C++ macro: {path}"));
            }
        }
    }
    if failures.is_empty() {
        println!("PASS: tracked application source language");
        Ok(())
    } else {
        Err(failures.join("\n"))
    }
}

fn main() {
    if let Err(error) = check() {
        eprintln!("{error}");
        std::process::exit(1);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rejects_native_source_and_headers_in_any_directory() {
        for path in ["src/a.cpp", "gui/a.C", "tools/a.hpp", "tests/a.cxx", "a.mm"] {
            assert!(forbidden_path(path), "{path}");
        }
    }

    #[test]
    fn keeps_application_code_in_rust_and_qml() {
        for path in ["src/a.py", "gui/a.js", "gui/a.tsx", "src/a.go"] {
            assert!(forbidden_path(path), "{path}");
        }
        for path in ["src/a.rs", "gui/a.qml", "gui/original/a.svg", "tools/a.py"] {
            assert!(!forbidden_path(path), "{path}");
        }
    }

    #[test]
    fn rejects_inline_cpp_with_spacing_comments_or_namespace() {
        for source in [
            "cpp! {}",
            "cpp /* a /* b */ c */ ! {}",
            "cpp::cpp! {}",
            "cpp_class! {}",
            "cpp\u{200e}! {}",
            "cpp! /* a /* b */ c */ {}",
        ] {
            assert!(inline_cpp(source), "{source}");
        }
    }

    #[test]
    fn permits_comparison_operators_and_requires_macro_delimiter() {
        for source in [
            "let cpp = false; assert!(cpp != true);",
            "assert!(cpp /* comment */ != true);",
            "let cpp_class = 1; assert!(cpp_class != 2);",
        ] {
            assert!(!inline_cpp(source), "{source}");
        }
        assert!(inline_cpp("cpp! // delimiter follows a comment\n[body]"));
        assert!(inline_cpp("cpp_class! /* comment */ (body)"));
    }

    #[test]
    fn permits_comments_strings_and_existing_binding_declarations() {
        for source in [
            "// cpp! {}\n/* cpp_class! {} */",
            "let s = \"cpp! {}\";",
            "let s = r###\"cpp! {}\"###;",
            "let s = br#\"cpp! {}\"#;",
            "let s = br#\"\"cpp! {}\"\"#;",
            "unsafe extern \"C++\" { type QWindow; }",
            "autocxx::include_cpp! { #include \"QtGui/QScreen\" }",
        ] {
            assert!(!inline_cpp(source), "{source}");
        }
        assert!(inline_cpp("let s = r#\"cpp!\"#; cpp! {}"));
        assert!(inline_cpp("let ch = '\"'; cpp! {}"));
        assert!(inline_cpp("let ch = '\\\"'; cpp! {}"));
        assert!(inline_cpp("let ch = '\\u{22}'; cpp! {}"));
        assert!(inline_cpp("fn a<'a>() { cpp! {} }"));
    }
}
