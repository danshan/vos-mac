use open2jam_core::{
    audio::{AudioAsset, AudioManifestV2},
    bundle::{
        BundleFile, BundleIdentity, BundleManifestV2, SoundFontIdentity, load_bundle_documents,
    },
    digest::Digest,
    format::Format,
    gameplay::{
        GameplayChartInput, GameplayChartV2, Note, Ratio, SoundSettings, TimeMicros, TimingPoint,
    },
    id::{ChartIdentity, SongId, SourceFingerprint, derive_sample_id},
    json::encode_contract,
    path::BundleRelativePath,
    schema::STATIC_ASSETS_VERSION,
};
use std::{
    fs,
    path::PathBuf,
    sync::atomic::{AtomicU64, Ordering},
};

static NEXT: AtomicU64 = AtomicU64::new(0);
struct Fixture {
    root: PathBuf,
    manifest: BundleManifestV2,
}
impl Fixture {
    fn new() -> Self {
        let root = std::env::temp_dir().join(format!(
            "bundle-documents-{}-{}",
            std::process::id(),
            NEXT.fetch_add(1, Ordering::Relaxed)
        ));
        fs::create_dir(&root).unwrap();
        let song = SongId::from_digest(Digest::from_bytes([1; 32]));
        let identity = ChartIdentity::ojn(0).unwrap();
        let chart_id = identity.chart_id(&song);
        let audio_bytes = b"RIFF transport fixture, not an audio decode proof";
        let audio_file = BundleFile::from_bytes(
            BundleRelativePath::parse("sample.wav").unwrap(),
            audio_bytes,
        );
        let sample = derive_sample_id(&audio_file.sha256);
        let time = |value| TimeMicros::new(value).unwrap();
        let ratio = |n, d| Ratio::new(n, d).unwrap();
        let timing = TimingPoint::new(time(0), ratio(120, 1), 0).unwrap();
        let chart = GameplayChartV2::new(GameplayChartInput {
            song_id: song,
            chart_id,
            format: Format::O2Jam,
            keys: 7,
            title: "Controlled".into(),
            artist: "Fixture".into(),
            duration_us: time(1_000_125),
            samples: vec![sample],
            notes: vec![
                Note::new(
                    0,
                    time(1_000_125),
                    0,
                    1,
                    Some(sample),
                    SoundSettings::new(ratio(15, 16), ratio(-7, 8)).unwrap(),
                    None,
                )
                .unwrap(),
            ],
            measures: vec![time(0)],
            judgment_timing: vec![timing.clone()],
            visual_timing: vec![timing],
            scroll: vec![],
            auto_play_events: vec![],
        })
        .unwrap();
        let audio = AudioManifestV2::new(
            song,
            chart_id,
            Format::O2Jam,
            vec![AudioAsset::new(sample, audio_file.path.clone()).unwrap()],
        )
        .unwrap();
        let mut files = Vec::new();
        for (path, bytes) in [
            ("audio-manifest.json", encode_contract(&audio).unwrap()),
            ("gameplay.json", encode_contract(&chart).unwrap()),
            ("sample.wav", audio_bytes.to_vec()),
        ] {
            fs::write(root.join(path), &bytes).unwrap();
            files.push(BundleFile::from_bytes(
                BundleRelativePath::parse(path).unwrap(),
                &bytes,
            ));
        }
        let manifest = BundleManifestV2::new(
            BundleIdentity {
                converter_version: "0.1.0".into(),
                static_assets_version: STATIC_ASSETS_VERSION.into(),
                soundfont: SoundFontIdentity {
                    version: "2.0.3".into(),
                    sha256: Digest::from_bytes([2; 32]),
                },
                song_id: song,
                chart_id,
                chart_selector: identity.selector(),
                source_fingerprint: SourceFingerprint::from_digest(Digest::from_bytes([3; 32])),
            },
            files,
        )
        .unwrap();
        fs::write(
            root.join("bundle.json"),
            encode_contract(&manifest).unwrap(),
        )
        .unwrap();
        Self { root, manifest }
    }
}
impl Drop for Fixture {
    fn drop(&mut self) {
        fs::remove_dir_all(&self.root).unwrap();
    }
}

#[test]
fn bundle_documents_agree_on_identity_samples_and_resources() {
    let fixture = Fixture::new();
    let documents =
        load_bundle_documents(&fixture.root, Some(fixture.manifest.bundle_key())).unwrap();
    assert_eq!(documents.chart().chart_id(), *fixture.manifest.chart_id());
    assert_eq!(documents.audio().assets().len(), 1);
    assert_eq!(
        documents.chart().notes()[0].volume(),
        Ratio::new(15, 16).unwrap()
    );
}

