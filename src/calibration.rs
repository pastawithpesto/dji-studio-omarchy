//! Bounded, experimental scalar calibration math for the pinned 1.0.0.30839 build.
//!
//! Evidence source: `pano_selfcali.dll`, SHA-256
//! `fd5399f24418fd46121a866ea3754a669f79041f205bedce458a146403c0691c`.
//! Preserved artifacts under `sol-calibration-review/`:
//! - `pano-pupil-single-point.json`, 0x180159300, REA
//!   `ev_118ccffc25f0e9e7b73881d5559c8d9b39e57bb7c3c660754281236a91d61f46`:
//!   model-8 projection, signed count, angular tangential terms, scale/crop order.
//! - `pano-projection-math.json`, 0x180158580, REA
//!   `ev_4a7f887ab0664d387fdc703d10a4e49ebe6a84b638e46b07008466977543082d`:
//!   derived rectified unprojection; expression-template bindings remain a limit.
//! - `pano-lens-and-field-helpers.json`, 0x18010cea0, REA
//!   `ev_14da2f5df06fc8019447e3e3c8a8d7731fae593ac99e28442cbd4544b9679b68`:
//!   supplied row-major matrix multiplication.
//!
//! Structs, return values, validation and error precedence are independent
//! portable API design, not vendor ABI or failure codes. Arithmetic stays f32,
//! as in the recovered float operations, without widening or explicit FMA.
//! Grouping/platform transcendental rounding is not verified against Windows.
//! No protobuf mapping, world-frame convention, full calibration, stitching,
//! EIS, media-output or Windows-parity claim is made by these helpers.

/// Independent portable parameters for the recovered model-8 scalar expression.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct Model8Calibration {
    pub focal: [f32; 2],
    pub principal_point: [f32; 2],
    /// Observed p0/p1 storage order; no protobuf coefficient mapping is implied.
    pub tangential: [f32; 2],
    pub radial: [f32; 10],
    /// Recovered signed count: negatives use no terms, values above ten use ten.
    pub radial_count: i32,
    /// Subtracted after scale division, in the resulting pixel coordinate units.
    pub crop: [f32; 2],
}

/// Independent options; names/layout do not reconstruct the original call ABI.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct RawProjectionOptions {
    pub model_selector: i32,
    /// Recovered scale is this float divided by the integer cast to f32.
    pub scale_numerator: f32,
    pub scale_denominator: i32,
    /// Requesting the omitted table correction returns an unsupported error.
    pub pupil_correction: bool,
}

/// Independent explicit representation of paths with no recovered output write.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum NoAssignment {
    RadiusBelowThreshold,
    UnsupportedModel(i32),
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum ProjectionOutcome {
    Pixel([f32; 2]),
    /// No principal-point or zero pixel is inferred for this path.
    NoAssignment(NoAssignment),
}

/// Independent finite-domain safety policy, separate from no-assignment paths.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CalibrationMathError {
    NonFiniteInput,
    NonPositiveFocalLength,
    InvalidScale,
    /// Includes nonfinite intermediates, even if the inputs were finite.
    NonFiniteResult,
    PupilCorrectionUnsupported,
}

