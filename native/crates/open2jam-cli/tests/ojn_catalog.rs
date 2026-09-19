use std::{fs, path::PathBuf, process::Command};

const MINIMAL: &[u8] =
    include_bytes!("../../../../rewrite/golden/java-migration/sources/ojn/minimal.ojn");

struct Library(PathBuf);
impl Library {
    fn new(name: &str) -> Self {
        let root = std::env::temp_dir().join(format!("ojn-catalog-{name}-{}", std::process::id()));
        fs::create_dir(&root).unwrap();
        fs::create_dir(root.join("staging")).unwrap();
        fs::create_dir_all(root.join("songs/nested")).unwrap();
        fs::write(root.join("songs/nested/song.OJN"), MINIMAL).unwrap();
        Self(root.canonicalize().unwrap())
    }
    fn scan(
        &self,
        name: &str,
        directory: &str,
        id: Option<&str>,
    ) -> (serde_json::Value, serde_json::Value) {
        let source = self.0.join(directory);
        let mut request = serde_json::json!({"schemaVersion":1,"jobId":name,"command":"CATALOG",
            "roots":[source],"previousIndexPath":null,"stagingRoot":self.0.join("staging"),
            "cancelMarkerPath":self.0.join("cancel")});
        if let Some(id) = id {
            request["rootIds"] = serde_json::json!({source.to_str().unwrap():id});
        }
        let request_path = self.0.join(format!("{name}.request.json"));
        let result_path = self.0.join(format!("{name}.result.json"));
        fs::write(&request_path, serde_json::to_vec(&request).unwrap()).unwrap();
        let output = Command::new(env!("CARGO_BIN_EXE_open2jam-converter"))
            .args(["catalog", "--request"])
            .arg(request_path)
            .arg("--progress")
            .arg(self.0.join(format!("{name}.progress.jsonl")))
            .arg("--result")
            .arg(&result_path)
            .output()
            .unwrap();
        assert!(
            result_path.exists(),
            "CLI exit {:?}: {}",
            output.status.code(),
            String::from_utf8_lossy(&output.stderr)
        );
        let result: serde_json::Value =
            serde_json::from_slice(&fs::read(result_path).unwrap()).unwrap();
        assert!(output.status.success(), "{result}");
        let catalog = serde_json::from_slice(
            &fs::read(result["output"]["catalogPath"].as_str().unwrap()).unwrap(),
        )
        .unwrap();
        (result, catalog)
    }
}
impl Drop for Library {
    fn drop(&mut self) {
        fs::remove_dir_all(&self.0).unwrap();
    }
}

#[test]
fn raw_ojn_catalog_groups_three_charts_and_preserves_identity_on_relocation() {
    let library = Library::new("identity");
    let id = format!("library:sha256:{}", "01".repeat(32));
    let (result, catalog) = library.scan("first", "songs", Some(&id));
    assert_eq!(result["output"]["sourceCount"], 1);
    assert_eq!(result["output"]["songCount"], 1);
    assert_eq!(result["output"]["chartCount"], 3);
    let entries = catalog["entries"].as_array().unwrap();
    assert_eq!(entries.len(), 3);
    for (index, entry) in entries.iter().enumerate() {
        assert_eq!(entry["rootId"], id);
        assert_eq!(entry["sourceKind"], "OJN");
        assert_eq!(entry["relativePath"], "nested/song.OJN");
        assert_eq!(entry["chartIndex"], index);
        assert_eq!(entry["level"], [3, 5, 8][index]);
        assert_eq!(entry["durationSeconds"], 91);
        assert_eq!(entry["title"], "Minimal O2Jam");
        assert_eq!(entry["songId"], entries[0]["songId"]);
        for other in &entries[..index] {
            assert_ne!(entry["chartId"], other["chartId"]);
        }
    }
    fs::rename(library.0.join("songs"), library.0.join("moved")).unwrap();
    let (_, moved) = library.scan("relocated", "moved", Some(&id));
    for (index, entry) in entries.iter().enumerate() {
        assert_eq!(moved["entries"][index]["songId"], entry["songId"]);
        assert_eq!(moved["entries"][index]["chartId"], entry["chartId"]);
    }
    let new_id = format!("library:sha256:{}", "02".repeat(32));
    let (_, added) = library.scan("added-source", "moved", Some(&new_id));
    assert_ne!(added["entries"][0]["songId"], entries[0]["songId"]);
}

