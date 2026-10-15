use cxx_qt::{ConnectionType, CxxQtType, QMetaObjectConnectionGuard};
use std::{
    pin::Pin,
    sync::{
        Arc, Mutex,
        atomic::{AtomicBool, Ordering},
    },
};

#[cxx_qt::bridge]
pub(crate) mod ffi {
    unsafe extern "C++" {
        include!("QtQuick/QQuickItem");
        type QQuickItem;
        include!("QtCore/QElapsedTimer");
        type QElapsedTimer;
        type qint64 = cxx_qt_lib::qint64;
        fn start(self: Pin<&mut QElapsedTimer>);
        fn elapsed(self: &QElapsedTimer) -> qint64;
        include!("cxx-qt-lib/common.h");
        #[namespace = "rust::cxxqtlib1"]
        #[rust_name = "new_elapsed_timer"]
        fn make_unique() -> UniquePtr<QElapsedTimer>;
        #[namespace = "rust::cxxqtlib1"]
        #[rust_name = "new_timer"]
        unsafe fn make_unique(parent: *mut FpsDetect) -> UniquePtr<QTimer>;
    }
    unsafe extern "C++Qt" {
        include!("QtCore/QTimer");
        #[qobject]
        type QTimer;
        fn start(self: Pin<&mut QTimer>, interval: i32);
        #[qsignal]
        #[qsignal_shared]
        pub(self) fn timeout(self: Pin<&mut QTimer>);
        include!("QtQuick/QQuickWindow");
        #[qobject]
        type QQuickWindow;
        #[qsignal]
        #[qsignal_shared]
        #[rust_name = "before_rendering"]
        fn beforeRendering(self: Pin<&mut QQuickWindow>);
        #[qsignal]
        #[qsignal_shared]
        #[rust_name = "after_rendering"]
        fn afterRendering(self: Pin<&mut QQuickWindow>);
    }
    unsafe extern "RustQt" {
        #[qobject]
        #[base = QQuickItem]
        #[qml_element]
        #[namespace = "FpsDetect"]
        #[qproperty(i32, fps, READ = fps, NOTIFY = fps_changed)]
        type FpsDetect = super::FpsDetectRust;
        fn fps(self: &FpsDetect) -> i32;
        #[qsignal]
        #[qsignal_shared]
        #[cxx_name = "fpsChanged"]
        fn fps_changed(self: Pin<&mut FpsDetect>, fps: i32);
        #[qsignal]
        #[qsignal_shared]
        #[cxx_name = "renderTime"]
        fn render_time(self: Pin<&mut FpsDetect>, time: f64);
        #[qsignal]
        #[qsignal_shared]
        #[inherit]
        #[cxx_name = "windowChanged"]
        unsafe fn window_changed(self: Pin<&mut FpsDetect>, window: *mut QQuickWindow);
        #[inherit]
        fn window(self: &FpsDetect) -> *mut QQuickWindow;
    }
    impl cxx_qt::Initialize for FpsDetect {}
}

/// Feature-only fixture: arm a native subscriber after QML handler installation.
#[cfg(feature = "test-fixture")]
pub(crate) unsafe fn arm_deferred_destroy(object: *mut cxx_qt::QObject) {
    // SAFETY: public Qt qobject_cast checks the actual native metatype and
    // adjusts the base pointer. The test passes its live dynamic detector.
    let object = unsafe { crate::test_support::ffi::cast_test_detector(object).as_mut() }
        .expect("test detector cast");
    let mut object = unsafe { Pin::new_unchecked(object) };
    let guard = object.as_mut().on_render_time(|_, _| {
        // QML's destroy() handler has returned before Qt calls this functor.
        // Qt 6.11.2 qcoreevent.h:105 defines DeferredDelete as 52.
        unsafe {
            crate::test_support::ffi::QCoreApplication::fps_test_flush(std::ptr::null_mut(), 52)
        };
    });
    object.rust_mut().connections.push(guard);
}

// The unsafe callback uses an opaque foreign receiver, never a Rust payload
// reference across handlers. Reject a future binding representation change.
const _: () = {
    assert!(std::mem::size_of::<ffi::FpsDetect>() == 0);
    assert!(std::mem::align_of::<ffi::FpsDetect>() == 1);
};

struct FrameState {
    detector: fpsdetect::FpsDetect,
    clock: cxx::UniquePtr<ffi::QElapsedTimer>,
}
// SAFETY: QElapsedTimer has no QObject affinity. The mutex serializes all calls.
// No reference to its native value escapes the lock.
unsafe impl Send for FrameState {}

impl Default for FrameState {
    fn default() -> Self {
        Self {
            detector: Default::default(),
            clock: ffi::new_elapsed_timer(),
        }
    }
}

