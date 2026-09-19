use std::fs;
use std::path::PathBuf;
use std::sync::atomic::{AtomicU64, Ordering};

use open2jam_cli::io::{AtomicResultWriter, ResultTempScope};
use open2jam_core::error::{CoreError, ErrorCode};
use open2jam_core::id::JobId;
use open2jam_core::json::decode_contract;
use open2jam_core::protocol::{CatalogOutputV1, Command, CommandResultV1};

static NEXT_CASE: AtomicU64 = AtomicU64::new(0);
struct Case(PathBuf);
impl Case {
    fn new() -> Self {
        let path = std::env::temp_dir().join(format!(
            "native-result-{}-{}",
            std::process::id(),
            NEXT_CASE.fetch_add(1, Ordering::Relaxed)
        ));
        fs::create_dir(&path).unwrap();
        Self(path)
    }
    fn result(&self) -> PathBuf {
        self.0.join("result.json")
    }
    fn private(&self) -> PathBuf {
        self.0.join(".result.json.job-001.tmp")
    }
    fn reserve(&self) -> AtomicResultWriter {
        AtomicResultWriter::reserve(
            &self.result(),
            &ResultTempScope::Job(JobId::parse("job-001").unwrap()),
        )
        .unwrap()
    }
}
impl Drop for Case {
    fn drop(&mut self) {
        fs::remove_dir_all(&self.0).unwrap();
    }
}
fn result() -> CommandResultV1<CatalogOutputV1> {
    CommandResultV1::failed(
        JobId::parse("job-001").unwrap(),
        Command::Catalog,
        CoreError::new(ErrorCode::UnsupportedFormat, "disabled").into(),
    )
}

#[test]
fn reservation_is_private_and_publication_is_complete() {
    let case = Case::new();
    let writer = case.reserve();
    assert!(!case.result().exists());
    assert!(case.private().exists());
    writer.publish(&result()).unwrap();
    let bytes = fs::read(case.result()).unwrap();
    assert!(bytes.ends_with(b"\n"));
    assert_eq!(
        decode_contract::<CommandResultV1<CatalogOutputV1>>(&bytes).unwrap(),
        result()
    );
    assert!(!case.private().exists());
}

#[test]
fn racing_result_is_preserved_and_only_private_output_is_cleaned() {
    let case = Case::new();
    let writer = case.reserve();
    fs::write(case.result(), b"racing caller result").unwrap();
    assert!(writer.publish(&result()).is_err());
    assert_eq!(fs::read(case.result()).unwrap(), b"racing caller result");
    assert!(!case.private().exists());
}

#[test]
fn existing_private_transport_is_not_owned_or_removed() {
    let case = Case::new();
    fs::write(case.private(), b"another job").unwrap();
    assert!(
        AtomicResultWriter::reserve(
            &case.result(),
            &ResultTempScope::Job(JobId::parse("job-001").unwrap())
        )
        .is_err()
    );
    assert_eq!(fs::read(case.private()).unwrap(), b"another job");
    assert!(!case.result().exists());
}

#[test]
fn publication_failures_preserve_the_correct_side_of_the_ownership_boundary() {
    use open2jam_cli::io::ResultPublicationFs;
    use std::cell::Cell;
    use std::io;
    use std::path::Path;

    struct FaultFs {
        fail_at: usize,
        calls: Cell<usize>,
    }
    impl FaultFs {
        fn check(&self) -> io::Result<()> {
            let call = self.calls.get() + 1;
            self.calls.set(call);
            if call == self.fail_at {
                Err(io::Error::other("injected publication failure"))
            } else {
                Ok(())
            }
        }
    }
    impl ResultPublicationFs for FaultFs {
        fn hard_link(&self, private: &Path, result: &Path) -> io::Result<()> {
            self.check()?;
            fs::hard_link(private, result)
        }
        fn sync_parent(&self, parent: &Path) -> io::Result<()> {
            self.check()?;
            fs::File::open(parent)?.sync_all()
        }
        fn remove_private(&self, private: &Path) -> io::Result<()> {
            self.check()?;
            fs::remove_file(private)
        }
    }
    for fail_at in 1..=4 {
        let case = Case::new();
        let error = case
            .reserve()
            .publish_with(
                &result(),
                &FaultFs {
                    fail_at,
                    calls: Cell::new(0),
                },
            )
            .unwrap_err();
        assert_eq!(error.code(), ErrorCode::InternalError);
        if fail_at == 1 {
            assert!(!case.result().exists());
        } else {
            let bytes = fs::read(case.result()).unwrap();
            assert_eq!(
                decode_contract::<CommandResultV1<CatalogOutputV1>>(&bytes).unwrap(),
                result()
            );
            let open2jam_core::error::ProtocolError::Invalid(error) = error else {
                panic!("missing publication context")
            };
            assert_eq!(
                error.context().get("resultPublished").map(String::as_str),
                Some("true")
            );
        }
        assert!(!case.private().exists());
    }
}
