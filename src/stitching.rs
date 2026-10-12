//! Checked scalar leaves for the reviewed DJI stitching shader equations.
//!
//! These functions use caller-supplied samples. They do not sample textures,
//! construct seam masks, select shader variants, or model a camera pipeline.

const MAX_DIMENSION: u32 = 16_777_216;
const MAX_BAND_STEP: i32 = 16_777_216;

/// Errors from the independent checked policy around the recovered equations.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum KernelError {
    InvalidDimensions,
    InvalidDomain,
    NonFiniteInput,
    NonFiniteResult,
}

/// Inputs for the supplied-sample linear blend kernel.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct LinearBlendInput {
    pub uv_y: f32,
    pub height: u32,
    pub mask_right: f32,
    pub mask_left: f32,
    pub left: [f32; 4],
    pub right: [f32; 4],
}

/// Inputs for the supplied-sample band weight kernel.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct BandWeightInput {
    pub current_y: f32,
    pub height: u32,
    pub mask_right: f32,
    pub mask_left: f32,
    pub band_step: i32,
}

/// Left-side weights for the low and high frequency bands.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct BandWeights {
    pub low_left: f32,
    pub high_left: f32,
}

/// Supplied samples for the four-component band blend kernel.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct BandSamples {
    pub left: [f32; 4],
    pub right: [f32; 4],
    pub low_left: [f32; 4],
    pub low_right: [f32; 4],
}

/// Coordinates returned by the buffer-band coordinate kernel.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct BandBufferCoordinates {
    pub mask_index: usize,
    pub current_y: f32,
}

/// Errors from the exact scalar AI dimension predicate.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum AiDimensionError {
    NonPositiveInput,
    SizeMismatch,
}

fn validate_height(height: u32) -> Result<(), KernelError> {
    if height == 0 || height > MAX_DIMENSION {
        return Err(KernelError::InvalidDimensions);
    }
    Ok(())
}

fn validate_size(size: [u32; 2]) -> Result<(), KernelError> {
    if size
        .into_iter()
        .any(|dimension| dimension == 0 || dimension > MAX_DIMENSION)
    {
        return Err(KernelError::InvalidDimensions);
    }
    Ok(())
}

fn require_finite(value: f32) -> Result<(), KernelError> {
    if value.is_finite() {
        Ok(())
    } else {
        Err(KernelError::NonFiniteInput)
    }
}

fn require_finite_slice(values: &[f32]) -> Result<(), KernelError> {
    for &value in values {
        require_finite(value)?;
    }
    Ok(())
}

fn require_finite_result(values: &[f32]) -> Result<(), KernelError> {
    if values.iter().all(|value| value.is_finite()) {
        Ok(())
    } else {
        Err(KernelError::NonFiniteResult)
    }
}

fn left_weight(current_y: f32, start: f32, stop: f32) -> f32 {
    if current_y < start {
        1.0
    } else if current_y > stop {
        0.0
    } else {
        let distance = current_y - start;
        let span = stop - start;
        1.0 - distance / span
    }
}

/// Blend two supplied RGBA samples by the reviewed linear seam equation.
pub fn linear_blend_sample(input: LinearBlendInput) -> Result<[f32; 4], KernelError> {
    validate_height(input.height)?;
    require_finite(input.uv_y)?;
    require_finite(input.mask_right)?;
    require_finite(input.mask_left)?;
    require_finite_slice(&input.left)?;
    require_finite_slice(&input.right)?;
    if !(0.0..=1.0).contains(&input.uv_y) {
        return Err(KernelError::InvalidDomain);
    }

    let start = input.mask_right;
    let stop = input.mask_left;
    let len = stop - start;
    let half_span = len * (1.0 - 0.5);
    let shrink = half_span * 0.5;
    let maximum = (input.height - 1) as f32;
    let start = (start + shrink).clamp(0.0, maximum);
    let mut stop = (stop - shrink).clamp(0.0, maximum);
    if stop <= start {
        stop = start + 1.0;
    }

    let current_y = input.uv_y * input.height as f32;
    let left_weight = left_weight(current_y, start, stop);
    let right_weight = 1.0 - left_weight;
    let mut result = [0.0; 4];
    for (channel, output) in result.iter_mut().enumerate() {
        let left_part = input.left[channel] * (1.0 - right_weight);
        let right_part = input.right[channel] * right_weight;
        *output = left_part + right_part;
    }
    require_finite_result(&result)?;
    Ok(result)
}

