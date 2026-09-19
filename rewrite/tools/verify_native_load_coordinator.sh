#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "$ROOT_DIR"
TEST_ROOT="$(mktemp -d /tmp/vos-native-async.XXXXXX)"
cleanup() {
    case "$TEST_ROOT" in
        /tmp/vos-native-async.*|/private/tmp/vos-native-async.*) rm -rf -- "$TEST_ROOT" ;;
        *) return 1 ;;
    esac
}
trap cleanup EXIT
mise exec -- cargo run --manifest-path native/Cargo.toml -p open2jam-cli --bin controlled-bundle-probe --locked -- "$TEST_ROOT/source"
mise exec -- cargo build --manifest-path native/Cargo.toml -p open2jam-cli --bin open2jam-converter --locked
mise exec -- python3 - "$TEST_ROOT" <<'PY'
import pathlib
import hashlib
import json
import shutil
import struct
import os
import subprocess
import sys
root = pathlib.Path(sys.argv[1]).resolve()
for name in ["hang-helper", "late-helper", "marker-error-helper", "bad-progress-helper", "truncated-progress-helper", "source-change-helper"]:
    helper = root / name
    body = pathlib.Path("rewrite/tools/native_load_test_helper.py").read_text().split("\n", 1)[1]
    helper.write_text("#!" + sys.executable + "\n" + body)
    helper.chmod(0o700)
# Independent key framing for the controlled OJN chart's producer-version variant.
variant = root / "version-source"
shutil.copytree(root / "source", variant)
manifest = json.loads((variant / "bundle.json").read_text())
manifest["converterVersion"] = "cache-test-next-version"
def framed(value):
    return struct.pack(">Q", len(value)) + value
def digest(value):
    return bytes.fromhex(value.split(":")[-1])
assert manifest["chartSelector"] == {"kind": "OJN_CHART", "index": 0}
key = b"open2jam.bundle-key.v1\0" + struct.pack(">HH", 1, 2)
key += framed(manifest["converterVersion"].encode()) + framed(manifest["staticAssetsVersion"].encode())
for value in [manifest["soundfont"]["sha256"], manifest["songId"], manifest["chartId"]]:
    key += framed(digest(value))
key += struct.pack(">HH", 2, 0) + framed(digest(manifest["sourceFingerprint"]))
manifest["bundleKey"] = "sha256:" + hashlib.sha256(key).hexdigest()
(variant / "bundle.json").write_text(json.dumps(manifest))
result = subprocess.run([
    "godot", "--headless", "--path", "rewrite/godot", "--log-file", str(root / "godot.log"),
    "--script", "res://scripts/tests/native_load_coordinator_test.gd", "--",
    str(pathlib.Path("native/target/debug/open2jam-converter").resolve()), str(root / "source"), str(root),
], capture_output=True, text=True, timeout=30)
print(result.stdout, end="")
marker = "Async native loading yielded frames, discarded cancelled generation and started current gameplay."
if result.returncode or marker not in result.stdout or "SCRIPT ERROR" in result.stderr or "SCRIPT ERROR" in result.stdout:
    print(result.stderr, file=sys.stderr)
    raise SystemExit("Native asynchronous loading gate failed")
ui_root = root / "ui"
ui_root.mkdir()
result = subprocess.run([
    "godot", "--headless", "--path", "rewrite/godot", "--log-file", str(root / "ui.log"),
    "--script", "res://scripts/tests/main_ui_native_load_test.gd", "--",
    str(pathlib.Path("native/target/debug/open2jam-converter").resolve()), str(root / "source"), str(ui_root),
], capture_output=True, text=True, timeout=30)
print(result.stdout, end="")
marker = "Native UI selected, cancelled, reselected and reached playable gameplay with bundled skin."
if result.returncode or marker not in result.stdout or "SCRIPT ERROR" in result.stderr or "SCRIPT ERROR" in result.stdout:
    print(result.stderr, file=sys.stderr)
    raise SystemExit("Native UI loading gate failed")

result = subprocess.run([
    "godot", "--headless", "--path", "rewrite/godot", "--log-file", str(root / "cache.log"),
    "--script", "res://scripts/tests/native_artifact_cache_test.gd", "--",
    str(pathlib.Path("native/target/debug/open2jam-converter").resolve()), str(root / "source"), str(root),
], capture_output=True, text=True, timeout=30)
print(result.stdout, end="")
marker = "Native artifact cache published validated output and reused a verified hit."
if result.returncode or marker not in result.stdout or "SCRIPT ERROR" in result.stderr or "SCRIPT ERROR" in result.stdout:
    print(result.stderr, file=sys.stderr)
    raise SystemExit("Native artifact cache gate failed")

for pid_file in root.rglob("*.pid"):
    try:
        os.kill(int(pid_file.read_text()), 0)
    except ProcessLookupError:
        continue
    raise SystemExit("Controlled helper was not reaped: " + pid_file.name)

PY

