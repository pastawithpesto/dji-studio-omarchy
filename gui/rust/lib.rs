//! Recovered integer policy for the original `WindowPositionDetector`.
//!
//! Original build: DJI Studio 1.0.0.30839. This safe value interface is an
//! independent Rust adaptation, not the original QObject or C++ ABI. The
//! original QML names, registration and platform integration remain separate.

#![forbid(unsafe_code)]

/// Inclusive signed DWORD endpoints, as used by the recovered QRect bodies.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Rect {
    pub left: i32,
    pub top: i32,
    pub right: i32,
    pub bottom: i32,
}

impl Rect {
    pub const NULL: Self = Self {
        left: 0,
        top: 0,
        right: -1,
        bottom: -1,
    };

    /// Qt6Core.dll 0x1800133c0. Arithmetic wraps before interpretation.
    pub fn width(self) -> i32 {
        self.right.wrapping_sub(self.left).wrapping_add(1)
    }

    /// Qt6Core.dll 0x1800118e0.
    pub fn height(self) -> i32 {
        self.bottom.wrapping_sub(self.top).wrapping_add(1)
    }

    fn is_null(self) -> bool {
        self.right == self.left.wrapping_sub(1) && self.bottom == self.top.wrapping_sub(1)
    }
}

fn adjusted(near: i32, far: i32) -> (i32, i32) {
    let previous = near.wrapping_sub(1);
    if far >= previous {
        (near, far)
    } else {
        (far.wrapping_add(1), previous)
    }
}

/// Qt6Core.dll 0x1801ac1f0 with the original DJI proper argument set to zero.
/// A single zero extent is not a null rectangle.
pub fn contains(screen: Rect, window: Rect) -> bool {
    if screen.is_null() || window.is_null() {
        return false;
    }
    let (sx0, sx1) = adjusted(screen.left, screen.right);
    let (sy0, sy1) = adjusted(screen.top, screen.bottom);
    let (wx0, wx1) = adjusted(window.left, window.right);
    let (wy0, wy1) = adjusted(window.top, window.bottom);
    wx0 >= sx0 && wx1 <= sx1 && wy0 >= sy0 && wy1 <= sy1
}

/// Qt6Core.dll 0x1801abd10. Shared endpoints are permitted. This deliberately
/// preserves the source adjustment rule instead of general min/max sorting.
pub fn intersected(first: Rect, second: Rect) -> Rect {
    if first.is_null() || second.is_null() {
        return Rect::NULL;
    }
    let (ax0, ax1) = adjusted(first.left, first.right);
    let (ay0, ay1) = adjusted(first.top, first.bottom);
    let (bx0, bx1) = adjusted(second.left, second.right);
    let (by0, by1) = adjusted(second.top, second.bottom);
    if ax0 > bx1 || bx0 > ax1 || ay0 > by1 || by0 > ay1 {
        return Rect::NULL;
    }
    Rect {
        left: ax0.max(bx0),
        top: ay0.max(by0),
        right: ax1.min(bx1),
        bottom: ay1.min(by1),
    }
}

/// DJI Studio.exe 0x1413a656f..0x1413a65b6. Exact endpoint equality is a
/// separate success path, including equality with the default null rectangle.
pub fn completely_on_screen(screen: Rect, window: Rect) -> bool {
    contains(screen, window) || intersected(screen, window) == window
}

/// Selector operand policy: sign-extend the wrapped height and width results,
/// then multiply them as signed 64-bit values. Every i32 product fits i64.
pub fn intersection_score(screen: Rect, window: Rect) -> i64 {
    let intersection = intersected(screen, window);
    let height = i64::from(intersection.height());
    let width = i64::from(intersection.width());
    width * height
}

/// Independent Rust value representation of the source selector result.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Selection {
    Screen(usize),
    Primary,
    None,
}

/// DJI Studio.exe 0x1413a63f7..0x1413a6414. Scores start at zero and only a
/// strictly greater signed score replaces the selected screen.
#[derive(Debug, Default)]
pub struct Selector {
    best_score: i64,
    best_index: Option<usize>,
}

impl Selector {
    pub fn consider(&mut self, index: usize, score: i64) {
        if score > self.best_score {
            self.best_score = score;
            self.best_index = Some(index);
        }
    }

    /// The native adapter must query the primary screen only for `Primary`.
    /// A nonempty list containing only null screen pointers still uses it.
    pub fn finish(&self, list_empty: bool) -> Selection {
        match self.best_index {
            Some(index) => Selection::Screen(index),
            None if list_empty => Selection::None,
            None => Selection::Primary,
        }
    }
}

/// Independent safe getter boundary. Calls must remain separate because the
/// original reset method reads dimensions twice and does not cache getters.
pub trait ResetGeometry {
    fn window_width(&mut self) -> i32;
    fn window_height(&mut self) -> i32;
    fn screen_width(&mut self) -> i32;
    fn screen_height(&mut self) -> i32;
    fn screen_x(&mut self) -> i32;
    fn screen_y(&mut self) -> i32;
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Position {
    pub x: i32,
    pub y: i32,
}

/// DJI Studio.exe 0x1413a696f..0x1413a6a47. Every add/subtract wraps to DWORD.
/// Signed halving truncates toward zero. Getter order is part of this contract.
pub fn reset_position(g: &mut impl ResetGeometry) -> Position {
    let first_width = g.window_width();
    let screen_width = g.screen_width();
    let half_width = screen_width.wrapping_sub(first_width) / 2;
    let center_x = half_width.wrapping_add(g.screen_x());
    let first_height = g.window_height();
    let screen_height = g.screen_height();
    let half_height = screen_height.wrapping_sub(first_height) / 2;
    let center_y = half_height.wrapping_add(g.screen_y());
    let lower_x = g.screen_x().max(center_x);
    let lower_y = g.screen_y().max(center_y);
    let second_width = g.window_width();
    let x_difference = g.screen_x().wrapping_sub(second_width);
    let upper_x = x_difference.wrapping_add(g.screen_width());
    let x = lower_x.min(upper_x);
    let second_height = g.window_height();
    let y_difference = g.screen_y().wrapping_sub(second_height);
    let upper_y = g.screen_height().wrapping_add(y_difference);
    Position {
        x,
        y: lower_y.min(upper_y),
    }
}
