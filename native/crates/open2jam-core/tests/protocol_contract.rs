use std::collections::BTreeMap;

use open2jam_core::digest::Digest;
use open2jam_core::error::{CoreError, ErrorCode, ErrorInfo};
use open2jam_core::format::{Format, SourceKind};
use open2jam_core::id::{BundleKey, ChartId, JobId, SampleId, SongId, SourceFingerprint};
use open2jam_core::json::{decode_contract, encode_contract};
use open2jam_core::path::{AbsoluteSourcePath, BundleRelativePath, SourceRelativePath};
use open2jam_core::protocol::{
    BundleRequestV1, CatalogOutputV1, CatalogRequestV1, ChartSelector, Command, CommandResultV1,
    JobStatus, SoundFontRequest,
};
use open2jam_core::schema::{
    AUDIO_MANIFEST_SCHEMA_VERSION, BUNDLE_KEY_ALGORITHM_VERSION, BUNDLE_SCHEMA_VERSION,
    CATALOG_SCHEMA_VERSION, GAMEPLAY_SCHEMA_VERSION, ID_ALGORITHM_VERSION, PROGRESS_SCHEMA_VERSION,
    PROTOCOL_SCHEMA_VERSION, REQUEST_SCHEMA_VERSION, RESULT_SCHEMA_VERSION,
    SOURCE_FINGERPRINT_VERSION, STATIC_ASSETS_VERSION,
};

const ZERO_DIGEST: &str = "sha256:0000000000000000000000000000000000000000000000000000000000000000";
const VALID_CATALOG: &[u8] = include_bytes!("fixtures/valid/catalog-request-v1.json");
const VALID_BUNDLE: &[u8] = include_bytes!("fixtures/valid/bundle-request-v1.json");
const VALID_RESULT: &[u8] = include_bytes!("fixtures/valid/catalog-result-v1.json");

#[test]
fn schema_constants_are_frozen() {
    assert_eq!(PROTOCOL_SCHEMA_VERSION, 1);
    assert_eq!(REQUEST_SCHEMA_VERSION, 1);
    assert_eq!(RESULT_SCHEMA_VERSION, 1);
    assert_eq!(PROGRESS_SCHEMA_VERSION, 1);
    assert_eq!(CATALOG_SCHEMA_VERSION, 2);
    assert_eq!(BUNDLE_SCHEMA_VERSION, 2);
    assert_eq!(GAMEPLAY_SCHEMA_VERSION, 2);
    assert_eq!(AUDIO_MANIFEST_SCHEMA_VERSION, 2);
    assert_eq!(ID_ALGORITHM_VERSION, 2);
    assert_eq!(SOURCE_FINGERPRINT_VERSION, 1);
    assert_eq!(BUNDLE_KEY_ALGORITHM_VERSION, 1);
    assert_eq!(STATIC_ASSETS_VERSION, "open2jam-gameplay-assets-v1");
}

#[test]
fn digest_is_strict_lowercase_full_sha256() {
    let digest = Digest::parse(ZERO_DIGEST).expect("valid digest");
    assert_eq!(digest.to_string(), ZERO_DIGEST);
    assert_eq!(digest.as_bytes(), &[0; 32]);
    assert_eq!(Digest::from_bytes([0; 32]), digest);

    for value in [
        "sha256:ABC",
        "SHA256:0000000000000000000000000000000000000000000000000000000000000000",
        "sha256:000000000000000000000000000000000000000000000000000000000000000A",
        "sha256:000000000000000000000000000000000000000000000000000000000000000",
        "sha256:00000000000000000000000000000000000000000000000000000000000000000",
        "md5:0000000000000000000000000000000000000000000000000000000000000000",
    ] {
        assert!(Digest::parse(value).is_err(), "accepted {value}");
    }
}

