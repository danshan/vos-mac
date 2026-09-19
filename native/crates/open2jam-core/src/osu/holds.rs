use super::{OsuNoteKind, OsuTimeline, TimedOsuSample};
use crate::{
    error::CoreError,
    legacy_notes::{LegacyNote, repair_long_notes},
};

impl OsuTimeline {
    pub fn repair_long_notes(
        mut self,
        checkpoint: &mut impl FnMut() -> Result<(), CoreError>,
    ) -> Result<Self, CoreError> {
        repair_long_notes(&mut self.samples, checkpoint)?;
        Ok(self)
    }
}

impl LegacyNote for TimedOsuSample {
    fn sample(&self) -> Option<(Option<u8>, u32, OsuNoteKind)> {
        Some((self.lane, self.sample_index, self.kind))
    }
    fn set_lane(&mut self, lane: Option<u8>) {
        self.lane = lane;
    }
    fn set_kind(&mut self, kind: OsuNoteKind) {
        self.kind = kind;
    }
}
