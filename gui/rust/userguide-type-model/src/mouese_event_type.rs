#[cxx_qt::bridge]
mod ffi {
    // Original name and spelling. Values 0..5 come from native metadata.
    #[qenum(MoueseEventType)]
    #[namespace = "rust::mouese_event_type"]
    #[qenum_unscoped]
    enum EnumType {
        CLICK,
        HOVER,
        WHEEL,
        PRESS,
        REALSE,
        DRAG,
    }

    extern "RustQt" {
        #[qobject]
        #[qml_element]
        type MoueseEventType = super::MoueseEventTypeRust;
    }
}

#[derive(Default)]
pub struct MoueseEventTypeRust;
