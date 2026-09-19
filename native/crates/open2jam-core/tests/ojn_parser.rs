use open2jam_core::{
    digest::Digest,
    error::{CoreError, ErrorCode},
    gameplay::Ratio,
    id::{SampleId, SongId},
    ojn::{EventKind, NoteKind, OjnMetadata, OjnSource},
};
use std::collections::BTreeMap;

const MINIMAL: &[u8] =
    include_bytes!("../../../../rewrite/golden/java-migration/sources/ojn/minimal.ojn");
const STRESS: &[u8] =
    include_bytes!("../../../../rewrite/golden/java-migration/sources/ojn/stress-4096.ojn");

#[test]
fn display_metadata_decodes_utf8_and_stops_at_the_first_nul() {
    let mut bytes = MINIMAL.to_vec();
    bytes[108..172].fill(0xff);
    let title = "\u{97f3}\u{697d}\u{306e}\u{4e16}\u{754c}";
    bytes[108..108 + title.len()].copy_from_slice(title.as_bytes());
    bytes[108 + title.len()] = 0;
    bytes[172..204].fill(0);
    bytes[172..178].copy_from_slice(b"Artist");
    let source = OjnSource::parse(&bytes).unwrap();
    assert_eq!(source.title().unwrap(), title);
    assert_eq!(source.artist().unwrap(), "Artist");
    assert_eq!(source.companion_bytes(), b"minimal.ojm");
}

#[test]
fn frozen_ojn_sources_expose_three_difficulties_and_actual_events() {
    let minimal = OjnSource::parse(MINIMAL).unwrap();
    assert_eq!(minimal.title_bytes(), b"Minimal O2Jam");
    assert_eq!(minimal.companion_bytes(), b"minimal.ojm");
    assert_eq!(minimal.bpm(), 130.0);
    assert_eq!(minimal.levels(), [3, 5, 8]);
    for index in 0..3 {
        assert!(minimal.events(index, &mut || Ok(())).unwrap().is_empty());
    }
    let stress = OjnSource::parse(STRESS).unwrap();
    let events = stress.events(0, &mut || Ok(())).unwrap();
    assert_eq!(events.len(), 4096);
    assert_eq!(events[4095].position.numerator(), 4095);
    assert_eq!(events[4095].position.denominator(), 4096);
    assert!(stress.events(1, &mut || Ok(())).unwrap().is_empty());
    assert!(stress.events(2, &mut || Ok(())).unwrap().is_empty());
}

fn with_packages(packages: &[(u32, u16, Vec<[u8; 4]>)]) -> Vec<u8> {
    let mut bytes = MINIMAL.to_vec();
    for (measure, channel, entries) in packages {
        bytes.extend(measure.to_le_bytes());
        bytes.extend(channel.to_le_bytes());
        bytes.extend((entries.len() as u16).to_le_bytes());
        for entry in entries {
            bytes.extend(entry);
        }
    }
    let end = (bytes.len() as u32).to_le_bytes();
    for offset in [288, 292, 296] {
        bytes[offset..offset + 4].copy_from_slice(&end);
    }
    bytes
}

#[test]
fn note_semantics_preserve_fractional_positions_source_order_and_exact_levels() {
    let bytes = with_packages(&[
        (1, 2, vec![[1, 0, 0xf1, 3]]),
        (0, 8, vec![[1, 0, 0, 2], [0; 4], [2, 0, 0x1f, 0]]),
        (1, 1, vec![180_f32.to_le_bytes()]),
        (1, 9, vec![[1, 0, 0x88, 4]]),
        (0, 0, vec![0.5_f32.to_le_bytes()]),
    ]);
    let source = OjnSource::parse(&bytes).unwrap();
    let events = source.events(0, &mut || Ok(())).unwrap();
    assert_eq!(events.len(), 6);
    assert_eq!(
        events[0].kind,
        EventKind::Sample {
            lane: Some(6),
            sample_index: 0,
            kind: NoteKind::Hold,
            volume: Ratio::new(1, 1).unwrap(),
            pan: Ratio::new(0, 1).unwrap(),
        }
    );
    assert_eq!(events[1].kind, EventKind::MeasureLength(0.5));
    assert_eq!(events[2].position, Ratio::new(2, 3).unwrap());
    assert_eq!(
        events[2].kind,
        EventKind::Sample {
            lane: Some(6),
            sample_index: 1,
            kind: NoteKind::Tap,
            volume: Ratio::new(1, 16).unwrap(),
            pan: Ratio::new(7, 8).unwrap(),
        }
    );
    assert_eq!(
        events[3].kind,
        EventKind::Sample {
            lane: Some(0),
            sample_index: 0,
            kind: NoteKind::Release,
            volume: Ratio::new(15, 16).unwrap(),
            pan: Ratio::new(-7, 8).unwrap(),
        }
    );
    assert_eq!(events[4].kind, EventKind::Bpm(180.0));
    assert_eq!(
        events[5].kind,
        EventKind::Sample {
            lane: None,
            sample_index: 1000,
            kind: NoteKind::Tap,
            volume: Ratio::new(1, 2).unwrap(),
            pan: Ratio::new(0, 1).unwrap(),
        }
    );
    assert_eq!(source.duration_seconds(0).unwrap(), 91);
}

