use open2jam_core::{
    audio::{AudioAsset, AudioManifestV2},
    bundle::{BundleIdentity, BundleStager, SoundFontIdentity, load_bundle_documents},
    canonical::CanonicalHasher,
    digest::Digest,
    error::{CoreError, ErrorCode},
    format::Format,
    id::{ChartIdentity, SongIdentity, SourceFingerprint, derive_sample_id},
    json::encode_contract,
    ojm,
    ojn::{self, OjnMetadata, OjnSource},
    path::{AbsoluteSourcePath, BundleRelativePath, SourceRelativePath},
    progress::{ProgressOwner, ProgressPhase, ProgressSink, ProgressTracker},
    protocol::{BundleOutputV1, BundleRequestV1, ChartSelector, Command},
    schema::SOURCE_FINGERPRINT_VERSION,
};
use sha2::{Digest as _, Sha256};
#[cfg(unix)]
use std::os::unix::fs::{MetadataExt, OpenOptionsExt};
use std::{
    collections::BTreeMap,
    fs::{self, File, Metadata, OpenOptions},
    io::Read,
    path::{Path, PathBuf},
};

fn failure(code: ErrorCode, message: &str) -> CoreError {
    CoreError::new(code, message)
}
fn io_error(error: std::io::Error) -> CoreError {
    CoreError::new(
        if error.kind() == std::io::ErrorKind::StorageFull {
            ErrorCode::OutOfSpace
        } else {
            ErrorCode::InternalError
        },
        format!("OJN source I/O failed: {error}"),
    )
}
fn cancelled(path: &Path) -> Result<(), CoreError> {
    match fs::symlink_metadata(path) {
        Ok(_) => Err(failure(ErrorCode::Cancelled, "OJN conversion cancelled")),
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => Ok(()),
        Err(error) => Err(io_error(error)),
    }
}
fn source_io_error(error: std::io::Error) -> CoreError {
    if error.kind() == std::io::ErrorKind::NotFound {
        failure(
            ErrorCode::SourceChanged,
            "selected source is no longer available",
        )
    } else {
        io_error(error)
    }
}
fn digest(bytes: &[u8], cancel: &impl Fn() -> Result<(), CoreError>) -> Result<Digest, CoreError> {
    let mut hash = Sha256::new();
    for chunk in bytes.chunks(65536) {
        cancel()?;
        hash.update(chunk);
    }
    Ok(Digest::from_bytes(hash.finalize().into()))
}
fn absolute(path: &Path) -> Result<AbsoluteSourcePath, CoreError> {
    AbsoluteSourcePath::parse(
        path.to_str()
            .ok_or_else(|| failure(ErrorCode::InvalidRequest, "non-UTF-8 source path"))?,
    )
}

