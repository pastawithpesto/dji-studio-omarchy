//! Experimental whole-buffer device metadata decoding.
//!
//! Contract: sol-review/resumed-metadata-20261010/CONTRACT.md, Astra bus approval
//! 56; twelve-root expansion: metadata-ten-root-contract/CONTRACT.md, independent
//! Sol High approval 919 and author grant 924. Exact descriptors and packet boundary are recovered static facts. This
//! API, size/error policy and use of prost-reflect are independent native design.
//! It does not demux media, convert to assemble.ProductMeta, interpret camera
//! timestamps, decrypt/decompress payloads or change quaternion components.

use super::{Registration, registration};
use prost_reflect::{DescriptorPool, DynamicMessage, MessageDescriptor};
use std::{error::Error, fmt};

const DESCRIPTORS: &[u8] = include_bytes!("../../descriptors/dji-metadata-descriptors.pb");

#[derive(Debug)]
pub enum DecoderInitError {
    InvalidDescriptors(prost_reflect::DescriptorError),
    MissingMessage(&'static str),
}

impl fmt::Display for DecoderInitError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::InvalidDescriptors(error) => write!(f, "invalid embedded descriptors: {error}"),
            Self::MissingMessage(name) => write!(f, "missing embedded message descriptor: {name}"),
        }
    }
}

impl Error for DecoderInitError {
    fn source(&self) -> Option<&(dyn Error + 'static)> {
        match self {
            Self::InvalidDescriptors(error) => Some(error),
            Self::MissingMessage(_) => None,
        }
    }
}