#[test]
fn corrupt_lengths_and_negative_metadata_are_diagnosed_without_trusting_counts() {
    for end in 0..300 {
        assert!(OjnSource::parse(&MINIMAL[..end]).is_err());
    }
    for (offset, value) in [
        (284, 299),
        (288, 301),
        (296, u32::MAX),
        (268, 1),
        (272, u32::MAX),
    ] {
        let mut bytes = MINIMAL.to_vec();
        bytes[offset..offset + 4].copy_from_slice(&value.to_le_bytes());
        assert!(OjnSource::parse(&bytes).is_err(), "offset {offset}");
    }
    let mut bytes = MINIMAL.to_vec();
    bytes[20..22].copy_from_slice(&(-1_i16).to_le_bytes());
    assert!(OjnSource::parse(&bytes).is_err());
    let mut bytes = with_packages(&[(0, 2, vec![[1, 0, 0, 0]])]);
    bytes[306..308].copy_from_slice(&32767_i16.to_le_bytes());
    assert_eq!(
        OjnSource::parse(&bytes)
            .unwrap()
            .events(0, &mut || Ok(()))
            .unwrap_err()
            .code(),
        ErrorCode::CorruptChart
    );
    let source = OjnSource::parse(STRESS).unwrap();
    assert!(source.events(3, &mut || Ok(())).is_err());
    assert_eq!(
        source
            .events(0, &mut || Err(CoreError::new(
                ErrorCode::Cancelled,
                "cancelled"
            )))
            .unwrap_err()
            .code(),
        ErrorCode::Cancelled
    );
}

#[test]
fn timeline_preserves_ojn_measure_length_bpm_changes_and_lead_in() {
    let mut bytes = with_packages(&[
        (0, 0, vec![0.5_f32.to_le_bytes()]),
        (0, 2, vec![[0; 4], [1, 0, 0, 2], [0; 4], [0; 4]]),
        (0, 1, vec![[0; 4], 240_f32.to_le_bytes()]),
        (1, 2, vec![[0; 4], [1, 0, 0, 3]]),
        (2, 3, vec![[1, 0, 0, 0]]),
    ]);
    bytes[16..20].copy_from_slice(&120_f32.to_le_bytes());
    let timeline = OjnSource::parse(&bytes)
        .unwrap()
        .timeline(0, &mut || Ok(()))
        .unwrap();
    assert_eq!(
        timeline
            .measures
            .iter()
            .map(|t| t.get())
            .collect::<Vec<_>>(),
        [1_500_000, 2_500_000, 3_500_000]
    );
    assert_eq!(
        timeline
            .events
            .iter()
            .map(|e| e.at.get())
            .collect::<Vec<_>>(),
        [1_500_000, 2_000_000, 2_500_000, 3_000_000, 3_500_000]
    );
    assert_eq!(timeline.timing.len(), 2);
    assert_eq!(timeline.timing[0].bpm(), Ratio::new(120, 1).unwrap());
    assert_eq!(timeline.timing[1].bpm(), Ratio::new(240, 1).unwrap());
    assert_eq!(timeline.timing[1].at().get(), 2_500_000);
}

