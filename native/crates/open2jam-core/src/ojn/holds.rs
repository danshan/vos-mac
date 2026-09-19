use super::{EventKind, NoteKind, OjnTimeline, TimedOjnEvent};
use crate::{
    error::CoreError,
    legacy_notes::{LegacyNote, repair_long_notes},
};

impl OjnTimeline {
    pub fn repair_long_notes(
        mut self,
        checkpoint: &mut impl FnMut() -> Result<(), CoreError>,
    ) -> Result<Self, CoreError> {
        repair_long_notes(&mut self.events, checkpoint)?;
        Ok(self)
    }
}

impl LegacyNote for TimedOjnEvent {
    fn sample(&self) -> Option<(Option<u8>, u32, NoteKind)> {
        match self.event.kind {
            EventKind::Sample {
                lane,
                sample_index,
                kind,
                ..
            } => Some((lane, sample_index, kind)),
            _ => None,
        }
    }
    fn set_lane(&mut self, value: Option<u8>) {
        if let EventKind::Sample { lane, .. } = &mut self.event.kind {
            *lane = value;
        }
    }
    fn set_kind(&mut self, value: NoteKind) {
        if let EventKind::Sample { kind, .. } = &mut self.event.kind {
            *kind = value;
        }
    }
}
