use open2jam_core::bundle::load_bundle_documents;
use std::{fs, process::Command};

#[test]
fn native_probe_generates_a_relocatable_bundle_without_overwriting() {
    let parent = std::env::temp_dir().join(format!("controlled-bundle-{}", std::process::id()));
    fs::create_dir(&parent).unwrap();
    let output = parent.join("generated bundle");
    let invoke = || {
        Command::new(env!("CARGO_BIN_EXE_controlled-bundle-probe"))
            .arg(&output)
            .output()
            .unwrap()
    };
    let result = invoke();
    assert!(
        result.status.success(),
        "{}",
        String::from_utf8_lossy(&result.stderr)
    );
    let first = load_bundle_documents(&output, None).unwrap();
    assert_eq!(first.chart().notes().len(), 3);
    assert!(first.chart().notes()[1].tail().is_some());
    let before = fs::read(output.join("bundle.json")).unwrap();
    assert!(!invoke().status.success());
    assert_eq!(fs::read(output.join("bundle.json")).unwrap(), before);
    let relocated = parent.join("relocated");
    fs::rename(&output, &relocated).unwrap();
    let second = load_bundle_documents(&relocated, None).unwrap();
    assert_eq!(first.bundle().manifest(), second.bundle().manifest());
    let wave = fs::read(relocated.join("audio/tone.wav")).unwrap();
    assert_eq!(&wave[..12], b"RIFF\x68\xac\x00\x00WAVE");
    assert_eq!(wave.len(), 44 + 11025 * 4);
    fs::remove_dir_all(parent).unwrap();
}