struct CapturedSource {
    path: PathBuf,
    file: File,
    metadata: Metadata,
    bytes: Vec<u8>,
    digest: Digest,
}
impl CapturedSource {
    fn read(
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
            "raw OJN capture currently requires Unix file identity",
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
    fn verify(&self) -> Result<(), CoreError> {
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

fn resolve_file(root: &Path, relative: &SourceRelativePath) -> Result<PathBuf, CoreError> {
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

fn resolve_companion(
    parent: &Path,
    bytes: &[u8],
    cancel: &impl Fn() -> Result<(), CoreError>,
) -> Result<PathBuf, CoreError> {
    let names = if let Ok(name) = std::str::from_utf8(bytes) {
        vec![name.to_owned()]
    } else {
        let mut detector = chardetng::EncodingDetector::new(chardetng::Iso2022JpDetection::Deny);
        detector.feed(bytes, true);
        [
            detector.guess(None, chardetng::Utf8Detection::Allow),
            encoding_rs::EUC_KR,
            encoding_rs::GBK,
            encoding_rs::BIG5,
            encoding_rs::SHIFT_JIS,
        ]
        .into_iter()
        .filter_map(|encoding| {
            encoding
                .decode_without_bom_handling_and_without_replacement(bytes)
                .map(|name| name.into_owned())
        })
        .collect()
    };
    let mut paths = std::collections::BTreeSet::new();
    for name in names {
        cancel()?;
        let Ok(relative) = SourceRelativePath::parse(&name) else {
            continue;
        };
        if let Ok(path) = resolve_file(parent, &relative)
            && fs::symlink_metadata(&path).is_ok_and(|metadata| metadata.is_file())
        {
            paths.insert(path);
        }
    }
    if paths.len() != 1 {
        return Err(failure(
            ErrorCode::MissingCompanion,
            "companion filename has no unique regular-file match",
        ));
    }
    Ok(paths.into_iter().next().expect("one companion"))
}

pub fn convert(
    request: &BundleRequestV1,
    sink: &mut dyn ProgressSink,
) -> Result<BundleOutputV1, CoreError> {
    let cancel = || cancelled(request.cancel_marker_path.as_path());
    cancel()?;
    let root = request
        .library_root
        .as_ref()
        .ok_or_else(|| failure(ErrorCode::InvalidRequest, "missing OJN library root"))?;
    let relative = request
        .source_path
        .as_path()
        .strip_prefix(root.path.as_path())
        .map_err(|_| {
            failure(
                ErrorCode::InvalidRequest,
                "source is outside its library root",
            )
        })?;
    let relative = SourceRelativePath::parse(
        relative
            .to_str()
            .ok_or_else(|| failure(ErrorCode::InvalidRequest, "non-UTF-8 source path"))?,
    )?;
    let song_id = SongIdentity::ojn_file(root.id, relative.clone()).song_id();
    let ChartSelector::OjnChart { index } = request.selector else {
        return Err(failure(ErrorCode::InvalidRequest, "expected OJN selector"));
    };
    if ChartIdentity::ojn(index)?.chart_id(&song_id) != request.chart_id {
        return Err(failure(
            ErrorCode::SourceChanged,
            "selected chart does not match its library source",
        ));
    }
    if !fs::symlink_metadata(root.path.as_path())
        .map_err(source_io_error)?
        .is_dir()
    {
        return Err(failure(
            ErrorCode::InvalidRequest,
            "library root must be a non-linked directory",
        ));
    }
    let root = root
        .path
        .as_path()
        .canonicalize()
        .map_err(source_io_error)?;
    let staging = request
        .staging_root
        .as_path()
        .canonicalize()
        .map_err(io_error)?;
    if staging.starts_with(&root) || root.starts_with(&staging) {
        return Err(failure(
            ErrorCode::InvalidRequest,
            "source and staging roots must be disjoint",
        ));
    }
    let mut progress = ProgressTracker::new(
        request.job_id.clone(),
        Command::Bundle,
        ProgressOwner::BundleCli,
        sink,
    )?;
    progress.emit(ProgressPhase::HashSources, 0, 2, "files".into(), None)?;
    let primary = CapturedSource::read(
        resolve_file(&root, &relative)?,
        ojn::MAX_SOURCE_BYTES,
        &cancel,
    )?;
    progress.emit(ProgressPhase::HashSources, 1, 2, "files".into(), None)?;
    let source = OjnSource::parse(&primary.bytes)?;
    let companion_path = resolve_companion(
        primary.path.parent().expect("source parent"),
        source.companion_bytes(),
        &cancel,
    )?;
    let companion = CapturedSource::read(companion_path, ojm::MAX_SOURCE_BYTES, &cancel)?;
    progress.emit(ProgressPhase::HashSources, 2, 2, "files".into(), None)?;
    progress.emit(ProgressPhase::ParseChart, 0, 1, "chart".into(), None)?;
    let samples = ojm::parse_plain_ojm(&companion.bytes, &mut || cancel())?;
    progress.emit(ProgressPhase::ParseChart, 1, 1, "chart".into(), None)?;
    let mut fingerprint = CanonicalHasher::new(b"open2jam.source-fingerprint.v1\0");
    fingerprint.write_u16(SOURCE_FINGERPRINT_VERSION);
    fingerprint.write_u32(2);
    for (role, capture) in [(1, &primary), (2, &companion)] {
        fingerprint.write_u16(role);
        fingerprint.write_u32(0);
        fingerprint.write_u64(capture.bytes.len() as u64);
        fingerprint.write_bytes(capture.digest.as_bytes());
    }
    let mut stage = BundleStager::create(request.staging_root.as_path(), &request.job_id, &cancel)?;
    let private_root = stage.private_root().to_owned();
    let completed_root = staging.join(request.job_id.as_str());
    let result = (|| {
        progress.emit(ProgressPhase::CompileTiming, 0, 1, "chart".into(), None)?;
        let compiled = source.compile(
            index,
            OjnMetadata {
                song_id,
                title: source.title()?,
                artist: source.artist()?,
            },
            &mut || cancel(),
        )?;
        progress.emit(ProgressPhase::CompileTiming, 1, 1, "chart".into(), None)?;
        let total = samples.len() as u64;
        progress.emit(
            ProgressPhase::PrepareAudio,
            0,
            total,
            "samples".into(),
            None,
        )?;
        let mut indices = BTreeMap::new();
        let mut assets = BTreeMap::new();
        let mut decoded_bytes = 0_u64;
        for (position, sample) in samples.into_iter().enumerate() {
            let wave = sample.data.prepare_wav(&mut || cancel())?;
            decoded_bytes += wave.len() as u64;
            if decoded_bytes > 4 * 1024 * 1024 * 1024 {
                return Err(failure(
                    ErrorCode::AudioDecodeFailed,
                    "prepared OJM audio exceeds the job bound",
                ));
            }
            let content = digest(&wave, &cancel)?;
            let sample_id = derive_sample_id(&content);
            indices.insert(sample.index, sample_id);
            if let std::collections::btree_map::Entry::Vacant(entry) = assets.entry(sample_id) {
                let path = BundleRelativePath::parse(&format!(
                    "audio/{}.wav",
                    content.to_string().trim_start_matches("sha256:")
                ))?;
                stage.write_artifact(path.clone(), &mut wave.as_slice(), &cancel)?;
                entry.insert(AudioAsset::new(sample_id, path)?);
            }
            progress.emit(
                ProgressPhase::PrepareAudio,
                position as u64 + 1,
                total,
                "samples".into(),
                None,
            )?;
        }
        let chart = compiled.with_samples(&indices, &mut || cancel())?;
        let audio = AudioManifestV2::new(
            song_id,
            request.chart_id,
            Format::O2Jam,
            assets.into_values().collect(),
        )?;
        progress.emit(ProgressPhase::WriteBundle, 0, 2, "documents".into(), None)?;
        for (position, (name, bytes)) in [
            (
                "gameplay.json",
                encode_contract(&chart)
                    .map_err(|error| failure(error.code(), &error.to_string()))?,
            ),
            (
                "audio-manifest.json",
                encode_contract(&audio)
                    .map_err(|error| failure(error.code(), &error.to_string()))?,
            ),
        ]
        .into_iter()
        .enumerate()
        {
            stage.write_artifact(
                BundleRelativePath::parse(name)?,
                &mut bytes.as_slice(),
                &cancel,
            )?;
            progress.emit(
                ProgressPhase::WriteBundle,
                position as u64 + 1,
                2,
                "documents".into(),
                None,
            )?;
        }
        cancel()?;
        primary.verify()?;
        companion.verify()?;
        progress.emit(ProgressPhase::VerifyBundle, 0, 1, "bundle".into(), None)?;
        let complete = stage.finalize(
            BundleIdentity {
                converter_version: env!("CARGO_PKG_VERSION").into(),
                static_assets_version: request.static_assets_version.clone(),
                soundfont: SoundFontIdentity {
                    version: request.soundfont.version.clone(),
                    sha256: request.soundfont.sha256,
                },
                song_id,
                chart_id: request.chart_id,
                chart_selector: request.selector.clone(),
                source_fingerprint: SourceFingerprint::from_digest(fingerprint.finish()),
            },
            &cancel,
        )?;
        load_bundle_documents(complete.completed_root(), Some(complete.bundle_key()))
            .map_err(|error| CoreError::new(error.code, error.message))?;
        primary.verify()?;
        companion.verify()?;
        cancel()?;
        progress.emit(ProgressPhase::VerifyBundle, 1, 1, "bundle".into(), None)?;
        cancel()?;
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
