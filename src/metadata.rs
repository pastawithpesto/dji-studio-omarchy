//! Metadata discovery boundaries recovered from VinceEditor.
//! See sol-review/METADATA-PARSER-CONTRACT.md. This does not decode protobuf
//! packets or establish camera timestamp units.
use std::io::{self, Read, Seek, SeekFrom};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Registration {
    pub encoder: &'static str,
    pub product: u32,
    pub package: &'static str,
}

include!("metadata_registry.rs");

/// Exact encoder matching is intentional: do not silently choose another
/// camera's schema or normalize the vendor's byte-string dispatch.
pub fn registration(encoder: &str) -> Option<Registration> {
    REGISTRATIONS.iter().find(|r| r.encoder == encoder).copied()
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct BoxExtent {
    pub tag: [u8; 4],
    pub payload_offset: u64,
    pub payload_len: u64,
}

/// Find top-level nested metadata containers without reading video payloads
/// into memory. Handles normal, extended and EOF sizes. Rejects malformed
/// sizes; the original data remains untouched. Leaves the cursor at EOF.
pub fn nested_containers<R: Read + Seek>(reader: &mut R) -> io::Result<Vec<BoxExtent>> {
    let end = reader.seek(SeekFrom::End(0))?;
    let mut position = 0_u64;
    let mut found = Vec::new();
    while position < end {
        if end - position < 8 {
            return Err(io::Error::new(
                io::ErrorKind::InvalidData,
                "truncated box header",
            ));
        }
        reader.seek(SeekFrom::Start(position))?;
        let mut header = [0_u8; 8];
        reader.read_exact(&mut header)?;
        let short_size = u32::from_be_bytes(header[..4].try_into().unwrap());
        let tag: [u8; 4] = header[4..].try_into().unwrap();
        let (size, header_size) = match short_size {
            0 => (end - position, 8_u64),
            1 => {
                let mut extended = [0_u8; 8];
                reader.read_exact(&mut extended)?;
                (u64::from_be_bytes(extended), 16_u64)
            }
            n => (u64::from(n), 8_u64),
        };
        if size < header_size || size > end - position {
            return Err(io::Error::new(
                io::ErrorKind::InvalidData,
                "invalid box extent",
            ));
        }
        if tag == *b"META" || tag == *b"camd" {
            found.push(BoxExtent {
                tag,
                payload_offset: position + header_size,
                payload_len: size - header_size,
            });
        }
        position += size;
    }
    reader.seek(SeekFrom::Start(end))?;
    Ok(found)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Cursor;

    #[test]
    fn generation_dispatch_is_exact_and_distinct() {
        assert_eq!(registration("Osmo 360").unwrap().package, "oqb101");
        assert_eq!(registration("Osmo 360 II").unwrap().package, "wab530");
        assert_eq!(registration("XTRA 360").unwrap().product, 9);
        assert_eq!(registration("osmo 360"), None);
        assert_eq!(registration("unknown camera"), None);
    }

    #[test]
    fn extended_and_eof_payloads_have_correct_boundaries() {
        let mut bytes = Vec::new();
        bytes.extend(12_u32.to_be_bytes());
        bytes.extend(b"free");
        bytes.extend([0; 4]);
        bytes.extend(1_u32.to_be_bytes());
        bytes.extend(b"META");
        bytes.extend(19_u64.to_be_bytes());
        bytes.extend([1, 2, 3]);
        bytes.extend(0_u32.to_be_bytes());
        bytes.extend(b"camd");
        bytes.extend([4, 5]);
        let mut input = Cursor::new(bytes);
        assert_eq!(
            nested_containers(&mut input).unwrap(),
            vec![
                BoxExtent {
                    tag: *b"META",
                    payload_offset: 28,
                    payload_len: 3
                },
                BoxExtent {
                    tag: *b"camd",
                    payload_offset: 39,
                    payload_len: 2
                },
            ]
        );
    }

    #[test]
    fn rejects_truncated_or_out_of_file_extents() {
        for bytes in [
            vec![0; 7],
            [4_u32.to_be_bytes().as_slice(), b"META"].concat(),
            [100_u32.to_be_bytes().as_slice(), b"camd"].concat(),
            [1_u32.to_be_bytes().as_slice(), b"META"].concat(),
        ] {
            assert!(nested_containers(&mut Cursor::new(bytes)).is_err());
        }
    }
}
