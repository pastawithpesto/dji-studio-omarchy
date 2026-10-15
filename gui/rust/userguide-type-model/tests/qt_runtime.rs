//! Check original QML names and native metadata values on the main thread.
#[path = "../src/reflection_bindings.rs"]
mod bindings;
#[path = "../src/reflection.rs"]
mod metaobject;

use cxx_qt_lib::{QByteArray, QGuiApplication, QQmlApplicationEngine, QUrl};
use std::sync::{
    atomic::{AtomicBool, Ordering},
    Arc,
};

fn main() {
    assert_eq!(
        std::mem::size_of::<bindings::QMetaEnum>(),
        bindings::NATIVE_ENUM_SIZE
    );
    assert_eq!(
        std::mem::align_of::<bindings::QMetaEnum>(),
        bindings::NATIVE_ENUM_ALIGN
    );
    assert_eq!(
        std::mem::size_of::<bindings::QMetaType>(),
        bindings::NATIVE_TYPE_SIZE
    );
    assert_eq!(
        std::mem::align_of::<bindings::QMetaType>(),
        bindings::NATIVE_TYPE_ALIGN
    );
    type Flags = cxx_qt_lib::QFlags<metaobject::MetaTypeFlag>;
    assert_eq!(std::mem::size_of::<Flags>(), bindings::NATIVE_FLAGS_SIZE);
    assert_eq!(std::mem::align_of::<Flags>(), bindings::NATIVE_FLAGS_ALIGN);

    let mut app = QGuiApplication::new();
    userguide_type_model::register_types();
    userguide_type_model::register_types();
    let mut ids = Vec::new();
    for name in ["UserGuideType::EnumType", "MoueseEventType::EnumType"] {
        let id = metaobject::object::QMetaType::type_from_name(&QByteArray::from(name));
        assert_ne!(
            id, 0,
            "original enum name must be registered before any engine or enum lookup: {name}"
        );
        ids.push(id);
    }
    // BOTH names were queried before any enum reflection can register anything.
    for id in ids {
        let meta_ptr = metaobject::object::QMetaType::metaObjectForType(id);
        let meta = unsafe { meta_ptr.as_ref() }.expect("named enum owner metaobject");
        let enum_type = meta.enumerator(meta.enumeratorOffset()).metaType();
        assert_eq!(
            enum_type.id(0),
            id,
            "named registration is the same native enum"
        );
        assert_eq!(enum_type.sizeOf().0, 4);
        assert_eq!(enum_type.alignOf().0, 4);
        assert_eq!(
            enum_type.flags().to_int(),
            0x14,
            "relocatable signed enum flags"
        );
    }
    let mut engine = QQmlApplicationEngine::new();
    let created = Arc::new(AtomicBool::new(false));
    let seen = Arc::clone(&created);
    let _connection = engine.pin_mut().on_object_created(move |_, object, _| {
        seen.store(!object.is_null(), Ordering::Release);
    });
    // These literals are independent expected values from the pinned PE rows.
    let qml = QByteArray::from(
        r#"import QtQuick
import UserGuideTypeModel 1.0
Item {
    UserGuideType { id: guide }
    UserGuideType { id: secondGuide }
    MoueseEventType { id: mouse }
    MoueseEventType { id: secondMouse }
    Timer { interval: 5000; running: true; onTriggered: Qt.exit(90) }
    Component.onCompleted: Qt.callLater(function() {
        var values = [UserGuideType.OVERALL, UserGuideType.KEYFRAME,
            UserGuideType.TRANSITION_EFFECT, UserGuideType.TRACKING,
            UserGuideType.FRAMECROP, UserGuideType.REGIONKEYFRAME,
            UserGuideType.REGIONKEYFRAMESTART, UserGuideType.KEYFRAMESTART,
            UserGuideType.SUPER_SLOW, UserGuideType.UNKOWN,
            MoueseEventType.CLICK, MoueseEventType.HOVER, MoueseEventType.WHEEL,
            MoueseEventType.PRESS, MoueseEventType.REALSE, MoueseEventType.DRAG];
        var expected = [0,1,2,3,4,5,6,7,8,9,0,1,2,3,4,5];
        for (var i = 0; i < expected.length; ++i) {
            if (values[i] !== expected[i]) { Qt.exit(10+i); return; }
        }
        if (guide === secondGuide || mouse === secondMouse) { Qt.exit(40); return; }
        if (UserGuideType.UNKNOWN !== undefined || MoueseEventType.RELEASE !== undefined) {
            Qt.exit(41); return;
        }
        console.log("EnumType objects:", typeof UserGuideType.EnumType,
            typeof MoueseEventType.EnumType);
        Qt.exit(0);
    })
}"#,
    );
    engine
        .pin_mut()
        .load_data(&qml, &QUrl::from("qrc:/userguide-type-model-test.qml"));
    assert!(
        created.load(Ordering::Acquire),
        "original types must be creatable"
    );
    assert_eq!(app.pin_mut().exec(), 0, "original enum values must match");
    let mut unsupported = QQmlApplicationEngine::new();
    let rejected = Arc::new(AtomicBool::new(false));
    let seen = Arc::clone(&rejected);
    let _unsupported_connection = unsupported
        .pin_mut()
        .on_object_created(move |_, object, _| {
            seen.store(object.is_null(), Ordering::Release);
        });
    unsupported.pin_mut().load_data(
        &QByteArray::from("import UserGuideTypeModel 2.0\nUserGuideType {}"),
        &QUrl::from("qrc:/userguide-type-model-unsupported-version.qml"),
    );
    assert!(
        rejected.load(Ordering::Acquire),
        "unregistered major version must fail"
    );
    verify_live_type(
        "UserGuideType",
        &[
            ("OVERALL", 0),
            ("KEYFRAME", 1),
            ("TRANSITION_EFFECT", 2),
            ("TRACKING", 3),
            ("FRAMECROP", 4),
            ("REGIONKEYFRAME", 5),
            ("REGIONKEYFRAMESTART", 6),
            ("KEYFRAMESTART", 7),
            ("SUPER_SLOW", 8),
            ("UNKOWN", 9),
        ],
    );
    verify_live_type(
        "MoueseEventType",
        &[
            ("CLICK", 0),
            ("HOVER", 1),
            ("WHEEL", 2),
            ("PRESS", 3),
            ("REALSE", 4),
            ("DRAG", 5),
        ],
    );
    println!(
        "UserGuideTypeModel 1.0: both creatable types, 16 values and unscoped live metadata pass"
    );
}

