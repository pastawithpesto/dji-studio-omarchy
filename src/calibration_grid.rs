//! Experimental rectified lattice geometry, without mesh buffers or GPU binding.
//!
//! Evidence: Windows 1.0.0.30839 `pano_selfcali.dll`, SHA-256
//! `fd5399f24418fd46121a866ea3754a669f79041f205bedce458a146403c0691c`;
//! preserved `sol-calibration-review/pano-projection-math.json`, 0x1801084c0,
//! REA `ev_4a7f887ab0664d387fdc703d10a4e49ebe6a84b638e46b07008466977543082d`.
//! Visible loops establish quotient-plus-one dimensions, row-major traversal
//! and separate integer-to-f32 casts before coordinate multiplication.
//!
//! The public API, positive-domain restrictions and checked errors are independent
//! portable design, reviewed in the corrected contract f751b98b (Astra bus 130).
//! No default camera, Mat layout/ownership, coordinate frame, timestamps, GPU
//! sampling, full projected mesh, EIS or Windows/runtime parity is established.

/// Independent checked geometry for an explicitly supplied rectified lattice.
///
/// Integer endpoints equal the extent when divisible and fall below it otherwise.
/// Returned f32 coordinates may round beyond the integer extent. No clamp is
/// applied and no bound on the returned floating-point coordinates is promised.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct RectifiedGrid {
    columns: usize,
    rows: usize,
    vertex_count: usize,
    step: [i32; 2],
}

/// Independent portable errors, not recovered DJI status codes.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum GridGeometryError {
    NonPositiveExtent,
    NonPositiveStep,
    SizeOverflow,
}

impl RectifiedGrid {
    /// Require positive extents and steps, then check signed dimensions and size.
    ///
    /// Error precedence is extent, then step, then size; this restriction and
    /// precedence are independent design. No buffer is allocated by construction.
    pub fn new(extent: [i32; 2], step: [i32; 2]) -> Result<Self, GridGeometryError> {
        if extent.iter().any(|&value| value <= 0) {
            return Err(GridGeometryError::NonPositiveExtent);
        }
        if step.iter().any(|&value| value <= 0) {
            return Err(GridGeometryError::NonPositiveStep);
        }
        let dimension = |extent: i32, step: i32| {
            extent
                .checked_div(step)
                .and_then(|quotient| quotient.checked_add(1))
                .and_then(|dimension| usize::try_from(dimension).ok())
                .ok_or(GridGeometryError::SizeOverflow)
        };
        let columns = dimension(extent[0], step[0])?;
        let rows = dimension(extent[1], step[1])?;
        let vertex_count = columns
            .checked_mul(rows)
            .ok_or(GridGeometryError::SizeOverflow)?;
        Ok(Self {
            columns,
            rows,
            vertex_count,
            step,
        })
    }

    pub const fn columns(&self) -> usize {
        self.columns
    }

    pub const fn rows(&self) -> usize {
        self.rows
    }

    pub const fn vertex_count(&self) -> usize {
        self.vertex_count
    }

    /// Select a row-major point without allocating or traversing earlier points.
    ///
    /// Column/row and step are separately cast to f32 before multiplication, as
    /// in the preserved body. Rounding can move a float endpoint beyond extent;
    /// integer multiplication before one cast would be a different expression.
    pub fn pixel_at(&self, index: usize) -> Option<[f32; 2]> {
        if index >= self.vertex_count {
            return None;
        }
        let column = index % self.columns;
        let row = index / self.columns;
        Some([
            (column as f32) * (self.step[0] as f32),
            (self.step[1] as f32) * (row as f32),
        ])
    }
}
