//! Supported MLT calculations from the original DJI Studio DLL.
//!
//! This module currently registers only the reviewed format calculations.
//! These are safe Rust interfaces, not declarations of the Windows C ABI.

#[path = "mlt/audio_format.rs"]
pub mod audio_format;
#[path = "mlt/image_format.rs"]
pub mod image_format;

pub use audio_format::{
    AudioFormatArithmeticError, mlt_audio_format_name, mlt_audio_format_samples,
    mlt_audio_format_size,
};
pub use image_format::{mlt_image_format_id, mlt_image_format_name, mlt_image_format_size};