#[test]
fn typed_digest_newtypes_remain_distinct_and_strict() {
    let digest = Digest::parse(ZERO_DIGEST).expect("valid digest");
    let source = open2jam_core::id::SourceId::from_digest(digest);
    let song = SongId::from_digest(digest);
    let chart = ChartId::from_digest(digest);
    let sample = SampleId::from_digest(digest);
    let fingerprint = SourceFingerprint::from_digest(digest);
    let bundle_key = BundleKey::from_digest(digest);

    assert_eq!(source.to_string(), format!("source:{ZERO_DIGEST}"));
    assert_eq!(song.to_string(), format!("song:{ZERO_DIGEST}"));
    assert_eq!(chart.to_string(), format!("chart:{ZERO_DIGEST}"));
    assert_eq!(sample.to_string(), format!("sample:{ZERO_DIGEST}"));
    assert_eq!(fingerprint.to_string(), ZERO_DIGEST);
    assert_eq!(bundle_key.to_string(), ZERO_DIGEST);
    assert_eq!(source.digest(), &digest);
    assert_eq!(song.digest(), &digest);
    assert_eq!(chart.digest(), &digest);
    assert_eq!(sample.digest(), &digest);
    assert_eq!(fingerprint.digest(), &digest);
    assert_eq!(bundle_key.digest(), &digest);

    assert!(serde_json::from_str::<SongId>(&format!("\"song:{ZERO_DIGEST}\"")).is_ok());
    assert!(serde_json::from_str::<SongId>(&format!("\"chart:{ZERO_DIGEST}\"")).is_err());
}

#[test]
fn relative_paths_preserve_their_separate_contracts() {
    assert!(BundleRelativePath::parse("audio/sample.wav").is_ok());
    for value in [
        "../sample.wav",
        "C:\\sample.wav",
        "/audio/sample.wav",
        "audio//sample.wav",
        "audio/./sample.wav",
        "audio/../sample.wav",
        "audio/sample wav",
        "音楽/sample.wav",
        "audio/sample.wav/",
        "audio\0sample.wav",
    ] {
        assert!(
            BundleRelativePath::parse(value).is_err(),
            "accepted {value:?}"
        );
    }

    let source = SourceRelativePath::parse("音楽/譜面.osu").expect("valid source path");
    assert_eq!(source.as_str(), "音楽/譜面.osu");
    for value in [
        "../譜面.osu",
        "/音楽/譜面.osu",
        "音楽//譜面.osu",
        "音楽/./譜面.osu",
        "音楽\\譜面.osu",
        "C:/譜面.osu",
        "音楽/譜面.osu/",
        "音楽\0譜面.osu",
    ] {
        assert!(
            SourceRelativePath::parse(value).is_err(),
            "accepted {value:?}"
        );
    }
}

#[test]
fn absolute_paths_preserve_exact_utf8_without_lexical_traversal() {
    let value = "/tmp/音楽/譜面.osu";
    let path = AbsoluteSourcePath::parse(value).expect("valid absolute path");
    assert_eq!(path.as_path().to_str(), Some(value));
    assert_eq!(path.clone().into_path_buf().to_str(), Some(value));

    for value in [
        "",
        "relative/file",
        "/tmp/./file",
        "/tmp/../file",
        "/tmp/a\0b",
    ] {
        assert!(
            AbsoluteSourcePath::parse(value).is_err(),
            "accepted {value:?}"
        );
    }
}

#[test]
fn job_id_is_a_portable_filename_component() {
    for value in ["a", "job-001", "A_b.c-9"] {
        assert_eq!(JobId::parse(value).expect("valid job id").as_str(), value);
    }

    let overlong = "a".repeat(129);
    for value in [
        "", ".", "..", "job:1", "-job", "_job", ".job", "job/1", "job\\1", "job ", "job.", "CON",
        "con.txt", "PRN", "AUX.log", "NUL", "COM1", "com9.txt", "LPT1", "lpt9.log",
    ] {
        assert!(JobId::parse(value).is_err(), "accepted {value:?}");
    }
    assert!(JobId::parse(&overlong).is_err());
}

#[test]
fn format_source_and_error_spellings_are_frozen() {
    assert_eq!(serde_json::to_string(&Format::Vos).unwrap(), "\"VOS\"");
    assert_eq!(serde_json::to_string(&Format::O2Jam).unwrap(), "\"O2JAM\"");
    assert_eq!(
        serde_json::to_string(&Format::OsuMania).unwrap(),
        "\"OSU_MANIA\""
    );
    assert_eq!(
        serde_json::to_string(&Format::Bundle).unwrap(),
        "\"BUNDLE\""
    );
    assert_eq!(
        serde_json::to_string(&SourceKind::BundleV2).unwrap(),
        "\"BUNDLE_V2\""
    );
    assert_eq!(ErrorCode::MissingAsset.as_str(), "MISSING_ASSET");
    assert_eq!(Command::Catalog.as_str(), "CATALOG");
    assert_eq!(Command::Bundle.as_str(), "BUNDLE");
}

