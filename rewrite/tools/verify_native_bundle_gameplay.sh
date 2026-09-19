#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "$ROOT_DIR"
TEST_ROOT="$(mktemp -d /tmp/vos-native-gameplay.XXXXXX)"
cleanup() {
    case "$TEST_ROOT" in
        /tmp/vos-native-gameplay.*|/private/tmp/vos-native-gameplay.*) rm -rf -- "$TEST_ROOT" ;;
        *) printf 'Refusing unsafe gameplay fixture cleanup.\n' >&2; return 1 ;;
    esac
}
trap cleanup EXIT
mise exec -- cargo run --manifest-path native/Cargo.toml -p open2jam-cli --bin controlled-bundle-probe --locked -- "$TEST_ROOT/generated"
mise exec -- cargo build --manifest-path native/Cargo.toml -p open2jam-cli --bin open2jam-converter --locked
mv "$TEST_ROOT/generated" "$TEST_ROOT/relocated bundle"
python3 rewrite/tools/create_invalid_native_bundles.py "$TEST_ROOT/relocated bundle" "$TEST_ROOT/invalid"
# Some Godot script parse failures exit zero. Require success markers and no script errors.
mise exec -- python3 - "$TEST_ROOT" <<'PY'
import pathlib
import subprocess
import sys

root = pathlib.Path(sys.argv[1]).resolve()
for script, target, marker in [
    ("native_bundle_cancellation_test.gd", root / "relocated bundle", "Native validation and JSON scanning honour cancellation without changing valid input."),
    ("native_bundle_gameplay_test.gd", root / "relocated bundle", "Native bundle reached Gameplay Ready and judged tap/hold/tap with audio."),
    ("native_bundle_rejection_test.gd", root / "invalid", "Native invalid bundle matrix rejected: 21 cases."),
]:
    arguments = [str(target)]
    if script == "native_bundle_gameplay_test.gd":
        arguments += [str(root), str(pathlib.Path("native/target/debug/open2jam-converter").resolve())]
    result = subprocess.run([
        "godot", "--headless", "--path", "rewrite/godot", "--log-file", str(root / (script + ".log")),
        "--script", "res://scripts/tests/" + script, "--", *arguments,
    ], capture_output=True, text=True, timeout=60)
    print(result.stdout, end="")
    if result.returncode or marker not in result.stdout or "SCRIPT ERROR" in result.stderr or "SCRIPT ERROR" in result.stdout:
        print(result.stderr, file=sys.stderr)
        raise SystemExit("Native bundle gameplay gate failed")
PY
