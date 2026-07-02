#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

export OPEN2JAM_CAPTURE_OUTPUT="${OPEN2JAM_CAPTURE_OUTPUT:-$ROOT_DIR/target/godot-captures/godot-gameplay-fixture.png}"
GODOT_LOG_FILE="${OPEN2JAM_CAPTURE_GODOT_LOG_FILE:-$ROOT_DIR/target/godot-logs/capture-godot-gameplay-screenshot.log}"

mkdir -p "$(dirname "$GODOT_LOG_FILE")"

godot --log-file "$GODOT_LOG_FILE" --path rewrite/godot --script res://scripts/tools/capture_gameplay_screenshot.gd
