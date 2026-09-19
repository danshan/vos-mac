use std::fs;
use std::path::PathBuf;
use std::process::{Command, Output};
use std::sync::atomic::{AtomicU64, Ordering};

static NEXT_CASE: AtomicU64 = AtomicU64::new(0);
struct Case(PathBuf);
impl Case {
    fn new(request: &[u8]) -> Self {
        let path = std::env::temp_dir().join(format!(
            "native-cli-{}-{}",
            std::process::id(),
            NEXT_CASE.fetch_add(1, Ordering::Relaxed)
        ));
        fs::create_dir(&path).unwrap();
        fs::write(path.join("request.json"), request).unwrap();
        Self(path)
    }
    fn invoke(&self) -> Output {
        Command::new(env!("CARGO_BIN_EXE_open2jam-converter"))
            .arg("catalog")
            .arg("--request")
            .arg(self.0.join("request.json"))
            .arg("--progress")
            .arg(self.0.join("progress.jsonl"))
            .arg("--result")
            .arg(self.0.join("result.json"))
            .output()
            .unwrap()
    }
}
impl Drop for Case {
    fn drop(&mut self) {
        fs::remove_dir_all(&self.0).unwrap();
    }
}

#[test]
fn malformed_request_produces_a_complete_structured_failure_without_progress() {
    let case = Case::new(b"{broken");
    let output = case.invoke();
    assert_eq!(output.status.code(), Some(2));
    assert!(output.stdout.is_empty());
    assert_eq!(fs::read(case.0.join("result.json")).unwrap(), b"{\"schemaVersion\":1,\"jobId\":null,\"command\":\"CATALOG\",\"status\":\"FAILED\",\"output\":null,\"error\":{\"code\":\"INVALID_REQUEST\",\"message\":\"Invalid request document\",\"sourcePath\":null,\"context\":{}}}\n");
    assert!(!case.0.join("progress.jsonl").exists());
    assert_eq!(fs::read_dir(&case.0).unwrap().count(), 2);
}

fn catalog_request(case: &Case) -> serde_json::Value {
    serde_json::json!({"schemaVersion":1,"jobId":"job-001","command":"CATALOG","roots":[],
        "previousIndexPath":null,"stagingRoot":case.0.join("stage"),"cancelMarkerPath":case.0.join("cancel")})
}

#[test]
fn wrong_command_keeps_a_validated_job_id_and_does_not_start_progress() {
    let case = Case::new(b"");
    let mut request = catalog_request(&case);
    request["command"] = "BUNDLE".into();
    fs::write(
        case.0.join("request.json"),
        serde_json::to_vec(&request).unwrap(),
    )
    .unwrap();
    let output = case.invoke();
    assert_eq!(output.status.code(), Some(2));
    let result: serde_json::Value =
        serde_json::from_slice(&fs::read(case.0.join("result.json")).unwrap()).unwrap();
    assert_eq!(result["jobId"], "job-001");
    assert_eq!(result["error"]["code"], "INVALID_REQUEST");
    assert!(!case.0.join("progress.jsonl").exists());
}

#[test]
fn protocol_failures_are_machine_readable_and_do_not_create_progress() {
    for (name, code) in [
        ("schema", "UNSUPPORTED_SCHEMA"),
        ("unknown", "INVALID_REQUEST"),
        ("duplicate", "INVALID_REQUEST"),
        ("trailing", "INVALID_REQUEST"),
        ("bom", "INVALID_REQUEST"),
        ("utf8", "INVALID_REQUEST"),
        ("oversized", "INVALID_REQUEST"),
    ] {
        let case = Case::new(b"");
        let mut request = catalog_request(&case);
        if name == "schema" {
            request["schemaVersion"] = 2.into();
        }
        if name == "unknown" {
            request["unknown"] = true.into();
        }
        let mut bytes = serde_json::to_vec(&request).unwrap();
        match name {
            "duplicate" => bytes
                .splice(1..1, b"\"jobId\":\"second\",".iter().copied())
                .for_each(drop),
            "trailing" => bytes.extend_from_slice(b" trailing"),
            "bom" => bytes.splice(0..0, [0xef, 0xbb, 0xbf]).for_each(drop),
            "utf8" => bytes = vec![0xff],
            "oversized" => bytes = vec![b' '; 1024 * 1024 + 1],
            _ => {}
        }
        fs::write(case.0.join("request.json"), bytes).unwrap();
        let output = case.invoke();
        assert_eq!(output.status.code(), Some(2), "{name}");
        assert!(output.stdout.is_empty());
        let result: serde_json::Value =
            serde_json::from_slice(&fs::read(case.0.join("result.json")).unwrap()).unwrap();
        assert_eq!(result["jobId"], serde_json::Value::Null);
        assert_eq!(result["error"]["code"], code);
        assert!(!case.0.join("progress.jsonl").exists());
    }
}

