use open2jam_core::{
    error::{CoreError, ErrorCode},
    osu::{OsuNoteKind, OsuSource},
};
use serde_json::{Value, json};

#[test]
fn tempo_meter_scroll_and_tied_samples_match_the_frozen_java_compiler() {
    assert_java_timeline(
        include_bytes!("fixtures/osu/timing.osu"),
        include_str!("fixtures/osu/timing-java.json"),
    );
}

#[test]
fn positive_first_tempo_extrapolates_back_to_zero_without_quantization_drift() {
    assert_java_timeline(
        include_bytes!("fixtures/osu/late-tempo.osu"),
        include_str!("fixtures/osu/late-tempo-java.json"),
    );
}

fn assert_java_timeline(input: &[u8], expected: &str) {
    let source = OsuSource::parse(input, &mut || Ok(())).unwrap();
    let timeline = source.timeline(&mut || Ok(())).unwrap();
    let samples: Vec<_> = timeline
        .samples
        .iter()
        .map(|event| {
            let kind = match event.kind {
                OsuNoteKind::Tap => "NONE",
                OsuNoteKind::Hold => "HOLD",
                OsuNoteKind::Release => "RELEASE",
            };
            json!([
                event.at.get(),
                event.measure,
                event.lane.map(i32::from).unwrap_or(-1),
                kind,
                event.sample_index,
                f64::from(event.volume)
            ])
        })
        .collect();
    let actual = json!({
        "samples": samples,
        "measures": timeline.measures.iter().map(|t| t.get()).collect::<Vec<_>>(),
        "judgmentTiming": timeline.judgment_timing.iter().map(|p| json!([p.at.get(), p.bpm])).collect::<Vec<_>>(),
        "visualTiming": timeline.visual_timing.iter().map(|p| json!([p.at.get(), p.bpm])).collect::<Vec<_>>(),
    });
    let expected: Value = serde_json::from_str(expected).unwrap();
    assert_eq!(actual, expected);
}

#[test]
fn seven_key_timeline_matches_existing_gameplay_golden_and_hold_order() {
    let source = OsuSource::parse(
        include_bytes!("../../../../rewrite/golden/java-migration/sources/osu/seven-key.osu"),
        &mut || Ok(()),
    )
    .unwrap();
    let timeline = source.timeline(&mut || Ok(())).unwrap();
    let golden: Value = serde_json::from_str(include_str!(
        "../../../../rewrite/golden/java-migration/expected/osu/gameplay.json"
    ))
    .unwrap();
    let notes = golden["notes"].as_array().unwrap();
    assert_eq!(timeline.samples.len(), notes.len() + 2);
    assert_eq!(timeline.samples[0].lane, None);
    assert_eq!(timeline.samples[0].sample_index, 1);
    assert_eq!(timeline.samples[0].at.get(), 1_500_000);
    for (actual, expected) in timeline.samples[1..=notes.len()].iter().zip(notes) {
        assert_eq!(
            u64::from(actual.lane.unwrap()),
            expected["lane"].as_u64().unwrap()
        );
        assert_eq!(
            u64::from(actual.measure),
            expected["measure"].as_u64().unwrap()
        );
        assert_eq!(
            actual.at.get(),
            (expected["startMs"].as_f64().unwrap() * 1000.0).round() as u64
        );
        assert_eq!(actual.sample_index, 0);
        assert_eq!(actual.volume, 0.0);
    }
    assert_eq!(timeline.samples[8].kind, OsuNoteKind::Hold);
    assert_eq!(timeline.samples[9].kind, OsuNoteKind::Release);
    assert_eq!(timeline.samples[9].at.get(), 4_500_000);
    assert_eq!(
        timeline
            .measures
            .iter()
            .map(|t| t.get())
            .collect::<Vec<_>>(),
        [1_500_000, 3_500_000]
    );
    assert_eq!(timeline.judgment_timing.len(), 1);
    assert_eq!(timeline.visual_timing.len(), 1);
    assert!(timeline.scroll.is_empty());
}

fn source_with(timing: &str, notes: &str) -> OsuSource {
    let text = format!(
        "osu file format v14\n[General]\nMode:3\n[Difficulty]\nCircleSize:7\n[TimingPoints]\n{timing}\n[HitObjects]\n{notes}\n"
    );
    OsuSource::parse(text.as_bytes(), &mut || Ok(())).unwrap()
}

#[test]
fn unrepresentable_or_backwards_timelines_are_diagnosed() {
    for source in [
        source_with("0,0.000001,4,0,0,100,1", "0,0,1000,1,0"),
        source_with("-2147483648,500,4,0,0,100,1", "0,0,0,1,0"),
        source_with("0,500,4,0,0,100,1\n0,-1e-306,4,0,0,100,0", "0,0,0,1,0"),
        source_with(
            "0,500,4,0,0,100,1\n1000,500,1,0,0,100,1",
            "0,0,500,1,0\n0,0,1000,1,0",
        ),
    ] {
        assert_eq!(
            source.timeline(&mut || Ok(())).unwrap_err().code(),
            ErrorCode::CorruptChart
        );
    }
}

#[test]
fn sparse_measures_and_stress_work_can_be_cancelled() {
    let source = source_with("0,500,4,0,0,100,1", "0,0,2000000,1,0");
    let mut calls = 0;
    let error = source
        .timeline(&mut || {
            calls += 1;
            if calls == 100 {
                Err(CoreError::new(ErrorCode::Cancelled, "cancelled"))
            } else {
                Ok(())
            }
        })
        .unwrap_err();
    assert_eq!(error.code(), ErrorCode::Cancelled);
    let source = OsuSource::parse(
        include_bytes!("../../../../rewrite/golden/java-migration/sources/osu/stress-4096.osu"),
        &mut || Ok(()),
    )
    .unwrap();
    let timeline = source.timeline(&mut || Ok(())).unwrap();
    assert_eq!(timeline.samples.len(), 4097);
    assert_eq!(timeline.samples.last().unwrap().at.get(), 9_690_000);
    let error = source
        .timeline(&mut || Err(CoreError::new(ErrorCode::Cancelled, "cancelled")))
        .unwrap_err();
    assert_eq!(error.code(), ErrorCode::Cancelled);
}
