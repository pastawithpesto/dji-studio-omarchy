//! Experimental direct djmd/xtmd import using trusted external FFprobe.
//! Contract: sol-review/resumed-demux-20261010/CONTRACT.md, Astra approval 98.
//! Loader 0x18034c3d0 and packet forwarding 0x18034cb36–0x18034cb42 support
//! the selected buffer boundary. Resource/error/inspection policies are native
//! design; no nested import, assembled conversion or camera/Windows parity.

use super::packet::{DecodedPacket, MetadataDecoder, PacketDecodeFailure};
use base64::{Engine, engine::general_purpose::STANDARD};
use serde_json::Value;
use std::{
    error::Error,
    fmt, fs,
    io::{self, Read},
    os::{
        fd::AsRawFd,
        unix::fs::{MetadataExt, OpenOptionsExt},
    },
    path::{Path, PathBuf},
    process::{Child, Command, ExitStatus, Stdio},
    thread,
    time::{Duration, Instant},
};

#[derive(Debug, Clone)]
pub struct ProbeLimits {
    pub stdout_bytes: usize,
    pub stderr_bytes: usize,
    pub streams: usize,
    pub packets_per_track: usize,
    pub packet_bytes: usize,
    pub total_packet_bytes: usize,
    pub timeout: Duration,
}