#[test]
fn ojn_catalog_reports_missing_root_identity_without_path_based_fallback() {
    let library = Library::new("missing-id");
    let (result, catalog) = library.scan("missing", "songs", None);
    assert_eq!(result["output"]["sourceCount"], 1);
    assert_eq!(result["output"]["songCount"], 0);
    assert_eq!(result["output"]["chartCount"], 0);
    assert_eq!(result["output"]["rejectedSourceCount"], 1);
    assert_eq!(catalog["entries"], serde_json::json!([]));
    assert_eq!(catalog["rejected"][0]["error"]["code"], "INVALID_REQUEST");
    assert!(
        catalog["rejected"][0]["error"]["message"]
            .as_str()
            .unwrap()
            .contains("root ID")
    );
}

#[test]
fn ojn_catalog_isolates_truncated_and_oversized_sources() {
    let library = Library::new("invalid");
    fs::write(library.0.join("songs/truncated.ojn"), &MINIMAL[..299]).unwrap();
    let oversized = fs::File::create(library.0.join("songs/oversized.ojn")).unwrap();
    oversized.set_len(64 * 1024 * 1024 + 1).unwrap();
    let id = format!("library:sha256:{}", "01".repeat(32));
    let (result, catalog) = library.scan("invalid", "songs", Some(&id));
    assert_eq!(result["output"]["sourceCount"], 3);
    assert_eq!(result["output"]["songCount"], 1);
    assert_eq!(result["output"]["chartCount"], 3);
    assert_eq!(result["output"]["rejectedSourceCount"], 2);
    for entry in catalog["rejected"].as_array().unwrap() {
        assert_eq!(entry["error"]["code"], "CORRUPT_CHART");
    }
}

#[test]
fn mixed_catalog_counts_sources_separately_from_charts_and_keeps_same_title_files_distinct() {
    let library = Library::new("mixed");
    fs::write(library.0.join("songs/another.ojn"), MINIMAL).unwrap();
    assert!(
        Command::new(env!("CARGO_BIN_EXE_controlled-bundle-probe"))
            .arg(library.0.join("songs/export.ojn"))
            .output()
            .unwrap()
            .status
            .success()
    );
    let id = format!("library:sha256:{}", "01".repeat(32));
    let (result, catalog) = library.scan("mixed", "songs", Some(&id));
    assert_eq!(result["output"]["sourceCount"], 3);
    assert_eq!(result["output"]["songCount"], 3);
    assert_eq!(result["output"]["chartCount"], 7);
    let entries = catalog["entries"].as_array().unwrap();
    let raw: Vec<_> = entries
        .iter()
        .filter(|entry| entry["sourceKind"] == "OJN")
        .collect();
    assert_eq!(raw.len(), 6);
    assert_ne!(raw[0]["songId"], raw[3]["songId"]);
    assert_eq!(raw[0]["title"], raw[3]["title"]);
    assert!(raw[0].get("soundfont").is_none());
    let bundle = entries
        .iter()
        .find(|entry| entry["sourceKind"] == "BUNDLE_V2")
        .unwrap();
    assert_eq!(bundle["relativePath"], "export.ojn");
    assert!(bundle.get("soundfont").is_some());
    assert!(bundle.get("chartIndex").is_none());
}

const OSU: &str =
    include_str!("../../../../rewrite/golden/java-migration/sources/osu/seven-key.osu");

