#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "$ROOT_DIR"
[[ "$(uname -s)" == Darwin && "$(uname -m)" == arm64 ]] || {
	printf 'The local macOS probe requires an Apple Silicon Mac.\n' >&2
	exit 1
}
[[ "$(godot --version)" == 4.6.3.stable.* ]] || {
	printf 'The probe requires Godot 4.6.3 stable.\n' >&2
	exit 1
}
OUTPUT_DIR="$ROOT_DIR/.scratch/godot-rust-migration/target/macos-probe"
APP="$OUTPUT_DIR/VosNativeProbe.app"
TEMPLATE="$ROOT_DIR/.scratch/godot-rust-migration/target/tools/macos.zip"
[[ -f "$TEMPLATE" ]] || {
	printf 'Missing verified Godot 4.6.3 macos.zip export template.\n' >&2
	exit 1
}
[[ ! -e "$APP" ]] || {
	printf 'Probe output already exists; move it aside before rebuilding: %s\n' "$APP" >&2
	exit 1
}
mkdir -p "$OUTPUT_DIR"
mise exec -- cargo build --manifest-path native/Cargo.toml --locked --release \
	-p open2jam-cli --bin open2jam-converter
godot --headless --editor --path rewrite/prototypes/macos-cli --import --quit \
	>"$OUTPUT_DIR/import.log" 2>&1
godot --headless --path rewrite/prototypes/macos-cli --export-release "macOS Probe" "$APP" \
	>"$OUTPUT_DIR/export.log" 2>&1
if grep -E '(^|[[:space:]])(SCRIPT ERROR|ERROR):' "$OUTPUT_DIR/import.log" "$OUTPUT_DIR/export.log"; then
	printf 'Godot probe import/export logged errors.\n' >&2
	exit 1
fi
# Official templates contain a universal binary; thin before signing the bundle.
BINARY="$APP/Contents/MacOS/VosNativeProbe"
lipo "$BINARY" -thin arm64 -output "$BINARY.arm64"
mv "$BINARY.arm64" "$BINARY"
chmod +x "$BINARY"
mkdir -p "$APP/Contents/Helpers"
cp native/target/release/open2jam-converter "$APP/Contents/Helpers/open2jam-converter"
cp rewrite/prototypes/macos-cli/probe-resource.txt "$APP/Contents/Resources/probe-resource.txt"
codesign --force --sign - "$APP/Contents/Helpers/open2jam-converter"
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
printf 'Built ad-hoc signed macOS probe: %s\n' "$APP"
