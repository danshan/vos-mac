#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

VOS_CHART="${OPEN2JAM_RECORDED_PARITY_VOS_CHART:-/Users/honghao.shan/Music/demo/Age of empire.vos}"
REAL_DEMO_VOS_CHART="${OPEN2JAM_RECORDED_PARITY_REAL_DEMO_VOS_CHART:-$VOS_CHART}"
REAL_OJN_CHART="${OPEN2JAM_RECORDED_PARITY_OJN_CHART:-/Users/honghao.shan/Music/demo/o2ma101.ojn}"
REAL_OSU_CHART="${OPEN2JAM_RECORDED_PARITY_OSU_CHART:-/Users/honghao.shan/Music/demo/1187083 Jay Chou - Nocturne.osz}"
REQUIRE_ALL="${OPEN2JAM_RECORDED_PARITY_REQUIRE_ALL:-0}"

usage() {
	cat <<'EOF'
Usage: rewrite/tools/capture_recorded_gameplay_parity_summaries.sh

Refreshes recorded gameplay parity screenshot packages under target/.

Environment overrides:
  OPEN2JAM_RECORDED_PARITY_VOS_CHART
  OPEN2JAM_RECORDED_PARITY_REAL_DEMO_VOS_CHART
  OPEN2JAM_RECORDED_PARITY_OJN_CHART
  OPEN2JAM_RECORDED_PARITY_OSU_CHART
  OPEN2JAM_RECORDED_PARITY_REQUIRE_ALL=1
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
	usage
	exit 0
fi

capture_pair() {
	local label="$1"
	local input_path="$2"
	local output_dir="$3"
	local chart_index="$4"
	local game_time_ms="$5"
	local pixel_tolerance="$6"

	if [[ ! -f "$input_path" ]]; then
		local message="Skipping recorded ${label} capture; chart is not present: ${input_path}"
		if [[ "$REQUIRE_ALL" == "1" ]]; then
			printf '%s\n' "$message" >&2
			return 1
		fi
		printf '%s\n' "$message"
		return 0
	fi

	printf 'Capturing recorded %s parity package.\n' "$label"
	OPEN2JAM_PARITY_CAPTURE_OUTPUT_DIR="$ROOT_DIR/$output_dir" \
	OPEN2JAM_PARITY_CAPTURE_CHART_INDEX="$chart_index" \
	OPEN2JAM_PARITY_CAPTURE_GAME_TIME_MS="$game_time_ms" \
	OPEN2JAM_PARITY_COMPARE_PIXEL_TOLERANCE="$pixel_tolerance" \
		rewrite/tools/capture_gameplay_parity_pair.sh "$input_path"
}

capture_pair "same-chart VOS" "$VOS_CHART" "target/gameplay-parity-capture" 0 1000 0
capture_pair "real demo VOS" "$REAL_DEMO_VOS_CHART" "target/gameplay-parity-capture-real-demo" 0 1000 0
capture_pair "real OJN note-time" "$REAL_OJN_CHART" "target/gameplay-parity-capture-real-ojn-notes" 2 5000 0
capture_pair "real OSU long-note" "$REAL_OSU_CHART" "target/gameplay-parity-capture-real-osu-notes" 0 3800 4

cat <<'EOF'
Recorded gameplay parity capture refresh finished.
Run rewrite/tools/verify_vos_godot_java_parity.sh to verify the recorded summaries.
EOF
