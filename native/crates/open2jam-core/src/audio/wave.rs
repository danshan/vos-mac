use super::SampleData;
use crate::error::{CoreError, ErrorCode};

pub(super) fn parse<'a>(
    bytes: &'a [u8],
    checkpoint: &mut impl FnMut() -> Result<(), CoreError>,
) -> Result<SampleData<'a>, CoreError> {
    if bytes.len() < 12
        || &bytes[..4] != b"RIFF"
        || &bytes[8..12] != b"WAVE"
        || u64::from(u32_at(bytes, 4)) + 8 != bytes.len() as u64
    {
        return Err(invalid("invalid WAV RIFF header or size"));
    }
    let mut cursor = 12;
    let mut format = None;
    let mut data = None;
    while cursor < bytes.len() {
        checkpoint()?;
        let header = bytes
            .get(cursor..cursor + 8)
            .ok_or_else(|| invalid("truncated WAV chunk header"))?;
        let length = u32_at(header, 4) as usize;
        let end = (cursor + 8)
            .checked_add(length)
            .ok_or_else(|| invalid("WAV chunk size overflow"))?;
        let chunk = bytes
            .get(cursor + 8..end)
            .ok_or_else(|| invalid("truncated WAV chunk payload"))?;
        match &header[..4] {
            b"fmt " => {
                if format.is_some() || chunk.len() < 16 {
                    return Err(invalid("invalid or duplicate WAV format chunk"));
                }
                format = Some(chunk);
            }
            b"data" => {
                if data.is_some() {
                    return Err(invalid("duplicate WAV data chunk"));
                }
                data = Some(chunk);
            }
            _ => {}
        }
        cursor = end + length % 2;
        if cursor > bytes.len() {
            return Err(invalid("missing WAV chunk padding"));
        }
    }
    let format = format.ok_or_else(|| invalid("WAV format chunk is missing"))?;
    let pcm = data.ok_or_else(|| invalid("WAV data chunk is missing"))?;
    Ok(SampleData::Wave {
        format: u16_at(format, 0),
        channels: u16_at(format, 2),
        sample_rate: u32_at(format, 4),
        byte_rate: u32_at(format, 8),
        block_align: u16_at(format, 12),
        bits_per_sample: u16_at(format, 14),
        pcm,
    })
}

fn u16_at(bytes: &[u8], offset: usize) -> u16 {
    u16::from_le_bytes(bytes[offset..offset + 2].try_into().unwrap())
}
fn u32_at(bytes: &[u8], offset: usize) -> u32 {
    u32::from_le_bytes(bytes[offset..offset + 4].try_into().unwrap())
}
fn invalid(message: &str) -> CoreError {
    CoreError::new(ErrorCode::AudioDecodeFailed, message)
}
