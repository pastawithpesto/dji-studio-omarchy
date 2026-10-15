//! Exact signed32 enums from the original BusinessLog metaobject.

#[allow(non_camel_case_types)]
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
#[repr(i32)]
pub enum Stream {
    UNKNOWN = -1,
    APP_LAUNCH = 1,
    DEVICE_CONNECTION = 2,
    PLAYER_PREVIEW = 3,
    DRAFT_SAVE = 4,
    PROJECT_OPEN = 5,
    DRAFT_COVER_UPDATE = 6,
}

pub(crate) const STREAM_KEYS: &[(&str, i32)] = &[
    ("UNKNOWN", Stream::UNKNOWN as i32),
    ("APP_LAUNCH", Stream::APP_LAUNCH as i32),
    ("DEVICE_CONNECTION", Stream::DEVICE_CONNECTION as i32),
    ("PLAYER_PREVIEW", Stream::PLAYER_PREVIEW as i32),
    ("DRAFT_SAVE", Stream::DRAFT_SAVE as i32),
    ("PROJECT_OPEN", Stream::PROJECT_OPEN as i32),
    ("DRAFT_COVER_UPDATE", Stream::DRAFT_COVER_UPDATE as i32),
];

#[allow(non_camel_case_types)]
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
#[repr(i32)]
pub enum Events {
    UNKNOWN = -1,
    STREAM_START = 1,
    MAIN_START = 2,
    PRE_CONFIGURE = 3,
    INIT_APP = 4,
    INIT_ENGINE = 5,
    INIT_SENTRY = 6,
    CONFIGURE_MLT = 7,
    INIT_EVENT_TRACKER = 8,
    CONFIGURE_PROJECT = 9,
    REGISTER_META_TYPE = 10,
    LOAD_EDITOR_QML = 11,
    EDITOR_QML_LOAD_COMPLETED = 12,
    APP_WINDOW_SHOWED = 13,
    PROJECT_FILE_PREPARED = 14,
    PROJECT_DRAMA_PREPARED = 15,
    PROJECT_VERIFIED = 16,
    PROJECT_DRAMA_READ = 17,
    PROJECT_RESOURCE_READY = 18,
    PROJECT_ACTIVATED = 19,
    STREAM_END = 20,
    STREAM_TIMEOUT = 21,
    STREAM_CANCEL = 22,
}

pub(crate) const EVENTS_KEYS: &[(&str, i32)] = &[
    ("UNKNOWN", Events::UNKNOWN as i32),
    ("STREAM_START", Events::STREAM_START as i32),
    ("MAIN_START", Events::MAIN_START as i32),
    ("PRE_CONFIGURE", Events::PRE_CONFIGURE as i32),
    ("INIT_APP", Events::INIT_APP as i32),
    ("INIT_ENGINE", Events::INIT_ENGINE as i32),
    ("INIT_SENTRY", Events::INIT_SENTRY as i32),
    ("CONFIGURE_MLT", Events::CONFIGURE_MLT as i32),
    ("INIT_EVENT_TRACKER", Events::INIT_EVENT_TRACKER as i32),
    ("CONFIGURE_PROJECT", Events::CONFIGURE_PROJECT as i32),
    ("REGISTER_META_TYPE", Events::REGISTER_META_TYPE as i32),
    ("LOAD_EDITOR_QML", Events::LOAD_EDITOR_QML as i32),
    (
        "EDITOR_QML_LOAD_COMPLETED",
        Events::EDITOR_QML_LOAD_COMPLETED as i32,
    ),
    ("APP_WINDOW_SHOWED", Events::APP_WINDOW_SHOWED as i32),
    (
        "PROJECT_FILE_PREPARED",
        Events::PROJECT_FILE_PREPARED as i32,
    ),
    (
        "PROJECT_DRAMA_PREPARED",
        Events::PROJECT_DRAMA_PREPARED as i32,
    ),
    ("PROJECT_VERIFIED", Events::PROJECT_VERIFIED as i32),
    ("PROJECT_DRAMA_READ", Events::PROJECT_DRAMA_READ as i32),
    (
        "PROJECT_RESOURCE_READY",
        Events::PROJECT_RESOURCE_READY as i32,
    ),
    ("PROJECT_ACTIVATED", Events::PROJECT_ACTIVATED as i32),
    ("STREAM_END", Events::STREAM_END as i32),
    ("STREAM_TIMEOUT", Events::STREAM_TIMEOUT as i32),
    ("STREAM_CANCEL", Events::STREAM_CANCEL as i32),
];
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn all_values_match_the_original_metadata_fixture() {
        let mut stream = Vec::new();
        let mut events = Vec::new();
        for line in include_str!("../tests/reference-values.tsv").lines() {
            let fields: Vec<_> = line.split('\t').collect();
            assert_eq!(fields.len(), 3);
            let entry = (fields[1], fields[2].parse::<i32>().unwrap());
            match fields[0] {
                "Stream" => stream.push(entry),
                "Events" => events.push(entry),
                other => panic!("unknown original enum {other}"),
            }
        }
        assert_eq!(STREAM_KEYS, stream);
        assert_eq!(EVENTS_KEYS, events);
        assert_eq!(stream.len() + events.len(), 30);
        assert!(
            !stream
                .iter()
                .chain(events.iter())
                .any(|(_, value)| *value == 0)
        );
        assert_eq!(std::mem::size_of::<Stream>(), 4);
        assert_eq!(std::mem::align_of::<Stream>(), 4);
        assert_eq!(std::mem::size_of::<Events>(), 4);
        assert_eq!(std::mem::align_of::<Events>(), 4);
    }
}
