use open2jam_core::digest::Digest;
use open2jam_core::format::SourceKind;
use open2jam_core::id::{
    ChartId, ChartIdentity, SongId, SongIdentity, SourceFingerprint, derive_sample_id,
    derive_source_id,
};
use open2jam_core::path::SourceRelativePath;

const ZERO_DIGEST: &str = "sha256:0000000000000000000000000000000000000000000000000000000000000000";

#[test]
fn identity_derivation_is_domain_separated_and_stable() {
    let digest = Digest::parse(ZERO_DIGEST).unwrap();
    let fingerprint = SourceFingerprint::from_digest(digest);

    assert_eq!(
        derive_source_id(SourceKind::Vos, &fingerprint).to_string(),
        "source:sha256:9c9a68f7f5a992a073d494fda594ce0f0f5edc933ed8f3b96e7a1ef439ccbd33"
    );
    assert_eq!(
        derive_sample_id(&digest).to_string(),
        "sample:sha256:ad4f477c63bc8535e543e229bb785ec349cf091c017c62f609872031bc9b0503"
    );

    let vos_a = SongIdentity::vos(
        SourceRelativePath::parse("pack-a/song.vos").unwrap(),
        "Same Title".to_owned(),
    )
    .unwrap();
    let vos_b = SongIdentity::vos(
        SourceRelativePath::parse("pack-b/song.vos").unwrap(),
        "Same Title".to_owned(),
    )
    .unwrap();
    let vos_title_changed = SongIdentity::vos(
        SourceRelativePath::parse("pack-a/song.vos").unwrap(),
        "Changed Title".to_owned(),
    )
    .unwrap();
    assert_ne!(vos_a.song_id(), vos_b.song_id());
    assert_ne!(vos_a.song_id(), vos_title_changed.song_id());
    assert_eq!(
        vos_a.song_id().to_string(),
        "song:sha256:aeb5e7ef8966bd78d3e49245af02896d85c9eb540f1603f8dc8f47f75a9d1e27"
    );

    let ojn = SongIdentity::ojn_file(SourceRelativePath::parse("album/song.ojn").unwrap());
    let easy = ChartIdentity::ojn(0).unwrap().chart_id(&ojn.song_id());
    let normal = ChartIdentity::ojn(1).unwrap().chart_id(&ojn.song_id());
    let hard = ChartIdentity::ojn(2).unwrap().chart_id(&ojn.song_id());
    assert_ne!(easy, normal);
    assert_ne!(normal, hard);
    assert_eq!(
        easy.to_string(),
        "chart:sha256:c209545f0ec20eccd41481e06f572fbaa07d570bf8c8d5ad7355f212ef28b18d"
    );

    let declared_song = SongId::from_digest(digest);
    let declared_chart = ChartId::from_digest(digest);
    assert_eq!(
        SongIdentity::bundle_declared(declared_song).song_id(),
        declared_song
    );
    assert_eq!(
        ChartIdentity::bundle_declared(declared_chart).chart_id(&declared_song),
        declared_chart
    );
}

#[test]
fn identity_wire_deserialization_cannot_bypass_validation() {
    assert!(
        serde_json::from_str::<SongIdentity>(
            r#"{"kind":"VOS","packagePath":"pack/song.vos","identityTitle":""}"#,
        )
        .is_err()
    );
    assert!(
        serde_json::from_str::<SongIdentity>(
            r#"{"kind":"VOS","packagePath":"../song.vos","identityTitle":"title"}"#,
        )
        .is_err()
    );
    assert!(serde_json::from_str::<ChartIdentity>(r#"{"kind":"VOS","index":1}"#).is_err());
    assert!(serde_json::from_str::<ChartIdentity>(r#"{"kind":"OJN","index":3}"#).is_err());
    assert!(
        serde_json::from_str::<ChartIdentity>(r#"{"kind":"OSU","relativePath":"../chart.osu"}"#,)
            .is_err()
    );
    assert!(
        serde_json::from_str::<ChartIdentity>(r#"{"kind":"VOS","index":0,"unexpected":true}"#,)
            .is_err()
    );
}
