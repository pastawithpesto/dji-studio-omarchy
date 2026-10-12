//! Read-only static shader extraction. This tool never loads the PE image.
//! Bounds and malformed-input rejection are independent native policies.

use serde_json::json;
use std::fs::File;
use std::io::{self, Read, Write};
use std::path::Path;

const MAX_FILE_BYTES: usize = 256 * 1024 * 1024;
const MAX_SOURCE_BYTES: usize = 1024 * 1024;

#[derive(Clone, Copy)]
struct Region {
    rva: u64,
    virtual_end: u64,
    raw_start: usize,
    raw_size: usize,
}

struct Image<'a> {
    bytes: &'a [u8],
    base: u64,
    regions: Vec<Region>,
}

fn span(bytes: &[u8], offset: usize, size: usize) -> Result<&[u8], String> {
    let end = offset.checked_add(size).ok_or("file extent overflow")?;
    bytes
        .get(offset..end)
        .ok_or_else(|| "truncated file extent".into())
}

fn u16_at(bytes: &[u8], offset: usize) -> Result<u16, String> {
    Ok(u16::from_le_bytes(
        span(bytes, offset, 2)?.try_into().unwrap(),
    ))
}

fn u32_at(bytes: &[u8], offset: usize) -> Result<u32, String> {
    Ok(u32::from_le_bytes(
        span(bytes, offset, 4)?.try_into().unwrap(),
    ))
}

fn u64_at(bytes: &[u8], offset: usize) -> Result<u64, String> {
    Ok(u64::from_le_bytes(
        span(bytes, offset, 8)?.try_into().unwrap(),
    ))
}

impl<'a> Image<'a> {
    fn parse(bytes: &'a [u8]) -> Result<Self, String> {
        if bytes.len() > MAX_FILE_BYTES {
            return Err("file exceeds 256 MiB native limit".into());
        }
        if span(bytes, 0, 2)? != b"MZ" {
            return Err("missing DOS signature".into());
        }
        let nt = u32_at(bytes, 0x3c)? as usize;
        span(bytes, nt, 24)?;
        if span(bytes, nt, 4)? != b"PE\0\0" {
            return Err("missing PE signature".into());
        }
        if u16_at(bytes, nt + 4)? != 0x8664 {
            return Err("only AMD64 PE images are supported".into());
        }
        let count = u16_at(bytes, nt + 6)? as usize;
        if !(1..=96).contains(&count) {
            return Err("section count outside native range 1..=96".into());
        }
        let optional_size = u16_at(bytes, nt + 20)? as usize;
        if optional_size < 112 {
            return Err("short PE32+ optional header".into());
        }
        let optional = nt + 24;
        span(bytes, optional, optional_size)?;
        if u16_at(bytes, optional)? != 0x20b {
            return Err("only PE32+ optional headers are supported".into());
        }
        let base = u64_at(bytes, optional + 24)?;
        let headers = u32_at(bytes, optional + 60)? as usize;
        let table = optional + optional_size;
        span(bytes, table, count * 40)?;
        if headers < table + count * 40 || headers > bytes.len() {
            return Err("invalid file-backed header extent".into());
        }
        if base.checked_add(headers as u64).is_none() {
            return Err("header address extent overflow".into());
        }
        let mut regions = vec![Region {
            rva: 0,
            virtual_end: headers as u64,
            raw_start: 0,
            raw_size: headers,
        }];
        for i in 0..count {
            let section = table + i * 40;
            let virtual_size = u32_at(bytes, section + 8)? as u64;
            let rva = u32_at(bytes, section + 12)? as u64;
            let raw_size = u32_at(bytes, section + 16)? as usize;
            let raw_start = u32_at(bytes, section + 20)? as usize;
            let mapped_size = virtual_size.max(raw_size as u64);
            if mapped_size == 0 {
                continue;
            }
            let virtual_end = rva + mapped_size;
            if virtual_end > (1_u64 << 32) || base.checked_add(virtual_end).is_none() {
                return Err("section address extent overflow".into());
            }
            if raw_size != 0 {
                if raw_start < headers {
                    return Err("section raw data overlaps headers".into());
                }
                span(bytes, raw_start, raw_size)?;
            }
            if regions
                .iter()
                .any(|r| rva < r.virtual_end && r.rva < virtual_end)
            {
                return Err("ambiguous overlapping virtual regions".into());
            }
            regions.push(Region {
                rva,
                virtual_end,
                raw_start,
                raw_size,
            });
        }
        Ok(Self {
            bytes,
            base,
            regions,
        })
    }

