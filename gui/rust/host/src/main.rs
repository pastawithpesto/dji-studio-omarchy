fn main() {
    let args: Vec<_> = std::env::args_os().skip(1).collect();
    let check_only = match args.as_slice() {
        [] => false,
        [arg] if arg == "--check" => true,
        [arg] if arg == "--help" => {
            println!("Usage: original-qml-host [--check]");
            return;
        }
        _ => {
            eprintln!("Usage: original-qml-host [--check]");
            std::process::exit(2);
        }
    };
    std::process::exit(original_qml_host::run(check_only, || {
        window_position_detector_qt::register_types();
        Ok(())
    }));
}
