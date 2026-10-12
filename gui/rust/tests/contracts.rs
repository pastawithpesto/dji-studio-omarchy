//! Literal cases from the independently approved method and QtCore contracts.
//! These are static-policy oracles, not Windows or native Qt observations.

use window_position_detector::{
    Position, Rect, ResetGeometry, Selection, Selector, completely_on_screen, contains,
    intersected, intersection_score, reset_position,
};

const fn rect(left: i32, top: i32, right: i32, bottom: i32) -> Rect {
    Rect {
        left,
        top,
        right,
        bottom,
    }
}
const SCREEN: Rect = rect(0, 0, 99, 79);

macro_rules! rectangle_case {
    ($name:ident, $screen:expr, $window:expr, $contained:expr, $intersection:expr, $complete:expr, $score:expr) => {
        #[test]
        fn $name() {
            assert_eq!(contains($screen, $window), $contained);
            assert_eq!(intersected($screen, $window), $intersection);
            assert_eq!(completely_on_screen($screen, $window), $complete);
            assert_eq!(intersection_score($screen, $window), $score);
        }
    };
}

rectangle_case!(equal, SCREEN, SCREEN, true, SCREEN, true, 8000);
rectangle_case!(
    inside,
    SCREEN,
    rect(10, 20, 29, 39),
    true,
    rect(10, 20, 29, 39),
    true,
    400
);
rectangle_case!(
    shared_edge,
    SCREEN,
    rect(99, 70, 100, 79),
    false,
    rect(99, 70, 99, 79),
    false,
    10
);
rectangle_case!(
    disjoint,
    SCREEN,
    rect(100, 0, 109, 9),
    false,
    Rect::NULL,
    false,
    0
);
rectangle_case!(
    negative_origin,
    rect(-100, -80, -1, -1),
    rect(-90, -70, -81, -61),
    true,
    rect(-90, -70, -81, -61),
    true,
    100
);
rectangle_case!(
    reversed_window,
    SCREEN,
    rect(10, 10, 0, 0),
    true,
    rect(1, 1, 9, 9),
    true,
    81
);
rectangle_case!(
    reversed_screen,
    rect(100, 80, -1, -1),
    SCREEN,
    true,
    SCREEN,
    true,
    8000
);
rectangle_case!(
    one_zero_width,
    SCREEN,
    rect(10, 10, 9, 19),
    true,
    rect(10, 10, 9, 19),
    true,
    0
);
rectangle_case!(
    one_zero_height,
    SCREEN,
    rect(10, 10, 19, 9),
    true,
    rect(10, 10, 19, 9),
    true,
    0
);
rectangle_case!(
    shifted_null,
    SCREEN,
    rect(10, 10, 9, 9),
    false,
    Rect::NULL,
    false,
    0
);
rectangle_case!(
    default_null_equality,
    SCREEN,
    Rect::NULL,
    false,
    Rect::NULL,
    true,
    0
);
rectangle_case!(
    null_screen_and_window,
    Rect::NULL,
    Rect::NULL,
    false,
    Rect::NULL,
    true,
    0
);
rectangle_case!(
    signed_negative_score,
    rect(0, 0, i32::MAX, 0),
    rect(0, 0, i32::MAX, 0),
    true,
    rect(0, 0, i32::MAX, 0),
    true,
    -2147483648
);
rectangle_case!(
    two_negative_extents,
    rect(0, 0, i32::MAX, i32::MAX),
    rect(0, 0, i32::MAX, i32::MAX),
    true,
    rect(0, 0, i32::MAX, i32::MAX),
    true,
    4611686018427387904
);
rectangle_case!(
    near_minus_one_wrap,
    rect(i32::MIN, 0, i32::MAX, 9),
    rect(i32::MIN, 1, i32::MAX, 2),
    true,
    rect(i32::MIN, 1, i32::MAX, 2),
    true,
    0
);

#[test]
fn dimensions_wrap_before_signed_interpretation() {
    assert_eq!(rect(0, 0, i32::MAX, i32::MAX).width(), i32::MIN);
    assert_eq!(rect(0, 0, i32::MAX, i32::MAX).height(), i32::MIN);
    assert_eq!(rect(i32::MIN, 0, i32::MAX, 0).width(), 0);
    assert_eq!(Rect::NULL.width(), 0);
    assert_eq!(Rect::NULL.height(), 0);
}

