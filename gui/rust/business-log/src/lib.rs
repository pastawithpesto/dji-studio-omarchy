//! The original BusinessLog 1.0 enum namespace.

// Autocxx0.30 generates old unsafe bodies and retains the exact Qt enum names.
#[allow(unsafe_op_in_unsafe_fn, clippy::enum_variant_names)]
mod bindings;
mod enums;
mod qt;

pub use enums::{Events, Stream};

use autocxx::prelude::*;
use cxx_qt_lib::{QByteArray, QString};
use std::sync::OnceLock;

/// Independent adapter errors. These are not original DJI error names.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum RegistrationError {
    AllocationFailed,
    RegistrationFailed,
}

impl std::fmt::Display for RegistrationError {
    fn fmt(&self, formatter: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        formatter.write_str(match self {
            Self::AllocationFailed => "BusinessLog metaobject allocation failed",
            Self::RegistrationFailed => "BusinessLog type registration failed",
        })
    }
}

impl std::error::Error for RegistrationError {}

/// Register the original uncreatable BusinessLog type, version 1.0.
/// Call on the application thread after QCoreApplication construction and before QML load.
/// Keep the Qt type registry for the process lifetime. Do not call qmlClearTypeRegistrations.
pub fn register_types() -> Result<(), RegistrationError> {
    static RESULT: OnceLock<Result<(), RegistrationError>> = OnceLock::new();
    *RESULT.get_or_init(register)
}

fn make_metaobject() -> Result<*mut qt::ffi::QMetaObject, RegistrationError> {
    let mut builder = bindings::QMetaObjectBuilder::new().within_unique_ptr();
    if builder.is_null() {
        return Err(RegistrationError::AllocationFailed);
    }
    // SAFETY: The generated bindings use Qt's actual declarations. The builder owns
    // its enum records. The resulting metaobject remains live while Qt retains it.
    unsafe {
        builder
            .pin_mut()
            .setClassName(&QByteArray::from("BusinessLog"));
        builder.pin_mut().set_super_class(std::ptr::null());
        for (name, keys) in [
            ("Stream", enums::STREAM_KEYS),
            ("Events", enums::EVENTS_KEYS),
        ] {
            let name = QByteArray::from(name);
            let mut enumeration = builder.pin_mut().addEnumerator(&name).within_unique_ptr();
            enumeration.pin_mut().set_scoped(true);
            enumeration.pin_mut().set_flag(false);
            enumeration.pin_mut().set_64_bit(false);
            for (key, value) in keys {
                enumeration
                    .pin_mut()
                    .add_key(&QByteArray::from(*key), *value);
            }
        }
        let metaobject = builder.to_meta_object();
        if metaobject.is_null() {
            return Err(RegistrationError::AllocationFailed);
        }
        Ok(metaobject)
    }
}

fn register() -> Result<(), RegistrationError> {
    let metaobject = make_metaobject()?;
    // SAFETY: This is an owned nonnull Qt snapshot. Qt retains it on success.
    unsafe {
        let id = qt::ffi::register_uncreatable_metaobject(
            &*metaobject,
            c"BusinessLog".as_ptr(),
            1,
            0,
            c"BusinessLog".as_ptr(),
            &QString::from("enums only"),
        );
        if id < 0 {
            // Qt did not retain the failed registration. Qt allocates this block with malloc.
            libc::free(metaobject.cast());
            return Err(RegistrationError::RegistrationFailed);
        }
        // Qt's registry keeps this pointer. Retain the allocation for the process lifetime.
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    #[test]
    fn native_metaobject_has_only_the_original_enum_surface() {
        let metaobject = super::make_metaobject().expect("build the enum metaobject");
        // SAFETY: The snapshot is live until this test frees it. No registry retains it.
        unsafe {
            let meta = &*metaobject;
            assert!(meta.super_class().is_null());
            assert_eq!(meta.method_count(), 0);
            assert_eq!(meta.property_count(), 0);
            assert_eq!(meta.constructor_count(), 0);
            assert_eq!(meta.enum_count(), 2);
            libc::free(metaobject.cast());
        }
    }
}
