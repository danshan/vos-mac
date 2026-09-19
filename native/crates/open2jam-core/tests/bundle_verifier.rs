use open2jam_core::{
    bundle::{BundleFile, BundleIdentity, BundleManifestV2, SoundFontIdentity, verify_bundle},
    digest::Digest,
    id::{ChartIdentity, SongId, SourceFingerprint},
    json::encode_contract,
    path::BundleRelativePath,
    schema::STATIC_ASSETS_VERSION,
};
use std::{
    fs,
    path::PathBuf,
    sync::atomic::{AtomicU64, Ordering},
};

static NEXT_CASE: AtomicU64 = AtomicU64::new(0);
struct Bundle(PathBuf);
impl Bundle {
    fn new() -> Self {
        let path = std::env::temp_dir().join(format!(
            "native-bundle-{}-{}",
            std::process::id(),
            NEXT_CASE.fetch_add(1, Ordering::Relaxed)
        ));
        fs::create_dir(&path).unwrap();
        Self(path)
    }
    fn write_fixture(&self) -> BundleManifestV2 {
        let song = SongId::from_digest(Digest::from_bytes([1; 32]));
        let chart = ChartIdentity::vos(0).unwrap();
        let identity = BundleIdentity {
            converter_version: "0.1.0".to_owned(),
            static_assets_version: STATIC_ASSETS_VERSION.to_owned(),
            soundfont: SoundFontIdentity {
                version: "2.0.3".to_owned(),
                sha256: Digest::from_bytes([2; 32]),
            },
            song_id: song,
            chart_id: chart.chart_id(&song),
            chart_selector: chart.selector(),
            source_fingerprint: SourceFingerprint::from_digest(Digest::from_bytes([3; 32])),
        };
        let mut files = Vec::new();
        for (path, bytes) in [
            ("audio-manifest.json", b"{}\n".as_slice()),
            ("audio/sample.wav", b"controlled audio bytes".as_slice()),
            ("gameplay.json", b"{}\n".as_slice()),
        ] {
            let target = self.0.join(path);
            fs::create_dir_all(target.parent().unwrap()).unwrap();
            fs::write(target, bytes).unwrap();
            files.push(BundleFile::from_bytes(
                BundleRelativePath::parse(path).unwrap(),
                bytes,
            ));
        }
        let manifest = BundleManifestV2::new(identity, files).unwrap();
        fs::write(
            self.0.join("bundle.json"),
            encode_contract(&manifest).unwrap(),
        )
        .unwrap();
        manifest
    }
}
impl Drop for Bundle {
    fn drop(&mut self) {
        fs::remove_dir_all(&self.0).unwrap();
    }
}

#[test]
fn exact_bundle_tree_verifies_after_relocation() {
    let first = Bundle::new();
    let manifest = first.write_fixture();
    let verified = verify_bundle(&first.0, Some(manifest.bundle_key())).unwrap();
    assert_eq!(verified.manifest(), &manifest);
    assert_eq!(verified.root(), first.0.canonicalize().unwrap());
    let second = Bundle::new();
    fs::create_dir(second.0.join("audio")).unwrap();
    for path in [
        "bundle.json",
        "gameplay.json",
        "audio-manifest.json",
        "audio/sample.wav",
    ] {
        fs::copy(first.0.join(path), second.0.join(path)).unwrap();
    }
    assert_eq!(
        verify_bundle(&second.0, None).unwrap().manifest(),
        &manifest
    );
}

#[test]
fn manifest_rejects_case_colliding_directory_components() {
    let bundle = Bundle::new();
    let manifest = bundle.write_fixture();
    let mut value = serde_json::to_value(manifest).unwrap();
    let files = value["files"].as_array_mut().unwrap();
    let mut extra = files[1].clone();
    extra["path"] = "Audio/other.wav".into();
    files.push(extra);
    files.sort_by_key(|entry| entry["path"].as_str().unwrap().to_owned());
    assert!(serde_json::from_value::<BundleManifestV2>(value).is_err());
}

#[test]
fn manifest_rejects_excessive_path_depth_before_walking() {
    let bundle = Bundle::new();
    let manifest = bundle.write_fixture();
    let mut value = serde_json::to_value(manifest).unwrap();
    value["files"][1]["path"] = format!("{}sample.wav", "audio/".repeat(64)).into();
    assert!(serde_json::from_value::<BundleManifestV2>(value).is_err());
}

