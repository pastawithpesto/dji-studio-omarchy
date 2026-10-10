//! One-level carrier transport. Astra375 approved the byte-backed boundary;
//! bounds, temporary files and result/error policies are independent design.
use super::*;
use std::io::Write;
use std::os::unix::fs::{DirBuilderExt, FileExt, PermissionsExt};
use std::sync::atomic::{AtomicU64, Ordering};

const CAMD: u32 = 0x646d6163;
const DIRECT: [u32; 2] = [0x646d6a64, 0x646d7478];

#[derive(Debug, Clone)]
pub struct NestedLimits {
    pub carrier_bytes: usize,
    pub top_level_boxes: usize,
    pub outer_camd_packets: usize,
    pub inspection_timeout: Duration,
    pub temp_root: PathBuf,
}
impl Default for NestedLimits {
    fn default() -> Self {
        Self {
            carrier_bytes: 32 * 1024 * 1024,
            top_level_boxes: 16384,
            outer_camd_packets: 10000,
            inspection_timeout: Duration::from_secs(90),
            temp_root: std::env::temp_dir(),
        }
    }
}

#[derive(Debug)]
pub struct OuterInventory {
    pub requested_path: PathBuf,
    pub canonical_path: PathBuf,
    pub encoder: Option<String>,
    pub streams: Vec<StreamInfo>,
    pub selected_camd_index: Option<u32>,
    pub ignored_camd_indexes: Vec<u32>,
}
#[derive(Debug)]
pub struct InnerInventory {
    /// Diagnostic only: schema dispatch always uses the outer encoder.
    pub encoder: Option<String>,
    pub streams: Vec<StreamInfo>,
    pub selected_track_indexes: Vec<u32>,
    pub excess_track_indexes: Vec<u32>,
}
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CarrierPart {
    pub sequence: usize,
    pub pts: Option<i64>,
    pub dts: Option<i64>,
    pub outer_source_position: Option<u64>,
    pub carrier_offset: usize,
    pub length: usize,
}
#[derive(Debug)]
pub enum CarrierOrigin {
    CamdStreamParts {
        stream: StreamInfo,
        parts: Vec<CarrierPart>,
    },
    TopLevelBox {
        tag: [u8; 4],
        box_offset: u64,
        header_bytes: u8,
        payload_offset: u64,
        payload_len: u64,
    },
}
#[derive(Debug)]
pub struct NestedCarrier {
    bytes: Vec<u8>,
    origin: CarrierOrigin,
}
impl NestedCarrier {
    pub fn bytes(&self) -> &[u8] {
        &self.bytes
    }
    pub fn origin(&self) -> &CarrierOrigin {
        &self.origin
    }
}
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum NestedDisposition {
    NoNestedCarrier,
    NoInnerDirectTracks,
    InnerDirectTracks,
}
#[derive(Debug)]
pub struct NestedMetadata {
    pub outer: OuterInventory,
    pub carrier: Option<NestedCarrier>,
    pub inner: Option<InnerInventory>,
    pub tracks: Vec<MetadataTrack>,
    pub disposition: NestedDisposition,
}
#[derive(Debug, Default)]
pub struct NestedProgress {
    pub outer: Option<OuterInventory>,
    pub carrier: Option<NestedCarrier>,
    pub inner: Option<InnerInventory>,
    pub completed_tracks: Vec<MetadataTrack>,
}
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum NestedStage {
    OuterInput,
    OuterInventory,
    OuterPackets(u32),
    BoxExtraction,
    TemporaryTransport,
    InnerInventory,
    InnerPackets(u32),
    FinalConsistency,
    Cleanup,
}
#[derive(Debug)]
pub enum NestedErrorKind {
    Probe(Box<DemuxError>),
    SourceChanged(Option<Box<DemuxError>>),
    ExtractionIo(String),
    MalformedBox(String),
    Limit { name: &'static str, limit: usize },
    EmptyCarrier,
    TemporaryIo(String),
    Deadline(Option<Box<DemuxError>>),
    InvalidPolicy(String),
    DecoderInit(String),
    CleanupOnly,
}
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CleanupKind {
    Identity,
    Residue,
    Inspect,
    Unlink,
    RemoveDirectory,
}
#[derive(Debug)]
pub struct CleanupDiagnostic {
    pub kind: CleanupKind,
    pub path: PathBuf,
    pub message: String,
}
#[derive(Debug)]
pub struct NestedError {
    pub kind: NestedErrorKind,
    pub stage: NestedStage,
    pub context: Box<NestedProgress>,
    pub cleanup: Option<Box<CleanupDiagnostic>>,
}
impl fmt::Display for NestedError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "nested metadata {:?}: ", self.stage)?;
        match &self.kind {
            NestedErrorKind::Probe(e) => write!(f, "{e}"),
            NestedErrorKind::SourceChanged(_) => f.write_str("outer source changed"),
            NestedErrorKind::ExtractionIo(s)
            | NestedErrorKind::MalformedBox(s)
            | NestedErrorKind::TemporaryIo(s)
            | NestedErrorKind::InvalidPolicy(s)
            | NestedErrorKind::DecoderInit(s) => f.write_str(s),
            NestedErrorKind::Limit { name, limit } => {
                write!(f, "{name} exceeds caller limit {limit}")
            }
            NestedErrorKind::EmptyCarrier => f.write_str("selected carrier is empty; no fallback"),
            NestedErrorKind::Deadline(_) => f.write_str("total inspection deadline exceeded"),
            NestedErrorKind::CleanupOnly => f.write_str("owned temporary cleanup failed"),
        }?;
        if let Some(d) = &self.cleanup {
            write!(f, "; cleanup {:?} at {:?}: {}", d.kind, d.path, d.message)?;
        }
        Ok(())
    }
}
impl Error for NestedError {}

