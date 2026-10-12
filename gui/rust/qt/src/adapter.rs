//! Ordered native calls for the recovered original methods.

use window_position_detector::{Position, Rect, ResetGeometry, Selection, Selector};

/// Borrowed window operations. Implementations must use the GUI thread.
pub trait Window {
    fn geometry(&mut self) -> Rect;
    fn width(&mut self) -> i32;
    fn height(&mut self) -> i32;
    fn set_position(&mut self, position: Position);
}

/// Native screen calls. The list order and null entries must be retained.
pub trait Screens {
    type Screen: Copy;
    fn screens(&mut self) -> Vec<Option<Self::Screen>>;
    fn primary_screen(&mut self) -> Option<Self::Screen>;
    fn geometry(&mut self, screen: Self::Screen) -> Rect;
}

/// Original `isWindowCompletelyOnScreen(QWindow*)` call order and null branch.
pub fn is_window_completely_on_screen(
    window: Option<&mut impl Window>,
    platform: &mut impl Screens,
) -> bool {
    let Some(window) = window else { return false };
    let screens = platform.screens();
    let geometry = window.geometry();
    screens.into_iter().flatten().any(|screen| {
        window_position_detector::completely_on_screen(platform.geometry(screen), geometry)
    })
}

/// Original selector. Query the primary screen only after a nonempty list has
/// no positive score. Do not remove null entries before the empty-list test.
fn best_screen<S: Screens>(platform: &mut S, geometry: Rect) -> Option<S::Screen> {
    let screens = platform.screens();
    let mut selector = Selector::default();
    for (index, screen) in screens.iter().enumerate() {
        if let Some(screen) = screen {
            selector.consider(
                index,
                window_position_detector::intersection_score(platform.geometry(*screen), geometry),
            );
        }
    }
    match selector.finish(screens.is_empty()) {
        Selection::Screen(index) => screens[index],
        Selection::Primary => platform.primary_screen(),
        Selection::None => None,
    }
}

struct Reset<'a, W> {
    window: &'a mut W,
    screen: Rect,
}

impl<W: Window> ResetGeometry for Reset<'_, W> {
    fn window_width(&mut self) -> i32 {
        self.window.width()
    }
    fn window_height(&mut self) -> i32 {
        self.window.height()
    }
    fn screen_width(&mut self) -> i32 {
        self.screen.width()
    }
    fn screen_height(&mut self) -> i32 {
        self.screen.height()
    }
    fn screen_x(&mut self) -> i32 {
        self.screen.left
    }
    fn screen_y(&mut self) -> i32 {
        self.screen.top
    }
}

/// Original `resetWindowToBestScreen(QWindow*)`. The selected screen geometry
/// is a separate read after selection. Window dimensions are read twice.
pub fn reset_window_to_best_screen(window: Option<&mut impl Window>, platform: &mut impl Screens) {
    let Some(window) = window else { return };
    let geometry = window.geometry();
    let Some(screen) = best_screen(platform, geometry) else {
        return;
    };
    let screen = platform.geometry(screen);
    let position = window_position_detector::reset_position(&mut Reset { window, screen });
    window.set_position(position);
}
