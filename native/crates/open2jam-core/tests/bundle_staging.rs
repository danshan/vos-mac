use open2jam_core::{
    bundle::{
        BundleIdentity, BundleStager, CompletionDisposition, SoundFontIdentity, verify_bundle,
    },
    digest::Digest,
    id::{ChartIdentity, JobId, SongId, SourceFingerprint},
    path::BundleRelativePath,
    schema::STATIC_ASSETS_VERSION,
};
use std::{
    fs,
    path::PathBuf,
    sync::atomic::{AtomicU64, Ordering},
};

static NEXT: AtomicU64 = AtomicU64::new(0);
struct Fixture(PathBuf);
impl Fixture {
    fn new() -> Self {
        let root = std::env::temp_dir().join(format!(
            "bundle-staging-{}-{}",
            std::process::id(),
            NEXT.fetch_add(1, Ordering::Relaxed)
        ));
        fs::create_dir(&root).unwrap();
        Self(root.canonicalize().unwrap())
    }
}
impl Drop for Fixture {
    fn drop(&mut self) {
        fs::remove_dir_all(&self.0).unwrap();
    }
}
fn identity() -> BundleIdentity {
    let song = SongId::from_digest(Digest::from_bytes([1; 32]));
    let chart = ChartIdentity::vos(0).unwrap();
    BundleIdentity {
        converter_version: "0.1.0".into(),
        static_assets_version: STATIC_ASSETS_VERSION.into(),
        soundfont: SoundFontIdentity {
            version: "2.0.3".into(),
            sha256: Digest::from_bytes([2; 32]),
        },
        song_id: song,
        chart_id: chart.chart_id(&song),
        chart_selector: chart.selector(),
        source_fingerprint: SourceFingerprint::from_digest(Digest::from_bytes([3; 32])),
    }
}

#[test]
fn only_verified_complete_tree_is_published_and_identical_retry_is_reused() {
    let f = Fixture::new();
    let job = JobId::parse("job-one").unwrap();
    for expected in [
        CompletionDisposition::Published,
        CompletionDisposition::Reused,
    ] {
        let mut stage = BundleStager::create(&f.0, &job, &|| Ok(())).unwrap();
        for name in ["gameplay.json", "audio-manifest.json"] {
            stage
                .write_artifact(
                    BundleRelativePath::parse(name).unwrap(),
                    &mut b"{}\n".as_slice(),
                    &|| Ok(()),
                )
                .unwrap();
        }
        assert!(!stage.private_root().join("bundle.json").exists());
        if expected == CompletionDisposition::Published {
            assert!(!f.0.join("job-one").exists());
        }
        let complete = stage.finalize(identity(), &|| Ok(())).unwrap();
        assert_eq!(complete.disposition(), expected);
        assert_eq!(complete.completed_root(), f.0.join("job-one"));
        assert_eq!(
            verify_bundle(complete.completed_root(), None)
                .unwrap()
                .manifest(),
            complete.manifest()
        );
        assert!(!f.0.join(".partial/job-one").exists());
    }
}

#[test]
fn cancellation_and_reader_failure_never_publish_and_retain_owned_partial() {
    use open2jam_core::error::{CoreError, ErrorCode};
    use std::io::{self, Read};
    let f = Fixture::new();
    let job = JobId::parse("cancelled").unwrap();
    let cancelled = || Err(CoreError::new(ErrorCode::Cancelled, "cancelled"));
    assert!(BundleStager::create(&f.0, &job, &cancelled).is_err());
    assert!(!f.0.join(".partial").exists());
    let mut stage = BundleStager::create(&f.0, &job, &|| Ok(())).unwrap();
    let error = stage
        .write_artifact(
            BundleRelativePath::parse("gameplay.json").unwrap(),
            &mut b"{}".as_slice(),
            &cancelled,
        )
        .unwrap_err();
    assert_eq!(error.code(), ErrorCode::Cancelled);
    assert_eq!(
        error.context()["privatePath"],
        f.0.join(".partial/cancelled").to_str().unwrap()
    );
    assert!(!f.0.join("cancelled").exists());
    assert!(stage.finalize(identity(), &|| Ok(())).is_err());

    struct BrokenReader;
    impl Read for BrokenReader {
        fn read(&mut self, _: &mut [u8]) -> io::Result<usize> {
            Err(io::Error::other("injected source failure"))
        }
    }
    let mut stage =
        BundleStager::create(&f.0, &JobId::parse("broken").unwrap(), &|| Ok(())).unwrap();
    assert!(
        stage
            .write_artifact(
                BundleRelativePath::parse("gameplay.json").unwrap(),
                &mut BrokenReader,
                &|| Ok(())
            )
            .is_err()
    );
    assert!(!stage.private_root().join("gameplay.json").exists());
    assert!(stage.private_root().join(".artifact.tmp").exists());
    assert!(stage.finalize(identity(), &|| Ok(())).is_err());
    assert!(!f.0.join("broken").exists());
}