fn deadline_check(deadline: Instant) -> Result<(), NestedErrorKind> {
    if Instant::now() >= deadline {
        Err(NestedErrorKind::Deadline(None))
    } else {
        Ok(())
    }
}
fn consistent(source: &Source) -> Result<(), NestedErrorKind> {
    if source.unchanged() {
        Ok(())
    } else {
        Err(NestedErrorKind::SourceChanged(None))
    }
}
fn probe(
    source: &Source,
    outer: &Source,
    tool: &Ffprobe,
    stage: ProbeStage,
    limits: &ProbeLimits,
    deadline: Instant,
) -> Result<Capture, NestedErrorKind> {
    deadline_check(deadline)?;
    consistent(outer)?;
    let mut bounded = limits.clone();
    bounded.timeout = bounded
        .timeout
        .min(deadline.saturating_duration_since(Instant::now()));
    let result = source.probe_until(tool, stage, &bounded, Some(deadline));
    if !outer.unchanged() {
        return Err(NestedErrorKind::SourceChanged(result.err().map(Box::new)));
    }
    match result {
        Ok(capture) => {
            deadline_check(deadline)?;
            Ok(capture)
        }
        Err(e) if matches!(e.kind, DemuxErrorKind::Timeout) && Instant::now() >= deadline => {
            Err(NestedErrorKind::Deadline(Some(Box::new(e))))
        }
        Err(e) => Err(NestedErrorKind::Probe(Box::new(e))),
    }
}
fn parse_inventory(
    capture: Capture,
    limits: &ProbeLimits,
) -> Result<(Option<String>, Vec<StreamInfo>), NestedErrorKind> {
    inventory(&capture, limits).map_err(|e| NestedErrorKind::Probe(Box::new(capture.failure(e))))
}
fn parse_packets(
    capture: Capture,
    index: u32,
    limits: &ProbeLimits,
    total: &mut usize,
) -> Result<Vec<RawTimedPacket>, NestedErrorKind> {
    raw_packets(&capture, index, limits, total)
        .map_err(|e| NestedErrorKind::Probe(Box::new(capture.failure(e))))
}

