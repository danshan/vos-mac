use open2jam_core::{
    bundle::{BundleIdentity, BundleStager, load_bundle_documents},
    error::{CoreError, ErrorCode},
    path::AbsoluteSourcePath,
    progress::{ProgressOwner, ProgressPhase, ProgressSink, ProgressTracker},
    protocol::{BundleOutputV1, BundleRequestV1, Command},
};
use std::{
    fs::{self, File},
    path::Path,
};

fn io_error(error: std::io::Error) -> CoreError {
    CoreError::new(
        ErrorCode::InternalError,
        format!("bundle source I/O failed: {error}"),
    )
}
fn cancelled(path: &Path) -> Result<(), CoreError> {
    match fs::symlink_metadata(path) {
        Ok(_) => Err(CoreError::new(
            ErrorCode::Cancelled,
            "Bundle loading cancelled",
        )),
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => Ok(()),
        Err(error) => Err(io_error(error)),
    }
}

/// Prepared bundles preserve their declared identity and synthesis configuration.
/// No SoundFont is opened: the bundle contains its prepared audio already.
pub fn import_bundle(
    request: &BundleRequestV1,
    sink: &mut dyn ProgressSink,
) -> Result<BundleOutputV1, CoreError> {
    let cancel = || cancelled(request.cancel_marker_path.as_path());
    cancel()?;
    let source = request.source_path.as_path();
    let source_root = source.canonicalize().map_err(io_error)?;
    let staging_root = request
        .staging_root
        .as_path()
        .canonicalize()
        .map_err(io_error)?;
    if staging_root.starts_with(&source_root) || source_root.starts_with(&staging_root) {
        return Err(CoreError::new(
            ErrorCode::InvalidRequest,
            "bundle source and staging roots must be disjoint",
        ));
    }
    let mut progress = ProgressTracker::new(
        request.job_id.clone(),
        Command::Bundle,
        ProgressOwner::BundleCli,
        sink,
    )?;
    progress.emit(ProgressPhase::HashSources, 0, 1, "bundle".into(), None)?;
    let documents =
        load_bundle_documents(source, None).map_err(|e| CoreError::new(e.code, e.message))?;
    let manifest = documents.bundle().manifest();
    if manifest.chart_id() != &request.chart_id {
        return Err(CoreError::new(
            ErrorCode::SourceChanged,
            "selected chart no longer matches bundle",
        ));
    }
    progress.emit(ProgressPhase::HashSources, 1, 1, "bundle".into(), None)?;
    let mut stage = BundleStager::create(request.staging_root.as_path(), &request.job_id, &cancel)?;
    let private_root = stage.private_root().to_owned();
    let completed_root = staging_root.join(request.job_id.as_str());
    let result = (|| {
        let total = manifest.files().len() as u64;
        progress.emit(ProgressPhase::WriteBundle, 0, total, "files".into(), None)?;
        for (index, entry) in manifest.files().iter().enumerate() {
            cancel()?;
            let path = source_root.join(entry.path.as_str());
            let metadata = fs::symlink_metadata(&path).map_err(io_error)?;
            if !metadata.is_file() || metadata.file_type().is_symlink() {
                return Err(CoreError::new(
                    ErrorCode::SourceChanged,
                    "source artifact is no longer a regular file",
                ));
            }
            let actual = stage.write_artifact(
                entry.path.clone(),
                &mut File::open(path).map_err(io_error)?,
                &cancel,
            )?;
            if &actual != entry {
                return Err(CoreError::new(
                    ErrorCode::SourceChanged,
                    "bundle changed while copying",
                )
                .with_context("privatePath", stage.private_root().to_string_lossy()));
            }
            progress.emit(
                ProgressPhase::WriteBundle,
                index as u64 + 1,
                total,
                "files".into(),
                Some(entry.path.as_str().into()),
            )?;
        }
        progress.emit(ProgressPhase::VerifyBundle, 0, 1, "bundle".into(), None)?;
        let complete = stage.finalize(
            BundleIdentity {
                converter_version: manifest.converter_version().into(),
                static_assets_version: manifest.static_assets_version().into(),
                soundfont: manifest.soundfont().clone(),
                song_id: *manifest.song_id(),
                chart_id: *manifest.chart_id(),
                chart_selector: manifest.chart_selector().clone(),
                source_fingerprint: *manifest.source_fingerprint(),
            },
            &cancel,
        )?;
        cancel()?;
        load_bundle_documents(complete.completed_root(), Some(complete.bundle_key()))
            .map_err(|e| CoreError::new(e.code, e.message))?;
        progress.emit(ProgressPhase::VerifyBundle, 1, 1, "bundle".into(), None)?;
        cancel()?;
        let absolute = |path: &Path| {
            AbsoluteSourcePath::parse(path.to_str().ok_or_else(|| {
                CoreError::new(ErrorCode::InvalidRequest, "non-UTF-8 staging path")
            })?)
        };
        Ok(BundleOutputV1 {
            staging_path: absolute(complete.completed_root())?,
            bundle_key: *complete.bundle_key(),
            manifest_path: absolute(&complete.completed_root().join("bundle.json"))?,
        })
    })();
    result.map_err(|error: CoreError| {
        let error = error.with_context("privatePath", private_root.to_string_lossy());
        if completed_root.exists() {
            error.with_context("completedPath", completed_root.to_string_lossy())
        } else {
            error
        }
    })
}
