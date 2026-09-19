use super::{MAX_EVENTS, OsuSource, OsuTimingKind, corrupt};
use crate::{error::CoreError, gameplay::TimeMicros};

const MAX_MEASURES: u32 = 1_000_000;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum OsuNoteKind {
    Tap,
    Hold,
    Release,
}

#[derive(Debug)]
pub struct TimedOsuSample {
    pub at: TimeMicros,
    pub measure: u32,
    pub lane: Option<u8>,
    pub kind: OsuNoteKind,
    pub sample_index: u32,
    pub volume: f32,
}

#[derive(Debug)]
pub struct OsuVelocityChange {
    pub at: TimeMicros,
    pub bpm: f64,
}

#[derive(Debug)]
pub struct OsuScrollChange {
    pub at: TimeMicros,
    pub multiplier: f64,
}

/// Compiled source events before long-note repair and bundle sample resolution.
#[derive(Debug)]
pub struct OsuTimeline {
    pub samples: Vec<TimedOsuSample>,
    pub measures: Vec<TimeMicros>,
    // Keep the compiler's binary64 values until conversion to the bundle wire model.
    pub judgment_timing: Vec<OsuVelocityChange>,
    pub visual_timing: Vec<OsuVelocityChange>,
    pub scroll: Vec<OsuScrollChange>,
}

#[derive(Clone, Copy)]
struct Position {
    measure: u32,
    fraction: f64,
}

enum EventKind {
    Bpm(f64),
    Meter(f64),
    Scroll(f64),
    Sample {
        lane: Option<u8>,
        kind: OsuNoteKind,
        index: u32,
        volume: f32,
    },
}

struct Event {
    position: Position,
    kind: EventKind,
}

struct BeatPoint {
    time: i32,
    length: f64,
    meter: u32,
    beats: f64,
    measures: f64,
}

struct TimingMap {
    points: Vec<BeatPoint>,
    origin_beat: f64,
    origin_measure: f64,
}

impl TimingMap {
    fn new(
        source: &OsuSource,
        checkpoint: &mut impl FnMut() -> Result<(), CoreError>,
    ) -> Result<Self, CoreError> {
        let mut points = Vec::new();
        for point in &source.timing {
            checkpoint()?;
            if let OsuTimingKind::Beat {
                beat_length_ms,
                meter,
            } = point.kind
            {
                if !beat_length_ms.is_finite() || beat_length_ms <= 0.0 || meter == 0 {
                    return Err(corrupt("invalid osu beat point"));
                }
                positive(60_000.0 / beat_length_ms)?;
                points.push(BeatPoint {
                    time: point.time_ms,
                    length: beat_length_ms,
                    meter,
                    beats: 0.0,
                    measures: 0.0,
                });
            }
        }
        if points.is_empty() {
            return Err(corrupt("osu timeline requires a base tempo"));
        }
        points.sort_by_key(|point| point.time);
        for index in 1..points.len() {
            checkpoint()?;
            let previous = &points[index - 1];
            let delta = elapsed(points[index].time, previous.time)? / previous.length;
            let beats = previous.beats + delta;
            let measures = previous.measures + delta / f64::from(previous.meter);
            if !beats.is_finite() || !measures.is_finite() {
                return Err(corrupt("osu timing map exceeds finite range"));
            }
            points[index].beats = beats;
            points[index].measures = measures;
        }
        let mut map = Self {
            points,
            origin_beat: 0.0,
            origin_measure: 0.0,
        };
        (map.origin_beat, map.origin_measure) = map.raw_at(0)?;
        Ok(map)
    }

    fn raw_at(&self, time: i32) -> Result<(f64, f64), CoreError> {
        // Before the first point, extrapolate with its tempo. At ties, use the last.
        let index = self
            .points
            .partition_point(|point| point.time <= time)
            .saturating_sub(1);
        let point = &self.points[index];
        let delta = elapsed(time, point.time)? / point.length;
        Ok((
            point.beats + delta,
            point.measures + delta / f64::from(point.meter),
        ))
    }

