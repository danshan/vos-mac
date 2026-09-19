use std::collections::{BTreeMap, BTreeSet};

use super::{EventKind, NoteKind, OjnSource, corrupt};
use crate::{
    error::{CoreError, ErrorCode},
    format::Format,
    gameplay::{
        AutoplayEvent, GameplayChartInput, GameplayChartV2, HoldTail, Note, SoundSettings,
        TimeMicros,
    },
    id::{ChartIdentity, SampleId, SongId},
};

pub struct OjnMetadata {
    pub song_id: SongId,
    pub title: String,
    pub artist: String,
}

impl OjnSource<'_> {
    pub fn gameplay(
        &self,
        chart_index: u8,
        metadata: OjnMetadata,
        samples: &BTreeMap<u32, SampleId>,
        checkpoint: &mut impl FnMut() -> Result<(), CoreError>,
    ) -> Result<GameplayChartV2, CoreError> {
        let chart_id = ChartIdentity::ojn(chart_index)?.chart_id(&metadata.song_id);
        let timeline = self
            .timeline(usize::from(chart_index), checkpoint)?
            .repair_long_notes(checkpoint)?;
        let mut notes: Vec<Note> = Vec::new();
        let mut pending: [Option<usize>; 7] = [None; 7];
        let mut auto_play_events = Vec::new();
        let mut playable_order = 0;
        let mut duration = u64::from(self.duration_seconds(usize::from(chart_index))?) * 1_000_000;
        for time in &timeline.measures {
            duration = duration.max(time.get());
        }
        for event in timeline.events {
            checkpoint()?;
            duration = duration.max(event.at.get());
            let EventKind::Sample {
                lane,
                sample_index,
                kind,
                volume,
                pan,
            } = event.event.kind
            else {
                continue;
            };
            let sound = SoundSettings::new(volume, pan)?;
            if let Some(lane) = lane {
                let order = playable_order;
                playable_order += 1;
                if kind == NoteKind::Release {
                    if let Some(head) = pending[lane as usize].take() {
                        let note = &notes[head];
                        notes[head] = Note::new(
                            note.lane(),
                            note.start(),
                            note.measure(),
                            note.event_order(),
                            note.sample_id(),
                            SoundSettings::new(note.volume(), note.pan())?,
                            Some(HoldTail::new(event.at, event.event.measure, order)),
                        )?;
                    }
                } else {
                    let sample_id = required_sample(samples, sample_index)?;
                    if kind == NoteKind::Hold {
                        pending[lane as usize] = Some(notes.len());
                    }
                    notes.push(Note::new(
                        lane,
                        event.at,
                        event.event.measure,
                        order,
                        Some(sample_id),
                        sound,
                        None,
                    )?);
                }
            } else {
                auto_play_events.push(AutoplayEvent::new(
                    event.at,
                    auto_play_events.len() as u32,
                    required_sample(samples, sample_index)?,
                    sound,
                ));
            }
        }
        if pending.iter().any(Option::is_some) {
            return Err(corrupt("OJN hold has no release after legacy repair"));
        }
        let samples: BTreeSet<_> = samples.values().copied().collect();
        GameplayChartV2::new(GameplayChartInput {
            song_id: metadata.song_id,
            chart_id,
            format: Format::O2Jam,
            keys: 7,
            title: metadata.title,
            artist: metadata.artist,
            duration_us: TimeMicros::new(duration)?,
            samples: samples.into_iter().collect(),
            notes,
            measures: timeline.measures,
            judgment_timing: timeline.timing.clone(),
            visual_timing: timeline.timing,
            scroll: Vec::new(),
            auto_play_events,
        })
    }
}

fn required_sample(samples: &BTreeMap<u32, SampleId>, index: u32) -> Result<SampleId, CoreError> {
    samples.get(&index).copied().ok_or_else(|| {
        CoreError::new(
            ErrorCode::MissingAsset,
            "OJN references an unavailable audio sample",
        )
        .with_context("sampleIndex", index.to_string())
    })
}
