//! Experimental allocation-free pano plane positions and strip indices.
//!
//! Evidence: Windows 1.0.0.30839 `VinceEditor.dll`, SHA-256
//! `9450a9631b40037ec8c9bbd874f56e455264ed408a93d66168235b68c4383e42`;
//! original setup body 0x180131120 and binary64 half constant 0x1806789a8.
//! The preserved setup window and independent fixtures are in
//! `sol-calibration-review/swarm-20261010-2154`. Contract SHA-256
//! `873b555afb19e6adba427a04e8b6aed6e70a2b23aa92bfe45aad92bdc7699eff`
//! was reviewed in Astra bus 431; original geometry/fixtures in bus 407.
//!
//! The checked domain, errors and random access interface are independent design.
//! Scalar arithmetic requires ordinary IEEE754 nearest-even rounding; vendor
//! MXCSR was not observed and this module does not inspect or alter float state.
//! No UVs, EIS/calibration binding, coordinate frame, GPU execution, original
//! allocation/error behavior, or Windows/media parity is established.

/// Independent checked descriptor; construction and lookup allocate no buffers.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct PanoPlaneGeometry {
    columns: usize,
    rows: usize,
    vertex_count: usize,
    index_count: usize,
}

/// Independent portable errors, not recovered DJI status codes.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PanoPlaneError {
    DimensionTooSmall,
    SizeOverflow,
}

impl PanoPlaneGeometry {
    /// Require both dimensions >= 2 before checking source and portable sizes.
    ///
    /// V, 4*V and the index count must fit positive i32; position and index
    /// byte lengths must fit usize and isize. These checks allocate no memory
    /// and do not promise that corresponding dense buffers can be allocated.
    pub fn new(columns: i32, rows: i32) -> Result<Self, PanoPlaneError> {
        if columns < 2 || rows < 2 {
            return Err(PanoPlaneError::DimensionTooSmall);
        }
        let columns = columns as u64;
        let rows = rows as u64;
        let signed_count = |value: Option<u64>| {
            value
                .filter(|&count| count <= i32::MAX as u64)
                .ok_or(PanoPlaneError::SizeOverflow)
        };
        let vertex_count = signed_count(columns.checked_mul(rows))?;
        signed_count(vertex_count.checked_mul(4))?;
        let index_count = signed_count(
            columns
                .checked_mul(2)
                .and_then(|width| width.checked_mul(rows - 1))
                .and_then(|bands| (rows - 2).checked_mul(2)?.checked_add(bands)),
        )?;
        for (count, stride) in [(vertex_count, 16), (index_count, 4)] {
            count
                .checked_mul(stride)
                .and_then(|bytes| usize::try_from(bytes).ok())
                .filter(|&bytes| bytes <= isize::MAX as usize)
                .ok_or(PanoPlaneError::SizeOverflow)?;
        }
        let portable_count =
            |count| usize::try_from(count).map_err(|_| PanoPlaneError::SizeOverflow);
        Ok(Self {
            columns: portable_count(columns)?,
            rows: portable_count(rows)?,
            vertex_count: portable_count(vertex_count)?,
            index_count: portable_count(index_count)?,
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

    pub const fn index_count(&self) -> usize {
        self.index_count
    }

    /// Select a row-major `[x, y, 0, 1]` record in O(1) without allocation.
    ///
    /// Each integer and dimension-minus-one are separately converted to f32,
    /// divided in f32, then widened for f64 centering/doubling before narrowing.
    pub fn vertex_at(&self, index: usize) -> Option<[f32; 4]> {
        if index >= self.vertex_count {
            return None;
        }
        let component = |position: usize, dimension: usize| {
            let quotient = (position as f32) / ((dimension - 1) as f32);
            let centered = f64::from(quotient) - 0.5;
            (centered + centered) as f32
        };
        Some([
            component(index % self.columns, self.columns),
            component(index / self.columns, self.rows),
            0.0,
            1.0,
        ])
    }

    /// Select the original neighboring-row strip order, including join indices.
    ///
    /// Each later band starts with the previous endpoint followed by its new
    /// start, then alternating upper/lower row vertices. Lookup is O(1).
    pub fn index_at(&self, index: usize) -> Option<u32> {
        if index >= self.index_count {
            return None;
        }
        let first_band_len = 2 * self.columns;
        let (band, offset) = if index < first_band_len {
            (0, index)
        } else {
            let remaining = index - first_band_len;
            let band_len = first_band_len + 2;
            let band = 1 + remaining / band_len;
            match remaining % band_len {
                0 => return Some(((band + 1) * self.columns - 1) as u32),
                1 => return Some((band * self.columns) as u32),
                offset => (band, offset - 2),
            }
        };
        let row = band + offset % 2;
        Some((row * self.columns + offset / 2) as u32)
    }
}
