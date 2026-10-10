//! Experimental whole-buffer device metadata decoding.
//!
//! Contract: sol-review/resumed-metadata-20261010/CONTRACT.md, Astra bus approval
//! 56. Exact descriptors and packet boundary are recovered static facts. This
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

/// A reusable decoder for the two evidenced 360-device schemas.
#[derive(Debug)]
pub struct MetadataDecoder {
    oqb101: MessageDescriptor,
    wab530: MessageDescriptor,
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
            oqb101: message("oqb101.ProductMeta")?,
            wab530: message("wab530.ProductMeta")?,
            max_packet_bytes,
        })
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
            let descriptor = match registration.package {
                "oqb101" => &self.oqb101,
                "wab530" => &self.wab530,
                _ => return Err(PacketFailureKind::UnsupportedSchema(registration)),
            };
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
