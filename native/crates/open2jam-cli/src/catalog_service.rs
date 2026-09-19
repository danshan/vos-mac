use open2jam_core::{
    bundle::{SoundFontIdentity, load_bundle_documents},
    error::{CoreError, ErrorCode, ErrorInfo},
    format::SourceKind,
    id::{ChartId, ChartIdentity, LibraryRootId, SongId, SongIdentity},
    ojn::{self, OjnSource},
    osu::{self, OsuSource},
    path::{AbsoluteSourcePath, SourceRelativePath},
    progress::{ProgressOwner, ProgressPhase, ProgressSink, ProgressTracker},
    protocol::{CatalogOutputV1, CatalogRequestV1, Command},
};
use serde::Serialize;
use std::{
    collections::BTreeSet,
    fs,
    io::{Read, Write},
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
    #[serde(skip_serializing_if = "Option::is_none")]
    root_id: Option<LibraryRootId>,
    relative_path: String,
    source_path: AbsoluteSourcePath,
    #[serde(flatten)]
    details: ChartDetails,
    song_id: SongId,
    chart_id: ChartId,
    title: String,
    artist: String,
}
#[derive(Serialize)]
#[serde(
    tag = "sourceKind",
    rename_all = "SCREAMING_SNAKE_CASE",
    rename_all_fields = "camelCase"
)]
enum ChartDetails {
    BundleV2 {
        soundfont: SoundFontIdentity,
        static_assets_version: String,
    },
    Osu {
        chart_path: SourceRelativePath,
        difficulty_name: String,
        level: u32,
        duration_seconds: u32,
    },
    Ojn {
        chart_index: u8,
        level: i16,
        duration_seconds: u32,
    },
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
    let mut roots: Vec<(PathBuf, PathBuf)> = Vec::new();
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
                .any(|(_, other)| path.starts_with(other) || other.starts_with(&path))
        {
            return Err(CoreError::new(
                ErrorCode::InvalidRequest,
                "Catalog roots and staging must not overlap",
            ));
        }
        roots.push((root.as_path().to_owned(), path));
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
    for (origin, root) in roots {
        let mut pending = vec![root.clone()];
        while let Some(path) = pending.pop() {
            cancel(request)?;
            if fs::symlink_metadata(path.join("bundle.json")).is_ok() {
                candidates.push((origin.clone(), root.clone(), path, SourceKind::BundleV2));
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
                } else if kind.is_file() {
                    let path = child.path();
                    let extension = path
                        .extension()
                        .and_then(|value| value.to_str())
                        .unwrap_or("");
                    let source_kind = if extension.eq_ignore_ascii_case("ojn") {
                        Some(SourceKind::Ojn)
                    } else if extension.eq_ignore_ascii_case("osu") {
                        Some(SourceKind::Osu)
                    } else {
                        None
                    };
                    if let Some(source_kind) = source_kind {
                        candidates.push((origin.clone(), root.clone(), path, source_kind));
                    }
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
    for (index, (origin, root, path, kind)) in candidates.into_iter().enumerate() {
        cancel(request)?;
        match read_entries(request, &origin, &root, &path, kind) {
            Ok(entries) => catalog.entries.extend(entries),
            Err(error) if error.code() == ErrorCode::Cancelled => return Err(error),
            Err(error) => catalog.rejected.push(Rejected {
                source_path: absolute(&path)?,
                error: error.into(),
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
    let sources: BTreeSet<_> = catalog
        .entries
        .iter()
        .map(|entry| (&entry.root_path, &entry.relative_path))
        .collect();
    let songs: BTreeSet<_> = catalog
        .entries
        .iter()
        .map(|entry| match &entry.details {
            ChartDetails::Osu { .. } => (
                &entry.root_path,
                SourceKind::Osu,
                entry
                    .relative_path
                    .rsplit_once('/')
                    .map_or("", |(parent, _)| parent),
            ),
            ChartDetails::Ojn { .. } => (
                &entry.root_path,
                SourceKind::Ojn,
                entry.relative_path.as_str(),
            ),
            ChartDetails::BundleV2 { .. } => (
                &entry.root_path,
                SourceKind::BundleV2,
                entry.relative_path.as_str(),
            ),
        })
        .collect();
    Ok(CatalogOutputV1 {
        catalog_path: absolute(&path)?,
        source_count: (sources.len() + catalog.rejected.len()) as u64,
        song_count: songs.len() as u64,
        chart_count: catalog.entries.len() as u64,
        rejected_source_count: catalog.rejected.len() as u64,
    })
}

fn read_entries(
    request: &CatalogRequestV1,
    origin: &Path,
    root: &Path,
    path: &Path,
    kind: SourceKind,
) -> Result<Vec<Entry>, CoreError> {
    let relative = path.strip_prefix(root).expect("discovered below root");
    let relative = relative.to_str().ok_or_else(|| {
        CoreError::new(ErrorCode::InvalidRequest, "non-UTF-8 relative catalog path")
    })?;
    let root_path = absolute(origin)?;
    let root_id = request.root_ids.get(&root_path).copied();
    let source_path = absolute(&origin.join(relative))?;
    if kind == SourceKind::Ojn {
        let root_id = root_id.ok_or_else(|| {
            CoreError::new(
                ErrorCode::InvalidRequest,
                "OJN discovery requires a persistent library root ID",
            )
        })?;
        let bytes = read_chart(path, ojn::MAX_SOURCE_BYTES, request)?;
        let source = OjnSource::parse(&bytes)?;
        let song_id =
            SongIdentity::ojn_file(root_id, SourceRelativePath::parse(relative)?).song_id();
        let title = source.title()?;
        let artist = source.artist()?;
        let mut entries = Vec::with_capacity(3);
        for chart_index in 0..3 {
            entries.push(Entry {
                root_path: root_path.clone(),
                root_id: Some(root_id),
                relative_path: relative.into(),
                source_path: source_path.clone(),
                song_id,
                chart_id: ChartIdentity::ojn(chart_index)?.chart_id(&song_id),
                title: title.clone(),
                artist: artist.clone(),
                details: ChartDetails::Ojn {
                    chart_index,
                    level: source.levels()[chart_index as usize],
                    duration_seconds: source.duration_seconds(chart_index as usize)?,
                },
            });
        }
        return Ok(entries);
    }
    if kind == SourceKind::Osu {
        let root_id = root_id.ok_or_else(|| {
            CoreError::new(
                ErrorCode::InvalidRequest,
                "osu discovery requires a persistent library root ID",
            )
        })?;
        let bytes = read_chart(path, osu::MAX_SOURCE_BYTES, request)?;
        let source = OsuSource::parse(&bytes, &mut || cancel(request))?;
        let (song_id, chart_path) = crate::osu_bundle::source_identity(root_id, relative)?;
        let duration_ms = source
            .notes
            .iter()
            .map(|note| note.end_ms.unwrap_or(note.time_ms))
            .max()
            .unwrap_or(0) as u32;
        return Ok(vec![Entry {
            root_path,
            root_id: Some(root_id),
            relative_path: relative.into(),
            source_path,
            song_id,
            chart_id: ChartIdentity::osu(chart_path.clone()).chart_id(&song_id),
            title: source.title,
            artist: source.artist,
            details: ChartDetails::Osu {
                chart_path,
                difficulty_name: source.difficulty_name,
                level: source.level,
                duration_seconds: duration_ms.div_ceil(1000),
            },
        }]);
    }
    let documents = load_bundle_documents(path, None)
        .map_err(|error| CoreError::new(error.code, error.message))?;
    Ok(vec![Entry {
        root_path,
        root_id,
        relative_path: relative.into(),
        source_path,
        song_id: documents.chart().song_id(),
        chart_id: documents.chart().chart_id(),
        title: documents.chart().title().into(),
        artist: documents.chart().artist().into(),
        details: ChartDetails::BundleV2 {
            soundfont: documents.bundle().manifest().soundfont().clone(),
            static_assets_version: documents.bundle().manifest().static_assets_version().into(),
        },
    }])
}

fn read_chart(path: &Path, limit: usize, request: &CatalogRequestV1) -> Result<Vec<u8>, CoreError> {
    let metadata = fs::symlink_metadata(path).map_err(io_error)?;
    if !metadata.is_file() || metadata.file_type().is_symlink() || metadata.len() > limit as u64 {
        return Err(CoreError::new(
            ErrorCode::CorruptChart,
            "chart source is not a bounded regular file",
        ));
    }
    let mut reader = fs::File::open(path)
        .map_err(io_error)?
        .take(limit as u64 + 1);
    let mut bytes = Vec::new();
    let mut chunk = [0; 65536];
    loop {
        cancel(request)?;
        let length = reader.read(&mut chunk).map_err(io_error)?;
        if length == 0 {
            break;
        }
        if bytes.len() + length > limit {
            return Err(CoreError::new(
                ErrorCode::CorruptChart,
                "chart source grew beyond its input bound",
            ));
        }
        bytes.extend_from_slice(&chunk[..length]);
    }
    Ok(bytes)
}
