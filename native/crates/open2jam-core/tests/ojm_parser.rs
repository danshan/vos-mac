use open2jam_core::error::{CoreError, ErrorCode};
use open2jam_core::ojm::{OjmSampleData, parse_plain_ojm};

const PLAIN: &[u8] =
    include_bytes!("../../../../rewrite/golden/java-migration/sources/ojn/minimal.ojm");

#[test]
fn plain_ojm_preserves_frozen_pcm_without_decoding_or_copying_it() {
    let samples = parse_plain_ojm(PLAIN, &mut || Ok(())).unwrap();
    assert_eq!(samples.len(), 1);
    assert_eq!(samples[0].index, 0);
    match samples[0].data {
        OjmSampleData::Wave {
            format,
            channels,
            sample_rate,
            byte_rate,
            block_align,
            bits_per_sample,
            pcm,
        } => {
            assert_eq!(
                (
                    format,
                    channels,
                    sample_rate,
                    byte_rate,
                    block_align,
                    bits_per_sample
                ),
                (1, 1, 8000, 16000, 2, 16)
            );
            assert_eq!(
                pcm,
                &[
                    3, 10, 17, 24, 31, 38, 45, 52, 59, 66, 73, 80, 87, 94, 101, 108, 115, 122, 129,
                    136, 143, 150, 157, 164, 171, 178, 185, 192, 199, 206, 213, 220, 227, 234
                ]
            );
        }
        OjmSampleData::Ogg(_) => panic!("expected PCM sample"),
    }
}

#[test]
fn empty_slots_and_ogg_bank_keep_source_sample_indices() {
    let mut bytes = PLAIN[..20].to_vec();
    bytes.extend([0; 56]);
    bytes.extend(&PLAIN[20..]);
    let ogg_start = bytes.len() as u32;
    bytes[12..16].copy_from_slice(&ogg_start.to_le_bytes());
    bytes.extend([0; 36]);
    bytes.extend([0; 32]);
    bytes.extend(4_u32.to_le_bytes());
    bytes.extend(b"OggS");
    let file_size = bytes.len() as u32;
    bytes[16..20].copy_from_slice(&file_size.to_le_bytes());
    let samples = parse_plain_ojm(&bytes, &mut || Ok(())).unwrap();
    assert_eq!(samples.len(), 2);
    assert_eq!(samples[0].index, 1);
    assert_eq!(samples[1].index, 1001);
    assert!(matches!(samples[1].data, OjmSampleData::Ogg(b"OggS")));
}

#[test]
fn corrupt_banks_and_unsupported_variants_are_diagnosed_before_payload_access() {
    for end in 0..PLAIN.len() {
        assert!(
            parse_plain_ojm(&PLAIN[..end], &mut || Ok(())).is_err(),
            "prefix {end}"
        );
    }
    for (offset, value) in [
        (8, 0),
        (12, 19),
        (12, u32::MAX),
        (16, 20),
        (72, u32::MAX),
        (68, 0),
    ] {
        let mut bytes = PLAIN.to_vec();
        bytes[offset..offset + 4].copy_from_slice(&value.to_le_bytes());
        assert_eq!(
            parse_plain_ojm(&bytes, &mut || Ok(())).unwrap_err().code(),
            ErrorCode::CorruptChart,
            "offset {offset}"
        );
    }
    for signature in [b"OMC\0", b"M30\0"] {
        let mut bytes = PLAIN.to_vec();
        bytes[..4].copy_from_slice(signature);
        assert_eq!(
            parse_plain_ojm(&bytes, &mut || Ok(())).unwrap_err().code(),
            ErrorCode::UnsupportedFormat
        );
    }
    assert_eq!(
        parse_plain_ojm(PLAIN, &mut || Err(CoreError::new(
            ErrorCode::Cancelled,
            "cancelled"
        )))
        .unwrap_err()
        .code(),
        ErrorCode::Cancelled
    );
}

#[test]
fn prepared_plain_pcm_matches_the_frozen_java_wav_exactly() {
    let bytes = include_bytes!("../../../../rewrite/golden/java-migration/sources/ojn/o2jam.ojm");
    let expected =
        include_bytes!("../../../../rewrite/golden/java-migration/expected/ojn/audio/sample-1.wav");
    let samples = parse_plain_ojm(bytes, &mut || Ok(())).unwrap();
    let wav = samples[0].data.prepare_wav(&mut || Ok(())).unwrap();
    assert_eq!(wav, expected);
}

