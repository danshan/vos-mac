use std::process::Command;

#[test]
fn version_command_emits_the_frozen_handshake() {
    let output = Command::new(env!("CARGO_BIN_EXE_open2jam-converter"))
        .arg("version")
        .output()
        .expect("version command must start");

    assert!(output.status.success());
    assert_eq!(
        output.stdout,
        b"{\"schemaVersion\":1,\"converterVersion\":\"0.1.0\",\"protocolSchemaVersion\":1,\"catalogSchemaVersion\":2,\"bundleSchemaVersion\":2,\"catalogFormats\":[\"O2JAM\",\"BUNDLE\"],\"bundleFormats\":[\"BUNDLE\"]}\n"
    );
    assert!(output.stderr.is_empty());
}
