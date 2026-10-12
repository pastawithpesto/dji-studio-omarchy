use std::{cell::RefCell, rc::Rc};
use window_position_detector::{Position, Rect};
use window_position_detector_qt::adapter::{self, Screens, Window};

type Log = Rc<RefCell<Vec<String>>>;
fn rect(x: i32, y: i32, width: i32, height: i32) -> Rect {
    Rect {
        left: x,
        top: y,
        right: x + width - 1,
        bottom: y + height - 1,
    }
}
struct TestWindow {
    log: Log,
    rectangle: Rect,
    widths: Vec<i32>,
    heights: Vec<i32>,
    moved: Option<Position>,
}
impl Window for TestWindow {
    fn geometry(&mut self) -> Rect {
        self.log.borrow_mut().push("window.geometry".into());
        self.rectangle
    }
    fn width(&mut self) -> i32 {
        self.log.borrow_mut().push("window.width".into());
        self.widths.remove(0)
    }
    fn height(&mut self) -> i32 {
        self.log.borrow_mut().push("window.height".into());
        self.heights.remove(0)
    }
    fn set_position(&mut self, position: Position) {
        self.log.borrow_mut().push("window.setPosition".into());
        self.moved = Some(position);
    }
}
struct TestScreens {
    log: Log,
    list: Vec<Option<usize>>,
    rectangles: Vec<Rect>,
    primary: Option<usize>,
    reads: usize,
}
impl Screens for TestScreens {
    type Screen = usize;
    fn screens(&mut self) -> Vec<Option<usize>> {
        self.log.borrow_mut().push("screens".into());
        self.list.clone()
    }
    fn primary_screen(&mut self) -> Option<usize> {
        self.log.borrow_mut().push("primaryScreen".into());
        self.primary
    }
    fn geometry(&mut self, index: usize) -> Rect {
        self.log
            .borrow_mut()
            .push(format!("screen[{index}].geometry"));
        self.reads += 1;
        self.rectangles[index]
    }
}
fn fixture(list: Vec<Option<usize>>, rectangles: Vec<Rect>) -> (TestWindow, TestScreens, Log) {
    let log = Log::default();
    (
        TestWindow {
            log: log.clone(),
            rectangle: rect(10, 20, 40, 20),
            widths: vec![40, 60],
            heights: vec![20, 30],
            moved: None,
        },
        TestScreens {
            log: log.clone(),
            list,
            rectangles,
            primary: None,
            reads: 0,
        },
        log,
    )
}
#[test]
fn null_window_does_not_query_screens() {
    let (_, mut screens, log) = fixture(vec![Some(0)], vec![rect(0, 0, 100, 100)]);
    assert!(!adapter::is_window_completely_on_screen(
        None::<&mut TestWindow>,
        &mut screens
    ));
    adapter::reset_window_to_best_screen(None::<&mut TestWindow>, &mut screens);
    assert!(log.borrow().is_empty());
}
#[test]
fn predicate_queries_list_before_window_and_skips_null_entries() {
    let (mut window, mut screens, log) = fixture(
        vec![None, Some(0), Some(1)],
        vec![rect(0, 0, 100, 100), rect(200, 0, 100, 100)],
    );
    assert!(adapter::is_window_completely_on_screen(
        Some(&mut window),
        &mut screens
    ));
    assert_eq!(
        *log.borrow(),
        ["screens", "window.geometry", "screen[0].geometry"]
    );
}
#[test]
fn predicate_does_not_query_primary_for_empty_or_outside_lists() {
    for list in [vec![], vec![None], vec![Some(0)]] {
        let (mut window, mut screens, log) = fixture(list, vec![rect(200, 0, 100, 100)]);
        screens.primary = Some(0);
        assert!(!adapter::is_window_completely_on_screen(
            Some(&mut window),
            &mut screens
        ));
        assert!(!log.borrow().iter().any(|s| s == "primaryScreen"));
    }
}
#[test]
fn reset_empty_list_does_not_query_primary_or_move() {
    let (mut window, mut screens, log) = fixture(vec![], vec![]);
    adapter::reset_window_to_best_screen(Some(&mut window), &mut screens);
    assert_eq!(*log.borrow(), ["window.geometry", "screens"]);
    assert_eq!(window.moved, None);
}
#[test]
fn reset_nonempty_null_list_queries_primary_lazily() {
    let (mut window, mut screens, log) = fixture(vec![None], vec![rect(-100, 0, 100, 80)]);
    screens.primary = Some(0);
    adapter::reset_window_to_best_screen(Some(&mut window), &mut screens);
    assert_eq!(
        *log.borrow(),
        [
            "window.geometry",
            "screens",
            "primaryScreen",
            "screen[0].geometry",
            "window.width",
            "window.height",
            "window.width",
            "window.height",
            "window.setPosition"
        ]
    );
    assert_eq!(window.moved, Some(Position { x: -70, y: 30 }));
}
#[test]
fn reset_nonempty_without_primary_does_not_move() {
    let (mut window, mut screens, log) = fixture(vec![Some(0)], vec![rect(200, 0, 100, 80)]);
    adapter::reset_window_to_best_screen(Some(&mut window), &mut screens);
    assert_eq!(
        *log.borrow(),
        [
            "window.geometry",
            "screens",
            "screen[0].geometry",
            "primaryScreen"
        ]
    );
    assert_eq!(window.moved, None);
}
#[test]
fn reset_tie_keeps_first_and_rereads_selected_geometry_and_window_sizes() {
    let (mut window, mut screens, log) = fixture(
        vec![Some(0), Some(1)],
        vec![rect(0, 0, 100, 100), rect(0, 0, 200, 200)],
    );
    adapter::reset_window_to_best_screen(Some(&mut window), &mut screens);
    assert_eq!(
        *log.borrow(),
        [
            "window.geometry",
            "screens",
            "screen[0].geometry",
            "screen[1].geometry",
            "screen[0].geometry",
            "window.width",
            "window.height",
            "window.width",
            "window.height",
            "window.setPosition"
        ]
    );
    assert_eq!(window.moved, Some(Position { x: 30, y: 40 }));
    assert!(window.widths.is_empty() && window.heights.is_empty());
}
