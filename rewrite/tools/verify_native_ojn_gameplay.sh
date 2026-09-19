#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "$ROOT_DIR"
TEST_ROOT="$(mktemp -d /tmp/vos-native-ojn.XXXXXX)"
cleanup() {
    case "$TEST_ROOT" in
        /tmp/vos-native-ojn.*|/private/tmp/vos-native-ojn.*) rm -rf -- "$TEST_ROOT" ;;
        *) return 1 ;;
    esac
}
trap cleanup EXIT
mise exec -- cargo build --manifest-path native/Cargo.toml -p open2jam-cli --bin open2jam-converter --locked
mise exec -- python3 - "$TEST_ROOT" "${1:-minimal}" <<'PY'
import json
import pathlib
import struct
import subprocess
import sys

root = pathlib.Path(sys.argv[1]).resolve()
variant = sys.argv[2]
if variant not in {"minimal", "omc"}:
    raise SystemExit("Expected minimal or omc fixture variant")
for directory in ["songs", "catalog", "work"]:
    (root / directory).mkdir()
fixtures = pathlib.Path("rewrite/golden/java-migration/sources/ojn")
source = bytearray((fixtures / f"{variant}.ojn").read_bytes())
for index in range(3):
    struct.pack_into("<I", source, 284 + index * 4, len(source))
    source += struct.pack("<IHH4B", 0, 2 + index, 1, 1, 0, 0xf1, 0)
struct.pack_into("<I", source, 296, len(source))
(root / "songs/song.ojn").write_bytes(source)
(root / "songs/copy.ojn").write_bytes(source)
(root / f"songs/{variant}.ojm").write_bytes((fixtures / f"{variant}.ojm").read_bytes())
converter = str(pathlib.Path("native/target/debug/open2jam-converter").resolve())
request = {"schemaVersion": 1, "jobId": "catalog", "command": "CATALOG", "roots": [str(root / "songs")],
           "rootIds": {str(root / "songs"): "library:sha256:" + "01" * 32}, "previousIndexPath": None,
           "stagingRoot": str(root / "catalog"), "cancelMarkerPath": str(root / "cancel")}
(root / "request.json").write_text(json.dumps(request))
subprocess.run([converter, "catalog", "--request", str(root / "request.json"), "--progress", str(root / "progress.jsonl"),
                "--result", str(root / "result.json")], check=True)
result = json.loads((root / "result.json").read_text())
catalog = json.loads(pathlib.Path(result["output"]["catalogPath"]).read_text())
assert len(catalog["entries"]) == 6
print(f"Native OJN gameplay variant: {variant}")
run = subprocess.run(["godot", "--headless", "--path", "rewrite/godot", "--log-file", str(root / "godot.log"),
                      "--script", "res://scripts/tests/native_ojn_gameplay_test.gd", "--", converter,
                      str(root / "songs"), str(root / "work")], capture_output=True, text=True, timeout=45)
print(run.stdout, end="")
marker = "Raw OJN reached Gameplay Ready through the native converter and judged its note with audio."
if run.returncode or marker not in run.stdout or "SCRIPT ERROR" in run.stdout or "SCRIPT ERROR" in run.stderr:
    print(run.stderr, file=sys.stderr)
    raise SystemExit("Native OJN gameplay gate failed")
PY