impl Fixture {
    fn rewrite_document(&self, name: &str, edit: impl FnOnce(&mut serde_json::Value)) {
        let mut document: serde_json::Value =
            serde_json::from_slice(&fs::read(self.root.join(name)).unwrap()).unwrap();
        edit(&mut document);
        self.replace_file(name, &serde_json::to_vec(&document).unwrap());
    }
    fn replace_file(&self, name: &str, bytes: &[u8]) {
        fs::write(self.root.join(name), bytes).unwrap();
        let mut manifest: serde_json::Value =
            serde_json::from_slice(&fs::read(self.root.join("bundle.json")).unwrap()).unwrap();
        let replacement = BundleFile::from_bytes(BundleRelativePath::parse(name).unwrap(), bytes);
        for file in manifest["files"].as_array_mut().unwrap() {
            if file["path"] == name {
                *file = serde_json::to_value(&replacement).unwrap();
            }
        }
        fs::write(
            self.root.join("bundle.json"),
            serde_json::to_vec(&manifest).unwrap(),
        )
        .unwrap();
        open2jam_core::bundle::verify_bundle(&self.root, None).unwrap();
    }
}

#[test]
fn valid_individual_files_cannot_hide_cross_document_conflicts() {
    for case in [
        "song",
        "chart",
        "audio-song",
        "audio-chart",
        "format",
        "selector-format",
        "sample-set",
        "missing-path",
        "content-id",
    ] {
        let fixture = Fixture::new();
        match case {
            "song" | "chart" => fixture.rewrite_document("gameplay.json", |value| {
                let (field, prefix) = if case == "song" {
                    ("songId", "song")
                } else {
                    ("chartId", "chart")
                };
                value[field] = format!("{prefix}:sha256:{}", "09".repeat(32)).into();
            }),
            "audio-song" | "audio-chart" => {
                fixture.rewrite_document("audio-manifest.json", |value| {
                    let (field, prefix) = if case == "audio-song" {
                        ("songId", "song")
                    } else {
                        ("chartId", "chart")
                    };
                    value[field] = format!("{prefix}:sha256:{}", "09".repeat(32)).into();
                })
            }
            "format" => fixture.rewrite_document("audio-manifest.json", |value| {
                value["format"] = "VOS".into()
            }),
            "selector-format" => {
                fixture.rewrite_document("audio-manifest.json", |value| {
                    value["format"] = "VOS".into()
                });
                fixture.rewrite_document("gameplay.json", |value| value["format"] = "VOS".into());
            }
            "sample-set" => fixture.rewrite_document("audio-manifest.json", |value| {
                value["assets"][0]["sampleId"] = format!("sample:sha256:{}", "09".repeat(32)).into()
            }),
            "missing-path" => fixture.rewrite_document("audio-manifest.json", |value| {
                value["assets"][0]["path"] = "missing.wav".into()
            }),
            "content-id" => fixture.replace_file("sample.wav", b"different prepared bytes"),
            _ => unreachable!(),
        }
        let error = load_bundle_documents(&fixture.root, None).expect_err(case);
        assert_eq!(
            error.code,
            open2jam_core::error::ErrorCode::CacheCorrupt,
            "{case}"
        );
    }
}

#[test]
fn audio_schema_and_assets_fail_closed() {
    for case in [
        "schema",
        "unknown",
        "duplicate",
        "traversal",
        "non-wav",
        "bad-id",
    ] {
        let fixture = Fixture::new();
        fixture.rewrite_document("audio-manifest.json", |value| match case {
            "schema" => value["schemaVersion"] = 3.into(),
            "unknown" => value["unexpected"] = true.into(),
            "duplicate" => {
                let asset = value["assets"][0].clone();
                value["assets"].as_array_mut().unwrap().push(asset);
            }
            "traversal" => value["assets"][0]["path"] = "../sample.wav".into(),
            "non-wav" => value["assets"][0]["path"] = "sample.mp3".into(),
            "bad-id" => value["assets"][0]["sampleId"] = "invalid".into(),
            _ => unreachable!(),
        });
        let error = load_bundle_documents(&fixture.root, None).expect_err(case);
        let code = if case == "schema" {
            open2jam_core::error::ErrorCode::UnsupportedSchema
        } else {
            open2jam_core::error::ErrorCode::CacheCorrupt
        };
        assert_eq!(error.code, code, "{case}");
        assert_eq!(error.relative_path.unwrap().as_str(), "audio-manifest.json");
    }
}

#[test]
fn oversized_json_is_rejected_even_when_file_integrity_matches() {
    let fixture = Fixture::new();
    let mut bytes = fs::read(fixture.root.join("gameplay.json")).unwrap();
    bytes.resize(64 * 1024 * 1024 + 1, b' ');
    fixture.replace_file("gameplay.json", &bytes);
    let error = load_bundle_documents(&fixture.root, None).unwrap_err();
    assert_eq!(error.code, open2jam_core::error::ErrorCode::CacheCorrupt);
    assert!(error.message.contains("64 MiB"));
}