#[test]
fn empty_list_and_nonpositive_scores_keep_distinct_fallbacks() {
    let mut selector = Selector::default();
    assert_eq!(selector.finish(true), Selection::None);
    assert_eq!(selector.finish(false), Selection::Primary);
    selector.consider(0, -2147483648);
    selector.consider(1, 0);
    assert_eq!(selector.finish(false), Selection::Primary);
}

#[test]
fn positive_ties_keep_original_index_and_signed_order() {
    let mut selector = Selector::default();
    selector.consider(2, 100);
    selector.consider(3, 100);
    selector.consider(4, 99);
    assert_eq!(selector.finish(false), Selection::Screen(2));
    selector.consider(5, 101);
    selector.consider(6, i64::MIN);
    assert_eq!(selector.finish(false), Selection::Screen(5));
    selector.consider(7, 4611686018427387904);
    selector.consider(8, 4611686018427387904);
    assert_eq!(selector.finish(false), Selection::Screen(7));
}

#[test]
fn adjacent_screens_keep_first_positive_overlap() {
    let window = rect(50, 0, 149, 9);
    let mut selector = Selector::default();
    selector.consider(0, intersection_score(rect(0, 0, 99, 99), window));
    selector.consider(1, intersection_score(rect(100, 0, 199, 99), window));
    assert_eq!(selector.finish(false), Selection::Screen(0));
}

struct Geometry {
    screen: Rect,
    widths: [i32; 2],
    heights: [i32; 2],
    width_reads: usize,
    height_reads: usize,
    calls: Vec<&'static str>,
}

impl Geometry {
    fn new(screen: Rect, width: i32, height: i32) -> Self {
        Self {
            screen,
            widths: [width; 2],
            heights: [height; 2],
            width_reads: 0,
            height_reads: 0,
            calls: Vec::new(),
        }
    }
}

impl ResetGeometry for Geometry {
    fn window_width(&mut self) -> i32 {
        self.calls.push("window.width");
        let value = self.widths[self.width_reads];
        self.width_reads += 1;
        value
    }
    fn window_height(&mut self) -> i32 {
        self.calls.push("window.height");
        let value = self.heights[self.height_reads];
        self.height_reads += 1;
        value
    }
    fn screen_width(&mut self) -> i32 {
        self.calls.push("screen.width");
        self.screen.width()
    }
    fn screen_height(&mut self) -> i32 {
        self.calls.push("screen.height");
        self.screen.height()
    }
    fn screen_x(&mut self) -> i32 {
        self.calls.push("screen.x");
        self.screen.left
    }
    fn screen_y(&mut self) -> i32 {
        self.calls.push("screen.y");
        self.screen.top
    }
}

macro_rules! reset_case {
    ($name:ident, $screen:expr, $width:expr, $height:expr, $x:expr, $y:expr) => {
        #[test]
        fn $name() {
            let mut geometry = Geometry::new($screen, $width, $height);
            assert_eq!(reset_position(&mut geometry), Position { x: $x, y: $y });
        }
    };
}

reset_case!(center, SCREEN, 20, 10, 40, 35);
reset_case!(
    reset_negative_origin,
    rect(-1920, -1080, -1, -1),
    1000,
    600,
    -1460,
    -840
);
reset_case!(
    oversized_window,
    rect(100, 200, 899, 799),
    1001,
    701,
    -101,
    99
);
reset_case!(negative_odd_difference, SCREEN, 103, 83, -3, -3);
reset_case!(
    maximum_origin,
    rect(i32::MAX, i32::MAX, i32::MAX, i32::MAX),
    3,
    3,
    2147483645,
    2147483645
);
reset_case!(
    minimum_origin_wrap,
    rect(i32::MIN, i32::MIN, i32::MIN, i32::MIN),
    3,
    3,
    2147483646,
    2147483646
);
reset_case!(
    subtraction_wrap,
    rect(0, 0, 0, 0),
    i32::MIN,
    i32::MIN,
    -2147483647,
    -2147483647
);

#[test]
fn reset_keeps_order_and_rereads_window_dimensions() {
    let mut geometry = Geometry::new(SCREEN, 10, 10);
    geometry.widths[1] = 90;
    geometry.heights[1] = 70;
    assert_eq!(reset_position(&mut geometry), Position { x: 10, y: 10 });
    assert_eq!(
        geometry.calls,
        [
            "window.width",
            "screen.width",
            "screen.x",
            "window.height",
            "screen.height",
            "screen.y",
            "screen.x",
            "screen.y",
            "window.width",
            "screen.x",
            "screen.width",
            "window.height",
            "screen.y",
            "screen.height",
        ]
    );
}