fn prepared(f: &Fixture, job: &str) -> BundleStager<open2jam_core::bundle::Incomplete> {
    let mut stage = BundleStager::create(&f.0, &JobId::parse(job).unwrap(), &|| Ok(())).unwrap();
    for name in ["audio-manifest.json", "gameplay.json"] {
        stage
            .write_artifact(
                BundleRelativePath::parse(name).unwrap(),
                &mut b"{}\n".as_slice(),
                &|| Ok(()),
            )
            .unwrap();
    }
    stage
}

#[test]
fn cancellation_before_manifest_and_before_rename_keeps_completed_namespace_absent() {
    use open2jam_core::error::{CoreError, ErrorCode};
    use std::cell::Cell;
    for stop in [1, 2] {
        let f = Fixture::new();
        let stage = prepared(&f, "finalize");
        let calls = Cell::new(0);
        let cancel = || {
            calls.set(calls.get() + 1);
            if calls.get() == stop {
                Err(CoreError::new(ErrorCode::Cancelled, "cancelled"))
            } else {
                Ok(())
            }
        };
        assert!(stage.finalize(identity(), &cancel).is_err());
        assert!(!f.0.join("finalize").exists());
        assert!(f.0.join(".partial/finalize").is_dir());
        assert_eq!(
            f.0.join(".partial/finalize/bundle.json").exists(),
            stop == 2
        );
    }
}

#[test]
fn existing_corrupt_or_different_completed_tree_is_never_replaced() {
    use open2jam_core::error::ErrorCode;
    let f = Fixture::new();
    prepared(&f, "same-job")
        .finalize(identity(), &|| Ok(()))
        .unwrap();
    let before = fs::read(f.0.join("same-job/bundle.json")).unwrap();
    let mut different = identity();
    different.converter_version = "different".into();
    let error = prepared(&f, "same-job")
        .finalize(different, &|| Ok(()))
        .err()
        .unwrap();
    assert_eq!(error.code(), ErrorCode::InternalError);
    assert_eq!(fs::read(f.0.join("same-job/bundle.json")).unwrap(), before);
    assert!(f.0.join(".partial/same-job").exists());
    fs::remove_dir_all(f.0.join(".partial/same-job")).unwrap();
    fs::write(f.0.join("same-job/gameplay.json"), b"corrupt").unwrap();
    let error = prepared(&f, "same-job")
        .finalize(identity(), &|| Ok(()))
        .err()
        .unwrap();
    assert_eq!(error.code(), ErrorCode::CacheCorrupt);
    assert_eq!(
        fs::read(f.0.join("same-job/gameplay.json")).unwrap(),
        b"corrupt"
    );
}

#[test]
fn stale_cleanup_is_scoped_idempotent_and_refuses_links_before_deleting() {
    use open2jam_core::bundle::cleanup_stale_job;
    let f = Fixture::new();
    let job = JobId::parse("stale").unwrap();
    prepared(&f, "stale")
        .finalize(identity(), &|| Ok(()))
        .unwrap();
    let _partial = prepared(&f, "stale");
    fs::create_dir(f.0.join("artifacts")).unwrap();
    fs::write(f.0.join("artifacts/keep"), b"keep").unwrap();
    let _other = prepared(&f, "other");
    #[cfg(unix)]
    {
        std::os::unix::fs::symlink(f.0.join("artifacts"), f.0.join(".partial/stale/link")).unwrap();
        assert!(cleanup_stale_job(&f.0, &job).is_err());
        assert!(f.0.join("stale/bundle.json").exists());
        fs::remove_file(f.0.join(".partial/stale/link")).unwrap();
    }
    cleanup_stale_job(&f.0, &job).unwrap();
    cleanup_stale_job(&f.0, &job).unwrap();
    assert!(!f.0.join("stale").exists());
    assert!(!f.0.join(".partial/stale").exists());
    assert!(f.0.join(".partial/other/gameplay.json").exists());
    assert_eq!(fs::read(f.0.join("artifacts/keep")).unwrap(), b"keep");
}

