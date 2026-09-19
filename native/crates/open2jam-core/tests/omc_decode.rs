use open2jam_core::error::{CoreError, ErrorCode};
use open2jam_core::ojm::{OjmSampleData, decode_omc_in_place, parse_plain_ojm};

#[test]
fn omc_reordering_and_cross_sample_xor_match_the_frozen_java_decoder() {
    let mut bank = include_bytes!("fixtures/ojn/omc-multisample.ojm").to_vec();
    let oracle: serde_json::Value =
        serde_json::from_str(include_str!("fixtures/ojn/omc-multisample-java.json")).unwrap();
    decode_omc_in_place(&mut bank, &mut || Ok(())).unwrap();
    let samples = parse_plain_ojm(&bank, &mut || Ok(())).unwrap();
    assert_eq!(samples.len(), oracle["samples"].as_array().unwrap().len());
    for (sample, expected) in samples.iter().zip(oracle["samples"].as_array().unwrap()) {
        assert_eq!(sample.index as u64, expected["index"].as_u64().unwrap());
        let OjmSampleData::Wave { pcm, .. } = sample.data else {
            panic!("expected wave sample");
        };
        assert_eq!(hex(pcm), expected["rawHex"].as_str().unwrap());
        let wav = sample.data.prepare_wav(&mut || Ok(())).unwrap();
        assert_eq!(hex(&wav[44..]), expected["pcm16Hex"].as_str().unwrap());
    }
}

fn hex(bytes: &[u8]) -> String {
    bytes.iter().map(|byte| format!("{byte:02x}")).collect()
}

#[test]
fn original_omc_fixture_matches_java_and_ogg_payloads_remain_unchanged() {
    let mut bank =
        include_bytes!("../../../../rewrite/golden/java-migration/sources/ojn/omc.ojm").to_vec();
    let mut header = [0_u8; 36];
    header[32..].copy_from_slice(&5_u32.to_le_bytes());
    bank.extend(header);
    bank.extend(b"OggS!");
    let size = bank.len() as u32;
    bank[16..20].copy_from_slice(&size.to_le_bytes());
    decode_omc_in_place(&mut bank, &mut || Ok(())).unwrap();
    let samples = parse_plain_ojm(&bank, &mut || Ok(())).unwrap();
    let expected: serde_json::Value =
        serde_json::from_str(include_str!("fixtures/ojn/omc-frozen-java.json")).unwrap();
    let wav = samples[0].data.prepare_wav(&mut || Ok(())).unwrap();
    assert_eq!(
        hex(&wav[44..]),
        expected["samples"][0]["pcm16Hex"].as_str().unwrap()
    );
    assert_eq!(samples[1].index, 1000);
    let OjmSampleData::Ogg(ogg) = samples[1].data else {
        panic!("expected Ogg");
    };
    assert_eq!(ogg, b"OggS!");
}

#[test]
fn malformed_omc_is_rejected_before_mutation_and_decoding_can_be_cancelled() {
    let source = include_bytes!("fixtures/ojn/omc-multisample.ojm");
    for end in [0, 4, 19, 25, source.len() - 1] {
        let mut bank = source[..end].to_vec();
        let before = bank.clone();
        assert_eq!(
            decode_omc_in_place(&mut bank, &mut || Ok(()))
                .unwrap_err()
                .code(),
            ErrorCode::CorruptChart
        );
        assert_eq!(bank, before);
    }
    let mut bank = source.to_vec();
    // A late corrupt payload must be rejected before earlier samples are transformed.
    bank.extend([0_u8; 4]);
    let size = bank.len() as u32;
    bank[16..20].copy_from_slice(&size.to_le_bytes());
    let before = bank.clone();
    assert_eq!(
        decode_omc_in_place(&mut bank, &mut || Ok(()))
            .unwrap_err()
            .code(),
        ErrorCode::CorruptChart
    );
    assert_eq!(bank, before);
    let mut bank = include_bytes!("../../../../rewrite/golden/java-migration/sources/ojn/omc.ojm")
        [..76]
        .to_vec();
    bank.extend(vec![0x55; 131072]);
    let size = bank.len() as u32;
    bank[12..16].copy_from_slice(&size.to_le_bytes());
    bank[16..20].copy_from_slice(&size.to_le_bytes());
    bank[72..76].copy_from_slice(&131072_u32.to_le_bytes());
    let mut checks = 0;
    let error = decode_omc_in_place(&mut bank, &mut || {
        checks += 1;
        if checks == 10 {
            Err(CoreError::new(ErrorCode::Cancelled, "cancelled"))
        } else {
            Ok(())
        }
    })
    .unwrap_err();
    assert_eq!(error.code(), ErrorCode::Cancelled);
    assert_eq!(&bank[..4], b"OMC\0");
}