#[test]
fn timeline_keeps_sub_millisecond_precision_without_cumulative_rounding() {
    let source = OjnSource::parse(STRESS).unwrap();
    let timeline = source.timeline(0, &mut || Ok(())).unwrap();
    assert_eq!(timeline.events[1].at.get(), 1_500_451);
    assert_eq!(timeline.events[4095].at.get(), 3_345_703);
    let mut bytes = MINIMAL.to_vec();
    bytes[16..20].copy_from_slice(&130.125_f32.to_le_bytes());
    let timeline = OjnSource::parse(&bytes)
        .unwrap()
        .timeline(0, &mut || Ok(()))
        .unwrap();
    assert_eq!(timeline.timing[0].bpm(), Ratio::new(1041, 8).unwrap());
}

#[test]
fn timeline_rejects_unbounded_expansion_backward_time_and_unrepresentable_bpm() {
    let cases = [
        with_packages(&[(1_000_000, 2, vec![[1, 0, 0, 0]])]),
        with_packages(&[
            (0, 0, vec![0.25_f32.to_le_bytes()]),
            (0, 2, vec![[0; 4], [1, 0, 0, 0]]),
            (1, 2, vec![[1, 0, 0, 0]]),
        ]),
    ];
    for bytes in cases {
        assert_eq!(
            OjnSource::parse(&bytes)
                .unwrap()
                .timeline(0, &mut || Ok(()))
                .unwrap_err()
                .code(),
            ErrorCode::CorruptChart
        );
    }
    for bpm in [f32::MIN_POSITIVE, f32::MAX] {
        let mut bytes = MINIMAL.to_vec();
        bytes[16..20].copy_from_slice(&bpm.to_le_bytes());
        assert!(
            OjnSource::parse(&bytes)
                .unwrap()
                .timeline(0, &mut || Ok(()))
                .is_err()
        );
    }
    let bytes = with_packages(&[(999_999, 2, vec![[1, 0, 0, 0]])]);
    let mut checkpoints = 0;
    let error = OjnSource::parse(&bytes)
        .unwrap()
        .timeline(0, &mut || {
            checkpoints += 1;
            if checkpoints > 10 {
                Err(CoreError::new(ErrorCode::Cancelled, "cancelled"))
            } else {
                Ok(())
            }
        })
        .unwrap_err();
    assert_eq!(error.code(), ErrorCode::Cancelled);
}

#[test]
fn long_note_repair_matches_legacy_duplicate_hold_and_orphan_release_rules() {
    let bytes = with_packages(&[
        (
            0,
            2,
            vec![[1, 0, 0, 2], [2, 0, 0, 2], [2, 0, 0, 3], [9, 0, 0, 3]],
        ),
        (1, 9, vec![[1, 0, 0, 2], [1, 0, 0, 3]]),
    ]);
    let timeline = OjnSource::parse(&bytes)
        .unwrap()
        .timeline(0, &mut || Ok(()))
        .unwrap()
        .repair_long_notes(&mut || Ok(()))
        .unwrap();
    let samples: Vec<_> = timeline
        .events
        .iter()
        .filter_map(|event| match event.event.kind {
            EventKind::Sample {
                lane,
                sample_index,
                kind,
                ..
            } => Some((lane, sample_index, kind)),
            _ => None,
        })
        .collect();
    assert_eq!(
        samples,
        [
            (Some(0), 0, NoteKind::Tap),
            (Some(0), 1, NoteKind::Hold),
            (None, 1, NoteKind::Release),
            (Some(0), 8, NoteKind::Release),
            (None, 0, NoteKind::Tap)
        ]
    );
}

