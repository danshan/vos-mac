use open2jam_core::ojm::{OjmSampleData, parse_m30_in_place};
use sha2::{Digest as _, Sha256};

#[test]
fn m30_masks_and_reference_ids_match_frozen_java_audio() {
    let oracle: serde_json::Value =
        serde_json::from_str(include_str!("fixtures/ojn/m30-java.json")).unwrap();
    let expected_pcm = include_bytes!("fixtures/ojn/tone-java.pcm");
    for encoded in [
        include_bytes!("fixtures/ojn/m30-plain.ojm").as_slice(),
        include_bytes!("fixtures/ojn/m30-nami.ojm").as_slice(),
        include_bytes!("fixtures/ojn/m30-0412.ojm").as_slice(),
    ] {
        let mut bank = encoded.to_vec();
        let mut samples = parse_m30_in_place(&mut bank, &mut || Ok(())).unwrap();
        samples.sort_by_key(|sample| sample.index);
        assert_eq!(samples.len(), 2);
        for (sample, expected) in samples.iter().zip(oracle["samples"].as_array().unwrap()) {
            assert_eq!(sample.index as u64, expected["index"].as_u64().unwrap());
            let OjmSampleData::Ogg(ogg) = sample.data else {
                panic!("expected Vorbis");
            };
            assert_eq!(
                format!("{:x}", Sha256::digest(ogg)),
                expected["sha256"].as_str().unwrap()
            );
            let wav = sample.data.prepare_wav(&mut || Ok(())).unwrap();
            assert_eq!(&wav[44..].len(), &expected_pcm.len());
            for (actual, expected) in wav[44..].chunks_exact(2).zip(expected_pcm.chunks_exact(2)) {
                let actual = i16::from_le_bytes(actual.try_into().unwrap());
                let expected = i16::from_le_bytes(expected.try_into().unwrap());
                assert!((i32::from(actual) - i32::from(expected)).abs() <= 1);
            }
        }
    }
}

#[test]
fn invalid_m30_metadata_is_rejected_before_any_payload_mutation() {
    use open2jam_core::error::ErrorCode;
    let source = include_bytes!("fixtures/ojn/m30-nami.ojm");
    for mutation in [
        "count",
        "offset",
        "size",
        "length",
        "reference",
        "duplicate",
        "flag",
        "codec",
        "trailing",
    ] {
        let mut bank = source.to_vec();
        let mut expected = ErrorCode::CorruptChart;
        match mutation {
            "count" => bank[12..16].copy_from_slice(&u32::MAX.to_le_bytes()),
            "offset" => bank[16..20].copy_from_slice(&29_u32.to_le_bytes()),
            "size" => bank[20..24].copy_from_slice(&0_u32.to_le_bytes()),
            "length" => bank[60..64].copy_from_slice(&u32::MAX.to_le_bytes()),
            "reference" => bank[72..74].copy_from_slice(&(-1_i16).to_le_bytes()),
            "duplicate" => {
                // The first sample becomes the same key-sound reference as the second.
                bank[64..66].copy_from_slice(&5_u16.to_le_bytes());
                bank[72..74].copy_from_slice(&7_u16.to_le_bytes());
            }
            "flag" => {
                bank[8..12].copy_from_slice(&1_u32.to_le_bytes());
                expected = ErrorCode::UnsupportedFormat;
            }
            "codec" => {
                bank[64..66].copy_from_slice(&9_u16.to_le_bytes());
                expected = ErrorCode::UnsupportedFormat;
            }
            "trailing" => bank[12..16].copy_from_slice(&1_u32.to_le_bytes()),
            _ => unreachable!(),
        }
        let before = bank.clone();
        assert_eq!(
            parse_m30_in_place(&mut bank, &mut || Ok(()))
                .unwrap_err()
                .code(),
            expected,
            "{mutation}"
        );
        assert_eq!(bank, before, "{mutation}");
    }
    for end in [0, 4, 27, 79, source.len() - 1] {
        let mut bank = source[..end].to_vec();
        assert_eq!(
            parse_m30_in_place(&mut bank, &mut || Ok(()))
                .unwrap_err()
                .code(),
            ErrorCode::CorruptChart
        );
    }
}

#[test]
fn m30_preserves_partial_xor_groups_and_can_cancel_between_samples() {
    use open2jam_core::error::{CoreError, ErrorCode};
    let source = include_bytes!("fixtures/ojn/m30-nami.ojm");
    let mut bank = source[..80].to_vec();
    bank.extend([0, 1, 2, 3, 4, 5, 6]);
    bank[12..16].copy_from_slice(&1_u32.to_le_bytes());
    bank[20..24].copy_from_slice(&59_u32.to_le_bytes());
    bank[60..64].copy_from_slice(&7_u32.to_le_bytes());
    let samples = parse_m30_in_place(&mut bank, &mut || Ok(())).unwrap();
    let OjmSampleData::Ogg(bytes) = samples[0].data else {
        panic!("expected Ogg");
    };
    assert_eq!(bytes, &[0x6e, 0x60, 0x6f, 0x6a, 4, 5, 6]);
    let mut bank = source.to_vec();
    let mut calls = 0;
    let error = parse_m30_in_place(&mut bank, &mut || {
        calls += 1;
        if calls == 5 {
            Err(CoreError::new(ErrorCode::Cancelled, "cancelled"))
        } else {
            Ok(())
        }
    })
    .unwrap_err();
    assert_eq!(error.code(), ErrorCode::Cancelled);
}

#[test]
fn original_metadata_fixtures_parse_but_their_stub_audio_is_not_playable() {
    for encoded in [
        include_bytes!("../../../../rewrite/golden/java-migration/sources/ojn/m30-nami.ojm")
            .as_slice(),
        include_bytes!("../../../../rewrite/golden/java-migration/sources/ojn/m30-0412.ojm")
            .as_slice(),
    ] {
        let mut bank = encoded.to_vec();
        let samples = parse_m30_in_place(&mut bank, &mut || Ok(())).unwrap();
        assert_eq!(samples.len(), 1);
        assert_eq!(samples[0].index, 1);
        assert_eq!(
            samples[0]
                .data
                .prepare_wav(&mut || Ok(()))
                .unwrap_err()
                .code(),
            open2jam_core::error::ErrorCode::AudioDecodeFailed
        );
    }
}
