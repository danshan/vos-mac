use super::{BundleFile, BundleIdentity, BundleManifestV2, VerifiedBundle, verify_bundle};
use crate::{
    digest::Digest,
    error::{CoreError, ErrorCode},
    id::{BundleKey, JobId},
    json::encode_contract,
    path::BundleRelativePath,
};
use sha2::{Digest as _, Sha256};
use std::{
    fs::{self, File, OpenOptions},
    io::{Read, Write},
    path::{Path, PathBuf},
};

/// Called before filesystem transitions and between bounded streaming chunks.
pub type CancellationCheck<'a> = dyn Fn() -> Result<(), CoreError> + 'a;

pub struct BundleStager<State> {
    state: State,
}
pub struct Incomplete {
    private_root: PathBuf,
    completed_root: PathBuf,
    files: Vec<BundleFile>,
    failed: bool,
}
pub struct Complete {
    verified: VerifiedBundle,
    disposition: CompletionDisposition,
}
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CompletionDisposition {
    Published,
    Reused,
}

fn io_error(error: std::io::Error) -> CoreError {
    CoreError::new(
        if error.kind() == std::io::ErrorKind::StorageFull {
            ErrorCode::OutOfSpace
        } else {
            ErrorCode::InternalError
        },
        format!("staging I/O failed: {error}"),
    )
}
fn invalid(message: &str) -> CoreError {
    CoreError::new(ErrorCode::InvalidRequest, message)
}
fn validate_job(job: &JobId) -> Result<(), CoreError> {
    if job.as_str().eq_ignore_ascii_case("artifacts") {
        return Err(invalid("artifact cache namespace is reserved"));
    }
    Ok(())
}
fn directory(path: &Path) -> Result<(), CoreError> {
    let metadata = fs::symlink_metadata(path).map_err(io_error)?;
    if !metadata.is_dir() || metadata.file_type().is_symlink() {
        return Err(invalid("staging directory must not be a symlink"));
    }
    Ok(())
}
fn ensure_directory(path: &Path) -> Result<(), CoreError> {
    match fs::create_dir(path) {
        Ok(()) => Ok(()),
        Err(error) if error.kind() == std::io::ErrorKind::AlreadyExists => directory(path),
        Err(error) => Err(io_error(error)),
    }
}
fn validation_error(error: super::BundleValidationError) -> CoreError {
    CoreError::new(error.code, error.message)
}