/// Project a ray with the recovered disabled-pupil model-8 expression.
///
/// Pupil requests fail explicitly. Other selectors return no assignment without
/// inspecting the math inputs. For selector 8, a finite ray with radius < 1e-7
/// returns no assignment before inspecting camera/scale data. This precedence
/// is independent API design. Used camera fields must be finite, both focal
/// lengths positive, and the scale operands/effective scale positive and finite.
/// The source does not establish those safety requirements.
pub fn project_raw_scalar(
    camera: &Model8Calibration,
    options: RawProjectionOptions,
    ray: [f32; 3],
) -> Result<ProjectionOutcome, CalibrationMathError> {
    if options.pupil_correction {
        return Err(CalibrationMathError::PupilCorrectionUnsupported);
    }
    if options.model_selector != 8 {
        return Ok(ProjectionOutcome::NoAssignment(
            NoAssignment::UnsupportedModel(options.model_selector),
        ));
    }
    if !finite(&ray) {
        return Err(CalibrationMathError::NonFiniteInput);
    }
    let radius = (ray[0] * ray[0] + ray[1] * ray[1]).sqrt();
    if !radius.is_finite() {
        return Err(CalibrationMathError::NonFiniteResult);
    }
    if radius < 1e-7 {
        return Ok(ProjectionOutcome::NoAssignment(
            NoAssignment::RadiusBelowThreshold,
        ));
    }

    let count = camera.radial_count.clamp(0, 10) as usize;
    if !finite(&camera.focal)
        || !finite(&camera.principal_point)
        || !finite(&camera.tangential)
        || !finite(&camera.crop)
        || !finite(&camera.radial[..count])
        || !options.scale_numerator.is_finite()
    {
        return Err(CalibrationMathError::NonFiniteInput);
    }
    if camera.focal.iter().any(|&f| f <= 0.0) {
        return Err(CalibrationMathError::NonPositiveFocalLength);
    }
    if options.scale_numerator <= 0.0 || options.scale_denominator <= 0 {
        return Err(CalibrationMathError::InvalidScale);
    }
    let scale = options.scale_numerator / options.scale_denominator as f32;
    if !scale.is_finite() || scale <= 0.0 {
        return Err(CalibrationMathError::InvalidScale);
    }

    let theta = radius.atan2(ray[2]);
    let theta_squared = theta * theta;
    let mut power = theta_squared * theta;
    let mut phi = theta;
    for &coefficient in &camera.radial[..count] {
        phi += power * coefficient;
        power *= theta_squared;
    }
    let a = (phi * ray[0]) / radius;
    let b = (phi * ray[1]) / radius;
    if !finite(&[phi, a, b]) {
        return Err(CalibrationMathError::NonFiniteResult);
    }
    let [p0, p1] = camera.tangential;
    // Preserve the angular phi^2 terms and the scalar expression order.
    let u = (((a + a) * a + phi * phi) * p1 + (p0 + p0) * a * b + a) * camera.focal[0]
        + camera.principal_point[0];
    let v = (((b + b) * b + phi * phi) * p0 + b + (p1 + p1) * a * b) * camera.focal[1]
        + camera.principal_point[1];
    let pixel = [u / scale - camera.crop[0], v / scale - camera.crop[1]];
    if !finite(&pixel) {
        return Err(CalibrationMathError::NonFiniteResult);
    }
    Ok(ProjectionOutcome::Pixel(pixel))
}

/// Independent portable parameters for rectified fisheye unprojection.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct RectifiedCamera {
    pub focal: f32,
    pub principal_point: [f32; 2],
}

/// Derived compact interpretation of 0x180158580, without distortion.
///
/// Radius is regularized to at least 1e-9 in both angle and division. The
/// recovered helper logs focal < 1; this portable scalar helper independently
/// permits any finite positive focal length. It does not enforce feed-record
/// validation or normalize the resulting ray.
pub fn unproject_rectified_fisheye(
    camera: RectifiedCamera,
    pixel: [f32; 2],
) -> Result<[f32; 3], CalibrationMathError> {
    if !camera.focal.is_finite() || !finite(&camera.principal_point) || !finite(&pixel) {
        return Err(CalibrationMathError::NonFiniteInput);
    }
    if camera.focal <= 0.0 {
        return Err(CalibrationMathError::NonPositiveFocalLength);
    }
    let dx = pixel[0] - camera.principal_point[0];
    let dy = pixel[1] - camera.principal_point[1];
    let radius = (dx * dx + dy * dy).sqrt();
    if !radius.is_finite() {
        return Err(CalibrationMathError::NonFiniteResult);
    }
    let radius = radius.max(1e-9);
    let angle = radius / camera.focal;
    if !angle.is_finite() {
        return Err(CalibrationMathError::NonFiniteResult);
    }
    let sine = angle.sin();
    let ray = [(sine * dx) / radius, (sine * dy) / radius, angle.cos()];
    if !finite(&ray) {
        return Err(CalibrationMathError::NonFiniteResult);
    }
    Ok(ray)
}

