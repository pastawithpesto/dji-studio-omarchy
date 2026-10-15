use fpsdetect::{FpsDetect, Signal};

#[test]
fn reference_timeout_vectors() {
    // Original: timer callback 0x1413941a0; elapsed callback 0x141394540.
    let vectors = [
        (0, 0, 0.0, false),
        (1, 0, 0.0, false),
        (1, 800, 800.0, false),
        (1, 801, 801.0, true),
        (60, 12, 12.0, false),
        (60, 13, 13.0, true),
        (1200, 0, 0.0, false),
        (1200, 1, 1.0, true),
        (1, -1, -1.0, false),
    ];
    for (frames, elapsed, mean, duplicate) in vectors {
        let mut detector = FpsDetect::default();
        assert_eq!(detector.fps(), 0);
        for _ in 0..frames {
            detector.after_rendering(|| elapsed);
        }
        assert_eq!(detector.fps(), 0, "fps publishes only on timeout");
        let mut expected = vec![Signal::RenderTime(mean), Signal::FpsChanged(frames)];
        if duplicate {
            expected.push(Signal::RenderTime(mean));
        }
        assert_eq!(detector.timeout(), expected);
        assert_eq!(detector.fps(), frames);
        assert_eq!(
            detector.timeout(),
            vec![Signal::RenderTime(0.0), Signal::FpsChanged(0)]
        );
    }
}

#[test]
fn mixed_durations_and_exact_threshold() {
    let mut detector = FpsDetect::default();
    // 48 frames at 13 ms, 12 frames at 12 ms: 768/60 = 12.8 ms.
    for _ in 0..48 {
        detector.after_rendering(|| 13);
    }
    for _ in 0..12 {
        detector.after_rendering(|| 12);
    }
    assert_eq!(
        detector.timeout(),
        vec![Signal::RenderTime(12.8), Signal::FpsChanged(60)]
    );
    detector.after_rendering(|| 4);
    detector.after_rendering(|| 7);
    assert_eq!(
        detector.timeout(),
        vec![Signal::RenderTime(5.5), Signal::FpsChanged(2)]
    );
}

#[test]
fn one_clock_read_for_each_after_rendering_event() {
    let reads = std::cell::Cell::new(0);
    let mut detector = FpsDetect::default();
    for _ in 0..3 {
        detector.after_rendering(|| {
            reads.set(reads.get() + 1);
            5
        });
    }
    assert_eq!(reads.get(), 3);
    assert_eq!(
        detector.timeout(),
        vec![Signal::RenderTime(5.0), Signal::FpsChanged(3)]
    );
    assert_eq!(reads.get(), 3, "timeout does not read elapsed clock");
}

#[test]
fn reentrant_sample_reloads_fields_and_retains_initial_budget() {
    let mut detector = FpsDetect::default();
    detector.after_rendering(|| 5);
    let first = detector.begin_timeout();
    assert_eq!(first.render_time, 5.0);
    assert_eq!(detector.fps(), 1);
    let nested = detector.begin_timeout();
    assert_eq!(nested.render_time, 0.0);
    assert_eq!(detector.fps(), 0);
    assert_eq!(detector.mean_time(), 0.0);
    // Original subsequent emissions read these current fields after handlers.
    assert_eq!(first.frame_budget, 1000.0);

    detector.after_rendering(|| 0);
    let first = detector.begin_timeout();
    for _ in 0..3 {
        detector.after_rendering(|| 500);
    }
    let nested = detector.begin_timeout();
    assert_eq!(detector.fps(), 3);
    assert_eq!(detector.mean_time(), 500.0);
    assert!(detector.mean_time() <= first.frame_budget * 0.8);
    assert!(detector.mean_time() > nested.frame_budget * 0.8);
}
