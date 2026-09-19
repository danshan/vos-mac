use std::collections::{BTreeMap, BTreeSet};

use super::{OsuNoteKind, OsuSource, OsuTimeline, OsuVelocityChange, corrupt};
use crate::{
    error::{CoreError, ErrorCode},
    format::Format,
    gameplay::{
        AutoplayEvent, GameplayChartInput, GameplayChartV2, HoldTail, Note, Ratio, ScrollPoint,
        SoundSettings, TimeMicros, TimingPoint,
    },
    id::{ChartId, ChartIdentity, SampleId, SongId},
    path::SourceRelativePath,
};

pub struct OsuMetadata {
    pub song_id: SongId,
    // Relative to the beatmap set, not the library root or current working directory.
    pub chart_path: SourceRelativePath,
    pub title: String,
    pub artist: String,
}

pub struct CompiledOsuChart {
    chart_id: ChartId,
    metadata: OsuMetadata,
    duration_us: u64,
    timeline: OsuTimeline,
}

impl OsuSource {
    pub fn compile(
        &self,
        metadata: OsuMetadata,
        checkpoint: &mut impl FnMut() -> Result<(), CoreError>,
    ) -> Result<CompiledOsuChart, CoreError> {
        let chart_id = ChartIdentity::osu(metadata.chart_path.clone()).chart_id(&metadata.song_id);
        let timeline = self.timeline(checkpoint)?.repair_long_notes(checkpoint)?;
        let duration_ms = self
            .notes
            .iter()
            .map(|note| note.end_ms.unwrap_or(note.time_ms) as u64)
            .max()
            .unwrap_or(0);
        Ok(CompiledOsuChart {
            chart_id,
            metadata,
            duration_us: duration_ms.div_ceil(1000) * 1_000_000,
            timeline,
        })
    }
}

impl CompiledOsuChart {
    pub fn with_samples(
        self,
        samples: &BTreeMap<u32, SampleId>,
        checkpoint: &mut impl FnMut() -> Result<(), CoreError>,
    ) -> Result<GameplayChartV2, CoreError> {
        let Self {
            chart_id,
            metadata,
            mut duration_us,
            timeline,
        } = self;
        let mut notes: Vec<Note> = Vec::new();
        let mut pending: [Option<usize>; 7] = [None; 7];
        let mut auto_play_events = Vec::new();
        let mut playable_order = 0;
        for event in timeline.samples {
            checkpoint()?;
            duration_us = duration_us.max(event.at.get());
            let sound = SoundSettings::new(volume_ratio(event.volume)?, Ratio::new(0, 1)?)?;
            if let Some(lane) = event.lane {
                let order = playable_order;
                playable_order += 1;
                if event.kind == OsuNoteKind::Release {
                    if let Some(head) = pending[lane as usize].take() {
                        let note = &notes[head];
                        notes[head] = Note::new(
                            note.lane(),
                            note.start(),
                            note.measure(),
                            note.event_order(),
                            note.sample_id(),
                            SoundSettings::new(note.volume(), note.pan())?,
                            Some(HoldTail::new(event.at, event.measure, order)),
                        )?;
                    }
                } else {
                    if event.kind == OsuNoteKind::Hold {
                        pending[lane as usize] = Some(notes.len());
                    }
                    notes.push(Note::new(
                        lane,
                        event.at,
                        event.measure,
                        order,
                        if event.sample_index == 0 {
                            None
                        } else {
                            Some(required_sample(samples, event.sample_index)?)
                        },
                        sound,
                        None,
                    )?);
                }
            } else if event.sample_index != 0 {
                // Legacy repair may move a sampleless osu note to autoplay. It has no audio event.
                auto_play_events.push(AutoplayEvent::new(
                    event.at,
                    auto_play_events.len() as u32,
                    required_sample(samples, event.sample_index)?,
                    sound,
                ));
            }
        }
        if pending.iter().any(Option::is_some) {
            return Err(corrupt("osu hold has no release after legacy repair"));
        }
        let judgment_timing = timing(timeline.judgment_timing, checkpoint)?;
        let visual_timing = timing(timeline.visual_timing, checkpoint)?;
        let mut scroll = Vec::new();
        for point in timeline.scroll {
            checkpoint()?;
            scroll.push(ScrollPoint::new(
                point.at,
                velocity_ratio(point.multiplier)?,
                scroll.len() as u32,
            )?);
        }
        for at in timeline
            .measures
            .iter()
            .copied()
            .chain(judgment_timing.iter().map(TimingPoint::at))
            .chain(visual_timing.iter().map(TimingPoint::at))
            .chain(scroll.iter().map(ScrollPoint::at))
        {
            checkpoint()?;
            duration_us = duration_us.max(at.get());
        }
        let samples: BTreeSet<_> = samples.values().copied().collect();
        GameplayChartV2::new(GameplayChartInput {
            song_id: metadata.song_id,
            chart_id,
            format: Format::OsuMania,
            keys: 7,
            title: metadata.title,
            artist: metadata.artist,
            duration_us: TimeMicros::new(duration_us)?,
            samples: samples.into_iter().collect(),
            notes,
            measures: timeline.measures,
            judgment_timing,
            visual_timing,
            scroll,
            auto_play_events,
        })
    }
}

