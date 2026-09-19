use crate::{
    error::{CoreError, ErrorCode, ProtocolError},
    format::Format,
    id::{ChartId, SampleId, SongId},
    json::Contract,
    path::BundleRelativePath,
    schema::AUDIO_MANIFEST_SCHEMA_VERSION,
};
use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;

mod mp3;
mod prepare;
mod wave;
pub use prepare::{AudioFileFormat, MAX_AUDIO_FILE_BYTES, SampleData, prepare_audio_file};

fn invalid(message: &str) -> CoreError {
    CoreError::new(ErrorCode::CorruptChart, message)
}

/// A prepared WAV resource. Original compressed formats are decoded before bundling.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", try_from = "AssetWire")]
pub struct AudioAsset {
    sample_id: SampleId,
    path: BundleRelativePath,
}
#[derive(Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct AssetWire {
    sample_id: SampleId,
    path: BundleRelativePath,
}
impl AudioAsset {
    pub fn new(sample_id: SampleId, path: BundleRelativePath) -> Result<Self, CoreError> {
        if !path.as_str().ends_with(".wav") {
            return Err(invalid("prepared audio must use a WAV resource path"));
        }
        Ok(Self { sample_id, path })
    }
    pub fn sample_id(&self) -> SampleId {
        self.sample_id
    }
    pub fn path(&self) -> &BundleRelativePath {
        &self.path
    }
}
impl TryFrom<AssetWire> for AudioAsset {
    type Error = CoreError;
    fn try_from(w: AssetWire) -> Result<Self, Self::Error> {
        Self::new(w.sample_id, w.path)
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", try_from = "AudioWire")]
pub struct AudioManifestV2 {
    schema_version: u16,
    song_id: SongId,
    chart_id: ChartId,
    format: Format,
    assets: Vec<AudioAsset>,
}
#[derive(Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct AudioWire {
    schema_version: u16,
    song_id: SongId,
    chart_id: ChartId,
    format: Format,
    assets: Vec<AudioAsset>,
}
impl AudioManifestV2 {
    pub fn new(
        song_id: SongId,
        chart_id: ChartId,
        format: Format,
        assets: Vec<AudioAsset>,
    ) -> Result<Self, CoreError> {
        let manifest = Self {
            schema_version: AUDIO_MANIFEST_SCHEMA_VERSION,
            song_id,
            chart_id,
            format,
            assets,
        };
        manifest.validate()?;
        Ok(manifest)
    }
    pub fn validate(&self) -> Result<(), CoreError> {
        if self.schema_version != AUDIO_MANIFEST_SCHEMA_VERSION {
            return Err(CoreError::new(
                ErrorCode::UnsupportedSchema,
                "unsupported audio manifest schema",
            ));
        }
        if self.format == Format::Bundle
            || self
                .assets
                .windows(2)
                .any(|pair| pair[0].sample_id >= pair[1].sample_id)
        {
            return Err(invalid("invalid audio format or unordered sample IDs"));
        }
        let mut paths = BTreeSet::new();
        if self
            .assets
            .iter()
            .any(|asset| !paths.insert(asset.path.as_str().to_ascii_lowercase()))
        {
            return Err(invalid("duplicate audio resource path"));
        }
        Ok(())
    }
    pub fn song_id(&self) -> SongId {
        self.song_id
    }
    pub fn chart_id(&self) -> ChartId {
        self.chart_id
    }
    pub fn format(&self) -> Format {
        self.format
    }
    pub fn assets(&self) -> &[AudioAsset] {
        &self.assets
    }
}
impl TryFrom<AudioWire> for AudioManifestV2 {
    type Error = CoreError;
    fn try_from(w: AudioWire) -> Result<Self, Self::Error> {
        if w.schema_version != AUDIO_MANIFEST_SCHEMA_VERSION {
            return Err(CoreError::new(
                ErrorCode::UnsupportedSchema,
                "unsupported audio manifest schema",
            ));
        }
        Self::new(w.song_id, w.chart_id, w.format, w.assets)
    }
}
impl Contract for AudioManifestV2 {
    const SCHEMA_VERSION: u16 = AUDIO_MANIFEST_SCHEMA_VERSION;
    fn validate(&self) -> Result<(), ProtocolError> {
        self.validate().map_err(Into::into)
    }
}