#[test]
fn ogg_vorbis_prepares_playable_pcm_with_original_duration_and_channels() {
    let wav = OjmSampleData::Ogg(include_bytes!("fixtures/ojn/tone.ogg"))
        .prepare_wav(&mut || Ok(()))
        .unwrap();
    assert_eq!(&wav[..4], b"RIFF");
    assert_eq!(u16::from_le_bytes(wav[22..24].try_into().unwrap()), 2);
    assert_eq!(u32::from_le_bytes(wav[24..28].try_into().unwrap()), 44100);
    assert_eq!(u16::from_le_bytes(wav[34..36].try_into().unwrap()), 16);
    // The fixture's final Ogg granule is 4416 (the encoder resamples its source).
    assert_eq!(wav.len(), 44 + 4416 * 4);
    assert!(wav[44..].iter().any(|byte| *byte != 0));
    let java_pcm = include_bytes!("fixtures/ojn/tone-java.pcm");
    assert_eq!(wav.len() - 44, java_pcm.len());
    let max_delta = wav[44..]
        .chunks_exact(2)
        .zip(java_pcm.chunks_exact(2))
        .map(|(rust, java)| {
            (i32::from(i16::from_le_bytes(rust.try_into().unwrap()))
                - i32::from(i16::from_le_bytes(java.try_into().unwrap())))
            .abs()
        })
        .max()
        .unwrap();
    assert!(max_delta <= 1, "PCM decoder difference: {max_delta}");
}

#[test]
fn audio_preparation_rejects_truncation_bad_pcm_headers_and_cancellation() {
    let ogg = include_bytes!("fixtures/ojn/tone.ogg");
    for end in [0, 26, ogg.len() - 1, ogg.len() / 2] {
        assert_eq!(
            OjmSampleData::Ogg(&ogg[..end])
                .prepare_wav(&mut || Ok(()))
                .unwrap_err()
                .code(),
            ErrorCode::AudioDecodeFailed
        );
    }
    let mut corrupt = ogg.to_vec();
    let last = corrupt.len() - 1;
    corrupt[last] ^= 1;
    assert!(
        OjmSampleData::Ogg(&corrupt)
            .prepare_wav(&mut || Ok(()))
            .is_err()
    );
    let samples = parse_plain_ojm(PLAIN, &mut || Ok(())).unwrap();
    assert_eq!(
        samples[0]
            .data
            .prepare_wav(&mut || Err(CoreError::new(ErrorCode::Cancelled, "cancelled")))
            .unwrap_err()
            .code(),
        ErrorCode::Cancelled
    );
    for offset in [54, 56, 60, 64, 66] {
        let mut bytes = PLAIN.to_vec();
        bytes[offset] = 0;
        bytes[offset + 1] = 0;
        let samples = parse_plain_ojm(&bytes, &mut || Ok(())).unwrap();
        assert!(
            samples[0].data.prepare_wav(&mut || Ok(())).is_err(),
            "offset {offset}"
        );
    }
}

#[test]
fn ogg_without_a_terminal_page_is_not_published_as_complete_audio() {
    use symphonia::core::{checksum::Crc32, io::Monitor};
    let mut encoded = include_bytes!("fixtures/ojn/tone.ogg").to_vec();
    let mut offset = 0;
    while offset < encoded.len() {
        let segments = usize::from(encoded[offset + 26]);
        let end = offset
            + 27
            + segments
            + encoded[offset + 27..offset + 27 + segments]
                .iter()
                .map(|v| usize::from(*v))
                .sum::<usize>();
        if end == encoded.len() {
            encoded[offset + 5] &= !4;
            encoded[offset + 22..offset + 26].fill(0);
            let mut crc = Crc32::new(0);
            crc.process_buf_bytes(&encoded[offset..end]);
            encoded[offset + 22..offset + 26].copy_from_slice(&crc.crc().to_le_bytes());
        }
        offset = end;
    }
    assert!(
        OjmSampleData::Ogg(&encoded)
            .prepare_wav(&mut || Ok(()))
            .is_err()
    );
}

#[test]
fn ogg_corruption_in_a_middle_page_is_not_silently_skipped() {
    let source = include_bytes!("fixtures/ojn/tone-multipage.ogg");
    let mut checkpoints = 0;
    let error = OjmSampleData::Ogg(source)
        .prepare_wav(&mut || {
            checkpoints += 1;
            if checkpoints == 4 {
                Err(CoreError::new(ErrorCode::Cancelled, "cancelled"))
            } else {
                Ok(())
            }
        })
        .unwrap_err();
    assert_eq!(error.code(), ErrorCode::Cancelled);
    assert!(
        OjmSampleData::Ogg(source)
            .prepare_wav(&mut || Ok(()))
            .is_ok()
    );
    let mut encoded = source.to_vec();
    let mut offset = 0;
    let mut page = 0;
    loop {
        let segments = usize::from(encoded[offset + 26]);
        let body = offset + 27 + segments;
        let end = body
            + encoded[offset + 27..body]
                .iter()
                .map(|v| usize::from(*v))
                .sum::<usize>();
        if page == 2 {
            assert!(end < encoded.len());
            encoded[body] ^= 1;
            break;
        }
        offset = end;
        page += 1;
    }
    assert!(
        OjmSampleData::Ogg(&encoded)
            .prepare_wav(&mut || Ok(()))
            .is_err()
    );
}
