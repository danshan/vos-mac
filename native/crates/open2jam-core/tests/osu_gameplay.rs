use open2jam_core::{
    digest::Digest,
    error::{CoreError, ErrorCode},
    gameplay::{GameplayChartV2, Ratio},
    id::{SampleId, SongId},
    osu::{OsuMetadata, OsuSource},
    path::SourceRelativePath,
};
use serde_json::{Value, json};
use std::collections::BTreeMap;

fn metadata() -> OsuMetadata {
    OsuMetadata {
        song_id: SongId::from_digest(Digest::from_bytes([1; 32])),
        chart_path: SourceRelativePath::parse("seven-key.osu").unwrap(),
        title: "Seven Key Fixture".into(),
        artist: "Fixture Artist".into(),
    }
}

fn sample_ids() -> BTreeMap<u32, SampleId> {
    (1..=4)
        .map(|id| {
            (
                id,
                SampleId::from_digest(Digest::from_bytes([id as u8; 32])),
            )
        })
        .collect()
}

fn value(ratio: Ratio) -> f64 {
    ratio.numerator() as f64 / f64::from(ratio.denominator())
}

#[test]
fn overlapping_holds_and_autoplay_repairs_match_the_production_java_exporter() {
    let source = OsuSource::parse(include_bytes!("fixtures/osu/hold-repair.osu"), &mut || {
        Ok(())
    })
    .unwrap();
    let samples = sample_ids();
    let chart = source
        .compile(metadata(), &mut || Ok(()))
        .unwrap()
        .with_samples(&samples, &mut || Ok(()))
        .unwrap();
    let golden: Value =
        serde_json::from_str(include_str!("fixtures/osu/hold-repair-gameplay-java.json")).unwrap();
    assert_java_notes(&chart, &golden, &samples);
    assert_eq!(
        serde_json::to_value(&chart).unwrap()["durationUs"],
        2_500_000
    );
}

fn assert_java_notes(chart: &GameplayChartV2, golden: &Value, samples: &BTreeMap<u32, SampleId>) {
    let index = |id: Option<SampleId>| {
        id.map(|id| *samples.iter().find(|(_, value)| **value == id).unwrap().0)
            .unwrap_or(0)
    };
    let notes: Vec<_> = chart.notes().iter().map(|note| {
        let mut item = json!({
            "lane": note.lane(), "kind": if note.tail().is_some() { "holdStart" } else { "tap" },
            "startMs": note.start().get() as f64 / 1000.0, "measure": note.measure(),
            "eventOrder": note.event_order(), "sampleId": index(note.sample_id()),
            "volume": value(note.volume()), "pan": value(note.pan()),
        });
        if let Some(tail) = note.tail() {
            item["endMs"] = json!(tail.at().get() as f64 / 1000.0);
            item["endMeasure"] = json!(tail.measure());
            item["releaseEventOrder"] = json!(tail.event_order());
        }
        item
    }).collect();
    assert_eq!(json!(notes), golden["notes"]);
    let wire = serde_json::to_value(chart).unwrap();
    let autoplay: Vec<_> = wire["autoPlayEvents"]
        .as_array()
        .unwrap()
        .iter()
        .map(|event| {
            json!({"startMs":event["atUs"].as_u64().unwrap() as f64 / 1000.0,
            "sampleId":index(Some(serde_json::from_value(event["sampleId"].clone()).unwrap())),
            "volume":value(serde_json::from_value(event["volume"].clone()).unwrap()),
            "pan":value(serde_json::from_value(event["pan"].clone()).unwrap())})
        })
        .collect();
    let sounding: Vec<_> = golden["autoPlayEvents"]
        .as_array()
        .unwrap()
        .iter()
        .filter(|event| event["sampleId"] != 0)
        .cloned()
        .collect();
    assert_eq!(json!(autoplay), json!(sounding));
}

#[test]
fn compiled_timing_retains_independent_tracks_scroll_and_exact_binary32_volumes() {
    let source =
        OsuSource::parse(include_bytes!("fixtures/osu/timing.osu"), &mut || Ok(())).unwrap();
    let chart = source
        .compile(metadata(), &mut || Ok(()))
        .unwrap()
        .with_samples(&sample_ids(), &mut || Ok(()))
        .unwrap();
    let wire = serde_json::to_value(&chart).unwrap();
    let oracle: Value =
        serde_json::from_str(include_str!("fixtures/osu/timing-java.json")).unwrap();
    for name in ["judgmentTiming", "visualTiming"] {
        let actual = wire[name].as_array().unwrap();
        let expected = oracle[name].as_array().unwrap();
        assert_eq!(actual.len(), expected.len());
        for (actual, expected) in actual.iter().zip(expected) {
            assert_eq!(actual["atUs"], expected[0]);
            assert_eq!(
                value(serde_json::from_value(actual["bpm"].clone()).unwrap()),
                expected[1].as_f64().unwrap()
            );
        }
    }
    let scroll: Vec<_> = wire["scroll"]
        .as_array()
        .unwrap()
        .iter()
        .map(|point| {
            json!([
                point["atUs"],
                value(serde_json::from_value(point["multiplier"].clone()).unwrap())
            ])
        })
        .collect();
    assert_eq!(
        json!(scroll),
        json!([
            [1500000, 0.5],
            [3000000, 2.0],
            [3000000, 4.0],
            [4000000, 2.5],
            [6291667, 0.75]
        ])
    );
    assert_eq!(value(chart.notes()[0].volume()), 0.33000001311302185);
    assert_eq!(wire["durationUs"], 9_533_333);
}

