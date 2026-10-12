//! Rust adapter for the original `WindowPositionDetector` Qt boundary.

pub mod adapter;

mod native;

/// Register the original WindowPositionDetector module, version 1.0.
/// Call after construction of QGuiApplication and before loading QML.
pub fn register_types() {
    cxx_qt::init_crate!(window_position_detector_qt);
}
