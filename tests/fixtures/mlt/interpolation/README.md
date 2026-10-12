# Original MLT interpolation bit fixtures

These fixtures preserve raw input and output binary64 bits observed from DJI Studio 1.0.0.30839 `mltframework-win.dll`, SHA-256 `59a83da5816e60a196289801f877b2740f9b3f5ff7b22adf638045ea2aa8e05c`, running under Wine 11.17. They do not establish Windows behavior.

`wine-initial-reference.jsonl` has nine rows each for `mlt_circular_ease_in` and `mlt_cublic_linear_ease_in_out`. Its source is reference-packet `WINE-SHORT-PREFIX.jsonl`, manifest SHA-256 `161dde5718d667e458f2f5b269627590b744e818d3c8e3d09e560b6cd0b41cf6`. The two functions' rows match the later interpolation replay.

`wine-interpolation-extension.jsonl` has nine rows each for `mlt_discrete_interpolation`, `mlt_linear_interpolation`, and `mlt_smooth_interpolation`. These exact rows come from `reference-interpolation/INTERPOLATION-CASES.json`; its packet manifest SHA-256 is `aff5bd1110eafd1b1f89c6dadfa622df4623cea621f11bd60844956ab7766fec`.

The adapter tests compare 44 outputs by `f64::to_bits()`: eight circular-in inputs with `1-t*t >= 0`, plus nine rows for each other function. The remaining circular input has a negative radicand. Review009 limits that output to a Wine observation, so the test preserves the row but excludes it from numeric contract assertions.

The Rust interfaces are independent pure `f64` adapters. They do not claim original C/C++ prototypes. The circular numeric contract is limited to finite inputs with nonnegative radicand. The helper in `mlt_cublic_linear_ease_in_out` has no added iteration cap. Nonfinite behavior, exception flags, Windows runtime behavior, and all other direct easing names remain unclaimed.
