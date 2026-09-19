#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "$ROOT_DIR"
TEST_ROOT="$(mktemp -d /tmp/vos-native-osu.XXXXXX)"
cleanup() {
    case "$TEST_ROOT" in
        /tmp/vos-native-osu.*|/private/tmp/vos-native-osu.*) rm -rf -- "$TEST_ROOT" ;;
        *) return 1 ;;
    esac
}
trap cleanup EXIT
mise exec -- cargo build --manifest-path native/Cargo.toml -p open2jam-cli --bin open2jam-converter --locked
mise exec -- python3 - "$TEST_ROOT" <<'PY'
import pathlib
import subprocess
import sys

root = pathlib.Path(sys.argv[1]).resolve()
for directory in ["songs/set", "work"]:
    (root / directory).mkdir(parents=True)
fixtures = pathlib.Path("rewrite/golden/java-migration/sources")
source = (fixtures / "osu/seven-key.osu").read_text().replace("36,192,0,1,0,0:0:0:0:", "36,192,0,1,0,0:0:0:100:audio.wav")
(root / "songs/set/one.osu").write_text(source)
(root / "songs/set/two.OSU").write_text(source.replace("Version:Test 7K", "Version:Hard 7K"))
(root / "songs/root.osu").write_text(source)
(root / "songs/set/audio.wav").write_bytes((fixtures / "osu/audio.wav").read_bytes())
(root / "songs/audio.wav").write_bytes((fixtures / "osu/audio.wav").read_bytes())
(root / "songs/legacy.ojn").write_bytes((fixtures / "ojn/minimal.ojn").read_bytes())
(root / "songs/minimal.ojm").write_bytes((fixtures / "ojn/minimal.ojm").read_bytes())
(root / "songs/unsupported.osu").write_text(source.replace("CircleSize:7", "CircleSize:4"))
converter = str(pathlib.Path("native/target/debug/open2jam-converter").resolve())
run = subprocess.run(["godot", "--headless", "--path", "rewrite/godot", "--log-file", str(root / "godot.log"),
                      "--script", "res://scripts/tests/native_osu_gameplay_test.gd", "--", converter,
                      str(root / "songs"), str(root / "work")], capture_output=True, text=True, timeout=45)
print(run.stdout, end="")
marker = "Raw osu reached Gameplay Ready and judged seven lanes and a hold with audio."
if run.returncode or marker not in run.stdout or "SCRIPT ERROR" in run.stdout or "SCRIPT ERROR" in run.stderr:
    print(run.stderr, file=sys.stderr)
    raise SystemExit("Native osu gameplay gate failed")
PY