/// The timer callback runs only on the creating GUI thread.
struct TimerReceiver {
    object: *mut ffi::FpsDetect,
    owner_thread: std::thread::ThreadId,
    alive: Arc<AtomicBool>,
}
// SAFETY: QTimer AutoConnection executes on the timer's creating GUI thread.
// The owner disconnects this callback and deletes its timer during destruction.
unsafe impl Send for TimerReceiver {}
// SAFETY: Shared callbacks read immutable receiver data. The thread check
// rejects pointer use outside the GUI thread. The flag checks owner lifetime.
unsafe impl Sync for TimerReceiver {}
impl TimerReceiver {
    fn publish(&self) {
        assert_eq!(
            self.owner_thread,
            std::thread::current().id(),
            "timer thread"
        );
        if !self.alive.load(Ordering::Acquire) {
            return;
        }
        // SAFETY: This callback has the same GUI thread and lifetime as its owner.
        unsafe {
            Pin::new_unchecked(&mut *self.object).publish();
        }
    }
}

pub struct FpsDetectRust {
    // Disconnect handlers before deleting their Qt sender or dropping state.
    connections: Vec<QMetaObjectConnectionGuard>,
    timer: cxx::UniquePtr<ffi::QTimer>,
    frames: Arc<Mutex<FrameState>>,
    alive: Arc<AtomicBool>,
}
impl Default for FpsDetectRust {
    fn default() -> Self {
        Self {
            connections: Vec::new(),
            timer: cxx::UniquePtr::null(),
            frames: Arc::new(Mutex::new(FrameState::default())),
            alive: Arc::new(AtomicBool::new(true)),
        }
    }
}
impl Drop for FpsDetectRust {
    fn drop(&mut self) {
        // Set this before connection guards and the child timer are destroyed.
        self.alive.store(false, Ordering::Release);
    }
}

impl ffi::FpsDetect {
    fn fps(&self) -> i32 {
        self.rust()
            .frames
            .lock()
            .expect("frame lock")
            .detector
            .fps()
    }
    fn publish(mut self: Pin<&mut Self>) {
        // These clones keep no owner borrow across a user signal handler.
        let frames = Arc::clone(&self.rust().frames);
        let alive = Arc::clone(&self.rust().alive);
        let sample = frames.lock().expect("frame lock").detector.begin_timeout();
        // Release the frame lock before calling user signal handlers.
        self.as_mut().render_time(sample.render_time);
        if !alive.load(Ordering::Acquire) {
            return;
        }
        // The original reads each field again after the preceding handler.
        let fps = frames.lock().expect("frame lock").detector.fps();
        self.as_mut().fps_changed(fps);
        if !alive.load(Ordering::Acquire) {
            return;
        }
        let mean = frames.lock().expect("frame lock").detector.mean_time();
        if mean > sample.frame_budget * 0.8 {
            self.as_mut().render_time(mean);
        }
    }
    fn attach_window(mut self: Pin<&mut Self>) {
        let window = self.window();
        // SAFETY: QQuickItem::window() gives a live, non-owning window pointer.
        let Some(window) = (unsafe { window.as_mut() }) else {
            return;
        };
        let mut window = unsafe { Pin::new_unchecked(window) };
        let frames = Arc::clone(&self.rust().frames);
        let before = window.as_mut().connect_before_rendering(
            move |_| {
                frames.lock().expect("frame lock").clock.pin_mut().start();
            },
            ConnectionType::AutoConnection,
        );
        let frames = Arc::clone(&self.rust().frames);
        let after = window.as_mut().connect_after_rendering(
            move |_| {
                let mut frames = frames.lock().expect("frame lock");
                let FrameState { detector, clock } = &mut *frames;
                detector.after_rendering(|| clock.elapsed().into());
            },
            ConnectionType::DirectConnection,
        );
        // The original callback adds connections on each non-null window change.
        self.as_mut().rust_mut().connections.extend([before, after]);
    }
}
impl cxx_qt::Initialize for ffi::FpsDetect {
    fn initialize(mut self: Pin<&mut Self>) {
        let owner_thread = std::thread::current().id();
        let receiver = TimerReceiver {
            object: unsafe { self.as_mut().get_unchecked_mut() as *mut Self },
            owner_thread,
            alive: Arc::clone(&self.rust().alive),
        };
        // SAFETY: The parent is the live, pinned QQuickItem under construction.
        // Rust deletes the child before the QObject base destructor runs.
        let timer = unsafe { ffi::new_timer(receiver.object) };
        self.as_mut().rust_mut().timer = timer;
        let timer_connection = self
            .as_mut()
            .rust_mut()
            .timer
            .pin_mut()
            .on_timeout(move |_| {
                receiver.publish();
            });
        let window_connection = self.as_mut().on_window_changed(move |mut object, _| {
            assert_eq!(owner_thread, std::thread::current().id(), "window thread");
            object.as_mut().attach_window();
        });
        self.as_mut()
            .rust_mut()
            .connections
            .extend([timer_connection, window_connection]);
        self.as_mut().rust_mut().timer.pin_mut().start(1000);
    }
}
