use std::{fs, path::PathBuf, process::Command};

#[test]
fn real_catalog_keeps_bundle_origins_distinct_and_isolates_corrupt_sources() {
    let root = std::env::temp_dir().join(format!("catalog-cli-{}", std::process::id()));
    fs::create_dir(&root).unwrap();
    let root = root.canonicalize().unwrap();
    for name in ["library-a/good", "library-a/bad", "library-b/good"] {
        fs::create_dir_all(root.join(name).parent().unwrap()).unwrap();
        assert!(
            Command::new(env!("CARGO_BIN_EXE_controlled-bundle-probe"))
                .arg(root.join(name))
                .output()
                .unwrap()
                .status
                .success()
        );
    }
    fs::remove_file(root.join("library-a/bad/audio/tone.wav")).unwrap();
    fs::create_dir(root.join("staging")).unwrap();
    let first_id = format!("library:sha256:{}", "01".repeat(32));
    let second_id = format!("library:sha256:{}", "02".repeat(32));
    let request = serde_json::json!({"schemaVersion":1,"jobId":"catalog-one","command":"CATALOG",
        "roots":[root.join("library-a"),root.join("library-b")],
        "rootIds": {root.join("library-a").to_str().unwrap(): first_id, root.join("library-b").to_str().unwrap(): second_id},
        "previousIndexPath":null,
        "stagingRoot":root.join("staging"),"cancelMarkerPath":root.join("cancel")});
    fs::write(
        root.join("request.json"),
        serde_json::to_vec(&request).unwrap(),
    )
    .unwrap();
    let output = Command::new(env!("CARGO_BIN_EXE_open2jam-converter"))
        .args(["catalog", "--request"])
        .arg(root.join("request.json"))
        .arg("--progress")
        .arg(root.join("progress.jsonl"))
        .arg("--result")
        .arg(root.join("result.json"))
        .output()
        .unwrap();
    let result: serde_json::Value =
        serde_json::from_slice(&fs::read(root.join("result.json")).unwrap()).unwrap();
    assert!(output.status.success(), "{result}");
    assert_eq!(result["output"]["sourceCount"], 3);
    assert_eq!(result["output"]["songCount"], 2);
    assert_eq!(result["output"]["rejectedSourceCount"], 1);
    let path = PathBuf::from(result["output"]["catalogPath"].as_str().unwrap());
    let catalog: serde_json::Value = serde_json::from_slice(&fs::read(path).unwrap()).unwrap();
    assert_eq!(catalog["schemaVersion"], 2);
    let entries = catalog["entries"].as_array().unwrap();
    assert_eq!(entries.len(), 2);
    assert_eq!(entries[0]["rootId"], first_id);
    assert_eq!(entries[1]["rootId"], second_id);
    assert_eq!(entries[0]["songId"], entries[1]["songId"]);
    assert_eq!(entries[0]["chartId"], entries[1]["chartId"]);
    assert_ne!(entries[0]["rootPath"], entries[1]["rootPath"]);
    assert_eq!(entries[0]["relativePath"], "good");
    assert_eq!(
        catalog["rejected"][0]["sourcePath"],
        root.join("library-a/bad").to_str().unwrap()
    );
    assert_eq!(catalog["rejected"][0]["error"]["code"], "CACHE_CORRUPT");
    let invoke = |request: &serde_json::Value, attempt: &str| {
        let request_path = root.join(format!("{attempt}.request.json"));
        let result_path = root.join(format!("{attempt}.result.json"));
        fs::write(&request_path, serde_json::to_vec(request).unwrap()).unwrap();
        let output = Command::new(env!("CARGO_BIN_EXE_open2jam-converter"))
            .args(["catalog", "--request"])
            .arg(request_path)
            .arg("--progress")
            .arg(root.join(format!("{attempt}.progress.jsonl")))
            .arg("--result")
            .arg(&result_path)
            .output()
            .unwrap();
        let result: serde_json::Value =
            serde_json::from_slice(&fs::read(result_path).unwrap()).unwrap();
        (output.status.code().unwrap(), result)
    };
    let saved = fs::read(root.join("staging/catalog-one/catalog-v2.json")).unwrap();
    let (code, _) = invoke(&request, "collision");
    assert_eq!(code, 4);
    assert_eq!(
        fs::read(root.join("staging/catalog-one/catalog-v2.json")).unwrap(),
        saved
    );
    fs::rename(root.join("library-a"), root.join("library-moved")).unwrap();
    let mut moved = request.clone();
    moved["jobId"] = "catalog-moved".into();
    moved["roots"] = serde_json::json!([root.join("library-b"), root.join("library-moved")]);
    moved["rootIds"] = serde_json::json!({root.join("library-b").to_str().unwrap(): second_id,
        root.join("library-moved").to_str().unwrap(): first_id});
    let (code, result) = invoke(&moved, "moved");
    assert_eq!(code, 0, "{result}");
    let moved_catalog: serde_json::Value = serde_json::from_slice(
        &fs::read(result["output"]["catalogPath"].as_str().unwrap()).unwrap(),
    )
    .unwrap();
    assert_eq!(
        moved_catalog["entries"][1]["chartId"],
        entries[0]["chartId"]
    );
    assert_eq!(
        moved_catalog["entries"][1]["sourcePath"],
        root.join("library-moved/good").to_str().unwrap()
    );
    assert_eq!(moved_catalog["entries"][1]["rootId"], first_id);
    moved["jobId"] = "catalog-cancelled".into();
    fs::write(root.join("cancel"), b"").unwrap();
    let (code, result) = invoke(&moved, "cancelled");
    assert_eq!(code, 3);
    assert_eq!(result["status"], "CANCELLED");
    assert!(!root.join("staging/catalog-cancelled").exists());
    fs::remove_dir_all(root).unwrap();
}
