use open2jam_core::{
    bundle::load_bundle_documents,
    digest::Digest,
    id::{ChartIdentity, LibraryRootId, SongIdentity},
    path::SourceRelativePath,
    schema::STATIC_ASSETS_VERSION,
};
use std::{
    fs,
    path::PathBuf,
    process::Command,
    sync::atomic::{AtomicU64, Ordering},
};

static NEXT: AtomicU64 = AtomicU64::new(0);
const OJN: &[u8] =
    include_bytes!("../../../../rewrite/golden/java-migration/sources/ojn/minimal.ojn");
const OJM: &[u8] =
    include_bytes!("../../../../rewrite/golden/java-migration/sources/ojn/minimal.ojm");
struct Case(PathBuf);
impl Case {
    fn new() -> Self {
        let root = std::env::temp_dir().join(format!(
            "ojn-bundle-{}-{}",
            std::process::id(),
            NEXT.fetch_add(1, Ordering::Relaxed)
        ));
        fs::create_dir(&root).unwrap();
        for name in ["songs", "staging"] {
            fs::create_dir(root.join(name)).unwrap();
        }
        let mut source = OJN.to_vec();
        source.extend(0_u32.to_le_bytes());
        source.extend(2_u16.to_le_bytes());
        source.extend(1_u16.to_le_bytes());
        source.extend([1, 0, 0xf1, 0]);
        let end = (source.len() as u32).to_le_bytes();
        for offset in [288, 292, 296] {
            source[offset..offset + 4].copy_from_slice(&end);
        }
        fs::write(root.join("songs/song.ojn"), source).unwrap();
        fs::write(root.join("songs/minimal.ojm"), OJM).unwrap();
        Self(root.canonicalize().unwrap())
    }
    fn request(&self) -> serde_json::Value {
        let root_id = LibraryRootId::from_digest(Digest::from_bytes([1; 32]));
        let song = SongIdentity::ojn_file(root_id, SourceRelativePath::parse("song.ojn").unwrap())
            .song_id();
        serde_json::json!({"schemaVersion":1,"jobId":"load-one","command":"BUNDLE",
            "chartId":ChartIdentity::ojn(0).unwrap().chart_id(&song),"sourcePath":self.0.join("songs/song.ojn"),"sourceKind":"OJN",
            "libraryRoot":{"id":root_id,"path":self.0.join("songs")},"selector":{"kind":"OJN_CHART","index":0},
            "stagingRoot":self.0.join("staging"),"cancelMarkerPath":self.0.join("cancel"),
            "soundfont":{"path":self.0.join("unused.sf2"),"version":"unused","sha256":Digest::from_bytes([0;32])},
            "staticAssetsVersion":STATIC_ASSETS_VERSION})
    }
    fn invoke(&self, request: &serde_json::Value, attempt: &str) -> (i32, serde_json::Value) {
        let path = self.0.join(format!("{attempt}.request.json"));
        let result = self.0.join(format!("{attempt}.result.json"));
        fs::write(&path, serde_json::to_vec(request).unwrap()).unwrap();
        let output = Command::new(env!("CARGO_BIN_EXE_open2jam-converter"))
            .args(["bundle", "--request"])
            .arg(path)
            .arg("--progress")
            .arg(self.0.join(format!("{attempt}.progress.jsonl")))
            .arg("--result")
            .arg(&result)
            .output()
            .unwrap();
        assert!(
            result.exists(),
            "{}",
            String::from_utf8_lossy(&output.stderr)
        );
        (
            output.status.code().unwrap(),
            serde_json::from_slice(&fs::read(result).unwrap()).unwrap(),
        )
    }
}
impl Drop for Case {
    fn drop(&mut self) {
        fs::remove_dir_all(&self.0).unwrap();
    }
}

#[test]
fn raw_ojn_prepares_a_self_contained_playable_bundle_without_java_or_soundfont() {
    let case = Case::new();
    let request = case.request();
    let (code, result) = case.invoke(&request, "first");
    assert_eq!(code, 0, "{result}");
    let output = PathBuf::from(result["output"]["stagingPath"].as_str().unwrap());
    let documents = load_bundle_documents(&output, None).unwrap();
    assert_eq!(
        serde_json::to_value(documents.chart().chart_id()).unwrap(),
        request["chartId"]
    );
    let chart: serde_json::Value =
        serde_json::from_slice(&fs::read(output.join("gameplay.json")).unwrap()).unwrap();
    assert_eq!(chart["notes"].as_array().unwrap().len(), 1);
    assert_eq!(chart["notes"][0]["startUs"], 1500000);
    assert_eq!(
        chart["notes"][0]["volume"],
        serde_json::json!({"numerator":15,"denominator":16})
    );
    assert_eq!(
        chart["notes"][0]["pan"],
        serde_json::json!({"numerator":-7,"denominator":8})
    );
    let audio: serde_json::Value =
        serde_json::from_slice(&fs::read(output.join("audio-manifest.json")).unwrap()).unwrap();
    let assets = audio["assets"].as_array().unwrap();
    assert!(!assets.is_empty());
    let prepared = fs::read(output.join(assets[0]["path"].as_str().unwrap())).unwrap();
    assert_eq!(&prepared[..4], b"RIFF");
    assert_eq!(chart["notes"][0]["sampleId"], assets[0]["sampleId"]);
    let progress = fs::read_to_string(case.0.join("first.progress.jsonl")).unwrap();
    let phases: Vec<String> = progress
        .lines()
        .map(|line| {
            let value: serde_json::Value = serde_json::from_str(line).unwrap();
            value["phase"].as_str().unwrap().to_owned()
        })
        .collect();
    assert!(
        phases
            .iter()
            .position(|phase| phase == "COMPILE_TIMING")
            .unwrap()
            < phases
                .iter()
                .position(|phase| phase == "PREPARE_AUDIO")
                .unwrap()
    );
    fs::remove_dir_all(case.0.join("songs")).unwrap();
    fs::rename(&output, case.0.join("relocated-bundle")).unwrap();
    load_bundle_documents(&case.0.join("relocated-bundle"), None).unwrap();
}

