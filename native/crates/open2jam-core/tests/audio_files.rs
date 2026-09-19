use open2jam_core::audio::{AudioFileFormat, prepare_audio_file};
use open2jam_core::error::{CoreError, ErrorCode};

#[test]
fn mp3_audio_preserves_the_frozen_java_pcm_timeline() {
    for (encoded, expected, rate, channels) in [
        (
            include_bytes!("fixtures/osu/tone.mp3").as_slice(),
            include_bytes!("fixtures/osu/tone-mp3-java.pcm").as_slice(),
            44100,
            2,
        ),
        (
            include_bytes!("fixtures/osu/tone-xing.mp3").as_slice(),
            include_bytes!("fixtures/osu/tone-xing-java.pcm").as_slice(),
            44100,
            2,
        ),
        (
            include_bytes!("fixtures/osu/mono-22050.mp3").as_slice(),
            include_bytes!("fixtures/osu/mono-22050-java.pcm").as_slice(),
            22050,
            1,
        ),
        (
            include_bytes!("fixtures/osu/mono-11025.mp3").as_slice(),
            include_bytes!("fixtures/osu/mono-11025-java.pcm").as_slice(),
            11025,
            1,
        ),
    ] {
        let wav = prepare_audio_file(encoded, AudioFileFormat::Mp3, &mut || Ok(())).unwrap();
        assert_eq!(&wav[..4], b"RIFF");
        assert_eq!(u32::from_le_bytes(wav[24..28].try_into().unwrap()), rate);
        assert_eq!(
            u16::from_le_bytes(wav[22..24].try_into().unwrap()),
            channels
        );
        assert_eq!(wav.len() - 44, expected.len());
        let mut maximum_error = 0;
        let mut squared_error = 0_u64;
        for (actual, expected) in wav[44..].chunks_exact(2).zip(expected.chunks_exact(2)) {
            let actual = i16::from_le_bytes(actual.try_into().unwrap());
            let expected = i16::from_le_bytes(expected.try_into().unwrap());
            let error = (i32::from(actual) - i32::from(expected)).abs();
            maximum_error = maximum_error.max(error);
            squared_error += u64::from(error.unsigned_abs()).pow(2);
        }
        assert!(maximum_error <= 32, "maximum PCM error: {maximum_error}");
        let mean_square = squared_error as f64 / (expected.len() / 2) as f64;
        assert!(
            mean_square <= 16.0 * 16.0,
            "PCM mean square error: {mean_square}"
        );
    }
}

#[test]
fn wave_chunks_are_bounded_and_unknown_padded_metadata_is_skipped() {
    let original =
        include_bytes!("../../../../rewrite/golden/java-migration/sources/osu/audio.wav");
    let mut tagged = original.to_vec();
    tagged.splice(12..12, [b'J', b'U', b'N', b'K', 1, 0, 0, 0, 42, 0]);
    let size = (tagged.len() - 8) as u32;
    tagged[4..8].copy_from_slice(&size.to_le_bytes());
    let expected = prepare_audio_file(original, AudioFileFormat::Wave, &mut || Ok(())).unwrap();
    assert_eq!(
        prepare_audio_file(&tagged, AudioFileFormat::Wave, &mut || Ok(())).unwrap(),
        expected
    );
    for mutation in [
        "riff-size",
        "chunk-size",
        "duplicate-format",
        "missing-format",
        "encoding",
        "truncated",
    ] {
        let mut input = original.to_vec();
        match mutation {
            "riff-size" => input[4..8].copy_from_slice(&u32::MAX.to_le_bytes()),
            "chunk-size" => input[16..20].copy_from_slice(&u32::MAX.to_le_bytes()),
            "duplicate-format" => {
                let format = input[12..36].to_vec();
                input.extend(format);
                let size = (input.len() - 8) as u32;
                input[4..8].copy_from_slice(&size.to_le_bytes());
            }
            "missing-format" => input[12..16].copy_from_slice(b"JUNK"),
            "encoding" => input[20..22].copy_from_slice(&999_u16.to_le_bytes()),
            _ => {
                input.pop();
            }
        }
        assert_eq!(
            prepare_audio_file(&input, AudioFileFormat::Wave, &mut || Ok(()))
                .unwrap_err()
                .code(),
            ErrorCode::AudioDecodeFailed,
            "{mutation}"
        );
    }
}

#[test]
fn mp3_tags_do_not_shift_audio_and_truncated_frames_are_not_silently_dropped() {
    let original = include_bytes!("fixtures/osu/tone.mp3");
    let expected = prepare_audio_file(original, AudioFileFormat::Mp3, &mut || Ok(())).unwrap();
    let mut tagged = b"ID3\x04\0\x10\0\0\0\0".to_vec();
    tagged.extend(b"3DI\x04\0\x10\0\0\0\0");
    tagged.extend(original);
    let tag = tagged.len();
    tagged.resize(tag + 128, 0);
    tagged[tag..tag + 3].copy_from_slice(b"TAG");
    assert_eq!(
        prepare_audio_file(&tagged, AudioFileFormat::Mp3, &mut || Ok(())).unwrap(),
        expected
    );
    for input in [
        original[..original.len() - 1].to_vec(),
        [original.as_slice(), &[0xff, 0xfb]].concat(),
        [b"ID3\x04\0\0\x7f\x7f\x7f\x7f".as_slice(), original].concat(),
    ] {
        assert_eq!(
            prepare_audio_file(&input, AudioFileFormat::Mp3, &mut || Ok(()))
                .unwrap_err()
                .code(),
            ErrorCode::AudioDecodeFailed
        );
    }
}

#[test]
fn compressed_formats_are_checked_and_decoding_is_cancellable() {
    let ogg = include_bytes!("fixtures/ojn/tone.ogg");
    let wave = prepare_audio_file(ogg, AudioFileFormat::Ogg, &mut || Ok(())).unwrap();
    let expected = include_bytes!("fixtures/ojn/tone-java.pcm");
    assert_eq!(wave.len() - 44, expected.len());
    assert!(
        wave[44..]
            .chunks_exact(2)
            .zip(expected.chunks_exact(2))
            .all(|(a, b)| {
                (i32::from(i16::from_le_bytes(a.try_into().unwrap()))
                    - i32::from(i16::from_le_bytes(b.try_into().unwrap())))
                .abs()
                    <= 1
            })
    );
    assert_eq!(
        prepare_audio_file(
            include_bytes!("fixtures/osu/tone.mp3"),
            AudioFileFormat::Ogg,
            &mut || Ok(())
        )
        .unwrap_err()
        .code(),
        ErrorCode::AudioDecodeFailed
    );
    let mut calls = 0;
    let error = prepare_audio_file(
        include_bytes!("fixtures/osu/tone-xing.mp3"),
        AudioFileFormat::Mp3,
        &mut || {
            calls += 1;
            if calls == 6 {
                Err(CoreError::new(ErrorCode::Cancelled, "cancelled"))
            } else {
                Ok(())
            }
        },
    )
    .unwrap_err();
    assert_eq!(error.code(), ErrorCode::Cancelled);
}

#[test]
fn wave_file_audio_matches_the_existing_java_bundle_pcm() {
    let source = include_bytes!("../../../../rewrite/golden/java-migration/sources/osu/audio.wav");
    let expected =
        include_bytes!("../../../../rewrite/golden/java-migration/expected/osu/audio/sample-1.wav");
    let wav = prepare_audio_file(source, AudioFileFormat::Wave, &mut || Ok(())).unwrap();
    assert_eq!(wav.as_slice(), expected);
}
