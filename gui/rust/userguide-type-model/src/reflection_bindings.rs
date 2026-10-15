//! Value storage for the pinned Qt6.11.2 metadata probe.
//! qmetaobject.h: QMetaEnum stores a metaobject pointer and Data{const uint*}.
//! qmetatype.h: QMetaType stores const QMetaTypeInterface*.
//! Native compiler layout constants are checked before either value is used.
#[repr(C)]
#[derive(Clone, Copy)]
pub struct QMetaEnum {
    _metaobject: *const std::ffi::c_void,
    _data: *const u32,
}
#[repr(C)]
#[derive(Clone, Copy)]
pub struct QMetaType {
    _interface: *const std::ffi::c_void,
}
// SAFETY: Exact pinned Qt header storage; native size/alignment are compiler-checked.
unsafe impl cxx::ExternType for QMetaEnum {
    type Id = cxx::type_id!("QMetaEnum");
    type Kind = cxx::kind::Trivial;
}
// SAFETY: Exact pinned Qt header storage; native size/alignment are compiler-checked.
unsafe impl cxx::ExternType for QMetaType {
    type Id = cxx::type_id!("QMetaType");
    type Kind = cxx::kind::Trivial;
}
include!(concat!(env!("OUT_DIR"), "/native-layout.rs"));
