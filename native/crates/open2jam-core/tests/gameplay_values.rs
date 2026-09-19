use open2jam_core::gameplay::{Note, Ratio, TimeMicros};

#[test]
fn exact_values_preserve_sub_millisecond_time_and_ojn_levels() {
    let time = TimeMicros::new(1_000_125).unwrap();
    assert_eq!(time.get(), 1_000_125);
    let volume = Ratio::new(15, 16).unwrap();
    assert_eq!(
        serde_json::to_string(&volume).unwrap(),
        r#"{"numerator":15,"denominator":16}"#
    );
    assert_eq!(Ratio::new(-14, 16).unwrap(), Ratio::new(-7, 8).unwrap());
    assert!(Ratio::new(1, 0).is_err());
    assert!(TimeMicros::new(9_007_199_254_740_992).is_err());
}

#[test]
fn hold_tail_preserves_measure_and_order_independently() {
    let note: Note = serde_json::from_str(
        r#"{
        "lane":2,"startUs":1000125,"measure":3,"eventOrder":9,
        "sampleId":null,"volume":{"numerator":15,"denominator":16},
        "pan":{"numerator":-7,"denominator":8},
        "tail":{"atUs":2000250,"measure":4,"eventOrder":17}
    }"#,
    )
    .unwrap();
    assert_eq!(note.start().get(), 1_000_125);
    let value = serde_json::to_value(note).unwrap();
    assert_eq!(value["tail"]["atUs"], 2_000_250);
    assert_eq!(value["tail"]["measure"], 4);
    assert_eq!(value["tail"]["eventOrder"], 17);
    assert_eq!(value["volume"]["denominator"], 16);
}

#[test]
fn deserialization_cannot_bypass_note_invariants() {
    let valid = serde_json::json!({
        "lane":0,"startUs":1000,"measure":2,"eventOrder":7,"sampleId":null,
        "volume":{"numerator":1,"denominator":1},
        "pan":{"numerator":0,"denominator":1},
        "tail":{"atUs":2000,"measure":3,"eventOrder":8}
    });
    for (pointer, replacement) in [
        ("/lane", serde_json::json!(7)),
        ("/startUs", serde_json::json!(-1)),
        ("/startUs", serde_json::json!(9_007_199_254_740_992_u64)),
        ("/volume/numerator", serde_json::json!(-1)),
        ("/volume/numerator", serde_json::json!(2)),
        ("/pan/numerator", serde_json::json!(-2)),
        ("/pan/numerator", serde_json::json!(2)),
        ("/volume/denominator", serde_json::json!(0)),
        ("/tail/atUs", serde_json::json!(999)),
        ("/tail/measure", serde_json::json!(1)),
        ("/sampleId", serde_json::json!("sample:invalid")),
    ] {
        let mut value = valid.clone();
        *value.pointer_mut(pointer).unwrap() = replacement;
        assert!(serde_json::from_value::<Note>(value).is_err(), "{pointer}");
    }
    for order in [6, 7] {
        let mut value = valid.clone();
        value["tail"]["atUs"] = 1000.into();
        value["tail"]["eventOrder"] = order.into();
        assert!(serde_json::from_value::<Note>(value).is_err());
    }
    let mut zero_length = valid;
    zero_length["tail"]["atUs"] = 1000.into();
    assert!(serde_json::from_value::<Note>(zero_length).is_ok());
}

#[test]
fn rational_extremes_are_bounded_and_normalized_without_overflow() {
    assert!(Ratio::new(i64::MIN, 1).is_err());
    assert_eq!(Ratio::new(0, u32::MAX).unwrap(), Ratio::new(0, 1).unwrap());
    let ratio = Ratio::new(9_007_199_254_740_991, u32::MAX).unwrap();
    assert!(ratio.is_between(i64::MIN, i64::MAX));
    assert!(!ratio.is_between(-1, 1));
    let invalid = r#"{"numerator":1,"denominator":0}"#;
    assert!(serde_json::from_str::<Ratio>(invalid).is_err());
}