/// A reusable decoder for the twelve explicitly bound product wire schemas.
#[derive(Debug)]
pub struct MetadataDecoder {
    roots: [(&'static str, MessageDescriptor); 12],
    max_packet_bytes: usize,
}

impl MetadataDecoder {
    /// `max_packet_bytes` is the caller's native policy, not a recovered camera
    /// limit. It bounds accepted wire length; decoded allocations can be larger.
    /// The protobuf dependency's default recursion guard remains enabled.
    pub fn new(max_packet_bytes: usize) -> Result<Self, DecoderInitError> {
        let pool =
            DescriptorPool::decode(DESCRIPTORS).map_err(DecoderInitError::InvalidDescriptors)?;
        let message = |name| {
            pool.get_message_by_name(name)
                .ok_or(DecoderInitError::MissingMessage(name))
        };
        Ok(Self {
            // Fixed lexical allowlist from the approved original factory bindings.
            // All descriptors belong to this one trusted pool.
            roots: [
                ("acb202", message("acb202.ProductMeta")?),
                ("acb203", message("acb203.ProductMeta")?),
                ("acb204", message("acb204.ProductMeta")?),
                ("hgb212", message("hgb212.ProductMeta")?),
                ("oqb101", message("oqb101.ProductMeta")?),
                ("wab140", message("wab140.ProductMeta")?),
                ("wab234", message("wab234.ProductMeta")?),
                ("wab341", message("wab341.ProductMeta")?),
                ("wab520", message("wab520.ProductMeta")?),
                ("wab521", message("wab521.ProductMeta")?),
                ("wab530", message("wab530.ProductMeta")?),
                ("wmb261", message("wmb261.ProductMeta")?),
            ],
            max_packet_bytes,
        })
    }

    fn root(&self, package: &str) -> Option<&MessageDescriptor> {
        self.roots
            .iter()
            .find(|(allowed, _)| *allowed == package)
            .map(|(_, descriptor)| descriptor)
    }

    /// Decode one complete, already-selected djmd/xtmd packet. No prefix is
    /// stripped. Every outcome retains the original bytes, including malformed
    /// tails. No alternative schema is tried after a failure.
    pub fn decode(
        &self,
        encoder: &str,
        original_packet: Vec<u8>,
    ) -> Result<DecodedPacket, PacketDecodeFailure> {
        let decode = || {
            let registration = registration(encoder)
                .ok_or_else(|| PacketFailureKind::UnknownEncoder(encoder.to_owned()))?;
            let descriptor = self
                .root(registration.package)
                .ok_or(PacketFailureKind::UnsupportedSchema(registration))?;
            if original_packet.len() > self.max_packet_bytes {
                return Err(PacketFailureKind::PacketTooLarge {
                    limit: self.max_packet_bytes,
                    actual: original_packet.len(),
                });
            }
            let message = DynamicMessage::decode(descriptor.clone(), original_packet.as_slice())
                .map_err(PacketFailureKind::InvalidProtobuf)?;
            Ok((registration, message))
        };
        match decode() {
            Ok((registration, message)) => Ok(DecodedPacket {
                registration,
                original_packet,
                message,
            }),
            Err(kind) => Err(PacketDecodeFailure {
                kind,
                original_packet,
            }),
        }
    }
}

/// Values follow the exact descriptor, including unknown fields. Message access
/// is immutable. Protobuf re-encoding can normalize ordering/duplicates/default
/// scalars; [`Self::original_packet`] is the authoritative exact byte sequence.
#[derive(Debug)]
pub struct DecodedPacket {
    registration: Registration,
    original_packet: Vec<u8>,
    message: DynamicMessage,
}

impl DecodedPacket {
    pub fn registration(&self) -> Registration {
        self.registration
    }

    pub fn original_packet(&self) -> &[u8] {
        &self.original_packet
    }

    pub fn message(&self) -> &DynamicMessage {
        &self.message
    }

    pub fn into_original_packet(self) -> Vec<u8> {
        self.original_packet
    }
}

/// These distinctions and malformed-input diagnostics are native policy, not
/// the vendor's public error mapping or a promise of identical acceptance.
#[derive(Debug)]
pub enum PacketFailureKind {
    UnknownEncoder(String),
    UnsupportedSchema(Registration),
    PacketTooLarge { limit: usize, actual: usize },
    InvalidProtobuf(prost_reflect::prost::DecodeError),
}

#[derive(Debug)]
pub struct PacketDecodeFailure {
    kind: PacketFailureKind,
    original_packet: Vec<u8>,
}

impl PacketDecodeFailure {
    pub fn kind(&self) -> &PacketFailureKind {
        &self.kind
    }

    pub fn original_packet(&self) -> &[u8] {
        &self.original_packet
    }

    pub fn into_original_packet(self) -> Vec<u8> {
        self.original_packet
    }
}

impl fmt::Display for PacketDecodeFailure {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match &self.kind {
            PacketFailureKind::UnknownEncoder(encoder) => write!(f, "unknown encoder: {encoder:?}"),
            PacketFailureKind::UnsupportedSchema(registration) => {
                write!(f, "unsupported metadata schema: {}", registration.package)
            }
            PacketFailureKind::PacketTooLarge { limit, actual } => {
                write!(
                    f,
                    "metadata packet length {actual} exceeds caller limit {limit}"
                )
            }
            PacketFailureKind::InvalidProtobuf(error) => {
                write!(f, "invalid metadata protobuf: {error}")
            }
        }
    }
}

impl Error for PacketDecodeFailure {
    fn source(&self) -> Option<&(dyn Error + 'static)> {
        match &self.kind {
            PacketFailureKind::InvalidProtobuf(error) => Some(error),
            _ => None,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::MetadataDecoder;

    #[test]
    fn private_root_selector_is_an_explicit_fail_closed_allowlist() {
        let decoder = MetadataDecoder::new(0).unwrap();
        assert_eq!(decoder.roots.len(), 12);
        for (package, descriptor) in &decoder.roots {
            assert_eq!(descriptor.full_name(), format!("{package}.ProductMeta"));
            assert!(decoder.root(package).is_some());
        }
        for package in [
            "wab020",
            "metadata",
            "assemble",
            "ClipMetaHeader",
            "ACB202",
            "acb202 ",
            "",
        ] {
            assert!(decoder.root(package).is_none(), "{package}");
        }
    }
}