#[test]
fn valid_request_reports_unsupported_instead_of_fake_import_success() {
    let case = Case::new(b"");
    fs::write(
        case.0.join("request.json"),
        serde_json::to_vec(&catalog_request(&case)).unwrap(),
    )
    .unwrap();
    let output = case.invoke();
    assert_eq!(output.status.code(), Some(1));
    assert!(output.stdout.is_empty());
    let result: serde_json::Value =
        serde_json::from_slice(&fs::read(case.0.join("result.json")).unwrap()).unwrap();
    assert_eq!(result["jobId"], "job-001");
    assert_eq!(result["error"]["code"], "UNSUPPORTED_FORMAT");
    assert_eq!(result["status"], "FAILED");
    assert!(fs::read(case.0.join("progress.jsonl")).unwrap().is_empty());
}

#[test]
fn existing_transport_outputs_are_never_modified() {
    for filename in ["progress.jsonl", "result.json"] {
        let case = Case::new(b"{}");
        fs::write(case.0.join(filename), b"caller data").unwrap();
        let output = case.invoke();
        assert_eq!(output.status.code(), Some(2));
        assert_eq!(fs::read(case.0.join(filename)).unwrap(), b"caller data");
        assert_eq!(fs::read_dir(&case.0).unwrap().count(), 2);
    }
}

#[test]
fn cancellation_path_cannot_alias_a_transport_file() {
    for filename in ["request.json", "progress.jsonl", "result.json"] {
        let case = Case::new(b"");
        let mut request = catalog_request(&case);
        request["cancelMarkerPath"] = serde_json::to_value(case.0.join(filename)).unwrap();
        fs::write(
            case.0.join("request.json"),
            serde_json::to_vec(&request).unwrap(),
        )
        .unwrap();
        let output = case.invoke();
        assert_eq!(output.status.code(), Some(2));
        let result: serde_json::Value =
            serde_json::from_slice(&fs::read(case.0.join("result.json")).unwrap()).unwrap();
        assert_eq!(result["error"]["code"], "INVALID_REQUEST");
        assert!(!case.0.join("progress.jsonl").exists());
    }
}

#[test]
fn invalid_cli_grammar_creates_no_transport_outputs() {
    for mutation in [
        "missing",
        "duplicate",
        "unknown",
        "reordered",
        "extra",
        "same-path",
        "missing-parent",
    ] {
        let case = Case::new(b"{}");
        let mut args: Vec<std::ffi::OsString> = vec![
            "catalog".into(),
            "--request".into(),
            case.0.join("request.json").into(),
            "--progress".into(),
            case.0.join("progress.jsonl").into(),
            "--result".into(),
            case.0.join("result.json").into(),
        ];
        match mutation {
            "missing" => {
                args.pop();
            }
            "duplicate" => args[3] = "--request".into(),
            "unknown" => args[3] = "--unknown".into(),
            "reordered" => {
                args.swap(1, 3);
                args.swap(2, 4);
            }
            "extra" => args.push("extra".into()),
            "same-path" => args[6] = args[4].clone(),
            "missing-parent" => args[6] = case.0.join("absent/result.json").into(),
            _ => unreachable!(),
        }
        let output = Command::new(env!("CARGO_BIN_EXE_open2jam-converter"))
            .args(args)
            .output()
            .unwrap();
        assert_eq!(output.status.code(), Some(2), "{mutation}");
        assert!(output.stdout.is_empty());
        assert_eq!(fs::read_dir(&case.0).unwrap().count(), 1, "{mutation}");
    }
}

#[cfg(unix)]
#[test]
fn symlink_outputs_do_not_create_or_modify_their_target() {
    for filename in ["progress.jsonl", "result.json"] {
        let case = Case::new(b"{}");
        let target = case.0.join("target");
        std::os::unix::fs::symlink(&target, case.0.join(filename)).unwrap();
        assert_eq!(case.invoke().status.code(), Some(2));
        assert!(!target.exists());
        fs::write(&target, b"keep").unwrap();
        assert_eq!(case.invoke().status.code(), Some(2));
        assert_eq!(fs::read(&target).unwrap(), b"keep");
    }
}
