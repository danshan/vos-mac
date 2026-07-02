#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

PAIR_CAPTURE="rewrite/tools/capture_gameplay_parity_pair.sh"
JAVA_CAPTURE="rewrite/tools/capture_java_gameplay_screenshot.sh"
RECORDED_CAPTURE="rewrite/tools/capture_recorded_gameplay_parity_summaries.sh"
PARITY_GATE="rewrite/tools/verify_vos_godot_java_parity.sh"

require_text() {
	local path="$1"
	local text="$2"
	local label="$3"
	if ! grep -Fq -- "$text" "$path"; then
		printf 'Missing %s in %s\n' "$label" "$path" >&2
		exit 1
	fi
}

reject_text() {
	local path="$1"
	local text="$2"
	local label="$3"
	if grep -Fq -- "$text" "$path"; then
		printf 'Unexpected %s in %s\n' "$label" "$path" >&2
		exit 1
	fi
}

require_text "$PAIR_CAPTURE" 'Usage: rewrite/tools/capture_gameplay_parity_pair.sh <chart-file>' \
	"format-generic pair capture usage"
require_text "$PAIR_CAPTURE" '--export-vos-selected' \
	"selected bundle export for pair capture"
require_text "$PAIR_CAPTURE" '--out-dir "$EXPORT_DIR"' \
	"selected bundle output directory"
require_text "$PAIR_CAPTURE" '--chart-index "$CHART_INDEX"' \
	"selected bundle chart index"
reject_text "$PAIR_CAPTURE" '--export-vos-gameplay' \
	"direct gameplay-only export in pair capture"
require_text "$PAIR_CAPTURE" 'OPEN2JAM_CAPTURE_GAMEPLAY="$EXPORT_DIR/gameplay.json"' \
	"selected gameplay bundle path"
require_text "$PAIR_CAPTURE" 'OPEN2JAM_CAPTURE_RENDER_METADATA="$EXPORT_DIR/render-metadata.json"' \
	"selected render metadata bundle path"
require_text "$PAIR_CAPTURE" 'OPEN2JAM_PARITY_COMPARE_PIXEL_TOLERANCE' \
	"optional renderer rounding tolerance"
require_text "$PAIR_CAPTURE" '--pixel-tolerance "$COMPARE_PIXEL_TOLERANCE"' \
	"Java screenshot compare pixel tolerance"

require_text "$JAVA_CAPTURE" 'Usage: rewrite/tools/capture_java_gameplay_screenshot.sh <chart-file>' \
	"format-generic Java capture usage"
require_text "$JAVA_CAPTURE" '--capture-vos-gameplay-screenshot' \
	"Java render screenshot oracle command"
require_text "$JAVA_CAPTURE" '--chart-index "$CHART_INDEX"' \
	"Java capture chart index"

require_text "$RECORDED_CAPTURE" 'capture_recorded_gameplay_parity_summaries.sh' \
	"recorded capture usage"
require_text "$RECORDED_CAPTURE" 'target/gameplay-parity-capture' \
	"same-chart VOS output directory"
require_text "$RECORDED_CAPTURE" 'target/gameplay-parity-capture-real-demo' \
	"real demo VOS output directory"
require_text "$RECORDED_CAPTURE" 'target/gameplay-parity-capture-real-ojn-notes' \
	"real OJN output directory"
require_text "$RECORDED_CAPTURE" 'target/gameplay-parity-capture-real-osu-notes' \
	"real OSU output directory"
require_text "$RECORDED_CAPTURE" 'capture_pair "real OSU long-note" "$REAL_OSU_CHART" "target/gameplay-parity-capture-real-osu-notes" 0 3800 4' \
	"real OSU renderer tolerance"

require_text "$PARITY_GATE" 'verify_recorded_summary "same-chart VOS"' \
	"recorded same-chart VOS summary verification"
require_text "$PARITY_GATE" 'verify_recorded_summary "real demo VOS"' \
	"recorded real demo VOS summary verification"
require_text "$PARITY_GATE" 'verify_recorded_summary "real OJN note-time"' \
	"recorded real OJN summary verification"
require_text "$PARITY_GATE" 'verify_recorded_summary "real OSU long-note"' \
	"recorded real OSU summary verification"
require_text "$PARITY_GATE" 'OPEN2JAM_PARITY_PIXEL_TOLERANCE="$pixel_tolerance"' \
	"recorded summary pixel tolerance propagation"
require_text "$PARITY_GATE" 'REQUIRE_RECORDED_SUMMARIES="${OPEN2JAM_RECORDED_PARITY_REQUIRE_ALL:-0}"' \
	"recorded summary require-all verifier switch"
require_text "$PARITY_GATE" 'Missing recorded %s summary artifacts' \
	"recorded summary require-all missing artifact failure"
require_text "$PARITY_GATE" 'target/gameplay-parity-capture/summary.json' \
	"recorded same-chart VOS summary path"
require_text "$PARITY_GATE" 'target/gameplay-parity-capture-real-demo/summary.json' \
	"recorded real demo VOS summary path"
require_text "$PARITY_GATE" 'target/gameplay-parity-capture-real-ojn-notes/summary.json' \
	"recorded real OJN summary path"
require_text "$PARITY_GATE" 'target/gameplay-parity-capture-real-osu-notes/summary.json' \
	"recorded real OSU summary path"

echo "Gameplay parity capture contract test passed."