#[test]
fn valid_fixtures_round_trip_to_exact_compact_json_lf() {
    let catalog: CatalogRequestV1 = decode_contract(VALID_CATALOG).expect("catalog fixture");
    assert_eq!(encode_contract(&catalog).unwrap(), VALID_CATALOG);

    let bundle: BundleRequestV1 = decode_contract(VALID_BUNDLE).expect("bundle fixture");
    assert_eq!(encode_contract(&bundle).unwrap(), VALID_BUNDLE);

    let result: CommandResultV1<CatalogOutputV1> =
        decode_contract(VALID_RESULT).expect("result fixture");
    assert_eq!(encode_contract(&result).unwrap(), VALID_RESULT);
}

#[test]
fn exact_malformed_fixture_matrix_fails_closed_with_stable_codes() {
    let cases: &[(&[u8], ErrorCode)] = &[
        (
            include_bytes!("fixtures/malformed/unknown-field.json"),
            ErrorCode::InvalidRequest,
        ),
        (
            include_bytes!("fixtures/malformed/duplicate-field.json"),
            ErrorCode::InvalidRequest,
        ),
        (
            include_bytes!("fixtures/malformed/wrong-schema.json"),
            ErrorCode::UnsupportedSchema,
        ),
        (
            include_bytes!("fixtures/malformed/trailing-data.json"),
            ErrorCode::InvalidRequest,
        ),
        (
            include_bytes!("fixtures/malformed/bom.json"),
            ErrorCode::InvalidRequest,
        ),
    ];

    for (bytes, expected) in cases {
        let error = decode_contract::<CatalogRequestV1>(bytes).unwrap_err();
        assert_eq!(error.code(), *expected);
    }

    let invalid_utf8 = [0xff, 0xfe, 0xfd];
    assert_eq!(
        decode_contract::<CatalogRequestV1>(&invalid_utf8)
            .unwrap_err()
            .code(),
        ErrorCode::InvalidRequest
    );
}

#[test]
fn error_info_rejects_nul_and_core_error_falls_back_safely() {
    let wire =
        br#"{"code":"CORRUPT_CHART","message":"bad\u0000message","sourcePath":null,"context":{}}"#;
    assert_eq!(
        decode_contract::<CommandResultV1<CatalogOutputV1>>(
            br#"{"schemaVersion":1,"jobId":"job-001","command":"CATALOG","status":"FAILED","output":null,"error":{"code":"CORRUPT_CHART","message":"bad\u0000message","sourcePath":null,"context":{}}}"#,
        )
        .unwrap_err()
        .code(),
        ErrorCode::InvalidRequest
    );
    assert!(serde_json::from_slice::<ErrorInfo>(wire).is_err());

    let fallback = CoreError::new(ErrorCode::CorruptChart, "bad\0message");
    assert_eq!(fallback.code(), ErrorCode::InternalError);
    assert_eq!(fallback.message(), "error message contained NUL");
    assert!(!fallback.message().contains('\0'));

    let fallback = CoreError::new(ErrorCode::CorruptChart, "bad").with_context("key", "bad\0value");
    assert_eq!(fallback.code(), ErrorCode::InternalError);
    assert!(fallback.context().is_empty());
}

