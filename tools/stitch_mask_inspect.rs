//! Read-only inspection of v2 panomask resources through the pinned decoder.
//! CLI limits, JSON output and exit codes are independent native tool policy.
//! Byte frequencies do not establish seam, alpha, row or camera semantics.

#[path = "../src/stitch_mask.rs"]
mod stitch_mask;

use std::ffi::OsString;
use std::fs::File;
use std::io::{Read, Write};
use std::path::Path;
use std::process::ExitCode;
use stitch_mask::{MaskLimits, decode_mask_v2};

const MAX_ENCODED_BYTES: usize = 64 * 1024 * 1024;
const DEFAULT_DECODED_LIMIT: usize = 16 * 1024 * 1024;
const USAGE: &str = "Usage: stitch-mask-inspect FILE [MAX_DECODED_BYTES]\n\
Inspect a v2 panomask resource without changing it.\n\
Emit dimensions, encoded/decoded byte counts and a 256-entry byte histogram as JSON.\n\
The default decoded limit is 16777216 bytes. The encoded limit is 67108864 bytes.\n";

enum ToolError {
    Usage(String),
    Input(String),
}

fn main() -> ExitCode {
    match run(std::env::args_os().skip(1).collect()) {
        Ok(()) => ExitCode::SUCCESS,
        Err(ToolError::Usage(message)) => {
            eprintln!("{message}\n{USAGE}");
            ExitCode::from(2)
        }
        Err(ToolError::Input(message)) => {
            eprintln!("{message}");
            ExitCode::FAILURE
        }
    }
}

fn run(args: Vec<OsString>) -> Result<(), ToolError> {
    if args.len() == 1 && (args[0] == "--help" || args[0] == "-h") {
        return write_stdout(USAGE.as_bytes());
    }
    if !(1..=2).contains(&args.len()) {
        return Err(ToolError::Usage(
            "Supply one input file and an optional limit.".into(),
        ));
    }
    let limit = match args.get(1) {
        Some(value) => value
            .to_str()
            .and_then(|value| value.parse::<usize>().ok())
            .filter(|&value| value > 0)
            .ok_or_else(|| {
                ToolError::Usage("The decoded limit must be a positive integer.".into())
            })?,
        None => DEFAULT_DECODED_LIMIT,
    };

    let input = read_bounded(Path::new(&args[0]))?;
    let mask = decode_mask_v2(
        &input,
        MaskLimits {
            max_decoded_bytes: limit,
        },
    )
    .map_err(|error| {
        ToolError::Input(format!(
            "Invalid mask: {:?} at byte {}.",
            error.kind, error.offset
        ))
    })?;
    let mut counts = [0_u64; 256];
    for &byte in &mask.bytes {
        counts[usize::from(byte)] += 1;
    }
    let histogram = counts
        .iter()
        .map(u64::to_string)
        .collect::<Vec<_>>()
        .join(",");
    let json = format!(
        "{{\"format_version\":2,\"width\":{},\"height\":{},\"encoded_bytes\":{},\"decoded_bytes\":{},\"byte_counts\":[{}]}}\n",
        mask.width,
        mask.height,
        input.len(),
        mask.bytes.len(),
        histogram
    );
    write_stdout(json.as_bytes())
}

fn read_bounded(path: &Path) -> Result<Vec<u8>, ToolError> {
    let file = File::open(path)
        .map_err(|error| ToolError::Input(format!("Cannot open input: {error}")))?;
    let metadata = file
        .metadata()
        .map_err(|error| ToolError::Input(format!("Cannot inspect input: {error}")))?;
    if !metadata.is_file() {
        return Err(ToolError::Input("Input must be a regular file.".into()));
    }
    if metadata.len() > MAX_ENCODED_BYTES as u64 {
        return Err(ToolError::Input(
            "Input exceeds the encoded byte limit.".into(),
        ));
    }
    let mut input = Vec::new();
    input
        .try_reserve_exact(metadata.len() as usize)
        .map_err(|error| {
            ToolError::Input(format!("Cannot reserve the bounded input buffer: {error}"))
        })?;
    // Check again after the bounded read in case the file grew after metadata.
    file.take(MAX_ENCODED_BYTES as u64 + 1)
        .read_to_end(&mut input)
        .map_err(|error| ToolError::Input(format!("Cannot read input: {error}")))?;
    if input.len() > MAX_ENCODED_BYTES {
        return Err(ToolError::Input(
            "Input exceeds the encoded byte limit.".into(),
        ));
    }
    Ok(input)
}

fn write_stdout(bytes: &[u8]) -> Result<(), ToolError> {
    std::io::stdout()
        .lock()
        .write_all(bytes)
        .map_err(|error| ToolError::Input(format!("Cannot write report: {error}")))
}
