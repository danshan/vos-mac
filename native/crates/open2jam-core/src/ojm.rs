use crate::error::{CoreError, ErrorCode};

const MAX_SOURCE_BYTES: usize = 512 * 1024 * 1024;
const MAX_SAMPLES: usize = 65_536;

#[derive(Debug, Clone, Copy)]
pub enum OjmSampleData<'a> {
    Wave {
        format: u16,
        channels: u16,
        sample_rate: u32,
        byte_rate: u32,
        block_align: u16,
        bits_per_sample: u16,
        pcm: &'a [u8],
    },
    Ogg(&'a [u8]),
}

#[derive(Debug, Clone, Copy)]
pub struct OjmSample<'a> {
    pub index: u32,
    pub data: OjmSampleData<'a>,
}

/// Extracts bounded, borrowed sample payloads. Audio decoding is a separate step.
pub fn parse_plain_ojm<'a>(
    bytes: &'a [u8],
    checkpoint: &mut impl FnMut() -> Result<(), CoreError>,
) -> Result<Vec<OjmSample<'a>>, CoreError> {
    checkpoint()?;
    if bytes.len() < 20 || bytes.len() > MAX_SOURCE_BYTES {
        return Err(corrupt("OJM source length is outside parser bounds"));
    }
    if &bytes[..4] != b"OJM\0" {
        return Err(CoreError::new(
            ErrorCode::UnsupportedFormat,
            "expected plain OJM audio bank",
        ));
    }
    let wave_start = u32_at(bytes, 8) as usize;
    let ogg_start = u32_at(bytes, 12) as usize;
    let file_size = u32_at(bytes, 16) as usize;
    if wave_start != 20
        || ogg_start < wave_start
        || ogg_start > bytes.len()
        || file_size != bytes.len()
    {
        return Err(corrupt("invalid OJM section offsets or file size"));
    }
    let mut samples = Vec::new();
    let mut wave = &bytes[wave_start..ogg_start];
    let mut index = 0;
    while !wave.is_empty() {
        checkpoint()?;
        if index >= 1000 {
            return Err(corrupt("OJM wave sample indices overlap Ogg indices"));
        }
        if wave.len() < 56 {
            return Err(corrupt("truncated OJM wave header"));
        }
        let size = u32_at(wave, 52) as usize;
        if size > wave.len() - 56 {
            return Err(corrupt("OJM wave payload exceeds section"));
        }
        if size != 0 {
            if &wave[48..52] != b"data" {
                return Err(corrupt("invalid OJM wave data marker"));
            }
            samples.push(OjmSample {
                index,
                data: OjmSampleData::Wave {
                    format: u16_at(wave, 32),
                    channels: u16_at(wave, 34),
                    sample_rate: u32_at(wave, 36),
                    byte_rate: u32_at(wave, 40),
                    block_align: u16_at(wave, 44),
                    bits_per_sample: u16_at(wave, 46),
                    pcm: &wave[56..56 + size],
                },
            });
        }
        wave = &wave[56 + size..];
        index += 1;
    }
    let mut ogg = &bytes[ogg_start..];
    index = 1000;
    while !ogg.is_empty() {
        checkpoint()?;
        if index as usize >= MAX_SAMPLES {
            return Err(corrupt("OJM sample count exceeds parser bound"));
        }
        if ogg.len() < 36 {
            return Err(corrupt("truncated OJM Ogg header"));
        }
        let size = u32_at(ogg, 32) as usize;
        if size > ogg.len() - 36 {
            return Err(corrupt("OJM Ogg payload exceeds section"));
        }
        if size != 0 {
            samples.push(OjmSample {
                index,
                data: OjmSampleData::Ogg(&ogg[36..36 + size]),
            });
        }
        ogg = &ogg[36 + size..];
        index += 1;
    }
    Ok(samples)
}

fn u16_at(bytes: &[u8], offset: usize) -> u16 {
    u16::from_le_bytes(bytes[offset..offset + 2].try_into().unwrap())
}
fn u32_at(bytes: &[u8], offset: usize) -> u32 {
    u32::from_le_bytes(bytes[offset..offset + 4].try_into().unwrap())
}
fn corrupt(message: &str) -> CoreError {
    CoreError::new(ErrorCode::CorruptChart, message)
}
