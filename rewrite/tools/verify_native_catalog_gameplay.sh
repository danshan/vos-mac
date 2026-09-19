#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "$ROOT_DIR"
TEST_ROOT="$(mktemp -d /tmp/vos-native-catalog.XXXXXX)"
cleanup() {
    case "$TEST_ROOT" in
        /tmp/vos-native-catalog.*|/private/tmp/vos-native-catalog.*) rm -rf -- "$TEST_ROOT" ;;
        *) return 1 ;;
    esac
}
trap cleanup EXIT
mkdir "$TEST_ROOT/library" "$TEST_ROOT/work"
mise exec -- cargo run --manifest-path native/Cargo.toml -p open2jam-cli --bin controlled-bundle-probe --locked -- "$TEST_ROOT/library/good"
mise exec -- cargo build --manifest-path native/Cargo.toml -p open2jam-cli --bin open2jam-converter --locked
mise exec -- python3 - "$TEST_ROOT" <<'PY'
import pathlib
import shutil
import subprocess
import sys
root = pathlib.Path(sys.argv[1]).resolve()
shutil.copytree(root / "library/good", root / "library/broken")
(root / "library/broken/audio/tone.wav").unlink()
(root / "library").rename(root / "relocated-library")
result = subprocess.run([
    "godot", "--headless", "--path", "rewrite/godot", "--log-file", str(root / "catalog.log"),
    "--script", "res://scripts/tests/native_catalog_gameplay_test.gd", "--",
    str(pathlib.Path("native/target/debug/open2jam-converter").resolve()), str(pathlib.Path(sys.argv[1]) / "relocated-library"), str(root / "work"),
], capture_output=True, text=True, timeout=45)
print(result.stdout, end="")
marker = "Native catalog discovered a bundle beside a rejected source and reached playable UI gameplay."
if result.returncode or marker not in result.stdout or "SCRIPT ERROR" in result.stderr or "SCRIPT ERROR" in result.stdout:
    print(result.stderr, file=sys.stderr)
    raise SystemExit("Native catalog gameplay gate failed")
PY
