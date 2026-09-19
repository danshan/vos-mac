use super::{BundleKeyInput, compute_bundle_key};
use crate::{
    digest::Digest,
    error::{CoreError, ErrorCode, ProtocolError},
    id::{BundleKey, ChartId, ChartIdentity, SongId, SourceFingerprint},
    json::Contract,
    path::BundleRelativePath,
    protocol::ChartSelector,
    schema::{BUNDLE_SCHEMA_VERSION, STATIC_ASSETS_VERSION},
};
use serde::{Deserialize, Serialize};
use sha2::{Digest as _, Sha256};
use std::collections::BTreeMap;

pub(super) const MAX_FILES: usize = 65_536;
const MAX_PATH_COMPONENTS: usize = 64;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct BundleFile {
    pub path: BundleRelativePath,
    pub size_bytes: u64,
    pub sha256: Digest,
}
impl BundleFile {
    pub fn from_bytes(path: BundleRelativePath, bytes: &[u8]) -> Self {
        Self {
            path,
            size_bytes: bytes.len() as u64,
            sha256: Digest::from_bytes(Sha256::digest(bytes).into()),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct SoundFontIdentity {
    pub version: String,
    pub sha256: Digest,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct BundleIdentity {
    pub converter_version: String,
    pub static_assets_version: String,
    pub soundfont: SoundFontIdentity,
    pub song_id: SongId,
    pub chart_id: ChartId,
    pub chart_selector: ChartSelector,
    pub source_fingerprint: SourceFingerprint,
}

/// A complete file manifest, constructed only through validation.
/// ```compile_fail
/// use open2jam_core::bundle::BundleManifestV2;
/// fn bypass_validation(mut manifest: BundleManifestV2) {
///     manifest.complete = false;
/// }
/// ```
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", try_from = "BundleManifestWire")]
pub struct BundleManifestV2 {
    schema_version: u16,
    complete: bool,
    bundle_key: BundleKey,
    converter_version: String,
    static_assets_version: String,
    soundfont: SoundFontIdentity,
    song_id: SongId,
    chart_id: ChartId,
    chart_selector: ChartSelector,
    source_fingerprint: SourceFingerprint,
    files: Vec<BundleFile>,
}
#[derive(Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct BundleManifestWire {
    schema_version: u16,
    complete: bool,
    bundle_key: BundleKey,
    converter_version: String,
    static_assets_version: String,
    soundfont: SoundFontIdentity,
    song_id: SongId,
    chart_id: ChartId,
    chart_selector: ChartSelector,
    source_fingerprint: SourceFingerprint,
    files: Vec<BundleFile>,
}
impl TryFrom<BundleManifestWire> for BundleManifestV2 {
    type Error = CoreError;
    fn try_from(w: BundleManifestWire) -> Result<Self, Self::Error> {
        let manifest = Self {
            schema_version: w.schema_version,
            complete: w.complete,
            bundle_key: w.bundle_key,
            converter_version: w.converter_version,
            static_assets_version: w.static_assets_version,
            soundfont: w.soundfont,
            song_id: w.song_id,
            chart_id: w.chart_id,
            chart_selector: w.chart_selector,
            source_fingerprint: w.source_fingerprint,
            files: w.files,
        };
        manifest.validate()?;
        Ok(manifest)
    }
}
impl BundleManifestV2 {
    pub fn new(identity: BundleIdentity, files: Vec<BundleFile>) -> Result<Self, CoreError> {
        let mut manifest = Self {
            schema_version: BUNDLE_SCHEMA_VERSION,
            complete: true,
            bundle_key: BundleKey::from_digest(Digest::from_bytes([0; 32])),
            converter_version: identity.converter_version,
            static_assets_version: identity.static_assets_version,
            soundfont: identity.soundfont,
            song_id: identity.song_id,
            chart_id: identity.chart_id,
            chart_selector: identity.chart_selector,
            source_fingerprint: identity.source_fingerprint,
            files,
        };
        manifest.bundle_key = compute_bundle_key(&manifest.key_input());
        manifest.validate()?;
        Ok(manifest)
    }
    pub fn validate(&self) -> Result<(), CoreError> {
        let invalid = |message| CoreError::new(ErrorCode::CacheCorrupt, message);
        if self.schema_version != BUNDLE_SCHEMA_VERSION {
            return Err(CoreError::new(
                ErrorCode::UnsupportedSchema,
                "unsupported bundle schema",
            ));
        }
        if !self.complete
            || self.static_assets_version != STATIC_ASSETS_VERSION
            || self.converter_version.is_empty()
            || self.converter_version.contains('\0')
            || self.soundfont.version.is_empty()
            || self.soundfont.version.contains('\0')
        {
            return Err(invalid("incomplete bundle or invalid asset version"));
        }
        let chart = ChartIdentity::from_selector(self.chart_selector.clone())
            .map_err(|_| invalid("invalid chart selector"))?;
        if chart.chart_id(&self.song_id) != self.chart_id
            || compute_bundle_key(&self.key_input()) != self.bundle_key
        {
            return Err(invalid("bundle identity or key mismatch"));
        }
        if self.files.len() > MAX_FILES || self.files.windows(2).any(|p| p[0].path >= p[1].path) {
            return Err(invalid(
                "manifest files must be bounded, sorted, and unique",
            ));
        }
        let mut nodes = BTreeMap::from([("bundle.json".to_owned(), ("bundle.json", true))]);
        for file in &self.files {
            let path = file.path.as_str();
            if path.split('/').count() > MAX_PATH_COMPONENTS {
                return Err(invalid("bundle path exceeds 64 components"));
            }
            for end in path
                .match_indices('/')
                .map(|(index, _)| index)
                .chain(std::iter::once(path.len()))
            {
                let prefix = &path[..end];
                let is_file = end == path.len();
                if let Some((existing, existing_is_file)) =
                    nodes.insert(prefix.to_ascii_lowercase(), (prefix, is_file))
                    && (existing != prefix || existing_is_file || is_file)
                {
                    return Err(invalid(
                        "manifest contains colliding file or directory paths",
                    ));
                }
            }
        }
        if !self
            .files
            .iter()
            .any(|f| f.path.as_str() == "gameplay.json")
            || !self
                .files
                .iter()
                .any(|f| f.path.as_str() == "audio-manifest.json")
        {
            return Err(invalid("required gameplay or audio manifest missing"));
        }
        Ok(())
    }
    pub fn key_input(&self) -> BundleKeyInput {
        BundleKeyInput {
            bundle_schema_version: self.schema_version,
            converter_version: self.converter_version.clone(),
            static_assets_version: self.static_assets_version.clone(),
            soundfont_sha256: self.soundfont.sha256,
            song_id: self.song_id,
            chart_id: self.chart_id,
            chart_selector: self.chart_selector.clone(),
            source_fingerprint: self.source_fingerprint,
        }
    }
    pub fn schema_version(&self) -> u16 {
        self.schema_version
    }
    pub fn complete(&self) -> bool {
        self.complete
    }
    pub fn bundle_key(&self) -> &BundleKey {
        &self.bundle_key
    }
    pub fn converter_version(&self) -> &str {
        &self.converter_version
    }
    pub fn static_assets_version(&self) -> &str {
        &self.static_assets_version
    }
    pub fn soundfont(&self) -> &SoundFontIdentity {
        &self.soundfont
    }
    pub fn song_id(&self) -> &SongId {
        &self.song_id
    }
    pub fn chart_id(&self) -> &ChartId {
        &self.chart_id
    }
    pub fn chart_selector(&self) -> &ChartSelector {
        &self.chart_selector
    }
    pub fn source_fingerprint(&self) -> &SourceFingerprint {
        &self.source_fingerprint
    }
    pub fn files(&self) -> &[BundleFile] {
        &self.files
    }
}
impl Contract for BundleManifestV2 {
    const SCHEMA_VERSION: u16 = BUNDLE_SCHEMA_VERSION;
    fn validate(&self) -> Result<(), ProtocolError> {
        self.validate().map_err(Into::into)
    }
}
