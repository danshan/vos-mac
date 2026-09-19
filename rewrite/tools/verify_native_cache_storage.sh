#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "$ROOT_DIR"
TEST_ROOT="$(mktemp -d /tmp/vos-cache-storage.XXXXXX)"
MOUNTED=false
cleanup() {
    if "$MOUNTED"; then
        hdiutil detach "$TEST_ROOT/mount" || return 1
    fi
    case "$TEST_ROOT" in
        /tmp/vos-cache-storage.*|/private/tmp/vos-cache-storage.*) rm -rf -- "$TEST_ROOT" ;;
        *) return 1 ;;
    esac
}
trap cleanup EXIT
# Only this bounded temporary image is filled, never the host filesystem.
hdiutil create -size 16m -fs HFS+ -volname VosCacheGate -type UDIF "$TEST_ROOT/full.dmg"
mkdir "$TEST_ROOT/mount"
hdiutil attach "$TEST_ROOT/full.dmg" -mountpoint "$TEST_ROOT/mount" -nobrowse
MOUNTED=true
python3 - "$TEST_ROOT/mount" <<'PY'
import errno
import pathlib
import sys
root = pathlib.Path(sys.argv[1]).resolve()
(root / "staging").mkdir()
try:
    with (root / "filler").open("wb", buffering=0) as stream:
        while True:
            stream.write(bytes(65536))
except OSError as error:
    if error.errno != errno.ENOSPC:
        raise
    print("Observed actual ENOSPC in the bounded test volume.")
PY
OPEN2JAM_FULL_STAGING="$TEST_ROOT/mount/staging" mise exec -- bash rewrite/tools/verify_native_load_coordinator.sh