    fn position(&self, time: i32) -> Result<Position, CoreError> {
        let (beat, measure) = self.raw_at(time)?;
        let beat = beat - self.origin_beat;
        let measure = measure - self.origin_measure;
        if !beat.is_finite() || !measure.is_finite() {
            return Err(corrupt("osu position exceeds finite range"));
        }
        if beat < 0.0 || measure < 0.0 {
            return Ok(Position {
                measure: 0,
                fraction: 0.0,
            });
        }
        if measure >= f64::from(MAX_MEASURES) {
            return Err(corrupt("osu measure count exceeds timeline bound"));
        }
        Ok(Position {
            measure: measure.floor() as u32,
            fraction: measure - measure.floor(),
        })
    }
}

impl OsuSource {
    pub fn timeline(
        &self,
        checkpoint: &mut impl FnMut() -> Result<(), CoreError>,
    ) -> Result<OsuTimeline, CoreError> {
        checkpoint()?;
        if self.notes.len().saturating_add(self.timing.len()) > MAX_EVENTS {
            return Err(corrupt("osu event count exceeds timeline bound"));
        }
        let map = TimingMap::new(self, checkpoint)?;
        let mut events = Vec::new();
        if self.audio_filename.is_some() {
            events.push(Event {
                position: Position {
                    measure: 0,
                    fraction: 0.0,
                },
                kind: EventKind::Sample {
                    lane: None,
                    kind: OsuNoteKind::Tap,
                    index: 1,
                    volume: 1.0,
                },
            });
        }
        // Java inserts sorted base tempos before scroll points and hit objects.
        for point in &map.points {
            checkpoint()?;
            let position = map.position(point.time)?;
            events.push(Event {
                position,
                kind: EventKind::Bpm(60_000.0 / point.length),
            });
            if point.meter != 4 {
                events.push(Event {
                    position,
                    kind: EventKind::Meter(f64::from(point.meter) / 4.0),
                });
            }
        }
        for point in &self.timing {
            checkpoint()?;
            if let OsuTimingKind::Scroll { speed } = point.kind {
                positive(speed)?;
                events.push(Event {
                    position: map.position(point.time_ms)?,
                    kind: EventKind::Scroll(speed),
                });
            }
        }
        for note in &self.notes {
            checkpoint()?;
            if !(1..=7).contains(&note.lane)
                || note.time_ms < 0
                || note.end_ms.is_some_and(|end| end <= note.time_ms)
                || !(0.0..=1.0).contains(&note.volume)
            {
                return Err(corrupt("invalid osu note in timeline"));
            }
            let kind = if note.end_ms.is_some() {
                OsuNoteKind::Hold
            } else {
                OsuNoteKind::Tap
            };
            for (time, kind) in std::iter::once((note.time_ms, kind))
                .chain(note.end_ms.map(|end| (end, OsuNoteKind::Release)))
            {
                events.push(Event {
                    position: map.position(time)?,
                    kind: EventKind::Sample {
                        lane: Some(note.lane - 1),
                        kind,
                        index: note.sample_index,
                        volume: note.volume,
                    },
                });
            }
        }
        events.sort_by(|a, b| {
            let key = |event: &Event| f64::from(event.position.measure) + event.position.fraction;
            key(a).total_cmp(&key(b))
        });
        checkpoint()?;
        compile(events, 60_000.0 / map.points[0].length, checkpoint)
    }
}