fn read_exact_at(
    source: &Source,
    mut bytes: &mut [u8],
    mut offset: u64,
    deadline: Instant,
) -> Result<(), NestedErrorKind> {
    while !bytes.is_empty() {
        deadline_check(deadline)?;
        match source.file.read_at(bytes, offset) {
            Ok(0) => {
                return Err(NestedErrorKind::ExtractionIo(
                    "unexpected EOF while reading carrier".into(),
                ));
            }
            Ok(n) => {
                offset = offset
                    .checked_add(n as u64)
                    .ok_or_else(|| NestedErrorKind::MalformedBox("read offset overflow".into()))?;
                bytes = &mut bytes[n..];
            }
            Err(e) if e.kind() == io::ErrorKind::Interrupted => {}
            Err(e) => return Err(NestedErrorKind::ExtractionIo(e.to_string())),
        }
    }
    Ok(())
}
fn box_carrier(
    source: &Source,
    limits: &NestedLimits,
    deadline: Instant,
) -> Result<Option<NestedCarrier>, NestedErrorKind> {
    consistent(source)?;
    let len = source.stamp.len;
    let mut offset = 0_u64;
    let mut count = 0_usize;
    while offset < len {
        deadline_check(deadline)?;
        if count >= limits.top_level_boxes {
            return Err(NestedErrorKind::Limit {
                name: "top-level boxes",
                limit: limits.top_level_boxes,
            });
        }
        count += 1;
        let malformed = |s: &str| NestedErrorKind::MalformedBox(format!("box at {offset}: {s}"));
        if len - offset < 8 {
            return Err(malformed("truncated header"));
        }
        let mut header = [0_u8; 8];
        read_exact_at(source, &mut header, offset, deadline)?;
        let size = u32::from_be_bytes(header[..4].try_into().unwrap());
        let tag: [u8; 4] = header[4..].try_into().unwrap();
        let (span, header_bytes) = if size == 1 {
            if len - offset < 16 {
                return Err(malformed("truncated extended header"));
            }
            let mut extended = [0_u8; 8];
            read_exact_at(source, &mut extended, offset + 8, deadline)?;
            (u64::from_be_bytes(extended), 16_u8)
        } else if size == 0 {
            (len - offset, 8)
        } else {
            (u64::from(size), 8)
        };
        if span < u64::from(header_bytes) {
            return Err(malformed("size smaller than header"));
        }
        let end = offset
            .checked_add(span)
            .ok_or_else(|| malformed("extent overflow"))?;
        if end > len {
            return Err(malformed("extent beyond held file length"));
        }
        if tag == *b"META" || tag == *b"camd" {
            let payload_offset = offset
                .checked_add(u64::from(header_bytes))
                .ok_or_else(|| malformed("payload offset overflow"))?;
            let payload_len = span - u64::from(header_bytes);
            if payload_len == 0 {
                return Err(NestedErrorKind::EmptyCarrier);
            }
            let n = usize::try_from(payload_len)
                .ok()
                .filter(|n| *n <= limits.carrier_bytes)
                .ok_or(NestedErrorKind::Limit {
                    name: "carrier bytes",
                    limit: limits.carrier_bytes,
                })?;
            let mut bytes = vec![0; n];
            read_exact_at(source, &mut bytes, payload_offset, deadline)?;
            consistent(source)?;
            return Ok(Some(NestedCarrier {
                bytes,
                origin: CarrierOrigin::TopLevelBox {
                    tag,
                    box_offset: offset,
                    header_bytes,
                    payload_offset,
                    payload_len,
                },
            }));
        }
        offset = end;
    }
    consistent(source)?;
    Ok(None)
}