#[test]
fn raw_ojn_bundle_rejects_missing_unsafe_and_unsupported_inputs() {
    for mutation in [
        "missing-root",
        "missing-source",
        "foreign-root",
        "wrong-chart",
        "missing-bank",
        "traversal",
        "missing-sample",
        "m30",
        "cancel",
    ] {
        let case = Case::new();
        let mut request = case.request();
        let (exit, error) = match mutation {
            "missing-source" => {
                fs::remove_file(case.0.join("songs/song.ojn")).unwrap();
                (1, "SOURCE_CHANGED")
            }
            "missing-root" => {
                request.as_object_mut().unwrap().remove("libraryRoot");
                (2, "INVALID_REQUEST")
            }
            "foreign-root" => {
                request["libraryRoot"]["path"] = serde_json::json!(case.0.join("elsewhere"));
                (2, "INVALID_REQUEST")
            }
            "wrong-chart" => {
                request["chartId"] = serde_json::json!(format!("chart:sha256:{}", "00".repeat(32)));
                (1, "SOURCE_CHANGED")
            }
            "missing-bank" => {
                fs::remove_file(case.0.join("songs/minimal.ojm")).unwrap();
                (1, "MISSING_COMPANION")
            }
            "traversal" => {
                set_companion(&case, b"../outside.ojm");
                fs::write(case.0.join("outside.ojm"), OJM).unwrap();
                (1, "MISSING_COMPANION")
            }
            "missing-sample" => {
                let mut empty = OJM[..20].to_vec();
                for offset in [8, 12, 16] {
                    empty[offset..offset + 4].copy_from_slice(&20_u32.to_le_bytes());
                }
                fs::write(case.0.join("songs/minimal.ojm"), empty).unwrap();
                (1, "MISSING_ASSET")
            }
            "m30" => {
                let mut bytes = OJM.to_vec();
                bytes[..4].copy_from_slice(b"M30\0");
                fs::write(case.0.join("songs/minimal.ojm"), bytes).unwrap();
                (1, "UNSUPPORTED_FORMAT")
            }
            "cancel" => {
                fs::write(case.0.join("cancel"), b"").unwrap();
                (3, "CANCELLED")
            }
            _ => unreachable!(),
        };
        let (code, result) = case.invoke(&request, mutation);
        assert_eq!(code, exit, "{mutation}: {result}");
        assert_eq!(result["error"]["code"], error, "{mutation}: {result}");
        assert!(!case.0.join("staging/load-one").exists());
    }
}

fn set_companion(case: &Case, name: &[u8]) {
    assert!(name.len() < 32);
    let path = case.0.join("songs/song.ojn");
    let mut source = fs::read(&path).unwrap();
    source[236..268].fill(0);
    source[236..236 + name.len()].copy_from_slice(name);
    fs::write(path, source).unwrap();
}

#[test]
fn legacy_companion_names_match_existing_files_without_display_guessing() {
    let case = Case::new();
    set_companion(&case, b"\xc7\xfa\xc4\xbf.ojm");
    fs::rename(
        case.0.join("songs/minimal.ojm"),
        case.0.join("songs/\u{66f2}\u{76ee}.ojm"),
    )
    .unwrap();
    let (code, result) = case.invoke(&case.request(), "legacy-name");
    assert_eq!(code, 0, "{result}");
}

#[cfg(unix)]
#[test]
fn raw_ojn_bundle_does_not_follow_source_or_companion_links() {
    for primary in [true, false] {
        let case = Case::new();
        let path = case.0.join(if primary {
            "songs/song.ojn"
        } else {
            "songs/minimal.ojm"
        });
        let target = case.0.join("outside-source");
        fs::rename(&path, &target).unwrap();
        std::os::unix::fs::symlink(&target, &path).unwrap();
        let (code, result) = case.invoke(&case.request(), "linked");
        assert_eq!(code, 1, "{result}");
        assert_eq!(
            result["error"]["code"],
            if primary {
                "INVALID_REQUEST"
            } else {
                "MISSING_COMPANION"
            }
        );
        assert!(!case.0.join("staging/load-one").exists());
    }
}