#[test]
fn long_note_repair_searches_forward_and_backward_before_assigning_autoplay() {
    type ExpectedSample = (Option<u8>, u32, NoteKind);
    type RepairCase<'a> = (&'a [[u8; 4]], &'a [ExpectedSample]);
    let cases: &[RepairCase<'_>] = &[
        (
            &[[1, 0, 0, 2], [2, 0, 0, 0], [1, 0, 0, 0]],
            &[
                (Some(0), 0, NoteKind::Hold),
                (None, 1, NoteKind::Tap),
                (Some(0), 0, NoteKind::Release),
            ],
        ),
        (
            &[[1, 0, 0, 0], [2, 0, 0, 0], [1, 0, 0, 3]],
            &[
                (Some(0), 0, NoteKind::Hold),
                (None, 1, NoteKind::Tap),
                (Some(0), 0, NoteKind::Release),
            ],
        ),
        (
            &[[1, 0, 0, 2], [2, 0, 0, 0]],
            &[
                (Some(0), 0, NoteKind::Hold),
                (Some(0), 1, NoteKind::Release),
            ],
        ),
        (
            &[
                [1, 0, 0, 2],
                [2, 0, 0, 0],
                [3, 0, 0, 0],
                [4, 0, 0, 2],
                [4, 0, 0, 3],
            ],
            &[
                (Some(0), 0, NoteKind::Hold),
                (None, 1, NoteKind::Tap),
                (Some(0), 2, NoteKind::Release),
                (Some(0), 3, NoteKind::Hold),
                (Some(0), 3, NoteKind::Release),
            ],
        ),
    ];
    for (entries, expected) in cases {
        let bytes = with_packages(&[(0, 2, entries.to_vec())]);
        let timeline = OjnSource::parse(&bytes)
            .unwrap()
            .timeline(0, &mut || Ok(()))
            .unwrap()
            .repair_long_notes(&mut || Ok(()))
            .unwrap();
        let samples: Vec<_> = timeline
            .events
            .iter()
            .filter_map(|event| match event.event.kind {
                EventKind::Sample {
                    lane,
                    sample_index,
                    kind,
                    ..
                } => Some((lane, sample_index, kind)),
                _ => None,
            })
            .collect();
        assert_eq!(&samples, expected, "{entries:?}");
    }
}

#[test]
fn long_note_repair_matches_frozen_java_cases_across_lanes() {
    let oracle: serde_json::Value =
        serde_json::from_str(include_str!("fixtures/ojn/hold-repair.json")).unwrap();
    for (case_index, case) in oracle["cases"].as_array().unwrap().iter().enumerate() {
        let mut packages = Vec::new();
        for (position, input) in case["input"].as_array().unwrap().iter().enumerate() {
            let sample = input[0].as_u64().unwrap() as u8;
            let lane = input[1].as_i64().unwrap();
            let kind = input[2].as_u64().unwrap() as u8;
            let mut entries = vec![[0; 4]; 24];
            entries[position] = [sample + 1, 0, 0xf1, kind];
            packages.push((0, if lane < 0 { 9 } else { lane as u16 + 2 }, entries));
        }
        let bytes = with_packages(&packages);
        let timeline = OjnSource::parse(&bytes)
            .unwrap()
            .timeline(0, &mut || Ok(()))
            .unwrap()
            .repair_long_notes(&mut || Ok(()))
            .unwrap();
        let actual: Vec<_> = timeline
            .events
            .iter()
            .map(|event| {
                let EventKind::Sample {
                    lane,
                    sample_index,
                    kind,
                    volume,
                    pan,
                } = event.event.kind
                else {
                    panic!("unexpected timing event");
                };
                assert_eq!(volume, Ratio::new(15, 16).unwrap());
                assert_eq!(pan, Ratio::new(-7, 8).unwrap());
                [
                    event.event.position.numerator() * 24
                        / i64::from(event.event.position.denominator()),
                    i64::from(sample_index),
                    lane.map(i64::from).unwrap_or(-1),
                    match kind {
                        NoteKind::Tap => 0,
                        NoteKind::Hold => 2,
                        NoteKind::Release => 3,
                    },
                ]
            })
            .collect();
        assert_eq!(
            serde_json::to_value(actual).unwrap(),
            case["expected"],
            "case {case_index}"
        );
    }
}

#[test]
fn adversarial_long_note_search_is_bounded_and_cancellable() {
    let bytes = with_packages(&[(0, 2, vec![[1, 0, 0, 3]; 9000])]);
    let source = OjnSource::parse(&bytes).unwrap();
    let error = source
        .timeline(0, &mut || Ok(()))
        .unwrap()
        .repair_long_notes(&mut || Ok(()))
        .unwrap_err();
    assert_eq!(error.code(), ErrorCode::CorruptChart);
    assert!(error.message().contains("search work bound"));
    let mut checkpoints = 0;
    let error = source
        .timeline(0, &mut || Ok(()))
        .unwrap()
        .repair_long_notes(&mut || {
            checkpoints += 1;
            if checkpoints == 100 {
                Err(CoreError::new(ErrorCode::Cancelled, "cancelled"))
            } else {
                Ok(())
            }
        })
        .unwrap_err();
    assert_eq!(error.code(), ErrorCode::Cancelled);
}

