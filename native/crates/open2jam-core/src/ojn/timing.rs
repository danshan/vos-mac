use super::{EventKind, OjnEvent, OjnSource, corrupt};
use crate::{
    error::CoreError,
    gameplay::{Ratio, TimeMicros, TimingPoint},
};

const MAX_MEASURES: u32 = 1_000_000;

#[derive(Debug)]
pub struct TimedOjnEvent {
    pub at: TimeMicros,
    pub event: OjnEvent,
}

#[derive(Debug)]
pub struct OjnTimeline {
    pub events: Vec<TimedOjnEvent>,
    pub measures: Vec<TimeMicros>,
    // OJN has no independent scroll or STOP events, so both timing tracks use this.
    pub timing: Vec<TimingPoint>,
}

impl OjnSource<'_> {
    pub fn timeline(
        &self,
        chart_index: usize,
        checkpoint: &mut impl FnMut() -> Result<(), CoreError>,
    ) -> Result<OjnTimeline, CoreError> {
        let events = self.events(chart_index, checkpoint)?;
        if events
            .last()
            .is_some_and(|event| event.measure >= MAX_MEASURES)
        {
            return Err(corrupt("OJN measure count exceeds timeline bound"));
        }
        let mut timer_ms = 1500.0;
        let mut bpm = f64::from(self.bpm());
        let mut measure = 0;
        let mut measure_length = 1.0;
        let mut position = 0.0;
        let mut timeline = OjnTimeline {
            events: Vec::with_capacity(events.len()),
            measures: vec![micros(timer_ms)?],
            timing: vec![TimingPoint::new(
                micros(timer_ms)?,
                bpm_ratio(self.bpm())?,
                0,
            )?],
        };
        for event in events {
            checkpoint()?;
            while measure < event.measure {
                checkpoint()?;
                if measure_length < position {
                    return Err(corrupt("OJN measure length precedes its final event"));
                }
                timer_ms += 240_000.0 * (measure_length - position) / bpm;
                timeline.measures.push(micros(timer_ms)?);
                measure += 1;
                measure_length = 1.0;
                position = 0.0;
            }
            // Unlike other legacy formats, OJN positions are not scaled by measure length.
            let next_position =
                event.position.numerator() as f64 / f64::from(event.position.denominator());
            timer_ms += 240_000.0 * (next_position - position) / bpm;
            position = next_position;
            let at = micros(timer_ms)?;
            match event.kind {
                EventKind::MeasureLength(value) => measure_length = f64::from(value),
                EventKind::Bpm(value) => {
                    bpm = f64::from(value);
                    timeline.timing.push(TimingPoint::new(
                        at,
                        bpm_ratio(value)?,
                        timeline.timing.len() as u32,
                    )?);
                }
                EventKind::Sample { .. } => {}
            }
            timeline.events.push(TimedOjnEvent { at, event });
        }
        Ok(timeline)
    }
}

fn micros(milliseconds: f64) -> Result<TimeMicros, CoreError> {
    let value = (milliseconds * 1000.0).round();
    if !value.is_finite() || !(0.0..=9_007_199_254_740_991.0).contains(&value) {
        return Err(corrupt("OJN timeline exceeds exact microsecond range"));
    }
    TimeMicros::new(value as u64)
}

// Preserve the binary32 BPM exactly rather than rounding it to a decimal percentage.
fn bpm_ratio(value: f32) -> Result<Ratio, CoreError> {
    let bits = value.to_bits();
    let exponent = ((bits >> 23) & 255) as i32 - 127 - 23;
    let mut numerator = u64::from((bits & 0x7f_ffff) | 0x80_0000);
    let mut shift = exponent;
    while shift < 0 && numerator.is_multiple_of(2) {
        numerator /= 2;
        shift += 1;
    }
    if !(-31..=29).contains(&shift) {
        return Err(corrupt("OJN BPM exceeds exact rational range"));
    }
    if shift >= 0 {
        Ratio::new((numerator << shift) as i64, 1)
    } else {
        Ratio::new(numerator as i64, 1_u32 << -shift)
    }
}
