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
const OSU: &str =
    include_str!("../../../../rewrite/golden/java-migration/sources/osu/seven-key.osu");
const WAV: &[u8] =
    include_bytes!("../../../../rewrite/golden/java-migration/sources/osu/audio.wav");
struct Case(PathBuf);
impl Case {
    fn new() -> Self {
        let root = std::env::temp_dir().join(format!(
            "osu-bundle-{}-{}",
            std::process::id(),
            NEXT.fetch_add(1, Ordering::Relaxed)
        ));
        fs::create_dir(&root).unwrap();
        for name in ["songs", "staging"] {
            fs::create_dir(root.join(name)).unwrap();
        }
        fs::write(root.join("songs/song.osu"), OSU).unwrap();
        fs::write(root.join("songs/audio.wav"), WAV).unwrap();
        Self(root.canonicalize().unwrap())
    }
    fn request(&self) -> serde_json::Value {
        let root_id = LibraryRootId::from_digest(Digest::from_bytes([1; 32]));
        let song = SongIdentity::osu_beatmap_set_at_root(root_id).song_id();
        serde_json::json!({"schemaVersion":1,"jobId":"load-one","command":"BUNDLE",
            "chartId":ChartIdentity::osu(SourceRelativePath::parse("song.osu").unwrap()).chart_id(&song),"sourcePath":self.0.join("songs/song.osu"),"sourceKind":"OSU",
            "libraryRoot":{"id":root_id,"path":self.0.join("songs")},"selector":{"kind":"OSU_BEATMAP","relativePath":"song.osu"},
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
fn raw_osu_converts_frozen_seven_key_chart_and_audio_to_relocatable_bundle() {
    let case = Case::new();
    let request = case.request();
    let (code, result) = case.invoke(&request, "first");
    assert_eq!(code, 0, "{result}");
    let output = PathBuf::from(result["output"]["stagingPath"].as_str().unwrap());
    load_bundle_documents(&output, None).unwrap();
    let chart: serde_json::Value =
        serde_json::from_slice(&fs::read(output.join("gameplay.json")).unwrap()).unwrap();
    assert_eq!(chart["chartId"], request["chartId"]);
    assert_eq!(chart["format"], "OSU_MANIA");
    assert_eq!(chart["notes"].as_array().unwrap().len(), 8);
    assert_eq!(chart["notes"][0]["startUs"], 1500000);
    assert_eq!(chart["notes"][7]["startUs"], 3500000);
    let audio: serde_json::Value =
        serde_json::from_slice(&fs::read(output.join("audio-manifest.json")).unwrap()).unwrap();
    let assets = audio["assets"].as_array().unwrap();
    assert_eq!(assets.len(), 1);
    assert_eq!(
        fs::read(output.join(assets[0]["path"].as_str().unwrap())).unwrap(),
        include_bytes!("../../../../rewrite/golden/java-migration/expected/osu/audio/sample-1.wav")
    );
    fs::remove_dir_all(case.0.join("songs")).unwrap();
    fs::rename(&output, case.0.join("moved-bundle")).unwrap();
    load_bundle_documents(&case.0.join("moved-bundle"), None).unwrap();
}

#[test]
fn osu_conversion_rejects_invalid_selection_missing_audio_and_unsafe_sources() {
    for mutation in [
        "missing-root",
        "selector",
        "chart-id",
        "missing-audio",
        "traversal",
        "corrupt-audio",
        "unsupported-mode",
        "cancel",
    ] {
        let case = Case::new();
        let mut request = case.request();
        let (exit, error) = match mutation {
            "missing-root" => {
                request.as_object_mut().unwrap().remove("libraryRoot");
                (2, "INVALID_REQUEST")
            }
            "selector" => {
                request["selector"]["relativePath"] = "other.osu".into();
                (1, "SOURCE_CHANGED")
            }
            "chart-id" => {
                request["chartId"] = format!("chart:sha256:{}", "00".repeat(32)).into();
                (1, "SOURCE_CHANGED")
            }
            "missing-audio" => {
                fs::remove_file(case.0.join("songs/audio.wav")).unwrap();
                (1, "MISSING_ASSET")
            }
            "traversal" => {
                fs::write(
                    case.0.join("songs/song.osu"),
                    OSU.replace("audio.wav", "../audio.wav"),
                )
                .unwrap();
                (1, "CORRUPT_CHART")
            }
            "corrupt-audio" => {
                fs::write(case.0.join("songs/audio.wav"), b"broken").unwrap();
                (1, "AUDIO_DECODE_FAILED")
            }
            "unsupported-mode" => {
                fs::write(
                    case.0.join("songs/song.osu"),
                    OSU.replace("Mode: 3", "Mode: 0"),
                )
                .unwrap();
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

#[cfg(unix)]
#[test]
fn osu_audio_symlinks_are_rejected_without_following_their_target() {
    let case = Case::new();
    fs::rename(case.0.join("songs/audio.wav"), case.0.join("outside.wav")).unwrap();
    std::os::unix::fs::symlink(case.0.join("outside.wav"), case.0.join("songs/audio.wav")).unwrap();
    let (code, result) = case.invoke(&case.request(), "linked");
    assert_eq!(code, 1);
    assert_eq!(result["error"]["code"], "INVALID_REQUEST");
    assert!(!case.0.join("staging/load-one").exists());
}

#[test]
fn osu_audio_content_changes_bundle_key_but_root_relocation_does_not() {
    let case = Case::new();
    let mut request = case.request();
    let (code, first) = case.invoke(&request, "first");
    assert_eq!(code, 0, "{first}");
    fs::rename(case.0.join("songs"), case.0.join("moved")).unwrap();
    request["sourcePath"] = serde_json::json!(case.0.join("moved/song.osu"));
    request["libraryRoot"]["path"] = serde_json::json!(case.0.join("moved"));
    request["jobId"] = "load-moved".into();
    let (code, moved) = case.invoke(&request, "moved");
    assert_eq!(code, 0, "{moved}");
    assert_eq!(first["output"]["bundleKey"], moved["output"]["bundleKey"]);
    let mut changed = WAV.to_vec();
    *changed.last_mut().unwrap() ^= 1;
    fs::write(case.0.join("moved/audio.wav"), changed).unwrap();
    request["jobId"] = "load-changed".into();
    let (code, changed) = case.invoke(&request, "changed");
    assert_eq!(code, 0, "{changed}");
    assert_ne!(first["output"]["bundleKey"], changed["output"]["bundleKey"]);
}

#[test]
fn osu_prepares_mp3_background_and_ogg_custom_sample_without_losing_references() {
    let case = Case::new();
    let source = OSU
        .replace("audio.wav", "audio.MP3")
        .replace("36,192,0,1,0,0:0:0:0:", "36,192,0,1,0,0:0:0:100:key.ogg");
    fs::write(case.0.join("songs/song.osu"), source).unwrap();
    fs::write(
        case.0.join("songs/audio.MP3"),
        include_bytes!("../../open2jam-core/tests/fixtures/osu/tone-xing.mp3"),
    )
    .unwrap();
    fs::write(
        case.0.join("songs/key.ogg"),
        include_bytes!("../../open2jam-core/tests/fixtures/ojn/tone.ogg"),
    )
    .unwrap();
    let (code, result) = case.invoke(&case.request(), "compressed");
    assert_eq!(code, 0, "{result}");
    let output = PathBuf::from(result["output"]["stagingPath"].as_str().unwrap());
    load_bundle_documents(&output, None).unwrap();
    let chart: serde_json::Value =
        serde_json::from_slice(&fs::read(output.join("gameplay.json")).unwrap()).unwrap();
    let audio: serde_json::Value =
        serde_json::from_slice(&fs::read(output.join("audio-manifest.json")).unwrap()).unwrap();
    assert_eq!(audio["assets"].as_array().unwrap().len(), 2);
    assert!(chart["notes"][0]["sampleId"].is_string());
    assert!(chart["notes"][1]["sampleId"].is_null());
    assert_ne!(
        chart["notes"][0]["sampleId"],
        chart["autoPlayEvents"][0]["sampleId"]
    );
}