fn verify_live_type(type_name: &'static str, values: &'static [(&'static str, i32)]) {
    let mut engine = QQmlApplicationEngine::new();
    let checked = Arc::new(AtomicBool::new(false));
    let seen = Arc::clone(&checked);
    let _connection = engine.pin_mut().on_object_created(move |_, object, _| {
        assert!(!object.is_null(), "original type creation failed");
        // SAFETY: Qt emits a live root QObject on this main thread. Its
        // metaobject and enum strings stay live during this synchronous call.
        let metadata = unsafe { &*(&*object.cast::<metaobject::object::QObject>()).metaObject() };
        assert_eq!(
            unsafe { std::ffi::CStr::from_ptr(metadata.className()) }
                .to_str()
                .unwrap(),
            type_name
        );
        assert_eq!(metadata.classInfoCount() - metadata.classInfoOffset(), 1);
        assert_eq!(unsafe { metadata.indexOfClassInfo(c"QML.Element".as_ptr()) }, metadata.classInfoOffset());
        assert_eq!(metadata.propertyCount() - metadata.propertyOffset(), 0);
        assert_eq!(metadata.methodCount() - metadata.methodOffset(), 0);
        assert_eq!(metadata.constructorCount(), 0);
        assert_eq!(metadata.enumeratorCount() - metadata.enumeratorOffset(), 1);
        let enumeration = metadata.enumerator(metadata.enumeratorOffset());
        assert!(!enumeration.isScoped(), "original enum is unscoped");
        assert!(!enumeration.isFlag());
        assert_eq!(
            unsafe { std::ffi::CStr::from_ptr(enumeration.name()) }.to_bytes(),
            b"EnumType"
        );
        assert_eq!(enumeration.keyCount() as usize, values.len());
        for (i, (name, value)) in values.iter().enumerate() {
            let i = i as i32;
            assert_eq!(
                unsafe { std::ffi::CStr::from_ptr(enumeration.key(i)) }
                    .to_str()
                    .unwrap(),
                *name
            );
            assert_eq!(enumeration.value(i), *value);
        }
        seen.store(true, Ordering::Release);
    });
    engine.pin_mut().load_data(
        &QByteArray::from(format!("import UserGuideTypeModel 1.0\n{type_name} {{}}").as_str()),
        &QUrl::from("qrc:/userguide-type-model-live-metadata.qml"),
    );
    assert!(
        checked.load(Ordering::Acquire),
        "live metadata was not checked"
    );
}
