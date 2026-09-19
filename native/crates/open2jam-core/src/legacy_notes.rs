use crate::error::{CoreError, ErrorCode};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum NoteKind {
    Tap,
    Hold,
    Release,
}

// Both importers retain their own timing/sample payload; repair only changes lanes and flags.
pub(crate) trait LegacyNote {
    fn sample(&self) -> Option<(Option<u8>, u32, NoteKind)>;
    fn set_lane(&mut self, lane: Option<u8>);
    fn set_kind(&mut self, kind: NoteKind);
}

pub(crate) fn repair_long_notes<T: LegacyNote>(
    events: &mut Vec<T>,
    checkpoint: &mut impl FnMut() -> Result<(), CoreError>,
) -> Result<(), CoreError> {
    let mut pending: [Option<usize>; 7] = [None; 7];
    let mut removed = vec![false; events.len()];
    let mut search_budget = 32_000_000_usize;
    for index in 0..events.len() {
        checkpoint()?;
        let Some((lane, _, kind)) = events[index].sample() else {
            continue;
        };
        if let Some(lane) = lane {
            if lane >= 7 {
                return Err(corrupt("legacy note lane exceeds seven keys"));
            }
            match kind {
                NoteKind::Hold => {
                    if let Some(previous) = pending[lane as usize] {
                        events[previous].set_kind(NoteKind::Tap);
                    }
                    pending[lane as usize] = Some(index);
                }
                NoteKind::Release => {
                    if pending[lane as usize].take().is_none() {
                        repair_release(
                            events,
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
                            events,
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
        if let Some((None, _, kind)) = events[index].sample() {
            if kind == NoteKind::Release {
                removed[index] = true;
            } else {
                events[index].set_kind(NoteKind::Tap);
            }
        }
    }
    let mut index = 0;
    events.retain(|_| {
        let keep = !removed[index];
        index += 1;
        keep
    });
    Ok(())
}

fn repair_hold<T: LegacyNote>(
    events: &mut [T],
    current: usize,
    head: usize,
    lane: u8,
    removed: &[bool],
    budget: &mut usize,
    checkpoint: &mut impl FnMut() -> Result<(), CoreError>,
) -> Result<(), CoreError> {
    let (_, head_sample, _) = events[head].sample().unwrap();
    let mut autoplay = vec![current];
    let mut last = current;
    let mut found = false;
    for (index, is_removed) in removed.iter().enumerate().skip(current + 1) {
        search_step(budget, checkpoint)?;
        if *is_removed {
            continue;
        }
        let Some((Some(event_lane), event_sample, kind)) = events[index].sample() else {
            continue;
        };
        if event_lane != lane {
            continue;
        }
        if kind == NoteKind::Hold {
            if events[last].sample().unwrap().2 == NoteKind::Tap {
                events[last].set_kind(NoteKind::Release);
                autoplay.retain(|index| *index != last);
                found = true;
            }
            break;
        }
        if event_sample == head_sample {
            events[index].set_kind(NoteKind::Release);
            found = true;
            break;
        }
        autoplay.push(index);
        last = index;
    }
    if found {
        for index in autoplay {
            events[index].set_lane(None);
        }
    } else {
        events[current].set_kind(NoteKind::Release);
    }
    Ok(())
}

fn repair_release<T: LegacyNote>(
    events: &mut [T],
    current: usize,
    lane: u8,
    removed: &mut [bool],
    budget: &mut usize,
    checkpoint: &mut impl FnMut() -> Result<(), CoreError>,
) -> Result<(), CoreError> {
    let (_, source_sample, _) = events[current].sample().unwrap();
    let mut autoplay = Vec::new();
    let mut found = false;
    for index in (0..current).rev() {
        search_step(budget, checkpoint)?;
        if removed[index] {
            continue;
        }
        let Some((Some(event_lane), event_sample, kind)) = events[index].sample() else {
            continue;
        };
        if event_lane != lane {
            continue;
        }
        if event_sample == source_sample {
            if kind != NoteKind::Release {
                events[index].set_kind(NoteKind::Hold);
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
            events[index].set_lane(None);
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
        return Err(corrupt("legacy long-note repair exceeds search work bound"));
    }
    *budget -= 1;
    if budget.is_multiple_of(1024) {
        checkpoint()?;
    }
    Ok(())
}

fn corrupt(message: &str) -> CoreError {
    CoreError::new(ErrorCode::CorruptChart, message)
}