#[derive(Clone, Copy, PartialEq, Eq)]
struct Identity {
    dev: u64,
    ino: u64,
}
impl Identity {
    fn of(m: &fs::Metadata) -> Self {
        Self {
            dev: m.dev(),
            ino: m.ino(),
        }
    }
}
static TEMP_SEQUENCE: AtomicU64 = AtomicU64::new(0);
struct OwnedTemp {
    directory: PathBuf,
    file: PathBuf,
    directory_id: Option<Identity>,
    file_id: Option<Identity>,
    finished: bool,
}
impl OwnedTemp {
    fn create(root: &Path, deadline: Instant) -> Result<Self, NestedErrorKind> {
        for _ in 0..64 {
            deadline_check(deadline)?;
            let directory = root.join(format!(
                "dji-nested-{}-{}",
                std::process::id(),
                TEMP_SEQUENCE.fetch_add(1, Ordering::Relaxed)
            ));
            match fs::DirBuilder::new().mode(0o700).create(&directory) {
                Ok(()) => {
                    return Ok(Self {
                        file: directory.join("carrier.bin"),
                        directory,
                        directory_id: None,
                        file_id: None,
                        finished: false,
                    });
                }
                Err(e) if e.kind() == io::ErrorKind::AlreadyExists => {}
                Err(e) => return Err(NestedErrorKind::TemporaryIo(e.to_string())),
            }
        }
        Err(NestedErrorKind::TemporaryIo(
            "64 exclusive temporary directory attempts exhausted".into(),
        ))
    }
    fn initialize(&mut self, bytes: &[u8], deadline: Instant) -> Result<(), NestedErrorKind> {
        let temp_io = |e: io::Error| NestedErrorKind::TemporaryIo(e.to_string());
        let dir = fs::OpenOptions::new()
            .read(true)
            .custom_flags(libc::O_DIRECTORY | libc::O_NOFOLLOW | libc::O_NONBLOCK)
            .open(&self.directory)
            .map_err(temp_io)?;
        let m = dir.metadata().map_err(temp_io)?;
        self.directory_id = Some(Identity::of(&m));
        if !m.is_dir() {
            return Err(NestedErrorKind::TemporaryIo(
                "temporary object is not a directory".into(),
            ));
        }
        dir.set_permissions(fs::Permissions::from_mode(0o700))
            .map_err(temp_io)?;
        if dir.metadata().map_err(temp_io)?.mode() & 0o777 != 0o700 {
            return Err(NestedErrorKind::TemporaryIo(
                "temporary directory permissions are not 0700".into(),
            ));
        }
        deadline_check(deadline)?;
        let mut file = fs::OpenOptions::new()
            .write(true)
            .create_new(true)
            .mode(0o600)
            .custom_flags(libc::O_NOFOLLOW | libc::O_NONBLOCK)
            .open(&self.file)
            .map_err(temp_io)?;
        let m = file.metadata().map_err(temp_io)?;
        self.file_id = Some(Identity::of(&m));
        if !m.is_file() {
            return Err(NestedErrorKind::TemporaryIo(
                "temporary carrier is not regular".into(),
            ));
        }
        file.set_permissions(fs::Permissions::from_mode(0o600))
            .map_err(temp_io)?;
        if file.metadata().map_err(temp_io)?.mode() & 0o777 != 0o600 {
            return Err(NestedErrorKind::TemporaryIo(
                "temporary file permissions are not 0600".into(),
            ));
        }
        file.write_all(bytes).map_err(temp_io)?;
        file.flush().map_err(temp_io)?;
        drop(file);
        deadline_check(deadline)
    }
    fn diagnostic(
        &self,
        kind: CleanupKind,
        path: &Path,
        message: impl ToString,
    ) -> CleanupDiagnostic {
        let message: String = message.to_string().chars().take(512).collect();
        CleanupDiagnostic {
            kind,
            path: path.to_path_buf(),
            message,
        }
    }
    fn cleanup(&mut self) -> Result<(), CleanupDiagnostic> {
        self.finished = true; // Uncertain contents are preserved, including on Drop.
        let directory = fs::symlink_metadata(&self.directory)
            .map_err(|e| self.diagnostic(CleanupKind::Inspect, &self.directory, e))?;
        if !directory.is_dir() || self.directory_id != Some(Identity::of(&directory)) {
            return Err(self.diagnostic(
                CleanupKind::Identity,
                &self.directory,
                "directory identity unavailable or changed",
            ));
        }
        if let Some(identity) = self.file_id {
            let file = fs::symlink_metadata(&self.file)
                .map_err(|e| self.diagnostic(CleanupKind::Inspect, &self.file, e))?;
            if !file.is_file() || Identity::of(&file) != identity {
                return Err(self.diagnostic(
                    CleanupKind::Identity,
                    &self.file,
                    "file identity changed",
                ));
            }
            fs::remove_file(&self.file)
                .map_err(|e| self.diagnostic(CleanupKind::Unlink, &self.file, e))?;
            self.file_id = None;
        }
        let mut entries = fs::read_dir(&self.directory)
            .map_err(|e| self.diagnostic(CleanupKind::Inspect, &self.directory, e))?;
        if let Some(entry) = entries.next() {
            entry.map_err(|e| self.diagnostic(CleanupKind::Inspect, &self.directory, e))?;
            return Err(self.diagnostic(
                CleanupKind::Residue,
                &self.directory,
                "unexpected entry; directory preserved",
            ));
        }
        let directory = fs::symlink_metadata(&self.directory)
            .map_err(|e| self.diagnostic(CleanupKind::Inspect, &self.directory, e))?;
        if !directory.is_dir() || self.directory_id != Some(Identity::of(&directory)) {
            return Err(self.diagnostic(
                CleanupKind::Identity,
                &self.directory,
                "directory identity changed before removal",
            ));
        }
        fs::remove_dir(&self.directory)
            .map_err(|e| self.diagnostic(CleanupKind::RemoveDirectory, &self.directory, e))
    }
}
impl Drop for OwnedTemp {
    fn drop(&mut self) {
        if !self.finished {
            let _ = self.cleanup();
        }
    }
}

