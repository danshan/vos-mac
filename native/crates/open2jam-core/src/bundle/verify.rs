use super::{BundleManifestV2, manifest::MAX_FILES};
use crate::{
    digest::Digest, error::ErrorCode, id::BundleKey, json::decode_contract,
    path::BundleRelativePath,
};
use sha2::{Digest as _, Sha256};
use std::{
    collections::{BTreeMap, BTreeSet},
    fmt,
    fs::{self, File},
    io::Read,
    path::{Path, PathBuf},
};

const MAX_MANIFEST_BYTES: u64 = 1024 * 1024;

#[derive(Debug)]
pub struct BundleValidationError {
    pub code: ErrorCode,
    pub message: String,
    pub relative_path: Option<BundleRelativePath>,
}
impl fmt::Display for BundleValidationError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}: {}", self.code.as_str(), self.message)
    }
}
impl std::error::Error for BundleValidationError {}
fn corrupt(message: impl Into<String>) -> BundleValidationError {
    BundleValidationError {
        code: ErrorCode::CacheCorrupt,
        message: message.into(),
        relative_path: None,
    }
}
fn io_error(error: std::io::Error) -> BundleValidationError {
    corrupt(format!("bundle I/O failed: {error}"))
}

/// A manifest and file-integrity audit, not a gameplay-readiness proof.
/// Gameplay/audio schema validation belongs to the consumer. Paths can change
/// after this audit; callers must keep staging ownership until consumption.
#[derive(Debug)]
pub struct VerifiedBundle {
    root: PathBuf,
    manifest: BundleManifestV2,
}
impl VerifiedBundle {
    pub fn root(&self) -> &Path {
        &self.root
    }
    pub fn manifest(&self) -> &BundleManifestV2 {
        &self.manifest
    }
    pub fn into_parts(self) -> (PathBuf, BundleManifestV2) {
        (self.root, self.manifest)
    }
}

pub fn verify_bundle(
    root: &Path,
    expected_key: Option<&BundleKey>,
) -> Result<VerifiedBundle, BundleValidationError> {
    let metadata = fs::symlink_metadata(root).map_err(io_error)?;
    if !metadata.is_dir() || metadata.file_type().is_symlink() {
        return Err(corrupt("bundle root must be a non-symlink directory"));
    }
    let root = root.canonicalize().map_err(io_error)?;
    let manifest_path = root.join("bundle.json");
    let metadata = fs::symlink_metadata(&manifest_path).map_err(io_error)?;
    if !metadata.is_file()
        || metadata.file_type().is_symlink()
        || metadata.len() > MAX_MANIFEST_BYTES
    {
        return Err(corrupt("manifest must be a regular file of at most 1 MiB"));
    }
    let mut bytes = Vec::new();
    File::open(manifest_path)
        .map_err(io_error)?
        .take(MAX_MANIFEST_BYTES + 1)
        .read_to_end(&mut bytes)
        .map_err(io_error)?;
    if bytes.len() as u64 > MAX_MANIFEST_BYTES {
        return Err(corrupt("manifest exceeds 1 MiB"));
    }
    let manifest: BundleManifestV2 =
        decode_contract(&bytes).map_err(|error| BundleValidationError {
            code: if error.code() == ErrorCode::UnsupportedSchema {
                ErrorCode::UnsupportedSchema
            } else {
                ErrorCode::CacheCorrupt
            },
            message: error.to_string(),
            relative_path: None,
        })?;
    if expected_key.is_some_and(|key| key != manifest.bundle_key()) {
        return Err(corrupt("unexpected bundle key"));
    }
    let files: BTreeMap<_, _> = manifest
        .files()
        .iter()
        .map(|f| (f.path.as_str(), f))
        .collect();
    let mut directories = BTreeSet::new();
    for path in files.keys() {
        for (index, _) in path.match_indices('/') {
            directories.insert(&path[..index]);
        }
    }
    let mut stack = vec![root.clone()];
    let mut seen = BTreeSet::new();
    let mut entries = 0;
    while let Some(directory) = stack.pop() {
        for entry in fs::read_dir(directory).map_err(io_error)? {
            let entry = entry.map_err(io_error)?;
            entries += 1;
            if entries > MAX_FILES + directories.len() + 1 {
                return Err(corrupt("bundle contains too many entries"));
            }
            let path = entry.path();
            let relative = path
                .strip_prefix(&root)
                .map_err(|_| corrupt("bundle path escaped root"))?
                .to_str()
                .ok_or_else(|| corrupt("non-UTF-8 bundle path"))?
                .replace(std::path::MAIN_SEPARATOR, "/");
            let metadata = fs::symlink_metadata(&path).map_err(io_error)?;
            if metadata.file_type().is_symlink() {
                return Err(corrupt("bundle symlinks are forbidden"));
            }
            if metadata.is_dir() {
                if !directories.contains(relative.as_str()) {
                    return Err(corrupt("extra bundle directory"));
                }
                stack.push(path);
            } else if metadata.is_file() {
                if relative == "bundle.json" {
                    continue;
                }
                let file = files
                    .get(relative.as_str())
                    .ok_or_else(|| corrupt("extra bundle file"))?;
                let verified = verify_file(&path, metadata.len(), file.size_bytes, &file.sha256);
                if let Err(mut error) = verified {
                    error.relative_path = Some(file.path.clone());
                    return Err(error);
                }
                seen.insert(relative);
            } else {
                return Err(corrupt("non-regular bundle entry"));
            }
        }
    }
    if seen.len() != files.len() {
        return Err(corrupt("bundle file missing"));
    }
    Ok(VerifiedBundle { root, manifest })
}

fn verify_file(
    path: &Path,
    actual_size: u64,
    expected_size: u64,
    expected_hash: &Digest,
) -> Result<(), BundleValidationError> {
    if actual_size != expected_size {
        return Err(corrupt("bundle file size mismatch"));
    }
    let mut file = File::open(path).map_err(io_error)?;
    let mut hash = Sha256::new();
    let mut buffer = [0; 64 * 1024];
    let mut size = 0_u64;
    loop {
        let count = file.read(&mut buffer).map_err(io_error)?;
        if count == 0 {
            break;
        }
        size = size
            .checked_add(count as u64)
            .ok_or_else(|| corrupt("bundle file size overflow"))?;
        if size > expected_size {
            return Err(corrupt("bundle file grew during verification"));
        }
        hash.update(&buffer[..count]);
    }
    if size != expected_size || Digest::from_bytes(hash.finalize().into()) != *expected_hash {
        return Err(corrupt("bundle file hash or size mismatch"));
    }
    Ok(())
}
