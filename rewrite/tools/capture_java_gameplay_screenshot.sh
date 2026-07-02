#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

INPUT_PATH="${1:-${OPEN2JAM_JAVA_CAPTURE_INPUT:-}}"
OUTPUT_PATH="${OPEN2JAM_JAVA_CAPTURE_OUTPUT:-$ROOT_DIR/target/java-captures/java-gameplay-reference.png}"
CHART_INDEX="${OPEN2JAM_JAVA_CAPTURE_CHART_INDEX:-0}"
DELAY_MS="${OPEN2JAM_JAVA_CAPTURE_DELAY_MS:-1500}"
FRAME="${OPEN2JAM_JAVA_CAPTURE_FRAME:-2}"
GAME_TIME_MS="${OPEN2JAM_JAVA_CAPTURE_GAME_TIME_MS:-1000}"
CONFIG_DIR="${OPEN2JAM_JAVA_CAPTURE_CONFIG_DIR:-$ROOT_DIR/target/java-capture-config}"

if [[ -z "$INPUT_PATH" ]]; then
    cat >&2 <<'EOF'
Usage: rewrite/tools/capture_java_gameplay_screenshot.sh <chart-file>

Environment overrides:
  OPEN2JAM_JAVA_CAPTURE_OUTPUT
  OPEN2JAM_JAVA_CAPTURE_CHART_INDEX
  OPEN2JAM_JAVA_CAPTURE_DELAY_MS
  OPEN2JAM_JAVA_CAPTURE_FRAME
  OPEN2JAM_JAVA_CAPTURE_GAME_TIME_MS
  OPEN2JAM_JAVA_CAPTURE_CONFIG_DIR
EOF
    exit 2
fi

JAR_FILE="$(find target -maxdepth 1 -type f -name 'open2jam-*.jar' ! -name 'original-*' | sort | tail -n 1)"
if [[ -z "$JAR_FILE" ]]; then
    echo "Packaged jar not found. Run: mise run package" >&2
    exit 1
fi
if [[ src/org/open2jam/export/VosExportCli.java -nt "$JAR_FILE" ||
      src/org/open2jam/render/Render.java -nt "$JAR_FILE" ||
      src/org/open2jam/render/lwjgl/LWJGLGameWindow.java -nt "$JAR_FILE" ]]; then
    echo "Packaged jar is older than the Java capture sources. Run: mise run package" >&2
    exit 1
fi

mkdir -p "$(dirname "$OUTPUT_PATH")" "$CONFIG_DIR"

rewrite/tools/open2jam-java \
    -Dopen2jam.config.dir="$CONFIG_DIR" \
    -jar "$JAR_FILE" \
    --capture-vos-gameplay-screenshot \
    --output "$OUTPUT_PATH" \
    --chart-index "$CHART_INDEX" \
    --delay-ms "$DELAY_MS" \
    --frame "$FRAME" \
    --game-time-ms "$GAME_TIME_MS" \
    "$INPUT_PATH"

echo "Saved Java gameplay screenshot: $OUTPUT_PATH"
