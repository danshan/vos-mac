use crate::{
    error::{CoreError, ErrorCode},
    path::SourceRelativePath,
};
use std::collections::BTreeMap;

mod timing;
pub use timing::{OsuNoteKind, OsuScrollChange, OsuTimeline, OsuVelocityChange, TimedOsuSample};

pub const MAX_SOURCE_BYTES: usize = 64 * 1024 * 1024;
const MAX_LINE_BYTES: usize = 65_536;
const MAX_EVENTS: usize = 1_000_000;
const MAX_SAMPLES: usize = 65_534;

#[derive(Debug)]
pub struct OsuSource {
    pub title: String,
    pub artist: String,
    pub creator: String,
    pub difficulty_name: String,
    pub level: u32,
    pub audio_filename: Option<SourceRelativePath>,
    pub timing: Vec<OsuTimingPoint>,
    pub notes: Vec<OsuNote>,
    pub samples: Vec<OsuSample>,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum OsuTimingKind {
    Beat { beat_length_ms: f64, meter: u32 },
    Scroll { speed: f64 },
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct OsuTimingPoint {
    pub time_ms: i32,
    pub kind: OsuTimingKind,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct OsuNote {
    pub lane: u8,
    pub time_ms: i32,
    pub end_ms: Option<i32>,
    pub sample_index: u32,
    pub volume: f32,
}

#[derive(Debug)]
pub struct OsuSample {
    pub index: u32,
    pub filename: SourceRelativePath,
}

impl OsuSource {
    pub fn parse(
        bytes: &[u8],
        checkpoint: &mut impl FnMut() -> Result<(), CoreError>,
    ) -> Result<Self, CoreError> {
        checkpoint()?;
        if bytes.len() > MAX_SOURCE_BYTES {
            return Err(corrupt("osu source exceeds parser bounds"));
        }
        for chunk in bytes.chunks(MAX_LINE_BYTES) {
            checkpoint()?;
            if chunk.contains(&0) {
                return Err(corrupt("osu source contains NUL"));
            }
        }
        let text = std::str::from_utf8(bytes).map_err(|_| corrupt("osu source is not UTF-8"))?;
        let mut source = Self {
            title: String::new(),
            artist: String::new(),
            creator: String::new(),
            difficulty_name: String::new(),
            level: 0,
            audio_filename: None,
            timing: Vec::new(),
            notes: Vec::new(),
            samples: Vec::new(),
        };
        let mut mode = 0;
        let mut keys = 0.0;
        let mut section = "";
        let mut header = false;
        let mut sample_ids = BTreeMap::new();
        for (number, raw) in text.lines().enumerate() {
            checkpoint()?;
            if raw.len() > MAX_LINE_BYTES {
                return Err(corrupt("osu line exceeds parser bounds")
                    .with_context("line", (number + 1).to_string()));
            }
            let line = raw.trim_start_matches('\u{feff}').trim();
            if line.is_empty() || line.starts_with("//") {
                continue;
            }
            if !header {
                let version = line
                    .strip_prefix("osu file format v")
                    .and_then(|value| value.parse::<u32>().ok());
                if version.is_none_or(|value| value == 0) {
                    return Err(corrupt("invalid osu format header"));
                }
                header = true;
                continue;
            }
            if line.starts_with('[') && line.ends_with(']') {
                section = &line[1..line.len() - 1];
                continue;
            }
            let parsed = (|| -> Result<(), CoreError> {
                match section {
                    "General" | "Metadata" | "Difficulty" => {
                        let (key, value) = line
                            .split_once(':')
                            .ok_or_else(|| corrupt("invalid osu property"))?;
                        let (key, value) = (key.trim(), value.trim());
                        match (section, key) {
                            ("General", "Mode") => mode = integer(value)?,
                            ("General", "AudioFilename") => {
                                source.audio_filename = if value.is_empty() {
                                    None
                                } else {
                                    Some(relative(value)?)
                                }
                            }
                            ("Difficulty", "CircleSize") => keys = decimal(value)?,
                            ("Difficulty", "OverallDifficulty") => {
                                let level = decimal(value)?;
                                if !(0.0..=f64::from(i32::MAX)).contains(&level) {
                                    return Err(corrupt("invalid overall difficulty"));
                                }
                                source.level = (level + 0.5).floor() as u32;
                            }
                            ("Metadata", "Title") => source.title = value.into(),
                            ("Metadata", "TitleUnicode") if !value.is_empty() => {
                                source.title = value.into()
                            }
                            ("Metadata", "Artist") => source.artist = value.into(),
                            ("Metadata", "ArtistUnicode") if !value.is_empty() => {
                                source.artist = value.into()
                            }
                            ("Metadata", "Creator") => source.creator = value.into(),
                            ("Metadata", "Version") => source.difficulty_name = value.into(),
                            _ => {}
                        }
                    }
                    "TimingPoints" => source.timing.push(timing_point(line)?),
                    "HitObjects" => {
                        let (mut note, filename) = note(line)?;
                        if let Some(filename) = filename {
                            let id = if let Some(id) = sample_ids.get(&filename) {
                                *id
                            } else {
                                if source.samples.len() >= MAX_SAMPLES {
                                    return Err(corrupt("too many osu custom samples"));
                                }
                                let id = source.samples.len() as u32 + 2;
                                source.samples.push(OsuSample {
                                    index: id,
                                    filename: filename.clone(),
                                });
                                sample_ids.insert(filename, id);
                                id
                            };
                            note.sample_index = id;
                        }
                        source.notes.push(note);
                    }
                    _ => {}
                }
                if source.notes.len() + source.timing.len() > MAX_EVENTS {
                    return Err(corrupt("osu event count exceeds parser bounds"));
                }
                Ok(())
            })();
            parsed.map_err(|error| error.with_context("line", (number + 1).to_string()))?;
        }
        if !header {
            return Err(corrupt("missing osu format header"));
        }
        if mode != 3 || keys != 7.0 {
            return Err(CoreError::new(
                ErrorCode::UnsupportedFormat,
                "only osu!mania 7K is supported",
            ));
        }
        if !source
            .timing
            .iter()
            .any(|point| matches!(point.kind, OsuTimingKind::Beat { .. }))
        {
            if source.notes.len() + source.timing.len() == MAX_EVENTS {
                return Err(corrupt("osu event count exceeds parser bounds"));
            }
            source.timing.insert(
                0,
                OsuTimingPoint {
                    time_ms: 0,
                    kind: OsuTimingKind::Beat {
                        beat_length_ms: 500.0,
                        meter: 4,
                    },
                },
            );
        }
        checkpoint()?;
        Ok(source)
    }
}

fn timing_point(line: &str) -> Result<OsuTimingPoint, CoreError> {
    let fields: Vec<_> = line.split(',').take(9).collect();
    if !(2..=8).contains(&fields.len()) {
        return Err(corrupt("invalid osu timing point"));
    }
    let time_ms = time(fields[0])?;
    let beat_length = decimal(fields[1])?;
    let inherited = if fields.len() >= 7 {
        integer(fields[6])?
    } else {
        1
    };
    let kind = match inherited {
        1 if beat_length > 0.0 => {
            if !(60000.0 / beat_length).is_finite() {
                return Err(corrupt("osu BPM exceeds finite numeric range"));
            }
            let meter = if fields.len() >= 3 {
                integer(fields[2])?
            } else {
                4
            };
            if meter <= 0 {
                return Err(corrupt("invalid osu timing meter"));
            }
            OsuTimingKind::Beat {
                beat_length_ms: beat_length,
                meter: meter as u32,
            }
        }
        0 if beat_length < 0.0 => {
            let speed = -100.0 / beat_length;
            if !speed.is_finite() || speed <= 0.0 {
                return Err(corrupt("invalid osu scroll speed"));
            }
            OsuTimingKind::Scroll { speed }
        }
        _ => return Err(corrupt("invalid osu timing inheritance or beat length")),
    };
    Ok(OsuTimingPoint { time_ms, kind })
}

fn note(line: &str) -> Result<(OsuNote, Option<SourceRelativePath>), CoreError> {
    let fields: Vec<_> = line.splitn(6, ',').collect();
    if fields.len() < 5 {
        return Err(corrupt("truncated osu hit object"));
    }
    let x = integer(fields[0])?;
    let time_ms = time(fields[2])?;
    let flags = integer(fields[3])?;
    if time_ms < 0 || !(0..=255).contains(&flags) {
        return Err(corrupt("invalid osu hit object time or type"));
    }
    let hold = flags & 128 != 0;
    if !hold && flags & 1 == 0 {
        return Err(CoreError::new(
            ErrorCode::UnsupportedFormat,
            "unsupported mania hit object type",
        ));
    }
    let mut sample = fields.get(5).copied().unwrap_or("");
    let end_ms = if hold {
        let (end, rest) = sample.split_once(':').unwrap_or((sample, ""));
        let end = time(end)?;
        if end <= time_ms {
            return Err(corrupt("osu hold end must follow its start"));
        }
        sample = rest;
        Some(end)
    } else {
        None
    };
    let parts: Vec<_> = sample.splitn(5, ':').collect();
    let volume = match parts.get(3).map(|value| value.trim()) {
        None | Some("") => 100,
        Some(value) => integer(value)?,
    }
    .clamp(0, 100) as f32
        / 100.0;
    let filename = match parts.get(4).map(|value| value.trim()) {
        None | Some("") => None,
        Some(value) => Some(relative(value)?),
    };
    let lane = (i64::from(x) * 7).div_euclid(512).clamp(0, 6) as u8 + 1;
    Ok((
        OsuNote {
            lane,
            time_ms,
            end_ms,
            sample_index: 0,
            volume,
        },
        filename,
    ))
}

fn decimal(value: &str) -> Result<f64, CoreError> {
    value
        .trim()
        .parse::<f64>()
        .ok()
        .filter(|number| number.is_finite())
        .ok_or_else(|| corrupt("invalid finite osu number"))
}
fn integer(value: &str) -> Result<i32, CoreError> {
    value
        .trim()
        .parse()
        .map_err(|_| corrupt("invalid osu integer"))
}
fn time(value: &str) -> Result<i32, CoreError> {
    let rounded = (decimal(value)? + 0.5).floor();
    if !(f64::from(i32::MIN)..=f64::from(i32::MAX)).contains(&rounded) {
        return Err(corrupt("osu time exceeds supported range"));
    }
    Ok(rounded as i32)
}
fn relative(value: &str) -> Result<SourceRelativePath, CoreError> {
    SourceRelativePath::parse(value).map_err(|_| corrupt("unsafe osu audio reference"))
}
fn corrupt(message: &str) -> CoreError {
    CoreError::new(ErrorCode::CorruptChart, message)
}