fn metadata() -> OjnMetadata {
    OjnMetadata {
        song_id: SongId::from_digest(Digest::from_bytes([1; 32])),
        title: "Fixture".into(),
        artist: "Artist".into(),
    }
}

#[test]
fn gameplay_compiles_paired_holds_sample_links_and_same_time_release_order() {
    let bytes = with_packages(&[
        (0, 2, vec![[1, 0, 0xf1, 2]]),
        (0, 9, vec![[0; 4], [2, 0, 0x88, 0]]),
        (1, 2, vec![[1, 0, 0, 3]]),
        (1, 2, vec![[2, 0, 0x1f, 0]]),
    ]);
    let first = SampleId::from_digest(Digest::from_bytes([2; 32]));
    let second = SampleId::from_digest(Digest::from_bytes([3; 32]));
    let samples = BTreeMap::from([(0, first), (1, second)]);
    let source = OjnSource::parse(&bytes).unwrap();
    let chart = source
        .gameplay(0, metadata(), &samples, &mut || Ok(()))
        .unwrap();
    let notes = chart.notes();
    assert_eq!(notes.len(), 2);
    assert_eq!(notes[0].start().get(), 1_500_000);
    assert_eq!(notes[0].event_order(), 0);
    assert_eq!(notes[0].sample_id(), Some(first));
    assert_eq!(notes[0].volume(), Ratio::new(15, 16).unwrap());
    assert_eq!(notes[0].pan(), Ratio::new(-7, 8).unwrap());
    let tail = notes[0].tail().unwrap();
    assert_eq!(
        (tail.at().get(), tail.measure(), tail.event_order()),
        (3_346_154, 1, 1)
    );
    assert_eq!(notes[1].start(), tail.at());
    assert_eq!(notes[1].event_order(), 2);
    assert_eq!(notes[1].sample_id(), Some(second));
    let json = serde_json::to_value(&chart).unwrap();
    assert_eq!(json["autoPlayEvents"][0]["sampleId"], second.to_string());
    assert_eq!(json["autoPlayEvents"][0]["atUs"], 2_423_077);
    assert_eq!(json["durationUs"], 91_000_000);
    let other = source
        .gameplay(1, metadata(), &samples, &mut || Ok(()))
        .unwrap();
    assert_eq!(chart.song_id(), other.song_id());
    assert_ne!(chart.chart_id(), other.chart_id());
}

#[test]
fn gameplay_rejects_missing_sounding_samples_and_dangling_holds() {
    let sample = SampleId::from_digest(Digest::from_bytes([2; 32]));
    let samples = BTreeMap::from([(0, sample)]);
    for channel in [2, 9] {
        let bytes = with_packages(&[(0, channel, vec![[2, 0, 0, 0]])]);
        let error = OjnSource::parse(&bytes)
            .unwrap()
            .gameplay(0, metadata(), &samples, &mut || Ok(()))
            .unwrap_err();
        assert_eq!(error.code(), ErrorCode::MissingAsset);
        assert_eq!(error.context().get("sampleIndex").unwrap(), "1");
    }
    let bytes = with_packages(&[(0, 2, vec![[1, 0, 0, 2]])]);
    let error = OjnSource::parse(&bytes)
        .unwrap()
        .gameplay(0, metadata(), &samples, &mut || Ok(()))
        .unwrap_err();
    assert_eq!(error.code(), ErrorCode::CorruptChart);
    assert!(error.message().contains("no release"));
    let bytes = with_packages(&[(0, 2, vec![[1, 0, 0, 2], [99, 0, 0, 3]])]);
    let chart = OjnSource::parse(&bytes)
        .unwrap()
        .gameplay(0, metadata(), &samples, &mut || Ok(()))
        .unwrap();
    assert!(chart.notes()[0].tail().is_some());
}

