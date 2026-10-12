fn main() {
    let check_only = std::env::args_os().skip(1).any(|arg| arg == "--check");
    std::process::exit(original_qml_host::run(check_only, || {}));
}