#[test]
fn bundle_request_selector_compatibility_is_exact() {
    let chart_id = ChartId::from_digest(Digest::parse(ZERO_DIGEST).unwrap());
    let valid = [
        (SourceKind::Vos, ChartSelector::VosChart { index: 0 }),
        (SourceKind::Ojn, ChartSelector::OjnChart { index: 0 }),
        (
            SourceKind::Osu,
            ChartSelector::OsuBeatmap {
                relative_path: SourceRelativePath::parse("set/chart.osu").unwrap(),
            },
        ),
        (
            SourceKind::Osz,
            ChartSelector::OsuBeatmap {
                relative_path: SourceRelativePath::parse("set/chart.osu").unwrap(),
            },
        ),
        (
            SourceKind::BundleV2,
            ChartSelector::BundleChart { chart_id },
        ),
    ];

    for (kind, selector) in valid {
        assert!(bundle_request(kind, selector, chart_id).validate().is_ok());
    }

    for (kind, selector) in [
        (SourceKind::Vos, ChartSelector::OjnChart { index: 0 }),
        (SourceKind::Ojn, ChartSelector::VosChart { index: 0 }),
        (SourceKind::Osu, ChartSelector::BundleChart { chart_id }),
        (
            SourceKind::BundleV2,
            ChartSelector::OsuBeatmap {
                relative_path: SourceRelativePath::parse("set/chart.osu").unwrap(),
            },
        ),
    ] {
        assert!(bundle_request(kind, selector, chart_id).validate().is_err());
    }

    let other = ChartId::from_digest(Digest::from_bytes([1; 32]));
    assert!(
        bundle_request(
            SourceKind::BundleV2,
            ChartSelector::BundleChart { chart_id: other },
            chart_id,
        )
        .validate()
        .is_err()
    );
}

#[test]
fn command_result_constructors_preserve_envelope_invariants() {
    let job_id = JobId::parse("job-001").unwrap();
    let output = CatalogOutputV1 {
        catalog_path: AbsoluteSourcePath::parse("/tmp/catalog.json").unwrap(),
        source_count: 1,
        song_count: 1,
        chart_count: 1,
        rejected_source_count: 0,
    };
    let succeeded = CommandResultV1::succeeded(job_id.clone(), Command::Catalog, output);
    assert_eq!(succeeded.status, JobStatus::Succeeded);
    assert!(succeeded.validate().is_ok());

    let failed = CommandResultV1::<CatalogOutputV1>::failed(
        job_id.clone(),
        Command::Catalog,
        CoreError::new(ErrorCode::CorruptChart, "bad chart").into(),
    );
    assert!(failed.validate().is_ok());

    let cancelled = CommandResultV1::<CatalogOutputV1>::cancelled(
        job_id,
        Command::Catalog,
        CoreError::new(ErrorCode::Cancelled, "cancelled").into(),
    );
    assert!(cancelled.validate().is_ok());

    let protocol_failure = CommandResultV1::<CatalogOutputV1>::protocol_failure(
        Command::Catalog,
        CoreError::new(ErrorCode::InvalidRequest, "invalid request").into(),
    );
    assert!(protocol_failure.validate().is_ok());

    let invalid_protocol_failure = CommandResultV1::<CatalogOutputV1> {
        schema_version: 1,
        job_id: None,
        command: Command::Catalog,
        status: JobStatus::Failed,
        output: None,
        error: Some(CoreError::new(ErrorCode::CorruptChart, "bad chart").into()),
    };
    assert!(invalid_protocol_failure.validate().is_err());
}

#[test]
fn catalog_roots_must_be_unique_and_sorted() {
    let mut request: CatalogRequestV1 = decode_contract(VALID_CATALOG).unwrap();
    request.roots = vec![
        AbsoluteSourcePath::parse("/tmp/z").unwrap(),
        AbsoluteSourcePath::parse("/tmp/a").unwrap(),
    ];
    assert!(request.validate().is_err());

    request.roots.sort();
    assert!(request.validate().is_ok());

    request
        .roots
        .push(AbsoluteSourcePath::parse("/tmp/z").unwrap());
    assert!(request.validate().is_err());
}

fn bundle_request(
    source_kind: SourceKind,
    selector: ChartSelector,
    chart_id: ChartId,
) -> BundleRequestV1 {
    BundleRequestV1 {
        schema_version: 1,
        job_id: JobId::parse("job-002").unwrap(),
        command: Command::Bundle,
        chart_id,
        source_path: AbsoluteSourcePath::parse("/tmp/chart.vos").unwrap(),
        source_kind,
        selector,
        staging_root: AbsoluteSourcePath::parse("/tmp/staging").unwrap(),
        cancel_marker_path: AbsoluteSourcePath::parse("/tmp/cancel/job-002").unwrap(),
        soundfont: SoundFontRequest {
            path: AbsoluteSourcePath::parse("/tmp/assets/soundfont.sf2").unwrap(),
            version: "2.0.3".to_owned(),
            sha256: Digest::parse(ZERO_DIGEST).unwrap(),
        },
        static_assets_version: STATIC_ASSETS_VERSION.to_owned(),
    }
}

