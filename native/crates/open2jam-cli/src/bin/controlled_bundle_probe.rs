#![forbid(unsafe_code)]

use open2jam_core::{
    audio::{AudioAsset, AudioManifestV2},
    bundle::{
        BundleFile, BundleIdentity, BundleManifestV2, SoundFontIdentity, load_bundle_documents,
    },
    canonical::CanonicalHasher,
    digest::Digest,
    format::Format,
    gameplay::GameplayChartV2,
    id::{ChartIdentity, LibraryRootId, SongIdentity, SourceFingerprint, derive_sample_id},
    json::encode_contract,
    path::{BundleRelativePath, SourceRelativePath},
    schema::STATIC_ASSETS_VERSION,
};
use sha2::{Digest as _, Sha256};
use std::{fs, io::Write, path::PathBuf};

const RECIPE: &[u8] = include_bytes!("../../fixtures/controlled-gameplay.json");

fn digest(bytes: &[u8]) -> Digest {
    Digest::from_bytes(Sha256::digest(bytes).into())
}

fn tone_wav() -> Vec<u8> {
    let mut bytes = Vec::with_capacity(44 + 11025 * 4);
    bytes.extend_from_slice(b"RIFF");
    bytes.extend_from_slice(&44136_u32.to_le_bytes());
    bytes.extend_from_slice(b"WAVEfmt ");
    bytes.extend_from_slice(&16_u32.to_le_bytes());
    bytes.extend_from_slice(&1_u16.to_le_bytes());
    bytes.extend_from_slice(&2_u16.to_le_bytes());
    bytes.extend_from_slice(&44100_u32.to_le_bytes());
    bytes.extend_from_slice(&176400_u32.to_le_bytes());
    bytes.extend_from_slice(&4_u16.to_le_bytes());
    bytes.extend_from_slice(&16_u16.to_le_bytes());
    bytes.extend_from_slice(b"data");
    bytes.extend_from_slice(&44100_u32.to_le_bytes());
    for frame in 0..11025 {
        let phase = frame % 100;
        let sample: i16 = if phase < 50 {
            -2048 + phase * 4096 / 50
        } else {
            2048 - (phase - 50) * 4096 / 50
        } as i16;
        bytes.extend_from_slice(&sample.to_le_bytes());
        bytes.extend_from_slice(&sample.to_le_bytes());
    }
    bytes
}

fn run() -> Result<(), Box<dyn std::error::Error>> {
    let args: Vec<_> = std::env::args_os().skip(1).collect();
    if args.len() != 1 {
        return Err("usage: controlled-bundle-probe NEW_OUTPUT_DIRECTORY".into());
    }
    let output = PathBuf::from(&args[0]);
    let wave = tone_wav();
    let root_id = LibraryRootId::from_digest(digest(b"open2jam controlled library v1"));
    let song =
        SongIdentity::ojn_file(root_id, SourceRelativePath::parse("controlled.ojn")?).song_id();
    let identity = ChartIdentity::ojn(0)?;
    let chart_id = identity.chart_id(&song);
    let sample = derive_sample_id(&digest(&wave));
    let mut recipe: serde_json::Value = serde_json::from_slice(RECIPE)?;
    recipe["songId"] = serde_json::to_value(song)?;
    recipe["chartId"] = serde_json::to_value(chart_id)?;
    recipe["samples"] = serde_json::json!([sample]);
    for field in ["notes", "autoPlayEvents"] {
        for event in recipe[field]
            .as_array_mut()
            .ok_or("fixture events missing")?
        {
            event["sampleId"] = serde_json::to_value(sample)?;
        }
    }
    let chart: GameplayChartV2 = serde_json::from_value(recipe)?;
    let audio = AudioManifestV2::new(
        song,
        chart_id,
        Format::O2Jam,
        vec![AudioAsset::new(
            sample,
            BundleRelativePath::parse("audio/tone.wav")?,
        )?],
    )?;
    let mut source = CanonicalHasher::new(b"open2jam.source-fingerprint.v1\0");
    source.write_u16(1);
    source.write_u32(2);
    for (role, bytes) in [(1, RECIPE), (3, wave.as_slice())] {
        source.write_u16(role);
        source.write_u32(0);
        source.write_u64(bytes.len() as u64);
        source.write_bytes(digest(bytes).as_bytes());
    }
    let artifacts = [
        ("audio-manifest.json", encode_contract(&audio)?),
        ("audio/tone.wav", wave),
        ("gameplay.json", encode_contract(&chart)?),
    ];
    let files = artifacts
        .iter()
        .map(|(name, bytes)| {
            Ok(BundleFile::from_bytes(
                BundleRelativePath::parse(name)?,
                bytes,
            ))
        })
        .collect::<Result<Vec<_>, open2jam_core::error::CoreError>>()?;
    let manifest = BundleManifestV2::new(
        BundleIdentity {
            converter_version: env!("CARGO_PKG_VERSION").into(),
            static_assets_version: STATIC_ASSETS_VERSION.into(),
            soundfont: SoundFontIdentity {
                version: "2.0.3".into(),
                sha256: Digest::parse(
                    "sha256:9575028c7a1f589f5770fccc8cff2734566af40cd26ed836944e9a5152688cfe",
                )?,
            },
            song_id: song,
            chart_id,
            chart_selector: identity.selector(),
            source_fingerprint: SourceFingerprint::from_digest(source.finish()),
        },
        files,
    )?;
    // This development fixture writer reserves a new directory; it is not the production stager.
    fs::create_dir(&output)?;
    fs::create_dir(output.join("audio"))?;
    for (name, bytes) in artifacts {
        fs::write(output.join(name), bytes)?;
    }
    fs::write(output.join("bundle.json"), encode_contract(&manifest)?)?;
    load_bundle_documents(&output, Some(manifest.bundle_key()))?;
    writeln!(
        std::io::stdout().lock(),
        "{}",
        serde_json::json!({"bundleKey":manifest.bundle_key(),"output":output.canonicalize()?})
    )?;
    Ok(())
}
fn main() {
    if let Err(error) = run() {
        eprintln!("{error}");
        std::process::exit(1);
    }
}
