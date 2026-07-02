#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

HELPER="rewrite/tools/verify_gameplay_parity_summary.sh"
PAIR_CAPTURE="rewrite/tools/capture_gameplay_parity_pair.sh"
if [[ ! -x "$HELPER" ]]; then
	echo "Missing executable helper: $HELPER" >&2
	exit 1
fi
if ! grep -Fq 'verify_gameplay_parity_summary.sh' "$PAIR_CAPTURE"; then
	echo "Expected pair capture to verify the generated gameplay parity summary." >&2
	exit 1
fi

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/open2jam-parity-summary-test.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

PASS_SUMMARY="$TMP_DIR/pass-summary.json"
PASS_COMPONENTS="$TMP_DIR/pass-components.json"
FAIL_SUMMARY="$TMP_DIR/fail-summary.json"
FAIL_COMPONENTS="$TMP_DIR/fail-components.json"
TOLERANCE_SUMMARY="$TMP_DIR/tolerance-summary.json"
TOLERANCE_COMPONENTS="$TMP_DIR/tolerance-components.json"

cat > "$PASS_SUMMARY" <<'JSON'
{"schemaVersion":1,"javaWidth":800,"javaHeight":600,"godotWidth":800,"godotHeight":600,"comparedWidth":800,"comparedHeight":600,"differingPixels":227.0,"meanAbsDelta":0.0021458333333333334,"maxChannelDelta":24}
JSON

cat > "$PASS_COMPONENTS" <<'JSON'
{"schemaVersion":1,"componentCount":27,"components":[{"x":385,"y":569,"width":23,"height":1,"pixels":23,"meanAbsDelta":4.231884057971015,"maxChannelDelta":7}]}
JSON

"$HELPER" "$PASS_SUMMARY" "$PASS_COMPONENTS" >/dev/null

cat > "$FAIL_SUMMARY" <<'JSON'
{"schemaVersion":1,"javaWidth":800,"javaHeight":600,"godotWidth":800,"godotHeight":600,"comparedWidth":800,"comparedHeight":600,"differingPixels":301.0,"meanAbsDelta":0.0021458333333333334,"maxChannelDelta":24}
JSON

cat > "$FAIL_COMPONENTS" <<'JSON'
{"schemaVersion":1,"componentCount":27,"components":[{"x":385,"y":569,"width":23,"height":1,"pixels":23,"meanAbsDelta":4.231884057971015,"maxChannelDelta":7}]}
JSON

if "$HELPER" "$FAIL_SUMMARY" "$FAIL_COMPONENTS" >/dev/null 2>&1; then
	echo "Expected helper to reject excessive differingPixels." >&2
	exit 1
fi

cp "$PASS_SUMMARY" "$FAIL_SUMMARY"
cat > "$FAIL_COMPONENTS" <<'JSON'
{"schemaVersion":1,"componentCount":27,"components":[{"x":385,"y":569,"width":26,"height":1,"pixels":26,"meanAbsDelta":4.231884057971015,"maxChannelDelta":7}]}
JSON

if "$HELPER" "$FAIL_SUMMARY" "$FAIL_COMPONENTS" >/dev/null 2>&1; then
	echo "Expected helper to reject excessive largest component size." >&2
	exit 1
fi

cat > "$FAIL_COMPONENTS" <<'JSON'
{"schemaVersion":1,"componentCount":27,"components":[{"x":385,"y":569,"width":5,"height":5,"pixels":25,"meanAbsDelta":4.231884057971015,"maxChannelDelta":7}]}
JSON

if "$HELPER" "$FAIL_SUMMARY" "$FAIL_COMPONENTS" >/dev/null 2>&1; then
	echo "Expected helper to reject block-shaped structural diff component." >&2
	exit 1
fi

cat > "$TOLERANCE_SUMMARY" <<'JSON'
{"schemaVersion":1,"javaWidth":800,"javaHeight":600,"godotWidth":800,"godotHeight":600,"comparedWidth":800,"comparedHeight":600,"differingPixels":1033.0,"significantDifferingPixels":200.0,"pixelTolerance":4,"meanAbsDelta":0.003907638888888889,"significantMeanAbsDelta":0.002187,"maxChannelDelta":24}
JSON

cat > "$TOLERANCE_COMPONENTS" <<'JSON'
{"schemaVersion":1,"componentCount":21,"components":[{"x":322,"y":569,"width":21,"height":1,"pixels":21,"meanAbsDelta":4.619047619047619,"maxChannelDelta":7}]}
JSON

if "$HELPER" "$TOLERANCE_SUMMARY" "$TOLERANCE_COMPONENTS" >/dev/null 2>&1; then
	echo "Expected helper to reject raw differingPixels without tolerance mode." >&2
	exit 1
fi

OPEN2JAM_PARITY_PIXEL_TOLERANCE=4 "$HELPER" "$TOLERANCE_SUMMARY" "$TOLERANCE_COMPONENTS" >/dev/null

echo "Gameplay parity summary verifier test passed."
