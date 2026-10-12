use crate::adapter::{Screens, Window};
use cxx_qt_lib::{QList, QListElement, QRect};
use window_position_detector::{Position, Rect};

#[cxx_qt::bridge]
pub mod ffi {
    unsafe extern "C++" {
        include!("cxx-qt-lib/qrect.h");
        type QRect = cxx_qt_lib::QRect;
        include!("autocxxgen_ffi.h");
        type ScreenPointer = super::ScreenPointer;
        type ScreenList = cxx_qt_lib::QList<super::ScreenPointer>;
        include!("QtGui/QGuiApplication");
        type QGuiApplication;
        #[Self = "QGuiApplication"]
        fn screens() -> ScreenList;
        #[Self = "QGuiApplication"]
        #[rust_name = "primary_screen"]
        fn primaryScreen() -> *mut QScreen;
        include!("cxx-qt-lib/common.h");
    }
    unsafe extern "C++Qt" {
        include!("QtGui/QWindow");
        #[qobject]
        type QWindow;
        fn geometry(self: &QWindow) -> QRect;
        fn width(self: &QWindow) -> i32;
        fn height(self: &QWindow) -> i32;
        #[rust_name = "set_position"]
        fn setPosition(self: Pin<&mut QWindow>, x: i32, y: i32);
        include!("QtGui/QScreen");
        #[qobject]
        type QScreen;
        fn geometry(self: &QScreen) -> QRect;
    }
    #[namespace = "rust::cxxqtlib1"]
    unsafe extern "C++" {
        #[rust_name = "list_default"]
        fn construct() -> ScreenList;
        #[rust_name = "list_clone"]
        fn construct(list: &ScreenList) -> ScreenList;
        #[rust_name = "list_drop"]
        fn drop(list: &mut ScreenList);
    }
    #[namespace = "rust::cxxqtlib1::qlist"]
    unsafe extern "C++" {
        include!("cxx-qt-lib/core/qlist/qlist_private.h");
        #[rust_name = "list_len"]
        fn qlistLen(list: &ScreenList) -> isize;
        #[rust_name = "list_append"]
        fn qlistAppend(list: &mut ScreenList, value: &ScreenPointer);
        #[rust_name = "list_get"]
        unsafe fn qlistGetUnchecked(list: &ScreenList, pos: isize) -> &ScreenPointer;
        #[rust_name = "list_index"]
        fn qlistIndexOf(list: &ScreenList, value: &ScreenPointer) -> isize;
        #[rust_name = "list_insert"]
        fn qlistInsert(list: &mut ScreenList, pos: isize, value: &ScreenPointer);
        #[rust_name = "list_remove"]
        fn qlistRemove(list: &mut ScreenList, pos: isize);
        #[rust_name = "list_reserve"]
        fn qlistReserve(list: &mut ScreenList, size: isize);
    }
    extern "RustQt" {
        #[qobject]
        #[qml_element]
        type WindowPositionDetector = super::WindowPositionDetectorRust;
        #[qinvokable]
        #[cxx_name = "isWindowCompletelyOnScreen"]
        unsafe fn is_window_completely_on_screen(
            self: &WindowPositionDetector,
            window: *mut QWindow,
        ) -> bool;
        #[qinvokable]
        #[cxx_name = "resetWindowToBestScreen"]
        unsafe fn reset_window_to_best_screen(self: &WindowPositionDetector, window: *mut QWindow);
    }
}

