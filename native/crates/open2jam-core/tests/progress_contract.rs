use std::fs;
use std::path::PathBuf;
use std::sync::atomic::{AtomicU64, Ordering};

use open2jam_core::id::JobId;
use open2jam_core::progress::{JsonlProgressWriter, ProgressOwner, ProgressPhase, ProgressTracker};
use open2jam_core::protocol::Command;

static NEXT_CASE: AtomicU64 = AtomicU64::new(0);

struct TestDirectory(PathBuf);
impl TestDirectory {
    fn new() -> Self {
        let path = std::env::temp_dir().join(format!(
            "native-progress-{}-{}",
            std::process::id(),
            NEXT_CASE.fetch_add(1, Ordering::Relaxed)
        ));
        fs::create_dir(&path).unwrap();
        Self(path)
    }
}
impl Drop for TestDirectory {
    fn drop(&mut self) {
        fs::remove_dir_all(&self.0).unwrap();
    }
}

#[test]
fn bundle_progress_is_immediately_readable_and_never_overwrites_an_existing_file() {
    let directory = TestDirectory::new();
    let path = directory.0.join("progress.jsonl");
    let mut writer = JsonlProgressWriter::create(&path).unwrap();
    let mut tracker = ProgressTracker::new(
        JobId::parse("job-001").unwrap(),
        Command::Bundle,
        ProgressOwner::BundleCli,
        &mut writer,
    )
    .unwrap();
    let mut previous = Vec::new();
    for (phase, expected) in [
        (ProgressPhase::HashSources, b"{\"schemaVersion\":1,\"jobId\":\"job-001\",\"sequence\":1,\"command\":\"BUNDLE\",\"phase\":\"HASH_SOURCES\",\"completedUnits\":1,\"totalUnits\":1,\"unit\":\"files\",\"currentItem\":null}\n".as_slice()),
        (ProgressPhase::ParseChart, b"{\"schemaVersion\":1,\"jobId\":\"job-001\",\"sequence\":2,\"command\":\"BUNDLE\",\"phase\":\"PARSE_CHART\",\"completedUnits\":1,\"totalUnits\":1,\"unit\":\"files\",\"currentItem\":null}\n".as_slice()),
        (ProgressPhase::VerifyBundle, b"{\"schemaVersion\":1,\"jobId\":\"job-001\",\"sequence\":3,\"command\":\"BUNDLE\",\"phase\":\"VERIFY_BUNDLE\",\"completedUnits\":1,\"totalUnits\":1,\"unit\":\"files\",\"currentItem\":null}\n".as_slice()),
    ] {
        tracker.emit(phase, 1, 1, "files".to_owned(), None).unwrap();
        previous.extend_from_slice(expected);
        assert_eq!(fs::read(&path).unwrap(), previous);
        assert!(JsonlProgressWriter::create(&path).is_err());
        assert_eq!(fs::read(&path).unwrap(), previous);
    }
}

#[test]
fn failed_progress_write_cannot_be_retried_with_an_ambiguous_sequence() {
    use open2jam_core::error::{CoreError, ErrorCode};
    use open2jam_core::progress::{ProgressEventV1, ProgressSink};

    struct InterruptedSink {
        writes: usize,
    }
    impl ProgressSink for InterruptedSink {
        fn write(&mut self, _: &ProgressEventV1) -> Result<(), CoreError> {
            self.writes += 1;
            if self.writes == 1 {
                // A filesystem error can occur after part or all of a line was written.
                Err(CoreError::new(
                    ErrorCode::OutOfSpace,
                    "injected partial write",
                ))
            } else {
                Ok(())
            }
        }
    }
    let mut sink = InterruptedSink { writes: 0 };
    let mut tracker = ProgressTracker::new(
        JobId::parse("job-001").unwrap(),
        Command::Bundle,
        ProgressOwner::BundleCli,
        &mut sink,
    )
    .unwrap();
    let first = tracker
        .emit(ProgressPhase::HashSources, 0, 1, "files".to_owned(), None)
        .unwrap_err();
    assert_eq!(first.code(), ErrorCode::OutOfSpace);
    assert!(
        tracker
            .emit(ProgressPhase::HashSources, 1, 1, "files".to_owned(), None)
            .is_err()
    );
    drop(tracker);
    assert_eq!(sink.writes, 1);
}

#[test]
fn each_owner_can_publish_only_its_phases_without_consuming_sequence_on_rejection() {
    use open2jam_core::progress::ProgressPhase::*;
    let all = [
        DiscoverSources,
        FingerprintSources,
        ParseSources,
        WriteCatalog,
        CatalogReady,
        CheckCache,
        HashSources,
        ParseChart,
        CompileTiming,
        PrepareAudio,
        WriteBundle,
        VerifyBundle,
        PreloadStartupAudio,
        CreateGameplay,
        Ready,
    ];
    for (owner, command, allowed) in [
        (
            ProgressOwner::CatalogCli,
            Command::Catalog,
            vec![
                DiscoverSources,
                FingerprintSources,
                ParseSources,
                WriteCatalog,
                CatalogReady,
            ],
        ),
        (
            ProgressOwner::BundleCli,
            Command::Bundle,
            vec![
                HashSources,
                ParseChart,
                CompileTiming,
                PrepareAudio,
                WriteBundle,
                VerifyBundle,
            ],
        ),
        (
            ProgressOwner::GodotGameplay,
            Command::Bundle,
            vec![
                CheckCache,
                HashSources,
                ParseChart,
                CompileTiming,
                PrepareAudio,
                WriteBundle,
                VerifyBundle,
                PreloadStartupAudio,
                CreateGameplay,
                Ready,
            ],
        ),
    ] {
        let directory = TestDirectory::new();
        let path = directory.0.join("progress.jsonl");
        let mut writer = JsonlProgressWriter::create(&path).unwrap();
        let wrong_command = if command == Command::Catalog {
            Command::Bundle
        } else {
            Command::Catalog
        };
        assert!(
            ProgressTracker::new(
                JobId::parse("owner-test").unwrap(),
                wrong_command,
                owner,
                &mut writer
            )
            .is_err()
        );
        let mut tracker = ProgressTracker::new(
            JobId::parse("owner-test").unwrap(),
            command,
            owner,
            &mut writer,
        )
        .unwrap();
        let mut expected_sequence = 0;
        for phase in all {
            let before = fs::read(&path).unwrap();
            let emitted = tracker.emit(phase, 0, 0, "items".to_owned(), None);
            if allowed.contains(&phase) {
                emitted.unwrap();
                expected_sequence += 1;
                let text = fs::read_to_string(&path).unwrap();
                let line: serde_json::Value =
                    serde_json::from_str(text.lines().last().unwrap()).unwrap();
                assert_eq!(line["sequence"], expected_sequence);
                assert_eq!(line["jobId"], "owner-test");
                assert_eq!(line["command"], command.as_str());
            } else {
                assert!(emitted.is_err(), "accepted {owner:?}: {phase:?}");
                assert_eq!(fs::read(&path).unwrap(), before);
            }
        }
    }
}

