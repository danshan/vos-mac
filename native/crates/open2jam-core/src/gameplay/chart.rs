use super::{AutoplayEvent, Note, ScrollPoint, TimeMicros, TimingPoint, corrupt};
use crate::{
    error::{CoreError, ErrorCode, ProtocolError},
    format::Format,
    id::{ChartId, SampleId, SongId},
    json::Contract,
    schema::GAMEPLAY_SCHEMA_VERSION,
};
use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;

/// Unvalidated construction input. Only `GameplayChartV2::new` grants a validated chart.
#[derive(Debug, Clone)]
pub struct GameplayChartInput {
    pub song_id: SongId,
    pub chart_id: ChartId,
    pub format: Format,
    pub keys: u8,
    pub title: String,
    pub artist: String,
    pub duration_us: TimeMicros,
    pub samples: Vec<SampleId>,
    pub notes: Vec<Note>,
    pub measures: Vec<TimeMicros>,
    pub judgment_timing: Vec<TimingPoint>,
    pub visual_timing: Vec<TimingPoint>,
    pub scroll: Vec<ScrollPoint>,
    pub auto_play_events: Vec<AutoplayEvent>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", try_from = "ChartWire")]
pub struct GameplayChartV2 {
    schema_version: u16,
    song_id: SongId,
    chart_id: ChartId,
    format: Format,
    keys: u8,
    title: String,
    artist: String,
    duration_us: TimeMicros,
    samples: Vec<SampleId>,
    notes: Vec<Note>,
    measures: Vec<TimeMicros>,
    judgment_timing: Vec<TimingPoint>,
    visual_timing: Vec<TimingPoint>,
    scroll: Vec<ScrollPoint>,
    auto_play_events: Vec<AutoplayEvent>,
}
#[derive(Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct ChartWire {
    schema_version: u16,
    song_id: SongId,
    chart_id: ChartId,
    format: Format,
    keys: u8,
    title: String,
    artist: String,
    duration_us: TimeMicros,
    samples: Vec<SampleId>,
    notes: Vec<Note>,
    measures: Vec<TimeMicros>,
    judgment_timing: Vec<TimingPoint>,
    visual_timing: Vec<TimingPoint>,
    scroll: Vec<ScrollPoint>,
    auto_play_events: Vec<AutoplayEvent>,
}
impl GameplayChartV2 {
    pub fn new(input: GameplayChartInput) -> Result<Self, CoreError> {
        let chart = Self {
            schema_version: GAMEPLAY_SCHEMA_VERSION,
            song_id: input.song_id,
            chart_id: input.chart_id,
            format: input.format,
            keys: input.keys,
            title: input.title,
            artist: input.artist,
            duration_us: input.duration_us,
            samples: input.samples,
            notes: input.notes,
            measures: input.measures,
            judgment_timing: input.judgment_timing,
            visual_timing: input.visual_timing,
            scroll: input.scroll,
            auto_play_events: input.auto_play_events,
        };
        chart.validate()?;
        Ok(chart)
    }
    pub fn validate(&self) -> Result<(), CoreError> {
        if self.schema_version != GAMEPLAY_SCHEMA_VERSION {
            return Err(CoreError::new(
                ErrorCode::UnsupportedSchema,
                "unsupported gameplay schema",
            ));
        }
        if self.keys != 7
            || self.format == Format::Bundle
            || self.title.contains('\0')
            || self.artist.contains('\0')
        {
            return Err(corrupt("invalid gameplay metadata"));
        }
        if !strict_order(&self.samples, |id| *id) {
            return Err(corrupt("sample IDs must be sorted and unique"));
        }
        if self.measures.is_empty() || !self.measures.windows(2).all(|pair| pair[0] <= pair[1]) {
            return Err(corrupt("measure times must be nonempty and ordered"));
        }
        for timing in [&self.judgment_timing, &self.visual_timing] {
            if timing.is_empty() || !strict_order(timing, |point| (point.at(), point.event_order()))
            {
                return Err(corrupt("timing must be nonempty and ordered"));
            }
        }
        if !strict_order(&self.notes, |note| (note.start(), note.event_order()))
            || !strict_order(&self.scroll, |point| (point.at(), point.event_order()))
            || !strict_order(&self.auto_play_events, |event| {
                (event.at(), event.event_order())
            })
        {
            return Err(corrupt("gameplay events must retain canonical time/order"));
        }
        let has_sample = |id| self.samples.binary_search(&id).is_ok();
        let mut playable_orders = BTreeSet::new();
        for note in &self.notes {
            if !playable_orders.insert((note.start(), note.event_order()))
                || note
                    .tail()
                    .is_some_and(|tail| !playable_orders.insert((tail.at(), tail.event_order())))
            {
                return Err(corrupt("duplicate playable event time/order"));
            }
            if note.sample_id().is_some_and(|id| !has_sample(id)) {
                return Err(corrupt("note sample reference is missing"));
            }
            if note.measure() as usize >= self.measures.len()
                || note
                    .tail()
                    .is_some_and(|tail| tail.measure() as usize >= self.measures.len())
            {
                return Err(corrupt("note measure reference is missing"));
            }
        }
        if self
            .auto_play_events
            .iter()
            .any(|event| !has_sample(event.sample_id()))
        {
            return Err(corrupt("autoplay sample reference is missing"));
        }
        if self.notes.iter().any(|note| {
            note.start() > self.duration_us
                || note.tail().is_some_and(|tail| tail.at() > self.duration_us)
        }) || self
            .auto_play_events
            .iter()
            .any(|event| event.at() > self.duration_us)
            || self.measures.iter().any(|time| *time > self.duration_us)
            || self
                .judgment_timing
                .iter()
                .chain(&self.visual_timing)
                .any(|point| point.at() > self.duration_us)
            || self
                .scroll
                .iter()
                .any(|point| point.at() > self.duration_us)
        {
            return Err(corrupt("chart duration does not cover its events"));
        }
        Ok(())
    }
    pub fn song_id(&self) -> SongId {
        self.song_id
    }
    pub fn chart_id(&self) -> ChartId {
        self.chart_id
    }
    pub fn title(&self) -> &str {
        &self.title
    }
    pub fn artist(&self) -> &str {
        &self.artist
    }
    pub fn format(&self) -> Format {
        self.format
    }
    pub fn notes(&self) -> &[Note] {
        &self.notes
    }
    pub fn samples(&self) -> &[SampleId] {
        &self.samples
    }
}
fn strict_order<T, K: Ord>(items: &[T], key: impl Fn(&T) -> K) -> bool {
    items.windows(2).all(|pair| key(&pair[0]) < key(&pair[1]))
}
impl TryFrom<ChartWire> for GameplayChartV2 {
    type Error = CoreError;
    fn try_from(w: ChartWire) -> Result<Self, Self::Error> {
        if w.schema_version != GAMEPLAY_SCHEMA_VERSION {
            return Err(CoreError::new(
                ErrorCode::UnsupportedSchema,
                "unsupported gameplay schema",
            ));
        }
        Self::new(GameplayChartInput {
            song_id: w.song_id,
            chart_id: w.chart_id,
            format: w.format,
            keys: w.keys,
            title: w.title,
            artist: w.artist,
            duration_us: w.duration_us,
            samples: w.samples,
            notes: w.notes,
            measures: w.measures,
            judgment_timing: w.judgment_timing,
            visual_timing: w.visual_timing,
            scroll: w.scroll,
            auto_play_events: w.auto_play_events,
        })
    }
}
impl Contract for GameplayChartV2 {
    const SCHEMA_VERSION: u16 = GAMEPLAY_SCHEMA_VERSION;
    fn validate(&self) -> Result<(), ProtocolError> {
        self.validate().map_err(Into::into)
    }
}