fn text_source(timing: &str, notes: &str) -> OsuSource {
    OsuSource::parse(format!("osu file format v14\n[General]\nMode:3\n[Difficulty]\nCircleSize:7\n[TimingPoints]\n{timing}\n[HitObjects]\n{notes}\n").as_bytes(), &mut || Ok(())).unwrap()
}

#[test]
fn all_percentages_preserve_java_binary32_values_exactly() {
    let mut notes = String::new();
    for percent in 0..=100 {
        notes.push_str(&format!("0,0,{},1,0,0:0:0:{percent}:\n", percent * 10));
    }
    let source = text_source("0,500,4,0,0,100,1", &notes);
    let chart = source
        .compile(metadata(), &mut || Ok(()))
        .unwrap()
        .with_samples(&BTreeMap::new(), &mut || Ok(()))
        .unwrap();
    for (percent, note) in chart.notes().iter().enumerate() {
        assert_eq!(value(note.volume()), f64::from(percent as f32 / 100.0));
    }
}

#[test]
fn missing_custom_audio_and_cancellation_fail_without_partial_chart() {
    let source = text_source("0,500,4,0,0,100,1", "0,0,0,1,0,0:0:0:0:custom.wav");
    let error = source
        .compile(metadata(), &mut || Ok(()))
        .unwrap()
        .with_samples(&BTreeMap::new(), &mut || Ok(()))
        .unwrap_err();
    assert_eq!(error.code(), ErrorCode::MissingAsset);
    let error = source
        .compile(metadata(), &mut || Ok(()))
        .unwrap()
        .with_samples(&sample_ids(), &mut || {
            Err(CoreError::new(ErrorCode::Cancelled, "cancelled"))
        })
        .unwrap_err();
    assert_eq!(error.code(), ErrorCode::Cancelled);
}

#[test]
fn noninteger_velocities_fit_wire_bounds_with_the_declared_precision() {
    let source =
        OsuSource::parse(include_bytes!("fixtures/osu/precision.osu"), &mut || Ok(())).unwrap();
    let chart = source
        .compile(metadata(), &mut || Ok(()))
        .unwrap()
        .with_samples(&BTreeMap::new(), &mut || Ok(()))
        .unwrap();
    let wire = serde_json::to_value(chart).unwrap();
    let oracle: Value =
        serde_json::from_str(include_str!("fixtures/osu/precision-java.json")).unwrap();
    for name in ["judgmentTiming", "visualTiming"] {
        let actual = wire[name].as_array().unwrap();
        let expected = oracle[name].as_array().unwrap();
        assert_eq!(actual.len(), expected.len());
        for (actual, expected) in actual.iter().zip(expected) {
            assert_eq!(actual["atUs"], expected[0]);
            let ratio: Ratio = serde_json::from_value(actual["bpm"].clone()).unwrap();
            let expected = expected[1].as_f64().unwrap();
            assert!(
                (value(ratio) - expected).abs() <= expected * 4.0 * f64::EPSILON,
                "{ratio:?} vs {expected}"
            );
        }
    }
    // These differences around integral tempos are real Java binary64 output.
    assert_eq!(
        wire["judgmentTiming"][0]["bpm"],
        json!({"numerator":126,"denominator":1})
    );
}

#[test]
fn positive_velocities_outside_wire_precision_are_rejected() {
    for scroll in ["-1e20", "-1e-20"] {
        let source = text_source(
            &format!("0,500,4,0,0,100,1\n0,{scroll},4,0,0,100,0"),
            "0,0,0,1,0",
        );
        let error = source
            .compile(metadata(), &mut || Ok(()))
            .unwrap()
            .with_samples(&BTreeMap::new(), &mut || Ok(()))
            .unwrap_err();
        assert_eq!(error.code(), ErrorCode::CorruptChart);
        assert!(error.message().contains("rational"));
    }
}

#[test]
fn seven_key_gameplay_preserves_frozen_notes_and_resolves_only_sounding_samples() {
    let source = OsuSource::parse(
        include_bytes!("../../../../rewrite/golden/java-migration/sources/osu/seven-key.osu"),
        &mut || Ok(()),
    )
    .unwrap();
    let background = SampleId::from_digest(Digest::from_bytes([2; 32]));
    let chart = source
        .compile(metadata(), &mut || Ok(()))
        .unwrap()
        .with_samples(&BTreeMap::from([(1, background)]), &mut || Ok(()))
        .unwrap();
    chart.validate().unwrap();
    assert_eq!(chart.notes().len(), 8);
    assert!(chart.notes().iter().all(|note| note.sample_id().is_none()));
    let hold = &chart.notes()[7];
    assert_eq!(hold.event_order(), 7);
    assert_eq!(hold.start().get(), 3_500_000);
    assert_eq!(hold.tail().unwrap().at().get(), 4_500_000);
    assert_eq!(hold.tail().unwrap().event_order(), 8);
    let wire = serde_json::to_value(chart).unwrap();
    assert_eq!(wire["durationUs"], 4_500_000);
    assert_eq!(
        wire["autoPlayEvents"][0]["sampleId"],
        background.to_string()
    );
    assert_eq!(
        wire["judgmentTiming"][0]["bpm"],
        serde_json::json!({"numerator":120,"denominator":1})
    );
}
