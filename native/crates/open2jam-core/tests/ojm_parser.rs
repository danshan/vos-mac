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
