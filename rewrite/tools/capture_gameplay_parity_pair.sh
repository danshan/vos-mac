#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

INPUT_PATH="${1:-${OPEN2JAM_PARITY_CAPTURE_INPUT:-}}"
OUTPUT_DIR="${OPEN2JAM_PARITY_CAPTURE_OUTPUT_DIR:-$ROOT_DIR/target/gameplay-parity-capture}"
CHART_INDEX="${OPEN2JAM_PARITY_CAPTURE_CHART_INDEX:-0}"
GAME_TIME_MS="${OPEN2JAM_PARITY_CAPTURE_GAME_TIME_MS:-1000}"
JAVA_DELAY_MS="${OPEN2JAM_PARITY_CAPTURE_JAVA_DELAY_MS:-0}"
JAVA_FRAME="${OPEN2JAM_PARITY_CAPTURE_JAVA_FRAME:-2}"
JAVA_CAPTURE_ATTEMPTS="${OPEN2JAM_PARITY_CAPTURE_JAVA_ATTEMPTS:-3}"
MIN_JAVA_IMAGE_BYTES="${OPEN2JAM_PARITY_CAPTURE_MIN_JAVA_IMAGE_BYTES:-32768}"
COMPARE_PIXEL_TOLERANCE="${OPEN2JAM_PARITY_COMPARE_PIXEL_TOLERANCE:-0}"
GODOT_ANIMATION_FRAME_OFFSET_MS="${OPEN2JAM_PARITY_CAPTURE_GODOT_ANIMATION_FRAME_OFFSET_MS:-0}"
GODOT_ANIMATION_TIME_MS="${OPEN2JAM_PARITY_CAPTURE_GODOT_ANIMATION_TIME_MS:-$(awk "BEGIN { print $JAVA_DELAY_MS + $GODOT_ANIMATION_FRAME_OFFSET_MS }")}"

if [[ -z "$INPUT_PATH" ]]; then
    cat >&2 <<'EOF'
Usage: rewrite/tools/capture_gameplay_parity_pair.sh <chart-file>

Environment overrides:
  OPEN2JAM_PARITY_CAPTURE_OUTPUT_DIR
  OPEN2JAM_PARITY_CAPTURE_CHART_INDEX
  OPEN2JAM_PARITY_CAPTURE_GAME_TIME_MS
  OPEN2JAM_PARITY_CAPTURE_JAVA_DELAY_MS  default: 0
  OPEN2JAM_PARITY_CAPTURE_JAVA_FRAME  default: 2
  OPEN2JAM_PARITY_CAPTURE_JAVA_ATTEMPTS  default: 3
  OPEN2JAM_PARITY_CAPTURE_MIN_JAVA_IMAGE_BYTES  default: 32768
  OPEN2JAM_PARITY_COMPARE_PIXEL_TOLERANCE  default: 0
  OPEN2JAM_PARITY_CAPTURE_GODOT_ANIMATION_TIME_MS
  OPEN2JAM_PARITY_CAPTURE_GODOT_ANIMATION_FRAME_OFFSET_MS  default: 0
EOF
    exit 2
fi

mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"
GODOT_LOG_FILE="${OPEN2JAM_PARITY_CAPTURE_GODOT_LOG_FILE:-$OUTPUT_DIR/godot-capture.log}"
mkdir -p "$(dirname "$GODOT_LOG_FILE")"
GODOT_LOG_FILE="$(cd "$(dirname "$GODOT_LOG_FILE")" && pwd)/$(basename "$GODOT_LOG_FILE")"

JAR_FILE="$(find target -maxdepth 1 -type f -name 'open2jam-*.jar' ! -name 'original-*' | sort | tail -n 1)"
if [[ -z "$JAR_FILE" ]]; then
    echo "Packaged jar not found. Run: mise run package" >&2
    exit 1
fi
if [[ src/org/open2jam/export/VosExportCli.java -nt "$JAR_FILE" ||
      src/org/open2jam/export/PlayableChartSelector.java -nt "$JAR_FILE" ||
      src/org/open2jam/export/VosAudioExporter.java -nt "$JAR_FILE" ||
      src/org/open2jam/export/VosCatalogExporter.java -nt "$JAR_FILE" ||
      src/org/open2jam/export/VosGameplayExporter.java -nt "$JAR_FILE" ||
      src/org/open2jam/export/VosRenderMetadataExporter.java -nt "$JAR_FILE" ||
      src/org/open2jam/render/Render.java -nt "$JAR_FILE" ||
      src/org/open2jam/render/lwjgl/LWJGLGameWindow.java -nt "$JAR_FILE" ]]; then
    echo "Packaged jar is older than the Java capture sources. Run: mise run package" >&2
    exit 1
