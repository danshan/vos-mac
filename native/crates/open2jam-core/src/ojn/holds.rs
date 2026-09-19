use super::{EventKind, NoteKind, OjnTimeline, corrupt};
use crate::error::CoreError;

impl OjnTimeline {
    pub fn repair_long_notes(
        mut self,
        checkpoint: &mut impl FnMut() -> Result<(), CoreError>,
    ) -> Result<Self, CoreError> {
        let mut pending = [None; 7];
        let mut removed = vec![false; self.events.len()];
        let mut search_budget = 32_000_000_usize;
        for index in 0..self.events.len() {
            checkpoint()?;
            let EventKind::Sample { lane, kind, .. } = self.events[index].event.kind else {
                continue;
            };
            if let Some(lane) = lane {
                if lane >= 7 {
                    return Err(corrupt("OJN note lane exceeds seven keys"));
                }
                match kind {
                    NoteKind::Hold => {
                        if let Some(previous) = pending[lane as usize] {
                            set_kind(&mut self, previous, NoteKind::Tap);
                        }
                        pending[lane as usize] = Some(index);
                    }
                    NoteKind::Release => {
                        if pending[lane as usize].take().is_none() {
                            repair_release(
                                &mut self,
                                index,
                                lane,
                                &mut removed,
                                &mut search_budget,
                                checkpoint,
                            )?;
                        }
                    }
                    NoteKind::Tap => {
                        if let Some(head) = pending[lane as usize].take() {
                            repair_hold(
                                &mut self,
                                index,
                                head,
                                lane,
                                &removed,
                                &mut search_budget,
                                checkpoint,
                            )?;
                        }
                    }
                }
            }
            // Forward repairs can move the current event into autoplay as well.
            if let EventKind::Sample {
                lane: None, kind, ..
            } = self.events[index].event.kind
            {
                if kind == NoteKind::Release {
                    removed[index] = true;
                } else {
                    set_kind(&mut self, index, NoteKind::Tap);
                }
            }
        }
        let mut index = 0;
        self.events.retain(|_| {
            let keep = !removed[index];
            index += 1;
            keep
        });
        Ok(self)
    }
}

fn repair_hold(
    timeline: &mut OjnTimeline,
    current: usize,
    head: usize,
    lane: u8,
    removed: &[bool],
    budget: &mut usize,
    checkpoint: &mut impl FnMut() -> Result<(), CoreError>,
) -> Result<(), CoreError> {
    let (_, head_sample, _) = sample(timeline, head).unwrap();
    let mut autoplay = vec![current];
    let mut last = current;
    let mut found = false;
    for (index, is_removed) in removed.iter().enumerate().skip(current + 1) {
        search_step(budget, checkpoint)?;
        if *is_removed {
            continue;
        }
        let Some((Some(event_lane), event_sample, kind)) = sample(timeline, index) else {
            continue;
        };
        if event_lane != lane {
            continue;
        }
        if kind == NoteKind::Hold {
            if sample(timeline, last).unwrap().2 == NoteKind::Tap {
                set_kind(timeline, last, NoteKind::Release);
                autoplay.retain(|index| *index != last);
                found = true;
            }
            break;
        }
        if event_sample == head_sample {
            set_kind(timeline, index, NoteKind::Release);
            found = true;
            break;
        }
        autoplay.push(index);
        last = index;
    }
    if found {
        for index in autoplay {
            set_autoplay(timeline, index);
        }
    } else {
        set_kind(timeline, current, NoteKind::Release);
    }
    Ok(())
}

fn repair_release(
    timeline: &mut OjnTimeline,
    current: usize,
    lane: u8,
    removed: &mut [bool],
    budget: &mut usize,
    checkpoint: &mut impl FnMut() -> Result<(), CoreError>,
) -> Result<(), CoreError> {
    let (_, source_sample, _) = sample(timeline, current).unwrap();
    let mut autoplay = Vec::new();
    let mut found = false;
    for index in (0..current).rev() {
        search_step(budget, checkpoint)?;
        if removed[index] {
            continue;
        }
        let Some((Some(event_lane), event_sample, kind)) = sample(timeline, index) else {
            continue;
        };
        if event_lane != lane {
            continue;
        }
        if event_sample == source_sample {
            if kind != NoteKind::Release {
                set_kind(timeline, index, NoteKind::Hold);
                found = true;
            }
            break;
        }
        if kind == NoteKind::Hold {
            found = true;
            break;
        }
        autoplay.push(index);
    }
    if found {
        for index in autoplay {
            set_autoplay(timeline, index);
        }
    } else {
        removed[current] = true;
    }
    Ok(())
}

fn search_step(
    budget: &mut usize,
    checkpoint: &mut impl FnMut() -> Result<(), CoreError>,
) -> Result<(), CoreError> {
    if *budget == 0 {
        return Err(corrupt("OJN long-note repair exceeds search work bound"));
    }
    *budget -= 1;
    if budget.is_multiple_of(1024) {
        checkpoint()?;
    }
    Ok(())
}

fn sample(timeline: &OjnTimeline, index: usize) -> Option<(Option<u8>, u32, NoteKind)> {
    match timeline.events[index].event.kind {
        EventKind::Sample {
            lane,
            sample_index,
            kind,
            ..
        } => Some((lane, sample_index, kind)),
        _ => None,
    }
}

fn set_autoplay(timeline: &mut OjnTimeline, index: usize) {
    if let EventKind::Sample { lane, .. } = &mut timeline.events[index].event.kind {
        *lane = None;
    }
}

fn set_kind(timeline: &mut OjnTimeline, index: usize, new_kind: NoteKind) {
    if let EventKind::Sample { kind, .. } = &mut timeline.events[index].event.kind {
        *kind = new_kind;
    }
}
