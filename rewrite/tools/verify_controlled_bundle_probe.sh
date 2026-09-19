#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "$ROOT_DIR"
TEST_ROOT="$(mktemp -d /tmp/vos-controlled-bundle.XXXXXX)"
cleanup() {
    case "$TEST_ROOT" in
        /tmp/vos-controlled-bundle.*|/private/tmp/vos-controlled-bundle.*) rm -rf -- "$TEST_ROOT" ;;
        *) printf 'Refusing unsafe fixture cleanup.\n' >&2; return 1 ;;
    esac
}
trap cleanup EXIT
mise exec -- cargo run --manifest-path native/Cargo.toml -p open2jam-cli --bin controlled-bundle-probe --locked -- "$TEST_ROOT/generated"
mv "$TEST_ROOT/generated" "$TEST_ROOT/relocated bundle"
python3 - "$TEST_ROOT/relocated bundle/audio/tone.wav" <<'PY'
import struct
import sys
import wave

with wave.open(sys.argv[1], "rb") as audio:
    assert (audio.getnchannels(), audio.getsampwidth(), audio.getframerate(), audio.getnframes()) == (2, 2, 44100, 11025)
    samples = struct.unpack("<22050h", audio.readframes(11025))
    assert samples[::2] == samples[1::2]
    assert (min(samples), max(samples)) == (-2048, 2048)
    assert len(set(samples)) > 40
print("Independent WAV decode: stereo PCM16, 44100 Hz, non-silent and unclipped")
PY
mise exec -- godot --headless --path rewrite/godot --log-file "$TEST_ROOT/godot.log" \
    --script res://scripts/tests/native_bundle_audio_probe_test.gd -- "$TEST_ROOT/relocated bundle"