#[test]
fn gameplay_covers_events_beyond_declared_duration_and_deduplicates_sample_content() {
    let mut bytes = with_packages(&[(0, 2, vec![[1, 0, 0, 0], [2, 0, 0, 0]])]);
    bytes[272..276].copy_from_slice(&0_u32.to_le_bytes());
    let sample = SampleId::from_digest(Digest::from_bytes([2; 32]));
    let samples = BTreeMap::from([(0, sample), (1, sample)]);
    let source = OjnSource::parse(&bytes).unwrap();
    let chart = source
        .gameplay(0, metadata(), &samples, &mut || Ok(()))
        .unwrap();
    assert_eq!(chart.samples(), &[sample]);
    assert_eq!(
        serde_json::to_value(&chart).unwrap()["durationUs"],
        2_423_077
    );
    assert_eq!(
        source
            .gameplay(3, metadata(), &samples, &mut || Ok(()))
            .unwrap_err()
            .code(),
        ErrorCode::InvalidRequest
    );
    assert_eq!(
        source
            .gameplay(0, metadata(), &samples, &mut || Err(CoreError::new(
                ErrorCode::Cancelled,
                "cancelled"
            )))
            .unwrap_err()
            .code(),
        ErrorCode::Cancelled
    );
}

#[test]
fn gameplay_omits_identical_same_time_bpm_points_like_the_java_exporter() {
    let bytes = with_packages(&[
        (0, 1, vec![130_f32.to_le_bytes()]),
        (0, 1, vec![130_f32.to_le_bytes()]),
    ]);
    let chart = OjnSource::parse(&bytes)
        .unwrap()
        .gameplay(0, metadata(), &BTreeMap::new(), &mut || Ok(()))
        .unwrap();
    let json = serde_json::to_value(chart).unwrap();
    assert_eq!(json["judgmentTiming"].as_array().unwrap().len(), 1);
    assert_eq!(json["visualTiming"], json["judgmentTiming"]);
}

#[test]
fn display_metadata_decodes_legacy_east_asian_fields_independently() {
    let cases: &[(&[u8], &str)] = &[
        (
            b"\xbe\xc6\xb8\xa7\xb4\xd9\xbf\xee\x20\xbc\xbc\xbb\xf3",
            "\u{c544}\u{b984}\u{b2e4}\u{c6b4} \u{c138}\u{c0c1}",
        ),
        (
            b"\xc3\xc0\xc0\xf6\xb5\xc4\xd2\xf4\xc0\xd6\xca\xc0\xbd\xe7",
            "\u{7f8e}\u{4e3d}\u{7684}\u{97f3}\u{4e50}\u{4e16}\u{754c}",
        ),
        (
            b"\xac\xfc\xc4\x52\xaa\xba\xad\xb5\xbc\xd6\xa5\x40\xac\xc9",
            "\u{7f8e}\u{9e97}\u{7684}\u{97f3}\u{6a02}\u{4e16}\u{754c}",
        ),
        (
            b"\x94\xfc\x82\xb5\x82\xa2\x89\xb9\x8a\x79\x82\xcc\x90\xa2\x8a\x45",
            "\u{7f8e}\u{3057}\u{3044}\u{97f3}\u{697d}\u{306e}\u{4e16}\u{754c}",
        ),
    ];
    for (raw, expected) in cases {
        let mut bytes = MINIMAL.to_vec();
        bytes[108..172].fill(0);
        bytes[108..108 + raw.len()].copy_from_slice(raw);
        bytes[172..204].fill(0);
        let artist = b"\x94\xfc\x82\xb5\x82\xa2\x89\xb9\x8a\x79\x82\xcc\x90\xa2\x8a\x45";
        bytes[172..172 + artist.len()].copy_from_slice(artist);
        let source = OjnSource::parse(&bytes).unwrap();
        assert_eq!(source.title().unwrap(), *expected);
        assert_eq!(
            source.artist().unwrap(),
            "\u{7f8e}\u{3057}\u{3044}\u{97f3}\u{697d}\u{306e}\u{4e16}\u{754c}"
        );
        assert_eq!(source.title_bytes(), *raw);
    }
}
