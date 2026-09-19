use super::{Ratio, TimeMicros, corrupt};
use crate::{error::CoreError, id::SampleId};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct SoundSettings {
    volume: Ratio,
    pan: Ratio,
}
impl SoundSettings {
    pub fn new(volume: Ratio, pan: Ratio) -> Result<Self, CoreError> {
        if !volume.is_between(0, 1) || !pan.is_between(-1, 1) {
            return Err(corrupt("invalid note volume or pan"));
        }
        Ok(Self { volume, pan })
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct HoldTail {
    at_us: TimeMicros,
    measure: u32,
    event_order: u32,
}
impl HoldTail {
    pub fn new(at_us: TimeMicros, measure: u32, event_order: u32) -> Self {
        Self {
            at_us,
            measure,
            event_order,
        }
    }
    pub fn at(self) -> TimeMicros {
        self.at_us
    }
    pub fn measure(self) -> u32 {
        self.measure
    }
    pub fn event_order(self) -> u32 {
        self.event_order
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", try_from = "NoteWire")]
pub struct Note {
    lane: u8,
    start_us: TimeMicros,
    measure: u32,
    event_order: u32,
    sample_id: Option<SampleId>,
    volume: Ratio,
    pan: Ratio,
    tail: Option<HoldTail>,
}
#[derive(Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct NoteWire {
    lane: u8,
    start_us: TimeMicros,
    measure: u32,
    event_order: u32,
    sample_id: Option<SampleId>,
    volume: Ratio,
    pan: Ratio,
    tail: Option<HoldTail>,
}
impl Note {
    pub fn new(
        lane: u8,
        start: TimeMicros,
        measure: u32,
        event_order: u32,
        sample_id: Option<SampleId>,
        sound: SoundSettings,
        tail: Option<HoldTail>,
    ) -> Result<Self, CoreError> {
        if lane >= 7 {
            return Err(corrupt("note lane exceeds seven keys"));
        }
        if tail.is_some_and(|tail| {
            tail.at_us < start
                || tail.measure < measure
                || (tail.at_us == start && tail.event_order <= event_order)
        }) {
            return Err(corrupt("hold tail precedes its head"));
        }
        Ok(Self {
            lane,
            start_us: start,
            measure,
            event_order,
            sample_id,
            volume: sound.volume,
            pan: sound.pan,
            tail,
        })
    }
    pub fn start(&self) -> TimeMicros {
        self.start_us
    }
    pub fn lane(&self) -> u8 {
        self.lane
    }
    pub fn measure(&self) -> u32 {
        self.measure
    }
    pub fn event_order(&self) -> u32 {
        self.event_order
    }
    pub fn sample_id(&self) -> Option<SampleId> {
        self.sample_id
    }
    pub fn volume(&self) -> Ratio {
        self.volume
    }
    pub fn pan(&self) -> Ratio {
        self.pan
    }
    pub fn tail(&self) -> Option<HoldTail> {
        self.tail
    }
}
impl TryFrom<NoteWire> for Note {
    type Error = CoreError;
    fn try_from(value: NoteWire) -> Result<Self, Self::Error> {
        Self::new(
            value.lane,
            value.start_us,
            value.measure,
            value.event_order,
            value.sample_id,
            SoundSettings::new(value.volume, value.pan)?,
            value.tail,
        )
    }
}