/// Compute supplied-sample low and high band weights.
pub fn band_weights_at(input: BandWeightInput) -> Result<BandWeights, KernelError> {
    validate_height(input.height)?;
    require_finite(input.current_y)?;
    require_finite(input.mask_right)?;
    require_finite(input.mask_left)?;
    if !(0..=MAX_BAND_STEP).contains(&input.band_step) {
        return Err(KernelError::InvalidDomain);
    }
    let start = input.mask_right;
    let stop = input.mask_left;
    let len = stop - start;
    let len_new = (len * 0.5).floor();
    let len_low = len_new.min(110.0);
    let len_high = len_new.min(input.band_step as f32);
    let maximum = (input.height - 1) as f32;

    let weight_for_level = |len_level: f32| {
        let offset = (len - len_level) * 0.5;
        let level_start = (start + offset).clamp(0.0, maximum);
        let mut level_stop = (stop - offset).clamp(0.0, maximum);
        if level_stop <= level_start {
            level_stop = level_start + 1.0;
        }
        left_weight(input.current_y, level_start, level_stop)
    };

    let weights = BandWeights {
        low_left: weight_for_level(len_low),
        high_left: weight_for_level(len_high),
    };
    require_finite_result(&[weights.low_left, weights.high_left])?;
    Ok(weights)
}

/// Compute the clamped buffer index and half-texel-adjusted y coordinate.
pub fn band_buffer_coordinates(
    uv: [f32; 2],
    size: [u32; 2],
) -> Result<BandBufferCoordinates, KernelError> {
    validate_size(size)?;
    require_finite_slice(&uv)?;
    if uv
        .into_iter()
        .any(|component| !(0.0..=1.0).contains(&component))
    {
        return Err(KernelError::InvalidDomain);
    }

    let scaled_x = uv[0] * size[0] as f32;
    let last_index = (size[0] - 1) as usize;
    let mask_index = if scaled_x >= last_index as f32 {
        last_index
    } else {
        scaled_x.trunc() as usize
    };
    let current_y = uv[1] * size[1] as f32 - 0.5;
    require_finite_result(&[current_y])?;
    Ok(BandBufferCoordinates {
        mask_index,
        current_y,
    })
}

/// Blend four supplied samples with the reviewed low/high frequency equation.
pub fn band_blend_sample(
    samples: BandSamples,
    weights: BandWeights,
) -> Result<[f32; 4], KernelError> {
    require_finite_slice(&samples.left)?;
    require_finite_slice(&samples.right)?;
    require_finite_slice(&samples.low_left)?;
    require_finite_slice(&samples.low_right)?;
    require_finite(weights.low_left)?;
    require_finite(weights.high_left)?;
    if !(0.0..=1.0).contains(&weights.low_left) || !(0.0..=1.0).contains(&weights.high_left) {
        return Err(KernelError::InvalidDomain);
    }

    let low_right_weight = 1.0 - weights.low_left;
    let high_right_weight = 1.0 - weights.high_left;
    let low_left_weight = 1.0 - low_right_weight;
    let high_left_weight = 1.0 - high_right_weight;
    let mut result = [0.0; 4];
    for (channel, output) in result.iter_mut().enumerate() {
        let high_left = samples.left[channel] - samples.low_left[channel];
        let high_right = samples.right[channel] - samples.low_right[channel];
        let low_mix = samples.low_left[channel] * low_left_weight
            + samples.low_right[channel] * low_right_weight;
        let high_mix = high_left * high_left_weight + high_right * high_right_weight;
        let amplified_high = 1.8 * high_mix;
        *output = low_mix + amplified_high;
    }
    require_finite_result(&result)?;
    Ok(result)
}

const GAUSSIAN_5X5: [f32; 25] = [
    0.002969, 0.013306, 0.021938, 0.013306, 0.002969, 0.013306, 0.059634, 0.098320, 0.059634,
    0.013306, 0.021938, 0.098320, 0.162103, 0.098320, 0.021938, 0.013306, 0.059634, 0.098320,
    0.059634, 0.013306, 0.002969, 0.013306, 0.021938, 0.013306, 0.002969,
];

/// Accumulate the 25 supplied RGBA samples in reviewed row-major order.
pub fn gaussian_5x5_sample(samples: &[[f32; 4]; 25]) -> Result<[f32; 4], KernelError> {
    for sample in samples {
        require_finite_slice(sample)?;
    }

    let mut result = [0.0; 4];
    for (sample, coefficient) in samples.iter().zip(GAUSSIAN_5X5) {
        for (channel, output) in result.iter_mut().enumerate() {
            let product = sample[channel] * coefficient;
            *output += product;
        }
    }
    require_finite_result(&result)?;
    Ok(result)
}

/// Apply the exact signed positivity and equality predicate from the host.
pub fn validate_ai_dimensions(input: [i32; 2], output: [i32; 2]) -> Result<(), AiDimensionError> {
    if input[0] <= 0 || input[1] <= 0 {
        return Err(AiDimensionError::NonPositiveInput);
    }
    if input != output {
        return Err(AiDimensionError::SizeMismatch);
    }
    Ok(())
}
