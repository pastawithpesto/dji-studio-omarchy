//! Original FpsDetect arithmetic. Qt supplies elapsed milliseconds and events.

/// Event arguments and order from the original timeout callback.
#[derive(Clone, Copy, Debug, PartialEq)]
pub enum Signal {
    RenderTime(f64),
    FpsChanged(i32),
}

/// Values retained before the original first signal emission.
#[derive(Clone, Copy, Debug)]
pub struct TimeoutSample {
    pub render_time: f64,
    pub frame_budget: f64,
}

/// Original fields at offsets +0x20, +0x28, +0x30, +0x48, and +0x50.
#[derive(Default, Debug)]
pub struct FpsDetect {
    fps: i32,
    mean_time: f64,
    frame_count: i32,
    last_time: f64,
    elapsed_sum: f64,
}

impl FpsDetect {
    pub fn fps(&self) -> i32 {
        self.fps
    }

    pub fn mean_time(&self) -> f64 {
        self.mean_time
    }

    /// Original afterRendering callback. Qt's elapsed() returns whole milliseconds.
    pub fn after_rendering(&mut self, elapsed_ms: impl FnOnce() -> i64) {
        self.frame_count = self.frame_count.wrapping_add(1);
        self.last_time = elapsed_ms() as f64;
        self.elapsed_sum = self.last_time + self.elapsed_sum;
    }

    /// Update sample fields before any user signal handler can run.
    pub fn begin_timeout(&mut self) -> TimeoutSample {
        self.fps = self.frame_count;
        self.mean_time = if self.frame_count == 0 {
            0.0
        } else {
            self.elapsed_sum / f64::from(self.frame_count)
        };
        self.frame_count = 0;
        self.elapsed_sum = 0.0;
        let frame_budget = if self.fps == 0 {
            0.0
        } else {
            f64::from(1000 / self.fps)
        };
        TimeoutSample {
            render_time: self.mean_time,
            frame_budget,
        }
    }

    /// Signal sequence for a sample without reentrant handlers.
    /// The Qt adapter reads current fields between actual signal emissions.
    pub fn timeout(&mut self) -> Vec<Signal> {
        let sample = self.begin_timeout();
        let mut signals = vec![
            Signal::RenderTime(sample.render_time),
            Signal::FpsChanged(self.fps),
        ];
        if self.mean_time > sample.frame_budget * 0.8 {
            signals.push(Signal::RenderTime(self.mean_time));
        }
        signals
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn original_signed_counter_wrap() {
        let mut detector = FpsDetect {
            frame_count: i32::MAX,
            ..Default::default()
        };
        detector.after_rendering(|| 1);
        assert_eq!(
            detector.timeout(),
            vec![
                Signal::RenderTime(1.0 / f64::from(i32::MIN)),
                Signal::FpsChanged(i32::MIN)
            ]
        );
    }
}
