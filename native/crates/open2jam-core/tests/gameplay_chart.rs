use open2jam_core::{
    gameplay::GameplayChartV2,
    json::{decode_contract, encode_contract},
};

fn fixture() -> serde_json::Value {
    serde_json::json!({
        "schemaVersion":2,
        "songId":format!("song:sha256:{}", "01".repeat(32)),
        "chartId":format!("chart:sha256:{}", "02".repeat(32)),
        "format":"O2JAM", "keys":7, "title":"Controlled chart", "artist":"Fixture",
        "durationUs":3_000_500,
        "samples":[format!("sample:sha256:{}", "03".repeat(32))],
        "notes":[{"lane":0,"startUs":1_000_125,"measure":0,"eventOrder":2,
            "sampleId":format!("sample:sha256:{}", "03".repeat(32)),
            "volume":{"numerator":15,"denominator":16},"pan":{"numerator":-7,"denominator":8},
            "tail":{"atUs":2_000_250,"measure":1,"eventOrder":4}}],
        "measures":[0,2_000_000],
        "judgmentTiming":[{"atUs":0,"bpm":{"numerator":120,"denominator":1},"eventOrder":0}],
        "visualTiming":[{"atUs":0,"bpm":{"numerator":120,"denominator":1},"eventOrder":0},
            {"atUs":500_125,"bpm":{"numerator":180,"denominator":1},"eventOrder":1}],
        "scroll":[{"atUs":500_125,"multiplier":{"numerator":3,"denominator":2},"eventOrder":1}],
        "autoPlayEvents":[{"atUs":125,"eventOrder":1,
            "sampleId":format!("sample:sha256:{}", "03".repeat(32)),
            "volume":{"numerator":1,"denominator":2},"pan":{"numerator":0,"denominator":1}}]
    })
}

#[test]
fn chart_preserves_separate_judgment_visual_scroll_and_measure_data() {
    let input = fixture();
    let chart: GameplayChartV2 = decode_contract(&serde_json::to_vec(&input).unwrap()).unwrap();
    let output: serde_json::Value =
        serde_json::from_slice(&encode_contract(&chart).unwrap()).unwrap();
    assert_eq!(input, output);
    assert_eq!(output["notes"][0]["startUs"], 1_000_125);
    assert_eq!(output["visualTiming"][1]["bpm"]["numerator"], 180);
    assert_eq!(output["judgmentTiming"].as_array().unwrap().len(), 1);
    assert_eq!(output["scroll"][0]["multiplier"]["denominator"], 2);
}

#[test]
fn sampleless_notes_keep_format_specific_volume_and_pan() {
    let mut value = fixture();
    value["notes"][0]["sampleId"] = serde_json::Value::Null;
    let chart: GameplayChartV2 = serde_json::from_value(value).unwrap();
    assert!(chart.notes()[0].sample_id().is_none());
    assert_eq!(chart.notes()[0].volume().numerator(), 15);
    assert_eq!(chart.notes()[0].pan().numerator(), -7);
}

#[test]
fn invalid_chart_references_and_sequences_are_rejected() {
    for (path, replacement) in [
        ("/keys", serde_json::json!(6)),
        ("/format", serde_json::json!("BUNDLE")),
        ("/durationUs", serde_json::json!(1000)),
        ("/samples", serde_json::json!([])),
        ("/notes/0/measure", serde_json::json!(9)),
        ("/notes/0/tail/measure", serde_json::json!(9)),
        ("/visualTiming", serde_json::json!([])),
        ("/judgmentTiming", serde_json::json!([])),
        ("/measures", serde_json::json!([1000, 0])),
        ("/scroll/0/multiplier/numerator", serde_json::json!(-1)),
        ("/visualTiming/0/bpm/numerator", serde_json::json!(-1)),
        ("/autoPlayEvents/0/volume/numerator", serde_json::json!(3)),
        (
            "/autoPlayEvents/0/sampleId",
            serde_json::json!(format!("sample:sha256:{}", "04".repeat(32))),
        ),
    ] {
        let mut value = fixture();
        *value.pointer_mut(path).unwrap() = replacement;
        assert!(
            serde_json::from_value::<GameplayChartV2>(value).is_err(),
            "{path}"
        );
    }
    for array in [
        "notes",
        "samples",
        "judgmentTiming",
        "visualTiming",
        "scroll",
        "autoPlayEvents",
    ] {
        let mut value = fixture();
        let values = value[array].as_array_mut().unwrap();
        values.push(values[0].clone());
        assert!(
            serde_json::from_value::<GameplayChartV2>(value).is_err(),
            "{array}"
        );
    }
    let mut value = fixture();
    value["visualTiming"].as_array_mut().unwrap().reverse();
    assert!(serde_json::from_value::<GameplayChartV2>(value).is_err());
}

#[test]
fn hold_release_and_note_head_cannot_share_one_order_at_one_time() {
    let mut value = fixture();
    let mut tap = value["notes"][0].clone();
    tap["startUs"] = 2_000_250.into();
    tap["eventOrder"] = 4.into();
    tap["tail"] = serde_json::Value::Null;
    value["notes"].as_array_mut().unwrap().push(tap);
    assert!(serde_json::from_value::<GameplayChartV2>(value).is_err());
}

#[test]
fn gameplay_schema_and_unknown_fields_fail_closed() {
    let mut value = fixture();
    value["schemaVersion"] = 3.into();
    let error =
        decode_contract::<GameplayChartV2>(&serde_json::to_vec(&value).unwrap()).unwrap_err();
    assert_eq!(
        error.code(),
        open2jam_core::error::ErrorCode::UnsupportedSchema
    );
    for pointer in ["", "/visualTiming/0", "/scroll/0", "/autoPlayEvents/0"] {
        let mut value = fixture();
        value
            .pointer_mut(pointer)
            .unwrap()
            .as_object_mut()
            .unwrap()
            .insert("unknown".to_owned(), true.into());
        assert!(
            serde_json::from_value::<GameplayChartV2>(value).is_err(),
            "{pointer}"
        );
    }
    let mut text = serde_json::to_string(&fixture()).unwrap();
    text.insert_str(1, "\"keys\":7,");
    assert!(decode_contract::<GameplayChartV2>(text.as_bytes()).is_err());
}

#[test]
fn simultaneous_timing_changes_retain_source_order_and_stop_velocity() {
    let mut value = fixture();
    value["visualTiming"][1]["atUs"] = 0.into();
    value["visualTiming"][1]["bpm"]["numerator"] = 0.into();
    let chart: GameplayChartV2 = serde_json::from_value(value).unwrap();
    let output = serde_json::to_value(chart).unwrap();
    assert_eq!(output["visualTiming"][0]["eventOrder"], 0);
    assert_eq!(output["visualTiming"][1]["eventOrder"], 1);
    assert_eq!(output["visualTiming"][1]["bpm"]["numerator"], 0);
}