fi

EXPORT_DIR="$OUTPUT_DIR/exported"
JAVA_IMAGE="$OUTPUT_DIR/java-gameplay-reference.png"
GODOT_IMAGE="$OUTPUT_DIR/godot-gameplay-reference.png"

mkdir -p "$EXPORT_DIR"

file_size_bytes() {
    if stat -f%z "$1" >/dev/null 2>&1; then
        stat -f%z "$1"
    else
        stat -c%s "$1"
    fi
}

capture_java_reference() {
    local attempt=1
    local frame="$JAVA_FRAME"
    while [[ "$attempt" -le "$JAVA_CAPTURE_ATTEMPTS" ]]; do
        OPEN2JAM_JAVA_CAPTURE_OUTPUT="$JAVA_IMAGE" \
        OPEN2JAM_JAVA_CAPTURE_CHART_INDEX="$CHART_INDEX" \
        OPEN2JAM_JAVA_CAPTURE_DELAY_MS="$JAVA_DELAY_MS" \
        OPEN2JAM_JAVA_CAPTURE_FRAME="$frame" \
        OPEN2JAM_JAVA_CAPTURE_GAME_TIME_MS="$GAME_TIME_MS" \
        rewrite/tools/capture_java_gameplay_screenshot.sh "$INPUT_PATH"

        local image_size
        image_size="$(file_size_bytes "$JAVA_IMAGE")"
        if [[ "$image_size" -ge "$MIN_JAVA_IMAGE_BYTES" ]]; then
            return 0
        fi

        printf 'Java gameplay screenshot is too small (%s bytes); retrying capture with frame %s\n' \
            "$image_size" "$((frame + 1))" >&2
        frame="$((frame + 1))"
        attempt="$((attempt + 1))"
    done

    printf 'Java gameplay screenshot stayed below %s bytes after %s attempts: %s\n' \
        "$MIN_JAVA_IMAGE_BYTES" "$JAVA_CAPTURE_ATTEMPTS" "$JAVA_IMAGE" >&2
    return 1
}

rewrite/tools/open2jam-java \
    -jar "$JAR_FILE" \
    --export-vos-selected \
    --out-dir "$EXPORT_DIR" \
    --chart-index "$CHART_INDEX" \
    "$INPUT_PATH"

capture_java_reference

OPEN2JAM_CAPTURE_OUTPUT="$GODOT_IMAGE" \
OPEN2JAM_CAPTURE_GAMEPLAY="$EXPORT_DIR/gameplay.json" \
OPEN2JAM_CAPTURE_RENDER_METADATA="$EXPORT_DIR/render-metadata.json" \
OPEN2JAM_CAPTURE_TIME_MS="$GAME_TIME_MS" \
OPEN2JAM_CAPTURE_ANIMATION_TIME_MS="$GODOT_ANIMATION_TIME_MS" \
OPEN2JAM_CAPTURE_JAVA_REFERENCE_STATE=1 \
godot --log-file "$GODOT_LOG_FILE" --path rewrite/godot --script res://scripts/tools/capture_gameplay_screenshot.gd

rewrite/tools/open2jam-java \
    -Djava.awt.headless=true \
    -jar "$JAR_FILE" \
    --compare-vos-gameplay-screenshots \
    --java "$JAVA_IMAGE" \
    --godot "$GODOT_IMAGE" \
    --out-dir "$OUTPUT_DIR" \
    --pixel-tolerance "$COMPARE_PIXEL_TOLERANCE"

OPEN2JAM_PARITY_PIXEL_TOLERANCE="$COMPARE_PIXEL_TOLERANCE" \
rewrite/tools/verify_gameplay_parity_summary.sh \
    "$OUTPUT_DIR/summary.json" \
    "$OUTPUT_DIR/diff-components.json"

cat <<EOF
Saved gameplay parity capture package:
  Java: $JAVA_IMAGE
  Godot: $GODOT_IMAGE
  Side by side: $OUTPUT_DIR/side-by-side.png
  Diff: $OUTPUT_DIR/diff.png
  Summary: $OUTPUT_DIR/summary.json
EOF
