use open2jam_core::digest::Digest;
use open2jam_core::format::SourceKind;
use open2jam_core::id::{
    ChartId, ChartIdentity, LibraryRootId, SongId, SongIdentity, SourceFingerprint,
    derive_sample_id, derive_source_id,
};
use open2jam_core::path::SourceRelativePath;

fn root(value: u8) -> LibraryRootId {
    LibraryRootId::from_digest(Digest::from_bytes([value; 32]))
}
fn path(value: &str) -> SourceRelativePath {
    SourceRelativePath::parse(value).unwrap()
}

#[test]
fn raw_song_identity_uses_root_and_relative_source_not_display_title() {
    let first = SongIdentity::vos(root(1), path("pack/song.vos"));
    assert_eq!(first, SongIdentity::vos(root(1), path("pack/song.vos")));
    assert_ne!(
        first.song_id(),
        SongIdentity::vos(root(2), path("pack/song.vos")).song_id()
    );
    assert_ne!(
        first.song_id(),
        SongIdentity::vos(root(1), path("other/song.vos")).song_id()
    );
    assert_ne!(
        first.song_id(),
        SongIdentity::osz_package(root(1), path("pack/song.vos")).song_id()
    );
    let wire = serde_json::to_value(&first).unwrap();
    assert_eq!(wire["rootId"], root(1).to_string());
    assert!(wire.get("title").is_none());
    assert!(wire.get("absolutePath").is_none());
    assert_eq!(serde_json::from_value::<SongIdentity>(wire).unwrap(), first);
}

#[test]
fn charts_group_by_song_and_bundle_declared_ids_remain_wire_ids() {
    let ojn = SongIdentity::ojn_file(root(1), path("album/song.ojn"));
    let easy = ChartIdentity::ojn(0).unwrap().chart_id(&ojn.song_id());
    let normal = ChartIdentity::ojn(1).unwrap().chart_id(&ojn.song_id());
    let hard = ChartIdentity::ojn(2).unwrap().chart_id(&ojn.song_id());
    assert_ne!(easy, normal);
    assert_ne!(normal, hard);
    assert_ne!(
        easy,
        ChartIdentity::ojn(0)
            .unwrap()
            .chart_id(&SongIdentity::ojn_file(root(2), path("album/song.ojn")).song_id())
    );
    let song = SongId::from_digest(Digest::from_bytes([0; 32]));
    let chart = ChartId::from_digest(Digest::from_bytes([0; 32]));
    assert_eq!(SongIdentity::bundle_declared(song).song_id(), song);
    assert_eq!(ChartIdentity::bundle_declared(chart).chart_id(&song), chart);
}

#[test]
fn identity_wire_deserialization_cannot_bypass_validation() {
    for wire in [
        r#"{"kind":"VOS","packagePath":"pack/song.vos","identityTitle":"title"}"#,
        r#"{"kind":"VOS","rootId":"invalid","packagePath":"pack/song.vos"}"#,
        r#"{"kind":"VOS","rootId":"library:sha256:0000000000000000000000000000000000000000000000000000000000000000","packagePath":"../song.vos"}"#,
    ] {
        assert!(serde_json::from_str::<SongIdentity>(wire).is_err());
    }
    for wire in [
        r#"{"kind":"VOS","index":1}"#,
        r#"{"kind":"OJN","index":3}"#,
        r#"{"kind":"OSU","relativePath":"../chart.osu"}"#,
        r#"{"kind":"VOS","index":0,"unexpected":true}"#,
    ] {
        assert!(serde_json::from_str::<ChartIdentity>(wire).is_err());
    }
}

#[test]
fn canonical_ids_match_independently_framed_python_vectors() {
    let vectors: serde_json::Value =
        serde_json::from_str(include_str!("fixtures/identity/v2-vectors.json")).unwrap();
    let fingerprint = SourceFingerprint::from_digest(Digest::from_bytes([0; 32]));
    let song = SongIdentity::ojn_file(root(1), path("album/song.ojn")).song_id();
    let chart = ChartIdentity::ojn(0).unwrap().chart_id(&song);
    let actual = [
        (
            "source",
            *derive_source_id(SourceKind::Vos, &fingerprint).digest(),
        ),
        ("sample", *derive_sample_id(fingerprint.digest()).digest()),
        ("song", *song.digest()),
        ("chart", *chart.digest()),
    ];
    for (name, digest) in actual {
        assert_eq!(
            digest.to_string(),
            format!("sha256:{}", vectors[name]["sha256"].as_str().unwrap()),
            "{name}"
        );
    }
    assert_ne!(
        derive_source_id(SourceKind::Vos, &fingerprint),
        derive_source_id(SourceKind::Ojn, &fingerprint)
    );
    assert_ne!(
        derive_sample_id(fingerprint.digest()),
        derive_sample_id(&Digest::from_bytes([1; 32]))
    );
}
