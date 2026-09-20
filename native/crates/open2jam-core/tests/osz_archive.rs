use open2jam_core::{osz::OszArchive, path::SourceRelativePath};

#[test]
fn frozen_osz_reads_nested_charts_and_resolves_legacy_audio_references() {
    let bytes =
        include_bytes!("../../../../rewrite/golden/java-migration/sources/osu/multi-chart.osz");
    let mut archive = OszArchive::open(bytes, &mut || Ok(())).unwrap();
    let names: Vec<_> = archive
        .chart_paths()
        .map(|path| path.as_str().to_owned())
        .collect();
    assert_eq!(names, ["pack/easy.osu", "pack/hard.osu"]);
    let chart = SourceRelativePath::parse("pack/easy.osu").unwrap();
    let audio = archive
        .resolve_audio(&chart, &SourceRelativePath::parse("audio.wav").unwrap())
        .unwrap();
    assert_eq!(audio.as_str(), "pack/audio.wav");
    assert_eq!(&archive.read(&audio, &mut || Ok(())).unwrap()[..4], b"RIFF");
    let bytes = include_bytes!(
        "../../../../rewrite/golden/java-migration/sources/osu/case-insensitive.osz"
    );
    let archive = OszArchive::open(bytes, &mut || Ok(())).unwrap();
    let chart = SourceRelativePath::parse("nested/seven-key.osu").unwrap();
    assert_eq!(
        archive
            .resolve_audio(&chart, &SourceRelativePath::parse("AUDIO.WAV").unwrap())
            .unwrap()
            .as_str(),
        "assets/audio.wav"
    );
}

fn archive_bytes(entries: &[(&str, &[u8])]) -> Vec<u8> {
    use std::io::{Cursor, Write};
    let mut writer = zip::ZipWriter::new(Cursor::new(Vec::new()));
    for (name, bytes) in entries {
        writer
            .start_file(
                *name,
                zip::write::SimpleFileOptions::default()
                    .compression_method(zip::CompressionMethod::Stored),
            )
            .unwrap();
        writer.write_all(bytes).unwrap();
    }
    writer.finish().unwrap().into_inner()
}

#[test]
fn osz_audio_lookup_preserves_precedence_and_rejects_ambiguous_fallback() {
    let bytes = archive_bytes(&[
        ("audio.wav", b"root"),
        ("set/audio.wav", b"relative"),
        ("other/AUDIO.WAV", b"fallback"),
    ]);
    let archive = OszArchive::open(&bytes, &mut || Ok(())).unwrap();
    let chart = SourceRelativePath::parse("set/chart.osu").unwrap();
    assert_eq!(
        archive
            .resolve_audio(&chart, &SourceRelativePath::parse("audio.wav").unwrap())
            .unwrap()
            .as_str(),
        "audio.wav"
    );
    assert!(
        archive
            .resolve_audio(&chart, &SourceRelativePath::parse("Audio.Wav").unwrap())
            .is_err()
    );
    assert!(
        archive
            .resolve_audio(&chart, &SourceRelativePath::parse("missing.wav").unwrap())
            .is_err()
    );
}

#[test]
fn osz_rejects_unsafe_names_links_duplicate_entries_and_directory_limits() {
    for name in [
        "../song.osu",
        "/song.osu",
        "C:/song.osu",
        "set/../song.osu",
        "set\\song.osu",
    ] {
        let bytes = archive_bytes(&[(name, b"chart")]);
        assert!(OszArchive::open(&bytes, &mut || Ok(())).is_err(), "{name}");
    }
    let mut writer = zip::ZipWriter::new(std::io::Cursor::new(Vec::new()));
    writer
        .add_symlink(
            "link.wav",
            "outside.wav",
            zip::write::SimpleFileOptions::default(),
        )
        .unwrap();
    let bytes = writer.finish().unwrap().into_inner();
    assert!(OszArchive::open(&bytes, &mut || Ok(())).is_err());
    let mut duplicate = archive_bytes(&[("a.osu", b"a"), ("b.osu", b"b")]);
    for at in 0..duplicate.len() - 5 {
        if &duplicate[at..at + 5] == b"b.osu" {
            duplicate[at] = b'a';
        }
    }
    assert!(OszArchive::open(&duplicate, &mut || Ok(())).is_err());
    let mut excessive = archive_bytes(&[("a.osu", b"a")]);
    let end = excessive.len() - 22;
    for offset in [8, 10] {
        excessive[end + offset..end + offset + 2].copy_from_slice(&8193_u16.to_le_bytes());
    }
    assert!(OszArchive::open(&excessive, &mut || Ok(())).is_err());
}

#[test]
fn osz_reads_validate_crc_and_honor_mid_read_cancellation() {
    use open2jam_core::error::{CoreError, ErrorCode};
    let path = SourceRelativePath::parse("audio.wav").unwrap();
    let mut bytes = archive_bytes(&[("audio.wav", b"unique-payload")]);
    let at = bytes
        .windows(14)
        .position(|window| window == b"unique-payload")
        .unwrap();
    bytes[at] ^= 1;
    let mut archive = OszArchive::open(&bytes, &mut || Ok(())).unwrap();
    assert_eq!(
        archive.read(&path, &mut || Ok(())).unwrap_err().code(),
        ErrorCode::CorruptChart
    );
    let bytes = archive_bytes(&[("audio.wav", &vec![0; 131072])]);
    let mut archive = OszArchive::open(&bytes, &mut || Ok(())).unwrap();
    let mut calls = 0;
    let error = archive
        .read(&path, &mut || {
            calls += 1;
            if calls == 3 {
                Err(CoreError::new(ErrorCode::Cancelled, "test cancellation"))
            } else {
                Ok(())
            }
        })
        .unwrap_err();
    assert_eq!(error.code(), ErrorCode::Cancelled);
}