#[test]
fn invalid_manifests_never_verify() {
    use serde_json::json;
    for case in [
        "incomplete",
        "schema",
        "key",
        "chart",
        "unknown",
        "duplicate-field",
        "unsorted",
        "duplicate-path",
        "case-path",
        "file-directory",
        "self",
        "self-directory",
        "absolute",
        "parent",
        "backslash",
        "required",
        "too-many",
        "too-large",
    ] {
        let bundle = Bundle::new();
        let manifest = bundle.write_fixture();
        let mut value = serde_json::to_value(&manifest).unwrap();
        match case {
            "incomplete" => value["complete"] = false.into(),
            "schema" => value["schemaVersion"] = 3.into(),
            "key" => {
                value["bundleKey"] = serde_json::to_value(
                    open2jam_core::id::BundleKey::from_digest(Digest::from_bytes([9; 32])),
                )
                .unwrap()
            }
            "chart" => {
                value["chartId"] = serde_json::to_value(open2jam_core::id::ChartId::from_digest(
                    Digest::from_bytes([9; 32]),
                ))
                .unwrap()
            }
            "unknown" => value["unrecognized"] = true.into(),
            "unsorted" => value["files"].as_array_mut().unwrap().reverse(),
            "duplicate-path" => {
                let file = value["files"][1].clone();
                value["files"].as_array_mut().unwrap().insert(1, file);
            }
            "case-path" | "file-directory" | "self" | "self-directory" => {
                let mut file = value["files"][1].clone();
                file["path"] = match case {
                    "case-path" => "audio/SAMPLE.wav",
                    "file-directory" => "audio",
                    "self" => "bundle.json",
                    _ => "bundle.json/file",
                }
                .into();
                let files = value["files"].as_array_mut().unwrap();
                files.push(file);
                files.sort_by_key(|entry| entry["path"].as_str().unwrap().to_owned());
            }
            "absolute" => value["files"][1]["path"] = "/audio/sample.wav".into(),
            "parent" => value["files"][1]["path"] = "audio/../sample.wav".into(),
            "backslash" => value["files"][1]["path"] = "audio\\sample.wav".into(),
            "required" => {
                value["files"].as_array_mut().unwrap().pop();
            }
            "too-many" => value["files"] = json!(vec![value["files"][1].clone(); 65_537]),
            "duplicate-field" | "too-large" => {}
            _ => unreachable!(),
        }
        let mut bytes = serde_json::to_vec(&value).unwrap();
        if case == "duplicate-field" {
            bytes.splice(1..1, b"\"complete\":true,".iter().copied());
        }
        if case == "too-large" {
            bytes.resize(1024 * 1024 + 1, b' ');
        }
        fs::write(bundle.0.join("bundle.json"), bytes).unwrap();
        let error = verify_bundle(&bundle.0, None).expect_err(case);
        let expected = if case == "schema" {
            open2jam_core::error::ErrorCode::UnsupportedSchema
        } else {
            open2jam_core::error::ErrorCode::CacheCorrupt
        };
        assert_eq!(error.code, expected, "{case}");
    }
}

#[test]
fn damaged_or_extra_bundle_files_never_verify() {
    for case in [
        "missing",
        "size",
        "hash",
        "extra-file",
        "extra-directory",
        "expected-key",
    ] {
        let bundle = Bundle::new();
        bundle.write_fixture();
        let audio = bundle.0.join("audio/sample.wav");
        match case {
            "missing" => fs::remove_file(audio).unwrap(),
            "size" => fs::write(audio, b"short").unwrap(),
            "hash" => fs::write(audio, b"CONTROLLED AUDIO BYTES").unwrap(),
            "extra-file" => fs::write(bundle.0.join("extra.bin"), []).unwrap(),
            "extra-directory" => fs::create_dir(bundle.0.join("extra")).unwrap(),
            "expected-key" => {}
            _ => unreachable!(),
        }
        let wrong_key = open2jam_core::id::BundleKey::from_digest(Digest::from_bytes([9; 32]));
        let error = verify_bundle(&bundle.0, (case == "expected-key").then_some(&wrong_key))
            .expect_err(case);
        assert_eq!(
            error.code,
            open2jam_core::error::ErrorCode::CacheCorrupt,
            "{case}"
        );
        if matches!(case, "size" | "hash") {
            assert_eq!(error.relative_path.unwrap().as_str(), "audio/sample.wav");
        }
    }
}

#[cfg(unix)]
#[test]
fn symlinks_and_non_regular_files_never_verify() {
    use std::os::unix::{fs::symlink, net::UnixListener};
    for case in ["root", "manifest", "file", "directory", "socket"] {
        let bundle = Bundle::new();
        let outside = Bundle::new();
        bundle.write_fixture();
        outside.write_fixture();
        let root = if case == "root" {
            symlink(&outside.0, bundle.0.join("linked")).unwrap();
            bundle.0.join("linked")
        } else {
            bundle.0.clone()
        };
        match case {
            "manifest" | "file" => {
                let relative = if case == "manifest" {
                    "bundle.json"
                } else {
                    "audio/sample.wav"
                };
                fs::remove_file(bundle.0.join(relative)).unwrap();
                symlink(outside.0.join(relative), bundle.0.join(relative)).unwrap();
            }
            "directory" => {
                fs::remove_dir_all(bundle.0.join("audio")).unwrap();
                symlink(outside.0.join("audio"), bundle.0.join("audio")).unwrap();
            }
            "socket" => {
                let _socket = UnixListener::bind(bundle.0.join("socket")).unwrap();
            }
            "root" => {}
            _ => unreachable!(),
        }
        assert!(verify_bundle(&root, None).is_err(), "{case}");
    }
}