#[test]
fn error_code_list_is_complete_and_context_is_sorted() {
    let codes = [
        ErrorCode::UnsupportedFormat,
        ErrorCode::CorruptChart,
        ErrorCode::MissingCompanion,
        ErrorCode::MissingAsset,
        ErrorCode::AudioDecodeFailed,
        ErrorCode::SoundfontFailed,
        ErrorCode::OutOfSpace,
        ErrorCode::CacheCorrupt,
        ErrorCode::ConverterCrashed,
        ErrorCode::Cancelled,
        ErrorCode::InternalError,
        ErrorCode::InvalidRequest,
        ErrorCode::UnsupportedSchema,
        ErrorCode::SourceChanged,
    ];
    assert_eq!(codes.len(), 14);

    let error = CoreError::new(ErrorCode::CorruptChart, "bad chart")
        .with_context("z", "last")
        .with_context("a", "first");
    assert_eq!(
        error.context().keys().collect::<Vec<_>>(),
        vec![&"a".to_owned(), &"z".to_owned()]
    );
    let _: BTreeMap<String, String> = error.context().clone();
}

#[test]
fn source_paths_preserve_non_drive_colons_but_bundle_paths_remain_portable() {
    let value = "set/song:alternate.osu";
    let path = SourceRelativePath::parse(value).expect("valid source filename");
    assert_eq!(path.as_str(), value);
    assert_eq!(
        serde_json::from_str::<SourceRelativePath>(&serde_json::to_string(&path).unwrap()).unwrap(),
        path
    );
    assert!(SourceRelativePath::parse("C:chart.osu").is_err());
    assert!(BundleRelativePath::parse(value).is_err());
}

#[test]
fn catalog_can_represent_an_empty_library() {
    let mut request: CatalogRequestV1 = decode_contract(VALID_CATALOG).unwrap();
    request.roots.clear();
    let encoded = encode_contract(&request).expect("empty root list is a valid catalog request");
    assert_eq!(
        decode_contract::<CatalogRequestV1>(&encoded).unwrap(),
        request
    );
}

#[test]
fn catalog_carries_persistent_root_ids_independently_of_current_paths() {
    let mut value: serde_json::Value = serde_json::from_slice(VALID_CATALOG).unwrap();
    let root_id = format!("library:{ZERO_DIGEST}");
    value["rootIds"] = serde_json::json!({"/tmp/open2jam-songs": root_id});
    let request: CatalogRequestV1 = decode_contract(&serde_json::to_vec(&value).unwrap()).unwrap();
    let encoded: serde_json::Value =
        serde_json::from_slice(&encode_contract(&request).unwrap()).unwrap();
    assert_eq!(encoded["rootIds"], value["rootIds"]);
    value["roots"] = serde_json::json!(["/tmp/relocated-songs"]);
    value["rootIds"] = serde_json::json!({"/tmp/relocated-songs": root_id});
    let moved: CatalogRequestV1 = decode_contract(&serde_json::to_vec(&value).unwrap()).unwrap();
    let encoded: serde_json::Value =
        serde_json::from_slice(&encode_contract(&moved).unwrap()).unwrap();
    assert_eq!(encoded["rootIds"]["/tmp/relocated-songs"], root_id);
}

#[test]
fn catalog_rejects_incomplete_foreign_or_reused_root_ids() {
    let first = format!("library:{ZERO_DIGEST}");
    let second = format!("library:{}", Digest::from_bytes([1; 32]));
    for ids in [
        serde_json::json!({"/tmp/a": first}),
        serde_json::json!({"/tmp/a": first, "/tmp/foreign": second}),
        serde_json::json!({"/tmp/a": first, "/tmp/b": first}),
        serde_json::json!({"/tmp/a": first, "/tmp/b": "library:bad"}),
    ] {
        let mut value: serde_json::Value = serde_json::from_slice(VALID_CATALOG).unwrap();
        value["roots"] = serde_json::json!(["/tmp/a", "/tmp/b"]);
        value["rootIds"] = ids;
        assert!(decode_contract::<CatalogRequestV1>(&serde_json::to_vec(&value).unwrap()).is_err());
    }
}
