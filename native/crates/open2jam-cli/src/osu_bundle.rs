use crate::source_capture::{
    CapturedSource, absolute, cancelled, digest, failure, io_error, resolve_file, source_io_error,
};
use open2jam_core::{
    audio::{AudioAsset, AudioManifestV2},
    audio::{AudioFileFormat, MAX_AUDIO_FILE_BYTES, prepare_audio_file},
    bundle::{BundleIdentity, BundleStager, SoundFontIdentity, load_bundle_documents},
    canonical::CanonicalHasher,
    error::{CoreError, ErrorCode},
    format::Format,
    id::{ChartIdentity, SongIdentity, SourceFingerprint, derive_sample_id},
    json::encode_contract,
    osu::{self, OsuMetadata, OsuSource},
    path::{BundleRelativePath, SourceRelativePath},
    progress::{ProgressOwner, ProgressPhase, ProgressSink, ProgressTracker},
    protocol::{BundleOutputV1, BundleRequestV1, ChartSelector, Command},
    schema::SOURCE_FINGERPRINT_VERSION,
};
use std::{collections::BTreeMap, fs, path::Path};

pub(crate) fn source_identity(
    root_id: open2jam_core::id::LibraryRootId,
    relative: &str,
) -> Result<(open2jam_core::id::SongId, SourceRelativePath), CoreError> {
    let (song, chart_path) = match relative.rsplit_once('/') {
        Some((parent, filename)) => (
            SongIdentity::osu_beatmap_set(root_id, SourceRelativePath::parse(parent)?),
            SourceRelativePath::parse(filename)?,
        ),
        None => (
            SongIdentity::osu_beatmap_set_at_root(root_id),
            SourceRelativePath::parse(relative)?,
        ),
    };
    Ok((song.song_id(), chart_path))
}

fn audio_format(path: &Path) -> Result<AudioFileFormat, CoreError> {
    match path
        .extension()
        .and_then(|value| value.to_str())
        .unwrap_or("")
        .to_ascii_lowercase()
        .as_str()
    {
        "wav" => Ok(AudioFileFormat::Wave),
        "ogg" => Ok(AudioFileFormat::Ogg),
        "mp3" => Ok(AudioFileFormat::Mp3),
        _ => Err(failure(
            ErrorCode::AudioDecodeFailed,
            "unsupported osu audio file type",
        )),
    }
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
        .ok_or_else(|| failure(ErrorCode::InvalidRequest, "missing osu library root"))?;
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
    let (song_id, chart_path) = source_identity(root.id, relative.as_str())?;
    let ChartSelector::OsuBeatmap { relative_path } = &request.selector else {
        return Err(failure(ErrorCode::InvalidRequest, "expected osu selector"));
    };
    if relative_path != &chart_path
        || ChartIdentity::osu(chart_path.clone()).chart_id(&song_id) != request.chart_id
    {
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
    progress.emit(ProgressPhase::HashSources, 0, 1, "files".into(), None)?;
    let primary = CapturedSource::read(
        resolve_file(&root, &relative)?,
        osu::MAX_SOURCE_BYTES,
        &cancel,
    )?;
    let source = OsuSource::parse(&primary.bytes, &mut || cancel())?;
    let mut references = BTreeMap::new();
    if let Some(path) = &source.audio_filename {
        references.insert(1, path);
    }
    for sample in &source.samples {
        references.insert(sample.index, &sample.filename);
    }
    let total = references.len() as u64 + 1;
    progress.emit(ProgressPhase::HashSources, 1, total, "files".into(), None)?;
    let mut captures = Vec::new();
    let mut encoded_bytes = 0_u64;
    for (position, (index, relative)) in references.into_iter().enumerate() {
        cancel()?;
        let path = resolve_file(primary.path.parent().expect("source parent"), relative).map_err(
            |error| {
                if error.code() == ErrorCode::SourceChanged {
                    failure(
                        ErrorCode::MissingAsset,
                        "referenced osu audio file is missing",
                    )
                    .with_context("relativePath", relative.as_str())
                } else {
                    error
                }
            },
        )?;
        let format = audio_format(&path)?;
        let capture = CapturedSource::read(path, MAX_AUDIO_FILE_BYTES, &cancel)?;
        encoded_bytes += capture.bytes.len() as u64;
        if encoded_bytes > 512 * 1024 * 1024 {
            return Err(failure(
                ErrorCode::AudioDecodeFailed,
                "encoded osu audio exceeds the job bound",
            ));
        }
        captures.push((index, format, capture));
        progress.emit(
            ProgressPhase::HashSources,
            position as u64 + 2,
            total,
            "files".into(),
            None,
        )?;
    }
    let mut fingerprint = CanonicalHasher::new(b"open2jam.source-fingerprint.v1\0");
    fingerprint.write_u16(SOURCE_FINGERPRINT_VERSION);
    fingerprint.write_u32(captures.len() as u32 + 1);
    for (role, ordinal, capture) in std::iter::once((1, 0, &primary)).chain(
        captures
            .iter()
            .map(|(index, _, capture)| (3, *index, capture)),
    ) {
        fingerprint.write_u16(role);
        fingerprint.write_u32(ordinal);
        fingerprint.write_u64(capture.bytes.len() as u64);
        fingerprint.write_bytes(capture.digest.as_bytes());
    }
    progress.emit(ProgressPhase::ParseChart, 1, 1, "chart".into(), None)?;
    let mut stage = BundleStager::create(request.staging_root.as_path(), &request.job_id, &cancel)?;
    let private_root = stage.private_root().to_owned();
    let completed_root = staging.join(request.job_id.as_str());
    let result = (|| {
        progress.emit(ProgressPhase::CompileTiming, 0, 1, "chart".into(), None)?;
        let compiled = source.compile(
            OsuMetadata {
                song_id,
                chart_path,
                title: source.title.clone(),
                artist: source.artist.clone(),
            },
            &mut || cancel(),
        )?;
        progress.emit(ProgressPhase::CompileTiming, 1, 1, "chart".into(), None)?;
        let total = captures.len() as u64;
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
        for (position, (index, format, capture)) in captures.iter().enumerate() {
            let wave = prepare_audio_file(&capture.bytes, *format, &mut || cancel())?;
            decoded_bytes += wave.len() as u64;
            if decoded_bytes > 4 * 1024 * 1024 * 1024 {
                return Err(failure(
                    ErrorCode::AudioDecodeFailed,
                    "prepared osu audio exceeds the job bound",
                ));
            }
            let content = digest(&wave, &cancel)?;
            let sample_id = derive_sample_id(&content);
            indices.insert(*index, sample_id);
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
            Format::OsuMania,
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
        for (_, _, capture) in &captures {
            capture.verify()?;
        }
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
        for (_, _, capture) in &captures {
            capture.verify()?;
        }
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