impl BundleStager<Incomplete> {
    /// The coordinator owns this namespace exclusively, including rename and cleanup.
    /// The configured root must already exist; its ancestors resolve before ownership begins.
    pub fn create(
        root: &Path,
        job: &JobId,
        cancel: &CancellationCheck<'_>,
    ) -> Result<Self, CoreError> {
        cancel()?;
        validate_job(job)?;
        directory(root)?;
        let root = root.canonicalize().map_err(io_error)?;
        let partial = root.join(".partial");
        ensure_directory(&partial)?;
        let private_root = partial.join(job.as_str());
        fs::create_dir(&private_root).map_err(io_error)?;
        Ok(Self {
            state: Incomplete {
                private_root,
                completed_root: root.join(job.as_str()),
                files: Vec::new(),
                failed: false,
            },
        })
    }
    pub fn private_root(&self) -> &Path {
        &self.state.private_root
    }
    fn contextual(&self, error: CoreError) -> CoreError {
        error.with_context("privatePath", self.state.private_root.to_string_lossy())
    }
    pub fn write_artifact<R: Read>(
        &mut self,
        path: BundleRelativePath,
        reader: &mut R,
        cancel: &CancellationCheck<'_>,
    ) -> Result<BundleFile, CoreError> {
        let result = self.write_inner(path, reader, cancel);
        if result.is_err() {
            self.state.failed = true;
        }
        result.map_err(|e| self.contextual(e))
    }
    fn write_inner<R: Read>(
        &mut self,
        path: BundleRelativePath,
        reader: &mut R,
        cancel: &CancellationCheck<'_>,
    ) -> Result<BundleFile, CoreError> {
        cancel()?;
        if self.state.failed {
            return Err(invalid("failed staging cannot resume"));
        }
        if path.as_str().eq_ignore_ascii_case("bundle.json") {
            return Err(invalid("manifest is owned by finalize"));
        }
        let target = self.state.private_root.join(path.as_str());
        let mut parent = self.state.private_root.clone();
        let components: Vec<_> = path.as_str().split('/').collect();
        for component in &components[..components.len() - 1] {
            parent.push(component);
            ensure_directory(&parent)?;
        }
        match fs::symlink_metadata(&target) {
            Err(error) if error.kind() == std::io::ErrorKind::NotFound => {}
            _ => return Err(invalid("staged artifact already exists")),
        }
        // One writer owns the private tree. A failed write leaves this temp for recovery.
        let temp = self.state.private_root.join(".artifact.tmp");
        let mut file = OpenOptions::new()
            .write(true)
            .create_new(true)
            .open(&temp)
            .map_err(io_error)?;
        let mut buffer = [0_u8; 64 * 1024];
        let mut hash = Sha256::new();
        let mut size = 0_u64;
        loop {
            cancel()?;
            let count = reader.read(&mut buffer).map_err(io_error)?;
            if count == 0 {
                break;
            }
            size = size
                .checked_add(count as u64)
                .ok_or_else(|| invalid("artifact size overflow"))?;
            file.write_all(&buffer[..count]).map_err(io_error)?;
            hash.update(&buffer[..count]);
        }
        file.sync_all().map_err(io_error)?;
        cancel()?;
        fs::rename(&temp, &target).map_err(io_error)?;
        let entry = BundleFile {
            path,
            size_bytes: size,
            sha256: Digest::from_bytes(hash.finalize().into()),
        };
        self.state.files.push(entry.clone());
        Ok(entry)
    }
    pub fn finalize(
        mut self,
        identity: BundleIdentity,
        cancel: &CancellationCheck<'_>,
    ) -> Result<BundleStager<Complete>, CoreError> {
        self.finalize_inner(identity, cancel)
            .map_err(|e| self.contextual(e))
    }
    fn finalize_inner(
        &mut self,
        identity: BundleIdentity,
        cancel: &CancellationCheck<'_>,
    ) -> Result<BundleStager<Complete>, CoreError> {
        cancel()?;
        if self.state.failed {
            return Err(invalid("failed staging cannot finalize"));
        }
        self.state.files.sort_by(|a, b| a.path.cmp(&b.path));
        let manifest = BundleManifestV2::new(identity, self.state.files.clone())?;
        let bytes =
            encode_contract(&manifest).map_err(|e| CoreError::new(e.code(), e.to_string()))?;
        let mut file = OpenOptions::new()
            .write(true)
            .create_new(true)
            .open(self.state.private_root.join("bundle.json"))
            .map_err(io_error)?;
        file.write_all(&bytes)
            .and_then(|()| file.sync_all())
            .map_err(io_error)?;
        verify_bundle(&self.state.private_root, Some(manifest.bundle_key()))
            .map_err(validation_error)?;
        sync_directories(&self.state.private_root)?;
        cancel()?;
        let disposition = match fs::symlink_metadata(&self.state.completed_root) {
            Ok(_) => {
                let existing =
                    verify_bundle(&self.state.completed_root, None).map_err(validation_error)?;
                if existing.manifest() != &manifest
                    || fs::read(self.state.completed_root.join("bundle.json")).map_err(io_error)?
                        != bytes
                {
                    return Err(CoreError::new(
                        ErrorCode::InternalError,
                        "completed job differs from deterministic output",
                    )
                    .with_context("collision", "true"));
                }
                fs::remove_dir_all(&self.state.private_root).map_err(io_error)?;
                CompletionDisposition::Reused
            }
            Err(error) if error.kind() == std::io::ErrorKind::NotFound => {
                fs::rename(&self.state.private_root, &self.state.completed_root)
                    .map_err(io_error)?;
                CompletionDisposition::Published
            }
            Err(error) => return Err(io_error(error)),
        };
        // A failure after rename leaves a complete orphan, never a successful result.
        let finish = || {
            File::open(self.state.completed_root.parent().expect("owned root"))
                .and_then(|f| f.sync_all())
                .map_err(io_error)?;
            File::open(self.state.private_root.parent().expect("partial parent"))
                .and_then(|f| f.sync_all())
                .map_err(io_error)?;
            verify_bundle(&self.state.completed_root, Some(manifest.bundle_key()))
                .map_err(validation_error)
        };
        let verified = finish().map_err(|e| {
            e.with_context("completedPath", self.state.completed_root.to_string_lossy())
        })?;
        Ok(BundleStager {
            state: Complete {
                verified,
                disposition,
            },
        })
    }
}
fn sync_directories(root: &Path) -> Result<(), CoreError> {
    let mut directories = vec![root.to_owned()];
    let mut index = 0;
    while index < directories.len() {
        for entry in fs::read_dir(&directories[index]).map_err(io_error)? {
            let entry = entry.map_err(io_error)?;
            if entry.file_type().map_err(io_error)?.is_dir() {
                directories.push(entry.path());
            }
        }
        index += 1;
    }
    for path in directories.into_iter().rev() {
        File::open(path)
            .and_then(|f| f.sync_all())
            .map_err(io_error)?;
    }
    Ok(())
}
impl BundleStager<Complete> {
    pub fn disposition(&self) -> CompletionDisposition {
        self.state.disposition
    }
    pub fn verified(&self) -> &VerifiedBundle {
        &self.state.verified
    }
    pub fn completed_root(&self) -> &Path {
        self.state.verified.root()
    }
    pub fn manifest(&self) -> &BundleManifestV2 {
        self.state.verified.manifest()
    }
    pub fn bundle_key(&self) -> &BundleKey {
        self.manifest().bundle_key()
    }
    pub fn into_verified(self) -> VerifiedBundle {
        self.state.verified
    }
}