#[test]
fn truncated_and_forged_zip64_records_do_not_panic() {
    let bytes = archive_bytes(&[("a.osu", b"chart")]);
    for end in 0..bytes.len() {
        assert!(OszArchive::open(&bytes[..end], &mut || Ok(())).is_err());
    }
    let mut bytes = vec![0; 42];
    bytes[..4].copy_from_slice(b"PK\x06\x07");
    bytes[16..20].copy_from_slice(&1_u32.to_le_bytes());
    bytes[20..24].copy_from_slice(b"PK\x05\x06");
    bytes[28..32].fill(255);
    assert!(OszArchive::open(&bytes, &mut || Ok(())).is_err());
}

#[test]
fn osz_does_not_fall_back_to_an_earlier_unchecked_central_directory() {
    let mut bytes = archive_bytes(&[("old.osu", b"old chart")]);
    let directory_start = bytes.len() as u32;
    bytes.extend([0; 46]);
    let mut end = vec![0; 22];
    end[..4].copy_from_slice(b"PK\x05\x06");
    end[8..10].copy_from_slice(&1_u16.to_le_bytes());
    end[10..12].copy_from_slice(&1_u16.to_le_bytes());
    end[12..16].copy_from_slice(&46_u32.to_le_bytes());
    end[16..20].copy_from_slice(&directory_start.to_le_bytes());
    bytes.extend(end);
    assert!(OszArchive::open(&bytes, &mut || Ok(())).is_err());
}

fn zip64_footer(mut bytes: Vec<u8>) -> Vec<u8> {
    let end = bytes.len() - 22;
    let mut footer = bytes.split_off(end);
    let count = u16::from_le_bytes(footer[10..12].try_into().unwrap()) as u64;
    let size = u32::from_le_bytes(footer[12..16].try_into().unwrap()) as u64;
    let start = u32::from_le_bytes(footer[16..20].try_into().unwrap()) as u64;
    let mut record = vec![0; 56];
    record[..4].copy_from_slice(b"PK\x06\x06");
    record[4..12].copy_from_slice(&44_u64.to_le_bytes());
    record[12..14].copy_from_slice(&45_u16.to_le_bytes());
    record[14..16].copy_from_slice(&45_u16.to_le_bytes());
    record[24..32].copy_from_slice(&count.to_le_bytes());
    record[32..40].copy_from_slice(&count.to_le_bytes());
    record[40..48].copy_from_slice(&size.to_le_bytes());
    record[48..56].copy_from_slice(&start.to_le_bytes());
    bytes.extend(record);
    let mut locator = vec![0; 20];
    locator[..4].copy_from_slice(b"PK\x06\x07");
    locator[8..16].copy_from_slice(&(end as u64).to_le_bytes());
    locator[16..20].copy_from_slice(&1_u32.to_le_bytes());
    bytes.extend(locator);
    footer[8..20].fill(255);
    bytes.extend(footer);
    bytes
}

#[test]
fn bounded_zip64_archive_reads_and_rejects_oversized_directory_claims() {
    let bytes = zip64_footer(archive_bytes(&[("chart.osu", b"chart")]));
    let mut archive = OszArchive::open(&bytes, &mut || Ok(())).unwrap();
    assert_eq!(
        archive
            .read(
                &SourceRelativePath::parse("chart.osu").unwrap(),
                &mut || Ok(())
            )
            .unwrap(),
        b"chart"
    );
    let mut excessive = bytes.clone();
    let record = excessive.len() - 22 - 20 - 56;
    for offset in [24, 32] {
        excessive[record + offset..record + offset + 8].copy_from_slice(&8193_u64.to_le_bytes());
    }
    assert!(OszArchive::open(&excessive, &mut || Ok(())).is_err());
}

#[test]
fn osz_rejects_entry_size_ratio_and_encryption_before_decompression() {
    let original = archive_bytes(&[("chart.osu", b"chart")]);
    let central = original
        .windows(4)
        .position(|window| window == b"PK\x01\x02")
        .unwrap();
    for mutation in ["size", "ratio", "encrypted", "compression"] {
        let mut bytes = original.clone();
        match mutation {
            "size" => bytes[central + 24..central + 28]
                .copy_from_slice(&(64_u32 * 1024 * 1024 + 1).to_le_bytes()),
            "ratio" => bytes[central + 24..central + 28].copy_from_slice(&5001_u32.to_le_bytes()),
            "encrypted" => bytes[central + 8] |= 1,
            "compression" => {
                bytes[central + 10..central + 12].copy_from_slice(&99_u16.to_le_bytes())
            }
            _ => unreachable!(),
        }
        assert!(
            OszArchive::open(&bytes, &mut || Ok(())).is_err(),
            "{mutation}"
        );
    }
}