fn compile(
    events: Vec<Event>,
    mut bpm: f64,
    checkpoint: &mut impl FnMut() -> Result<(), CoreError>,
) -> Result<OsuTimeline, CoreError> {
    let mut timer_ms = 1500.0;
    let mut previous_judgment = (timer_ms, bpm);
    let mut previous_visual = (timer_ms, bpm);
    let mut scroll = 1.0;
    let mut measure = 0;
    let mut length = 1.0;
    let mut position = 0.0;
    let mut timeline = OsuTimeline {
        samples: Vec::new(),
        measures: vec![micros(timer_ms)?],
        judgment_timing: vec![OsuVelocityChange {
            at: micros(timer_ms)?,
            bpm,
        }],
        visual_timing: vec![OsuVelocityChange {
            at: micros(timer_ms)?,
            bpm,
        }],
        scroll: Vec::new(),
    };
    for event in events {
        checkpoint()?;
        while measure < event.position.measure {
            checkpoint()?;
            timer_ms += 240_000.0 * (length - position) / bpm;
            timeline.measures.push(micros(timer_ms)?);
            measure += 1;
            length = 1.0;
            position = 0.0;
        }
        // Preserve legacy non-OJN scaling and the per-measure signature reset.
        let next_position = event.position.fraction * length;
        timer_ms += 240_000.0 * (next_position - position) / bpm;
        position = next_position;
        let at = micros(timer_ms)?;
        match event.kind {
            EventKind::Bpm(value) => {
                bpm = value;
                add_velocity(
                    &mut timeline.judgment_timing,
                    &mut previous_judgment,
                    timer_ms,
                    bpm,
                )?;
                add_velocity(
                    &mut timeline.visual_timing,
                    &mut previous_visual,
                    timer_ms,
                    bpm * scroll,
                )?;
            }
            EventKind::Scroll(value) => {
                scroll = value;
                timeline.scroll.push(OsuScrollChange {
                    at,
                    multiplier: scroll,
                });
                add_velocity(
                    &mut timeline.visual_timing,
                    &mut previous_visual,
                    timer_ms,
                    bpm * scroll,
                )?;
            }
            EventKind::Meter(value) => length = value,
            EventKind::Sample {
                lane,
                kind,
                index,
                volume,
            } => {
                timeline.samples.push(TimedOsuSample {
                    at,
                    measure,
                    lane,
                    kind,
                    sample_index: index,
                    volume,
                });
            }
        }
    }
    if !ordered(&timeline.samples, |sample| sample.at)
        || !ordered(&timeline.measures, |at| *at)
        || !ordered(&timeline.judgment_timing, |point| point.at)
        || !ordered(&timeline.visual_timing, |point| point.at)
        || !ordered(&timeline.scroll, |point| point.at)
    {
        return Err(corrupt(
            "osu signature changes produce a backwards timeline",
        ));
    }
    checkpoint()?;
    Ok(timeline)
}

fn ordered<T>(values: &[T], time: impl Fn(&T) -> TimeMicros) -> bool {
    values
        .windows(2)
        .all(|pair| time(&pair[0]) <= time(&pair[1]))
}

fn add_velocity(
    changes: &mut Vec<OsuVelocityChange>,
    previous: &mut (f64, f64),
    milliseconds: f64,
    bpm: f64,
) -> Result<(), CoreError> {
    positive(bpm)?;
    // Deduplicate before rounding time, as VosGameplayExporter does.
    if *previous != (milliseconds, bpm) {
        changes.push(OsuVelocityChange {
            at: micros(milliseconds)?,
            bpm,
        });
        *previous = (milliseconds, bpm);
    }
    Ok(())
}

fn positive(value: f64) -> Result<(), CoreError> {
    if value.is_finite() && value > 0.0 {
        Ok(())
    } else {
        Err(corrupt("osu timing velocity must be positive and finite"))
    }
}

fn elapsed(time: i32, origin: i32) -> Result<f64, CoreError> {
    time.checked_sub(origin)
        .map(f64::from)
        .ok_or_else(|| corrupt("osu timing difference exceeds supported range"))
}

fn micros(milliseconds: f64) -> Result<TimeMicros, CoreError> {
    let value = (milliseconds * 1000.0).round();
    if !value.is_finite() || !(0.0..=9_007_199_254_740_991.0).contains(&value) {
        return Err(corrupt("osu timeline exceeds exact microsecond range"));
    }
    TimeMicros::new(value as u64)
}
