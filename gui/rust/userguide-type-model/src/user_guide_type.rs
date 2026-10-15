#[cxx_qt::bridge]
mod ffi {
    // CXX-Qt 0.10 does not accept explicit qenum values. This order matches
    // the original metadata values 0..9. The QML test checks each value.
    #[qenum(UserGuideType)]
    #[namespace = "rust::user_guide_type"]
    #[qenum_unscoped]
    enum EnumType {
        OVERALL,
        KEYFRAME,
        TRANSITION_EFFECT,
        TRACKING,
        FRAMECROP,
        REGIONKEYFRAME,
        REGIONKEYFRAMESTART,
        KEYFRAMESTART,
        SUPER_SLOW,
        UNKOWN,
    }

    extern "RustQt" {
        #[qobject]
        #[qml_element]
        type UserGuideType = super::UserGuideTypeRust;
    }
}

#[derive(Default)]
pub struct UserGuideTypeRust;
