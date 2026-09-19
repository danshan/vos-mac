use super::verify::corrupt;
use super::{BundleValidationError, VerifiedBundle, verify_bundle};
use crate::{
    audio::AudioManifestV2,
    digest::Digest,
    error::ErrorCode,
    format::Format,
    gameplay::GameplayChartV2,
    id::{BundleKey, derive_sample_id},
    json::{Contract, decode_contract},
    path::BundleRelativePath,
    protocol::ChartSelector,
};
use sha2::{Digest as _, Sha256};
use std::{fs::File, io::Read, path::Path};

const MAX_DOCUMENT_BYTES: u64 = 64 * 1024 * 1024;

/// Validated JSON documents and file references, not proof that audio can decode.
#[derive(Debug)]
pub struct BundleDocuments {
    bundle: VerifiedBundle,
    chart: GameplayChartV2,
    audio: AudioManifestV2,
}
impl BundleDocuments {
    pub fn bundle(&self) -> &VerifiedBundle {
        &self.bundle
    }
    pub fn chart(&self) -> &GameplayChartV2 {
        &self.chart
    }
    pub fn audio(&self) -> &AudioManifestV2 {
        &self.audio
    }
}

pub fn load_bundle_documents(
    root: &Path,
    expected_key: Option<&BundleKey>,
) -> Result<BundleDocuments, BundleValidationError> {
    let bundle = verify_bundle(root, expected_key)?;
    let chart: GameplayChartV2 = read_document(&bundle, "gameplay.json")?;
    let audio: AudioManifestV2 = read_document(&bundle, "audio-manifest.json")?;
    let manifest = bundle.manifest();
    if chart.song_id() != *manifest.song_id()
        || chart.chart_id() != *manifest.chart_id()
        || audio.song_id() != chart.song_id()
        || audio.chart_id() != chart.chart_id()
        || audio.format() != chart.format()
    {
        return Err(corrupt(
            "bundle documents disagree on chart identity or format",
        ));
    }
    let expected_format = match manifest.chart_selector() {
        ChartSelector::VosChart { .. } => Some(Format::Vos),
        ChartSelector::OjnChart { .. } => Some(Format::O2Jam),
        ChartSelector::OsuBeatmap { .. } => Some(Format::OsuMania),
        ChartSelector::BundleChart { .. } => None,
    };
    if expected_format.is_some_and(|format| format != chart.format()) {
        return Err(corrupt("chart format disagrees with source selector"));
    }
    if !chart
        .samples()
        .iter()
        .copied()
        .eq(audio.assets().iter().map(|asset| asset.sample_id()))
    {
        return Err(corrupt("chart and audio sample sets differ"));
    }
    for asset in audio.assets() {
        let index = manifest
            .files()
            .binary_search_by(|file| file.path.cmp(asset.path()))
            .map_err(|_| corrupt("audio resource is absent from bundle manifest"))?;
        if derive_sample_id(&manifest.files()[index].sha256) != asset.sample_id() {
            return Err(corrupt("audio sample ID does not match prepared content"));
        }
    }
    Ok(BundleDocuments {
        bundle,
        chart,
        audio,
    })
}

fn read_document<T: Contract>(
    bundle: &VerifiedBundle,
    name: &str,
) -> Result<T, BundleValidationError> {
    let metadata = bundle
        .manifest()
        .files()
        .iter()
        .find(|file| file.path.as_str() == name)
        .ok_or_else(|| corrupt("required document missing"))?;
    if metadata.size_bytes > MAX_DOCUMENT_BYTES {
        return Err(corrupt("bundle document exceeds 64 MiB"));
    }
    let mut bytes = Vec::new();
    File::open(bundle.root().join(name))
        .map_err(|error| corrupt(format!("document open failed: {error}")))?
        .take(metadata.size_bytes + 1)
        .read_to_end(&mut bytes)
        .map_err(|error| corrupt(format!("document read failed: {error}")))?;
    if bytes.len() as u64 != metadata.size_bytes
        || Digest::from_bytes(Sha256::digest(&bytes).into()) != metadata.sha256
    {
        return Err(corrupt("bundle document changed after verification"));
    }
    decode_contract(&bytes).map_err(|error| BundleValidationError {
        code: if error.code() == ErrorCode::UnsupportedSchema {
            ErrorCode::UnsupportedSchema
        } else {
            ErrorCode::CacheCorrupt
        },
        message: error.to_string(),
        relative_path: BundleRelativePath::parse(name).ok(),
    })
}
