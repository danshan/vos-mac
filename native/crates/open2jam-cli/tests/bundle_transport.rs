use open2jam_core::bundle::load_bundle_documents;
use std::{
    fs,
    path::PathBuf,
    process::Command,
    sync::atomic::{AtomicU64, Ordering},
};

static NEXT: AtomicU64 = AtomicU64::new(0);
struct Case(PathBuf);
impl Case {
    fn new() -> Self {
        let root = std::env::temp_dir().join(format!(
            "bundle-cli-{}-{}",
            std::process::id(),
            NEXT.fetch_add(1, Ordering::Relaxed)
        ));
        fs::create_dir(&root).unwrap();
        let case = Self(root.canonicalize().unwrap());
        assert!(
            Command::new(env!("CARGO_BIN_EXE_controlled-bundle-probe"))
                .arg(case.0.join("source"))
                .output()
                .unwrap()
                .status
                .success()
        );
        fs::create_dir(case.0.join("staging")).unwrap();
        case
    }
    fn request(&self) -> serde_json::Value {
        let source = load_bundle_documents(&self.0.join("source"), None).unwrap();
        let manifest = source.bundle().manifest();
        serde_json::json!({"schemaVersion":1,"jobId":"load-one","command":"BUNDLE",
            "chartId":manifest.chart_id(),"sourcePath":self.0.join("source"),"sourceKind":"BUNDLE_V2",
            "selector":{"kind":"BUNDLE_CHART","chartId":manifest.chart_id()},"stagingRoot":self.0.join("staging"),
            "cancelMarkerPath":self.0.join("cancel"),"soundfont":{"path":self.0.join("unused.sf2"),"version":"2.0.3","sha256":manifest.soundfont().sha256},
            "staticAssetsVersion":manifest.static_assets_version()})
    }
    fn invoke(&self, request: &serde_json::Value, attempt: &str) -> (i32, serde_json::Value) {
        let path = self.0.join(format!("{attempt}.request.json"));
        fs::write(&path, serde_json::to_vec(request).unwrap()).unwrap();
        let result = self.0.join(format!("{attempt}.result.json"));
        let output = Command::new(env!("CARGO_BIN_EXE_open2jam-converter"))
            .arg("bundle")
            .arg("--request")
            .arg(path)
            .arg("--progress")
            .arg(self.0.join(format!("{attempt}.progress.jsonl")))
            .arg("--result")
            .arg(&result)
            .output()
            .unwrap();
        assert!(output.stdout.is_empty());
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
fn real_cli_stages_existing_bundle_and_retry_uses_fresh_transport() {
    let case = Case::new();
    let request = case.request();
    let source = load_bundle_documents(&case.0.join("source"), None).unwrap();
    for attempt in ["first", "retry"] {
        let (code, result) = case.invoke(&request, attempt);
        assert_eq!(code, 0, "{result}");
        assert_eq!(result["status"], "SUCCEEDED");
        assert_eq!(result["jobId"], "load-one");
        let output = &result["output"];
        let staged = PathBuf::from(output["stagingPath"].as_str().unwrap());
        assert_eq!(staged, case.0.join("staging/load-one"));
        assert_eq!(
            load_bundle_documents(&staged, None)
                .unwrap()
                .bundle()
                .manifest(),
            source.bundle().manifest()
        );
        assert!(!case.0.join("staging/.partial/load-one").exists());
        let progress =
            fs::read_to_string(case.0.join(format!("{attempt}.progress.jsonl"))).unwrap();
        let events: Vec<serde_json::Value> = progress
            .lines()
            .map(|line| serde_json::from_str(line).unwrap())
            .collect();
        assert_eq!(events.first().unwrap()["sequence"], 1);
        assert_eq!(events.last().unwrap()["phase"], "VERIFY_BUNDLE");
        assert!(events.iter().all(|e| e["phase"] != "READY"));
    }
}

#[test]
fn cancellation_corruption_and_identity_changes_never_report_success() {
    for mode in ["cancel", "corrupt", "changed", "overlap"] {
        let case = Case::new();
        let mut request = case.request();
        let expected = match mode {
            "cancel" => {
                fs::write(case.0.join("cancel"), b"").unwrap();
                "CANCELLED"
            }
            "corrupt" => {
                fs::write(case.0.join("source/audio/tone.wav"), b"broken").unwrap();
                "CACHE_CORRUPT"
            }
            "changed" => {
                let chart = format!("chart:sha256:{}", "00".repeat(32));
                request["chartId"] = chart.clone().into();
                request["selector"]["chartId"] = chart.into();
                "SOURCE_CHANGED"
            }
            "overlap" => {
                request["stagingRoot"] = serde_json::to_value(case.0.join("source")).unwrap();
                "INVALID_REQUEST"
            }
            _ => unreachable!(),
        };
        let (code, result) = case.invoke(&request, "failure");
        assert_ne!(code, 0);
        assert_eq!(result["error"]["code"], expected, "{mode}");
        assert_eq!(
            result["status"],
            if mode == "cancel" {
                "CANCELLED"
            } else {
                "FAILED"
            }
        );
        assert!(result["output"].is_null());
        assert!(!case.0.join("staging/load-one").exists());
    }
}

#[test]
fn internal_staging_failure_uses_internal_exit_code_and_preserves_existing_partial() {
    let case = Case::new();
    let request = case.request();
    fs::create_dir_all(case.0.join("staging/.partial/load-one")).unwrap();
    let marker = case.0.join("staging/.partial/load-one/keep");
    fs::write(&marker, b"owned by another attempt").unwrap();
    let (code, result) = case.invoke(&request, "collision");
    assert_eq!(result["error"]["code"], "INTERNAL_ERROR");
    assert_eq!(code, 4);
    assert_eq!(fs::read(marker).unwrap(), b"owned by another attempt");
    assert!(!case.0.join("staging/load-one").exists());
}
