use super::{MAX_SAMPLES, MAX_SOURCE_BYTES, OjmSample, OjmSampleData, corrupt, u16_at, u32_at};
use crate::error::{CoreError, ErrorCode};
use std::collections::BTreeSet;

/// Validates an entire M30 bank, decrypts its private buffer, and borrows Ogg payloads.
/// Hash the original source first. Discard the buffer if decoding is cancelled.
pub fn parse_m30_in_place<'a>(
    bytes: &'a mut [u8],
    checkpoint: &mut impl FnMut() -> Result<(), CoreError>,
) -> Result<Vec<OjmSample<'a>>, CoreError> {
    checkpoint()?;
    if bytes.len() < 28 || bytes.len() > MAX_SOURCE_BYTES {
        return Err(corrupt("M30 source length is outside parser bounds"));
    }
    if &bytes[..4] != b"M30\0" {
        return Err(unsupported("expected M30 audio bank"));
    }
    let mask = match u32_at(bytes, 8) {
        0 => None,
        16 => Some(b"nami"),
        32 => Some(b"0412"),
        _ => return Err(unsupported("unknown M30 encryption flag")),
    };
    let count = u32_at(bytes, 12) as usize;
    if count > MAX_SAMPLES
        || u32_at(bytes, 16) != 28
        || u32_at(bytes, 20) as usize != bytes.len() - 28
    {
        return Err(corrupt("invalid M30 sample count, offset, or payload size"));
    }
    let mut rows = Vec::new();
    let mut indices = BTreeSet::new();
    let mut offset = 28;
    for _ in 0..count {
        checkpoint()?;
        if bytes.len() - offset < 52 {
            return Err(corrupt("truncated M30 sample header"));
        }
        let size = u32_at(bytes, offset + 32) as usize;
        let codec = u16_at(bytes, offset + 36);
        let reference = u16_at(bytes, offset + 44) as i16;
        if reference < 0 {
            return Err(corrupt("negative M30 sample reference"));
        }
        let index = match codec {
            0 => 1000 + reference as u32,
            5 => reference as u32,
            _ => return Err(unsupported("unknown M30 sample codec")),
        };
        if !indices.insert(index) {
            return Err(corrupt("duplicate M30 sample reference"));
        }
        offset += 52;
        if size > bytes.len() - offset || size > 64 * 1024 * 1024 {
            return Err(corrupt("M30 Ogg payload exceeds source or decoder bounds"));
        }
        rows.push((index, offset..offset + size));
        offset += size;
    }
    if offset != bytes.len() {
        return Err(corrupt("M30 sample count leaves trailing bytes"));
    }
    if let Some(mask) = mask {
        for (_, range) in &rows {
            // Only complete four-byte groups are encrypted; trailing bytes remain unchanged.
            let end = range.start + range.len() / 4 * 4;
            for chunk in bytes[range.start..end].chunks_mut(65_536) {
                checkpoint()?;
                for (index, byte) in chunk.iter_mut().enumerate() {
                    *byte ^= mask[index % 4];
                }
            }
        }
    }
    checkpoint()?;
    Ok(rows
        .into_iter()
        .map(|(index, range)| OjmSample {
            index,
            data: OjmSampleData::Ogg(&bytes[range]),
        })
        .collect())
}

fn unsupported(message: &str) -> CoreError {
    CoreError::new(ErrorCode::UnsupportedFormat, message)
}
