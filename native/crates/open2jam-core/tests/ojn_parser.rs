use open2jam_core::{
    error::{CoreError, ErrorCode},
    gameplay::Ratio,
    ojn::{EventKind, NoteKind, OjnSource},
};

const MINIMAL: &[u8] =
    include_bytes!("../../../../rewrite/golden/java-migration/sources/ojn/minimal.ojn");
const STRESS: &[u8] =
    include_bytes!("../../../../rewrite/golden/java-migration/sources/ojn/stress-4096.ojn");

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
