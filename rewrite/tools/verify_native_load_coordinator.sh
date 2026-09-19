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
import os
import subprocess
import sys
root = pathlib.Path(sys.argv[1]).resolve()
for name in ["hang-helper", "late-helper", "marker-error-helper"]:
    helper = root / name
    body = pathlib.Path("rewrite/tools/native_load_test_helper.py").read_text().split("\n", 1)[1]
    helper.write_text("#!" + sys.executable + "\n" + body)
    helper.chmod(0o700)
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
for pid_file in root.glob("*.pid"):
    try:
        os.kill(int(pid_file.read_text()), 0)
    except ProcessLookupError:
        continue
    raise SystemExit("Controlled helper was not reaped: " + pid_file.name)
PY