impl Default for ProbeLimits {
    fn default() -> Self {
        Self {
            stdout_bytes: 64 * 1024 * 1024,
            stderr_bytes: 64 * 1024,
            streams: 256,
            packets_per_track: 10000,
            packet_bytes: 16 * 1024 * 1024,
            total_packet_bytes: 64 * 1024 * 1024,
            timeout: Duration::from_secs(30),
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct TimeBase {
    pub numerator: i32,
    pub denominator: i32,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct StreamInfo {
    pub index: u32,
    pub id: Option<String>,
    pub codec_tag: u32,
    pub codec_tag_string: String,
    pub time_base: TimeBase,
}

#[derive(Debug)]
pub enum PacketOutcome {
    Decoded(DecodedPacket),
    DecodeFailed(PacketDecodeFailure),
    MissingEncoder(Vec<u8>),
}

impl PacketOutcome {
    pub fn original_packet(&self) -> &[u8] {
        match self {
            Self::Decoded(packet) => packet.original_packet(),
            Self::DecodeFailed(error) => error.original_packet(),
            Self::MissingEncoder(bytes) => bytes,
        }
    }
}

#[derive(Debug)]
pub struct TimedPacket {
    pub pts: Option<i64>,
    pub dts: Option<i64>,
    /// Source position is context only, never an offset used to extract bytes.
    pub source_position: Option<u64>,
    pub outcome: PacketOutcome,
}

#[derive(Debug)]
pub struct MetadataTrack {
    pub stream: StreamInfo,
    /// Demux order within this stream; no cross-track interleaving is inferred.
    pub packets: Vec<TimedPacket>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DirectDisposition {
    DirectTracks,
    /// No direct tags. This does not assert absence of hidden/nested metadata.
    NoDirectTracks,
    /// camd observed with no direct tags. Its nested payload is not processed.
    NestedUnsupported,
}

#[derive(Debug)]
pub struct DirectMetadata {
    pub requested_path: PathBuf,
    pub canonical_path: PathBuf,
    pub encoder: Option<String>,
    pub streams: Vec<StreamInfo>,
    pub tracks: Vec<MetadataTrack>,
    pub excess_track_indexes: Vec<u32>,
    pub disposition: DirectDisposition,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ProbeStage {
    Inventory,
    Packets(u32),
}

#[derive(Debug)]
pub enum DemuxErrorKind {
    Input(String),
    SourceChanged,
    Spawn(String),
    Read(String),
    Exit(ExitStatus),
    Timeout,
    OutputLimit { pipe: &'static str, limit: usize },
    InvalidJson(String),
    InvalidData(String),
    Limit { name: &'static str, limit: usize },
    DecoderInit(String),
}

/// Probe/transport failures carry bounded diagnostic prefixes. No truncated
/// document is parsed or mistaken for a successful absence result.
#[derive(Debug)]
pub struct DemuxError {
    pub kind: DemuxErrorKind,
    pub stage: Option<ProbeStage>,
    stdout: Vec<u8>,
    stderr: Vec<u8>,
}

impl DemuxError {
    fn new(kind: DemuxErrorKind) -> Self {
        Self {
            kind,
            stage: None,
            stdout: Vec::new(),
            stderr: Vec::new(),
        }
    }
    pub fn stdout_prefix(&self) -> &[u8] {
        &self.stdout
    }
    pub fn stderr_prefix(&self) -> &[u8] {
        &self.stderr
    }
}

impl fmt::Display for DemuxError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "metadata demux {:?}: ", self.stage)?;
        match &self.kind {
            DemuxErrorKind::Input(s)
            | DemuxErrorKind::Spawn(s)
            | DemuxErrorKind::Read(s)
            | DemuxErrorKind::InvalidJson(s)
            | DemuxErrorKind::InvalidData(s)
            | DemuxErrorKind::DecoderInit(s) => f.write_str(s),
            DemuxErrorKind::SourceChanged => f.write_str("source changed during probing"),
            DemuxErrorKind::Exit(status) => write!(f, "FFprobe failed: {status}"),
            DemuxErrorKind::Timeout => f.write_str("FFprobe timeout"),
            DemuxErrorKind::OutputLimit { pipe, limit } => {
                write!(f, "FFprobe {pipe} exceeds {limit} bytes")
            }
            DemuxErrorKind::Limit { name, limit } => {
                write!(f, "{name} exceeds caller limit {limit}")
            }
        }
    }
}
impl Error for DemuxError {}

struct Capture {
    stage: ProbeStage,
    stdout: Vec<u8>,
    stderr: Vec<u8>,
}
impl Capture {
    fn failure(self, kind: DemuxErrorKind) -> DemuxError {
        DemuxError {
            kind,
            stage: Some(self.stage),
            stdout: self.stdout,
            stderr: self.stderr,
        }
    }
}

/// Only this directly launched trusted process is owned. No global process or
/// process-group termination is performed, and no detached reader threads exist.
struct OwnedChild(Child);
impl Drop for OwnedChild {
    fn drop(&mut self) {
        // Also handles setup/read/parse-unwind errors. Child::wait caches already
        // reaped status, so a successful normal path is harmless here.
        let _ = self.0.kill();
        let _ = self.0.wait();
    }
}

fn nonblocking(pipe: &impl AsRawFd) -> io::Result<()> {
    let fd = pipe.as_raw_fd();
    // SAFETY: fd belongs to a live child pipe held by this call; these fcntl
    // operations take only integer arguments and access no user memory.
    let flags = unsafe { libc::fcntl(fd, libc::F_GETFL) };
    if flags < 0 {
        return Err(io::Error::last_os_error());
    }
    // Preserve every existing file flag while setting O_NONBLOCK.
    // SAFETY: the same live descriptor and checked flags as above.
    if unsafe { libc::fcntl(fd, libc::F_SETFL, flags | libc::O_NONBLOCK) } < 0 {
        return Err(io::Error::last_os_error());
    }
    Ok(())
}

// Exactly one bounded read per pipe per iteration keeps the other pipe/deadline
// responsive even when one writer continuously produces output.
fn read_pipe(
    pipe: &mut impl Read,
    bytes: &mut Vec<u8>,
    limit: usize,
    name: &'static str,
) -> Result<(bool, bool), DemuxErrorKind> {
    let remaining = limit - bytes.len();
    let mut buffer = [0_u8; 8192];
    let wanted = buffer.len().min(remaining.saturating_add(1));
    match pipe.read(&mut buffer[..wanted]) {
        Ok(0) => Ok((true, false)),
        Ok(n) => {
            bytes.extend_from_slice(&buffer[..n.min(remaining)]);
            if n > remaining {
                return Err(DemuxErrorKind::OutputLimit { pipe: name, limit });
            }
            Ok((false, true))
        }
        Err(e)
            if matches!(
                e.kind(),
                io::ErrorKind::WouldBlock | io::ErrorKind::Interrupted
            ) =>
        {
            Ok((false, false))
        }
        Err(e) => Err(DemuxErrorKind::Read(e.to_string())),
    }
}

#[derive(Debug)]
pub struct Ffprobe {
    executable: PathBuf,
}
impl Ffprobe {
    /// The executable is trusted configuration, not shell text. It must support
    /// -data_dump_format base64. CLI uses the pinned local /usr/bin/ffprobe.
    pub fn new(executable: impl Into<PathBuf>) -> Self {
        Self {
            executable: executable.into(),
        }
    }

    fn capture(
        &self,
        path: &Path,
        stage: ProbeStage,
        limits: &ProbeLimits,
    ) -> Result<Capture, DemuxError> {
        let mut capture = Capture {
            stage,
            stdout: Vec::new(),
            stderr: Vec::new(),
        };
        let mut command = Command::new(&self.executable);
        command.args([
            "-v",
            "error",
            "-protocol_whitelist",
            "file",
            "-of",
            "json=string_validation=fail",
        ]);
        match stage {
            ProbeStage::Inventory => {
                command.args([
                    "-show_entries",
                    "format_tags=encoder:stream=index,id,codec_tag,codec_tag_string,time_base",
                ]);
            }
            ProbeStage::Packets(index) => {
                command.args([
                    "-select_streams",
                    &index.to_string(),
                    "-show_packets",
                    "-show_data",
                    "-data_dump_format",
                    "base64",
                    "-show_entries",
                    "packet=stream_index,pts,dts,pos,size,data",
                ]);
            }
        }
        command
            .arg("-i")
            .arg(path)
            .stdin(Stdio::null())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped());
        let child = command.spawn().map_err(|e| DemuxError {
            kind: DemuxErrorKind::Spawn(e.to_string()),
            stage: Some(stage),
            stdout: Vec::new(),
            stderr: Vec::new(),
        })?;
        let mut child = OwnedChild(child);
        let mut stdout = child.0.stdout.take().expect("stdout configured piped");
        let mut stderr = child.0.stderr.take().expect("stderr configured piped");
        if let Err(e) = nonblocking(&stdout).and_then(|()| nonblocking(&stderr)) {
            return Err(capture.failure(DemuxErrorKind::Read(e.to_string())));
        }
        let start = Instant::now();
        let (mut stdout_eof, mut stderr_eof, mut status) = (false, false, None);
        loop {
            if start.elapsed() >= limits.timeout {
                return Err(capture.failure(DemuxErrorKind::Timeout));
            }
            let mut progress = false;
            if !stdout_eof {
                match read_pipe(
                    &mut stdout,
                    &mut capture.stdout,
                    limits.stdout_bytes,
                    "stdout",
                ) {
                    Ok((eof, read)) => {
                        stdout_eof = eof;
                        progress |= read;
                    }
                    Err(kind) => return Err(capture.failure(kind)),
                }
            }
            if !stderr_eof {
                match read_pipe(
                    &mut stderr,
                    &mut capture.stderr,
                    limits.stderr_bytes,
                    "stderr",
                ) {
                    Ok((eof, read)) => {
                        stderr_eof = eof;
                        progress |= read;
                    }
                    Err(kind) => return Err(capture.failure(kind)),
                }
            }
            if status.is_none() {
                match child.0.try_wait() {
                    Ok(found) => status = found,
                    Err(e) => return Err(capture.failure(DemuxErrorKind::Read(e.to_string()))),
                }
            }
            if let Some(status) = status.filter(|_| stdout_eof && stderr_eof) {
                return if status.success() {
                    Ok(capture)
                } else {
                    Err(capture.failure(DemuxErrorKind::Exit(status)))
                };
            }
            if !progress {
                thread::sleep(
                    Duration::from_millis(5).min(limits.timeout.saturating_sub(start.elapsed())),
                );
            }
        }
    }
}

#[derive(PartialEq, Eq)]
struct SourceStamp {
    dev: u64,
    ino: u64,
    len: u64,
    modified: (i64, i64),
    changed: (i64, i64),
}
impl SourceStamp {
    fn from(metadata: &fs::Metadata) -> Self {
        Self {
            dev: metadata.dev(),
            ino: metadata.ino(),
            len: metadata.len(),
            modified: (metadata.mtime(), metadata.mtime_nsec()),
            changed: (metadata.ctime(), metadata.ctime_nsec()),
        }
    }
}
struct Source {
    file: fs::File,
    path: PathBuf,
    stamp: SourceStamp,
}
impl Source {
    fn open(path: &Path) -> Result<Self, DemuxError> {
        let input = |e: io::Error| DemuxError::new(DemuxErrorKind::Input(e.to_string()));
        let path = fs::canonicalize(path).map_err(input)?;
        // O_NONBLOCK prevents a no-writer FIFO from hanging before fstat can
        // reject it. Validate the opened object, rather than a raced path stat.
        let file = fs::OpenOptions::new()
            .read(true)
            .custom_flags(libc::O_NONBLOCK)
            .open(&path)
            .map_err(input)?;
        let metadata = file.metadata().map_err(input)?;
        if !metadata.is_file() {
            return Err(DemuxError::new(DemuxErrorKind::Input(
                "input must be a local regular file".into(),
            )));
        }
        Ok(Self {
            file,
            path,
            stamp: SourceStamp::from(&metadata),
        })
    }
    fn unchanged(&self) -> bool {
        [self.file.metadata(), fs::metadata(&self.path)]
            .into_iter()
            .all(|m| m.is_ok_and(|m| m.is_file() && SourceStamp::from(&m) == self.stamp))
    }
    fn probe(
        &self,
        tool: &Ffprobe,
        stage: ProbeStage,
        limits: &ProbeLimits,
    ) -> Result<Capture, DemuxError> {
        if !self.unchanged() {
            return Err(DemuxError::new(DemuxErrorKind::SourceChanged));
        }
        let result = tool.capture(&self.path, stage, limits);
        if !self.unchanged() {
            return Err(match result {
                Ok(capture) => capture.failure(DemuxErrorKind::SourceChanged),
                Err(mut error) => {
                    error.kind = DemuxErrorKind::SourceChanged;
                    error
                }
            });
        }
        result
    }
}

fn invalid(message: &str) -> DemuxErrorKind {
    DemuxErrorKind::InvalidData(message.into())
}
fn string<'a>(value: &'a Value, key: &str) -> Result<&'a str, DemuxErrorKind> {
    value
        .get(key)
        .and_then(Value::as_str)
        .ok_or_else(|| invalid(&format!("missing/invalid {key}")))
}
fn unsigned(value: &Value) -> Result<u64, DemuxErrorKind> {
    value
        .as_u64()
        .or_else(|| value.as_str().and_then(|s| s.parse().ok()))
        .ok_or_else(|| invalid("invalid unsigned integer"))
}
fn timestamp(value: Option<&Value>) -> Result<Option<i64>, DemuxErrorKind> {
    match value {
        None | Some(Value::Null) => Ok(None),
        Some(Value::String(s)) if s == "N/A" => Ok(None),
        Some(v) => v
            .as_i64()
            .or_else(|| v.as_str().and_then(|s| s.parse().ok()))
            .map(Some)
            .ok_or_else(|| invalid("invalid signed packet timestamp")),
    }
}
fn position(value: Option<&Value>) -> Result<Option<u64>, DemuxErrorKind> {
    match value {
        None | Some(Value::Null) => Ok(None),
        Some(Value::String(s)) if s == "N/A" || s == "-1" => Ok(None),
        Some(v) if v.as_i64() == Some(-1) => Ok(None),
        Some(v) => unsigned(v).map(Some),
    }
}
fn document(capture: &Capture) -> Result<Value, DemuxErrorKind> {
    serde_json::from_slice(&capture.stdout).map_err(|e| DemuxErrorKind::InvalidJson(e.to_string()))
}
fn inventory(
    capture: &Capture,
    limits: &ProbeLimits,
) -> Result<(Option<String>, Vec<StreamInfo>), DemuxErrorKind> {
    let document = document(capture)?;
    let format = document
        .get("format")
        .and_then(Value::as_object)
        .ok_or_else(|| invalid("missing format object"))?;
    let encoder = match format.get("tags") {
        None => None,
        Some(tags) => {
            let tags = tags
                .as_object()
                .ok_or_else(|| invalid("invalid format tags"))?;
            tags.get("encoder")
                .map(|e| {
                    e.as_str()
                        .map(str::to_owned)
                        .ok_or_else(|| invalid("invalid encoder"))
                })
                .transpose()?
        }
    };
    let records = document
        .get("streams")
        .and_then(Value::as_array)
        .ok_or_else(|| invalid("missing streams array"))?;
    if records.len() > limits.streams {
        return Err(DemuxErrorKind::Limit {
            name: "stream count",
            limit: limits.streams,
        });
    }
    let mut streams = Vec::new();
    for stream in records {
        let index = u32::try_from(unsigned(
            stream
                .get("index")
                .ok_or_else(|| invalid("missing stream index"))?,
        )?)
        .map_err(|_| invalid("stream index overflow"))?;
        let tag = string(stream, "codec_tag")?
            .strip_prefix("0x")
            .ok_or_else(|| invalid("invalid codec tag"))?;
        let codec_tag = u32::from_str_radix(tag, 16).map_err(|_| invalid("invalid codec tag"))?;
        let (num, den) = string(stream, "time_base")?
            .split_once('/')
            .ok_or_else(|| invalid("invalid time base"))?;
        let numerator = num
            .parse::<i32>()
            .map_err(|_| invalid("invalid time base numerator"))?;
        let denominator = den
            .parse::<i32>()
            .map_err(|_| invalid("invalid time base denominator"))?;
        if numerator <= 0 || denominator <= 0 {
            return Err(invalid("time base must be positive"));
        }
        let id = match stream.get("id") {
            None | Some(Value::Null) => None,
            Some(v) => Some(
                v.as_str()
                    .ok_or_else(|| invalid("invalid stream id"))?
                    .to_owned(),
            ),
        };
        streams.push(StreamInfo {
            index,
            id,
            codec_tag,
            codec_tag_string: string(stream, "codec_tag_string")?.to_owned(),
            time_base: TimeBase {
                numerator,
                denominator,
            },
        });
    }
    streams.sort_by_key(|s| s.index);
    if streams.windows(2).any(|s| s[0].index == s[1].index) {
        return Err(invalid("duplicate stream index"));
    }
    Ok((encoder, streams))
}

fn packets(
    capture: &Capture,
    index: u32,
    encoder: Option<&str>,
    decoder: &MetadataDecoder,
    limits: &ProbeLimits,
    total: &mut usize,
) -> Result<Vec<TimedPacket>, DemuxErrorKind> {
    let document = document(capture)?;
    let records = document
        .get("packets")
        .and_then(Value::as_array)
        .ok_or_else(|| invalid("missing packets array"))?;
    if records.len() > limits.packets_per_track {
        return Err(DemuxErrorKind::Limit {
            name: "packet count",
            limit: limits.packets_per_track,
        });
    }
    let mut packets = Vec::new();
    for packet in records {
        if unsigned(
            packet
                .get("stream_index")
                .ok_or_else(|| invalid("missing packet stream index"))?,
        )? != u64::from(index)
        {
            return Err(invalid("packet stream index mismatch"));
        }
        let pts = timestamp(packet.get("pts"))?;
        let dts = timestamp(packet.get("dts"))?;
        let source_position = position(packet.get("pos"))?;
        let size = usize::try_from(unsigned(
            packet
                .get("size")
                .ok_or_else(|| invalid("missing packet size"))?,
        )?)
        .map_err(|_| invalid("packet size overflow"))?;
        if size > limits.packet_bytes {
            return Err(DemuxErrorKind::Limit {
                name: "packet bytes",
                limit: limits.packet_bytes,
            });
        }
        let next_total = total
            .checked_add(size)
            .ok_or_else(|| invalid("total packet size overflow"))?;
        if next_total > limits.total_packet_bytes {
            return Err(DemuxErrorKind::Limit {
                name: "total packet bytes",
                limit: limits.total_packet_bytes,
            });
        }
        let data = string(packet, "data")?;
        let encoded_size = size
            .checked_add(2)
            .and_then(|s| (s / 3).checked_mul(4))
            .ok_or_else(|| invalid("base64 length overflow"))?;
        // FFprobe's base64 transport contains ASCII dump whitespace/newlines
        // (independent Luna carrier outputs). Count before allocation, then
        // strictly validate the remaining alphabet/padding and exact bytes.
        let normalized_len = data.bytes().filter(|b| !b.is_ascii_whitespace()).count();
        if normalized_len != encoded_size {
            return Err(invalid("packet base64 length differs from declared size"));
        }
        let normalized: Vec<u8> = data.bytes().filter(|b| !b.is_ascii_whitespace()).collect();
        let bytes = STANDARD
            .decode(normalized)
            .map_err(|_| invalid("invalid packet base64"))?;
        if bytes.len() != size {
            return Err(invalid("decoded packet length differs from declared size"));
        }
        let outcome = match encoder {
            Some(encoder) => match decoder.decode(encoder, bytes) {
                Ok(packet) => PacketOutcome::Decoded(packet),
                Err(error) => PacketOutcome::DecodeFailed(error),
            },
            None => PacketOutcome::MissingEncoder(bytes),
        };
        *total = next_total;
        packets.push(TimedPacket {
            pts,
            dts,
            source_position,
            outcome,
        });
    }
    Ok(packets)
}

/// Inspect complete selected direct metadata tracks of an unchanged local file.
/// Limits are caller inspection policies. No camera timestamp conversion or
/// nested import is performed; no-direct does not mean all metadata is absent.
pub fn inspect_direct(
    path: &Path,
    tool: &Ffprobe,
    limits: &ProbeLimits,
) -> Result<DirectMetadata, DemuxError> {
    let source = Source::open(path)?;
    let decoder = MetadataDecoder::new(limits.packet_bytes)
        .map_err(|e| DemuxError::new(DemuxErrorKind::DecoderInit(e.to_string())))?;
    let capture = source.probe(tool, ProbeStage::Inventory, limits)?;
    let (encoder, streams) = match inventory(&capture, limits) {
        Ok(v) => v,
        Err(kind) => return Err(capture.failure(kind)),
    };
    let selected: Vec<_> = streams
        .iter()
        .filter(|s| matches!(s.codec_tag, 0x646d6a64 | 0x646d7478))
        .collect();
    let excess_track_indexes = selected.iter().skip(2).map(|s| s.index).collect();
    let disposition = if !selected.is_empty() {
        DirectDisposition::DirectTracks
    } else if streams.iter().any(|s| s.codec_tag == 0x646d6163) {
        DirectDisposition::NestedUnsupported
    } else {
        DirectDisposition::NoDirectTracks
    };
    let (mut tracks, mut total) = (Vec::new(), 0_usize);
    for stream in selected.into_iter().take(2) {
        let capture = source.probe(tool, ProbeStage::Packets(stream.index), limits)?;
        let packets = match packets(
            &capture,
            stream.index,
            encoder.as_deref(),
            &decoder,
            limits,
            &mut total,
        ) {
            Ok(v) => v,
            Err(kind) => return Err(capture.failure(kind)),
        };
        tracks.push(MetadataTrack {
            stream: stream.clone(),
            packets,
        });
    }
    if !source.unchanged() {
        return Err(DemuxError::new(DemuxErrorKind::SourceChanged));
    }
    Ok(DirectMetadata {
        requested_path: path.to_owned(),
        canonical_path: source.path,
        encoder,
        streams,
        tracks,
        excess_track_indexes,
        disposition,
    })
}
