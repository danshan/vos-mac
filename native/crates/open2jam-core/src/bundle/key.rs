use crate::{
    canonical::CanonicalHasher,
    digest::Digest,
    id::{BundleKey, ChartId, SongId, SourceFingerprint},
    protocol::ChartSelector,
    schema::BUNDLE_KEY_ALGORITHM_VERSION,
};

#[derive(Debug, Clone)]
pub struct BundleKeyInput {
    pub bundle_schema_version: u16,
    pub converter_version: String,
    pub static_assets_version: String,
    pub soundfont_sha256: Digest,
    pub song_id: SongId,
    pub chart_id: ChartId,
    pub chart_selector: ChartSelector,
    pub source_fingerprint: SourceFingerprint,
}

pub fn compute_bundle_key(input: &BundleKeyInput) -> BundleKey {
    let mut hash = CanonicalHasher::new(b"open2jam.bundle-key.v1\0");
    hash.write_u16(BUNDLE_KEY_ALGORITHM_VERSION);
    hash.write_u16(input.bundle_schema_version);
    hash.write_str(&input.converter_version);
    hash.write_str(&input.static_assets_version);
    hash.write_bytes(input.soundfont_sha256.as_bytes());
    hash.write_bytes(input.song_id.digest().as_bytes());
    hash.write_bytes(input.chart_id.digest().as_bytes());
    match &input.chart_selector {
        ChartSelector::VosChart { index } => {
            hash.write_u16(1);
            hash.write_u16(u16::from(*index));
        }
        ChartSelector::OjnChart { index } => {
            hash.write_u16(2);
            hash.write_u16(u16::from(*index));
        }
        ChartSelector::OsuBeatmap { relative_path } => {
            hash.write_u16(3);
            hash.write_str(relative_path.as_str());
        }
        ChartSelector::BundleChart { chart_id } => {
            hash.write_u16(4);
            hash.write_bytes(chart_id.digest().as_bytes());
        }
    }
    hash.write_bytes(input.source_fingerprint.digest().as_bytes());
    BundleKey::from_digest(hash.finish())
}
