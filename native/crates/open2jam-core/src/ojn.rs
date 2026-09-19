use crate::{
    error::{CoreError, ErrorCode},
    gameplay::Ratio,
};

mod gameplay;
mod holds;
mod timing;
pub use gameplay::{CompiledOjnChart, OjnMetadata};
pub use timing::{OjnTimeline, TimedOjnEvent};

// These bounds constrain parsing work independently of untrusted header counts.
pub const MAX_SOURCE_BYTES: usize = 64 * 1024 * 1024;
const MAX_EVENTS: usize = 1_000_000;

#[derive(Debug)]
pub struct OjnSource<'a> {
    bytes: &'a [u8],
    offsets: [usize; 4],
    bpm: f32,
    levels: [i16; 3],
}

pub use crate::legacy_notes::NoteKind;

#[derive(Debug, Clone, PartialEq)]
pub enum EventKind {
    MeasureLength(f32),
    Bpm(f32),
    Sample {
        lane: Option<u8>,
        sample_index: u32,
        kind: NoteKind,
        volume: Ratio,
        pan: Ratio,
    },
}

#[derive(Debug, Clone, PartialEq)]
pub struct OjnEvent {
    pub measure: u32,
    pub position: Ratio,
    pub kind: EventKind,
}

impl<'a> OjnSource<'a> {
    pub fn parse(bytes: &'a [u8]) -> Result<Self, CoreError> {
        if bytes.len() < 300 || bytes.len() > MAX_SOURCE_BYTES {
            return Err(corrupt("OJN source length is outside parser bounds"));
        }
        if &bytes[4..8] != b"ojn\0" {
            return Err(corrupt("invalid OJN signature"));
        }
        let bpm = f32::from_le_bytes(bytes[16..20].try_into().unwrap());
        if !bpm.is_finite() || bpm <= 0.0 {
            return Err(corrupt("invalid initial OJN BPM"));
        }
        let mut offsets = [0; 4];
        for (index, offset) in offsets.iter_mut().enumerate() {
            *offset = u32_at(bytes, 284 + index * 4) as usize;
        }
        let cover_size = u32_at(bytes, 268) as usize;
        if offsets[0] < 300
            || offsets.windows(2).any(|pair| pair[0] > pair[1])
            || offsets[3] > bytes.len()
            || cover_size > bytes.len() - offsets[3]
        {
            return Err(corrupt("invalid OJN chart or cover offsets"));
        }
        let levels: [i16; 3] = std::array::from_fn(|index| {
            i16::from_le_bytes(bytes[20 + index * 2..22 + index * 2].try_into().unwrap())
        });
        if levels.iter().any(|level| *level < 0)
            || (0..3).any(|index| u32_at(bytes, 272 + index * 4) > i32::MAX as u32)
        {
            return Err(corrupt("negative OJN level or duration"));
        }
        Ok(Self {
            bytes,
            offsets,
            bpm,
            levels,
        })
    }

