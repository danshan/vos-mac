use open2jam_core::{
    bundle::load_bundle_documents,
    error::{CoreError, ErrorCode, ErrorInfo},
    id::{ChartId, SongId},
    path::AbsoluteSourcePath,
    progress::{ProgressOwner, ProgressPhase, ProgressSink, ProgressTracker},
    protocol::{CatalogOutputV1, CatalogRequestV1, Command},
};
use serde::Serialize;
use std::{
    fs,
    io::Write,
    path::{Path, PathBuf},
};

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct Catalog {
    schema_version: u16,
    entries: Vec<Entry>,
    rejected: Vec<Rejected>,
}
#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct Entry {
    root_path: AbsoluteSourcePath,
    relative_path: String,
    source_path: AbsoluteSourcePath,
    song_id: SongId,
    chart_id: ChartId,
    title: String,
    artist: String,
}
#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct Rejected {
    source_path: AbsoluteSourcePath,
    error: ErrorInfo,
}
fn io_error(error: std::io::Error) -> CoreError {
    CoreError::new(
        if error.kind() == std::io::ErrorKind::StorageFull {
            ErrorCode::OutOfSpace
        } else {
            ErrorCode::InternalError
        },
        format!("catalog I/O failed: {error}"),
    )
}
fn absolute(path: &Path) -> Result<AbsoluteSourcePath, CoreError> {
    AbsoluteSourcePath::parse(
        path.to_str()
            .ok_or_else(|| CoreError::new(ErrorCode::InvalidRequest, "non-UTF-8 catalog path"))?,
    )
}
fn cancel(request: &CatalogRequestV1) -> Result<(), CoreError> {
    match fs::symlink_metadata(request.cancel_marker_path.as_path()) {
        Ok(_) => Err(CoreError::new(
            ErrorCode::Cancelled,
            "Catalog scan cancelled",
        )),
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(()),
        Err(e) => Err(io_error(e)),
    }
}

pub fn scan(
    request: &CatalogRequestV1,
    sink: &mut dyn ProgressSink,
) -> Result<CatalogOutputV1, CoreError> {
    cancel(request)?;
    let staging = request.staging_root.as_path();
    let metadata = fs::symlink_metadata(staging).map_err(io_error)?;
    if !metadata.is_dir() || metadata.file_type().is_symlink() {
        return Err(CoreError::new(
            ErrorCode::InvalidRequest,
            "Catalog staging must be an owned directory",
        ));
    }
    let staging = staging.canonicalize().map_err(io_error)?;
    let mut roots: Vec<PathBuf> = Vec::new();
    for root in &request.roots {
        let path = root.as_path();
        let metadata = fs::symlink_metadata(path).map_err(io_error)?;
        if !metadata.is_dir() || metadata.file_type().is_symlink() {
            return Err(CoreError::new(
                ErrorCode::InvalidRequest,
                "Catalog roots must be non-symlink directories",
            ));
        }
        let path = path.canonicalize().map_err(io_error)?;
        if staging.starts_with(&path)
            || path.starts_with(&staging)
            || roots
                .iter()
                .any(|other| path.starts_with(other) || other.starts_with(&path))
        {
            return Err(CoreError::new(
                ErrorCode::InvalidRequest,
                "Catalog roots and staging must not overlap",
            ));
        }
        roots.push(path);
    }
    let mut progress = ProgressTracker::new(
        request.job_id.clone(),
        Command::Catalog,
        ProgressOwner::CatalogCli,
        sink,
    )?;
    let mut catalog = Catalog {
        schema_version: 2,
        entries: Vec::new(),
        rejected: Vec::new(),
    };
    let mut candidates = Vec::new();
    for root in roots {
        let mut pending = vec![root.clone()];
        while let Some(path) = pending.pop() {
            cancel(request)?;
            if fs::symlink_metadata(path.join("bundle.json")).is_ok() {
                candidates.push((root.clone(), path));
                continue;
            }
            let children = match fs::read_dir(&path) {
                Ok(children) => children,
                Err(error) => {
                    catalog.rejected.push(Rejected {
                        source_path: absolute(&path)?,
                        error: io_error(error).into(),
                    });
                    continue;
                }
            };
            for child in children {
                cancel(request)?;
                let child = child.map_err(io_error)?;
                let kind = child.file_type().map_err(io_error)?;
                if kind.is_symlink() {
                    catalog.rejected.push(Rejected {
                        source_path: absolute(&child.path())?,
                        error: CoreError::new(
                            ErrorCode::InvalidRequest,
                            "Linked catalog sources are not followed",
                        )
                        .into(),
                    });
                } else if kind.is_dir() {
                    pending.push(child.path());
                }
            }
        }
    }
    candidates.sort();
    let total = candidates.len() as u64;
    progress.emit(
        ProgressPhase::DiscoverSources,
        total,
        total,
        "sources".into(),
        None,
    )?;
    for (index, (root, path)) in candidates.into_iter().enumerate() {
        cancel(request)?;
        match load_bundle_documents(&path, None) {
            Ok(documents) => {
                let relative = path.strip_prefix(&root).expect("discovered below root");
                let relative = relative.to_str().ok_or_else(|| {
                    CoreError::new(ErrorCode::InvalidRequest, "non-UTF-8 relative catalog path")
                })?;
                catalog.entries.push(Entry {
                    root_path: absolute(&root)?,
                    relative_path: relative.into(),
                    source_path: absolute(&path)?,
                    song_id: documents.chart().song_id(),
                    chart_id: documents.chart().chart_id(),
                    title: documents.chart().title().into(),
                    artist: documents.chart().artist().into(),
                });
            }
            Err(error) => catalog.rejected.push(Rejected {
                source_path: absolute(&path)?,
                error: CoreError::new(error.code, error.message).into(),
            }),
        }
        progress.emit(
            ProgressPhase::ParseSources,
            index as u64 + 1,
            total,
            "sources".into(),
            Some(path.to_string_lossy().into_owned()),
        )?;
    }
    catalog
        .rejected
        .sort_by(|a, b| a.source_path.cmp(&b.source_path));
    cancel(request)?;
    let output = staging.join(request.job_id.as_str());
    fs::create_dir(&output).map_err(io_error)?;
    let temporary = output.join("catalog-v2.json.tmp");
    let path = output.join("catalog-v2.json");
    let bytes = serde_json::to_vec(&catalog)
        .map_err(|e| CoreError::new(ErrorCode::InternalError, e.to_string()))?;
    let mut file = fs::OpenOptions::new()
        .write(true)
        .create_new(true)
        .open(&temporary)
        .map_err(io_error)?;
    file.write_all(&bytes)
        .and_then(|()| file.sync_all())
        .map_err(io_error)?;
    cancel(request)?;
    fs::rename(temporary, &path).map_err(io_error)?;
    fs::File::open(&output)
        .and_then(|f| f.sync_all())
        .map_err(io_error)?;
    progress.emit(ProgressPhase::WriteCatalog, 1, 1, "catalog".into(), None)?;
    cancel(request)?;
    Ok(CatalogOutputV1 {
        catalog_path: absolute(&path)?,
        source_count: (catalog.entries.len() + catalog.rejected.len()) as u64,
        song_count: catalog.entries.len() as u64,
        chart_count: catalog.entries.len() as u64,
        rejected_source_count: catalog.rejected.len() as u64,
    })
}