#[test]
fn osu_catalog_groups_beatmap_sets_and_preserves_selection_on_relocation() {
    let library = Library::new("osu-identity");
    fs::write(library.0.join("songs/nested/easy.osu"), OSU).unwrap();
    fs::write(
        library.0.join("songs/nested/hard.OSU"),
        OSU.replace("Version:Test 7K", "Version:Hard 7K"),
    )
    .unwrap();
    fs::write(library.0.join("songs/root.osu"), OSU).unwrap();
    let id = format!("library:sha256:{}", "01".repeat(32));
    let (result, catalog) = library.scan("osu-first", "songs", Some(&id));
    assert_eq!(result["output"]["sourceCount"], 4);
    assert_eq!(result["output"]["songCount"], 3);
    assert_eq!(result["output"]["chartCount"], 6);
    let entries = catalog["entries"].as_array().unwrap();
    let osu: Vec<_> = entries
        .iter()
        .filter(|e| e["sourceKind"] == "OSU")
        .collect();
    assert_eq!(osu.len(), 3);
    assert_eq!(osu[0]["relativePath"], "nested/easy.osu");
    assert_eq!(osu[0]["chartPath"], "easy.osu");
    assert_eq!(osu[0]["difficultyName"], "Test 7K");
    assert_eq!(osu[1]["difficultyName"], "Hard 7K");
    assert_eq!(osu[0]["songId"], osu[1]["songId"]);
    assert_ne!(osu[0]["chartId"], osu[1]["chartId"]);
    assert_ne!(osu[0]["songId"], osu[2]["songId"]);
    for entry in &osu {
        assert_eq!(entry["rootId"], id);
        assert_eq!(entry["title"], "Seven Key Fixture");
        assert_eq!(entry["artist"], "Fixture Artist");
        assert_eq!(entry["level"], 8);
        assert_eq!(entry["durationSeconds"], 3);
        assert!(entry.get("soundfont").is_none());
    }
    fs::rename(library.0.join("songs"), library.0.join("moved")).unwrap();
    let (_, moved) = library.scan("osu-moved", "moved", Some(&id));
    for (index, entry) in entries.iter().enumerate() {
        assert_eq!(moved["entries"][index]["songId"], entry["songId"]);
        assert_eq!(moved["entries"][index]["chartId"], entry["chartId"]);
    }
    let (_, added) = library.scan(
        "osu-added",
        "moved",
        Some(&format!("library:sha256:{}", "02".repeat(32))),
    );
    for (index, entry) in entries.iter().enumerate() {
        assert_ne!(added["entries"][index]["songId"], entry["songId"]);
    }
}

#[test]
fn osu_catalog_isolates_unsupported_corrupt_and_unidentified_sources() {
    let library = Library::new("osu-invalid");
    for (name, text) in [
        ("valid", OSU.to_owned()),
        ("four-key", OSU.replace("CircleSize:7", "CircleSize:4")),
        ("standard", OSU.replace("Mode: 3", "Mode: 0")),
        ("broken", "broken".into()),
    ] {
        fs::write(library.0.join(format!("songs/{name}.osu")), text).unwrap();
    }
    fs::File::create(library.0.join("songs/oversized.osu"))
        .unwrap()
        .set_len(64 * 1024 * 1024 + 1)
        .unwrap();
    let id = format!("library:sha256:{}", "01".repeat(32));
    let (result, catalog) = library.scan("osu-invalid", "songs", Some(&id));
    assert_eq!(result["output"]["sourceCount"], 6);
    assert_eq!(result["output"]["songCount"], 2);
    assert_eq!(result["output"]["chartCount"], 4);
    assert_eq!(result["output"]["rejectedSourceCount"], 4);
    let rejected = catalog["rejected"].as_array().unwrap();
    assert_eq!(
        rejected
            .iter()
            .filter(|e| e["error"]["code"] == "UNSUPPORTED_FORMAT")
            .count(),
        2
    );
    assert_eq!(
        rejected
            .iter()
            .filter(|e| e["error"]["code"] == "CORRUPT_CHART")
            .count(),
        2
    );
    let (result, catalog) = library.scan("osu-no-id", "songs", None);
    assert_eq!(result["output"]["chartCount"], 0);
    assert_eq!(result["output"]["rejectedSourceCount"], 6);
    assert!(
        catalog["rejected"]
            .as_array()
            .unwrap()
            .iter()
            .all(|entry| entry["error"]["code"] == "INVALID_REQUEST")
    );
}