/// Explicit single-level inspection; no recursive fallback or timing conversion.
pub fn inspect_nested(
    path: &Path,
    tool: &Ffprobe,
    probe_limits: &ProbeLimits,
    nested_limits: &NestedLimits,
) -> Result<NestedMetadata, NestedError> {
    let started = Instant::now();
    let mut context = NestedProgress::default();
    let mut stage = NestedStage::OuterInput;
    let mut temporary = None;
    let mut outer_source = None;
    let mut result = (|| {
        let deadline = started
            .checked_add(nested_limits.inspection_timeout)
            .ok_or_else(|| NestedErrorKind::InvalidPolicy("inspection deadline overflow".into()))?;
        deadline_check(deadline)?;
        outer_source = Some(Source::open(path).map_err(|e| NestedErrorKind::Probe(Box::new(e)))?);
        let source = outer_source.as_ref().unwrap();
        stage = NestedStage::OuterInventory;
        let capture = probe(
            source,
            source,
            tool,
            ProbeStage::Inventory,
            probe_limits,
            deadline,
        )?;
        let (encoder, streams) = parse_inventory(capture, probe_limits)?;
        let camd: Vec<_> = streams
            .iter()
            .filter(|s| s.codec_tag == CAMD)
            .map(|s| s.index)
            .collect();
        context.outer = Some(OuterInventory {
            requested_path: path.to_path_buf(),
            canonical_path: source.path.clone(),
            encoder,
            streams,
            selected_camd_index: camd.first().copied(),
            ignored_camd_indexes: camd.iter().skip(1).copied().collect(),
        });
        let outer = context.outer.as_ref().unwrap();
        context.carrier = if let Some(index) = outer.selected_camd_index {
            stage = NestedStage::OuterPackets(index);
            let mut limits = probe_limits.clone();
            limits.packets_per_track = limits
                .packets_per_track
                .min(nested_limits.outer_camd_packets);
            limits.total_packet_bytes = limits.total_packet_bytes.min(nested_limits.carrier_bytes);
            let capture = probe(
                source,
                source,
                tool,
                ProbeStage::Packets(index),
                &limits,
                deadline,
            )?;
            let raw = parse_packets(capture, index, &limits, &mut 0)?;
            let mut bytes = Vec::new();
            let mut parts = Vec::new();
            for (sequence, packet) in raw.into_iter().enumerate() {
                deadline_check(deadline)?;
                let carrier_offset = bytes.len();
                let next = carrier_offset
                    .checked_add(packet.bytes.len())
                    .filter(|n| *n <= nested_limits.carrier_bytes)
                    .ok_or(NestedErrorKind::Limit {
                        name: "carrier bytes",
                        limit: nested_limits.carrier_bytes,
                    })?;
                parts.push(CarrierPart {
                    sequence,
                    pts: packet.pts,
                    dts: packet.dts,
                    outer_source_position: packet.source_position,
                    carrier_offset,
                    length: next - carrier_offset,
                });
                bytes.extend_from_slice(&packet.bytes);
            }
            if bytes.is_empty() {
                return Err(NestedErrorKind::EmptyCarrier);
            }
            Some(NestedCarrier {
                bytes,
                origin: CarrierOrigin::CamdStreamParts {
                    stream: outer
                        .streams
                        .iter()
                        .find(|s| s.index == index)
                        .unwrap()
                        .clone(),
                    parts,
                },
            })
        } else {
            stage = NestedStage::BoxExtraction;
            box_carrier(source, nested_limits, deadline)?
        };
        consistent(source)?;
        deadline_check(deadline)?;
        let Some(carrier) = context.carrier.as_ref() else {
            stage = NestedStage::FinalConsistency;
            return Ok(NestedDisposition::NoNestedCarrier);
        };
        stage = NestedStage::TemporaryTransport;
        temporary = Some(OwnedTemp::create(&nested_limits.temp_root, deadline)?);
        let temp = temporary.as_mut().unwrap();
        temp.initialize(carrier.bytes(), deadline)?;
        let inner_source =
            Source::open(&temp.file).map_err(|e| NestedErrorKind::Probe(Box::new(e)))?;
        stage = NestedStage::InnerInventory;
        let capture = probe(
            &inner_source,
            source,
            tool,
            ProbeStage::Inventory,
            probe_limits,
            deadline,
        )?;
        let (encoder, streams) = parse_inventory(capture, probe_limits)?;
        let direct: Vec<_> = streams
            .iter()
            .filter(|s| DIRECT.contains(&s.codec_tag))
            .cloned()
            .collect();
        context.inner = Some(InnerInventory {
            encoder,
            streams,
            selected_track_indexes: direct.iter().take(2).map(|s| s.index).collect(),
            excess_track_indexes: direct.iter().skip(2).map(|s| s.index).collect(),
        });
        let decoder = MetadataDecoder::new(probe_limits.packet_bytes)
            .map_err(|e| NestedErrorKind::DecoderInit(e.to_string()))?;
        let mut total = 0;
        for stream in direct.into_iter().take(2) {
            stage = NestedStage::InnerPackets(stream.index);
            let capture = probe(
                &inner_source,
                source,
                tool,
                ProbeStage::Packets(stream.index),
                probe_limits,
                deadline,
            )?;
            let raw = parse_packets(capture, stream.index, probe_limits, &mut total)?;
            let packets = decode_packets(
                raw,
                context.outer.as_ref().unwrap().encoder.as_deref(),
                &decoder,
            );
            context
                .completed_tracks
                .push(MetadataTrack { stream, packets });
            deadline_check(deadline)?;
        }
        stage = NestedStage::FinalConsistency;
        consistent(source)?;
        if !inner_source.unchanged() {
            return Err(NestedErrorKind::Probe(Box::new(DemuxError::new(
                DemuxErrorKind::SourceChanged,
            ))));
        }
        deadline_check(deadline)?;
        Ok(if context.completed_tracks.is_empty() {
            NestedDisposition::NoInnerDirectTracks
        } else {
            NestedDisposition::InnerDirectTracks
        })
    })();
    let cleanup = temporary
        .as_mut()
        .and_then(|t| t.cleanup().err())
        .map(Box::new);
    if result.is_ok() {
        stage = NestedStage::FinalConsistency;
        if outer_source
            .as_ref()
            .is_some_and(|source| !source.unchanged())
        {
            result = Err(NestedErrorKind::SourceChanged(None));
        } else if started.elapsed() >= nested_limits.inspection_timeout {
            result = Err(NestedErrorKind::Deadline(None));
        }
    }
    match result {
        Err(kind) => Err(NestedError {
            kind,
            stage,
            context: Box::new(context),
            cleanup,
        }),
        Ok(_) if cleanup.is_some() => Err(NestedError {
            kind: NestedErrorKind::CleanupOnly,
            stage: NestedStage::Cleanup,
            context: Box::new(context),
            cleanup,
        }),
        Ok(disposition) => Ok(NestedMetadata {
            outer: context.outer.unwrap(),
            carrier: context.carrier,
            inner: context.inner,
            tracks: context.completed_tracks,
            disposition,
        }),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn exclusive_temporary_collisions_preserve_every_existing_candidate() {
        // This library test process has no concurrent nested inspections. The
        // integration tests run in a separate process with a separate counter.
        let root =
            std::env::temp_dir().join(format!("dji-nested-collision-test-{}", std::process::id()));
        fs::create_dir(&root).unwrap();
        let first = TEMP_SEQUENCE.load(Ordering::Relaxed);
        for sequence in first..first + 64 {
            let dir = root.join(format!("dji-nested-{}-{sequence}", std::process::id()));
            fs::create_dir(&dir).unwrap();
            fs::write(dir.join("preexisting"), b"preserve").unwrap();
        }
        let result = OwnedTemp::create(&root, Instant::now() + Duration::from_secs(5));
        assert!(matches!(result, Err(NestedErrorKind::TemporaryIo(_))));
        assert_eq!(fs::read_dir(&root).unwrap().count(), 64);
        for entry in fs::read_dir(&root).unwrap() {
            assert_eq!(
                fs::read(entry.unwrap().path().join("preexisting")).unwrap(),
                b"preserve"
            );
        }
        // Only this exclusively created test root is removed.
        fs::remove_dir_all(root).unwrap();
    }
}