/// Non-owning screen pointer. The generated alias is exactly `QScreen*`.
#[repr(transparent)]
#[derive(Clone, Copy, PartialEq, Eq)]
pub struct ScreenPointer(*mut ffi::QScreen);
// SAFETY: This is a transparent native pointer. CXX checks its generated alias.
unsafe impl cxx::ExternType for ScreenPointer {
    type Id = cxx::type_id!("ScreenPointer");
    type Kind = cxx::kind::Trivial;
}
impl QListElement for ScreenPointer {
    type TypeId = cxx::type_id!("ScreenList");
    fn default() -> QList<Self> {
        ffi::list_default()
    }
    fn clone(list: &QList<Self>) -> QList<Self> {
        ffi::list_clone(list)
    }
    fn drop(list: &mut QList<Self>) {
        ffi::list_drop(list);
    }
    fn clear(list: &mut QList<Self>) {
        while !list.is_empty() {
            ffi::list_remove(list, list.len() - 1);
        }
    }
    fn contains(list: &QList<Self>, value: &Self) -> bool {
        list.iter().any(|screen| screen == value)
    }
    fn append(list: &mut QList<Self>, value: Self) {
        ffi::list_append(list, &value);
    }
    fn append_clone(list: &mut QList<Self>, value: &Self) {
        ffi::list_append(list, value);
    }
    unsafe fn get_unchecked(list: &QList<Self>, pos: isize) -> &Self {
        unsafe { ffi::list_get(list, pos) }
    }
    fn index_of(list: &QList<Self>, value: &Self) -> isize {
        ffi::list_index(list, value)
    }
    fn insert(list: &mut QList<Self>, pos: isize, value: Self) {
        assert!(pos >= 0 && pos <= list.len());
        ffi::list_insert(list, pos, &value);
    }
    fn insert_clone(list: &mut QList<Self>, pos: isize, value: &Self) {
        assert!(pos >= 0 && pos <= list.len());
        ffi::list_insert(list, pos, value);
    }
    fn len(list: &QList<Self>) -> isize {
        ffi::list_len(list)
    }
    fn remove(list: &mut QList<Self>, pos: isize) {
        assert!(pos >= 0 && pos < list.len());
        ffi::list_remove(list, pos);
    }
    fn reserve(list: &mut QList<Self>, size: isize) {
        assert!(size >= 0);
        ffi::list_reserve(list, size);
    }
}
fn rect(rect: QRect) -> Rect {
    Rect {
        left: rect.left(),
        top: rect.top(),
        right: rect.right(),
        bottom: rect.bottom(),
    }
}
struct QtWindow(*mut ffi::QWindow);
impl Window for QtWindow {
    fn geometry(&mut self) -> Rect {
        rect(unsafe { &*self.0 }.geometry())
    }
    fn width(&mut self) -> i32 {
        unsafe { &*self.0 }.width()
    }
    fn height(&mut self) -> i32 {
        unsafe { &*self.0 }.height()
    }
    fn set_position(&mut self, position: Position) {
        unsafe { core::pin::Pin::new_unchecked(&mut *self.0) }.set_position(position.x, position.y);
    }
}
struct QtScreens;
impl Screens for QtScreens {
    type Screen = ScreenPointer;
    fn screens(&mut self) -> Vec<Option<Self::Screen>> {
        ffi::QGuiApplication::screens()
            .iter()
            .map(|s| (!s.0.is_null()).then_some(*s))
            .collect()
    }
    fn primary_screen(&mut self) -> Option<Self::Screen> {
        let screen = ffi::QGuiApplication::primary_screen();
        (!screen.is_null()).then_some(ScreenPointer(screen))
    }
    fn geometry(&mut self, screen: Self::Screen) -> Rect {
        // SAFETY: Only live pointers from Qt's synchronous GUI-thread screen calls reach this method.
        rect(unsafe { &*screen.0 }.geometry())
    }
}

#[derive(Default)]
pub struct WindowPositionDetectorRust;
impl ffi::WindowPositionDetector {
    /// # Safety
    /// A nonnull pointer must refer to a live QWindow on the GUI thread. No
    /// concurrent access or destruction may occur during the call.
    pub unsafe fn is_window_completely_on_screen(&self, window: *mut ffi::QWindow) -> bool {
        // SAFETY: The caller supplies the live GUI-thread window. It is not retained.
        let mut window = (!window.is_null()).then_some(QtWindow(window));
        crate::adapter::is_window_completely_on_screen(window.as_mut(), &mut QtScreens)
    }
    /// # Safety
    /// The pointer has the same requirements as is_window_completely_on_screen.
    pub unsafe fn reset_window_to_best_screen(&self, window: *mut ffi::QWindow) {
        // SAFETY: The caller supplies the live GUI-thread window. It is not retained.
        let mut window = (!window.is_null()).then_some(QtWindow(window));
        crate::adapter::reset_window_to_best_screen(window.as_mut(), &mut QtScreens);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn generated_pointer_list_uses_library_storage_and_operations() {
        let null = ScreenPointer(core::ptr::null_mut());
        let mut list = QList::<ScreenPointer>::default();
        list.reserve(3);
        list.append(null);
        list.insert(0, null);
        assert_eq!(list.len(), 2);
        assert!(list.contains(&null));
        assert_eq!(list.index_of(&null), 0);
        assert!(list.get(1).unwrap().0.is_null());
        let copy = list.clone();
        list.remove(0);
        assert_eq!(list.len(), 1);
        assert_eq!(copy.len(), 2);
        list.clear();
        assert!(list.is_empty());
        assert_eq!(copy.len(), 2);
    }
}