    // Return a file offset and the exclusive end of its file-backed region.
    // A requested extent must stay in that region. Virtual zero-fill is rejected.
    fn map(&self, va: u64, size: usize) -> Result<(usize, usize), String> {
        let rva = va
            .checked_sub(self.base)
            .ok_or("address below image base")?;
        if rva > u32::MAX as u64 {
            return Err("address outside 32-bit RVA domain".into());
        }
        let region = self
            .regions
            .iter()
            .find(|r| r.rva <= rva && rva < r.virtual_end)
            .ok_or("address has no mapped region")?;
        let delta = usize::try_from(rva - region.rva).map_err(|_| "RVA too large")?;
        if delta
            .checked_add(size)
            .is_none_or(|end| end > region.raw_size)
        {
            return Err("address extent is not file-backed".into());
        }
        let offset = region.raw_start + delta;
        span(self.bytes, offset, size)?;
        Ok((offset, region.raw_start + region.raw_size))
    }

    fn extract(&self, slot_va: u64) -> Result<serde_json::Value, String> {
        let (slot_offset, _) = self.map(slot_va, 8)?;
        let source_va = u64_at(self.bytes, slot_offset)?;
        let (source_offset, region_end) = self.map(source_va, 1)?;
        let scan_end = region_end.min(source_offset + MAX_SOURCE_BYTES + 1);
        let source = &self.bytes[source_offset..scan_end];
        let length = source
            .iter()
            .position(|&b| b == 0)
            .ok_or("source is unterminated within its region or 1 MiB native limit")?;
        let text = std::str::from_utf8(&source[..length]).map_err(|_| "source is not UTF-8")?;
        Ok(json!({
            "schema_version": 1,
            "evidence_type": "static_pointer_and_source_bytes",
            "file_bytes": self.bytes.len(),
            "image_base": format!("0x{:x}", self.base),
            "slot_va": format!("0x{slot_va:x}"),
            "slot_file_offset": slot_offset,
            "source_va": format!("0x{source_va:x}"),
            "source_file_offset": source_offset,
            "source_bytes": length,
            "terminator_file_offset": source_offset + length,
            "source_text": text,
        }))
    }
}

fn read_file(path: &Path) -> Result<Vec<u8>, String> {
    let mut options = File::options();
    options.read(true);
    #[cfg(unix)]
    {
        use std::os::unix::fs::OpenOptionsExt;
        // Avoid blocking when a caller accidentally supplies a FIFO.
        options.custom_flags(libc::O_NONBLOCK);
    }
    let file = options.open(path).map_err(|e| format!("open input: {e}"))?;
    let metadata = file
        .metadata()
        .map_err(|e| format!("input metadata: {e}"))?;
    if !metadata.is_file() {
        return Err("input must be a regular file".into());
    }
    if metadata.len() > MAX_FILE_BYTES as u64 {
        return Err("file exceeds 256 MiB native limit".into());
    }
    let mut bytes = Vec::new();
    file.take((MAX_FILE_BYTES + 1) as u64)
        .read_to_end(&mut bytes)
        .map_err(|e| format!("read input: {e}"))?;
    if bytes.len() > MAX_FILE_BYTES {
        return Err("file exceeds 256 MiB native limit".into());
    }
    Ok(bytes)
}

fn run() -> Result<(), String> {
    let mut args = std::env::args_os().skip(1);
    let path = args
        .next()
        .ok_or("usage: pe_shader_extract INPUT_PE SLOT_VA")?;
    let address = args
        .next()
        .ok_or("usage: pe_shader_extract INPUT_PE SLOT_VA")?;
    if args.next().is_some() {
        return Err("usage: pe_shader_extract INPUT_PE SLOT_VA".into());
    }
    let address = address.to_str().ok_or("slot address must be UTF-8")?;
    let slot = match address
        .strip_prefix("0x")
        .or_else(|| address.strip_prefix("0X"))
    {
        Some(hex) => u64::from_str_radix(hex, 16),
        None => address.parse::<u64>(),
    }
    .map_err(|_| "slot address must be an unsigned decimal or 0x hexadecimal integer")?;
    let bytes = read_file(Path::new(&path))?;
    let value = Image::parse(&bytes)?.extract(slot)?;
    let mut stdout = io::stdout().lock();
    serde_json::to_writer_pretty(&mut stdout, &value).map_err(|e| format!("write JSON: {e}"))?;
    writeln!(stdout).map_err(|e| format!("write newline: {e}"))
}

fn main() {
    if let Err(error) = run() {
        eprintln!("pe_shader_extract: {error}");
        std::process::exit(1);
    }
}