    pub fn title(&self) -> Result<String, CoreError> {
        decode_text(self.title_bytes())
    }
    pub fn artist(&self) -> Result<String, CoreError> {
        decode_text(self.artist_bytes())
    }
    // Retain source bytes for diagnostics and companion resolution by the file adapter.
    pub fn title_bytes(&self) -> &'a [u8] {
        text(&self.bytes[108..172])
    }
    pub fn artist_bytes(&self) -> &'a [u8] {
        text(&self.bytes[172..204])
    }
    pub fn companion_bytes(&self) -> &'a [u8] {
        text(&self.bytes[236..268])
    }
    pub fn bpm(&self) -> f32 {
        self.bpm
    }
    pub fn levels(&self) -> [i16; 3] {
        self.levels
    }
    pub fn duration_seconds(&self, chart_index: usize) -> Result<u32, CoreError> {
        if chart_index >= 3 {
            return Err(corrupt("OJN chart index must be 0, 1 or 2"));
        }
        Ok(u32_at(self.bytes, 272 + chart_index * 4))
    }

    pub fn events(
        &self,
        chart_index: usize,
        checkpoint: &mut impl FnMut() -> Result<(), CoreError>,
    ) -> Result<Vec<OjnEvent>, CoreError> {
        if chart_index >= 3 {
            return Err(corrupt("OJN chart index must be 0, 1 or 2"));
        }
        let mut bytes = &self.bytes[self.offsets[chart_index]..self.offsets[chart_index + 1]];
        let mut events = Vec::new();
        while !bytes.is_empty() {
            checkpoint()?;
            if bytes.len() < 8 {
                return Err(corrupt("truncated OJN package header"));
            }
            let measure = u32_at(bytes, 0);
            let channel = i16::from_le_bytes(bytes[4..6].try_into().unwrap());
            let count = i16::from_le_bytes(bytes[6..8].try_into().unwrap());
            if measure > i32::MAX as u32 || channel < 0 || count < 0 {
                return Err(corrupt("negative OJN package field"));
            }
            let count = count as usize;
            bytes = &bytes[8..];
            if count > bytes.len() / 4 {
                return Err(corrupt("truncated OJN package events"));
            }
            for (index, entry) in bytes[..count * 4].chunks_exact(4).enumerate() {
                if index % 1024 == 0 {
                    checkpoint()?;
                }
                let kind = if channel <= 1 {
                    let value = f32::from_le_bytes(entry.try_into().unwrap());
                    if value == 0.0 {
                        continue;
                    }
                    if !value.is_finite() || value < 0.0 {
                        return Err(corrupt("invalid OJN timing value"));
                    }
                    if channel == 0 {
                        EventKind::MeasureLength(value)
                    } else {
                        EventKind::Bpm(value)
                    }
                } else {
                    let sample = i16::from_le_bytes(entry[..2].try_into().unwrap());
                    if sample == 0 {
                        continue;
                    }
                    if sample < 0 || entry[3] > 127 {
                        return Err(corrupt("negative OJN sample or note type"));
                    }
                    let volume = entry[2] >> 4;
                    let pan = entry[2] & 15;
                    EventKind::Sample {
                        lane: (2..=8).contains(&channel).then(|| (channel - 2) as u8),
                        sample_index: sample as u32 - 1 + if entry[3] % 8 > 3 { 1000 } else { 0 },
                        kind: match entry[3] % 4 {
                            2 => NoteKind::Hold,
                            3 => NoteKind::Release,
                            _ => NoteKind::Tap,
                        },
                        volume: Ratio::new(if volume == 0 { 16 } else { i64::from(volume) }, 16)?,
                        pan: Ratio::new(if pan == 0 { 0 } else { i64::from(pan) - 8 }, 8)?,
                    }
                };
                if events.len() == MAX_EVENTS {
                    return Err(corrupt("OJN event count exceeds parser bound"));
                }
                events.push(OjnEvent {
                    measure,
                    position: Ratio::new(index as i64, count as u32)?,
                    kind,
                });
            }
            bytes = &bytes[count * 4..];
        }
        // Java's stable sort preserves source order for simultaneous events.
        events.sort_by(|a, b| {
            a.measure.cmp(&b.measure).then_with(|| {
                (a.position.numerator() * i64::from(b.position.denominator()))
                    .cmp(&(b.position.numerator() * i64::from(a.position.denominator())))
            })
        });
        checkpoint()?;
        Ok(events)
    }
}

fn decode_text(bytes: &[u8]) -> Result<String, CoreError> {
    if let Ok(text) = std::str::from_utf8(bytes) {
        return Ok(text.to_owned());
    }
    // OJN has no encoding label. Guess each bounded field independently so mixed
    // encodings do not contaminate one another; never use this guess as a file path.
    let mut detector = chardetng::EncodingDetector::new(chardetng::Iso2022JpDetection::Deny);
    detector.feed(bytes, true);
    detector
        .guess(None, chardetng::Utf8Detection::Allow)
        .decode_without_bom_handling_and_without_replacement(bytes)
        .map(|text| text.into_owned())
        .ok_or_else(|| corrupt("invalid OJN metadata encoding"))
}

fn text(bytes: &[u8]) -> &[u8] {
    &bytes[..bytes
        .iter()
        .position(|byte| *byte == 0)
        .unwrap_or(bytes.len())]
}
fn u32_at(bytes: &[u8], offset: usize) -> u32 {
    u32::from_le_bytes(bytes[offset..offset + 4].try_into().unwrap())
}
fn corrupt(message: &str) -> CoreError {
    CoreError::new(ErrorCode::CorruptChart, message)
}
