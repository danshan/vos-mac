use open2jam_core::{
    error::ErrorCode,
    osu::{OsuSource, OsuTimingKind},
};

#[test]
fn frozen_seven_key_source_preserves_lanes_holds_and_metadata() {
    let source = OsuSource::parse(
        include_bytes!("../../../../rewrite/golden/java-migration/sources/osu/seven-key.osu"),
        &mut || Ok(()),
    )
    .unwrap();
    assert_eq!(source.title, "Seven Key Fixture");
    assert_eq!(source.artist, "Fixture Artist");
    assert_eq!(source.difficulty_name, "Test 7K");
    assert_eq!(source.audio_filename.unwrap().as_str(), "audio.wav");
    assert_eq!(source.notes.len(), 8);
    for (index, note) in source.notes[..7].iter().enumerate() {
        assert_eq!(note.lane, index as u8 + 1);
        assert_eq!(note.time_ms, index as i32 * 250);
        assert_eq!(note.end_ms, None);
        assert_eq!(note.sample_index, 0);
        assert_eq!(note.volume, 0.0);
    }
    assert_eq!(source.notes[7].lane, 4);
    assert_eq!(source.notes[7].end_ms, Some(3000));
    assert_eq!(
        source.timing[0].kind,
        OsuTimingKind::Beat {
            beat_length_ms: 500.0,
            meter: 4
        }
    );
}

#[test]
fn custom_samples_and_scroll_points_keep_source_order_and_java_volume_semantics() {
    let input = b"\xef\xbb\xbfosu file format v14\r\n[General]\r\nMode:3\r\n[Difficulty]\r\nCircleSize:7\r\n[TimingPoints]\r\n-100,500,3,0,0,100,1,0\r\n1000,-50,4,0,0,100,0,0\r\n[HitObjects]\r\n512,0,100.5,1,0,0:0:0:25:custom.wav\r\n-1,0,200,128,0,400:0:0:0:150:custom.wav\r\n";
    let source = OsuSource::parse(input, &mut || Ok(())).unwrap();
    assert_eq!(source.notes[0].time_ms, 101);
    assert_eq!(source.notes[0].lane, 7);
    assert_eq!(source.notes[1].lane, 1);
    assert_eq!(source.notes[0].sample_index, 2);
    assert_eq!(source.notes[1].sample_index, 2);
    assert_eq!(source.samples.len(), 1);
    assert_eq!(source.notes[0].volume, 0.25);
    assert_eq!(source.notes[1].volume, 1.0);
    assert_eq!(source.timing[1].kind, OsuTimingKind::Scroll { speed: 2.0 });
}

#[test]
fn unsupported_modes_and_key_counts_are_never_interpreted_as_seven_keys() {
    for name in ["non-mania.osu", "non-seven-key.osu"] {
        let path = std::path::Path::new(env!("CARGO_MANIFEST_DIR"))
            .join("../../../rewrite/golden/java-migration/sources/osu")
            .join(name);
        assert_eq!(
            OsuSource::parse(&std::fs::read(path).unwrap(), &mut || Ok(()))
                .unwrap_err()
                .code(),
            ErrorCode::UnsupportedFormat
        );
    }
}

#[test]
fn malformed_timing_notes_and_audio_references_are_diagnosed() {
    let base = "osu file format v14\n[General]\nMode:3\n[Difficulty]\nCircleSize:7\n";
    for suffix in [
        "[TimingPoints]\n0,NaN,4,0,0,100,1,0",
        "[TimingPoints]\n0,0,4,0,0,100,1,0",
        "[TimingPoints]\n0,5e-324,4,0,0,100,1,0",
        "[TimingPoints]\n0,500,0,0,0,100,1,0",
        "[TimingPoints]\n0,500,4,0,0,100,0,0",
        "[HitObjects]\n0,0,0,128,0,0:0:0:0:0:",
        "[HitObjects]\n0,0,2147483648,1,0",
        "[HitObjects]\n0,0,NaN,1,0",
        "[HitObjects]\n0,0,-1,1,0",
        "[HitObjects]\n0,0,0",
        "[HitObjects]\n0,0,0,1,0,0:0:0:100:../outside.wav",
        "[General]\nAudioFilename:/outside.wav",
    ] {
        let result = OsuSource::parse(format!("{base}{suffix}\n").as_bytes(), &mut || Ok(()));
        assert_eq!(
            result.unwrap_err().code(),
            ErrorCode::CorruptChart,
            "{suffix}"
        );
    }
    let input = format!("{base}[Difficulty]\nCircleSize:6.5\n");
    assert_eq!(
        OsuSource::parse(input.as_bytes(), &mut || Ok(()))
            .unwrap_err()
            .code(),
        ErrorCode::UnsupportedFormat
    );
}

#[test]
fn parser_limits_encoding_line_size_and_cancellation() {
    use open2jam_core::error::CoreError;
    assert_eq!(
        OsuSource::parse(&[255], &mut || Ok(())).unwrap_err().code(),
        ErrorCode::CorruptChart
    );
    assert_eq!(
        OsuSource::parse(b"osu file format v14\0", &mut || Ok(()))
            .unwrap_err()
            .code(),
        ErrorCode::CorruptChart
    );
    let line = format!("osu file format v14\n{}", "x".repeat(65537));
    assert_eq!(
        OsuSource::parse(line.as_bytes(), &mut || Ok(()))
            .unwrap_err()
            .code(),
        ErrorCode::CorruptChart
    );
    let source =
        include_bytes!("../../../../rewrite/golden/java-migration/sources/osu/stress-4096.osu");
    assert_eq!(
        OsuSource::parse(source, &mut || Ok(()))
            .unwrap()
            .notes
            .len(),
        4096
    );
    let mut calls = 0;
    let result = OsuSource::parse(source, &mut || {
        calls += 1;
        if calls == 100 {
            Err(CoreError::new(ErrorCode::Cancelled, "cancelled"))
        } else {
            Ok(())
        }
    });
    assert_eq!(result.unwrap_err().code(), ErrorCode::Cancelled);
}