#[test]
fn artifact_cache_namespace_cannot_be_used_as_a_job() {
    use open2jam_core::bundle::cleanup_stale_job;
    let f = Fixture::new();
    fs::create_dir(f.0.join("artifacts")).unwrap();
    fs::write(f.0.join("artifacts/keep"), b"keep").unwrap();
    for name in ["artifacts", "ARTIFACTS"] {
        let job = JobId::parse(name).unwrap();
        assert!(BundleStager::create(&f.0, &job, &|| Ok(())).is_err());
        assert!(cleanup_stale_job(&f.0, &job).is_err());
    }
    assert_eq!(fs::read(f.0.join("artifacts/keep")).unwrap(), b"keep");
}

#[test]
fn process_interruption_leaves_private_tree_or_verified_completed_orphan() {
    use std::{cell::Cell, process::Command};
    if let Ok(root) = std::env::var("OPEN2JAM_STAGING_CRASH_FIXTURE") {
        let f = Fixture(PathBuf::from(root));
        let stage = prepared(&f, "interrupted");
        let before = std::env::var("OPEN2JAM_STAGING_CRASH_POINT").unwrap() == "before";
        let calls = Cell::new(0);
        let checkpoint = || {
            calls.set(calls.get() + 1);
            if before && calls.get() == 2 {
                std::process::exit(17);
            }
            Ok(())
        };
        stage.finalize(identity(), &checkpoint).unwrap();
        std::process::exit(18);
    }
    for point in ["before", "after"] {
        let f = Fixture::new();
        let result = Command::new(std::env::current_exe().unwrap())
            .args([
                "--exact",
                "process_interruption_leaves_private_tree_or_verified_completed_orphan",
            ])
            .env("OPEN2JAM_STAGING_CRASH_FIXTURE", &f.0)
            .env("OPEN2JAM_STAGING_CRASH_POINT", point)
            .output()
            .unwrap();
        assert_eq!(
            result.status.code(),
            Some(if point == "before" { 17 } else { 18 })
        );
        assert_eq!(f.0.join("interrupted").exists(), point == "after");
        assert_eq!(f.0.join(".partial/interrupted").exists(), point == "before");
        if point == "after" {
            verify_bundle(&f.0.join("interrupted"), None).unwrap();
            let retried = prepared(&f, "interrupted")
                .finalize(identity(), &|| Ok(()))
                .unwrap();
            assert_eq!(retried.disposition(), CompletionDisposition::Reused);
        } else {
            verify_bundle(&f.0.join(".partial/interrupted"), None).unwrap();
        }
    }
}

#[test]
fn cancellation_between_stream_chunks_does_not_publish_partial_artifact() {
    use open2jam_core::error::{CoreError, ErrorCode};
    use std::{
        cell::Cell,
        io::{self, Read},
    };
    let f = Fixture::new();
    let read = Cell::new(false);
    struct Chunk<'a>(&'a Cell<bool>);
    impl Read for Chunk<'_> {
        fn read(&mut self, buffer: &mut [u8]) -> io::Result<usize> {
            self.0.set(true);
            buffer.fill(7);
            Ok(buffer.len())
        }
    }
    let mut stage =
        BundleStager::create(&f.0, &JobId::parse("chunk").unwrap(), &|| Ok(())).unwrap();
    let cancel = || {
        if read.get() {
            Err(CoreError::new(ErrorCode::Cancelled, "cancelled"))
        } else {
            Ok(())
        }
    };
    let error = stage
        .write_artifact(
            BundleRelativePath::parse("audio/sample.wav").unwrap(),
            &mut Chunk(&read),
            &cancel,
        )
        .unwrap_err();
    assert_eq!(error.code(), ErrorCode::Cancelled);
    assert!(!stage.private_root().join("audio/sample.wav").exists());
    assert_eq!(
        fs::metadata(stage.private_root().join(".artifact.tmp"))
            .unwrap()
            .len(),
        64 * 1024
    );
    assert!(!f.0.join("chunk").exists());
}