/// The coordinator must establish that no live generation or helper owns this job.
/// Validate both trees before removing either; reject links and special files.
pub fn cleanup_stale_job(root: &Path, job: &JobId) -> Result<(), CoreError> {
    validate_job(job)?;
    directory(root)?;
    let root = root.canonicalize().map_err(io_error)?;
    let partial = root.join(".partial");
    match fs::symlink_metadata(&partial) {
        Ok(_) => directory(&partial)?,
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => {}
        Err(error) => return Err(io_error(error)),
    }
    let mut files = Vec::new();
    let mut directories = Vec::new();
    for path in [partial.join(job.as_str()), root.join(job.as_str())] {
        match fs::symlink_metadata(&path) {
            Ok(_) => {
                directory(&path)?;
                directories.push(path);
            }
            Err(error) if error.kind() == std::io::ErrorKind::NotFound => {}
            Err(error) => return Err(io_error(error)),
        }
    }
    let mut index = 0;
    while index < directories.len() {
        for entry in fs::read_dir(&directories[index]).map_err(io_error)? {
            let entry = entry.map_err(io_error)?;
            let kind = fs::symlink_metadata(entry.path())
                .map_err(io_error)?
                .file_type();
            if kind.is_symlink() || !(kind.is_file() || kind.is_dir()) {
                return Err(invalid("stale staging contains a link or special file"));
            }
            if kind.is_dir() {
                directories.push(entry.path());
            } else {
                files.push(entry.path());
            }
        }
        index += 1;
    }
    for path in files {
        fs::remove_file(path).map_err(io_error)?;
    }
    for path in directories.into_iter().rev() {
        fs::remove_dir(path).map_err(io_error)?;
    }
    Ok(())
}
