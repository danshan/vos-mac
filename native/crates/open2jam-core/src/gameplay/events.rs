use super::{Ratio, SoundSettings, TimeMicros, corrupt};
use crate::{error::CoreError, id::SampleId};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", try_from = "TimingWire")]
pub struct TimingPoint {
    at_us: TimeMicros,
    bpm: Ratio,
    event_order: u32,
}
#[derive(Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct TimingWire {
    at_us: TimeMicros,
    bpm: Ratio,
    event_order: u32,
}
impl TimingPoint {
    pub fn new(at_us: TimeMicros, bpm: Ratio, event_order: u32) -> Result<Self, CoreError> {
        if bpm.numerator() < 0 {
            return Err(corrupt("negative timing velocity"));
        }
        Ok(Self {
            at_us,
            bpm,
            event_order,
        })
    }
    pub fn at(&self) -> TimeMicros {
        self.at_us
    }
    pub fn bpm(&self) -> Ratio {
        self.bpm
    }
    pub fn event_order(&self) -> u32 {
        self.event_order
    }
}
impl TryFrom<TimingWire> for TimingPoint {
    type Error = CoreError;
    fn try_from(w: TimingWire) -> Result<Self, Self::Error> {
        Self::new(w.at_us, w.bpm, w.event_order)
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", try_from = "ScrollWire")]
pub struct ScrollPoint {
    at_us: TimeMicros,
    multiplier: Ratio,
    event_order: u32,
}
#[derive(Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct ScrollWire {
    at_us: TimeMicros,
    multiplier: Ratio,
    event_order: u32,
}
impl ScrollPoint {
    pub fn new(at_us: TimeMicros, multiplier: Ratio, event_order: u32) -> Result<Self, CoreError> {
        if multiplier.numerator() < 0 {
            return Err(corrupt("negative scroll multiplier"));
        }
        Ok(Self {
            at_us,
            multiplier,
            event_order,
        })
    }
    pub fn at(&self) -> TimeMicros {
        self.at_us
    }
    pub fn multiplier(&self) -> Ratio {
        self.multiplier
    }
    pub fn event_order(&self) -> u32 {
        self.event_order
    }
}
impl TryFrom<ScrollWire> for ScrollPoint {
    type Error = CoreError;
    fn try_from(w: ScrollWire) -> Result<Self, Self::Error> {
        Self::new(w.at_us, w.multiplier, w.event_order)
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", try_from = "AutoplayWire")]
pub struct AutoplayEvent {
    at_us: TimeMicros,
    event_order: u32,
    sample_id: SampleId,
    volume: Ratio,
    pan: Ratio,
}
#[derive(Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct AutoplayWire {
    at_us: TimeMicros,
    event_order: u32,
    sample_id: SampleId,
    volume: Ratio,
    pan: Ratio,
}
impl AutoplayEvent {
    pub fn new(
        at_us: TimeMicros,
        event_order: u32,
        sample_id: SampleId,
        sound: SoundSettings,
    ) -> Self {
        Self {
            at_us,
            event_order,
            sample_id,
            volume: sound.volume(),
            pan: sound.pan(),
        }
    }
    pub fn at(&self) -> TimeMicros {
        self.at_us
    }
    pub fn event_order(&self) -> u32 {
        self.event_order
    }
    pub fn sample_id(&self) -> SampleId {
        self.sample_id
    }
    pub fn volume(&self) -> Ratio {
        self.volume
    }
    pub fn pan(&self) -> Ratio {
        self.pan
    }
}
impl TryFrom<AutoplayWire> for AutoplayEvent {
    type Error = CoreError;
    fn try_from(w: AutoplayWire) -> Result<Self, Self::Error> {
        Ok(Self::new(
            w.at_us,
            w.event_order,
            w.sample_id,
            SoundSettings::new(w.volume, w.pan)?,
        ))
    }
}