#[test]
fn malformed_progress_cannot_bypass_wire_validation() {
    use open2jam_core::json::decode_contract;
    use open2jam_core::progress::ProgressEventV1;
    use serde_json::json;
    let valid = json!({"schemaVersion":1,"jobId":"job-001","sequence":1,"command":"BUNDLE",
        "phase":"HASH_SOURCES","completedUnits":0,"totalUnits":1,"unit":"files","currentItem":null});
    let event: ProgressEventV1 = decode_contract(&serde_json::to_vec(&valid).unwrap()).unwrap();
    assert_eq!(event.schema_version(), 1);
    assert_eq!(event.job_id().as_str(), "job-001");
    assert_eq!(event.sequence(), 1);
    assert_eq!(event.command(), Command::Bundle);
    assert_eq!(event.phase(), ProgressPhase::HashSources);
    assert_eq!((event.completed_units(), event.total_units()), (0, 1));
    assert_eq!(event.unit(), "files");
    assert_eq!(event.current_item(), None);
    for (field, value) in [
        ("schemaVersion", json!(2)),
        ("sequence", json!(0)),
        ("sequence", json!(-1)),
        ("completedUnits", json!(2)),
        ("unit", json!("")),
        ("unit", json!("f\0iles")),
        ("currentItem", json!("a\0b")),
        ("phase", json!("UNKNOWN")),
        ("extra", json!(true)),
    ] {
        let mut malformed = valid.clone();
        malformed[field] = value;
        assert!(
            decode_contract::<ProgressEventV1>(&serde_json::to_vec(&malformed).unwrap()).is_err(),
            "accepted {malformed}"
        );
    }
    let bytes = serde_json::to_string(&valid).unwrap();
    let duplicate = bytes.replacen('{', "{\"sequence\":9,", 1);
    assert!(decode_contract::<ProgressEventV1>(duplicate.as_bytes()).is_err());
}

#[test]
fn rejected_counts_and_units_leave_the_stream_unchanged() {
    let directory = TestDirectory::new();
    let path = directory.0.join("progress.jsonl");
    let mut writer = JsonlProgressWriter::create(&path).unwrap();
    let mut tracker = ProgressTracker::new(
        JobId::parse("job-001").unwrap(),
        Command::Bundle,
        ProgressOwner::BundleCli,
        &mut writer,
    )
    .unwrap();
    for (completed, total, unit) in [(2, 1, "files"), (0, 1, ""), (0, 1, "a\0b")] {
        assert!(
            tracker
                .emit(
                    ProgressPhase::HashSources,
                    completed,
                    total,
                    unit.to_owned(),
                    None
                )
                .is_err()
        );
        assert!(fs::read(&path).unwrap().is_empty());
    }
    tracker
        .emit(ProgressPhase::HashSources, 1, 1, "files".to_owned(), None)
        .unwrap();
    let value: serde_json::Value = serde_json::from_slice(&fs::read(&path).unwrap()).unwrap();
    assert_eq!(value["sequence"], 1);
}

#[cfg(unix)]
#[test]
fn progress_creation_never_follows_an_existing_symlink() {
    let directory = TestDirectory::new();
    let target = directory.0.join("target");
    let link = directory.0.join("progress.jsonl");
    std::os::unix::fs::symlink(&target, &link).unwrap();
    assert!(JsonlProgressWriter::create(&link).is_err());
    assert!(!target.exists());
    fs::write(&target, b"keep").unwrap();
    assert!(JsonlProgressWriter::create(&link).is_err());
    assert_eq!(fs::read(&target).unwrap(), b"keep");
}

#[test]
fn progress_schema_mismatch_retains_unsupported_schema_error_code() {
    use open2jam_core::error::ErrorCode;
    use open2jam_core::json::decode_contract;
    use open2jam_core::progress::ProgressEventV1;
    let bytes = br#"{"schemaVersion":2,"jobId":"job-001","sequence":1,"command":"BUNDLE","phase":"HASH_SOURCES","completedUnits":0,"totalUnits":1,"unit":"files","currentItem":null}"#;
    assert_eq!(
        decode_contract::<ProgressEventV1>(bytes)
            .unwrap_err()
            .code(),
        ErrorCode::UnsupportedSchema
    );
    assert!(serde_json::from_slice::<ProgressEventV1>(bytes).is_err());
}