fn required_sample(samples: &BTreeMap<u32, SampleId>, index: u32) -> Result<SampleId, CoreError> {
    samples.get(&index).copied().ok_or_else(|| {
        CoreError::new(
            ErrorCode::MissingAsset,
            "osu references an unavailable audio sample",
        )
        .with_context("sampleIndex", index.to_string())
    })
}

fn timing(
    points: Vec<OsuVelocityChange>,
    checkpoint: &mut impl FnMut() -> Result<(), CoreError>,
) -> Result<Vec<TimingPoint>, CoreError> {
    let mut output = Vec::with_capacity(points.len());
    for point in points {
        checkpoint()?;
        output.push(TimingPoint::new(
            point.at,
            velocity_ratio(point.bpm)?,
            output.len() as u32,
        )?);
    }
    Ok(output)
}

fn volume_ratio(value: f32) -> Result<Ratio, CoreError> {
    // All integer percentages divided by binary32 100 fit this power-of-two denominator.
    let scaled = f64::from(value) * f64::from(1_u32 << 30);
    if !(0.0..=1.0).contains(&value) || scaled.fract() != 0.0 {
        return Err(corrupt("osu volume exceeds exact rational range"));
    }
    Ratio::new(scaled as i64, 1_u32 << 30)
}

fn velocity_ratio(value: f64) -> Result<Ratio, CoreError> {
    // Continued fractions keep normal tempos precise without changing the v2 wire limits.
    const MAX_NUMERATOR: u64 = (1 << 53) - 1;
    if !value.is_finite() || value <= 0.0 || value > MAX_NUMERATOR as f64 {
        return Err(corrupt("osu velocity exceeds rational range"));
    }
    let close = |n: u64, d: u64| {
        d != 0 && ((n as f64 / d as f64) - value).abs() <= value * (4.0 * f64::EPSILON)
    };
    let (mut p0, mut p1, mut q0, mut q1) = (0, 1, 1, 0);
    let mut remainder = value;
    for _ in 0..128 {
        let limit = (MAX_NUMERATOR - p0)
            .checked_div(p1)
            .unwrap_or(u64::MAX)
            .min(
                (u64::from(u32::MAX) - q0)
                    .checked_div(q1)
                    .unwrap_or(u64::MAX),
            );
        let coefficient = remainder.floor();
        let bounded = coefficient > limit as f64;
        let coefficient = if bounded { limit } else { coefficient as u64 };
        let (p, q) = (coefficient * p1 + p0, coefficient * q1 + q0);
        if close(p, q) {
            return Ratio::new(p as i64, q as u32);
        }
        if bounded {
            break;
        }
        (p0, p1, q0, q1) = (p1, p, q1, q);
        remainder = 1.0 / (remainder - coefficient as f64);
    }
    Err(corrupt("osu velocity cannot fit rational precision budget"))
}