/// Multiply a supplied row-major matrix by a column ray, as in 0x18010cea0.
///
/// Matrix/ray layout and finite-value errors are portable API design. No
/// Euler/world-frame convention, orthogonality check or normalization is added.
pub fn rotate_ray_row_major(
    matrix: [f32; 9],
    ray: [f32; 3],
) -> Result<[f32; 3], CalibrationMathError> {
    if !finite(&matrix) || !finite(&ray) {
        return Err(CalibrationMathError::NonFiniteInput);
    }
    let [x, y, z] = ray;
    let rotated = [
        x * matrix[0] + y * matrix[1] + matrix[2] * z,
        x * matrix[3] + y * matrix[4] + matrix[5] * z,
        y * matrix[7] + matrix[8] * z + x * matrix[6],
    ];
    if !finite(&rotated) {
        return Err(CalibrationMathError::NonFiniteResult);
    }
    Ok(rotated)
}

fn finite(values: &[f32]) -> bool {
    values.iter().all(|v| v.is_finite())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::f64::consts::{FRAC_PI_2, FRAC_PI_4, PI};

    // Expected values below are independent analytic identities/hand sums,
    // detailed in sol-calibration-review/rust-implementation/MATH_CHECKS.md.
    // f64 is used only for test expectations; helper arithmetic remains f32.
    fn camera() -> Model8Calibration {
        Model8Calibration {
            focal: [1.0, 1.0],
            principal_point: [0.0, 0.0],
            tangential: [0.0, 0.0],
            radial: [0.0; 10],
            radial_count: 0,
            crop: [0.0, 0.0],
        }
    }

    fn options() -> RawProjectionOptions {
        RawProjectionOptions {
            model_selector: 8,
            scale_numerator: 1.0,
            scale_denominator: 1,
            pupil_correction: false,
        }
    }

    fn pixel(camera: &Model8Calibration, options: RawProjectionOptions, ray: [f32; 3]) -> [f32; 2] {
        match project_raw_scalar(camera, options, ray).unwrap() {
            ProjectionOutcome::Pixel(pixel) => pixel,
            other => panic!("expected assigned pixel, got {other:?}"),
        }
    }

    fn close(actual: f32, expected: f64, tolerance: f64) {
        assert!(
            (f64::from(actual) - expected).abs() <= tolerance,
            "{actual} differs from analytic {expected} by more than {tolerance}"
        );
    }

    #[test]
    fn raw_axis_and_below_threshold_do_not_assign_a_pixel() {
        let mut camera = camera();
        camera.principal_point = [100.0, 200.0];
        for ray in [[0.0, 0.0, 1.0], [0.0, 0.0, -1.0], [5e-8, 0.0, 1.0]] {
            assert_eq!(
                project_raw_scalar(&camera, options(), ray),
                Ok(ProjectionOutcome::NoAssignment(
                    NoAssignment::RadiusBelowThreshold
                ))
            );
        }
        // Explicit API precedence: irrelevant camera/scale data is not used.
        camera.focal[0] = f32::NAN;
        let mut options = options();
        options.scale_denominator = 0;
        assert_eq!(
            project_raw_scalar(&camera, options, [0.0, 0.0, 0.0]),
            Ok(ProjectionOutcome::NoAssignment(
                NoAssignment::RadiusBelowThreshold
            ))
        );
    }

    #[test]
    fn raw_threshold_is_inclusive() {
        let result = pixel(&camera(), options(), [1e-7, 0.0, 0.0]);
        close(result[0], FRAC_PI_2, 2e-7);
        assert_eq!(result[1], 0.0);
    }

    #[test]
    fn unsupported_paths_are_explicit() {
        let mut options = options();
        options.model_selector = 7;
        assert_eq!(
            project_raw_scalar(&camera(), options, [f32::NAN; 3]),
            Ok(ProjectionOutcome::NoAssignment(
                NoAssignment::UnsupportedModel(7)
            ))
        );
        options.pupil_correction = true;
        assert_eq!(
            project_raw_scalar(&camera(), options, [1.0, 0.0, 1.0]),
            Err(CalibrationMathError::PupilCorrectionUnsupported)
        );
    }

    #[test]
    fn three_four_five_ray_divides_scale_before_subtracting_crop() {
        let mut camera = camera();
        camera.focal = [10.0, 20.0];
        camera.principal_point = [7.0, 11.0];
        camera.crop = [2.0, 3.0];
        let mut options = options();
        options.scale_numerator = 6.0;
        options.scale_denominator = 3;
        let result = pixel(&camera, options, [3.0, 4.0, 0.0]);
        close(result[0], 1.5 * PI + 1.5, 2e-6);
        close(result[1], 4.0 * PI + 2.5, 3e-6);
    }

    #[test]
    fn polynomial_uses_odd_angle_powers() {
        let mut camera = camera();
        camera.radial[..4].fill(1.0);
        camera.radial_count = 4;
        let theta = FRAC_PI_4;
        let expected = theta + theta.powi(3) + theta.powi(5) + theta.powi(7) + theta.powi(9);
        let result = pixel(&camera, options(), [1.0, 0.0, 1.0]);
        close(result[0], expected, 5e-7);
        assert_eq!(result[1], 0.0);
    }

    #[test]
    fn tangential_terms_use_distorted_angular_phi_squared() {
        let mut camera = camera();
        camera.radial[0] = 1.0;
        camera.radial_count = 1;
        camera.tangential = [0.125, -0.0625];
        // At [1,0,1], a=phi and b=0; u=phi-3phi^2/16, v=phi^2/8.
        let phi = FRAC_PI_4 + PI.powi(3) / 64.0;
        let result = pixel(&camera, options(), [1.0, 0.0, 1.0]);
        close(result[0], phi - 3.0 * phi * phi / 16.0, 2e-7);
        close(result[1], phi * phi / 8.0, 1e-7);
    }

    #[test]
    fn diagonal_ray_exercises_cross_tangential_terms() {
        let mut camera = camera();
        camera.tangential = [0.125, -0.0625];
        // a=b=phi/sqrt(2); u's tangential terms cancel, v adds 3phi^2/16.
        let diagonal = FRAC_PI_2 / 2.0_f64.sqrt();
        let result = pixel(&camera, options(), [1.0, 1.0, 0.0]);
        close(result[0], diagonal, 3e-7);
        close(result[1], diagonal + 3.0 * FRAC_PI_2.powi(2) / 16.0, 4e-7);
    }

    #[test]
    fn signed_count_and_ten_slot_cap_select_theta_to_the_twenty_first() {
        let mut camera = camera();
        camera.radial[9] = 1.0;
        for count in [-1, i32::MIN, 0, 9, 10, 11, i32::MAX] {
            camera.radial_count = count;
            let expected = if count >= 10 {
                FRAC_PI_4 + FRAC_PI_4.powi(21)
            } else {
                FRAC_PI_4
            };
            close(
                pixel(&camera, options(), [1.0, 0.0, 1.0])[0],
                expected,
                2e-7,
            );
        }
        // The safety policy examines only coefficients used by the expression.
        camera.radial.fill(f32::NAN);
        camera.radial_count = -1;
        close(
            pixel(&camera, options(), [1.0, 0.0, 1.0])[0],
            FRAC_PI_4,
            1e-7,
        );
    }

    #[test]
    fn raw_safety_errors_reject_nonfinite_and_nonpositive_domains() {
        assert_eq!(
            project_raw_scalar(&camera(), options(), [f32::NAN, 0.0, 1.0]),
            Err(CalibrationMathError::NonFiniteInput)
        );
        for (numerator, denominator) in [
            (0.0, 1),
            (-1.0, 1),
            (1.0, 0),
            (1.0, -1),
            (f32::from_bits(1), i32::MAX),
        ] {
            let mut options = options();
            options.scale_numerator = numerator;
            options.scale_denominator = denominator;
            assert_eq!(
                project_raw_scalar(&camera(), options, [1.0, 0.0, 1.0]),
                Err(CalibrationMathError::InvalidScale)
            );
        }
        let mut camera = camera();
        camera.focal[1] = 0.0;
        assert_eq!(
            project_raw_scalar(&camera, options(), [1.0, 0.0, 1.0]),
            Err(CalibrationMathError::NonPositiveFocalLength)
        );
        camera.focal[1] = 1.0;
        camera.radial_count = 1;
        camera.radial[0] = f32::INFINITY;
        assert_eq!(
            project_raw_scalar(&camera, options(), [1.0, 0.0, 1.0]),
            Err(CalibrationMathError::NonFiniteInput)
        );
    }

    #[test]
    fn raw_finite_inputs_can_still_overflow_and_return_safety_errors() {
        assert_eq!(
            project_raw_scalar(&camera(), options(), [f32::MAX, 0.0, 1.0]),
            Err(CalibrationMathError::NonFiniteResult)
        );
        let mut camera = camera();
        camera.focal[0] = f32::MAX;
        assert_eq!(
            project_raw_scalar(&camera, options(), [1.0, 0.0, 0.0]),
            Err(CalibrationMathError::NonFiniteResult)
        );
        camera.focal[0] = 1.0;
        camera.radial[0] = f32::MAX;
        camera.radial_count = 1;
        assert_eq!(
            project_raw_scalar(&camera, options(), [1.0, 0.0, 0.0]),
            Err(CalibrationMathError::NonFiniteResult)
        );
    }

    #[test]
    fn rectified_center_and_cardinal_rays_follow_sine_cosine_identities() {
        let camera = RectifiedCamera {
            focal: 1.0,
            principal_point: [10.0, 20.0],
        };
        assert_eq!(
            unproject_rectified_fisheye(camera, [10.0, 20.0]),
            Ok([0.0, 0.0, 1.0])
        );
        for (pixel, expected) in [
            ([10.0 + FRAC_PI_2 as f32, 20.0], [1.0, 0.0, 0.0]),
            ([10.0, 20.0 - FRAC_PI_2 as f32], [0.0, -1.0, 0.0]),
        ] {
            let ray = unproject_rectified_fisheye(camera, pixel).unwrap();
            for lane in 0..3 {
                close(ray[lane], expected[lane], 8e-7);
            }
        }
        let ray = unproject_rectified_fisheye(
            RectifiedCamera {
                focal: (10.0 / PI) as f32,
                principal_point: [0.0; 2],
            },
            [3.0, 4.0],
        )
        .unwrap();
        close(ray[0], 0.6, 1e-7);
        close(ray[1], 0.8, 1e-7);
        close(ray[2], 0.0, 1e-7);
    }

    #[test]
    fn rectified_sub_threshold_radius_is_used_for_both_angle_and_division() {
        let ray = unproject_rectified_fisheye(
            RectifiedCamera {
                focal: 1e-9,
                principal_point: [0.0; 2],
            },
            [5e-10, 0.0],
        )
        .unwrap();
        close(ray[0], 0.42073549240394825, 6e-8); // sin(1)/2
        assert_eq!(ray[1], 0.0);
        close(ray[2], 0.5403023058681398, 6e-8); // cos(1)
    }

    #[test]
    fn row_major_basis_rays_select_matrix_columns() {
        let matrix = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0];
        assert_eq!(
            rotate_ray_row_major(matrix, [1.0, 0.0, 0.0]),
            Ok([1.0, 4.0, 7.0])
        );
        assert_eq!(
            rotate_ray_row_major(matrix, [0.0, 1.0, 0.0]),
            Ok([2.0, 5.0, 8.0])
        );
        assert_eq!(
            rotate_ray_row_major(matrix, [0.0, 0.0, 1.0]),
            Ok([3.0, 6.0, 9.0])
        );
        assert_eq!(
            rotate_ray_row_major(matrix, [2.0, 3.0, 5.0]),
            Ok([23.0, 53.0, 83.0])
        );
    }

    #[test]
    fn unprojection_and_matrix_safety_domains_are_explicit() {
        let mut camera = RectifiedCamera {
            focal: 1.0,
            principal_point: [0.0; 2],
        };
        assert_eq!(
            unproject_rectified_fisheye(camera, [f32::NAN, 0.0]),
            Err(CalibrationMathError::NonFiniteInput)
        );
        assert_eq!(
            unproject_rectified_fisheye(camera, [f32::MAX, 0.0]),
            Err(CalibrationMathError::NonFiniteResult)
        );
        camera.focal = 0.0;
        assert_eq!(
            unproject_rectified_fisheye(camera, [1.0, 0.0]),
            Err(CalibrationMathError::NonPositiveFocalLength)
        );
        camera.focal = f32::from_bits(1);
        assert_eq!(
            unproject_rectified_fisheye(camera, [1.0, 0.0]),
            Err(CalibrationMathError::NonFiniteResult)
        );
        let mut matrix = [0.0; 9];
        matrix[0] = f32::INFINITY;
        assert_eq!(
            rotate_ray_row_major(matrix, [1.0; 3]),
            Err(CalibrationMathError::NonFiniteInput)
        );
        matrix[0] = f32::MAX;
        assert_eq!(
            rotate_ray_row_major(matrix, [2.0, 0.0, 0.0]),
            Err(CalibrationMathError::NonFiniteResult)
        );
    }
}
