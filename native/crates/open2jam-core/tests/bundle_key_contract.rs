use open2jam_core::{
    bundle::{BundleKeyInput, compute_bundle_key},
    digest::Digest,
    id::{ChartId, SongId, SourceFingerprint},
    path::SourceRelativePath,
    protocol::ChartSelector,
    schema::STATIC_ASSETS_VERSION,
};

fn input() -> BundleKeyInput {
    BundleKeyInput {
        bundle_schema_version: 2,
        converter_version: "0.1.0".to_owned(),
        static_assets_version: STATIC_ASSETS_VERSION.to_owned(),
        soundfont_sha256: Digest::from_bytes([2; 32]),
        song_id: SongId::from_digest(Digest::from_bytes([1; 32])),
        chart_id: ChartId::from_digest(Digest::from_bytes([4; 32])),
        chart_selector: ChartSelector::VosChart { index: 0 },
        source_fingerprint: SourceFingerprint::from_digest(Digest::from_bytes([3; 32])),
    }
}

#[test]
fn bundle_keys_match_independent_python_framing_vectors() {
    let vectors: serde_json::Value =
        serde_json::from_str(include_str!("fixtures/bundle/key-v1-vectors.json")).unwrap();
    for (name, selector) in [
        ("vos", ChartSelector::VosChart { index: 0 }),
        ("ojn", ChartSelector::OjnChart { index: 2 }),
        (
            "osu",
            ChartSelector::OsuBeatmap {
                relative_path: SourceRelativePath::parse("set/hard.osu").unwrap(),
            },
        ),
        (
            "bundle",
            ChartSelector::BundleChart {
                chart_id: input().chart_id,
            },
        ),
    ] {
        let mut input = input();
        input.chart_selector = selector;
        assert_eq!(
            *compute_bundle_key(&input).digest(),
            Digest::parse(&format!(
                "sha256:{}",
                vectors[name]["sha256"].as_str().unwrap()
            ))
            .unwrap(),
            "{name}"
        );
    }
}

#[test]
fn every_cache_identity_component_changes_the_key() {
    let original = input();
    for component in 0..8 {
        let mut changed = original.clone();
        match component {
            0 => changed.bundle_schema_version += 1,
            1 => changed.converter_version.push('1'),
            2 => changed.static_assets_version.push('1'),
            3 => changed.soundfont_sha256 = Digest::from_bytes([9; 32]),
            4 => changed.song_id = SongId::from_digest(Digest::from_bytes([9; 32])),
            5 => changed.chart_id = ChartId::from_digest(Digest::from_bytes([9; 32])),
            6 => changed.chart_selector = ChartSelector::OjnChart { index: 0 },
            7 => {
                changed.source_fingerprint =
                    SourceFingerprint::from_digest(Digest::from_bytes([9; 32]))
            }
            _ => unreachable!(),
        }
        assert_ne!(
            compute_bundle_key(&original),
            compute_bundle_key(&changed),
            "component {component}"
        );
    }
    let mut first = original.clone();
    first.converter_version = "ab".to_owned();
    first.static_assets_version = "c".to_owned();
    let mut second = original;
    second.converter_version = "a".to_owned();
    second.static_assets_version = "bc".to_owned();
    assert_ne!(compute_bundle_key(&first), compute_bundle_key(&second));
}
