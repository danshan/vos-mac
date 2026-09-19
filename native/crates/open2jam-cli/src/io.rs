use std::fs::{self, File, OpenOptions};
use std::io::{Read, Write};
use std::path::{Component, Path, PathBuf};

use open2jam_core::error::{CoreError, ErrorCode, ProtocolError};
use open2jam_core::id::JobId;
use open2jam_core::json::{Contract, decode_contract, encode_contract};
use open2jam_core::protocol::{Command, CommandResultV1};
use serde::{Serialize, de::DeserializeOwned};

use crate::args::JobFiles;

const MAX_REQUEST_BYTES: u64 = 1024 * 1024;

fn invalid(message: &str) -> ProtocolError {
    CoreError::new(ErrorCode::InvalidRequest, message).into()
}
fn internal_io(source: std::io::Error) -> ProtocolError {
    ProtocolError::Io {
        code: ErrorCode::InternalError,
        source,
    }
}

fn checked_path(path: &Path, input: bool) -> Result<PathBuf, ProtocolError> {
    if !path.is_absolute() || path.components().any(|c| matches!(c, Component::ParentDir)) {
        return Err(invalid(
            "transport paths must be absolute without traversal",
        ));
    }
    let parent = path
        .parent()
        .ok_or_else(|| invalid("transport path has no parent"))?;
    let name = path
        .file_name()
        .ok_or_else(|| invalid("transport path has no filename"))?;
    let metadata =
        fs::symlink_metadata(parent).map_err(|_| invalid("transport parent is unavailable"))?;
    if !metadata.is_dir() || metadata.file_type().is_symlink() {
        return Err(invalid("transport parent must be a non-symlink directory"));
    }
    match fs::symlink_metadata(path) {
        Ok(metadata) if input && metadata.is_file() && !metadata.file_type().is_symlink() => {}
        Err(error) if !input && error.kind() == std::io::ErrorKind::NotFound => {}
        _ => {
            return Err(invalid(
                "transport input must be regular and outputs must be absent",
            ));
        }
    }
    Ok(parent.canonicalize().map_err(internal_io)?.join(name))
}

pub fn validate_job_files(files: &JobFiles) -> Result<JobFiles, ProtocolError> {
    let files = JobFiles {
        request: checked_path(&files.request, true)?,
        progress: checked_path(&files.progress, false)?,
        result: checked_path(&files.result, false)?,
    };
    if files.request == files.progress
        || files.request == files.result
        || files.progress == files.result
    {
        return Err(invalid("transport paths must be distinct"));
    }
    Ok(files)
}

fn read_request_bytes(path: &Path) -> Result<Vec<u8>, ProtocolError> {
    let file = File::open(path).map_err(|source| ProtocolError::Io {
        code: ErrorCode::InvalidRequest,
        source,
    })?;
    let mut bytes = Vec::new();
    file.take(MAX_REQUEST_BYTES + 1)
        .read_to_end(&mut bytes)
        .map_err(|source| ProtocolError::Io {
            code: ErrorCode::InvalidRequest,
            source,
        })?;
    if bytes.len() as u64 > MAX_REQUEST_BYTES {
        return Err(invalid("request exceeds 1 MiB"));
    }
    Ok(bytes)
}

pub fn read_request<T: Contract>(path: &Path) -> Result<T, ProtocolError> {
    decode_contract(&read_request_bytes(path)?)
}

pub(crate) fn read_request_document<T: DeserializeOwned>(path: &Path) -> Result<T, ProtocolError> {
    serde_json::from_slice(&read_request_bytes(path)?).map_err(|source| ProtocolError::Json {
        code: ErrorCode::InvalidRequest,
        source,
    })
}

#[derive(Debug, Clone)]
pub enum ResultTempScope {
    Job(JobId),
    Protocol(Command),
}

pub struct AtomicResultWriter {
    requested_path: PathBuf,
    private_path: PathBuf,
    file: File,
    scope: ResultTempScope,
    private_owned: bool,
}

impl AtomicResultWriter {
    pub fn reserve(requested_path: &Path, scope: &ResultTempScope) -> Result<Self, ProtocolError> {
        let requested_path = checked_path(requested_path, false)?;
        let mut name = std::ffi::OsString::from(".");
        name.push(
            requested_path
                .file_name()
                .ok_or_else(|| invalid("result filename missing"))?,
        );
        name.push(match scope {
            ResultTempScope::Job(job) => format!(".{}.tmp", job.as_str()),
            ResultTempScope::Protocol(command) => {
                format!(".protocol-{}.tmp", command.as_str().to_ascii_lowercase())
            }
        });
        let private_path = requested_path.with_file_name(name);
        let file = OpenOptions::new()
            .write(true)
            .create_new(true)
            .open(&private_path)
            .map_err(internal_io)?;
        Ok(Self {
            requested_path,
            private_path,
            file,
            scope: scope.clone(),
            private_owned: true,
        })
    }

    pub fn publish<T: Serialize + DeserializeOwned>(
        self,
        result: &CommandResultV1<T>,
    ) -> Result<(), ProtocolError> {
        self.publish_with(result, &StdResultPublicationFs)
    }

    pub fn publish_with<T: Serialize + DeserializeOwned>(
        mut self,
        result: &CommandResultV1<T>,
        publication: &dyn ResultPublicationFs,
    ) -> Result<(), ProtocolError> {
        let scope_matches = match &self.scope {
            ResultTempScope::Job(job) => result.job_id.as_ref() == Some(job),
            ResultTempScope::Protocol(command) => {
                result.job_id.is_none() && result.command == *command
            }
        };
        if !scope_matches {
            return Err(invalid("result does not match reserved scope"));
        }
        let bytes = encode_contract(result)?;
        self.file
            .write_all(&bytes)
            .and_then(|()| self.file.sync_all())
            .map_err(internal_io)?;
        publication
            .hard_link(&self.private_path, &self.requested_path)
            .map_err(internal_io)?;
        // After publication the complete result belongs to the caller, even on later failure.
        let parent = self.requested_path.parent().expect("validated parent");
        let mut finish = || -> std::io::Result<()> {
            publication.sync_parent(parent)?;
            publication.remove_private(&self.private_path)?;
            self.private_owned = false;
            publication.sync_parent(parent)
        };
        finish().map_err(|error| {
            CoreError::new(
                ErrorCode::InternalError,
                format!("result publication finalization failed: {error}"),
            )
            .with_context("resultPublished", "true")
            .into()
        })
    }
}
impl Drop for AtomicResultWriter {
    fn drop(&mut self) {
        if self.private_owned {
            let _ = fs::remove_file(&self.private_path);
        }
    }
}

pub trait ResultPublicationFs {
    fn hard_link(&self, private_path: &Path, requested_path: &Path) -> std::io::Result<()>;
    fn sync_parent(&self, parent: &Path) -> std::io::Result<()>;
    fn remove_private(&self, private_path: &Path) -> std::io::Result<()>;
}

pub struct StdResultPublicationFs;
impl ResultPublicationFs for StdResultPublicationFs {
    fn hard_link(&self, private_path: &Path, requested_path: &Path) -> std::io::Result<()> {
        fs::hard_link(private_path, requested_path)
    }
    fn sync_parent(&self, parent: &Path) -> std::io::Result<()> {
        File::open(parent)?.sync_all()
    }
    fn remove_private(&self, private_path: &Path) -> std::io::Result<()> {
        fs::remove_file(private_path)
    }
}
