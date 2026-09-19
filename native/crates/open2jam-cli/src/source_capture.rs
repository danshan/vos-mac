use open2jam_core::{
    digest::Digest,
    error::{CoreError, ErrorCode},
    path::{AbsoluteSourcePath, SourceRelativePath},
};
use sha2::{Digest as _, Sha256};
#[cfg(unix)]
use std::os::unix::fs::{MetadataExt, OpenOptionsExt};
use std::{
    fs::{self, File, Metadata, OpenOptions},
    io::Read,
    path::{Path, PathBuf},
};

pub(crate) fn failure(code: ErrorCode, message: &str) -> CoreError {
    CoreError::new(code, message)
}
pub(crate) fn io_error(error: std::io::Error) -> CoreError {
    CoreError::new(
        if error.kind() == std::io::ErrorKind::StorageFull {
            ErrorCode::OutOfSpace
        } else {
            ErrorCode::InternalError
        },
        format!("raw source I/O failed: {error}"),
    )
}
pub(crate) fn cancelled(path: &Path) -> Result<(), CoreError> {
    match fs::symlink_metadata(path) {
        Ok(_) => Err(failure(ErrorCode::Cancelled, "conversion cancelled")),
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => Ok(()),
        Err(error) => Err(io_error(error)),
    }
}
pub(crate) fn source_io_error(error: std::io::Error) -> CoreError {
    if error.kind() == std::io::ErrorKind::NotFound {
        failure(
            ErrorCode::SourceChanged,
            "selected source is no longer available",
        )
    } else {
        io_error(error)
    }
}
pub(crate) fn digest(
    bytes: &[u8],
    cancel: &impl Fn() -> Result<(), CoreError>,
) -> Result<Digest, CoreError> {
    let mut hash = Sha256::new();
    for chunk in bytes.chunks(65536) {
        cancel()?;
        hash.update(chunk);
    }
    Ok(Digest::from_bytes(hash.finalize().into()))
}
pub(crate) fn absolute(path: &Path) -> Result<AbsoluteSourcePath, CoreError> {
    AbsoluteSourcePath::parse(
        path.to_str()
            .ok_or_else(|| failure(ErrorCode::InvalidRequest, "non-UTF-8 source path"))?,
    )
}

pub(crate) struct CapturedSource {
    pub(crate) path: PathBuf,
    file: File,
    metadata: Metadata,
    pub(crate) bytes: Vec<u8>,
    pub(crate) digest: Digest,
}
impl CapturedSource {
    pub(crate) fn read(
        path: PathBuf,
        limit: usize,
        cancel: &impl Fn() -> Result<(), CoreError>,
    ) -> Result<Self, CoreError> {
        cancel()?;
        let metadata = fs::symlink_metadata(&path).map_err(source_io_error)?;
        if !metadata.is_file() || metadata.len() > limit as u64 {
            return Err(failure(
                ErrorCode::CorruptChart,
                "source is not a bounded regular file",
            ));
        }
        let mut options = OpenOptions::new();
        options.read(true);
        #[cfg(unix)]
        options.custom_flags(libc::O_NOFOLLOW | libc::O_NONBLOCK);
        #[cfg(not(unix))]
        return Err(failure(
            ErrorCode::UnsupportedFormat,
            "raw source capture currently requires Unix file identity",
        ));
        let mut file = options.open(&path).map_err(source_io_error)?;
        if !same_metadata(&metadata, &file.metadata().map_err(io_error)?) {
            return Err(failure(
                ErrorCode::SourceChanged,
                "source changed before reading",
            ));
        }
        let mut bytes = Vec::new();
        let mut chunk = [0; 65536];
        loop {
            cancel()?;
            let length = file.read(&mut chunk).map_err(io_error)?;
            if length == 0 {
                break;
            }
            if bytes.len() + length > limit {
                return Err(failure(
                    ErrorCode::SourceChanged,
                    "source grew beyond its input bound",
                ));
            }
            bytes.extend_from_slice(&chunk[..length]);
        }
        let captured = Self {
            path,
            file,
            metadata,
            digest: digest(&bytes, cancel)?,
            bytes,
        };
        captured.verify()?;
        Ok(captured)
    }
    pub(crate) fn verify(&self) -> Result<(), CoreError> {
        let changed = || failure(ErrorCode::SourceChanged, "source changed during conversion");
        let current = fs::symlink_metadata(&self.path).map_err(|_| changed())?;
        let opened = self.file.metadata().map_err(|_| changed())?;
        if !same_metadata(&self.metadata, &current) || !same_metadata(&self.metadata, &opened) {
            return Err(changed());
        }
        Ok(())
    }
}
#[cfg(unix)]
fn same_metadata(a: &Metadata, b: &Metadata) -> bool {
    b.is_file()
        && a.dev() == b.dev()
        && a.ino() == b.ino()
        && a.len() == b.len()
        && a.mtime() == b.mtime()
        && a.mtime_nsec() == b.mtime_nsec()
}
#[cfg(not(unix))]
fn same_metadata(_a: &Metadata, _b: &Metadata) -> bool {
    false
}

pub(crate) fn resolve_file(
    root: &Path,
    relative: &SourceRelativePath,
) -> Result<PathBuf, CoreError> {
    let mut path = root.to_owned();
    for part in relative.as_str().split('/') {
        path.push(part);
        let metadata = fs::symlink_metadata(&path).map_err(source_io_error)?;
        if metadata.file_type().is_symlink() {
            return Err(failure(
                ErrorCode::InvalidRequest,
                "linked source paths are not followed",
            ));
        }
    }
    Ok(path)
}
