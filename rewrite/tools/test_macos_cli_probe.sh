#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
APP="$ROOT_DIR/.scratch/godot-rust-migration/target/macos-probe/VosNativeProbe.app"
[[ -d "$APP" ]] || { printf 'Missing macOS probe application.\n' >&2; exit 1; }
codesign --verify --deep --strict "$APP"
[[ "$(lipo -archs "$APP/Contents/MacOS/VosNativeProbe")" == arm64 ]]
[[ "$(lipo -archs "$APP/Contents/Helpers/open2jam-converter")" == arm64 ]]

TEST_ROOT="$(mktemp -d /tmp/vos-macos-probe.XXXXXX)"
TEST_ROOT="$(cd "$TEST_ROOT" && pwd -P)"
cleanup() {
	if [[ "$?" -ne 0 ]]; then
		find "$TEST_ROOT" -maxdepth 1 -type f \( -name "*.json" -o -name "*.log" \) -exec cat {} \; >&2
	fi
	case "$TEST_ROOT" in
		/private/tmp/vos-macos-probe.*|/tmp/vos-macos-probe.*) rm -rf -- "$TEST_ROOT" ;;
		*) printf 'Refusing unsafe probe cleanup.\n' >&2; return 1 ;;
	esac
}
trap cleanup EXIT
MOVED_APP="$TEST_ROOT/Moved App.app"
ditto "$APP" "$MOVED_APP"
codesign --verify --deep --strict "$MOVED_APP"
PROBE_BINARY="$MOVED_APP/Contents/MacOS/VosNativeProbe"
HELPER="$MOVED_APP/Contents/Helpers/open2jam-converter"
# Godot OS.execute uses the system shell; all other executables remain denied.
PROFILE="(version 1)(allow default)(deny process-exec)(allow process-exec (literal \"$PROBE_BINARY\") (literal \"$HELPER\") (literal \"/bin/sh\") (literal \"/bin/bash\"))"
cd "$TEST_ROOT"
sandbox-exec -p "$PROFILE" "$PROBE_BINARY" --headless --log-file "$TEST_ROOT/godot.log" \
	-- --probe-output "$TEST_ROOT/result.json"
python3 - "$TEST_ROOT/result.json" "$MOVED_APP" <<'PY'
import json
import sys
from pathlib import Path

result = json.loads(Path(sys.argv[1]).read_text())
assert result["ok"] is True, result
assert result["converter"]["converterVersion"] == "0.1.0", result
assert result["resource"] == "native-helper-probe-v1", result
assert result["helper_path"].startswith(sys.argv[2] + "/Contents/Helpers/"), result
PY

assert_failure() {
	local expected="$1"
	if sandbox-exec -p "$PROFILE" "$PROBE_BINARY" --headless --log-file "$TEST_ROOT/failure.log" \
		-- --probe-output "$TEST_ROOT/failure.json"; then
		printf 'Probe accepted failure case: %s\n' "$expected" >&2
		exit 1
	fi
	python3 - "$TEST_ROOT/failure.json" "$expected" <<'PYTEST'
import json
import sys
from pathlib import Path

result = json.loads(Path(sys.argv[1]).read_text())
assert result["ok"] is False and result["error"] == sys.argv[2], result
PYTEST
}

RESOURCE="$MOVED_APP/Contents/Resources/probe-resource.txt"
mv "$RESOURCE" "$TEST_ROOT/saved-resource.txt"
assert_failure "Packaged resource is missing"
mv "$TEST_ROOT/saved-resource.txt" "$RESOURCE"
chmod -x "$HELPER"
assert_failure "Embedded helper failed"
chmod +x "$HELPER"
rm "$HELPER"
assert_failure "Embedded helper is missing"
printf 'macOS probe passed: arm64, ad-hoc package, relocation, no-Java execution, failure diagnostics.\n'