#[test]
fn raw_ojn_retry_is_deterministic_and_companion_changes_invalidate_the_bundle_key() {
    let case = Case::new();
    let request = case.request();
    let (code, first) = case.invoke(&request, "first");
    assert_eq!(code, 0, "{first}");
    let (code, retry) = case.invoke(&request, "retry");
    assert_eq!(code, 0, "{retry}");
    assert_eq!(first["output"]["bundleKey"], retry["output"]["bundleKey"]);
    let mut changed = OJM.to_vec();
    changed[76] ^= 1;
    fs::write(case.0.join("songs/minimal.ojm"), changed).unwrap();
    let mut next = request;
    next["jobId"] = "changed-source".into();
    let (code, changed) = case.invoke(&next, "changed");
    assert_eq!(code, 0, "{changed}");
    assert_ne!(first["output"]["bundleKey"], changed["output"]["bundleKey"]);
    let original = load_bundle_documents(&case.0.join("staging/load-one"), None).unwrap();
    assert_eq!(
        serde_json::to_value(original.bundle().manifest().bundle_key()).unwrap(),
        first["output"]["bundleKey"]
    );
}

#[test]
fn ambiguous_legacy_companion_names_fail_instead_of_picking_a_guess() {
    let case = Case::new();
    set_companion(&case, b"\xc7\xfa\xc4\xbf.ojm");
    for name in ["\u{66f2}\u{76ee}.ojm", "\u{d613}\u{cee4}.ojm"] {
        fs::write(case.0.join("songs").join(name), OJM).unwrap();
    }
    let (code, result) = case.invoke(&case.request(), "ambiguous");
    assert_eq!(code, 1, "{result}");
    assert_eq!(result["error"]["code"], "MISSING_COMPANION");
    assert!(!case.0.join("staging/load-one").exists());
}

#[test]
fn omc_companion_uses_production_decoding_and_preserves_encoded_source_identity() {
    let case = Case::new();
    let encoded = include_bytes!("../../../../rewrite/golden/java-migration/sources/ojn/omc.ojm");
    fs::write(case.0.join("songs/minimal.ojm"), encoded).unwrap();
    let (code, result) = case.invoke(&case.request(), "omc");
    assert_eq!(code, 0, "{result}");
    let output = PathBuf::from(result["output"]["stagingPath"].as_str().unwrap());
    load_bundle_documents(&output, None).unwrap();
    let audio: serde_json::Value =
        serde_json::from_slice(&fs::read(output.join("audio-manifest.json")).unwrap()).unwrap();
    let prepared = fs::read(output.join(audio["assets"][0]["path"].as_str().unwrap())).unwrap();
    let oracle: serde_json::Value = serde_json::from_str(include_str!(
        "../../open2jam-core/tests/fixtures/ojn/omc-frozen-java.json"
    ))
    .unwrap();
    let pcm_hex: String = prepared[44..]
        .iter()
        .map(|byte| format!("{byte:02x}"))
        .collect();
    assert_eq!(pcm_hex, oracle["samples"][0]["pcm16Hex"].as_str().unwrap());
    assert_eq!(fs::read(case.0.join("songs/minimal.ojm")).unwrap(), encoded);
    let mut decoded = encoded.to_vec();
    open2jam_core::ojm::decode_omc_in_place(&mut decoded, &mut || Ok(())).unwrap();
    fs::write(case.0.join("songs/minimal.ojm"), decoded).unwrap();
    let mut request = case.request();
    request["jobId"] = serde_json::json!("decoded-source");
    let (code, plain) = case.invoke(&request, "plain-equivalent");
    assert_eq!(code, 0, "{plain}");
    assert_ne!(result["output"]["bundleKey"], plain["output"]["bundleKey"]);
}

#[test]
fn corrupt_omc_does_not_damage_a_previously_prepared_song() {
    let case = Case::new();
    let (code, good) = case.invoke(&case.request(), "good");
    assert_eq!(code, 0, "{good}");
    let prepared = PathBuf::from(good["output"]["stagingPath"].as_str().unwrap());
    let encoded = include_bytes!("../../../../rewrite/golden/java-migration/sources/ojn/omc.ojm");
    for (index, end) in [4, 19, 75, encoded.len() - 1].into_iter().enumerate() {
        fs::write(case.0.join("songs/minimal.ojm"), &encoded[..end]).unwrap();
        let mut request = case.request();
        let job = format!("corrupt-omc-{index}");
        request["jobId"] = serde_json::json!(job);
        let (code, result) = case.invoke(&request, &job);
        assert_eq!(code, 1, "{result}");
        assert_eq!(result["error"]["code"], "CORRUPT_CHART");
        assert!(!case.0.join("staging").join(&job).exists());
        load_bundle_documents(&prepared, None).unwrap();
    }
    fs::write(case.0.join("songs/minimal.ojm"), OJM).unwrap();
    let mut request = case.request();
    request["jobId"] = serde_json::json!("healthy-after-errors");
    let (code, result) = case.invoke(&request, "recovered");
    assert_eq!(code, 0, "{result}");
    assert_eq!(good["output"]["bundleKey"], result["output"]["bundleKey"]);
}
